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

descargar_bm_wdi_indicador <- function(codigo_indicador, publicacion_id) {
  url <- sprintf("https://api.worldbank.org/v2/country/SLV/indicator/%s", codigo_indicador)

  resp <- httr2::request(url) |>
    httr2::req_url_query(format = "json", per_page = 1000) |>
    httr2::req_perform()

  codigo_http <- httr2::resp_status(resp)
  contenido_crudo <- httr2::resp_body_raw(resp)

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
    url = paste0(url, "?format=json"),
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
        "indicadores de esa base, no por observacion (a diferencia de FRED). NO es una",
        "fecha sintetica de captura. %d observaciones con valor real (de %s en la",
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
