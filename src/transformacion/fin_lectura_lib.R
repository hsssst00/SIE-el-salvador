# src/transformacion/fin_lectura_lib.R
#
# Fin de lectura por vintage (F6-19 de doc/metodologia/decisiones_fase6.md, decision de Harold del
# 2026-10-20). Los extractores L0 -> L1 de libros .xlsx del BCR y de la ONEC ubican cada serie con
# los campos estructurados de 03_series.csv (hoja, fila_dato, col_inicio, fila_anios,
# fila_trimestres). La columna FINAL ya no sale de `col_fin` de 03, que es la del vintage en que se
# registro la serie, sino del vintage que se lee: es la columna cuyo encabezado (anio + trimestre o
# mes) es el `periodo_referencia_max` que 08_vintages.csv declara para ese archivo.
#
# Motivo (hechos de C3, 2026-10-19): con el `col_fin` fijo, el vintage v2026-09 del PIB y de los seis
# mensuales del BCR traia 1 o 2 periodos mas que quedaban fuera sin error; y corregir `col_fin` en
# 03 rompia `make master` sobre corte_fase5.csv, cuyos vintages terminan antes (F6-18-d).
#
# Guardas (regla 7, stop()): el periodo de 08 tiene que tener el formato AAAA-Tn o AAAA-Mnn de la
# frecuencia del extractor, aparecer exactamente una vez en los encabezados desde col_inicio, y
# despues de esa columna la fila del dato tiene que estar vacia.

.fl_col_a_num <- function(s) {
  Reduce(function(acc, ch) acc * 26L + (utf8ToInt(ch) - utf8ToInt("A") + 1L),
         strsplit(s, "")[[1]], accumulate = FALSE, init = 0L)
}

.fl_num_a_col <- function(n) {
  s <- ""
  while (n > 0) {
    r <- (n - 1L) %% 26L
    s <- paste0(LETTERS[r + 1L], s)
    n <- (n - 1L) %/% 26L
  }
  s
}

#' periodo_referencia_max (08_vintages.csv) del vintage cuyo archivo de L0 es `path`. Falla visible si
#' el archivo no tiene exactamente una fila en 08 o si el periodo esta vacio.
periodo_max_de_archivo <- function(path, vintages) {
  fila <- vintages[!is.na(vintages$archivo_raw) & vintages$archivo_raw == basename(path), ]
  if (nrow(fila) != 1) {
    stop("FALLO VISIBLE: el archivo de L0 '", basename(path), "' tiene ", nrow(fila),
         " fila(s) en 08_vintages.csv (se espera 1); no se puede fijar su fin de lectura (F6-19).")
  }
  p <- fila$periodo_referencia_max
  if (is.na(p) || !nzchar(trimws(p))) {
    stop("FALLO VISIBLE: el vintage '", fila$vintage_id, "' no declara periodo_referencia_max en ",
         "08_vintages.csv; sin el no hay fin de lectura (F6-19).")
  }
  trimws(p)
}

#' Indice de la columna final de lectura de una serie en `raw` (hoja leida con
#' read_excel(col_names = FALSE)). `tipo` es "T" (trimestral, etiquetas I..IV) o "M" (mensual,
#' Ene..Dic); `etiquetas` es el vector con nombre que traduce la etiqueta a 1..4 o 1..12. Los anios
#' se rellenan hacia adelante desde la columna 2 (la 1 es la etiqueta de fila), como hacen
#' extraer_onec_ipc.R y extraer_bcr_ipp.R.
columna_fin_lectura <- function(raw, col_inicio, fila_anios, fila_periodos, fila_dato,
                                periodo_max, tipo, etiquetas, serie_id, path) {
  patron <- if (identical(tipo, "T")) "^([0-9]{4})-T([1-4])$" else if (identical(tipo, "M")) {
    "^([0-9]{4})-M(0[1-9]|1[0-2])$"
  } else {
    stop("FALLO VISIBLE: tipo de frecuencia desconocido en columna_fin_lectura(): ", tipo)
  }
  if (!grepl(patron, periodo_max)) {
    stop("FALLO VISIBLE [", serie_id, "]: periodo_referencia_max '", periodo_max, "' de ",
         "08_vintages.csv no tiene el formato AAAA-", tipo, "n que espera este extractor (", path, ").")
  }
  anio_obj <- as.integer(sub(patron, "\\1", periodo_max))
  sub_obj <- as.integer(sub(patron, "\\2", periodo_max))

  n <- ncol(raw)
  ci <- .fl_col_a_num(col_inicio)
  anios_raw <- as.character(unlist(raw[fila_anios, seq_len(n)]))
  for (i in seq_along(anios_raw)) {
    if (i > 2 && is.na(anios_raw[i])) anios_raw[i] <- anios_raw[i - 1]
  }
  anios <- suppressWarnings(as.integer(anios_raw))
  etiqueta <- trimws(sub("\\s*\\(.\\)$", "", as.character(unlist(raw[fila_periodos, seq_len(n)]))))
  sub_num <- unname(etiquetas[etiqueta])

  cand <- which(seq_len(n) >= ci & !is.na(anios) & anios == anio_obj &
                  !is.na(sub_num) & sub_num == sub_obj)
  if (length(cand) != 1) {
    stop("FALLO VISIBLE [", serie_id, "]: el periodo_referencia_max ", periodo_max,
         " de 08_vintages.csv aparece ", length(cand), " vez/veces en los encabezados de ", path,
         " (filas ", fila_anios, " y ", fila_periodos, ", desde ", col_inicio,
         "); se espera exactamente 1 (F6-19).")
  }
  cf <- cand
  if (cf < n) {
    resto <- as.character(unlist(raw[fila_dato, (cf + 1L):n]))
    con_dato <- which(!is.na(resto) & trimws(resto) != "")
    if (length(con_dato) > 0) {
      stop("FALLO VISIBLE [", serie_id, "]: ", path, " trae datos en la fila ", fila_dato,
           " despues de ", periodo_max, " (columna ", .fl_num_a_col(cf + con_dato[1]), "); el ",
           "periodo_referencia_max de 08_vintages.csv no es el ultimo periodo publicado (F6-19).")
    }
  }
  cf
}
