# tests/test-analisis-posterior-ap3.R
#
# Análisis posterior AP-3 de Fase 5 (src/analisis_posterior/ap3_tamano.R): los DGP bajo H0 tienen el largo, la
# estructura MA(h − 1) y la correlación declarados; el resumen de tamaño cuenta bien; una corrida corta del estudio es
# reproducible. No lee datos del proyecto.

library(testthat)
source(here::here("src", "analisis_posterior", "ap3_tamano.R"))

test_that("AP-3: DGP bajo H0 con el largo, la MA(h − 1) y la correlación declarados", {
  set.seed(1)
  e <- errores_h0(30L, 4L, "D1")
  expect_length(e$e1, 30L); expect_length(e$e2, 30L)
  set.seed(2)
  big <- errores_h0(20000L, 4L, "D1")
  ac <- stats::acf(big$e1, lag.max = 5, plot = FALSE)$acf[-1]
  expect_equal(ac[1:3], (3:1) / 4, tolerance = 0.03)                              # MA(3) de unos: ρ_k = (h − k)/h
  expect_lt(abs(ac[4]), 0.03)
  expect_equal(stats::var(big$e1), 4, tolerance = 0.1)
  set.seed(3)
  d2 <- errores_h0(20000L, 1L, "D2")
  expect_equal(stats::cor(d2$e1, d2$e2), RHO_D2_AP3, tolerance = 0.01)
  set.seed(4)
  d3 <- errores_h0(50000L, 1L, "D3")
  expect_equal(stats::var(d3$e1), 1, tolerance = 0.05)
  expect_error(errores_h0(10L, 1L, "D9"), "DGP desconocido")
})

test_that("AP-3: resumen de tamaño y reproducibilidad de una corrida corta", {
  r <- resumir_celda(c(0.01, 0.07, 0.5, NA), "gw", "D1", data.frame(grupo = "G9", h = 1L, n = 10L))
  expect_identical(r$replicas_definidas, 3L)
  expect_equal(r$tamano_05, 1 / 3); expect_equal(r$tamano_10, 2 / 3)
  a <- estudio_tamano(R = 20L, dgps = "D1"); b <- estudio_tamano(R = 20L, dgps = "D1")
  expect_identical(a, b)
  expect_identical(nrow(a), nrow(CELDAS_GW_AP3) + nrow(CELDAS_ESTAB_AP3))
})
