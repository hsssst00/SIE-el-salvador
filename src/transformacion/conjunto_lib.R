# conjunto_lib.R
#
# CONJUNTO DE VINTAGES DECLARADO: construir L1 y L3 con los vintages que un archivo declara, en
# vez de con el "vigente" (ultima fila de 08_vintages.csv), y escribir el resultado en un
# directorio propio sin tocar la L1/L3/L2 vigentes. Capacidad generica: no sabe nada de
# evaluacion ni de ningun corte concreto; quien arme el conjunto decide que vintages entran.
#
# FORMATO. CSV con dos columnas, `publicacion_id,vintage_id`, una fila por vintage declarado.
# Una publicacion tiene UN vintage, salvo las capturadas un archivo por año (hoy solo UT, ver
# PUBLICACIONES_POR_ANIO), que traen uno por año de cobertura. Se recomienda guardarlos en
# data/conjuntos/ (en .gitignore).
#
# COMO LO USA EL PIPELINE. `make master CONJUNTO=<ruta.csv> SALIDA=<dir>` exporta SIE_CONJUNTO y
# SIE_SALIDA; cada script de la cadena lee conjunto_activo() y escribe con ruta_capa(). Sin esas
# variables todo sigue exactamente como antes (L1/L2/L3 en data/).
#
# GUARDAS (todas con stop(), regla 7 de CLAUDE.md): validar_conjunto() corre ANTES de escribir
# nada (src/transformacion/validar_conjunto.R, primer paso de `make master`); ademas
# archivo_l0_vigente() reverifica el sha256 de cada archivo en el momento de usarlo, de modo que
# un extractor corrido solo tambien quede protegido.

source(here::here("src", "transformacion", "vintage_lib.R"))

# Publicaciones capturadas UN ARCHIVO POR AÑO: unicas que pueden traer varios vintages en un
# conjunto (uno por año). Debe coincidir con PUBLICACION_UT de ut_demanda_lib.R (lo comprueba
# tests/test-conjunto.R).
PUBLICACIONES_POR_ANIO <- "UT.DEMANDA_TOTAL_MENSUAL"

# Capas vigentes bajo data/: ninguna puede ser (ni contener) la SALIDA de un conjunto.
CAPAS_VIGENTES <- c("L0_raw", "L1_staging", "L2_validated", "L3_master", "L4_experiments")

#' Lee un conjunto de vintages (CSV `publicacion_id,vintage_id`). Falla visible si faltan
#' columnas, si hay celdas vacias, filas duplicadas o si no declara ninguna fila.
leer_conjunto <- function(ruta) {
  if (!file.exists(ruta)) {
    stop("FALLO VISIBLE: no existe el archivo de conjunto de vintages: ", ruta)
  }
  conjunto <- read.csv(ruta, stringsAsFactors = FALSE, colClasses = "character", na.strings = "")
  if (!identical(names(conjunto), c("publicacion_id", "vintage_id"))) {
    stop("FALLO VISIBLE: ", ruta, " debe tener exactamente las columnas publicacion_id,vintage_id ",
         "(en ese orden); trae: ", paste(names(conjunto), collapse = ","))
  }
  if (nrow(conjunto) == 0) stop("FALLO VISIBLE: ", ruta, " no declara ningun vintage.")
  if (anyNA(conjunto)) stop("FALLO VISIBLE: ", ruta, " tiene celdas vacias.")
  conjunto$publicacion_id <- trimws(conjunto$publicacion_id)
  conjunto$vintage_id <- trimws(conjunto$vintage_id)
  if (anyDuplicated(conjunto) > 0) {
    stop("FALLO VISIBLE: ", ruta, " tiene filas duplicadas: ",
         paste(conjunto$vintage_id[duplicated(conjunto)], collapse = ", "))
  }
  conjunto
}

#' Publicaciones que el pipeline necesita: todas las publicacion_id de catalogos/03_series.csv.
#' (Decision de interfaz, no metodologica: tests/test-conjunto.R comprueba que cada una aparece en
#' algun extractor, y archivo_l0_vigente() falla al usarse si alguna falta.) Pura.
publicaciones_necesarias <- function(catalogo_series) {
  sort(unique(catalogo_series$publicacion_id))
}

#' Valida un conjunto contra los catalogos y L0. Falla visible (stop) si:
#'  - un vintage_id no existe en 08_vintages.csv o no pertenece a su publicacion_id;
#'  - una publicacion que no es de PUBLICACIONES_POR_ANIO trae mas de un vintage, o una que si lo
#'    es trae dos del mismo año;
#'  - su archivo no esta en L0 o su sha256 crudo difiere del manifiesto (verificar_sha256_l0());
#'  - alguna publicacion de `necesarias` queda sin vintage.
#' Las publicaciones sobrantes (no necesarias) se permiten -un conjunto generado sobre toda L0
#' sirve- pero sus vintages cumplen las mismas guardas; se devuelven en `sobrantes` para
#' informarlas. Devuelve invisible(list(necesarias, sobrantes)).
validar_conjunto <- function(conjunto, vintages, manifiesto, dir_l0, necesarias) {
  fila <- match(conjunto$vintage_id, vintages$vintage_id)
  if (anyNA(fila)) {
    stop("FALLO VISIBLE: vintage(s) del conjunto que no existen en catalogos/08_vintages.csv: ",
         paste(conjunto$vintage_id[is.na(fila)], collapse = ", "))
  }
  ajeno <- vintages$publicacion_id[fila] != conjunto$publicacion_id
  if (any(ajeno)) {
    stop("FALLO VISIBLE: vintage(s) del conjunto que no pertenecen a la publicacion declarada: ",
         paste0(conjunto$vintage_id[ajeno], " (catalogo: ", vintages$publicacion_id[fila][ajeno],
                "; conjunto: ", conjunto$publicacion_id[ajeno], ")", collapse = "; "))
  }
  por_pub <- split(conjunto$vintage_id, conjunto$publicacion_id)
  for (pub in names(por_pub)) {
    ids <- por_pub[[pub]]
    if (length(ids) == 1) next
    if (!pub %in% PUBLICACIONES_POR_ANIO) {
      stop("FALLO VISIBLE: el conjunto declara ", length(ids), " vintages para '", pub,
           "' (", paste(ids, collapse = ", "), "); solo las publicaciones por año (",
           paste(PUBLICACIONES_POR_ANIO, collapse = ", "), ") admiten varios.")
    }
    mapa_vintage_por_anio(pub, vintages, conjunto)  # stop() si dos vintages caen en el mismo año
  }
  for (vid in conjunto$vintage_id) verificar_sha256_l0(vid, vintages, dir_l0, manifiesto)
  faltan <- setdiff(necesarias, conjunto$publicacion_id)
  if (length(faltan) > 0) {
    stop("FALLO VISIBLE: el conjunto no declara vintage para publicacion(es) que el pipeline ",
         "necesita: ", paste(faltan, collapse = ", "), ".")
  }
  invisible(list(necesarias = necesarias,
                 sobrantes = sort(setdiff(unique(conjunto$publicacion_id), necesarias))))
}

#' Conjunto activo del proceso: el de SIE_CONJUNTO, o NULL si no esta definida (= pipeline
#' vigente de siempre). SIE_CONJUNTO y SIE_SALIDA se exigen juntas (ruta_capa()).
conjunto_activo <- function() {
  ruta <- Sys.getenv("SIE_CONJUNTO", "")
  if (!nzchar(ruta)) {
    if (nzchar(Sys.getenv("SIE_SALIDA", ""))) salida_sin_conjunto()
    return(NULL)
  }
  if (!nzchar(Sys.getenv("SIE_SALIDA", ""))) conjunto_sin_salida()
  leer_conjunto(ruta)
}
salida_sin_conjunto <- function() {
  stop("FALLO VISIBLE: SIE_SALIDA (SALIDA=) esta definida sin SIE_CONJUNTO (CONJUNTO=); se ",
       "exigen juntas.")
}
conjunto_sin_salida <- function() {
  stop("FALLO VISIBLE: SIE_CONJUNTO (CONJUNTO=) esta definida sin SIE_SALIDA (SALIDA=); se ",
       "exigen juntas: un conjunto nunca escribe sobre la L1/L3 vigente.")
}

#' Valida un directorio de SALIDA: ni es una capa vigente de data/ ni cae dentro de una, ni es
#' data/ mismo (SALIDA/L1_staging seria la L1 vigente). `raiz` es la raiz del repo. Devuelve la
#' ruta normalizada.
validar_salida <- function(salida, raiz = here::here()) {
  s <- tolower(normalizePath(salida, winslash = "/", mustWork = FALSE))
  datos <- tolower(normalizePath(file.path(raiz, "data"), winslash = "/", mustWork = FALSE))
  capas <- file.path(datos, tolower(CAPAS_VIGENTES))
  es_capa_o_dentro <- any(s == capas | startsWith(s, paste0(capas, "/")))
  if (s == datos || es_capa_o_dentro) {
    stop("FALLO VISIBLE: SALIDA '", salida, "' cae en una capa vigente de data/ (o es data/ ",
         "mismo); un conjunto escribe en su propio directorio (p. ej. data/conjuntos/<nombre>/), ",
         "nunca sobre L0/L1/L2/L3/L4 vigentes.")
  }
  normalizePath(salida, winslash = "/", mustWork = FALSE)
}

#' Ruta de una capa generada (`capa` = "L1_staging", "L2_validated" o "L3_master"): data/<capa>
#' por defecto; <SALIDA>/<capa> con conjunto activo. Los `...` son el resto de la ruta. Con
#' SIE_CONJUNTO/SIE_SALIDA a medias o con una SALIDA que cae en una capa vigente, falla visible.
ruta_capa <- function(capa, ...) {
  salida <- Sys.getenv("SIE_SALIDA", "")
  conjunto <- Sys.getenv("SIE_CONJUNTO", "")
  if (!nzchar(salida)) {
    if (nzchar(conjunto)) conjunto_sin_salida()
    return(here::here("data", capa, ...))
  }
  if (!nzchar(conjunto)) salida_sin_conjunto()
  file.path(validar_salida(salida), capa, ...)
}
