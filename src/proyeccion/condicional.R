# condicional.R
#
# Proyección condicional del Ejercicio B (checklist de Fase 6, D2; F6-01, F6-06, F6-06-a, F6-13, F6-15-a, F6-17 de
# doc/metodologia/decisiones_fase6.md; protocolo_proyeccion.md §3 y §6). Agrega el campo opcional
# `predecir_condicional(ajuste, h, senderos_x)` a los 14 modelos elegibles y deja la trayectoria sin escenario de los
# demás con h = 20. Los modelos y sus ajustes son los de Fase 5, sin cambios en sus YAML (F6-04); lo único que Fase 6
# pide distinto al ajustar es h = 20 en el puente (AR mensuales de IVAE y UT) y en el BVAR (momentos y extracciones).
# Sin I/O y sin estado global, como el resto del contrato.
#
# Senderos de las predictoras externas (`senderos_x`, el insumo que arman las satélites de D3):
#   list(dlog = matriz H_s x k de Δlog trimestral, filas o+1..o+H_s, colnames = series_master_id .Q de
#             SATELITES_FASE6 (un trimestre completo observado después de o va como dato, F6-17-a);
#        cov  = Σ_X, matriz (H_s k) x (H_s k) del error de las satélites en el orden de as.vector(dlog), es decir,
#               predictora por predictora; NULL = sin error de satélite)
# Cada modelo toma las columnas de sus predictoras externas y las filas 1..h; las columnas que no usa se ignoran.
#
# Resultado de predecir_condicional(): list(sendero, media, cov, J), todo en log-nivel del PIB y con h filas.
#   sendero  el sendero puntual: la media, salvo en el BVAR, donde es la mediana de la predictiva (F6-13 a)
#   media    media de la densidad condicional
#   cov      Σ_y + J Σ_X J' (F6-15-a): la covarianza condicional al sendero más la que aporta la satélite
#   J        h x (h k) derivada de la media respecto de los Δlog de las predictoras externas, en el orden de Σ_X
#
# Condicionamiento duro (F6-06):
#   ARIMAX  el sendero reemplaza al AR(p) de la predictora en los regresores futuros; la densidad es la del sistema de
#           Fase 5 (F5-12, B1-5) sin las innovaciones de las predictoras externas, que ya no se proyectan: queda el
#           error ARMA y, en G2 y G3, el AR de IVAE y UT con su covarianza contemporánea con el error (la submatriz
#           de Σ de B1-5).
#   puente  los Δlog trimestrales de las externas salen del sendero desde el primer trimestre sin meses observados;
#           antes, del dato y del AR mensual de B3b-4 (F6-17, F6-17-b). IVAE y UT siguen con su AR mensual. La
#           densidad es la de B3b-5 y B3b-6 sin las innovaciones mensuales que ya no se usan.
#   VAR, VECM y BVAR  distribución normal del vector apilado de pronósticos (variables x h, en las unidades del
#           modelo: Δ en el VAR en diferencias, log-nivel en los demás) condicionada a que las componentes de las
#           predictoras externas igualen su sendero (F6-06-a). En el BVAR, por extracción, con la media y los pesos MA
#           de cada (β_j, Σ_j); la predictiva es la mezcla de esas normales.

source(here::here("src", "proyeccion", "diseno_fase6.R"))
source(here::here("src", "evaluacion", "motor_backtesting.R"))   # eval_lib, modelos_referencia, modelos_fase5

# ---------------------------------------------------------------------------------------------
# Piezas comunes
# ---------------------------------------------------------------------------------------------

#' Matriz h x h que acumula: L %*% Δ = niveles relativos al origen.
.acumulador <- function(h) lower.tri(diag(h), diag = TRUE) * 1

#' series_master_id trimestral de una predictora (el puente la pide mensual).
.id_q <- function(ids) sub("\\.M$", ".Q", ids)

#' TRUE si alguna predictora del modelo tiene satélite (F6-01-b).
es_condicionable <- function(m) any(.id_q(setdiff(m$requiere, "objetivo")) %in% names(SATELITES_FASE6))

#' Senderos de las predictoras `ids` (.Q) para h pasos: list(dx = matriz h x k de Δlog, Sx = Σ_X de esas columnas y
#' filas). Falla visible si falta una predictora, si el sendero es corto o no finito, o si Σ_X está mal formada.
senderos_modelo <- function(senderos_x, ids, h, modelo_id) {
  donde <- paste0(modelo_id, ": senderos_x ")
  if (!is.list(senderos_x) || is.null(senderos_x$dlog)) stop(donde, "debe ser list(dlog, cov)")
  D <- senderos_x$dlog
  if (!is.matrix(D) || !is.numeric(D) || is.null(colnames(D)) || anyDuplicated(colnames(D))) stop(donde, "$dlog debe ser una matriz numérica con colnames únicos")
  faltan <- setdiff(ids, colnames(D))
  if (length(faltan)) stop(donde, "no trae el sendero de ", paste(faltan, collapse = ", "))
  if (nrow(D) < h) stop(donde, "llega a h = ", nrow(D), " y se pidió h = ", h)
  dx <- D[seq_len(h), ids, drop = FALSE]
  if (any(!is.finite(dx))) stop(donde, "trae valores no finitos en h = 1..", h)
  n <- nrow(D)
  idx <- unlist(lapply(match(ids, colnames(D)), function(c_) (c_ - 1L) * n + seq_len(h)))
  C <- senderos_x$cov
  Sx <- if (is.null(C)) matrix(0, length(idx), length(idx)) else {
    if (!is.matrix(C) || !identical(dim(C), rep(length(D), 2L)) || any(!is.finite(C))) stop(donde, "$cov debe ser una matriz finita de ", length(D), "x", length(D))
    if (max(abs(C - t(C))) > 1e-10 * max(1, abs(C))) stop(donde, "$cov no es simétrica")
    C[idx, idx, drop = FALSE]
  }
  list(dx = dx, Sx = Sx)
}

#' Valida el resultado de predecir_condicional() con h pasos (falla visible, regla 7).
validar_condicional <- function(res, h, modelo_id = "?") {
  donde <- paste0("predecir_condicional mal formado: modelo ", modelo_id, ": ")
  if (!is.list(res) || !all(c("sendero", "media", "cov", "J") %in% names(res))) stop(donde, "se espera list(sendero, media, cov, J)")
  if (!is.numeric(res$sendero) || length(res$sendero) != h || any(!is.finite(res$sendero))) stop(donde, "`sendero` debe tener ", h, " valores finitos")
  validar_densidad(res[c("media", "cov")], res$media, modelo_id)
  if (!is.matrix(res$J) || nrow(res$J) != h || any(!is.finite(res$J))) stop(donde, "`J` debe ser una matriz finita con ", h, " filas")
  invisible(TRUE)
}

#' Arma el resultado de un modelo gaussiano: suma J Σ_X J' (F6-15-a) y valida.
.resultado_condicional <- function(sendero, media, cov, J, Sx, modelo_id) {
  V <- cov + J %*% Sx %*% t(J)
  res <- list(sendero = sendero, media = media, cov = (V + t(V)) / 2, J = J)
  validar_condicional(res, length(sendero), modelo_id)
  res
}

#' Pronóstico condicional de un VAR en sus unidades (F6-06-a). `mu` (h x M): media incondicional de cada variable;
#' `Phi` (M x M x h): pesos MA; `Sigma`: covarianza de las innovaciones; `cols`: columnas de las predictoras
#' condicionadas y `vx` (h x k): su sendero en las unidades del modelo. El error apilado de la variable v en o+a es
#' Σ_{s<=a} Φ_{a-s}[v, ] u_{o+s}; se arma solo para el PIB (columna 1) y `cols`. Devuelve la media y la covarianza
#' del PIB dado el sendero y K = V_yx V_xx^{-1} (h x h k, predictora por predictora).
condicionar_var <- function(mu, Phi, Sigma, cols, vx, modelo_id = "VAR") {
  h <- nrow(mu); M <- ncol(mu); sel <- c(1L, cols); n <- length(sel)
  G <- matrix(0, n * h, M * h)                                  # filas (variable de sel, a); columnas (s, choque)
  for (a in seq_len(h)) for (s in seq_len(a)) G[(seq_len(n) - 1L) * h + a, (s - 1L) * M + seq_len(M)] <- Phi[sel, , a - s + 1L]
  Lc <- t(chol(Sigma))
  for (s in seq_len(h)) { b <- (s - 1L) * M + seq_len(M); G[, b] <- G[, b, drop = FALSE] %*% Lc }
  V <- tcrossprod(G)
  iy <- seq_len(h); ix <- h + seq_len(length(cols) * h)
  R <- tryCatch(chol(V[ix, ix]), error = function(e) stop(modelo_id, ": la covarianza del sendero condicionado no es definida positiva"))
  K <- t(backsolve(R, forwardsolve(t(R), V[ix, iy, drop = FALSE])))
  m <- as.vector(mu[, sel])
  C <- V[iy, iy] - K %*% V[ix, iy, drop = FALSE]
  list(media = m[iy] + drop(K %*% (as.vector(vx) - m[ix])), cov = (C + t(C)) / 2, K = K)
}

#' Cuantil `p` por columna de una mezcla con pesos iguales de normales N(mu[j, t], sd[j, t]²): la raíz de su
#' función de distribución (F6-13 a; F6-07 para las bandas de la combinación).
cuantil_mezcla_normal <- function(mu, sd, p) {
  vapply(seq_len(ncol(mu)), function(t_) {
    f <- function(x) mean(stats::pnorm(x, mu[, t_], sd[, t_])) - p
    stats::uniroot(f, c(min(mu[, t_] - 10 * sd[, t_]), max(mu[, t_] + 10 * sd[, t_])), tol = 1e-12)$root
  }, numeric(1))
}

#' Mediana por trimestre de una mezcla con pesos iguales de normales (F6-13 a).
mediana_mezcla_normal <- function(mu, sd) cuantil_mezcla_normal(mu, sd, 0.5)

# ---------------------------------------------------------------------------------------------
# ARIMAX
# ---------------------------------------------------------------------------------------------

condicional_arimax <- function(aj, h, senderos_x) {
  ext <- aj$predictoras[aj$predictoras %in% names(SATELITES_FASE6)]
  if (!length(ext)) stop(aj$modelo_id, ": ninguna predictora externa; el modelo no es condicionable (F6-01-b)")
  s <- senderos_modelo(senderos_x, ext, h, aj$modelo_id)
  sendero <- aj$y_o + cumsum(as.numeric(stats::predict(aj$fit, n.ahead = h, newxreg = .xreg_futuro(aj, h, fijos = s$dx))$pred))
  # Densidad: el sistema de Fase 5 con solo el error ARMA y las predictoras internas.
  int <- setdiff(aj$predictoras, ext); e_i <- c(1L, 1L + match(int, aj$predictoras))
  aj_i <- aj; aj_i$predictoras <- int; aj_i$ars <- aj$ars[int]; aj_i$beta <- aj$beta[int]
  aj_i$Sigma <- aj$Sigma[e_i, e_i, drop = FALSE]
  # J: Δy_{o+s} responde con β_{i,L} al Δlog de la predictora i en o+s−L (regresión con errores ARMA).
  dDY <- matrix(0, h, h * length(ext))
  for (c_ in seq_along(ext)) for (l in seq_along(aj$rezagos_x)) {
    L_ <- aj$rezagos_x[l]; b <- aj$beta[[ext[c_]]][l]
    for (s_ in seq_len(h)) if (s_ - L_ >= 1L) {
      j_ <- (c_ - 1L) * h + s_ - L_; dDY[s_, j_] <- dDY[s_, j_] + b
    }
  }
  .resultado_condicional(sendero, sendero, cov_sistema_arimax(aj_i, h), .acumulador(h) %*% dDY, s$Sx, aj$modelo_id)
}

# ---------------------------------------------------------------------------------------------
# Puente (F6-17)
# ---------------------------------------------------------------------------------------------

condicional_puente <- function(aj, h, senderos_x) {
  if (h > aj$H) stop(sprintf("%s: el puente se proyectó hasta h = %d y se pidió h = %d", aj$modelo_id, aj$H, h))
  ids_q <- .id_q(aj$predictoras); ext <- which(ids_q %in% names(SATELITES_FASE6))
  if (!length(ext)) stop(aj$modelo_id, ": ninguna predictora externa; el modelo no es condicionable (F6-01-b)")
  s <- senderos_modelo(senderos_x, ids_q[ext], h, aj$modelo_id)
  q_sat <- aj$ult %/% 3L + 1L                       # primer trimestre sin meses observados de cada predictora
  mascara <- matrix(FALSE, h, length(aj$predictoras))
  dX <- aj$dX_fut[seq_len(h), , drop = FALSE]
  J <- matrix(0, h, h * length(ext))
  for (c_ in seq_along(ext)) {
    i <- ext[c_]; f <- aj$o + seq_len(h) >= q_sat[[i]]
    mascara[, i] <- f
    dX[f, i] <- s$dx[f, ids_q[i]]
    J[, (c_ - 1L) * h + which(f)] <- .respuesta_sendero(aj$beta[[i]], aj$phi, h)[, f, drop = FALSE]
  }
  sendero <- iterar_puente(aj, dX, h)
  .resultado_condicional(sendero, sendero, cov_sistema_puente(aj, h, sendero = mascara), J, s$Sx, aj$modelo_id)
}

# ---------------------------------------------------------------------------------------------
# VAR y VECM
# ---------------------------------------------------------------------------------------------

#' `predictoras`: las del modelo, en el orden de sus columnas 2..M (panel_var()).
condicional_var <- function(aj, h, senderos_x, predictoras) {
  pos <- which(predictoras %in% names(SATELITES_FASE6))
  if (!length(pos)) stop(aj$modelo_id, ": ninguna predictora externa; el modelo no es condicionable (F6-01-b)")
  s <- senderos_modelo(senderos_x, predictoras[pos], h, aj$modelo_id)
  cols <- 1L + pos; L <- .acumulador(h); dif <- aj$forma == "dif"
  mu <- vapply(stats::predict(aj$fit, n.ahead = h)$fcst, function(f) unname(f[, "fcst"]), numeric(h))
  mu <- matrix(mu, nrow = h)
  vx <- if (dif) s$dx else sweep(L %*% s$dx, 2L, aj$fit$y[nrow(aj$fit$y), cols], "+")
  cn <- condicionar_var(mu, pesos_ma_var(aj$A, h), aj$Sigma, cols, vx, aj$modelo_id)
  if (dif) {
    .resultado_condicional(aj$y_o + cumsum(cn$media), aj$y_o + cumsum(cn$media), L %*% cn$cov %*% t(L), L %*% cn$K, s$Sx, aj$modelo_id)
  } else {
    .resultado_condicional(cn$media, cn$media, cn$cov, cn$K %*% kronecker(diag(length(pos)), L), s$Sx, aj$modelo_id)
  }
}

# ---------------------------------------------------------------------------------------------
# BVAR (F6-06-a, F6-13 a)
# ---------------------------------------------------------------------------------------------

#' Sendero de las predictoras `cols` en las unidades del BVAR: log-nivel desestacionalizado dentro del origen
#' (B2-5). El log-nivel observado en o es el del panel más su factor estacional; cada trimestre proyectado resta el
#' suyo.
niveles_condicion_bvar <- function(aj, dx, cols) {
  N <- nrow(aj$Y); h <- nrow(dx)
  l_o <- aj$Y[N, cols] + aj$estacional[aj$o %% 4L + 1L, cols]
  sweep(.acumulador(h) %*% dx, 2L, l_o, "+") - aj$estacional[(aj$o + seq_len(h)) %% 4L + 1L, cols, drop = FALSE]
}

#' Predictiva condicional de un VAR en log-niveles sobre extracciones (β_j, Σ_j). beta: S x (1 + M p) x M
#' (constante, rezago 1 de las M variables, rezago 2, ...), sigma: S x M x M, Y: panel del modelo. Por extracción, la
#' normal condicional de condicionar_var() más J_j Σ_X J_j'; la predictiva es la mezcla con pesos iguales: media y
#' covarianza por varianza total (denominador S, como B2-10), sendero = su mediana por trimestre (F6-13 a) y J = la
#' derivada de la media de la mezcla.
condicional_extracciones_var <- function(beta, sigma, Y, lags, h, cols, vx, Sx, modelo_id = "BVAR") {
  S <- dim(beta)[1]; M <- dim(beta)[3]; N <- nrow(Y); k <- length(cols)
  if (dim(beta)[2] != 1L + M * lags || !identical(dim(sigma), c(S, M, M)) || ncol(Y) != M || N < lags) stop(modelo_id, ": extracciones de dimensiones incompatibles")
  Lk <- kronecker(diag(k), .acumulador(h)); con_sx <- any(Sx != 0)
  x0 <- c(1, as.vector(t(Y[N:(N - lags + 1L), , drop = FALSE])))
  mu <- v <- matrix(NA_real_, S, h); Csum <- matrix(0, h, h); Jsum <- matrix(0, h, h * k)
  for (j in seq_len(S)) {
    B <- matrix(beta[j, , ], ncol = M)
    x <- x0; m_ <- matrix(NA_real_, h, M)
    for (t_ in seq_len(h)) {
      yn <- drop(x %*% B); m_[t_, ] <- yn
      x <- c(1, yn, if (lags > 1L) x[1L + seq_len(M * (lags - 1L))])
    }
    A <- lapply(seq_len(lags), function(l) t(B[1L + (l - 1L) * M + seq_len(M), , drop = FALSE]))
    cn <- condicionar_var(m_, pesos_ma_var(A, h), matrix(sigma[j, , ], M), cols, vx, modelo_id)
    J <- cn$K %*% Lk; C <- cn$cov
    if (con_sx) C <- C + J %*% Sx %*% t(J)
    mu[j, ] <- cn$media; v[j, ] <- diag(C); Csum <- Csum + C; Jsum <- Jsum + J
  }
  media <- colMeans(mu)
  V <- Csum / S + crossprod(sweep(mu, 2L, media)) / S
  res <- list(sendero = mediana_mezcla_normal(mu, sqrt(v)), media = media, cov = (V + t(V)) / 2, J = Jsum / S)
  validar_condicional(res, h, modelo_id)
  res
}

condicional_bvar <- function(aj, h, senderos_x, predictoras) {
  if (is.null(aj$beta)) stop(aj$modelo_id, ": el ajuste no guardó las extracciones (modelo_bvar(extracciones = TRUE))")
  if (h > aj$H) stop(aj$modelo_id, ": se pidió h = ", h, " y el ajuste se hizo con H = ", aj$H)
  pos <- which(predictoras %in% names(SATELITES_FASE6))
  if (!length(pos)) stop(aj$modelo_id, ": ninguna predictora externa; el modelo no es condicionable (F6-01-b)")
  s <- senderos_modelo(senderos_x, predictoras[pos], h, aj$modelo_id)
  cols <- 1L + pos
  condicional_extracciones_var(aj$beta, aj$sigma, aj$Y, aj$lags, h, cols, niveles_condicion_bvar(aj, s$dx, cols), s$Sx, aj$modelo_id)
}

# ---------------------------------------------------------------------------------------------
# Registro de Fase 6 (F6-01)
# ---------------------------------------------------------------------------------------------

#' Modelos de Fase 6 de un grupo: `condicionables` (los elegibles de F6-01, con predecir_condicional) y
#' `sin_escenario` (benchmarks, UNI.ARIMA, UNI.UC_LLT y, en G2, UNI.ARIMAX_IVAE.G2: su trayectoria con h = 20 se
#' reporta aparte). Los de forma directa y las combinaciones de Fase 5 quedan fuera. Cada modelo es el de Fase 5; el
#' BVAR y el puente se construyen con h = 20 y el BVAR guarda sus extracciones. `n_draw` y `n_burn` son los de Fase 5
#' (B2-7); solo las pruebas sintéticas los achican, para correr rápido.
modelos_fase6 <- function(grupo, n_draw = N_DRAW_BVAR, n_burn = N_BURN_BVAR) {
  if (length(grupo) != 1L || !grupo %in% DISENO_FASE6$grupos) stop("modelos_fase6: grupo no declarado: ", paste(grupo, collapse = ", "))
  h_max <- DISENO_FASE6$h_max
  arimax <- modelo_arimax_grupo(grupo)
  arimax$predecir_condicional <- function(aj, h, senderos_x) condicional_arimax(aj, h, senderos_x)
  mv <- lapply(modelos_multivariados_grupo(grupo), function(m) {
    pr <- setdiff(m$requiere, "objetivo")
    m$predecir_condicional <- function(aj, h, senderos_x) condicional_var(aj, h, senderos_x, pr)
    m
  })
  pr_b <- predictoras_grupo(grupo)
  bvar <- modelo_bvar(paste0("MULT.BVAR.", grupo), pr_b, n_draw = n_draw, n_burn = n_burn, H = h_max, extracciones = TRUE)
  bvar$predecir_condicional <- function(aj, h, senderos_x) condicional_bvar(aj, h, senderos_x, pr_b)
  puente <- modelo_puente(paste0("MIX.PUENTE.", grupo), predictoras_no_penalizadas(grupo, "M"), H = h_max)
  puente$predecir_condicional <- function(aj, h, senderos_x) condicional_puente(aj, h, senderos_x)
  cond <- c(list(arimax), mv, list(bvar, puente))
  sin <- c(modelos_referencia(), list(modelo_arima_fase5(), modelo_uc_llt()), if (grupo == "G2") list(modelo_arimax_ivae()))
  if (!all(vapply(cond, es_condicionable, logical(1))) || any(vapply(sin, es_condicionable, logical(1)))) {
    stop("modelos_fase6: el registro de ", grupo, " no cumple el criterio de F6-01-b")
  }
  invisible(lapply(c(cond, sin), .validar_modelo))
  list(condicionables = cond, sin_escenario = sin)
}

#' Trayectoria sin escenario (F6-01) de un modelo ajustado: su sendero de Fase 5 con h pasos y, si el modelo la
#' tiene, su densidad (BENCH.MEDIA_CRECIMIENTO no la tiene, como en Fase 5). Mismo formato que predecir_condicional()
#' sin J.
trayectoria_sin_escenario <- function(m, aj, h = DISENO_FASE6$h_max) {
  sendero <- m$predecir(aj, h)
  if (!is.function(m$predecir_densidad)) return(list(sendero = sendero, media = NULL, cov = NULL))
  dens <- m$predecir_densidad(aj, h)
  validar_densidad(dens, sendero, m$modelo_id)
  list(sendero = sendero, media = dens$media, cov = dens$cov)
}
