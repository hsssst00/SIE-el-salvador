# Puebla los seis campos estructurados (hoja, fila_dato, col_inicio, col_fin,
# fila_anios, fila_trimestres) que datapackage.json agrega a 03_series.csv el
# 2026-09-15 (Fase 3). Los parsea desde fuente_celda (texto libre, se conserva
# sin cambios) con expresiones regulares sobre el patrón ya usado consistentemente
# en las cuatro publicaciones de PIB del BCR: "hoja X, fila N (...), columnas/rango
# A:B ...; años en fila M, trimestres en fila K". Migración de un solo uso: se
# corre una vez y el resultado (03_series.csv actualizado) es lo que se commitea,
# no un paso recurrente del pipeline.
#
# No aplica a UT.DEMANDA_TOTAL_MENSUAL (su fuente_celda no describe una celda
# XLSX — ver notas ahí); esas filas quedan con los seis campos vacíos.

ruta <- "catalogos/03_series.csv"
x <- read.csv(ruta, stringsAsFactors = FALSE, na.strings = "", colClasses = "character")

parse_uno <- function(fc) {
  hoja <- regmatches(fc, regexpr("(?<=hoja )[^,]+", fc, perl = TRUE))
  fila_dato <- regmatches(fc, regexpr("(?<=fila )[0-9]+", fc, perl = TRUE))

  m_rango <- regmatches(fc, regexpr("rango [A-Z]+[0-9]+:[A-Z]+[0-9]+", fc))
  m_cols  <- regmatches(fc, regexpr("columnas [A-Z]+:[A-Z]+", fc))
  if (length(m_rango) == 1) {
    letras <- regmatches(m_rango, gregexpr("[A-Z]+(?=[0-9])", m_rango, perl = TRUE))[[1]]
    col_inicio <- letras[1]; col_fin <- letras[2]
  } else if (length(m_cols) == 1) {
    letras <- strsplit(sub("columnas ", "", m_cols), ":")[[1]]
    col_inicio <- letras[1]; col_fin <- letras[2]
  } else {
    col_inicio <- NA_character_; col_fin <- NA_character_
  }

  fila_anios <- regmatches(fc, regexpr("(?<=años en fila )[0-9]+", fc, perl = TRUE))
  fila_trim  <- regmatches(fc, regexpr("(?<=trimestres en fila )[0-9]+", fc, perl = TRUE))

  list(
    hoja = if (length(hoja) == 1) hoja else NA_character_,
    fila_dato = if (length(fila_dato) == 1) fila_dato else NA_character_,
    col_inicio = col_inicio,
    col_fin = col_fin,
    fila_anios = if (length(fila_anios) == 1) fila_anios else NA_character_,
    fila_trimestres = if (length(fila_trim) == 1) fila_trim else NA_character_
  )
}

es_celda_xlsx <- x$publicacion_id != "UT.DEMANDA_TOTAL_MENSUAL"

parsed <- lapply(x$fuente_celda, parse_uno)
x$hoja            <- vapply(parsed, `[[`, character(1), "hoja")
x$fila_dato       <- vapply(parsed, `[[`, character(1), "fila_dato")
x$col_inicio      <- vapply(parsed, `[[`, character(1), "col_inicio")
x$col_fin         <- vapply(parsed, `[[`, character(1), "col_fin")
x$fila_anios      <- vapply(parsed, `[[`, character(1), "fila_anios")
x$fila_trimestres <- vapply(parsed, `[[`, character(1), "fila_trimestres")

# Las filas que no describen una celda XLSX (UT) deben quedar vacías, no con
# basura de un parseo que no les corresponde.
campos_nuevos <- c("hoja", "fila_dato", "col_inicio", "col_fin", "fila_anios", "fila_trimestres")
x[!es_celda_xlsx, campos_nuevos] <- NA_character_

# Fallar de forma visible si alguna fila que SÍ debería parsear quedó incompleta.
incompletas <- es_celda_xlsx & !complete.cases(x[, campos_nuevos])
if (any(incompletas)) {
  stop("FALLO VISIBLE: fuente_celda no parseable para serie_id: ",
       paste(x$serie_id[incompletas], collapse = ", "),
       ". Revisar el texto de fuente_celda antes de continuar.")
}

write.csv(x, ruta, row.names = FALSE, na = "")

cat("OK:", sum(es_celda_xlsx), "series con campos estructurados poblados,",
    sum(!es_celda_xlsx), "fila(s) UT dejadas vacías por diseño.\n")
