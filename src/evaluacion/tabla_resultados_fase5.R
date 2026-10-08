# src/evaluacion/tabla_resultados_fase5.R
#
# Tabla de resultados de Fase 5 (checklist E2-E4): RMSE, MAE y RMSE relativo por experimento, grupo, horizonte y
# modelo, con la pertenencia al MCS, la calibración de la densidad (cobertura al 80 y 95 % y CRPS; F4-33, F5-12) y la
# marca de pérdidas idénticas del MCS (identico_a, B2-9), para los F5_G* de la corrida única: la principal de cada grupo
# con R3 y R4 (submuestras) y las variantes R1, R2, R5, R6 y R7. Lee lo que escribió motor_backtesting.R en
# data/L4_experiments/<exp_id>/ y no recalcula nada, con el mismo armado que la tabla de Fase 4
# (armar_tabla_resultados() de tabla_resultados_fase4.R). Las combinaciones no tienen densidad (F5-12): sus columnas de
# calibración quedan vacías.
#
# Uso:  Rscript src/evaluacion/tabla_resultados_fase5.R   (lo corre `make eval` después del motor)
#
# Escribe doc/metodologia/reportes_fase5/tabla_resultados_fase5.csv (versionado; LF), con las columnas de la de Fase 4
# más cobertura_80, cobertura_95, crps e identico_a. La variante sale del sufijo del exp_id (F5_Gk_Rn, B5-2).
# Regla 7: si falta un experimento declarado o las tablas no casan 1 a 1, falla.

source(here::here("src", "evaluacion", "tabla_resultados_fase4.R"))   # armar_tabla_resultados(); EXPERIMENTOS_FASE5

VARIANTES_ORDEN_F5   <- c(VARIANTES_ORDEN, "R7")
COLUMNAS_DENSIDAD_F5 <- c("cobertura_80", "cobertura_95", "crps")

#' Variante de un experimento de Fase 5, por el sufijo de su exp_id (B5-2): F5_Gk es la principal; F5_Gk_Rn, la Rn.
variante_f5 <- function(ex) {
  if (!grepl(PATRON_EXP_PREREGISTRO, ex$exp_id)) stop("tabla: ", ex$exp_id, " no es un experimento de modelos de Fase 5")
  s <- sub("^F5_G[123]_?", "", ex$exp_id)
  if (!nzchar(s)) "principal" else s
}

experimentos_tabla_fase5 <- function() EXPERIMENTOS_FASE5[grepl(PATRON_EXP_PREREGISTRO, EXPERIMENTOS_FASE5$exp_id), , drop = FALSE]

armar_tabla_fase5 <- function(dir_l4, exps = experimentos_tabla_fase5()) {
  armar_tabla_resultados(dir_l4, exps, variante = variante_f5, orden = VARIANTES_ORDEN_F5,
                         extra_met = COLUMNAS_DENSIDAD_F5, extra_mcs = "identico_a")
}

if (sys.nframe() == 0L) {
  t <- armar_tabla_fase5(here::here("data", "L4_experiments"))
  ruta <- here::here("doc", "metodologia", "reportes_fase5", "tabla_resultados_fase5.csv")
  escribir_tabla_resultados(t, ruta)
  cat(sprintf("tabla_resultados_fase5.csv: %d filas, %d experimentos, sha256 %s\n", nrow(t), length(unique(t$exp_id)),
              digest::digest(file = ruta, algo = "sha256")))
}
