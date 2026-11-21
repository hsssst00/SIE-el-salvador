# tests/test-captura-d3.R
#
# Pruebas de la logica pura de la captura fuera de ventana asistida (src/adquisicion/captura_d3_lib.R;
# ADR-007 D3, ficha F7-13). Calendario y vintages sinteticos; sin red ni navegador.

library(testthat)

source(here::here("src", "adquisicion", "verificacion_rapida.R"))
source(here::here("src", "adquisicion", "captura_d3_lib.R"))

.leer <- function(ruta) paste(readLines(ruta, encoding = "UTF-8", warn = FALSE), collapse = "\n")

.cal <- data.frame(
  variable = unname(CALENDARIO_BCR_VARIABLE[c("BCR.ISI", "BCR.ISI")]),
  mes_publicacion = c("Septiembre", "Octubre"),
  dia_publicacion = c(9L, 9L),
  periodo_referencia = c("2026-08", "2026-09"),
  stringsAsFactors = FALSE
)
.vin <- data.frame(
  publicacion_id = "BCR.ISI", vintage_id = "BCR.ISI.v2026-09", periodo_referencia_max = "2026-M08",
  stringsAsFactors = FALSE
)
.trab <- function(pid = "BCR.ISI", pmax = "2026-M08", pf = "2026-M09", estado = "NUEVO_PERIODO") {
  data.frame(publicacion_id = pid, periodo_max = pmax, estado = estado, periodo_fuente = pf,
             stringsAsFactors = FALSE)
}

test_that("FUNCION_DESCARGA_D3 cubre toda publicacion vista-serie del manifiesto y cada funcion existe", {
  man <- read.csv(here::here("data", "L0_raw", "manifiesto.csv"), stringsAsFactors = FALSE, colClasses = "character")
  vig <- do.call(rbind, lapply(unique(man$publicacion_id), function(p) { f <- man[man$publicacion_id == p, ]; f[nrow(f), ] }))
  vista <- vig$publicacion_id[startsWith(vig$url, "https://estadisticas.bcr.gob.sv/serie/")]
  expect_gt(length(vista), 0L)
  expect_setequal(names(FUNCION_DESCARGA_D3), vista)

  fuentes <- list.files(here::here("src", "adquisicion"), pattern = "\\.R$", full.names = TRUE)
  definidas <- unlist(lapply(fuentes, function(f) {
    m <- regmatches(.leer(f), gregexpr("(?m)^(descargar_\\w+)\\s*<-\\s*function", .leer(f), perl = TRUE))[[1]]
    sub("\\s*<-.*$", "", m, perl = TRUE)
  }))
  expect_true(all(FUNCION_DESCARGA_D3 %in% definidas),
              info = paste("sin definir:", paste(setdiff(FUNCION_DESCARGA_D3, definidas), collapse = ", ")))
})

test_that("candidata que cumple las tres condiciones: fecha, vintage_id y comando", {
  ev <- evaluar_candidatas_d3(.trab(), .vin, .cal, hoy = as.Date("2026-10-10"))
  expect_equal(nrow(ev), 1L)
  expect_true(ev$cumple)
  expect_equal(ev$fecha_publicacion, "2026-10-01")
  expect_equal(ev$vintage_id, "BCR.ISI.v2026-10")
  expect_equal(ev$comando, 'descargar_bcr_isi("2026-10-01")')
  expect_equal(ev$saltos, 1L)
})

test_that("(b) no cumple si el calendario lo anuncia para despues de hoy", {
  ev <- evaluar_candidatas_d3(.trab(), .vin, .cal, hoy = as.Date("2026-10-05"))
  expect_false(ev$cumple)
  expect_match(ev$motivo, "^\\(b\\).*despues de hoy")
  expect_true(is.na(ev$comando))
})

test_that("(b) no cumple si el calendario no anuncia ese periodo o la publicacion no tiene fila", {
  ev <- evaluar_candidatas_d3(.trab(pf = "2026-M10", pmax = "2026-M09"), .vin, .cal, hoy = as.Date("2026-11-20"))
  expect_false(ev$cumple)
  expect_match(ev$motivo, "^\\(b\\) el calendario no anuncia")
  ev2 <- evaluar_candidatas_d3(.trab(pid = "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA", pmax = "2026-T2", pf = "2026-T3"),
                               .vin, .cal, hoy = as.Date("2026-12-31"))
  expect_false(ev2$cumple)
  expect_match(ev2$motivo, "^\\(b\\)")
})

test_that("(c) no cumple si ya hay un vintage de ese periodo o si el vintage_id del mes ya existe", {
  v1 <- rbind(.vin, data.frame(publicacion_id = "BCR.ISI", vintage_id = "BCR.ISI.v2026-11",
                               periodo_referencia_max = "2026-M09", stringsAsFactors = FALSE))
  ev <- evaluar_candidatas_d3(.trab(), v1, .cal, hoy = as.Date("2026-10-10"))
  expect_match(ev$motivo, "^\\(c\\) ya hay un vintage")
  v2 <- rbind(.vin, data.frame(publicacion_id = "BCR.ISI", vintage_id = "BCR.ISI.v2026-10",
                               periodo_referencia_max = "2026-M08", stringsAsFactors = FALSE))
  ev2 <- evaluar_candidatas_d3(.trab(), v2, .cal, hoy = as.Date("2026-10-10"))
  expect_match(ev2$motivo, "^\\(c\\) el vintage_id BCR.ISI.v2026-10 ya existe")
})

test_that("solo entran las NUEVO_PERIODO; sin ninguna, la tabla sale vacia", {
  ev <- evaluar_candidatas_d3(.trab(estado = "SIN_NUEVO"), .vin, .cal, hoy = as.Date("2026-10-10"))
  expect_equal(nrow(ev), 0L)
})

test_that("saltos y nota del backlog: vintages intermedios y estado de cada publicacion", {
  expect_equal(saltos_periodo("2026-M07", "2026-M09"), 2L)
  expect_equal(saltos_periodo("2026-T2", "2026-T3"), 1L)
  expect_error(saltos_periodo("2026-T2", "2026-M09"), "no comparables")
  ev <- evaluar_candidatas_d3(.trab(), .vin, .cal, hoy = as.Date("2026-10-10"))
  n_si <- nota_backlog_d3(ev, "BCR.ISI", hoy = as.Date("2026-10-10"))
  expect_match(n_si, "capturada como `BCR.ISI.v2026-10`")
  expect_match(n_si, "sin vintages intermedios perdidos")
  n_no <- nota_backlog_d3(ev, character(), hoy = as.Date("2026-10-10"))
  expect_match(n_no, "no se confirmo")
})

test_that("captura_d3.R no carga verificar_l0_fisico.R con source(): termina con quit()", {
  txt <- .leer(here::here("src", "adquisicion", "captura_d3.R"))
  expect_false(grepl('source("scripts/verificar_l0_fisico.R"', txt, fixed = TRUE))
  expect_true(grepl("system2(", txt, fixed = TRUE))
})
