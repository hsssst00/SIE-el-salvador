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
# máximo de búsqueda de Schwert. Ver .rezagos_efectivos() en las reglas para por qué no son el
# mismo número.
#
# La grilla de la búsqueda BIC va de 0 a ese techo y la selección la hace el archivo de reglas,
# no `urca` (corregido 2026-09-19): `ur.df(selectlags = "BIC")` nunca evalúa el modelo con 0
# rezagos. La nota de cabecera de estacionariedad_reglas.R explica el detalle y por qué importa.
# De ahí sale también la columna `adf_ljung_box_p`, el diagnóstico de autocorrelación residual
# de la regresión elegida: no detiene la corrida, hace visible la sub-parametrización.
#
# El CSV publica los valores críticos al 1%, 5% y 10% de las dos pruebas, no solo el del 5% que
# decide el veredicto (hallazgo I3): sin los otros dos, la marginalidad de una fila es invisible
# y nadie puede saber si el veredicto aguanta un cambio de umbral sin recomputar la corrida. Y
# publica `adf_tipo`/`kpss_tipo` (hallazgo M3), la especificación determinística que cada prueba
# mantuvo: es constante por transformación, pero sin esas dos columnas la tabla no se interpreta
# sin abrir el código.

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

  # La frecuencia sale del sufijo del nombre, el mismo que ya filtra `archivos` más arriba.
  # La necesita el diagnóstico de Ljung-Box de la regresión ADF (12 rezagos si es mensual, 4 si
  # es trimestral): es el período donde aparecería la estacionalidad que la especificación de
  # las pruebas no modela. Ver la nota de cabecera de estacionariedad_reglas.R.
  frecuencia <- if (grepl("_M$", serie_id)) "M" else "Q"

  resultados[[serie_id]] <- analizar_estacionariedad_serie(df$valor, serie_id, frecuencia)
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
