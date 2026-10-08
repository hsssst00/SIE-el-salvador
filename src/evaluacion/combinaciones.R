# src/evaluacion/combinaciones.R
#
# Combinaciones de pronósticos de Fase 5, bloque B5 (F5-13, F5-14e, F5-12 y B5-1 a B5-n de doc/metodologia/decisiones_fase5.md).
# No son modelos del contrato: son un paso posterior del orquestador (motor_backtesting.R, correr_experimento()) sobre los
# senderos que correr_backtest() ya produjo (F5-13). Sin I/O y sin estado global.
#
# Miembros (F5-13): todos los modelos de Fase 5 del experimento, sin los benchmarks; en las variantes con representantes
# (F5-14e), los presentes. Cuatro esquemas por grupo, sobre el log-nivel de cada h (equivale a combinar el crecimiento
# acumulado, porque y_o es común):
#   COMB.MEDIA.Gk       media simple
#   COMB.MEDIANA.Gk     mediana
#   COMB.RECORTADA.Gk   media recortada al 10 % (base::mean(trim = 0,1): ⌊0,1 M⌋ miembros de cada lado)
#   COMB.ECM_INV.Gk     pesos inversos al ECM descontado con δ = 0,9 (Stock y Watson, 2004): en el origen o y el
#                       horizonte h, w_m ∝ 1 / Σ_{o'} δ^{(o − h) − o'} e²_{m,o',h} sobre los orígenes o' del experimento con
#                       o' + h <= o; con menos de 8 errores, pesos iguales (F5-13). Los errores son los de la pérdida del
#                       experimento (yoy_pp) contra el objetivo como se ve en o (B5-1): no usan nada posterior a o.
# Sin densidad (F5-12): una mezcla de gaussianas no es gaussiana; las columnas de calibración quedan vacías.

ESQUEMAS_COMBINACION <- c("MEDIA", "MEDIANA", "RECORTADA", "ECM_INV")   # F5-13, en el orden en que se reportan
RECORTE_COMBINACION  <- 0.10   # F5-13
DELTA_ECM_INV        <- 0.9    # F5-13 (Stock y Watson, 2004)
MIN_ERRORES_ECM_INV  <- 8L     # F5-13: hasta acumular 8 errores, pesos iguales

ids_combinaciones <- function(grupo) paste0("COMB.", ESQUEMAS_COMBINACION, ".", grupo)

#' Miembros de las combinaciones de un grupo en la principal (F5-13): los modelos de Fase 5 del registro.
miembros_combinacion <- function(grupo) vapply(modelos_fase5(grupo), `[[`, character(1), "modelo_id")

#' Error en la unidad yoy_pp (F4-04) del sendero `s` (log-nivel, h = 1..H) emitido en o', contra el objetivo `yv` visto en
#' el origen de la combinación (nombrado por índice): con h <= 4 la base es observada; con h > 4, la del mismo sendero.
.error_yoy_sendero <- function(s, yv, op, h) {
  e <- function(j) unname(yv[as.character(op + j)]) - s[j]
  v <- if (h <= 4L) 100 * e(h) else 100 * (e(h) - e(h - 4L))
  if (!is.finite(v)) stop(sprintf("combinaciones: el objetivo visto en el origen no trae %s para el error de %s a h = %d", ind_a_q(op + h), ind_a_q(op), h))
  v
}

#' Combinaciones de un experimento (F5-13).
#'
#' @param pron        data.frame modelo_id, origen (índice), h, log_nivel_pronosticado (salida de correr_backtest()).
#' @param miembros    modelo_id de los miembros (presentes en `pron`).
#' @param grupo       grupo de comparación (sufijo de los modelo_id).
#' @param y_por_origen lista nombrada por origen (índice como texto) con el log-nivel del objetivo visto en ese origen,
#'                    nombrado por índice trimestral (el que recibieron los modelos).
#' @return data.frame con las columnas de `pron` (sd_* en NA) y el atributo "diagnosticos" (modelo_id, origen, clave, valor)
#'         con, para COMB.ECM_INV, el número de errores y el peso de cada miembro por h.
combinar_pronosticos <- function(pron, miembros, grupo, y_por_origen, delta = DELTA_ECM_INV, min_err = MIN_ERRORES_ECM_INV,
                                 recorte = RECORTE_COMBINACION) {
  if (length(miembros) < 2L) stop("combinaciones: hacen falta al menos dos miembros")
  faltan <- setdiff(miembros, unique(pron$modelo_id))
  if (length(faltan)) stop("combinaciones: miembros sin pronósticos: ", paste(faltan, collapse = ", "))
  origenes <- sort(unique(pron$origen[pron$modelo_id %in% miembros])); H <- max(pron$h)
  A <- array(NA_real_, c(length(origenes), H, length(miembros)), dimnames = list(origenes, seq_len(H), miembros))
  p <- pron[pron$modelo_id %in% miembros, ]
  A[cbind(match(p$origen, origenes), p$h, match(p$modelo_id, miembros))] <- p$log_nivel_pronosticado
  if (anyNA(A)) stop("combinaciones: los miembros no tienen senderos completos en todos los orígenes")
  ids <- ids_combinaciones(grupo)
  filas <- vector("list", length(origenes)); diags <- vector("list", length(origenes))
  for (io in seq_along(origenes)) {
    o <- origenes[io]
    yv <- y_por_origen[[as.character(o)]]
    if (is.null(yv)) stop("combinaciones: falta el objetivo visto en el origen ", ind_a_q(o))
    val <- matrix(NA_real_, H, length(ids)); dg <- list()
    for (h in seq_len(H)) {
      x <- A[io, h, ]
      prev <- which(origenes + h <= o)
      w <- rep(1 / length(miembros), length(miembros))
      if (length(prev) >= min_err) {
        E <- vapply(miembros, function(m) vapply(origenes[prev], function(op) .error_yoy_sendero(A[as.character(op), , m], yv, op, h), numeric(1)),
                    numeric(length(prev)))
        E <- matrix(E, nrow = length(prev))
        ecm <- colSums(delta^((o - h) - origenes[prev]) * E^2)
        if (any(!is.finite(ecm)) || any(!(ecm > 0))) stop(sprintf("combinaciones: ECM descontado no positivo en %s, h = %d", ind_a_q(o), h))
        w <- (1 / ecm) / sum(1 / ecm)
      }
      val[h, ] <- c(mean(x), stats::median(x), mean(x, trim = recorte), sum(w * x))
      dg[[h]] <- data.frame(modelo_id = ids[4], origen = o, clave = c(paste0("h", h, ".n_errores"), paste0("h", h, ".peso.", miembros)),
                            valor = c(length(prev), w), stringsAsFactors = FALSE)
    }
    filas[[io]] <- data.frame(modelo_id = rep(ids, each = H), origen = o, h = rep(seq_len(H), length(ids)),
                              log_nivel_pronosticado = as.vector(val), stringsAsFactors = FALSE)
    diags[[io]] <- do.call(rbind, dg)
  }
  out <- do.call(rbind, filas)
  for (cn in setdiff(names(pron), names(out))) out[[cn]] <- NA_real_
  out <- out[, names(pron)]
  rownames(out) <- NULL
  attr(out, "diagnosticos") <- do.call(rbind, diags)
  out
}
