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

library(httr2)
library(jsonlite)
source("src/adquisicion/lib_adquisicion.R")

.fred_verificar_forma <- function(contenido_crudo) {
  json <- tryCatch(jsonlite::fromJSON(rawToChar(contenido_crudo)), error = function(e) NULL)
  if (is.null(json)) return(FALSE)
  if (is.null(json$observations) || nrow(json$observations) == 0) return(FALSE)
  TRUE
}

descargar_fred_serie <- function(series_id, frecuencia, publicacion_id = paste0("FRED.", series_id)) {
  api_key <- Sys.getenv("FRED_API_KEY")
  if (!nzchar(api_key)) {
    stop("FALLO VISIBLE: FRED_API_KEY no esta definida - configurar .Renviron ",
         "(Paso 0 del handoff) y reiniciar R antes de seguir.")
  }

  resp <- httr2::request("https://api.stlouisfed.org/fred/series/observations") |>
    httr2::req_url_query(series_id = series_id, api_key = api_key, file_type = "json") |>
    httr2::req_perform()

  codigo_http <- httr2::resp_status(resp)
  contenido_crudo <- httr2::resp_body_raw(resp)

  url_sin_clave <- sprintf(
    "https://api.stlouisfed.org/fred/series/observations?series_id=%s&file_type=json",
    series_id
  )

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
        "period), no una fecha sintetica. %d observaciones totales, %d con valor",
        "real (huecos marcados '.' por FRED, excluidos del calculo de",
        "periodo_referencia_max). publicacion_id = %s, un publicacion_id por serie",
        "desde el inicio (ADR-007, nota 2026-08-27) - sin colision de vintage_id",
        "con otras series de la misma familia. api_key usada para la consulta",
        "pero NUNCA guardada."
      ),
      series_id, fecha_publicacion, nrow(obs), nrow(obs_validas), publicacion_id
    )
  )
}
