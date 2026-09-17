# Reglas puras de la mitad "estacionariedad" del análisis exploratorio de Fase 3 (senda §4),
# separadas del script que toca disco (estacionariedad.R) para que tests/test-estacionariedad.R
# las ejerza con datos sintéticos -- mismo patrón que el resto de Fase 3.
#
# Decisiones fijadas por Harold vía `AskUserQuestion` (2026-09-17, ver doc/checklist_fase3.md):
#   - Estrategia: ADF + KPSS confirmatorio (se declara estacionaria una transformación solo si
#     ADF rechaza raíz unitaria Y KPSS no rechaza estacionariedad; si ambos coinciden en sentido
#     contrario, no_estacionaria; si discrepan, ambigua -- tabla de interpretación estándar,
#     Kwiatkowski et al. 1992).
#   - Selección de rezagos: BIC/SIC para ADF.
#   - Alcance: nivel, log-nivel, primera diferencia y diferencia del log, por serie.
#
# Paquete: `urca` (ADR-009, nota de seguimiento "pruebas formales de estacionariedad",
# 2026-09-17) -- es la única de las dos opciones consideradas (`urca` vs `tseries`) que soporta
# selección de rezagos por BIC en ur.df(). `ur.kpss()` no tiene un análogo exacto de BIC (no es
# una regresión con rezagos seleccionables, sino un estimador de varianza de largo plazo con un
# parámetro de truncamiento): se usa `lags = "short"` (regla de Schwert) como la opción más
# parsimoniosa disponible -- aproximación declarada, no una correspondencia exacta a BIC.
#
# Especificación determinística por transformación (fijada acá, no preguntada -- ver nota en
# doc/checklist_fase3.md): nivel y log-nivel llevan tendencia determinística esperada (índices y
# magnitudes económicas de este proyecto crecen en el tiempo) -> ADF type="trend" (tau3),
# KPSS type="tau" (estacionariedad alrededor de una tendencia). Diferencia y diferencia del log
# no deberían llevar tendencia determinística remanente -> ADF type="drift" (tau2),
# KPSS type="mu" (estacionariedad alrededor de una media constante).
#
# Máximo de rezagos para la búsqueda BIC de ADF: ur.df(lags=...) por defecto es 1 (búsqueda
# 0..1, casi no busca nada) -- hay que fijar un techo explícito para que "selectlags=BIC"
# signifique algo. Se usa la regla de Schwert trunc(12*(n/100)^0.25), convención común en
# software econométrico para el techo de búsqueda de ADF (no es la selección en sí, que sigue
# siendo BIC dentro de ese rango).

library(urca)

.max_rezagos_schwert <- function(n) trunc(12 * (n / 100)^0.25)

#' Devuelve las transformaciones candidatas de un vector de nivel, en el orden fijado por
#' Harold. Las dos basadas en logaritmo se omiten (NULL) si `valor` tiene algún valor no
#' positivo -- log() no está definido ahí; se documenta, no se fuerza.
transformaciones_candidatas <- function(valor) {
  todo_positivo <- all(valor > 0, na.rm = TRUE)
  log_valor <- if (todo_positivo) log(valor) else NULL
  list(
    nivel = valor,
    log = log_valor,
    diff = diff(valor),
    diff_log = if (!is.null(log_valor)) diff(log_valor) else NULL
  )
}

.especificacion <- function(tipo_transf) {
  if (tipo_transf %in% c("nivel", "log")) {
    list(adf_type = "trend", adf_tau = "tau3", kpss_type = "tau")
  } else if (tipo_transf %in% c("diff", "diff_log")) {
    list(adf_type = "drift", adf_tau = "tau2", kpss_type = "mu")
  } else {
    stop("tipo_transf desconocido: ", tipo_transf)
  }
}

#' ADF (Dickey-Fuller aumentado) con selección de rezagos por BIC, especificación
#' determinística según `tipo_transf` (ver .especificacion()). rechaza_raiz_unitaria = TRUE
#' significa que el estadístico es más negativo que el valor crítico al 5% -- evidencia a
#' favor de estacionariedad.
prueba_adf <- function(x, tipo_transf) {
  spec <- .especificacion(tipo_transf)
  n <- length(x)
  ajuste <- ur.df(x, type = spec$adf_type, lags = .max_rezagos_schwert(n), selectlags = "BIC")
  estadistico <- unname(ajuste@teststat[1, spec$adf_tau])
  cval_5pct <- unname(ajuste@cval[spec$adf_tau, "5pct"])
  list(estadistico = estadistico, cval_5pct = cval_5pct, rezagos = ajuste@lags,
       rechaza_raiz_unitaria = estadistico < cval_5pct)
}

#' KPSS con truncamiento "short" (Schwert, la opción más parsimoniosa), tipo según
#' `tipo_transf`. rechaza_estacionariedad = TRUE significa que el estadístico supera el valor
#' crítico al 5% -- evidencia en contra de estacionariedad.
prueba_kpss <- function(x, tipo_transf) {
  spec <- .especificacion(tipo_transf)
  ajuste <- ur.kpss(x, type = spec$kpss_type, lags = "short")
  estadistico <- unname(ajuste@teststat[1])
  cval_5pct <- unname(ajuste@cval[1, "5pct"])
  list(estadistico = estadistico, cval_5pct = cval_5pct, rezagos_truncamiento = ajuste@lag,
       rechaza_estacionariedad = estadistico > cval_5pct)
}

#' Interpretación confirmatoria (Kwiatkowski et al. 1992): "estacionaria" solo si ambas
#' pruebas coinciden en ese sentido; "no_estacionaria" solo si ambas coinciden en el sentido
#' contrario; "ambigua" si discrepan (H0 propia de cada prueba es distinta, así que discrepar
#' es información, no un empate a romper).
interpretar_conjunta <- function(adf, kpss) {
  if (adf$rechaza_raiz_unitaria && !kpss$rechaza_estacionariedad) {
    "estacionaria"
  } else if (!adf$rechaza_raiz_unitaria && kpss$rechaza_estacionariedad) {
    "no_estacionaria"
  } else {
    "ambigua"
  }
}

#' Corre ADF+KPSS sobre las transformaciones disponibles de una serie y devuelve una fila por
#' transformación (las basadas en log se omiten si no aplican, ver transformaciones_candidatas()).
analizar_estacionariedad_serie <- function(valor, serie_id) {
  candidatas <- transformaciones_candidatas(valor)
  filas <- list()
  for (tipo_transf in names(candidatas)) {
    x <- candidatas[[tipo_transf]]
    if (is.null(x)) next
    adf <- prueba_adf(x, tipo_transf)
    kpss <- prueba_kpss(x, tipo_transf)
    filas[[tipo_transf]] <- data.frame(
      serie_id = serie_id, transformacion = tipo_transf, n_obs = length(x),
      adf_estadistico = adf$estadistico, adf_cval_5pct = adf$cval_5pct, adf_rezagos = adf$rezagos,
      adf_rechaza_raiz_unitaria = adf$rechaza_raiz_unitaria,
      kpss_estadistico = kpss$estadistico, kpss_cval_5pct = kpss$cval_5pct,
      kpss_rezagos_truncamiento = kpss$rezagos_truncamiento,
      kpss_rechaza_estacionariedad = kpss$rechaza_estacionariedad,
      conclusion = interpretar_conjunta(adf, kpss),
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, filas)
}
