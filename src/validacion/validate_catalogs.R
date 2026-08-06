# Valida cada catálogo CSV en catalogos/ contra su esquema declarado en datapackage.json.
# Debe FALLAR (stop with non-zero exit), no advertir, ante cualquier incumplimiento —
# conforme al principio de §3.5 de la senda metodológica.
#
# Esqueleto de Fase 0 — implementación real es tarea de Fase 3.
# No usar esto todavía como validación real: solo confirma que el datapackage.json
# es JSON válido y que los CSV declarados existen.

library(jsonlite)

dp <- fromJSON("catalogos/datapackage.json", simplifyVector = FALSE)

faltantes <- character(0)
for (r in dp$resources) {
  ruta <- file.path("catalogos", r$path)
  if (!file.exists(ruta)) {
    faltantes <- c(faltantes, ruta)
  }
}

if (length(faltantes) > 0) {
  stop("Catálogos declarados en datapackage.json pero ausentes: ",
       paste(faltantes, collapse = ", "))
}

message("OK (chequeo mínimo): todos los catálogos declarados existen. ",
        "Validación de esquema con pointblank pendiente de Fase 3.")
