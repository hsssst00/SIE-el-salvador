# tests/test-integridad-referencial.R
#
# Integridad referencial de 01_publicaciones/*.yaml contra 00_instituciones.csv y
# 02_metodologias/, y consistencia publicacion_id == nombre de archivo. Es la
# senda §3.5 lista esta verificación como responsabilidad de la validación con
# pointblank de Fase 3. Se adelantó aquí como test_that (decisión de Harold,
# 2026-09-03: adelantar el alcance no cambia nada).
#
# ALCANCE REDUCIDO (2026-09-17, decisión #4 de doc/checklist_fase3.md): este
# archivo cubría originalmente 7 aristas FK. Las 6 que son tabulares (columna de
# un catálogo CSV que debe resolver contra otro) se migraron a
# src/validacion/validar_integridad_catalogos.R (pointblank, corre en
# `make validate`, falla de forma visible por regla 7 de CLAUDE.md) — ver ese
# archivo y src/validacion/integridad_catalogos_reglas.R para el detalle. Queda
# SOLO la arista de acá, que no es tabular (son archivos .yaml, no una tabla
# CSV) y por eso no calza con create_agent(tbl=...) de pointblank — mismo motivo
# estructural que dejó los checks de huecos/identidad de L2 en R base.
#
# Lee sólo texto (CSV + 3 escalares de YAML por regex), sin los .xlsx. Cuando se
# escribió, `yaml` era transitiva y no estaba declarada en DESCRIPTION; desde Fase 4
# está en Imports (F4-12, nota de ADR-009) y la usa tests/test-catalogo-modelos.R.
# Este bloque sigue con regex porque lee 3 claves escalares planas y no cambia de
# comportamiento; pasarlo a yaml::read_yaml() es un cambio aparte.

library(testthat)

.stems <- function(subdir) {
  archivos <- list.files(here::here("catalogos", subdir), pattern = "\\.yaml$")
  archivos <- archivos[!startsWith(archivos, "_")]   # excluir _plantilla.yaml
  sub("\\.yaml$", "", archivos)
}

.yaml_scalar <- function(ruta, clave) {               # sólo claves escalares al margen izquierdo
  lineas <- readLines(ruta, encoding = "UTF-8", warn = FALSE)
  hit <- grep(paste0("^", clave, ":"), lineas, value = TRUE)
  if (length(hit) == 0L) return(NA_character_)
  val <- sub(paste0("^", clave, ":\\s*"), "", hit[[1]])
  trimws(gsub("^['\"]|['\"]$", "", trimws(val)))
}

.csv <- function(nombre) {
  read.csv(here::here("catalogos", nombre), stringsAsFactors = FALSE,
           colClasses = "character", check.names = FALSE)
}

mets     <- .stems("02_metodologias")
inst_ids <- .csv("00_instituciones.csv")$institucion_id

espera_en <- function(valor, universo, contexto) {
  expect_true(valor %in% universo,
              info = paste0(contexto, ": '", valor, "' no resuelve"))
}

test_that("01_publicaciones/*.yaml: institucion_id, metodologia_id y publicacion_id==nombre", {
  archivos <- list.files(here::here("catalogos", "01_publicaciones"), pattern = "\\.yaml$")
  archivos <- archivos[!startsWith(archivos, "_")]
  expect_gt(length(archivos), 0L)
  for (a in archivos) {
    stem <- sub("\\.yaml$", "", a)
    ruta <- here::here("catalogos", "01_publicaciones", a)
    pid <- .yaml_scalar(ruta, "publicacion_id")
    iid <- .yaml_scalar(ruta, "institucion_id")
    mid <- .yaml_scalar(ruta, "metodologia_id")
    expect_identical(pid, stem,
                     info = paste0(a, ": publicacion_id ('", pid, "') != nombre de archivo"))
    espera_en(iid, inst_ids, paste0(a, ".institucion_id"))
    if (!is.na(mid) && nzchar(mid))
      espera_en(mid, mets, paste0(a, ".metodologia_id"))
  }
})
