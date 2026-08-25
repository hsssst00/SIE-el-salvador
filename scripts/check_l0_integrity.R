# scripts/check_l0_integrity.R
# Verificación de integridad de L0 - vía CRUZADA OFFLINE (Fase 2, Decisión 2 - 2026-08-25).
# Corre en CI (job check-l0-integrity) y en cualquier máquina: solo lee texto, no necesita
# los .xlsx (que están en .gitignore por ADR-008) ni acceso al portal.
#
# Verifica la consistencia interna del registro de L0:
#   (1) manifiesto.csv y 08_vintages.csv tienen sus columnas declaradas, en orden;
#   (2) no hay vintage_id duplicado en el manifiesto;
#   (3) cada vintage_id del manifiesto existe en 08_vintages y viceversa;
#   (4) sha256 y sha256_norm coinciden entre ambos para cada vintage_id.
# La verificación archivo-físico <-> checksum es responsabilidad de `make raw`
# (scripts/verificar_l0.R), que re-captura del portal en vivo - no de este script.
# Falla de forma visible (regla 6 de CLAUDE.md): stop() ante cualquier inconsistencia.

ruta_manifiesto <- "data/L0_raw/manifiesto.csv"
ruta_vintages   <- "catalogos/08_vintages.csv"

cols_manifiesto <- c("archivo", "fuente", "url", "fecha_descarga", "sha256", "sha256_norm",
                     "tamano_bytes", "codigo_http", "vintage_id", "publicacion_id")
cols_vintages   <- c("vintage_id", "publicacion_id", "fecha_publicacion",
                     "periodo_referencia_max", "documento_fuente", "archivo_raw",
                     "sha256", "sha256_norm", "alcance_revision", "notas")

fallar <- function(...) stop("FALLO VISIBLE [check-l0-integrity]: ", ..., call. = FALSE)

if (!file.exists(ruta_manifiesto)) fallar("no existe ", ruta_manifiesto)
if (!file.exists(ruta_vintages))   fallar("no existe ", ruta_vintages)

man <- read.csv(ruta_manifiesto, stringsAsFactors = FALSE, colClasses = "character")
vin <- read.csv(ruta_vintages,   stringsAsFactors = FALSE, colClasses = "character")

# (1) columnas exactas, en orden
if (!identical(colnames(man), cols_manifiesto)) {
  fallar("columnas de manifiesto.csv inesperadas. Esperado: ",
         paste(cols_manifiesto, collapse = ","), " | Obtenido: ",
         paste(colnames(man), collapse = ","))
}
if (!identical(colnames(vin), cols_vintages)) {
  fallar("columnas de 08_vintages.csv inesperadas. Esperado: ",
         paste(cols_vintages, collapse = ","), " | Obtenido: ",
         paste(colnames(vin), collapse = ","))
}

# (2) sin vintage_id duplicado en el manifiesto
dup <- unique(man$vintage_id[duplicated(man$vintage_id)])
if (length(dup) > 0) fallar("vintage_id duplicado en manifiesto: ", paste(dup, collapse = ", "))

# (3) correspondencia de conjuntos manifiesto <-> vintages
solo_man <- setdiff(man$vintage_id, vin$vintage_id)
solo_vin <- setdiff(vin$vintage_id, man$vintage_id)
if (length(solo_man) > 0)
  fallar("vintage_id en manifiesto sin fila en 08_vintages: ", paste(solo_man, collapse = ", "))
if (length(solo_vin) > 0)
  fallar("vintage_id en 08_vintages sin fila en manifiesto: ", paste(solo_vin, collapse = ", "))

# (4) checksums coinciden por vintage_id
for (vid in unique(man$vintage_id)) {
  m <- man[man$vintage_id == vid, ]
  v <- vin[vin$vintage_id == vid, ]
  if (nrow(v) != 1)
    fallar("vintage_id ", vid, " aparece ", nrow(v), " veces en 08_vintages (se esperaba 1)")
  if (!identical(m$sha256, v$sha256))
    fallar("sha256 no coincide para ", vid, " (manifiesto=", m$sha256, " vintages=", v$sha256, ")")
  if (!identical(m$sha256_norm, v$sha256_norm))
    fallar("sha256_norm no coincide para ", vid,
           " (manifiesto=", m$sha256_norm, " vintages=", v$sha256_norm, ")")
}

cat("OK check-l0-integrity: ", nrow(man),
    " vintage(s); manifiesto <-> 08_vintages consistentes ",
    "(columnas, correspondencia y checksums).\n", sep = "")
