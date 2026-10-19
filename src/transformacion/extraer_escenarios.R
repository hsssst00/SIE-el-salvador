# L0 -> L1 de las variables de escenario de Fase 6 (F6-18 de doc/metodologia/decisiones_fase6.md;
# checklist C3). Catalogo-dirigido: lee las filas de catalogos/03_series.csv de las publicaciones de
# escenario (publicaciones_de_escenario() de conjunto_lib.R: las que solo alimentan series maestras
# de rol `escenario`) y escribe data/L1_staging/ESCENARIOS_series_largo.csv (serie_id, periodo,
# valor), con periodo AAAA-Qn, AAAA-Mnn o AAAA segun la frecuencia de la fila.
#
# Publicaciones y formato de su vintage en L0:
#   - FRED.BEA_PIB_EEUU y FRED.CPIAUCSL: JSON de la API de FRED (observations[].date, .value; el
#     valor "." es dato ausente y queda vacio). La clave que cita fuente_celda (`clave "GDPC1"`) se
#     exige en la url del manifiesto (series_id=...), porque el JSON de FRED no la repite.
#   - FMI.PCPS.POILAPSP_USD y FMI.WEO: JSON SDMX 3.0 de la API del FMI. La clave que cita
#     fuente_celda (`clave "USA.NGDP_RPCH.A"`) se busca entre las series del archivo.
#   - FMI.WEO.CAPITULO1: libro .xlsx de figuras. hoja, fila_dato, col_inicio, col_fin y fila_anios
#     salen de 03_series.csv; el rotulo de la fila (`("Scenario C")`) se exige en la columna
#     anterior a col_inicio, cada `panel "..."` de fuente_celda en esa misma columna por encima de
#     fila_anios, y los años de fila_anios deben ser inicio..fin de la fila (la hoja escribe 2026 y
#     luego 27, 28, ...).
#
# Con un conjunto de vintages (make master CONJUNTO=... SALIDA=...) la etapa corre solo si el
# conjunto declara todas las publicaciones de escenario; un corte anterior a Fase 6 (corte_fase5.csv)
# no declara ninguna y la etapa se salta (etapa_escenario_activa(), F6-18-d). Falla con stop()
# ante cualquier cambio de estructura (reglas 6 y 7 de CLAUDE.md).

source(here::here("src", "transformacion", "conjunto_lib.R"))

series_catalogo <- read.csv(here::here("catalogos", "03_series.csv"), stringsAsFactors = FALSE, na.strings = "")
master_catalogo <- read.csv(here::here("catalogos", "05_series_master.csv"), stringsAsFactors = FALSE, na.strings = "")
vintages <- leer_vintages()
conjunto <- conjunto_activo()

PUBLICACIONES_ESCENARIO <- publicaciones_de_escenario(series_catalogo, master_catalogo)
if (length(PUBLICACIONES_ESCENARIO) == 0) {
  stop("FALLO VISIBLE: ninguna publicacion de catalogos/03_series.csv alimenta solo series de rol ",
       "'escenario' en 05_series_master.csv; extraer_escenarios.R no tiene nada que leer.")
}
if (!etapa_escenario_activa(conjunto, PUBLICACIONES_ESCENARIO)) {
  cat("Etapa de escenario omitida: el conjunto no declara ninguna publicacion de escenario (",
      paste(PUBLICACIONES_ESCENARIO, collapse = ", "), "); es un corte anterior a Fase 6.\n", sep = "")
  quit(status = 0)
}

# Las cinco publicaciones con lector propio. Una publicacion de escenario nueva sin lector es stop().
LECTOR <- c("FRED.BEA_PIB_EEUU" = "fred", "FRED.CPIAUCSL" = "fred", "FMI.PCPS.POILAPSP_USD" = "sdmx",
            "FMI.WEO" = "sdmx", "FMI.WEO.CAPITULO1" = "xlsx_capitulo1")
sin_lector <- setdiff(PUBLICACIONES_ESCENARIO, names(LECTOR))
if (length(sin_lector) > 0) {
  stop("FALLO VISIBLE: publicacion(es) de escenario sin lector en extraer_escenarios.R: ",
       paste(sin_lector, collapse = ", "))
}

series <- series_catalogo[series_catalogo$publicacion_id %in% PUBLICACIONES_ESCENARIO, ]
manifiesto <- leer_manifiesto(here::here("data", "L0_raw"))

.clave <- function(fila) {
  m <- regmatches(fila$fuente_celda, regexec('clave "([^"]+)"', fila$fuente_celda))[[1]]
  if (length(m) != 2) stop("FALLO VISIBLE [", fila$serie_id, "]: fuente_celda no cita `clave \"...\"`.")
  m[2]
}

.periodo_desde_fecha <- function(fecha, freq, serie_id) {
  if (!all(grepl("^[0-9]{4}-[0-9]{2}-01$", fecha))) stop("FALLO VISIBLE [", serie_id, "]: fecha de FRED mal formada.")
  anio <- as.integer(substr(fecha, 1, 4)); mes <- as.integer(substr(fecha, 6, 7))
  if (freq == "M") return(sprintf("%d-M%02d", anio, mes))
  if (freq == "Q") {
    if (!all(mes %in% c(1L, 4L, 7L, 10L))) stop("FALLO VISIBLE [", serie_id, "]: fecha trimestral de FRED que no abre trimestre.")
    return(sprintf("%d-Q%d", anio, (mes - 1L) %/% 3L + 1L))
  }
  stop("FALLO VISIBLE [", serie_id, "]: frecuencia '", freq, "' no soportada para FRED.")
}

leer_fred <- function(fila, path, vintage_id) {
  clave <- .clave(fila)
  url <- manifiesto$url[manifiesto$vintage_id == vintage_id]
  if (length(url) != 1 || !grepl(paste0("series_id=", clave, "(&|$)"), url)) {
    stop("FALLO VISIBLE [", fila$serie_id, "]: la url del manifiesto para ", vintage_id,
         " no pide series_id=", clave, " (url: ", paste(url, collapse = " | "), ").")
  }
  j <- jsonlite::fromJSON(path, simplifyVector = TRUE)
  obs <- j$observations
  if (!is.data.frame(obs) || !all(c("date", "value") %in% names(obs)) || nrow(obs) == 0) {
    stop("FALLO VISIBLE [", fila$serie_id, "]: el JSON de FRED no trae observations con date y value: ", path)
  }
  valor <- ifelse(obs$value == ".", NA_character_, obs$value)
  num <- suppressWarnings(as.numeric(valor))
  if (any(is.na(num) & !is.na(valor))) stop("FALLO VISIBLE [", fila$serie_id, "]: valor no numerico en FRED.")
  data.frame(serie_id = fila$serie_id, periodo = .periodo_desde_fecha(obs$date, fila$freq, fila$serie_id),
             valor = num, stringsAsFactors = FALSE)
}

cache_sdmx <- new.env(parent = emptyenv())
.tabla_sdmx <- function(path) {
  if (exists(path, envir = cache_sdmx, inherits = FALSE)) return(get(path, envir = cache_sdmx))
  j <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  st <- j$data$structures[[1]]
  dims <- st$dimensions$series
  tiempo <- st$dimensions$observation
  if (is.null(dims) || length(tiempo) != 1 || tiempo[[1]]$id != "TIME_PERIOD") {
    stop("FALLO VISIBLE: el JSON SDMX no tiene la estructura esperada (dimensiones de serie y TIME_PERIOD): ", path)
  }
  tp <- vapply(tiempo[[1]]$values, function(v) v$value, character(1))
  ds <- j$data$dataSets[[1]]$series
  filas <- lapply(names(ds), function(k) {
    ix <- as.integer(strsplit(k, ":", fixed = TRUE)[[1]]) + 1L
    clave <- paste(vapply(seq_along(ix), function(d) dims[[d]]$values[[ix[d]]]$id, character(1)), collapse = ".")
    obs <- ds[[k]]$observations
    val <- vapply(obs, function(o) if (length(o) >= 1 && !is.null(o[[1]])) as.character(o[[1]]) else NA_character_, character(1))
    data.frame(clave = clave, periodo = tp[as.integer(names(obs)) + 1L], valor_txt = val, stringsAsFactors = FALSE)
  })
  tabla <- do.call(rbind, filas)
  assign(path, tabla, envir = cache_sdmx)
  tabla
}

leer_sdmx <- function(fila, path, vintage_id) {
  clave <- .clave(fila)
  tabla <- .tabla_sdmx(path)
  t <- tabla[tabla$clave == clave, ]
  if (nrow(t) == 0) stop("FALLO VISIBLE [", fila$serie_id, "]: la clave ", clave, " no esta en ", path)
  t <- t[!is.na(t$valor_txt) & nzchar(t$valor_txt), ]
  num <- suppressWarnings(as.numeric(t$valor_txt))
  if (anyNA(num)) stop("FALLO VISIBLE [", fila$serie_id, "]: valor no numerico en la clave ", clave)
  patron <- switch(fila$freq, A = "^[0-9]{4}$", M = "^[0-9]{4}-M(0[1-9]|1[0-2])$", Q = "^[0-9]{4}-Q[1-4]$")
  if (is.null(patron) || !all(grepl(patron, t$periodo))) {
    stop("FALLO VISIBLE [", fila$serie_id, "]: TIME_PERIOD no corresponde a la frecuencia ", fila$freq, " de la fila.")
  }
  out <- data.frame(serie_id = fila$serie_id, periodo = t$periodo, valor = num, stringsAsFactors = FALSE)
  out[order(out$periodo), ]
}

.col_a_num <- function(letras) {
  v <- utf8ToInt(toupper(letras)) - 64L
  if (any(v < 1L | v > 26L)) stop("FALLO VISIBLE: columna de Excel mal formada: ", letras)
  sum(v * 26L^(rev(seq_along(v)) - 1L))
}
.texto <- function(x) if (is.na(x)) "" else trimws(as.character(x))

leer_capitulo1 <- function(fila, path, vintage_id) {
  hoja <- fila$hoja; f_dato <- as.integer(fila$fila_dato); f_anios <- as.integer(fila$fila_anios)
  ci <- .col_a_num(fila$col_inicio); cf <- .col_a_num(fila$col_fin)
  if (anyNA(c(f_dato, f_anios)) || ci < 2L || cf < ci) stop("FALLO VISIBLE [", fila$serie_id, "]: hoja/fila/columnas mal declaradas.")
  if (!hoja %in% readxl::excel_sheets(path)) stop("FALLO VISIBLE [", fila$serie_id, "]: no existe la hoja '", hoja, "' en ", path)
  raw <- readxl::read_excel(path, sheet = hoja, col_names = FALSE, .name_repair = "minimal")
  if (nrow(raw) < f_dato || ncol(raw) < cf) stop("FALLO VISIBLE [", fila$serie_id, "]: la hoja '", hoja, "' es mas chica que lo declarado.")
  rot <- regmatches(fila$fuente_celda, regexec('fila [0-9]+ \\("([^"]+)"\\)', fila$fuente_celda))[[1]]
  if (length(rot) != 2) stop("FALLO VISIBLE [", fila$serie_id, "]: fuente_celda no cita el rotulo de la fila.")
  if (.texto(raw[[ci - 1L]][f_dato]) != rot[2]) {
    stop("FALLO VISIBLE [", fila$serie_id, "]: en la hoja '", hoja, "', fila ", f_dato, ", la columna anterior a ",
         fila$col_inicio, " dice '", .texto(raw[[ci - 1L]][f_dato]), "' y se esperaba '", rot[2], "'.")
  }
  paneles <- regmatches(fila$fuente_celda, gregexpr('panel "[^"]+"', fila$fuente_celda))[[1]]
  paneles <- sub('^panel "([^"]+)"$', "\\1", paneles)
  if (length(paneles) == 0) stop("FALLO VISIBLE [", fila$serie_id, "]: fuente_celda no cita ningun `panel \"...\"`.")
  arriba <- vapply(raw[[ci - 1L]][seq_len(f_anios - 1L)], .texto, character(1))
  falta <- setdiff(paneles, arriba)
  if (length(falta) > 0) {
    stop("FALLO VISIBLE [", fila$serie_id, "]: la columna anterior a ", fila$col_inicio, " de la hoja '", hoja,
         "' no tiene, por encima de la fila ", f_anios, ", el/los rotulo(s) de panel: ", paste(falta, collapse = ", "))
  }
  anios_txt <- vapply(ci:cf, function(k) .texto(raw[[k]][f_anios]), character(1))
  anios <- suppressWarnings(as.integer(anios_txt))
  if (anyNA(anios)) stop("FALLO VISIBLE [", fila$serie_id, "]: años no numericos en la fila ", f_anios, ": ", paste(anios_txt, collapse = ", "))
  anios <- ifelse(anios < 100L, 2000L + anios, anios)
  esperados <- seq(as.integer(fila$inicio), as.integer(fila$fin))
  if (!identical(anios, esperados)) {
    stop("FALLO VISIBLE [", fila$serie_id, "]: los años de la fila ", f_anios, " (", paste(anios, collapse = ", "),
         ") no son inicio..fin de 03_series.csv (", fila$inicio, "..", fila$fin, ").")
  }
  # Sin pasar por texto cuando readxl ya leyo la columna como numero: as.character() redondea a 15
  # cifras y el valor tiene que ser el double de la celda.
  vals <- vapply(ci:cf, function(k) {
    v <- raw[[k]][f_dato]
    if (is.numeric(v)) as.numeric(v) else suppressWarnings(as.numeric(.texto(v)))
  }, numeric(1))
  vals_txt <- vapply(ci:cf, function(k) .texto(raw[[k]][f_dato]), character(1))
  if (anyNA(vals)) stop("FALLO VISIBLE [", fila$serie_id, "]: celda vacia o no numerica en la fila ", f_dato, ": ", paste(vals_txt, collapse = ", "))
  data.frame(serie_id = fila$serie_id, periodo = as.character(anios), valor = vals, stringsAsFactors = FALSE)
}

LECTORES <- list(fred = leer_fred, sdmx = leer_sdmx, xlsx_capitulo1 = leer_capitulo1)

resultados <- vector("list", nrow(series))
for (i in seq_len(nrow(series))) {
  fila <- series[i, ]
  vid <- vintage_vigente(fila$publicacion_id, vintages, conjunto)
  path <- archivo_l0_vigente(fila$publicacion_id, conjunto, vintages)
  if (!file.exists(path)) stop("FALLO VISIBLE: archivo L0 ausente para ", fila$serie_id, ": ", path)
  resultados[[i]] <- LECTORES[[LECTOR[[fila$publicacion_id]]]](fila, path, vid)
  r <- resultados[[i]]
  if (nrow(r) == 0) stop("FALLO VISIBLE [", fila$serie_id, "]: la lectura no produjo filas.")
  if (anyDuplicated(r$periodo)) stop("FALLO VISIBLE [", fila$serie_id, "]: periodos repetidos.")
  primero <- min(r$periodo[!is.na(r$valor)])
  if (!identical(primero, fila$inicio)) {
    stop("FALLO VISIBLE [", fila$serie_id, "]: el primer periodo con dato es ", primero, " y 03_series.csv declara inicio ", fila$inicio, ".")
  }
  cat(sprintf("OK: %s (%d obs, %s a %s, %d sin dato) <- %s\n", fila$serie_id, nrow(r), min(r$periodo), max(r$periodo),
              sum(is.na(r$valor)), basename(path)))
}

largo <- do.call(rbind, resultados)
if (length(unique(largo$serie_id)) != nrow(series)) {
  stop("FALLO VISIBLE: se esperaban ", nrow(series), " series y se obtuvieron ", length(unique(largo$serie_id)), ".")
}
largo <- largo[order(largo$serie_id, largo$periodo), ]
dir.create(ruta_capa("L1_staging"), showWarnings = FALSE, recursive = TRUE)
archivo <- ruta_capa("L1_staging", "ESCENARIOS_series_largo.csv")
write.csv(largo, archivo, row.names = FALSE, na = "")
cat("OK:", nrow(largo), "observaciones,", length(unique(largo$serie_id)), "series ->", archivo, "\n")
