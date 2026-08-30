# scripts/verificar_l0_fisico.R
# Verificacion FISICA de L0: cada fila del manifiesto tiene su archivo en disco, con el
# sha256 y el tamano que el manifiesto declara.
#
# POR QUE EXISTE. Hasta el 2026-08-28 el repositorio tenia dos verificaciones de L0 y
# ninguna de las dos respondia "el archivo sigue ahi":
#   - scripts/check_l0_integrity.R  -> cruzada OFFLINE (manifiesto <-> 08_vintages). Corre en
#     CI. Solo lee texto: pasa en verde aunque data/L0_raw/ este vacio.
#   - scripts/verificar_l0.R        -> re-captura EN VIVO del portal y compara sha256_norm.
#     No mira el disco: compara el portal contra el manifiesto.
# El hueco lo materializo el hallazgo B1 de la auditoria de Fase 2: los 12 archivos del lote
# BCR del 2026-08-26 desaparecieron de data/L0_raw/ y las dos verificaciones siguieron en
# verde. Este script cierra ese hueco (regla 1 de CLAUDE.md: L0 es inmutable; una ausencia
# silenciosa es la forma mas barata de violarla).
#
# QUE COMPRUEBA, POR FILA DEL MANIFIESTO:
#   1. el archivo existe en data/L0_raw/;
#   2. su sha256 real coincide con el declarado -integridad del archivo crudo (ADR-007,
#      nota 2026-08-21: sha256 es integridad, sha256_norm es identidad de vintage);
#   3. su tamano en bytes coincide con el declarado.
#
# LOS DOS MODOS, Y POR QUE. Los .xlsx/.json/.csv de L0 estan en .gitignore (ADR-008), asi
# que en un clon limpio -CI incluido- la ausencia de TODOS los archivos es el estado normal
# y no es un hallazgo. Lo que si es un hallazgo es que falten ALGUNOS. De ahi la regla:
#   - L0 NO materializada (0 archivos presentes) -> modo informativo, sale 0.
#   - L0 materializada (>=1 archivo presente)    -> toda ausencia es FAIL, sale != 0.
# La regla es mecanica y no necesita saber en que maquina corre: si esta maquina tiene L0,
# la tiene completa o esta rota.
#
# Falla de forma visible (regla 6 de CLAUDE.md): stop() con el detalle por archivo.

ruta_manifiesto <- "data/L0_raw/manifiesto.csv"
dir_l0 <- "data/L0_raw"

fallar <- function(...) stop("FALLO VISIBLE [verificar-l0-fisico]: ", ..., call. = FALSE)

if (!requireNamespace("digest", quietly = TRUE)) {
  fallar("el paquete 'digest' no esta instalado. Corra renv::restore() antes de este script.")
}
if (!file.exists(ruta_manifiesto)) {
  fallar("no existe ", ruta_manifiesto, " - no correr este script fuera de la raiz del repo.")
}

manifiesto <- utils::read.csv(ruta_manifiesto, stringsAsFactors = FALSE,
                              colClasses = "character", fileEncoding = "UTF-8")

verificar_fila <- function(fila) {
  ruta <- file.path(dir_l0, fila$archivo)

  if (!file.exists(ruta)) {
    return(list(estado = "AUSENTE", detalle = "el archivo no esta en data/L0_raw/"))
  }

  sha_real <- tolower(digest::digest(object = ruta, algo = "sha256", file = TRUE))
  if (!identical(sha_real, tolower(fila$sha256))) {
    return(list(
      estado = "FAIL",
      detalle = paste0("sha256 no coincide (manifiesto: ", fila$sha256, "; archivo: ", sha_real, ")")
    ))
  }

  tamano_real <- file.info(ruta)$size
  if (!identical(as.character(tamano_real), fila$tamano_bytes)) {
    return(list(
      estado = "FAIL",
      detalle = paste0("tamano_bytes no coincide (manifiesto: ", fila$tamano_bytes,
                       "; archivo: ", tamano_real, ")")
    ))
  }

  list(estado = "PASS", detalle = paste0("sha256 y tamano coinciden (", tamano_real, " bytes)"))
}

resultados <- do.call(rbind, lapply(seq_len(nrow(manifiesto)), function(i) {
  r <- verificar_fila(manifiesto[i, ])
  data.frame(archivo = manifiesto$archivo[i], publicacion_id = manifiesto$publicacion_id[i],
             vintage_id = manifiesto$vintage_id[i], estado = r$estado, detalle = r$detalle,
             stringsAsFactors = FALSE)
}))

n_pass    <- sum(resultados$estado == "PASS")
n_fail    <- sum(resultados$estado == "FAIL")
n_ausente <- sum(resultados$estado == "AUSENTE")
l0_materializada <- n_pass + n_fail > 0

for (i in seq_len(nrow(resultados))) {
  if (resultados$estado[i] != "PASS") {
    cat(sprintf("%s | %s | %s\n", resultados$estado[i], resultados$archivo[i], resultados$detalle[i]))
  }
}

message(sprintf("Resumen: %d PASS, %d FAIL, %d AUSENTE (de %d filas del manifiesto).",
                n_pass, n_fail, n_ausente, nrow(resultados)))

if (!l0_materializada) {
  message(
    "L0 NO materializada en esta maquina (0 de ", nrow(resultados), " archivos presentes). ",
    "Es el estado normal de un clon limpio y de CI: los archivos crudos estan en .gitignore ",
    "(ADR-008). No se verifico ninguna integridad fisica; la consistencia cruzada la cubre ",
    "scripts/check_l0_integrity.R."
  )
  quit(status = 0)
}

if (n_fail > 0 || n_ausente > 0) {
  fallar(
    n_fail, " archivo(s) con checksum/tamano distinto del declarado y ", n_ausente,
    " ausente(s), sobre una L0 que SI esta materializada en esta maquina (", n_pass,
    " archivo(s) presentes y correctos). Detalle arriba.\n",
    "  - Un FAIL significa que el archivo de L0 cambio despues de registrarse: L0 es inmutable ",
    "(regla 1 de CLAUDE.md), asi que esto no se 'corrige' reescribiendo el manifiesto.\n",
    "  - Un AUSENTE sobre L0 materializada significa que el archivo se perdio. Recapturarlo ",
    "reproduce el sha256_norm (identidad de vintage, estable por construccion) pero NO el ",
    "sha256 crudo en las fuentes tipo contenedor: el .xlsx de SheetJS no es determinista byte ",
    "a byte (ADR-007, nota 2026-08-21). Que hacer con esas filas es decision de politica de ",
    "L0, no una limpieza."
  )
}

message("OK verificar-l0-fisico: ", n_pass, "/", nrow(resultados),
        " archivo(s) de L0 presentes, integros y del tamano declarado.")
