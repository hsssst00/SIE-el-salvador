# src/evaluacion/paridad_bvar.R
#
# Paridad Windows/Linux del BVAR (checklist F1; F5-15; decisiones F1-1 y F1-2 en
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
# scripts/referencia_paridad_bvar.R, y se detiene con stop() si alguno difiere (Regla 7). Si cambia el código o la
# configuración del BVAR, la referencia se regenera en ese mismo PR, con una nota fechada (F1-1).
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

.ruta_paridad_bvar <- function() do.call(here::here, as.list(RUTA_REFERENCIA_PARIDAD_BVAR))

#' Lee la referencia versionada; se detiene si falta o si sus columnas no son las esperadas.
leer_referencia_paridad_bvar <- function(ruta = .ruta_paridad_bvar()) {
  if (!file.exists(ruta)) stop("paridad del BVAR: no existe la referencia ", ruta, " (se genera en Windows con scripts/referencia_paridad_bvar.R)")
  r <- utils::read.csv(ruta, colClasses = "character", na.strings = character(0), stringsAsFactors = FALSE)
  if (!identical(names(r), COLUMNAS_PARIDAD_BVAR)) stop("paridad del BVAR: la referencia debe traer las columnas ", paste(COLUMNAS_PARIDAD_BVAR, collapse = ","))
  r$i <- as.integer(r$i); r$j <- as.integer(r$j)
  r$valor <- suppressWarnings(as.numeric(r$valor))                            # solo para leerla; manda `bytes`
  r
}

#' Escribe la referencia con LF. `valor` va en texto decimal (%.17g) solo para leerla; la comparación usa `bytes`.
escribir_referencia_paridad_bvar <- function(actual, ruta = .ruta_paridad_bvar()) {
  if (!identical(names(actual), COLUMNAS_PARIDAD_BVAR)) stop("paridad del BVAR: columnas inesperadas")
  dir.create(dirname(ruta), showWarnings = FALSE, recursive = TRUE)
  salida <- actual
  salida$valor <- ifelse(is.na(actual$valor), "", sprintf("%.17g", actual$valor))
  con <- file(ruta, open = "wb"); on.exit(close(con))
  utils::write.csv(salida, con, row.names = FALSE, eol = "\n")
  invisible(ruta)
}

#' Compara el ajuste actual con la referencia, valor por valor en sus bytes. Se detiene si las filas no son las
#' mismas (cambió la configuración sin regenerar la referencia). Devuelve el número de valores distintos y, para
#' leer la magnitud, las diferencias máximas: absoluta en la media (log-nivel), relativa en la covarianza y absoluta
#' en la aceptación.
comparar_paridad_bvar <- function(actual, referencia) {
  clave <- function(d) paste(d$grupo, d$origen, d$campo, d$i, d$j, sep = "|")
  if (!identical(clave(actual), clave(referencia))) {
    stop("paridad del BVAR: el ajuste actual y la referencia no tienen las mismas filas (si cambió la configuración ",
         "del BVAR, la referencia se regenera en Windows con scripts/referencia_paridad_bvar.R y una nota fechada, F1-1)")
  }
  num <- actual$campo != CAMPO_ENTRADAS_PARIDAD_BVAR
  ref <- rep(NA_real_, nrow(referencia)); ref[num] <- double_de_hex(referencia$bytes[num])
  dif <- abs(actual$valor - ref)
  maximo <- function(x) if (length(x)) max(x) else 0
  list(n = nrow(actual), n_distintos = sum(actual$bytes != referencia$bytes),
       entradas_iguales = identical(actual$bytes[!num], referencia$bytes[!num]),
       dif_media = maximo(dif[actual$campo == "media"]),
       dif_rel_cov = maximo(dif[actual$campo == "cov"] / abs(ref[actual$campo == "cov"])),
       dif_aceptacion = maximo(dif[actual$campo == "aceptacion"]),
       sha256 = sha256_doubles(actual$valor[num]))
}
