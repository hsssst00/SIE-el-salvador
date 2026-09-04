# tests/test-integridad-referencial.R
#
# Integridad referencial entre catálogos: toda clave foránea resuelve contra un
# registro que existe. Es la verificación que las tres auditorías re-hicieron a
# mano ("todas las claves foráneas... resuelven contra registros que sí existen").
#
# La senda §3.5 lista esta verificación como responsabilidad de la validación con
# pointblank de Fase 3. Se adelanta aquí como test_that (decisión de Harold,
# 2026-09-03: adelantar el alcance no cambia nada). Cuando Fase 3 implemente la
# validación pointblank de los catálogos, este test puede subsumirse o
# reemplazarse sin deuda.
#
# NO duplica check_l0_integrity.R, que ya cubre manifiesto.csv <-> 08_vintages.csv
# (vintage_id en ambos sentidos y paridad de checksums). Aquí se cubren las FKs
# ENTRE CATÁLOGOS que ese script no toca.
#
# Lee sólo texto (CSV + 3 escalares de YAML por regex), sin los .xlsx y sin
# dependencia nueva: `yaml` está en el lockfile como transitiva pero no declarada
# en DESCRIPTION, y el proyecto ya corrigió antes el uso de transitivas sin
# declarar (CLAUDE.md, remediación M1 de Fase 2). Para 3 claves escalares planas
# no se justifica declarar un parser; si Fase 3 lo declara, este bloque se cambia.
#
# FUERA DE ALCANCE deliberado: 04_transformaciones.series_insumo, cuyo formato es
# mixto (serie_id o "transf_id (producto)") y exige resolución consciente de la
# transformación, no una FK plana. Son 2 filas que Fase 3 reelabora. Se deja para
# la validación pointblank.

library(testthat)

.stems <- function(subdir) {
  archivos <- list.files(here::here("catalogos", subdir), pattern = "\\.yaml$")
  archivos <- archivos[!startsWith(archivos, "_")]   # excluir _plantilla.yaml
  sub("\\.yaml$", "", archivos)
}

.multi <- function(v) {                               # separador coma-espacio
  v <- trimws(v)
  if (!nzchar(v)) return(character(0))
  trimws(strsplit(v, ",", fixed = TRUE)[[1]])
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

# Conjuntos objetivo y catálogos con FK (una sola lectura).
pubs       <- .stems("01_publicaciones")
mets       <- .stems("02_metodologias")
series     <- .csv("03_series.csv")
serie_ids  <- series$serie_id
transf     <- .csv("04_transformaciones.csv")
transf_ids <- transf$transf_id
master     <- .csv("05_series_master.csv")
vintages   <- .csv("08_vintages.csv")
rupturas   <- .csv("09_rupturas.csv")
inst_ids   <- .csv("00_instituciones.csv")$institucion_id

# Aserción: falla nombrando la fila de origen y el valor que no resuelve.
espera_en <- function(valor, universo, contexto) {
  expect_true(valor %in% universo,
              info = paste0(contexto, ": '", valor, "' no resuelve"))
}

test_that("03_series.publicacion_id resuelve contra 01_publicaciones", {
  for (i in seq_len(nrow(series)))
    espera_en(series$publicacion_id[i], pubs,
              paste0("03_series[", series$serie_id[i], "].publicacion_id"))
})

test_that("03_series.metodologia_id resuelve contra 02_metodologias (vacío permitido)", {
  for (i in seq_len(nrow(series))) {
    m <- trimws(series$metodologia_id[i])
    if (nzchar(m))
      espera_en(m, mets, paste0("03_series[", series$serie_id[i], "].metodologia_id"))
  }
})

test_that("08_vintages.publicacion_id resuelve contra 01_publicaciones", {
  for (i in seq_len(nrow(vintages)))
    espera_en(vintages$publicacion_id[i], pubs,
              paste0("08_vintages[", vintages$vintage_id[i], "].publicacion_id"))
})

test_that("05_series_master: transf_id (opcional) y series_insumo_ids resuelven", {
  for (i in seq_len(nrow(master))) {
    id <- master$series_master_id[i]
    t  <- trimws(master$transf_id[i])
    if (nzchar(t))
      espera_en(t, transf_ids, paste0("05_master[", id, "].transf_id"))
    for (tok in .multi(master$series_insumo_ids[i]))
      espera_en(tok, serie_ids, paste0("05_master[", id, "].series_insumo_ids"))
  }
})

test_that("09_rupturas.series_afectadas resuelve según tipo_referencia", {
  for (i in seq_len(nrow(rupturas))) {
    id <- rupturas$ruptura_id[i]
    tr <- trimws(rupturas$tipo_referencia[i])
    universo <- switch(tr,
      "serie_id"       = serie_ids,
      "publicacion_id" = pubs,
      NULL)
    expect_false(is.null(universo),
                 info = paste0("09_rupturas[", id, "]: tipo_referencia desconocido '", tr, "'"))
    if (!is.null(universo))
      for (tok in .multi(rupturas$series_afectadas[i]))
        espera_en(tok, universo,
                  paste0("09_rupturas[", id, "].series_afectadas[", tr, "]"))
  }
})

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
