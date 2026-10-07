# tests/test-modelo-bvar.R
#
# BVAR de Fase 5, bloque B2b (F5-07, F5-12 y B2-5, B2-7, B2-10 a B2-16 de doc/metodologia/decisiones_fase5.md),
# con datos SINTÉTICOS: no se lee data/. Comprueba el registro por grupo, el ajuste estacional de las NSA, ψ por MCO,
# los momentos de la predictiva contra dos oráculos independientes (la recursión y los pesos MA de cada extracción
# con el código del paquete y de B2a, y una simulación de senderos con choques propagados), la reproducibilidad bit
# a bit con la semilla del motor, el primer origen de cada grupo con las fechas de inicio reales de L3 y la
# configuración de producción (sin G-8), y las guardas.

library(testthat)
source(here::here("src", "evaluacion", "motor_backtesting.R"))   # eval_lib, modelos_referencia, modelos_fase5

.INICIOS_L3_BVAR <- c("BCR.REMESAS.NOM.NSA.Q" = "1991-Q1", "BCR.EXPORT_FOB.NOM.NSA.Q" = "1994-Q1", "BCR.ITCER.IDX.NSA.Q" = "2000-Q1",
                      "UT.DEMANDA_ELEC.GWH.NSA.Q" = "2002-Q1", "BCR.IVAE.VOL.SA.Q" = "2005-Q1", "BCR.IPM.IDX.NSA.Q" = "2005-Q1",
                      "BCR.IPP.IDX.NSA.Q" = "2010-Q1", "BCR.REMESAS.REAL.NSA.Q" = "2010-Q1")

.objetivo_bv <- function(semilla) {
  set.seed(semilla)
  per <- ind_a_q(q_a_ind("1990-Q1") + 0:144)
  data.frame(periodo = per, y = 4 + cumsum(0.005 + as.numeric(stats::arima.sim(list(ar = 0.3), length(per), sd = 0.01))),
             stringsAsFactors = FALSE)
}
.predictoras_bv <- function(semilla, hasta = "2026-Q2") {
  set.seed(semilla)
  stats::setNames(lapply(names(.INICIOS_L3_BVAR), function(id) {
    i <- q_a_ind(.INICIOS_L3_BVAR[[id]]):q_a_ind(hasta)
    est <- if (grepl(".NSA.", id, fixed = TRUE)) 0.03 * sin(pi * (i %% 4L) / 2) else 0
    data.frame(periodo = ind_a_q(i), valor = 100 * exp(cumsum(0.004 + stats::rnorm(length(i), 0, 0.02)) + est), stringsAsFactors = FALSE)
  }), names(.INICIOS_L3_BVAR))
}
.hasta_bv <- function(d, o) d[q_a_ind(d$periodo) <= o, , drop = FALSE]
.datos_bv <- function(obj, pred, ids, o) c(list(objetivo = .hasta_bv(obj, o)), lapply(pred[ids], .hasta_bv, o = o))

# Un ajuste corto (1 000 extracciones retenidas) de G1 en 2016-Q4 para las pruebas de los momentos.
.ajuste_corto <- function(semilla = 11L) {
  obj <- .objetivo_bv(101); pred <- .predictoras_bv(102)
  ids <- predictoras_grupo("G1"); o <- q_a_ind("2016-Q4")
  datos <- .datos_bv(obj, pred, ids, o)
  set.seed(semilla)
  pn <- panel_bvar(datos, ids, "PRUEBA")
  fit <- BVAR::bvar(pn$Y, lags = LAGS_BVAR, n_draw = 1500L, n_burn = 500L, n_thin = 1L, priors = priors_bvar(psi_bvar(pn$Y, LAGS_BVAR)),
                    mh = mh_bvar(), fcast = NULL, irf = NULL, verbose = FALSE)
  list(datos = datos, ids = ids, pn = pn, fit = fit)
}

test_that("F5-07, B1b-2, B2-7: registro del BVAR por grupo bajo el contrato", {
  n_series <- c(G1 = 3L, G2 = 7L, G3 = 9L)
  for (g in names(n_series)) {
    ids <- vapply(modelos_fase5(g), `[[`, character(1), "modelo_id")
    expect_identical(utils::tail(ids, 1), paste0("MULT.BVAR.", g), info = g)
    m <- modelo_bvar_grupo(g)
    expect_silent(.validar_modelo(m))
    expect_identical(m$requiere, c("objetivo", predictoras_grupo(g)), info = g)
    expect_identical(length(m$requiere), n_series[[g]], info = g)
    expect_false(m$piso_gl, info = g)
    expect_identical(c(m$lags, m$n_draw, m$n_burn), c(4L, 10000L, 5000L), info = g)
  }
  expect_true("BCR.REMESAS.REAL.NSA.Q" %in% modelo_bvar_grupo("G3")$requiere)          # B1b-2: el BVAR está penalizado
  expect_true("UT.DEMANDA_ELEC.GWH.NSA.Q" %in% modelo_bvar_grupo("G2")$requiere)       # F5-07: UT entra al BVAR
  expect_error(modelo_bvar_grupo("G4"), "grupo no declarado")
  mh <- mh_bvar()
  expect_true(mh$adjust_acc); expect_identical(mh$adjust_burn, 0.75); expect_identical(mh$scale_hess, 0.01)   # B2-11
  pr <- priors_bvar(c(0.01, 0.02, 0.03))
  expect_identical(pr$hyper, c("lambda", "soc", "sur"))                                 # B2-7: hyper = "auto"
  expect_identical(pr$b, 1); expect_identical(pr$var, 1e+07)                            # B2-12: valores por defecto
  expect_identical(pr$lambda$mode, 0.2); expect_identical(pr$alpha$mode, 2)
  expect_identical(pr$psi$mode, c(0.01, 0.02, 0.03))                                    # B2-15, B2-16: ψ fijo por MCO
  expect_equal(pr$psi$min, c(0.01, 0.02, 0.03) / 100); expect_equal(pr$psi$max, c(0.01, 0.02, 0.03) * 100)
})

test_that("B2-5, B2-13, B2-14: factores estacionales con tendencia; solo las NSA cambian y solo en su estacional", {
  iq <- q_a_ind("1994-Q1") + 0:76                                       # termina en Q1: la muestra no está balanceada
  s_ver <- c(0.03, -0.01, -0.04, 0.02)
  x <- 4 + 0.015 * seq_along(iq) + s_ver[as.integer(iq) %% 4L + 1L]
  f <- factores_estacionales(x, iq)
  expect_equal(f, (s_ver - mean(s_ver))[as.integer(iq) %% 4L + 1L], tolerance = 1e-12)   # exacto sin ruido
  # con solo dummies (B2-5 literal) la deriva se colaría en los factores: la tendencia lo evita
  D <- dummies_trimestrales(iq); b0 <- qr.coef(qr(cbind(1, D)), x); s0 <- c(0, b0[2:4]); s0 <- s0 - mean(s0)
  expect_gt(max(abs(s0 - (s_ver - mean(s_ver)))), 0.005)
  # con ruido de paseo aleatorio los factores se recuperan dentro de una tolerancia
  set.seed(7); xr <- x + cumsum(stats::rnorm(length(x), 0, 0.01))
  expect_lt(max(abs(factores_estacionales(xr, iq)[1:4] - (s_ver - mean(s_ver))[as.integer(iq[1:4]) %% 4L + 1L])), 0.012)
  expect_equal(sum(unique(round(f, 12))), 0, tolerance = 1e-12)
  # en el panel: PIB e IVAE (SA) no cambian; cada NSA cambia en un patrón de período 4 que suma cero en el año
  obj <- .objetivo_bv(111); pred <- .predictoras_bv(112)
  ids <- predictoras_grupo("G2"); o <- origenes_grupo("G2")[1]
  d <- .datos_bv(obj, pred, ids, o)
  pv <- panel_var(d, ids, "P"); pb <- panel_bvar(d, ids, "P")
  expect_identical(pb$Y[, c("PIB", "BCR.IVAE.VOL.SA.Q")], pv$Y[, c("PIB", "BCR.IVAE.VOL.SA.Q")])
  expect_identical(pb$nsa_col, c(FALSE, grepl(".NSA.", ids, fixed = TRUE)))
  for (j in which(pb$nsa_col)) {
    dif <- pv$Y[, j] - pb$Y[, j]
    expect_equal(unname(dif[-(1:4)]), unname(dif[seq_len(length(dif) - 4L)]), tolerance = 1e-12, info = colnames(pv$Y)[j])
    expect_equal(sum(dif[1:4]), 0, tolerance = 1e-12, info = colnames(pv$Y)[j])
  }
})

test_that("B2-15, B2-16: ψ es la varianza residual de MCO de un AR(4) con constante por serie, contra qr.solve", {
  set.seed(161); Y <- apply(matrix(stats::rnorm(3 * 60, 0.004, 0.01), 60), 2, cumsum) + 4
  psi <- psi_bvar(Y, 4L)
  ref <- vapply(1:3, function(j) {
    Z <- stats::embed(Y[, j], 5L); X <- cbind(1, Z[, -1]); e <- Z[, 1] - X %*% qr.solve(X, Z[, 1])
    sum(e^2) / (nrow(X) - 5L)
  }, numeric(1))
  expect_equal(psi, ref, tolerance = 1e-12)
  expect_error(psi_bvar(cbind(Y[, 1], 1), 4L, "PRUEBA"), "ψ del BVAR no finito o degenerado")   # serie constante: σ² ≈ 0
})

test_that("B2-10: los momentos de la predictiva coinciden con la recursión del paquete y con los pesos MA de cada extracción", {
  a <- .ajuste_corto(); fit <- a$fit; M <- ncol(a$pn$Y); S <- dim(fit$beta)[1]; H <- 8L; K <- 1L + M * LAGS_BVAR
  mom <- momentos_predictiva_bvar(fit$beta, fit$sigma, a$pn$Y, LAGS_BVAR, H)
  mus <- matrix(NA_real_, S, H); Cs <- matrix(0, H, H)
  for (j in seq_len(S)) {
    bc <- BVAR:::get_beta_comp(fit$beta[j, , ], K = K, M = M, lags = LAGS_BVAR)
    mus[j, ] <- BVAR:::compute_fcast(Y = fit$meta$Y, K = K, M = M, N = fit$meta$N, lags = LAGS_BVAR, horizon = H,
                                     beta_comp = bc, beta_const = fit$beta[j, 1, ])[, 1]
    A <- lapply(seq_len(LAGS_BVAR), function(l) t(fit$beta[j, 1L + (l - 1L) * M + seq_len(M), ]))
    Cs <- Cs + cov_sendero_var(pesos_ma_var(A, H), fit$sigma[j, , ], acumular = FALSE)
  }
  expect_equal(mom$media, colMeans(mus), tolerance = 1e-12)
  V <- Cs / S + crossprod(sweep(mus, 2L, colMeans(mus))) / S
  expect_equal(mom$cov, V, tolerance = 1e-10)
  expect_true(isSymmetric(mom$cov))
  # los momentos de h <= H son el bloque de los de H (el motor recorta)
  m4 <- momentos_predictiva_bvar(fit$beta, fit$sigma, a$pn$Y, LAGS_BVAR, 4L)
  expect_equal(m4$cov, mom$cov[1:4, 1:4], tolerance = 1e-12); expect_equal(m4$media, mom$media[1:4], tolerance = 1e-12)
})

test_that("B2-10: los momentos reproducen una simulación de senderos con choques propagados, y predict.bvar no", {
  a <- .ajuste_corto(); fit <- a$fit; Y <- a$pn$Y; M <- ncol(Y); S <- dim(fit$beta)[1]; H <- 8L; p <- LAGS_BVAR; R <- 40L
  mom <- momentos_predictiva_bvar(fit$beta, fit$sigma, Y, p, H)
  set.seed(121)
  sim <- do.call(rbind, lapply(seq_len(S), function(j) {
    B <- fit$beta[j, , ]; Lc <- chol(fit$sigma[j, , ])
    st <- matrix(rep(as.vector(t(Y[nrow(Y):(nrow(Y) - p + 1L), ])), each = R), nrow = R)
    out <- matrix(NA_real_, R, H)
    for (h in seq_len(H)) {
      yn <- cbind(1, st) %*% B + matrix(stats::rnorm(R * M), R) %*% Lc
      out[, h] <- yn[, 1]; st <- cbind(yn, st[, seq_len(M * (p - 1L)), drop = FALSE])
    }
    out
  }))
  Ssim <- stats::cov(sim)
  expect_lt(max(abs(colMeans(sim) - mom$media) / sqrt(diag(mom$cov))), 0.05)
  expect_lt(max(abs(diag(Ssim) / diag(mom$cov) - 1)), 0.04)
  expect_lt(max(abs(stats::cov2cor(Ssim) - stats::cov2cor(mom$cov))), 0.02)
  # la razón de B2-10: en BVAR 1.0.5 el choque de predict.bvar en h = 1 tiene la varianza de Σ² (no de Σ): su varianza
  # es Var(μ_j) + E[Σ²_11], no Var(μ_j) + E[Σ_11]; con log-niveles Σ² es despreciable y la densidad sale angosta
  set.seed(122); pr <- predict(fit, horizon = H)$fcast[, , 1]
  st <- as.vector(t(Y[nrow(Y):(nrow(Y) - p + 1L), ]))
  mu1 <- fit$beta[, 1L, 1L] + drop(fit$beta[, -1L, 1L] %*% st)
  s11 <- mean(fit$sigma[, 1, 1]); s2_11 <- mean(apply(fit$sigma, 1L, function(s) (s %*% s)[1, 1]))
  vmu <- mean((mu1 - mean(mu1))^2)
  expect_equal(mom$cov[1, 1], vmu + s11, tolerance = 1e-10)
  expect_lt(abs(stats::var(pr[, 1]) / (vmu + s2_11) - 1), 0.25)
  expect_gt(mom$cov[1, 1] / stats::var(pr[, 1]), 5)
  expect_gt(s11 / s2_11, 100)
})

test_that("F5-15: el BVAR es reproducible bit a bit con la semilla del motor; otra semilla cambia las extracciones", {
  obj <- .objetivo_bv(131); pred <- .predictoras_bv(132); ids <- predictoras_grupo("G1")
  m <- modelo_bvar("PRUEBA.BVAR", ids, n_draw = 600L, n_burn = 300L)
  ors <- origenes_grupo("G1")[1:2]
  r1 <- correr_backtest(c(list(objetivo = obj), pred[ids]), list(m), ors, rezagos = rezagos_predictoras(ids), exp_id = "E", densidad = TRUE)
  r2 <- correr_backtest(c(list(objetivo = obj), pred[ids]), list(m), ors, rezagos = rezagos_predictoras(ids), exp_id = "E", densidad = TRUE)
  expect_identical(r1, r2)
  r3 <- correr_backtest(c(list(objetivo = obj), pred[ids]), list(m), ors, rezagos = rezagos_predictoras(ids), exp_id = "OTRO", densidad = TRUE)
  expect_false(identical(r1$log_nivel_pronosticado, r3$log_nivel_pronosticado))
  expect_lt(max(abs(r1$log_nivel_pronosticado - r3$log_nivel_pronosticado)), 0.01)
})

test_that("C1, B2-7: el BVAR corre en el primer origen de cada grupo con las fechas de inicio de L3 y la configuración de producción", {
  obj <- .objetivo_bv(141); pred <- .predictoras_bv(142)
  n_muestra <- c(G1 = 77L, G2 = 40L, G3 = 40L)                          # inicios comunes 1994-Q1, 2005-Q1 y 2010-Q1
  for (g in names(n_muestra)) {
    m <- modelo_bvar_grupo(g); ids <- setdiff(m$requiere, "objetivo"); o1 <- origenes_grupo(g)[1]
    r <- correr_backtest(c(list(objetivo = obj), pred[ids]), list(m), o1, rezagos = rezagos_predictoras(ids), exp_id = "F5_G", densidad = TRUE)
    expect_true(all(is.finite(r$sd_log_nivel)) && all(diff(r$sd_log_nivel) > 0), info = g)
    dg <- attr(r, "diagnosticos")
    expect_identical(dg$clave, c("n_obs", "n_series", "aceptacion", "lambda", "soc", "sur", "psi_pib"), info = g)
    v <- stats::setNames(dg$valor, dg$clave)
    expect_identical(unname(v[["n_obs"]]), n_muestra[[g]] - 4, info = g)
    expect_identical(unname(v[["n_series"]]), length(ids) + 1, info = g)
    expect_true(v[["aceptacion"]] > 0.05 && v[["aceptacion"]] < 0.8, info = g)
    expect_true(v[["psi_pib"]] > 0, info = g)
  }
})

test_that("guardas del BVAR: predictora que no llega al origen, valores no positivos y h fuera de los momentos", {
  obj <- .objetivo_bv(151); pred <- .predictoras_bv(152)
  ids <- predictoras_grupo("G1"); o <- q_a_ind("2016-Q4")
  m <- modelo_bvar("PRUEBA.BVAR", ids, n_draw = 200L, n_burn = 100L)
  corto <- c(list(objetivo = .hasta_bv(obj, o)), lapply(pred[ids], .hasta_bv, o = o - 1L))
  expect_error(m$ajustar(corto, NULL), "no llega al origen 2016-Q4")
  neg <- .datos_bv(obj, pred, ids, o); neg[[2]]$valor[5] <- -1
  expect_error(m$ajustar(neg, NULL), "no positivos")
  set.seed(1); aj <- m$ajustar(.datos_bv(obj, pred, ids, o), NULL)
  expect_error(m$predecir(aj, 9L), "se pidió h = 9 y los momentos llegan a 8")
  expect_silent(validar_densidad(m$predecir_densidad(aj, 8L), m$predecir(aj, 8L)))
})
