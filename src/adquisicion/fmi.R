# fmi.R
#
# Adquisicion FMI (SDMX 3.0, api.imf.org). Sin clave de API - REST publica.
#
# fecha_publicacion: BOP, QNEA y PCPS NO traen ninguna fecha de dato legible
# (ni en meta, ni en atributos de serie/observacion, ni en cabeceras HTTP, ni en
# /structure -esas estan congeladas a la version del esquema-, confirmado en el
# diagnostico del 2026-08-29). El unico mecanismo de esta API que da una fecha
# real y sensible al dato es el parametro SDMX `updatedAfter`: se bisecta el rango
# de fechas para hallar la mas reciente con respuesta NO vacia = fecha del ultimo
# refresco de datos del lado del FMI para El Salvador. Es el analogo, para estos
# dataflows, del `asOf` que QNEA ya expone (QNEA soporta ambos).
#
# Parametro liviano para los sondeos de bisecion: `attributes=none&measures=none`
# reduce la respuesta ~98% (BOP 2.5MB -> 35KB, QNEA 166KB -> 5.7KB, serie PCPS
# 25KB -> 0.8KB), UNIFORME para los tres dataflows. `detail=serieskeysonly` NO
# reduce nada en SDMX 3.0 (confirmado - ver ficha de FMI.QNEA). Verificado por
# Claude Code, Bloque 0 del handoff, 2026-08-29.
#
# Una respuesta vacia de esta API es un cuerpo HTTP genuinamente vacio (HTTP 200,
# sin content-length, sin cuerpo) - httr2::resp_body_raw() lanza "Can't retrieve
# empty body". La deteccion de vacio se hace capturando ese error, no por umbral
# de bytes.

library(httr2)
library(jsonlite)
source("src/adquisicion/lib_adquisicion.R")

.FMI_ACCEPT <- "application/vnd.sdmx.data+json"
.FMI_PARAMS_LIVIANOS <- list(attributes = "none", measures = "none")

.fmi_perform <- function(url, query = list()) {
  req <- httr2::request(url) |>
    httr2::req_headers(Accept = .FMI_ACCEPT) |>
    httr2::req_timeout(120) |>
    httr2::req_retry(max_tries = 3, backoff = function(i) 2 * i)
  if (length(query)) req <- req |> httr2::req_url_query(!!!query)
  httr2::req_perform(req)
}

# TRUE si la respuesta trae datos; FALSE si el cuerpo esta vacio (updatedAfter
# posterior al ultimo refresco). Cualquier otro error se propaga.
.fmi_hay_datos <- function(url, query = list()) {
  resp <- .fmi_perform(url, query)
  if (httr2::resp_status(resp) != 200) {
    stop("FALLO VISIBLE [FMI]: codigo HTTP ", httr2::resp_status(resp), " en sondeo. URL: ", url)
  }
  bytes <- tryCatch(httr2::resp_body_raw(resp), error = function(e) {
    if (grepl("empty body", conditionMessage(e), fixed = TRUE)) return(NULL)
    stop(e)
  })
  !is.null(bytes) && length(bytes) > 0
}

# Bisecta `updatedAfter` sobre [fecha_min, fecha_max] y devuelve (como cadena ISO)
# la fecha mas reciente para la cual la respuesta NO esta vacia = dia del ultimo
# refresco de datos del FMI para esta consulta.
.fmi_bisecar_fecha_actualizacion <- function(url_base,
                                             fecha_min = as.Date("2024-01-01"),
                                             fecha_max = Sys.Date()) {
  ua <- function(fecha) list(updatedAfter = paste0(format(fecha), "T00:00:00Z"))
  probar <- function(fecha) .fmi_hay_datos(url_base, c(.FMI_PARAMS_LIVIANOS, ua(fecha)))

  if (!probar(fecha_min)) {
    stop("FALLO VISIBLE [FMI]: fecha_min (", fecha_min, ") ya da respuesta vacia - ",
         "el rango de bisecion esta mal elegido, ampliar fecha_min hacia atras. URL: ", url_base)
  }
  if (probar(fecha_max)) {
    stop("FALLO VISIBLE [FMI]: fecha_max (", fecha_max, ", hoy) NO da respuesta vacia - ",
         "hay datos actualizados hoy mismo para esta consulta. Revisar a mano antes de ",
         "capturar (podria ser un refresco real de hoy, o el rango mal elegido). URL: ", url_base)
  }

  lo <- fecha_min  # invariante: ultimo "no vacio" confirmado
  hi <- fecha_max  # invariante: primer "vacio" confirmado
  iter <- 0L
  while (as.integer(hi - lo) > 1L) {
    iter <- iter + 1L
    if (iter > 25L) stop("FALLO VISIBLE [FMI]: bisecion no converge (", iter, " iteraciones). URL: ", url_base)
    mid <- lo + (as.integer(hi - lo) %/% 2L)
    if (probar(mid)) lo <- mid else hi <- mid
  }
  message("  updatedAfter bisecado en ", iter, " iteraciones -> ", lo, " (URL: ", url_base, ")")
  as.character(lo)
}

# --- Bloque 2: dataflow completo (BOP, QNEA) - un vintage por dataflow ---

descargar_fmi_dataflow_completo <- function(url_datos, publicacion_id) {
  fecha_pub <- .fmi_bisecar_fecha_actualizacion(url_datos)

  resp <- .fmi_perform(url_datos)
  codigo_http <- httr2::resp_status(resp)
  contenido_crudo <- httr2::resp_body_raw(resp)

  verif <- function(c) {
    j <- tryCatch(jsonlite::fromJSON(rawToChar(c), simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(j)) return(FALSE)
    ds <- j$data$dataSets
    !is.null(ds) && length(ds) >= 1 && length(ds[[1]]$series) > 0
  }
  if (!verif(contenido_crudo)) {
    stop("FALLO VISIBLE [", publicacion_id, "]: la respuesta de dataflow completo no trae ",
         "series (", length(contenido_crudo), " bytes). URL: ", url_datos)
  }

  registrar_descarga(
    fuente = "FMI",
    publicacion_id = publicacion_id,
    url = url_datos,
    descripcion_archivo = tolower(gsub("\\.", "_", sub("^FMI\\.", "", publicacion_id))),
    extension = "json",
    contenido_crudo = contenido_crudo,
    codigo_http = codigo_http,
    fecha_publicacion = fecha_pub,
    periodo_referencia_max = "",  # dataflow completo: decenas de series con rangos de periodo
                                  # distintos entre si; no hay un maximo unico honesto sin
                                  # agregar de mas. Vacio deliberado (ver notas_vintage).
    verificacion_forma = verif,
    notas_vintage = sprintf(
      paste(
        "Dataflow completo via %s. fecha_publicacion = %s, fecha bisecada del parametro",
        "SDMX updatedAfter (dia mas reciente con respuesta no vacia) - unico mecanismo de",
        "esta API que da una fecha real y sensible al dato para BOP/QNEA (no traen fecha",
        "en meta ni en atributos de serie/observacion, ni en cabeceras HTTP, ni en",
        "/structure -esas estan congeladas a la version del esquema-; confirmado en el",
        "diagnostico del 2026-08-29). Sondeos de bisecion con attributes=none&measures=none",
        "(reduce ~98%%, detail=serieskeysonly es inerte en SDMX 3.0). periodo_referencia_max",
        "queda VACIO deliberadamente: es un dataflow con muchas series y muchos periodos",
        "distintos, sin un valor unico representativo sin agregar de mas - no se inventa."
      ),
      url_datos, fecha_pub
    )
  )
}

descargar_fmi_bop <- function() {
  descargar_fmi_dataflow_completo(
    "https://api.imf.org/external/sdmx/3.0/data/dataflow/IMF.STA/BOP/~/SLV",
    "FMI.BOP"
  )
}

descargar_fmi_qnea <- function() {
  descargar_fmi_dataflow_completo(
    "https://api.imf.org/external/sdmx/3.0/data/dataflow/IMF.STA/QNEA/~/SLV",
    "FMI.QNEA"
  )
}

# --- Bloque 3: PCPS por indicador - un publicacion_id por indicador (ADR-007,
# nota 2026-08-27, preventivo: los candidatos de PCPS comparten dataflow y fecha
# de refresco, colisionarian igual que FRED.INDICADORES_MENSUALES_EEUU) ---

descargar_fmi_pcps_indicador <- function(codigo_indicador, publicacion_id) {
  url_datos <- sprintf(
    "https://api.imf.org/external/sdmx/3.0/data/dataflow/IMF.RES/PCPS/+/G001.%s.INDEX.M",
    codigo_indicador
  )
  fecha_pub <- .fmi_bisecar_fecha_actualizacion(url_datos)

  resp <- .fmi_perform(url_datos)
  codigo_http <- httr2::resp_status(resp)
  contenido_crudo <- httr2::resp_body_raw(resp)

  verif <- function(c) {
    j <- tryCatch(jsonlite::fromJSON(rawToChar(c), simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(j)) return(FALSE)
    ds <- j$data$dataSets
    if (is.null(ds) || length(ds) < 1 || length(ds[[1]]$series) != 1) return(FALSE)
    length(ds[[1]]$series[[1]]$observations) > 0
  }
  if (!verif(contenido_crudo)) {
    stop("FALLO VISIBLE [", publicacion_id, "]: la serie ", codigo_indicador,
         " no trae una unica serie con observaciones. URL: ", url_datos)
  }

  json <- jsonlite::fromJSON(rawToChar(contenido_crudo), simplifyVector = FALSE)
  st <- json$data$structures[[1]]
  serie <- json$data$dataSets[[1]]$series[[1]]
  tp <- vapply(st$dimensions$observation[[1]]$values, function(v) v$value, character(1))
  idx_con_valor <- as.integer(names(Filter(
    function(o) length(o) >= 1 && !is.null(o[[1]]) && nzchar(as.character(o[[1]])),
    serie$observations
  )))
  if (length(idx_con_valor) == 0) {
    stop("FALLO VISIBLE [", publicacion_id, "]: ninguna observacion con valor real.")
  }
  periodo_max <- tp[max(idx_con_valor) + 1L]

  registrar_descarga(
    fuente = "FMI",
    publicacion_id = publicacion_id,
    url = url_datos,
    descripcion_archivo = tolower(codigo_indicador),
    extension = "json",
    contenido_crudo = contenido_crudo,
    codigo_http = codigo_http,
    fecha_publicacion = fecha_pub,
    periodo_referencia_max = periodo_max,
    verificacion_forma = verif,
    notas_vintage = sprintf(
      paste(
        "Serie %s de PCPS (G001.%s.INDEX.M). fecha_publicacion = %s, fecha bisecada del",
        "parametro SDMX updatedAfter (mismo mecanismo que BOP/QNEA - PCPS no trae fecha",
        "de dato legible, diagnostico 2026-08-29). %d observaciones con valor, periodo",
        "mas reciente %s. publicacion_id = %s, un publicacion_id por indicador desde el",
        "inicio (ADR-007, nota 2026-08-27, preventivo: los candidatos de PCPS comparten",
        "dataflow y fecha de refresco, colisionarian en vintage_id bajo una ficha comun)."
      ),
      codigo_indicador, codigo_indicador, fecha_pub, length(idx_con_valor), periodo_max, publicacion_id
    )
  )
}
