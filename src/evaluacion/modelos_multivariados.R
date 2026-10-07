# src/evaluacion/modelos_multivariados.R
#
# Modelos multivariados de Fase 5, bloque B2a (F5-07, F5-12 y B2-1 a B2-8 de doc/metodologia/decisiones_fase5.md),
# bajo el contrato de modelo del motor (eval_lib.R §4; especificación del motor §2) con los campos opcionales de
# Fase 5 (`piso_gl`, `diagnosticar`). Sin I/O y sin estado global: cada modelo solo ve lo que el motor le pasa, ya
# recortado al origen (G-1) y con el borde completo (G-7). El BVAR es el bloque B2b (PR propio, B2-8).
#
#   MULT.VAR_DIF.Gk   VAR(p) en Δ de los log-niveles: Δy (PIB SA) y Δlog de las predictoras del VAR del grupo, con
#                     constante y, si alguna serie es NSA, dummies estacionales centradas (vars, season = 4); p por
#                     BIC (VARselect, misma muestra para todos los candidatos) en 1..p_max (B2-1, B2-2). El sendero
#                     es y_o más la suma de los Δy pronosticados.
#   MULT.VAR_NIV.G1   VAR(p) en log-niveles, sin imponer raíces unitarias, con constante y dummies (B2-1).
#   MULT.VECM.G1      Johansen dentro del origen (urca::ca.jo, traza al 5 %, ecdet = "none": constante no
#                     restringida, caso 3; K = max(2, p del BIC en niveles); dummies centradas) (B2-3). Con 0 < r < k,
#                     el VECM en su forma VAR en niveles (vars::vec2var); con r = 0, VAR en Δ con K − 1 rezagos (el
#                     VECM anidado); con r = k, VAR en niveles con K rezagos (B2-4). El r y la forma usada van a
#                     diagnosticos.csv.
#
# Series (F5-07 con B1b-2; predictoras_no_penalizadas()): G1 PIB + remesas nominales + FOB; G2 y G3 PIB + IVAE +
# remesas nominales. MULT.VAR_DIF.G3 tiene la misma especificación que MULT.VAR_DIF.G2 y su muestra empieza donde
# empiezan sus tres series (2005-Q1), así que en los orígenes comunes sus pronósticos coinciden (B2-6, declarado).
#
# Densidad (F5-12, B2-1): gaussiana plug-in del sendero en log-nivel, list(media = sendero, cov). El error del
# sendero del PIB es lineal en las innovaciones futuras u_{o+1..o+h} del VAR: e_j = Σ_{k<=j} a_{j-k}' u_{o+k}, con
# a_m la primera fila de Φ_m (pesos MA de la forma VAR, vars::Phi) en niveles, o de Ψ_m = Σ_{i<=m} Φ_i si el VAR
# está en diferencias. cov = G (I_h ⊗ Σ_u) G'. Σ_u es la de vars en cada clase: crossprod(resid) / (obs − regresores
# por ecuación) en un VAR, crossprod(resid) / obs en un vec2var; así la diagonal reproduce la varianza de
# predict() en un VAR en niveles (prueba en tests/test-modelos-multivariados.R).

P_MAX_VAR <- c(G1 = 4L, G2 = 3L, G3 = 3L)   # B2-2: rejilla de p, fija en todos los orígenes del grupo
P_MAX_VECM <- 4L                             # B2-3: K = max(2, p del BIC en niveles, p en 1..4); solo G1
NIVEL_JOHANSEN <- "5pct"                     # B2-3: valores críticos de urca::ca.jo
SERIES_VAR <- list(                          # F5-07 con B1b-2 (orden: el de la ficha)
  G1 = c("BCR.REMESAS.NOM.NSA.Q", "BCR.EXPORT_FOB.NOM.NSA.Q"),
  G2 = c("BCR.IVAE.VOL.SA.Q", "BCR.REMESAS.NOM.NSA.Q"),
  G3 = c("BCR.IVAE.VOL.SA.Q", "BCR.REMESAS.NOM.NSA.Q")
)
FORMAS_VECM <- c(dif = 0, vecm = 1, niv = 2)  # código numérico de la forma usada, para diagnosticos.csv

# ---------------------------------------------------------------------------------------------
# Datos del origen
# ---------------------------------------------------------------------------------------------

#' log de una serie trimestral (data.frame periodo, valor) nombrado por índice; falla si no es positiva o tiene huecos.
.log_q <- function(d, nombre, modelo_id) {
  if (!all(c("periodo", "valor") %in% names(d))) stop(modelo_id, ": ", nombre, " necesita periodo y valor")
  iq <- q_a_ind(d$periodo)
  if (any(diff(iq) != 1L)) stop(modelo_id, ": ", nombre, " tiene trimestres faltantes o desordenados")
  if (anyNA(d$valor) || any(d$valor <= 0)) stop(modelo_id, ": ", nombre, " trae valores no positivos o ausentes (se usa el log)")
  stats::setNames(log(d$valor), iq)
}

#' Panel de log-niveles (PIB SA y predictoras) en la muestra común de sus series, hasta el origen. Cada predictora
#' debe llegar al origen (F5-04, parte 1: los modelos trimestrales usan los .Q hasta o).
panel_var <- function(datos, predictoras, modelo_id) {
  y <- .y_de(datos); iy <- q_a_ind(datos$objetivo$periodo); o <- utils::tail(iy, 1)
  if (any(diff(iy) != 1L)) stop(modelo_id, ": el objetivo tiene trimestres faltantes o desordenados")
  series <- c(list(PIB = stats::setNames(y, iy)),
              stats::setNames(lapply(predictoras, function(id) .log_q(datos[[id]], id, modelo_id)), predictoras))
  for (id in predictoras) if (as.integer(utils::tail(names(series[[id]]), 1)) != o) stop(modelo_id, ": ", id, " no llega al origen ", ind_a_q(o), " (F5-04)")
  ini <- max(vapply(series, function(s) as.integer(names(s))[1], integer(1)))
  t_ <- ini:o
  Y <- vapply(series, function(s) unname(s[as.character(t_)]), numeric(length(t_)))
  Y <- matrix(Y, nrow = length(t_), dimnames = list(t_, names(series)))
  if (anyNA(Y)) stop(modelo_id, ": el panel tiene NA en la muestra común")
  list(Y = Y, t = t_, o = o, nsa = any(grepl(".NSA.", predictoras, fixed = TRUE)))
}

# ---------------------------------------------------------------------------------------------
# Piezas comunes
# ---------------------------------------------------------------------------------------------

#' p por BIC (SC de vars::VARselect, misma muestra para todos los candidatos) en 1..p_max.
.p_bic <- function(Y, p_max, season, modelo_id, o) {
  sel <- vars::VARselect(Y, lag.max = p_max, type = "const", season = season)
  p <- unname(as.integer(sel$selection["SC(n)"]))
  if (length(p) != 1L || is.na(p) || p < 1L || p > p_max) stop(modelo_id, " en ", ind_a_q(o), ": VARselect no devolvió un orden válido")
  p
}

#' VAR(p) con constante y dummies centradas opcionales; Σ_u de vars (grados de libertad por ecuación).
.ajustar_varest <- function(Y, p, season, modelo_id, o) {
  fit <- vars::VAR(Y, p = p, type = "const", season = season)
  B <- vars::Bcoef(fit)
  if (any(!is.finite(B))) stop(modelo_id, " en ", ind_a_q(o), ": coeficientes del VAR no finitos")
  df <- vapply(fit$varresult, function(e) summary(e)$df[2], numeric(1))
  Sigma <- crossprod(stats::resid(fit)) / df[1]           # como vars:::.fecov (todas las ecuaciones con los mismos regresores)
  list(fit = fit, A = vars::Acoef(fit), Sigma = Sigma)
}

#' Σ_u de un vec2var, como vars:::.fecovvec2var (denominador obs).
.sigma_vec2var <- function(v) crossprod(stats::resid(v)) / v$obs

#' Módulo máximo de las raíces de la forma compañera de A_1..A_p (estabilidad; 1 = raíz unitaria).
raiz_max_var <- function(A) {
  K <- nrow(A[[1]]); p <- length(A)
  M <- matrix(0, K * p, K * p)
  M[seq_len(K), ] <- do.call(cbind, A)
  if (p > 1L) M[(K + 1L):(K * p), seq_len(K * (p - 1L))] <- diag(K * (p - 1L))
  max(Mod(eigen(M, only.values = TRUE)$values))
}

#' Pesos MA Φ_0..Φ_{h-1} (K x K x h) de un VAR con matrices A_1..A_p (Φ_0 = I, Φ_m = Σ_i A_i Φ_{m-i}).
pesos_ma_var <- function(A, h) {
  K <- nrow(A[[1]]); p <- length(A)
  Phi <- array(0, c(K, K, h)); Phi[, , 1] <- diag(K)
  if (h > 1L) for (m in 2:h) for (i in seq_len(min(p, m - 1L))) Phi[, , m] <- Phi[, , m] + A[[i]] %*% Phi[, , m - i]
  Phi
}

#' Covarianza h x h del sendero de la variable `fila` (el PIB) desde los pesos MA y Σ_u. Si `acumular`, el VAR
#' está en diferencias y el error del log-nivel acumula los pesos: Ψ_m = Σ_{i<=m} Φ_i.
cov_sendero_var <- function(Phi, Sigma, acumular, fila = 1L) {
  K <- dim(Phi)[1]; h <- dim(Phi)[3]
  a <- t(vapply(seq_len(h), function(m) Phi[fila, , m], numeric(K)))   # h x K: fila m = a_{m-1}'
  if (h == 1L) a <- matrix(a, nrow = 1L)
  if (acumular) a <- apply(a, 2, cumsum)
  if (h == 1L) a <- matrix(a, nrow = 1L)
  G <- matrix(0, h, h * K)
  for (j in seq_len(h)) for (k in seq_len(j)) G[j, (k - 1L) * K + seq_len(K)] <- a[j - k + 1L, ]
  S <- G %*% kronecker(diag(h), Sigma) %*% t(G)
  (S + t(S)) / 2
}

#' Guarda de Σ_u (Regla 7): definida positiva.
.guarda_sigma <- function(Sigma, modelo_id, o) {
  if (any(!is.finite(Sigma)) || inherits(try(chol(Sigma), silent = TRUE), "try-error")) {
    stop(modelo_id, " en ", ind_a_q(o), ": la covarianza de las innovaciones no es definida positiva")
  }
  invisible(TRUE)
}

#' Pronóstico puntual h pasos de la primera variable con vars::predict (varest o vec2var).
.fcst_pib <- function(fit, h) unname(as.numeric(stats::predict(fit, n.ahead = h)$fcst[[1]][, "fcst"]))

# ---------------------------------------------------------------------------------------------
# VAR en diferencias y en niveles (B2-1, B2-2)
# ---------------------------------------------------------------------------------------------

#' Ajuste de un VAR en un origen. forma = "dif" (Δ de los log-niveles) o "niv" (log-niveles).
ajustar_var <- function(datos, predictoras, p_max, forma, modelo_id) {
  pn <- panel_var(datos, predictoras, modelo_id)
  season <- if (pn$nsa) 4L else NULL
  Y <- if (forma == "dif") diff(pn$Y) else pn$Y
  if (nrow(Y) - p_max <= ncol(Y) * p_max + 1L + 3L * pn$nsa) stop(modelo_id, " en ", ind_a_q(pn$o), ": muestra insuficiente para p_max = ", p_max)
  p <- .p_bic(Y, p_max, season, modelo_id, pn$o)
  v <- .ajustar_varest(Y, p, season, modelo_id, pn$o)
  .guarda_sigma(v$Sigma, modelo_id, pn$o)
  list(modelo_id = modelo_id, forma = forma, fit = v$fit, A = v$A, Sigma = v$Sigma, p = p, o = pn$o,
       y_o = unname(pn$Y[nrow(pn$Y), 1]), n_muestra = nrow(Y), raiz_max = raiz_max_var(v$A),
       gl = c(n_obs = nrow(Y) - p_max, n_par = ncol(Y) * p_max + 1L + 3L * pn$nsa))          # el mayor candidato
}

#' Sendero en log-nivel del PIB de un ajuste VAR/VECM según su forma.
sendero_var <- function(aj, h) {
  f <- .fcst_pib(aj$fit, h)
  if (aj$forma == "dif") aj$y_o + cumsum(f) else f
}

densidad_var <- function(aj, h) list(media = sendero_var(aj, h),
                                     cov = cov_sendero_var(pesos_ma_var(aj$A, h), aj$Sigma, acumular = aj$forma == "dif"))

#' Fábrica de un VAR bajo el contrato del motor.
modelo_var <- function(modelo_id, predictoras, p_max, forma = c("dif", "niv")) {
  forma <- match.arg(forma)
  list(
    modelo_id = modelo_id, requiere = c("objetivo", predictoras), piso_gl = TRUE, p_max = p_max, forma = forma,
    ajustar = function(datos, spec) ajustar_var(datos, predictoras, p_max, forma, modelo_id),
    predecir = function(aj, h) sendero_var(aj, h),
    predecir_densidad = function(aj, h) densidad_var(aj, h),
    diagnosticar = function(aj) c(p = aj$p, n_obs = aj$n_muestra - aj$p, raiz_max = aj$raiz_max)
  )
}

# ---------------------------------------------------------------------------------------------
# VECM (B2-3, B2-4)
# ---------------------------------------------------------------------------------------------

#' Rango de cointegración por la traza de Johansen: el primer r0 en 0..k-1 cuya hipótesis r <= r0 no se rechaza al
#' nivel dado; k si se rechazan todas. ca.jo ordena las filas de r <= k-1 a r = 0.
rango_johansen <- function(cj, nivel = NIVEL_JOHANSEN) {
  stat <- rev(unname(cj@teststat)); cv <- rev(unname(cj@cval[, nivel]))
  k <- length(stat); r <- 0L
  while (r < k && stat[r + 1L] > cv[r + 1L]) r <- r + 1L
  r
}

ajustar_vecm <- function(datos, predictoras, modelo_id, p_max = P_MAX_VECM) {
  pn <- panel_var(datos, predictoras, modelo_id)
  season <- if (pn$nsa) 4L else NULL
  k <- ncol(pn$Y)
  p_niv <- .p_bic(pn$Y, p_max, season, modelo_id, pn$o)
  K <- max(2L, p_niv)
  cj <- urca::ca.jo(pn$Y, type = "trace", ecdet = "none", K = K, spec = "transitory", season = season)
  r <- rango_johansen(cj)
  if (r == 0L) {                                   # B2-4: el VECM anidado, VAR en Δ con K − 1 rezagos
    v <- .ajustar_varest(diff(pn$Y), K - 1L, season, modelo_id, pn$o); forma <- "dif"; fit <- v$fit; A <- v$A; Sigma <- v$Sigma
  } else if (r == k) {                             # B2-4: rango completo, VAR en niveles con K rezagos
    v <- .ajustar_varest(pn$Y, K, season, modelo_id, pn$o); forma <- "niv"; fit <- v$fit; A <- v$A; Sigma <- v$Sigma
  } else {
    fit <- vars::vec2var(cj, r = r); forma <- "vecm"; A <- fit$A; Sigma <- .sigma_vec2var(fit)
    if (any(!is.finite(unlist(A)))) stop(modelo_id, " en ", ind_a_q(pn$o), ": coeficientes del VECM no finitos")
  }
  .guarda_sigma(Sigma, modelo_id, pn$o)
  list(modelo_id = modelo_id, forma = forma, fit = fit, A = A, Sigma = Sigma, K = K, r = r, o = pn$o,
       y_o = unname(pn$Y[nrow(pn$Y), 1]), n_muestra = nrow(pn$Y), raiz_max = raiz_max_var(A),
       traza = rev(unname(cj@teststat)),
       gl = c(n_obs = nrow(pn$Y) - p_max, n_par = k * p_max + 1L + 3L * pn$nsa))    # el mayor caso: VAR en niveles con K = 4
}

modelo_vecm <- function(modelo_id, predictoras) list(
  modelo_id = modelo_id, requiere = c("objetivo", predictoras), piso_gl = TRUE, p_max = P_MAX_VECM,
  ajustar = function(datos, spec) ajustar_vecm(datos, predictoras, modelo_id),
  predecir = function(aj, h) sendero_var(aj, h),
  predecir_densidad = function(aj, h) densidad_var(aj, h),
  diagnosticar = function(aj) c(K = aj$K, r = aj$r, forma = unname(FORMAS_VECM[aj$forma]), n_obs = aj$n_muestra - aj$K,
                                raiz_max = aj$raiz_max, stats::setNames(aj$traza, paste0("traza_r", seq_along(aj$traza) - 1L)))
)

# ---------------------------------------------------------------------------------------------
# Registro de B2a por grupo
# ---------------------------------------------------------------------------------------------

#' Los multivariados de B2a del grupo (F5-07): VAR_DIF en los tres grupos; VAR_NIV y VECM solo en G1.
modelos_multivariados_grupo <- function(grupo) {
  if (length(grupo) != 1L || !grupo %in% names(SERIES_VAR)) stop("modelos_multivariados_grupo: grupo no declarado: ", paste(grupo, collapse = ", "))
  s <- SERIES_VAR[[grupo]]
  if (!all(s %in% predictoras_no_penalizadas(grupo))) stop("modelos_multivariados_grupo: el VAR de ", grupo, " pide series fuera de predictoras_no_penalizadas() (B1b-2)")
  c(list(modelo_var(paste0("MULT.VAR_DIF.", grupo), s, P_MAX_VAR[[grupo]], "dif")),
    if (grupo == "G1") list(modelo_var("MULT.VAR_NIV.G1", s, P_MAX_VAR[["G1"]], "niv"), modelo_vecm("MULT.VECM.G1", s)))
}
