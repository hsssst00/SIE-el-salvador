# Reglas puras del test HEGY (Hylleberg, Engle, Granger y Yoo 1990; extension mensual de
# Beaulieu y Miron 1993) para la nota de ADR-010 sobre componente estacional (D1 del checklist
# de cierre de Fase 3, decision de Harold 2026-09-21: "Reimplementar HEGY en R" en vez de
# aceptar un insumo externo -- ver doc/metodologia/evidencia_estacionalidad_ADR010.md).
#
# CONSTRUCCION VERIFICADA CONTRA EL CODIGO FUENTE PUBLICADO, NO REIMPLEMENTADA DE MEMORIA. La
# transformacion de regresores (hegy_regresores(), abajo) reproduce linea por linea
# uroot::hegy.regressors() (paquete `uroot`, GeoBosh/cran, R/hegy-regressors.R, verificado
# 2026-09-22 leyendo el fuente publicado) -- el HEGY test tiene una convencion de signos para
# el regresor seno que se invierte a partir de la frecuencia armonica j > ceiling(S)/4 (ver
# comentario en hegy_regresores()) que ningun texto general documenta y que es facil de
# transcribir mal; se prefirio verificar contra una implementacion publicada y probada en vez
# de derivarla de la teoria general. NO se agrega `uroot` como dependencia (ADR-009 sigue
# abierta sobre si esa decision entra al stack): esto es una reimplementacion propia que solo
# reutiliza la formula, no el paquete.
#
# QUE DIFIERE DE ESTACIONARIEDAD_REGLAS.R (ADF/KPSS). HEGY prueba raiz unitaria en la
# frecuencia CERO (como ADF) Y en las frecuencias ESTACIONALES simultaneamente, sobre una sola
# regresion de Δ_S x_t (diferencia estacional, no la diferencia simple Δ_1 de ADF) contra S
# regresores rezagados (uno por frecuencia, mas un par coseno/seno por cada armonico). Si NO
# rechaza en una frecuencia estacional, esa frecuencia necesita Δ_S (no solo Δ_1) para volverse
# estacionaria -- la pregunta que dejo abierta el reporte exploratorio de Fase 3 (D1).
#
# VALORES CRITICOS: SIMULADOS, no tabulados (mismo criterio que la evidencia externa que este
# archivo reemplaza): 1-L^S bajo H0 es un paseo aleatorio estacional puro (S paseos aleatorios
# entrelazados, uno por fase), simulado con el mismo n, los mismos rezagos y los mismos
# terminos deterministicos que la regresion aplicada -- mas ajustado que una tabla asintotica
# porque respeta la especificacion exacta de cada serie. Fuente publicada de las
# superficies de respuesta (Beaulieu y Miron 1993) queda como trabajo futuro si esta prueba se
# vuelve permanente en el pipeline (ver limites en la nota de ADR-010).

#' Regresores HEGY para una serie x (objeto `ts`, frecuencia S = 4 o 12).
#'
#' Reproduce uroot::hegy.regressors(): para cada t, construye S regresores a partir de los
#' valores REZAGADOS x[t-1]..x[t-S] (acompanan a Δ_S x_t = x_t - x_{t-S} en la regresion
#' auxiliar, igual que el regresor de nivel rezagado en un ADF):
#'   - Columna 1 ("cero"): suma S(L) = x[t-1] + x[t-2] + ... + x[t-S] -- frecuencia cero.
#'   - Columna 2 (solo S par, "nyq"): suma alternante -x[t-1] + x[t-2] - x[t-3] + ... --
#'     frecuencia de Nyquist (pi).
#'   - Columnas 3..S: (S/2 - 1) pares (coseno, seno) de sumas ponderadas por
#'     cos((k+1)*2*pi*j/S) y sin((k+1)*2*pi*j/S), k=0..S-1, j=1..(S/2-1) -- un par por cada
#'     frecuencia armonica 2*pi*j/S. El signo del regresor seno se invierte a partir del primer
#'     armonico j > ceiling(S)/4: no es un error de signo, es la convencion de HEGY para que
#'     los estadisticos correspondan a la parte real/imaginaria correcta de la raiz compleja en
#'     cada mitad del circulo unitario (verificado contra uroot::hegy.regressors()).
#'
#' Devuelve una matriz de (length(x) - S) filas (las primeras S posiciones no tienen S rezagos
#' completos y se descartan), alineada por posicion con `diff(x, lag = S)`.
hegy_regresores <- function(x) {
  S <- stats::frequency(x)
  n <- length(x)
  x_num <- as.numeric(x)

  if (n <= S) {
    stop("FALLO VISIBLE: hegy_regresores() necesita mas de ", S, " observaciones, recibio ", n)
  }

  # ML[t, k+1] = x[t-k], k = 0..S-1 (NA cuando t-k < 1). Misma construccion que
  # uroot::hegy.regressors() (la variable `ML` de ese archivo, tras su reasignacion via sapply).
  ML <- sapply(0:(S - 1), function(k) c(rep(NA_real_, k), x_num[seq_len(n - k)]))

  ypi <- matrix(NA_real_, nrow = n, ncol = S)
  ypi[, 1] <- rowSums(ML)

  es_par <- (S %% 2) == 0
  if (es_par) {
    ypi[, 2] <- as.numeric(ML %*% rep(c(-1, 1), length.out = S))
  }

  inicio_pares <- 2L + as.integer(es_par)
  id <- seq.int(inicio_pares, S, by = 2)
  seqS <- seq_len(S)
  ref <- ceiling(S) / 4
  sinesign <- -1
  j <- 0L
  for (i in id) {
    j <- j + 1L
    seqw <- seqS * (2 * pi * j / S)
    ypi[, i]     <- as.numeric(ML %*% cos(seqw))
    ypi[, i + 1] <- sinesign * as.numeric(ML %*% sin(seqw))
    if (j == ref) sinesign <- -sinesign
  }

  # Desfase de un periodo mas: la fila t debe usar x[t-1]..x[t-S] (no x[t]..x[t-S+1]), para
  # acompanar a Δ_S x_t en la regresion auxiliar -- mismo shift que hace
  # uroot::hegy.regressors() con `rbind(NA, ypi[-n,])`.
  ypi <- rbind(NA_real_, ypi[-n, , drop = FALSE])
  # Nombres de columna: cero, [nyq], j1_cos, j1_sin, j2_cos, j2_sin, ...
  nombres_armonicos <- character(0)
  for (k in seq_along(id)) nombres_armonicos <- c(nombres_armonicos, paste0("j", k, "_cos"), paste0("j", k, "_sin"))
  colnames(ypi) <- c("cero", if (es_par) "nyq" else NULL, nombres_armonicos)

  ypi[-seq_len(S), , drop = FALSE]
}

#' Ciclo (fase estacional, 1..S) de cada observacion de Δ_S x -- para las dummies
#' deterministicas de la regresion auxiliar. Usa `stats::cycle()` sobre la serie diferenciada
#' (no `posicion %% S`) para que la fase sea la real del calendario, no la de una serie
#' arbitrariamente truncada.
.ciclo_diferencia <- function(x) as.integer(stats::cycle(diff(x, lag = stats::frequency(x))))

#' Techo de busqueda de rezagos para la regresion auxiliar de HEGY, mismo criterio que
#' `techo_rezagos` de estacionariedad_reglas.R pero con un tope mas bajo (S/2, no la regla de
#' Schwert completa): la regresion HEGY ya tiene S regresores de nivel mas S-1 dummies mas
#' constante y tendencia -- (S+S+1) parametros antes de agregar ningun rezago --, asi que un
#' techo generoso agota grados de libertad rapido en las series mas cortas de esta matriz.
.techo_hegy <- function(S) if (identical(S, 12L) || identical(S, 12)) 6L else 4L

#' Diseno de la regresion auxiliar de HEGY sobre la muestra comun que define el techo de
#' rezagos -- mismo patron que .diseno_adf() en estacionariedad_reglas.R: todos los candidatos
#' de la grilla de BIC comparten esta muestra para que sus BIC sean comparables.
.diseno_hegy <- function(x, techo) {
  S <- stats::frequency(x)
  dx_full <- as.numeric(diff(x, lag = S))
  ypi_full <- hegy_regresores(x)
  ciclo_full <- .ciclo_diferencia(x)
  n <- length(dx_full)
  if (techo + 2 > n) {
    stop("FALLO VISIBLE: techo de rezagos ", techo, " incompatible con ", length(x),
         " observaciones (S=", S, ") -- la muestra comun de HEGY quedaria vacia o degenerada.")
  }

  rezagos_disponibles <- if (techo > 0) {
    sapply(seq_len(techo), function(l) dx_full[(techo + 1 - l):(n - l)])
  } else {
    matrix(nrow = n - techo, ncol = 0)
  }

  list(
    dx = dx_full[(techo + 1):n],
    ypi = ypi_full[(techo + 1):n, , drop = FALSE],
    ciclo = ciclo_full[(techo + 1):n],
    S = S,
    rezagos_disponibles = rezagos_disponibles
  )
}

#' Matriz de diseno (X) de la regresion auxiliar de HEGY con `k` rezagos de Δ_S x: columnas de
#' `ypi`, constante, tendencia, S-1 dummies estacionales (referencia = fase 1) y los `k`
#' rezagos. Devuelve X e y por separado para ajustar via `stats::lm.fit()` -- mas rapido que la
#' interfaz de formula, necesario porque la simulacion de criticos ajusta miles de regresiones.
.diseno_matriz_hegy <- function(dis, k) {
  n <- length(dis$dx)
  temporada <- factor(dis$ciclo, levels = seq_len(dis$S))
  SD <- stats::model.matrix(~temporada)[, -1, drop = FALSE]  # S-1 dummies

  X <- cbind(dis$ypi, c = 1, tt = seq_len(n), SD)
  if (k > 0) {
    rez <- dis$rezagos_disponibles[, seq_len(k), drop = FALSE]
    colnames(rez) <- paste0("dxlag", seq_len(k))
    X <- cbind(X, rez)
  }
  list(X = X, y = dis$dx)
}

#' Ajusta por minimos cuadrados (lm.fit) y devuelve lo necesario para BIC, t-stats y el F
#' conjunto: coeficientes, error estandar, RSS y grados de libertad residuales.
.ajustar_hegy <- function(dis, k) {
  d <- .diseno_matriz_hegy(dis, k)
  ajuste <- stats::lm.fit(d$X, d$y)
  residuos <- ajuste$residuals
  n <- length(d$y)
  p <- ajuste$rank
  rss <- sum(residuos^2)
  df_res <- n - p
  sigma2 <- rss / df_res
  # Errores estandar de los coeficientes via la inversa de X'X (QR ya factorizado por lm.fit).
  qr_obj <- ajuste$qr
  R_inv <- backsolve(qr_obj$qr[seq_len(p), seq_len(p), drop = FALSE], diag(p))
  cov_beta <- R_inv %*% t(R_inv) * sigma2
  se <- sqrt(diag(cov_beta))
  coef <- ajuste$coefficients[!is.na(ajuste$coefficients)]
  names(se) <- names(coef)
  list(coef = coef, se = se, rss = rss, df_res = df_res, n = n, p = p, X = d$X, y = d$y)
}

#' Seleccion de rezagos por BIC sobre la grilla 0..techo -- mismo patron que
#' .seleccion_bic_adf() en estacionariedad_reglas.R.
.seleccion_bic_hegy <- function(dis, techo) {
  ajustes <- lapply(0:techo, function(k) .ajustar_hegy(dis, k))
  bic <- vapply(ajustes, function(a) a$n * log(a$rss / a$n) + a$p * log(a$n), numeric(1))
  elegido <- which.min(bic)
  list(rezagos = elegido - 1L, ajuste = ajustes[[elegido]])
}

#' F conjunto de TODAS las frecuencias estacionales (columnas de `ypi` distintas de "cero"):
#' compara el RSS del modelo completo contra el de un modelo restringido que omite esas
#' columnas (deja solo "cero" + deterministicos + rezagos). Rechazar (F grande) es evidencia
#' EN CONTRA de raiz unitaria estacional conjunta.
.f_estacional <- function(dis, k, ajuste_completo) {
  d <- .diseno_matriz_hegy(dis, k)
  cols_estacionales <- setdiff(colnames(dis$ypi), "cero")
  X_restringido <- d$X[, !(colnames(d$X) %in% cols_estacionales), drop = FALSE]
  ajuste_r <- stats::lm.fit(X_restringido, d$y)
  rss_r <- sum(ajuste_r$residuals^2)
  rss_c <- ajuste_completo$rss
  q <- length(cols_estacionales)
  df_c <- ajuste_completo$df_res
  f_val <- ((rss_r - rss_c) / q) / (rss_c / df_c)
  list(F = f_val, gl_num = q, gl_den = df_c)
}

#' Paseo aleatorio estacional puro bajo H0 de HEGY: (1-L^S) x_t = e_t, e_t ~ N(0,1) iid -- S
#' paseos aleatorios entrelazados, uno por fase (fase = (t-1) %% S + 1), cada uno una caminata
#' aleatoria independiente de las demas. Vectorizado por fase (una matriz de S columnas, cumsum
#' por columna) en vez de un bucle sobre `n_total`: mas rapido para miles de replicas.
simular_paseo_estacional <- function(n_total, S) {
  n_por_fase <- ceiling(n_total / S)
  choques <- matrix(stats::rnorm(n_por_fase * S), nrow = n_por_fase, ncol = S)
  caminatas <- apply(choques, 2, cumsum)
  x <- numeric(n_total)
  for (fase in seq_len(S)) {
    idx <- seq(fase, n_total, by = S)
    x[idx] <- caminatas[seq_along(idx), fase]
  }
  stats::ts(x, frequency = S)
}

#' Valores criticos simulados de t_cero, t_nyq (si S par) y F_estacional, bajo H0 (paseo
#' aleatorio estacional), con el mismo n, los mismos rezagos (`k` fijo, no re-seleccionado por
#' replica) y los mismos terminos deterministicos que la regresion aplicada a los datos reales
#' -- mismo criterio que la evidencia externa que este archivo reemplaza (D1). `semilla`
#' distinta por combinacion (S, n, k) para que cada fila sea reproducible sin acoplar la
#' semilla global entre series.
simular_criticos_hegy <- function(n_x, S, k, replicas = 5000L, nivel = 0.05,
                                   semilla = NULL) {
  if (is.null(semilla)) semilla <- as.integer(n_x * 1000 + S * 10 + k)
  set.seed(semilla)
  techo <- .techo_hegy(S)

  t_cero <- numeric(replicas)
  t_nyq <- if (S %% 2 == 0) numeric(replicas) else NULL
  f_est <- numeric(replicas)

  for (r in seq_len(replicas)) {
    x0 <- simular_paseo_estacional(n_x, S)
    dis0 <- .diseno_hegy(x0, techo)
    a0 <- .ajustar_hegy(dis0, k)
    t_cero[r] <- a0$coef["cero"] / a0$se["cero"]
    if (!is.null(t_nyq)) t_nyq[r] <- a0$coef["nyq"] / a0$se["nyq"]
    f_est[r] <- .f_estacional(dis0, k, a0)$F
  }

  list(
    cv_t_cero = unname(stats::quantile(t_cero, probs = nivel, na.rm = TRUE)),
    cv_t_nyq = if (!is.null(t_nyq)) unname(stats::quantile(t_nyq, probs = nivel, na.rm = TRUE)) else NA_real_,
    cv_F = unname(stats::quantile(f_est, probs = 1 - nivel, na.rm = TRUE)),
    replicas = replicas
  )
}

#' Corre HEGY completo sobre una serie de nivel (en logaritmo si se pasa ya transformada) y
#' devuelve una fila de resultados: estadisticos en frecuencia cero y Nyquist, F estacional
#' conjunto, sus criticos simulados, rezagos elegidos y tamaño de muestra efectivo.
analizar_hegy_serie <- function(valor, serie_id, frecuencia, replicas = 5000L) {
  S <- switch(frecuencia, "M" = 12L, "Q" = 4L,
              stop("FALLO VISIBLE: frecuencia desconocida: ", frecuencia, " (se esperaba \"M\" o \"Q\")"))
  x <- stats::ts(valor, frequency = S)
  techo <- .techo_hegy(S)

  dis <- .diseno_hegy(x, techo)
  sel <- .seleccion_bic_hegy(dis, techo)
  ajuste <- sel$ajuste
  fest <- .f_estacional(dis, sel$rezagos, ajuste)

  t_cero <- unname(ajuste$coef["cero"] / ajuste$se["cero"])
  t_nyq <- if ("nyq" %in% names(ajuste$coef)) unname(ajuste$coef["nyq"] / ajuste$se["nyq"]) else NA_real_

  crit <- simular_criticos_hegy(n_x = length(x), S = S, k = sel$rezagos, replicas = replicas,
                                 semilla = as.integer(length(x) * 1000 + S * 10 + sel$rezagos))

  data.frame(
    serie_id = serie_id, s = S, n = ajuste$n, rezagos = sel$rezagos,
    t_cero = t_cero, cv_t_cero = crit$cv_t_cero,
    rechaza_cero = t_cero < crit$cv_t_cero,
    t_nyq = t_nyq, cv_t_nyq = crit$cv_t_nyq,
    rechaza_nyq = if (is.na(t_nyq)) NA else t_nyq < crit$cv_t_nyq,
    f_estacional = fest$F, cv_f_estacional = crit$cv_F,
    gl_num = fest$gl_num, gl_den = fest$gl_den,
    rechaza_estacional_conjunta = fest$F > crit$cv_F,
    replicas = replicas,
    stringsAsFactors = FALSE
  )
}
