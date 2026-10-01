# tests/test-ut-serie.R
#
# Pruebas de src/transformacion/ut_demanda_lib.R: la construccion de la serie mensual de UT y su
# guarda de año completo (ADR-007, nota de seguimiento del 2026-09-30). Hasta esa fecha el script
# tenia valores fijos de la captura original -- 25 archivos, 295 filas, 2026 hasta julio -- y la
# primera recaptura lo rompia. Aqui NADA de eso esta escrito: lo esperado se deriva de un catalogo
# de vintages sintetico, con archivos sinteticos en un directorio temporal. No se toca L0.

library(testthat)

source(here::here("src", "transformacion", "vintage_lib.R"))
source(here::here("src", "transformacion", "ut_demanda_lib.R"))

csv_ut <- function(ruta, anio, gwh, meses = seq_along(gwh)) {
  lineas <- c(
    ',"Unidad de Transacciones, S.A. de C.V.",,,,',
    ',Demanda Total (GWH),,,,',
    ',,,,,Fecha y hora del Reporte:',
    sprintf(',,Anio: %s,,26/08/2026 5.36 PM,', anio),
    'MES,,,GWH,,',
    sprintf('%s,,,%s,,', names(MESES_ES)[meses], sprintf("%.2f", gwh))
  )
  writeLines(lineas, ruta)
  ruta
}

# Escenario sintetico: años `anios` con `n_meses[i]` meses cada uno, un vintage por año, el
# archivo en `dir_l0`. Devuelve list(vintages, manifiesto, dir_l0). Cada vintage declara en
# periodo_referencia_max el mes final de SU archivo.
escenario <- function(anios, n_meses, extras = NULL) {
  dir_l0 <- tempfile("l0_ut_"); dir.create(dir_l0)
  v <- data.frame(vintage_id = character(), publicacion_id = character(),
                  periodo_referencia_max = character(), archivo_raw = character(),
                  stringsAsFactors = FALSE)
  for (i in seq_along(anios)) {
    v <- rbind(v, agregar_vintage(dir_l0, anios[i], n_meses[i], sufijo = ""))
  }
  for (e in extras) v <- rbind(v, do.call(agregar_vintage, c(list(dir_l0), e)))
  man <- data.frame(archivo = v$archivo_raw, vintage_id = v$vintage_id,
                    publicacion_id = v$publicacion_id, stringsAsFactors = FALSE)
  list(vintages = v, manifiesto = man, dir_l0 = dir_l0)
}

agregar_vintage <- function(dir_l0, anio, n_meses, sufijo = "", declarado = n_meses,
                            nombre_anio = anio) {
  archivo <- sprintf("UT_demanda_total_%d_2026-08-26%s.csv", nombre_anio, sufijo)
  csv_ut(file.path(dir_l0, archivo), anio, 500 + (anio %% 100) + seq_len(n_meses))
  data.frame(vintage_id = sprintf("UT.DEMANDA_TOTAL_MENSUAL.v%d-%02d%s", anio, declarado, sufijo),
             publicacion_id = "UT.DEMANDA_TOTAL_MENSUAL",
             periodo_referencia_max = ut_periodo_max(anio, declarado),
             archivo_raw = archivo, stringsAsFactors = FALSE)
}

construir <- function(e) construir_serie_ut(e$vintages, e$manifiesto, e$dir_l0)

# --- Camino feliz: nada fijo ------------------------------------------------------------------

test_that("construye la serie para cualquier cobertura: no hay 25 archivos ni 295 filas escritos", {
  e <- escenario(2020:2022, c(12, 12, 3))   # 2022 parcial con 3 meses
  serie <- construir(e)
  expect_equal(nrow(serie), 27L)
  expect_equal(range(serie$periodo), c("2020-M01", "2022-M03"))
  expect_equal(names(serie), c("anio", "mes", "periodo", "gwh"))
})

test_that("un año maximo completo (12 meses) tambien pasa: el año parcial es el maximo, no 2026", {
  e <- escenario(2024:2025, c(12, 12))
  expect_equal(nrow(construir(e)), 24L)
})

test_that("con recapturas toma el archivo del ULTIMO vintage de cada año", {
  e <- escenario(2020:2022, c(12, 12, 3),
                 extras = list(list(2022, 5, sufijo = "_b")))   # recaptura de 2022 con 5 meses
  serie <- construir(e)
  expect_equal(nrow(serie), 29L)
  expect_equal(max(serie$periodo), "2022-M05")
  # el valor de mayo de 2022 solo existe en el archivo recapturado
  expect_equal(serie$gwh[serie$periodo == "2022-M05"], 500 + 22 + 5)
})

test_that("la revision de un año cerrado reemplaza al original en la serie", {
  e <- escenario(2020:2021, c(12, 12))
  # revision de 2020 sin meses nuevos: otro archivo, mismo periodo_referencia_max (12)
  rev <- agregar_vintage(e$dir_l0, 2020, 12, sufijo = "_rev")
  writeLines(sub("521.00", "999.00", readLines(file.path(e$dir_l0, rev$archivo_raw)), fixed = TRUE),
             file.path(e$dir_l0, rev$archivo_raw))
  e$vintages <- rbind(e$vintages, rev)
  e$manifiesto <- rbind(e$manifiesto, data.frame(archivo = rev$archivo_raw, vintage_id = rev$vintage_id,
                                                  publicacion_id = rev$publicacion_id))
  serie <- construir(e)
  expect_equal(nrow(serie), 24L)
  expect_equal(nrow(serie[serie$anio == 2020, ]), 12L)
  # enero de 2020 vale 999 solo en la revision; febrero no cambio
  expect_equal(serie$gwh[serie$periodo == "2020-M01"], 999)
  expect_equal(serie$gwh[serie$periodo == "2020-M02"], 500 + 20 + 2)
})

# --- Guarda de año completo -------------------------------------------------------------------

test_that("un año anterior al maximo con menos de 12 meses detiene la serie", {
  e <- escenario(2020:2022, c(12, 11, 3))   # 2021 quedo sin diciembre y ya hay 2022
  expect_error(construir(e), "anteriores al m.ximo \\(2022\\).*2021 \\(11\\)")
})

test_that("el año maximo con meses distintos de su periodo_referencia_max detiene la serie", {
  e <- escenario(2020:2021, c(12, 3))
  e$vintages$periodo_referencia_max[2] <- "2021-M07"   # el catalogo dice julio, el archivo trae marzo
  expect_error(construir(e), "2021 tiene 3, se esperaban 7")
})

test_that("un año con hueco entre el minimo y el maximo detiene la serie", {
  e <- escenario(c(2020, 2022), c(12, 3))
  expect_error(construir(e), "hueco entre 2020 y 2022")
})

test_that("el archivo ausente de L0 detiene la serie y manda a materializar", {
  e <- escenario(2020:2021, c(12, 3))
  file.remove(file.path(e$dir_l0, e$vintages$archivo_raw[1]))
  expect_error(construir(e), "materializar-l0")
})

test_that("un archivo cuyo nombre no lleva el año del vintage detiene la serie", {
  e <- escenario(2020:2021, c(12, 3))
  e$vintages <- rbind(e$vintages[1, ],
                      agregar_vintage(e$dir_l0, 2021, 3, sufijo = "_x", nombre_anio = 2019))
  e$manifiesto <- data.frame(archivo = e$vintages$archivo_raw, vintage_id = e$vintages$vintage_id,
                             publicacion_id = e$vintages$publicacion_id)
  expect_error(construir(e), "no lleva el año 2021")
})

test_that("un vintage sin exactamente una fila en el manifiesto detiene la serie", {
  e <- escenario(2020:2021, c(12, 3))
  e$manifiesto <- e$manifiesto[-1, ]
  expect_error(construir(e), "0 filas en manifiesto.csv")
})

test_that("validar_anios_cerrados_ut: cierra o se detiene, y el año maximo puede ser parcial", {
  completo <- c(sprintf("2023-M%02d", 1:12), sprintf("2024-M%02d", 1:5))
  expect_true(validar_anios_cerrados_ut(completo))
  expect_error(validar_anios_cerrados_ut(completo[-3]), "2023 \\(11\\)")
  # un unico año, parcial: nada que cerrar
  expect_true(validar_anios_cerrados_ut(sprintf("2026-M%02d", 1:7)))
})

# --- Derivaciones desde el catalogo -----------------------------------------------------------

test_that("ut_meses_esperados: 12 para los años anteriores al maximo, el mes del vintage para el maximo", {
  e <- escenario(2020:2022, c(12, 12, 7))
  mapa <- mapa_vintage_por_anio("UT.DEMANDA_TOTAL_MENSUAL", e$vintages)
  expect_equal(ut_meses_esperados(mapa, e$vintages), c("2020" = 12L, "2021" = 12L, "2022" = 7L))
})

test_that("mes_de_periodo_max valida el formato", {
  expect_equal(mes_de_periodo_max(c("2026-M07", "2025-M12")), c(7L, 12L))
  expect_error(mes_de_periodo_max("2026-Q3"), "formato AAAA-Mnn")
  expect_error(mes_de_periodo_max("2026-M13"), "fuera de 1..12")
})

test_that("ut_fecha_sintetica es el ultimo dia del mes, bisiestos incluidos", {
  expect_equal(ut_fecha_sintetica(2025, 12), "2025-12-31")
  expect_equal(ut_fecha_sintetica(2026, 7), "2026-07-31")
  expect_equal(ut_fecha_sintetica(2026, 9), "2026-09-30")
  expect_equal(ut_fecha_sintetica(2024, 2), "2024-02-29")
  expect_equal(ut_fecha_sintetica(2025, 2), "2025-02-28")
})

test_that("ut_contenido_igual compara meses y valores, no el orden ni el encabezado", {
  a <- data.frame(anio = 2026L, mes = 1:3, gwh = c(1, 2, 3))
  expect_true(ut_contenido_igual(a, a[3:1, ]))
  expect_false(ut_contenido_igual(a, transform(a, gwh = c(1, 2, 3.01))))
  expect_false(ut_contenido_igual(a, a[1:2, ]))
})

test_that("leer_ut_anual rechaza un archivo con el encabezado de datos ausente", {
  f <- tempfile(fileext = ".csv"); writeLines(c("a,b", "1,2"), f)
  expect_error(leer_ut_anual(f, 2026L), "1 l.nea que empiece con 'MES,'")
})
