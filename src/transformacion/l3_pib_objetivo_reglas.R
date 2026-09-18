# Reglas puras de la transformación L1 -> L3 de la variable objetivo del PIB
# (target_primary y target_robustness en catalogos/05_series_master.csv).
# Separadas del script que toca disco (l3_pib_objetivo.R) para que
# tests/test-l3-pib-objetivo.R las ejerza con datos sintéticos, mismo patrón
# que src/validacion/l2_pib_reglas.R + validar_l2_pib.R.
#
# Implementa:
#   T001_CONCAT_PIB_NSA (catalogos/04_transformaciones.csv) — concatenar_pib_nsa().
#   T002_AJUSTE_ESTACIONAL_PROPIO (catalogos/04_transformaciones.csv) —
#     ajustar_estacional_propio(), conforme a ADR-001 (enmienda 2026-08-07) y
#     ADR-004: X-13ARIMA-SEATS vía `seasonal`, con la detección nativa de
#     outliers (AO/LS/TC) declarada como variables dicotómicas, sin
#     parámetros adicionales fijados por ningún ADR (se usan los defaults de
#     seas(): selección automática de transformación y de modelo ARIMA).
#   construir_pib_oficial() — pass-through de BCR.PIB.VOL.SA.Q, sin
#     transformación (05_series_master.csv, fila PIB.SA.OFICIAL.Q).

#' Concatena la serie retropolada (1990-2004) con la nativa (2005-2026) en una
#' sola serie NSA homogénea, verificando el empalme exacto de ADR-003 antes de
#' descartar los 4 trimestres de superposición de la serie retropolada.
#'
#' tol=0.01, no 0.005: en los 4 trimestres reales de superposición (2005-T1 a
#' 2005-T4), RETRO y nativo difieren hasta 0.0078 (verificado 2026-09-16, ver
#' doc/metodologia/empalme_cuentas_nacionales.md) porque la tabla nativa
#' publica solo 2 decimales mientras RETRO conserva la precisión completa de
#' su cómputo de retropolación — 0.005 (media unidad del último decimal
#' publicado) sería insuficiente incluso cuando ambas series describen el
#' mismo valor subyacente.
concatenar_pib_nsa <- function(l1, tol = 0.01) {
  retro  <- l1[l1$serie_id == "BCR.PIB.VOL.NSA.Q.RETRO", c("periodo", "valor")]
  nativo <- l1[l1$serie_id == "BCR.PIB.VOL.NSA.Q", c("periodo", "valor")]
  retro  <- retro[order(retro$periodo), ]
  nativo <- nativo[order(nativo$periodo), ]

  periodos_solape <- intersect(retro$periodo, nativo$periodo)
  if (length(periodos_solape) != 4) {
    stop("FALLO VISIBLE [T001_CONCAT_PIB_NSA]: se esperaban 4 trimestres de ",
         "superposicion entre RETRO y nativo (ADR-003), se encontraron ",
         length(periodos_solape), ": ", paste(periodos_solape, collapse = ", "))
  }

  retro_pre      <- retro[!(retro$periodo %in% periodos_solape), ]
  retro_overlap  <- retro[retro$periodo %in% periodos_solape, ]
  nativo_overlap <- nativo[nativo$periodo %in% periodos_solape, ]

  m <- merge(retro_overlap, nativo_overlap, by = "periodo", suffixes = c("_retro", "_nativo"))
  diffs <- abs(m$valor_retro - m$valor_nativo)
  if (any(diffs > tol)) {
    stop("FALLO VISIBLE [T001_CONCAT_PIB_NSA]: la superposicion 2005-T1/2005-T4 ",
         "no coincide dentro de tolerancia (ADR-003 exige empalme exacto):\n",
         paste(capture.output(print(m[diffs > tol, ])), collapse = "\n"))
  }

  concat <- rbind(retro_pre, nativo)
  concat <- concat[order(concat$periodo), ]
  rownames(concat) <- NULL

  .verificar_secuencia_trimestral(concat$periodo, "T001_CONCAT_PIB_NSA")
  concat
}

#' Especificación declarada en catalogos/04_transformaciones.csv, fila T002_AJUSTE_ESTACIONAL_PROPIO
#' (columna `parametros`, corrida real del 2026-09-16): 2 outliers AO, en 2020-Q2 y 2020-Q3.
OUTLIERS_T002_DECLARADOS <- data.frame(
  periodo = c("2020-Q2", "2020-Q3"),
  tipo = c("AO", "AO"),
  stringsAsFactors = FALSE
)

#' Ajuste estacional propio (X-13ARIMA-SEATS vía `seasonal`) sobre la serie
#' concatenada, con declaracion de las fechas de outlier detectadas (ADR-004).
#'
#' Falla de forma visible si los outliers que `seas()` detecta en esta corrida no coinciden con
#' los declarados en 04_transformaciones.csv (remediación del hallazgo M2 de la revisión
#' independiente 2026-09-17: `seas()` usa selección automática sin parámetros fijados por ningún
#' ADR, así que un vintage nuevo puede mover la especificación seleccionada -- y con ella toda la
#' historia de la variable objetivo -- sin que nada avise; la celda `parametros` quedaría
#' afirmando algo falso). No congela la especificación con `seasonal::static()`: eso requiere
#' decidir dónde versionar el artefacto congelado por vintage, una decisión de diseño que esta
#' sesión no resuelve (ver nota en la revisión) -- este es el mínimo de "regla 7: la validación
#' falla, no advierte" aplicado al caso ya cubierto por el propio catálogo.
ajustar_estacional_propio <- function(concat, outliers_esperados = OUTLIERS_T002_DECLARADOS) {
  anio_inicio <- as.integer(substr(concat$periodo[1], 1, 4))
  trim_inicio <- as.integer(substr(concat$periodo[1], 7, 7))
  x <- ts(concat$valor, start = c(anio_inicio, trim_inicio), frequency = 4)

  modelo <- seasonal::seas(x)
  sa <- as.numeric(seasonal::final(modelo))

  if (length(sa) != nrow(concat) || anyNA(sa)) {
    stop("FALLO VISIBLE [T002_AJUSTE_ESTACIONAL_PROPIO]: el ajuste estacional ",
         "produjo NA o una longitud distinta de la serie de entrada.")
  }

  tipo_outlier <- as.character(seasonal::outlier(modelo))
  outliers <- data.frame(
    periodo = concat$periodo,
    tipo = tipo_outlier,
    stringsAsFactors = FALSE
  )
  outliers <- outliers[!is.na(outliers$tipo), ]
  rownames(outliers) <- NULL

  if (!is.null(outliers_esperados)) {
    obs <- outliers[order(outliers$periodo), ]
    esp <- outliers_esperados[order(outliers_esperados$periodo), ]
    rownames(obs) <- NULL
    rownames(esp) <- NULL
    if (!identical(obs, esp)) {
      stop("FALLO VISIBLE [T002_AJUSTE_ESTACIONAL_PROPIO]: los outliers detectados por seas() ",
           "en esta corrida no coinciden con los declarados en 04_transformaciones.csv. ",
           "Declarados: ", paste(sprintf("%s(%s)", esp$periodo, esp$tipo), collapse = ", "),
           ". Detectados: ", if (nrow(obs) == 0) "ninguno" else
             paste(sprintf("%s(%s)", obs$periodo, obs$tipo), collapse = ", "),
           ". Un vintage nuevo movió la especificación estacional -- actualiza ",
           "OUTLIERS_T002_DECLARADOS y la fila T002 de 04_transformaciones.csv a la vez, no solo el código.")
    }
  }

  list(
    sa = data.frame(periodo = concat$periodo, valor = sa, stringsAsFactors = FALSE),
    outliers = outliers,
    modelo = modelo
  )
}

#' Pass-through de la serie oficial SA del BCR (target_robustness), sin
#' transformacion — 05_series_master.csv, fila PIB.SA.OFICIAL.Q.
construir_pib_oficial <- function(l1) {
  oficial <- l1[l1$serie_id == "BCR.PIB.VOL.SA.Q", c("periodo", "valor")]
  oficial <- oficial[order(oficial$periodo), ]
  rownames(oficial) <- NULL
  .verificar_secuencia_trimestral(oficial$periodo, "PIB.SA.OFICIAL.Q")
  oficial
}

#' Verifica que `periodos` sea una secuencia trimestral consecutiva sin huecos
#' ni duplicados, de su primer a su ultimo valor observado.
.verificar_secuencia_trimestral <- function(periodos, etiqueta) {
  anio_ini <- as.integer(substr(periodos[1], 1, 4))
  trim_ini <- as.integer(substr(periodos[1], 7, 7))
  anio_fin <- as.integer(substr(periodos[length(periodos)], 1, 4))

  anios <- rep(anio_ini:anio_fin, each = 4)
  trims <- rep(1:4, times = length(anio_ini:anio_fin))
  esperado <- sprintf("%d-Q%d", anios, trims)
  offset <- trim_ini - 1L
  esperado <- esperado[(offset + 1L):(offset + length(periodos))]

  if (!identical(periodos, esperado)) {
    stop("FALLO VISIBLE [", etiqueta, "]: huecos, duplicados o desorden en la ",
         "secuencia trimestral esperada entre ", periodos[1], " y ",
         periodos[length(periodos)], ".")
  }
}
