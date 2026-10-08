# tests/test-forma-directa.R
#
# Forma directa y validación anidada de Fase 5 (primer PR de B3; checklist C3 y C4; F5-05, F5-09, F5-11, F5-12 y
# B3-1 a B3-8 de doc/metodologia/decisiones_fase5.md), con datos SINTÉTICOS: no se lee data/. Comprueba la matriz
# de predictores y el crecimiento acumulado, la ventana de B3-2 contra MCO con dummies (Frisch-Waugh-Lovell), que
# ningún pronóstico interno usa datos posteriores a su origen interno (C4), las filas de cada ventana en el primer
# origen de cada grupo con las fechas de inicio de L3 (B3-4), la elección por ECM interno, la covarianza Σ = D R D
# (B3-5, B3-6), las guardas (B3-7) y, de punta a punta, un modelo directo de juguete en el motor.

library(testthat)
source(here::here("src", "evaluacion", "motor_backtesting.R"))   # eval_lib, modelos_referencia, modelos_fase5

# Inicios de las predictoras trimestrales en L3 (los de F4-05 y de evidencia_insumos_fase4.csv).
.INICIOS_L3_FD <- c("BCR.REMESAS.NOM.NSA.Q" = "1991-Q1", "BCR.EXPORT_FOB.NOM.NSA.Q" = "1994-Q1", "BCR.ITCER.IDX.NSA.Q" = "2000-Q1",
                    "UT.DEMANDA_ELEC.GWH.NSA.Q" = "2002-Q1", "BCR.IVAE.VOL.SA.Q" = "2005-Q1", "BCR.IPM.IDX.NSA.Q" = "2005-Q1",
                    "BCR.IPP.IDX.NSA.Q" = "2010-Q1", "BCR.REMESAS.REAL.NSA.Q" = "2010-Q1")

.objetivo_fd <- function(semilla, phi = 0.3, sd = 0.01) {
  set.seed(semilla)
  per <- ind_a_q(q_a_ind("1990-Q1") + 0:144)
  dy <- 0.005 + as.numeric(stats::arima.sim(list(ar = phi), length(per), sd = sd))
  data.frame(periodo = per, y = 4 + cumsum(dy), stringsAsFactors = FALSE)
}
.predictoras_fd <- function(semilla, ids = names(.INICIOS_L3_FD), hasta = "2026-Q2") {
  set.seed(semilla)
  stats::setNames(lapply(ids, function(id) {
    i <- q_a_ind(.INICIOS_L3_FD[[id]]):q_a_ind(hasta)
    est <- if (grepl(".NSA.", id, fixed = TRUE)) 0.03 * sin(pi * (i %% 4L) / 2) else 0
    data.frame(periodo = ind_a_q(i), valor = 100 * exp(cumsum(0.004 + stats::rnorm(length(i), 0, 0.02)) + est), stringsAsFactors = FALSE)
  }), ids)
}
.hasta_fd <- function(d, o) d[q_a_ind(d$periodo) <= o, , drop = FALSE]
.datos_fd <- function(obj, pred, ids, o) c(list(objetivo = .hasta_fd(obj, o)), lapply(pred[ids], .hasta_fd, o = o))

# Modelo directo de juguete: ridge en forma cerrada sobre la ventana transformada, λ de más a menos penalizado.
.esp_ridge <- function(lambdas = c(1, 0.1, 0.01), registro = NULL) list(
  transformar = TRUE,
  candidatos = function(Z, g, h) data.frame(lambda = lambdas),
  estimar_predecir = function(Z, g, z, rejilla, cand) {
    if (is.environment(registro)) registro$filas <- c(registro$filas, nrow(Z))
    n <- nrow(Z)
    vapply(cand, function(j) {
      b <- solve(crossprod(Z) + n * rejilla$lambda[j] * diag(ncol(Z)), crossprod(Z, g))
      as.numeric(z %*% b)
    }, numeric(nrow(z)))
  },
  diagnosticar = function(rejilla, j) c(lambda = rejilla$lambda[j], borde = as.numeric(j %in% c(1L, nrow(rejilla))))
)

test_that("C3, F5-05, F5-09: matriz directa con Δy y Δlog de las predictoras en rezagos 0..3, y crecimiento acumulado", {
  obj <- .objetivo_fd(1); pred <- .predictoras_fd(2)
  ids <- predictoras_grupo("G2"); o <- origenes_grupo("G2")[1]
  md <- matriz_directa(.datos_fd(obj, pred, ids, o), ids, "PRUEBA.DIRECTA")
  expect_identical(md$o, o)
  expect_identical(md$t[1], q_a_ind("2005-Q1") + 1L + 3L)                     # primer Δ del IVAE/IPM más 3 rezagos
  expect_identical(md$t[length(md$t)], o)
  expect_identical(ncol(md$X), 4L * (1L + length(ids)))                         # 28 columnas en G2
  expect_identical(colnames(md$X)[1:4], paste0("objetivo__L", 0:3))
  expect_true(md$con_dummies)
  # una celda: Δlog de las remesas con rezago 2 en el trimestre o - 5
  t0 <- o - 5L; rem <- pred[["BCR.REMESAS.NOM.NSA.Q"]]
  v <- log(rem$valor[q_a_ind(rem$periodo) == t0 - 2L]) - log(rem$valor[q_a_ind(rem$periodo) == t0 - 3L])
  expect_equal(unname(md$X[md$t == t0, "BCR.REMESAS.NOM.NSA.Q__L2"]), v, tolerance = 1e-14)
  dy <- diff(obj$y); expect_equal(unname(md$X[md$t == t0, "objetivo__L1"]), dy[t0 - 1L - q_a_ind("1990-Q1")], tolerance = 1e-14)
  g4 <- crecimiento_acumulado(md, 4L)
  yo <- stats::setNames(obj$y, q_a_ind(obj$periodo))
  expect_equal(unname(g4[as.character(t0)]), unname(yo[as.character(t0 + 4L)] - yo[as.character(t0)]), tolerance = 1e-14)
  expect_true(all(is.na(g4[as.character((o - 3L):o)])))                          # t + h > o: no observado en el origen
  expect_false(anyNA(g4[as.character(md$t[md$t <= o - 4L])]))
  # sin NSA no hay dummies
  expect_false(matriz_directa(.datos_fd(obj, pred, "BCR.IVAE.VOL.SA.Q", o), "BCR.IVAE.VOL.SA.Q", "PRUEBA.DIRECTA")$con_dummies)
  # guardas
  corta <- .datos_fd(obj, pred, ids, o); corta[["BCR.IPM.IDX.NSA.Q"]] <- .hasta_fd(corta[["BCR.IPM.IDX.NSA.Q"]], o - 1L)
  expect_error(matriz_directa(corta, ids, "PRUEBA.DIRECTA"), "BCR.IPM.IDX.NSA.Q no llega al origen 2014-Q4 \\(F5-04\\)")
  neg <- .datos_fd(obj, pred, ids, o); neg[["BCR.ITCER.IDX.NSA.Q"]]$valor[5] <- -1
  expect_error(matriz_directa(neg, ids, "PRUEBA.DIRECTA"), "valores no positivos o ausentes")
  hueco <- .datos_fd(obj, pred, ids, o); hueco[["BCR.EXPORT_FOB.NOM.NSA.Q"]] <- hueco[["BCR.EXPORT_FOB.NOM.NSA.Q"]][-10, ]
  expect_error(matriz_directa(hueco, ids, "PRUEBA.DIRECTA"), "trimestres faltantes o desordenados")
  expect_error(matriz_directa(.datos_fd(obj, pred, ids[-1], o), ids, "PRUEBA.DIRECTA"), "faltan predictoras")
})

test_that("B3-2: la ventana reproduce MCO con constante y dummies (Frisch-Waugh-Lovell) y estandariza con la escala no estacional", {
  set.seed(11)
  n <- 30L; t_ <- q_a_ind("2006-Q1") + seq_len(n) - 1L
  D <- dummies_trimestrales(t_)
  X <- cbind(a = stats::rnorm(n) + as.numeric(D %*% c(2, -1, 0.5)), b = stats::rnorm(n, sd = 3), c = stats::rnorm(n) + 5)
  g <- as.numeric(0.3 + D %*% c(0.1, 0.2, -0.1) + X %*% c(0.5, -0.2, 0.1) + stats::rnorm(n, sd = 0.1))
  vt <- ventana_directa(X, g, t_, con_dummies = TRUE)
  expect_equal(unname(colMeans(vt$Z)), rep(0, 3), tolerance = 1e-12)
  expect_equal(unname(colMeans(vt$Z^2)), rep(1, 3), tolerance = 1e-12)
  expect_equal(unname(crossprod(cbind(1, D), vt$Z)), matrix(0, 4, 3), tolerance = 1e-10)   # sin parte estacional
  # MCO sobre lo residualizado + parte determinista = MCO completo con constante, dummies y X
  b_z <- qr.coef(qr(vt$Z), vt$gz)
  t_n <- t_[n] + 1:3; x_n <- matrix(stats::rnorm(9), 3)
  an <- aplicar_ventana(vt, x_n, t_n)
  completo <- stats::lm.fit(cbind(1, D, X), g)
  esperado <- as.numeric(cbind(1, dummies_trimestrales(t_n), x_n) %*% completo$coefficients)
  expect_equal(as.numeric(an$z %*% b_z) + an$base, esperado, tolerance = 1e-10)
  # sin dummies: solo se centra
  v0 <- ventana_directa(X, g, t_, con_dummies = FALSE)
  expect_equal(unname(v0$Z[, "c"]), unname((X[, "c"] - mean(X[, "c"])) / sqrt(mean((X[, "c"] - mean(X[, "c"]))^2))), tolerance = 1e-12)
  # B3-7: una columna que es solo estacionalidad no tiene variación no estacional
  Xs <- cbind(X, s = as.numeric(D %*% c(1, 2, 3)))
  expect_error(ventana_directa(Xs, g, t_, con_dummies = TRUE), "columnas sin variación no estacional en la ventana \\(B3-7\\): s")
  Xna <- X; Xna[3, 2] <- NA
  expect_error(ventana_directa(Xna, g, t_, con_dummies = TRUE), "NA o valores no finitos \\(B3-7\\)")
  expect_error(ventana_directa(X[1:4, ], g[1:4], t_[1:4], con_dummies = TRUE), "ventana de 4 filas con 4 regresores deterministas")
})

test_that("C4, F5-11: ningún pronóstico interno usa datos posteriores a su origen interno", {
  obj <- .objetivo_fd(3); pred <- .predictoras_fd(4)
  ids <- predictoras_grupo("G2"); o <- origenes_grupo("G2")[5]
  md <- matriz_directa(.datos_fd(obj, pred, ids, o), ids, "PRUEBA.DIRECTA")
  esp <- .esp_ridge()
  rej <- data.frame(lambda = c(1, 0.1, 0.01))
  for (h in c(1L, 2L, 4L, 8L)) {
    org <- origenes_internos(o, h)
    expect_identical(org, as.integer((o - h - 11L):(o - h)))
    base <- pronosticos_internos(md, h, org, esp, rej, 1:3)
    for (op in org[c(1, 6, 12)]) {
      # se alteran todos los datos posteriores a o': el pronóstico de o' no cambia
      alt <- md
      sel <- md$t > op
      alt$X[sel, ] <- alt$X[sel, ] * 3 + 1
      futuros <- as.integer(names(alt$y)) > op
      alt$y[futuros] <- alt$y[futuros] + seq_len(sum(futuros)) * 0.05
      p_alt <- pronosticos_internos(alt, h, op, esp, rej, 1:3)
      expect_identical(p_alt$pred[1, ], base$pred[org == op, ], info = sprintf("h = %d, o' = %s", h, ind_a_q(op)))
      # el error sí cambia: el valor observado g_h(o') usa y hasta o' + h <= o
      expect_false(isTRUE(all.equal(p_alt$obs, base$obs[org == op])))
    }
    # la ventana de o' son exactamente las filas con t + h <= o'
    expect_identical(base$n_filas, vapply(org, function(op) sum(md$t + h <= op), integer(1)))
  }
  # el ajuste completo en o no ve nada posterior a o: el motor recorta (G-1) y el ajuste es el mismo con datos de más
  aj <- ajustar_directo(md, esp)
  md_largo <- matriz_directa(.datos_fd(obj, pred, ids, o + 6L), ids, "PRUEBA.DIRECTA")
  expect_false(identical(ajustar_directo(md_largo, esp)$sendero, aj$sendero))
  expect_identical(ajustar_directo(matriz_directa(.datos_fd(obj, pred, ids, o), ids, "PRUEBA.DIRECTA"), esp)$sendero, aj$sendero)
  # un origen interno anterior a la primera fila con todos los rezagos se detiene
  expect_error(pronosticos_internos(md, 1L, md$t[1] - 1L, esp, rej, 1L), "queda antes de la primera fila con todos los rezagos")
})

test_that("B3-4: filas de las ventanas en el primer origen de cada grupo con las fechas de inicio de L3", {
  obj <- .objetivo_fd(5); pred <- .predictoras_fd(6)
  # n_L = trimestres en niveles hasta el primer origen: 77 en G1 (desde 1994-Q1) y 40 en G2 y G3 (39 Δ)
  esperado <- list(G1 = list(n_L = 77L, min = c(60L, 58L, 54L, 46L), fin = c(72L, 71L, 69L, 65L), col = 12L),
                   G2 = list(n_L = 40L, min = c(23L, 21L, 17L, 9L), fin = c(35L, 34L, 32L, 28L), col = 28L),
                   G3 = list(n_L = 40L, min = c(23L, 21L, 17L, 9L), fin = c(35L, 34L, 32L, 28L), col = 36L))
  for (g in names(esperado)) {
    ids <- predictoras_grupo(g); o1 <- origenes_grupo(g)[1]
    md <- matriz_directa(.datos_fd(obj, pred, ids, o1), ids, paste0("PRUEBA.DIRECTA.", g))
    e <- esperado[[g]]
    expect_identical(length(md$t), e$n_L - 4L, info = g)                       # 1 por el Δ y 3 por los rezagos
    expect_identical(ncol(md$X), e$col, info = g)
    aj <- ajustar_directo(md, .esp_ridge())
    hs <- c(1L, 2L, 4L, 8L)
    expect_identical(vapply(aj$por_h[hs], `[[`, integer(1), "n_filas_min"), e$min, info = g)
    expect_identical(vapply(aj$por_h[hs], `[[`, integer(1), "n_filas_final"), e$fin, info = g)
    expect_identical(e$min, e$n_L - 15L - 2L * hs, info = g)                     # n_L − 15 − 2h
  }
})

test_that("F5-11, B3-5: elección por ECM interno, empates al primero y errores del elegido en los orígenes comunes", {
  expect_identical(seleccionar_candidato(c(3, 1, 1, 2)), 2L)
  expect_error(seleccionar_candidato(c(1, NA)), "ECM interno no finito")
  obj <- .objetivo_fd(7); pred <- .predictoras_fd(8)
  ids <- predictoras_grupo("G1"); o <- origenes_grupo("G1")[3]
  md <- matriz_directa(.datos_fd(obj, pred, ids, o), ids, "PRUEBA.DIRECTA")
  esp <- .esp_ridge()
  aj <- ajustar_directo(md, esp)
  com <- origenes_comunes(o)
  expect_identical(com, as.integer((o - 19L):(o - 8L)))
  for (h in 1:8) {
    ph <- aj$por_h[[h]]
    ip <- pronosticos_internos(md, h, origenes_internos(o, h), esp, ph$rejilla, seq_len(nrow(ph$rejilla)))
    ecm <- colMeans((ip$obs - ip$pred)^2)
    expect_identical(ph$eleccion, which.min(ecm))
    expect_equal(ph$e_propios, ip$obs - ip$pred[, ph$eleccion], tolerance = 0)
    # los errores del elegido en los orígenes comunes son los de estimarlo en cada uno
    ic <- pronosticos_internos(md, h, com, esp, ph$rejilla, ph$eleccion)
    expect_equal(ph$e_comunes, ic$obs - ic$pred[, 1], tolerance = 1e-12, info = h)
    # el pronóstico final usa todas las filas con t + h <= o
    g <- crecimiento_acumulado(md, h); tr <- which(md$t + h <= o)
    vt <- ventana_directa(md$X[tr, ], unname(g[tr]), md$t[tr], TRUE); an <- aplicar_ventana(vt, md$X[md$t == o, , drop = FALSE], o)
    expect_equal(ph$g_hat, esp$estimar_predecir(vt$Z, vt$gz, an$z, ph$rejilla, ph$eleccion) + an$base, tolerance = 1e-12)
  }
  expect_equal(aj$sendero, md$y_o + aj$g_hat, tolerance = 0)
  expect_identical(length(aj$sendero), 8L)
})

test_that("B3-5, B3-6: Σ = D R D con momentos sin centrar, definida positiva", {
  set.seed(9)
  K <- 12L; H <- 8L
  e_p <- lapply(seq_len(H), function(h) stats::rnorm(K, mean = 0.002 * h, sd = 0.01 * sqrt(h)))
  Ec <- matrix(stats::rnorm(K * H, sd = 0.01), K) %*% chol(0.5 + 0.5 * diag(H))
  S <- cov_errores_internos(e_p, Ec)
  expect_equal(diag(S), vapply(e_p, function(e) mean(e^2), numeric(1)), tolerance = 1e-14)   # ECM interno, sin centrar
  M <- crossprod(Ec) / K
  expect_equal(S[2, 5] / sqrt(S[2, 2] * S[5, 5]), M[2, 5] / sqrt(M[2, 2] * M[5, 5]), tolerance = 1e-12)
  expect_gt(min(eigen(S, only.values = TRUE)$values), 0)
  expect_true(isSymmetric(S))
  # con un sesgo grande la diagonal crece aunque la dispersión no cambie (B3-6)
  e_sesgo <- e_p; e_sesgo[[1]] <- e_sesgo[[1]] + 0.05
  expect_gt(cov_errores_internos(e_sesgo, Ec)[1, 1], S[1, 1] + 0.05^2 * 0.9)
  # B3-7: errores nulos o una matriz de rango incompleto se detienen
  e_cero <- e_p; e_cero[[3]] <- rep(0, K)
  expect_error(cov_errores_internos(e_cero, Ec), "errores internos nulos o no finitos")
  Ed <- Ec; Ed[, 4] <- Ed[, 3]
  expect_error(cov_errores_internos(e_p, Ed), "no es definida positiva")
})

test_that("C3: un modelo directo cumple el contrato del motor, con densidad y diagnósticos por h", {
  obj <- .objetivo_fd(13); pred <- .predictoras_fd(14)
  ids <- predictoras_grupo("G3")
  m <- modelo_directo("PRUEBA.DIRECTA.G3", ids, .esp_ridge())
  expect_silent(.validar_modelo(m))
  expect_false(m$piso_gl)
  expect_identical(m$requiere, c("objetivo", ids))                             # G3: las ocho predictoras (B1b-2)
  org <- origenes_grupo("G3")[1:3]
  r <- correr_backtest(c(list(objetivo = obj), pred[ids]), list(m), org, rezagos = rezagos_predictoras(ids), densidad = TRUE)
  expect_identical(nrow(r), 3L * 8L)
  expect_true(all(is.finite(r$sd_log_nivel)) && all(is.finite(r$sd_yoy_pp)) && all(is.finite(r$sd_qoq_pp)))
  aj <- m$ajustar(.datos_fd(obj, pred, ids, org[2]), NULL)
  expect_equal(r$log_nivel_pronosticado[r$origen == org[2]], aj$sendero, tolerance = 0)
  expect_equal(r$sd_log_nivel[r$origen == org[2]], sqrt(diag(aj$Sigma)), tolerance = 1e-12)
  d <- attr(r, "diagnosticos")
  claves <- unique(d$clave)
  expect_true(all(c("n_filas", "n_columnas", paste0("h", 1:8, ".candidato"), paste0("h", 1:8, ".ecm_interno"),
                    paste0("h", 1:8, ".n_filas_min"), paste0("h", 1:8, ".lambda"), "h8.borde") %in% claves))
  expect_identical(d$valor[d$origen == org[1] & d$clave == "h8.n_filas_min"], 9)
  expect_identical(d$valor[d$origen == org[1] & d$clave == "n_columnas"], 36)
  expect_error(m$predecir(aj, 9L), "se estimó hasta h = 8")
  # especificación incompleta
  expect_error(modelo_directo("PRUEBA.MALA", ids, list(transformar = TRUE)), "necesita candidatos\\(\\) y estimar_predecir\\(\\)")
  mal <- .esp_ridge(); mal$estimar_predecir <- function(Z, g, z, rejilla, cand) rep(NA_real_, length(cand))
  expect_error(m2 <- modelo_directo("PRUEBA.MALA", ids, mal)$ajustar(.datos_fd(obj, pred, ids, org[1]), NULL),
               "estimar_predecir\\(\\) debe devolver .* pronósticos finitos \\(B3-7\\)")
})

test_that("B3, B3b, B4: los modelos directos del registro de Fase 5 son los regularizados y los árboles (sin piso) y el U-MIDAS (con piso)", {
  for (g in c("G1", "G2", "G3")) {
    ms <- modelos_fase5(g)
    directos <- vapply(ms, function(m) !is.null(m$esp), logical(1))
    ids <- vapply(ms[directos], `[[`, character(1), "modelo_id")
    expect_identical(ids, paste0(c("REG.ENET.", "REG.PCR.", "MIX.UMIDAS.", "ML.RF.", "ML.LGBM."), g), info = g)
    expect_identical(unname(vapply(ms[directos], `[[`, logical(1), "piso_gl")), c(FALSE, FALSE, TRUE, FALSE, FALSE), info = g)
  }
})
