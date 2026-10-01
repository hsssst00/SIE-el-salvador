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
#
# RECAPTURAS DE UT (2026-09-30, ADR-007, nota de seguimiento de esa fecha): desde la primera
# ventana trimestral un mismo año puede tener varios vintages -- el año en curso gana meses, un
# año revisado se vuelve a bajar --, y cuenta el ULTIMO registrado de cada año, la misma
# convencion de "vigente = ultima fila" aplicada por año. mapa_vintage_por_anio() ya no se
# detiene ante un año con mas de un vintage.

#' Lee catalogos/08_vintages.csv. Separada en su propia funcion para que
#' tests/test-vintage-lib.R pueda pasarle un data.frame sintetico a las funciones de abajo sin
#' tocar disco. `ruta` solo se cambia para leer un catalogo que no es el del repo (el repo de
#' mentira de tests/test-ut-captura.R).
leer_vintages <- function(ruta = here::here("catalogos", "08_vintages.csv")) {
  read.csv(ruta, stringsAsFactors = FALSE, na.strings = "")
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

#' Filas de `vintages` que un `conjunto` declara para una publicacion_id, en el orden de
#' 08_vintages.csv. `conjunto` es un data.frame(publicacion_id, vintage_id) -- ver
#' leer_conjunto() en conjunto_lib.R --; NULL = sin conjunto (todas las filas de la publicacion,
#' como siempre). Con conjunto falla visible si la publicacion no tiene ningun vintage declarado,
#' o si alguno declarado no es un vintage de esa publicacion en el catalogo. Pura.
filas_de_publicacion <- function(publicacion_id, vintages, conjunto = NULL) {
  filas <- vintages[vintages$publicacion_id == publicacion_id, ]
  if (is.null(conjunto)) return(filas)
  declarados <- conjunto$vintage_id[conjunto$publicacion_id == publicacion_id]
  if (length(declarados) == 0) {
    stop("FALLO VISIBLE: el conjunto de vintages no declara ningun vintage para la publicacion '",
         publicacion_id, "'.")
  }
  desconocidos <- setdiff(declarados, filas$vintage_id)
  if (length(desconocidos) > 0) {
    stop("FALLO VISIBLE: el conjunto declara para '", publicacion_id, "' vintage(s) que no son ",
         "de esa publicacion en catalogos/08_vintages.csv: ",
         paste(desconocidos, collapse = ", "), ".")
  }
  filas[filas$vintage_id %in% declarados, ]
}

#' vintage_id vigente de una publicacion_id: la ULTIMA fila de 08_vintages.csv (append-only) o,
#' con `conjunto`, el vintage que el conjunto declara para ella (debe ser exactamente uno: una
#' publicacion con varios declarados es ambigua aca; las de un vintage por año se resuelven con
#' mapa_vintage_por_anio()). Falla visible si la publicacion no tiene ninguna fila -- un
#' predictor de L3 sin fila en 08_vintages.csv es un catalogo inconsistente que esta columna no
#' debe encubrir con un valor vacio.
vintage_vigente <- function(publicacion_id, vintages, conjunto = NULL) {
  filas <- filas_de_publicacion(publicacion_id, vintages, conjunto)
  if (nrow(filas) == 0) {
    stop("FALLO VISIBLE: publicacion_id '", publicacion_id, "' no tiene ninguna fila en ",
         "catalogos/08_vintages.csv -- no se puede resolver su vintage vigente para la ",
         "columna vintage_id de L3.")
  }
  if (!is.null(conjunto) && nrow(filas) > 1) {
    stop("FALLO VISIBLE: el conjunto declara ", nrow(filas), " vintages para '", publicacion_id,
         "' (", paste(filas$vintage_id, collapse = ", "), "); aca se espera uno solo.")
  }
  filas$vintage_id[nrow(filas)]
}

#' Archivo de L0 que corresponde a una publicacion_id: el de su vintage vigente (ultima fila de
#' 08_vintages.csv) o, con `conjunto`, el del vintage que el conjunto declara. Devuelve la
#' ruta `file.path(dir_l0, archivo_raw)`. Con conjunto verifica ademas, en el momento de usarse,
#' que el archivo exista en L0 con el sha256 del manifiesto (verificar_sha256_l0()), de modo que
#' un extractor corrido solo tambien quede protegido. Es la unica seleccion de archivo que usan
#' los extractores de L1.
archivo_l0_vigente <- function(publicacion_id, conjunto = NULL, vintages = leer_vintages(),
                               dir_l0 = "data/L0_raw") {
  filas <- filas_de_publicacion(publicacion_id, vintages, conjunto)
  if (nrow(filas) < 1) {
    stop("FALLO VISIBLE: no se encontró ningún vintage para ", publicacion_id, " en 08_vintages.csv")
  }
  if (!is.null(conjunto)) {
    vid <- vintage_vigente(publicacion_id, vintages, conjunto)
    verificar_sha256_l0(vid, vintages, dir_l0)
    filas <- filas[filas$vintage_id == vid, ]
  }
  file.path(dir_l0, filas$archivo_raw[nrow(filas)])
}

#' Comprueba que el archivo de L0 de un vintage existe y que su sha256 crudo coincide con el que
#' declara manifiesto.csv (la integridad de ADR-007: sha256 es integridad, sha256_norm identidad).
#' Falla visible si el vintage no tiene exactamente una fila en el manifiesto, si esa fila no es
#' de la misma publicacion y archivo que el catalogo, si el archivo no esta o si el hash difiere.
#' Memoiza por archivo dentro de la sesion de R: el extractor del PIB lo pide una vez por serie.
verificar_sha256_l0 <- function(vintage_id, vintages, dir_l0 = "data/L0_raw",
                                manifiesto = leer_manifiesto(dir_l0)) {
  fv <- vintages[vintages$vintage_id == vintage_id, ]
  fm <- manifiesto[manifiesto$vintage_id == vintage_id, ]
  if (nrow(fv) != 1 || nrow(fm) != 1) {
    stop("FALLO VISIBLE: el vintage '", vintage_id, "' tiene ", nrow(fv), " fila(s) en ",
         "08_vintages.csv y ", nrow(fm), " en manifiesto.csv (se espera 1 en cada uno).")
  }
  if (!identical(fm$archivo, fv$archivo_raw) || !identical(fm$publicacion_id, fv$publicacion_id)) {
    stop("FALLO VISIBLE: el vintage '", vintage_id, "' no concuerda entre 08_vintages.csv ",
         "(archivo '", fv$archivo_raw, "') y manifiesto.csv (archivo '", fm$archivo, "').")
  }
  ruta <- file.path(dir_l0, fm$archivo)
  if (!file.exists(ruta)) {
    stop("FALLO VISIBLE: no está ", ruta, " (vintage '", vintage_id, "'). Repoblar L0 con ",
         "`make materializar-l0`.")
  }
  clave <- paste(normalizePath(ruta, winslash = "/"), tolower(fm$sha256))
  if (isTRUE(.sha256_verificados[[clave]])) return(invisible(TRUE))
  sha_real <- tolower(digest::digest(object = ruta, algo = "sha256", file = TRUE))
  if (!identical(sha_real, tolower(fm$sha256))) {
    stop("FALLO VISIBLE: el sha256 de ", ruta, " (", sha_real, ") no coincide con el del ",
         "manifiesto (", fm$sha256, ") para el vintage '", vintage_id, "'. L0 es inmutable ",
         "(regla 1 de CLAUDE.md).")
  }
  .sha256_verificados[[clave]] <- TRUE
  invisible(TRUE)
}
.sha256_verificados <- new.env(parent = emptyenv())

#' manifiesto.csv de L0 como lo lee todo el pipeline: todo texto.
leer_manifiesto <- function(dir_l0 = "data/L0_raw") {
  read.csv(file.path(dir_l0, "manifiesto.csv"), stringsAsFactors = FALSE, colClasses = "character")
}

#' Agrega una columna `vintage_id` constante a `serie` (data.frame con columna `periodo`),
#' resuelta como el vintage vigente de cada publicacion_id en `publicacion_ids`, unidos con
#' " + " cuando son varias (p.ej. una deflactacion que consume dos publicaciones en cada fila).
#' Uso: series cuyo valor en CADA fila depende de la(s) misma(s) publicacion(es) en toda la
#' serie -- el caso de todos los predictores de la matriz (ADR-010) y de PIB.SA.OFICIAL.Q.
agregar_vintage_constante <- function(serie, publicacion_ids, vintages, conjunto = NULL) {
  ids <- vapply(unique(publicacion_ids), vintage_vigente, character(1), vintages = vintages,
                conjunto = conjunto)
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
agregar_vintage_por_anio <- function(serie, publicacion_id, vintages, conjunto = NULL) {
  mapa <- mapa_vintage_por_anio(publicacion_id, vintages, conjunto)
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
#' visible si la publicacion no tiene vintages o si algun `periodo_referencia_max` no arranca con
#' un año. Con varios vintages para un mismo año (recapturas: el año en curso gana meses, un año
#' revisado se vuelve a bajar) toma el ULTIMO registrado de ese año, en el orden de las filas de
#' 08_vintages.csv (append-only). Con `conjunto` solo cuentan los vintages que declara, y cada año
#' debe tener uno solo. El resultado va ordenado por año. Pura.
mapa_vintage_por_anio <- function(publicacion_id, vintages, conjunto = NULL) {
  filas <- filas_de_publicacion(publicacion_id, vintages, conjunto)
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
  if (!is.null(conjunto) && anyDuplicated(anio_vintage) > 0) {
    stop("FALLO VISIBLE ['", publicacion_id, "']: el conjunto declara mas de un vintage para el ",
         "mismo año (", paste(unique(anio_vintage[duplicated(anio_vintage)]), collapse = ", "),
         "); un conjunto trae un vintage por año.")
  }
  ultimo_del_anio <- !duplicated(anio_vintage, fromLast = TRUE)
  mapa <- setNames(filas$vintage_id[ultimo_del_anio], anio_vintage[ultimo_del_anio])
  mapa[order(names(mapa))]
}

#' Agrega una columna `vintage_id` que varia por fila segun `publicacion_id_por_fila` (vector
#' del mismo largo que `nrow(serie)`, alineado por posicion): el vintage vigente de la
#' publicacion que aporto la observacion cruda de esa fila especifica. Uso: PIB.SA.PROPIO.Q,
#' donde T001 empalma dos publicaciones (RETRO hasta el trimestre anterior al primer nativo,
#' nativo desde ahi) y cada periodo hereda el vintage de la que efectivamente lo aporto.
agregar_vintage_por_fila <- function(serie, publicacion_id_por_fila, vintages, conjunto = NULL) {
  if (length(publicacion_id_por_fila) != nrow(serie)) {
    stop("FALLO VISIBLE: publicacion_id_por_fila (", length(publicacion_id_por_fila),
         ") no tiene el mismo largo que la serie (", nrow(serie), " filas).")
  }
  ids_unicos <- unique(publicacion_id_por_fila)
  mapa <- setNames(vapply(ids_unicos, vintage_vigente, character(1), vintages = vintages,
                          conjunto = conjunto), ids_unicos)
  serie$vintage_id <- unname(mapa[publicacion_id_por_fila])
  serie
}
