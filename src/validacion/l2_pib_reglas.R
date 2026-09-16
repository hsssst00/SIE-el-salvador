# Reglas de la batería L2 para BCR_PIB_series_largo.csv, factorizadas en una
# función pura para que tests/test-validar-l2-pib.R pueda ejercerlas con datos
# sintéticos sin pasar por el archivo real. src/validacion/validar_l2_pib.R
# hace el I/O (leer L1 y el catálogo, reportar, fallar) y llama a validar_l2()
# definida acá. Ver ese archivo para la descripción de cada uno de los 5 checks
# (senda metodológica §3.5).

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
#' @return character vector de mensajes de error; vacío si todo cumple.
validar_l2 <- function(l1, catalogo) {
  errores <- character(0)
  agregar_error <- function(msg) errores <<- c(errores, msg)

  campos_esperados <- c("serie_id", "periodo", "valor", "provisional")
  faltantes <- setdiff(campos_esperados, names(l1))
  if (length(faltantes) > 0) {
    stop("FALLO VISIBLE L2: campo(s) ausente(s) en L1: ", paste(faltantes, collapse = ", "))
  }

  # --- 1. Esquema ---
  if (any(is.na(l1$serie_id) | l1$serie_id == "")) {
    agregar_error("serie_id: valores vacíos")
  }
  periodo_valido <- grepl("^[0-9]{4}-Q[1-4]$", l1$periodo)
  if (any(!periodo_valido)) {
    agregar_error(paste0("periodo: ", sum(!periodo_valido),
                          " valor(es) fuera del formato AAAA-Qn: ",
                          paste(head(unique(l1$periodo[!periodo_valido]), 5), collapse = ", ")))
  }
  if (!is.numeric(l1$valor)) {
    agregar_error("valor: columna no numérica")
  } else if (any(is.na(l1$valor))) {
    agregar_error(paste0("valor: ", sum(is.na(l1$valor)), " valor(es) ausente(s)"))
  }
  if (!is.logical(l1$provisional)) {
    agregar_error("provisional: columna no lógica (TRUE/FALSE)")
  }

  # --- 2. Integridad referencial con el catálogo ---
  series_l1 <- unique(l1$serie_id)
  series_catalogo <- unique(catalogo$serie_id)

  huerfanas <- setdiff(series_l1, series_catalogo)
  if (length(huerfanas) > 0) {
    agregar_error(paste0("serie_id en L1 sin entrada en 03_series.csv: ",
                          paste(huerfanas, collapse = ", ")))
  }
  ausentes <- setdiff(series_catalogo, series_l1)
  if (length(ausentes) > 0) {
    agregar_error(paste0("serie_id declarada en 03_series.csv pero ausente en L1: ",
                          paste(ausentes, collapse = ", ")))
  }

  # --- 3. Duplicados en (serie_id, periodo) ---
  clave <- paste(l1$serie_id, l1$periodo, sep = "|")
  dup <- unique(clave[duplicated(clave)])
  if (length(dup) > 0) {
    agregar_error(paste0(length(dup), " clave(s) (serie_id, periodo) duplicada(s): ",
                          paste(head(dup, 5), collapse = "; ")))
  }

  # --- 4. Huecos no declarados (solo sobre periodos con formato válido) ---
  for (sid in series_catalogo) {
    periodos_obs <- sort(unique(l1$periodo[l1$serie_id == sid & periodo_valido]))
    if (length(periodos_obs) == 0) next  # ya reportado arriba como "ausente" o "formato inválido"
    idx <- periodo_a_indice(periodos_obs)
    esperado <- seq(min(idx), max(idx))
    faltan_idx <- setdiff(esperado, idx)
    if (length(faltan_idx) > 0) {
      agregar_error(paste0(sid, ": hueco no declarado en ",
                            paste(indice_a_periodo(faltan_idx), collapse = ", ")))
    }
  }

  # --- 5. Coherencia de agregados (identidad contable, precios corrientes) ---
  # Requiere "valor" numérico; si el check 1 ya lo marcó como inválido, la
  # aritmética de la identidad no tiene sentido y se omite (el error de
  # esquema ya está reportado, no hace falta duplicarlo aquí).
  if (!is.numeric(l1$valor)) {
    return(errores)
  }
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
      periodos_vab <- names(vab_total)
      suma_ramas <- Reduce(`+`, lapply(ramas_anchas, function(r) r[periodos_vab]))
      dif_vab <- suma_ramas - vab_total[periodos_vab]
      mal_vab <- periodos_vab[abs(dif_vab) > TOLERANCIA_AGREGADOS]
      if (length(mal_vab) > 0) {
        agregar_error(paste0("identidad suma(VAB ramas) = VAB total rota en: ",
                              paste(mal_vab, collapse = ", ")))
      }

      periodos_pib <- intersect(names(vab_total), intersect(names(impuestos), names(pib)))
      dif_pib <- (vab_total[periodos_pib] + impuestos[periodos_pib]) - pib[periodos_pib]
      mal_pib <- periodos_pib[abs(dif_pib) > TOLERANCIA_AGREGADOS]
      if (length(mal_pib) > 0) {
        agregar_error(paste0("identidad VAB total + impuestos netos = PIB rota en: ",
                              paste(mal_pib, collapse = ", ")))
      }
    }
  }

  errores
}
