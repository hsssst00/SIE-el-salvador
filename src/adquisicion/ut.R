# ut.R
#
# Registro en L0 de UT.DEMANDA_TOTAL_MENSUAL: 25 archivos CSV ya descargados
# manualmente por Harold (2002.csv-2026.csv), captura puntual sujeta a la Regla 9
# de CLAUDE.md (sin scraping desatendido - robots.txt de ut.com.sv lo prohibe,
# verificado con polite::scrape() en verificar_robots_ut.R). No hace ningun
# fetch en vivo: registrar_ut_demanda_anual() recibe los bytes ya obtenidos,
# mismo patron que la captura manual de BCR.PIB_T.SERIE_RETROPOLADA_1990_2005.
#
# Alcance: 1998-2001 quedan fuera (ningun formato de archivo los exporta - ver
# catalogos/01_publicaciones/UT.DEMANDA_TOTAL_MENSUAL.yaml). Decision pendiente
# de Harold, no se resuelve aca.

source("src/adquisicion/lib_adquisicion.R")

# fecha_publicacion SINTETICA, no real: registrar_descarga() deriva vintage_id de
# substr(fecha_publicacion, 1, 7) (año-mes). Los 25 archivos se capturaron el mismo
# dia real (2026-08-26); si se pasara esa misma fecha para los 25, los 25
# colisionarian en el mismo vintage_id (Paso 3b de lib_adquisicion.R esta escrito
# para fallar, no para permitir, esa colision). No hay un calendario de divulgacion
# de UT del cual derivar una fecha_publicacion real por año (a diferencia del BCR),
# asi que se usa una fecha sintetica distinta por año -  el 31 de diciembre de ese
# año para años completos, el 31 de julio de 2026 para el año parcial - unicamente
# para dar a cada archivo un vintage_id distinto. La fecha real de captura (2026-08-26)
# queda intacta en fecha_descarga del manifiesto para los 25. Decision de Harold,
# 2026-08-26, en respuesta al bloqueo de colision reportado por Claude Code.
registrar_ut_demanda_anual <- function(ruta_archivo_local, anio) {
  contenido <- readBin(ruta_archivo_local, "raw", n = file.info(ruta_archivo_local)$size)

  periodo_max <- if (anio == 2026L) "2026-M07" else sprintf("%d-M12", anio)
  fecha_publicacion_sintetica <- if (anio == 2026L) "2026-07-31" else sprintf("%d-12-31", anio)

  # OJO con el texto de esta nota: NO debe parecerse al literal centinela que
  # registrar_descarga() escribe en alcance_revision ("primera captura — sin vintage previo
  # con el cual comparar", con raya larga U+2014). Ese literal es el mecanismo de deteccion
  # de deriva del proyecto (src/adquisicion/README.md S3) y una cadena casi identica en otra
  # columna estropea cualquier busqueda por texto. Hasta el 2026-08-28 esta rama escribia
  # justamente eso, con guion simple y punto final (hallazgo L5 de la auditoria de Fase 2).
  nota_anio <- if (anio <= 2003L) {
    "Advertencia: el campo 'Año' interno de este archivo está vacío o corrupto - el año se identificó por el nombre del archivo, no por el contenido."
  } else {
    "Sin anomalías en el campo 'Año' interno del archivo."
  }

  registrar_descarga(
    fuente = "UT",
    publicacion_id = "UT.DEMANDA_TOTAL_MENSUAL",
    url = "https://www.ut.com.sv/reportes?p_p_id=MenuReportesEstadisticosPublicReports_WAR_PublicReports&p_p_lifecycle=1&p_p_state=normal&p_p_mode=view&_MenuReportesEstadisticosPublicReports_WAR_PublicReports_reportName=14utdemtotal",
    descripcion_archivo = sprintf("demanda_total_%d", anio),
    extension = "csv",
    contenido_crudo = contenido,
    codigo_http = 200L,
    fecha_publicacion = fecha_publicacion_sintetica,
    periodo_referencia_max = periodo_max,
    verificacion_forma = NULL,
    notas_vintage = sprintf(
      paste(
        "Captura manual (Regla 9 - robots.txt de ut.com.sv no permite scraping,",
        "verificado con polite::scrape() el 2026-08-26, ver",
        "src/adquisicion/verificar_robots_ut.R). Archivo descargado por Harold desde",
        "el formulario de Reportes Estadísticos de UT, salida CSV, año %d.",
        "fecha_publicacion (%s) es SINTÉTICA, NO una fecha real de publicación de UT",
        "ni la fecha real de esta captura - los 25 archivos (2002-2026) se descargaron",
        "el mismo día real (2026-08-26, ver fecha_descarga en el manifiesto). Se usa",
        "una fecha sintética distinta por año (31 de diciembre del año, o 31 de julio",
        "para 2026 por ser parcial) únicamente para que vintage_id -derivado de",
        "año-mes de fecha_publicacion en registrar_descarga()- no colisione entre los",
        "25 archivos. No existe un calendario de divulgación de UT del cual derivar",
        "una fecha_publicacion real, a diferencia de las series del BCR. Decisión de",
        "Harold, 2026-08-26, en respuesta a un bloqueo de colisión de vintage_id",
        "reportado por Claude Code al ejecutar este handoff. %s"
      ),
      anio, fecha_publicacion_sintetica, nota_anio
    )
  )
}

# Lote completo 2002-2026. Es una FUNCION, no codigo suelto (hallazgo L2 de la auditoria de
# Fase 2, 2026-08-28): hasta esa fecha el lazo corria al hacer source() de este archivo y con
# la ruta de descargas de Harold escrita a mano, de modo que abrir el script para leerlo o
# cargar registrar_ut_demanda_anual() disparaba una captura. Ahora hay que llamarla, y el
# directorio es argumento.
#
# La corrida real que produjo los 25 vintages del manifiesto fue:
#   source("src/adquisicion/ut.R"); registrar_ut_demanda_lote("C:/Users/harold/Downloads/total")
# Re-ejecutarla hoy falla en el paso 4 de registrar_descarga() (el archivo de L0 ya existe,
# regla 1: nunca se sobrescribe), que es el comportamiento correcto.
registrar_ut_demanda_lote <- function(directorio_ut, anios = 2002:2026) {
  rutas <- file.path(directorio_ut, sprintf("%d.csv", anios))
  faltantes <- rutas[!file.exists(rutas)]
  if (length(faltantes) > 0) {
    stop("FALLO VISIBLE: no se encontraron ", length(faltantes), " de ", length(rutas),
         " archivo(s) esperados en '", directorio_ut, "': ",
         paste(basename(faltantes), collapse = ", "),
         ". Se comprueban TODOS antes de registrar ninguno, para no dejar el lote a medias.")
  }
  invisible(lapply(seq_along(anios), function(i) registrar_ut_demanda_anual(rutas[i], anios[i])))
}
