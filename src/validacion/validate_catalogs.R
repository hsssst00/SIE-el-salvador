# Valida cada catálogo CSV en catalogos/ contra su esquema declarado en datapackage.json.
# Debe FALLAR (stop con exit non-zero), no advertir, ante cualquier incumplimiento —
# conforme al principio de §3.5 de la senda metodológica.

library(jsonlite)
library(pointblank)
library(dplyr)

dp <- fromJSON("catalogos/datapackage.json", simplifyVector = FALSE)

errores <- list()

for (r in dp$resources) {
  ruta <- file.path("catalogos", r$path)
  cat_name <- r$name

  if (!file.exists(ruta)) {
    errores[[cat_name]] <- paste("Archivo ausente:", ruta)
    next
  }

  df <- read.csv(ruta, stringsAsFactors = FALSE, na.strings = "")
  schema <- r$schema$fields

  # Validar cada campo del esquema
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

    col <- df[[fname]]

    # Cheque 2: Validar restricción "required"
    if (isTRUE(constraints$required)) {
      missing_count <- sum(is.na(col) | col == "")
      if (missing_count > 0) {
        cat_errors <- errores[[cat_name]] %||% character(0)
        errores[[cat_name]] <- c(cat_errors,
          paste0(fname, ": ", missing_count, " valor(es) ausente(s) pero required=true"))
      }
    }

    # Cheque 3: Validar restricción "unique"
    if (isTRUE(constraints$unique)) {
      non_na <- col[!is.na(col) & col != ""]
      dup_count <- sum(duplicated(non_na))
      if (dup_count > 0) {
        cat_errors <- errores[[cat_name]] %||% character(0)
        errores[[cat_name]] <- c(cat_errors,
          paste0(fname, ": ", dup_count, " valor(es) duplicado(s) pero unique=true"))
      }
    }

    # Cheque 4: Validar restricción "enum"
    if (!is.null(constraints$enum) && length(constraints$enum) > 0) {
      non_na <- col[!is.na(col) & col != ""]
      invalid <- non_na[!non_na %in% unlist(constraints$enum)]
      if (length(invalid) > 0) {
        cat_errors <- errores[[cat_name]] %||% character(0)
        invalid_unique <- unique(invalid)
        errores[[cat_name]] <- c(cat_errors,
          paste0(fname, ": valor(es) inválido(s) ",
                paste(sQuote(invalid_unique), collapse=", "),
                " (enum: ", paste(sQuote(unlist(constraints$enum)), collapse=", "), ")"))
      }
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
