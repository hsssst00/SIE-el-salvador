# scripts/restaurar_l0_perdido.R
# Restauracion de archivos de L0 perdidos - hallazgo B1 de la auditoria de Fase 2.
# Decision de Harold, 2026-08-28: recapturar del portal y cotejar sha256_norm.
#
# POR QUE NO SIRVE descargar_bcr_*() PARA ESTO. registrar_descarga() esta escrita para
# CAPTURAR vintages nuevos, no para restaurar archivos. Si el contenido coincide con el
# ultimo vintage registrado, su paso 3 retorna temprano con "sin cambios" y NO ESCRIBE
# NADA - que es lo correcto para una captura y exactamente lo contrario de lo que hace
# falta aca. Y si escribiera, lo haria con el nombre {FUENTE}_{desc}_{HOY}.xlsx, creando
# un archivo que ninguna fila del manifiesto menciona. Por eso esto es un script aparte.
#
# QUE HACE, POR PUBLICACION CON ARCHIVO AUSENTE:
#   1. Recaptura del portal con el mismo mecanismo y los mismos parametros que la captura
#      original (bcr_capturar_xlsx, formula = "0").
#   2. Calcula sha256_norm y lo compara contra el REGISTRADO.
#   3a. COINCIDE -> es el mismo dato. Escribe el archivo con su NOMBRE REGISTRADO original
#       (no con la fecha de hoy: no es un vintage nuevo, es el mismo vintage restaurado) y
#       actualiza `sha256` y `tamano_bytes` de esa fila en manifiesto.csv y `sha256` en
#       08_vintages.csv, anotando en `notas` por que cambiaron.
#   3b. NO COINCIDE -> el portal ya sirve otro dato. El vintage perdido es IRRECUPERABLE.
#       No escribe nada para esa publicacion y lo reporta. Que hacer con esa fila vuelve a
#       ser decision de Harold (regla 4), no de este script.
#
# POR QUE HAY QUE REESCRIBIR sha256 Y NO ES UNA TRAMPA. El .xlsx que genera SheetJS no es
# determinista byte a byte: el empaquetado ZIP varia entre descargas del mismo dato (prueba
# F1, ADR-007 nota 2026-08-21). Por eso existen dos checksums. `sha256_norm` -identidad de
# vintage- es estable y es el que PRUEBA que el dato es el mismo; `sha256` -integridad del
# archivo en disco- es del archivo concreto, y el archivo concreto es nuevo. Reescribirlo es
# lo unico honesto: dejar el viejo declararia la integridad de un archivo que ya no existe.
# El valor historico no se borra, queda en `notas`.
#
# POR TANDAS. Las escrituras se acumulan y se aplican JUNTAS al final de la corrida, para que
# una interrupcion no deje el catalogo a medio reescribir - protegio de verdad el 2026-08-30,
# cuando el proceso murio en la sexta de doce y no quedo ni un archivo ni una fila a medias.
# El costo de esa garantia es que una corrida interrumpida no conserva NADA de su trabajo. Por
# eso el segundo argumento acota cuantas publicaciones procesa una corrida: tandas cortas que
# terminan y escriben valen mas que una tanda larga que se cae. El script es idempotente
# -recalcula la lista de ausentes al arrancar-, asi que las tandas se encadenan solas.
#
# Uso:
#   Rscript scripts/restaurar_l0_perdido.R            # informa que haria, no escribe (default)
#   Rscript scripts/restaurar_l0_perdido.R aplicar    # recaptura y escribe TODAS las ausentes
#   Rscript scripts/restaurar_l0_perdido.R aplicar 4  # ... solo las primeras 4 de la lista
#   Rscript scripts/restaurar_l0_perdido.R aplicar 4 --omitir=BCR.ITCER,BCR.IPP
#
# --omitir= existe por la regla 9 de CLAUDE.md, no por comodidad. Una publicacion cuya
# recaptura ya probo ser IRRECUPERABLE seguira figurando como ausente hasta que se decida que
# hacer con su fila, y el script la reintentaria en cada tanda: eso es golpear el portal para
# obtener un resultado que ya se conoce. Se omite explicitamente, nombrandola.

source("src/adquisicion/lib_adquisicion.R")

.ARGS <- commandArgs(trailingOnly = TRUE)
.APLICAR <- isTRUE(length(.ARGS) >= 1 && tolower(.ARGS[1]) == "aplicar")
.OMITIR <- local({
  a <- grep("^--omitir=", .ARGS, value = TRUE)
  if (length(a) == 0) return(character(0))
  trimws(strsplit(sub("^--omitir=", "", a[1]), ",", fixed = TRUE)[[1]])
})
.MAX <- local({
  posicionales <- .ARGS[!grepl("^--", .ARGS)]
  if (length(posicionales) < 2) return(Inf)
  n <- suppressWarnings(as.integer(posicionales[2]))
  if (is.na(n) || n < 1) {
    stop("FALLO VISIBLE [restaurar-l0]: el segundo argumento debe ser un entero >= 1 ",
         "(cuantas publicaciones procesar en esta tanda). Recibido: '", posicionales[2], "'")
  }
  n
})

.FORMULA_BASE <- "0"
.HOY <- as.character(Sys.Date())

fallar <- function(...) stop("FALLO VISIBLE [restaurar-l0]: ", ..., call. = FALSE)

manifiesto <- leer_manifiesto()
ausentes <- manifiesto[!file.exists(file.path(dir_l0, manifiesto$archivo)), ]

if (nrow(ausentes) == 0) {
  message("No hay archivos ausentes en data/L0_raw/: nada que restaurar.")
  quit(status = 0)
}

no_bcr <- ausentes[ausentes$fuente != "BCR", ]
if (nrow(no_bcr) > 0) {
  fallar("hay ", nrow(no_bcr), " archivo(s) ausente(s) que NO son del BCR (",
         paste(unique(no_bcr$fuente), collapse = ", "), "). Este script solo sabe recapturar ",
         "publicaciones de la familia vista-serie del portal del BCR. Resolver esas por ",
         "separado antes de seguir.")
}

message("Archivos de L0 ausentes: ", nrow(ausentes), "\n")
for (i in seq_len(nrow(ausentes))) {
  message("   ", ausentes$publicacion_id[i], "  ->  ", ausentes$archivo[i])
}

if (!.APLICAR) {
  message("\nModo informe (default). Para recapturar y escribir:\n",
          "   Rscript scripts/restaurar_l0_perdido.R aplicar      # las ", nrow(ausentes), "\n",
          "   Rscript scripts/restaurar_l0_perdido.R aplicar 4    # solo las primeras 4\n",
          "Son ", nrow(ausentes), " capturas con navegador headless contra el portal del BCR; ",
          "algunas tardan minutos (regla 9 de CLAUDE.md: es un acto deliberado, al ritmo de ",
          "publicacion de la fuente, no una recoleccion repetida).")
  quit(status = 0)
}

if (length(.OMITIR) > 0) {
  desconocidas <- setdiff(.OMITIR, ausentes$publicacion_id)
  if (length(desconocidas) > 0) {
    fallar("--omitir nombra publicacion(es) que no estan ausentes: ",
           paste(desconocidas, collapse = ", "), ". Se falla en vez de ignorarlo en silencio: ",
           "un id mal escrito haria creer que se omitio algo que en realidad se recapturo.")
  }
  ausentes <- ausentes[!ausentes$publicacion_id %in% .OMITIR, ]
  message("\nOmitidas por pedido explicito (", length(.OMITIR), "): ",
          paste(.OMITIR, collapse = ", "))
}

if (is.finite(.MAX) && .MAX < nrow(ausentes)) {
  total_ausentes <- nrow(ausentes)
  ausentes <- ausentes[seq_len(.MAX), ]
  message("\nTanda acotada a ", nrow(ausentes), " publicacion(es) de las ", total_ausentes,
          " ausentes. Volver a correr para continuar con el resto.")
}

source("src/adquisicion/bcr.R")  # arrastra bcr_captura.R (chromote)

resultados <- data.frame(publicacion_id = character(), estado = character(),
                         detalle = character(), stringsAsFactors = FALSE)
# Se acumulan las escrituras y se aplican al final, juntas: si una captura falla a la mitad
# no se queda el catalogo parcialmente reescrito.
pendientes <- list()

for (i in seq_len(nrow(ausentes))) {
  fila <- ausentes[i, ]
  pid <- fila$publicacion_id
  message("\n== Recapturando ", pid, " ==")

  cap <- tryCatch(bcr_capturar_xlsx(fila$url, formula = .FORMULA_BASE),
                  error = function(e) e)
  if (inherits(cap, "error")) {
    resultados <- rbind(resultados, data.frame(
      publicacion_id = pid, estado = "ERROR", detalle = conditionMessage(cap),
      stringsAsFactors = FALSE))
    message("   ERROR: ", conditionMessage(cap))
    next
  }

  sha_norm_obtenido <- calcular_sha256_norm(cap$bytes, "xlsx")
  message("   sha256_norm registrado: ", fila$sha256_norm)
  message("   sha256_norm obtenido:   ", sha_norm_obtenido)

  if (!identical(sha_norm_obtenido, fila$sha256_norm)) {
    resultados <- rbind(resultados, data.frame(
      publicacion_id = pid, estado = "IRRECUPERABLE",
      detalle = paste0("el portal sirve otro dato (sha256_norm ", sha_norm_obtenido,
                       " != ", fila$sha256_norm, "): el vintage ", fila$vintage_id,
                       " no se puede restaurar; lo que hay hoy es un vintage distinto"),
      stringsAsFactors = FALSE))
    message("   -> IRRECUPERABLE: no se escribe nada para esta publicacion.")
    next
  }

  pendientes[[pid]] <- list(
    archivo = fila$archivo, bytes = cap$bytes,
    sha256_nuevo = calcular_sha256_raw(cap$bytes),
    sha256_viejo = fila$sha256,
    tamano_nuevo = as.character(length(cap$bytes)),
    tamano_viejo = fila$tamano_bytes
  )
  resultados <- rbind(resultados, data.frame(
    publicacion_id = pid, estado = "RESTAURABLE",
    detalle = "sha256_norm coincide: es el mismo dato", stringsAsFactors = FALSE))
  message("   -> RESTAURABLE: mismo dato, listo para escribir.")
}

message("\n== Resumen de la recaptura ==")
for (i in seq_len(nrow(resultados))) {
  message("   ", formatC(resultados$estado[i], width = -14), resultados$publicacion_id[i])
}

if (length(pendientes) == 0) {
  fallar("ninguna publicacion resulto restaurable. No se escribio nada.")
}

# --- Escritura, toda junta -------------------------------------------------------------
man <- readLines(ruta_manifiesto, encoding = "UTF-8", warn = FALSE)
vin <- readLines(ruta_vintages, encoding = "UTF-8", warn = FALSE)

# La nota dice lo que REALMENTE paso con cada campo. El .xlsx de SheetJS no es determinista
# byte a byte, pero eso no garantiza que cambie: puede volver a empaquetarse igual. Afirmar
# un cambio que no ocurrio seria tan falso como callar uno que si.
nota_restauracion <- function(sha_viejo, sha_nuevo, tam_viejo, tam_nuevo) {
  cambio_sha <- if (identical(sha_viejo, sha_nuevo)) {
    paste0("El sha256 CRUDO resulto identico al registrado (", sha_viejo, "): en esta ocasion ",
           "el empaquetado ZIP salio byte a byte igual. No estaba garantizado -el .xlsx de ",
           "SheetJS no es determinista (prueba F1, ADR-007 nota 2026-08-21)- y por eso la ",
           "identidad del vintage se afirma por sha256_norm, no por este campo.")
  } else {
    paste0("El sha256 CRUDO cambio, de ", sha_viejo, " a ", sha_nuevo, ": el .xlsx que genera ",
           "SheetJS no es determinista byte a byte y el empaquetado ZIP varia entre descargas ",
           "del mismo dato (prueba F1, ADR-007 nota 2026-08-21). Ese campo declara la integridad ",
           "del archivo que esta en disco, y el archivo en disco es materialmente otro; el valor ",
           "historico queda asentado en esta nota.")
  }
  cambio_tam <- if (identical(tam_viejo, tam_nuevo)) {
    paste0(" tamano_bytes no cambio (", tam_viejo, ").")
  } else {
    paste0(" tamano_bytes cambio de ", tam_viejo, " a ", tam_nuevo, ".")
  }
  paste0(
    " ARCHIVO RESTAURADO ", .HOY, " (hallazgo B1 de la auditoria de Fase 2): el .xlsx de este ",
    "vintage se perdio de data/L0_raw/ entre el 2026-08-26 y el 2026-08-28. Se recapturo del ",
    "portal con el mismo mecanismo y parametros que la captura original, y su sha256_norm ",
    "-identidad de vintage- coincide exactamente con el registrado, lo que prueba que el ",
    "contenido es el mismo dato. ", cambio_sha, cambio_tam,
    " fecha_descarga NO se toca: sigue siendo la de la captura original del vintage."
  )
}

escritos <- character(0)
for (pid in names(pendientes)) {
  p <- pendientes[[pid]]
  ruta <- file.path(dir_l0, p$archivo)
  if (file.exists(ruta)) fallar(ruta, " aparecio durante la corrida. No se sobrescribe.")
  writeBin(p$bytes, ruta)
  escritos <- c(escritos, p$archivo)

  # sha256 y tamano_bytes en la fila del manifiesto (identificada por su nombre de archivo)
  idx_m <- grep(p$archivo, man, fixed = TRUE)
  if (length(idx_m) != 1) fallar("esperaba 1 linea del manifiesto con '", p$archivo,
                                  "', hay ", length(idx_m))
  man[idx_m] <- sub(p$sha256_viejo, p$sha256_nuevo, man[idx_m], fixed = TRUE)
  man[idx_m] <- sub(paste0(",\"", p$tamano_viejo, "\","), paste0(",\"", p$tamano_nuevo, "\","),
                    man[idx_m], fixed = TRUE)

  # sha256 y nota en la fila de 08_vintages
  idx_v <- grep(p$archivo, vin, fixed = TRUE)
  if (length(idx_v) != 1) fallar("esperaba 1 linea de 08_vintages con '", p$archivo,
                                  "', hay ", length(idx_v))
  vin[idx_v] <- sub(p$sha256_viejo, p$sha256_nuevo, vin[idx_v], fixed = TRUE)
  nota <- nota_restauracion(p$sha256_viejo, p$sha256_nuevo, p$tamano_viejo, p$tamano_nuevo)
  # la nota va al final del ultimo campo (notas), justo antes de la comilla de cierre
  vin[idx_v] <- sub("\"$", paste0(gsub("\"", "\"\"", nota), "\""), vin[idx_v])
}

writeLines(man, con = file(ruta_manifiesto, open = "wb", encoding = "UTF-8"), sep = "\n")
writeLines(vin, con = file(ruta_vintages, open = "wb", encoding = "UTF-8"), sep = "\n")

message("\nRestaurados ", length(escritos), " archivo(s) de L0 y actualizadas sus filas:")
for (a in escritos) message("   ", a)

irrecuperables <- resultados[resultados$estado == "IRRECUPERABLE", ]
errores <- resultados[resultados$estado == "ERROR", ]
if (nrow(irrecuperables) > 0 || nrow(errores) > 0) {
  message("\nQUEDAN SIN RESOLVER: ", nrow(irrecuperables), " irrecuperable(s), ",
          nrow(errores), " con error de captura. Ver detalle arriba. Que hacer con esas filas ",
          "vuelve a ser decision de Harold (regla 4 de CLAUDE.md).")
}

message("\nComprobar ahora:\n",
        "   Rscript scripts/verificar_l0_fisico.R\n",
        "   Rscript scripts/check_l0_integrity.R")
