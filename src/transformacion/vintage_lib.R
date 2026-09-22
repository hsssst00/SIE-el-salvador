# vintage_lib.R
#
# Resuelve el vintage VIGENTE de una publicacion_id contra catalogos/08_vintages.csv, para la
# columna `vintage_id` que E3/D4 (checklist de cierre de Fase 3, decision de Harold 2026-09-21)
# agrega a cada archivo de data/L3_master/.
#
# LA LECTURA DE "BITEMPORAL" QUE ESTO IMPLEMENTA (senda S4/D7: "cada observacion indexada por
# periodo de referencia Y por fecha de publicacion"): cada archivo de L3 pasa a
# periodo,valor,vintage_id, resuelta contra 08_vintages.csv por el/los publicacion_id que
# aportaron el valor crudo de esa fila -- no una lectura documental aparte (la opcion que se
# descarto): la dimension de vintage vive EN la base maestra, no solo en el catalogo.
#
# "Vigente" = ULTIMA fila del manifiesto para esa publicacion_id (append-only), misma
# convencion que registrar_descarga() paso 3, scripts/verificar_l0.R y
# src/validacion/verificar_fuente_celda.R. Hoy (2026-09-21) toda publicacion que alimenta L3
# tiene exactamente 1 vintage en el catalogo -- salvo UT, que no se materializa a L3 (E1/D3) --
# asi que la columna es constante dentro de cada archivo salvo en PIB.SA.PROPIO.Q, donde el
# empalme RETRO+nativo (T001) hace que el vintage varie por periodo segun cual de las dos
# publicaciones aporto la observacion cruda de ese trimestre.

#' Lee catalogos/08_vintages.csv. Separada en su propia funcion para que
#' tests/test-vintage-lib.R pueda pasarle un data.frame sintetico a las funciones de abajo sin
#' tocar disco.
leer_vintages <- function() {
  read.csv(here::here("catalogos", "08_vintages.csv"), stringsAsFactors = FALSE, na.strings = "")
}

#' publicacion_id declarado en catalogos/03_series.csv para una serie_id. Pura -- recibe el
#' catalogo ya cargado, no lo lee de disco -- para que tanto l3_pib_objetivo.R como
#' l3_predictores.R resuelvan la misma columna con la misma funcion en vez de repetir el
#' `series_catalogo$publicacion_id[series_catalogo$serie_id == serie_id]` cada uno por su lado.
resolver_publicacion <- function(serie_id, catalogo_series) {
  publicacion <- catalogo_series$publicacion_id[catalogo_series$serie_id == serie_id]
  if (length(publicacion) != 1) {
    stop("FALLO VISIBLE [", serie_id, "]: se esperaba exactamente una fila en ",
         "catalogos/03_series.csv para esta serie (la columna vintage_id exige su ",
         "`publicacion_id` por catalogo), hay ", length(publicacion), ".")
  }
  publicacion
}

#' vintage_id vigente (ultima fila) de una publicacion_id. Falla visible si la publicacion no
#' tiene ninguna fila -- un predictor de L3 sin fila en 08_vintages.csv es un catalogo
#' inconsistente que esta columna no debe encubrir con un valor vacio.
vintage_vigente <- function(publicacion_id, vintages) {
  filas <- vintages[vintages$publicacion_id == publicacion_id, ]
  if (nrow(filas) == 0) {
    stop("FALLO VISIBLE: publicacion_id '", publicacion_id, "' no tiene ninguna fila en ",
         "catalogos/08_vintages.csv -- no se puede resolver su vintage vigente para la ",
         "columna vintage_id de L3.")
  }
  filas$vintage_id[nrow(filas)]
}

#' Agrega una columna `vintage_id` constante a `serie` (data.frame con columna `periodo`),
#' resuelta como el vintage vigente de cada publicacion_id en `publicacion_ids`, unidos con
#' " + " cuando son varias (p.ej. una deflactacion que consume dos publicaciones en cada fila).
#' Uso: series cuyo valor en CADA fila depende de la(s) misma(s) publicacion(es) en toda la
#' serie -- el caso de todos los predictores de la matriz (ADR-010) y de PIB.SA.OFICIAL.Q.
agregar_vintage_constante <- function(serie, publicacion_ids, vintages) {
  ids <- vapply(unique(publicacion_ids), vintage_vigente, character(1), vintages = vintages)
  serie$vintage_id <- paste(ids, collapse = " + ")
  serie
}

#' Agrega una columna `vintage_id` que varia por fila segun `publicacion_id_por_fila` (vector
#' del mismo largo que `nrow(serie)`, alineado por posicion): el vintage vigente de la
#' publicacion que aporto la observacion cruda de esa fila especifica. Uso: PIB.SA.PROPIO.Q,
#' donde T001 empalma dos publicaciones (RETRO hasta el trimestre anterior al primer nativo,
#' nativo desde ahi) y cada periodo hereda el vintage de la que efectivamente lo aporto.
agregar_vintage_por_fila <- function(serie, publicacion_id_por_fila, vintages) {
  if (length(publicacion_id_por_fila) != nrow(serie)) {
    stop("FALLO VISIBLE: publicacion_id_por_fila (", length(publicacion_id_por_fila),
         ") no tiene el mismo largo que la serie (", nrow(serie), " filas).")
  }
  ids_unicos <- unique(publicacion_id_por_fila)
  mapa <- setNames(vapply(ids_unicos, vintage_vigente, character(1), vintages = vintages), ids_unicos)
  serie$vintage_id <- unname(mapa[publicacion_id_por_fila])
  serie
}
