# cbo.R
#
# Adquisicion CBO (Congressional Budget Office de EE. UU.). Fase 6, checklist C1b/C2: el empleo
# asalariado no agricola de EE. UU. del escenario base sale de las proyecciones economicas de la
# CBO (F6-05-a de doc/metodologia/decisiones_fase6.md).
#
# CANAL. www.cbo.gov responde 403 con un desafio de DataDome («Please enable JS and disable any
# ad blocker») a un cliente HTTP sin navegador (verificado el 2026-10-19). Eso es un bloqueo de
# acceso automatizado y la regla 9 de CLAUDE.md prohibe evadirlo. El canal programatico es el
# repositorio publico de la propia CBO en GitHub, US-CBO/cbo-data, que publica las mismas
# proyecciones en CSV largo (date, variable, value, estimate_type) por vintage, con la CBO como
# autora y licencia de dominio publico (17 U.S.C. § 105, con renuncia mundial; LICENSE.md del
# repositorio). Su README declara que la fuente canonica sigue siendo
# https://www.cbo.gov/data/budget-economic-data.
#
# fecha_publicacion. El CSV no trae fecha. El vintage del repositorio va en el nombre del archivo
# (quarterly_AAAA-MM.csv) y es el mes del informe de la CBO del que sale. La fecha exacta del
# informe se pasa de forma explicita y se declara su origen en las notas (precedente:
# BCR.PIB_T.SERIE_RETROPOLADA_1990_2005.v2019-03). El script se detiene si el mes de la fecha
# no coincide con el del nombre del archivo.
#
# Falla de forma visible (regla 6 de CLAUDE.md).

library(httr2)
source("src/adquisicion/lib_adquisicion.R")

.CBO_REPO_RAW <- "https://raw.githubusercontent.com/US-CBO/cbo-data/main/"
.CBO_RUTA_TRIMESTRAL <- "data/economic/economic_projections/quarterly_%s.csv"

# Variables que el Ejercicio B necesita como minimo (F6-05-a y la ficha F6-15).
.CBO_VARIABLES_REQUERIDAS <- c("empl_payroll_nf", "real_gdp", "unemployment_rate")

.cbo_perform <- function(url) {
  httr2::request(url) |>
    httr2::req_timeout(120) |>
    httr2::req_retry(max_tries = 3, backoff = function(i) 2 * i) |>
    httr2::req_perform()
}

# La usa scripts/verificar_l0.R para volver a pedir la URL registrada; no registra nada.
.cbo_refetch <- function(url) httr2::resp_body_raw(.cbo_perform(url))

.cbo_tabla <- function(contenido_crudo) {
  utils::read.csv(text = rawToChar(contenido_crudo), stringsAsFactors = FALSE,
                  colClasses = c("character", "character", "numeric", "character"))
}

.cbo_verificar_forma <- function(contenido_crudo) {
  tab <- tryCatch(.cbo_tabla(contenido_crudo), error = function(e) NULL)
  if (is.null(tab) || nrow(tab) == 0) return(FALSE)
  if (!identical(names(tab), c("date", "variable", "value", "estimate_type"))) return(FALSE)
  if (!all(grepl("^[0-9]{4}q[1-4]$", tab$date))) return(FALSE)
  if (!all(tab$estimate_type %in% c("actual", "projected"))) return(FALSE)
  if (!all(.CBO_VARIABLES_REQUERIDAS %in% tab$variable)) return(FALSE)
  fin <- tapply(tab$date, tab$variable, max)
  all(fin[.CBO_VARIABLES_REQUERIDAS] >= "2031q4") && !anyNA(tab$value)
}

# vintage_cbo: "AAAA-MM" del nombre del archivo en US-CBO/cbo-data.
# fecha_informe: fecha ISO del informe de la CBO de ese vintage; fuente_fecha: de donde sale.
descargar_cbo_proyecciones_trimestrales <- function(vintage_cbo, fecha_informe, fuente_fecha) {
  if (!grepl("^[0-9]{4}-[0-9]{2}$", vintage_cbo)) {
    stop("FALLO VISIBLE [CBO]: vintage_cbo debe ser AAAA-MM (recibido: '", vintage_cbo, "').")
  }
  if (!identical(substr(fecha_informe, 1, 7), vintage_cbo)) {
    stop("FALLO VISIBLE [CBO]: la fecha del informe (", fecha_informe, ") no cae en el mes del ",
         "vintage del archivo (", vintage_cbo, "). Revisar a mano antes de capturar.")
  }
  if (!nzchar(fuente_fecha)) stop("FALLO VISIBLE [CBO]: falta declarar de donde sale fecha_informe.")

  url_datos <- paste0(.CBO_REPO_RAW, sprintf(.CBO_RUTA_TRIMESTRAL, vintage_cbo))
  resp <- .cbo_perform(url_datos)
  codigo_http <- httr2::resp_status(resp)
  contenido_crudo <- httr2::resp_body_raw(resp)

  if (!.cbo_verificar_forma(contenido_crudo)) {
    stop("FALLO VISIBLE [CBO.PROYECCIONES_ECONOMICAS]: el CSV no tiene la forma esperada ",
         "(columnas, fechas trimestrales, estimate_type o variables requeridas hasta 2031q4). ",
         "URL: ", url_datos)
  }
  tab <- .cbo_tabla(contenido_crudo)
  ult_actual <- max(tab$date[tab$estimate_type == "actual" & tab$variable == "empl_payroll_nf"])

  registrar_descarga(
    fuente = "CBO",
    publicacion_id = "CBO.PROYECCIONES_ECONOMICAS",
    url = url_datos,
    descripcion_archivo = paste0("proyecciones_economicas_trimestrales_", gsub("-", "_", vintage_cbo)),
    extension = "csv",
    contenido_crudo = contenido_crudo,
    codigo_http = codigo_http,
    fecha_publicacion = fecha_informe,
    periodo_referencia_max = max(tab$date),
    verificacion_forma = .cbo_verificar_forma,
    notas_vintage = sprintf(
      paste(
        "Proyecciones economicas trimestrales de la CBO, vintage %s del repositorio US-CBO/cbo-data",
        "(CSV largo; %d variables, %s a %s; empl_payroll_nf observado hasta %s). fecha_publicacion =",
        "%s, fecha del informe de origen declarada a mano: %s. Canal: GitHub de la propia CBO, porque",
        "www.cbo.gov bloquea el acceso automatizado con DataDome (regla 9; verificado el 2026-10-19).",
        "Dominio publico (17 U.S.C. 105; LICENSE.md del repositorio); se reconoce a la CBO como fuente",
        "(ADR-008, tramo de la CBO). Captura de Fase 6 (checklist C2)."
      ),
      vintage_cbo, length(unique(tab$variable)), min(tab$date), max(tab$date), ult_actual,
      fecha_informe, fuente_fecha
    )
  )
}
