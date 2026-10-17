# src/analisis_posterior/ap4_familias.R
#
# Análisis posterior AP-4 de Fase 5 (doc/metodologia/decisiones_fase5.md, «Análisis posteriores»): comparación por
# familia de modelos en la corrida principal (F5_G1, F5_G2, F5_G3), separando la precisión puntual (RMSE, MAE), la
# calidad probabilística (CRPS, cobertura) y la robustez ante valores extremos (error absoluto máximo, RMSE recortado,
# RMSE sin los targets de 2020-2021), y MCS de un representante por familia.
#
# Es POSTERIOR a los resultados: no cambia ningún modelo, YAML, experimento, tabla ni MCS de Fase 5, ni los tags.
# Los representantes los fijó Harold el 2026-10-15 con la regla «el de referencia», antes de calcular este MCS (commit
# 502e88a, rama del PR #64). El MCS de representantes es un contraste nuevo, posterior, y se rotula así.
#
# Familia = prefijo del modelo_id (BENCH, UNI, MULT, MIX, REG, ML, COMB). Los errores se reconstruyen desde
# pronosticos.csv de la L4 citada y el objetivo observado del corte (el mismo observado que usa el motor), y se
# comprueba que reproducen el RMSE y el MAE de metricas.csv antes de usarlos.
#
# Uso:
#   SIE_CONJUNTO=doc/metodologia/corte_fase5.csv SIE_SALIDA=data/conjuntos/corte_f5 Rscript src/analisis_posterior/ap4_familias.R
#
# Escribe en doc/metodologia/reportes_fase5/posteriores/ (LF): ap4_miembros.csv, ap4_familias.csv y
# ap4_mcs_representantes.csv. No escribe en data/.

source(here::here("src", "evaluacion", "motor_backtesting.R"))
source(here::here("src", "evaluacion", "tabla_resultados_fase4.R"))            # escribir_tabla_resultados()

DIR_AP <- here::here("doc", "metodologia", "reportes_fase5", "posteriores")
EXP_PRINCIPALES_AP4 <- c(G1 = "F5_G1", G2 = "F5_G2", G3 = "F5_G3")
FAMILIAS_AP4 <- c("BENCH", "UNI", "MULT", "MIX", "REG", "ML", "COMB")
REPRESENTANTES_AP4 <- c(BENCH = "BENCH.RW_SIN_DERIVA", UNI = "UNI.ARIMA", MULT = "MULT.VAR_DIF.%s", REG = "REG.ENET.%s",
                        MIX = "MIX.PUENTE.%s", ML = "ML.RF.%s", COMB = "COMB.MEDIA.%s")   # Harold, 2026-10-15 (502e88a)
FRACCION_RECORTE_AP4 <- 0.10   # RMSE recortado: sin el 10 % de errores cuadráticos más grandes de cada modelo y h
TOL_AP4 <- 1e-8

familia_de <- function(modelo_id) sub("\\..*$", "", modelo_id)
representantes_grupo <- function(grupo) unname(vapply(REPRESENTANTES_AP4, function(p) sub("%s", grupo, p, fixed = TRUE), character(1)))

#' Errores interanuales (observado − pronóstico) de un experimento, desde su pronosticos.csv y el objetivo observado.
errores_l4 <- function(exp_id, objetivo, dir_l4 = here::here("data", "L4_experiments")) {
  p <- utils::read.csv(file.path(dir_l4, exp_id, "pronosticos.csv"), stringsAsFactors = FALSE)
  y <- stats::setNames(objetivo$y, q_a_ind(objetivo$periodo))
  o <- q_a_ind(p$origen); tgt <- o + p$h
  p <- p[p$h %in% DISENO_FASE4$horizontes & tgt <= max(q_a_ind(objetivo$periodo)), ]
  o <- q_a_ind(p$origen); tgt <- o + p$h
  obs <- 100 * (unname(y[as.character(tgt)]) - unname(y[as.character(tgt - 4L)]))
  if (anyNA(obs)) stop("AP-4: falta un observado en ", exp_id)
  data.frame(modelo_id = p$modelo_id, origen = o, h = p$h, unidad = "yoy_pp", pronostico = p$yoy_pp_pronosticado,
             observado = obs, error = obs - p$yoy_pp_pronosticado, stringsAsFactors = FALSE)
}

#' Métricas por modelo y h de un experimento: las de L4 (RMSE, MAE, CRPS, cobertura, MCS) más las de extremos, con la
#' comprobación de que los errores reconstruidos dan el RMSE y el MAE de metricas.csv.
miembros_experimento <- function(exp_id, grupo, objetivo, dir_l4 = here::here("data", "L4_experiments")) {
  err <- errores_l4(exp_id, objetivo, dir_l4)
  met <- utils::read.csv(file.path(dir_l4, exp_id, "metricas.csv"), stringsAsFactors = FALSE)
  met <- met[met$unidad == "yoy_pp", ]
  mcs <- utils::read.csv(file.path(dir_l4, exp_id, "mcs.csv"), stringsAsFactors = FALSE)
  mcs <- mcs[mcs$unidad == "yoy_pp", ]
  sin <- SUBMUESTRAS_FASE4$sin_2020_2021
  filas <- lapply(split(err, list(err$modelo_id, err$h), drop = TRUE), function(e) {
    id <- e$modelo_id[1]; h <- e$h[1]
    m <- met[met$modelo_id == id & met$h == h, ]
    k <- mcs[mcs$modelo_id == id & mcs$h == h, ]
    if (nrow(m) != 1L || nrow(k) != 1L) stop("AP-4: ", exp_id, " no tiene una fila de métricas y MCS para ", id, " h = ", h)
    rmse <- sqrt(mean(e$error^2)); mae <- mean(abs(e$error))
    if (abs(rmse - m$rmse) > TOL_AP4 || abs(mae - m$mae) > TOL_AP4 || nrow(e) != m$n_pares) {
      stop(sprintf("AP-4: los errores reconstruidos de %s, %s, h = %d no dan el RMSE/MAE de metricas.csv", exp_id, id, h))
    }
    e2 <- sort(e$error^2)
    n_rec <- floor(length(e2) * (1 - FRACCION_RECORTE_AP4))
    keep <- sin(e$origen + e$h)
    data.frame(exp_id = exp_id, grupo = grupo, h = h, familia = familia_de(id), modelo_id = id, n_pares = nrow(e),
               rmse = rmse, mae = mae, crps = m$crps, cobertura_80 = m$cobertura_80, cobertura_95 = m$cobertura_95,
               en_mcs = as.logical(k$en_mcs), p_mcs = k$p_mcs,
               max_abs_error = max(abs(e$error)), rmse_recortado = sqrt(mean(e2[seq_len(n_rec)])),
               n_sin_2020_2021 = sum(keep), rmse_sin_2020_2021 = sqrt(mean(e$error[keep]^2)), stringsAsFactors = FALSE)
  })
  res <- do.call(rbind, filas)
  res[order(res$h, match(res$familia, FAMILIAS_AP4), res$modelo_id), ]
}

#' Resumen por familia × h × grupo: mejor miembro y miembro mediano en cada métrica, por separado, y proporción en el
#' MCS. El «mejor» de cada métrica se elige dentro de la familia para esa métrica, así que puede ser otro modelo.
familias_desde_miembros <- function(mb) {
  med <- function(x) if (all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
  mejor <- function(x, ids) if (all(is.na(x))) NA_character_ else ids[which.min(x)]
  out <- lapply(split(mb, list(mb$grupo, mb$h, mb$familia), drop = TRUE), function(d) {
    data.frame(grupo = d$grupo[1], h = d$h[1], familia = d$familia[1], n_miembros = nrow(d),
               n_con_densidad = sum(!is.na(d$crps)), prop_en_mcs = mean(d$en_mcs),
               rmse_mejor = min(d$rmse), rmse_mejor_modelo = mejor(d$rmse, d$modelo_id), rmse_mediana = med(d$rmse),
               mae_mejor = min(d$mae), mae_mediana = med(d$mae),
               crps_mejor = if (all(is.na(d$crps))) NA_real_ else min(d$crps, na.rm = TRUE),
               crps_mejor_modelo = mejor(d$crps, d$modelo_id), crps_mediana = med(d$crps),
               cobertura_80_mediana = med(d$cobertura_80), cobertura_95_mediana = med(d$cobertura_95),
               max_abs_error_mediana = med(d$max_abs_error), max_abs_error_peor = max(d$max_abs_error),
               rmse_recortado_mediana = med(d$rmse_recortado), rmse_sin_2020_2021_mediana = med(d$rmse_sin_2020_2021),
               stringsAsFactors = FALSE)
  })
  res <- do.call(rbind, out)
  res[order(res$grupo, res$h, match(res$familia, FAMILIAS_AP4)), ]
}

#' MCS (configuración de Fase 5: T_max, α = 0,10, B = 5000, deduplicación B2-9) con los representantes de un grupo.
#' Semilla propia: semilla_de("AP4_REP_<grupo>", "MCS", h), distinta de la de Fase 5.
mcs_representantes <- function(exp_id, grupo, objetivo, dir_l4 = here::here("data", "L4_experiments")) {
  ids <- representantes_grupo(grupo)
  err <- errores_l4(exp_id, objetivo, dir_l4)
  faltan <- setdiff(ids, unique(err$modelo_id))
  if (length(faltan)) stop("AP-4: faltan representantes en ", exp_id, ": ", paste(faltan, collapse = ", "))
  err <- err[err$modelo_id %in% ids, ]
  tag <- paste0("AP4_REP_", grupo)
  tab <- evaluar_errores(err, ids, tag, grupo, "yoy_pp", semilla_mcs = function(h) semilla_de(tag, "MCS", h),
                         benchmark = BENCHMARK, alpha = ALPHA_MCS, B = B_MCS, marca_h_largo = MARCA_TAMANO,
                         marcar_identicos = TRUE)
  m <- tab$mcs
  m$familia <- familia_de(m$modelo_id)
  m$rotulo <- "posterior_a_resultados"
  m[, c("exp_id", "grupo", "h", "familia", "modelo_id", "p_mcs", "en_mcs", "orden_eliminacion", "alpha", "replicas",
        "bloque", "semilla", "marca_tamano", "identico_a", "rotulo")]
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
  mb <- do.call(rbind, lapply(names(EXP_PRINCIPALES_AP4), function(g) miembros_experimento(EXP_PRINCIPALES_AP4[[g]], g, objetivo)))
  escribir_ap(mb, "ap4_miembros.csv")
  escribir_ap(familias_desde_miembros(mb), "ap4_familias.csv")
  escribir_ap(do.call(rbind, lapply(names(EXP_PRINCIPALES_AP4), function(g) mcs_representantes(EXP_PRINCIPALES_AP4[[g]], g, objetivo))),
              "ap4_mcs_representantes.csv")
}
