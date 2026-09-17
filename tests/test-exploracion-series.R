# tests/test-exploracion-series.R
#
# Ejercita src/analisis/exploracion_series_reglas.R con datos sinteticos, sin tocar disco.
# Mismo patron que tests/test-l3-predictores.R.

library(testthat)
source(here::here("src", "analisis", "exploracion_series_reglas.R"))

test_that("resumen_serie reporta cobertura y momentos sin huecos", {
  df <- data.frame(periodo = sprintf("2020-Q%d", 1:4), valor = c(10, 20, 30, 40),
                    stringsAsFactors = FALSE)

  r <- resumen_serie(df, "TEST.Q", "Q")

  expect_equal(r$n_obs, 4)
  expect_equal(r$n_esperado, 4)
  expect_equal(r$n_hueco, 0)
  expect_equal(r$huecos, "")
  expect_equal(r$periodo_inicio, "2020-Q1")
  expect_equal(r$periodo_fin, "2020-Q4")
  expect_equal(r$media, 25)
  expect_equal(r$media_diff1, 10)
})

test_that("resumen_serie detecta un hueco interno real (no de borde)", {
  df <- data.frame(periodo = c("2020-Q1", "2020-Q2", "2020-Q4"), valor = c(10, 20, 40),
                    stringsAsFactors = FALSE)

  r <- resumen_serie(df, "TEST.Q", "Q")

  expect_equal(r$n_obs, 3)
  expect_equal(r$n_esperado, 4)
  expect_equal(r$n_hueco, 1)
  expect_equal(r$huecos, "2020-Q3")
})

test_that("resumen_serie funciona en frecuencia mensual y cruza el borde de anio", {
  df <- data.frame(periodo = c("2020-M11", "2020-M12", "2021-M01"), valor = c(1, 2, 3),
                    stringsAsFactors = FALSE)

  r <- resumen_serie(df, "TEST.M", "M")

  expect_equal(r$n_obs, 3)
  expect_equal(r$n_esperado, 3)
  expect_equal(r$n_hueco, 0)
  expect_equal(r$periodo_inicio, "2020-M11")
  expect_equal(r$periodo_fin, "2021-M01")
})

test_that("resumen_serie no confunde una serie corta (arranca tarde) con un hueco", {
  df <- data.frame(periodo = sprintf("2015-Q%d", 1:4), valor = c(5, 6, 7, 8),
                    stringsAsFactors = FALSE)

  r <- resumen_serie(df, "TEST.Q", "Q")

  expect_equal(r$n_hueco, 0) # la serie simplemente empieza en 2015-Q1, no hay ausencia interna
})
