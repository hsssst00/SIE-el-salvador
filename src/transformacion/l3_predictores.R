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
# Segundo predictor: BCR.REMESAS.NOM.NSA.M (senda §6.4, sector externo). A diferencia de IVAE,
# es una serie NOMINAL (millones de US$ corrientes), no un índice, y es un FLUJO, no un nivel —
# por eso se agrega a trimestral por SUMA (agregar_trimestral_suma()), no por promedio. Por
# decisión de Harold (2026-09-16), se materializa en dos versiones: nominal (pass-through) y
# real (deflactada por ONEC.IPC.IDX.NSA.M, T004_DEFLACTAR_REMESAS) — ver 04_transformaciones.
# La serie real solo cubre desde 2009-M12 (arranque de ONEC.IPC.BASE_2009), aunque la nominal
# cubre desde 1991-M01 — deflactar_serie() recorta a la intersección, no inventa el tramo previo.
#
# Salidas en data/L3_master/ (capa generada, no versionada):
#   BCR_IVAE_VOL_SA_M.csv / _Q.csv       -- pass-through mensual / promedio trimestral
#   BCR_REMESAS_NOM_NSA_M.csv / _Q.csv   -- pass-through mensual / suma trimestral
#   BCR_REMESAS_REAL_NSA_M.csv / _Q.csv  -- deflactada por IPC, mensual / suma trimestral

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

remesas_nom_m <- read.csv("data/L1_staging/BCR_REMESAS_series_largo.csv", stringsAsFactors = FALSE, na.strings = "")
remesas_nom_m <- remesas_nom_m[remesas_nom_m$serie_id == "BCR.REMESAS.NOM.NSA.M", c("periodo", "valor")]
remesas_nom_m <- remesas_nom_m[order(remesas_nom_m$periodo), ]

ipc_m <- read.csv("data/L1_staging/ONEC_IPC_series_largo.csv", stringsAsFactors = FALSE, na.strings = "")
ipc_m <- ipc_m[ipc_m$serie_id == "ONEC.IPC.IDX.NSA.M", c("periodo", "valor")]
ipc_m <- ipc_m[order(ipc_m$periodo), ]

remesas_real_m <- deflactar_serie(remesas_nom_m, ipc_m, etiqueta = "BCR.REMESAS.REAL.NSA.M")

remesas_nom_q <- agregar_trimestral_suma(remesas_nom_m, etiqueta = "BCR.REMESAS.NOM.NSA.Q")
remesas_real_q <- agregar_trimestral_suma(remesas_real_m, etiqueta = "BCR.REMESAS.REAL.NSA.Q")

write.csv(remesas_nom_m, "data/L3_master/BCR_REMESAS_NOM_NSA_M.csv", row.names = FALSE, na = "")
write.csv(remesas_nom_q, "data/L3_master/BCR_REMESAS_NOM_NSA_Q.csv", row.names = FALSE, na = "")
write.csv(remesas_real_m, "data/L3_master/BCR_REMESAS_REAL_NSA_M.csv", row.names = FALSE, na = "")
write.csv(remesas_real_q, "data/L3_master/BCR_REMESAS_REAL_NSA_Q.csv", row.names = FALSE, na = "")

cat("OK: BCR.REMESAS.NOM.NSA.M (", nrow(remesas_nom_m), " obs, pass-through) -> ",
    "data/L3_master/BCR_REMESAS_NOM_NSA_M.csv\n", sep = "")
cat("OK: BCR.REMESAS.NOM.NSA.Q (", nrow(remesas_nom_q), " obs, suma trimestral) -> ",
    "data/L3_master/BCR_REMESAS_NOM_NSA_Q.csv\n", sep = "")
cat("OK: BCR.REMESAS.REAL.NSA.M (", nrow(remesas_real_m), " obs, deflactada por IPC) -> ",
    "data/L3_master/BCR_REMESAS_REAL_NSA_M.csv\n", sep = "")
cat("OK: BCR.REMESAS.REAL.NSA.Q (", nrow(remesas_real_q), " obs, suma trimestral) -> ",
    "data/L3_master/BCR_REMESAS_REAL_NSA_Q.csv\n", sep = "")
