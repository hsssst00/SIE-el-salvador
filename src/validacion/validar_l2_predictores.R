# L2 — batería de validaciones (checks 1-4 de la senda metodológica §3.5, ver
# src/validacion/l2_serie_larga_reglas.R) sobre las siete series predictoras mensuales de
# data/L1_staging/ que alimentan src/transformacion/l3_predictores.R.
#
# Remediación del hallazgo I1 de la revisión independiente de Fase 3 (2026-09-17): antes, solo
# BCR_PIB_series_largo.csv pasaba por una batería (validar_l2_pib.R); las series predictoras
# entraban a L3 sin ningún control -- incluido el que atajaría el hallazgo C1 (col_vals_not_null
# sobre valor) una capa antes de la agregación mensual->trimestral.
#
# No cubre UT.DEMANDA_TOTAL_MENSUAL: mismo motivo que validar_l2_pib.R -- esa serie todavía no
# pasa por 03_series.csv y ya trae sus propias validaciones de conteo/duplicados en
# src/transformacion/ut_demanda_serie.R.
#
# El check 5 (identidad contable de agregados) no aplica: es específico del PIB nominal en
# precios corrientes y no tiene equivalente en una serie predictora aislada.

source(here::here("src", "validacion", "l2_serie_larga_reglas.R"))

# publicacion_id (03_series.csv) -> archivo L1 correspondiente. Mismo universo de siete series
# que src/transformacion/l3_predictores.R (ver FUENTE_L1 ahí), indexado por publicacion_id en
# vez de por serie_id porque acá el filtro de catálogo es por publicación, no por serie.
PREDICTORES <- list(
  list(publicacion_id = "BCR.IVAE.VIGENTE",
       archivo = here::here("data", "L1_staging", "BCR_IVAE_series_largo.csv")),
  list(publicacion_id = "BCR.REMESAS_FAMILIARES_MENSUAL",
       archivo = here::here("data", "L1_staging", "BCR_REMESAS_series_largo.csv")),
  list(publicacion_id = "ONEC.IPC.BASE_2009",
       archivo = here::here("data", "L1_staging", "ONEC_IPC_series_largo.csv")),
  list(publicacion_id = "BCR.IPP",
       archivo = here::here("data", "L1_staging", "BCR_IPP_series_largo.csv")),
  list(publicacion_id = "BCR.BALANZA_COMERCIAL",
       archivo = here::here("data", "L1_staging", "BCR_BALANZA_COMERCIAL_series_largo.csv")),
  list(publicacion_id = "BCR.ITCER",
       archivo = here::here("data", "L1_staging", "BCR_ITCER_series_largo.csv")),
  list(publicacion_id = "BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR",
       archivo = here::here("data", "L1_staging", "BCR_INDICES_PRECIOS_COMERCIO_EXTERIOR_series_largo.csv"))
)

catalogo_completo <- read.csv(here::here("catalogos", "03_series.csv"), stringsAsFactors = FALSE, na.strings = "")

dir.create(here::here("data", "L2_validated"), showWarnings = FALSE, recursive = TRUE)

errores_totales <- character(0)

for (p in PREDICTORES) {
  catalogo <- catalogo_completo[catalogo_completo$publicacion_id == p$publicacion_id, ]
  if (nrow(catalogo) == 0) {
    stop("FALLO VISIBLE: no hay filas de ", p$publicacion_id, " en catalogos/03_series.csv.")
  }
  l1 <- read.csv(p$archivo, stringsAsFactors = FALSE, na.strings = "")

  resultado <- validar_l2_serie_larga(l1, catalogo, freq = "M", label = paste("L2", p$publicacion_id))

  reporte_html <- paste0("reporte_calidad_l2_", tolower(gsub("[^A-Za-z0-9]+", "_", p$publicacion_id)), ".html")
  pointblank::export_report(
    resultado$agente,
    filename = reporte_html,
    path = here::here("data", "L2_validated"),
    quiet = TRUE
  )

  if (length(resultado$errores) > 0) {
    errores_totales <- c(errores_totales,
                          paste0("[", p$publicacion_id, "] ", resultado$errores))
  } else {
    message("Validación L2 OK: ", p$publicacion_id, " (", nrow(l1), " observaciones).")
  }
}

if (length(errores_totales) > 0) {
  cat("\nVALIDACIÓN L2 (predictores) FALLIDA (", length(errores_totales), " problema(s)):\n\n", sep = "")
  for (e in errores_totales) cat("  - ", e, "\n", sep = "")
  cat("\nReportes de calidad de datos: data/L2_validated/reporte_calidad_l2_*.html\n")
  stop("L1 no pasa la batería de validaciones L2 para una o más series predictoras.")
}

message("Validación L2 (predictores) OK para las ", length(PREDICTORES), " series: esquema, ",
        "integridad referencial, duplicados y continuidad cumplen.")
