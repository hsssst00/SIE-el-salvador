# bcr.R
#
# Scripts de descarga por publicacion del BCR. Una funcion por publicacion,
# para que un cambio de estructura en una rompa solo esa (senda S8, tabla de
# riesgos: "scripts modulares por publicacion").

library(httr2)
source("src/adquisicion/lib_adquisicion.R")

descargar_bcr_pib_nsa <- function() {
  url <- "https://estadisticas.bcr.gob.sv/serie/pib-t-produccion-y-gasto-indices-de-volumen-encadenados-serie-original-referencia-2014-indices-de-volumen-encadenados"

  # El BCR tiene deteccion de bots confirmada (Claude, 2026-08-18: un fetch
  # simple sin estos headers contra esta misma URL fue bloqueado). No hay
  # garantia de que headers de navegador alcancen - documentar el resultado
  # sea cual sea, no forzar un exito.
  resp <- tryCatch({
    request(url) |>
      req_headers(
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language" = "es-ES,es;q=0.9,en;q=0.8",
        "Referer" = "https://estadisticas.bcr.gob.sv/"
      ) |>
      req_perform()
  }, error = function(e) {
    stop("FALLO VISIBLE [BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA]: la solicitud ",
         "fallo antes de recibir respuesta - ", conditionMessage(e))
  })

  codigo_http <- resp_status(resp)
  contenido_crudo <- resp_body_raw(resp)
  content_type <- resp_content_type(resp)

  # Verificacion de forma: un .xlsx real empieza con la firma ZIP "PK". Si esto
  # viene como text/html, es casi seguro una pagina de bloqueo o de error, no
  # el archivo real.
  verificacion_xlsx <- function(bytes) {
    if (length(bytes) < 2) return(FALSE)
    identical(as.integer(bytes[1:2]), c(0x50L, 0x4bL))  # firma "PK" de ZIP/xlsx
  }

  if (!is.null(content_type) && grepl("html", content_type, ignore.case = TRUE)) {
    stop("FALLO VISIBLE [BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA]: la respuesta vino ",
         "con Content-Type '", content_type, "' en vez de un tipo de archivo de hoja de ",
         "calculo. Consistente con deteccion de bots o pagina de error del portal ",
         "Livewire/Alpine.js del BCR (ver hallazgo de Claude, 2026-08-18: un fetch simple ",
         "contra esta misma URL fue bloqueado). No se guarda nada.")
  }

  registrar_descarga(
    fuente = "BCR",
    publicacion_id = "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA",
    url = url,
    descripcion_archivo = "pib_t_indices_volumen_nsa",
    extension = "xlsx",
    contenido_crudo = contenido_crudo,
    codigo_http = codigo_http,
    verificacion_forma = verificacion_xlsx
  )
}
