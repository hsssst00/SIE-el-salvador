# tests/test-modelos-multivariados.R
#
# Modelos multivariados de Fase 5, bloque B2a (F5-07, F5-12 y B2-1 a B2-8 de doc/metodologia/decisiones_fase5.md),
# con datos SINTÉTICOS: no se lee data/. Comprueba el registro por grupo, el sendero contra una implementación
# independiente (MCO con dummies de calendario y recursión propia), la densidad contra predict() de vars y contra
# una simulación de las recursiones del VAR, la elección del rango de Johansen y sus casos límite (B2-4), el piso de
# grados de libertad en el primer origen de cada grupo con las fechas de inicio reales de L3 (checklist C1), las
# guardas y, de punta a punta, la deduplicación de pérdidas idénticas en el MCS (B2-9).

library(testthat)
source(here::here("src", "evaluacion", "motor_backtesting.R"))   # eval_lib, modelos_referencia, modelos_fase5

.INICIOS_L3_MV <- c("BCR.REMESAS.NOM.NSA.Q" = "1991-Q1", "BCR.EXPORT_FOB.NOM.NSA.Q" = "1994-Q1", "BCR.IVAE.VOL.SA.Q" = "2005-Q1")

.objetivo_mv <- function(semilla, phi = 0.3, sd = 0.01) {
  set.seed(semilla)
  per <- ind_a_q(q_a_ind("1990-Q1") + 0:144)
  dy <- 0.005 + as.numeric(stats::arima.sim(list(ar = phi), length(per), sd = sd))
  data.frame(periodo = per, y = 4 + cumsum(dy), stringsAsFactors = FALSE)
}
.predictoras_mv <- function(semilla, ids = names(.INICIOS_L3_MV), hasta = "2026-Q2") {
  set.seed(semilla)
  stats::setNames(lapply(ids, function(id) {
    i <- q_a_ind(.INICIOS_L3_MV[[id]]):q_a_ind(hasta)
    est <- if (grepl(".NSA.", id, fixed = TRUE)) 0.03 * sin(pi * (i %% 4L) / 2) else 0
    data.frame(periodo = ind_a_q(i), valor = 100 * exp(cumsum(0.004 + stats::rnorm(length(i), 0, 0.02)) + est), stringsAsFactors = FALSE)
  }), ids)
}
.hasta_mv <- function(d, o) d[q_a_ind(d$periodo) <= o, , drop = FALSE]
.datos_mv <- function(obj, pred, ids, o) c(list(objetivo = .hasta_mv(obj, o)), lapply(pred[ids], .hasta_mv, o = o))

#' Panel sintético de k series con un patrón estacional en las NSA, desde un objetivo y predictoras dadas.
.panel_desde <- function(Y, ini, nsa = c(FALSE, TRUE, TRUE)) {
  per <- ind_a_q(q_a_ind(ini) + seq_len(nrow(Y)) - 1L)
  ids <- c("BCR.REMESAS.NOM.NSA.Q", "BCR.EXPORT_FOB.NOM.NSA.Q")
  c(list(objetivo = data.frame(periodo = per, y = Y[, 1], stringsAsFactors = FALSE)),
    stats::setNames(lapply(2:3, function(j) data.frame(periodo = per, valor = exp(Y[, j]), stringsAsFactors = FALSE)), ids))
}

test_that("F5-07, B2-2, B2-6: registro de los multivariados por grupo bajo el contrato", {
  esperados <- list(G1 = c("MULT.VAR_DIF.G1", "MULT.VAR_NIV.G1", "MULT.VECM.G1"), G2 = "MULT.VAR_DIF.G2", G3 = "MULT.VAR_DIF.G3")
  for (g in names(esperados)) {
    ids <- vapply(modelos_fase5(g), `[[`, character(1), "modelo_id")
    expect_identical(ids[startsWith(ids, "MULT.")], esperados[[g]], info = g)
    for (m in modelos_multivariados_grupo(g)) {
      expect_silent(.validar_modelo(m))
      expect_true(isTRUE(m$piso_gl), info = m$modelo_id)
      expect_true(is.function(m$predecir_densidad) && is.function(m$diagnosticar), info = m$modelo_id)
      expect_identical(m$requiere, c("objetivo", SERIES_VAR[[g]]), info = m$modelo_id)
      expect_true(all(SERIES_VAR[[g]] %in% predictoras_no_penalizadas(g)), info = m$modelo_id)   # B1b-2
    }
  }
  expect_identical(SERIES_VAR$G3, SERIES_VAR$G2)                                       # B2-6
  expect_false("BCR.REMESAS.REAL.NSA.Q" %in% SERIES_VAR$G3)
  expect_identical(unname(vapply(c("G1", "G2", "G3"), function(g) modelos_multivariados_grupo(g)[[1]]$p_max, integer(1))), c(4L, 3L, 3L))
  expect_identical(modelos_multivariados_grupo("G1")[[2]]$forma, "niv")
  expect_error(modelos_multivariados_grupo("G4"), "grupo no declarado")
})

test_that("pesos_ma_var coincide con vars::Phi y raiz_max_var con vars::roots", {
  set.seed(31); Y <- apply(matrix(stats::rnorm(300, 0, 0.01), 100), 2, cumsum); colnames(Y) <- c("a", "b", "c")
  fit <- vars::VAR(diff(Y), p = 2, type = "const")
  Ph <- vars::Phi(fit, nstep = 5)
  expect_equal(pesos_ma_var(vars::Acoef(fit), 6L), unname(Ph), tolerance = 1e-12, ignore_attr = TRUE)
  expect_equal(raiz_max_var(vars::Acoef(fit)), max(vars::roots(fit)), tolerance = 1e-10)
  # en h = 1 la covarianza es Σ_11; con Φ = I en todos los pasos (paseo) y acumulación, la de un paseo aleatorio
  S <- diag(3) * 0.5
  Phi_rw <- array(0, c(3, 3, 4)); Phi_rw[, , 1] <- diag(3)
  expect_equal(cov_sendero_var(Phi_rw, S, acumular = TRUE), 0.5 * outer(1:4, 1:4, pmin))
  expect_equal(cov_sendero_var(Phi_rw[, , 1, drop = FALSE], S, acumular = FALSE), matrix(0.5))
})

test_that("VAR_DIF y VAR_NIV: el sendero coincide con MCO + dummies de calendario y recursión propia (B2-1)", {
  obj <- .objetivo_mv(41); pred <- .predictoras_mv(42)
  o <- q_a_ind("2016-Q4"); ids <- SERIES_VAR$G1
  for (forma in c("dif", "niv")) {
    m <- modelo_var(paste0("PRUEBA.VAR_", forma), ids, 4L, forma)
    aj <- m$ajustar(.datos_mv(obj, pred, ids, o), NULL)
    pn <- panel_var(.datos_mv(obj, pred, ids, o), ids, "PRUEBA")
    Z <- if (forma == "dif") diff(pn$Y) else pn$Y
    tz <- if (forma == "dif") pn$t[-1] else pn$t
    p <- aj$p; n <- nrow(Z); K <- ncol(Z); filas <- (p + 1L):n
    X <- cbind(1, dummies_trimestrales(tz[filas]), do.call(cbind, lapply(seq_len(p), function(l) Z[filas - l, , drop = FALSE])))
    B <- qr.solve(X, Z[filas, , drop = FALSE])                       # (1 + 3 + K p) x K
    Zf <- Z; tf <- tz
    for (j in 1:8) {
      t_new <- utils::tail(tf, 1) + 1L
      x <- c(1, dummies_trimestrales(t_new), unlist(lapply(seq_len(p), function(l) Zf[nrow(Zf) - l + 1L, ])))
      Zf <- rbind(Zf, drop(x %*% B)); tf <- c(tf, t_new)
    }
    f <- Zf[n + 1:8, 1]
    esperado <- if (forma == "dif") aj$y_o + cumsum(f) else f
    expect_equal(m$predecir(aj, 8L), unname(esperado), tolerance = 1e-8, info = forma)
    expect_identical(aj$gl[["n_par"]], K * 4L + 1L + 3L)
    expect_identical(aj$gl[["n_obs"]], n - 4L)
    expect_identical(names(m$diagnosticar(aj)), c("p", "n_obs", "raiz_max"))
  }
})

test_that("VAR: la densidad reproduce predict() en niveles y la simulación de las recursiones en diferencias (F5-12)", {
  obj <- .objetivo_mv(43); pred <- .predictoras_mv(44)
  o <- q_a_ind("2018-Q2"); ids <- SERIES_VAR$G1; h <- 6L
  niv <- modelo_var("PRUEBA.NIV", ids, 4L, "niv")
  aj <- niv$ajustar(.datos_mv(obj, pred, ids, o), NULL)
  d <- niv$predecir_densidad(aj, h)
  expect_silent(validar_densidad(d, niv$predecir(aj, h)))
  pr <- stats::predict(aj$fit, n.ahead = h)$fcst[[1]]
  expect_equal(diag(d$cov), unname(((pr[, "upper"] - pr[, "fcst"]) / stats::qnorm(0.975))^2), tolerance = 1e-10)
  dif <- modelo_var("PRUEBA.DIF", ids, 4L, "dif")
  aj <- dif$ajustar(.datos_mv(obj, pred, ids, o), NULL)
  S <- dif$predecir_densidad(aj, h)$cov
  expect_silent(validar_densidad(list(media = dif$predecir(aj, h), cov = S), dif$predecir(aj, h)))
  pr <- stats::predict(aj$fit, n.ahead = 1L)$fcst[[1]]
  expect_equal(S[1, 1], unname(((pr[1, "upper"] - pr[1, "fcst"]) / stats::qnorm(0.975))^2), tolerance = 1e-10)
  # Simulación independiente de Φ: recursión del VAR con innovaciones u ~ N(0, Σ_u); el error del log-nivel del PIB
  # es la suma de los errores de Δy (el pasado y los determinísticos son comunes y se cancelan).
  A <- aj$A; K <- nrow(A[[1]]); p <- length(A); R <- 40000L
  set.seed(45); U <- matrix(stats::rnorm(R * h * K), ncol = K) %*% chol(aj$Sigma)
  E <- t(vapply(seq_len(R), function(r) {
    u <- U[(r - 1L) * h + seq_len(h), , drop = FALSE]; e <- matrix(0, h + p, K)
    for (s in seq_len(h)) { v <- u[s, ]; for (i in seq_len(p)) v <- v + drop(A[[i]] %*% e[p + s - i, ]); e[p + s, ] <- v }
    cumsum(e[p + seq_len(h), 1])
  }, numeric(h)))
  Se <- crossprod(E) / R
  expect_lt(max(abs(diag(Se) / diag(S) - 1)), 0.04)
  expect_lt(max(abs(stats::cov2cor(Se) - stats::cov2cor(S))), 0.03)
})

test_that("VECM: rango de Johansen y casos límite r = 0, 0 < r < k, r = k (B2-3, B2-4)", {
  set.seed(51); n <- 90L
  tr <- cumsum(stats::rnorm(n, 0.004, 0.01))
  s <- c(0.03, -0.02, 0.01, -0.02)[(0:(n - 1L)) %% 4L + 1L]
  # una tendencia común: r = 2 relaciones de cointegración entre 3 series
  Yc <- cbind(4 + tr, 5 + tr + stats::rnorm(n, 0, 0.01) + s, 6 + tr + stats::rnorm(n, 0, 0.01) - s)
  # tres paseos independientes: r = 0
  Yr <- cbind(4 + tr, 5 + cumsum(stats::rnorm(n, 0.003, 0.01)) + s, 6 + cumsum(stats::rnorm(n, 0.002, 0.01)) - s)
  # tres series estacionarias en nivel: r = 3
  Ys <- cbind(4 + stats::arima.sim(list(ar = 0.3), n, sd = 0.01), 5 + stats::rnorm(n, 0, 0.01) + s, 6 + stats::rnorm(n, 0, 0.01) - s)
  m <- modelo_vecm("PRUEBA.VECM", SERIES_VAR$G1)
  casos <- list(vecm = Yc, dif = Yr, niv = Ys)
  for (cs in names(casos)) {
    dat <- .panel_desde(casos[[cs]], "1994-Q1")
    aj <- m$ajustar(dat, NULL)
    expect_identical(aj$forma, cs, info = cs)
    cj <- urca::ca.jo(panel_var(dat, SERIES_VAR$G1, "P")$Y, type = "trace", ecdet = "none", K = aj$K, spec = "transitory", season = 4L)
    expect_identical(aj$r, rango_johansen(cj), info = cs)
    sendero <- m$predecir(aj, 8L); d <- m$predecir_densidad(aj, 8L)
    expect_silent(validar_densidad(d, sendero))
    dg <- m$diagnosticar(aj)
    expect_identical(names(dg), c("K", "r", "forma", "n_obs", "raiz_max", "traza_r0", "traza_r1", "traza_r2"))
    expect_identical(unname(dg[["forma"]]), unname(FORMAS_VECM[[cs]]))
    if (cs == "vecm") {
      expect_true(aj$r %in% 1:2)
      pr <- stats::predict(aj$fit, n.ahead = 8L)$fcst[[1]]
      expect_equal(sendero, unname(pr[, "fcst"]), tolerance = 1e-10)
      expect_equal(diag(d$cov), unname(((pr[, "upper"] - pr[, "fcst"]) / stats::qnorm(0.975))^2), tolerance = 1e-10)
      expect_equal(aj$Sigma, crossprod(stats::resid(aj$fit)) / aj$fit$obs)
    }
    if (cs == "dif") {                                       # el VECM anidado: VAR en Δ con K − 1 rezagos
      expect_identical(aj$r, 0L); expect_identical(aj$fit$p, aj$K - 1L)
      v <- vars::VAR(diff(panel_var(dat, SERIES_VAR$G1, "P")$Y), p = aj$K - 1L, type = "const", season = 4L)
      expect_equal(sendero, aj$y_o + cumsum(unname(stats::predict(v, n.ahead = 8L)$fcst[[1]][, "fcst"])), tolerance = 1e-10)
    }
    if (cs == "niv") { expect_identical(aj$r, 3L); expect_identical(aj$fit$p, aj$K) }
  }
  # la regla de la traza: sin rechazos r = 0; rechazo solo de r = 0, r = 1; todos, r = k
  falso <- methods::new(methods::getClass("ca.jo", where = asNamespace("urca")))
  falso@cval <- matrix(c(8, 18, 31), 3, 1, dimnames = list(c("r <= 2 |", "r <= 1 |", "r = 0  |"), "5pct"))
  falso@teststat <- c(1, 5, 20); expect_identical(rango_johansen(falso), 0L)
  falso@teststat <- c(1, 5, 40); expect_identical(rango_johansen(falso), 1L)
  falso@teststat <- c(1, 25, 40); expect_identical(rango_johansen(falso), 2L)
  falso@teststat <- c(9, 25, 40); expect_identical(rango_johansen(falso), 3L)
  falso@teststat <- c(9, 5, 40); expect_identical(rango_johansen(falso), 1L)                 # secuencial: se detiene en r <= 1
})

test_that("C1, F5-03, B2-2: G-8 pasa en el primer origen de cada grupo con las fechas de inicio de L3", {
  obj <- .objetivo_mv(61); pred <- .predictoras_mv(62)
  rez <- rezagos_predictoras(names(pred))
  libres <- c(MULT.VAR_DIF.G1 = 56L, MULT.VAR_NIV.G1 = 57L, MULT.VECM.G1 = 57L, MULT.VAR_DIF.G2 = 23L, MULT.VAR_DIF.G3 = 43L)
  for (g in c("G1", "G2", "G3")) {
    o1 <- origenes_grupo(g)[1]; ms <- modelos_multivariados_grupo(g); ids <- SERIES_VAR[[g]]
    r <- correr_backtest(c(list(objetivo = obj), pred[ids]), ms, o1, rezagos = rez[ids], densidad = TRUE)
    expect_true(all(is.finite(r$sd_log_nivel)), info = g)
    expect_false(is.null(attr(r, "diagnosticos")), info = g)
    for (m in ms) {
      gl <- m$ajustar(.datos_mv(obj, pred, ids, o1), NULL)$gl
      expect_identical(unname(gl[["n_obs"]] - gl[["n_par"]]), libres[[m$modelo_id]], info = m$modelo_id)
    }
  }
  # con p = 4 el VAR de G2 queda bajo el piso en su primer origen (B2-2)
  ancho <- modelo_var("MULT.VAR_DIF.G2", SERIES_VAR$G2, 4L, "dif")
  expect_error(correr_backtest(c(list(objetivo = obj), pred[SERIES_VAR$G2]), list(ancho), origenes_grupo("G2")[1], rezagos = rez[SERIES_VAR$G2]),
               "^G-8 modelo MULT.VAR_DIF.G2 en 2014-Q4: 35 observaciones efectivas y 16 parámetros dejan 19 grados de libertad")
})

test_that("B2-6: MULT.VAR_DIF.G3 reproduce a MULT.VAR_DIF.G2 en un origen común", {
  obj <- .objetivo_mv(71); pred <- .predictoras_mv(72)
  o <- origenes_grupo("G3")[1]
  m2 <- modelos_multivariados_grupo("G2")[[1]]; m3 <- modelos_multivariados_grupo("G3")[[1]]
  d <- .datos_mv(obj, pred, SERIES_VAR$G2, o)
  expect_identical(m3$predecir(m3$ajustar(d, NULL), 8L), m2$predecir(m2$ajustar(d, NULL), 8L))
})

test_that("guardas de los multivariados: predictora que no llega al origen, valores no positivos, huecos", {
  obj <- .objetivo_mv(81); pred <- .predictoras_mv(82)
  o <- q_a_ind("2016-Q4"); ids <- SERIES_VAR$G1
  m <- modelos_multivariados_grupo("G1")[[1]]
  corto <- c(list(objetivo = .hasta_mv(obj, o)), lapply(pred[ids], .hasta_mv, o = o - 1L))
  expect_error(m$ajustar(corto, NULL), "no llega al origen 2016-Q4")
  neg <- .datos_mv(obj, pred, ids, o); neg[[2]]$valor[5] <- 0
  expect_error(m$ajustar(neg, NULL), "no positivos")
  hueco <- .datos_mv(obj, pred, ids, o); hueco[[3]] <- hueco[[3]][-10, ]
  expect_error(m$ajustar(hueco, NULL), "faltantes o desordenados")
  expect_error(modelo_vecm("MULT.VECM.G1", ids)$ajustar(corto, NULL), "no llega al origen")
})

test_that("B2-9: en un experimento de Fase 5 un modelo duplicado comparte el MCS de su representante; fuera de Fase 5 detiene", {
  # El objetivo sintético de V12 y de test-modelos-univariados.R.
  set.seed(20260924L + 12L)
  per <- ind_a_q(q_a_ind("1990-Q1") + 0:144)
  dy <- numeric(length(per)); e <- stats::rnorm(length(per), 0, 0.008)
  for (t_ in 2:length(per)) dy[t_] <- 0.003 + 0.5 * dy[t_ - 1] + e[t_]
  y <- 4.6 + cumsum(dy)
  i20 <- match(c("2020-Q2", "2020-Q3"), per); y[i20] <- y[i20] + c(-0.20, -0.08)
  obj <- data.frame(periodo = per, y = y, vintage_id = "SINT.v1", stringsAsFactors = FALSE)
  pred <- .predictoras_mv(91, ids = predictoras_grupo("G1"))
  ex <- EXPERIMENTOS_PRINCIPALES_FASE5[EXPERIMENTOS_PRINCIPALES_FASE5$exp_id == "F5_G1", ]
  ex$sa <- "l3_unico"; ex$r3 <- FALSE; ex$r4 <- TRUE
  insumos <- list(objetivos = list(PIB_SA_PROPIO_Q = obj), predictoras = pred, conjunto = list(etiqueta = "corte_sint@0123abcd"))
  copia <- modelo_ar1(); copia$modelo_id <- "PRUEBA.AR1_COPIA"                      # pronostica lo mismo que BENCH.AR1
  orig <- modelos_fase5
  assign("modelos_fase5", function(grupo) list(copia), envir = globalenv())
  on.exit(assign("modelos_fase5", orig, envir = globalenv()), add = TRUE)
  r <- correr_experimento(ex, insumos, new.env())
  for (tab in list(r$mcs, r$sub$mcs)) {
    expect_true("identico_a" %in% names(tab))
    expect_true(all(tab$identico_a[tab$modelo_id == "PRUEBA.AR1_COPIA"] == "BENCH.AR1"))
    expect_true(all(tab$identico_a[tab$modelo_id != "PRUEBA.AR1_COPIA"] == ""))
    a <- tab[tab$modelo_id == "BENCH.AR1", ]; b <- tab[tab$modelo_id == "PRUEBA.AR1_COPIA", ]
    expect_identical(b$p_mcs, a$p_mcs); expect_identical(b$en_mcs, a$en_mcs); expect_identical(b$orden_eliminacion, a$orden_eliminacion)
  }
  # el MCS de los demás modelos es el de una corrida sin la copia
  assign("modelos_fase5", function(grupo) list(), envir = globalenv())
  r0 <- correr_experimento(ex, insumos, new.env())
  k <- r$mcs$modelo_id != "PRUEBA.AR1_COPIA"
  expect_identical(r$mcs$p_mcs[k], r0$mcs$p_mcs); expect_identical(r$mcs$en_mcs[k], r0$mcs$en_mcs)
  expect_identical(r0$mcs$identico_a, rep("", nrow(r0$mcs)))
  # fuera de Fase 5 (Fase 4 y F5_REPRO_*) el MCS es mcs_tmax() tal cual: misma tabla, sin columna nueva, y con
  # los idénticos al final de la eliminación sigue deteniéndose (Regla 7)
  err <- calcular_errores(correr_backtest(list(objetivo = obj), list(modelo_rw_sin_deriva(), modelo_ar1(), copia), origenes_grupo("G1")), obj)
  ids <- c("BENCH.RW_SIN_DERIVA", "BENCH.AR1", "PRUEBA.AR1_COPIA")
  sin_dedup <- tryCatch(evaluar_errores(err, ids, "F5_REPRO_G1", "G1", "yoy_pp", semilla_mcs = function(h) h, B = 200L), error = function(e) e)
  if (inherits(sin_dedup, "error")) expect_match(conditionMessage(sin_dedup), "varianza bootstrap nula") else expect_false("identico_a" %in% names(sin_dedup$mcs))
  con_dedup <- evaluar_errores(err, ids, "F5_G1", "G1", "yoy_pp", semilla_mcs = function(h) h, B = 200L, marcar_identicos = TRUE)
  expect_true(all(con_dedup$mcs$identico_a[con_dedup$mcs$modelo_id == "PRUEBA.AR1_COPIA"] == "BENCH.AR1"))
  sin <- evaluar_errores(err[err$modelo_id != "PRUEBA.AR1_COPIA", ], ids[1:2], "F5_REPRO_G1", "G1", "yoy_pp", semilla_mcs = function(h) h, B = 200L)
  expect_identical(names(sin$mcs), c("exp_id", "grupo", "h", "unidad", "modelo_id", "p_mcs", "en_mcs", "orden_eliminacion", "alpha",
                                     "replicas", "bloque", "semilla", "marca_tamano"))
})
