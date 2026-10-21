# armar_corte_fase6.R
#
# Arma doc/metodologia/corte_fase6.csv con la regla de F6-04: el último vintage de cada publicación que
# el pipeline necesita con la etapa de escenario activa (publicaciones_necesarias() de conjunto_lib.R),
# según fecha_publicacion de catalogos/08_vintages.csv; para las publicaciones por año (UT), el último
# vintage de cada año. A diferencia de scripts/armar_conjunto.R, no lee una L3: parte del catálogo.
# Hasta E1 del checklist de Fase 6 se vuelve a correr después de cada captura nueva (F6-04-b); desde E1
# el corte queda congelado y este script ya no se usa sobre él.
#
# Uso: Rscript scripts/armar_corte_fase6.R [salida = doc/metodologia/corte_fase6.csv]
#   Falla visible si el corte no valida contra los catálogos y L0 (validar_conjunto()).

source(here::here("src", "transformacion", "conjunto_lib.R"))

args <- commandArgs(trailingOnly = TRUE)
ruta_salida <- if (length(args) >= 1) args[1] else here::here("doc", "metodologia", "corte_fase6.csv")

series <- read.csv(here::here("catalogos", "03_series.csv"), stringsAsFactors = FALSE, na.strings = "")
master <- read.csv(here::here("catalogos", "05_series_master.csv"), stringsAsFactors = FALSE, na.strings = "")
vintages <- leer_vintages()
necesarias <- publicaciones_necesarias(series, master, NULL)

filas <- lapply(necesarias, function(p) {
  d <- vintages[vintages$publicacion_id == p, ]
  if (!nrow(d)) stop("FALLO VISIBLE: '", p, "' no tiene ningún vintage en 08_vintages.csv.")
  if (p %in% PUBLICACIONES_POR_ANIO) {
    d$anio <- sub("^.*\\.v(\\d{4})-\\d{2}$", "\\1", d$vintage_id)
    if (any(d$anio == d$vintage_id)) stop("FALLO VISIBLE: vintage de '", p, "' sin sufijo .vAAAA-MM.")
    d <- d[order(d$anio, d$fecha_publicacion, d$vintage_id), ]
    d <- d[!duplicated(d$anio, fromLast = TRUE), ]
  } else {
    d <- d[order(d$fecha_publicacion, d$vintage_id, na.last = FALSE), ]
    d <- d[nrow(d), ]
  }
  data.frame(publicacion_id = p, vintage_id = d$vintage_id, stringsAsFactors = FALSE)
})
corte <- do.call(rbind, filas)

dir_l0 <- here::here("data", "L0_raw")
validar_conjunto(corte, vintages, leer_manifiesto(dir_l0), dir_l0, publicaciones_necesarias(series, master, corte))

con <- file(ruta_salida, "wb")
writeLines(c("publicacion_id,vintage_id", paste(corte$publicacion_id, corte$vintage_id, sep = ",")), con, sep = "\n")
close(con)
cat("OK corte escrito: ", ruta_salida, " (", nrow(corte), " vintages de ", length(necesarias), " publicaciones)\n", sep = "")
