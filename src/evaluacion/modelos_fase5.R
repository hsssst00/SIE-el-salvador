# src/evaluacion/modelos_fase5.R
#
# Registro de los modelos de Fase 5 por grupo de comparación (F5-01, F5-03; decisión B1-3 de
# doc/metodologia/decisiones_fase5.md). Cada experimento principal de Fase 5 (F5_G1, F5_G2, F5_G3) corre los
# seis benchmarks de modelos_referencia.R más los modelos que este registro devuelve para su grupo, de modo
# que el MCS de cada grupo y horizonte compara a todos los competidores.
#
# Cada bloque (F5-01: B1 univariados, B2 multivariados, B3 regularizados, B3b MIDAS y puente, B4 árboles,
# B5 combinaciones) agrega aquí sus modelos, con su YAML en catalogos/06_modelos/ (C8) y su canario
# sintético (F5-02). B1a construyó la infraestructura (lectura de predictoras del corte, alineación, guardas
# G-7 y G-8, experimentos); B1b agrega los univariados de modelos_univariados.R (F5-06): UNI.ARIMA y UNI.UC_LLT
# en los tres grupos, la ARIMAX del grupo y, en G2, la ARIMAX de referencia con el IVAE. B2a agrega los VAR y el
# VECM de modelos_multivariados.R (F5-07, B2-1 a B2-4): MULT.VAR_DIF del grupo y, en G1, MULT.VAR_NIV.G1 y
# MULT.VECM.G1. B2b agrega el BVAR del grupo (F5-07, B2-5, B2-7, B2-10 a B2-14): MULT.BVAR.G1/.G2/.G3, con todas
# las series trimestrales del grupo (en G3, también las remesas reales; B1b-2) y sin piso de grados de libertad. El PR 1 de
# B3 (B3-8) carga forma_directa.R: forma directa por h y validación anidada (C3, C4; F5-05, F5-11, B3-1 a B3-7), la base de
# los regularizados y, si B4 lo decide, de los árboles. El PR 2 de B3 agrega los regularizados de modelos_regularizados.R
# (F5-09, B3-1 a B3-7): REG.ENET.Gk y REG.PCR.Gk, con todas las predictoras del grupo (B1b-2) y sin piso de grados de libertad.
# B3b agrega los de frecuencia mixta de modelos_frecuencia_mixta.R (F5-08, B3b-1 a B3b-6): MIX.UMIDAS.Gk (directo, con la
# forma directa y meses) y MIX.PUENTE.Gk (iterado), con las predictoras mensuales sin penalización (B1b-2) y el piso de G-8.
# B4 agrega los árboles de modelos_arboles.R (F5-10, B4-1 a B4-6), también directos sobre forma_directa.R: ML.RF.Gk
# (ranger) y ML.LGBM.Gk (lightgbm), con todas las predictoras del grupo y sin piso de grados de libertad.
#
# Contrato: el de eval_lib.R §4, más los campos opcionales de Fase 5:
#   piso_gl = TRUE   el ajuste devuelve gl = c(n_obs, n_par) y el motor exige n_obs - n_par >= PISO_GL (G-8);
#                    FALSE en el BVAR (B2-7), cuyo prior hace estimable el modelo, y en los regularizados (F5-09) y
#                    los árboles (F5-10)
#   requiere         series_master_id de las predictoras (predictoras_grupo()), además de "objetivo"
#   diagnosticar     función(ajuste) -> vector numérico nombrado (órdenes elegidos, número de condición, ...);
#                    el motor lo escribe por origen en diagnosticos.csv del experimento
# Sin I/O y sin estado global, como los benchmarks.

source(here::here("src", "evaluacion", "modelos_univariados.R"))     # B1: ARIMA, UC, ARIMAX
source(here::here("src", "evaluacion", "modelos_multivariados.R"))   # B2: VAR, VECM y BVAR
source(here::here("src", "evaluacion", "forma_directa.R"))           # B3 y B4: forma directa y validación anidada (C3, C4)
source(here::here("src", "evaluacion", "modelos_regularizados.R"))   # B3: elastic net y PCR
source(here::here("src", "evaluacion", "modelos_frecuencia_mixta.R")) # B3b: U-MIDAS y puente
source(here::here("src", "evaluacion", "modelos_arboles.R"))         # B4: random forest y LightGBM

#' Modelos de Fase 5 de un grupo de comparación, en el orden en que se reportan.
modelos_fase5 <- function(grupo) {
  if (length(grupo) != 1L || !grupo %in% names(GRUPOS_FASE4)) stop("modelos_fase5: grupo no declarado: ", paste(grupo, collapse = ", "))
  c(list(modelo_arima_fase5(), modelo_uc_llt(), modelo_arimax_grupo(grupo)),          # B1 (F5-06)
    if (grupo == "G2") list(modelo_arimax_ivae()),
    modelos_multivariados_grupo(grupo),                                                 # B2a (F5-07)
    list(modelo_bvar_grupo(grupo)),                                                     # B2b (F5-07)
    modelos_regularizados_grupo(grupo),                                                 # B3 (F5-09)
    modelos_frecuencia_mixta_grupo(grupo),                                              # B3b (F5-08)
    modelos_arboles_grupo(grupo))                                                       # B4 (F5-10)
}
