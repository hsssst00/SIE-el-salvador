# ut_demanda_lib.R
#
# Funciones de UT.DEMANDA_TOTAL_MENSUAL compartidas por la captura (src/adquisicion/ut.R) y la
# construcción de la serie larga (src/transformacion/ut_demanda_serie.R). Separadas de ese script
# el 2026-09-30 para que el registro de un archivo recapturado lea el CSV con el MISMO parser que
# lo lee el extractor, y para que las pruebas las ejerzan con archivos sintéticos sin correr el
# script (que, al hacer source(), escribe en data/L1_staging/).
#
# Estructura real del CSV (diagnosticada 2026-08-26, no asumida de la vista embebida): 4 filas de
# metadata, luego encabezado "MES,,,GWH,," (6 columnas por celdas combinadas del Excel original:
# MES en col 1, GWH en col 4, resto vacías), luego filas de datos "Enero,,,337.88,,". El año se
# toma SIEMPRE del nombre del archivo, nunca del contenido: 2002/2003 tienen el campo interno
# "Año:" corrupto o vacío. La cuarta fila trae además "Fecha y hora del Reporte" (precisión de
# minuto), que cambia en cada descarga: por eso la identidad de un archivo se juzga por sus
# meses y valores, no por su hash (decisión de Harold, 2026-09-30).
#
# La serie que se construye admite recapturas: un mismo año puede tener varios vintages en
# 08_vintages.csv, y cuenta el último registrado de cada año (mapa_vintage_por_anio()). Qué es
# "completo" no se escribe acá: se deriva del catálogo (12 meses por año anterior al máximo; para
# el año máximo, los meses de su periodo_referencia_max).

PUBLICACION_UT <- "UT.DEMANDA_TOTAL_MENSUAL"

MESES_ES <- c("Enero"=1,"Febrero"=2,"Marzo"=3,"Abril"=4,"Mayo"=5,"Junio"=6,
              "Julio"=7,"Agosto"=8,"Septiembre"=9,"Octubre"=10,"Noviembre"=11,
              "Diciembre"=12)

#' Lee un CSV anual de UT. Devuelve data.frame(anio, mes, gwh), posiblemente de cero filas si el
#' archivo trae el encabezado y ningún mes. Falla visible ante cualquier desvío de la estructura
#' diagnosticada: no asume, no corrige.
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

  lineas_datos <- if (idx_header < length(lineas)) lineas[(idx_header + 1):length(lineas)] else character(0)
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

  if (length(filas) == 0) return(data.frame(anio = integer(0), mes = integer(0), gwh = numeric(0)))
  do.call(rbind, filas)
}

#' Año que el propio archivo declara en su campo "Año: NNNN" (antes del encabezado de datos), o NA
#' si no lo trae legible. 2002 y 2003 lo tienen vacío o corrupto; de 2004 en adelante coincide con
#' el año del nombre en los 23 archivos de la captura del 2026-08-26.
anio_interno_ut <- function(ruta) {
  lineas <- readLines(ruta, warn = FALSE)
  idx_header <- which(grepl("^MES,", lineas))
  previas <- if (length(idx_header) >= 1) lineas[seq_len(idx_header[1] - 1)] else lineas
  m <- regmatches(previas, regexpr(": *[0-9]{4}\\b", previas, useBytes = TRUE))
  if (length(m) != 1) return(NA_integer_)
  as.integer(sub("^: *", "", m))
}

#' Lee un CSV anual y exige lo que toda serie mensual de un año necesita para que su
#' `periodo_referencia_max` signifique algo: al menos un mes, y los meses presentes son
#' exactamente enero..mes_max, sin huecos ni repetidos. Devuelve data.frame(anio, mes, gwh).
leer_ut_anual <- function(ruta, anio) {
  d <- parsear_archivo_ut(ruta, anio)
  if (nrow(d) == 0) {
    stop("FALLO VISIBLE: ", basename(ruta), " - el archivo no trae ningún mes con dato. ",
         "En la ventana de enero el año en curso aún no tiene datos y se omite, no se registra.")
  }
  d$mes <- as.integer(d$mes)  # MESES_ES es numerico (double); seq_len() devuelve entero
  if (!identical(sort(d$mes), seq_len(max(d$mes)))) {
    stop("FALLO VISIBLE: ", basename(ruta), " - los meses con dato no son enero..",
         names(MESES_ES)[max(d$mes)], " sin huecos ni repetidos (meses presentes: ",
         paste(d$mes, collapse = ", "), "). Un periodo_referencia_max sobre un año con huecos ",
         "no describe lo que hay en el archivo.")
  }
  d[order(d$mes), ]
}

#' "AAAA-Mnn" del último mes con dato -- el formato de `periodo_referencia_max` de 08_vintages.csv.
ut_periodo_max <- function(anio, mes) sprintf("%d-M%02d", as.integer(anio), as.integer(mes))

#' `fecha_publicacion` sintética de un vintage de UT: el ÚLTIMO DÍA del mes de su
#' `periodo_referencia_max`. Es la regla de los 25 vintages de la captura del 2026-08-26
#' (31-dic para un año completo, 31-jul para 2026 con datos hasta julio), generalizada.
ut_fecha_sintetica <- function(anio, mes) {
  primero <- as.Date(sprintf("%d-%02d-01", as.integer(anio), as.integer(mes)))
  as.character(seq(primero, by = "month", length.out = 2)[2] - 1)
}

#' ¿Dos lecturas de un mismo año (data.frame(anio, mes, gwh)) son el mismo dato? Mismos meses y
#' mismos valores GWH; no mira nada del encabezado, así que la hora del reporte o el estilo de fin
#' de línea no hacen "distintos" a dos archivos con los mismos números.
ut_contenido_igual <- function(a, b) {
  a <- a[order(a$mes), ]
  b <- b[order(b$mes), ]
  nrow(a) == nrow(b) && all(a$mes == b$mes) && all(a$gwh == b$gwh)
}

#' Mes (1-12) de un `periodo_referencia_max` "AAAA-Mnn". Falla visible si no tiene ese formato.
mes_de_periodo_max <- function(periodo_max) {
  m <- regmatches(periodo_max, regexec("^[0-9]{4}-M([0-9]{2})$", periodo_max))
  ok <- lengths(m) == 2
  if (!all(ok)) {
    stop("FALLO VISIBLE: periodo_referencia_max '", paste(periodo_max[!ok], collapse = "', '"),
         "' no tiene el formato AAAA-Mnn de las publicaciones mensuales por año.")
  }
  mes <- as.integer(vapply(m, `[`, character(1), 2))
  if (any(mes < 1 | mes > 12)) {
    stop("FALLO VISIBLE: periodo_referencia_max '", paste(periodo_max[mes < 1 | mes > 12], collapse = "', '"),
         "' tiene un mes fuera de 1..12.")
  }
  mes
}

#' Meses esperados por año (vector entero nombrado por año), DERIVADOS del catálogo de vintages:
#' 12 para todo año anterior al máximo y, para el año máximo, el mes de su
#' `periodo_referencia_max`. `mapa` es el vector año -> vintage_id de mapa_vintage_por_anio().
#' Pura.
ut_meses_esperados <- function(mapa, vintages) {
  anios <- as.integer(names(mapa))
  anio_max <- max(anios)
  fila <- match(mapa, vintages$vintage_id)
  if (anyNA(fila)) {
    stop("FALLO VISIBLE: vintage(s) del mapa sin fila en 08_vintages.csv: ",
         paste(mapa[is.na(fila)], collapse = ", "))
  }
  mes_vintage <- mes_de_periodo_max(vintages$periodo_referencia_max[fila])
  esperado <- ifelse(anios < anio_max, 12L, mes_vintage)
  setNames(as.integer(esperado), names(mapa))
}

#' Guarda de año completo: todo año ANTERIOR al máximo de `periodos` ("AAAA-Mnn") trae sus 12
#' meses. El año máximo puede ser parcial. Falla visible, no advierte (regla 7 de CLAUDE.md). La
#' usan el extractor de L1 y la L3 de predictores, para que un L1 viejo o armado a mano no pase a
#' la matriz con un año anterior a medias.
validar_anios_cerrados_ut <- function(periodos, etiqueta = "UT.DEMANDA_ELEC.GWH.NSA.M") {
  anio <- substr(periodos, 1, 4)
  n_meses <- tapply(periodos, anio, function(p) length(unique(p)))
  anio_max <- max(as.integer(names(n_meses)))
  incompletos <- n_meses[as.integer(names(n_meses)) < anio_max & n_meses != 12]
  if (length(incompletos) > 0) {
    stop("FALLO VISIBLE [", etiqueta, "]: años anteriores al máximo (", anio_max, ") que deberían ",
         "tener 12 meses y no los tienen: ",
         paste0(names(incompletos), " (", incompletos, ")", collapse = ", "),
         ". Falta bajar y registrar el resto del año en la ventana trimestral de UT ",
         "(doc/backlog_captura_vintages.md); la serie no pasa con un año cerrado a medias.")
  }
  invisible(TRUE)
}

#' Serie mensual de UT a partir del archivo de L0 del vintage vigente de CADA año (o, con
#' `conjunto`, del que el conjunto declara para cada año; el «año máximo» es entonces el del
#' conjunto, y el sha256 de cada archivo se verifica al usarlo). `vintages` es
#' el contenido de 08_vintages.csv, `manifiesto` el de manifiesto.csv y `dir_l0` el directorio de
#' los archivos. Devuelve data.frame(anio, mes, periodo, gwh) ordenado. Falla visible si:
#'   - los años con vintage no son contiguos (un hueco entre el mínimo y el máximo);
#'   - un vintage no tiene exactamente una fila en el manifiesto, o su archivo no está en L0, o el
#'     año del nombre del archivo no es el del vintage;
#'   - algún año no trae los meses esperados (ut_meses_esperados()), lo que incluye un año anterior
#'     al máximo con menos de 12 meses;
#'   - hay períodos duplicados.
construir_serie_ut <- function(vintages, manifiesto, dir_l0, publicacion_id = PUBLICACION_UT,
                               conjunto = NULL) {
  mapa <- mapa_vintage_por_anio(publicacion_id, vintages, conjunto)
  anios <- as.integer(names(mapa))
  if (!identical(anios, seq(min(anios), max(anios)))) {
    stop("FALLO VISIBLE ['", publicacion_id, "']: los años con vintage en 08_vintages.csv (",
         paste(anios, collapse = ", "), ") tienen un hueco entre ", min(anios), " y ", max(anios),
         ". No se arma una serie mensual saltando un año.")
  }

  piezas <- lapply(seq_along(mapa), function(i) {
    vid <- mapa[[i]]
    anio <- anios[i]
    fila <- manifiesto[manifiesto$vintage_id == vid, ]
    if (nrow(fila) != 1) {
      stop("FALLO VISIBLE ['", publicacion_id, "']: el vintage '", vid, "' (año ", anio, ") tiene ",
           nrow(fila), " filas en manifiesto.csv (se espera 1).")
    }
    ruta <- file.path(dir_l0, fila$archivo)
    if (!is.null(conjunto)) verificar_sha256_l0(vid, vintages, dir_l0, manifiesto)
    if (!file.exists(ruta)) {
      stop("FALLO VISIBLE ['", publicacion_id, "']: no está ", ruta, " (vintage '", vid,
           "', año ", anio, "). Repoblar L0 con `make materializar-l0`.")
    }
    anio_nombre <- as.integer(regmatches(fila$archivo, regexpr("[0-9]{4}", fila$archivo)))
    if (!identical(anio_nombre, anio)) {
      stop("FALLO VISIBLE ['", publicacion_id, "']: el archivo '", fila$archivo, "' del vintage '",
           vid, "' no lleva el año ", anio, " en su nombre.")
    }
    leer_ut_anual(ruta, anio)
  })
  serie <- do.call(rbind, piezas)
  serie <- serie[order(serie$anio, serie$mes), ]
  serie$periodo <- sprintf("%d-M%02d", serie$anio, serie$mes)
  serie <- serie[, c("anio", "mes", "periodo", "gwh")]

  # --- Validaciones (fallar de forma visible, no advertir) ---
  validar_anios_cerrados_ut(serie$periodo, publicacion_id)
  esperado <- ut_meses_esperados(mapa, vintages)
  conteo <- table(serie$anio)
  difiere <- as.integer(conteo[names(esperado)]) != esperado
  if (any(difiere)) {
    stop("FALLO VISIBLE ['", publicacion_id, "']: meses por año distintos de los que declara ",
         "08_vintages.csv (periodo_referencia_max): ",
         paste0(names(esperado)[difiere], " tiene ", as.integer(conteo[names(esperado)])[difiere],
                ", se esperaban ", esperado[difiere], collapse = "; "), ".")
  }
  dup <- serie[duplicated(serie[, c("anio", "mes")]), ]
  if (nrow(dup) > 0) {
    stop("FALLO VISIBLE: períodos duplicados encontrados:\n", paste(capture.output(print(dup)), collapse = "\n"))
  }
  serie
}
