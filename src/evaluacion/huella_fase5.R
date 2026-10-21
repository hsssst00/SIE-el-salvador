# huella_fase5.R
#
# Huella de Fase 5 frente a una referencia fija (checklist de Fase 6, D1; F6-06 y F6-12: «DISENO_FASE4 no cambia, y
# CI comprueba que los F5_REPRO_* siguen bit a bit»). V21 de verificar_motor_sintetico.R ya corre, sobre insumos
# sintéticos, los benchmarks (los modelos de F5_REPRO_*), los 12 modelos de Fase 5 de G2 y sus combinaciones, y
# comprueba que dos corridas coinciden entre sí. V21b toma esa misma corrida y compara un sha256 por modelo_id con
# src/evaluacion/referencias/huella_fase5.csv, tomada antes de que Fase 6 tocara el código de los modelos: un
# cambio de Fase 6 que mueva un solo byte de un pronóstico, una densidad o un diagnóstico de Fase 5 se detiene.
#
# La referencia es por plataforma (sistema, versión de R y BLAS), porque el redondeo depende de la librería de
# álgebra lineal (F5-15, nota I4): una fila por (plataforma, modelo_id). Hoy declara Windows (la máquina de la corrida
# única) y el Linux del CI con la BLAS de referencia. En una plataforma sin filas, V21b se detiene en CI e informa
# fuera de CI. Delegada al agente (F6-06-b); se puede reabrir.

RUTA_REFERENCIA_HUELLA_FASE5 <- c("src", "evaluacion", "referencias", "huella_fase5.csv")
COLUMNAS_HUELLA_FASE5 <- c("plataforma", "modelo_id", "sha256")

#' Clave de plataforma de la huella: sistema, versión de R y nombre del archivo de la BLAS. En Windows,
#' extSoftVersion() no nombra la BLAS interna de R y queda como «Rblas».
plataforma_huella <- function() {
  blas <- basename(extSoftVersion()[["BLAS"]])
  sprintf("%s|R %s|%s", Sys.info()[["sysname"]], getRversion(), if (nzchar(blas)) blas else "Rblas")
}

#' sha256 por modelo_id de las salidas de una corrida: sus filas de `p` (pronósticos y densidades, ordenadas por
#' origen y h, sin nombres de fila ni atributos) y sus filas de `d` (diagnósticos), si las hay. Pura.
huella_por_modelo <- function(p, d = NULL) {
  attr(p, "diagnosticos") <- NULL
  ids <- sort(unique(p$modelo_id))
  sha <- vapply(ids, function(id) {
    f <- p[p$modelo_id == id, , drop = FALSE]
    f <- f[order(f$origen, f$h), , drop = FALSE]; rownames(f) <- NULL
    g <- if (is.null(d)) NULL else d[d$modelo_id == id, , drop = FALSE]
    if (!is.null(g)) { g <- g[order(g$origen, g$clave), , drop = FALSE]; rownames(g) <- NULL }
    digest::digest(list(f, g), algo = "sha256")
  }, character(1))
  data.frame(modelo_id = ids, sha256 = unname(sha), stringsAsFactors = FALSE)
}

.ruta_huella_fase5 <- function() do.call(here::here, as.list(RUTA_REFERENCIA_HUELLA_FASE5))

#' Lee la referencia. Falla visible si falta el archivo, si las columnas no son las declaradas o si un par
#' (plataforma, modelo_id) se repite.
leer_referencia_huella <- function(ruta = .ruta_huella_fase5()) {
  if (!file.exists(ruta)) stop("FALLO VISIBLE: no existe la referencia de la huella de Fase 5: ", ruta)
  r <- utils::read.csv(ruta, stringsAsFactors = FALSE, colClasses = "character", na.strings = "")
  if (!identical(names(r), COLUMNAS_HUELLA_FASE5)) {
    stop("FALLO VISIBLE: ", ruta, " debe tener las columnas ", paste(COLUMNAS_HUELLA_FASE5, collapse = ","))
  }
  if (anyNA(r)) stop("FALLO VISIBLE: ", ruta, " tiene celdas vacías")
  if (anyDuplicated(r[, c("plataforma", "modelo_id")])) stop("FALLO VISIBLE: ", ruta, " repite un par (plataforma, modelo_id)")
  r
}

#' Compara la huella actual con las filas de la referencia de `plataforma`. Devuelve una lista con `estado`
#' ("igual", "distinta" o "sin_referencia") y los modelo_id distintos, faltantes en la corrida y sin referencia. Pura.
comparar_huella <- function(actual, referencia, plataforma) {
  r <- referencia[referencia$plataforma == plataforma, , drop = FALSE]
  if (!nrow(r)) return(list(estado = "sin_referencia", distintos = character(0), faltan = character(0), sobran = character(0)))
  comunes <- intersect(actual$modelo_id, r$modelo_id)
  distintos <- comunes[actual$sha256[match(comunes, actual$modelo_id)] != r$sha256[match(comunes, r$modelo_id)]]
  faltan <- setdiff(r$modelo_id, actual$modelo_id)
  sobran <- setdiff(actual$modelo_id, r$modelo_id)
  estado <- if (length(distintos) || length(faltan) || length(sobran)) "distinta" else "igual"
  list(estado = estado, distintos = sort(distintos), faltan = sort(faltan), sobran = sort(sobran))
}

#' Filas CSV de la huella actual para `plataforma`, listas para pegar en la referencia.
filas_huella <- function(actual, plataforma) {
  sprintf("\"%s\",\"%s\",\"%s\"", plataforma, actual$modelo_id, actual$sha256)
}
