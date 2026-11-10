# src/proyeccion/tablas_informe_fase6.R
#
# Tablas del informe de proyección de Fase 6 (checklist F2). Las salidas de `make fase6` viven en
# data/L4_experiments/F6_*/, que no se versiona; este script las copia a doc/metodologia/reportes_fase6/ para que el
# informe cite archivos versionados. No recalcula nada: une las tablas de los tres grupos línea a línea, con el texto
# tal cual lo escribió correr_fase6.R, y antepone la columna `grupo`. Las tablas de F6_COMUN se copian sin cambios.
#
# Antes de leer, comprueba el sha256 de cada archivo (los bytes tal cual) contra
# doc/metodologia/reportes_fase6/sha256_salidas_fase6.csv. No usa las líneas «salidas (sha256)» de los manifiestos:
# hasta el 2026-11-10 no eran los sha256 de los archivos (decisiones_fase6.md, hechos del 2026-11-10). La lista
# versionada es la de la reproducción de E4 (doc/evidencia_reproduccion_fase6.txt). De los manifiestos solo exige
# «arbol: limpio» y el corte del preregistro.
#
# Uso:  Rscript src/proyeccion/tablas_informe_fase6.R   (o `make tablas-fase6`)
# Regla 7: si falta un archivo, sobra uno sin listar o un sha256 no coincide, falla.

TABLAS_GRUPO_F6 <- c("trimestral", "anual", "guarda", "sensibilidad", "coherencia_signos", "coherencia_weo",
                     "coherencia_historica", "coherencia_deflactor", "diagnosticos")
TABLAS_COMUN_F6 <- c("satelites", "sd_sensibilidad", "senderos_sensibilidad")
GRUPOS_F6 <- c("G1", "G2", "G3")
NOMBRE_SALIDA_F6 <- c(trimestral = "proyeccion_trimestral", anual = "proyeccion_anual")

.leer_lineas_lf <- function(ruta) {
  lin <- readLines(ruta, encoding = "UTF-8", warn = FALSE)
  if (!length(lin)) stop("tablas de Fase 6: ", ruta, " está vacío")
  lin
}

.escribir_lineas_lf <- function(lin, ruta) {
  con <- file(ruta, open = "wb")
  tryCatch(writeLines(enc2utf8(lin), con, sep = "\n", useBytes = TRUE), finally = close(con))
  invisible(ruta)
}

#' Comprueba que los CSV de F6_G* y F6_COMUN son exactamente los listados y con su sha256. Devuelve la lista leída.
verificar_salidas_fase6 <- function(dir_l4, ruta_sha) {
  ref <- utils::read.csv(ruta_sha, colClasses = "character")
  if (!identical(names(ref), c("archivo", "sha256")) || anyDuplicated(ref$archivo))
    stop("tablas de Fase 6: ", ruta_sha, " debe tener columnas archivo,sha256 y un archivo por fila")
  dirs <- c(paste0("F6_", GRUPOS_F6), "F6_COMUN")
  hay <- unlist(lapply(dirs, function(d) file.path(d, list.files(file.path(dir_l4, d), pattern = "\\.csv$"))))
  falta <- setdiff(ref$archivo, hay); sobra <- setdiff(hay, ref$archivo)
  if (length(falta)) stop("tablas de Fase 6: faltan en L4: ", paste(falta, collapse = ", "))
  if (length(sobra)) stop("tablas de Fase 6: archivos de L4 sin sha256 de referencia: ", paste(sobra, collapse = ", "))
  real <- vapply(ref$archivo, function(a) digest::digest(file = file.path(dir_l4, a), algo = "sha256"), character(1))
  mal <- ref$archivo[real != ref$sha256]
  if (length(mal)) stop("tablas de Fase 6: sha256 distinto del de referencia en: ", paste(mal, collapse = ", "))
  ref
}

#' Comprueba en cada manifiesto el árbol limpio y que el corte es el que congeló el preregistro.
verificar_manifiestos_fase6 <- function(dir_l4, corte_sha256) {
  for (d in c(paste0("F6_", GRUPOS_F6), "F6_COMUN")) {
    lin <- .leer_lineas_lf(file.path(dir_l4, d, "manifiesto.txt"))
    if (!"arbol: limpio" %in% lin) stop("tablas de Fase 6: ", d, " no viene de un árbol limpio")
    if (!any(grepl(paste0("sha256 sin CR ", corte_sha256), lin, fixed = TRUE)))
      stop("tablas de Fase 6: el corte de ", d, " no es el del preregistro (", substr(corte_sha256, 1, 8), "…)")
  }
  invisible(TRUE)
}

#' Une una tabla de los grupos que la tienen, con `grupo` como primera columna. Exige el mismo encabezado en todos.
unir_tabla_grupos <- function(dir_l4, tabla) {
  rutas <- file.path(dir_l4, paste0("F6_", GRUPOS_F6), paste0(tabla, ".csv"))
  esta <- file.exists(rutas)
  if (!any(esta)) stop("tablas de Fase 6: ningún grupo tiene ", tabla, ".csv")
  partes <- lapply(which(esta), function(i) .leer_lineas_lf(rutas[i]))
  cab <- unique(vapply(partes, `[`, character(1), 1L))
  if (length(cab) != 1L) stop("tablas de Fase 6: ", tabla, ".csv no tiene el mismo encabezado en todos los grupos")
  c(paste0("\"grupo\",", cab),
    unlist(Map(function(lin, g) if (length(lin) > 1L) paste0("\"", g, "\",", lin[-1L]) else character(0), partes, GRUPOS_F6[esta])))
}

escribir_tablas_fase6 <- function(dir_l4 = here::here("data", "L4_experiments"),
                                  dir_salida = here::here("doc", "metodologia", "reportes_fase6"),
                                  ruta_sha = file.path(dir_salida, "sha256_salidas_fase6.csv"),
                                  corte_sha256 = NULL) {
  verificar_salidas_fase6(dir_l4, ruta_sha)
  if (!is.null(corte_sha256)) verificar_manifiestos_fase6(dir_l4, corte_sha256)
  dir.create(dir_salida, showWarnings = FALSE, recursive = TRUE)
  escritos <- character(0)
  for (t in TABLAS_GRUPO_F6) {
    nom <- if (t %in% names(NOMBRE_SALIDA_F6)) NOMBRE_SALIDA_F6[[t]] else t
    ruta <- file.path(dir_salida, paste0(nom, "_fase6.csv"))
    escritos <- c(escritos, .escribir_lineas_lf(unir_tabla_grupos(dir_l4, t), ruta))
  }
  for (t in TABLAS_COMUN_F6) {
    ruta <- file.path(dir_salida, paste0(t, "_fase6.csv"))
    escritos <- c(escritos, .escribir_lineas_lf(.leer_lineas_lf(file.path(dir_l4, "F6_COMUN", paste0(t, ".csv"))), ruta))
  }
  invisible(escritos)
}

main <- function() {
  prereg <- yaml::read_yaml(here::here("doc", "metodologia", "preregistro_fase6.yaml"))
  escritos <- escribir_tablas_fase6(corte_sha256 = prereg$corte_sha256_sin_cr)
  for (r in escritos) cat(sprintf("OK %s  %d filas\n", basename(r), length(readLines(r)) - 1L))
}

if (sys.nframe() == 0L) main()
