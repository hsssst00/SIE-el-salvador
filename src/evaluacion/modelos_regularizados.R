# src/evaluacion/modelos_regularizados.R
#
# Regularizados de Fase 5, bloque B3 (PR 2; F5-09, F5-11, F5-12 y B3-1 a B3-7 de doc/metodologia/decisiones_fase5.md),
# bajo el contrato del motor (eval_lib.R §4) por medio de la forma directa de forma_directa.R (modelo_directo(); C3 y
# C4). Sin I/O y sin estado global: cada modelo solo ve lo que el motor le pasa, ya recortado al origen (G-1).
#
#   REG.ENET.Gk  un solo elastic net con glmnet (F5-09): α ∈ {0; 0,5; 1} y λ elegidos por validación anidada (F5-11),
#                sobre la ventana de B3-2 (columnas y g_h sin la parte estacional y estandarizadas), con
#                standardize = FALSE e intercept = FALSE (la constante y las dummies salen en la ventana, sin
#                penalizar). Rejilla de λ de B3-1: por origen, h y α, 100 valores log-espaciados desde
#                λ_max = max |Z'g| / (n · max(α, 10⁻³)) (el de glmnet) hasta λ_max · 10⁻³, pasada de forma explícita
#                a glmnet (con su propia rejilla y p > n, glmnet corta la senda antes de los 100 valores).
#   REG.PCR.Gk   regresión sobre los k primeros componentes principales (stats::prcomp) de las columnas de la ventana
#                de B3-2 (rezagos del PIB incluidos, B3-3), k ∈ 1..5 por validación anidada; MCO de g_h residualizado
#                sobre los k componentes (por Frisch-Waugh-Lovell, el MCO con constante, dummies y k componentes).
#
# Predictores (F5-09; B1b-2): Δy y el Δlog de todas las predictoras del grupo (en G3, también las remesas reales),
# rezagos 0..3. Directos por h (F5-05). Sin piso de grados de libertad (F5-09). Densidad: Σ = D R D de los errores
# internos (F5-12, B3-5, B3-6). Las rejillas se ordenan de más a menos penalizado: un empate en el ECM interno va al
# candidato más penalizado.

ALFAS_ENET        <- c(0, 0.5, 1)   # F5-09
N_LAMBDA_ENET     <- 100L           # B3-1
RAZON_LAMBDA_ENET <- 1e-3           # B3-1: λ_min = λ_max · 10⁻³
ALFA_MIN_LAMBDA   <- 1e-3           # glmnet calcula el λ_max de ridge como si α = 10⁻³
K_MAX_PCR         <- 5L             # F5-09: k ∈ 1..5

# ---------------------------------------------------------------------------------------------
# REG.ENET (glmnet)
# ---------------------------------------------------------------------------------------------

#' λ_max del elastic net sobre la ventana (Z, g) ya transformada: el menor λ que anula todos los coeficientes
#' (para α = 0, el que usa glmnet con α = 10⁻³).
lambda_max_enet <- function(Z, g, alpha) max(abs(crossprod(Z, g))) / (nrow(Z) * max(alpha, ALFA_MIN_LAMBDA))

#' Rejilla de B3-1 sobre la ventana final de un origen y un h: por α, 100 valores de λ de mayor a menor.
rejilla_enet <- function(Z, g, h, alfas = ALFAS_ENET, n_lambda = N_LAMBDA_ENET, razon = RAZON_LAMBDA_ENET) {
  do.call(rbind, lapply(alfas, function(a) {
    lm <- lambda_max_enet(Z, g, a)
    if (!is.finite(lm) || !(lm > 0)) stop(sprintf("REG.ENET: λ_max no positivo con α = %g (g sin covariación con las columnas en la ventana final; B3-7)", a))
    data.frame(alpha = a, lambda = exp(seq(log(lm), log(lm * razon), length.out = n_lambda)), pos = seq_len(n_lambda))
  }))
}

#' Senda de glmnet con la rejilla explícita de un α. Falla si la senda queda incompleta o con coeficientes no finitos
#' (B3-7).
.senda_glmnet <- function(Z, g, alpha, lambda) {
  fit <- glmnet::glmnet(Z, g, family = "gaussian", alpha = alpha, lambda = lambda, standardize = FALSE, intercept = FALSE)
  if (length(fit$lambda) != length(lambda)) {
    stop(sprintf("REG.ENET: la senda de glmnet con α = %g quedó incompleta (%d de %d valores de λ; B3-7)", alpha, length(fit$lambda), length(lambda)))
  }
  B <- as.matrix(fit$beta)
  if (any(!is.finite(B)) || any(!is.finite(fit$a0)) || any(fit$a0 != 0)) stop(sprintf("REG.ENET: coeficientes no finitos con α = %g (B3-7)", alpha))
  B
}

#' Pronósticos del elastic net en la fila `z` para los candidatos `cand` de la rejilla. Por cada α presente en `cand`
#' estima la senda completa de su rejilla (así el pronóstico de un candidato no depende de qué otros se piden).
estimar_predecir_enet <- function(Z, g, z, rejilla, cand) {
  out <- numeric(length(cand))
  for (a in unique(rejilla$alpha[cand])) {
    ia <- which(rejilla$alpha == a)
    B <- .senda_glmnet(Z, g, a, rejilla$lambda[ia])
    P <- matrix(z, nrow = 1L) %*% B
    sel <- which(rejilla$alpha[cand] == a)
    out[sel] <- P[1L, rejilla$pos[cand[sel]]]
  }
  out
}

especificacion_enet <- function() list(
  transformar = TRUE,
  candidatos = function(Z, g, h) rejilla_enet(Z, g, h),
  estimar_predecir = estimar_predecir_enet,
  diagnosticar = function(rejilla, j) c(alpha = rejilla$alpha[j], lambda = rejilla$lambda[j], lambda_pos = rejilla$pos[j],
                                        borde = as.numeric(rejilla$pos[j] %in% c(1L, max(rejilla$pos))))
)

# ---------------------------------------------------------------------------------------------
# REG.PCR (prcomp)
# ---------------------------------------------------------------------------------------------

rejilla_pcr <- function(Z, g, h, k_max = K_MAX_PCR) data.frame(k = seq_len(k_max))

#' Pronósticos del PCR en la fila `z` para los candidatos `cand`. Los componentes salen de la ventana ya transformada
#' (centrada y escalada, B3-2); el k-ésimo debe tener varianza: si no la tiene, la ventana perdió rango o tiene menos
#' filas que parámetros (constante, dummies y k componentes), y el motor se detiene (B3-7).
estimar_predecir_pcr <- function(Z, g, z, rejilla, cand) {
  k_max <- max(rejilla$k[cand])
  pc <- stats::prcomp(Z, center = FALSE, scale. = FALSE)
  if (k_max > length(pc$sdev) || !(pc$sdev[k_max] > sqrt(.Machine$double.eps) * pc$sdev[1])) {
    stop(sprintf("REG.PCR: el componente %d no tiene varianza en una ventana de %d filas: pierde rango o hay menos filas que parámetros (B3-7)", k_max, nrow(Z)))
  }
  S <- pc$x[, seq_len(k_max), drop = FALSE]
  zs <- matrix(z, nrow = 1L) %*% pc$rotation[, seq_len(k_max), drop = FALSE]
  vapply(cand, function(j) {
    k <- rejilla$k[j]
    q <- qr(S[, seq_len(k), drop = FALSE])
    if (q$rank < k) stop(sprintf("REG.PCR: el MCO sobre %d componentes pierde rango (B3-7)", k))
    sum(zs[1L, seq_len(k)] * qr.coef(q, g))
  }, numeric(1))
}

especificacion_pcr <- function() list(
  transformar = TRUE,
  candidatos = function(Z, g, h) rejilla_pcr(Z, g, h),
  estimar_predecir = estimar_predecir_pcr,
  diagnosticar = function(rejilla, j) c(k = rejilla$k[j], borde = as.numeric(rejilla$k[j] == max(rejilla$k)))
)

# ---------------------------------------------------------------------------------------------
# Registro por grupo
# ---------------------------------------------------------------------------------------------

modelo_enet_grupo <- function(grupo) modelo_directo(paste0("REG.ENET.", grupo), predictoras_grupo(grupo), especificacion_enet())
modelo_pcr_grupo  <- function(grupo) modelo_directo(paste0("REG.PCR.", grupo), predictoras_grupo(grupo), especificacion_pcr())

#' Los regularizados de un grupo (F5-09), con todas sus predictoras (B1b-2), en el orden en que se reportan.
modelos_regularizados_grupo <- function(grupo) {
  if (length(grupo) != 1L || !grupo %in% names(GRUPOS_PREDICTORAS)) stop("modelos_regularizados_grupo: grupo no declarado: ", paste(grupo, collapse = ", "))
  list(modelo_enet_grupo(grupo), modelo_pcr_grupo(grupo))
}
