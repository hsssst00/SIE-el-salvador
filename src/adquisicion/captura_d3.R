# captura_d3.R
#
# Captura fuera de ventana asistida (ADR-007 D3; ficha F7-13 de doc/metodologia/decisiones_fase7.md).
# Uso, desde la CONSOLA de R con el proyecto abierto (no desde make ni Rscript: hay que contestar):
#
#     source("src/adquisicion/captura_d3.R")
#     captura_d3()
#
# Que hace:
#   1. Una pasada de `make raw-rapido` (scripts/verificar_l0_rapido.R). Una sola: regla 9.
#   2. Para cada NUEVO_PERIODO comprueba las otras dos condiciones de D3 (el calendario ya lo
#      anuncia; es el primer vintage de ese periodo) y muestra la tabla de candidatas.
#   3. Pregunta, publicacion por publicacion, si se captura. Solo con «s» llama a su
#      descargar_*() con fecha_publicacion = AAAA-MM-01 del mes que anuncia el calendario.
#   4. Corre scripts/verificar_l0_fisico.R e imprime la nota fechada para pegar en
#      doc/backlog_captura_vintages.md.
#
# Fuera de una sesion interactiva no captura nada: muestra la tabla y los comandos. Un fallo de
# captura no se reintenta solo (regla 9): se informa y se sigue con la siguiente.

source("src/adquisicion/verificacion_rapida.R")
source("src/adquisicion/captura_d3_lib.R")
source("src/transformacion/vintage_lib.R")   # leer_vintages

captura_d3 <- function(hoy = Sys.Date()) {
  message("== 1. Una pasada de raw-rapido (regla 9) ==")
  env <- new.env()
  source("scripts/verificar_l0_rapido.R", local = env)   # se detiene de forma visible ante un ERROR
  calendario <- read.csv("doc/calendario_divulgacion_bcr.csv", stringsAsFactors = FALSE, encoding = "UTF-8")
  ev <- evaluar_candidatas_d3(env$trabajo, leer_vintages(), calendario, hoy)

  message("\n== 2. Condiciones de D3 ==")
  if (nrow(ev) == 0) {
    message("Ningun NUEVO_PERIODO: no hay nada que capturar fuera de ventana.")
    return(invisible(ev))
  }
  print(ev[, c("publicacion_id", "periodo_max", "periodo_fuente", "fecha_calendario", "cumple", "motivo")],
        row.names = FALSE)
  candidatas <- ev[ev$cumple, , drop = FALSE]
  if (nrow(candidatas) == 0) {
    message("\nNinguna cumple las tres condiciones. Nota para el backlog:\n")
    cat(nota_backlog_d3(ev, character(), hoy), "\n")
    return(invisible(ev))
  }
  if (!interactive()) {
    message("\nSesion no interactiva: no se captura nada. Para confirmar, corre captura_d3() desde la ",
            "consola de R. Comandos que se usarian:")
    message(paste0("   ", candidatas$comando, collapse = "\n"))
    return(invisible(ev))
  }

  message("\n== 3. Confirmacion, una publicacion a la vez ==")
  source("src/adquisicion/bcr.R")
  capturadas <- character()
  for (i in seq_len(nrow(candidatas))) {
    c_ <- candidatas[i, ]
    resp <- readline(sprintf("Capturar %s (%s -> %s) con %s? (s/n): ", c_$publicacion_id, c_$periodo_max,
                             c_$periodo_fuente, c_$comando))
    if (!tolower(trimws(resp)) %in% c("s", "si", "s\u00ed")) {
      message("   no se captura")
      next
    }
    ok <- tryCatch({
      do.call(c_$funcion, list(c_$fecha_publicacion))
      TRUE
    }, error = function(e) {
      message("   FALLO de captura (no se reintenta; anotar en doc/bitacora_fuentes_fragiles.md si es de la ",
              "fuente): ", conditionMessage(e))
      FALSE
    })
    if (ok) capturadas <- c(capturadas, c_$publicacion_id)
  }

  message("\n== 4. Verificacion de L0 en disco ==")
  if (length(capturadas) > 0) {
    # En un proceso aparte: el script termina con quit() y cerraria esta sesion.
    st <- system2(file.path(R.home("bin"), "Rscript"), "scripts/verificar_l0_fisico.R")
    if (!identical(as.integer(st), 0L)) {
      stop("FALLO VISIBLE: verificar_l0_fisico.R salio con codigo ", st, ". Revisar L0 antes de seguir.")
    }
  } else {
    message("Nada capturado: L0 no cambio.")
  }
  message("\nNota para pegar en doc/backlog_captura_vintages.md:\n")
  cat(nota_backlog_d3(ev, capturadas, hoy), "\n")
  message("\nSiguiente: PR con data/L0_raw/manifiesto.csv, catalogos/08_vintages.csv y la nota del backlog.")
  invisible(ev)
}
