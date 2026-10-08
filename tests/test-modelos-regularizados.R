# tests/test-modelos-regularizados.R
#
# Regularizados de Fase 5, bloque B3 (PR 2; F5-09, F5-11, F5-12 y B3-1 a B3-7 de doc/metodologia/decisiones_fase5.md),
# con datos SINTÉTICOS: no se lee data/. Comprueba el registro por grupo, la rejilla de λ de B3-1 contra el λ_max de
# glmnet, el pronóstico del elastic net contra glmnet y el del PCR contra MCO sobre los componentes (y contra MCO
# completo cuando k = número de columnas), las guardas de B3-7, que los dos corren en el primer origen de cada grupo
# con las fechas de inicio de L3 (9 filas en la ventana interna más chica de G2 y G3 a h = 8, B3-4), sus diagnósticos y
# que reejecutar reproduce bit a bit.

library(testthat)
source(here::here("src", "evaluacion", "motor_backtesting.R"))   # eval_lib, modelos_referencia, modelos_fase5

.INICIOS_L3_RG <- c("BCR.REMESAS.NOM.NSA.Q" = "1991-Q1", "BCR.EXPORT_FOB.NOM.NSA.Q" = "1994-Q1", "BCR.ITCER.IDX.NSA.Q" = "2000-Q1",
                    "UT.DEMANDA_ELEC.GWH.NSA.Q" = "2002-Q1", "BCR.IVAE.VOL.SA.Q" = "2005-Q1", "BCR.IPM.IDX.NSA.Q" = "2005-Q1",
                    "BCR.IPP.IDX.NSA.Q" = "2010-Q1", "BCR.REMESAS.REAL.NSA.Q" = "2010-Q1")
.objetivo_rg <- function(semilla) {
  set.seed(semilla)
  per <- ind_a_q(q_a_ind("1990-Q1") + 0:144)
  data.frame(periodo = per, y = 4 + cumsum(0.005 + as.numeric(stats::arima.sim(list(ar = 0.3), length(per), sd = 0.01))), stringsAsFactors = FALSE)
}
.predictoras_rg <- function(semilla, ids = names(.INICIOS_L3_RG), hasta = "2026-Q2") {
  set.seed(semilla)
  stats::setNames(lapply(ids, function(id) {
    i <- q_a_ind(.INICIOS_L3_RG[[id]]):q_a_ind(hasta)
    est <- if (grepl(".NSA.", id, fixed = TRUE)) 0.03 * sin(pi * (i %% 4L) / 2) else 0
    data.frame(periodo = ind_a_q(i), valor = 100 * exp(cumsum(0.004 + stats::rnorm(length(i), 0, 0.02)) + est), stringsAsFactors = FALSE)
  }), ids)
}
.hasta_rg <- function(d, o) d[q_a_ind(d$periodo) <= o, , drop = FALSE]
.datos_rg <- function(obj, pred, ids, o) c(list(objetivo = .hasta_rg(obj, o)), lapply(pred[ids], .hasta_rg, o = o))
.ventana_rg <- function(semilla, n = 40L, p = 12L) {
  set.seed(semilla)
  Z <- scale(matrix(stats::rnorm(n * p), n), scale = FALSE); Z <- sweep(Z, 2L, sqrt(colMeans(Z^2)), "/")
  g <- as.numeric(Z[, 1:2] %*% c(0.02, -0.01) + stats::rnorm(n, 0, 0.01)); g <- g - mean(g)
  list(Z = Z, g = g, z = matrix(stats::rnorm(p), 1L))
}

test_that("F5-09, B1b-2: registro de los regularizados por grupo bajo el contrato", {
  for (g in c("G1", "G2", "G3")) {
    ids <- vapply(modelos_fase5(g), `[[`, character(1), "modelo_id")
    expect_identical(ids[startsWith(ids, "REG.")], paste0(c("REG.ENET.", "REG.PCR."), g), info = g)
    for (m in modelos_regularizados_grupo(g)) {
      expect_silent(.validar_modelo(m))
      expect_false(m$piso_gl, info = m$modelo_id)                                  # F5-09
      expect_identical(m$requiere, c("objetivo", predictoras_grupo(g)), info = m$modelo_id)   # B1b-2: todas
      expect_true(is.function(m$predecir_densidad) && is.function(m$diagnosticar), info = m$modelo_id)
      expect_true(m$esp$transformar, info = m$modelo_id)                            # B3-2
    }
  }
  expect_true("BCR.REMESAS.REAL.NSA.Q" %in% modelo_enet_grupo("G3")$requiere)
  expect_identical(c(ALFAS_ENET, N_LAMBDA_ENET, RAZON_LAMBDA_ENET, K_MAX_PCR), c(0, 0.5, 1, 100, 1e-3, 5))
  expect_error(modelos_regularizados_grupo("G4"), "grupo no declarado")
})

test_that("B3-1: la rejilla de λ va de λ_max (el de glmnet) a λ_max · 10⁻³, 100 valores por α, de más a menos penalizado", {
  v <- .ventana_rg(1)
  rj <- rejilla_enet(v$Z, v$g, 1L)
  expect_identical(nrow(rj), 300L)
  expect_identical(unique(rj$alpha), ALFAS_ENET)
  for (a in ALFAS_ENET) {
    l <- rj$lambda[rj$alpha == a]
    expect_true(all(diff(l) < 0))
    expect_equal(l[100] / l[1], 1e-3, tolerance = 1e-12)
    propio <- glmnet::glmnet(v$Z, v$g, alpha = a, standardize = FALSE, intercept = FALSE)
    expect_equal(l[1], max(propio$lambda), tolerance = 1e-10, info = a)           # λ_max de glmnet
  }
  # en λ_max el lasso y el elastic net anulan todos los coeficientes
  expect_true(all(.senda_glmnet(v$Z, v$g, 1, rj$lambda[rj$alpha == 1])[, 1] == 0))
  expect_error(rejilla_enet(v$Z, rep(0, length(v$g)), 1L), "λ_max no positivo")
})

test_that("F5-09: el elastic net pronostica lo mismo que glmnet con la rejilla explícita, sin depender de los otros candidatos", {
  v <- .ventana_rg(2, n = 9L, p = 31L)                                              # p > n, como G2 y G3 a h = 8
  rj <- rejilla_enet(v$Z, v$g, 8L)
  todos <- estimar_predecir_enet(v$Z, v$g, v$z, rj, seq_len(nrow(rj)))
  for (a in ALFAS_ENET) {
    ia <- which(rj$alpha == a)
    f <- glmnet::glmnet(v$Z, v$g, alpha = a, lambda = rj$lambda[ia], standardize = FALSE, intercept = FALSE)
    expect_identical(length(f$lambda), 100L)
    expect_equal(todos[ia], as.numeric(stats::predict(f, newx = v$z)), tolerance = 1e-12, info = a)
  }
  sub <- c(150L, 7L, 260L)
  expect_identical(estimar_predecir_enet(v$Z, v$g, v$z, rj, sub), todos[sub])
})

test_that("B3-7: una senda de glmnet incompleta o con coeficientes no finitos detiene el motor", {
  v <- .ventana_rg(9, n = 9L, p = 31L)
  lam <- rejilla_enet(v$Z, v$g, 8L)$lambda[1:100]
  local_mocked_bindings(glmnet = function(x, y, ..., lambda) list(lambda = lambda[1:61], beta = matrix(0, ncol(x), 61L), a0 = rep(0, 61L)),
                        .package = "glmnet")
  expect_error(.senda_glmnet(v$Z, v$g, 0, lam), "con α = 0 quedó incompleta \\(61 de 100 valores de λ; B3-7\\)")
  local_mocked_bindings(glmnet = function(x, y, ..., lambda) list(lambda = lambda, beta = matrix(NaN, ncol(x), length(lambda)), a0 = rep(0, length(lambda))),
                        .package = "glmnet")
  expect_error(.senda_glmnet(v$Z, v$g, 1, lam), "coeficientes no finitos con α = 1 \\(B3-7\\)")
})

test_that("F5-09, B3-3: el PCR es MCO sobre los k primeros componentes y, con todos, MCO completo", {
  v <- .ventana_rg(3, n = 30L, p = 5L)
  rj <- rejilla_pcr(v$Z, v$g, 1L)
  expect_identical(rj$k, 1:5)
  p <- estimar_predecir_pcr(v$Z, v$g, v$z, rj, 1:5)
  pc <- stats::prcomp(v$Z, center = FALSE, scale. = FALSE)
  for (k in 1:5) {
    S <- pc$x[, 1:k, drop = FALSE]
    b <- stats::lm.fit(S, v$g)$coefficients
    expect_equal(p[k], sum((v$z %*% pc$rotation[, 1:k, drop = FALSE]) * b), tolerance = 1e-12, info = k)
  }
  expect_equal(p[5], sum(v$z * stats::lm.fit(v$Z, v$g)$coefficients), tolerance = 1e-12)   # k = p: MCO completo
  expect_identical(estimar_predecir_pcr(v$Z, v$g, v$z, rj, c(3L, 1L)), p[c(3L, 1L)])
  # B3-7: con la ventana residualizada sobre constante y 3 dummies, 8 filas dejan rango 4 y el componente 5 no existe
  set.seed(4)
  t_ <- q_a_ind("2006-Q1") + 0:7
  vt <- ventana_directa(matrix(stats::rnorm(8 * 20), 8), stats::rnorm(8), t_, con_dummies = TRUE)
  expect_error(estimar_predecir_pcr(vt$Z, vt$gz, matrix(0, 1, 20), rj, 1:5), "el componente 5 no tiene varianza")
  expect_length(estimar_predecir_pcr(vt$Z, vt$gz, matrix(0, 1, 20), rj, 1:4), 4L)
})

test_that("B3-4, B3-7: ENET y PCR corren en el primer origen de cada grupo con las fechas de inicio de L3", {
  obj <- .objetivo_rg(5); pred <- .predictoras_rg(6)
  for (g in c("G1", "G2", "G3")) {
    o1 <- origenes_grupo(g)[1]; ids <- predictoras_grupo(g)
    r <- correr_backtest(c(list(objetivo = obj), pred[ids]), modelos_regularizados_grupo(g), o1, rezagos = rezagos_predictoras(ids), densidad = TRUE)
    expect_identical(nrow(r), 16L, info = g)
    expect_true(all(is.finite(r$sd_log_nivel)) && all(r$sd_log_nivel > 0), info = g)
    d <- attr(r, "diagnosticos")
    en <- d[d$modelo_id == paste0("REG.ENET.", g), ]; pc <- d[d$modelo_id == paste0("REG.PCR.", g), ]
    expect_true(all(c(paste0("h", 1:8, ".alpha"), paste0("h", 1:8, ".lambda"), paste0("h", 1:8, ".lambda_pos"), paste0("h", 1:8, ".borde")) %in% en$clave), info = g)
    expect_true(all(en$valor[grepl("\\.alpha$", en$clave)] %in% ALFAS_ENET), info = g)
    expect_true(all(pc$valor[grepl("\\.k$", pc$clave)] %in% 1:5), info = g)
    expect_identical(en$valor[en$clave == "h8.n_filas_min"], c(G1 = 46, G2 = 9, G3 = 9)[[g]], info = g)
  }
})

test_that("F5-15: reejecutar ENET y PCR reproduce bit a bit sendero, densidad y diagnósticos", {
  obj <- .objetivo_rg(7); pred <- .predictoras_rg(8)
  ids <- predictoras_grupo("G2"); org <- origenes_grupo("G2")[c(3, 9)]
  a <- correr_backtest(c(list(objetivo = obj), pred[ids]), modelos_regularizados_grupo("G2"), org, rezagos = rezagos_predictoras(ids), densidad = TRUE, exp_id = "A")
  b <- correr_backtest(c(list(objetivo = obj), pred[ids]), modelos_regularizados_grupo("G2"), org, rezagos = rezagos_predictoras(ids), densidad = TRUE, exp_id = "B")
  expect_identical(a, b)                                                             # deterministas: no usan la semilla
})
