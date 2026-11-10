# inventario_cepalstat.R
#
# Inventario de indicadores de CEPALSTAT con datos para El Salvador, limitado a los temas
# macroeconómicos del SIE. Decisión de Harold, 2026-11-10: el inventario vive en
# doc/inventario_cepalstat/, FUERA de catalogos/. ADR-008 (enmienda del 2026-10-19) impide
# que una serie de CEPAL entre a 03_series.csv mientras siga abierta la cuestión de obras
# derivadas de la cláusula 4; esta lista no admite ninguna serie, solo dice qué hay.
#
# Qué hace:
#   1. Pide el árbol temático (thematic-tree) una vez y lo aplana.
#   2. Se queda con los indicadores de las ramas de TEMAS_INCLUIDOS.
#   3. Por cada indicador pide los datos filtrados a El Salvador y resume cobertura,
#      frecuencia, dimensiones adicionales, fuentes y última actualización.
#   4. Escribe doc/inventario_cepalstat/indicadores.csv.
#
# Qué NO hace: no guarda las respuestas crudas (ni en L0 ni en otro lugar), no toca
# catalogos/ ni el manifiesto de L0. Para cada respuesta registra el sha256 del `body`
# (el `header` lleva timestamp y máquina, y cambia en cada llamada).
#
# El filtro por país: la dimensión de país NO es la misma en todos los indicadores. La
# estándar (id 208) tiene a El Salvador como miembro 230, pero p. ej. las cuentas
# nacionales trimestrales usan otra dimensión con un miembro por año base ("El Salvador
# [año base 1990]", "[año base 2005]", ...). Por eso: primera llamada con members=230; si
# vuelve sin filas, se buscan los miembros "El Salvador*" en la dimensión de país de esa
# misma respuesta y, si hay, se hace una segunda llamada con esos ids. Que esa segunda
# llamada vuelva vacía es un resultado, no un error del filtro: verificado el 2026-11-10 con
# el indicador 286 (PIB trimestral), donde el mismo filtro por "Costa Rica [año base 1991]"
# devuelve 719 filas y por los tres miembros de El Salvador devuelve 0.
#
# Regla 9 de CLAUDE.md: una pasada, con PAUSA_S segundos entre llamadas. No es un proceso
# recurrente; se vuelve a correr solo si se quiere refrescar el inventario.
#
# Uso: Rscript scripts/inventario_cepalstat.R [n_max | ids=365,1819]
#   n_max (opcional): limita el número de indicadores, para probar.
#   ids=  (opcional): consulta solo esos indicadores (deben estar en los temas incluidos) y
#         reemplaza sus filas en el CSV existente, conservando las demás.
#   n_max sobrescribe el CSV entero: es solo para probar.

library(httr2)
library(jsonlite)
library(digest)

BASE <- "https://api-cepalstat.cepal.org/cepalstat/api/v1"
USER_AGENT <- "SIE-el-salvador (investigacion academica, inventario de metadatos)"
PAUSA_S <- 2
MIEMBRO_SLV_ESTANDAR <- 230L
# La API corta en 10 000 filas sin avisar (verificado 2026-11-10 con el indicador 286 sin
# filtro de país). Una respuesta que llega al tope se marca como truncada.
TOPE_FILAS_API <- 10000L
TEMAS_INCLUIDOS <- c(
  "^Económicos > ",
  "^Temas transversales > Estadísticas de los Subsectores Eléctrico y de Hidrocarburos"
)
SALIDA <- "doc/inventario_cepalstat/indicadores.csv"

args <- commandArgs(trailingOnly = TRUE)
ids_forzados <- NULL; n_max <- NA_integer_
if (length(args) >= 1) {
  if (startsWith(args[1], "ids=")) {
    ids_forzados <- as.integer(strsplit(sub("^ids=", "", args[1]), ",")[[1]])
  } else {
    n_max <- as.integer(args[1])
  }
}

# --- HTTP ---------------------------------------------------------------------------

pedir <- function(ruta, query = list()) {
  req <- request(BASE) |>
    req_url_path_append(ruta) |>
    req_url_query(!!!query, lang = "es", format = "json") |>
    req_user_agent(USER_AGENT) |>
    req_retry(max_tries = 3, backoff = function(i) 5 * i) |>
    req_error(is_error = function(resp) FALSE)
  resp <- req_perform(req)
  Sys.sleep(PAUSA_S)
  codigo <- resp_status(resp)
  tipo <- resp_content_type(resp)
  cuerpo <- NULL
  if (codigo == 200) {
    # La nota de 00_instituciones.csv registra que un cliente recibió .xlsx con
    # format=json: se verifica el Content-Type en cada respuesta, no se asume.
    if (!identical(tipo, "application/json")) {
      stop("FALLO VISIBLE: ", req$url, " devolvió Content-Type '", tipo, "', no JSON.")
    }
    json <- fromJSON(resp_body_string(resp, encoding = "UTF-8"), simplifyVector = FALSE)
    if (!isTRUE(json$header$success) || is.null(json$body)) {
      stop("FALLO VISIBLE: ", req$url, " respondió 200 sin header$success o sin body.")
    }
    cuerpo <- json$body
  }
  list(url = req$url, codigo = codigo, body = cuerpo,
       sha256 = if (is.null(cuerpo)) NA_character_ else
         digest(toJSON(cuerpo, auto_unbox = TRUE, digits = NA, null = "null"),
                algo = "sha256", serialize = FALSE))
}

# --- Árbol temático -----------------------------------------------------------------

aplanar_arbol <- function(nodo) {
  filas <- list()
  recorrer <- function(n, ruta) {
    if (!is.null(n$indicator_id)) {
      filas[[length(filas) + 1]] <<- data.frame(
        indicator_id = as.integer(n$indicator_id),
        ruta_tematica = paste(ruta, collapse = " > "),
        stringsAsFactors = FALSE)
      return(invisible())
    }
    for (h in n$children) recorrer(h, c(ruta, n$name))
  }
  for (h in nodo$children) recorrer(h, character())
  if (length(filas) == 0) stop("FALLO VISIBLE: el árbol temático no tiene hojas con indicator_id.")
  do.call(rbind, filas)
}

# --- Resumen de un indicador --------------------------------------------------------

es_dim_pais <- function(nombre) grepl("^Pa[ií]s", nombre)
es_dim_anio <- function(nombre) grepl("^A[ñn]os", nombre)
es_dim_trim <- function(nombre) grepl("^Trimestre", nombre)
es_dim_mes  <- function(nombre) grepl("^Meses", nombre)
# Dimensión de período mixta (p. ej. "Periodo__ind mon" en los agregados monetarios): un
# mismo indicador trae filas "Anual", "Trimestre N" y meses por nombre.
es_dim_periodo <- function(nombre) grepl("^Per[ií]odo", nombre)
MESES <- c("Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto",
           "Septiembre", "Octubre", "Noviembre", "Diciembre")
ORDEN_FREQ <- c("M", "Q", "A")

miembros_slv <- function(body) {
  ids <- integer(); nombres <- character()
  for (d in body$dimensions) if (es_dim_pais(d$name)) for (m in d$members) {
    if (grepl("^El Salvador", m$name)) {
      ids <- c(ids, as.integer(m$id)); nombres <- c(nombres, m$name)
    }
  }
  list(ids = ids, nombres = nombres)
}

texto <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else
  trimws(gsub("[\r\n]+", " ", as.character(x[[1]])))

resumir <- function(body) {
  meta <- body$metadata
  dims <- body$dimensions
  datos <- body$data
  base <- list(nombre_indicador = texto(meta$indicator_name), area = texto(meta$area),
               unidad = texto(meta$unit), ultima_actualizacion = texto(meta$last_update))
  if (length(datos) == 0) {
    return(c(base, list(tiene_datos_slv = FALSE, freq = NA, inicio = NA, fin = NA, n_obs = 0L,
                        respuesta_truncada = FALSE, miembros_slv = NA,
                        dimensiones_adicionales = NA, n_series = 0L, fuentes_originales = NA,
                        advertencia = NA)))
  }
  # Fuentes originales: solo las que citan las filas de El Salvador (source_id), no todas
  # las que el indicador declara para la región.
  ids_fuente <- unique(vapply(datos, function(r) as.character(r$source_id %||% NA), ""))
  fuentes <- Filter(function(s) as.character(s$id) %in% ids_fuente, body$sources)
  fuentes_originales <- paste(unique(vapply(fuentes, function(s)
    sprintf("%s: %s", texto(s$organization_acronym), texto(s$description)), "")), collapse = " | ")
  if (!nzchar(fuentes_originales)) fuentes_originales <- NA_character_

  iso <- vapply(datos, function(r) texto(r$iso3), "")
  if (any(is.na(iso) | iso != "SLV")) {
    stop("FALLO VISIBLE: el filtro por país no se aplicó (iso3 distinto de SLV: ",
         paste(unique(iso[is.na(iso) | iso != "SLV"]), collapse = ", "), ").")
  }

  # Tabla de etiquetas por dimensión: id de miembro -> nombre, orden
  etiqueta <- list(); orden <- list(); nombre_dim <- character()
  for (d in dims) {
    k <- paste0("dim_", d$id)
    nombre_dim[k] <- d$name
    etiqueta[[k]] <- setNames(vapply(d$members, function(m) m$name, ""),
                              vapply(d$members, function(m) as.character(m$id), ""))
    orden[[k]] <- setNames(vapply(d$members, function(m) as.integer(m$order), 0L),
                           vapply(d$members, function(m) as.character(m$id), ""))
  }
  cols <- grep("^dim_", unique(unlist(lapply(datos, names))), value = TRUE)
  faltan <- setdiff(cols, names(nombre_dim))
  if (length(faltan)) stop("FALLO VISIBLE: columnas sin dimensión declarada: ", paste(faltan, collapse = ", "))
  val <- function(r, k) if (is.null(r[[k]])) NA_character_ else as.character(r[[k]])
  tabla <- as.data.frame(lapply(setNames(cols, cols), function(k) vapply(datos, val, "", k = k)),
                         stringsAsFactors = FALSE)

  k_pais <- cols[es_dim_pais(nombre_dim[cols])]
  k_anio <- cols[es_dim_anio(nombre_dim[cols])]
  k_trim <- cols[es_dim_trim(nombre_dim[cols])]
  k_mes  <- cols[es_dim_mes(nombre_dim[cols])]
  k_per  <- cols[es_dim_periodo(nombre_dim[cols])]
  k_otras <- setdiff(cols, c(k_pais, k_anio, k_trim, k_mes, k_per))
  avisos <- character()

  # Frecuencia y período ISO por fila.
  n <- nrow(tabla)
  f_fila <- rep(NA_character_, n); periodo <- rep(NA_character_, n)
  if (length(k_anio) == 1 && length(c(k_mes, k_trim, k_per)) <= 1) {
    anio <- unname(etiqueta[[k_anio]][tabla[[k_anio]]])
    if (length(k_mes) == 1) {
      # Por nombre del mes, no por `order`: el orden no es 1..12 en todos los indicadores
      # (en el 1901, TCRE, salía "2013-00" y "2025-90").
      et <- unname(etiqueta[[k_mes]][tabla[[k_mes]]])
      # "Promedio anual" dentro de Meses (visto en el 1901) es una fila anual.
      num <- match(et, MESES); es_a <- et == "Promedio anual"
      raras <- unique(et[is.na(num) & !es_a])
      if (length(raras)) avisos <- c(avisos, paste0("meses no reconocidos: ", paste(raras, collapse = ", ")))
      f_fila[!is.na(num)] <- "M"
      periodo[!is.na(num)] <- sprintf("%s-%02d", anio[!is.na(num)], num[!is.na(num)])
      f_fila[es_a] <- "A"; periodo[es_a] <- anio[es_a]
    } else if (length(k_trim) == 1) {
      f_fila[] <- "Q"
      periodo <- sprintf("%s-Q%s", anio, sub("^Trimestre\\s*", "", etiqueta[[k_trim]][tabla[[k_trim]]]))
    } else if (length(k_per) == 1) {
      et <- unname(etiqueta[[k_per]][tabla[[k_per]]])
      es_m <- et %in% MESES; es_q <- grepl("^Trimestre [1-4]$", et); es_a <- et == "Anual"
      f_fila[es_m] <- "M"; periodo[es_m] <- sprintf("%s-%02d", anio[es_m], match(et[es_m], MESES))
      f_fila[es_q] <- "Q"; periodo[es_q] <- sprintf("%s-Q%s", anio[es_q], sub("^Trimestre ", "", et[es_q]))
      f_fila[es_a] <- "A"; periodo[es_a] <- anio[es_a]
      raras <- unique(et[!(es_m | es_q | es_a)])
      if (length(raras)) avisos <- c(avisos, paste0("etiquetas de período no reconocidas: ",
                                                     paste(raras, collapse = ", ")))
    } else {
      f_fila[] <- "A"; periodo <- anio
    }
  } else {
    # Caso visto: "Año_decadas" (promedios por década, indicadores 3376-3379), sin años.
    avisos <- c(avisos, paste0("sin dimensión de años reconocible; dimensiones: ",
                               paste(nombre_dim[cols], collapse = ", ")))
  }
  freqs <- intersect(ORDEN_FREQ, unique(f_fila))
  # inicio/fin: los de la frecuencia más alta disponible (la primera de `freq`).
  p_alta <- if (length(freqs)) periodo[f_fila %in% freqs[1]] else character()

  # Una "serie" = combinación distinta de dimensiones no temporales (país incluido, por los
  # miembros por año base), por frecuencia.
  claves <- c(k_pais, k_otras)
  n_series <- nrow(unique(cbind(tabla[claves], f = f_fila)))
  slv_usados <- unique(etiqueta[[k_pais]][unique(tabla[[k_pais]])])
  adicionales <- if (length(k_otras)) paste(vapply(k_otras, function(k)
    sprintf("%s (%d)", nombre_dim[[k]], length(unique(tabla[[k]]))), ""), collapse = "; ") else NA
  truncada <- n >= TOPE_FILAS_API
  if (truncada) avisos <- c(avisos, sprintf("respuesta con %d filas: posible corte de la API", n))

  c(base, list(tiene_datos_slv = TRUE,
               freq = if (length(freqs)) paste(freqs, collapse = "; ") else NA,
               inicio = if (length(p_alta)) min(p_alta) else NA,
               fin = if (length(p_alta)) max(p_alta) else NA,
               n_obs = n, respuesta_truncada = truncada,
               miembros_slv = paste(slv_usados, collapse = "; "),
               dimensiones_adicionales = adicionales, n_series = as.integer(n_series),
               fuentes_originales = fuentes_originales,
               advertencia = if (length(avisos)) paste(avisos, collapse = "; ") else NA))
}

# --- Corrida ------------------------------------------------------------------------

fecha_consulta <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
message("Árbol temático...")
arbol <- pedir("thematic-tree")
if (arbol$codigo != 200) stop("FALLO VISIBLE: thematic-tree devolvió HTTP ", arbol$codigo)
hojas <- aplanar_arbol(arbol$body)
hojas <- hojas[Reduce(`|`, lapply(TEMAS_INCLUIDOS, grepl, x = hojas$ruta_tematica)), ]
rutas <- tapply(hojas$ruta_tematica, hojas$indicator_id,
                function(x) paste(sort(unique(x)), collapse = " | "))
ids <- sort(as.integer(names(rutas)))
if (!is.null(ids_forzados)) {
  fuera <- setdiff(ids_forzados, ids)
  if (length(fuera)) stop("Indicadores fuera de los temas incluidos: ", paste(fuera, collapse = ", "))
  ids <- ids_forzados
}
if (!is.na(n_max)) ids <- head(ids, n_max)
message(sprintf("%d hojas en los temas incluidos, %d indicadores distintos a consultar.",
                nrow(hojas), length(ids)))

filas <- vector("list", length(ids))
for (i in seq_along(ids)) {
  id <- ids[i]
  r <- pedir(file.path("indicator", id, "data"), list(members = MIEMBRO_SLV_ESTANDAR))
  if (r$codigo == 200 && length(r$body$data) == 0) {
    alt <- miembros_slv(r$body)
    alt$ids <- setdiff(alt$ids, MIEMBRO_SLV_ESTANDAR)
    if (length(alt$ids)) {
      r <- pedir(file.path("indicator", id, "data"), list(members = paste(alt$ids, collapse = ",")))
    }
  }
  res <- if (r$codigo == 200) resumir(r$body) else list(tiene_datos_slv = NA)
  filas[[i]] <- data.frame(
    indicator_id = id,
    ruta_tematica = rutas[[as.character(id)]],
    nombre_indicador = res$nombre_indicador %||% NA,
    area = res$area %||% NA,
    unidad = res$unidad %||% NA,
    tiene_datos_slv = res$tiene_datos_slv,
    freq = res$freq %||% NA,
    inicio = res$inicio %||% NA,
    fin = res$fin %||% NA,
    n_obs = res$n_obs %||% NA,
    respuesta_truncada = res$respuesta_truncada %||% NA,
    n_series = res$n_series %||% NA,
    miembros_slv = res$miembros_slv %||% NA,
    dimensiones_adicionales = res$dimensiones_adicionales %||% NA,
    fuentes_originales = res$fuentes_originales %||% NA,
    ultima_actualizacion = res$ultima_actualizacion %||% NA,
    advertencia = res$advertencia %||% NA,
    url_consulta = r$url,
    codigo_http = r$codigo,
    sha256_body = r$sha256,
    fecha_consulta = fecha_consulta,
    stringsAsFactors = FALSE)
  message(sprintf("[%d/%d] %d  HTTP %d  slv=%s  %s %s-%s", i, length(ids), id, r$codigo,
                  res$tiene_datos_slv, res$freq %||% "", res$inicio %||% "", res$fin %||% ""))
}
inv <- do.call(rbind, filas)
inv$ruta_tematica <- gsub("[\r\n]+", " ", inv$ruta_tematica)

dir.create(dirname(SALIDA), showWarnings = FALSE, recursive = TRUE)
if (!is.null(ids_forzados) && file.exists(SALIDA)) {
  # Modo actualización: reemplaza solo las filas de esos indicadores, conserva el resto.
  previo <- read.csv(SALIDA, colClasses = "character", encoding = "UTF-8", check.names = FALSE)
  if (!identical(names(previo), names(inv))) {
    stop("FALLO VISIBLE: las columnas de ", SALIDA, " no coinciden con las del script; ",
         "hace falta la corrida completa.")
  }
  inv_chr <- as.data.frame(lapply(inv, function(v) ifelse(is.na(v), "", as.character(v))),
                           stringsAsFactors = FALSE)
  inv_chr <- rbind(previo[!previo$indicator_id %in% as.character(inv$indicator_id), ], inv_chr)
  inv_chr <- inv_chr[order(as.integer(inv_chr$indicator_id)), ]
  write.csv(inv_chr, SALIDA, row.names = FALSE, na = "", fileEncoding = "UTF-8")
} else {
  write.csv(inv, SALIDA, row.names = FALSE, na = "", fileEncoding = "UTF-8")
}
message(sprintf("Escrito %s: %d indicadores, %d con datos de El Salvador. sha256 del árbol: %s",
                SALIDA, nrow(inv), sum(inv$tiene_datos_slv %in% TRUE), arbol$sha256))

con_aviso <- inv[!is.na(inv$advertencia), ]
if (nrow(con_aviso)) {
  message(nrow(con_aviso), " indicadores con advertencia (revisar a mano): ",
          paste(con_aviso$indicator_id, collapse = ", "))
}
errores <- inv[inv$codigo_http != 200, ]
if (nrow(errores)) {
  stop("FALLO VISIBLE: ", nrow(errores), " indicadores sin respuesta 200: ",
       paste(errores$indicator_id, collapse = ", "), ". El CSV se escribió con esas filas marcadas.")
}
