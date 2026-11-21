# captura_d3.R
#
# Captura fuera de ventana asistida (ADR-007 D3; ficha F7-13 de doc/metodologia/decisiones_fase7.md).
# Dos llamadas, sin preguntas interactivas: funcionan en la consola, con Ctrl+Enter, en un chunk o con
# Rscript. Desde la raiz del repo:
#
#     source("src/adquisicion/captura_d3.R")
#     planear_d3()                                   # una pasada de raw-rapido y la tabla de candidatas
#     capturar_d3("BCR.GOBIERNO_CENTRAL_CONSOLIDADO") # solo la publicacion que nombras
#
# planear_d3() corre UNA pasada de `make raw-rapido` (regla 9), comprueba las condiciones 2 y 3 de D3
# para cada NUEVO_PERIODO y guarda el plan del dia. capturar_d3() usa ese plan (no vuelve a sondear),
# captura una sola publicacion que cumpla, corre verificar_l0_fisico.R en un proceso aparte (el script
# termina con quit()) e imprime la nota para doc/backlog_captura_vintages.md. Un fallo de captura no se
# reintenta: la publicacion queda para la ventana.

source("src/adquisicion/verificacion_rapida.R")
source("src/adquisicion/captura_d3_lib.R")
source("src/transformacion/vintage_lib.R")   # leer_vintages

# Plan del dia. Volver a cargar este archivo no lo borra; solo planear_d3() lo reemplaza.
if (!exists(".estado_d3", inherits = FALSE)) .estado_d3 <- new.env()

planear_d3 <- function(hoy = Sys.Date()) {
  message("== Una pasada de raw-rapido (regla 9) ==")
  env <- new.env()
  source("scripts/verificar_l0_rapido.R", local = env)   # se detiene de forma visible ante un ERROR
  calendario <- read.csv("doc/calendario_divulgacion_bcr.csv", stringsAsFactors = FALSE, encoding = "UTF-8")
  plan <- evaluar_candidatas_d3(env$trabajo, leer_vintages(), calendario, hoy)
  attr(plan, "fecha") <- as.Date(hoy)
  assign("plan", plan, envir = .estado_d3)
  assign("capturadas", character(), envir = .estado_d3)
  assign("fallidas", character(), envir = .estado_d3)

  message("\n== Condiciones de D3 ==")
  if (nrow(plan) == 0) {
    message("Ningun NUEVO_PERIODO: no hay nada que capturar fuera de ventana.")
    return(invisible(plan))
  }
  print(plan[, c("publicacion_id", "periodo_max", "periodo_fuente", "fecha_calendario", "cumple", "motivo")],
        row.names = FALSE)
  candidatas <- plan$publicacion_id[plan$cumple]
  if (length(candidatas) == 0) {
    message("\nNinguna cumple las tres condiciones. Nota para el backlog: nota_d3()")
  } else {
    message("\nPara capturar, una a la vez:")
    message(paste0('   capturar_d3("', candidatas, '")', collapse = "\n"))
  }
  invisible(plan)
}

capturar_d3 <- function(publicacion_id, hoy = Sys.Date()) {
  fila <- validar_captura_d3(.estado_d3$plan, publicacion_id, leer_vintages(), hoy,
                             .estado_d3$capturadas, .estado_d3$fallidas)
  funciones <- new.env()
  source("src/adquisicion/bcr.R", local = funciones)
  message("== Capturando ", publicacion_id, " con ", fila$comando, " ==")
  ok <- tryCatch({
    do.call(get(fila$funcion, envir = funciones), list(fila$fecha_publicacion))
    TRUE
  }, error = function(e) {
    message("FALLO de captura: ", conditionMessage(e))
    FALSE
  })
  if (!ok) {
    assign("fallidas", c(.estado_d3$fallidas, publicacion_id), envir = .estado_d3)
    stop("FALLO VISIBLE: no se capturo ", publicacion_id, ". No se reintenta (regla 9); queda para la ventana. ",
         "Si es de la fuente, anotalo en doc/bitacora_fuentes_fragiles.md. Nota para el backlog: nota_d3()")
  }
  assign("capturadas", c(.estado_d3$capturadas, publicacion_id), envir = .estado_d3)
  message("\n== Verificacion de L0 en disco (proceso aparte) ==")
  st <- system2(file.path(R.home("bin"), "Rscript"), "scripts/verificar_l0_fisico.R")
  if (!identical(as.integer(st), 0L)) {
    stop("FALLO VISIBLE: verificar_l0_fisico.R salio con codigo ", st, ". Revisar L0 antes de seguir.")
  }
  nota_d3()
  invisible(TRUE)
}

nota_d3 <- function() {
  if (is.null(.estado_d3$plan)) stop("FALLO VISIBLE: no hay plan. Corre primero planear_d3().")
  message("\nNota para pegar en doc/backlog_captura_vintages.md:\n")
  cat(nota_backlog_d3(.estado_d3$plan, .estado_d3$capturadas, attr(.estado_d3$plan, "fecha"),
                      .estado_d3$fallidas), "\n")
  invisible(NULL)
}
