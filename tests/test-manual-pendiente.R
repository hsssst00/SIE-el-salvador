# tests/test-manual-pendiente.R
#
# Pruebas del estado MANUAL_PENDIENTE de `make raw` (src/adquisicion/manual_pendiente.R): UT se
# lista con los dias desde su ultima captura registrada y los años anteriores al actual que no
# llegan a diciembre. Manifiesto y catalogo sinteticos; sin red, sin tocar L0.

library(testthat)

source(here::here("src", "adquisicion", "manual_pendiente.R"))

.PUB <- "UT.DEMANDA_TOTAL_MENSUAL"

.vintages_ut <- function(periodos) {
  data.frame(vintage_id = paste0(.PUB, ".v", seq_along(periodos)), publicacion_id = .PUB,
             periodo_referencia_max = periodos, stringsAsFactors = FALSE)
}
.manifiesto_ut <- function(fechas) {
  data.frame(publicacion_id = .PUB, fecha_descarga = fechas, stringsAsFactors = FALSE)
}

test_that("dias desde la ultima captura registrada: el mayor fecha_descarga del manifiesto", {
  e <- estado_manual_pendiente(.PUB, .manifiesto_ut(c("2026-08-26", "2026-09-10")),
                               .vintages_ut(c("2025-M12", "2026-M07")), hoy = as.Date("2026-09-30"))
  expect_equal(e$ultima_captura, as.Date("2026-09-10"))
  expect_equal(e$dias, 20L)
})

test_that("sin años anteriores a medias: ninguno", {
  e <- estado_manual_pendiente(.PUB, .manifiesto_ut("2026-08-26"),
                               .vintages_ut(c("2025-M12", "2026-M07")), hoy = as.Date("2026-09-30"))
  expect_length(e$anios_sin_diciembre, 0L)
  expect_match(formatear_manual_pendiente(e), "no llegan a diciembre: ninguno", fixed = TRUE)
})

test_that("el año en curso parcial no cuenta; un año anterior sin diciembre si", {
  v <- .vintages_ut(c("2025-M12", "2026-M11"))
  # en octubre de 2026 el parcial 2026 es el año en curso: no es anomalia
  e1 <- estado_manual_pendiente(.PUB, .manifiesto_ut("2026-10-02"), v, hoy = as.Date("2026-10-05"))
  expect_length(e1$anios_sin_diciembre, 0L)
  # en enero de 2027 el mismo vintage deja a 2026 sin diciembre
  e2 <- estado_manual_pendiente(.PUB, .manifiesto_ut("2026-12-02"), v, hoy = as.Date("2027-01-05"))
  expect_equal(e2$anios_sin_diciembre, c("2026" = 11L))
  expect_match(formatear_manual_pendiente(e2), "2026 (último mes con dato: 11)", fixed = TRUE)
})

test_that("usa el vintage vigente de cada año: una recaptura que cierra diciembre limpia el aviso", {
  v <- .vintages_ut(c("2025-M12", "2026-M11", "2026-M12"))   # 2026 se recapturo hasta diciembre
  e <- estado_manual_pendiente(.PUB, .manifiesto_ut("2027-01-03"), v, hoy = as.Date("2027-01-05"))
  expect_length(e$anios_sin_diciembre, 0L)
})

test_that("varios años anteriores a medias se listan todos", {
  v <- .vintages_ut(c("2024-M10", "2025-M09", "2026-M07"))
  e <- estado_manual_pendiente(.PUB, .manifiesto_ut("2026-08-26"), v, hoy = as.Date("2026-09-30"))
  expect_equal(e$anios_sin_diciembre, c("2024" = 10L, "2025" = 9L))
})

test_that("una publicacion sin filas en el manifiesto falla de forma visible", {
  expect_error(estado_manual_pendiente("OTRA", .manifiesto_ut("2026-08-26"),
                                       .vintages_ut("2026-M07")), "FALLO VISIBLE.*OTRA")
})

test_that("UT esta declarada como captura manual periodica", {
  expect_true(.PUB %in% PUBLICACIONES_MANUALES_PERIODICAS)
})
