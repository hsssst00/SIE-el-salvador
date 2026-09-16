# tests/test-adr-indice.R
#
# Guard anti-regresión para el índice de ADR.
#
# La celda "Estado" de cada fila de doc/adr/README.md debe ser copia literal de
# la línea **Estado:** del ADR correspondiente. Es una regla ya escrita en ese
# índice ("Se verifica con un grep; en Fase 3 corresponde un test_that() que lo
# compruebe automáticamente"); este archivo la implementa.
#
# Ataca el modo de falla que recurrió en las auditorías: una enmienda a un ADR
# que no se propaga al índice (Fase 0, hallazgos C2/C3; verificación de Fase 1,
# hallazgo C1). Cuando pasa, dos archivos del mismo directorio afirman cosas
# opuestas sobre el mismo hecho y sólo una auditoría manual lo detecta. Con este
# test lo detecta CI en el commit que introduce la deriva.
#
# No depende de los .xlsx (sólo lee texto), así que corre en CI vía
# testthat::test_dir("tests") sin ningún cambio en .github/workflows/ci.yml.

library(testthat)

.leer_utf8 <- function(ruta) readLines(ruta, encoding = "UTF-8", warn = FALSE)

test_that("la celda Estado del índice coincide con la línea **Estado:** de cada ADR", {
  ruta_indice <- here::here("doc", "adr", "README.md")
  expect_true(file.exists(ruta_indice), info = "falta doc/adr/README.md")

  lineas_indice <- .leer_utf8(ruta_indice)

  # Fila de la tabla: | [008](./ADR-008-....md) | Decisión | <estado> |
  # Grupos: 1 = número, 2 = archivo del ADR, 3 = celda de estado.
  patron_fila <- "^\\|\\s*\\[(\\d{3})\\]\\(\\./(ADR-\\d{3}[^)]+\\.md)\\)\\s*\\|.*\\|\\s*(.*?)\\s*\\|\\s*$"
  m <- regmatches(lineas_indice, regexec(patron_fila, lineas_indice, perl = TRUE))
  filas <- Filter(function(x) length(x) == 4L, m)

  # El índice debe tener filas parseables; si el formato de la tabla cambió y
  # ninguna fila matchea, esto es un fallo — no un pase vacío silencioso.
  expect_gt(length(filas), 0L)

  archivos      <- vapply(filas, function(x) x[[3]], character(1))
  estado_indice <- vapply(filas, function(x) trimws(x[[4]]), character(1))
  names(estado_indice) <- archivos

  for (archivo_adr in archivos) {
    ruta_adr <- here::here("doc", "adr", archivo_adr)
    expect_true(
      file.exists(ruta_adr),
      info = paste("el índice referencia un ADR inexistente:", archivo_adr)
    )

    lineas_adr   <- .leer_utf8(ruta_adr)
    linea_estado <- grep("^\\*\\*Estado:\\*\\*", lineas_adr, value = TRUE)

    # Exactamente una línea **Estado:** por ADR (assertion explícita).
    expect_length(linea_estado, 1L)

    estado_adr <- if (length(linea_estado) == 1L) {
      trimws(sub("^\\*\\*Estado:\\*\\*", "", linea_estado[[1]]))
    } else {
      NA_character_
    }

    expect_identical(
      estado_indice[[archivo_adr]], estado_adr,
      info = paste0(
        "divergencia en ", archivo_adr, "\n",
        "  índice: ", estado_indice[[archivo_adr]], "\n",
        "  ADR:    ", estado_adr, "\n",
        "El ADR manda: actualizar la celda del índice en doc/adr/README.md."
      )
    )
  }
})

# Guard hermano: ataca la reincidencia (tercera vez) del mismo modo de falla, pero
# en CLAUDE.md y el README.md raíz — los dos archivos que un tercero (y los tres
# agentes) leen primero, y que el test de arriba no cubre porque no son un ADR.
# Ver auditoría independiente de Fase 2 (hallazgo C1, 2026-09-15): CLAUDE.md seguía
# diciendo "Fase 1 … en curso" y el README omitía Fase 2, dos cierres después de
# que doc/adr/README.md ya los certificaba.
test_that("CLAUDE.md y README.md declaran cerrada la última fase que doc/adr/README.md certifica", {
  ruta_indice <- here::here("doc", "adr", "README.md")
  lineas_indice <- .leer_utf8(ruta_indice)

  encabezados_cierre <- grep("^## Cierre de Fase (\\d+)", lineas_indice, value = TRUE)
  expect_gt(length(encabezados_cierre), 0L)

  numeros_fase <- as.integer(sub("^## Cierre de Fase (\\d+).*$", "\\1", encabezados_cierre))
  fase_max <- max(numeros_fase)

  ruta_claude  <- here::here("CLAUDE.md")
  ruta_readme  <- here::here("README.md")
  texto_claude <- paste(.leer_utf8(ruta_claude), collapse = " ")
  texto_readme <- paste(.leer_utf8(ruta_readme), collapse = " ")

  # La fase más reciente cerrada en el índice de ADR debe aparecer como cerrada
  # (no "en curso") en ambos archivos de primera lectura.
  patron_cerrada <- sprintf("Fase %d[^.]*?cerrada", fase_max)
  expect_true(
    grepl(patron_cerrada, texto_claude, ignore.case = TRUE, perl = TRUE),
    info = sprintf(
      "CLAUDE.md no declara cerrada la Fase %d, pese a que doc/adr/README.md ya la certifica.",
      fase_max
    )
  )
  expect_true(
    grepl(patron_cerrada, texto_readme, ignore.case = TRUE, perl = TRUE),
    info = sprintf(
      "README.md no declara cerrada la Fase %d, pese a que doc/adr/README.md ya la certifica.",
      fase_max
    )
  )

  # Ninguna fase ya cerrada en el índice puede seguir descrita como "en curso"
  # en ninguno de los dos archivos (el modo exacto de la reincidencia C1).
  for (n in numeros_fase) {
    patron_en_curso <- sprintf("Fase %d[^.]*?en curso", n)
    expect_false(
      grepl(patron_en_curso, texto_claude, ignore.case = TRUE, perl = TRUE),
      info = sprintf("CLAUDE.md describe la Fase %d como \"en curso\", pero ya está cerrada.", n)
    )
    expect_false(
      grepl(patron_en_curso, texto_readme, ignore.case = TRUE, perl = TRUE),
      info = sprintf("README.md describe la Fase %d como \"en curso\", pero ya está cerrada.", n)
    )
  }
})
