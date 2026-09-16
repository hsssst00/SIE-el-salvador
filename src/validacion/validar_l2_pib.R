# L2 — batería de validaciones sobre data/L1_staging/BCR_PIB_series_largo.csv
# (senda metodológica §3.5, arquitectura L2 en §3.1). Debe FALLAR, no advertir,
# ante cualquier incumplimiento. No cubre UT.DEMANDA_TOTAL_MENSUAL: esa serie
# todavía no pasa por 03_series.csv (ver nota en src/transformacion/
# ut_demanda_serie.R) y ya trae sus propias validaciones de conteo/duplicados
# en ese script — no hay catálogo contra el cual validar su esquema aquí.
#
# Reglas en src/validacion/l2_pib_reglas.R (validar_l2()), para que
# tests/test-validar-l2-pib.R las ejerza con datos sintéticos sin tocar disco.
# validar_l2() devuelve list(errores, agente): agente es el ptblank_agent ya
# interrogado, árbitro unificado de los 5 checks. Acá se usa $errores para la
# decisión de fallar y $agente para escribir el reporte de calidad de datos
# (entregable de Fase 3, senda §4) como HTML autocontenido en data/L2_validated/
# -- capa generada, no se versiona (ver .gitignore) -- se reescribe en cada corrida.
# Checks, en el orden de §3.5:
#   1. Esquema: campos, tipos, dominio de "periodo" (trimestral ISO 8601).
#   2. Integridad referencial con catalogos/03_series.csv (en ambas direcciones:
#      todo serie_id de L1 declarado en el catálogo, y todo serie_id del
#      catálogo presente en L1 — ninguna serie declarada puede faltar en silencio).
#   3. Duplicados en la clave (serie_id, periodo).
#   4. Huecos no declarados: la secuencia de periodos de cada serie no debe
#      tener saltos entre su primer y último periodo observado.
#   5. Coherencia de agregados: identidad contable del enfoque de producción,
#      solo en precios corrientes (BCR.PIB_T.NOMINAL) — las series de volumen
#      son índices encadenados, no aditivos por construcción (no se valida esa
#      identidad ahí; no es un hueco de esta batería, es la naturaleza del dato).
#      suma(19 ramas VAB) = VAB total; VAB total + impuestos netos = PIB.
#      Tolerancia 0.05 (redondeo a 2 decimales propagado en una suma de 19 términos).

source(here::here("src", "validacion", "l2_pib_reglas.R"))

# Lista de inclusión, no de exclusión (corregido 2026-09-16, mismo motivo que
# src/transformacion/extraer_bcr_pib.R): valida solo el tramo de 03_series.csv que
# BCR_PIB_series_largo.csv realmente cubre, sin importar qué otras publicaciones se agreguen
# después al catálogo (p.ej. BCR.IVAE.VIGENTE).
PUBLICACIONES_PIB <- c(
  "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA",
  "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_SA",
  "BCR.PIB_T.NOMINAL",
  "BCR.PIB_T.SERIE_RETROPOLADA_1990_2005"
)

l1 <- read.csv("data/L1_staging/BCR_PIB_series_largo.csv", stringsAsFactors = FALSE, na.strings = "")
catalogo <- read.csv("catalogos/03_series.csv", stringsAsFactors = FALSE, na.strings = "")
catalogo <- catalogo[catalogo$publicacion_id %in% PUBLICACIONES_PIB, ]

resultado <- validar_l2(l1, catalogo)
errores <- resultado$errores

pointblank::export_report(
  resultado$agente,
  filename = "reporte_calidad_l2_pib.html",
  path = "data/L2_validated",
  quiet = TRUE
)

if (length(errores) > 0) {
  cat("\nVALIDACIÓN L2 FALLIDA (", length(errores), " problema(s)):\n\n", sep = "")
  for (e in errores) cat("  - ", e, "\n", sep = "")
  cat("\nReporte de calidad de datos: data/L2_validated/reporte_calidad_l2_pib.html\n")
  stop("L1 no pasa la batería de validaciones L2.")
}

message("Validación L2 OK: esquema, integridad referencial, duplicados, continuidad e identidad contable cumplen.")
message("Reporte de calidad de datos: data/L2_validated/reporte_calidad_l2_pib.html")
