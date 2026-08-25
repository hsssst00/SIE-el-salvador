# calendario_bcr_extraer.R
#
# PROVISIONAL — pendiente de decisión de Harold sobre dónde vive el resultado
# (L0 como publicación propia BCR.CALENDARIO_DIVULGACION, vs. doc/ como
# metadata operativa). Este script solo hace el parseo; no escribe todavía a
# ninguna ruta definitiva del repo.
#
# Convierte calendario-anticipado.xlsx (descarga directa del BCR, botón
# "Exportar" de https://estadisticas.bcr.gob.sv/calendario-de-divulgacion) de
# formato ancho (variable x mes-columna, celda "DD\n(MES.AA)" o "DD\n(Tn-AA)")
# a formato largo: una fila por (variable, mes de publicación).
#
# Semántica de cada celda, confirmada por inspección directa del archivo
# (2026-08-25): el MES de la columna es el mes en que se PUBLICA; el DÍA es
# el día de publicación dentro de ese mes; el paréntesis es el PERÍODO DE
# REFERENCIA que el dato publicado cubre (mes o trimestre), no la fecha de
# publicación. Son cosas distintas — igual que fecha_descarga vs
# fecha_publicacion ya distintas en el manifiesto de L0 (senda §3.1).
#
# OJO — esto es la fecha ANUNCIADA, no la fecha REAL de publicación. No debe
# usarse para llenar fecha_publicacion en registrar_descarga(): ese campo
# exige la fecha que la fuente declara en el momento real de la captura
# (ver lib_adquisicion.R). El uso legítimo de este calendario es decidir
# CUÁNDO intentar una captura, no QUÉ fecha declarar una vez capturada.

library(readxl)
library(stringr)

extraer_calendario_bcr <- function(ruta_xlsx) {
  hoja <- read_excel(ruta_xlsx, col_names = FALSE, .name_repair = "minimal")
  
  # Fila 4 (índice 1-based de readxl): encabezados de mes en columnas B:E
  meses_col <- as.character(hoja[4, 2:5])
  letras_col <- c("B", "C", "D", "E")
  
  # Filas de encabezado de sección (fusionadas A:E en el xlsx original;
  # readxl las lee como texto en A, NA en el resto de la fila)
  es_fila_seccion <- function(fila) {
    !is.na(fila[[1]]) && all(is.na(fila[2:5]))
  }
  
  MESES_ABREV <- c(Ene=1, Feb=2, Mar=3, Abr=4, May=5, Jun=6,
                   Jul=7, Ago=8, Sep=9, Oct=10, Nov=11, Dic=12)
  
  patron_mensual  <- "^(\\d{1,2})\\n\\(([A-Za-z]{3})\\.(\\d{2})\\)$"
  patron_trimestral <- "^(\\d{1,2})\\n\\(T(\\d)-(\\d{2})\\)$"
  
  seccion_actual <- NA_character_
  registros <- list()
  
  # Datos empiezan en la fila 5 (1-based) = fila 5 del xlsx original
  for (i in 5:nrow(hoja)) {
    fila <- hoja[i, ]
    variable <- fila[[1]]
    if (is.na(variable)) next
    
    if (es_fila_seccion(fila)) {
      seccion_actual <- variable
      next
    }
    
    for (j in seq_along(letras_col)) {
      valor <- fila[[j + 1]]
      if (is.na(valor)) next
      valor <- as.character(valor)
      
      m_mensual <- str_match(valor, patron_mensual)
      m_trim <- str_match(valor, patron_trimestral)
      
      if (!is.na(m_mensual[1, 1])) {
        dia <- as.integer(m_mensual[1, 2])
        mes_ref_abrev <- m_mensual[1, 3]
        anio_ref <- as.integer(m_mensual[1, 4])
        registros[[length(registros) + 1]] <- data.frame(
          seccion = seccion_actual,
          variable = variable,
          mes_publicacion = meses_col[j],
          dia_publicacion = dia,
          tipo_referencia = "mensual",
          periodo_referencia = sprintf("20%02d-%02d", anio_ref, MESES_ABREV[[mes_ref_abrev]]),
          stringsAsFactors = FALSE
        )
      } else if (!is.na(m_trim[1, 1])) {
        dia <- as.integer(m_trim[1, 2])
        trimestre <- m_trim[1, 3]
        anio_ref <- as.integer(m_trim[1, 4])
        registros[[length(registros) + 1]] <- data.frame(
          seccion = seccion_actual,
          variable = variable,
          mes_publicacion = meses_col[j],
          dia_publicacion = dia,
          tipo_referencia = "trimestral",
          periodo_referencia = sprintf("20%02d-T%s", anio_ref, trimestre),
          stringsAsFactors = FALSE
        )
      } else {
        stop("FALLO VISIBLE: celda no reconoce el patrón esperado (DD\\n(MES.AA) o ",
             "DD\\n(Tn-AA)). Variable: '", variable, "', columna: ", letras_col[j],
             ", valor crudo: '", valor, "'. No se ignora en silencio - revisar si el ",
             "formato del calendario cambió respecto de esta versión (2026-08-25).")
      }
    }
  }
  
  do.call(rbind, registros)
}

# Uso:
# tabla <- extraer_calendario_bcr("calendario-anticipado.xlsx")
# write.csv(tabla, "calendario_bcr_largo.csv", row.names = FALSE)