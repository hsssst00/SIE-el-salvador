# Mitad "estacionariedad" del análisis exploratorio de Fase 3 (senda §4) sobre la base maestra
# en data/L3_master/. Reglas puras en src/analisis/estacionariedad_reglas.R, ejercidas con datos
# sintéticos en tests/test-estacionariedad.R. Ver ese archivo para el detalle de la estrategia
# (ADF + KPSS confirmatorio, BIC, 4 transformaciones) y las decisiones que Harold fijó vía
# `AskUserQuestion` (2026-09-17, doc/checklist_fase3.md).
#
# Requiere `make master` ya corrido (data/L3_master/ poblado). Salida (capa generada, no
# versionada, mismo criterio que el resto de L3_master):
#   data/L3_master/reporte_estacionariedad.csv -- una fila por serie x transformación disponible
#
# Dos columnas de rezagos, no una (corregido 2026-09-18): `adf_rezagos` es la selección BIC
# efectiva -- la que corresponde al estadístico de la misma fila -- y `adf_techo_rezagos` el
# máximo de búsqueda de Schwert que se le pasó a ur.df(). Ver .rezagos_efectivos() en las
# reglas para por qué no son el mismo número.

source(here::here("src", "analisis", "estacionariedad_reglas.R"))

dir_l3 <- here::here("data", "L3_master")
archivos <- list.files(dir_l3, pattern = "\\.csv$", full.names = FALSE)
archivos <- archivos[grepl("_M\\.csv$|_Q\\.csv$", archivos)]  # mismo filtro que exploracion_series.R

resultados <- list()

for (a in archivos) {
  serie_id <- sub("\\.csv$", "", a)
  df <- read.csv(file.path(dir_l3, a), stringsAsFactors = FALSE, na.strings = "")
  # L3 no debe tener ausentes: las reglas de L2/L3 ya fallan ante uno (ver .agregar_trimestral()
  # en src/transformacion/l3_predictores_reglas.R). Descartarlos en silencio acá -- como hacía
  # la versión anterior -- convertía un ausente que no debería existir en una serie más corta
  # sin dejar rastro, y encima habría dejado correr ADF/KPSS sobre una serie con un hueco
  # interno tapado. La validación falla, no advierte (regla 7 de CLAUDE.md).
  if (anyNA(df$valor)) {
    stop("FALLO VISIBLE [", serie_id, "]: ", sum(is.na(df$valor)), " valor(es) ausente(s) en ",
         file.path(dir_l3, a), ", en el/los período(s): ",
         paste(df$periodo[is.na(df$valor)], collapse = ", "),
         ". L3 no debe tener ausentes -- corregir la transformación que generó el archivo, no acá.")
  }
  df <- df[, c("periodo", "valor")]
  df <- df[order(df$periodo), ]

  if (nrow(df) < 30) {
    message("Omitido (menos de 30 obs, insuficiente para ADF con selección BIC de rezagos): ", a)
    next
  }

  resultados[[serie_id]] <- analizar_estacionariedad_serie(df$valor, serie_id)
  cat("OK: ", serie_id, " (", nrow(df), " obs) -> ",
      nrow(resultados[[serie_id]]), " transformación(es) evaluada(s)\n", sep = "")
}

tabla <- do.call(rbind, resultados)
tabla <- tabla[order(tabla$serie_id, tabla$transformacion), ]
write.csv(tabla, file.path(dir_l3, "reporte_estacionariedad.csv"), row.names = FALSE, na = "")

cat("\nOK: reporte de estacionariedad de ", length(resultados), " serie(s), ", nrow(tabla),
    " fila(s) -> ", file.path(dir_l3, "reporte_estacionariedad.csv"), "\n", sep = "")

resumen_conclusion <- table(tabla$conclusion)
cat("\nResumen de conclusiones (serie x transformación):\n")
print(resumen_conclusion)
