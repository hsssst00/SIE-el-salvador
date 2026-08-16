# Verifica que el rotulo citado en la columna fuente_celda de catalogos/03_series.csv
# siga coincidiendo con la celda real del archivo .xlsx de origen en data/L0_raw/, y que
# ese archivo no haya cambiado sin que exista un vintage nuevo (checksum SHA-256 contra
# manifiesto.csv).
#
# Se compara contra el rotulo transcrito en fuente_celda, NO contra nombre_oficial: son
# literales distintos en 7 de 50 filas por razones ya documentadas en 03_series.csv (redaccion
# propia del proyecto en las filas de PIB agregado; marcadores de nota al pie del BCR, p.ej.
# "2/", que nombre_oficial omite pero la celda real conserva). Comparar contra nombre_oficial
# produciria falsos FAIL en filas correctas.
#
# La validacion falla, no advierte (regla 7 de CLAUDE.md, S3.5 de la senda metodologica):
# termina con stop() y codigo de salida distinto de cero si hay al menos un FAIL (checksum
# roto o rotulo que ya no coincide). Las filas cuyo archivo .xlsx no existe localmente (caso
# normal fuera de la maquina de Harold: los .xlsx estan en .gitignore, ver ADR-008) se
# reportan como NO_VERIFICABLE — nunca como FAIL ni como advertencia silenciada — y se cuentan
# aparte en el resumen final.

library(xml2)

ruta_series <- "catalogos/03_series.csv"
ruta_manifiesto <- "data/L0_raw/manifiesto.csv"
dir_l0 <- "data/L0_raw"

patron_fuente_celda <- 'hoja ([^,]+), fila (\\d+) \\("([^"]+)"'

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

cache_extraccion <- new.env(parent = emptyenv())

# unzip() de R base (§ estilo del script): `zip` no esta en renv.lock como transitiva,
# a diferencia de `digest`, asi que no corresponde usarlo aqui.
extraer_xlsx <- function(ruta_archivo) {
  clave <- normalizePath(ruta_archivo, mustWork = TRUE)
  if (exists(clave, envir = cache_extraccion, inherits = FALSE)) {
    return(get(clave, envir = cache_extraccion, inherits = FALSE))
  }
  dir_destino <- tempfile(pattern = "xlsx_")
  dir.create(dir_destino)
  utils::unzip(clave, exdir = dir_destino)
  assign(clave, dir_destino, envir = cache_extraccion)
  dir_destino
}

# Resuelve el nombre de hoja citado en fuente_celda (p.ej. "worksheet", "T1", "T2") a la
# ruta real del XML de esa hoja, vía xl/workbook.xml (nombre -> r:id) y
# xl/_rels/workbook.xml.rels (r:id -> archivo). No asumir que la hoja N es sheetN.xml: en
# el archivo retropolado el orden de r:id no coincide necesariamente con el de <sheets>.
resolver_ruta_hoja <- function(dir_extraido, nombre_hoja) {
  wb <- read_xml(file.path(dir_extraido, "xl", "workbook.xml"))
  ns <- xml_ns(wb)

  nodos_hoja <- xml_find_all(wb, "//*[local-name()='sheet']")
  nombres_hoja <- xml_attr(nodos_hoja, "name")
  rids_hoja <- xml_attr(nodos_hoja, "r:id", ns = ns)

  idx <- which(nombres_hoja == nombre_hoja)
  if (length(idx) == 0) {
    stop(
      "la hoja '", nombre_hoja, "' no existe en workbook.xml (hojas disponibles: ",
      paste(nombres_hoja, collapse = ", "), ")"
    )
  }
  rid_objetivo <- rids_hoja[idx[1]]

  rels <- read_xml(file.path(dir_extraido, "xl", "_rels", "workbook.xml.rels"))
  nodos_rel <- xml_find_all(rels, "//*[local-name()='Relationship']")
  idx_rel <- which(xml_attr(nodos_rel, "Id") == rid_objetivo)
  if (length(idx_rel) == 0) {
    stop(
      "el r:id '", rid_objetivo, "' de la hoja '", nombre_hoja,
      "' no tiene relacion declarada en workbook.xml.rels"
    )
  }
  file.path(dir_extraido, "xl", xml_attr(nodos_rel[idx_rel[1]], "Target"))
}

leer_shared_strings <- function(dir_extraido) {
  ruta_sst <- file.path(dir_extraido, "xl", "sharedStrings.xml")
  if (!file.exists(ruta_sst)) {
    return(character(0))
  }
  sst <- read_xml(ruta_sst)
  # xml_text() concatena todo el texto descendiente de cada <si>, incluidas las citas con
  # varios <r><t> (texto en mas de un run, p.ej. un rotulo mas un marcador de nota al pie en
  # superindice) — sin esto, rotulos como "Formacion Bruta de Capital Fijo 2/" se leerian
  # truncados en el primer run.
  xml_text(xml_find_all(sst, "//*[local-name()='si']"))
}

texto_celda <- function(nodo_celda, shared_strings) {
  tipo <- xml_attr(nodo_celda, "t")
  if (!is.na(tipo) && tipo == "s") {
    nodo_v <- xml_find_first(nodo_celda, "./*[local-name()='v']")
    if (inherits(nodo_v, "xml_missing")) return(NA_character_)
    idx <- suppressWarnings(as.integer(xml_text(nodo_v)))
    if (is.na(idx) || idx < 0 || idx >= length(shared_strings)) return(NA_character_)
    return(shared_strings[idx + 1])
  }
  if (!is.na(tipo) && tipo == "inlineStr") {
    nodo_is <- xml_find_first(nodo_celda, "./*[local-name()='is']")
    if (inherits(nodo_is, "xml_missing")) return(NA_character_)
    return(xml_text(nodo_is))
  }
  nodo_v <- xml_find_first(nodo_celda, "./*[local-name()='v']")
  if (inherits(nodo_v, "xml_missing")) return(NA_character_)
  xml_text(nodo_v)
}

# Busca, entre todas las celdas de la fila num_fila (sin asumir columna fija: varia entre
# "worksheet" y "T1"/"T2"), una cuyo texto tras trimws() sea igual a rotulo_esperado.
verificar_rotulo_en_fila <- function(ruta_hoja, dir_extraido, num_fila, rotulo_esperado) {
  hoja <- read_xml(ruta_hoja)
  shared_strings <- leer_shared_strings(dir_extraido)

  nodo_fila <- xml_find_first(hoja, paste0("//*[local-name()='row'][@r='", num_fila, "']"))
  if (inherits(nodo_fila, "xml_missing")) {
    filas_r <- suppressWarnings(as.integer(xml_attr(xml_find_all(hoja, "//*[local-name()='row']"), "r")))
    max_fila <- suppressWarnings(max(filas_r, na.rm = TRUE))
    return(list(
      ok = FALSE,
      motivo = paste0(
        "la hoja tiene menos filas que ", num_fila,
        " (ultima fila declarada: ", max_fila, ")"
      )
    ))
  }

  nodos_celda <- xml_find_all(nodo_fila, "./*[local-name()='c']")
  textos <- vapply(nodos_celda, function(nodo_c) {
    v <- texto_celda(nodo_c, shared_strings)
    if (is.na(v)) "" else trimws(v)
  }, character(1))

  if (rotulo_esperado %in% textos) {
    return(list(ok = TRUE))
  }

  textos_no_vacios <- textos[nzchar(textos)]
  motivo <- if (length(textos_no_vacios) > 0) {
    paste0(
      "no se encontro el rotulo exacto en la fila ", num_fila,
      "; celdas de texto encontradas: ",
      paste(sprintf('"%s"', textos_no_vacios), collapse = "; ")
    )
  } else {
    paste0("no se encontro el rotulo exacto en la fila ", num_fila, "; la fila no tiene celdas de texto")
  }
  list(ok = FALSE, motivo = motivo)
}

verificar_fila <- function(serie_id, publicacion_id, fuente_celda, manifiesto) {
  pub <- manifiesto[manifiesto$publicacion_id == publicacion_id, ]

  if (nrow(pub) == 0) {
    return(data.frame(
      serie_id = serie_id, estado = "FAIL",
      detalle = paste0("publicacion_id '", publicacion_id, "' no existe en manifiesto.csv"),
      stringsAsFactors = FALSE
    ))
  }
  if (nrow(pub) > 1) {
    return(data.frame(
      serie_id = serie_id, estado = "FAIL",
      detalle = paste0(
        "publicacion_id '", publicacion_id, "' tiene ", nrow(pub),
        " filas en manifiesto.csv (deberia ser unico)"
      ),
      stringsAsFactors = FALSE
    ))
  }

  ruta_archivo <- file.path(dir_l0, pub$archivo[1])

  if (!file.exists(ruta_archivo)) {
    return(data.frame(
      serie_id = serie_id, estado = "NO_VERIFICABLE",
      detalle = "archivo ausente localmente",
      stringsAsFactors = FALSE
    ))
  }

  hash_real <- calcular_sha256(ruta_archivo)
  hash_manifiesto <- tolower(pub$sha256[1])
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

    dir_extraido <- extraer_xlsx(ruta_archivo)
    ruta_hoja <- resolver_ruta_hoja(dir_extraido, nombre_hoja)
    res <- verificar_rotulo_en_fila(ruta_hoja, dir_extraido, num_fila, rotulo_esperado)
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

resultados <- do.call(rbind, lapply(seq_len(nrow(series)), function(i) {
  verificar_fila(series$serie_id[i], series$publicacion_id[i], series$fuente_celda[i], manifiesto)
}))

cat("serie_id | estado | detalle\n")
for (i in seq_len(nrow(resultados))) {
  cat(sprintf("%s | %s | %s\n", resultados$serie_id[i], resultados$estado[i], resultados$detalle[i]))
}

n_pass <- sum(resultados$estado == "PASS")
n_fail <- sum(resultados$estado == "FAIL")
n_no_verificable <- sum(resultados$estado == "NO_VERIFICABLE")

message(sprintf(
  "Resumen: %d PASS, %d FAIL, %d NO_VERIFICABLE (de %d filas en total).",
  n_pass, n_fail, n_no_verificable, nrow(resultados)
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
      "AVISO: %d fila(s) quedaron NO_VERIFICABLE (archivo .xlsx ausente localmente en esta ",
      "corrida) y no fueron comprobadas. Ejecutar con los 4 archivos de data/L0_raw/ presentes ",
      "para cobertura completa."
    ),
    n_no_verificable
  ))
}

message("OK: verificacion de fuente_celda completada sin FAIL.")
