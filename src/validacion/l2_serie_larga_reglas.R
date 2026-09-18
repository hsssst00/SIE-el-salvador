# Bateria L2 generica para una serie larga (serie_id, periodo, valor, provisional) de cualquier
# frecuencia trimestral o mensual -- checks 1-4 de la senda metodologica S3.5 (esquema,
# integridad referencial con el catalogo, duplicados, continuidad), factorizados fuera de
# src/validacion/l2_pib_reglas.R.
#
# Motivo (hallazgo I1 de la revision independiente 2026-09-17): la bateria original solo cubria
# BCR_PIB_series_largo.csv (por diseño, ver PUBLICACIONES_PIB en validar_l2_pib.R); las ocho
# series predictoras de data/L1_staging/ entraban a l3_predictores.R sin pasar por ningun
# control -- incluido col_vals_not_null sobre valor, el check que habria atajado el hallazgo C1
# (perdida silenciosa de un mes ausente en la agregacion mensual->trimestral) una capa antes.
#
# Check 5 (identidad contable de agregados VAB/PIB) sigue en l2_pib_reglas.R: es especifico del
# PIB nominal en precios corrientes, no tiene equivalente agnostico para una serie predictora.
# l2_pib_reglas.R llama a validar_l2_serie_larga() para los checks 1-4 y agrega el suyo encima.
#
# freq: "Q" (periodo "YYYY-Qn") o "M" (periodo "YYYY-Mnn").

library(pointblank)

.periodo_regex <- function(freq) {
  switch(freq,
    Q = "^[0-9]{4}-Q[1-4]$",
    M = "^[0-9]{4}-M(0[1-9]|1[0-2])$",
    stop("freq debe ser 'Q' o 'M', recibido: ", freq)
  )
}

.periodo_a_indice <- function(p, freq) {
  if (identical(freq, "Q")) {
    partes <- regmatches(p, regexec("^([0-9]{4})-Q([1-4])$", p))
    anio <- as.integer(vapply(partes, `[[`, character(1), 2))
    sub <- as.integer(vapply(partes, `[[`, character(1), 3))
    anio * 4L + sub
  } else {
    partes <- regmatches(p, regexec("^([0-9]{4})-M([0-9]{2})$", p))
    anio <- as.integer(vapply(partes, `[[`, character(1), 2))
    sub <- as.integer(vapply(partes, `[[`, character(1), 3))
    anio * 12L + sub
  }
}

.indice_a_periodo <- function(idx, freq) {
  if (identical(freq, "Q")) {
    anio <- (idx - 1L) %/% 4L
    sub <- (idx - 1L) %% 4L + 1L
    sprintf("%d-Q%d", anio, sub)
  } else {
    anio <- (idx - 1L) %/% 12L
    sub <- (idx - 1L) %% 12L + 1L
    sprintf("%d-M%02d", anio, sub)
  }
}

#' Corre los checks 1-4 de la bateria L2 sobre un data frame L1 ya cargado.
#' @param l1 data frame con columnas serie_id, periodo, valor, provisional.
#' @param catalogo data frame de 03_series.csv, YA filtrado a las series que corresponden a
#'   este L1.
#' @param freq "Q" o "M" -- frecuencia declarada del campo periodo.
#' @param label etiqueta del agente pointblank (aparece en el reporte HTML).
#' @return list(errores = character vector de mensajes, vacío si todo cumple; agente = el
#'   ptblank_agent ya interrogado, con los checks 1-4 como pasos).
validar_l2_serie_larga <- function(l1, catalogo, freq, label = "L2") {
  campos_esperados <- c("serie_id", "periodo", "valor", "provisional")
  faltantes <- setdiff(campos_esperados, names(l1))
  if (length(faltantes) > 0) {
    stop("FALLO VISIBLE ", label, ": campo(s) ausente(s) en L1: ", paste(faltantes, collapse = ", "))
  }

  errores <- character(0)
  agregar_error <- function(msg) errores <<- c(errores, msg)

  series_l1 <- unique(l1$serie_id)
  series_catalogo <- unique(catalogo$serie_id)
  valor_numerico <- is.numeric(l1$valor)
  provisional_logico <- is.logical(l1$provisional)
  regex_periodo <- .periodo_regex(freq)

  # --- 2b. Ausentes: series del catálogo que no aparecen en L1. ---
  ausentes <- setdiff(series_catalogo, series_l1)
  cobertura_catalogo <- !(series_catalogo %in% ausentes)

  # --- 4. Huecos no declarados: secuencia de periodos por serie. ---
  periodo_valido <- grepl(regex_periodo, l1$periodo)
  huecos_por_serie <- character(0)
  sin_hueco <- logical(0)
  for (sid in series_catalogo) {
    periodos_obs <- sort(unique(l1$periodo[l1$serie_id == sid & periodo_valido]))
    if (length(periodos_obs) == 0) next  # ya reportado como "ausente" o de formato inválido
    idx <- .periodo_a_indice(periodos_obs, freq)
    esperado <- seq(min(idx), max(idx))
    faltan_idx <- setdiff(esperado, idx)
    sin_hueco[sid] <- length(faltan_idx) == 0
    if (length(faltan_idx) > 0) {
      huecos_por_serie[sid] <- paste0(sid, ": hueco no declarado en ",
                                       paste(.indice_a_periodo(faltan_idx, freq), collapse = ", "))
    }
  }

  idx_pasos <- list()
  paso_i <- 0L
  registrar <- function(nombre, agente_nuevo) {
    paso_i <<- paso_i + 1L
    idx_pasos[[nombre]] <<- paso_i
    agente_nuevo
  }

  agente <- create_agent(tbl = l1, label = label)
  agente <- registrar("serie_id_no_vacio", agente |>
    col_vals_regex(columns = vars(serie_id), regex = "^.+$",
                    label = "esquema: serie_id no vacío"))
  formato_legible <- if (identical(freq, "Q")) "AAAA-Qn" else "AAAA-Mnn"
  agente <- registrar("periodo_formato", agente |>
    col_vals_regex(columns = vars(periodo), regex = regex_periodo,
                    label = paste0("esquema: periodo ", formato_legible)))
  agente <- registrar("valor_numerico", agente |>
    specially(fn = function(x) valor_numerico, label = "esquema: valor numérico"))
  if (valor_numerico) {
    agente <- registrar("valor_sin_ausentes", agente |>
      col_vals_not_null(columns = vars(valor), label = "esquema: valor sin ausentes"))
  }
  agente <- registrar("provisional_logico", agente |>
    specially(fn = function(x) provisional_logico, label = "esquema: provisional lógico"))
  agente <- registrar("serie_en_catalogo", agente |>
    col_vals_in_set(columns = vars(serie_id), set = series_catalogo,
                     label = "referencial: serie_id en catálogo"))
  agente <- registrar("catalogo_cubierto", agente |>
    specially(fn = function(x) cobertura_catalogo, label = "referencial: catálogo cubierto por L1"))
  agente <- registrar("sin_duplicados", agente |>
    rows_distinct(columns = vars(serie_id, periodo), label = "duplicados: (serie_id, periodo)"))
  if (length(sin_hueco) > 0) {
    agente <- registrar("continuidad", agente |>
      specially(fn = function(x) unname(sin_hueco), label = "continuidad: sin huecos no declarados"))
  }

  agente <- interrogate(agente)
  reporte <- get_agent_report(agente, display_table = FALSE)
  extractos <- get_data_extracts(agente)

  fallo <- function(nombre) {
    fila <- reporte[reporte$i == idx_pasos[[nombre]], ]
    is.na(fila$f_pass) || fila$f_pass < 1
  }
  extracto <- function(nombre) extractos[[as.character(idx_pasos[[nombre]])]]

  # --- 1. Esquema ---
  if (fallo("serie_id_no_vacio")) {
    agregar_error("serie_id: valores vacíos")
  }
  if (fallo("periodo_formato")) {
    ext <- extracto("periodo_formato")
    agregar_error(paste0("periodo: ", nrow(ext),
                          " valor(es) fuera del formato ", formato_legible, ": ",
                          paste(head(unique(ext$periodo), 5), collapse = ", ")))
  }
  if (fallo("valor_numerico")) {
    agregar_error("valor: columna no numérica")
  } else if (fallo("valor_sin_ausentes")) {
    ext <- extracto("valor_sin_ausentes")
    agregar_error(paste0("valor: ", nrow(ext), " valor(es) ausente(s)"))
  }
  if (fallo("provisional_logico")) {
    agregar_error("provisional: columna no lógica (TRUE/FALSE)")
  }

  # --- 2. Integridad referencial con el catálogo ---
  if (fallo("serie_en_catalogo")) {
    ext <- extracto("serie_en_catalogo")
    huerfanas <- unique(ext$serie_id[ext$serie_id != "" & !is.na(ext$serie_id)])
    if (length(huerfanas) > 0) {
      agregar_error(paste0("serie_id en L1 sin entrada en 03_series.csv: ",
                            paste(huerfanas, collapse = ", ")))
    }
  }
  if (length(ausentes) > 0) {
    agregar_error(paste0("serie_id declarada en 03_series.csv pero ausente en L1: ",
                          paste(ausentes, collapse = ", ")))
  }

  # --- 3. Duplicados en (serie_id, periodo) ---
  if (fallo("sin_duplicados")) {
    ext <- extracto("sin_duplicados")
    clave <- paste(ext$serie_id, ext$periodo, sep = "|")
    dup <- unique(clave)
    agregar_error(paste0(length(dup), " clave(s) (serie_id, periodo) duplicada(s): ",
                          paste(head(dup, 5), collapse = "; ")))
  }

  # --- 4. Huecos no declarados ---
  for (msg in huecos_por_serie) agregar_error(msg)

  list(errores = errores, agente = agente)
}
