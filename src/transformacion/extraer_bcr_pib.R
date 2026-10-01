# Extractor genérico L0 -> L1 para las 98 series de las cuatro publicaciones de
# PIB del BCR (NSA, SA, NOMINAL, RETRO) en catalogos/03_series.csv. Usa los
# campos estructurados hoja/fila_dato/col_inicio/col_fin/fila_anios/
# fila_trimestres (poblados por scripts/estructurar_fuente_celda.R desde
# fuente_celda, corregidos por scripts/corregir_offset_retro.R para RETRO) para
# ubicar mecánicamente cada serie en su archivo XLSX de data/L0_raw/, sin volver
# a parsear el texto libre de fuente_celda.
#
# No cubre UT.DEMANDA_TOTAL_MENSUAL (ver src/transformacion/ut_demanda_serie.R,
# extracción de 25 CSV, no de una celda XLSX).
#
# Salida: data/L1_staging/BCR_PIB_series_largo.csv en formato largo
# (serie_id, periodo, valor, provisional) — una fila por observación, todas las
# series apiladas. "provisional" marca trimestres publicados como preliminares
# o estimados ("(p)"/"(e)" en el encabezado de trimestre de la fuente); no se
# descarta esa información porque revisiones futuras (nuevo vintage) pueden
# cambiar el valor.

library(readxl)

col_to_idx <- function(s) {
  Reduce(function(acc, ch) acc * 26L + (utf8ToInt(ch) - utf8ToInt("A") + 1L),
         strsplit(s, "")[[1]], accumulate = FALSE, init = 0L)
}

TRIM_ROMANO <- c(I = 1L, II = 2L, III = 3L, IV = 4L)

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

  trims_raw <- as.character(unlist(raw[fila_trimestres, ci:cf]))
  trim_etiqueta <- trimws(sub("\\s*\\(.\\)$", "", trims_raw))
  trim_num <- unname(TRIM_ROMANO[trim_etiqueta])
  provisional <- grepl("\\(p\\)|\\(e\\)", trims_raw)

  vals_raw <- as.character(unlist(raw[fila_dato, ci:cf]))
  vals <- suppressWarnings(as.numeric(vals_raw))

  if (any(is.na(anios))) {
    stop("FALLO VISIBLE [", serie_id, "]: año no parseable en ", path,
         " hoja ", hoja, ", fila ", fila_anios)
  }
  if (any(is.na(trim_num))) {
    stop("FALLO VISIBLE [", serie_id, "]: trimestre no parseable en ", path,
         " hoja ", hoja, ", fila ", fila_trimestres, " (valores: ",
         paste(unique(trims_raw), collapse = ", "), ")")
  }
  faltantes_reales <- is.na(vals) & !is.na(vals_raw) & trimws(vals_raw) != ""
  if (any(faltantes_reales)) {
    stop("FALLO VISIBLE [", serie_id, "]: valor no numérico en ", path,
         " hoja ", hoja, ", fila ", fila_dato)
  }

  data.frame(
    serie_id = serie_id,
    periodo = sprintf("%d-Q%d", anios, trim_num),
    valor = vals,
    provisional = provisional,
    stringsAsFactors = FALSE
  )
}

# Lista de inclusión, no de exclusión (corregido 2026-09-16): con una exclusión (p.ej. "todo
# menos UT") este extractor intentaría procesar cualquier publicación nueva que se agregue a
# 03_series.csv -- ya ocurrió con la primera fila de BCR.IVAE.VIGENTE, que rompía este script al
# parsear "Ene"/"Feb" como si fueran trimestres romanos. Las 4 publicaciones de PIB son fijas;
# una publicación nueva de PIB requeriría añadirla aquí explícitamente, no aparecer sola.
PUBLICACIONES_PIB <- c(
  "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA",
  "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_SA",
  "BCR.PIB_T.NOMINAL",
  "BCR.PIB_T.SERIE_RETROPOLADA_1990_2005"
)

series <- read.csv("catalogos/03_series.csv", stringsAsFactors = FALSE, na.strings = "")
series <- series[series$publicacion_id %in% PUBLICACIONES_PIB, ]

# Seleccion del archivo de L0: archivo_l0_vigente() (vintage_lib.R). Sin conjunto es el vintage
# vigente de siempre; con SIE_CONJUNTO (make master CONJUNTO=... SALIDA=...), el que el conjunto
# declara, con su sha256 verificado al usarse (conjunto_lib.R).
# Cambio de comportamiento (2026-09-30, PR-3): este extractor exigia EXACTAMENTE 1 vintage por
# publicacion (`nrow(fila) != 1`) y se rompia en cuanto se capturaba un segundo vintage del PIB.
# Ahora toma la ultima fila, como los otros siete extractores; solo cambia el caso que antes fallaba.
source(here::here("src", "transformacion", "conjunto_lib.R"))
vintages <- leer_vintages()
conjunto <- conjunto_activo()

resultados <- vector("list", nrow(series))
for (i in seq_len(nrow(series))) {
  fila <- series[i, ]
  path <- archivo_l0_vigente(fila$publicacion_id, conjunto, vintages)
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

dir.create(ruta_capa("L1_staging"), showWarnings = FALSE, recursive = TRUE)
largo <- largo[order(largo$serie_id, largo$periodo), ]
write.csv(largo, ruta_capa("L1_staging", "BCR_PIB_series_largo.csv"), row.names = FALSE, na = "")

cat("OK:", nrow(largo), "observaciones,", n_series_obtenidas, "series ->",
    ruta_capa("L1_staging", "BCR_PIB_series_largo.csv"), "\n")
