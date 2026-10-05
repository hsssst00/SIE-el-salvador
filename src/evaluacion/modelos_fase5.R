# src/evaluacion/modelos_fase5.R
#
# Registro de los modelos de Fase 5 por grupo de comparación (F5-01, F5-03; decisión B1-3 de
# doc/metodologia/decisiones_fase5.md). Cada experimento principal de Fase 5 (F5_G1, F5_G2, F5_G3) corre los
# seis benchmarks de modelos_referencia.R más los modelos que este registro devuelve para su grupo, de modo
# que el MCS de cada grupo y horizonte compara a todos los competidores.
#
# Cada bloque (F5-01: B1 univariados, B2 multivariados, B3 regularizados, B3b MIDAS y puente, B4 árboles,
# B5 combinaciones) agrega aquí sus modelos, con su YAML en catalogos/06_modelos/ (C8) y su canario
# sintético (F5-02). Hasta B1b la lista está vacía: B1a solo construye la infraestructura (lectura de
# predictoras del corte, alineación, guardas G-7 y G-8, experimentos).
#
# Contrato: el de eval_lib.R §4, más dos campos opcionales de Fase 5:
#   piso_gl = TRUE   el ajuste devuelve gl = c(n_obs, n_par) y el motor exige n_obs - n_par >= PISO_GL (G-8)
#   requiere         series_master_id de las predictoras (predictoras_grupo()), además de "objetivo"
# Sin I/O y sin estado global, como los benchmarks.

#' Modelos de Fase 5 de un grupo de comparación, en el orden en que se reportan.
modelos_fase5 <- function(grupo) {
  if (length(grupo) != 1L || !grupo %in% names(GRUPOS_FASE4)) stop("modelos_fase5: grupo no declarado: ", paste(grupo, collapse = ", "))
  list()
}
