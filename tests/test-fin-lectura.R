# tests/test-fin-lectura.R
#
# Pruebas sinteticas del fin de lectura por vintage (src/transformacion/fin_lectura_lib.R; F6-19 de
# decisiones_fase6.md). No se lee data/: las hojas son data.frames armados aca, con la misma forma
# que devuelve read_excel(col_names = FALSE) (fila de anios, fila de periodos, fila de dato).

library(testthat)

source(here::here("src", "transformacion", "fin_lectura_lib.R"))

ROMANOS <- c(I = 1L, II = 2L, III = 3L, IV = 4L)
MESES <- c(Ene = 1L, Feb = 2L, Mar = 3L, Abr = 4L, May = 5L, Jun = 6L,
           Jul = 7L, Ago = 8L, Sep = 9L, Oct = 10L, Nov = 11L, Dic = 12L)

# Hoja trimestral: columna A = rotulos; desde B, trimestres de 2025-I a 2026-II. El anio solo esta
# escrito en el primer trimestre de cada anio (como en los libros del BCR).
.hoja_trimestral <- function(n_trim = 6L, marca_ultimo = " (e)") {
  anios <- c("2025", NA, NA, NA, "2026", NA, NA, NA)[seq_len(n_trim)]
  trims <- rep(c("I", "II", "III", "IV"), 2)[seq_len(n_trim)]
  trims[n_trim] <- paste0(trims[n_trim], marca_ultimo)
  datos <- as.character(100 + seq_len(n_trim))
  filas <- list(c("Anio", anios), c("Trimestre", trims), c("PIB", datos))
  as.data.frame(do.call(rbind, filas), stringsAsFactors = FALSE)
}

test_that("toma la columna del periodo_referencia_max del vintage, no la del registro", {
  raw <- .hoja_trimestral(6L)
  expect_identical(columna_fin_lectura(raw, "B", 1L, 2L, 3L, "2026-T2", "T", ROMANOS, "X", "f.xlsx"), 7L)
  # Un vintage mas viejo (termina en 2026-T1) se lee hasta su propio fin: corte_fase5 no cambia.
  raw_viejo <- .hoja_trimestral(5L)
  expect_identical(columna_fin_lectura(raw_viejo, "B", 1L, 2L, 3L, "2026-T1", "T", ROMANOS, "X", "f.xlsx"), 6L)
})

test_that("stop() si el periodo de 08 no aparece o aparece mas de una vez", {
  raw <- .hoja_trimestral(6L)
  expect_error(columna_fin_lectura(raw, "B", 1L, 2L, 3L, "2026-T3", "T", ROMANOS, "X", "f.xlsx"),
               "aparece 0 vez")
  doble <- cbind(raw, data.frame(V8 = c("2026", "II", ""), stringsAsFactors = FALSE))
  expect_error(columna_fin_lectura(doble, "B", 1L, 2L, 3L, "2026-T2", "T", ROMANOS, "X", "f.xlsx"),
               "aparece 2 vez")
})

test_that("stop() si hay datos despues del periodo de 08 (08 atrasado respecto del libro)", {
  raw <- .hoja_trimestral(6L)
  expect_error(columna_fin_lectura(raw, "B", 1L, 2L, 3L, "2026-T1", "T", ROMANOS, "X", "f.xlsx"),
               "despues de 2026-T1 \\(columna G\\)")
  # Celdas vacias despues del fin no cuentan como datos.
  con_vacias <- cbind(raw, data.frame(V8 = c(NA, NA, ""), V9 = c(NA, NA, NA), stringsAsFactors = FALSE))
  expect_identical(columna_fin_lectura(con_vacias, "B", 1L, 2L, 3L, "2026-T2", "T", ROMANOS, "X", "f.xlsx"), 7L)
})

test_that("el formato del periodo tiene que ser el de la frecuencia del extractor", {
  raw <- .hoja_trimestral(6L)
  expect_error(columna_fin_lectura(raw, "B", 1L, 2L, 3L, "2026-M06", "T", ROMANOS, "X", "f.xlsx"),
               "no tiene el formato AAAA-Tn")
  expect_error(columna_fin_lectura(raw, "B", 1L, 2L, 3L, "2026-Q2", "T", ROMANOS, "X", "f.xlsx"),
               "no tiene el formato")
  expect_error(columna_fin_lectura(raw, "B", 1L, 2L, 3L, "2026-T2", "A", ROMANOS, "X", "f.xlsx"),
               "tipo de frecuencia desconocido")
})

test_that("mensual: anios rellenados desde la columna 2 aunque col_inicio caiga a mitad de anio", {
  anios <- c("Anio", "2025", rep(NA, 11), "2026", rep(NA, 6))
  meses <- c("Mes", names(MESES), names(MESES)[1:7])
  datos <- c("IPC", as.character(seq_len(19)))
  raw <- as.data.frame(rbind(anios, meses, datos), stringsAsFactors = FALSE)
  # col_inicio en M (dic-2025), como ONEC.IPC: el anio de M sale del relleno desde B.
  expect_identical(columna_fin_lectura(raw, "M", 1L, 2L, 3L, "2026-M07", "M", MESES, "X", "f.xlsx"), 20L)
  # Un mes anterior a col_inicio no es candidato.
  expect_error(columna_fin_lectura(raw, "M", 1L, 2L, 3L, "2025-M03", "M", MESES, "X", "f.xlsx"),
               "aparece 0 vez")
})

test_that("periodo_max_de_archivo() exige una sola fila en 08 con periodo declarado", {
  v <- data.frame(vintage_id = c("P.v1", "P.v2", "Q.v1"),
                  archivo_raw = c("p_1.xlsx", "p_2.xlsx", "q_1.xlsx"),
                  periodo_referencia_max = c("2026-T1", "2026-T2", NA), stringsAsFactors = FALSE)
  expect_identical(periodo_max_de_archivo("data/L0_raw/p_2.xlsx", v), "2026-T2")
  expect_error(periodo_max_de_archivo("data/L0_raw/z.xlsx", v), "tiene 0 fila")
  expect_error(periodo_max_de_archivo("data/L0_raw/q_1.xlsx", v), "no declara periodo_referencia_max")
})

test_that("los extractores de .xlsx con col_fin usan el fin de lectura de F6-19", {
  extractores <- c("extraer_bcr_pib.R", "extraer_bcr_ivae.R", "extraer_bcr_remesas.R",
                   "extraer_onec_ipc.R", "extraer_bcr_ipp.R", "extraer_bcr_balanza_comercial.R",
                   "extraer_bcr_itcer.R", "extraer_bcr_indices_precios_comercio_exterior.R")
  for (f in extractores) {
    src <- readLines(here::here("src", "transformacion", f), warn = FALSE, encoding = "UTF-8")
    expect_true(any(grepl("columna_fin_lectura(", src, fixed = TRUE)), info = f)
    expect_true(any(grepl("periodo_max_de_archivo(path, vintages)", src, fixed = TRUE)), info = f)
    expect_false(any(grepl("col_to_idx(col_fin)", src, fixed = TRUE)), info = f)
  }
})
