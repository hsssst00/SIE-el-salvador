# L1 -> L3 de la matriz de predictores (ADR-010). Reglas en
# src/transformacion/l3_predictores_reglas.R, para que tests/test-l3-predictores.R las ejerza
# con datos sinteticos.
#
# Catalogo-dirigido (2026-09-17, remediacion del hallazgo I4 de la revision independiente de
# Fase 3): antes, este script repetia a mano un bloque de seis lineas por serie -- con el nombre
# de la funcion y el de la serie producto escritos en el codigo, duplicando lo que
# catalogos/04_transformaciones.csv ya declara por fila (series_insumo, serie_producto, funcion).
# Ahora el catalogo ES la especificacion ejecutable: este script itera las filas cuyo
# script_path es este archivo y resuelve `funcion` con match.fun(). Añadir un predictor nuevo
# que agregue o deflacte con las funciones ya existentes en l3_predictores_reglas.R es una fila
# de catalogo, no un bloque de codigo copiado.
#
# La justificacion metodologica por predictor (por que suma vs promedio, por que se deflacta o
# no, decisiones de Harold sobre que serie de cabecera admitir de una publicacion multi-serie)
# vive en la columna `justificacion` de 04_transformaciones.csv, fila por fila -- no se repite
# aca. Contexto que el catalogo no captura, porque es sobre el conjunto y no sobre una fila:
#
# - IVAE (T003) ya es volumen SA de la publicacion del BCR: no requiere deflactacion ni ajuste
#   estacional propio, a diferencia de la variable objetivo (ver l3_pib_objetivo.R).
# - REMESAS (T004-T006) es la unica serie que se materializa en dos versiones -- nominal y real
#   -- por decision de Harold (2026-09-16); T006 encadena sobre el producto de T004, no sobre L1.
# - EXPORT_FOB (T008) es la unica de las tres series de cabecera de Balanza Comercial
#   (Exportaciones/Importaciones/Balanza) admitida esta sesion (decision de Harold, AskUserQuestion,
#   2026-09-16); no se deflacta (solo nominal, por ahora).
# - ITCER e IPM (T009-T010) siguen el mismo criterio de "serie de cabecera mas directa/agregada"
#   ya fijado para IPP/EXPORT_FOB, sin volver a preguntar caso por caso (autorizacion de Harold,
#   2026-09-16) -- el detalle de cual serie es la de cabecera esta en 03_series.csv.
# - UT.DEMANDA_ELEC (T011) es el octavo predictor y el primero que NO es del BCR: entra el
#   2026-09-23 por decision de Harold, enmendando el alcance E1/D3 del cierre de Fase 3, que la
#   habia dejado admitida en 03_series.csv y en la bateria L2 pero fuera de la matriz. Es la
#   unica serie insumo de la matriz con mas de un vintage en 08_vintages.csv (25, uno por año
#   de captura), asi que su columna vintage_id se resuelve por AÑO y no por vintage vigente --
#   ver VINTAGE_POR_ANIO abajo.
#
# Salidas en data/L3_master/ (capa generada, no versionada): un CSV por serie_id (mensual o
# trimestral), con el punto reemplazado por guion bajo -- p.ej. BCR.IVAE.VOL.SA.Q ->
# BCR_IVAE_VOL_SA_Q.csv. El pass-through mensual de una serie L1 solo se materializa cuando esa
# serie tiene su propia fila de agregacion trimestral en el catalogo (evita escribir a L3 series
# que solo existen como insumo intermedio de otra transformacion, p.ej. ONEC.IPC.IDX.NSA.M).

source(here::here("src", "transformacion", "l3_predictores_reglas.R"))
source(here::here("src", "transformacion", "vintage_lib.R"))

vintages_catalogo <- leer_vintages()

FUENTE_L1 <- list(
  "BCR.IVAE.VOL.SA.M" = here::here("data", "L1_staging", "BCR_IVAE_series_largo.csv"),
  "BCR.REMESAS.NOM.NSA.M" = here::here("data", "L1_staging", "BCR_REMESAS_series_largo.csv"),
  "ONEC.IPC.IDX.NSA.M" = here::here("data", "L1_staging", "ONEC_IPC_series_largo.csv"),
  "BCR.IPP.IDX.NSA.M" = here::here("data", "L1_staging", "BCR_IPP_series_largo.csv"),
  "BCR.EXPORT_FOB.NOM.NSA.M" = here::here("data", "L1_staging", "BCR_BALANZA_COMERCIAL_series_largo.csv"),
  "BCR.ITCER.IDX.NSA.M" = here::here("data", "L1_staging", "BCR_ITCER_series_largo.csv"),
  "BCR.IPM.IDX.NSA.M" = here::here("data", "L1_staging", "BCR_INDICES_PRECIOS_COMERCIO_EXTERIOR_series_largo.csv"),
  "UT.DEMANDA_ELEC.GWH.NSA.M" = here::here("data", "L1_staging", "UT_DEMANDA_series_largo.csv")
)

# Series insumo cuyo `vintage_id` se resuelve por AÑO de referencia en vez de por vintage
# vigente (ver src/transformacion/vintage_lib.R). El caso general es una publicacion con un
# solo vintage en 08_vintages.csv, donde ambas resoluciones coinciden. UT es la excepcion:
# 25 vintages, uno por archivo anual, y su serie L1 se deriva de los 25 -- el vintage vigente
# etiquetaria con el archivo de 2026 las 288 observaciones mensuales de 2002-2025, que no las
# produjo (solo las 7 de 2026 le corresponden).
VINTAGE_POR_ANIO <- "UT.DEMANDA_ELEC.GWH.NSA.M"

ruta_l3 <- function(serie_id) here::here("data", "L3_master", paste0(gsub("\\.", "_", serie_id), ".csv"))

dir.create(here::here("data", "L3_master"), showWarnings = FALSE, recursive = TRUE)

transformaciones <- read.csv(here::here("catalogos", "04_transformaciones.csv"), stringsAsFactors = FALSE, na.strings = "")
transformaciones <- transformaciones[transformaciones$script_path == "src/transformacion/l3_predictores.R", ]
if (nrow(transformaciones) == 0) {
  stop("FALLO VISIBLE: catalogos/04_transformaciones.csv no tiene ninguna fila con ",
       "script_path == 'src/transformacion/l3_predictores.R'")
}

insumos_por_fila <- lapply(transformaciones$series_insumo, function(x) trimws(strsplit(x, ",")[[1]]))
series_con_agregacion_propia <- unique(unlist(insumos_por_fila[lengths(insumos_por_fila) == 1]))

series_catalogo <- read.csv(here::here("catalogos", "03_series.csv"), stringsAsFactors = FALSE, na.strings = "")

# `unit_measure` declarado en 03_series.csv para una serie insumo. Solo se consulta para las
# funciones que lo piden en su firma (hoy deflactar_serie(), que exige que el segundo insumo
# sea el indice de precios: el orden de `series_insumo` es semantico y el bucle los pasa por
# posicion). Se resuelve aca y no dentro de la regla para que las reglas sigan siendo puras.
unidad_insumo <- function(serie_id) {
  unidad <- series_catalogo$unit_measure[series_catalogo$serie_id == serie_id]
  if (length(unidad) != 1) {
    stop("FALLO VISIBLE [", serie_id, "]: se esperaba exactamente una fila en ",
         "catalogos/03_series.csv para esta serie insumo (la transformacion que la usa exige ",
         "su `unit_measure` por catalogo), hay ", length(unidad), ".")
  }
  unidad
}

# `publicacion_id` declarado en 03_series.csv para una serie insumo -- resuelve la columna
# `vintage_id` de E3/D4 (cierre de Fase 3): cada archivo de L3_master/ hereda el vintage
# vigente de la(s) publicacion(es) de sus insumos, vía vintage_lib.R (resolver_publicacion()).
publicacion_de_insumo <- function(serie_id) resolver_publicacion(serie_id, series_catalogo)

registro <- new.env(parent = emptyenv())

# Registro de vintage_id ya resuelto por serie_id (crudo o producto). REMESAS es la única
# cadena de dos niveles de esta matriz (T006 encadena sobre el producto de T004, ver la nota de
# cabecera): cuando un insumo es el `serie_producto` de una fila ya procesada, su vintage se
# REUSA del que ya se calculó para ese producto, no se busca en 03_series.csv (no tiene fila
# ahí -- es un producto de L3, no una serie cruda de L1). Las filas del catálogo están en orden
# de dependencia (T004 antes de T006), así que el producto ya está en este registro quando se
# lo necesita como insumo.
vintage_registro <- new.env(parent = emptyenv())

vintage_de_insumo <- function(serie_id) {
  if (exists(serie_id, envir = vintage_registro, inherits = FALSE)) {
    return(get(serie_id, envir = vintage_registro, inherits = FALSE))
  }
  vid <- vintage_vigente(publicacion_de_insumo(serie_id), vintages_catalogo)
  assign(serie_id, vid, envir = vintage_registro)
  vid
}

vintage_de_insumos <- function(serie_ids) {
  paste(unique(vapply(serie_ids, vintage_de_insumo, character(1))), collapse = " + ")
}

# Agrega la columna `vintage_id` a una serie de L3 (cruda pass-through o producto de una
# transformacion), eligiendo la resolucion segun sus insumos: por AÑO si el insumo esta en
# VINTAGE_POR_ANIO, constante (vintage vigente) en el caso general. Devuelve la serie con la
# columna agregada; NO escribe a disco.
con_vintage <- function(serie, serie_ids) {
  por_anio <- intersect(serie_ids, VINTAGE_POR_ANIO)
  if (length(por_anio) == 0) {
    serie$vintage_id <- vintage_de_insumos(serie_ids)
    return(serie)
  }
  if (length(serie_ids) > 1) {
    stop("FALLO VISIBLE [", paste(serie_ids, collapse = ", "), "]: ",
         paste(por_anio, collapse = ", "), " resuelve su vintage por año, y esta ",
         "transformacion combina varios insumos -- una fila con dos publicaciones de las ",
         "cuales una tiene vintage anual necesita una regla explicita (hoy no existe ese ",
         "caso en la matriz).")
  }
  agregar_vintage_por_anio(serie, publicacion_de_insumo(por_anio), vintages_catalogo)
}

leer_l1 <- function(serie_id) {
  archivo <- FUENTE_L1[[serie_id]]
  if (is.null(archivo)) {
    stop("FALLO VISIBLE [", serie_id, "]: no hay archivo L1 registrado para esta serie en ",
         "l3_predictores.R (FUENTE_L1)")
  }
  l1 <- read.csv(archivo, stringsAsFactors = FALSE, na.strings = "")
  l1 <- l1[l1$serie_id == serie_id, c("periodo", "valor")]
  l1[order(l1$periodo), ]
}

resolver_insumo <- function(serie_id) {
  if (exists(serie_id, envir = registro, inherits = FALSE)) {
    return(get(serie_id, envir = registro))
  }
  serie <- leer_l1(serie_id)
  assign(serie_id, serie, envir = registro)
  if (serie_id %in% series_con_agregacion_propia) {
    archivo <- ruta_l3(serie_id)
    serie_con_vintage <- con_vintage(serie, serie_id)
    write.csv(serie_con_vintage, archivo, row.names = FALSE, na = "")
    cat("OK: ", serie_id, " (", nrow(serie), " obs, pass-through) -> ", archivo, "\n", sep = "")
  }
  serie
}

for (i in seq_len(nrow(transformaciones))) {
  fila <- transformaciones[i, ]
  insumos <- insumos_por_fila[[i]]
  fn <- match.fun(sub("\\(\\)$", "", fila$funcion))
  series_insumo <- lapply(insumos, resolver_insumo)

  if (length(series_insumo) < 1 || length(series_insumo) > 2) {
    stop("FALLO VISIBLE [", fila$transf_id, "]: ", length(series_insumo),
         " serie(s) insumo declaradas; l3_predictores.R solo sabe invocar funciones de 1 o 2 ",
         "insumos (agregacion o deflactacion)")
  }

  # Las funciones que declaran `unidades_insumo` en su firma reciben ademas el `unit_measure`
  # de cada insumo segun 03_series.csv, en el mismo orden posicional que `series_insumo`.
  argumentos <- c(series_insumo, list(etiqueta = fila$serie_producto))
  if ("unidades_insumo" %in% names(formals(fn))) {
    argumentos$unidades_insumo <- vapply(insumos, unidad_insumo, character(1))
  }
  resultado <- do.call(fn, argumentos)

  assign(fila$serie_producto, resultado, envir = registro)
  resultado_con_vintage <- con_vintage(resultado, insumos)
  # El registro de vintage por serie_id solo tiene sentido cuando el vintage es un escalar
  # (caso constante): lo consume vintage_de_insumo() cuando un producto de L3 es a su vez
  # insumo de otra fila (hoy solo T006 sobre el producto de T004). Un producto de vintage
  # anual no se registra; si alguna vez se usa como insumo, vintage_de_insumo() lo buscara en
  # 03_series.csv y fallara de forma visible en vez de heredar un valor equivocado.
  if (length(intersect(insumos, VINTAGE_POR_ANIO)) == 0) {
    assign(fila$serie_producto, vintage_de_insumos(insumos), envir = vintage_registro)
  }
  archivo <- ruta_l3(fila$serie_producto)
  write.csv(resultado_con_vintage, archivo, row.names = FALSE, na = "")
  cat("OK: ", fila$serie_producto, " (", nrow(resultado), " obs, ", fila$transf_id, ") -> ",
      archivo, "\n", sep = "")
}
