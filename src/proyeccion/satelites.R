# satelites.R
#
# Ecuaciones satélite del Ejercicio B (checklist de Fase 6, D3; F6-03, F6-15, F6-15-a, F6-15-b, F6-17-a de
# doc/metodologia/decisiones_fase6.md; protocolo_proyeccion.md §5). Una satélite por predictora externa
# (SATELITES_FASE6): ADL en Δlog de la predictora X sobre una variable de escenario Z,
#
#   Δlog X_t = c + δ'D_t + Σ_{i=1..p} φ_i Δlog X_{t−i} + Σ_{j=0..q} β_j Δlog Z_{t−j} + e_t,
#
# con D las dummies T2..T4 (las seis predictoras son NSA), p y q en 0..4 por BIC y β_0 siempre presente. Cada una se
# declara en catalogos/06_modelos/<satelite_id>.yaml. Sin I/O y sin estado global: las series llegan como
# data.frame(periodo, valor) trimestrales, ya leídas de L3 por quien llama.
#
# Produce el insumo de predecir_condicional() (src/proyeccion/condicional.R, F6-06-c):
#   senderos_x = list(dlog = matriz h x k de Δlog, filas o+1..o+h, colnames = predictoras .Q;
#                     cov  = Σ_X, (h k) x (h k), predictora por predictora)
#
# Borde (F6-17-a): las .Q de L3 solo traen trimestres completos (agregar_trimestral_promedio() y _suma() descartan
# el último si está incompleto), así que todo trimestre de X posterior a `o` que llegue en la serie es dato: entra
# en `dlog` con error cero y la satélite arranca en el siguiente. La estimación usa solo hasta `o` (F6-15).
#
# Error (F6-15-a): Σ_X = G (Σ_e ⊗ I_h) G', con G los pesos MA ψ de cada satélite (su polinomio en φ; Z es conocido)
# desde su primer trimestre proyectado, y Σ_e la covarianza contemporánea de los residuos de las satélites del
# conjunto pedido, con stats::cov en sus trimestres comunes (como B1-5). Por eso Σ_X depende del conjunto de
# predictoras: senderos_satelites() se llama con las del modelo que lo recibe.

source(here::here("src", "proyeccion", "diseno_fase6.R"))
source(here::here("src", "evaluacion", "modelos_univariados.R"))   # dummies_trimestrales(), PISO_GL (eval_lib)

ORDENES_SATELITE <- list(p_max = 4L, q_max = 4L)   # F6-15: p y q en 0..4; en los YAML SAT.*
ANIOS_FUERA_SATELITE <- c(2020L, 2021L)           # F6-15: sin las filas de 2020 y 2021 (como F6-08-a y F6-09-a)

# Variable de escenario de cada satélite (F6-15): la serie histórica de L3 con la que se estima y el prefijo de sus
# series ESC.* de L3 (F6-18), que llevan historia + sendero hasta 2031-T4.
VARIABLES_SATELITE <- data.frame(
  predictora = names(SATELITES_FASE6),
  satelite_id = unname(SATELITES_FASE6),
  z_historia = c("FRED.PIB_EEUU.VOL.SA.Q", "FRED.PIB_EEUU.VOL.SA.Q", "FRED.PIB_EEUU.VOL.SA.Q",
                 "FRED.IPC_EEUU.IDX.SA.Q", "FMI.PETROLEO_APSP.USD.NSA.Q", "FMI.PETROLEO_APSP.USD.NSA.Q"),
  z_escenario = c("ESC.PIB_EEUU.VOL.SA.Q", "ESC.PIB_EEUU.VOL.SA.Q", "ESC.PIB_EEUU.VOL.SA.Q",
                  "ESC.IPC_EEUU.IDX.SA.Q", "ESC.PETROLEO_APSP.USD.NSA.Q", "ESC.PETROLEO_APSP.USD.NSA.Q"),
  stringsAsFactors = FALSE
)

#' Fila de VARIABLES_SATELITE de una predictora .Q; falla visible si no tiene satélite.
.variable_satelite <- function(predictora) {
  i <- match(predictora, VARIABLES_SATELITE$predictora)
  if (length(predictora) != 1L || is.na(i)) stop("satélites: ", paste(predictora, collapse = ", "), " no tiene satélite en SATELITES_FASE6")
  VARIABLES_SATELITE[i, ]
}

#' series_master_id de la variable de escenario de `predictora` en `escenario`, entre los ids de L3 `disponibles`.
#' Una variable que el escenario no publica usa la serie BASE (F6-18: no se duplica); sin BASE, stop().
serie_escenario <- function(predictora, escenario, disponibles) {
  if (length(escenario) != 1L || !escenario %in% DISENO_FASE6$escenarios) stop("serie_escenario: escenario no declarado: ", paste(escenario, collapse = ", "))
  pref <- .variable_satelite(predictora)$z_escenario
  for (id in paste0(pref, ".", unique(c(escenario, "BASE")))) if (id %in% disponibles) return(id)
  stop("serie_escenario: no hay ", pref, ".", escenario, " ni ", pref, ".BASE en L3")
}

#' Δlog de una serie trimestral (data.frame periodo, valor), nombrado por índice trimestral. Falla si no es positiva,
#' tiene huecos o está desordenada.
.dlog_satelite <- function(d, nombre, satelite_id) {
  donde <- paste0(satelite_id, ": ", nombre)
  if (!is.data.frame(d) || !all(c("periodo", "valor") %in% names(d))) stop(donde, " debe ser data.frame(periodo, valor)")
  iq <- q_a_ind(d$periodo)
  if (length(iq) < 3L) stop(donde, " tiene menos de 3 trimestres")
  if (any(diff(iq) != 1L)) stop(donde, " tiene trimestres faltantes o desordenados")
  if (anyNA(d$valor) || any(d$valor <= 0)) stop(donde, " trae valores no positivos o ausentes (se usa el Δlog)")
  stats::setNames(diff(log(d$valor)), iq[-1])
}

#' Regresores de la satélite en los trimestres `t_`: constante, dummies T2..T4, Δlog X en t−1..t−p y Δlog Z en t..t−q.
.diseno_satelite <- function(dx, dz, t_, p, q) {
  X <- cbind(1, dummies_trimestrales(t_))
  for (i in seq_len(p)) X <- cbind(X, unname(dx[as.character(t_ - i)]))
  for (j in 0:q) X <- cbind(X, unname(dz[as.character(t_ - j)]))
  colnames(X) <- c("c", "T2", "T3", "T4", if (p > 0L) paste0("x_L", seq_len(p)), paste0("z_L", 0:q))
  X
}

#' Trimestres de la muestra con L1 rezagos de X y L2 de Z disponibles, hasta `o` y sin 2020-2021 (F6-15).
.filas_satelite <- function(dx, dz, o, L1, L2) {
  ix <- as.integer(names(dx)); iz <- as.integer(names(dz))
  t_ <- seq.int(max(ix[1] + L1, iz[1] + L2), o)
  t_[!(t_ %/% 4L) %in% ANIOS_FUERA_SATELITE]
}

#' Estima una satélite en el origen `o` (F6-15). `x` y `z`: data.frame(periodo, valor) trimestrales de la predictora y
#' de la variable de escenario histórica; se usan hasta `o`. Los candidatos p, q en 0..p_max, 0..q_max se comparan
#' por BIC (n log(RSS/n) + k log n) en la misma muestra, la de los trimestres con max(p_max, q_max) rezagos de las dos
#' series; el elegido se reestima por MCO con su muestra máxima, como seleccionar_ar_bic_x() (F5-05). Guardas con
#' stop() (F6-15): regresores sin rango completo, menos de PISO_GL grados de libertad con el mayor candidato (como
#' G-8 de Fase 5) y raíz del polinomio en φ dentro o sobre el círculo unitario.
ajustar_satelite <- function(x, z, o, satelite_id, p_max = ORDENES_SATELITE$p_max, q_max = ORDENES_SATELITE$q_max) {
  o <- as.integer(o)
  dx <- .dlog_satelite(x, "la predictora", satelite_id); dz <- .dlog_satelite(z, "la variable de escenario", satelite_id)
  for (d in list(list(dx, "la predictora"), list(dz, "la variable de escenario"))) {
    if (as.integer(utils::tail(names(d[[1]]), 1)) < o) stop(satelite_id, ": ", d[[2]], " no llega al origen ", ind_a_q(o), " (F6-17-a)")
  }
  dx <- dx[as.integer(names(dx)) <= o]; dz <- dz[as.integer(names(dz)) <= o]
  # BIC en la muestra común de los candidatos.
  t_b <- .filas_satelite(dx, dz, o, p_max, q_max); n_b <- length(t_b)
  X_max <- .diseno_satelite(dx, dz, t_b, p_max, q_max)
  gl <- c(n_obs = n_b, n_par = ncol(X_max))
  if (n_b - ncol(X_max) < PISO_GL) {
    stop(sprintf("%s en %s: %d observaciones y %d parámetros en el mayor candidato dejan %d grados de libertad < %d (F6-15)",
                 satelite_id, ind_a_q(o), n_b, ncol(X_max), n_b - ncol(X_max), PISO_GL))
  }
  if (qr(X_max)$rank < ncol(X_max)) stop(satelite_id, " en ", ind_a_q(o), ": la matriz de regresores pierde rango (F6-15)")
  grilla <- expand.grid(p = 0:p_max, q = 0:q_max)
  grilla <- grilla[order(grilla$p + grilla$q, grilla$p), , drop = FALSE]
  grilla$bic <- vapply(seq_len(nrow(grilla)), function(i) {
    X <- .diseno_satelite(dx, dz, t_b, grilla$p[i], grilla$q[i])
    rss <- sum(stats::lm.fit(X, unname(dx[as.character(t_b)]))$residuals^2)
    n_b * log(rss / n_b) + ncol(X) * log(n_b)
  }, numeric(1))
  rownames(grilla) <- NULL
  p <- grilla$p[which.min(grilla$bic)]; q <- grilla$q[which.min(grilla$bic)]
  # Reestimación del elegido con su muestra máxima.
  t_e <- .filas_satelite(dx, dz, o, p, q)
  X <- .diseno_satelite(dx, dz, t_e, p, q); yv <- unname(dx[as.character(t_e)])
  if (qr(X)$rank < ncol(X)) stop(satelite_id, " en ", ind_a_q(o), ": la matriz de regresores pierde rango (F6-15)")
  f <- stats::lm.fit(X, yv)
  b <- stats::setNames(unname(f$coefficients), colnames(X))
  phi <- if (p > 0L) unname(b[paste0("x_L", seq_len(p))]) else numeric(0)   # paste0("x_L", integer(0)) es "x_L", no vacío
  raiz_min <- if (p > 0L) min(Mod(polyroot(c(1, -phi)))) else Inf
  if (raiz_min <= 1) stop(sprintf("%s en %s: el polinomio en φ tiene una raíz de módulo %.4f <= 1 (F6-15)", satelite_id, ind_a_q(o), raiz_min))
  list(satelite_id = satelite_id, o = o, p = p, q = q, c0 = unname(b["c"]), gamma = unname(b[c("T2", "T3", "T4")]),
       phi = phi, beta = unname(b[paste0("z_L", 0:q)]), grilla = grilla, gl = gl, n_est = length(t_e),
       s2 = sum(f$residuals^2) / (length(t_e) - ncol(X)), raiz_min = raiz_min,
       residuos = stats::setNames(unname(f$residuals), t_e))
}

#' Sendero de Δlog de la predictora en o+1..o+h (F6-15, F6-17-a). `x`: la predictora con todos sus trimestres
#' completos, también los posteriores a `o` (los rezagos observados); `z`: la serie ESC.* del escenario, con historia
#' y sendero hasta al menos o+h. Los trimestres observados de X entran como dato; desde el primero sin dato, la
#' ecuación se itera con Δlog Z del escenario. Devuelve list(dlog (h, nombrado por período), desde = primera fila
#' que sale de la satélite (h + 1 si ninguna), psi = pesos MA ψ_0..ψ_{h−1} del polinomio en φ).
proyectar_satelite <- function(sat, x, z, h = DISENO_FASE6$h_max) {
  h <- as.integer(h); id <- sat$satelite_id
  dx <- .dlog_satelite(x, "la predictora", id); dz <- .dlog_satelite(z, "la variable de escenario", id)
  t_ <- sat$o + seq_len(h); u <- as.integer(utils::tail(names(dx), 1))
  if (u < sat$o) stop(id, ": la predictora no llega al origen ", ind_a_q(sat$o), " (F6-17-a)")
  if (as.integer(utils::tail(names(dz), 1)) < sat$o + h) stop(id, ": el sendero del escenario no llega a ", ind_a_q(sat$o + h))
  libres <- seq.int(u + 1L, length.out = max(0L, sat$o + h - u))
  if (length(libres) && !all(as.character(seq.int(libres[1] - sat$q, sat$o + h)) %in% names(dz))) {
    stop(id, ": a la variable de escenario le faltan trimestres que la ecuación necesita")
  }
  v <- dx
  for (t in libres) {
    val <- sat$c0 + sum(dummies_trimestrales(t) * sat$gamma) +
      (if (sat$p > 0L) sum(sat$phi * unname(v[as.character(t - seq_len(sat$p))])) else 0) +
      sum(sat$beta * unname(dz[as.character(t - 0:sat$q)]))
    v <- c(v, stats::setNames(val, t))
  }
  dl <- unname(v[as.character(t_)])
  if (any(!is.finite(dl))) stop(id, ": el sendero de la satélite no es finito")
  if (anyNA(sat$phi)) stop(id, ": coeficientes φ ausentes en la satélite")
  list(dlog = stats::setNames(dl, ind_a_q(t_)), desde = min(h + 1L, max(1L, u - sat$o + 1L)),
       psi = c(1, if (h > 1L) stats::ARMAtoMA(ar = sat$phi, ma = numeric(0), lag.max = h - 1L) else numeric(0)))
}

#' Arma senderos_x (F6-06-c) para las predictoras `ids` (.Q) con sus satélites ajustadas (`ajustes`, nombrada por
#' predictora) y sus proyecciones (`proyecciones`, ídem, de proyectar_satelite() con el mismo h). Σ_X por F6-15-a:
#' el error de la predictora i en la fila s es Σ_{r=desde_i..s} ψ_i[s−r] e_{i,r}, con Cov(e_{i,r}, e_{j,r'}) =
#' Σ_e[i, j] 1{r = r'} y Σ_e la covarianza muestral de los residuos de esas satélites en sus trimestres comunes. Las
#' filas observadas (antes de `desde`) no tienen error.
senderos_satelites <- function(ajustes, proyecciones, ids) {
  if (!length(ids) || anyDuplicated(ids)) stop("senderos_satelites: ids vacío o repetido")
  faltan <- setdiff(ids, intersect(names(ajustes), names(proyecciones)))
  if (length(faltan)) stop("senderos_satelites: falta la satélite de ", paste(faltan, collapse = ", "))
  h <- unique(vapply(proyecciones[ids], function(p) length(p$dlog), integer(1)))
  if (length(h) != 1L) stop("senderos_satelites: las proyecciones no tienen el mismo h")
  if (length(unique(vapply(ajustes[ids], `[[`, integer(1), "o"))) != 1L) stop("senderos_satelites: las satélites no comparten el origen")
  k <- length(ids)
  D <- matrix(unlist(lapply(proyecciones[ids], `[[`, "dlog")), nrow = h, dimnames = list(names(proyecciones[[ids[1]]]$dlog), ids))
  comunes <- Reduce(intersect, lapply(ajustes[ids], function(a) names(a$residuos)))
  if (length(comunes) < k + 2L) stop("senderos_satelites: pocos trimestres comunes para la covarianza de los residuos (", length(comunes), ")")
  W <- vapply(ajustes[ids], function(a) unname(a$residuos[comunes]), numeric(length(comunes)))
  Se <- stats::cov(matrix(W, ncol = k))
  G <- matrix(0, h * k, h * k)
  for (i in seq_len(k)) {
    pr <- proyecciones[[ids[i]]]
    for (s in seq_len(h)) for (r in seq_len(s)) if (r >= pr$desde) G[(i - 1L) * h + s, (i - 1L) * h + r] <- pr$psi[s - r + 1L]
  }
  V <- G %*% kronecker(Se, diag(h)) %*% t(G)
  dimnames(Se) <- list(ids, ids)
  list(dlog = D, cov = (V + t(V)) / 2, Sigma_e = Se, n_sigma = length(comunes))
}

#' Predictoras externas (.Q, con satélite) de un modelo del registro de Fase 6, en el orden de su `requiere`.
predictoras_externas <- function(m) {
  ids <- sub("\\.M$", ".Q", setdiff(m$requiere, "objetivo"))   # el puente las pide mensuales
  unique(ids[ids %in% names(SATELITES_FASE6)])
}
