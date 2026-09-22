# Corre HEGY (src/analisis/hegy_reglas.R) sobre las 16 series de data/L3_master/, mismo
# universo y mismo filtro de archivo que src/analisis/estacionariedad.R. Insumo de la nota de
# ADR-010 sobre componente estacional (D1 del checklist de cierre de Fase 3): responde si la
# estacionalidad de las series NSA es una raiz unitaria estacional (harian falta Δ_S, no solo
# Δ_1) o determinista (Δ_1 ya basta, pero las pruebas de estacionariedad quedan mal
# especificadas mientras no incluyan el componente estacional -- ver estacionariedad_reglas.R,
# que desde esta sesion SI lo incluye).
#
# Corre sobre el LOG de cada serie (todas son positivas en este universo -- ver
# transformaciones_candidatas() en estacionariedad_reglas.R para el mismo chequeo), igual que
# la evidencia que este script reemplaza: el logaritmo es la escala en que se interpreta la
# estacionalidad multiplicativa habitual de índices y magnitudes económicas.
#
# Salida (capa generada, no versionada, mismo criterio que reporte_estacionariedad.csv):
#   data/L3_master/reporte_hegy.csv -- una fila por serie con t_cero, t_nyq, F_estacional
#   conjunto, sus criticos simulados y la decision de rechazo en cada uno.
#
# 5000 replicas de simulacion por serie (mismo numero que la evidencia externa v2, D1): a ese
# tamaño, una serie mensual de ~400 obs tarda del orden de 30s en esta maquina -- la corrida
# completa de las 16 series tarda varios minutos. No es un target de `master` (no bloquea la
# base maestra); es parte de `explore` porque, como estacionariedad.R, es analisis, no
# transformacion.

source(here::here("src", "analisis", "hegy_reglas.R"))

REPLICAS_HEGY <- 5000L

dir_l3 <- here::here("data", "L3_master")
archivos <- list.files(dir_l3, pattern = "\\.csv$", full.names = FALSE)
archivos <- archivos[grepl("_M\\.csv$|_Q\\.csv$", archivos)]  # mismo filtro que estacionariedad.R

resultados <- list()

for (a in archivos) {
  serie_id <- sub("\\.csv$", "", a)
  df <- read.csv(file.path(dir_l3, a), stringsAsFactors = FALSE, na.strings = "")
  if (anyNA(df$valor)) {
    stop("FALLO VISIBLE [", serie_id, "]: ", sum(is.na(df$valor)), " valor(es) ausente(s) en ",
         file.path(dir_l3, a), " -- L3 no debe tener ausentes (regla 7 de CLAUDE.md).")
  }
  df <- df[order(df$periodo), ]

  if (any(df$valor <= 0)) {
    message("Omitido (valores no positivos, log no definido): ", a)
    next
  }

  frecuencia <- if (grepl("_M$", serie_id)) "M" else "Q"
  n_min <- if (frecuencia == "M") 30 else 20
  if (nrow(df) < n_min) {
    message("Omitido (menos de ", n_min, " obs, insuficiente para HEGY con S=",
            if (frecuencia == "M") 12 else 4, "): ", a)
    next
  }

  cat("Corriendo HEGY: ", serie_id, " (", nrow(df), " obs, ", REPLICAS_HEGY, " replicas)...\n", sep = "")
  resultados[[serie_id]] <- analizar_hegy_serie(log(df$valor), serie_id, frecuencia, replicas = REPLICAS_HEGY)
}

tabla <- do.call(rbind, resultados)
tabla <- tabla[order(tabla$serie_id), ]
write.csv(tabla, file.path(dir_l3, "reporte_hegy.csv"), row.names = FALSE, na = "")

cat("\nOK: HEGY de ", nrow(tabla), " serie(s) -> ", file.path(dir_l3, "reporte_hegy.csv"), "\n", sep = "")
cat("Rechazan raiz unitaria ESTACIONAL conjunta (Δ_S no hace falta): ",
    sum(tabla$rechaza_estacional_conjunta), " de ", nrow(tabla), "\n", sep = "")
cat("Rechazan raiz unitaria en frecuencia CERO: ", sum(tabla$rechaza_cero), " de ", nrow(tabla), "\n", sep = "")
