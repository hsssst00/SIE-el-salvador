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

test_that("agregar_trimestral_promedio no falla si el PRIMER trimestre está incompleto (borde de cobertura)", {
  # Caso real: una serie deflactada por deflactar_serie() puede arrancar a mitad de trimestre.
  periodos <- c("2020-M03", sprintf("2020-M%02d", 4:12))
  valores <- c(30, 40, 50, 60, 70, 80, 90, 100, 110, 120)
  mensual <- .mensual_sintetico(periodos, valores)

  trimestral <- agregar_trimestral_promedio(mensual, etiqueta = "TEST")

  expect_equal(trimestral$periodo, c("2020-Q2", "2020-Q3", "2020-Q4"))
  expect_false("2020-Q1" %in% trimestral$periodo)
})

test_that("agregar_trimestral_suma suma los 3 meses por trimestre, no promedia", {
  periodos <- sprintf("2020-M%02d", 1:12)
  valores <- c(10, 20, 30,  40, 50, 60,  70, 80, 90,  100, 110, 120)
  mensual <- .mensual_sintetico(periodos, valores)

  trimestral <- agregar_trimestral_suma(mensual, etiqueta = "TEST")

  expect_equal(trimestral$periodo, c("2020-Q1", "2020-Q2", "2020-Q3", "2020-Q4"))
  expect_equal(trimestral$valor, c(60, 150, 240, 330))
})

test_that("agregar_trimestral_suma descarta bordes incompletos igual que agregar_trimestral_promedio", {
  periodos <- c("2020-M02", sprintf("2020-M%02d", 3:11)) # arranca a mitad del Q1, termina a mitad del Q4
  valores <- 1:10
  mensual <- .mensual_sintetico(periodos, valores)

  trimestral <- agregar_trimestral_suma(mensual, etiqueta = "TEST")

  expect_false("2020-Q1" %in% trimestral$periodo)
  expect_false("2020-Q4" %in% trimestral$periodo)
  expect_equal(trimestral$periodo, c("2020-Q2", "2020-Q3"))
})

test_that("agregar_trimestral_suma falla de forma visible ante un hueco real (no de borde)", {
  periodos <- sprintf("2020-M%02d", 1:12)
  valores <- 1:12
  mensual <- .mensual_sintetico(periodos, valores)
  mensual <- mensual[mensual$periodo != "2020-M05", ] # hueco en 2020-Q2

  expect_error(agregar_trimestral_suma(mensual, etiqueta = "TEST"), "FALLO VISIBLE.*TEST")
})

test_that("agregar_trimestral_promedio falla de forma visible ante un valor NA (celda vacia en L1), no lo descarta en silencio", {
  # Regresion del hallazgo C1 de la revision independiente 2026-09-17: la interfaz de formula de
  # aggregate() aplica na.action = na.omit por defecto y promediaba/sumaba sobre 2 meses sin
  # avisar. El periodo con NA existe (pasa el conteo de huecos), pero su valor esta ausente.
  periodos <- sprintf("2020-M%02d", 1:6)
  valores <- c(10, NA, 10, 10, 10, 10)
  mensual <- .mensual_sintetico(periodos, valores)

  expect_error(agregar_trimestral_promedio(mensual, etiqueta = "TEST"), "FALLO VISIBLE.*TEST.*ausente")
})

test_that("agregar_trimestral_suma falla de forma visible ante un valor NA (celda vacia en L1)", {
  periodos <- sprintf("2020-M%02d", 1:6)
  valores <- c(10, NA, 10, 10, 10, 10)
  mensual <- .mensual_sintetico(periodos, valores)

  expect_error(agregar_trimestral_suma(mensual, etiqueta = "TEST"), "FALLO VISIBLE.*TEST.*ausente")
})

test_that("deflactar_serie calcula valor_nominal / (valor_indice / 100)", {
  nominal <- .mensual_sintetico(sprintf("2020-M%02d", 1:4), c(100, 110, 120, 130))
  indice <- .mensual_sintetico(sprintf("2020-M%02d", 1:4), c(100, 102, 104, 106))

  real <- deflactar_serie(nominal, indice, etiqueta = "TEST")

  expect_equal(real$periodo, sprintf("2020-M%02d", 1:4))
  expect_equal(real$valor, c(100, 110 / 1.02, 120 / 1.04, 130 / 1.06))
})

test_that("deflactar_serie recorta a la intersección de períodos, no interpola ni asume cero", {
  nominal <- .mensual_sintetico(sprintf("2020-M%02d", 1:6), 1:6)
  indice <- .mensual_sintetico(sprintf("2020-M%02d", 4:9), rep(100, 6)) # solo desde abril

  real <- deflactar_serie(nominal, indice, etiqueta = "TEST")

  expect_equal(real$periodo, sprintf("2020-M%02d", 4:6))
  expect_equal(nrow(real), 3)
})

test_that("deflactar_serie falla de forma visible si no hay períodos en común", {
  nominal <- .mensual_sintetico(sprintf("2019-M%02d", 1:3), 1:3)
  indice <- .mensual_sintetico(sprintf("2020-M%02d", 1:3), c(100, 101, 102))

  expect_error(deflactar_serie(nominal, indice, etiqueta = "TEST"), "FALLO VISIBLE.*TEST")
})
