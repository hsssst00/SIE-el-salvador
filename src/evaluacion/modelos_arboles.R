# src/evaluacion/modelos_arboles.R
#
# Árboles de Fase 5, bloque B4 (F5-10, F5-11, F5-12, F5-15 y B4-1 a B4-6 de doc/metodologia/decisiones_fase5.md), bajo
# el contrato del motor (eval_lib.R §4) por medio de la forma directa de forma_directa.R (modelo_directo(); C3 y C4).
# Sin I/O y sin estado global: cada modelo solo ve lo que el motor le pasa, ya recortado al origen (G-1).
#
#   ML.RF.Gk    random forest de regresión con ranger (F5-10): 500 árboles, mtry ∈ {⌈√p⌉, ⌈p/3⌉} (p = columnas de la
#               matriz directa: 12, 28 y 36 en G1, G2 y G3; en G1 los dos valen 4 y la rejilla se deduplica) y
#               min.node.size ∈ {5, 3}, elegidos por validación anidada (F5-11). Muestreo con reemplazo de n filas por
#               árbol, partición por varianza (los defectos de ranger), num.threads = 1 y sin error OOB (B4-2, B4-3).
#   ML.LGBM.Gk  gradient boosting con lightgbm (F5-10): objetivo L2, num_leaves ∈ {4, 8}, learning_rate = 0,05,
#               min_data_in_leaf = 5 y rondas ∈ {10, 20, ..., 500} por validación anidada (F5-11). Un entrenamiento por
#               num_leaves hasta la mayor ronda pedida y el pronóstico en cada ronda de la rejilla (num_iteration; B4-4).
#               num_threads = 1, deterministic = TRUE y force_row_wise = TRUE (F5-15); sin bagging ni submuestreo de
#               columnas, así que el ajuste no tiene componente aleatorio.
#
# Predictores (F5-10 = F5-09; B1b-2): Δy y el Δlog de todas las predictoras del grupo (en G3, también las remesas reales),
# rezagos 0..3. Directos por h (F5-05). Ventana (B4-1): la de B3-2 (transformar = TRUE): columnas y g_h sin la parte
# estacional; la estandarización no cambia los árboles. Sin piso de grados de libertad. Densidad (B4-2): Σ = D R D de los
# errores internos (F5-12, B3-5, B3-6), no los OOB. Semilla (F5-15, B4-3, B4-4): estimar_predecir() no recibe
# semilla_de(); cada llamada toma una semilla del generador de R, que el motor siembra con set.seed(semilla_de(exp_id,
# modelo, origen)) antes de ajustar(), y la pasa explícitamente (seed =) a ranger o lightgbm. Es la forma en que se cumple
# la semilla del motor de F5-15. La misma semilla sirve a todos los candidatos de la llamada. Las rejillas se ordenan de
# más a menos regularizado: un empate en el ECM interno va al candidato más regularizado.

NUM_ARBOLES_RF   <- 500L          # F5-10
NODO_MIN_RF      <- c(5L, 3L)     # F5-10: min.node.size ∈ {3, 5}, de más a menos regularizado (B4-3)
HOJAS_LGBM       <- c(4L, 8L)     # F5-10: num_leaves
TASA_LGBM        <- 0.05          # F5-10: learning_rate
DATOS_HOJA_LGBM  <- 5L            # F5-10: min_data_in_leaf
RONDAS_MAX_LGBM  <- 500L          # F5-10
PASO_RONDAS_LGBM <- 10L           # B4-4: rondas ∈ {10, 20, ..., 500}

#' Semilla de ranger o lightgbm tomada del generador de R (sembrado por el motor; F5-15).
.semilla_arboles <- function() sample.int(.Machine$integer.max, 1L)

#' Filas nuevas como matriz con los nombres de columna de la ventana (ranger los exige al predecir).
.filas_arboles <- function(Z, z) {
  nm <- colnames(Z)
  if (is.null(nm)) nm <- paste0("x", seq_len(ncol(Z)))
  list(Z = matrix(Z, nrow = nrow(Z), dimnames = list(NULL, nm)), z = matrix(z, ncol = ncol(Z), dimnames = list(NULL, nm)))
}

# ---------------------------------------------------------------------------------------------
# ML.RF (ranger)
# ---------------------------------------------------------------------------------------------

#' Valores de mtry de F5-10 para p columnas, sin duplicados y de menor a mayor (más aleatorio primero).
mtry_rf <- function(p) {
  if (length(p) != 1L || !is.finite(p) || p < 1) stop("ML.RF: número de columnas no válido")
  sort(unique(as.integer(c(ceiling(sqrt(p)), ceiling(p / 3)))))
}

#' Rejilla del RF (B4-3): min.node.size de mayor a menor y, dentro de cada uno, mtry de menor a mayor.
rejilla_rf <- function(Z, g, h, nodos = NODO_MIN_RF) {
  m <- mtry_rf(ncol(Z))
  data.frame(min_node_size = rep(as.integer(nodos), each = length(m)), mtry = rep(m, times = length(nodos)))
}

#' Pronósticos del RF en las filas de `z` para los candidatos `cand`: un bosque por candidato, todos con la misma semilla.
#' Falla si ranger no devuelve el bosque pedido o pronósticos finitos (B3-7).
estimar_predecir_rf <- function(Z, g, z, rejilla, cand, num_arboles = NUM_ARBOLES_RF) {
  semilla <- .semilla_arboles()
  f <- .filas_arboles(Z, z)
  P <- vapply(cand, function(j) {
    fit <- ranger::ranger(x = f$Z, y = g, num.trees = num_arboles, mtry = rejilla$mtry[j], min.node.size = rejilla$min_node_size[j],
                          replace = TRUE, sample.fraction = 1, splitrule = "variance", importance = "none", oob.error = FALSE,
                          num.threads = 1L, seed = semilla, verbose = FALSE)
    if (!identical(as.integer(fit$num.trees), as.integer(num_arboles))) {
      stop(sprintf("ML.RF: ranger devolvió %d árboles y se pidieron %d (B3-7)", fit$num.trees, num_arboles))
    }
    p <- stats::predict(fit, data = f$z, num.threads = 1L, seed = semilla, verbose = FALSE)$predictions
    if (!is.numeric(p) || length(p) != nrow(f$z) || any(!is.finite(p))) {
      stop(sprintf("ML.RF: pronósticos no finitos con mtry = %d y min.node.size = %d (B3-7)", rejilla$mtry[j], rejilla$min_node_size[j]))
    }
    p
  }, numeric(nrow(f$z)))
  as.numeric(P)
}

especificacion_rf <- function(num_arboles = NUM_ARBOLES_RF) list(
  transformar = TRUE,
  num_arboles = num_arboles,
  candidatos = function(Z, g, h) rejilla_rf(Z, g, h),
  estimar_predecir = function(Z, g, z, rejilla, cand) estimar_predecir_rf(Z, g, z, rejilla, cand, num_arboles),
  diagnosticar = function(rejilla, j) c(mtry = rejilla$mtry[j], min_node_size = rejilla$min_node_size[j])
)

# ---------------------------------------------------------------------------------------------
# ML.LGBM (lightgbm)
# ---------------------------------------------------------------------------------------------

#' Rejilla de LightGBM (B4-4): num_leaves de menor a mayor y, dentro de cada uno, rondas de menor a mayor.
rejilla_lgbm <- function(Z, g, h, hojas = HOJAS_LGBM, rondas_max = RONDAS_MAX_LGBM, paso = PASO_RONDAS_LGBM) {
  r <- seq.int(paso, rondas_max, by = paso)
  data.frame(num_leaves = rep(as.integer(hojas), each = length(r)), rondas = rep(as.integer(r), times = length(hojas)))
}

.parametros_lgbm <- function(hojas, semilla) list(
  objective = "regression", num_leaves = as.integer(hojas), learning_rate = TASA_LGBM, min_data_in_leaf = DATOS_HOJA_LGBM,
  num_threads = 1L, deterministic = TRUE, force_row_wise = TRUE, seed = semilla, verbose = -1L
)

#' Pronósticos de LightGBM en las filas de `z` para los candidatos `cand`. Por cada num_leaves presente en `cand` entrena
#' hasta su mayor número de rondas pedido y pronostica con las primeras r rondas de cada candidato (sin bagging, las
#' primeras r rondas no dependen de cuántas más se entrenen; así el pronóstico de un candidato no depende de qué otros se
#' piden). Con menos de 2 · min_data_in_leaf filas no hay partición posible y el modelo es la media de la ventana; no es
#' un error. Falla si el entrenamiento no deja ninguna ronda o si los pronósticos no son finitos (B3-7).
estimar_predecir_lgbm <- function(Z, g, z, rejilla, cand) {
  semilla <- .semilla_arboles()
  f <- .filas_arboles(Z, z)
  P <- matrix(NA_real_, nrow(f$z), length(cand))
  for (nl in unique(rejilla$num_leaves[cand])) {
    sel <- which(rejilla$num_leaves[cand] == nl)
    ds <- lightgbm::lgb.Dataset(f$Z, label = g, params = list(min_data_in_leaf = DATOS_HOJA_LGBM, num_threads = 1L, verbose = -1L))
    bst <- lightgbm::lgb.train(params = .parametros_lgbm(nl, semilla), data = ds, nrounds = max(rejilla$rondas[cand[sel]]),
                               verbose = -1L, serializable = FALSE)
    if (!(bst$current_iter() >= 1L)) stop(sprintf("ML.LGBM: el entrenamiento con num_leaves = %d no dejó ninguna ronda (B3-7)", nl))
    for (k in sel) {
      p <- stats::predict(bst, f$z, num_iteration = rejilla$rondas[cand[k]], params = list(num_threads = 1L))
      if (!is.numeric(p) || length(p) != nrow(f$z) || any(!is.finite(p))) {
        stop(sprintf("ML.LGBM: pronósticos no finitos con num_leaves = %d y %d rondas (B3-7)", nl, rejilla$rondas[cand[k]]))
      }
      P[, k] <- p
    }
  }
  as.numeric(P)
}

especificacion_lgbm <- function(rondas_max = RONDAS_MAX_LGBM, paso = PASO_RONDAS_LGBM) list(
  transformar = TRUE,
  rondas_max = rondas_max, paso_rondas = paso,
  candidatos = function(Z, g, h) rejilla_lgbm(Z, g, h, rondas_max = rondas_max, paso = paso),
  estimar_predecir = estimar_predecir_lgbm,
  diagnosticar = function(rejilla, j) c(num_leaves = rejilla$num_leaves[j], rondas = rejilla$rondas[j],
                                        borde = as.numeric(rejilla$rondas[j] %in% range(rejilla$rondas)))
)

# ---------------------------------------------------------------------------------------------
# Registro por grupo
# ---------------------------------------------------------------------------------------------

modelo_rf_grupo   <- function(grupo) modelo_directo(paste0("ML.RF.", grupo), predictoras_grupo(grupo), especificacion_rf())
modelo_lgbm_grupo <- function(grupo) modelo_directo(paste0("ML.LGBM.", grupo), predictoras_grupo(grupo), especificacion_lgbm())

#' Los árboles de un grupo (F5-10), con todas sus predictoras (B1b-2), en el orden en que se reportan.
modelos_arboles_grupo <- function(grupo) {
  if (length(grupo) != 1L || !grupo %in% names(GRUPOS_PREDICTORAS)) stop("modelos_arboles_grupo: grupo no declarado: ", paste(grupo, collapse = ", "))
  list(modelo_rf_grupo(grupo), modelo_lgbm_grupo(grupo))
}
