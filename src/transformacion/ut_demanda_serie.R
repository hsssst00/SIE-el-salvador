# ut_demanda_serie.R
#
# Construye la serie larga de UT.DEMANDA_TOTAL_MENSUAL a partir de los 25 archivos
# ya registrados en L0 (data/L0_raw/, ver src/adquisicion/ut.R). Adelanto de Fase 3
# (transformacion) declarado - no pasa por 03_series.csv todavia (falta serie_id y
# el resto del esquema D1). Salida a data/L1_staging/, que por diseño de la senda
# (S7) no se versiona en Git - se versiona este script, no el resultado.
#
# Estructura real del CSV (diagnosticada 2026-08-26, no asumida de la vista
# embebida): 4 filas de metadata, luego encabezado "MES,,,GWH,," (6 columnas por
# celdas combinadas del Excel original: MES en col 1, GWH en col 4, resto vacias),
# luego filas de datos "Enero,,,337.88,,". El año se toma SIEMPRE del nombre del
# archivo (manifiesto), nunca del contenido - 2002/2003 tienen el campo interno
# "Año:" corrupto/con mojibake. Los nombres de mes en español no llevan tilde ni
# ñ, asi que esa corrupcion (limitada a la linea "Año:", que se descarta) no
# afecta ninguna celda de dato real - no hace falta resolver encoding para esto.

library(dplyr)

MESES_ES <- c("Enero"=1,"Febrero"=2,"Marzo"=3,"Abril"=4,"Mayo"=5,"Junio"=6,
              "Julio"=7,"Agosto"=8,"Septiembre"=9,"Octubre"=10,"Noviembre"=11,
              "Diciembre"=12)

parsear_archivo_ut <- function(ruta, anio) {
  lineas <- readLines(ruta, warn = FALSE)

  idx_header <- which(grepl("^MES,", lineas))
  if (length(idx_header) != 1) {
    stop("FALLO VISIBLE: ", basename(ruta), " - se esperaba exactamente 1 línea que",
         " empiece con 'MES,', se encontraron ", length(idx_header),
         ". La estructura de este archivo difiere de la diagnosticada - no asumir,",
         " revisar el archivo a mano antes de seguir.")
  }

  campos_header <- strsplit(lineas[idx_header], ",", fixed = TRUE)[[1]]
  if (length(campos_header) < 4 || trimws(campos_header[1]) != "MES" ||
      trimws(campos_header[4]) != "GWH") {
    stop("FALLO VISIBLE: ", basename(ruta), " - encabezado no coincide con el",
         " patrón esperado 'MES,,,GWH,,'. Encabezado real: '", lineas[idx_header], "'")
  }

  lineas_datos <- lineas[(idx_header + 1):length(lineas)]
  lineas_datos <- lineas_datos[nzchar(trimws(lineas_datos))]  # descarta líneas vacías al final, si las hay

  filas <- lapply(lineas_datos, function(l) {
    campos <- strsplit(l, ",", fixed = TRUE)[[1]]
    mes_txt <- trimws(campos[1])
    gwh_txt <- trimws(campos[4])
    mes_num <- MESES_ES[[mes_txt]]
    if (is.null(mes_num)) {
      stop("FALLO VISIBLE: ", basename(ruta), " - mes no reconocido: '", mes_txt, "'")
    }
    gwh_val <- suppressWarnings(as.numeric(gwh_txt))
    if (is.na(gwh_val)) {
      stop("FALLO VISIBLE: ", basename(ruta), " - GWH no numérico para ", mes_txt,
           ": '", gwh_txt, "'")
    }
    data.frame(anio = anio, mes = mes_num, gwh = gwh_val)
  })

  do.call(rbind, filas)
}

# Los 25 archivos viven en data/L0_raw/ con el nombre que registrar_descarga() les
# dio - patrón UT_demanda_total_{anio}_{fecha_descarga}.csv. Listar por año, no por
# fecha_descarga (que es la misma para los 25 - no sirve para distinguir).
archivos_l0 <- list.files("data/L0_raw", pattern = "^UT_demanda_total_.*\\.csv$",
                          full.names = TRUE)
if (length(archivos_l0) != 25) {
  stop("FALLO VISIBLE: se esperaban 25 archivos UT_demanda_total_*.csv en data/L0_raw/, ",
       "se encontraron ", length(archivos_l0), ". Confirmar antes de seguir.")
}

extraer_anio <- function(nombre) as.integer(regmatches(nombre, regexpr("[0-9]{4}", nombre)))

serie <- do.call(rbind, lapply(archivos_l0, function(ruta) {
  anio <- extraer_anio(basename(ruta))
  parsear_archivo_ut(ruta, anio)
}))

serie <- serie[order(serie$anio, serie$mes), ]
serie$periodo <- sprintf("%d-M%02d", serie$anio, serie$mes)
serie <- serie[, c("anio", "mes", "periodo", "gwh")]

# --- Validaciones (fallar de forma visible, no advertir) ---
n_esperado <- 24 * 12 + 7  # 2002-2025 completos + 2026 parcial (ene-jul)
if (nrow(serie) != n_esperado) {
  stop("FALLO VISIBLE: se esperaban ", n_esperado, " filas, se obtuvieron ", nrow(serie))
}
dup <- serie[duplicated(serie[, c("anio", "mes")]), ]
if (nrow(dup) > 0) {
  stop("FALLO VISIBLE: períodos duplicados encontrados:\n", paste(capture.output(print(dup)), collapse = "\n"))
}
conteo_por_anio <- table(serie$anio)
anios_incompletos <- conteo_por_anio[names(conteo_por_anio) != "2026" & conteo_por_anio != 12]
if (length(anios_incompletos) > 0) {
  stop("FALLO VISIBLE: años que deberían tener 12 meses y no los tienen:\n",
       paste(capture.output(print(anios_incompletos)), collapse = "\n"))
}
if (conteo_por_anio[["2026"]] != 7) {
  stop("FALLO VISIBLE: 2026 debería tener 7 meses (ene-jul), tiene ", conteo_por_anio[["2026"]])
}

dir.create("data/L1_staging", showWarnings = FALSE, recursive = TRUE)
write.csv(serie, "data/L1_staging/UT_DEMANDA_TOTAL_MENSUAL.csv", row.names = FALSE)

cat("OK:", nrow(serie), "filas,", min(serie$anio), "-", max(serie$anio),
    "-> data/L1_staging/UT_DEMANDA_TOTAL_MENSUAL.csv\n")
