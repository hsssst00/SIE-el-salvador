# tests/test-modelos-frecuencia-mixta.R
#
# Frecuencia mixta de Fase 5, bloque B3b (F5-08, F5-04, F5-05, F5-12 y B3b-1 a B3b-6 de doc/metodologia/decisiones_fase5.md),
# con datos SINTÉTICOS: no se lee data/. Comprueba el registro por grupo, las utilidades mensuales (el AR mensual sin dummies
# es el AR(p)-BIC trimestral), la matriz del U-MIDAS (meses y borde), su MCO contra lm con dummies, el sendero del puente
# contra una recursión independiente, su densidad contra una simulación del sistema con la agregación exacta, el piso de
# grados de libertad en el primer origen de cada grupo con las fechas de inicio de L3 (G-8, F5-03) y las guardas.

library(testthat)
source(here::here("src", "evaluacion", "motor_backtesting.R"))   # eval_lib, modelos_referencia, modelos_fase5

.INICIOS_L3_M <- c("BCR.REMESAS.NOM.NSA.M" = "1991-M01", "BCR.EXPORT_FOB.NOM.NSA.M" = "1994-M01", "BCR.ITCER.IDX.NSA.M" = "2000-M01",
                   "UT.DEMANDA_ELEC.GWH.NSA.M" = "2002-M01", "BCR.IVAE.VOL.SA.M" = "2005-M01", "BCR.IPM.IDX.NSA.M" = "2005-M01",
                   "BCR.IPP.IDX.NSA.M" = "2009-M12", "BCR.REMESAS.REAL.NSA.M" = "2009-M12")
.ind_a_m <- function(i) sprintf("%d-M%02d", i %/% 12L, i %% 12L + 1L)
.objetivo_mx <- function(semilla) {
  set.seed(semilla)
  per <- ind_a_q(q_a_ind("1990-Q1") + 0:144)
  data.frame(periodo = per, y = 4 + cumsum(0.005 + as.numeric(stats::arima.sim(list(ar = 0.3), length(per), sd = 0.01))), stringsAsFactors = FALSE)
}
.predictoras_mx <- function(semilla, ids = names(.INICIOS_L3_M), hasta = "2026-M07") {
  set.seed(semilla)
  stats::setNames(lapply(ids, function(id) {
    i <- m_a_ind(.INICIOS_L3_M[[id]]):m_a_ind(hasta)
    est <- if (grepl(".NSA.", id, fixed = TRUE)) 0.03 * sin(2 * pi * (i %% 12L) / 12) else 0
    data.frame(periodo = .ind_a_m(i), valor = 100 * exp(cumsum(0.0015 + stats::rnorm(length(i), 0, 0.01)) + est), stringsAsFactors = FALSE)
  }), ids)
}
.datos_mx <- function(obj, pred, ids, o) {
  rz <- rezagos_predictoras(ids)
  c(list(objetivo = obj[q_a_ind(obj$periodo) <= o, , drop = FALSE]), stats::setNames(lapply(ids, function(id) recortar_a_origen(pred[[id]], o, rz[[id]])), ids))
}

test_that("F5-08, B1b-2: registro de los modelos de frecuencia mixta por grupo bajo el contrato", {
  for (g in c("G1", "G2", "G3")) {
    ids <- vapply(modelos_fase5(g), `[[`, character(1), "modelo_id")
    expect_identical(ids[startsWith(ids, "MIX.")], paste0(c("MIX.UMIDAS.", "MIX.PUENTE."), g), info = g)
    expect_true(max(which(startsWith(ids, "REG."))) < min(which(startsWith(ids, "MIX."))), info = g)       # orden de F5-01
    for (m in modelos_frecuencia_mixta_grupo(g)) {
      expect_silent(.validar_modelo(m))
      expect_true(m$piso_gl, info = m$modelo_id)                                     # F5-03: sin penalización
      expect_identical(m$requiere, c("objetivo", predictoras_no_penalizadas(g, "M")), info = m$modelo_id)
      expect_true(is.function(m$predecir_densidad) && is.function(m$diagnosticar), info = m$modelo_id)
    }
  }
  expect_false("BCR.REMESAS.REAL.NSA.M" %in% modelo_puente_grupo("G3")$requiere)       # B1b-2
  expect_identical(LAGS_UMIDAS, list(G1 = 0:5, G2 = integer(0), G3 = integer(0)))
  expect_identical(P_MAX_AR_MENSUAL, 12L)
})

test_that("B3b-4: utilidades mensuales; sin dummies el AR mensual es el AR(p)-BIC de seleccionar_ar_bic_x()", {
  expect_identical(ultimo_mes_trimestre(q_a_ind("2014-Q4")), m_a_ind("2014-M12"))
  expect_identical(ultimo_mes_trimestre(q_a_ind("2005-Q1")), m_a_ind("2005-M03"))
  D <- dummies_mensuales(m_a_ind("2010-M01") + 0:23)
  expect_identical(dim(D), c(24L, 11L)); expect_identical(rowSums(D), rep(c(0, rep(1, 11)), 2))
  set.seed(1)
  x <- stats::setNames(as.numeric(stats::arima.sim(list(ar = 0.5), 150, sd = 0.01)), 1000L + 0:149)
  a <- seleccionar_ar_bic_m(x, dummies = FALSE, p_max = 4L); b <- seleccionar_ar_bic_x(x, dummies = FALSE, p_max = 4L)
  expect_identical(a$p, b$p); expect_equal(a$phi, b$phi, tolerance = 1e-12); expect_equal(a$c0, b$c0, tolerance = 1e-12)
  pr <- .proyectar_ar_m(a, 1000L + 155L)
  expect_identical(names(pr), as.character(1000L + 150:155))
  v <- utils::tail(unname(x), a$p); for (j in 1:6) { nv <- a$c0 + sum(a$phi * rev(utils::tail(v, a$p))); v <- c(v, nv) }
  expect_equal(unname(pr), utils::tail(v, 6), tolerance = 1e-12)
  # el Δlog trimestral de la suma de los 3 meses es el del promedio (B3b-4: la regla de T00x no lo cambia)
  l <- stats::setNames(log(100) + cumsum(stats::rnorm(24, 0, 0.01)), m_a_ind("2010-M01") + 0:23)
  qs <- q_a_ind("2010-Q1") + 0:7
  dq <- .dlog_trimestral_de_meses(l, qs)
  prom <- vapply(qs, function(q) log(mean(exp(l[as.character(ultimo_mes_trimestre(q) - 2:0)]))), numeric(1))
  expect_equal(unname(dq[-1]), diff(prom), tolerance = 1e-12)
})

test_that("B3b-1: la matriz del U-MIDAS toma los meses del borde y, en G1, los rezagos 0..5", {
  obj <- .objetivo_mx(2); pred <- .predictoras_mx(3)
  for (g in c("G1", "G2", "G3")) {
    o <- origenes_grupo(g)[1]; ids <- predictoras_no_penalizadas(g, "M")
    md <- matriz_umidas(.datos_mx(obj, pred, ids, o), ids, "PRUEBA", LAGS_UMIDAS[[g]])
    d_esp <- vapply(ids, function(id) rezago_alineacion(id, g)$desfase, integer(1))
    expect_identical(md$desfases, d_esp, info = g)                                     # el borde de F5-04
    expect_identical(ncol(md$X), if (g == "G1") as.integer(sum(d_esp + 6L)) else length(ids), info = g)
    expect_identical(md$t[length(md$t)], o, info = g)
    # una celda: la predictora 1 en el mes m(t) + d de una fila
    t0 <- md$t[5]; id <- ids[1]; mm <- ultimo_mes_trimestre(t0) + d_esp[[1]]
    pv <- pred[[id]]; v <- log(pv$valor[m_a_ind(pv$periodo) == mm]) - log(pv$valor[m_a_ind(pv$periodo) == mm - 1L])
    expect_equal(unname(md$X[5, sprintf("%s__m%+d", id, d_esp[[1]])]), v, tolerance = 1e-14, info = g)
  }
  expect_identical(colnames(matriz_umidas(.datos_mx(obj, pred, predictoras_no_penalizadas("G1", "M"), origenes_grupo("G1")[1]),
                                          predictoras_no_penalizadas("G1", "M"), "PRUEBA", 0:5)$X)[1:8],
                   sprintf("BCR.REMESAS.NOM.NSA.M__m%+d", c(2, 1, 0, -1, -2, -3, -4, -5)))
})

test_that("F5-05, B3-2: el U-MIDAS es el MCO directo con constante y dummies trimestrales", {
  obj <- .objetivo_mx(4); pred <- .predictoras_mx(5)
  g <- "G2"; o <- origenes_grupo(g)[6]; ids <- predictoras_no_penalizadas(g, "M")
  m <- modelo_umidas_grupo(g)
  aj <- m$ajustar(.datos_mx(obj, pred, ids, o), NULL)
  md <- matriz_umidas(.datos_mx(obj, pred, ids, o), ids, "PRUEBA", integer(0))
  for (h in c(1L, 4L, 8L)) {
    g_h <- crecimiento_acumulado(md, h); tr <- which(md$t + h <= o)
    W <- cbind(1, dummies_trimestrales(md$t[tr]), md$X[tr, ])
    b <- stats::lm.fit(W, unname(g_h[tr]))$coefficients
    nw <- which(md$t == o)
    expect_equal(aj$g_hat[h], sum(c(1, dummies_trimestrales(o), md$X[nw, ]) * b), tolerance = 1e-10, info = h)
  }
  expect_equal(aj$sendero, md$y_o + aj$g_hat, tolerance = 0)
})

test_that("F5-08: el sendero del puente es la recursión del MCO sobre los agregados con los meses proyectados", {
  obj <- .objetivo_mx(6); pred <- .predictoras_mx(7)
  g <- "G1"; o <- origenes_grupo(g)[10]; ids <- predictoras_no_penalizadas(g, "M")
  aj <- modelo_puente_grupo(g)$ajustar(.datos_mx(obj, pred, ids, o), NULL)
  # agregados futuros: meses observados del borde + AR mensual; recursión propia
  d <- .datos_mx(obj, pred, ids, o)
  fut <- vapply(ids, function(id) {
    l <- stats::setNames(log(d[[id]]$valor), m_a_ind(d[[id]]$periodo))
    pr <- .proyectar_ar_m(aj$ars[[id]], ultimo_mes_trimestre(o + 8L)); lc <- c(l, stats::setNames(l[length(l)] + cumsum(pr), names(pr)))
    unname(.dlog_trimestral_de_meses(lc, o + 0:8)[-1])
  }, numeric(8))
  expect_equal(unname(aj$dX_fut), unname(fut), tolerance = 1e-12)
  dy <- diff(obj$y[q_a_ind(obj$periodo) <= o]); prev <- utils::tail(dy, 1); s <- numeric(8)
  D <- dummies_trimestrales(o + 1:8)
  for (j in 1:8) { prev <- aj$c0 + sum(aj$beta * fut[j, ]) + aj$phi * prev + sum(D[j, ] * aj$delta); s[j] <- prev }
  expect_equal(sendero_puente(aj, 8L), aj$y_o + cumsum(s), tolerance = 1e-12)
  # el borde entra: en G1 las dos predictoras traen 2 meses de o+1
  expect_identical(unname(aj$ult - ultimo_mes_trimestre(o)), c(2L, 2L))
})

test_that("F5-12, B3b-5, B3b-6: la densidad del puente coincide con una simulación del sistema con la agregación exacta", {
  obj <- .objetivo_mx(8); pred <- .predictoras_mx(9)
  g <- "G2"; o <- origenes_grupo(g)[8]; ids <- predictoras_no_penalizadas(g, "M")
  d <- .datos_mx(obj, pred, ids, o)
  aj <- modelo_puente_grupo(g)$ajustar(d, NULL)
  S <- cov_sistema_puente(aj, 8L)
  expect_true(isSymmetric(S)); expect_gt(min(eigen(S, only.values = TRUE)$values), 0)
  set.seed(10)
  k <- length(ids); N <- 3000L; D <- dummies_trimestrales(o + 1:8); m_fin <- ultimo_mes_trimestre(o + 8L)
  cv <- as.vector(t(aj$Ceu))                                          # B3b-6: e_{o+j} con los meses de o+j
  Lq <- chol(rbind(c(aj$s2, cv), cbind(cv, kronecker(diag(3), aj$Su))))
  expect_gt(max(abs(cv)), 0)
  sims <- replicate(N, {
    Wq <- matrix(stats::rnorm(8 * (1 + 3 * k)), 8) %*% Lq              # un bloque conjunto por trimestre
    U <- matrix(0, m_fin - ultimo_mes_trimestre(o), k)                 # fila r − m(o): mes r
    for (j in 1:8) for (pp in 1:3) U[ultimo_mes_trimestre(o + j) - (3L - pp) - ultimo_mes_trimestre(o), ] <- Wq[j, 1 + (pp - 1) * k + seq_len(k)]
    fut <- vapply(seq_along(ids), function(i) {
      s <- aj$ars[[i]]; l <- stats::setNames(log(d[[ids[i]]]$valor), m_a_ind(d[[ids[i]]]$periodo))
      x <- unname(s$x); i_ult <- aj$ult[[i]]; n <- m_fin - i_ult; out <- numeric(n)
      Dm <- if (s$dummies) dummies_mensuales(i_ult + seq_len(n)) else NULL
      for (j in seq_len(n)) {
        v <- s$c0 + (if (!is.null(Dm)) sum(Dm[j, ] * s$gamma) else 0) + (if (s$p > 0L) sum(s$phi * rev(utils::tail(x, s$p))) else 0) + U[i_ult + j - ultimo_mes_trimestre(o), i]
        x <- c(x, v); out[j] <- v
      }
      lc <- c(l, stats::setNames(l[length(l)] + cumsum(out), i_ult + seq_len(n)))
      unname(.dlog_trimestral_de_meses(lc, o + 0:8)[-1])
    }, numeric(8))
    e <- Wq[, 1]; prev <- aj$dy_o; s <- numeric(8)
    for (j in 1:8) { prev <- aj$c0 + sum(aj$beta * fut[j, ]) + aj$phi * prev + sum(D[j, ] * aj$delta) + e[j]; s[j] <- prev }
    aj$y_o + cumsum(s)
  })
  sd_sim <- apply(sims, 1, stats::sd); sd_an <- sqrt(diag(S))
  expect_true(all(abs(sd_sim / sd_an - 1) < 0.06), info = paste(round(sd_sim / sd_an, 3), collapse = "/"))   # MC (≈ 1,3 %) + linealización
  cs <- stats::cor(t(sims))[1, 8]; ca <- S[1, 8] / sqrt(S[1, 1] * S[8, 8])
  expect_lt(abs(cs - ca), 0.05)
  expect_lt(max(abs(rowMeans(sims) - sendero_puente(aj, 8L)) / sd_an), 0.1)                 # sesgo de la linealización
})

test_that("C1, F5-03: G-8 pasa en el primer origen de cada grupo con las fechas de inicio de L3 y el piso acota los meses del U-MIDAS", {
  obj <- .objetivo_mx(11); pred <- .predictoras_mx(12)
  libres <- list(G1 = c(MIX.UMIDAS.G1 = 47L, MIX.PUENTE.G1 = 69L), G2 = c(MIX.UMIDAS.G2 = 22L, MIX.PUENTE.G2 = 28L),
                 G3 = c(MIX.UMIDAS.G3 = 22L, MIX.PUENTE.G3 = 27L))
  for (g in names(libres)) {
    o1 <- origenes_grupo(g)[1]; ids <- predictoras_no_penalizadas(g, "M")
    r <- correr_backtest(c(list(objetivo = obj), pred[ids]), modelos_frecuencia_mixta_grupo(g), o1, rezagos = rezagos_predictoras(ids), densidad = TRUE)
    expect_true(all(is.finite(r$sd_log_nivel)) && all(r$sd_log_nivel > 0), info = g)
    for (m in modelos_frecuencia_mixta_grupo(g)) {
      gl <- m$ajustar(.datos_mx(obj, pred, ids, o1), NULL)$gl
      expect_identical(unname(gl[["n_obs"]] - gl[["n_par"]]), libres[[g]][[m$modelo_id]], info = m$modelo_id)
    }
  }
  # con un mes más por predictora (m(t) + d y m(t)), el U-MIDAS de G2 baja del piso en el primer origen
  ids <- predictoras_no_penalizadas("G2", "M")
  ancho <- modelo_directo("MIX.UMIDAS.G2", ids, especificacion_umidas(), construir = function(datos) matriz_umidas(datos, ids, "MIX.UMIDAS.G2", 0L))
  expect_error(correr_backtest(c(list(objetivo = obj), pred[ids]), list(ancho), origenes_grupo("G2")[1], rezagos = rezagos_predictoras(ids)),
               "^G-8 modelo MIX.UMIDAS.G2 en 2014-Q4")
})

test_that("B3b-2: guardas del borde, del rango y del número de condición", {
  obj <- .objetivo_mx(13); pred <- .predictoras_mx(14)
  g <- "G1"; o <- origenes_grupo(g)[1]; ids <- predictoras_no_penalizadas(g, "M")
  d <- .datos_mx(obj, pred, ids, o)
  corta <- d; corta[[ids[2]]] <- corta[[ids[2]]][m_a_ind(corta[[ids[2]]]$periodo) <= ultimo_mes_trimestre(o) - 1L, ]
  expect_error(modelo_puente_grupo(g)$ajustar(corta, NULL), "no llegan al último mes del origen")
  expect_error(matriz_umidas(corta, ids, "PRUEBA", 0:5), "no llegan al último mes del origen")
  # dos predictoras casi idénticas disparan el número de condición
  dup <- d; dup[[ids[2]]] <- d[[ids[1]]]; dup[[ids[2]]]$valor <- dup[[ids[2]]]$valor * exp(stats::rnorm(nrow(dup[[ids[2]]]), 0, 1e-7))
  expect_error(modelo_puente_grupo(g)$ajustar(dup, NULL), "número de condición")
  expect_error(modelo_umidas_grupo(g)$ajustar(dup, NULL), "número de condición")
})
