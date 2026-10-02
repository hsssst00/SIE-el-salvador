# tests/test-verificacion-rapida.R
#
# Pruebas de la logica pura de `make raw-rapido` (src/adquisicion/verificacion_rapida.R):
# nivel 1 por calendario y comparacion del nivel 2. Calendario sintetico; sin red ni navegador.

library(testthat)

source(here::here("src", "adquisicion", "verificacion_rapida.R"))

.cal <- data.frame(
  variable = c("Índice Subyacente de Inflación (ISI) Base dic. 2009.", rep("Índice Subyacente de Inflación (ISI) Base dic. 2009.", 2)),
  mes_publicacion = c("Septiembre", "Octubre", "Noviembre"),
  dia_publicacion = c(9L, 9L, 11L),
  periodo_referencia = c("2026-08", "2026-09", "2026-10"),
  stringsAsFactors = FALSE
)

test_that("clave_periodo entiende M, mes pelado y T, y rechaza lo demas", {
  expect_equal(clave_periodo("2026-M06")$n, 2026L * 12L + 6L)
  expect_equal(clave_periodo("2026-07")$n, 2026L * 12L + 7L)
  expect_equal(clave_periodo("2026-T2"), list(tipo = "T", n = 2026L * 4L + 2L))
  expect_null(clave_periodo("2026"))
})

test_that("TOCA si una fecha anunciada de un periodo posterior ya paso", {
  e <- estado_calendario("BCR.ISI", "2026-M08", .cal, hoy = as.Date("2026-10-10"))
  expect_equal(e$estado, "TOCA")
})

test_that("NO_TOCA si todas las fechas posteriores son futuras", {
  e <- estado_calendario("BCR.ISI", "2026-M08", .cal, hoy = as.Date("2026-10-02"))
  expect_equal(e$estado, "NO_TOCA")
  expect_match(e$detalle, "2026-10-09")
})

test_that("SIN_CALENDARIO ante la duda: sin mapeo, sin periodo posterior, otro año", {
  expect_equal(estado_calendario("BCR.PIB_T.NOMINAL", "2026-T2", .cal, hoy = as.Date("2026-10-02"))$estado,
               "SIN_CALENDARIO")
  expect_equal(estado_calendario("BCR.ISI", "2026-M10", .cal, hoy = as.Date("2026-10-02"))$estado,
               "SIN_CALENDARIO")
  expect_equal(estado_calendario("BCR.ISI", "2026-M08", .cal, hoy = as.Date("2027-01-05"))$estado,
               "SIN_CALENDARIO")
})

test_that("un periodo trimestral no se compara contra filas mensuales", {
  cal <- .cal
  e <- estado_calendario("BCR.ISI", "2026-T2", cal, hoy = as.Date("2026-10-10"))
  expect_equal(e$estado, "SIN_CALENDARIO")
})

test_that("sondeo: nuevo, igual, y falla visible si es anterior o incomparable", {
  expect_equal(estado_sondeo("2026-M08", "2026-M09")$estado, "NUEVO_PERIODO")
  expect_equal(estado_sondeo("2026-T2", "2026-T2")$estado, "SIN_NUEVO")
  expect_error(estado_sondeo("2026-M08", "2026-M07"), "FALLO VISIBLE")
  expect_error(estado_sondeo("2026-M08", "2026-T3"), "FALLO VISIBLE")
})
