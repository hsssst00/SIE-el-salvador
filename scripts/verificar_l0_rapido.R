# scripts/verificar_l0_rapido.R
# `make raw-rapido`: PRECHECK barato de las publicaciones del portal del BCR. NO reemplaza a
# `make raw` (ver el limite en src/adquisicion/verificacion_rapida.R: no ve revisiones de
# valores de periodos viejos). No captura nada ni toca L0 ni los catalogos.
#
#     Rscript scripts/verificar_l0_rapido.R              # nivel 1 + nivel 2
#     Rscript scripts/verificar_l0_rapido.R calendario   # solo nivel 1: sin red ni navegador
#
# Regla 9: una pasada por ventana (doc/calendario_make_raw.md), no en bucle. El nivel 2 abre
# el navegador solo para lo que el nivel 1 no descarta. Un ERROR de fuente detiene el script
# de forma visible (regla 6); NUEVO_PERIODO no es un fallo: es la senal de capturar.

source("src/adquisicion/lib_adquisicion.R")
source("src/transformacion/vintage_lib.R")         # leer_vintages
source("src/adquisicion/verificacion_rapida.R")

alcance <- local({
  a <- commandArgs(trailingOnly = TRUE)
  a <- if (length(a) == 0) "todo" else tolower(a[1])
  if (!a %in% c("todo", "calendario")) {
    stop("FALLO VISIBLE: alcance '", a, "' no reconocido. Use: todo | calendario")
  }
  a
})

manifiesto <- read.csv("data/L0_raw/manifiesto.csv", stringsAsFactors = FALSE, colClasses = "character")
vintages   <- leer_vintages()
calendario <- read.csv("doc/calendario_divulgacion_bcr.csv", stringsAsFactors = FALSE, encoding = "UTF-8")

# Publicaciones servidas por el componente vista-serie (misma regla de host que .mecanismo en
# verificar_l0.R); deja fuera el .xlsx estatico de la retropolada, que no es vista-serie.
vigentes <- do.call(rbind, lapply(unique(manifiesto$publicacion_id), function(pid) {
  f <- manifiesto[manifiesto$publicacion_id == pid, ]
  f[nrow(f), ]
}))
trabajo <- vigentes[startsWith(vigentes$url, "https://estadisticas.bcr.gob.sv/serie/"), ]
trabajo <- trabajo[order(trabajo$publicacion_id), ]
if (nrow(trabajo) == 0) stop("FALLO VISIBLE: el manifiesto no tiene publicaciones vista-serie.")

trabajo$periodo_max <- vintages$periodo_referencia_max[match(trabajo$archivo, vintages$archivo_raw)]
if (anyNA(trabajo$periodo_max)) {
  stop("FALLO VISIBLE: sin vintage en 08_vintages.csv para el archivo vigente de: ",
       paste(trabajo$publicacion_id[is.na(trabajo$periodo_max)], collapse = ", "))
}

message("Nivel 1 (calendario, sin red) - ", nrow(trabajo), " publicacion(es), hoy ", Sys.Date(), "\n")
n1 <- lapply(seq_len(nrow(trabajo)), function(i) {
  estado_calendario(trabajo$publicacion_id[i], trabajo$periodo_max[i], calendario)
})
trabajo$estado1 <- vapply(n1, `[[`, character(1), "estado")
for (i in seq_len(nrow(trabajo))) {
  message("   ", formatC(trabajo$estado1[i], width = -15), formatC(trabajo$publicacion_id[i], width = -42),
          n1[[i]]$detalle)
}

trabajo$estado <- trabajo$estado1
trabajo$detalle <- vapply(n1, `[[`, character(1), "detalle")

errores <- character()
a_sondear <- trabajo$estado1 != "NO_TOCA"
if (alcance == "todo" && any(a_sondear)) {
  source("src/adquisicion/bcr_captura.R")
  message("\nNivel 2 (sondeo, navegador) - ", sum(a_sondear), " publicacion(es)\n")
  for (i in which(a_sondear)) {
    pid <- trabajo$publicacion_id[i]
    message("== ", pid, " (vigente ", trabajo$periodo_max[i], ") ==")
    r <- tryCatch({
      s <- bcr_sondear_ultimo_periodo(trabajo$url[i])
      estado_sondeo(trabajo$periodo_max[i], s$ultimo_periodo)
    }, error = function(e) list(estado = "ERROR", detalle = conditionMessage(e)))
    trabajo$estado[i]  <- r$estado
    trabajo$detalle[i] <- r$detalle
    message("   ", r$estado, ": ", r$detalle)
    if (r$estado == "ERROR") errores <- c(errores, pid)
  }
} else if (alcance == "calendario") {
  message("\nAlcance 'calendario': no se sondea nada.")
}

message("\n== Resumen ==")
for (i in seq_len(nrow(trabajo))) {
  message("   ", formatC(trabajo$estado[i], width = -15), trabajo$publicacion_id[i])
}

nuevos <- trabajo$publicacion_id[trabajo$estado == "NUEVO_PERIODO"]
if (length(nuevos) > 0) {
  message("\n== ", length(nuevos), " NUEVO_PERIODO: capturar con descargar_*() (regla 9, una pasada) ==")
  message(paste0("   ", nuevos, collapse = "\n"))
}
if (alcance == "todo" && length(errores) > 0) {
  stop("FALLO VISIBLE: ", length(errores), " publicacion(es) no se pudieron sondear: ",
       paste(errores, collapse = ", "), ". Ver el detalle arriba.")
}
pend <- trabajo$publicacion_id[trabajo$estado %in% c("TOCA", "SIN_CALENDARIO")]
message("\nOK verificar-l0-rapido: ", sum(trabajo$estado == "NO_TOCA"), " NO_TOCA, ",
        sum(trabajo$estado == "SIN_NUEVO"), " SIN_NUEVO, ", length(nuevos), " NUEVO_PERIODO",
        if (alcance == "calendario") paste0(", ", length(pend), " sin sondear") else "",
        ". Limite: no ve revisiones de valores viejos; eso es `make raw`.")
