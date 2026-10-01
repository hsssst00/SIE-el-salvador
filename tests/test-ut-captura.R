# tests/test-ut-captura.R
#
# Pruebas de registrar_ut_demanda_anual() (src/adquisicion/ut.R), el mecanismo de captura manual
# trimestral de UT (ADR-007, nota de seguimiento del 2026-09-30). Cada prueba corre en un
# repositorio de mentira (directorio temporal con data/L0_raw/manifiesto.csv y
# catalogos/08_vintages.csv): NINGUNA toca la L0 ni los catalogos reales -- mismo patron que
# tests/test-adquisicion.R. Los CSV son sinteticos pero con la estructura real de UT, incluida la
# linea "Fecha y hora del Reporte" que hace cambiar el hash de cada descarga.
#
# El historial previo se SIEMBRA escribiendo el archivo y sus filas a mano, en vez de llamar dos
# veces a la funcion: registrar_descarga() nombra el archivo {FUENTE}_{desc}_{fecha_descarga}, con
# la fecha de hoy, y dos capturas del mismo año el mismo dia colisionan por nombre (ver la ultima
# prueba de tests/test-adquisicion.R). En la realidad las ventanas distan meses.

library(testthat)

source(here::here("src", "adquisicion", "ut.R"))

.COLS_MANIFIESTO <- paste(
  c("archivo", "fuente", "url", "fecha_descarga", "sha256", "sha256_norm",
    "tamano_bytes", "codigo_http", "vintage_id", "publicacion_id"), collapse = ",")
.COLS_VINTAGES <- paste(
  c("vintage_id", "publicacion_id", "fecha_publicacion", "periodo_referencia_max",
    "documento_fuente", "archivo_raw", "sha256", "sha256_norm", "alcance_revision",
    "notas"), collapse = ",")

con_repo_ut <- function(expr) {
  d <- tempfile("repo_ut_")
  dir.create(file.path(d, "data", "L0_raw"), recursive = TRUE)
  dir.create(file.path(d, "catalogos"), recursive = TRUE)
  writeLines(.COLS_MANIFIESTO, file.path(d, "data", "L0_raw", "manifiesto.csv"))
  writeLines(.COLS_VINTAGES, file.path(d, "catalogos", "08_vintages.csv"))
  anterior <- setwd(d)
  on.exit(setwd(anterior), add = TRUE)
  force(expr)
}

# CSV con la estructura real de UT. `gwh` trae un valor por mes (de enero en adelante, salvo que
# se pase `meses`); `hora` es la hora del reporte, que cambia en cada descarga; `anio_interno`
# es el campo "Año:" que el archivo declara (NA = vacio, como 2002/2003).
csv_ut <- function(ruta, anio, gwh, hora = "5.36 PM", anio_interno = anio, eol = "\n",
                   meses = seq_along(gwh)) {
  lineas <- c(
    ',"Unidad de Transacciones, S.A. de C.V.",,,,',
    ',Demanda Total (GWH),,,,',
    ',,,,,Fecha y hora del Reporte:',
    sprintf(',,Anio: %s,,26/08/2026 %s,', ifelse(is.na(anio_interno), "", anio_interno), hora),
    'MES,,,GWH,,',
    sprintf('%s,,,%s,,', names(MESES_ES)[meses], sprintf("%.2f", gwh))
  )
  writeBin(charToRaw(paste0(paste(lineas, collapse = eol), eol)), ruta)
  ruta
}

# Valores GWH sinteticos y estables: mes m del año a -> 500 + a %% 100 + m.
gwh_de <- function(anio, n = 12) 500 + (anio %% 100) + seq_len(n)

# Siembra un vintage previo (archivo en L0 + una fila en cada catalogo), como lo dejaria una
# captura anterior. `fecha_captura` va en el nombre del archivo y en fecha_descarga.
sembrar_ut <- function(anio, gwh = gwh_de(anio), fecha_captura = "2026-08-26", ...) {
  mes_max <- length(gwh)
  periodo <- ut_periodo_max(anio, mes_max)
  fecha_pub <- ut_fecha_sintetica(anio, mes_max)
  vid <- paste0(PUBLICACION_UT, ".v", substr(fecha_pub, 1, 7))
  archivo <- sprintf("UT_demanda_total_%d_%s.csv", anio, fecha_captura)
  ruta <- csv_ut(file.path("data", "L0_raw", archivo), anio, gwh, ...)
  sha <- calcular_sha256_raw(readBin(ruta, "raw", file.info(ruta)$size))
  write.table(data.frame(archivo = archivo, fuente = "UT", url = "u", fecha_descarga = fecha_captura,
                         sha256 = sha, sha256_norm = sha, tamano_bytes = file.info(ruta)$size,
                         codigo_http = 200L, vintage_id = vid, publicacion_id = PUBLICACION_UT,
                         stringsAsFactors = FALSE),
              ruta_manifiesto, sep = ",", append = TRUE, row.names = FALSE, col.names = FALSE,
              qmethod = "double")
  write.table(data.frame(vintage_id = vid, publicacion_id = PUBLICACION_UT,
                         fecha_publicacion = fecha_pub, periodo_referencia_max = periodo,
                         documento_fuente = "u", archivo_raw = archivo, sha256 = sha,
                         sha256_norm = sha, alcance_revision = "semilla", notas = "",
                         stringsAsFactors = FALSE),
              ruta_vintages, sep = ",", append = TRUE, row.names = FALSE, col.names = FALSE,
              qmethod = "double")
  invisible(vid)
}

# Un archivo recien bajado, fuera de L0 (la carpeta de descargas de Harold).
descargado <- function(anio, gwh = gwh_de(anio), nombre = sprintf("%d.csv", anio), ...) {
  csv_ut(file.path(tempdir(), nombre), anio, gwh, ...)
}

registrar <- function(...) suppressMessages(registrar_ut_demanda_anual(...))

estado_catalogos <- function() {
  list(manifiesto = readLines(ruta_manifiesto), vintages = readLines(ruta_vintages),
       l0 = sort(list.files("data/L0_raw")))
}

# --- Caso 2: vintage nuevo; periodo_referencia_max sale del contenido -------------------------

test_that("un año nuevo: periodo_referencia_max es el ultimo mes con dato y la fecha es fin de ese mes", {
  con_repo_ut({
    r25 <- registrar(descargado(2025), 2025L)
    expect_true(r25$vintage_nuevo)
    expect_equal(r25$vintage_id, "UT.DEMANDA_TOTAL_MENSUAL.v2025-12")

    # el año parcial NO se declara: sale de que el archivo trae 7 meses
    r26 <- registrar(descargado(2026, gwh_de(2026, 7)), 2026L)
    expect_equal(r26$vintage_id, "UT.DEMANDA_TOTAL_MENSUAL.v2026-07")

    vin <- read.csv(ruta_vintages, colClasses = "character")
    expect_equal(vin$fecha_publicacion, c("2025-12-31", "2026-07-31"))
    expect_equal(vin$periodo_referencia_max, c("2025-M12", "2026-M07"))
    expect_true(all(grepl("SINT.TICA", vin$notas)))
    expect_equal(nrow(read.csv(ruta_manifiesto)), 2L)
  })
})

test_that("un año bisiesto parcial termina el 29 de febrero", {
  con_repo_ut({
    r <- registrar(descargado(2028, gwh_de(2028, 2)), 2028L)
    expect_equal(r$vintage_id, "UT.DEMANDA_TOTAL_MENSUAL.v2028-02")
    expect_equal(read.csv(ruta_vintages, colClasses = "character")$fecha_publicacion, "2028-02-29")
  })
})

test_that("recaptura del año parcial con meses nuevos: vintage nuevo, sin colision", {
  con_repo_ut({
    sembrar_ut(2026, gwh_de(2026, 7))
    nuevo <- registrar(descargado(2026, gwh_de(2026, 9), hora = "10.02 AM"), 2026L,
                       fecha_captura = as.Date("2026-10-02"))
    expect_true(nuevo$vintage_nuevo)
    expect_equal(nuevo$vintage_id, "UT.DEMANDA_TOTAL_MENSUAL.v2026-09")

    vin <- read.csv(ruta_vintages, colClasses = "character")
    expect_equal(vin$vintage_id, c("UT.DEMANDA_TOTAL_MENSUAL.v2026-07", "UT.DEMANDA_TOTAL_MENSUAL.v2026-09"))
    # fecha sintetica = fin del ultimo mes con dato (septiembre), NO la fecha de captura
    expect_equal(vin$fecha_publicacion[2], "2026-09-30")
    expect_equal(vin$periodo_referencia_max[2], "2026-M09")
    expect_false(grepl("ya existe", vin$notas[2]))
    # los dos archivos del año conviven en L0; el vigente del año pasa a ser el nuevo
    expect_equal(length(list.files("data/L0_raw", pattern = "^UT_demanda_total_2026_")), 2L)
    mapa <- mapa_vintage_por_anio(PUBLICACION_UT, leer_vintages(ruta_vintages))
    expect_equal(unname(mapa[["2026"]]), "UT.DEMANDA_TOTAL_MENSUAL.v2026-09")
  })
})

test_that("el año anterior que cierra en diciembre da 31-dic aunque se capture en enero", {
  con_repo_ut({
    sembrar_ut(2026, gwh_de(2026, 11))
    nuevo <- registrar(descargado(2026, gwh_de(2026, 12)), 2026L, fecha_captura = as.Date("2027-04-02"))
    expect_equal(nuevo$vintage_id, "UT.DEMANDA_TOTAL_MENSUAL.v2026-12")
    expect_equal(read.csv(ruta_vintages, colClasses = "character")$fecha_publicacion[2], "2026-12-31")
  })
})

# --- Caso 1: mismo contenido -> no se registra nada -------------------------------------------

test_that("archivo con los mismos meses y valores pero otra hora de reporte: no registra nada", {
  con_repo_ut({
    sembrar_ut(2026, gwh_de(2026, 7), hora = "5.36 PM")
    nuevo <- descargado(2026, gwh_de(2026, 7), hora = "9.12 AM", eol = "\r\n")

    # la premisa de la decision: los archivos NO son identicos por hash
    en_l0 <- file.path("data/L0_raw", list.files("data/L0_raw", pattern = "^UT_demanda"))
    expect_false(identical(unname(tools::md5sum(nuevo)), unname(tools::md5sum(en_l0))))

    antes <- estado_catalogos()
    res <- expect_message(registrar_ut_demanda_anual(nuevo, 2026L), "Sin cambios")
    expect_false(res$vintage_nuevo)
    expect_equal(res$vintage_previo, "UT.DEMANDA_TOTAL_MENSUAL.v2026-07")
    # "el script corrio y comparo" no es indistinguible de "no hizo nada": no se escribe, pero lo dice
    expect_identical(estado_catalogos(), antes)
  })
})

test_that("un valor GWH distinto es contenido distinto aunque los meses sean los mismos", {
  con_repo_ut({
    sembrar_ut(2025)
    g <- gwh_de(2025); g[3] <- g[3] + 0.01
    res <- registrar(descargado(2025, g), 2025L, fecha_captura = as.Date("2026-10-02"))
    expect_true(res$vintage_nuevo)
  })
})

# --- Caso 3: revision sin meses nuevos -> fecha de captura y nota -----------------------------

test_that("revision sin meses nuevos: usa la fecha de captura y deja el motivo en notas_vintage", {
  con_repo_ut({
    sembrar_ut(2025)
    g <- gwh_de(2025); g[5] <- g[5] + 1
    res <- registrar(descargado(2025, g), 2025L, fecha_captura = as.Date("2026-10-02"))
    expect_true(res$vintage_nuevo)
    expect_equal(res$vintage_id, "UT.DEMANDA_TOTAL_MENSUAL.v2026-10")

    vin <- read.csv(ruta_vintages, colClasses = "character")
    expect_equal(vin$fecha_publicacion[2], "2026-10-02")
    expect_equal(vin$periodo_referencia_max[2], "2025-M12")
    expect_match(vin$notas[2], "UT.DEMANDA_TOTAL_MENSUAL.v2025-12) ya existe", fixed = TRUE)
    expect_match(vin$notas[2], "fecha de captura (2026-10-02)", fixed = TRUE)
    # y la resolucion por año toma esta revision, no el vintage original
    mapa <- mapa_vintage_por_anio(PUBLICACION_UT, leer_vintages(ruta_vintages))
    expect_equal(unname(mapa[["2025"]]), "UT.DEMANDA_TOTAL_MENSUAL.v2026-10")
  })
})

test_that("dos revisiones del mismo año en el mismo mes colisionan y se detienen sin escribir", {
  con_repo_ut({
    sembrar_ut(2025)
    g1 <- gwh_de(2025); g1[5] <- g1[5] + 1
    registrar(descargado(2025, g1), 2025L, fecha_captura = as.Date("2026-10-02"))
    antes <- estado_catalogos()
    g2 <- gwh_de(2025); g2[5] <- g2[5] + 2
    expect_error(registrar(descargado(2025, g2), 2025L, fecha_captura = as.Date("2026-10-20")),
                 "vintage_id.*ya existe")
    expect_identical(estado_catalogos(), antes)
  })
})

# --- Guardas: fallan, no advierten ------------------------------------------------------------

test_that("un archivo con menos meses que el vintage vigente es un retroceso: se detiene", {
  con_repo_ut({
    sembrar_ut(2026, gwh_de(2026, 7))
    antes <- estado_catalogos()
    expect_error(registrar(descargado(2026, gwh_de(2026, 5)), 2026L), "retroceso")
    expect_identical(estado_catalogos(), antes)
  })
})

test_that("un archivo cuyo campo 'Año' interno es de otro año se detiene (archivo equivocado)", {
  con_repo_ut({
    expect_error(registrar(descargado(2026, gwh_de(2026, 7), anio_interno = 2025), 2026L),
                 "interno dice 2025")
    expect_equal(nrow(read.csv(ruta_manifiesto)), 0L)
  })
})

test_that("2002 y 2003, con el campo 'Año' vacio, se registran y lo dicen en la nota", {
  con_repo_ut({
    res <- registrar(descargado(2002, anio_interno = NA), 2002L)
    expect_true(res$vintage_nuevo)
    expect_match(read.csv(ruta_vintages, colClasses = "character")$notas, "Advertencia", fixed = TRUE)
  })
})

test_that("un archivo sin ningun mes con dato se detiene (el año en curso en la ventana de enero)", {
  con_repo_ut({
    vacio <- descargado(2027, numeric(0))
    expect_error(registrar(vacio, 2027L), "ning.n mes con dato")
    expect_equal(nrow(read.csv(ruta_manifiesto)), 0L)
  })
})

test_that("un archivo con meses salteados se detiene: periodo_referencia_max no describiria el contenido", {
  con_repo_ut({
    saltado <- descargado(2026, gwh_de(2026, 3), meses = c(1, 2, 4))
    expect_error(registrar(saltado, 2026L), "sin huecos")
    expect_equal(nrow(read.csv(ruta_manifiesto)), 0L)
  })
})

test_that("si el archivo del vintage previo no esta en L0 no se puede comparar y se detiene", {
  con_repo_ut({
    sembrar_ut(2026, gwh_de(2026, 7))
    file.remove(list.files("data/L0_raw", pattern = "^UT_demanda", full.names = TRUE))
    expect_error(registrar(descargado(2026, gwh_de(2026, 9)), 2026L), "materializar-l0")
    expect_equal(nrow(read.csv(ruta_manifiesto)), 1L)
  })
})

test_that("un año anterior al de la captura que queda sin diciembre lo avisa", {
  con_repo_ut({
    res <- expect_message(
      registrar_ut_demanda_anual(descargado(2026, gwh_de(2026, 11)), 2026L,
                                 fecha_captura = as.Date("2027-01-02")),
      "queda sin diciembre")
    expect_true(res$vintage_nuevo)
  })
  con_repo_ut({
    # el año en curso parcial NO es una anomalia: no avisa
    mensajes <- testthat::capture_messages(
      registrar_ut_demanda_anual(descargado(2026, gwh_de(2026, 7)), 2026L,
                                 fecha_captura = as.Date("2026-10-02")))
    expect_false(any(grepl("queda sin diciembre", mensajes)))
  })
})

# --- Lote ------------------------------------------------------------------------------------

test_that("el lote comprueba TODOS los archivos antes de registrar ninguno", {
  con_repo_ut({
    d <- file.path(tempdir(), "lote_ut"); dir.create(d, showWarnings = FALSE)
    csv_ut(file.path(d, "2026.csv"), 2026, gwh_de(2026, 7))
    expect_error(registrar_ut_demanda_lote(d, anios = c(2026L, 2027L)), "2027.csv")
    expect_equal(nrow(read.csv(ruta_manifiesto)), 0L)

    csv_ut(file.path(d, "2027.csv"), 2027, gwh_de(2027, 3))
    suppressMessages(registrar_ut_demanda_lote(d, anios = c(2026L, 2027L)))
    expect_equal(read.csv(ruta_vintages, colClasses = "character")$vintage_id,
                 c("UT.DEMANDA_TOTAL_MENSUAL.v2026-07", "UT.DEMANDA_TOTAL_MENSUAL.v2027-03"))
  })
})
