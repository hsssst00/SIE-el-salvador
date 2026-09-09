# scripts/materializar_l0.R
# Materializa data/L0_raw/ a partir de un almacen canonico local (una copia de trabajo del
# repo privado de L0), copiando los archivos que falten. NO descarga de ninguna fuente y NO
# toca el manifiesto: solo repone archivos ya registrados que no estan en esta maquina.
#
# POR QUE EXISTE. Los archivos crudos de L0 estan en .gitignore (ADR-008: el default
# conservador publica script + checksum, nunca el archivo). En consecuencia L0 vive solo en
# las maquinas de trabajo, y un clon limpio no la tiene. Hasta el 2026-09-09 no habia forma
# reproducible de repoblarla en una maquina nueva salvo recapturar de las fuentes -que para
# el BCR es irreversible (ADR-007) y para todas es carga innecesaria sobre la fuente-.
# El almacen canonico es un repo PRIVADO (no redistribuye: no es el acto #4 consultado al
# BCR, es el acto #1 -conservacion local con procedencia- en mas de una maquina). Este
# script es el puente almacen -> data/L0_raw/.
#
# QUE HACE, POR FILA DEL MANIFIESTO:
#   - si el archivo ya esta en data/L0_raw/  -> no se toca (su integridad la comprueba
#     verificar_l0_fisico.R; este script no decide si un archivo existente esta bien);
#   - si falta y esta en el almacen           -> se copia con el nombre registrado;
#   - si falta y tampoco esta en el almacen   -> FALTA_EN_ALMACEN, y el script sale != 0.
#
# NUNCA sobrescribe un archivo existente (regla 1 de CLAUDE.md: L0 es inmutable; reponer un
# ausente no es editar un existente). La direccion inversa -un archivo capturado en esta
# maquina que todavia no esta en el almacen- esta FUERA DE ALCANCE: eso se sube al repo
# privado con `git add` desde la copia de trabajo del almacen, deliberadamente.
#
# USO:
#   SIE_L0_STORE=/ruta/a/copia-de-trabajo-del-repo-privado  Rscript scripts/materializar_l0.R
#   # o, en la sesion de R, Sys.setenv(SIE_L0_STORE = "...") antes de correrlo.
# Luego: make raw-fisico   (o el target make materializar-l0 encadena ambos).
#
# Falla de forma visible (regla 6 de CLAUDE.md).

ruta_manifiesto <- "data/L0_raw/manifiesto.csv"
dir_l0 <- "data/L0_raw"

fallar <- function(...) stop("FALLO VISIBLE [materializar-l0]: ", ..., call. = FALSE)

almacen <- Sys.getenv("SIE_L0_STORE", unset = NA_character_)
if (is.na(almacen) || !nzchar(almacen)) {
  fallar("la variable de entorno SIE_L0_STORE no esta definida. Debe apuntar a una copia de ",
         "trabajo local del repo privado de L0 (el directorio que contiene los .xlsx/.json/",
         ".csv con los nombres registrados en el manifiesto).")
}
if (!dir.exists(almacen)) {
  fallar("SIE_L0_STORE apunta a '", almacen, "', que no es un directorio existente.")
}
if (!file.exists(ruta_manifiesto)) {
  fallar("no existe ", ruta_manifiesto, " - correr este script desde la raiz del repo.")
}

manifiesto <- utils::read.csv(ruta_manifiesto, stringsAsFactors = FALSE,
                              colClasses = "character", fileEncoding = "UTF-8")

if (!"archivo" %in% names(manifiesto)) {
  fallar("el manifiesto no tiene columna 'archivo'.")
}

resultados <- data.frame(archivo = character(), estado = character(), detalle = character(),
                         stringsAsFactors = FALSE)

for (i in seq_len(nrow(manifiesto))) {
  nombre <- manifiesto$archivo[i]
  destino <- file.path(dir_l0, nombre)
  origen <- file.path(almacen, nombre)

  if (file.exists(destino)) {
    resultados <- rbind(resultados, data.frame(
      archivo = nombre, estado = "YA_PRESENTE",
      detalle = "no se toca; su integridad la comprueba verificar_l0_fisico.R",
      stringsAsFactors = FALSE))
    next
  }

  if (!file.exists(origen)) {
    resultados <- rbind(resultados, data.frame(
      archivo = nombre, estado = "FALTA_EN_ALMACEN",
      detalle = paste0("no esta en data/L0_raw/ ni en ", almacen),
      stringsAsFactors = FALSE))
    next
  }

  ok <- file.copy(from = origen, to = destino, overwrite = FALSE, copy.mode = TRUE,
                  copy.date = TRUE)
  if (!ok || !file.exists(destino)) {
    resultados <- rbind(resultados, data.frame(
      archivo = nombre, estado = "ERROR_COPIA",
      detalle = paste0("file.copy() no pudo copiar ", origen, " -> ", destino),
      stringsAsFactors = FALSE))
    next
  }
  resultados <- rbind(resultados, data.frame(
    archivo = nombre, estado = "COPIADO", detalle = paste0("desde ", origen),
    stringsAsFactors = FALSE))
}

for (i in seq_len(nrow(resultados))) {
  if (resultados$estado[i] != "YA_PRESENTE") {
    cat(sprintf("%-16s | %s | %s\n", resultados$estado[i], resultados$archivo[i],
                resultados$detalle[i]))
  }
}

n_presente <- sum(resultados$estado == "YA_PRESENTE")
n_copiado  <- sum(resultados$estado == "COPIADO")
n_falta    <- sum(resultados$estado == "FALTA_EN_ALMACEN")
n_error    <- sum(resultados$estado == "ERROR_COPIA")

message(sprintf("Resumen: %d ya presente(s), %d copiado(s), %d falta(n) en el almacen, %d error(es) de copia (de %d filas).",
                n_presente, n_copiado, n_falta, n_error, nrow(manifiesto)))

# Aviso -no fatal- sobre archivos del almacen que el manifiesto no menciona: pueden ser
# capturas nuevas todavia sin registrar, o basura. No es asunto de este script resolverlo.
archivos_almacen <- list.files(almacen, recursive = FALSE)
huerfanos <- setdiff(archivos_almacen, c(manifiesto$archivo, "manifiesto.csv", "README.md",
                                         ".git", ".gitignore", ".gitkeep"))
if (length(huerfanos) > 0) {
  message("AVISO: ", length(huerfanos), " archivo(s) en el almacen sin fila en el manifiesto: ",
          paste(huerfanos, collapse = ", "),
          ". Si son capturas nuevas, corresponde registrarlas con registrar_descarga(); ",
          "si no, revisar el almacen.")
}

if (n_falta > 0 || n_error > 0) {
  fallar(n_falta, " archivo(s) del manifiesto no estan ni aqui ni en el almacen, y ", n_error,
         " no se pudieron copiar. L0 NO quedo completa en esta maquina. Detalle arriba.\n",
         "  - FALTA_EN_ALMACEN sobre todas las filas suele significar SIE_L0_STORE mal ",
         "apuntada, o el repo privado sin actualizar (git pull).\n",
         "  - FALTA_EN_ALMACEN sobre algunas filas significa que esos vintages no estan ",
         "respaldados en el almacen: hay que subirlos desde la maquina que los tenga.")
}

message("OK materializar-l0: ", n_copiado, " archivo(s) repuesto(s), ", n_presente,
        " ya presente(s). Correr ahora `make raw-fisico` para verificar integridad.")
