# bm.R
#
# Adquisicion Banco Mundial (WDI). Sin clave de API - REST publica. Un
# publicacion_id por indicador desde el inicio (ADR-007, nota de seguimiento
# 2026-08-27, aplicada preventivamente - sin esperar una colision de vintage_id).
#
# fecha_publicacion: campo `lastupdated` NATIVO de la respuesta de la API v2 del
# Banco Mundial (objeto de metadatos de pagina), formato ISO 8601. Verificado por
# Claude Code el 2026-08-28 (Bloque 0 del handoff FMI/BM) para los dos indicadores
# de arranque: "2026-07-13" para la base WDI (fuente id=2). Es la fecha de ultima
# actualizacion de la base -comun a todos los indicadores de esa base, no por
# indicador ni por observacion (menos fino que el realtime_start de FRED, que es
# por observacion), pero es una fecha declarada por la fuente y ligada al vintage
# de los datos. NO se usa una fecha sintetica de captura (el handoff original
# proponia el patron UT, sobre la premisa -falsa- de que WDI no traia fecha
# nativa). Decision de Harold, 2026-08-28.

library(httr2)
library(jsonlite)
source("src/adquisicion/lib_adquisicion.R")

.bm_verificar_forma <- function(contenido_crudo) {
  json <- tryCatch(jsonlite::fromJSON(rawToChar(contenido_crudo)), error = function(e) NULL)
  if (is.null(json) || length(json) < 2) return(FALSE)
  datos <- json[[2]]
  if (is.null(datos) || length(datos) == 0 || (is.data.frame(datos) && nrow(datos) == 0)) return(FALSE)
  TRUE
}

.BM_PER_PAGE <- 1000L

# URL EXACTA de la consulta, con todos los parametros - es la que se registra y la que
# scripts/verificar_l0.R vuelve a pedir. CORREGIDO el 2026-08-28 (hallazgo A4 de la
# auditoria de Fase 2): hasta esa fecha se pedia con per_page=1000 pero se registraba solo
# `?format=json`, de modo que la URL del manifiesto devolvia la primera pagina con el
# default de 50 registros y NO reproducia la respuesta archivada. El contrato de
# src/adquisicion/README.md S3 pide la URL exacta consultada, con todos los parametros.
.bm_url_registrada <- function(codigo_indicador) {
  sprintf("https://api.worldbank.org/v2/country/SLV/indicator/%s?format=json&per_page=%d",
          codigo_indicador, .BM_PER_PAGE)
}

# Un solo lugar donde se arma la peticion, para que la captura y la verificacion de
# scripts/verificar_l0.R no puedan divergir.
.bm_fetch <- function(codigo_indicador) {
  resp <- httr2::request(
    sprintf("https://api.worldbank.org/v2/country/SLV/indicator/%s", codigo_indicador)
  ) |>
    httr2::req_url_query(format = "json", per_page = .BM_PER_PAGE) |>
    httr2::req_perform()
  list(bytes = httr2::resp_body_raw(resp), codigo_http = httr2::resp_status(resp),
       url_registrada = .bm_url_registrada(codigo_indicador))
}

# Re-pide desde la URL guardada en el manifiesto, que ya lleva todos los parametros.
# La usa scripts/verificar_l0.R; no registra nada.
.bm_refetch <- function(url_registrada) {
  httr2::resp_body_raw(httr2::req_perform(httr2::request(url_registrada)))
}

descargar_bm_wdi_indicador <- function(codigo_indicador, publicacion_id) {
  obtenido <- .bm_fetch(codigo_indicador)
  codigo_http <- obtenido$codigo_http
  contenido_crudo <- obtenido$bytes
  url <- obtenido$url_registrada

  if (!.bm_verificar_forma(contenido_crudo)) {
    stop("FALLO VISIBLE: ", codigo_indicador, " - respuesta sin datos, o JSON ",
         "malformado. codigo_http=", codigo_http)
  }

  json <- jsonlite::fromJSON(rawToChar(contenido_crudo))
  meta <- json[[1]]
  datos <- json[[2]]

  fecha_publicacion <- as.character(meta$lastupdated)[1]
  if (is.na(fecha_publicacion) || !nzchar(fecha_publicacion) ||
      !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", fecha_publicacion)) {
    stop("FALLO VISIBLE: ", codigo_indicador, " - campo `lastupdated` ausente o no ISO ",
         "en la respuesta (recibido: '", fecha_publicacion, "'). La API cambio de forma; ",
         "no se registra nada.")
  }

  datos_validos <- datos[!is.na(datos$value), ]
  if (nrow(datos_validos) == 0) {
    stop("FALLO VISIBLE: ", codigo_indicador, " - ninguna observacion con valor real")
  }

  anio_max <- max(as.integer(datos_validos$date))
  periodo_max <- as.character(anio_max)

  registrar_descarga(
    fuente = "BM",
    publicacion_id = publicacion_id,
    url = url,
    descripcion_archivo = tolower(gsub("\\.", "_", codigo_indicador)),
    extension = "json",
    contenido_crudo = contenido_crudo,
    codigo_http = codigo_http,
    fecha_publicacion = fecha_publicacion,
    periodo_referencia_max = periodo_max,
    verificacion_forma = .bm_verificar_forma,
    notas_vintage = sprintf(
      paste(
        "Indicador %s via v2/country/SLV/indicator. fecha_publicacion = campo",
        "`lastupdated` NATIVO de la page-meta de la respuesta (%s, ISO 8601) - fecha",
        "de ultima actualizacion de la base WDI (fuente id=%s), comun a todos los",
        "indicadores de esa base y no por indicador (mas gruesa que el `last_updated` por",
        "serie de FRED). NO es una fecha sintetica de captura. La url registrada lleva",
        "todos los parametros de la consulta, per_page incluido (hallazgo A4 de la",
        "auditoria de Fase 2, 2026-08-28). %d observaciones con valor real (de %s en la",
        "respuesta; los anios sin dato vienen con value=null), anio mas reciente %s.",
        "publicacion_id = %s, un publicacion_id por indicador desde el inicio (ADR-007,",
        "nota 2026-08-27, aplicado preventivamente). periodo_referencia_max es un anio",
        "simple (%s) por la periodicidad anual - formato nuevo en 08_vintages, inocuo",
        "para check_l0_integrity.R (solo compara igualdad cruzada, no valida formato)."
      ),
      codigo_indicador, fecha_publicacion, as.character(meta$sourceid)[1],
      nrow(datos_validos), as.character(meta$total)[1], periodo_max, publicacion_id,
      periodo_max
    )
  )
}
