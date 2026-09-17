# Reglas puras del analisis exploratorio de Fase 3 (senda §4: "analisis exploratorio y de
# estacionariedad"), separadas del script que toca disco (exploracion_series.R) para que
# tests/test-exploracion-series.R las ejerza con datos sinteticos -- mismo patron que
# src/transformacion/l3_predictores_reglas.R.
#
# Alcance deliberadamente acotado a estadistica DESCRIPTIVA (cobertura, huecos, momentos
# muestrales). NO incluye pruebas formales de raiz unitaria/estacionariedad (ADF, KPSS, PP):
# ningun ADR fija que prueba usar, que especificacion de tendencia/intercepto, ni el criterio de
# rezagos -- es una eleccion de hiperparametros no cubierta (regla 4 de CLAUDE.md), pendiente de
# `AskUserQuestion` antes de implementarse. Este archivo cubre solo la mitad "analisis
# exploratorio" de esa actividad de la senda, no la mitad "estacionariedad".

#' Secuencia completa de periodos entre `inicio` y `fin` (ambos "YYYY-Mnn" o "YYYY-Qn", misma
#' freq), sin huecos, para comparar contra los periodos observados y contar huecos reales.
.secuencia_periodos <- function(inicio, fin, freq) {
  if (freq == "M") {
    a0 <- as.integer(substr(inicio, 1, 4)); m0 <- as.integer(substr(inicio, 7, 8))
    a1 <- as.integer(substr(fin, 1, 4));    m1 <- as.integer(substr(fin, 7, 8))
    n0 <- a0 * 12 + (m0 - 1); n1 <- a1 * 12 + (m1 - 1)
    idx <- n0:n1
    sprintf("%d-M%02d", idx %/% 12, idx %% 12 + 1)
  } else if (freq == "Q") {
    a0 <- as.integer(substr(inicio, 1, 4)); q0 <- as.integer(substr(inicio, 7, 7))
    a1 <- as.integer(substr(fin, 1, 4));    q1 <- as.integer(substr(fin, 7, 7))
    n0 <- a0 * 4 + (q0 - 1); n1 <- a1 * 4 + (q1 - 1)
    idx <- n0:n1
    sprintf("%d-Q%d", idx %/% 4, idx %% 4 + 1)
  } else {
    stop("freq debe ser 'M' o 'Q', recibido: ", freq)
  }
}

#' Resumen descriptivo de una serie L3 (columnas periodo/valor): cobertura, huecos internos
#' (periodos ausentes entre el primero y el ultimo observado -- NO cuenta como hueco el hecho de
#' que la serie empiece tarde o termine temprano, eso es cobertura, no un hueco) y momentos
#' muestrales de nivel y de primera diferencia (esta ultima como insumo descriptivo para una
#' futura discusion de estacionariedad, no como sustituto de una prueba formal).
resumen_serie <- function(df, serie_id, freq) {
  df <- df[order(df$periodo), ]
  esperados <- .secuencia_periodos(df$periodo[1], df$periodo[nrow(df)], freq)
  huecos <- setdiff(esperados, df$periodo)

  d1 <- diff(df$valor)

  data.frame(
    serie_id = serie_id,
    freq = freq,
    n_obs = nrow(df),
    periodo_inicio = df$periodo[1],
    periodo_fin = df$periodo[nrow(df)],
    n_esperado = length(esperados),
    n_hueco = length(huecos),
    huecos = paste(huecos, collapse = "; "),
    media = mean(df$valor, na.rm = TRUE),
    sd = sd(df$valor, na.rm = TRUE),
    min = min(df$valor, na.rm = TRUE),
    max = max(df$valor, na.rm = TRUE),
    media_diff1 = mean(d1, na.rm = TRUE),
    sd_diff1 = sd(d1, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}
