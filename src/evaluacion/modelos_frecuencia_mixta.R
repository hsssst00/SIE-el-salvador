# src/evaluacion/modelos_frecuencia_mixta.R
#
# Frecuencia mixta de Fase 5, bloque B3b (F5-08, F5-04 parte 1, F5-05, F5-12 y B3b-1 a B3b-n de
# doc/metodologia/decisiones_fase5.md), bajo el contrato del motor (eval_lib.R §4). Son los únicos modelos que usan el
# borde irregular: las predictoras entran mensuales (.M) hasta el último mes que el calendario admite en el origen
# (F5-04; G-7 lo comprueba), con meses de o+1. Sin penalización: predictoras_no_penalizadas() (B1b-2) y piso de grados de
# libertad (F5-03, G-8). Sin I/O y sin estado global.
#
#   MIX.UMIDAS.Gk  U-MIDAS sin restricciones (Foroni, Marcellino y Schumacher, 2015), directo por h sobre el crecimiento
#                  acumulado g_h(t) = y_{t+h} − y_t (F5-05), con la infraestructura de forma_directa.R: MCO de g_h sobre
#                  el Δlog mensual de cada predictora en meses fijos respecto del último mes del trimestre t, m(t). La
#                  predictora i entra en los meses m(t) + d_i, ..., m(t) + 1 (los d_i meses de t+1 que el calendario
#                  admite en el origen) y m(t), ..., m(t) − 5 en G1; en G2 y G3, por el piso, solo en m(t) + d_i, su
#                  último mes admitido (B3b-1). Constante y dummies trimestrales sin penalizar por la ventana de B3-2. Una
#                  sola especificación, sin hiperparámetros: la validación anidada de F5-11 solo da los errores internos de
#                  la densidad (Σ = D R D, B3b-3). Piso: G-8 con la estimación final más chica (h = 8).
#   MIX.PUENTE.Gk  ecuación puente, iterada (F5-05, F5-08): cada mensual se completa hasta el último mes de o+8 con un
#                  AR(p)-BIC mensual en Δlog (p en 0..12, con dummies mensuales si es NSA) y se agrega al trimestre con
#                  la regla de T00x (suma o promedio de los 3 meses: el Δlog trimestral no depende de cuál, B3b-4); MCO de
#                  Δy_t sobre constante, los Δlog trimestrales contemporáneos de las predictoras, Δy_{t-1} (el AR(1) del
#                  PIB) y dummies trimestrales si alguna predictora es NSA. El sendero itera la ecuación con los agregados
#                  proyectados. Densidad (F5-12): el sistema lineal conjunto del puente y de los AR mensuales, con el
#                  Δlog trimestral de un agregado linealizado en los Δlog mensuales (pesos 1, 2, 3, 2, 1 sobre 3; B3b-5):
#                  cov = σ²_e A_e A_e' + Σ_{i,k} Σ_u[i, k] A_i A_k' en los meses comunes + los términos cruzados de la
#                  innovación del puente con las innovaciones mensuales de los meses del mismo trimestre, con Σ_u la
#                  covarianza contemporánea completa de los residuos de los AR mensuales (B3b-6, la analogía de B1-5).
#                  Plug-in en los parámetros.

P_MAX_AR_MENSUAL   <- 12L                                      # B3b-4: AR(p)-BIC mensual, p en 0..12
LAGS_UMIDAS        <- list(G1 = 0:5, G2 = integer(0), G3 = integer(0))   # B3b-1: meses m(t) − k además del último admitido
KAPPA_MAX_MIXTA    <- 1e4                                      # B3b-2: el número de condición de las ARIMAX (B1b-1)

# ---------------------------------------------------------------------------------------------
# Utilidades mensuales
# ---------------------------------------------------------------------------------------------

#' Último mes (índice mensual año*12 + mes − 1) de un trimestre (índice trimestral).
ultimo_mes_trimestre <- function(q) as.integer(q) %/% 4L * 12L + (as.integer(q) %% 4L) * 3L + 2L

#' Dummies mensuales (M2..M12; la constante absorbe enero) para índices mensuales.
dummies_mensuales <- function(im) {
  mes <- as.integer(im) %% 12L + 1L
  D <- matrix(vapply(2:12, function(k) as.numeric(mes == k), numeric(length(mes))), ncol = 11L)
  colnames(D) <- paste0("M", 2:12)
  D
}

#' log de una predictora mensual (data.frame periodo "YYYY-Mmm", valor) nombrado por índice mensual; falla si no es
#' positiva, si tiene huecos o si trae NA.
.log_m <- function(d, id, modelo_id) {
  if (is.null(d) || !all(c("periodo", "valor") %in% names(d))) stop(modelo_id, ": la predictora ", id, " necesita periodo y valor")
  im <- m_a_ind(d$periodo)
  if (length(im) < 3L || any(diff(im) != 1L)) stop(modelo_id, ": la predictora mensual ", id, " tiene meses faltantes o desordenados")
  if (anyNA(d$valor) || any(!is.finite(d$valor)) || any(d$valor <= 0)) stop(modelo_id, ": la predictora ", id, " trae valores no positivos o ausentes (se usa el Δlog)")
  stats::setNames(log(d$valor), im)
}

#' AR(p)-BIC mensual con constante y, si `dummies`, dummies mensuales: los candidatos p = 0..p_max se comparan en la
#' muestra común de p_max y el p elegido se reestima con la muestra máxima (la regla de seleccionar_ar_bic_x(), F5-05).
#' `x` es el Δlog mensual nombrado por índice mensual.
seleccionar_ar_bic_m <- function(x, dummies = FALSE, p_max = P_MAX_AR_MENSUAL) {
  n <- length(x); im <- as.integer(names(x))
  if (is.null(names(x)) || any(diff(im) != 1L)) stop("seleccionar_ar_bic_m: x debe venir nombrada por meses consecutivos")
  D <- if (dummies) dummies_mensuales(im) else matrix(numeric(0), n, 0L)
  if (n <= p_max + ncol(D) + 2L) stop("seleccionar_ar_bic_m: muestra insuficiente para p_max = ", p_max)
  t_idx <- (p_max + 1L):n; n_eff <- length(t_idx)
  X_lags <- matrix(vapply(seq_len(p_max), function(j) x[t_idx - j], numeric(n_eff)), nrow = n_eff)
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
  if (any(!is.finite(f$coefficients))) stop("seleccionar_ar_bic_m: el AR mensual pierde rango")
  b <- unname(f$coefficients)
  list(p = p, c0 = b[1], gamma = b[1L + seq_len(ncol(D))], phi = b[1L + ncol(D) + seq_len(p)], dummies = dummies,
       residuos = stats::setNames(f$residuals, im[t_est]), x = x)
}

#' Proyección del Δlog mensual de un AR de seleccionar_ar_bic_m() hasta el mes `hasta`, desde el último observado.
.proyectar_ar_m <- function(s, hasta) {
  x <- unname(s$x); i_ult <- as.integer(utils::tail(names(s$x), 1)); n <- hasta - i_ult
  if (n <= 0L) return(stats::setNames(numeric(0), character(0)))
  D <- if (s$dummies) dummies_mensuales(i_ult + seq_len(n)) else NULL
  out <- numeric(n)
  for (j in seq_len(n)) {
    v <- s$c0 + (if (!is.null(D)) sum(D[j, ] * s$gamma) else 0) + (if (s$p > 0L) sum(s$phi * rev(utils::tail(x, s$p))) else 0)
    x <- c(x, v); out[j] <- v
  }
  stats::setNames(out, i_ult + seq_len(n))
}

# ---------------------------------------------------------------------------------------------
# MIX.UMIDAS (forma directa con meses)
# ---------------------------------------------------------------------------------------------

#' Matriz del U-MIDAS en un origen (B3b-1): filas trimestrales t, columnas = Δlog mensual de cada predictora en los meses
#' m(t) + d_i, ..., m(t) + 1 y m(t), ..., m(t) − L (L de LAGS_UMIDAS; en G2 y G3 solo m(t) + d_i). d_i = meses de o+1 que
#' la predictora trae en el origen (el borde que admite el calendario, F5-04). Devuelve la lista de matriz_directa().
matriz_umidas <- function(datos, predictoras, modelo_id, lags) {
  ob <- datos$objetivo
  if (is.null(ob) || !all(c("periodo", "y") %in% names(ob))) stop(modelo_id, ": falta datos$objetivo con periodo e y")
  iy <- q_a_ind(ob$periodo)
  if (length(iy) < 2L || any(diff(iy) != 1L) || anyNA(ob$y)) stop(modelo_id, ": el objetivo tiene huecos o NA")
  o <- iy[length(iy)]; mo <- ultimo_mes_trimestre(o)
  faltan <- setdiff(predictoras, names(datos))
  if (length(faltan)) stop(modelo_id, ": faltan predictoras en los datos: ", paste(faltan, collapse = ", "))
  dl <- stats::setNames(lapply(predictoras, function(id) { l <- .log_m(datos[[id]], id, modelo_id); stats::setNames(diff(l), names(l)[-1]) }), predictoras)
  d <- vapply(dl, function(v) as.integer(utils::tail(names(v), 1)) - mo, integer(1))
  if (any(d < 0L)) stop(modelo_id, " en ", ind_a_q(o), ": predictoras mensuales que no llegan al último mes del origen: ", paste(predictoras[d < 0L], collapse = ", "))
  pos <- lapply(seq_along(d), function(i) if (length(lags)) c(rev(seq_len(d[i])), -lags) else d[i])
  cand <- (iy[1] + 1L):o
  cols <- list(); nm <- character(0)
  for (i in seq_along(predictoras)) for (k in pos[[i]]) {
    cols[[length(cols) + 1L]] <- unname(dl[[i]][as.character(ultimo_mes_trimestre(cand) + k)])
    nm <- c(nm, sprintf("%s__m%+d", predictoras[i], k))
  }
  X <- matrix(unlist(cols), nrow = length(cand)); colnames(X) <- nm
  completas <- stats::complete.cases(X)
  if (!completas[length(completas)]) stop(modelo_id, " en ", ind_a_q(o), ": la fila del origen no tiene todos los meses")
  ini <- max(which(!completas), 0L) + 1L
  t_ <- cand[ini:length(cand)]; X <- X[ini:length(cand), , drop = FALSE]
  list(modelo_id = modelo_id, o = o, t = t_, X = X, y = stats::setNames(ob$y, iy), y_o = ob$y[length(ob$y)],
       con_dummies = any(grepl(".NSA.", predictoras, fixed = TRUE)), predictoras = predictoras, desfases = d)
}

#' MCO del U-MIDAS sobre la ventana transformada (B3-2: Frisch-Waugh-Lovell con constante y dummies). Una sola
#' especificación; el número de condición de las columnas de la ventana final queda en la rejilla para la guarda de
#' B3b-2 y los diagnósticos.
especificacion_umidas <- function(kappa_max = KAPPA_MAX_MIXTA) list(
  transformar = TRUE, piso_gl = TRUE,
  candidatos = function(Z, g, h) {
    kap <- kappa(Z, exact = TRUE)
    if (!is.finite(kap) || kap > kappa_max) stop(sprintf("MIX.UMIDAS: número de condición de las columnas de la ventana final %.3g > %.3g en h = %d (B3b-2)", kap, kappa_max, h))
    data.frame(mco = 1L, kappa = kap)
  },
  estimar_predecir = function(Z, g, z, rejilla, cand) {
    q <- qr(Z)
    if (q$rank < ncol(Z)) stop(sprintf("MIX.UMIDAS: el MCO pierde rango en una ventana de %d filas y %d columnas (B3b-2)", nrow(Z), ncol(Z)))
    rep(sum(matrix(z, nrow = 1L) * qr.coef(q, g)), length(cand))
  },
  diagnosticar = function(rejilla, j) c(kappa = rejilla$kappa[j])
)

modelo_umidas_grupo <- function(grupo) {
  pred <- predictoras_no_penalizadas(grupo, "M")
  id <- paste0("MIX.UMIDAS.", grupo); lags <- LAGS_UMIDAS[[grupo]]
  m <- modelo_directo(id, pred, especificacion_umidas(), construir = function(datos) matriz_umidas(datos, pred, id, lags))
  m$lags_mensuales <- lags
  m
}

# ---------------------------------------------------------------------------------------------
# MIX.PUENTE (ecuación puente iterada)
# ---------------------------------------------------------------------------------------------

#' Δlog trimestral de un agregado de meses (suma de niveles; el promedio da el mismo Δlog) para los trimestres `qs`.
.dlog_trimestral_de_meses <- function(l, qs) {
  agr <- vapply(qs, function(q) { m <- ultimo_mes_trimestre(q) - 2:0; v <- l[as.character(m)]; if (anyNA(v)) NA_real_ else log(sum(exp(v))) }, numeric(1))
  stats::setNames(agr - c(NA_real_, agr[-length(agr)]), qs)
}

#' Ajuste de la ecuación puente en un origen (F5-08, B3b-4 a B3b-6).
ajustar_puente <- function(datos, predictoras, modelo_id, H = DISENO_FASE4$h_max, p_max = P_MAX_AR_MENSUAL, kappa_max = KAPPA_MAX_MIXTA) {
  y <- .y_de(datos); iy <- q_a_ind(datos$objetivo$periodo); o <- iy[length(iy)]
  if (any(diff(iy) != 1L)) stop(modelo_id, ": el objetivo tiene trimestres faltantes")
  dy <- stats::setNames(diff(y), iy[-1])
  nsa <- grepl(".NSA.", predictoras, fixed = TRUE); con_d <- any(nsa)
  m_fin <- ultimo_mes_trimestre(o + H)
  ls <- stats::setNames(lapply(predictoras, function(id) .log_m(datos[[id]], id, modelo_id)), predictoras)
  ult <- vapply(ls, function(l) as.integer(utils::tail(names(l), 1)), integer(1))
  if (any(ult < ultimo_mes_trimestre(o))) stop(modelo_id, " en ", ind_a_q(o), ": predictoras mensuales que no llegan al último mes del origen: ", paste(predictoras[ult < ultimo_mes_trimestre(o)], collapse = ", "))
  ars <- stats::setNames(lapply(seq_along(predictoras), function(i) {
    l <- ls[[i]]; seleccionar_ar_bic_m(stats::setNames(diff(l), names(l)[-1]), dummies = nsa[i], p_max = p_max)
  }), predictoras)
  # niveles mensuales observados + proyectados hasta el último mes de o+H
  lc <- stats::setNames(lapply(seq_along(predictoras), function(i) {
    l <- ls[[i]]; pr <- .proyectar_ar_m(ars[[i]], m_fin)
    c(l, stats::setNames(l[length(l)] + cumsum(pr), names(pr)))
  }), predictoras)
  q_ini <- max(vapply(ls, function(l) (as.integer(names(l))[1] + 2L) %/% 3L + 1L, integer(1)), iy[1] + 2L)  # primer trimestre con Δlog completo
  qs <- (q_ini - 1L):(o + H)
  dX <- vapply(lc, function(l) .dlog_trimestral_de_meses(l, qs), numeric(length(qs)))
  dX <- matrix(dX, nrow = length(qs), dimnames = list(qs, predictoras))
  t_ <- q_ini:o
  t_ <- t_[stats::complete.cases(dX[as.character(t_), , drop = FALSE]) & !is.na(dy[as.character(t_ - 1L)])]
  if (any(diff(t_) != 1L) || utils::tail(t_, 1) != o) stop(modelo_id, " en ", ind_a_q(o), ": la muestra del puente tiene huecos")
  W <- cbind(constante = 1, dX[as.character(t_), , drop = FALSE], dy_l1 = unname(dy[as.character(t_ - 1L)]), if (con_d) dummies_trimestrales(t_))
  qw <- qr(W)
  if (qw$rank < ncol(W)) stop(modelo_id, " en ", ind_a_q(o), ": la matriz de regresores del puente pierde rango")
  kap <- kappa(scale(W[, -1, drop = FALSE]), exact = TRUE)
  if (!is.finite(kap) || kap > kappa_max) stop(sprintf("%s en %s: número de condición de los regresores estandarizados %.3g > %.3g (B3b-2)", modelo_id, ind_a_q(o), kap, kappa_max))
  yv <- unname(dy[as.character(t_)])
  b <- qr.coef(qw, yv); e <- qr.resid(qw, yv)
  n <- length(t_); s2 <- sum(e^2) / (n - ncol(W))
  k <- length(predictoras)
  beta <- b[1L + seq_len(k)]; phi <- b[[1L + k + 1L]]; delta <- if (con_d) b[1L + k + 1L + 1:3] else numeric(0)
  # Σ_u: covarianza contemporánea completa de los residuos de los AR mensuales en los meses comunes (B3b-6)
  comunes <- Reduce(intersect, lapply(ars, function(s) names(s$residuos)))
  U <- vapply(ars, function(s) unname(s$residuos[comunes]), numeric(length(comunes)))
  U <- matrix(U, ncol = k)
  if (length(comunes) < k + 2L) stop(modelo_id, " en ", ind_a_q(o), ": pocos meses comunes para la covarianza de las innovaciones mensuales")
  Su <- stats::cov(U)
  # B3b-6: covarianza de la innovación del puente con las innovaciones mensuales de los meses del mismo trimestre (la
  # analogía de B1-5), c[p, i] = promedio de e_t · u_{i, mes p de t} en los trimestres de la regresión; u–u por meses
  # (Σ_u, independientes entre meses). Si con c la matriz conjunta del trimestre no es definida positiva, c se reduce
  # (λ c, con complemento de Schur ≥ 0,05 σ²_e) y λ va a diagnosticos.csv.
  Cm <- matrix(0, 3L, k)
  for (pp in 1:3) for (i in seq_len(k)) {
    mm <- as.character(ultimo_mes_trimestre(t_) - (3L - pp))
    r <- ars[[i]]$residuos[mm]; ok_ <- !is.na(r)
    Cm[pp, i] <- if (sum(ok_) >= 10L) sum(e[ok_] * r[ok_]) / sum(ok_) else 0
  }
  cv <- as.vector(t(Cm))                                         # orden (mes 1: predictoras 1..k), (mes 2: ...), (mes 3: ...)
  Sblk <- kronecker(diag(3), Su)
  q_c <- as.numeric(crossprod(cv, solve(Sblk, cv)))
  lambda_c <- if (q_c > 0.95 * s2) sqrt(0.95 * s2 / q_c) else 1
  list(modelo_id = modelo_id, o = o, y_o = y[length(y)], dy_o = unname(dy[as.character(o)]), H = H, predictoras = predictoras,
       c0 = b[[1]], beta = beta, phi = phi, delta = delta, con_dummies = con_d, s2 = s2, Su = Su, ars = ars, ult = ult,
       Ceu = lambda_c * Cm, lambda_c = lambda_c,
       dX_fut = dX[as.character(o + seq_len(H)), , drop = FALSE], kappa = kap, n_sigma = length(comunes),
       gl = c(n_obs = n, n_par = ncol(W)))
}

sendero_puente <- function(aj, h) {
  if (h > aj$H) stop(sprintf("%s: el puente se proyectó hasta h = %d y se pidió h = %d", aj$modelo_id, aj$H, h))
  D <- if (aj$con_dummies) dummies_trimestrales(aj$o + seq_len(h)) else NULL
  d_prev <- aj$dy_o; out <- numeric(h)
  for (j in seq_len(h)) {
    d_prev <- aj$c0 + sum(aj$beta * aj$dX_fut[j, ]) + aj$phi * d_prev + (if (!is.null(D)) sum(D[j, ] * aj$delta) else 0)
    out[j] <- d_prev
  }
  aj$y_o + cumsum(out)
}

#' Respuesta del sendero (h filas) a una unidad en el Δlog trimestral de la predictora i en cada trimestre j (h x h):
#' ε_j = β_i x_j + φ ε_{j−1}, acumulado al log-nivel.
.respuesta_sendero <- function(beta_i, phi, h) {
  R <- matrix(0, h, h)
  for (j in seq_len(h)) { e <- numeric(h); e[j] <- beta_i; for (s in seq_len(h)) if (s > j) e[s] <- phi * e[s - 1L]; R[, j] <- cumsum(e) }
  R
}

#' Covarianza del sendero del sistema puente + AR mensuales (F5-12, B3b-5, B3b-6), con el Δlog trimestral de cada
#' agregado linealizado en los Δlog mensuales: Δlog X_Q(q) ≈ (Δl_m + 2 Δl_{m−1} + 3 Δl_{m−2} + 2 Δl_{m−3} + Δl_{m−4}) / 3,
#' con m = último mes de q.
cov_sistema_puente <- function(aj, h) {
  k <- length(aj$predictoras)
  Re <- .respuesta_sendero(1, aj$phi, h)                                # innovación del puente
  S <- aj$s2 * Re %*% t(Re)
  w <- c(1, 2, 3, 2, 1) / 3
  m_fin <- ultimo_mes_trimestre(aj$o + h)
  A <- lapply(seq_len(k), function(i) {
    meses <- (aj$ult[[i]] + 1L):m_fin
    if (!length(meses) || aj$ult[[i]] >= m_fin) return(matrix(0, h, 0))
    psi <- c(1, if (length(meses) > 1L) stats::ARMAtoMA(ar = aj$ars[[i]]$phi, ma = numeric(0), lag.max = length(meses) - 1L) else numeric(0))
    Rx <- .respuesta_sendero(aj$beta[[i]], aj$phi, h)
    Ai <- matrix(0, h, length(meses), dimnames = list(NULL, meses))
    for (c_ in seq_along(meses)) {
      r <- meses[c_]
      xq <- vapply(seq_len(h), function(j) {
        m <- ultimo_mes_trimestre(aj$o + j) - 0:4
        sum(w * ifelse(m >= r, psi[pmax(m - r, 0L) + 1L], 0))
      }, numeric(1))
      Ai[, c_] <- Rx %*% xq
    }
    Ai
  })
  for (i in seq_len(k)) for (j in seq_len(k)) {
    cm <- intersect(colnames(A[[i]]), colnames(A[[j]]))
    if (length(cm)) S <- S + aj$Su[i, j] * A[[i]][, cm, drop = FALSE] %*% t(A[[j]][, cm, drop = FALSE])
  }
  # B3b-6: términos cruzados de e_{o+j} con las innovaciones mensuales proyectadas de los meses de o+j
  for (i in seq_len(k)) for (r in as.integer(colnames(A[[i]]))) {
    q <- r %/% 3L; j <- q - aj$o; pp <- r %% 3L + 1L
    if (j >= 1L && j <= h && aj$Ceu[pp, i] != 0) {
      X <- aj$Ceu[pp, i] * Re[, j] %*% t(A[[i]][, as.character(r)])
      S <- S + X + t(X)
    }
  }
  (S + t(S)) / 2
}

modelo_puente <- function(modelo_id, predictoras) list(
  modelo_id = modelo_id, requiere = c("objetivo", predictoras), piso_gl = TRUE,
  ajustar = function(datos, spec) ajustar_puente(datos, predictoras, modelo_id),
  predecir = function(aj, h) sendero_puente(aj, h),
  predecir_densidad = function(aj, h) list(media = sendero_puente(aj, h), cov = cov_sistema_puente(aj, h)),
  diagnosticar = function(aj) c(n_obs = aj$gl[["n_obs"]], kappa = aj$kappa, phi = aj$phi, sigma_e = sqrt(aj$s2), n_sigma = aj$n_sigma,
                                lambda_c = aj$lambda_c,
                                stats::setNames(vapply(aj$ars, `[[`, numeric(1), "p"), paste0("p_ar.", aj$predictoras)))
)

modelo_puente_grupo <- function(grupo) modelo_puente(paste0("MIX.PUENTE.", grupo), predictoras_no_penalizadas(grupo, "M"))

#' Los modelos de frecuencia mixta de un grupo (F5-08), en el orden en que se reportan.
modelos_frecuencia_mixta_grupo <- function(grupo) {
  if (length(grupo) != 1L || !grupo %in% names(GRUPOS_PREDICTORAS)) stop("modelos_frecuencia_mixta_grupo: grupo no declarado: ", paste(grupo, collapse = ", "))
  list(modelo_umidas_grupo(grupo), modelo_puente_grupo(grupo))
}
