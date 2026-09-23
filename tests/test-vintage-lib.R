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

# --- agregar_vintage_por_anio() (UT en la matriz, 2026-09-23) ---------------------------------
# Catalogo separado: estas pruebas necesitan `periodo_referencia_max`, que .vintages_sinteticos()
# no declara porque las funciones anteriores no lo usan.

.vintages_anuales <- function() {
  data.frame(
    vintage_id = c("PUB_D.v2002-12", "PUB_D.v2003-12", "PUB_D.v2004-07"),
    publicacion_id = rep("PUB_D", 3),
    periodo_referencia_max = c("2002-M12", "2003-M12", "2004-M07"),
    stringsAsFactors = FALSE
  )
}

test_that("agregar_vintage_por_anio asigna a cada fila el vintage de su año, mensual y trimestral", {
  v <- .vintages_anuales()
  mensual <- data.frame(periodo = c("2002-M01", "2002-M12", "2003-M06", "2004-M07"),
                        valor = 1:4, stringsAsFactors = FALSE)
  expect_equal(agregar_vintage_por_anio(mensual, "PUB_D", v)$vintage_id,
               c("PUB_D.v2002-12", "PUB_D.v2002-12", "PUB_D.v2003-12", "PUB_D.v2004-07"))
  trimestral <- data.frame(periodo = c("2002-Q1", "2003-Q4"), valor = c(1, 2),
                           stringsAsFactors = FALSE)
  expect_equal(agregar_vintage_por_anio(trimestral, "PUB_D", v)$vintage_id,
               c("PUB_D.v2002-12", "PUB_D.v2003-12"))
})

test_that("agregar_vintage_por_anio NO colapsa al vintage vigente", {
  # La razon de ser de esta funcion: vintage_vigente() etiquetaria toda la serie con el ultimo
  # archivo (2004), que no produjo las observaciones de 2002-2003.
  v <- .vintages_anuales()
  serie <- data.frame(periodo = c("2002-M01", "2004-M01"), valor = c(1, 2), stringsAsFactors = FALSE)
  resultado <- agregar_vintage_por_anio(serie, "PUB_D", v)
  expect_false(all(resultado$vintage_id == vintage_vigente("PUB_D", v)))
  expect_equal(length(unique(resultado$vintage_id)), 2L)
})

test_that("agregar_vintage_por_anio falla de forma visible ante un año sin vintage", {
  v <- .vintages_anuales()
  serie <- data.frame(periodo = c("2002-M01", "2005-M01"), valor = c(1, 2), stringsAsFactors = FALSE)
  expect_error(agregar_vintage_por_anio(serie, "PUB_D", v), "FALLO VISIBLE.*2005")
})

test_that("agregar_vintage_por_anio falla de forma visible ante dos vintages del mismo año", {
  v <- .vintages_anuales()
  v <- rbind(v, data.frame(vintage_id = "PUB_D.v2003-06", publicacion_id = "PUB_D",
                           periodo_referencia_max = "2003-M06", stringsAsFactors = FALSE))
  serie <- data.frame(periodo = "2003-M01", valor = 1, stringsAsFactors = FALSE)
  expect_error(agregar_vintage_por_anio(serie, "PUB_D", v), "FALLO VISIBLE.*2003")
})

test_that("agregar_vintage_por_anio falla de forma visible si la publicacion no tiene vintages", {
  v <- .vintages_anuales()
  serie <- data.frame(periodo = "2002-M01", valor = 1, stringsAsFactors = FALSE)
  expect_error(agregar_vintage_por_anio(serie, "PUB_INEXISTENTE", v),
               "FALLO VISIBLE.*PUB_INEXISTENTE")
})

# --- mapa_vintage_por_anio() (compartida con verificar_fuente_celda.R, 2026-09-23) ------------

test_that("mapa_vintage_por_anio devuelve el vintage de cada año, nombrado por año", {
  mapa <- mapa_vintage_por_anio("PUB_D", .vintages_anuales())
  expect_equal(names(mapa), c("2002", "2003", "2004"))
  expect_equal(unname(mapa[["2004"]]), "PUB_D.v2004-07")
})

test_that("mapa_vintage_por_anio falla de forma visible ante un periodo_referencia_max sin año", {
  v <- .vintages_anuales()
  v$periodo_referencia_max[2] <- "M12"
  expect_error(mapa_vintage_por_anio("PUB_D", v), "FALLO VISIBLE.*4 digitos")
})
