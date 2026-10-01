# ut.R
#
# Registro en L0 de UT.DEMANDA_TOTAL_MENSUAL: un CSV por año, descargado MANUALMENTE por Harold
# del formulario de Reportes Estadísticos de UT. Captura sujeta a la Regla 9 de CLAUDE.md (sin
# scraping desatendido - robots.txt de ut.com.sv lo prohibe, verificado con polite::scrape() en
# verificar_robots_ut.R). No hace ningun fetch en vivo: registrar_ut_demanda_anual() recibe un
# archivo ya bajado, mismo patron que la captura manual de BCR.PIB_T.SERIE_RETROPOLADA_1990_2005.
#
# CAPTURA TRIMESTRAL (ADR-007, nota de seguimiento del 2026-09-30; procedimiento en
# doc/backlog_captura_vintages.md). Las ventanas son enero, abril, julio y octubre, y en cada una
# se baja el año en curso mas todos los años anteriores que en L0 todavia no llegan a diciembre.
# Los años que ya llegan a diciembre no se vuelven a bajar: una revision de un año cerrado no se
# detecta (limite declarado). Por cada archivo, registrar_ut_demanda_anual() decide entre tres
# resultados:
#   1. mismos meses y valores que el ultimo vintage de ese año en L0 -> NO registra nada, informa;
#   2. contenido distinto -> vintage nuevo, con fecha_publicacion sintetica = ultimo dia del
#      periodo_referencia_max (que sale del CONTENIDO: el ultimo mes con dato);
#   3. contenido distinto pero ese vintage_id ya existe (archivo revisado sin meses nuevos) ->
#      vintage nuevo con la fecha de captura como fecha_publicacion y el motivo en notas_vintage.
# "Mismo contenido" es mismos meses y mismos GWH, no el hash del archivo: cada CSV de UT trae
# "Fecha y hora del Reporte" con precision de minuto, asi que su hash cambia en cada descarga
# (decision de Harold, 2026-09-30).
#
# Alcance: 1998-2001 quedan fuera (ningun formato de archivo los exporta - ver
# catalogos/01_publicaciones/UT.DEMANDA_TOTAL_MENSUAL.yaml). Decision pendiente
# de Harold, no se resuelve aca.

source(here::here("src", "adquisicion", "lib_adquisicion.R"))
source(here::here("src", "transformacion", "vintage_lib.R"))
source(here::here("src", "transformacion", "ut_demanda_lib.R"))

URL_UT_DEMANDA <- "https://www.ut.com.sv/reportes?p_p_id=MenuReportesEstadisticosPublicReports_WAR_PublicReports&p_p_lifecycle=1&p_p_state=normal&p_p_mode=view&_MenuReportesEstadisticosPublicReports_WAR_PublicReports_reportName=14utdemtotal"

# Registra el CSV anual de UT de `anio` ya bajado en `ruta_archivo_local`. `fecha_captura` es el
# dia real en que Harold lo bajo (por defecto hoy); solo se usa como fecha_publicacion en el
# caso 3 de arriba, y para avisar si el año quedo sin diciembre.
#
# fecha_publicacion SINTETICA, no real: registrar_descarga() deriva vintage_id de
# substr(fecha_publicacion, 1, 7) (año-mes). No hay un calendario de divulgacion de UT del cual
# derivar una fecha_publicacion real por archivo (a diferencia del BCR), asi que se usa el
# ultimo dia del periodo_referencia_max -- la regla de los 25 vintages de la captura del
# 2026-08-26 (31-dic para un año completo, 31-jul para 2026 con datos hasta julio), generalizada
# a "fin del ultimo mes con dato". La fecha real de captura queda intacta en fecha_descarga del
# manifiesto. Decision de Harold, 2026-08-26 (colision de vintage_id) y 2026-09-30 (generalizacion).
registrar_ut_demanda_anual <- function(ruta_archivo_local, anio, fecha_captura = Sys.Date()) {
  anio <- as.integer(anio)
  fecha_captura <- as.Date(fecha_captura)
  contenido <- readBin(ruta_archivo_local, "raw", n = file.info(ruta_archivo_local)$size)

  # El año viene del nombre/argumento, nunca de un supuesto: si el archivo declara OTRO año en su
  # campo interno, se bajo el archivo equivocado y registrarlo contaminaria el año `anio`.
  # 2002 y 2003 traen ese campo vacio o corrupto (anio_interno_ut() devuelve NA) y no se miran.
  interno <- anio_interno_ut(ruta_archivo_local)
  if (!is.na(interno) && interno != anio) {
    stop("FALLO VISIBLE [", PUBLICACION_UT, "]: se pidio registrar ", basename(ruta_archivo_local),
         " como el año ", anio, ", pero su campo 'Año' interno dice ", interno, ". Se bajo el ",
         "archivo equivocado: no se registra nada.")
  }

  nuevo <- leer_ut_anual(ruta_archivo_local, anio)
  mes_max <- max(nuevo$mes)
  periodo_max <- ut_periodo_max(anio, mes_max)
  fecha_sintetica <- ut_fecha_sintetica(anio, mes_max)

  vintages <- leer_vintages(ruta_vintages)
  mapa <- if (any(vintages$publicacion_id == PUBLICACION_UT)) {
    mapa_vintage_por_anio(PUBLICACION_UT, vintages)
  } else {
    character(0)
  }
  vid_previo <- if (as.character(anio) %in% names(mapa)) mapa[[as.character(anio)]] else NA_character_

  if (!is.na(vid_previo)) {
    archivo_previo <- vintages$archivo_raw[vintages$vintage_id == vid_previo]
    ruta_previo <- file.path(dir_l0, archivo_previo)
    if (!file.exists(ruta_previo)) {
      stop("FALLO VISIBLE [", PUBLICACION_UT, "]: no se puede comparar con el vintage previo del ",
           "año ", anio, " ('", vid_previo, "') porque ", ruta_previo, " no esta en L0. Repoblar ",
           "L0 con `make materializar-l0` y repetir; no se registra nada.")
    }
    previo <- leer_ut_anual(ruta_previo, anio)

    # Caso 1: mismos meses y valores -> no se registra, se informa. Va ANTES de cualquier
    # escritura, igual que el retorno temprano de "sin cambios" de registrar_descarga().
    if (ut_contenido_igual(nuevo, previo)) {
      message("Sin cambios respecto del vintage vigente del año ", anio, " ('", vid_previo,
              "', hasta ", ut_periodo_max(anio, max(previo$mes)), "): mismos meses y valores GWH. ",
              "No se registra archivo ni vintage nuevo.")
      return(invisible(list(
        vintage_nuevo = FALSE,
        vintage_previo = vid_previo,
        mensaje = paste0("verificado, mismo contenido que ", vid_previo)
      )))
    }

    # Un archivo con MENOS meses que el vigente no es una recaptura sino un retroceso (archivo
    # viejo, descarga a medias): registrarlo achicaria la serie sin que nada lo avise. Falla; si
    # UT realmente retiro meses, eso se resuelve a mano (regla 4 de CLAUDE.md).
    if (mes_max < max(previo$mes)) {
      stop("FALLO VISIBLE [", PUBLICACION_UT, "]: el archivo del año ", anio, " llega hasta ",
           periodo_max, " y el vintage vigente ('", vid_previo, "') llega hasta ",
           ut_periodo_max(anio, max(previo$mes)), ". Una recaptura con menos meses es un ",
           "retroceso, no una revision: no se registra nada. Si UT retiro meses de verdad, ",
           "resolver a mano.")
    }
  }

  # Caso 3: el vintage_id derivado ya existe (p.ej. archivo revisado sin meses nuevos). Se usa la
  # fecha de captura y se deja el motivo. Si el id derivado de la fecha de captura TAMBIEN existe,
  # registrar_descarga() se detiene por colision: dos revisiones en el mismo mes no caben en la
  # convencion de vintage_id (ADR-007, nota 2026-08-20) y se resuelve a mano.
  vintage_derivado <- paste0(PUBLICACION_UT, ".v", substr(fecha_sintetica, 1, 7))
  colision <- vintage_derivado %in% vintages$vintage_id
  fecha_publicacion <- if (colision) as.character(fecha_captura) else fecha_sintetica
  nota_colision <- if (colision) {
    sprintf(paste(
      "El vintage_id derivado del periodo_referencia_max (%s) ya existe en este catálogo",
      "(archivo revisado sin meses nuevos): se usa la fecha de captura (%s) como",
      "fecha_publicacion para no colisionar."), vintage_derivado, fecha_publicacion)
  } else {
    ""
  }

  # OJO con el texto de esta nota: NO debe parecerse al literal centinela que
  # registrar_descarga() escribe en alcance_revision ("primera captura — sin vintage previo
  # con el cual comparar", con raya larga U+2014). Ese literal es el mecanismo de deteccion
  # de deriva del proyecto (src/adquisicion/README.md S3) y una cadena casi identica en otra
  # columna estropea cualquier busqueda por texto. Hasta el 2026-08-28 esta rama escribia
  # justamente eso, con guion simple y punto final (hallazgo L5 de la auditoria de Fase 2).
  nota_anio <- if (anio <= 2003L) {
    "Advertencia: el campo 'Año' interno de este archivo está vacío o corrupto - el año se identificó por el nombre del archivo, no por el contenido."
  } else if (!is.na(interno)) {
    "El campo 'Año' interno del archivo coincide con el año registrado."
  } else {
    "El campo 'Año' interno del archivo no se pudo leer; el año se identificó por el nombre del archivo."
  }

  res <- registrar_descarga(
    fuente = "UT",
    publicacion_id = PUBLICACION_UT,
    url = URL_UT_DEMANDA,
    descripcion_archivo = sprintf("demanda_total_%d", anio),
    extension = "csv",
    contenido_crudo = contenido,
    codigo_http = 200L,
    fecha_publicacion = fecha_publicacion,
    periodo_referencia_max = periodo_max,
    verificacion_forma = NULL,
    notas_vintage = paste(
      sprintf(paste(
        "Captura manual (Regla 9 - robots.txt de ut.com.sv no permite scraping,",
        "verificado con polite::scrape() el 2026-08-26, ver",
        "src/adquisicion/verificar_robots_ut.R). Archivo descargado por Harold desde",
        "el formulario de Reportes Estadísticos de UT, salida CSV, año %d, con datos",
        "hasta %s (periodo_referencia_max, leído del contenido del archivo; captura",
        "%s). fecha_publicacion (%s) es SINTÉTICA, NO una fecha real de publicación",
        "de UT: es el último día del mes de periodo_referencia_max, misma regla de los",
        "25 vintages anuales de la captura del 2026-08-26, generalizada (ADR-007, nota",
        "del 2026-09-30). No existe un calendario de divulgación de UT del cual derivar",
        "una fecha_publicacion real, a diferencia de las series del BCR."),
        anio, periodo_max, as.character(fecha_captura), fecha_publicacion),
      nota_colision, nota_anio)
  )

  if (isTRUE(res$vintage_nuevo) && mes_max < 12L && anio < as.integer(format(fecha_captura, "%Y"))) {
    message("AVISO: el año ", anio, " es anterior al de la captura y queda sin diciembre (último ",
            "mes con dato: ", mes_max, "). Se retoma en la próxima ventana trimestral; hasta ",
            "entonces la L3 de UT se detendrá si hay un año posterior con datos.")
  }
  invisible(res)
}

# Lote de archivos anuales de una captura. Es una FUNCION, no codigo suelto (hallazgo L2 de la
# auditoria de Fase 2, 2026-08-28): hasta esa fecha el lazo corria al hacer source() de este
# archivo y con la ruta de descargas de Harold escrita a mano, de modo que abrir el script para
# leerlo o cargar registrar_ut_demanda_anual() disparaba una captura. Ahora hay que llamarla, y el
# directorio es argumento.
#
# Espera un archivo `{año}.csv` por cada año de `anios`, y los comprueba TODOS antes de registrar
# ninguno. El default 2002:2026 es el de la captura original; en una ventana trimestral se pasan
# los años que toca bajar, p.ej. registrar_ut_demanda_lote(dir, anios = c(2026L, 2027L)).
#
# La corrida real que produjo los 25 vintages del manifiesto fue:
#   source("src/adquisicion/ut.R"); registrar_ut_demanda_lote("C:/Users/harold/Downloads/total")
# Re-ejecutarla hoy ya no escribe nada: cada año da "sin cambios" (mismo contenido que su vintage
# vigente), que es el comportamiento correcto.
registrar_ut_demanda_lote <- function(directorio_ut, anios = 2002:2026, fecha_captura = Sys.Date()) {
  rutas <- file.path(directorio_ut, sprintf("%d.csv", anios))
  faltantes <- rutas[!file.exists(rutas)]
  if (length(faltantes) > 0) {
    stop("FALLO VISIBLE: no se encontraron ", length(faltantes), " de ", length(rutas),
         " archivo(s) esperados en '", directorio_ut, "': ",
         paste(basename(faltantes), collapse = ", "),
         ". Se comprueban TODOS antes de registrar ninguno, para no dejar el lote a medias.")
  }
  invisible(lapply(seq_along(anios), function(i) {
    registrar_ut_demanda_anual(rutas[i], anios[i], fecha_captura = fecha_captura)
  }))
}
