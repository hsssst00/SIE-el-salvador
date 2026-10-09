# src/evaluacion/tabla_resultados_fase4.R
#
# Tabla de resultados de Fase 4 (checklist E4 y E5; F4-30): RMSE, MAE y RMSE relativo por
# experimento, grupo, horizonte y modelo, con la pertenencia al MCS al lado, para la corrida
# principal y la batería de robustez R1-R6. Lee lo que escribió motor_backtesting.R en
# data/L4_experiments/<exp_id>/ y no recalcula nada: une metricas.csv con mcs.csv (y los
# *_submuestras.csv de R3/R4) en la unidad primaria de la pérdida (F4-04, yoy_pp).
#
# Uso:  Rscript src/evaluacion/tabla_resultados_fase4.R   (lo corre `make eval` después del motor)
#
# Escribe doc/metodologia/reportes_fase4/tabla_resultados_fase4.csv (versionado; LF). Formato
# largo, una fila por (exp_id, muestra_eval, h, modelo_id):
#   variante      principal | R1 | R2 | R3 | R4 | R5 | R6
#   muestra_eval  completa | pre2020 | post2020 (R3) | sin_2020 | sin_2020_2021 (R4)
#   exp_id, grupo, h, unidad, modelo_id, n_pares, rmse, mae, rmse_relativo, en_mcs, p_mcs,
#   marca_tamano (la del MCS: distorsion_tamano_documentada en h = 4, 8),
#   marca_n      (F4-35: n_bajo_calibracion si n_pares < 18, el piso calibrado por V9; vacía si no)
# R3 y R4 llevan el exp_id de la principal del grupo, que es donde el motor escribe sus tablas.
#
# Regla 7 de CLAUDE.md: si falta un experimento declarado o las tablas no casan 1 a 1, falla.

source(here::here("src", "evaluacion", "motor_backtesting.R"))   # EXPERIMENTOS; main() no corre al hacer source

VARIANTES_ORDEN <- c("principal", "R1", "R2", "R3", "R4", "R5", "R6")
MUESTRAS_ORDEN  <- c("completa", "pre2020", "post2020", "sin_2020", "sin_2020_2021")
# F4-35 (hallazgo I4 de la auditoría independiente de Fase 4): V9 de verificar_motor_sintetico.R
# calibra el MCS hasta n = 18 pares; las celdas con menos pares no se interpretan y se marcan.
N_MIN_CALIBRADO_MCS <- 18L
MARCA_N_BAJO <- "n_bajo_calibracion"

#' Variante del protocolo §5 de una fila de EXPERIMENTOS.
variante_de <- function(ex) {
  if (ex$objetivo == "PIB_SA_OFICIAL_Q") return("R5")
  if (ex$ventana == "rodante92") return("R1")
  if (ex$ventana == "homogenea2005") return("R2")
  if (ex$sa == "l3_unico") return("R6")
  if (ex$ventana == "expansiva" && ex$sa == "reestimado_en_origen") return("principal")
  stop("tabla: experimento sin variante reconocida: ", ex$exp_id)
}

#' Une métricas y MCS de una muestra en la unidad primaria. `met` y `mcs` pueden traer la columna
#' muestra_eval (submuestras) o no (muestra completa).
.unir_met_mcs <- function(met, mcs, perdida, exp_id, extra_met = character(0), extra_mcs = character(0)) {
  met <- met[met$unidad == perdida, , drop = FALSE]
  if (!"muestra_eval" %in% names(met)) met$muestra_eval <- "completa"
  if (!"muestra_eval" %in% names(mcs)) mcs$muestra_eval <- "completa"
  clave <- c("muestra_eval", "h", "modelo_id")
  if (anyDuplicated(met[, clave]) || anyDuplicated(mcs[, clave])) stop("tabla: claves duplicadas en ", exp_id)
  faltan <- c(setdiff(extra_met, names(met)), setdiff(extra_mcs, names(mcs)))
  if (length(faltan)) stop("tabla: faltan columnas en ", exp_id, ": ", paste(faltan, collapse = ", "))
  u <- merge(met[, c(clave, "exp_id", "grupo", "unidad", "n_pares", "rmse", "mae", "rmse_relativo", extra_met)],
             mcs[, c(clave, "en_mcs", "p_mcs", "marca_tamano", extra_mcs)], by = clave, all = TRUE)
  if (nrow(u) != nrow(met) || nrow(u) != nrow(mcs) || anyNA(u$rmse) || anyNA(u$en_mcs)) {
    stop("tabla: metricas y mcs no casan 1 a 1 en ", exp_id)
  }
  u
}

#' Tabla larga de resultados a partir de los directorios de L4 de los experimentos `exps`. `variante`, `orden`,
#' `extra_met` y `extra_mcs` los usa la tabla de Fase 5 (tabla_resultados_fase5.R); sus valores por defecto dan la
#' tabla de Fase 4 tal cual.
armar_tabla_resultados <- function(dir_l4, exps, perdida = "yoy_pp", variante = variante_de, orden = VARIANTES_ORDEN,
                                   extra_met = character(0), extra_mcs = character(0)) {
  partes <- list()
  for (k in seq_len(nrow(exps))) {
    ex <- exps[k, ]
    d <- file.path(dir_l4, ex$exp_id)
    if (!dir.exists(d)) stop("tabla: falta el directorio del experimento declarado ", ex$exp_id)
    lee <- function(nm) utils::read.csv(file.path(d, nm), stringsAsFactors = FALSE, na.strings = "")
    u <- .unir_met_mcs(lee("metricas.csv"), lee("mcs.csv"), perdida, ex$exp_id, extra_met, extra_mcs)
    u$variante <- variante(ex)
    partes[[length(partes) + 1L]] <- u
    subs <- file.path(d, c("metricas_submuestras.csv", "mcs_submuestras.csv"))
    tiene <- file.exists(subs)
    esperado <- isTRUE(ex$r3) || isTRUE(ex$r4)
    if (any(tiene) != esperado || (esperado && !all(tiene))) stop("tabla: submuestras de ", ex$exp_id, " no son las declaradas (r3/r4)")
    if (esperado) {
      s <- .unir_met_mcs(lee("metricas_submuestras.csv"), lee("mcs_submuestras.csv"), perdida, ex$exp_id, extra_met, extra_mcs)
      s$variante <- ifelse(s$muestra_eval %in% c("pre2020", "post2020"), "R3", "R4")
      partes[[length(partes) + 1L]] <- s
    }
  }
  t <- do.call(rbind, partes)
  if (!all(t$variante %in% orden) || !all(t$muestra_eval %in% MUESTRAS_ORDEN)) stop("tabla: variante o muestra fuera del dominio")
  t$en_mcs <- as.logical(t$en_mcs)
  t$marca_n <- ifelse(t$n_pares < N_MIN_CALIBRADO_MCS, MARCA_N_BAJO, "")
  t <- t[order(match(t$variante, orden), t$grupo, t$exp_id, match(t$muestra_eval, MUESTRAS_ORDEN), t$h, t$modelo_id), ]
  rownames(t) <- NULL
  t[, c("variante", "muestra_eval", "exp_id", "grupo", "h", "unidad", "modelo_id", "n_pares", "rmse", "mae",
        "rmse_relativo", "en_mcs", "p_mcs", "marca_tamano", "marca_n", extra_met, extra_mcs)]
}

escribir_tabla_resultados <- function(t, ruta) {
  dir.create(dirname(ruta), recursive = TRUE, showWarnings = FALSE)
  con <- file(ruta, open = "wb")                                                # LF en todas las plataformas
  utils::write.csv(t, con, row.names = FALSE, na = "", eol = "\n")
  close(con)
  invisible(ruta)
}

if (sys.nframe() == 0L) {
  t <- armar_tabla_resultados(here::here("data", "L4_experiments"), EXPERIMENTOS)
  ruta <- here::here("doc", "metodologia", "reportes_fase4", "tabla_resultados_fase4.csv")
  escribir_tabla_resultados(t, ruta)
  cat(sprintf("tabla_resultados_fase4.csv: %d filas, %d experimentos, sha256 %s\n", nrow(t), length(unique(t$exp_id)),
              digest::digest(file = ruta, algo = "sha256")))
}
