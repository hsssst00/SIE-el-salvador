# Analisis exploratorio de Fase 3 (senda §4) sobre la base maestra en data/L3_master/. Reglas
# puras en src/analisis/exploracion_series_reglas.R, ejercidas con datos sinteticos en
# tests/test-exploracion-series.R.
#
# Alcance: estadistica descriptiva y grafica (cobertura, huecos internos, momentos de nivel y
# primera diferencia, series de tiempo en nivel y en diferencia). Deliberadamente NO incluye
# pruebas formales de estacionariedad (ADF/KPSS/PP) -- ver nota en exploracion_series_reglas.R.
#
# Requiere `make master` ya corrido (data/L3_master/ poblado). Salidas:
#   doc/metodologia/reportes_fase3/reporte_exploratorio_resumen.csv -- una fila por serie.
#     VERSIONADO (decision de Harold, 2026-09-23): lo cita doc/metodologia/
#     reporte_exploratorio_fase3.md, y lo que un documento versionado cita tiene que estar en el
#     repositorio. La columna `fecha_generacion` dice de que corrida sale.
#   data/L3_master/exploracion/<serie>.png -- nivel + primera diferencia (capa generada, no
#     versionada: ningun documento los cita).

source(here::here("src", "analisis", "exploracion_series_reglas.R"))

dir_l3 <- here::here("data", "L3_master")
# Carpeta de graficos sin tilde, a proposito: es el nombre portable (UTF-8 en nombres de
# archivo se comporta distinto entre Windows, macOS y Linux, y este directorio se crea desde
# codigo en las tres). Si en una maquina quedaron PNG bajo "exploración", renombrar la carpeta
# a mano una vez -- una corrida nueva no los sobrescribe, los deja huerfanos al lado.
dir_out <- file.path(dir_l3, "exploracion")
dir.create(dir_out, showWarnings = FALSE, recursive = TRUE)
dir_reportes <- here::here("doc", "metodologia", "reportes_fase3")
dir.create(dir_reportes, showWarnings = FALSE, recursive = TRUE)
ruta_resumen <- file.path(dir_reportes, "reporte_exploratorio_resumen.csv")

archivos <- list.files(dir_l3, pattern = "\\.csv$", full.names = FALSE)
# Excluye subproductos que no son series L3 en si (catalogo de outliers).
archivos <- archivos[!grepl("_outliers\\.csv$", archivos)]

resumenes <- list()

for (a in archivos) {
  freq <- if (grepl("_Q\\.csv$", a)) "Q" else if (grepl("_M\\.csv$", a)) "M" else NA_character_
  if (is.na(freq)) {
    message("Omitido (sin sufijo _M/_Q reconocible): ", a)
    next
  }

  serie_id <- sub("\\.csv$", "", a)
  df <- read.csv(file.path(dir_l3, a), stringsAsFactors = FALSE, na.strings = "")
  df <- df[!is.na(df$valor), c("periodo", "valor")]

  if (nrow(df) < 2) {
    message("Omitido (menos de 2 obs no ausentes): ", a)
    next
  }

  resumenes[[serie_id]] <- resumen_serie(df, serie_id, freq)

  png(file.path(dir_out, paste0(serie_id, ".png")), width = 1000, height = 500, res = 120)
  op <- par(mfrow = c(1, 2), mar = c(4, 4, 2, 1))
  plot(seq_len(nrow(df)), df$valor, type = "l",
       main = paste0(serie_id, " (nivel)"), xlab = "obs #", ylab = "valor")
  plot(seq_len(nrow(df) - 1), diff(df$valor), type = "l",
       main = paste0(serie_id, " (1a diferencia)"), xlab = "obs #", ylab = "diff")
  par(op)
  dev.off()
}

resumen_tabla <- do.call(rbind, resumenes)
resumen_tabla <- resumen_tabla[order(resumen_tabla$serie_id), ]
resumen_tabla$fecha_generacion <- format(Sys.Date())
write.csv(resumen_tabla, ruta_resumen, row.names = FALSE, na = "")

cat("OK: resumen exploratorio de ", nrow(resumen_tabla), " serie(s) -> ", ruta_resumen, "\n",
    sep = "")
cat("OK: ", nrow(resumen_tabla), " grafico(s) -> ", dir_out, "/\n", sep = "")

huecos_reales <- resumen_tabla[resumen_tabla$n_hueco > 0, c("serie_id", "n_hueco", "huecos")]
if (nrow(huecos_reales) > 0) {
  cat("\nATENCION -- huecos internos detectados (periodos ausentes entre inicio y fin, no de borde):\n")
  print(huecos_reales, row.names = FALSE)
} else {
  cat("Sin huecos internos en ninguna serie.\n")
}
