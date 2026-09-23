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
# src/validacion/verificar_fuente_celda.R. La columna es CONSTANTE dentro de cada archivo para
# toda publicacion con un solo vintage en el catalogo (las 7 familias del BCR), y VARIA por
# periodo en dos casos:
#
# - PIB.SA.PROPIO.Q: el empalme RETRO+nativo (T001) hace que el vintage dependa de cual de las
#   dos publicaciones aporto la observacion cruda de cada trimestre -- agregar_vintage_por_fila().
# - UT.DEMANDA_ELEC.GWH.NSA.M/.Q desde 2026-09-23 (enmienda del alcance E1/D3, decision de
#   Harold: UT entra a la matriz). Es la primera publicacion de la matriz capturada UN ARCHIVO
#   POR AÑO -- 25 vintages, uno por año de cobertura --, asi que cada observacion hereda el
#   vintage del archivo del año que la aporto: agregar_vintage_por_anio(). Tomar aca el vintage
#   "vigente" (la ultima fila) etiquetaria con el archivo de 2026 las 288 observaciones de
#   2002-2025, que no las produjo -- solo las 7 de 2026 (M01-M07) le corresponden.
#
# ADVERTENCIA sobre UT: la `fecha_publicacion` de sus 25 vintages es SINTETICA (31-dic de cada
# año, 31-jul para 2026), derivada solo para evitar colision de vintage_id -- no es la fecha
# real de publicacion de UT, que el portal no expone (ver la nota de cada vintage en
# 08_vintages.csv y la fila de 03_series.csv). La dimension bitemporal de esta serie es por lo
# tanto de grano ANUAL y de fecha APROXIMADA; Fase 4 debe tratarla como tal si evalua con datos
# tal-como-se-conocian.

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

#' Agrega una columna `vintage_id` que varia por AÑO de referencia, para publicaciones
#' capturadas UN ARCHIVO POR AÑO: cada fila hereda el vintage cuyo `periodo_referencia_max` cae
#' en el mismo año que su `periodo`. Uso: UT.DEMANDA_ELEC.GWH.NSA.M/.Q (25 vintages, 2002-2026),
#' cuya serie L1 se deriva de los 25 CSV anuales via src/transformacion/ut_demanda_serie.R --
#' tomar el vintage "vigente" (la ultima fila) etiquetaria toda la serie con el archivo de 2026.
#' Sirve igual para mensual (2002-M01) y trimestral (2002-Q1): la clave es el año, y ningun
#' trimestre cruza el borde de año. Pura -- recibe el catalogo de vintages ya cargado.
agregar_vintage_por_anio <- function(serie, publicacion_id, vintages) {
  mapa <- mapa_vintage_por_anio(publicacion_id, vintages)
  anio_obs <- substr(serie$periodo, 1, 4)
  faltantes <- setdiff(unique(anio_obs), names(mapa))
  if (length(faltantes) > 0) {
    stop("FALLO VISIBLE ['", publicacion_id, "']: la serie tiene observaciones de ",
         paste(faltantes, collapse = ", "), " y no hay vintage de ese año en ",
         "catalogos/08_vintages.csv.")
  }
  serie$vintage_id <- unname(mapa[anio_obs])
  serie
}

#' Mapa año -> vintage_id (vector nombrado por año de 4 digitos) de una publicacion capturada UN
#' ARCHIVO POR AÑO. Separado de agregar_vintage_por_anio() el 2026-09-23 para que
#' src/validacion/verificar_fuente_celda.R resuelva que archivo de L0 corresponde a cada año con
#' la MISMA regla que usa L3 para etiquetar la columna vintage_id, en vez de repetirla. Falla
#' visible si la publicacion no tiene vintages, si algun `periodo_referencia_max` no arranca con
#' un año, o si hay mas de un vintage para el mismo año. Pura.
mapa_vintage_por_anio <- function(publicacion_id, vintages) {
  filas <- vintages[vintages$publicacion_id == publicacion_id, ]
  if (nrow(filas) == 0) {
    stop("FALLO VISIBLE: publicacion_id '", publicacion_id, "' no tiene ninguna fila en ",
         "catalogos/08_vintages.csv -- no se puede resolver su vintage por año.")
  }
  anio_vintage <- substr(filas$periodo_referencia_max, 1, 4)
  if (anyNA(anio_vintage) || any(!grepl("^[0-9]{4}$", anio_vintage))) {
    stop("FALLO VISIBLE ['", publicacion_id, "']: `periodo_referencia_max` de 08_vintages.csv ",
         "no arranca con un año de 4 digitos en todas sus filas -- esta resolucion por año ",
         "exige esa convencion.")
  }
  duplicado <- anyDuplicated(anio_vintage)
  if (duplicado > 0) {
    stop("FALLO VISIBLE ['", publicacion_id, "']: hay mas de un vintage para el año ",
         anio_vintage[duplicado], " en catalogos/08_vintages.csv -- la resolucion por año ",
         "exige un archivo por año (si la publicacion pasa a tener revisiones dentro del mismo ",
         "año, esta serie necesita la resolucion por fila, no por año).")
  }
  setNames(filas$vintage_id, anio_vintage)
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
