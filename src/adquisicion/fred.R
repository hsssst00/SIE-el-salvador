# fred.R
#
# Adquisicion FRED: cliente propio sobre httr2 (ADR-009, disparador resuelto
# 2026-08-18). Respuesta JSON cruda de fred/series/observations, sin tidificar.
# Un publicacion_id por serie (ADR-007, nota de seguimiento 2026-08-27) - salvo
# GDPC1, que mantiene FRED.BEA_PIB_EEUU por decision de Harold.
#
# CRITICO: FRED_API_KEY (en .Renviron, nunca committeada) jamas se pasa como
# parte de la url que registrar_descarga() escribe a manifiesto.csv/08_vintages.csv
# (ambos versionados en Git). La url guardada omite api_key.
#
# fecha_publicacion: `realtime_start` de las observaciones (concepto nativo de FRED/ALFRED:
# inicio del periodo de tiempo real del vintage vigente de la serie).
#
# COMPROBADO el 2026-08-28, a raiz de un hallazgo A2 de la auditoria de Fase 2 que resulto
# FALSO y que conviene dejar refutado para que nadie lo "arregle" de nuevo: se sospecho que
# `realtime_start`, sin parametros realtime_*, devolvia el dia de la consulta y por tanto
# degeneraba en la fecha de descarga -lo que ADR-007 (nota 2026-08-20) rechaza-. Es correcto
# que el valor es UNIFORME dentro de un archivo (todas las observaciones comparten el vintage
# vigente de la serie), pero NO es la fecha de la consulta: varia por serie. Las 5 series
# capturadas el mismo dia (2026-08-27) traen 2026-08-26 (GDPC1), 2026-08-18 (INDPRO),
# 2026-08-07 (PAYEMS y UNRATE) y 2026-08-12 (CPIAUCSL); las cinco coinciden exactamente con
# el `last_updated` que fred/series declara para cada una, consultado de forma independiente.
# La sospecha nacio de mirar solo GDPC1, cuya fecha real cae cerca de la de descarga.
# Conclusion: `realtime_start` es la fecha correcta y no hace falta una segunda consulta a
# fred/series para obtenerla.

library(httr2)
library(jsonlite)
source("src/adquisicion/lib_adquisicion.R")

.fred_verificar_forma <- function(contenido_crudo) {
  json <- tryCatch(jsonlite::fromJSON(rawToChar(contenido_crudo)), error = function(e) NULL)
  if (is.null(json)) return(FALSE)
  if (is.null(json$observations) || nrow(json$observations) == 0) return(FALSE)
  TRUE
}

.fred_api_key <- function() {
  api_key <- Sys.getenv("FRED_API_KEY")
  if (!nzchar(api_key)) {
    stop("FALLO VISIBLE: FRED_API_KEY no esta definida - configurar .Renviron ",
         "(ver .Renviron.example) y reiniciar R antes de seguir.")
  }
  api_key
}

# URL tal como se registra en manifiesto.csv / 08_vintages.csv: sin api_key. Es tambien la
# que scripts/verificar_l0.R vuelve a pedir, re-agregando la clave (.fred_refetch).
.fred_url_registrada <- function(series_id) {
  sprintf("https://api.stlouisfed.org/fred/series/observations?series_id=%s&file_type=json",
          series_id)
}

# Un solo lugar donde se arma la peticion de observaciones, para que la captura y la
# verificacion de scripts/verificar_l0.R no puedan divergir.
.fred_fetch_observaciones <- function(series_id) {
  resp <- httr2::request("https://api.stlouisfed.org/fred/series/observations") |>
    httr2::req_url_query(series_id = series_id, api_key = .fred_api_key(), file_type = "json") |>
    httr2::req_perform()
  list(bytes = httr2::resp_body_raw(resp), codigo_http = httr2::resp_status(resp),
       url_registrada = .fred_url_registrada(series_id))
}

# Re-pide desde la URL guardada en el manifiesto (sin clave), re-agregando la api_key.
# La usa scripts/verificar_l0.R; no registra nada.
.fred_refetch <- function(url_sin_clave) {
  resp <- httr2::request(url_sin_clave) |>
    httr2::req_url_query(api_key = .fred_api_key()) |>
    httr2::req_perform()
  httr2::resp_body_raw(resp)
}

descargar_fred_serie <- function(series_id, frecuencia, publicacion_id = paste0("FRED.", series_id)) {
  obtenido <- .fred_fetch_observaciones(series_id)
  codigo_http <- obtenido$codigo_http
  contenido_crudo <- obtenido$bytes
  url_sin_clave <- obtenido$url_registrada

  if (!.fred_verificar_forma(contenido_crudo)) {
    stop("FALLO VISIBLE: ", series_id, " - respuesta sin observaciones, o JSON ",
         "malformado. codigo_http=", codigo_http)
  }

  json <- jsonlite::fromJSON(rawToChar(contenido_crudo))
  obs <- json$observations
  obs_validas <- obs[obs$value != ".", ]
  if (nrow(obs_validas) == 0) {
    stop("FALLO VISIBLE: ", series_id, " - ninguna observacion con valor real (todas '.')")
  }

  fecha_max <- max(as.Date(obs_validas$date))
  fila_max <- obs_validas[as.Date(obs_validas$date) == fecha_max, ][1, ]
  fecha_publicacion <- fila_max$realtime_start

  periodo_max <- if (frecuencia == "Q") {
    mes <- as.integer(format(fecha_max, "%m"))
    trimestre <- (mes - 1) %/% 3 + 1
    sprintf("%s-T%d", format(fecha_max, "%Y"), trimestre)
  } else if (frecuencia == "M") {
    format(fecha_max, "%Y-M%m")
  } else {
    stop("FALLO VISIBLE: frecuencia '", frecuencia, "' no reconocida (solo Q o M)")
  }

  registrar_descarga(
    fuente = "FRED",
    publicacion_id = publicacion_id,
    url = url_sin_clave,
    descripcion_archivo = tolower(series_id),
    extension = "json",
    contenido_crudo = contenido_crudo,
    codigo_http = codigo_http,
    fecha_publicacion = fecha_publicacion,
    periodo_referencia_max = periodo_max,
    verificacion_forma = .fred_verificar_forma,
    notas_vintage = sprintf(
      paste(
        "Serie %s via fred/series/observations. fecha_publicacion = realtime_start",
        "de la observacion mas reciente (%s) - concepto nativo de FRED (real-time",
        "period), no una fecha sintetica; varia por serie y coincide con el last_updated",
        "que fred/series declara (comprobado 2026-08-28, ver cabecera de fred.R). %d",
        "observaciones totales, %d con valor real (huecos marcados '.' por FRED, excluidos",
        "del calculo de periodo_referencia_max). publicacion_id = %s, un publicacion_id por",
        "serie desde el inicio (ADR-007, nota 2026-08-27) - sin colision de vintage_id con",
        "otras series de la misma familia. api_key usada para la consulta pero NUNCA",
        "guardada."
      ),
      series_id, fecha_publicacion, nrow(obs), nrow(obs_validas), publicacion_id
    )
  )
}
