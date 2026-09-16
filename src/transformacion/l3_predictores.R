# L1 -> L3 de la matriz de predictores (ADR-010). Reglas en
# src/transformacion/l3_predictores_reglas.R, para que tests/test-l3-predictores.R las ejerza
# con datos sinteticos.
#
# Primer predictor: BCR.IVAE.VOL.SA.M (senda §6.4). Ya es un índice de volumen (real) y ya
# viene desestacionalizado (SA) de la publicación del BCR — no requiere deflactación ni ajuste
# estacional propio (a diferencia de la variable objetivo, ver l3_pib_objetivo.R). Se conserva
# la frecuencia mensual (senda §4: "matriz de predictores mensuales y trimestrales") y se agrega
# a trimestral por promedio simple (BCR.IVAE.VOL.SA.Q), sin tratamiento de outlier (ADR-010).
#
# Salidas en data/L3_master/ (capa generada, no versionada):
#   BCR_IVAE_VOL_SA_M.csv -- pass-through mensual
#   BCR_IVAE_VOL_SA_Q.csv -- agregado trimestral (promedio de 3 meses)

source(here::here("src", "transformacion", "l3_predictores_reglas.R"))

ivae_m <- read.csv("data/L1_staging/BCR_IVAE_series_largo.csv", stringsAsFactors = FALSE, na.strings = "")
ivae_m <- ivae_m[ivae_m$serie_id == "BCR.IVAE.VOL.SA.M", c("periodo", "valor")]
ivae_m <- ivae_m[order(ivae_m$periodo), ]

ivae_q <- agregar_trimestral_promedio(ivae_m, etiqueta = "BCR.IVAE.VOL.SA.Q")

dir.create("data/L3_master", showWarnings = FALSE, recursive = TRUE)
write.csv(ivae_m, "data/L3_master/BCR_IVAE_VOL_SA_M.csv", row.names = FALSE, na = "")
write.csv(ivae_q, "data/L3_master/BCR_IVAE_VOL_SA_Q.csv", row.names = FALSE, na = "")

cat("OK: BCR.IVAE.VOL.SA.M (", nrow(ivae_m), " obs, pass-through) -> ",
    "data/L3_master/BCR_IVAE_VOL_SA_M.csv\n", sep = "")
cat("OK: BCR.IVAE.VOL.SA.Q (", nrow(ivae_q), " obs, promedio trimestral) -> ",
    "data/L3_master/BCR_IVAE_VOL_SA_Q.csv\n", sep = "")
