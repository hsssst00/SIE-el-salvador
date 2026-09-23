# Verifica que el rotulo citado en la columna fuente_celda de catalogos/03_series.csv
# siga coincidiendo con la celda real del archivo .xlsx de origen en data/L0_raw/, y que
# ese archivo no haya cambiado sin que exista un vintage nuevo (checksum SHA-256 contra
# manifiesto.csv).
#
# Se compara contra el rotulo transcrito en fuente_celda, NO contra nombre_oficial: son
# literales distintos en una fraccion de filas (11 de 98 al recalcular contra el catalogo del
# 2026-08-17 — recalcular contra el catalogo vigente en cada revision, esta cifra crece con el
# catalogo) por razones ya documentadas en 03_series.csv (redaccion propia del proyecto en las
# filas de PIB agregado; marcadores de nota al pie del BCR, p.ej. "2/", que nombre_oficial omite
# pero la celda real conserva). Comparar contra nombre_oficial produciria falsos FAIL en filas
# correctas.
#
# La validacion falla, no advierte (regla 7 de CLAUDE.md, S3.5 de la senda metodologica):
# termina con stop() y codigo de salida distinto de cero si hay al menos un FAIL (checksum
# roto o rotulo que ya no coincide). Las filas cuyo archivo .xlsx no existe localmente (caso
# normal fuera de la maquina de Harold: los .xlsx estan en .gitignore, ver ADR-008) se
# reportan como NO_VERIFICABLE — nunca como FAIL ni como advertencia silenciada — y se cuentan
# aparte en el resumen final.
#
# QUE VINTAGE SE VERIFICA (corregido 2026-08-28, hallazgos B2/B3 de la auditoria de Fase 2).
# El manifiesto es append-only con UNA FILA POR VINTAGE, no por publicacion: en cuanto una
# publicacion tiene su segundo vintage -que es exactamente lo que ADR-007 se propone hacer con
# la captura prospectiva- hay varias filas para el mismo publicacion_id. La version anterior
# de este script trataba eso como FAIL ("deberia ser unico"), de modo que el mecanismo central
# de ADR-007 rompia este verificador la primera vez que hiciera su trabajo. Ya habia empezado
# a ocurrir: UT.DEMANDA_TOTAL_MENSUAL tiene 25 filas y dejaba el script en rojo.
# Ahora se verifica contra la ULTIMA fila del manifiesto para ese publicacion_id -el vintage
# vigente-, que es la misma convencion que ya usan registrar_descarga() (paso 3) y
# scripts/verificar_l0.R. 03_series.csv describe la serie tal como se lee hoy; los vintages
# anteriores no se re-verifican aca.
#
# QUE QUEDA FUERA DE ALCANCE. Este verificador resuelve hoja -> readxl -> fila dentro de un
# .xlsx, y desde 2026-09-23 tambien archivos .csv anuales con encabezado citado (ver "RAMA CSV
# POR AÑO" abajo; UT.DEMANDA_TOTAL_MENSUAL era hasta entonces la unica fila fuera de alcance).
# Una fila cuyo vintage vigente no cae en ninguna de las dos ramas no es una verificacion
# fallida: es una verificacion que esta herramienta no puede hacer. Se reporta como
# FUERA_DE_ALCANCE, se lista una por una en el resumen para que un humano las lea, y no cuenta como FAIL. La distincion es por
# extension del archivo de L0, no por publicacion_id: un fuente_celda malformado sobre una
# publicacion que SI es .xlsx sigue siendo FAIL, que es el fallo que importa conservar.
#
# POR QUE LA LECTURA DE FILA USA readxl Y NO XML CRUDO (corregido 2026-09-16, ver bitacora).
# La version anterior de este script resolvia "fila N" contra el atributo @r="N" del XML crudo
# de la hoja. Eso asume que "fila N" en fuente_celda/fila_dato significa "la N-esima fila fisica
# de Excel" -- pero fila_dato es, por diseno, el indice de fila que src/transformacion/
# extraer_bcr_pib.R obtiene de read_excel(), y ambos NO siempre coinciden: si la hoja tiene una
# fila inicial sin ninguna celda hija (<row r="1"/> vacia, confirmado en
# BCR_pib_t_retropolado_1990_2005_2026-08-06.xlsx, hojas T1/T2), readxl la omite del todo y
# recorre el resto corrido una posicion, mientras que el XML crudo sigue contando esa fila vacia
# como la 1. El desfase resultante (verificador contra XML: fila N: extractor contra readxl:
# fila N-1) genero un FAIL en las 13 filas *.RETRO la primera vez que este script corrio tras la
# estructuracion de fuente_celda (commit db91582) -- un falso positivo: los valores que
# extraer_bcr_pib.R ya produce con fila_dato tal como esta declarado coinciden con la serie
# nativa del BCR dentro de la tolerancia documentada en doc/metodologia/
# empalme_cuentas_nacionales.md, o sea que fila_dato SI apunta a la celda correcta bajo la
# convencion de readxl. La correccion es leer con la misma libreria y la misma convencion que el
# extractor, para que este verificador confirme lo que el extractor realmente hace, no una
# indexacion distinta que por coincidencia suele dar el mismo numero.
#
# RAMA CSV POR AÑO (2026-09-23; hasta entonces UT.DEMANDA_ELEC.GWH.NSA.M salia FUERA_DE_ALCANCE).
# Una publicacion capturada UN ARCHIVO POR AÑO en .csv (hoy solo UT.DEMANDA_TOTAL_MENSUAL, 25
# archivos 2002-2026) no tiene "vintage vigente" en el sentido de arriba: sus vintages no se
# reemplazan entre si, cada uno aporta su propio año. Por eso esta rama no toma la ultima fila
# del manifiesto sino el mapa año -> vintage de mapa_vintage_por_anio() (vintage_lib.R), la
# MISMA regla con la que L3 etiqueta la columna vintage_id, y comprueba por cada año:
#   - que el vintage exista en el manifiesto y su archivo en data/L0_raw/ (si falta alguno:
#     NO_VERIFICABLE, igual que la rama .xlsx);
#   - checksum SHA-256 contra el manifiesto;
#   - que el año del nombre de archivo sea el año del vintage (ut_demanda_serie.R toma el año
#     del NOMBRE, nunca del contenido, asi que esa correspondencia es la que sostiene cada fecha);
#   - que el archivo tenga exactamente una linea igual al encabezado que cita fuente_celda
#     (`encabezado "MES,,,GWH,,"`), el analogo del rotulo en la fila citada de un .xlsx.
# Ademas, que los años del mapa cubran sin huecos inicio..fin de 03_series.csv. Como en la rama
# .xlsx, se verifica el ancla estructural que el extractor usa, no cada valor numerico.
# Una fila .csv cuyo fuente_celda no cita un encabezado sigue siendo FUERA_DE_ALCANCE.

library(readxl)
source(here::here("src", "transformacion", "vintage_lib.R"))

ruta_series <- "catalogos/03_series.csv"
ruta_manifiesto <- "data/L0_raw/manifiesto.csv"
dir_l0 <- "data/L0_raw"

patron_fuente_celda <- 'hoja ([^,]+), fila (\\d+) \\("([^"]+)"'
patron_encabezado_csv <- 'encabezado "([^"]+)"'

# digest no esta en los 14 imports de DESCRIPTION, pero ya esta en renv.lock como
# dependencia transitiva (de pointblank, ranger, entre otros) — mismo criterio que ADR-009
# aplica a `zip` para el paso de descompresion: se usa lo que renv.lock ya resuelve antes
# de sumar un import nuevo no solicitado. Si esto deja de sostenerse, corresponde declarar
# `digest` como import propio en vez de depender de una transitiva ajena.
calcular_sha256 <- function(ruta_archivo) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop(
      "El paquete 'digest' no esta instalado. Es una dependencia transitiva ya presente ",
      "en renv.lock; corra renv::restore() antes de ejecutar este verificador."
    )
  }
  tolower(digest::digest(object = ruta_archivo, algo = "sha256", file = TRUE))
}

cache_lectura <- new.env(parent = emptyenv())

# Lee la hoja completa vía readxl (misma libreria y misma convencion de indices de fila que
# src/transformacion/extraer_bcr_pib.R), cacheada por archivo+hoja para no releer la misma hoja
# una vez por fila de 03_series.csv.
leer_hoja <- function(ruta_archivo, nombre_hoja) {
  clave <- paste0(normalizePath(ruta_archivo, mustWork = TRUE), "::", nombre_hoja)
  if (exists(clave, envir = cache_lectura, inherits = FALSE)) {
    return(get(clave, envir = cache_lectura, inherits = FALSE))
  }
  datos <- readxl::read_excel(ruta_archivo, sheet = nombre_hoja, col_names = FALSE, .name_repair = "minimal")
  assign(clave, datos, envir = cache_lectura)
  datos
}

# Busca, entre todas las celdas de la fila num_fila (sin asumir columna fija: varia entre
# "worksheet" y "T1"/"T2"), una cuyo texto tras trimws() sea igual a rotulo_esperado. num_fila
# es el indice de fila tal como lo devuelve readxl -- ver nota de cabecera sobre por que no es
# necesariamente el atributo @r del XML crudo.
verificar_rotulo_en_fila <- function(ruta_archivo, nombre_hoja, num_fila, rotulo_esperado) {
  datos <- leer_hoja(ruta_archivo, nombre_hoja)
  num_fila <- as.integer(num_fila)

  if (is.na(num_fila) || num_fila < 1 || num_fila > nrow(datos)) {
    return(list(
      ok = FALSE,
      motivo = paste0(
        "la hoja tiene menos filas que ", num_fila,
        " (readxl leyo ", nrow(datos), " filas de datos)"
      )
    ))
  }

  textos <- vapply(datos[num_fila, ], function(v) {
    if (is.na(v)) "" else trimws(as.character(v))
  }, character(1))

  if (rotulo_esperado %in% textos) {
    return(list(ok = TRUE))
  }

  textos_no_vacios <- textos[nzchar(textos)]
  motivo <- if (length(textos_no_vacios) > 0) {
    paste0(
      "no se encontro el rotulo exacto en la fila ", num_fila,
      " (lectura via readxl); celdas de texto encontradas: ",
      paste(sprintf('"%s"', textos_no_vacios), collapse = "; ")
    )
  } else {
    paste0("no se encontro el rotulo exacto en la fila ", num_fila, " (lectura via readxl); la fila no tiene celdas de texto")
  }
  list(ok = FALSE, motivo = motivo)
}

# Rama CSV por año -- ver cabecera. Devuelve una sola fila de resultado para la serie: PASS si
# los N archivos anuales cumplen, FAIL listando cada año que no, NO_VERIFICABLE si falta alguno
# localmente y el resto no falla.
verificar_fila_csv_por_anio <- function(serie_id, publicacion_id, encabezado, inicio, fin,
                                        manifiesto, vintages) {
  resultado <- function(estado, detalle) {
    data.frame(serie_id = serie_id, estado = estado, detalle = detalle, stringsAsFactors = FALSE)
  }

  mapa <- tryCatch(mapa_vintage_por_anio(publicacion_id, vintages),
                   error = function(e) conditionMessage(e))
  if (is.character(mapa) && is.null(names(mapa))) {
    return(resultado("FAIL", mapa))
  }

  anios_esperados <- as.character(seq(as.integer(substr(inicio, 1, 4)), as.integer(substr(fin, 1, 4))))
  if (!setequal(names(mapa), anios_esperados)) {
    return(resultado("FAIL", paste0(
      "los años con vintage en 08_vintages.csv (", paste(sort(names(mapa)), collapse = ", "),
      ") no cubren exactamente inicio..fin de 03_series.csv (", inicio, " .. ", fin, ")"
    )))
  }

  fallas <- character(0)
  ausentes <- character(0)
  for (anio in sort(names(mapa))) {
    vid <- mapa[[anio]]
    fila_m <- manifiesto[manifiesto$vintage_id == vid, ]
    if (nrow(fila_m) != 1) {
      fallas <- c(fallas, paste0(anio, ": vintage '", vid, "' tiene ", nrow(fila_m), " filas en manifiesto.csv (se espera 1)"))
      next
    }
    ruta_archivo <- file.path(dir_l0, fila_m$archivo)
    if (!file.exists(ruta_archivo)) {
      ausentes <- c(ausentes, fila_m$archivo)
      next
    }
    hash_real <- calcular_sha256(ruta_archivo)
    if (!identical(hash_real, tolower(fila_m$sha256))) {
      fallas <- c(fallas, paste0(anio, ": checksum SHA-256 de '", fila_m$archivo, "' no coincide con manifiesto.csv"))
      next
    }
    anio_nombre <- regmatches(fila_m$archivo, regexpr("[0-9]{4}", fila_m$archivo))
    if (!identical(anio_nombre, anio)) {
      fallas <- c(fallas, paste0(anio, ": el nombre de archivo '", fila_m$archivo, "' no lleva el año del vintage"))
      next
    }
    lineas <- sub("\r$", "", readLines(ruta_archivo, warn = FALSE))
    n_encabezado <- sum(trimws(lineas) == encabezado)
    if (n_encabezado != 1) {
      fallas <- c(fallas, paste0(anio, ": '", fila_m$archivo, "' tiene ", n_encabezado,
                                 " lineas iguales al encabezado \"", encabezado, "\" (se espera 1)"))
    }
  }

  anios <- sort(names(mapa))
  rango <- paste0(anios[1], "-", anios[length(anios)])
  if (length(fallas) > 0) {
    return(resultado("FAIL", paste0(length(fallas), " de ", length(mapa), " archivos anuales fallan: ",
                                    paste(fallas, collapse = "; "))))
  }
  if (length(ausentes) > 0) {
    return(resultado("NO_VERIFICABLE", paste0(length(ausentes), " de ", length(mapa),
                                              " archivos anuales ausentes localmente: ",
                                              paste(ausentes, collapse = ", "))))
  }
  resultado("PASS", paste0(
    length(mapa), " archivos anuales .csv (", rango, "), uno por vintage: checksum, año del nombre y ",
    "encabezado \"", encabezado, "\" coinciden en todos"
  ))
}

verificar_fila <- function(serie_id, publicacion_id, fuente_celda, manifiesto,
                           inicio = NA_character_, fin = NA_character_, vintages = NULL) {
  pub <- manifiesto[manifiesto$publicacion_id == publicacion_id, ]

  if (nrow(pub) == 0) {
    return(data.frame(
      serie_id = serie_id, estado = "FAIL",
      detalle = paste0("publicacion_id '", publicacion_id, "' no existe en manifiesto.csv"),
      stringsAsFactors = FALSE
    ))
  }
  # Vintage VIGENTE = ultima fila del manifiesto para esa publicacion (append-only). Misma
  # convencion que registrar_descarga() paso 3 y scripts/verificar_l0.R — ver cabecera.
  vintage_vigente <- pub[nrow(pub), ]
  sufijo_vintage <- if (nrow(pub) > 1) {
    paste0(" [vintage vigente ", vintage_vigente$vintage_id, ", ", nrow(pub), " en el manifiesto]")
  } else {
    ""
  }

  # .csv con encabezado citado en fuente_celda: rama por año -- ver cabecera.
  encabezado <- regmatches(fuente_celda, regexec(patron_encabezado_csv, fuente_celda, perl = TRUE))[[1]]
  if (grepl("\\.csv$", vintage_vigente$archivo, ignore.case = TRUE) && length(encabezado) == 2) {
    return(verificar_fila_csv_por_anio(serie_id, publicacion_id, encabezado[2], inicio, fin,
                                       manifiesto, vintages))
  }

  # Fuera del alcance de esta herramienta: el vintage vigente no es un .xlsx (ni un .csv con
  # encabezado citado), asi que no hay hoja ni sharedStrings que resolver. No es un FAIL — ver
  # cabecera.
  if (!grepl("\\.xlsx$", vintage_vigente$archivo, ignore.case = TRUE)) {
    return(data.frame(
      serie_id = serie_id, estado = "FUERA_DE_ALCANCE",
      detalle = paste0(
        "el vintage vigente de '", publicacion_id, "' es '", vintage_vigente$archivo,
        "', no un .xlsx: este verificador resuelve hoja/fila/rotulo dentro de un .xlsx. ",
        "La trazabilidad de esta fila se sostiene por otra via (ver su fuente_celda)", sufijo_vintage
      ),
      stringsAsFactors = FALSE
    ))
  }

  ruta_archivo <- file.path(dir_l0, vintage_vigente$archivo)

  if (!file.exists(ruta_archivo)) {
    return(data.frame(
      serie_id = serie_id, estado = "NO_VERIFICABLE",
      detalle = paste0("archivo ausente localmente", sufijo_vintage),
      stringsAsFactors = FALSE
    ))
  }

  hash_real <- calcular_sha256(ruta_archivo)
  hash_manifiesto <- tolower(vintage_vigente$sha256)
  if (!identical(hash_real, hash_manifiesto)) {
    return(data.frame(
      serie_id = serie_id, estado = "FAIL",
      detalle = paste0(
        "checksum SHA-256 no coincide con manifiesto.csv (manifiesto: ", hash_manifiesto,
        "; archivo: ", hash_real, ")"
      ),
      stringsAsFactors = FALSE
    ))
  }

  # Todo el resto (parseo de fuente_celda, resolucion del .xlsx, busqueda del rotulo) va en
  # un solo tryCatch: una fila con fuente_celda malformado o un .xlsx con estructura
  # inesperada debe reportarse como FAIL de esa fila, no interrumpir la corrida completa.
  resultado <- tryCatch({
    grupos <- regmatches(fuente_celda, regexec(patron_fuente_celda, fuente_celda, perl = TRUE))[[1]]
    if (length(grupos) < 4) {
      stop("fuente_celda no coincide con el patron esperado ('hoja X, fila N (\"rotulo\"')")
    }
    nombre_hoja <- grupos[2]
    num_fila <- grupos[3]
    rotulo_esperado <- grupos[4]

    res <- verificar_rotulo_en_fila(ruta_archivo, nombre_hoja, num_fila, rotulo_esperado)
    res$nombre_hoja <- nombre_hoja
    res$num_fila <- num_fila
    res
  }, error = function(e) {
    list(ok = FALSE, motivo = conditionMessage(e), nombre_hoja = NA_character_, num_fila = NA_character_)
  })

  if (isTRUE(resultado$ok)) {
    data.frame(
      serie_id = serie_id, estado = "PASS",
      detalle = paste0("coincide en hoja '", resultado$nombre_hoja, "', fila ", resultado$num_fila),
      stringsAsFactors = FALSE
    )
  } else {
    detalle <- if (!is.na(resultado$nombre_hoja)) {
      paste0("hoja '", resultado$nombre_hoja, "': ", resultado$motivo)
    } else {
      resultado$motivo
    }
    data.frame(serie_id = serie_id, estado = "FAIL", detalle = detalle, stringsAsFactors = FALSE)
  }
}

series <- utils::read.csv(ruta_series, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
manifiesto <- utils::read.csv(ruta_manifiesto, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
vintages <- leer_vintages()

resultados <- do.call(rbind, lapply(seq_len(nrow(series)), function(i) {
  verificar_fila(series$serie_id[i], series$publicacion_id[i], series$fuente_celda[i], manifiesto,
                 series$inicio[i], series$fin[i], vintages)
}))

cat("serie_id | estado | detalle\n")
for (i in seq_len(nrow(resultados))) {
  cat(sprintf("%s | %s | %s\n", resultados$serie_id[i], resultados$estado[i], resultados$detalle[i]))
}

n_pass <- sum(resultados$estado == "PASS")
n_fail <- sum(resultados$estado == "FAIL")
n_no_verificable <- sum(resultados$estado == "NO_VERIFICABLE")
n_fuera_alcance <- sum(resultados$estado == "FUERA_DE_ALCANCE")

message(sprintf(
  "Resumen: %d PASS, %d FAIL, %d NO_VERIFICABLE, %d FUERA_DE_ALCANCE (de %d filas en total).",
  n_pass, n_fail, n_no_verificable, n_fuera_alcance, nrow(resultados)
))

if (n_fail > 0) {
  stop(sprintf(
    "%d fila(s) de 03_series.csv fallaron la verificacion de fuente_celda o de checksum. Ver detalle arriba.",
    n_fail
  ))
}

if (n_no_verificable > 0) {
  message(sprintf(
    paste0(
      "AVISO: %d fila(s) quedaron NO_VERIFICABLE (archivo de L0 ausente localmente en esta ",
      "corrida) y no fueron comprobadas. Ejecutar con los archivos de data/L0_raw/ presentes ",
      "para cobertura completa."
    ),
    n_no_verificable
  ))
}

# Las filas fuera de alcance se listan una por una, nunca se resumen en un numero: son
# justamente las que ninguna herramienta esta comprobando, y tienen que quedar a la vista de
# quien lea la corrida (y de la entrada de bitacora que la asienta, regla 8 de CLAUDE.md).
if (n_fuera_alcance > 0) {
  message(sprintf(
    paste0(
      "AVISO: %d fila(s) quedaron FUERA_DE_ALCANCE de este verificador (el vintage vigente de ",
      "su publicacion no es un .xlsx). Su trazabilidad NO la comprueba este script:"
    ),
    n_fuera_alcance
  ))
  fuera <- resultados[resultados$estado == "FUERA_DE_ALCANCE", ]
  for (i in seq_len(nrow(fuera))) {
    message("  - ", fuera$serie_id[i], ": ", fuera$detalle[i])
  }
}

message("OK: verificacion de fuente_celda completada sin FAIL.")
