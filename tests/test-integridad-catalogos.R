# tests/test-integridad-catalogos.R
#
# Ejercita src/validacion/integridad_catalogos_reglas.R con datos sintéticos, sin tocar disco.
# Mismo patrón que tests/test-validar-l2-pib.R. No duplica tests/test-integridad-referencial.R,
# que sigue cubriendo (con datos REALES) la parte que esta función no toca: 01_publicaciones/*.yaml.

library(testthat)
source(here::here("src", "validacion", "integridad_catalogos_reglas.R"))

.caso_base <- function() {
  list(
    series = data.frame(
      serie_id = c("A.1", "A.2"),
      publicacion_id = c("PUB.1", "PUB.1"),
      metodologia_id = c("MET.1", ""),
      stringsAsFactors = FALSE
    ),
    transf = data.frame(transf_id = c("T001", "T002"), stringsAsFactors = FALSE),
    master = data.frame(
      series_master_id = c("M.1", "M.2"),
      transf_id = c("T001", ""),
      series_insumo_ids = c("A.1, A.2", "A.1"),
      stringsAsFactors = FALSE
    ),
    vintages = data.frame(
      vintage_id = c("V.1"),
      publicacion_id = c("PUB.1"),
      stringsAsFactors = FALSE
    ),
    rupturas = data.frame(
      ruptura_id = c("R.1", "R.2"),
      series_afectadas = c("A.1", "PUB.1"),
      tipo_referencia = c("serie_id", "publicacion_id"),
      stringsAsFactors = FALSE
    ),
    pubs = c("PUB.1", "PUB.2"),
    mets = c("MET.1", "MET.2")
  )
}

.correr <- function(caso) {
  validar_integridad_catalogos(caso$series, caso$transf, caso$master, caso$vintages,
                                caso$rupturas, caso$pubs, caso$mets)
}

test_that("caso base, todas las aristas resuelven: sin errores", {
  r <- .correr(.caso_base())
  expect_equal(r$errores, character(0))
})

test_that("03_series.publicacion_id huérfano produce error", {
  caso <- .caso_base()
  caso$series$publicacion_id[1] <- "PUB.INEXISTENTE"
  r <- .correr(caso)
  expect_true(any(grepl("03_series.publicacion_id", r$errores)))
})

test_that("03_series.metodologia_id vacío no es error (opcional)", {
  caso <- .caso_base()
  caso$series$metodologia_id <- c("", "")
  r <- .correr(caso)
  expect_equal(r$errores, character(0))
})

test_that("03_series.metodologia_id huérfano (no vacío) produce error", {
  caso <- .caso_base()
  caso$series$metodologia_id[1] <- "MET.INEXISTENTE"
  r <- .correr(caso)
  expect_true(any(grepl("03_series.metodologia_id", r$errores)))
})

test_that("05_series_master.transf_id huérfano produce error", {
  caso <- .caso_base()
  caso$master$transf_id[1] <- "T999"
  r <- .correr(caso)
  expect_true(any(grepl("05_series_master.transf_id", r$errores)))
})

test_that("05_series_master.series_insumo_ids con un token huérfano produce error", {
  caso <- .caso_base()
  caso$master$series_insumo_ids[1] <- "A.1, A.999"
  r <- .correr(caso)
  expect_true(any(grepl("series_insumo_ids", r$errores)))
})

test_that("08_vintages.publicacion_id huérfano produce error", {
  caso <- .caso_base()
  caso$vintages$publicacion_id[1] <- "PUB.INEXISTENTE"
  r <- .correr(caso)
  expect_true(any(grepl("08_vintages.publicacion_id", r$errores)))
})

test_that("09_rupturas.series_afectadas resuelve segun tipo_referencia (serie_id vs publicacion_id)", {
  caso <- .caso_base()
  caso$rupturas$series_afectadas[1] <- "A.999"  # tipo_referencia = serie_id, no resuelve
  r <- .correr(caso)
  expect_true(any(grepl("series_afectadas", r$errores)))
})

test_that("09_rupturas.tipo_referencia desconocido produce error, no se ignora", {
  caso <- .caso_base()
  caso$rupturas$tipo_referencia[1] <- "otro_tipo"
  r <- .correr(caso)
  expect_true(any(grepl("tipo_referencia conocido", r$errores)))
})

test_that("multiples series_master apuntando al mismo transf_id no confunden el agente", {
  caso <- .caso_base()
  caso$master <- rbind(caso$master, data.frame(
    series_master_id = "M.3", transf_id = "T002", series_insumo_ids = "A.2",
    stringsAsFactors = FALSE
  ))
  r <- .correr(caso)
  expect_equal(r$errores, character(0))
})
