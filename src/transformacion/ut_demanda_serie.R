# ut_demanda_serie.R
#
# Construye la serie larga de UT.DEMANDA_TOTAL_MENSUAL a partir de los archivos anuales ya
# registrados en L0 (data/L0_raw/, ver src/adquisicion/ut.R): el del vintage vigente de cada año.
# Serie admitida en catalogos/03_series.csv como UT.DEMANDA_ELEC.GWH.NSA.M (corregido 2026-09-18:
# este comentario decía "no pasa por 03_series.csv todavía", desactualizado desde que esa fila se
# agregó). Salida a data/L1_staging/, que por diseño de la senda (S7) no se versiona en Git -
# se versiona este script, no el resultado. Esquema largo (serie_id, periodo, valor,
# provisional) desde 2026-09-22 (hallazgo A1 del checklist de cierre de Fase 3) -- ver la nota
# junto a la escritura del archivo, más abajo, para el motivo.
#
# Desde 2026-09-30 (ADR-007, nota de seguimiento de esa fecha) ya no hay valores fijos de la
# captura original (25 archivos, 295 filas, 2026 hasta julio): un año puede tener varios vintages
# por recaptura, cuenta el último registrado de cada año, y lo esperado se deriva de
# catalogos/08_vintages.csv -- 12 meses por año anterior al máximo; para el año máximo, los meses
# de su periodo_referencia_max. Un año anterior al máximo con menos de 12 meses detiene el
# script (regla 7 de CLAUDE.md). El parser, el mapa año -> archivo y las validaciones viven en
# src/transformacion/ut_demanda_lib.R, donde las prueban tests/test-ut-serie.R y
# tests/test-ut-captura.R con archivos sintéticos.
#
# El año se toma SIEMPRE del nombre del archivo (manifiesto), nunca del contenido - 2002/2003
# tienen el campo interno "Año:" corrupto/con mojibake. Los nombres de mes en español no llevan
# tilde ni ñ, asi que esa corrupcion (limitada a la linea "Año:", que se descarta) no afecta
# ninguna celda de dato real - no hace falta resolver encoding para esto.

library(dplyr)

source(here::here("src", "transformacion", "vintage_lib.R"))
source(here::here("src", "transformacion", "ut_demanda_lib.R"))

source(here::here("src", "transformacion", "conjunto_lib.R"))

# Con SIE_CONJUNTO (make master CONJUNTO=... SALIDA=...) cuenta el vintage que el conjunto declara
# para cada año, no el último registrado (conjunto_lib.R).
serie <- construir_serie_ut(
  vintages = leer_vintages(),
  manifiesto = leer_manifiesto(here::here("data", "L0_raw")),
  dir_l0 = here::here("data", "L0_raw"),
  conjunto = conjunto_activo()
)

dir.create(ruta_capa("L1_staging"), showWarnings = FALSE, recursive = TRUE)

# Esquema largo (serie_id, periodo, valor, provisional) -- remediacion del hallazgo A1 del
# checklist de cierre de Fase 3 (2026-09-22): hasta acá esta serie escribía
# anio|mes|periodo|gwh, el único L1 de las series admitidas que no calzaba con el esquema que
# src/validacion/l2_serie_larga_reglas.R asume, así que quedaba fuera de la batería L2 de
# predictores (ver la nota de exclusión, ahora retirada, en validar_l2_predictores.R). serie_id
# es constante -- UT.DEMANDA_ELEC.GWH.NSA.M, la única fila de catalogos/03_series.csv con
# publicacion_id = UT.DEMANDA_TOTAL_MENSUAL -- y provisional es FALSE en todas las filas: ninguno
# de los CSV de origen marca un mes como preliminar/estimado (a diferencia de las
# publicaciones del BCR, que sí traen "(p)"/"(e)"). Las validaciones de construir_serie_ut()
# (años contiguos, meses esperados, años anteriores completos, duplicados por año-mes) siguen
# intactas -- son sobre la construcción de `serie`, no sobre el esquema de salida.
serie_larga <- data.frame(
  serie_id = "UT.DEMANDA_ELEC.GWH.NSA.M",
  periodo = serie$periodo,
  valor = serie$gwh,
  provisional = FALSE,
  stringsAsFactors = FALSE
)
ruta_salida <- ruta_capa("L1_staging", "UT_DEMANDA_series_largo.csv")
write.csv(serie_larga, ruta_salida, row.names = FALSE)

cat("OK:", nrow(serie_larga), "filas,", min(serie$anio), "-", max(serie$anio),
    "->", ruta_salida, "\n")
