# Valida cada catálogo CSV en catalogos/ contra su esquema declarado en datapackage.json.
# Debe FALLAR (stop con exit non-zero), no advertir, ante cualquier incumplimiento —
# conforme al principio de §3.5 de la senda metodológica.
#
# Remediación del hallazgo I2 de la revisión independiente de Fase 3 (2026-09-17): el `type` de
# cada campo se leía y nunca se usaba (80 campos con tipo declarado en datapackage.json --
# 73 string, 4 integer, 2 date, 1 boolean -- ninguno se verificaba). Se agrega el check de tipo
# (Cheque 0) vía pointblank col_vals_regex(), sobre el valor crudo leído como texto (evita
# depender de la inferencia de tipos de read.csv, que es ambigua para "date" -- Frictionless lo
# declara como string ISO 8601, no hay clase Date nativa que inferir). required/enum también se
# migraron a pasos nativos de pointblank (col_vals_not_null/col_vals_in_set); unique se queda en
# R base porque su semántica -- ignorar vacíos, no contarlos como duplicado entre sí -- no es la
# de rows_distinct() sin más trabajo, y el resultado se registra igual como paso `specially()`
# del mismo agente para que el reporte quede unificado (mismo patrón que
# src/validacion/l2_serie_larga_reglas.R).
#
# Este archivo NO valida las foreignKeys de datapackage.json (03_series -> 01_publicaciones,
# 03_series -> 02_metodologias, etc.) -- 01_publicaciones/ y 02_metodologias/ son directorios de
# YAML por publicación, no un recurso tabular Frictionless, así que esas referencias no son
# resolubles por un validador genérico de esquema. Las cubre
# src/validacion/validar_integridad_catalogos.R (commit 705ac99, 2026-09-17), que corre justo
# después de este script en `make validate`.

library(jsonlite)
library(pointblank)

dp <- fromJSON(here::here("catalogos", "datapackage.json"), simplifyVector = FALSE)

errores <- list()

TIPO_REGEX <- list(
  integer = "^-?[0-9]+$",
  boolean = "^(true|false|TRUE|FALSE)$",
  date = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
  # "string": sin restricción de formato -- cualquier valor no vacío es válido.
)

for (r in dp$resources) {
  ruta <- here::here("catalogos", r$path)
  cat_name <- r$name

  if (!file.exists(ruta)) {
    errores[[cat_name]] <- paste("Archivo ausente:", ruta)
    next
  }

  # colClasses = "character": conserva el valor crudo del CSV para los checks de formato
  # (Cheque 0) y no depende de qué tipo infiera read.csv por columna.
  df <- read.csv(ruta, stringsAsFactors = FALSE, na.strings = "", colClasses = "character")
  schema <- r$schema$fields

  agente <- create_agent(tbl = df, label = cat_name)
  idx_pasos <- list()
  paso_i <- 0L
  registrar <- function(nombre, agente_nuevo) {
    paso_i <<- paso_i + 1L
    idx_pasos[[nombre]] <<- paso_i
    agente_nuevo
  }

  campos_presentes <- list()
  for (field in schema) {
    fname <- field$name
    ftype <- field$type
    constraints <- field$constraints %||% list()

    # Cheque 1: ¿existe el campo?
    if (!fname %in% names(df)) {
      cat_errors <- errores[[cat_name]] %||% character(0)
      errores[[cat_name]] <- c(cat_errors, paste("Campo faltante:", fname))
      next
    }
    campos_presentes[[fname]] <- list(ftype = ftype, constraints = constraints)

    # Cheque 0: tipo declarado (nuevo -- I2). Solo sobre valores no vacíos: un campo opcional
    # vacío no es un valor del tipo incorrecto, es un ausente (cubierto por Cheque 2 si aplica).
    regex_tipo <- TIPO_REGEX[[ftype]]
    if (!is.null(regex_tipo)) {
      agente <- registrar(paste0("tipo__", fname), agente |>
        col_vals_regex(columns = fname, regex = regex_tipo, na_pass = TRUE,
                        label = paste0("tipo (", ftype, "): ", fname)))
    }

    # Cheque 2: restricción "required"
    if (isTRUE(constraints$required)) {
      agente <- registrar(paste0("required__", fname), agente |>
        col_vals_not_null(columns = fname, label = paste0("required: ", fname)))
    }

    # Cheque 4: restricción "enum"
    if (!is.null(constraints$enum) && length(constraints$enum) > 0) {
      agente <- registrar(paste0("enum__", fname), agente |>
        col_vals_in_set(columns = fname, set = unlist(constraints$enum), na_pass = TRUE,
                         label = paste0("enum: ", fname)))
    }
  }

  agente <- interrogate(agente)
  reporte <- get_agent_report(agente, display_table = FALSE)
  extractos <- get_data_extracts(agente)
  fallo <- function(nombre) {
    fila <- reporte[reporte$i == idx_pasos[[nombre]], ]
    is.na(fila$f_pass) || fila$f_pass < 1
  }
  extracto <- function(nombre) extractos[[as.character(idx_pasos[[nombre]])]]

  for (fname in names(campos_presentes)) {
    info <- campos_presentes[[fname]]
    col <- df[[fname]]

    if (paste0("tipo__", fname) %in% names(idx_pasos) && fallo(paste0("tipo__", fname))) {
      ext <- extracto(paste0("tipo__", fname))
      cat_errors <- errores[[cat_name]] %||% character(0)
      errores[[cat_name]] <- c(cat_errors,
        paste0(fname, ": ", nrow(ext), " valor(es) no calzan con el tipo declarado (",
               info$ftype, ")"))
    }

    if (paste0("required__", fname) %in% names(idx_pasos) && fallo(paste0("required__", fname))) {
      ext <- extracto(paste0("required__", fname))
      cat_errors <- errores[[cat_name]] %||% character(0)
      errores[[cat_name]] <- c(cat_errors,
        paste0(fname, ": ", nrow(ext), " valor(es) ausente(s) pero required=true"))
    }

    # Cheque 3: "unique" -- ignora vacíos (un campo opcional vacío repetido no es una
    # violación de unicidad), semántica que rows_distinct() no da sin trabajo adicional.
    if (isTRUE(info$constraints$unique)) {
      non_na <- col[!is.na(col) & col != ""]
      dup_count <- sum(duplicated(non_na))
      if (dup_count > 0) {
        cat_errors <- errores[[cat_name]] %||% character(0)
        errores[[cat_name]] <- c(cat_errors,
          paste0(fname, ": ", dup_count, " valor(es) duplicado(s) pero unique=true"))
      }
    }

    if (paste0("enum__", fname) %in% names(idx_pasos) && fallo(paste0("enum__", fname))) {
      ext <- extracto(paste0("enum__", fname))
      invalid_unique <- unique(ext[[fname]])
      cat_errors <- errores[[cat_name]] %||% character(0)
      errores[[cat_name]] <- c(cat_errors,
        paste0(fname, ": valor(es) inválido(s) ",
              paste(sQuote(invalid_unique), collapse=", "),
              " (enum: ", paste(sQuote(unlist(info$constraints$enum)), collapse=", "), ")"))
    }
  }
}

# Reportar errores
if (length(errores) > 0) {
  cat("\n❌ VALIDACIÓN DE CATÁLOGOS FALLIDA:\n\n")
  for (cat_name in names(errores)) {
    cat(sprintf("  %s:\n", cat_name))
    for (err in errores[[cat_name]]) {
      cat(sprintf("    - %s\n", err))
    }
  }
  stop("Catálogos contienen errores de esquema.")
}

message("✓ Validación de catálogos OK: todos los esquemas cumplen datapackage.json.")
