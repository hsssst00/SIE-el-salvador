# src/evaluacion/modelos_referencia.R
#
# Los seis modelos de referencia de la senda §6.1 bajo el contrato de modelo del motor
# (doc/metodologia/especificacion_motor_evaluacion.md §2 y §5). Sin I/O y sin estado global: cada
# modelo solo ve lo que el motor le pasa, ya recortado al origen.
#
# Todos se reestiman en cada origen sobre y = log-nivel del objetivo (ADR-001) y devuelven el
# sendero h = 1..h en log-nivel. Ninguno necesita paquetes fuera de Imports: los cinco primeros son
# R base (stats) y el ETS usa fable/fabletools/tsibble, ya fijados.
#
# Especificaciones (declaradas en catalogos/06_modelos/<modelo_id>.yaml antes de la primera corrida):
#   BENCH.RW_SIN_DERIVA      y_{o+h} = y_o                                   denominador del RMSE relativo (F4-07)
#   BENCH.RW_CON_DERIVA      y_{o+h} = y_o + h * mean(Δy)
#   BENCH.AR1                Δy_t = c + φ Δy_{t-1} + e, MCO, recursión acumulada a nivel
#   BENCH.ARP_BIC            Δy_t = c + Σ φ_j Δy_{t-j} + e, p ∈ 0..8 por BIC. La selección compara los
#                            nueve candidatos en la misma muestra común (la de p = 8); el p elegido se
#                            REESTIMA con la muestra máxima, descartando solo las p observaciones que
#                            sus rezagos exigen (decisión de Harold, 2026-09-24)
#   BENCH.MEDIA_CRECIMIENTO  yoy constante = media histórica de y_t - y_{t-4}; la base es observada
#                            para h <= 4 y pronosticada para h > 4 (asimetría de F4-04)
#   BENCH.ETS                fable::ETS(y ~ error("A") + trend("A") + season("N")), sin selección
#                            automática; el objetivo es SA, así que no lleva componente estacional

.y_de <- function(datos) {
  d <- datos$objetivo
  if (is.null(d) || !"y" %in% names(d)) stop("modelo de referencia: falta datos$objetivo$y")
  y <- d$y
  if (anyNA(y)) stop("modelo de referencia: el objetivo trae NA")
  y
}

#' Recursión de un AR(p) en Δy con constante, acumulada al log-nivel.
.recursion_ar <- function(c0, phi, dy_hist, y_o, h) {
  p <- length(phi); d <- dy_hist; sendero <- numeric(h); nivel <- y_o
  for (j in seq_len(h)) {
    dj <- c0 + if (p > 0L) sum(phi * rev(utils::tail(d, p))) else 0
    d <- c(d, dj); nivel <- nivel + dj; sendero[j] <- nivel
  }
  sendero
}

modelo_rw_sin_deriva <- function() list(
  modelo_id = "BENCH.RW_SIN_DERIVA", requiere = "objetivo",
  ajustar  = function(datos, spec) list(y_o = utils::tail(.y_de(datos), 1)),
  predecir = function(aj, h) rep(aj$y_o, h)
)

modelo_rw_con_deriva <- function() list(
  modelo_id = "BENCH.RW_CON_DERIVA", requiere = "objetivo",
  ajustar  = function(datos, spec) { y <- .y_de(datos); list(y_o = utils::tail(y, 1), deriva = mean(diff(y))) },
  predecir = function(aj, h) aj$y_o + seq_len(h) * aj$deriva
)

modelo_ar1 <- function() list(
  modelo_id = "BENCH.AR1", requiere = "objetivo",
  ajustar = function(datos, spec) {
    y <- .y_de(datos); dy <- diff(y); n <- length(dy)
    if (n < 3L) stop("BENCH.AR1: muestra insuficiente")
    b <- stats::coef(stats::lm(dy[-1] ~ dy[-n]))
    list(c0 = unname(b[1]), phi = unname(b[2]), dy = dy, y_o = utils::tail(y, 1))
  },
  predecir = function(aj, h) .recursion_ar(aj$c0, aj$phi, aj$dy, aj$y_o, h)
)

#' Selección de p por BIC sobre la muestra común de p_max, y estimación del p elegido sobre la
#' muestra máxima (expuesta para pruebas). `n_eff` es el tamaño de la muestra de selección; `n_est`,
#' el de la muestra de estimación.
seleccionar_ar_bic <- function(dy, p_max = 8L) {
  n <- length(dy)
  if (n <= p_max + 2L) stop("seleccionar_ar_bic: muestra insuficiente para p_max = ", p_max)
  t_idx <- (p_max + 1L):n; n_eff <- length(t_idx); yv <- dy[t_idx]
  X_todos <- sapply(seq_len(p_max), function(j) dy[t_idx - j])
  ajustes <- lapply(0:p_max, function(p) {
    X <- cbind(1, X_todos[, seq_len(p), drop = FALSE])
    f <- stats::lm.fit(X, yv)
    list(p = p, coef = f$coefficients, bic = n_eff * log(sum(f$residuals^2) / n_eff) + (p + 1) * log(n_eff))
  })
  bics <- vapply(ajustes, `[[`, numeric(1), "bic")
  p <- ajustes[[which.min(bics)]]$p
  # Reestimación del p elegido con la muestra máxima: descarta solo las p primeras observaciones.
  t_est <- (p + 1L):n
  X <- matrix(1, nrow = length(t_est), ncol = 1L)
  if (p > 0L) X <- cbind(X, sapply(seq_len(p), function(j) dy[t_est - j]))
  f <- stats::lm.fit(X, dy[t_est])
  list(p = p, c0 = unname(f$coefficients[1]), phi = unname(f$coefficients[-1]),
       bic = bics, n_eff = n_eff, n_est = length(t_est))
}

modelo_arp_bic <- function(p_max = 8L) list(
  modelo_id = "BENCH.ARP_BIC", requiere = "objetivo",
  ajustar = function(datos, spec) {
    y <- .y_de(datos); dy <- diff(y)
    s <- seleccionar_ar_bic(dy, p_max)
    c(s, list(dy = dy, y_o = utils::tail(y, 1)))
  },
  predecir = function(aj, h) .recursion_ar(aj$c0, aj$phi, aj$dy, aj$y_o, h)
)

modelo_media_crecimiento <- function() list(
  modelo_id = "BENCH.MEDIA_CRECIMIENTO", requiere = "objetivo",
  ajustar = function(datos, spec) {
    y <- .y_de(datos)
    if (length(y) < 5L) stop("BENCH.MEDIA_CRECIMIENTO: muestra insuficiente")
    list(g = mean(diff(y, lag = 4L)), ultimos4 = utils::tail(y, 4))
  },
  predecir = function(aj, h) {
    s <- numeric(h)
    for (j in seq_len(h)) s[j] <- (if (j <= 4L) aj$ultimos4[j] else s[j - 4L]) + aj$g
    s
  }
)

modelo_ets <- function() list(
  modelo_id = "BENCH.ETS", requiere = "objetivo",
  ajustar = function(datos, spec) {
    d <- datos$objetivo
    ts_ <- tsibble::tsibble(t = tsibble::yearquarter(sub("-Q", " Q", d$periodo, fixed = TRUE)), y = .y_de(datos), index = t)
    fabletools::model(ts_, ets = fable::ETS(y ~ error("A") + trend("A") + season("N")))
  },
  predecir = function(aj, h) as.numeric(fabletools::forecast(aj, h = h)$.mean)
)

#' Los seis benchmarks de la senda §6.1, en el orden en que se reportan.
modelos_referencia <- function() list(
  modelo_rw_sin_deriva(), modelo_rw_con_deriva(), modelo_ar1(),
  modelo_arp_bic(), modelo_media_crecimiento(), modelo_ets()
)
