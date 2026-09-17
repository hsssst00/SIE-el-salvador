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
# Tercer predictor: BCR.IPP.IDX.NSA.M (senda §6.4, precios). Igual que IVAE, es un índice de
# NIVEL (no un flujo) -- se agrega a trimestral por PROMEDIO, no por suma. A diferencia de IVAE,
# es NSA (la fuente no lo publica desestacionalizado); por la enmienda de ADR-010 (2026-09-16),
# eso no dispara ningún ajuste estacional propio en L3 -- ver ADR-010. No se deflacta: ya es un
# índice de precios, no una serie monetaria nominal (la pregunta de deflactación de ADR-010
# aplica a valores monetarios, no a índices de precios en sí mismos).
#
# Cuarto predictor: BCR.EXPORT_FOB.NOM.NSA.M (senda §6.4, comercio exterior). Exportaciones FOB
# de la Balanza Comercial de Mercancías -- distinta de BCR.EXPORT.NOM.NSA.Q (Cuentas
# Nacionales/SCN2008, bienes Y servicios, trimestral). Es un FLUJO mensual (como REMESAS), no un
# índice de nivel -- se agrega a trimestral por SUMA. Por decisión de Harold (2026-09-16,
# AskUserQuestion), esta sesión admite solo Exportaciones de las tres series de cabecera de la
# publicación (Exportaciones/Importaciones/Balanza); no se deflacta (solo nominal, por ahora).
#
# Salidas en data/L3_master/ (capa generada, no versionada):
#   BCR_IVAE_VOL_SA_M.csv / _Q.csv         -- pass-through mensual / promedio trimestral
#   BCR_REMESAS_NOM_NSA_M.csv / _Q.csv     -- pass-through mensual / suma trimestral
#   BCR_REMESAS_REAL_NSA_M.csv / _Q.csv    -- deflactada por IPC, mensual / suma trimestral
#   BCR_IPP_IDX_NSA_M.csv / _Q.csv         -- pass-through mensual / promedio trimestral
#   BCR_EXPORT_FOB_NOM_NSA_M.csv / _Q.csv  -- pass-through mensual / suma trimestral
#
# Quinto y sexto predictor (2026-09-16, misma sesión): BCR.ITCER.IDX.NSA.M (tipo de cambio real,
# serie global) y BCR.IPM.IDX.NSA.M (índice de precios de importación, de la publicación
# BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR). Ambos son índices de NIVEL como IVAE/IPP -- se agregan
# a trimestral por PROMEDIO. Sesión autorizada por Harold a proceder sin pregunta explícita por
# cada predictor (a diferencia de IPP/EXPORT_FOB); la elección de cuál serie de cabecera admitir
# de cada publicación multi-serie sigue el mismo criterio ya fijado (la más directa/agregada, ver
# 03_series.csv de cada una para el detalle).
#   BCR_ITCER_IDX_NSA_M.csv / _Q.csv       -- pass-through mensual / promedio trimestral
#   BCR_IPM_IDX_NSA_M.csv / _Q.csv         -- pass-through mensual / promedio trimestral

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

ipp_m <- read.csv("data/L1_staging/BCR_IPP_series_largo.csv", stringsAsFactors = FALSE, na.strings = "")
ipp_m <- ipp_m[ipp_m$serie_id == "BCR.IPP.IDX.NSA.M", c("periodo", "valor")]
ipp_m <- ipp_m[order(ipp_m$periodo), ]

ipp_q <- agregar_trimestral_promedio(ipp_m, etiqueta = "BCR.IPP.IDX.NSA.Q")

write.csv(ipp_m, "data/L3_master/BCR_IPP_IDX_NSA_M.csv", row.names = FALSE, na = "")
write.csv(ipp_q, "data/L3_master/BCR_IPP_IDX_NSA_Q.csv", row.names = FALSE, na = "")

cat("OK: BCR.IPP.IDX.NSA.M (", nrow(ipp_m), " obs, pass-through) -> ",
    "data/L3_master/BCR_IPP_IDX_NSA_M.csv\n", sep = "")
cat("OK: BCR.IPP.IDX.NSA.Q (", nrow(ipp_q), " obs, promedio trimestral) -> ",
    "data/L3_master/BCR_IPP_IDX_NSA_Q.csv\n", sep = "")

export_fob_m <- read.csv("data/L1_staging/BCR_BALANZA_COMERCIAL_series_largo.csv", stringsAsFactors = FALSE, na.strings = "")
export_fob_m <- export_fob_m[export_fob_m$serie_id == "BCR.EXPORT_FOB.NOM.NSA.M", c("periodo", "valor")]
export_fob_m <- export_fob_m[order(export_fob_m$periodo), ]

export_fob_q <- agregar_trimestral_suma(export_fob_m, etiqueta = "BCR.EXPORT_FOB.NOM.NSA.Q")

write.csv(export_fob_m, "data/L3_master/BCR_EXPORT_FOB_NOM_NSA_M.csv", row.names = FALSE, na = "")
write.csv(export_fob_q, "data/L3_master/BCR_EXPORT_FOB_NOM_NSA_Q.csv", row.names = FALSE, na = "")

cat("OK: BCR.EXPORT_FOB.NOM.NSA.M (", nrow(export_fob_m), " obs, pass-through) -> ",
    "data/L3_master/BCR_EXPORT_FOB_NOM_NSA_M.csv\n", sep = "")
cat("OK: BCR.EXPORT_FOB.NOM.NSA.Q (", nrow(export_fob_q), " obs, suma trimestral) -> ",
    "data/L3_master/BCR_EXPORT_FOB_NOM_NSA_Q.csv\n", sep = "")

itcer_m <- read.csv("data/L1_staging/BCR_ITCER_series_largo.csv", stringsAsFactors = FALSE, na.strings = "")
itcer_m <- itcer_m[itcer_m$serie_id == "BCR.ITCER.IDX.NSA.M", c("periodo", "valor")]
itcer_m <- itcer_m[order(itcer_m$periodo), ]

itcer_q <- agregar_trimestral_promedio(itcer_m, etiqueta = "BCR.ITCER.IDX.NSA.Q")

write.csv(itcer_m, "data/L3_master/BCR_ITCER_IDX_NSA_M.csv", row.names = FALSE, na = "")
write.csv(itcer_q, "data/L3_master/BCR_ITCER_IDX_NSA_Q.csv", row.names = FALSE, na = "")

cat("OK: BCR.ITCER.IDX.NSA.M (", nrow(itcer_m), " obs, pass-through) -> ",
    "data/L3_master/BCR_ITCER_IDX_NSA_M.csv\n", sep = "")
cat("OK: BCR.ITCER.IDX.NSA.Q (", nrow(itcer_q), " obs, promedio trimestral) -> ",
    "data/L3_master/BCR_ITCER_IDX_NSA_Q.csv\n", sep = "")

ipm_m <- read.csv("data/L1_staging/BCR_INDICES_PRECIOS_COMERCIO_EXTERIOR_series_largo.csv", stringsAsFactors = FALSE, na.strings = "")
ipm_m <- ipm_m[ipm_m$serie_id == "BCR.IPM.IDX.NSA.M", c("periodo", "valor")]
ipm_m <- ipm_m[order(ipm_m$periodo), ]

ipm_q <- agregar_trimestral_promedio(ipm_m, etiqueta = "BCR.IPM.IDX.NSA.Q")

write.csv(ipm_m, "data/L3_master/BCR_IPM_IDX_NSA_M.csv", row.names = FALSE, na = "")
write.csv(ipm_q, "data/L3_master/BCR_IPM_IDX_NSA_Q.csv", row.names = FALSE, na = "")

cat("OK: BCR.IPM.IDX.NSA.M (", nrow(ipm_m), " obs, pass-through) -> ",
    "data/L3_master/BCR_IPM_IDX_NSA_M.csv\n", sep = "")
cat("OK: BCR.IPM.IDX.NSA.Q (", nrow(ipm_q), " obs, promedio trimestral) -> ",
    "data/L3_master/BCR_IPM_IDX_NSA_Q.csv\n", sep = "")
