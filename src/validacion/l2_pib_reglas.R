# Reglas de la batería L2 para BCR_PIB_series_largo.csv, factorizadas en una
# función pura para que tests/test-validar-l2-pib.R pueda ejercerlas con datos
# sintéticos sin pasar por el archivo real. src/validacion/validar_l2_pib.R
# hace el I/O (leer L1 y el catálogo, reportar, fallar) y llama a validar_l2()
# definida acá. Ver ese archivo para la descripción de cada uno de los 5 checks
# (senda metodológica §3.5).
#
# Migrado a pointblank (2026-09-16, decisión de Harold) para los checks que
# calzan con su modelo de columna/fila -- esquema, integridad referencial
# "huérfanas" y duplicados -- que corren como pasos nativos de un mismo agente
# y de los que se puede extraer el detalle de filas que fallaron
# (get_data_extracts()). Los checks que requieren reformular la tabla (huecos
# por serie, identidad contable entre series) no tienen ese soporte de extract
# en pointblank 0.12.4 (verificado empíricamente, no es una limitación
# documentada): quedan en R base como antes, pero también se registran como
# pasos `specially()` en el mismo agente -- sobre el vector ya calculado en R,
# sin repetir el cómputo -- para que el agente sea el árbitro único de si algo
# falló y el reporte quede unificado en un solo objeto interrogado.

library(pointblank)

VAB_RAMAS <- c(
  "BCR.VAB_AGRICULTURA.NOM.NSA.Q", "BCR.VAB_MINAS.NOM.NSA.Q", "BCR.VAB_MANUFACTURA.NOM.NSA.Q",
  "BCR.VAB_ELECTRICIDAD.NOM.NSA.Q", "BCR.VAB_AGUA.NOM.NSA.Q", "BCR.VAB_CONSTRUCCION.NOM.NSA.Q",
  "BCR.VAB_COMERCIO.NOM.NSA.Q", "BCR.VAB_TRANSPORTE.NOM.NSA.Q", "BCR.VAB_ALOJAMIENTO.NOM.NSA.Q",
  "BCR.VAB_INFO_COM.NOM.NSA.Q", "BCR.VAB_FINANCIERO.NOM.NSA.Q", "BCR.VAB_INMOBILIARIO.NOM.NSA.Q",
  "BCR.VAB_PROFESIONAL.NOM.NSA.Q", "BCR.VAB_SERV_APOYO.NOM.NSA.Q", "BCR.VAB_ADMIN_PUBLICA.NOM.NSA.Q",
  "BCR.VAB_ENSENANZA.NOM.NSA.Q", "BCR.VAB_SALUD.NOM.NSA.Q", "BCR.VAB_ARTE_RECREACION.NOM.NSA.Q",
  "BCR.VAB_OTROS_SERVICIOS.NOM.NSA.Q"
)
TOLERANCIA_AGREGADOS <- 0.05

periodo_a_indice <- function(p) {
  partes <- regmatches(p, regexec("^([0-9]{4})-Q([1-4])$", p))
  anio <- as.integer(vapply(partes, `[[`, character(1), 2))
  trim <- as.integer(vapply(partes, `[[`, character(1), 3))
  anio * 4L + trim
}

indice_a_periodo <- function(idx) {
  anio <- (idx - 1L) %/% 4L
  trim <- (idx - 1L) %% 4L + 1L
  sprintf("%d-Q%d", anio, trim)
}

#' Corre la batería de validaciones L2 sobre un data frame L1 ya cargado.
#' @param l1 data frame con columnas serie_id, periodo, valor, provisional.
#' @param catalogo data frame de 03_series.csv, YA filtrado a las series que
#'   corresponden a este L1 (sin UT.DEMANDA_TOTAL_MENSUAL).
#' @return list(errores = character vector de mensajes, vacío si todo cumple;
#'   agente = el ptblank_agent ya interrogado, con los 5 checks como pasos,
#'   para quien necesite el reporte unificado más allá del mensaje de FALLO).
validar_l2 <- function(l1, catalogo) {
  campos_esperados <- c("serie_id", "periodo", "valor", "provisional")
  faltantes <- setdiff(campos_esperados, names(l1))
  if (length(faltantes) > 0) {
    stop("FALLO VISIBLE L2: campo(s) ausente(s) en L1: ", paste(faltantes, collapse = ", "))
  }

  errores <- character(0)
  agregar_error <- function(msg) errores <<- c(errores, msg)

  series_l1 <- unique(l1$serie_id)
  series_catalogo <- unique(catalogo$serie_id)
  valor_numerico <- is.numeric(l1$valor)
  provisional_logico <- is.logical(l1$provisional)

  # --- 2b. Ausentes: series del catálogo que no aparecen en L1. No tiene
  # detalle de fila que extraer (el catálogo, no L1, es la tabla relevante),
  # así que el mensaje se construye acá y el paso del agente solo espeja el
  # mismo vector ya calculado. ---
  ausentes <- setdiff(series_catalogo, series_l1)
  cobertura_catalogo <- !(series_catalogo %in% ausentes)

  # --- 4. Huecos no declarados: secuencia de periodos por serie. Requiere
  # reformular la tabla por serie (no es un check de fila), mismo motivo que
  # el punto anterior para quedarse en R base. ---
  periodo_valido <- grepl("^[0-9]{4}-Q[1-4]$", l1$periodo)
  huecos_por_serie <- character(0)
  sin_hueco <- logical(0)
  for (sid in series_catalogo) {
    periodos_obs <- sort(unique(l1$periodo[l1$serie_id == sid & periodo_valido]))
    if (length(periodos_obs) == 0) next  # ya reportado como "ausente" o de formato inválido
    idx <- periodo_a_indice(periodos_obs)
    esperado <- seq(min(idx), max(idx))
    faltan_idx <- setdiff(esperado, idx)
    sin_hueco[sid] <- length(faltan_idx) == 0
    if (length(faltan_idx) > 0) {
      huecos_por_serie[sid] <- paste0(sid, ": hueco no declarado en ",
                                       paste(indice_a_periodo(faltan_idx), collapse = ", "))
    }
  }

  # --- 5. Coherencia de agregados (identidad contable, precios corrientes).
  # Álgebra entre series reordenadas a ancho -- tampoco es un check de fila. ---
  mal_vab <- character(0)
  mal_pib <- character(0)
  chequear_identidad <- FALSE
  sin_error_vab <- logical(0)
  sin_error_pib <- logical(0)
  if (valor_numerico) {
    serie_ancha <- function(sid) {
      s <- l1[l1$serie_id == sid, c("periodo", "valor")]
      setNames(s$valor, s$periodo)
    }
    vab_total <- serie_ancha("BCR.VAB.NOM.NSA.Q")
    impuestos <- serie_ancha("BCR.IMPUESTOS_NETOS.NOM.NSA.Q")
    pib <- serie_ancha("BCR.PIB.NOM.NSA.Q")

    if (length(vab_total) == 0 || length(impuestos) == 0 || length(pib) == 0) {
      agregar_error("coherencia de agregados: falta VAB total, impuestos netos o PIB nominal para verificar la identidad")
    } else {
      ramas_anchas <- lapply(VAB_RAMAS, serie_ancha)
      n_por_rama <- vapply(ramas_anchas, length, integer(1))
      if (any(n_por_rama == 0)) {
        agregar_error(paste0("coherencia de agregados: rama(s) VAB ausente(s) en L1: ",
                              paste(VAB_RAMAS[n_por_rama == 0], collapse = ", ")))
      } else {
        chequear_identidad <- TRUE
        periodos_vab <- names(vab_total)
        suma_ramas <- Reduce(`+`, lapply(ramas_anchas, function(r) r[periodos_vab]))
        dif_vab <- suma_ramas - vab_total[periodos_vab]
        mal_vab <- periodos_vab[abs(dif_vab) > TOLERANCIA_AGREGADOS]
        sin_error_vab <- !(periodos_vab %in% mal_vab)

        periodos_pib <- intersect(names(vab_total), intersect(names(impuestos), names(pib)))
        dif_pib <- (vab_total[periodos_pib] + impuestos[periodos_pib]) - pib[periodos_pib]
        mal_pib <- periodos_pib[abs(dif_pib) > TOLERANCIA_AGREGADOS]
        sin_error_pib <- !(periodos_pib %in% mal_pib)
      }
    }
  }

  # --- Agente pointblank: árbitro de esquema, integridad referencial
  # "huérfanas" y duplicados (con extract de las filas que fallaron); espejo
  # de reporte unificado para los checks de arriba que ya se resolvieron en R. ---
  idx <- list()
  paso_i <- 0L
  registrar <- function(nombre, agente_nuevo) {
    paso_i <<- paso_i + 1L
    idx[[nombre]] <<- paso_i
    agente_nuevo
  }

  agente <- create_agent(tbl = l1, label = "L2 BCR PIB")
  agente <- registrar("serie_id_no_vacio", agente |>
    col_vals_regex(columns = vars(serie_id), regex = "^.+$",
                    label = "esquema: serie_id no vacío"))
  agente <- registrar("periodo_formato", agente |>
    col_vals_regex(columns = vars(periodo), regex = "^[0-9]{4}-Q[1-4]$",
                    label = "esquema: periodo AAAA-Qn"))
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
  if (chequear_identidad) {
    agente <- registrar("identidad_vab", agente |>
      specially(fn = function(x) sin_error_vab, label = "identidad: suma(VAB ramas) = VAB total"))
    agente <- registrar("identidad_pib", agente |>
      specially(fn = function(x) sin_error_pib, label = "identidad: VAB total + impuestos = PIB"))
  }

  agente <- interrogate(agente)
  reporte <- get_agent_report(agente, display_table = FALSE)
  extractos <- get_data_extracts(agente)

  fallo <- function(nombre) {
    fila <- reporte[reporte$i == idx[[nombre]], ]
    is.na(fila$f_pass) || fila$f_pass < 1
  }
  extracto <- function(nombre) extractos[[as.character(idx[[nombre]])]]

  # --- 1. Esquema ---
  if (fallo("serie_id_no_vacio")) {
    agregar_error("serie_id: valores vacíos")
  }
  if (fallo("periodo_formato")) {
    ext <- extracto("periodo_formato")
    agregar_error(paste0("periodo: ", nrow(ext),
                          " valor(es) fuera del formato AAAA-Qn: ",
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

  # --- 5. Coherencia de agregados ---
  if (length(mal_vab) > 0) {
    agregar_error(paste0("identidad suma(VAB ramas) = VAB total rota en: ",
                          paste(mal_vab, collapse = ", ")))
  }
  if (length(mal_pib) > 0) {
    agregar_error(paste0("identidad VAB total + impuestos netos = PIB rota en: ",
                          paste(mal_pib, collapse = ", ")))
  }

  list(errores = errores, agente = agente)
}
