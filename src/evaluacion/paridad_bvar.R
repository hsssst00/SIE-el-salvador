# src/evaluacion/paridad_bvar.R
#
# Paridad Windows/Linux del BVAR (checklist F1; F5-15; decisiones F1-1, F1-2 y F1-3 reabierta en
# doc/metodologia/decisiones_fase5.md). Un ajuste fijo del BVAR con la configuración de producción (p = 4,
# 10 000 extracciones y 5 000 de quemado; B2-7) en el primer origen de G1 (3 series) y de G3 (9 series), sobre
# datos sintéticos con las fechas de inicio de L3: el mismo generador y las mismas semillas (141 y 142) que la
# prueba de producción de tests/test-modelo-bvar.R. La siembra es la del motor (semilla_de(), como en
# correr_backtest()) con exp_id = "V17".
#
# Se registran los bytes (IEEE 754 de 8 bytes, little-endian, en hexadecimal) de la media y la covarianza de la
# predictiva posterior en h = 1..8 (B2-10) y de los diagnósticos del ajuste (aceptación del MH, medias posteriores
# de lambda, SOC y SUR, ψ del PIB y tamaños), más el sha256 de los datos de entrada, que separa una diferencia de
# los datos de una del BVAR. Los bytes y no el texto decimal: el texto depende de la rutina de impresión de cada
# sistema.
#
# V17 (verificar_motor_sintetico.R) compara esos bytes con la referencia versionada en
# src/evaluacion/referencias/paridad_bvar.csv, generada en Windows (la máquina de la corrida única) con
# scripts/referencia_paridad_bvar.R. En Windows exige que sean idénticos y se detiene con stop() si no (F5-15, Regla 7).
# En otro sistema solo informa (F1-3, reabierta): con OpenBLAS, un redondeo distinto puede cambiar decisiones del MH y
# las cadenas se separan hasta la escala del error de Monte Carlo. Por eso la referencia trae también el MCSE de cada
# momento y de las medias de los hiperparámetros, y V17 informa las diferencias en esas unidades. Si cambia el código
# o la configuración del BVAR, la referencia se regenera en ese mismo PR, con una nota fechada (F1-1).
#
# Requiere eval_lib.R y modelos_multivariados.R cargados.

INICIOS_PARIDAD_BVAR <- c("BCR.REMESAS.NOM.NSA.Q" = "1991-Q1", "BCR.EXPORT_FOB.NOM.NSA.Q" = "1994-Q1",
                          "BCR.ITCER.IDX.NSA.Q" = "2000-Q1", "UT.DEMANDA_ELEC.GWH.NSA.Q" = "2002-Q1",
                          "BCR.IVAE.VOL.SA.Q" = "2005-Q1", "BCR.IPM.IDX.NSA.Q" = "2005-Q1",
                          "BCR.IPP.IDX.NSA.Q" = "2010-Q1", "BCR.REMESAS.REAL.NSA.Q" = "2010-Q1")
GRUPOS_PARIDAD_BVAR <- c("G1", "G3")                                          # F1-2
EXP_PARIDAD_BVAR <- "V17"
RUTA_REFERENCIA_PARIDAD_BVAR <- c("src", "evaluacion", "referencias", "paridad_bvar.csv")
COLUMNAS_PARIDAD_BVAR <- c("grupo", "origen", "campo", "i", "j", "bytes", "valor")
CAMPO_ENTRADAS_PARIDAD_BVAR <- "sha256_entradas"
COLUMNAS_REFERENCIA_PARIDAD_BVAR <- c(COLUMNAS_PARIDAD_BVAR, "mcse")
LOTES_MCSE_PARIDAD_BVAR <- 50L      # medias por lotes: 50 lotes de 100 de las 5 000 extracciones retenidas
CAMPOS_MCSE_PARIDAD_BVAR <- c("media", "cov", "lambda", "soc", "sur")

#' Datos sintéticos de la prueba de producción del BVAR (tests/test-modelo-bvar.R, semillas 141 y 142): el objetivo
#' en log-nivel de 1990-Q1 a 2026-Q1 y las 8 predictoras trimestrales desde su inicio en L3 hasta 2026-Q2, con
#' estacional determinista en las NSA.
datos_paridad_bvar <- function() {
  set.seed(141L)
  per <- ind_a_q(q_a_ind("1990-Q1") + 0:144)
  obj <- data.frame(periodo = per, y = 4 + cumsum(0.005 + as.numeric(stats::arima.sim(list(ar = 0.3), length(per), sd = 0.01))),
                    stringsAsFactors = FALSE)
  set.seed(142L)
  pred <- stats::setNames(lapply(names(INICIOS_PARIDAD_BVAR), function(id) {
    i <- q_a_ind(INICIOS_PARIDAD_BVAR[[id]]):q_a_ind("2026-Q2")
    est <- if (grepl(".NSA.", id, fixed = TRUE)) 0.03 * sin(pi * (i %% 4L) / 2) else 0
    data.frame(periodo = ind_a_q(i), valor = 100 * exp(cumsum(0.004 + stats::rnorm(length(i), 0, 0.02)) + est),
               stringsAsFactors = FALSE)
  }), names(INICIOS_PARIDAD_BVAR))
  c(list(objetivo = obj), pred)
}

#' Bytes de cada valor double (IEEE 754, little-endian) como 16 caracteres hexadecimales.
bytes_hex <- function(x) {
  x <- as.double(x)
  b <- as.character(writeBin(x, raw(), size = 8L, endian = "little"))
  vapply(seq_along(x), function(k) paste(b[(8L * k - 7L):(8L * k)], collapse = ""), character(1))
}

#' Inversa de bytes_hex(): el double exacto de cada cadena de 16 caracteres hexadecimales.
double_de_hex <- function(h) {
  if (!is.character(h) || any(!grepl("^[0-9a-f]{16}$", h))) stop("double_de_hex: se esperan cadenas de 16 caracteres hexadecimales")
  vapply(h, function(s) readBin(as.raw(strtoi(substring(s, seq(1L, 15L, 2L), seq(2L, 16L, 2L)), 16L)), "double", n = 1L,
                                size = 8L, endian = "little"), numeric(1), USE.NAMES = FALSE)
}

#' sha256 de los bytes de un vector double.
sha256_doubles <- function(x) digest::digest(writeBin(as.double(x), raw(), size = 8L, endian = "little"), algo = "sha256", serialize = FALSE)

#' Ajusta el BVAR fijo de F1-2 y devuelve un data.frame con las columnas COLUMNAS_PARIDAD_BVAR: una fila con el
#' sha256 de las entradas y, por grupo, la media (i = h), la covarianza (i, j; por columnas) y los diagnósticos.
#' `valor` es el double (NA en la fila de las entradas); `bytes`, sus bytes en hexadecimal.
momentos_paridad_bvar <- function(series = datos_paridad_bvar(), grupos = GRUPOS_PARIDAD_BVAR) {
  entradas <- unlist(lapply(series, function(s) if ("y" %in% names(s)) s$y else s$valor), use.names = FALSE)
  filas <- list(data.frame(grupo = "-", origen = "-", campo = CAMPO_ENTRADAS_PARIDAD_BVAR, i = 0L, j = 0L,
                           bytes = sha256_doubles(entradas), valor = NA_real_, stringsAsFactors = FALSE))
  for (g in grupos) {
    m <- modelo_bvar_grupo(g); o <- origenes_grupo(g)[1]
    rz <- rezagos_predictoras(setdiff(m$requiere, "objetivo"))
    info <- stats::setNames(lapply(m$requiere, function(nm) recortar_a_origen(series[[nm]], o, rz[[nm]])), m$requiere)
    set.seed(semilla_de(EXP_PARIDAD_BVAR, m$modelo_id, o))                    # la siembra de correr_backtest()
    aj <- m$ajustar(info, NULL)
    d <- m$predecir_densidad(aj, DISENO_FASE4$h_max)
    H <- length(d$media)
    if (H != DISENO_FASE4$h_max || !identical(dim(d$cov), c(H, H))) stop("paridad del BVAR: momentos mal dimensionados en ", g)
    filas[[length(filas) + 1L]] <- data.frame(
      grupo = g, origen = ind_a_q(o),
      campo = c(rep("media", H), rep("cov", H * H), names(aj$diag)),
      i = c(seq_len(H), rep(seq_len(H), H), rep(0L, length(aj$diag))),
      j = c(rep(0L, H), rep(seq_len(H), each = H), rep(0L, length(aj$diag))),
      bytes = NA_character_, valor = c(d$media, as.vector(d$cov), unname(aj$diag)), stringsAsFactors = FALSE)
  }
  r <- do.call(rbind, filas)
  num <- r$campo != CAMPO_ENTRADAS_PARIDAD_BVAR
  r$bytes[num] <- bytes_hex(r$valor[num])
  rownames(r) <- NULL
  r[, COLUMNAS_PARIDAD_BVAR]
}

#' Error de Monte Carlo por medias por lotes de una serie de extracciones (lotes contiguos de igual tamaño).
mcse_lotes <- function(x, lotes = LOTES_MCSE_PARIDAD_BVAR) {
  if (length(x) %% lotes != 0L) stop("mcse_lotes: ", length(x), " extracciones no se dividen en ", lotes, " lotes")
  stats::sd(colMeans(matrix(x, ncol = lotes))) / sqrt(lotes)
}

#' MCSE de cada valor de momentos_paridad_bvar() (NA en las entradas, los tamaños, la aceptación y ψ, que no son
#' promedios de extracciones). Repite el ajuste de ajustar_bvar() con la misma siembra para tener las extracciones, y
#' se detiene si la media o la covarianza no son idénticas a las de `actual`, es decir, si la réplica dejó de ser el
#' ajuste de producción. Media: MCSE absoluto; covarianza: MCSE de cada elemento como media de su contribución por
#' extracción (C_j + desvíos de μ_j); hiperparámetros: MCSE de su media posterior. Solo se usa al regenerar la
#' referencia (Windows); el costo es el de otro ajuste por grupo.
mcse_paridad_bvar <- function(actual, series = datos_paridad_bvar()) {
  mcse <- rep(NA_real_, nrow(actual))
  for (g in setdiff(unique(actual$grupo), "-")) {
    m <- modelo_bvar_grupo(g); pr <- setdiff(m$requiere, "objetivo"); o <- origenes_grupo(g)[1]
    rz <- rezagos_predictoras(pr)
    info <- stats::setNames(lapply(m$requiere, function(nm) recortar_a_origen(series[[nm]], o, rz[[nm]])), m$requiere)
    set.seed(semilla_de(EXP_PARIDAD_BVAR, m$modelo_id, o))
    pn <- panel_bvar(info, pr, m$modelo_id); Y <- pn$Y; lags <- m$lags; H <- DISENO_FASE4$h_max
    psi <- psi_bvar(Y, lags, m$modelo_id, pn$o)
    fit <- BVAR::bvar(Y, lags = lags, n_draw = m$n_draw, n_burn = m$n_burn, n_thin = 1L, priors = priors_bvar(psi),
                      mh = mh_bvar(), fcast = NULL, irf = NULL, verbose = FALSE)
    mom <- momentos_predictiva_bvar(fit$beta, fit$sigma, Y, lags, H)
    fila <- actual$grupo == g
    if (!identical(bytes_hex(c(mom$media, as.vector(mom$cov))), actual$bytes[fila & actual$campo %in% c("media", "cov")])) {
      stop("mcse_paridad_bvar: la réplica del ajuste de ", g, " no reproduce los momentos de ajustar_bvar()")
    }
    # Por extracción, como en momentos_predictiva_bvar(): μ_j por recursión y C_j con los pesos MA.
    beta <- fit$beta; sigma <- fit$sigma; S <- dim(beta)[1]; M <- dim(beta)[3]; N <- nrow(Y)
    idx <- function(l, k) 1L + (l - 1L) * M + k
    estado <- matrix(rep(as.vector(t(Y[N:(N - lags + 1L), , drop = FALSE])), each = S), nrow = S)
    mu <- matrix(NA_real_, S, H)
    for (h in seq_len(H)) {
      yn <- matrix(vapply(seq_len(M), function(i) beta[, 1L, i] + rowSums(beta[, -1L, i, drop = FALSE][, , 1L] * estado), numeric(S)), nrow = S)
      mu[, h] <- yn[, 1L]
      estado <- if (lags > 1L) cbind(yn, estado[, seq_len(M * (lags - 1L)), drop = FALSE]) else yn
    }
    r <- vector("list", H); r[[1L]] <- matrix(rep(c(1, numeric(M - 1L)), each = S), nrow = S)
    if (H > 1L) for (k0 in 1:(H - 1L)) {
      rm_ <- matrix(0, S, M)
      for (l in seq_len(min(lags, k0))) for (k in seq_len(M)) rm_[, k] <- rm_[, k] + rowSums(r[[k0 - l + 1L]] * beta[, idx(l, k), , drop = FALSE][, 1L, ])
      r[[k0 + 1L]] <- rm_
    }
    rS <- lapply(r, function(rr) matrix(vapply(seq_len(M), function(k) rowSums(rr * sigma[, , k]), numeric(S)), nrow = S))
    q <- function(a, b) rowSums(rS[[a]] * r[[b]])                             # q_j[a, b], S valores
    dmu <- sweep(mu, 2L, colMeans(mu))
    mc_cov <- matrix(NA_real_, H, H)
    for (a in seq_len(H)) for (b in seq_len(a)) {
      x <- Reduce(`+`, lapply(seq_len(b), function(k) q(a - k + 1L, b - k + 1L))) + dmu[, a] * dmu[, b]
      mc_cov[a, b] <- mc_cov[b, a] <- mcse_lotes(x)
    }
    hyp <- vapply(c("lambda", "soc", "sur"), function(nm) mcse_lotes(fit$hyper[, nm]), numeric(1))
    mcse[fila & actual$campo == "media"] <- apply(mu, 2L, mcse_lotes)
    mcse[fila & actual$campo == "cov"] <- as.vector(mc_cov)
    for (nm in names(hyp)) mcse[fila & actual$campo == nm] <- hyp[[nm]]
  }
  mcse
}

.ruta_paridad_bvar <- function() do.call(here::here, as.list(RUTA_REFERENCIA_PARIDAD_BVAR))

#' Lee la referencia versionada; se detiene si falta o si sus columnas no son las esperadas.
leer_referencia_paridad_bvar <- function(ruta = .ruta_paridad_bvar()) {
  if (!file.exists(ruta)) stop("paridad del BVAR: no existe la referencia ", ruta, " (se genera en Windows con scripts/referencia_paridad_bvar.R)")
  r <- utils::read.csv(ruta, colClasses = "character", na.strings = character(0), stringsAsFactors = FALSE)
  if (!identical(names(r), COLUMNAS_REFERENCIA_PARIDAD_BVAR)) {
    stop("paridad del BVAR: la referencia debe traer las columnas ", paste(COLUMNAS_REFERENCIA_PARIDAD_BVAR, collapse = ","))
  }
  r$i <- as.integer(r$i); r$j <- as.integer(r$j)
  r$valor <- suppressWarnings(as.numeric(r$valor))                            # solo para leerla; manda `bytes`
  r$mcse <- suppressWarnings(as.numeric(r$mcse))
  r
}

#' Escribe la referencia con LF. `valor` (%.17g) es solo para leerla; la comparación usa `bytes`. `mcse` (%.6g) es la
#' escala con la que V17 informa las diferencias fuera de Windows.
escribir_referencia_paridad_bvar <- function(actual, mcse, ruta = .ruta_paridad_bvar()) {
  if (!identical(names(actual), COLUMNAS_PARIDAD_BVAR)) stop("paridad del BVAR: columnas inesperadas")
  if (length(mcse) != nrow(actual)) stop("paridad del BVAR: `mcse` debe tener una entrada por fila")
  dir.create(dirname(ruta), showWarnings = FALSE, recursive = TRUE)
  salida <- actual
  salida$valor <- ifelse(is.na(actual$valor), "", sprintf("%.17g", actual$valor))
  salida$mcse <- ifelse(is.na(mcse), "", sprintf("%.6g", mcse))
  con <- file(ruta, open = "wb"); on.exit(close(con))
  utils::write.csv(salida, con, row.names = FALSE, eol = "\n")
  invisible(ruta)
}

#' Compara el ajuste actual con la referencia, valor por valor en sus bytes. Se detiene si las filas no son las
#' mismas (cambió la configuración sin regenerar la referencia). Devuelve: el número de valores distintos; si las
#' entradas son idénticas; los máximos por campo (`maximos`: |dif| en la media, en log-nivel, y diferencia relativa en
#' los demás); los máximos de |dif| / MCSE por campo (`en_mcse`); el número de decisiones del MH distintas por grupo
#' (|Δ aceptación| · extracciones retenidas); las diferencias máximas de la media, la covarianza y la aceptación, y el
#' sha256 de los momentos actuales.
comparar_paridad_bvar <- function(actual, referencia) {
  clave <- function(d) paste(d$grupo, d$origen, d$campo, d$i, d$j, sep = "|")
  if (!identical(clave(actual), clave(referencia))) {
    stop("paridad del BVAR: el ajuste actual y la referencia no tienen las mismas filas (si cambió la configuración ",
         "del BVAR, la referencia se regenera en Windows con scripts/referencia_paridad_bvar.R y una nota fechada, F1-1)")
  }
  num <- actual$campo != CAMPO_ENTRADAS_PARIDAD_BVAR
  ref <- rep(NA_real_, nrow(referencia)); ref[num] <- double_de_hex(referencia$bytes[num])
  dif <- abs(actual$valor - ref)
  rel <- ifelse(dif == 0, 0, dif / abs(ref))                                  # Inf si la referencia es 0 y el valor no
  maximo <- function(x) if (length(x)) max(x) else 0
  medida <- ifelse(actual$campo == "media", dif, rel)
  campos <- setdiff(unique(actual$campo[num]), c("n_obs", "n_series", "aceptacion"))
  con_mcse <- intersect(CAMPOS_MCSE_PARIDAD_BVAR, unique(actual$campo))
  S <- N_DRAW_BVAR - N_BURN_BVAR
  ac <- actual$campo == "aceptacion"
  list(n = nrow(actual), n_distintos = sum(actual$bytes != referencia$bytes),
       entradas_iguales = identical(actual$bytes[!num], referencia$bytes[!num]),
       maximos = vapply(campos, function(cp) maximo(medida[actual$campo == cp]), numeric(1)),
       en_mcse = vapply(con_mcse, function(cp) maximo((dif / referencia$mcse)[actual$campo == cp & dif > 0]), numeric(1)),
       decisiones_distintas = stats::setNames(as.integer(round(dif[ac] * S)), actual$grupo[ac]),
       dif_media = maximo(dif[actual$campo == "media"]), dif_rel_cov = maximo(rel[actual$campo == "cov"]),
       dif_aceptacion = maximo(dif[ac]), sha256 = sha256_doubles(actual$valor[num]))
}
