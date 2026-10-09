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

test_that("MCS: acepta remuestras externas (oráculo V11) y valida sus dimensiones", {
  set.seed(8); L <- matrix(rnorm(30 * 3)^2, 30, 3, dimnames = list(NULL, c("A", "B", "C")))
  idx <- matrix(sample.int(30, 200 * 30, replace = TRUE), 200, 30)
  expect_identical(mcs_tmax(L, 1L, semilla = 1L, indices = idx), mcs_tmax(L, 1L, semilla = 2L, indices = idx))
  expect_identical(attr(mcs_tmax(L, 1L, semilla = 1L, indices = idx), "B"), 200L)
  expect_error(mcs_tmax(L, 1L, semilla = 1L, indices = idx[, 1:29]), "B x n")
})

test_that("MCS: misma semilla, mismo resultado, y no altera el RNG del llamador", {
  set.seed(6); L <- matrix(rnorm(40 * 3)^2, 40, 3, dimnames = list(NULL, c("A", "B", "C")))
  set.seed(99); antes <- .Random.seed
  r1 <- mcs_tmax(L, 2L, B = 300L, semilla = 7L)
  expect_identical(.Random.seed, antes)
  expect_identical(r1, mcs_tmax(L, 2L, B = 300L, semilla = 7L))
})

test_that("B2-9: mcs_tmax_dedup sin duplicados reproduce a mcs_tmax y con duplicados comparte el resultado", {
  set.seed(15); n <- 40
  L <- cbind(A = rnorm(n, 1, 0.3)^2, B = rnorm(n, 1.1, 0.3)^2, C = rnorm(n, 1.6, 0.3)^2)
  base <- mcs_tmax(L, 2L, B = 400L, semilla = 3L)
  r <- mcs_tmax_dedup(L, 2L, B = 400L, semilla = 3L)
  for (nm in names(base)) expect_identical(unname(r[[nm]]), unname(base[[nm]]), info = nm)
  for (a in c("alpha", "B", "bloque")) expect_identical(attr(r, a), attr(base, a))
  expect_identical(r$identico_a, c("", "", ""))
  # D y E copian a B (un VECM con r = 0 que repite al VAR en diferencias): corre sin ellos y comparten el de B
  L2 <- cbind(L[, 1:2], D = L[, "B"], C = L[, 3], E = L[, "B"])
  expect_identical(unname(modelos_identicos(L2)), c(NA, NA, "B", NA, "B"))
  r2 <- mcs_tmax_dedup(L2, 2L, B = 400L, semilla = 3L)
  expect_identical(r2$modelo_id, colnames(L2)); expect_identical(r2$identico_a, c("", "", "B", "", "B"))
  ref <- base[match(c("A", "B", "B", "C", "B"), base$modelo_id), ]
  expect_identical(r2$p_mcs, ref$p_mcs); expect_identical(r2$en_mcs, ref$en_mcs); expect_identical(r2$orden_eliminacion, ref$orden_eliminacion)
  # mcs_tmax solo sigue deteniéndose si los idénticos quedan al final (Regla 7); la deduplicación vive en el contenedor
  expect_error(mcs_tmax(cbind(A = L[, 1], B = L[, 1]), 1L, B = 100L, semilla = 1L), "varianza bootstrap nula")
  # todos idénticos: conjunto trivial
  r3 <- mcs_tmax_dedup(cbind(A = L[, 1], B = L[, 1]), 1L, B = 100L, semilla = 1L)
  expect_identical(r3$p_mcs, c(1, 1)); expect_true(all(r3$en_mcs)); expect_identical(r3$identico_a, c("", "A"))
  expect_identical(attr(r3, "bloque"), bloque_mcs(n, 1L))
  # una diferencia mínima no es un duplicado
  L4 <- L; L4[1, 2] <- L4[1, 1] + 1e-12; L4[-1, 2] <- L4[-1, 1]
  expect_identical(unname(modelos_identicos(L4)), c(NA_character_, NA_character_, NA_character_))
  expect_error(mcs_tmax_dedup(L[, 1, drop = FALSE], 1L, semilla = 1L), "al menos 2 modelos")
})

test_that("GW (E2-2): diferencial idénticamente cero → degenerada (p = 1); instrumento nulo → NA marcado; si no, Bartlett", {
  set.seed(7); e2 <- stats::rnorm(18)
  g0 <- prueba_gw(e2, e2, 8L)
  expect_identical(c(g0$estadistico, g0$p_valor), c(0, 1)); expect_identical(g0$varianza, "degenerada")
  e1 <- e2; e1[12:18] <- e1[12:18] + 0.5                                         # iguales en los 11 primeros pares
  g1 <- prueba_gw(e2, e1, 8L)                                                   # el caso de F5_G3_R1, UNI.ARIMA, h = 8
  expect_true(is.na(g1$p_valor)); expect_identical(g1$varianza, "instrumento_degenerado"); expect_identical(g1$n_pares, 10L)
  expect_identical(prueba_gw(stats::rnorm(50), stats::rnorm(50), 1L)$varianza, "bartlett")
  # el patrón de F5_G3_R1: 11 de 18 diferenciales nulos, con d_{t-8} · d_t = 0 en los 10 pares útiles sin que el
  # instrumento sea nulo entero (Ω singular)
  e3 <- e2; dif <- c(1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0) == 1
  e3[dif] <- e3[dif] + 0.5
  d3 <- e2^2 - e3^2; t_ <- 9:18
  expect_false(all(d3[t_ - 8L] == 0)); expect_true(all(d3[t_ - 8L] * d3[t_] == 0))
  g3 <- prueba_gw(e2, e3, 8L)
  expect_true(is.na(g3$p_valor)); expect_identical(g3$varianza, "singular")
})
