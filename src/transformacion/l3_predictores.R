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
#
# Salidas en data/L3_master/ (capa generada, no versionada): un CSV por serie_id (mensual o
# trimestral), con el punto reemplazado por guion bajo -- p.ej. BCR.IVAE.VOL.SA.Q ->
# BCR_IVAE_VOL_SA_Q.csv. El pass-through mensual de una serie L1 solo se materializa cuando esa
# serie tiene su propia fila de agregacion trimestral en el catalogo (evita escribir a L3 series
# que solo existen como insumo intermedio de otra transformacion, p.ej. ONEC.IPC.IDX.NSA.M).

source(here::here("src", "transformacion", "l3_predictores_reglas.R"))

FUENTE_L1 <- list(
  "BCR.IVAE.VOL.SA.M" = here::here("data", "L1_staging", "BCR_IVAE_series_largo.csv"),
  "BCR.REMESAS.NOM.NSA.M" = here::here("data", "L1_staging", "BCR_REMESAS_series_largo.csv"),
  "ONEC.IPC.IDX.NSA.M" = here::here("data", "L1_staging", "ONEC_IPC_series_largo.csv"),
  "BCR.IPP.IDX.NSA.M" = here::here("data", "L1_staging", "BCR_IPP_series_largo.csv"),
  "BCR.EXPORT_FOB.NOM.NSA.M" = here::here("data", "L1_staging", "BCR_BALANZA_COMERCIAL_series_largo.csv"),
  "BCR.ITCER.IDX.NSA.M" = here::here("data", "L1_staging", "BCR_ITCER_series_largo.csv"),
  "BCR.IPM.IDX.NSA.M" = here::here("data", "L1_staging", "BCR_INDICES_PRECIOS_COMERCIO_EXTERIOR_series_largo.csv")
)

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

registro <- new.env(parent = emptyenv())

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
    write.csv(serie, archivo, row.names = FALSE, na = "")
    cat("OK: ", serie_id, " (", nrow(serie), " obs, pass-through) -> ", archivo, "\n", sep = "")
  }
  serie
}

for (i in seq_len(nrow(transformaciones))) {
  fila <- transformaciones[i, ]
  insumos <- insumos_por_fila[[i]]
  fn <- match.fun(sub("\\(\\)$", "", fila$funcion))
  series_insumo <- lapply(insumos, resolver_insumo)

  resultado <- if (length(series_insumo) == 1) {
    fn(series_insumo[[1]], etiqueta = fila$serie_producto)
  } else if (length(series_insumo) == 2) {
    fn(series_insumo[[1]], series_insumo[[2]], etiqueta = fila$serie_producto)
  } else {
    stop("FALLO VISIBLE [", fila$transf_id, "]: ", length(series_insumo),
         " serie(s) insumo declaradas; l3_predictores.R solo sabe invocar funciones de 1 o 2 ",
         "insumos (agregacion o deflactacion)")
  }

  assign(fila$serie_producto, resultado, envir = registro)
  archivo <- ruta_l3(fila$serie_producto)
  write.csv(resultado, archivo, row.names = FALSE, na = "")
  cat("OK: ", fila$serie_producto, " (", nrow(resultado), " obs, ", fila$transf_id, ") -> ",
      archivo, "\n", sep = "")
}
