# tests/test-vintage-lib.R
#
# Ejercita src/transformacion/vintage_lib.R con un catalogo de vintages sintetico, sin tocar
# disco -- mismo patron que tests/test-l3-predictores.R. Cubre la columna `vintage_id` que
# E3/D4 (cierre de Fase 3) agrega a data/L3_master/.

library(testthat)
source(here::here("src", "transformacion", "vintage_lib.R"))

.vintages_sinteticos <- function() {
  data.frame(
    vintage_id = c("PUB_A.v1", "PUB_B.v1", "PUB_B.v2", "PUB_C.v1"),
    publicacion_id = c("PUB_A", "PUB_B", "PUB_B", "PUB_C"),
    stringsAsFactors = FALSE
  )
}

test_that("vintage_vigente devuelve la unica fila cuando hay una sola", {
  v <- .vintages_sinteticos()
  expect_equal(vintage_vigente("PUB_A", v), "PUB_A.v1")
  expect_equal(vintage_vigente("PUB_C", v), "PUB_C.v1")
})

test_that("vintage_vigente devuelve la ULTIMA fila (append-only) cuando hay varias", {
  v <- .vintages_sinteticos()
  expect_equal(vintage_vigente("PUB_B", v), "PUB_B.v2")
})

test_that("vintage_vigente falla de forma visible si la publicacion no existe", {
  v <- .vintages_sinteticos()
  expect_error(vintage_vigente("PUB_INEXISTENTE", v), "FALLO VISIBLE.*PUB_INEXISTENTE")
})

test_that("agregar_vintage_constante agrega el mismo vintage_id a todas las filas", {
  v <- .vintages_sinteticos()
  serie <- data.frame(periodo = c("2020-Q1", "2020-Q2"), valor = c(1, 2), stringsAsFactors = FALSE)
  resultado <- agregar_vintage_constante(serie, "PUB_A", v)
  expect_equal(resultado$vintage_id, c("PUB_A.v1", "PUB_A.v1"))
})

test_that("agregar_vintage_constante une varias publicaciones con ' + '", {
  v <- .vintages_sinteticos()
  serie <- data.frame(periodo = "2020-Q1", valor = 1, stringsAsFactors = FALSE)
  resultado <- agregar_vintage_constante(serie, c("PUB_A", "PUB_C"), v)
  expect_equal(resultado$vintage_id, "PUB_A.v1 + PUB_C.v1")
})

test_that("agregar_vintage_constante deduplica publicaciones repetidas", {
  v <- .vintages_sinteticos()
  serie <- data.frame(periodo = "2020-Q1", valor = 1, stringsAsFactors = FALSE)
  resultado <- agregar_vintage_constante(serie, c("PUB_A", "PUB_A"), v)
  expect_equal(resultado$vintage_id, "PUB_A.v1")
})

test_that("agregar_vintage_por_fila asigna el vintage segun la publicacion de cada fila", {
  v <- .vintages_sinteticos()
  serie <- data.frame(periodo = c("2020-Q1", "2020-Q2", "2020-Q3"), valor = c(1, 2, 3),
                       stringsAsFactors = FALSE)
  fuente <- c("PUB_A", "PUB_C", "PUB_A")
  resultado <- agregar_vintage_por_fila(serie, fuente, v)
  expect_equal(resultado$vintage_id, c("PUB_A.v1", "PUB_C.v1", "PUB_A.v1"))
})

test_that("agregar_vintage_por_fila falla de forma visible si el largo no coincide", {
  v <- .vintages_sinteticos()
  serie <- data.frame(periodo = c("2020-Q1", "2020-Q2"), valor = c(1, 2), stringsAsFactors = FALSE)
  expect_error(agregar_vintage_por_fila(serie, "PUB_A", v), "FALLO VISIBLE.*largo")
})
