# tests/test-pruebas-significancia.R
#
# Pruebas unitarias de la sección 8 de src/evaluacion/eval_lib.R: Diebold-Mariano/HLN,
# Giacomini-White y MCS con T_max (F4-12, F4-15..F4-17). Datos construidos; corre en CI.
# El comportamiento en muestras repetidas (tamaño, potencia, cobertura) está en V7-V9 de
# verificar_motor_sintetico.R.

library(testthat)
source(here::here("src", "evaluacion", "eval_lib.R"))

test_that("DM/HLN: errores idénticos dan estadístico 0 y p = 1 (caso degenerado)", {
  e <- c(0.5, -1, 2, 0.3, -0.7, 1.1, 0.2, -0.4)
  r <- prueba_dm_hln(e, e, 1L)
  expect_identical(r$estadistico, 0); expect_identical(r$p_valor, 1)
  expect_identical(r$varianza, "degenerada")
})

test_that("DM/HLN: el signo positivo favorece al modelo 2", {
  set.seed(1); e1 <- rnorm(60, 0, 2); e2 <- rnorm(60, 0, 1)
  r <- prueba_dm_hln(e1, e2, 1L)
  expect_gt(r$estadistico, 0); expect_gt(r$media_diferencial, 0)
  expect_lt(prueba_dm_hln(e2, e1, 1L)$estadistico, 0)
  expect_equal(prueba_dm_hln(e2, e1, 1L)$estadistico, -r$estadistico)
})

test_that("DM/HLN en h=1 coincide con t de medias con corrección HLN y t(n-1)", {
  set.seed(2); e1 <- rnorm(40); e2 <- rnorm(40); n <- 40
  d <- e1^2 - e2^2
  dm <- mean(d) / sqrt(mean((d - mean(d))^2) / n)
  hln <- dm * sqrt((n + 1 - 2 + 0) / n)            # factor HLN con h=1: sqrt((n+1-2h+h(h-1)/n)/n)
  r <- prueba_dm_hln(e1, e2, 1L)
  expect_equal(r$estadistico, hln, tolerance = 1e-10)
  expect_equal(r$p_valor, 2 * pt(-abs(hln), n - 1), tolerance = 1e-10)
  expect_identical(r$varianza, "rectangular")
})

test_that("DM/HLN recurre a Bartlett y lo registra cuando la varianza rectangular no es positiva", {
  # diferencial alternante: autocovarianza de orden 1 muy negativa → varianza rectangular h=2 < 0
  d_alt <- rep(c(1, -1), 15) + seq(0, 0.29, by = 0.01)
  e2 <- rep(1, 30); e1 <- sqrt(d_alt + 1 + 1)
  r <- prueba_dm_hln(e1, e2, 2L)
  expect_false(r$varianza == "rectangular")
  expect_true(is.finite(r$estadistico))
})

test_that("GW: estadístico χ²(2) finito, p en [0,1] y rechaza con diferencias claras", {
  set.seed(3); e1 <- rnorm(52, 0, 1.6); e2 <- rnorm(52)
  r <- prueba_gw(e1, e2, 1L)
  expect_true(is.finite(r$estadistico)); expect_gte(r$p_valor, 0); expect_lte(r$p_valor, 1)
  expect_identical(r$n_pares, 51L)                  # un par se pierde por el instrumento d_{t-h}
  expect_lt(r$p_valor, 0.05)
  expect_identical(prueba_gw(e1, e2, 4L)$n_pares, 48L)
})

test_that("GW exige un mínimo de pares", {
  expect_error(prueba_gw(rnorm(5), rnorm(5), 2L))
})

test_that("bloque del MCS es max(h, ceiling(n^(1/3)))", {
  expect_identical(bloque_mcs(52, 1), 4L); expect_identical(bloque_mcs(18, 8), 8L)
  expect_identical(bloque_mcs(125, 2), 5L)
})

test_that("índices del bootstrap estacionario circular están en 1..n y tienen B*n elementos", {
  set.seed(4); idx <- indices_bootstrap_estacionario(30L, 4L, 50L)
  expect_length(idx, 30L * 50L)
  expect_true(all(idx >= 1L & idx <= 30L)); expect_true(all(idx == round(idx)))
})

test_that("MCS: con pérdidas muy separadas conserva solo al mejor; con idénticas se detiene", {
  set.seed(5); n <- 52
  L <- cbind(A = rnorm(n, 1, 0.1)^2, B = rnorm(n, 3, 0.1)^2, C = rnorm(n, 5, 0.1)^2)
  r <- mcs_tmax(L, 1L, B = 500L, semilla = 1L)
  expect_identical(r$modelo_id[r$en_mcs], "A")
  expect_true(all(r$p_mcs >= 0 & r$p_mcs <= 1))
  Li <- cbind(A = L[, 1], B = L[, 1])
  expect_error(mcs_tmax(Li, 1L, B = 200L, semilla = 1L), "varianza bootstrap nula")   # regla 7: falla visible
})

test_that("MCS: misma semilla, mismo resultado, y no altera el RNG del llamador", {
  set.seed(6); L <- matrix(rnorm(40 * 3)^2, 40, 3, dimnames = list(NULL, c("A", "B", "C")))
  set.seed(99); antes <- .Random.seed
  r1 <- mcs_tmax(L, 2L, B = 300L, semilla = 7L)
  expect_identical(.Random.seed, antes)
  expect_identical(r1, mcs_tmax(L, 2L, B = 300L, semilla = 7L))
})
