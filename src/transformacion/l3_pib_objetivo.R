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

source(here::here("src", "transformacion", "l3_pib_objetivo_reglas.R"))

l1 <- read.csv("data/L1_staging/BCR_PIB_series_largo.csv", stringsAsFactors = FALSE, na.strings = "")

concat <- concatenar_pib_nsa(l1)
ajuste <- ajustar_estacional_propio(concat)
oficial <- construir_pib_oficial(l1)

dir.create("data/L3_master", showWarnings = FALSE, recursive = TRUE)

write.csv(ajuste$sa, "data/L3_master/PIB_SA_PROPIO_Q.csv", row.names = FALSE, na = "")
write.csv(ajuste$outliers, "data/L3_master/PIB_SA_PROPIO_Q_outliers.csv", row.names = FALSE, na = "")
write.csv(oficial, "data/L3_master/PIB_SA_OFICIAL_Q.csv", row.names = FALSE, na = "")

cat("OK: PIB.SA.PROPIO.Q (", nrow(ajuste$sa), " obs, ", nrow(ajuste$outliers),
    " outlier(es) declarado(s)) -> data/L3_master/PIB_SA_PROPIO_Q.csv\n", sep = "")
cat("OK: PIB.SA.OFICIAL.Q (", nrow(oficial), " obs, pass-through) -> ",
    "data/L3_master/PIB_SA_OFICIAL_Q.csv\n", sep = "")
