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
# QUE QUEDA FUERA DE ALCANCE. Este verificador resuelve hoja -> XML -> sharedStrings dentro de
# un .xlsx. Una fila cuyo vintage vigente no es un .xlsx (p.ej. UT.DEMANDA_TOTAL_MENSUAL, serie
# derivada de 25 CSV via src/transformacion/ut_demanda_serie.R, cuyo fuente_celda describe la
# derivacion en prosa y no cita una celda) no es una verificacion fallida: es una verificacion
# que esta herramienta no puede hacer. Se reporta como FUERA_DE_ALCANCE, se lista una por una
# en el resumen para que un humano las lea, y no cuenta como FAIL. La distincion es por
# extension del archivo de L0, no por publicacion_id: un fuente_celda malformado sobre una
# publicacion que SI es .xlsx sigue siendo FAIL, que es el fallo que importa conservar.

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
  # Vintage VIGENTE = ultima fila del manifiesto para esa publicacion (append-only). Misma
  # convencion que registrar_descarga() paso 3 y scripts/verificar_l0.R — ver cabecera.
  vintage_vigente <- pub[nrow(pub), ]
  sufijo_vintage <- if (nrow(pub) > 1) {
    paste0(" [vintage vigente ", vintage_vigente$vintage_id, ", ", nrow(pub), " en el manifiesto]")
  } else {
    ""
  }

  # Fuera del alcance de esta herramienta: el vintage vigente no es un .xlsx, asi que no hay
  # hoja ni sharedStrings que resolver. No es un FAIL — ver cabecera.
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
      "AVISO: %d fila(s) quedaron NO_VERIFICABLE (archivo .xlsx ausente localmente en esta ",
      "corrida) y no fueron comprobadas. Ejecutar con los 4 archivos de data/L0_raw/ presentes ",
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
