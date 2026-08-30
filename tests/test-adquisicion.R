# tests/test-adquisicion.R
#
# Pruebas de registrar_descarga(), el nucleo de Fase 2. Agregadas el 2026-08-28 (hallazgo M2
# de la auditoria de Fase 2): la funcion que materializa la regla 7 de CLAUDE.md ("la
# validacion falla, no advierte") no tenia ninguna prueba que comprobara que efectivamente
# falla. Las 7 pruebas existentes eran todas de catalogos.
#
# Cada prueba corre en un repositorio de mentira (directorio temporal con la estructura
# minima: data/L0_raw/manifiesto.csv y catalogos/08_vintages.csv, solo cabeceras). Las rutas
# de lib_adquisicion.R son relativas y se resuelven contra getwd() en el momento de la
# llamada, asi que basta con cambiar el directorio de trabajo: NINGUNA prueba toca el
# manifiesto ni el catalogo reales.

library(testthat)

source(here::here("src", "adquisicion", "lib_adquisicion.R"))

.COLS_MANIFIESTO <- paste(
  c("archivo", "fuente", "url", "fecha_descarga", "sha256", "sha256_norm",
    "tamano_bytes", "codigo_http", "vintage_id", "publicacion_id"), collapse = ",")
.COLS_VINTAGES <- paste(
  c("vintage_id", "publicacion_id", "fecha_publicacion", "periodo_referencia_max",
    "documento_fuente", "archivo_raw", "sha256", "sha256_norm", "alcance_revision",
    "notas"), collapse = ",")

# Literales exactos que registrar_descarga() escribe en alcance_revision. La igualdad
# literal es el mecanismo de deteccion de deriva del proyecto (src/adquisicion/README.md
# S3), asi que se declaran con escape unicode: la raya larga es U+2014, no un guion, y no
# debe depender de como cada maquina interprete la codificacion de este archivo.
.LIT_PRIMERA <- "primera captura — sin vintage previo con el cual comparar"
.LIT_NUEVO   <- "vintage nuevo — sha256 distinto del capturado el "

# Ejecuta expr dentro de un repositorio de mentira. `filas_*` permiten sembrar historia.
con_repo_temporal <- function(expr, filas_manifiesto = character(), filas_vintages = character()) {
  d <- tempfile("repo_falso_")
  dir.create(file.path(d, "data", "L0_raw"), recursive = TRUE)
  dir.create(file.path(d, "catalogos"), recursive = TRUE)
  writeLines(c(.COLS_MANIFIESTO, filas_manifiesto), file.path(d, "data", "L0_raw", "manifiesto.csv"))
  writeLines(c(.COLS_VINTAGES, filas_vintages), file.path(d, "catalogos", "08_vintages.csv"))
  anterior <- setwd(d)
  on.exit(setwd(anterior), add = TRUE)
  force(expr)
}

bytes_de <- function(txt) charToRaw(txt)

# Llamada valida por defecto; cada prueba cambia solo lo que quiere romper.
descarga <- function(...) {
  args <- list(
    fuente = "TEST", publicacion_id = "TEST.PUB",
    url = "https://ejemplo.test/serie?x=1", descripcion_archivo = "serie",
    extension = "json", contenido_crudo = bytes_de('{"a":1}'), codigo_http = 200L,
    fecha_publicacion = "2026-08-01", periodo_referencia_max = "2026-M07"
  )
  do.call(registrar_descarga, utils::modifyList(args, list(...)))
}

# --- Paso 0: fecha_publicacion, de la que se deriva el vintage_id ----------------------

test_that("falla si fecha_publicacion falta o no es ISO (ADR-007, nota 2026-08-20)", {
  con_repo_temporal({
    expect_error(descarga(fecha_publicacion = ""), "fecha_publicacion ausente o no ISO")
    expect_error(descarga(fecha_publicacion = "agosto 2026"), "fecha_publicacion ausente o no ISO")
    expect_error(descarga(fecha_publicacion = "2026-8-1"), "fecha_publicacion ausente o no ISO")
    # y no dejo rastro en disco
    expect_equal(nrow(read.csv("data/L0_raw/manifiesto.csv")), 0L)
    expect_equal(length(list.files("data/L0_raw", pattern = "\\.json$")), 0L)
  })
})

# --- Paso 1: fallar de forma visible (regla 6/7 de CLAUDE.md) -------------------------

test_that("falla si codigo_http != 200 y no escribe nada", {
  con_repo_temporal({
    expect_error(descarga(codigo_http = 404L), "codigo HTTP 404")
    expect_equal(nrow(read.csv("data/L0_raw/manifiesto.csv")), 0L)
    expect_equal(length(list.files("data/L0_raw", pattern = "\\.json$")), 0L)
  })
})

test_that("falla si verificacion_forma devuelve FALSE y no escribe nada", {
  con_repo_temporal({
    expect_error(descarga(verificacion_forma = function(b) FALSE),
                 "no paso la verificacion de forma")
    expect_equal(nrow(read.csv("data/L0_raw/manifiesto.csv")), 0L)
    expect_equal(length(list.files("data/L0_raw", pattern = "\\.json$")), 0L)
  })
})

test_that("una verificacion_forma que no devuelve TRUE tampoco pasa (isTRUE, no truthiness)", {
  con_repo_temporal({
    expect_error(descarga(verificacion_forma = function(b) NULL), "no paso la verificacion")
    expect_error(descarga(verificacion_forma = function(b) 1), "no paso la verificacion")
  })
})

# --- Camino feliz ----------------------------------------------------------------------

test_that("primera captura: escribe el archivo y una fila en cada catalogo", {
  con_repo_temporal({
    res <- descarga()
    expect_true(res$vintage_nuevo)
    expect_equal(res$vintage_id, "TEST.PUB.v2026-08")

    man <- read.csv("data/L0_raw/manifiesto.csv", colClasses = "character")
    expect_equal(nrow(man), 1L)
    expect_equal(man$publicacion_id, "TEST.PUB")
    expect_equal(man$vintage_id, "TEST.PUB.v2026-08")
    expect_equal(man$tamano_bytes, "7")
    # json no es un contenedor: sha256_norm coincide con sha256 (ADR-007, nota 2026-08-21)
    expect_equal(man$sha256_norm, man$sha256)
    expect_true(file.exists(file.path("data/L0_raw", man$archivo)))

    vin <- read.csv("catalogos/08_vintages.csv", colClasses = "character")
    expect_equal(nrow(vin), 1L)
    expect_equal(vin$vintage_id, man$vintage_id)
    expect_equal(vin$sha256, man$sha256)
    expect_equal(vin$fecha_publicacion, "2026-08-01")
    # literal exacto: es el mecanismo de deteccion de deriva del proyecto
    expect_equal(vin$alcance_revision, .LIT_PRIMERA)
  })
})

test_that("el nombre del archivo sigue la convencion {FUENTE}_{desc}_{fecha_descarga}.{ext}", {
  con_repo_temporal({
    res <- descarga()
    expect_equal(res$archivo, paste0("TEST_serie_", Sys.Date(), ".json"))
  })
})

# --- Paso 3: sin cambios / vintage nuevo ----------------------------------------------

test_that("contenido identico al ultimo vintage: no escribe nada y lo reporta", {
  con_repo_temporal({
    primera <- descarga()
    antes_man <- readLines("data/L0_raw/manifiesto.csv")
    antes_vin <- readLines("catalogos/08_vintages.csv")

    segunda <- expect_message(descarga(fecha_publicacion = "2026-09-01"), "Sin cambios")
    expect_false(segunda$vintage_nuevo)
    expect_equal(segunda$sha256, primera$sha256)

    # "el script corrio y verifico" no debe ser indistinguible de "el script no hizo nada":
    # no se escribe, pero el retorno lo dice.
    expect_identical(readLines("data/L0_raw/manifiesto.csv"), antes_man)
    expect_identical(readLines("catalogos/08_vintages.csv"), antes_vin)
  })
})

test_that("contenido distinto: registra vintage nuevo con el literal exacto", {
  con_repo_temporal({
    descarga()
    res <- descarga(contenido_crudo = bytes_de('{"a":2}'), fecha_publicacion = "2026-09-01",
                    descripcion_archivo = "serie_b")
    expect_true(res$vintage_nuevo)

    vin <- read.csv("catalogos/08_vintages.csv", colClasses = "character")
    expect_equal(nrow(vin), 2L)
    expect_equal(vin$alcance_revision[1], .LIT_PRIMERA)
    expect_true(startsWith(vin$alcance_revision[2], .LIT_NUEVO))
  })
})

# --- Paso 3b: colision de vintage_id ---------------------------------------------------

test_that("falla si el vintage_id ya existe en 08_vintages con contenido distinto", {
  con_repo_temporal({
    descarga()
    # mismo mes de publicacion => mismo vintage_id, pero contenido distinto
    expect_error(descarga(contenido_crudo = bytes_de('{"a":3}')),
                 "ya existe")
    expect_equal(nrow(read.csv("data/L0_raw/manifiesto.csv")), 1L)
    expect_equal(length(list.files("data/L0_raw", pattern = "\\.json$")), 1L)
  })
})

# --- Paso 4: nunca sobrescribe ---------------------------------------------------------

test_that("falla si el archivo destino ya existe (regla 1: L0 es inmutable)", {
  con_repo_temporal({
    ruta <- file.path("data/L0_raw", paste0("TEST_serie_", Sys.Date(), ".json"))
    writeLines("ocupado", ruta)
    expect_error(descarga(), "ya existe")
    # y no lo piso
    expect_equal(readLines(ruta), "ocupado")
  })
})

# --- Regresion B3: varias filas por publicacion no rompen nada -------------------------
# El manifiesto es append-only con UNA FILA POR VINTAGE. Que una publicacion tenga varias
# filas es el estado NORMAL en cuanto la captura prospectiva de ADR-007 hace su trabajo.
# Esta prueba fija esa expectativa: hasta el 2026-08-28,
# src/validacion/verificar_fuente_celda.R trataba ese caso como FAIL ("deberia ser unico").

test_that("con varios vintages previos, compara contra el ULTIMO, no contra el primero", {
  con_repo_temporal({
    descarga(contenido_crudo = bytes_de('{"v":1}'), fecha_publicacion = "2026-06-01",
             descripcion_archivo = "serie_v1")
    descarga(contenido_crudo = bytes_de('{"v":2}'), fecha_publicacion = "2026-07-01",
             descripcion_archivo = "serie_v2")
    descarga(contenido_crudo = bytes_de('{"v":3}'), fecha_publicacion = "2026-08-01",
             descripcion_archivo = "serie_v3")

    man <- read.csv("data/L0_raw/manifiesto.csv", colClasses = "character")
    expect_equal(nrow(man), 3L)
    expect_equal(length(unique(man$publicacion_id)), 1L)

    # repetir el contenido del ULTIMO => sin cambios
    res <- expect_message(descarga(contenido_crudo = bytes_de('{"v":3}'),
                                   fecha_publicacion = "2026-09-01",
                                   descripcion_archivo = "serie_v4"), "Sin cambios")
    expect_false(res$vintage_nuevo)

    # repetir el contenido de uno ANTERIOR => es un cambio respecto del vigente, no "sin
    # cambios": la comparacion es contra el vintage vigente, no contra todo el historial.
    res2 <- descarga(contenido_crudo = bytes_de('{"v":1}'), fecha_publicacion = "2026-09-01",
                     descripcion_archivo = "serie_v4")
    expect_true(res2$vintage_nuevo)
  })
})

test_that("dos vintages de la misma publicacion el MISMO dia chocan por nombre de archivo", {
  # Restriccion real, descubierta al escribir estas pruebas (2026-08-28): el nombre de
  # archivo es {FUENTE}_{descripcion}_{fecha_descarga}.{ext} (senda S3.1) y no lleva nada
  # del vintage, asi que dos capturas del mismo dia de la misma publicacion colisionan en
  # el paso 4 aunque el contenido difiera y el vintage_id sea distinto. Se documenta como
  # comportamiento esperado, no como fallo: es el guardarrail de "nunca sobrescribe"
  # actuando. Quien necesite registrar varios artefactos el mismo dia bajo un mismo
  # publicacion_id pasa una descripcion_archivo distinta - que es lo que hace ut.R con sus
  # 25 cortes anuales.
  con_repo_temporal({
    descarga(contenido_crudo = bytes_de('{"v":1}'), fecha_publicacion = "2026-06-01")
    expect_error(
      descarga(contenido_crudo = bytes_de('{"v":2}'), fecha_publicacion = "2026-07-01"),
      "ya existe. No se sobrescribe"
    )
  })
})

# --- calcular_sha256_norm ---------------------------------------------------------------

test_that("para contenido que no es contenedor, sha256_norm == sha256", {
  b <- bytes_de('{"a":1}')
  expect_equal(calcular_sha256_norm(b, "json"), calcular_sha256_raw(b))
  expect_equal(calcular_sha256_norm(b, "csv"), calcular_sha256_raw(b))
})

test_that("sha256_norm de un .xlsx ignora el empaquetado ZIP (prueba F1, ADR-007 2026-08-21)", {
  # Dos ZIP con las mismas entradas y el mismo contenido, comprimidos distinto: el sha256
  # crudo difiere, el normalizado no. Es el supuesto sobre el que descansa la deteccion de
  # vintage del BCR.
  d <- tempfile("zipsrc_"); dir.create(d)
  writeLines("alfa", file.path(d, "a.xml"))
  writeLines("beta", file.path(d, "b.xml"))
  anterior <- setwd(d); on.exit(setwd(anterior), add = TRUE)

  z1 <- tempfile(fileext = ".xlsx"); z2 <- tempfile(fileext = ".xlsx")
  ok <- tryCatch({
    utils::zip(z1, c("a.xml", "b.xml"), flags = "-q -X -0")   # sin comprimir
    utils::zip(z2, c("a.xml", "b.xml"), flags = "-q -X -9")   # comprimido al maximo
    file.exists(z1) && file.exists(z2)
  }, error = function(e) FALSE, warning = function(w) FALSE)
  skip_if_not(isTRUE(ok), "no hay un ejecutable zip disponible en esta maquina")

  b1 <- readBin(z1, "raw", file.info(z1)$size)
  b2 <- readBin(z2, "raw", file.info(z2)$size)

  expect_false(identical(calcular_sha256_raw(b1), calcular_sha256_raw(b2)))
  expect_equal(calcular_sha256_norm(b1, "xlsx"), calcular_sha256_norm(b2, "xlsx"))
})
