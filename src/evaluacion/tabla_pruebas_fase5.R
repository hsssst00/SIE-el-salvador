# src/evaluacion/tabla_pruebas_fase5.R
#
# Tabla de pruebas de Fase 5 (remediación del hallazgo I3 de la auditoría independiente de Fase 5): DM/HLN y GW
# (pruebas.csv y pruebas_submuestras.csv) y el contraste de estabilidad de R3 (estabilidad.csv) de los F5_G* de la
# corrida única, más el extracto de los pronósticos que cita el informe de lectura (§3.3). Hasta ahora esas cifras
# vivían solo en data/L4_experiments/, que no se versiona. No recalcula nada: copia lo que escribió
# motor_backtesting.R, en la unidad primaria (yoy_pp), y antes de leer cada archivo comprueba que su sha256 es el que
# lista el manifiesto del experimento, y que el manifiesto es de la corrida registrada en catalogos/07_experimentos.csv
# (el commit_hash de las filas `<exp_id>__*`; hoy, e1722fa) y con árbol limpio.
#
# No agrega reglas de lectura. `marca_tamano` y `varianza` son las del motor. `marca_n` es la misma marca de la tabla
# de resultados (F4-35, V9): se decide por el n de la CELDA (exp_id, muestra_eval, h), que es el n_pares de DM/HLN, y
# no por el n_pares de cada fila (en GW, n_pares = n - h). Al generar, se comprueba contra tabla_resultados_fase5.csv.
#
# Uso:  Rscript src/evaluacion/tabla_pruebas_fase5.R   (lo corre `make eval` después de tabla_resultados_fase5.R)
#
# Escribe, versionados y en LF:
#   doc/metodologia/reportes_fase5/tabla_pruebas_fase5.csv
#   doc/metodologia/reportes_fase5/tabla_estabilidad_fase5.csv
#   doc/metodologia/reportes_fase5/extracto_pronosticos_fase5.csv
# Regla 7: si falta un experimento declarado, un archivo no casa con su manifiesto o las marcas no coinciden, falla.

source(here::here("src", "evaluacion", "tabla_resultados_fase5.R"))   # experimentos_tabla_fase5(), variante_f5(), etc.

#' Commit registrado en 07_experimentos.csv para cada experimento (filas `<exp_id>__<modelo_id>`); uno por experimento.
commits_registrados <- function(exp_ids, ruta07 = here::here("catalogos", "07_experimentos.csv")) {
  r <- utils::read.csv(ruta07, colClasses = "character", check.names = FALSE, na.strings = character(0))
  vapply(exp_ids, function(x) {
    c_ <- unique(r$commit_hash[startsWith(r$exp_id, paste0(x, "__"))])
    if (length(c_) != 1L || !nzchar(c_)) stop("tabla de pruebas: ", x, " no tiene un único commit registrado en 07_experimentos.csv")
    c_
  }, character(1))
}

COLUMNAS_PRUEBAS_F5 <- c("variante", "muestra_eval", "exp_id", "grupo", "h", "unidad", "prueba", "modelo_a", "modelo_b",
                         "estadistico", "p_valor", "n_pares", "varianza", "media_diferencial", "marca_tamano", "marca_n")
COLUMNAS_ESTABILIDAD_F5 <- c("variante", "exp_id", "grupo", "h", "unidad", "modelo_a", "modelo_b", "media_pre",
                             "cambio_post", "ee_hac", "estadistico", "p_valor", "n_pre", "n_post", "marca_tamano")

# Pronósticos que cita el informe de lectura de Fase 5, §3.3 (pronósticos explosivos aislados en G3). Se extrae el
# corte transversal completo de esos orígenes y horizontes (todos los modelos), no solo las filas citadas, para que la
# mediana entre modelos que cita el informe se pueda recalcular.
CITAS_PRONOSTICOS_F5 <- data.frame(exp_id = "F5_G3", origen = c("2020-Q2", "2021-Q1"), stringsAsFactors = FALSE)
HORIZONTES_CITADOS_F5 <- c(4L, 8L)
COLUMNAS_EXTRACTO_F5 <- c("exp_id", "modelo_id", "grupo", "origen", "h", "periodo_objetivo", "yoy_pp_pronosticado")

#' Lee manifiesto.txt de un experimento y devuelve commit, árbol y los sha256 de las salidas.
leer_manifiesto <- function(d) {
  ruta <- file.path(d, "manifiesto.txt")
  if (!file.exists(ruta)) stop("tabla de pruebas: falta manifiesto.txt en ", d)
  lin <- readLines(ruta, encoding = "UTF-8", warn = FALSE)
  campo <- function(nm) {
    x <- sub(paste0("^", nm, ": "), "", grep(paste0("^", nm, ": "), lin, value = TRUE))
    if (length(x) != 1L) stop("tabla de pruebas: el manifiesto de ", d, " no tiene un único campo ", nm)
    x
  }
  i <- match("salidas (sha256):", lin)
  if (is.na(i)) stop("tabla de pruebas: el manifiesto de ", d, " no lista sus salidas")
  j <- i + 1L
  sal <- character(0)
  while (j <= length(lin) && grepl("^  \\S+  [0-9a-f]{64}$", lin[j])) {
    p <- strsplit(trimws(lin[j]), "  ", fixed = TRUE)[[1]]
    sal[[p[1]]] <- p[2]
    j <- j + 1L
  }
  list(commit = campo("commit_hash"), arbol = campo("arbol"), salidas = sal)
}

#' Lee un CSV de salida del motor solo si su sha256 es el que lista el manifiesto de la corrida citada.
leer_salida_verificada <- function(d, nm, man, commit) {
  if (!identical(man$commit, commit)) stop("tabla de pruebas: ", d, " es de ", man$commit, ", no de la corrida ", commit)
  if (!identical(man$arbol, "limpio")) stop("tabla de pruebas: ", d, " no se corrió con árbol limpio")
  ruta <- file.path(d, nm)
  if (!nm %in% names(man$salidas)) stop("tabla de pruebas: ", nm, " no está en el manifiesto de ", d)
  sha <- digest::digest(file = ruta, algo = "sha256")
  if (!identical(sha, unname(man$salidas[[nm]]))) stop("tabla de pruebas: ", file.path(d, nm), " no coincide con su manifiesto")
  utils::read.csv(ruta, stringsAsFactors = FALSE, na.strings = "")
}

.exigir_columnas <- function(x, cols, que) {
  faltan <- setdiff(cols, names(x))
  if (length(faltan)) stop("tabla de pruebas: faltan columnas en ", que, ": ", paste(faltan, collapse = ", "))
  x[, cols, drop = FALSE]
}

#' Tablas de pruebas y de estabilidad a partir de los directorios de L4 de los experimentos `exps`.
armar_tablas_pruebas_fase5 <- function(dir_l4, exps = experimentos_tabla_fase5(), perdida = "yoy_pp",
                                       commits = commits_registrados(exps$exp_id)) {
  partes <- list(); estab <- list()
  for (k in seq_len(nrow(exps))) {
    ex <- exps[k, ]
    d <- file.path(dir_l4, ex$exp_id)
    if (!dir.exists(d)) stop("tabla de pruebas: falta el directorio del experimento declarado ", ex$exp_id)
    man <- leer_manifiesto(d)
    lee <- function(nm) leer_salida_verificada(d, nm, man, unname(commits[[ex$exp_id]]))
    p <- lee("pruebas.csv")
    p$muestra_eval <- "completa"
    p$variante <- variante_f5(ex)
    partes[[length(partes) + 1L]] <- p
    con_sub <- isTRUE(ex$r3) || isTRUE(ex$r4)
    if (file.exists(file.path(d, "pruebas_submuestras.csv")) != con_sub) {
      stop("tabla de pruebas: submuestras de ", ex$exp_id, " no son las declaradas (r3/r4)")
    }
    if (con_sub) {
      s <- lee("pruebas_submuestras.csv")
      s$variante <- ifelse(s$muestra_eval %in% c("pre2020", "post2020"), "R3", "R4")
      partes[[length(partes) + 1L]] <- s
    }
    if (file.exists(file.path(d, "estabilidad.csv")) != isTRUE(ex$r3)) {
      stop("tabla de pruebas: estabilidad de ", ex$exp_id, " no es la declarada (r3)")
    }
    if (isTRUE(ex$r3)) {
      e <- lee("estabilidad.csv")
      e$variante <- "R3"
      estab[[length(estab) + 1L]] <- e
    }
  }
  base <- setdiff(COLUMNAS_PRUEBAS_F5, "marca_n")
  t <- do.call(rbind, lapply(partes, .exigir_columnas, cols = base, que = "pruebas"))
  t <- t[t$unidad == perdida, , drop = FALSE]
  if (!all(t$variante %in% VARIANTES_ORDEN_F5) || !all(t$muestra_eval %in% MUESTRAS_ORDEN)) {
    stop("tabla de pruebas: variante o muestra fuera del dominio")
  }
  # marca_n por celda: el n de la celda es el n_pares de DM/HLN, igual en todos sus modelos.
  celda <- paste(t$exp_id, t$muestra_eval, t$h, sep = "|")
  dm <- t[t$prueba == "dm_hln", , drop = FALSE]
  n_celda <- tapply(dm$n_pares, paste(dm$exp_id, dm$muestra_eval, dm$h, sep = "|"), unique)
  if (any(lengths(n_celda) != 1L)) stop("tabla de pruebas: n_pares de DM/HLN distinto dentro de una celda")
  if (!all(celda %in% names(n_celda))) stop("tabla de pruebas: celda sin filas de DM/HLN")
  n_c <- unlist(n_celda)[celda]
  t$marca_n <- ifelse(n_c < N_MIN_CALIBRADO_MCS, MARCA_N_BAJO, "")
  t <- t[order(match(t$variante, VARIANTES_ORDEN_F5), t$grupo, t$exp_id, match(t$muestra_eval, MUESTRAS_ORDEN), t$h,
               t$prueba, t$modelo_b), COLUMNAS_PRUEBAS_F5]
  rownames(t) <- NULL
  e <- if (length(estab)) do.call(rbind, lapply(estab, .exigir_columnas, cols = COLUMNAS_ESTABILIDAD_F5, que = "estabilidad")) else NULL
  if (!is.null(e)) {
    e <- e[e$unidad == perdida, , drop = FALSE]
    e <- e[order(e$grupo, e$exp_id, e$h, e$modelo_b), , drop = FALSE]
    rownames(e) <- NULL
  }
  list(pruebas = t, estabilidad = e)
}

#' Extracto de los pronósticos citados en el informe de lectura (§3.3): todos los modelos de los orígenes y horizontes
#' citados.
armar_extracto_pronosticos_fase5 <- function(dir_l4, citas = CITAS_PRONOSTICOS_F5, horizontes = HORIZONTES_CITADOS_F5,
                                             commits = commits_registrados(unique(citas$exp_id))) {
  partes <- list()
  for (x in unique(citas$exp_id)) {
    d <- file.path(dir_l4, x)
    if (!dir.exists(d)) stop("extracto: falta el directorio ", x)
    p <- leer_salida_verificada(d, "pronosticos.csv", leer_manifiesto(d), unname(commits[[x]]))
    p <- p[p$origen %in% citas$origen[citas$exp_id == x] & p$h %in% horizontes, , drop = FALSE]
    falta <- setdiff(citas$origen[citas$exp_id == x], p$origen)
    if (length(falta)) stop("extracto: ", x, " no tiene los orígenes citados ", paste(falta, collapse = ", "))
    partes[[length(partes) + 1L]] <- .exigir_columnas(p, COLUMNAS_EXTRACTO_F5, "pronosticos")
  }
  t <- do.call(rbind, partes)
  t <- t[order(t$exp_id, t$origen, t$h, t$modelo_id), , drop = FALSE]
  rownames(t) <- NULL
  t
}

#' Comprueba que marca_n de la tabla de pruebas es la de la tabla de resultados en cada celda (exp_id, muestra, h).
contrastar_marca_n <- function(pruebas, resultados) {
  clave <- function(x) paste(x$exp_id, x$muestra_eval, x$h, sep = "|")
  r <- unique(data.frame(k = clave(resultados), m = ifelse(is.na(resultados$marca_n), "", resultados$marca_n),
                         stringsAsFactors = FALSE))
  if (anyDuplicated(r$k)) stop("contraste: la tabla de resultados tiene marcas distintas dentro de una celda")
  p <- unique(data.frame(k = clave(pruebas), m = pruebas$marca_n, stringsAsFactors = FALSE))
  m <- r$m[match(p$k, r$k)]
  if (anyNA(m)) stop("contraste: celdas de la tabla de pruebas que no están en la de resultados")
  if (!identical(m, p$m)) stop("contraste: marca_n de la tabla de pruebas no coincide con la de resultados")
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  dir_l4 <- here::here("data", "L4_experiments")
  dir_out <- here::here("doc", "metodologia", "reportes_fase5")
  tabs <- armar_tablas_pruebas_fase5(dir_l4)
  res <- utils::read.csv(file.path(dir_out, "tabla_resultados_fase5.csv"), stringsAsFactors = FALSE, na.strings = "")
  contrastar_marca_n(tabs$pruebas, res)
  ext <- armar_extracto_pronosticos_fase5(dir_l4)
  salidas <- list(tabla_pruebas_fase5.csv = tabs$pruebas, tabla_estabilidad_fase5.csv = tabs$estabilidad,
                  extracto_pronosticos_fase5.csv = ext)
  for (nm in names(salidas)) {
    ruta <- file.path(dir_out, nm)
    escribir_tabla_resultados(salidas[[nm]], ruta)                            # LF en todas las plataformas
    cat(sprintf("%s: %d filas, sha256 %s\n", nm, nrow(salidas[[nm]]), digest::digest(file = ruta, algo = "sha256")))
  }
}
