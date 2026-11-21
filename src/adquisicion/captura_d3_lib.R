# captura_d3_lib.R
#
# Logica pura de la captura fuera de ventana asistida (ADR-007 D3; ficha F7-13 de
# doc/metodologia/decisiones_fase7.md). Separada de src/adquisicion/captura_d3.R para que
# tests/test-captura-d3.R la ejerza sin red ni navegador, igual que verificacion_rapida.R.
#
# Automatiza la DECISION de D3, no la captura: dice que publicaciones cumplen las tres
# condiciones, con que funcion y con que fecha_publicacion se capturarian. Cada captura la
# confirma una persona, una publicacion a la vez (regla 9 de CLAUDE.md).
#
# Requiere haber cargado src/adquisicion/verificacion_rapida.R (clave_periodo,
# CALENDARIO_BCR_VARIABLE, CALENDARIO_BCR_ANIO, .MESES_ES).

# publicacion_id -> funcion de captura. Explicito, no inferido por nombre; la prueba comprueba
# que cubra toda publicacion vista-serie del manifiesto y que cada funcion exista.
FUNCION_DESCARGA_D3 <- c(
  "BCR.BALANZA_COMERCIAL"                     = "descargar_bcr_balanza_comercial",
  "BCR.BALANZA_PAGOS_TRIMESTRAL"              = "descargar_bcr_balanza_pagos_trimestral",
  "BCR.GOBIERNO_CENTRAL_CONSOLIDADO"          = "descargar_bcr_gobierno_central_consolidado",
  "BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR"     = "descargar_bcr_indices_precios_comercio_exterior",
  "BCR.IPI.VIGENTE"                           = "descargar_bcr_ipi_vigente",
  "BCR.IPP"                                   = "descargar_bcr_ipp",
  "BCR.ISI"                                   = "descargar_bcr_isi",
  "BCR.ITCER"                                 = "descargar_bcr_itcer",
  "BCR.IVAE.VIGENTE"                          = "descargar_bcr_ivae_vigente",
  "BCR.PANORAMA_BANCO_CENTRAL"                = "descargar_bcr_panorama_banco_central",
  "BCR.PANORAMA_SOCIEDADES_DEPOSITO"          = "descargar_bcr_panorama_sociedades_deposito",
  "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA" = "descargar_bcr_pib_nsa",
  "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_SA"  = "descargar_bcr_pib_sa",
  "BCR.PIB_T.NOMINAL"                         = "descargar_bcr_pib_nominal",
  "BCR.REMESAS_FAMILIARES_MENSUAL"            = "descargar_bcr_remesas",
  "BCR.RESERVAS_INTERNACIONALES_NETAS"        = "descargar_bcr_reservas_internacionales_netas",
  "BCR.SPNF_VIGENTE"                          = "descargar_bcr_spnf_vigente",
  "ONEC.IPC.BASE_2009"                        = "descargar_onec_ipc_base2009"
)

#' Fecha que el calendario del BCR anuncia para `periodo` de una publicacion, o NA si la
#' publicacion no tiene fila mapeada o el calendario no anuncia ese periodo.
fecha_calendario_periodo <- function(publicacion_id, periodo, calendario) {
  variable <- unname(CALENDARIO_BCR_VARIABLE[publicacion_id])
  k <- clave_periodo(periodo)
  if (is.na(variable) || is.null(k)) return(as.Date(NA))
  filas <- calendario[calendario$variable == variable, ]
  iguales <- vapply(filas$periodo_referencia, function(p) {
    kp <- clave_periodo(p)
    !is.null(kp) && kp$tipo == k$tipo && kp$n == k$n
  }, logical(1))
  filas <- filas[iguales, ]
  if (nrow(filas) == 0) return(as.Date(NA))
  mes <- match(tolower(filas$mes_publicacion), .MESES_ES)
  if (anyNA(mes)) {
    stop("FALLO VISIBLE: mes_publicacion no reconocido en el calendario: ",
         paste(unique(filas$mes_publicacion[is.na(mes)]), collapse = ", "))
  }
  min(as.Date(sprintf("%d-%02d-%02d", CALENDARIO_BCR_ANIO, mes, as.integer(filas$dia_publicacion))))
}

#' Cuantos periodos avanza `despues` respecto de `antes` (mismo tipo, M o T).
saltos_periodo <- function(antes, despues) {
  a <- clave_periodo(antes); d <- clave_periodo(despues)
  if (is.null(a) || is.null(d) || a$tipo != d$tipo) {
    stop("FALLO VISIBLE: periodos no comparables: '", antes, "' y '", despues, "'.")
  }
  d$n - a$n
}

#' Evalua las tres condiciones de D3 para cada publicacion de `trabajo` (la tabla que arma
#' scripts/verificar_l0_rapido.R: publicacion_id, periodo_max, estado, periodo_fuente).
#' Devuelve una fila por publicacion NUEVO_PERIODO con `cumple` y el `motivo` si no cumple.
evaluar_candidatas_d3 <- function(trabajo, vintages, calendario, hoy = Sys.Date()) {
  nuevos <- trabajo[trabajo$estado == "NUEVO_PERIODO", , drop = FALSE]
  vacia <- data.frame(publicacion_id = character(), periodo_max = character(),
                      periodo_fuente = character(), fecha_calendario = as.Date(character()),
                      fecha_publicacion = character(), vintage_id = character(),
                      funcion = character(), saltos = integer(), cumple = logical(),
                      motivo = character(), comando = character(), stringsAsFactors = FALSE)
  if (nrow(nuevos) == 0) return(vacia)
  filas <- lapply(seq_len(nrow(nuevos)), function(i) {
    pid <- nuevos$publicacion_id[i]
    pmax <- nuevos$periodo_max[i]
    pf <- nuevos$periodo_fuente[i]
    funcion <- unname(FUNCION_DESCARGA_D3[pid])
    fcal <- fecha_calendario_periodo(pid, pf, calendario)
    fpub <- if (is.na(fcal)) NA_character_ else format(fcal, "%Y-%m-01")
    vid <- if (is.na(fpub)) NA_character_ else paste0(pid, ".v", substr(fpub, 1, 7))
    k <- clave_periodo(pf)
    propios <- vintages[vintages$publicacion_id == pid, , drop = FALSE]
    ya_periodo <- any(vapply(propios$periodo_referencia_max, function(p) {
      kp <- clave_periodo(p); !is.null(kp) && kp$tipo == k$tipo && kp$n == k$n
    }, logical(1)))
    motivo <- if (is.na(funcion)) {
      "sin funcion de captura en FUNCION_DESCARGA_D3"
    } else if (is.na(fcal)) {
      paste0("(b) el calendario no anuncia el periodo ", pf, ": esperar la ventana")
    } else if (fcal > hoy) {
      paste0("(b) el calendario lo anuncia para el ", fcal, ", despues de hoy: esperar")
    } else if (ya_periodo) {
      paste0("(c) ya hay un vintage con periodo ", pf, " en 08_vintages.csv")
    } else if (vid %in% vintages$vintage_id) {
      paste0("(c) el vintage_id ", vid, " ya existe (mismo mes de publicacion): esperar la ventana")
    } else {
      ""
    }
    data.frame(publicacion_id = pid, periodo_max = pmax, periodo_fuente = pf,
               fecha_calendario = fcal, fecha_publicacion = fpub, vintage_id = vid,
               funcion = if (is.na(funcion)) NA_character_ else funcion,
               saltos = saltos_periodo(pmax, pf), cumple = motivo == "",
               motivo = motivo,
               comando = if (motivo == "") sprintf("%s(\"%s\")", funcion, fpub) else NA_character_,
               stringsAsFactors = FALSE)
  })
  do.call(rbind, filas)
}

#' Texto de la nota fechada para doc/backlog_captura_vintages.md.
nota_backlog_d3 <- function(evaluacion, capturadas, hoy = Sys.Date()) {
  lineas <- c(sprintf("## Nota del %s \u2014 captura posterior a la publicacion (ADR-007 D3)", hoy), "",
              sprintf("`captura_d3()` (una pasada de `make raw-rapido`) marco %d `NUEVO_PERIODO`.", nrow(evaluacion)))
  for (i in seq_len(nrow(evaluacion))) {
    e <- evaluacion[i, ]
    estado <- if (e$publicacion_id %in% capturadas) {
      sprintf("capturada como `%s` (%s -> %s%s)", e$vintage_id, e$periodo_max, e$periodo_fuente,
              if (e$saltos > 1) sprintf("; avanzo %d periodos: hubo vintages intermedios no capturados", e$saltos)
              else "; sin vintages intermedios perdidos")
    } else if (isTRUE(e$cumple)) {
      "cumplia D3 y no se confirmo: queda para la ventana"
    } else {
      paste0("no capturada: ", e$motivo)
    }
    lineas <- c(lineas, sprintf("- `%s`: %s.", e$publicacion_id, estado))
  }
  paste(lineas, collapse = "\n")
}
