# fmi.R
#
# Adquisicion FMI (SDMX 3.0, api.imf.org). Sin clave de API - REST publica.
# Bloques: 2 dataflow completo (BOP, QNEA); 3 PCPS por indicador; 4 WEO y 5 su capitulo 1 (Fase 6).
#
# fecha_publicacion: BOP, QNEA y PCPS NO traen ninguna fecha de dato legible
# (ni en meta, ni en atributos de serie/observacion, ni en cabeceras HTTP, ni en
# /structure -esas estan congeladas a la version del esquema-, confirmado en el
# diagnostico del 2026-08-28). El unico mecanismo de esta API que da una fecha
# real y sensible al dato es el parametro SDMX `updatedAfter`: se bisecta el rango
# de fechas para hallar la mas reciente con respuesta NO vacia = fecha del ultimo
# refresco de datos del lado del FMI para El Salvador. Es el analogo, para estos
# dataflows, del `asOf` que QNEA ya expone (QNEA soporta ambos).
#
# Parametro liviano para los sondeos de bisecion: `attributes=none&measures=none`
# reduce la respuesta ~98% (BOP 2.5MB -> 35KB, QNEA 166KB -> 5.7KB, serie PCPS
# 25KB -> 0.8KB), UNIFORME para los tres dataflows. `detail=serieskeysonly` NO
# reduce nada en SDMX 3.0 (confirmado - ver ficha de FMI.QNEA). Verificado por
# Claude Code, Bloque 0 del handoff, 2026-08-28.
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
        "diagnostico del 2026-08-28). La url NO basta para reproducir esta respuesta: el",
        "formato lo decide el header Accept: application/vnd.sdmx.data+json (negociacion de",
        "contenido de SDMX 3.0); la misma url sin ese header devuelve otra representacion",
        "(hallazgo M3 de la auditoria de Fase 2, 2026-08-28).",
        "Sondeos de bisecion con attributes=none&measures=none",
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
        "de dato legible, diagnostico 2026-08-28). La url NO basta para reproducir esta",
        "respuesta: el formato lo decide el header Accept:",
        "application/vnd.sdmx.data+json (hallazgo M3 de la auditoria de Fase 2,",
        "2026-08-28). %d observaciones con valor, periodo",
        "mas reciente %s. publicacion_id = %s, un publicacion_id por indicador desde el",
        "inicio (ADR-007, nota 2026-08-27, preventivo: los candidatos de PCPS comparten",
        "dataflow y fecha de refresco, colisionarian en vintage_id bajo una ficha comun)."
      ),
      codigo_indicador, codigo_indicador, fecha_pub, length(idx_con_valor), periodo_max, publicacion_id
    )
  )
}

# --- Bloque 4: WEO (Fase 6, C2) - extracto de la base de datos del WEO vigente ---
#
# Un solo archivo y un solo vintage por edicion del WEO (FMI.WEO.vAAAA-MM): las tres
# economias que usa el Ejercicio B (G001 = mundo, USA, SLV), con TODOS sus indicadores,
# para no adelantar la eleccion de satelites (fichas F6-15 a F6-18). Hechos verificados el
# 2026-10-19 contra la API (decisiones_fase6.md, hecho del 2026-10-17):
#   - la API sirve solo el WEO vigente; por eso la captura fija el vintage por fecha y sha256;
#   - el filtro c[TIME_PERIOD] rompe la consulta en este dataflow (ver FMI.WEO.yaml): se pide
#     sin filtro de tiempo;
#   - con attributes=all la respuesta trae los atributos del dataset, entre ellos
#     PUBLICATION_DATE (2026-10-13T02:00:00Z para la edicion de octubre de 2026): es la fecha
#     que la fuente declara y de ella sale fecha_publicacion. Sin ese parametro no viene. El
#     updatedAfter bisecado de BOP/QNEA/PCPS da otra cosa aca (2026-10-09, el refresco interno
#     previo a la publicacion), por eso no se usa;
#   - COUNTRY_UPDATE_DATE es atributo de serie (USA y SLV lo traen; G001 no);
#   - dos descargas seguidas dan el mismo sha256 (respuesta determinista).
.WEO_URL <- "https://api.imf.org/external/sdmx/3.0/data/dataflow/IMF.RES/WEO/+/G001+USA+SLV.*.A?attributes=all"

# Series que el Ejercicio B necesita si o si (F6-05, F6-10 y el prompt de C2). Si alguna
# falta o no llega al ultimo anio del horizonte, la captura se detiene (regla 6).
.WEO_SERIES_REQUERIDAS <- c(
  "USA.NGDP_R.A", "USA.NGDP_RPCH.A", "USA.PCPIPCH.A", "USA.LUR.A",
  "G001.NGDP_RPCH.A", "G001.TRADEPCH.A", "G001.POILAPSP.A",
  "G001.PALLFNFW.A", "G001.PFOODW.A", "G001.PNFUELW.A",
  "SLV.NGDP_RPCH.A", "SLV.PCPIPCH.A"
)
.WEO_ANIO_MIN_FIN <- 2030L  # el horizonte h = 1..20 desde 2026-Q2/Q3 llega a 2031

# Lee el JSON SDMX del WEO a una tabla larga (clave, periodo, valor) mas la fecha de
# actualizacion por serie. Se usa en la verificacion de forma y en las notas del vintage.
.weo_tabla <- function(contenido_crudo) {
  j <- jsonlite::fromJSON(rawToChar(contenido_crudo), simplifyVector = FALSE)
  st <- j$data$structures[[1]]
  dims <- st$dimensions$series
  tp <- vapply(st$dimensions$observation[[1]]$values, function(v) v$value, character(1))
  sat <- vapply(st$attributes$series, function(a) a$id, character(1))
  i_upd <- match("COUNTRY_UPDATE_DATE", sat)
  series <- j$data$dataSets[[1]]$series
  filas <- lapply(names(series), function(k) {
    ix <- as.integer(strsplit(k, ":", fixed = TRUE)[[1]]) + 1L
    clave <- paste(vapply(seq_along(ix), function(d) dims[[d]]$values[[ix[d]]]$id, character(1)),
                   collapse = ".")
    s <- series[[k]]
    upd <- NA_character_
    if (!is.na(i_upd) && length(s$attributes) >= i_upd && !is.null(s$attributes[[i_upd]])) {
      a <- s$attributes[[i_upd]]
      vals <- st$attributes$series[[i_upd]]$values
      upd <- if (is.numeric(a) && length(vals) > a) {
        v <- vals[[a + 1L]]; as.character(if (!is.null(v$value)) v$value else v$id)
      } else as.character(a)
    }
    obs <- s$observations
    con_valor <- Filter(function(o) length(o) >= 1 && !is.null(o[[1]]) && nzchar(as.character(o[[1]])), obs)
    if (length(con_valor) == 0) return(NULL)
    data.frame(clave = clave, periodo = tp[as.integer(names(con_valor)) + 1L],
               valor = as.numeric(vapply(con_valor, function(o) as.character(o[[1]]), character(1))),
               actualizacion = upd, stringsAsFactors = FALSE)
  })
  do.call(rbind, filas)
}

# PUBLICATION_DATE del dataset (atributo de nivel dataSet; solo viene con attributes=all).
.weo_fecha_publicacion <- function(contenido_crudo) {
  j <- jsonlite::fromJSON(rawToChar(contenido_crudo), simplifyVector = FALSE)
  ids <- vapply(j$data$structures[[1]]$attributes$dataSet, function(a) a$id, character(1))
  i <- match("PUBLICATION_DATE", ids)
  v <- if (is.na(i)) NULL else j$data$dataSets[[1]]$attributes[[i]]
  v <- if (is.list(v)) unlist(v) else v
  if (is.null(v) || length(v) != 1 || !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", v)) {
    stop("FALLO VISIBLE [FMI.WEO]: la respuesta no trae un PUBLICATION_DATE legible en los ",
         "atributos del dataset (se pide con attributes=all).")
  }
  substr(v, 1, 10)
}

.weo_verificar_forma <- function(contenido_crudo) {
  tab <- tryCatch(.weo_tabla(contenido_crudo), error = function(e) NULL)
  if (is.null(tab) || nrow(tab) == 0) return(FALSE)
  if (!all(.WEO_SERIES_REQUERIDAS %in% tab$clave)) return(FALSE)
  fin <- tapply(as.integer(tab$periodo), tab$clave, max)
  all(fin[.WEO_SERIES_REQUERIDAS] >= .WEO_ANIO_MIN_FIN) &&
    all(c("G001", "USA", "SLV") %in% sub("\\..*$", "", tab$clave))
}

descargar_fmi_weo <- function() {
  url_datos <- .WEO_URL
  resp <- .fmi_perform(url_datos)
  codigo_http <- httr2::resp_status(resp)
  contenido_crudo <- httr2::resp_body_raw(resp)

  if (!.weo_verificar_forma(contenido_crudo)) {
    tab <- tryCatch(.weo_tabla(contenido_crudo), error = function(e) NULL)
    faltan <- if (is.null(tab)) "(no se pudo leer el JSON)" else
      paste(setdiff(.WEO_SERIES_REQUERIDAS, tab$clave), collapse = ", ")
    stop("FALLO VISIBLE [FMI.WEO]: el extracto no trae las series requeridas hasta ",
         .WEO_ANIO_MIN_FIN, ". Faltan: ", faltan, ". URL: ", url_datos)
  }
  tab <- .weo_tabla(contenido_crudo)
  fecha_pub <- .weo_fecha_publicacion(contenido_crudo)
  upd <- tapply(tab$actualizacion, sub("\\..*$", "", tab$clave),
                function(x) paste(sort(unique(stats::na.omit(x))), collapse = "/"))
  upd_txt <- paste(sprintf("%s=%s", names(upd), ifelse(nzchar(upd), upd, "sin atributo")), collapse = "; ")
  anio_max <- max(as.integer(tab$periodo))

  registrar_descarga(
    fuente = "FMI",
    publicacion_id = "FMI.WEO",
    url = url_datos,
    descripcion_archivo = "weo",
    extension = "json",
    contenido_crudo = contenido_crudo,
    codigo_http = codigo_http,
    fecha_publicacion = fecha_pub,
    periodo_referencia_max = as.character(anio_max),
    verificacion_forma = .weo_verificar_forma,
    notas_vintage = sprintf(
      paste(
        "Extracto de la base de datos del WEO vigente (G001, USA y SLV, todos sus indicadores,",
        "frecuencia anual) via %s. %d series, ultimo anio %d (incluye proyecciones; el WEO",
        "no marca por observacion que anios son estimacion). fecha_publicacion = %s, el",
        "PUBLICATION_DATE del dataset (atributo que trae attributes=all). COUNTRY_UPDATE_DATE por",
        "economia: %s. La url NO basta para reproducir esta respuesta: el formato lo decide el",
        "header Accept: application/vnd.sdmx.data+json (hallazgo M3 de la auditoria de Fase 2).",
        "La API sirve solo el WEO vigente: una edicion posterior reemplaza estos datos en la",
        "fuente, no en L0. Captura de Fase 6 (checklist C2)."
      ),
      url_datos, length(unique(tab$clave)), anio_max, fecha_pub, upd_txt
    )
  )
}

# --- Bloque 5: datos del capitulo 1 del WEO (Fase 6, C2, insumo de la ficha F6-14) ---
#
# Es el libro de datos de las figuras del capitulo 1 del informe (www.imf.org/-/media/...), no la
# base de datos de la API: por eso es una publicacion aparte (FMI.WEO.CAPITULO1), que ademas no
# colisiona en vintage_id con FMI.WEO. Trae los recuadros de escenarios que usa F6-14.
# fecha_publicacion = el Last-Modified que declara el servidor (2026-10-13 para octubre de 2026,
# el mismo dia del PUBLICATION_DATE de la base); si no viene, se detiene. robots.txt de
# www.imf.org no restringe la ruta (verificado el 2026-10-19). Una descarga por edicion.
.weo_cap1_url <- function(anio, mes_en) {
  sprintf("https://www.imf.org/-/media/files/publications/weo/%d/%s/english/data/ch1data.xlsx",
          as.integer(anio), tolower(mes_en))
}

.weo_cap1_perform <- function(url) {
  httr2::request(url) |>
    httr2::req_timeout(300) |>
    httr2::req_retry(max_tries = 3, backoff = function(i) 5 * i) |>
    httr2::req_perform()
}

.weo_cap1_verificar_forma <- function(contenido_crudo) {
  tmp <- tempfile(fileext = ".xlsx"); on.exit(unlink(tmp))
  writeBin(contenido_crudo, tmp)
  hojas <- tryCatch(readxl::excel_sheets(tmp), error = function(e) NULL)
  if (is.null(hojas) || !"Table of Contents" %in% hojas) return(FALSE)
  if (!any(grepl("^Figure 1\\.", hojas))) return(FALSE)
  grepl("WEO Chapter 1", hojas[1], fixed = TRUE)  # la portada se llama "<Mes> <anio> WEO Chapter 1"
}

# Fecha HTTP (RFC 7231, "Tue, 13 Oct 2026 18:06:08 GMT") -> "AAAA-MM-DD", sin depender del locale.
.fecha_http <- function(x) {
  m <- regmatches(x, regexec("^[A-Za-z]{3}, ([0-9]{2}) ([A-Za-z]{3}) ([0-9]{4}) ", x))[[1]]
  meses <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
  if (length(m) != 4 || !m[3] %in% meses) {
    stop("FALLO VISIBLE [FMI]: fecha HTTP no reconocida: '", x, "'.")
  }
  sprintf("%s-%02d-%s", m[4], match(m[3], meses), m[2])
}

descargar_fmi_weo_capitulo1 <- function(anio, mes_en) {
  url_datos <- .weo_cap1_url(anio, mes_en)
  resp <- .weo_cap1_perform(url_datos)
  codigo_http <- httr2::resp_status(resp)
  contenido_crudo <- httr2::resp_body_raw(resp)
  lm <- httr2::resp_header(resp, "last-modified")
  if (is.null(lm) || !nzchar(lm)) {
    stop("FALLO VISIBLE [FMI.WEO.CAPITULO1]: el servidor no declara Last-Modified; no se infiere ",
         "una fecha de publicacion. URL: ", url_datos)
  }
  fecha_pub <- .fecha_http(lm)
  if (!.weo_cap1_verificar_forma(contenido_crudo)) {
    stop("FALLO VISIBLE [FMI.WEO.CAPITULO1]: el libro no tiene la forma esperada (hoja 'Table of ",
         "Contents', hojas 'Figure 1.*' y primera hoja '... WEO Chapter 1'). URL: ", url_datos)
  }
  tmp <- tempfile(fileext = ".xlsx"); writeBin(contenido_crudo, tmp)
  hojas <- readxl::excel_sheets(tmp); unlink(tmp)

  registrar_descarga(
    fuente = "FMI",
    publicacion_id = "FMI.WEO.CAPITULO1",
    url = url_datos,
    descripcion_archivo = sprintf("weo_capitulo1_%d_%s", as.integer(anio), tolower(mes_en)),
    extension = "xlsx",
    contenido_crudo = contenido_crudo,
    codigo_http = codigo_http,
    fecha_publicacion = fecha_pub,
    periodo_referencia_max = "",  # libro de figuras con horizontes distintos por figura: vacio deliberado
    verificacion_forma = .weo_cap1_verificar_forma,
    notas_vintage = sprintf(
      paste(
        "Datos de las figuras del capitulo 1 del WEO (%s %d), %d hojas. fecha_publicacion = %s, del",
        "Last-Modified del servidor (%s). periodo_referencia_max vacio a proposito: cada figura tiene su",
        "horizonte. Insumo de la ficha F6-14 (escenario adverso). Captura de Fase 6 (checklist C2)."
      ),
      mes_en, as.integer(anio), length(hojas), fecha_pub, lm
    )
  )
}
