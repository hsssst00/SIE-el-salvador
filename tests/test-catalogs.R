# tests/test-catalogs.R
library(testthat)
library(jsonlite)

test_that("datapackage.json es JSON valido", {
  expect_no_error(
    jsonlite::fromJSON(here::here("catalogos", "datapackage.json"), simplifyVector = FALSE)
  )
})

test_that("todos los catalogos declarados en datapackage.json existen", {
  dp <- jsonlite::fromJSON(here::here("catalogos", "datapackage.json"), simplifyVector = FALSE)
  rutas <- vapply(dp$resources, function(r) here::here("catalogos", r$path), character(1))
  expect_true(all(file.exists(rutas)))
})

test_that("los catalogos con esquema cerrado tienen las columnas declaradas", {
  dp <- jsonlite::fromJSON(here::here("catalogos", "datapackage.json"), simplifyVector = FALSE)
  cerrados <- Filter(function(r) grepl("^cerrado", r$estado_esquema), dp$resources)
  for (r in cerrados) {
    if (grepl("\\.csv$", r$path)) {
      cols_esperadas <- vapply(r$schema$fields, function(f) f$name, character(1))
      cols_reales <- names(read.csv(here::here("catalogos", r$path), nrows = 0))
      expect_equal(cols_reales, cols_esperadas, info = paste("catalogo:", r$name))
    }
  }
})

test_that("el manifiesto de L0 tiene las columnas declaradas", {
  cols_esperadas <- c("archivo","fuente","url","fecha_descarga","sha256","sha256_norm",
                       "tamano_bytes","codigo_http","vintage_id","publicacion_id")
  cols_reales <- names(read.csv(here::here("data", "L0_raw", "manifiesto.csv"), nrows = 0))
  expect_equal(cols_reales, cols_esperadas)
})
