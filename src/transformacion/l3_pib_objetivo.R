# L1 -> L3 de la variable objetivo del PIB (target_primary y
# target_robustness en catalogos/05_series_master.csv). Reglas en
# src/transformacion/l3_pib_objetivo_reglas.R, para que
# tests/test-l3-pib-objetivo.R las ejerza con datos sinteticos sin tocar disco.
#
# Requiere data/L1_staging/BCR_PIB_series_largo.csv (generado por
# extraer_bcr_pib.R) ya validado por src/validacion/validar_l2_pib.R.
#
# Salidas en data/L3_master/ (capa generada, no versionada):
#   PIB_SA_PROPIO_Q.csv          -- PIB.SA.PROPIO.Q (target_primary, ADR-001/004)
#   PIB_SA_PROPIO_Q_outliers.csv -- fechas de outlier declaradas (ADR-004)
#   PIB_SA_OFICIAL_Q.csv         -- PIB.SA.OFICIAL.Q (target_robustness, pass-through)
#
# Las dos primeras llevan columna `vintage_id` desde 2026-09-22 (E3/D4, cierre de Fase 3): ver
# src/transformacion/vintage_lib.R para la lectura de "bitemporal" que implementa. En
# PIB_SA_PROPIO_Q.csv el vintage varía por período (T001 empalma dos publicaciones); en
# PIB_SA_OFICIAL_Q.csv es constante (pass-through de una sola publicación).

source(here::here("src", "transformacion", "l3_pib_objetivo_reglas.R"))
source(here::here("src", "transformacion", "vintage_lib.R"))

l1 <- read.csv(here::here("data", "L1_staging", "BCR_PIB_series_largo.csv"),
                stringsAsFactors = FALSE, na.strings = "")
series_catalogo <- read.csv(here::here("catalogos", "03_series.csv"), stringsAsFactors = FALSE, na.strings = "")
vintages <- leer_vintages()

concat <- concatenar_pib_nsa(l1)
ajuste <- ajustar_estacional_propio(concat)
oficial <- construir_pib_oficial(l1)

# fuente_pib_nsa_por_periodo() devuelve serie_id ("BCR.PIB.VOL.NSA.Q"/".RETRO"), no
# publicacion_id -- 08_vintages.csv se indexa por publicacion_id
# (BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA / BCR.PIB_T.SERIE_RETROPOLADA_1990_2005), que es
# un identificador distinto por diseño (una publicación puede tener varias series). Se resuelve
# uno contra el otro vía resolver_publicacion() (escalar -- vapply para el vector por período)
# antes de consultar el vintage.
serie_a_publicacion <- function(serie_ids) {
  vapply(serie_ids, resolver_publicacion, character(1), catalogo_series = series_catalogo)
}

fuente_por_periodo <- unname(serie_a_publicacion(fuente_pib_nsa_por_periodo(l1, ajuste$sa$periodo)))
sa_con_vintage <- agregar_vintage_por_fila(ajuste$sa, fuente_por_periodo, vintages)
outliers_fuente <- unname(serie_a_publicacion(fuente_pib_nsa_por_periodo(l1, ajuste$outliers$periodo)))
outliers_con_vintage <- agregar_vintage_por_fila(ajuste$outliers, outliers_fuente, vintages)
oficial_con_vintage <- agregar_vintage_constante(oficial, resolver_publicacion("BCR.PIB.VOL.SA.Q", series_catalogo), vintages)

dir.create(here::here("data", "L3_master"), showWarnings = FALSE, recursive = TRUE)

write.csv(sa_con_vintage, here::here("data", "L3_master", "PIB_SA_PROPIO_Q.csv"), row.names = FALSE, na = "")
write.csv(outliers_con_vintage, here::here("data", "L3_master", "PIB_SA_PROPIO_Q_outliers.csv"), row.names = FALSE, na = "")
write.csv(oficial_con_vintage, here::here("data", "L3_master", "PIB_SA_OFICIAL_Q.csv"), row.names = FALSE, na = "")

cat("OK: PIB.SA.PROPIO.Q (", nrow(ajuste$sa), " obs, ", nrow(ajuste$outliers),
    " outlier(es) declarado(s)) -> data/L3_master/PIB_SA_PROPIO_Q.csv\n", sep = "")
cat("OK: PIB.SA.OFICIAL.Q (", nrow(oficial), " obs, pass-through) -> ",
    "data/L3_master/PIB_SA_OFICIAL_Q.csv\n", sep = "")
