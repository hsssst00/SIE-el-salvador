# tests/test-l3-predictores.R
#
# Ejercita src/transformacion/l3_predictores_reglas.R con datos sinteticos, sin tocar disco.
# Mismo patron que tests/test-l3-pib-objetivo.R.

library(testthat)
source(here::here("src", "transformacion", "l3_predictores_reglas.R"))

.mensual_sintetico <- function(periodos, valores) {
  data.frame(periodo = periodos, valor = valores, stringsAsFactors = FALSE)
}

test_that("agregar_trimestral_promedio promedia 3 meses por trimestre", {
  periodos <- sprintf("2020-M%02d", 1:12)
  valores <- c(10, 20, 30,  40, 50, 60,  70, 80, 90,  100, 110, 120)
  mensual <- .mensual_sintetico(periodos, valores)

  trimestral <- agregar_trimestral_promedio(mensual, etiqueta = "TEST")

  expect_equal(nrow(trimestral), 4)
  expect_equal(trimestral$periodo, c("2020-Q1", "2020-Q2", "2020-Q3", "2020-Q4"))
  expect_equal(trimestral$valor, c(20, 50, 80, 110))
})

test_that("agregar_trimestral_promedio descarta el ultimo trimestre si esta incompleto", {
  periodos <- c(sprintf("2020-M%02d", 1:12), "2021-M01", "2021-M02")
  valores <- c(10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140)
  mensual <- .mensual_sintetico(periodos, valores)

  trimestral <- agregar_trimestral_promedio(mensual, etiqueta = "TEST")

  expect_equal(nrow(trimestral), 4) # 2021-Q1 (solo 2 meses) se descarta, no se promedia a medias
  expect_false("2021-Q1" %in% trimestral$periodo)
})

test_that("agregar_trimestral_promedio falla de forma visible ante un hueco real (no de borde)", {
  periodos <- sprintf("2020-M%02d", 1:12)
  valores <- c(10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120)
  mensual <- .mensual_sintetico(periodos, valores)
  mensual <- mensual[mensual$periodo != "2020-M05", ] # hueco en 2020-Q2 (abr/jun sin mayo)

  expect_error(agregar_trimestral_promedio(mensual, etiqueta = "TEST"), "FALLO VISIBLE.*TEST")
})

test_that("agregar_trimestral_promedio funciona con una sola serie de un año completo", {
  periodos <- sprintf("2005-M%02d", 1:12)
  valores <- 1:12
  mensual <- .mensual_sintetico(periodos, valores)

  trimestral <- agregar_trimestral_promedio(mensual, etiqueta = "TEST")

  expect_equal(trimestral$valor, c(mean(1:3), mean(4:6), mean(7:9), mean(10:12)))
})
