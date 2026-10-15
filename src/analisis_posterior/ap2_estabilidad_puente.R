# src/analisis_posterior/ap2_estabilidad_puente.R
#
# Análisis posterior AP-2 de Fase 5 (doc/metodologia/decisiones_fase5.md, «Análisis posteriores»), parte descriptiva:
# estabilidad en el tiempo del desempeño de MIX.PUENTE.Gk frente a los demás modelos de la corrida principal
# (F5_G1, F5_G2, F5_G3), por bloques de targets y por ventanas móviles de 12 targets.
#
# Es POSTERIOR a los resultados y NO INDEPENDIENTE: usa los mismos targets que Fase 5, así que describe la estabilidad
# pero no reduce el riesgo de haber elegido el puente por suerte. Esa es la tarea de la evaluación prospectiva de AP-2
# (borrador de protocolo aparte). No cambia nada de Fase 5.
#
# Los errores se reconstruyen desde pronosticos.csv de la L4 citada (e1722fa) y el objetivo observado del corte, con
# la misma comprobación que AP-4: tienen que dar el RMSE de metricas.csv.
#
# Uso:
#   SIE_CONJUNTO=doc/metodologia/corte_fase5.csv SIE_SALIDA=data/conjuntos/corte_f5 Rscript src/analisis_posterior/ap2_estabilidad_puente.R
#
# Escribe en doc/metodologia/reportes_fase5/posteriores/ (LF): ap2_bloques.csv y ap2_ventanas.csv.

source(here::here("src", "evaluacion", "motor_backtesting.R"))
source(here::here("src", "evaluacion", "tabla_resultados_fase4.R"))            # escribir_tabla_resultados()

DIR_AP <- here::here("doc", "metodologia", "reportes_fase5", "posteriores")
EXP_PRINCIPALES_AP2 <- c(G1 = "F5_G1", G2 = "F5_G2", G3 = "F5_G3")
BLOQUES_AP2 <- list(`2013-2016` = c("2013-Q1", "2016-Q4"), `2017-2019` = c("2017-Q1", "2019-Q4"),
                    `2020-2021` = c("2020-Q1", "2021-Q4"), `2022-2026` = c("2022-Q1", "2026-Q4"))   # por target
VENTANA_AP2 <- 12L        # targets consecutivos por ventana móvil
MIN_BLOQUE_AP2 <- 4L      # un bloque con menos targets no se reporta

#' Errores interanuales (observado − pronóstico) de un experimento, con la comprobación contra metricas.csv.
errores_verificados_ap2 <- function(exp_id, objetivo, dir_l4 = here::here("data", "L4_experiments")) {
  p <- utils::read.csv(file.path(dir_l4, exp_id, "pronosticos.csv"), stringsAsFactors = FALSE)
  y <- stats::setNames(objetivo$y, q_a_ind(objetivo$periodo))
  p$o <- q_a_ind(p$origen); p$t <- p$o + p$h
  p <- p[p$h %in% DISENO_FASE4$horizontes & p$t <= max(q_a_ind(objetivo$periodo)), ]
  obs <- 100 * (unname(y[as.character(p$t)]) - unname(y[as.character(p$t - 4L)]))
  if (anyNA(obs)) stop("AP-2: falta un observado en ", exp_id)
  e <- data.frame(modelo_id = p$modelo_id, h = p$h, t = p$t, error = obs - p$yoy_pp_pronosticado, stringsAsFactors = FALSE)
  met <- utils::read.csv(file.path(dir_l4, exp_id, "metricas.csv"), stringsAsFactors = FALSE)
  met <- met[met$unidad == "yoy_pp", ]
  r <- stats::aggregate(error ~ modelo_id + h, e, function(x) sqrt(mean(x^2)))
  k <- match(paste(r$modelo_id, r$h), paste(met$modelo_id, met$h))
  if (anyNA(k) || max(abs(r$error - met$rmse[k])) > 1e-8) stop("AP-2: los errores reconstruidos de ", exp_id, " no dan el RMSE de metricas.csv")
  e
}

#' RMSE por modelo en un subconjunto de targets, con el relativo al benchmark y el puesto de cada modelo (1 = menor).
.rmse_subconjunto <- function(e) {
  r <- stats::aggregate(error ~ modelo_id, e, function(x) sqrt(mean(x^2)))
  names(r)[2] <- "rmse"
  r$n <- as.integer(table(e$modelo_id)[r$modelo_id])
  r$rmse_relativo <- r$rmse / r$rmse[r$modelo_id == BENCHMARK]
  r$puesto <- rank(r$rmse, ties.method = "min")
  r
}

#' Por grupo, h y bloque de targets: RMSE, relativo al paseo y puesto de cada modelo.
bloques_ap2 <- function(e, grupo) {
  out <- list()
  for (h in DISENO_FASE4$horizontes) for (b in names(BLOQUES_AP2)) {
    lim <- q_a_ind(BLOQUES_AP2[[b]])
    eb <- e[e$h == h & e$t >= lim[1] & e$t <= lim[2], ]
    nt <- length(unique(eb$t))
    if (nt < MIN_BLOQUE_AP2) next
    r <- .rmse_subconjunto(eb)
    out[[length(out) + 1L]] <- data.frame(grupo = grupo, h = h, bloque = b, n_targets = nt, r[, c("modelo_id", "n", "rmse", "rmse_relativo", "puesto")],
                                          n_modelos = nrow(r), stringsAsFactors = FALSE)
  }
  do.call(rbind, out)
}

#' Por grupo y h, ventanas móviles de VENTANA_AP2 targets consecutivos: puesto y RMSE relativo del puente, y el modelo
#' de menor RMSE de la ventana.
ventanas_ap2 <- function(e, grupo) {
  puente <- paste0("MIX.PUENTE.", grupo)
  out <- list()
  for (h in DISENO_FASE4$horizontes) {
    eh <- e[e$h == h, ]; ts <- sort(unique(eh$t))
    if (length(ts) < VENTANA_AP2) next
    for (k in VENTANA_AP2:length(ts)) {
      ew <- eh[eh$t %in% ts[(k - VENTANA_AP2 + 1L):k], ]
      r <- .rmse_subconjunto(ew)
      i <- which(r$modelo_id == puente)
      out[[length(out) + 1L]] <- data.frame(grupo = grupo, h = h, target_inicio = ind_a_q(ts[k - VENTANA_AP2 + 1L]),
                                            target_fin = ind_a_q(ts[k]), n_modelos = nrow(r), puesto_puente = r$puesto[i],
                                            rmse_relativo_puente = r$rmse_relativo[i], mejor_modelo = r$modelo_id[which.min(r$rmse)],
                                            rmse_relativo_mejor = min(r$rmse_relativo), stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, out)
}

escribir_ap <- function(x, nombre) {
  dir.create(DIR_AP, showWarnings = FALSE, recursive = TRUE)
  rownames(x) <- NULL
  escribir_tabla_resultados(x, file.path(DIR_AP, nombre))
  cat(sprintf("%s: %d filas, sha256 %s\n", nombre, nrow(x), digest::digest(file = file.path(DIR_AP, nombre), algo = "sha256")))
}

if (sys.nframe() == 0L) {
  conjunto <- exigir_conjunto(conjunto_activo())
  objetivo <- leer_objetivo("PIB_SA_PROPIO_Q.csv", "revision_vigente", leer_vintages(), conjunto)
  es <- lapply(EXP_PRINCIPALES_AP2, errores_verificados_ap2, objetivo = objetivo)
  escribir_ap(do.call(rbind, lapply(names(es), function(g) bloques_ap2(es[[g]], g))), "ap2_bloques.csv")
  escribir_ap(do.call(rbind, lapply(names(es), function(g) ventanas_ap2(es[[g]], g))), "ap2_ventanas.csv")
}
