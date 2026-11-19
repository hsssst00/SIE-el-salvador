# tests/test-tablas-fase6-reconstruccion.R
#
# Remediación de la auditoría independiente de Fase 6 (hallazgo I1). Las tablas versionadas de
# doc/metodologia/reportes_fase6/ son copias de las salidas de L4 que certificó la corrida: las de grupo
# llevan delante la columna `grupo`, y las de F6_COMUN se copian tal cual (src/proyeccion/tablas_informe_fase6.R).
# Este test reconstruye, desde lo versionado, cada archivo de L4 y compara su sha256 con la lista certificada.
#
#   1. Corrida vigente (E3 del 2026-11-12, `1528483`): las 28 salidas contra sha256_salidas_fase6.csv.
#   2. Corrida reemplazada (E3 del 2026-11-04, `b1376df`): sensibilidad_reemplazada_fase6.csv y
#      senderos_sensibilidad_reemplazada_fase6.csv contra los sha256 de esa corrida (lista de `b084c1b` y segunda
#      tabla de doc/evidencia_reproduccion_fase6_2026-11-12.txt).
#
# Lee solo texto versionado, así que corre en CI. Quita los CR antes de hashear, porque en Windows con
# core.autocrlf=true los CSV se materializan con CRLF; el sha256 de la lista es el del archivo LF de L4.

library(testthat)

.dir_f6 <- here::here("doc", "metodologia", "reportes_fase6")

.lineas_lf <- function(ruta) {
  b <- readBin(ruta, "raw", file.size(ruta))
  b <- b[b != as.raw(13L)]
  txt <- rawToChar(b)
  Encoding(txt) <- "UTF-8"
  l <- strsplit(txt, "\n", fixed = TRUE)[[1]]
  l
}

.sha_lineas <- function(l) digest::digest(charToRaw(paste0(paste(l, collapse = "\n"), "\n")), algo = "sha256", serialize = FALSE)

# Reconstruye el archivo de L4 de un grupo desde una tabla versionada con columna `grupo` delante.
.reconstruir_grupo <- function(l, g) {
  pre_h <- "\"grupo\","
  expect_true(startsWith(l[1], pre_h))
  pre <- sprintf("\"%s\",", g)
  cuerpo <- l[-1][startsWith(l[-1], pre)]
  c(substring(l[1], nchar(pre_h) + 1L), substring(cuerpo, nchar(pre) + 1L))
}

test_that("las tablas versionadas de Fase 6 reconstruyen byte a byte las 28 salidas certificadas (corrida vigente)", {
  ref <- utils::read.csv(file.path(.dir_f6, "sha256_salidas_fase6.csv"), stringsAsFactors = FALSE)
  expect_identical(nrow(ref), 28L)
  nombre_tabla <- c(trimestral = "proyeccion_trimestral", anual = "proyeccion_anual")
  for (i in seq_len(nrow(ref))) {
    partes <- strsplit(ref$archivo[i], "/", fixed = TRUE)[[1]]
    exp <- partes[1]; base <- sub("\\.csv$", "", partes[2])
    tabla <- if (base %in% names(nombre_tabla)) nombre_tabla[[base]] else base
    l <- .lineas_lf(file.path(.dir_f6, paste0(tabla, "_fase6.csv")))
    rec <- if (exp == "F6_COMUN") l else .reconstruir_grupo(l, sub("^F6_", "", exp))
    expect_identical(.sha_lineas(rec), ref$sha256[i], info = ref$archivo[i])
  }
})

test_that("las copias de la sensibilidad reemplazada reconstruyen las salidas de la corrida del 2026-11-04", {
  # sha256 de la corrida reemplazada (b1376df): lista de sha256_salidas_fase6.csv en b084c1b.
  reemplazada <- c(
    "F6_G1/sensibilidad.csv"            = "341d0fb70c7bd5cda55de17c90a81e0e80fbd815a8537faa9b516582cb84a088",
    "F6_G2/sensibilidad.csv"            = "4ee17f37af7a4f01a889ab107b9f104cc738bfdf4a4b24a5b814def98c27f6e9",
    "F6_G3/sensibilidad.csv"            = "976afea871bb32ca80284da303184fcc94870340979ad66ff180751051ebf61b",
    "F6_COMUN/senderos_sensibilidad.csv" = "4bd54519483c40bcf3d8d33c938b68c886ea63b0751a768e2f7445366cda3e4e"
  )
  # Los cuatro sha256 constan en la evidencia versionada de la reproducción (segunda tabla).
  ev <- paste(readLines(here::here("doc", "evidencia_reproduccion_fase6_2026-11-12.txt"), encoding = "UTF-8", warn = FALSE),
              collapse = "\n")
  for (s in reemplazada) expect_true(grepl(s, ev, fixed = TRUE), info = s)

  l <- .lineas_lf(file.path(.dir_f6, "sensibilidad_reemplazada_fase6.csv"))
  for (g in c("G1", "G2", "G3")) {
    clave <- sprintf("F6_%s/sensibilidad.csv", g)
    expect_identical(.sha_lineas(.reconstruir_grupo(l, g)), unname(reemplazada[clave]), info = clave)
  }
  s <- .lineas_lf(file.path(.dir_f6, "senderos_sensibilidad_reemplazada_fase6.csv"))
  expect_identical(.sha_lineas(s), unname(reemplazada["F6_COMUN/senderos_sensibilidad.csv"]))
})
