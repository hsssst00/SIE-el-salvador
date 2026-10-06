# src/evaluacion/modelos_univariados.R
#
# Modelos univariados de Fase 5 (bloque B1; F5-06, F5-12 y B1-1 a B1-5, B1b-1 de
# doc/metodologia/decisiones_fase5.md) bajo el contrato de modelo del motor (eval_lib.R §4; especificación del
# motor §2), con los campos opcionales de Fase 5 (`piso_gl`, `diagnosticar`). Sin I/O y sin estado global: cada
# modelo solo ve lo que el motor le pasa, ya recortado al origen (G-1) y con el borde completo (G-7).
#
#   UNI.ARIMA           ARIMA(p, d, q) sobre y = log-nivel SA, sin parte estacional; d por KPSS dentro del origen
#                       (diferencias_kpss(), la regla de fable sin `feasts`), p, q en 0..4 por BIC con búsqueda
#                       exhaustiva (fable::ARIMA, stepwise = FALSE, sin aproximación); constante elegida por fable
#                       por BIC si d <= 1 y excluida si d = 2 (regla de forecast::auto.arima).
#   UNI.UC_LLT          tendencia lineal local, stats::StructTS(type = "trend") sobre y (máxima verosimilitud).
#   UNI.ARIMAX.G1..G3   Δy_t = c + β'x_t + δ'D_t + η_t, η ARMA(p, q) por BIC (B1-1: d = 1 fijo); x = Δlog de las
#                       predictoras trimestrales del grupo para modelos sin penalización (predictoras_no_penalizadas():
#                       todas en G1 y G2; en G3, sin las remesas reales, B1b-1 y B1b-2) con los rezagos de B1-2, D =
#                       dummies estacionales si alguna predictora es NSA. Grillas de B1-2. Las predictoras se proyectan
#                       dentro del origen con un AR(p)-BIC en Δlog, con dummies si son NSA (F5-05).
#   UNI.ARIMAX_IVAE.G2  la misma forma con el IVAE (SA, sin dummies) como única predictora (referencia de F5-06).
#
# Densidad (F5-12): gaussiana plug-in del sendero en log-nivel, list(media = sendero, cov).
#   ARIMA   pesos ψ del ARIMA integrado: C[j, k] = ψ_{j-k} y cov = σ² C C' (σ² de fable, la de su pronóstico).
#   UC      recursión del filtro de Kalman sobre el estado final del ajuste: Cov(y_{o+k}, y_{o+j}) = Z T^{k-j} P_j Z'
#           + h 1{j = k}, con P_j la covarianza del estado a j pasos (la diagonal es la de stats::KalmanForecast).
#   ARIMAX  sistema lineal conjunto del ARIMAX y de los AR de sus predictoras: el error del sendero es lineal en las
#           innovaciones futuras w_r = (e_r, u_1r, ..., u_kr), cov = G (I_h ⊗ Σ) G', con Σ la covarianza muestral
#           contemporánea completa de los residuos (B1-5), en los períodos donde todos los residuos existen.

ORDENES_UNI_ARIMA <- list(p_max = 4L, q_max = 4L, d_max = 2L)   # catalogos/06_modelos/UNI.ARIMA.yaml
P_MAX_PREDICTORAS <- 4L    # orden máximo del AR(p)-BIC de cada predictora (F5-05); en los YAML de las ARIMAX
KAPPA_MAX_ARIMAX  <- 1e4   # B1b-1: número de condición máximo de los regresores estandarizados

# ---------------------------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------------------------

#' Número de diferencias por KPSS (nivel, rezagos "short"), la regla de fable::ARIMA y forecast::ndiffs: se
#' diferencia mientras KPSS rechaza estacionariedad al 5 %, hasta d_max. fable la calcula con `feasts`, que no está
#' en renv.lock; urca::ur.kpss da el mismo estadístico y rechazar con p < 0,05 equivale a superar el valor crítico
#' tabulado del 5 % (feasts interpola el p-valor en esa misma tabla).
diferencias_kpss <- function(y, d_max = ORDENES_UNI_ARIMA$d_max) {
  d <- 0L; x <- y
  while (d < d_max) {
    k <- urca::ur.kpss(x, type = "mu", lags = "short")
    if (unname(k@teststat[1]) <= unname(k@cval[1, "5pct"])) break
    d <- d + 1L; x <- diff(x)
  }
  d
}

#' Coeficientes `pref1..prefn` de un vector nombrado; numeric(0) si n = 0 (paste0("ar", integer(0)) da "ar").
.coefs <- function(est, pref, n) if (n > 0L) unname(est[paste0(pref, seq_len(n))]) else numeric(0)

#' Dummies estacionales trimestrales (T2, T3, T4; la constante absorbe T1) para índices trimestrales.
dummies_trimestrales <- function(iq) {
  q <- as.integer(iq) %% 4L + 1L
  D <- vapply(2:4, function(k) as.numeric(q == k), numeric(length(q)))
  D <- matrix(D, ncol = 3L)
  colnames(D) <- c("T2", "T3", "T4")
  D
}

#' Pesos C (h x h) del error de pronóstico de un ARIMA(p, d, q) en el nivel: ψ del polinomio AR integrado
#' φ(B)(1 - B)^d con el MA θ(B) (convención de stats::arima: + θ), C[j, k] = ψ_{j-k}.
pesos_arima <- function(ar, ma, d, h) {
  pol <- c(1, -ar)
  for (i in seq_len(d)) pol <- c(pol, 0) - c(0, pol)
  ar_int <- -pol[-1]
  psi <- c(1, if (h > 1L) stats::ARMAtoMA(ar = ar_int, ma = ma, lag.max = h - 1L) else numeric(0))
  C <- matrix(0, h, h)
  for (j in seq_len(h)) for (k in seq_len(j)) C[j, k] <- psi[j - k + 1L]
  C
}

#' Δlog de una serie trimestral (data.frame periodo, valor) con su índice; falla si no es positiva o tiene huecos.
.dlog_q <- function(d, nombre) {
  if (!all(c("periodo", "valor") %in% names(d))) stop("ARIMAX: ", nombre, " necesita periodo y valor")
  iq <- q_a_ind(d$periodo)
  if (length(iq) < 3L) stop("ARIMAX: ", nombre, " tiene menos de 3 trimestres")
  if (any(diff(iq) != 1L)) stop("ARIMAX: ", nombre, " tiene trimestres faltantes o desordenados")
  if (anyNA(d$valor) || any(d$valor <= 0)) stop("ARIMAX: ", nombre, " trae valores no positivos o ausentes (se usa el Δlog)")
  stats::setNames(diff(log(d$valor)), iq[-1])
}

#' AR(p)-BIC con constante y regresores deterministas opcionales (dummies estacionales), al estilo de
#' seleccionar_ar_bic(): los candidatos p = 0..p_max se comparan en la muestra común de p_max y el p elegido se
#' reestima con la muestra máxima. `x` es un vector nombrado por índice trimestral. Sin dummies coincide con
#' seleccionar_ar_bic() (prueba en tests/test-modelos-univariados.R).
seleccionar_ar_bic_x <- function(x, dummies = FALSE, p_max = P_MAX_PREDICTORAS) {
  n <- length(x); iq <- as.integer(names(x))
  if (is.null(names(x)) || any(diff(iq) != 1L)) stop("seleccionar_ar_bic_x: x debe venir nombrada por trimestres consecutivos")
  D <- if (dummies) dummies_trimestrales(iq) else matrix(numeric(0), n, 0L)
  if (n <= p_max + ncol(D) + 2L) stop("seleccionar_ar_bic_x: muestra insuficiente para p_max = ", p_max)
  t_idx <- (p_max + 1L):n; n_eff <- length(t_idx)
  X_lags <- vapply(seq_len(p_max), function(j) x[t_idx - j], numeric(n_eff))
  X_lags <- matrix(X_lags, nrow = n_eff)
  bics <- vapply(0:p_max, function(p) {
    X <- cbind(1, D[t_idx, , drop = FALSE], X_lags[, seq_len(p), drop = FALSE])
    f <- stats::lm.fit(X, x[t_idx])
    n_eff * log(sum(f$residuals^2) / n_eff) + ncol(X) * log(n_eff)
  }, numeric(1))
  p <- which.min(bics) - 1L
  t_est <- (p + 1L):n
  X <- cbind(1, D[t_est, , drop = FALSE])
  if (p > 0L) X <- cbind(X, matrix(vapply(seq_len(p), function(j) x[t_est - j], numeric(length(t_est))), nrow = length(t_est)))
  f <- stats::lm.fit(X, x[t_est])
  b <- unname(f$coefficients)
  list(p = p, c0 = b[1], gamma = b[1L + seq_len(ncol(D))], phi = b[1L + ncol(D) + seq_len(p)], dummies = dummies,
       bic = bics, n_eff = n_eff, n_est = length(t_est), s2 = sum(f$residuals^2) / (length(t_est) - ncol(X)),
       residuos = stats::setNames(f$residuals, iq[t_est]), x = x)
}

#' Proyección h pasos de un AR(p)-BIC de seleccionar_ar_bic_x() desde el último trimestre observado.
.proyectar_ar_x <- function(s, h) {
  x <- unname(s$x); i_ult <- as.integer(utils::tail(names(s$x), 1)); p <- s$p
  out <- numeric(h)
  D <- if (s$dummies) dummies_trimestrales(i_ult + seq_len(h)) else NULL
  for (j in seq_len(h)) {
    v <- s$c0 + (if (!is.null(D)) sum(D[j, ] * s$gamma) else 0) + (if (p > 0L) sum(s$phi * rev(utils::tail(x, p))) else 0)
    x <- c(x, v); out[j] <- v
  }
  stats::setNames(out, i_ult + seq_len(h))
}

# ---------------------------------------------------------------------------------------------
# UNI.ARIMA (fable)
# ---------------------------------------------------------------------------------------------

modelo_arima_fase5 <- function() list(
  modelo_id = "UNI.ARIMA", requiere = "objetivo", piso_gl = TRUE,
  ajustar = function(datos, spec) {
    y <- .y_de(datos); o <- datos$objetivo$periodo
    d <- diferencias_kpss(y)
    ts_ <- tsibble::tsibble(t = tsibble::yearquarter(sub("-Q", " Q", o, fixed = TRUE)), y = y, index = t)
    # Constante solo con d <= 1 (regla de forecast::auto.arima): con d = 2 sería una tendencia cuadrática en el
    # log-nivel, que fable admite con una advertencia.
    fm <- stats::as.formula(sprintf("y ~ %spdq(p = 0:%d, d = %d, q = 0:%d) + PDQ(0, 0, 0)", if (d >= 2L) "0 + " else "",
                                    ORDENES_UNI_ARIMA$p_max, d, ORDENES_UNI_ARIMA$q_max))
    m <- fabletools::model(ts_, a = fable::ARIMA(!!fm, ic = "bic", stepwise = FALSE, approximation = FALSE,
                                                 order_constraint = p + q <= 8))
    f <- m$a[[1]]$fit
    if (!inherits(f, "ARIMA")) stop("UNI.ARIMA: fable no ajustó ningún candidato en ", utils::tail(o, 1))
    sp <- f$spec; par <- fabletools::tidy(m); est <- stats::setNames(par$estimate, par$term)
    ar <- .coefs(est, "ar", sp$p); ma <- .coefs(est, "ma", sp$q)
    if (anyNA(ar) || anyNA(ma)) stop("UNI.ARIMA: coeficientes ARMA ausentes en ", utils::tail(o, 1))
    list(m = m, p = as.integer(sp$p), d = as.integer(sp$d), q = as.integer(sp$q), constante = isTRUE(sp$constant), ar = ar, ma = ma,
         s2 = fabletools::glance(m)$sigma2,
         gl = c(n_obs = length(y) - d, n_par = ORDENES_UNI_ARIMA$p_max + ORDENES_UNI_ARIMA$q_max + 1L))   # el mayor candidato
  },
  predecir = function(aj, h) as.numeric(fabletools::forecast(aj$m, h = h)$.mean),
  predecir_densidad = function(aj, h) list(media = as.numeric(fabletools::forecast(aj$m, h = h)$.mean),
                                           cov = cov_desde_pesos(pesos_arima(aj$ar, aj$ma, aj$d, h), aj$s2)),
  diagnosticar = function(aj) c(p = aj$p, d = aj$d, q = aj$q, constante = as.numeric(aj$constante))
)

# ---------------------------------------------------------------------------------------------
# UNI.UC_LLT (StructTS)
# ---------------------------------------------------------------------------------------------

#' Covarianza h x h del sendero de un modelo de espacio de estados de StructTS desde su estado final.
cov_estado_uc <- function(mod, h) {
  Tm <- mod$T; Z <- matrix(mod$Z, nrow = 1L); P <- mod$P; V <- mod$V
  Ps <- vector("list", h)
  for (j in seq_len(h)) { P <- Tm %*% P %*% t(Tm) + V; Ps[[j]] <- P }
  S <- matrix(0, h, h)
  for (j in seq_len(h)) {
    Tk <- diag(nrow(Tm))
    for (k in j:h) {
      S[k, j] <- S[j, k] <- as.numeric(Z %*% Tk %*% Ps[[j]] %*% t(Z)) + if (k == j) mod$h else 0
      Tk <- Tm %*% Tk
    }
  }
  S
}

modelo_uc_llt <- function() list(
  modelo_id = "UNI.UC_LLT", requiere = "objetivo", piso_gl = TRUE,
  ajustar = function(datos, spec) {
    y <- .y_de(datos)
    a <- stats::StructTS(stats::ts(y, frequency = 4L), type = "trend")
    if (!identical(as.integer(a$code), 0L)) stop("UNI.UC_LLT: StructTS no convergió (optim code ", a$code, ") en ", utils::tail(datos$objetivo$periodo, 1))
    list(mod = a$model, coef = a$coef, gl = c(n_obs = length(y), n_par = 3L))
  },
  predecir = function(aj, h) as.numeric(stats::KalmanForecast(h, aj$mod)$pred),
  predecir_densidad = function(aj, h) list(media = as.numeric(stats::KalmanForecast(h, aj$mod)$pred), cov = cov_estado_uc(aj$mod, h)),
  diagnosticar = function(aj) c(var_nivel = unname(aj$coef["level"]), var_pendiente = unname(aj$coef["slope"]),
                                var_irregular = unname(aj$coef["epsilon"]))
)

# ---------------------------------------------------------------------------------------------
# ARIMAX (B1-1, B1-2, B1-5, B1b-1)
# ---------------------------------------------------------------------------------------------

#' Grilla (p, q) de un ARIMAX: p <= p_max, q <= q_max, p + q <= pq_max.
grilla_arma <- function(p_max, q_max, pq_max = p_max + q_max) {
  g <- expand.grid(p = 0:p_max, q = 0:q_max)
  g <- g[g$p + g$q <= pq_max, , drop = FALSE]
  g[order(g$p + g$q, g$p), , drop = FALSE]
}

#' Ajuste de un ARIMAX en un origen. `datos` trae objetivo (periodo, y) y las predictoras (periodo, valor) .Q.
ajustar_arimax <- function(datos, predictoras, rezagos_x, grilla, modelo_id, p_max_x = P_MAX_PREDICTORAS,
                           kappa_max = KAPPA_MAX_ARIMAX) {
  y <- .y_de(datos); iy <- q_a_ind(datos$objetivo$periodo); o <- utils::tail(iy, 1)
  dy <- stats::setNames(diff(y), iy[-1])
  dx <- stats::setNames(lapply(predictoras, function(id) .dlog_q(datos[[id]], id)), predictoras)
  nsa <- grepl(".NSA.", predictoras, fixed = TRUE); con_d <- any(nsa)
  for (id in predictoras) if (as.integer(utils::tail(names(dx[[id]]), 1)) != o) stop(modelo_id, ": ", id, " no llega al origen ", ind_a_q(o), " (F5-04)")
  # Muestra común: Δy y todos los Δlog x con sus rezagos.
  ini <- max(as.integer(names(dy))[1], vapply(dx, function(v) as.integer(names(v))[1], integer(1)) + max(rezagos_x))
  t_ <- ini:o; n <- length(t_)
  cols <- list(); nm <- character(0)
  for (id in predictoras) for (L in rezagos_x) {
    cols[[length(cols) + 1L]] <- unname(dx[[id]][as.character(t_ - L)]); nm <- c(nm, paste0(id, "__L", L))
  }
  X <- matrix(unlist(cols), nrow = n); colnames(X) <- nm
  if (con_d) X <- cbind(X, dummies_trimestrales(t_))
  if (anyNA(X)) stop(modelo_id, ": regresores con NA en la muestra común")
  # B1b-1: guarda numérica (Regla 7). Rango completo con la constante y número de condición acotado.
  if (qr(cbind(1, X))$rank < ncol(X) + 1L) stop(modelo_id, " en ", ind_a_q(o), ": la matriz de regresores pierde rango")
  kappa <- kappa(scale(X), exact = TRUE)
  if (!is.finite(kappa) || kappa > kappa_max) stop(sprintf("%s en %s: número de condición de los regresores estandarizados %.3g > %.3g (B1b-1)", modelo_id, ind_a_q(o), kappa, kappa_max))
  yv <- unname(dy[as.character(t_)])
  ajustes <- lapply(seq_len(nrow(grilla)), function(i) {
    p <- grilla$p[i]; q <- grilla$q[i]
    f <- tryCatch(suppressWarnings(stats::arima(yv, order = c(p, 0L, q), xreg = X, include.mean = TRUE, method = "ML")),
                  error = function(e) NULL)
    if (is.null(f) || !identical(as.integer(f$code), 0L)) return(NULL)
    f$call$xreg <- X                                   # predict.Arima reevalúa call$xreg; sin I/O ni entornos externos
    list(p = p, q = q, fit = f, bic = -2 * f$loglik + (length(f$coef) + 1L) * log(n))
  })
  fallidos <- sum(vapply(ajustes, is.null, logical(1)))
  ajustes <- Filter(Negate(is.null), ajustes)
  if (!length(ajustes)) stop(modelo_id, " en ", ind_a_q(o), ": ningún candidato de la grilla convergió")
  mej <- ajustes[[which.min(vapply(ajustes, `[[`, numeric(1), "bic"))]]
  cf <- mej$fit$coef
  # AR(p)-BIC de cada predictora con su historia hasta el origen (F5-05).
  ars <- stats::setNames(lapply(seq_along(predictoras), function(i) seleccionar_ar_bic_x(dx[[i]], dummies = nsa[i], p_max = p_max_x)), predictoras)
  # Σ: covarianza muestral contemporánea completa (B1-5) en los períodos con todos los residuos.
  e <- stats::setNames(as.numeric(stats::residuals(mej$fit)), t_)
  comunes <- Reduce(intersect, c(list(names(e)), lapply(ars, function(s) names(s$residuos))))
  W <- cbind(e[comunes], vapply(ars, function(s) unname(s$residuos[comunes]), numeric(length(comunes))))
  if (length(comunes) < ncol(W) + 2L) stop(modelo_id, " en ", ind_a_q(o), ": pocos períodos comunes para la covarianza de las innovaciones")
  Sigma <- stats::cov(W)
  cx <- if (length(predictoras) > 1L) stats::cor(X[, paste0(predictoras, "__L", rezagos_x[1]), drop = FALSE]) else matrix(1)
  list(modelo_id = modelo_id, fit = mej$fit, p = mej$p, q = mej$q, predictoras = predictoras, rezagos_x = rezagos_x,
       con_dummies = con_d, ars = ars, dx = dx, o = o, y_o = utils::tail(y, 1), Sigma = Sigma, n_sigma = length(comunes),
       beta = lapply(stats::setNames(predictoras, predictoras), function(id) vapply(rezagos_x, function(L) unname(cf[paste0(id, "__L", L)]), numeric(1))),
       ar = .coefs(cf, "ar", mej$p), ma = .coefs(cf, "ma", mej$q),
       kappa = kappa, cor_max = if (length(predictoras) > 1L) max(abs(cx[upper.tri(cx)])) else NA_real_, fallidos = fallidos,
       gl = c(n_obs = n, n_par = 1L + ncol(X) + max(grilla$p + grilla$q)))                             # el mayor candidato
}

#' Regresores futuros (o+1..o+h) con las predictoras proyectadas por sus AR.
.xreg_futuro <- function(aj, h) {
  t_ <- aj$o + seq_len(h)
  cols <- list()
  for (id in aj$predictoras) {
    v <- c(aj$dx[[id]], .proyectar_ar_x(aj$ars[[id]], h))
    for (L in aj$rezagos_x) cols[[length(cols) + 1L]] <- unname(v[as.character(t_ - L)])
  }
  X <- matrix(unlist(cols), nrow = h)
  if (aj$con_dummies) X <- cbind(X, dummies_trimestrales(t_))
  X
}

sendero_arimax <- function(aj, h) aj$y_o + cumsum(as.numeric(stats::predict(aj$fit, n.ahead = h, newxreg = .xreg_futuro(aj, h))$pred))

#' Covarianza del sendero del sistema ARIMAX + AR de las predictoras (F5-12, B1-5).
cov_sistema_arimax <- function(aj, h) {
  k <- length(aj$predictoras); m <- k + 1L
  psi_e <- c(1, if (h > 1L) stats::ARMAtoMA(ar = aj$ar, ma = aj$ma, lag.max = h - 1L) else numeric(0))
  psi_x <- lapply(aj$ars, function(s) c(1, if (h > 1L) stats::ARMAtoMA(ar = s$phi, ma = numeric(0), lag.max = h - 1L) else numeric(0)))
  dY <- matrix(0, h, h * m)                       # fila s: error de Δy en o+s; columna (r-1)m + c: componente c de w_r
  for (s in seq_len(h)) {
    for (r in seq_len(s)) dY[s, (r - 1L) * m + 1L] <- psi_e[s - r + 1L]
    for (i in seq_len(k)) for (l in seq_along(aj$rezagos_x)) {
      L <- aj$rezagos_x[l]; b <- aj$beta[[i]][l]; t_err <- s - L
      if (t_err >= 1L) for (r in seq_len(t_err)) dY[s, (r - 1L) * m + 1L + i] <- dY[s, (r - 1L) * m + 1L + i] + b * psi_x[[i]][t_err - r + 1L]
    }
  }
  G <- apply(dY, 2, cumsum); if (h == 1L) G <- matrix(G, nrow = 1L)
  S <- G %*% kronecker(diag(h), aj$Sigma) %*% t(G)
  (S + t(S)) / 2
}

#' Fábrica de un ARIMAX bajo el contrato del motor.
modelo_arimax <- function(modelo_id, predictoras, rezagos_x, p_max, q_max, pq_max = p_max + q_max) {
  grilla <- grilla_arma(p_max, q_max, pq_max)
  list(
    modelo_id = modelo_id, requiere = c("objetivo", predictoras), piso_gl = TRUE,
    grilla = grilla, rezagos_x = rezagos_x,
    ajustar = function(datos, spec) ajustar_arimax(datos, predictoras, rezagos_x, grilla, modelo_id),
    predecir = function(aj, h) sendero_arimax(aj, h),
    predecir_densidad = function(aj, h) list(media = sendero_arimax(aj, h), cov = cov_sistema_arimax(aj, h)),
    diagnosticar = function(aj) c(p = aj$p, q = aj$q, n_obs = aj$gl[["n_obs"]], kappa = aj$kappa, cor_max = aj$cor_max,
                                  candidatos_fallidos = aj$fallidos, n_sigma = aj$n_sigma,
                                  stats::setNames(vapply(aj$ars, `[[`, numeric(1), "p"), paste0("p_ar.", aj$predictoras)))
  )
}

#' Las ARIMAX de B1-2: una por grupo con las predictoras para modelos sin penalización (B1b-2), y la de referencia
#' con el IVAE en G2.
modelo_arimax_grupo <- function(grupo) {
  switch(grupo,
    G1 = modelo_arimax("UNI.ARIMAX.G1", predictoras_no_penalizadas("G1"), rezagos_x = 0:1, p_max = 2L, q_max = 2L),
    G2 = modelo_arimax("UNI.ARIMAX.G2", predictoras_no_penalizadas("G2"), rezagos_x = 0:1, p_max = 2L, q_max = 2L, pq_max = 2L),
    G3 = modelo_arimax("UNI.ARIMAX.G3", predictoras_no_penalizadas("G3"), rezagos_x = 0L, p_max = 2L, q_max = 2L),
    stop("modelo_arimax_grupo: grupo no declarado: ", grupo))
}
modelo_arimax_ivae <- function() modelo_arimax("UNI.ARIMAX_IVAE.G2", "BCR.IVAE.VOL.SA.Q", rezagos_x = 0:1, p_max = 2L, q_max = 2L)
