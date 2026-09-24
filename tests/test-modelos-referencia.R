# tests/test-modelos-referencia.R
#
# Ejercita los seis benchmarks de src/evaluacion/modelos_referencia.R sobre series construidas, sin
# datos del proyecto (especificación del motor §8). Corre en CI.

library(testthat)
source(here::here("src", "evaluacion", "eval_lib.R"))
source(here::here("src", "evaluacion", "modelos_referencia.R"))

.datos <- function(y, inicio = "1990-Q1") {
  list(objetivo = data.frame(periodo = ind_a_q(q_a_ind(inicio) + seq_along(y) - 1L), y = y, stringsAsFactors = FALSE))
}
.pronostico <- function(m, y, h = 8L) m$predecir(m$ajustar(.datos(y), NULL), h)

test_that("los seis benchmarks están declarados con identificadores únicos y el contrato completo", {
  ms <- modelos_referencia()
  ids <- vapply(ms, `[[`, character(1), "modelo_id")
  expect_identical(ids, c("BENCH.RW_SIN_DERIVA", "BENCH.RW_CON_DERIVA", "BENCH.AR1",
                          "BENCH.ARP_BIC", "BENCH.MEDIA_CRECIMIENTO", "BENCH.ETS"))
  for (m in ms) {
    expect_true(all(c("modelo_id", "requiere", "ajustar", "predecir") %in% names(m)))
    expect_identical(m$requiere, "objetivo")
  }
})

test_that("RW sin deriva repite el último valor", {
  y <- log(100) + cumsum(c(0, rep(0.01, 59)))
  expect_equal(.pronostico(modelo_rw_sin_deriva(), y), rep(utils::tail(y, 1), 8))
})

test_that("RW con deriva extrapola exactamente una serie lineal en logs", {
  y <- log(100) + 0.01 * (0:59)
  expect_equal(.pronostico(modelo_rw_con_deriva(), y), utils::tail(y, 1) + 0.01 * (1:8))
})

test_that("AR(1) recupera φ en muestra larga y su sendero es la recursión acumulada", {
  set.seed(11)
  n <- 2000L; dy <- numeric(n); e <- rnorm(n, 0, 0.01)
  for (t in 2:n) dy[t] <- 0.5 * dy[t - 1] + e[t]
  m <- modelo_ar1(); aj <- m$ajustar(.datos(cumsum(dy) + log(100)), NULL)
  expect_equal(aj$phi, 0.5, tolerance = 0.05)
  s <- m$predecir(aj, 3L)
  d1 <- aj$c0 + aj$phi * utils::tail(aj$dy, 1); d2 <- aj$c0 + aj$phi * d1; d3 <- aj$c0 + aj$phi * d2
  expect_equal(s, aj$y_o + cumsum(c(d1, d2, d3)))
})

test_that("AR(p)-BIC elige p = 0 en ruido blanco y p = 2 en un AR(2) marcado", {
  set.seed(12)
  expect_identical(seleccionar_ar_bic(rnorm(400, 0, 0.01))$p, 0L)
  n <- 400L; dy <- numeric(n); e <- rnorm(n, 0, 0.01)
  for (t in 3:n) dy[t] <- 0.5 * dy[t - 1] - 0.4 * dy[t - 2] + e[t]
  s <- seleccionar_ar_bic(dy)
  expect_identical(s$p, 2L)
  expect_length(s$bic, 9L)                                 # p = 0..8
  expect_identical(s$n_eff, n - 8L)                        # selección: muestra común de p_max = 8
  expect_identical(s$n_est, n - 2L)                        # estimación: muestra máxima para p = 2
  f <- stats::lm.fit(cbind(1, dy[3:n - 1], dy[3:n - 2]), dy[3:n])
  expect_equal(c(s$c0, s$phi), unname(f$coefficients))     # coeficientes de la muestra máxima
})

test_that("con p = 0 la constante del AR(p)-BIC es la media de toda la muestra", {
  set.seed(15)
  dy <- rnorm(200, 0.004, 0.01)
  s <- seleccionar_ar_bic(dy)
  expect_identical(s$p, 0L)
  expect_identical(s$n_est, 200L)
  expect_equal(s$c0, mean(dy))
  expect_length(s$phi, 0L)
})

test_that("AR(p)-BIC falla de forma visible con muestra insuficiente", {
  expect_error(seleccionar_ar_bic(rnorm(10)), "muestra insuficiente")
})

test_that("la media de crecimiento continúa exactamente un crecimiento interanual constante", {
  y <- log(100) + 0.02 * (0:39) / 4                         # yoy constante = 0,02
  s <- .pronostico(modelo_media_crecimiento(), y)
  expect_equal(s, utils::tail(y, 1) + 0.02 * (1:8) / 4)
  expect_equal(s[5:8] - s[1:4], rep(0.02, 4))               # h > 4 se apoya en el propio sendero
})

test_that("ETS devuelve 8 valores finitos que siguen una tendencia lineal", {
  set.seed(13)
  y <- log(100) + 0.01 * (0:79) + rnorm(80, 0, 0.001)
  s <- .pronostico(modelo_ets(), y)
  expect_length(s, 8L)
  expect_true(all(is.finite(s)))
  expect_equal(s, log(100) + 0.01 * (80:87), tolerance = 1e-3)
})

test_that("los seis benchmarks corren en el motor sobre los 52 orígenes", {
  set.seed(14)
  y <- log(100) + cumsum(c(0, rnorm(144, 0.005, 0.01)))
  obj <- .datos(y)$objetivo
  p <- correr_backtest(list(objetivo = obj), modelos_referencia(), origenes_diseno(), exp_id = "test")
  expect_identical(nrow(p), 6L * 52L * 8L)
  expect_true(all(is.finite(p$log_nivel_pronosticado)))
  m <- agregar_rmse_relativo(metricas_por_horizonte(calcular_errores(p, obj)))
  expect_identical(sort(unique(m$n_pares)), c(45L, 49L, 51L, 52L))
})
