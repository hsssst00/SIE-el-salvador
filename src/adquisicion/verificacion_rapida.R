# verificacion_rapida.R
#
# Logica pura de `make raw-rapido` (scripts/verificar_l0_rapido.R): un PRECHECK barato de las
# publicaciones del portal del BCR, en dos niveles. No reemplaza a `make raw`.
#
#   Nivel 1 (calendario, sin red): con doc/calendario_divulgacion_bcr.csv, decide si a una
#     publicacion le TOCA un periodo nuevo (alguna fecha anunciada ya paso para un periodo
#     posterior al del vintage vigente) o NO_TOCA (todas las fechas anunciadas son futuras).
#     Si el calendario no permite decidir -publicacion sin fila mapeada, calendario sin un
#     periodo posterior, o año distinto del que cubre- el estado es SIN_CALENDARIO y la
#     publicacion pasa al nivel 2: ante la duda se mira, no se asume.
#   Nivel 2 (sondeo, navegador): para TOCA y SIN_CALENDARIO, carga la pagina de la
#     publicacion y lee el ultimo periodo que sirve la fuente (/api/rangos), sin renderizar ni
#     exportar la tabla. Compara contra periodo_referencia_max del vintage vigente.
#
# LIMITE QUE NO SE PUEDE SALVAR: ambos niveles ven periodos nuevos, NO revisiones de valores
# de periodos viejos con el mismo ultimo periodo (p.ej. una revision del PIB-T). Esas solo las
# detecta el sha256_norm completo de `make raw`. Por eso este precheck es un aviso barato y
# `make raw` completo sigue siendo lo que exigen las ventanas (doc/calendario_make_raw.md).
#
# Separado del script para que tests/test-verificacion-rapida.R lo ejerza sin red.

# El calendario del BCR no trae año: "lo que resta del año en curso" (doc/calendario_
# divulgacion_bcr.md). Si hoy es de otro año, el nivel 1 no decide nada.
CALENDARIO_BCR_ANIO <- 2026L

# publicacion_id -> `variable` del calendario. Explicito, no inferido por nombre. Lo que no
# esta aqui (PIB_T NSA y NOMINAL, que el calendario no nombra) queda SIN_CALENDARIO y se
# sondea siempre. SPNF_VIGENTE usa la fila heredada "Serie 1994-2025": correccion de mapeo
# de Harold, 2026-08-26 (doc/calendario_divulgacion_bcr.md).
CALENDARIO_BCR_VARIABLE <- c(
  "BCR.BALANZA_COMERCIAL"            = "Balanza Comercial de Mercancías. Valores",
  "BCR.BALANZA_PAGOS_TRIMESTRAL"     = "Balanza de Pagos Trimestral",
  "BCR.GOBIERNO_CENTRAL_CONSOLIDADO" = "Gobierno Central Consolidado",
  "BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR" = "Índices de Precios del Comercio Exterior - Mensual",
  "BCR.IPI.VIGENTE"                  = "Índice de Producción Industrial (IPI). Serie desestacionalizada",
  "BCR.IPP"                          = "Índice de Precios al Productor (IPP)",
  "BCR.ISI"                          = "Índice Subyacente de Inflación (ISI) Base dic. 2009.",
  "BCR.ITCER"                        = "Índice de Tipo de Cambio Efectivo Real - Mensual",
  "BCR.IVAE.VIGENTE"                 = "Índice de Volumen de la Actividad Económica (IVAE). Serie desestacionalizada",
  "BCR.PANORAMA_BANCO_CENTRAL"       = "Panorama del Banco Central",
  "BCR.PANORAMA_SOCIEDADES_DEPOSITO" = "Panorama de las sociedades de depósito",
  "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_SA" =
    "PIB T. Producción y gasto. Índices de volumen encadenados. Serie desestacionalizada (referencia 2014)",
  "BCR.REMESAS_FAMILIARES_MENSUAL"   = "Ingresos mensuales de remesas familiares",
  "BCR.RESERVAS_INTERNACIONALES_NETAS" = "Reservas Internacionales Netas BCR",
  "BCR.SPNF_VIGENTE"                 = "Sector Público No Financiero (Serie 1994-2025)",
  "ONEC.IPC.BASE_2009"               = "Índice de Precios al Consumidor (IPC)"
)

.MESES_ES <- c("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
               "septiembre", "octubre", "noviembre", "diciembre")

#' Periodo ("2026-M06", "2026-07", "2026-T2") -> list(tipo = "M"|"T", n = año*12+mes | año*4+trim),
#' comparable dentro del mismo tipo. NULL si el formato no se reconoce.
clave_periodo <- function(p) {
  m <- regmatches(p, regexec("^(\\d{4})-(?:M?(\\d{2})|T(\\d))$", p))[[1]]
  if (length(m) == 0) return(NULL)
  anio <- as.integer(m[2])
  if (nzchar(m[4])) list(tipo = "T", n = anio * 4L + as.integer(m[4]))
  else list(tipo = "M", n = anio * 12L + as.integer(m[3]))
}

#' Nivel 1. `calendario` es el data.frame de calendario_divulgacion_bcr.csv. Devuelve
#' list(estado = TOCA | NO_TOCA | SIN_CALENDARIO, detalle).
estado_calendario <- function(publicacion_id, periodo_max, calendario, hoy = Sys.Date()) {
  sin <- function(motivo) list(estado = "SIN_CALENDARIO", detalle = motivo)
  variable <- unname(CALENDARIO_BCR_VARIABLE[publicacion_id])
  if (is.na(variable)) return(sin("sin fila del calendario mapeada"))
  if (as.integer(format(hoy, "%Y")) != CALENDARIO_BCR_ANIO) {
    return(sin(paste0("el calendario cubre ", CALENDARIO_BCR_ANIO, ", hoy es otro año")))
  }
  k_max <- clave_periodo(periodo_max)
  if (is.null(k_max)) return(sin(paste0("periodo_referencia_max no reconocido: ", periodo_max)))

  filas <- calendario[calendario$variable == variable, ]
  claves <- lapply(filas$periodo_referencia, clave_periodo)
  posterior <- vapply(claves, function(k) {
    !is.null(k) && k$tipo == k_max$tipo && k$n > k_max$n
  }, logical(1))
  filas <- filas[posterior, ]
  if (nrow(filas) == 0) return(sin("el calendario no anuncia un periodo posterior al vigente"))

  mes <- match(tolower(filas$mes_publicacion), .MESES_ES)
  if (anyNA(mes)) {
    stop("FALLO VISIBLE: mes_publicacion no reconocido en el calendario: ",
         paste(unique(filas$mes_publicacion[is.na(mes)]), collapse = ", "))
  }
  fechas <- as.Date(sprintf("%d-%02d-%02d", CALENDARIO_BCR_ANIO, mes, as.integer(filas$dia_publicacion)))
  primera <- min(fechas)
  if (primera <= hoy) {
    list(estado = "TOCA",
         detalle = paste0("anunciado para el ", primera, " (periodo posterior a ", periodo_max, ")"))
  } else {
    list(estado = "NO_TOCA", detalle = paste0("proxima fecha anunciada: ", primera))
  }
}

#' Nivel 2. Compara el ultimo periodo que sirve la fuente con el del vintage vigente. Devuelve
#' list(estado = NUEVO_PERIODO | SIN_NUEVO, detalle). Falla visible si el formato no se
#' reconoce o si la fuente sirve un periodo ANTERIOR al ya capturado (no es un caso esperado).
estado_sondeo <- function(periodo_max, periodo_fuente) {
  k_max <- clave_periodo(periodo_max)
  k_src <- clave_periodo(periodo_fuente)
  if (is.null(k_max) || is.null(k_src) || k_max$tipo != k_src$tipo) {
    stop("FALLO VISIBLE: periodos no comparables: vigente '", periodo_max, "', fuente '",
         periodo_fuente, "'.")
  }
  if (k_src$n < k_max$n) {
    stop("FALLO VISIBLE: la fuente sirve '", periodo_fuente, "', anterior al vigente '",
         periodo_max, "'. No se asume nada: revisar la fuente.")
  }
  if (k_src$n > k_max$n) {
    list(estado = "NUEVO_PERIODO", detalle = paste0("fuente: ", periodo_fuente, ", vigente: ", periodo_max))
  } else {
    list(estado = "SIN_NUEVO", detalle = paste0("fuente y vigente en ", periodo_max))
  }
}
