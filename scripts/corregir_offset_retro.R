# Corrige un desfase sistemático de +1 fila en los campos estructurados
# (fila_dato, fila_anios, fila_trimestres) de las 13 series de
# BCR.PIB_T.SERIE_RETROPOLADA_1990_2005 en catalogos/03_series.csv, detectado
# el 2026-09-15 al construir el extractor L0→L1 de Fase 3.
#
# La corrección de 2026-08-13 (documentada en fuente_celda de
# BCR.PIB.VOL.NSA.Q.RETRO) decía haber verificado contra "el XML crudo del
# archivo", pero el archivo hoy en data/L0_raw/
# (BCR_pib_t_retropolado_1990_2005_2026-08-06.xlsx) no coincide con esos
# números: la fila que el catálogo asigna a cada serie es siempre una fila más
# que la real. Re-verificado el 2026-09-15 de dos formas independientes:
#   1. Lectura directa del XLSX (readxl) — la etiqueta en columna A/B de cada
#      fila candidata se compara contra nombre_oficial.
#   2. Aritmética en T1 (valores nominales, aditivos por construcción):
#      fila 22 "Valor Agregado Bruto" (994.862...) + fila 23 "Impuestos Netos"
#      (69.838...) = fila 24 "PRODUCTO INTERNO BRUTO TRIMESTRAL" (1064.700...),
#      exacto — confirma que el PIB de T1 está en la fila 24, no 25.
# No se pudo determinar si el archivo de L0 cambió de estructura después de la
# verificación de agosto o si esa verificación tuvo un error de conteo; ver
# nota agregada a fuente_celda para el estado de esa pregunta.

ruta <- "catalogos/03_series.csv"
x <- read.csv(ruta, stringsAsFactors = FALSE, na.strings = "", colClasses = "character")

es_retro <- x$publicacion_id == "BCR.PIB_T.SERIE_RETROPOLADA_1990_2005"
if (sum(es_retro) != 13) {
  stop("FALLO VISIBLE: se esperaban 13 series RETRO, se encontraron ", sum(es_retro))
}

restar_uno <- function(v) as.character(as.integer(v) - 1L)
x$fila_dato[es_retro]       <- restar_uno(x$fila_dato[es_retro])
x$fila_anios[es_retro]      <- restar_uno(x$fila_anios[es_retro])
x$fila_trimestres[es_retro] <- restar_uno(x$fila_trimestres[es_retro])

nota_correccion <- paste0(
  " RE-CORREGIDO 2026-09-15 (Fase 3): la corrección de 2026-08-13 no coincidía ",
  "con el archivo en data/L0_raw/BCR_pib_t_retropolado_1990_2005_2026-08-06.xlsx ",
  "(desfase de +1 fila en todo T1/T2, detectado al construir el extractor L0→L1); ",
  "re-verificado por lectura directa del XLSX y por aritmética VAB+Impuestos=PIB ",
  "en T1. No se determinó si el archivo cambió de estructura tras agosto o si la ",
  "verificación previa tuvo un error de conteo."
)

# Actualiza el texto libre de fuente_celda para que sus números coincidan con
# los campos estructurados recién corregidos: resta 1 a cada "fila N" dentro
# del texto, solo para las filas RETRO.
restar_uno_en_texto <- function(fc) {
  m <- gregexpr("(?<=fila )[0-9]+", fc, perl = TRUE)
  nums <- regmatches(fc, m)[[1]]
  if (length(nums) > 0) {
    nuevos <- as.character(as.integer(nums) - 1L)
    regmatches(fc, m)[[1]] <- nuevos
  }
  paste0(fc, nota_correccion)
}

x$fuente_celda[es_retro] <- vapply(x$fuente_celda[es_retro], restar_uno_en_texto, character(1))

write.csv(x, ruta, row.names = FALSE, na = "")

cat("OK: corregidas", sum(es_retro), "series RETRO (fila_dato, fila_anios, fila_trimestres -1; nota agregada a fuente_celda).\n")
