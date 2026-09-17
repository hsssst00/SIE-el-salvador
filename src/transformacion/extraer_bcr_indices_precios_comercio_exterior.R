# Extractor L0 -> L1 para BCR.IPM_COMEXT.IDX.NSA.M (Indice de Precios de Importacion, Indices de
# Precios del Comercio Exterior, BCR) -- sexto predictor de la matriz (senda S6.4, precios de
# importacion), catalogado en catalogos/03_series.csv (publicacion_id =
# BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR).
#
# La publicacion trae tres series de cabecera en la misma hoja (Indice de Precios de
# Exportacion, Indice de Precios de Importacion, Indice de Terminos de Intercambio). Se admite
# solo IMPORTACION en esta pasada: es la serie que 01_publicaciones/
# BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR.yaml ya identifica como "candidato directo al predictor
# 'precios de importacion' que nombra S1.3 de la senda" -- no una eleccion nueva de esta sesion,
# sino la que el propio catalogo ya senalaba. Exportacion y Terminos de Intercambio quedan como
# candidatos futuros, no una omision (mismo criterio que BCR.BALANZA_COMERCIAL/BCR.ITCER).
# Autorizado a proceder sin pregunta explicita a Harold para esta tanda (instruccion de la
# sesion, 2026-09-16).
#
# Mismo mecanismo que src/transformacion/extraer_bcr_ivae.R, duplicado a proposito. Sin celdas
# vacias al inicio (arranca ene-2005 con dato real) -- no necesita el forward-fill extendido de
# extraer_bcr_ipp.R.
#
# Salida: data/L1_staging/BCR_INDICES_PRECIOS_COMERCIO_EXTERIOR_series_largo.csv, formato largo
# (serie_id, periodo, valor, provisional). periodo en formato "YYYY-Mnn".

library(readxl)

col_to_idx <- function(s) {
  Reduce(function(acc, ch) acc * 26L + (utf8ToInt(ch) - utf8ToInt("A") + 1L),
         strsplit(s, "")[[1]], accumulate = FALSE, init = 0L)
}

MESES_ABREV <- c(Ene = 1L, Feb = 2L, Mar = 3L, Abr = 4L, May = 5L, Jun = 6L,
                  Jul = 7L, Ago = 8L, Sep = 9L, Oct = 10L, Nov = 11L, Dic = 12L)

extraer_serie <- function(path, hoja, fila_dato, col_inicio, col_fin,
                           fila_anios, fila_trimestres, serie_id) {
  raw <- read_excel(path, sheet = hoja, col_names = FALSE, .name_repair = "minimal")
  ci <- col_to_idx(col_inicio)
  cf <- col_to_idx(col_fin)

  anios_raw <- as.character(unlist(raw[fila_anios, ci:cf]))
  for (i in seq_along(anios_raw)) {
    if (i > 1 && is.na(anios_raw[i])) anios_raw[i] <- anios_raw[i - 1]
  }
  anios <- suppressWarnings(as.integer(anios_raw))

  meses_raw <- as.character(unlist(raw[fila_trimestres, ci:cf]))
  mes_etiqueta <- trimws(sub("\\s*\\(.\\)$", "", meses_raw))
  mes_num <- unname(MESES_ABREV[mes_etiqueta])
  provisional <- grepl("\\(p\\)|\\(e\\)", meses_raw)

  vals_raw <- as.character(unlist(raw[fila_dato, ci:cf]))
  vals <- suppressWarnings(as.numeric(vals_raw))

  if (any(is.na(anios))) {
    stop("FALLO VISIBLE [", serie_id, "]: año no parseable en ", path,
         " hoja ", hoja, ", fila ", fila_anios)
  }
  if (any(is.na(mes_num))) {
    stop("FALLO VISIBLE [", serie_id, "]: mes no parseable en ", path,
         " hoja ", hoja, ", fila ", fila_trimestres, " (valores: ",
         paste(unique(meses_raw), collapse = ", "), ")")
  }
  faltantes_reales <- is.na(vals) & !is.na(vals_raw) & trimws(vals_raw) != ""
  if (any(faltantes_reales)) {
    stop("FALLO VISIBLE [", serie_id, "]: valor no numérico en ", path,
         " hoja ", hoja, ", fila ", fila_dato)
  }

  data.frame(
    serie_id = serie_id,
    periodo = sprintf("%d-M%02d", anios, mes_num),
    valor = vals,
    provisional = provisional,
    stringsAsFactors = FALSE
  )
}

series <- read.csv("catalogos/03_series.csv", stringsAsFactors = FALSE, na.strings = "")
series <- series[series$publicacion_id == "BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR", ]

if (nrow(series) == 0) {
  stop("FALLO VISIBLE: no hay filas de BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR en catalogos/03_series.csv.")
}

vintages <- read.csv("catalogos/08_vintages.csv", stringsAsFactors = FALSE, na.strings = "")

archivo_de_publicacion <- function(pub_id) {
  fila <- vintages[vintages$publicacion_id == pub_id, ]
  if (nrow(fila) < 1) {
    stop("FALLO VISIBLE: no se encontró ningún vintage para ", pub_id, " en 08_vintages.csv")
  }
  # Vintage vigente = última fila (manifiesto append-only, mismo criterio que
  # src/validacion/verificar_fuente_celda.R y scripts/verificar_l0.R).
  file.path("data/L0_raw", fila$archivo_raw[nrow(fila)])
}

resultados <- vector("list", nrow(series))
for (i in seq_len(nrow(series))) {
  fila <- series[i, ]
  path <- archivo_de_publicacion(fila$publicacion_id)
  if (!file.exists(path)) {
    stop("FALLO VISIBLE: archivo L0 ausente para ", fila$serie_id, ": ", path)
  }
  resultados[[i]] <- extraer_serie(
    path = path, hoja = fila$hoja, fila_dato = as.integer(fila$fila_dato),
    col_inicio = fila$col_inicio, col_fin = fila$col_fin,
    fila_anios = as.integer(fila$fila_anios),
    fila_trimestres = as.integer(fila$fila_trimestres),
    serie_id = fila$serie_id
  )
}

largo <- do.call(rbind, resultados)

# --- Validaciones (fallar de forma visible, no advertir) ---
if (nrow(largo) == 0) stop("FALLO VISIBLE: extracción produjo cero filas.")

dup <- largo[duplicated(largo[, c("serie_id", "periodo")]), ]
if (nrow(dup) > 0) {
  stop("FALLO VISIBLE: períodos duplicados dentro de una serie:\n",
       paste(capture.output(print(dup)), collapse = "\n"))
}

n_series_esperadas <- nrow(series)
n_series_obtenidas <- length(unique(largo$serie_id))
if (n_series_obtenidas != n_series_esperadas) {
  stop("FALLO VISIBLE: se esperaban ", n_series_esperadas, " series, se obtuvieron ",
       n_series_obtenidas)
}

dir.create("data/L1_staging", showWarnings = FALSE, recursive = TRUE)
largo <- largo[order(largo$serie_id, largo$periodo), ]
write.csv(largo, "data/L1_staging/BCR_INDICES_PRECIOS_COMERCIO_EXTERIOR_series_largo.csv", row.names = FALSE, na = "")

cat("OK:", nrow(largo), "observaciones,", n_series_obtenidas, "series ->",
    "data/L1_staging/BCR_INDICES_PRECIOS_COMERCIO_EXTERIOR_series_largo.csv\n")
