# armar_conjunto.R
#
# Arma el CSV de un conjunto de vintages (publicacion_id,vintage_id; ver conjunto_lib.R) a partir de
# una L3 ya generada: toma los vintage_id de la columna vintage_id de cada serie de L3, separa los
# « + » (una serie derivada de varias publicaciones los une asi, p. ej. REMESAS_REAL) y suma el
# vintage de BCR.PIB_T.NOMINAL, que L3 no lleva (solo se usa para deflactar/objetivo, no se
# propaga a la columna). No decide que corte usar ni toca modelos: solo declara lo que L3 ya uso.
#
# Uso: Rscript scripts/armar_conjunto.R <salida.csv> <vintage_id_NOMINAL> [dir_L3 = data/L3_master]
#   El vintage de NOMINAL es argumento obligatorio: L3 no lo registra, asi que no hay forma de
#   inferirlo sin riesgo de mezclar cortes (regla 4 de CLAUDE.md). Falla visible si falta o si el
#   conjunto resultante no valida contra los catalogos y L0 (validar_conjunto()).

source(here::here("src", "transformacion", "conjunto_lib.R"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2 || length(args) > 3) {
  stop("FALLO VISIBLE: uso: Rscript scripts/armar_conjunto.R <salida.csv> <vintage_id_NOMINAL> ",
       "[dir_L3]")
}
ruta_salida <- args[1]
vintage_nominal <- args[2]
dir_l3 <- if (length(args) == 3) args[3] else here::here("data", "L3_master")

# Series de L3 con columna vintage_id: <serie>_{M,Q}.csv y PIB_SA_*.csv.
# Se excluyen los reportes (reporte_*.csv, *_outliers.csv: el outlier repite el vintage del PIB).
archivos <- list.files(dir_l3, pattern = "\\.csv$", full.names = TRUE)
archivos <- archivos[!grepl("^reporte_|_outliers\\.csv$", basename(archivos))]
if (length(archivos) == 0) stop("FALLO VISIBLE: no hay series en ", dir_l3)

ids <- unlist(lapply(archivos, function(f) {
  d <- read.csv(f, stringsAsFactors = FALSE, colClasses = "character")
  if (!"vintage_id" %in% names(d)) stop("FALLO VISIBLE: ", f, " no tiene columna vintage_id.")
  d$vintage_id
}))
ids <- unique(trimws(unlist(strsplit(ids, " + ", fixed = TRUE))))
ids <- c(ids, vintage_nominal)

vintages <- leer_vintages()
fila <- match(ids, vintages$vintage_id)
if (anyNA(fila)) {
  stop("FALLO VISIBLE: vintage(s) que no existen en catalogos/08_vintages.csv: ",
       paste(ids[is.na(fila)], collapse = ", "))
}
conjunto <- unique(data.frame(publicacion_id = vintages$publicacion_id[fila], vintage_id = ids,
                              stringsAsFactors = FALSE))
if (vintages$publicacion_id[match(vintage_nominal, vintages$vintage_id)] != "BCR.PIB_T.NOMINAL") {
  stop("FALLO VISIBLE: '", vintage_nominal, "' no es un vintage de BCR.PIB_T.NOMINAL.")
}
conjunto <- conjunto[order(conjunto$publicacion_id, conjunto$vintage_id), ]

# Mismas guardas que `make master`: aborta antes de escribir si el conjunto no valida.
dir_l0 <- here::here("data", "L0_raw")
validar_conjunto(conjunto, vintages, leer_manifiesto(dir_l0), dir_l0,
                 publicaciones_necesarias(read.csv(here::here("catalogos", "03_series.csv"),
                                                   stringsAsFactors = FALSE, na.strings = "")))

write.csv(conjunto, ruta_salida, row.names = FALSE, quote = FALSE)
cat("OK conjunto escrito: ", ruta_salida, " (", nrow(conjunto), " vintages de ",
    length(unique(conjunto$publicacion_id)), " publicaciones)\n", sep = "")
