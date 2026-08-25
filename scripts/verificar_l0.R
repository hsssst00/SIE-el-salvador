# scripts/verificar_l0.R
# Motor de `make raw` (Fase 2, Decisión 1b - 2026-08-25): VERIFICACIÓN, no captura.
# Re-captura en vivo cada publicación BCR automatizable de la familia vista-serie,
# recalcula sha256_norm y lo compara contra el manifiesto. NO agrega vintages: la
# captura de un vintage nuevo es un acto deliberado y fechado vía descargar_bcr_*()
# (ADR-007). Falla de forma visible (regla 6 de CLAUDE.md) si el portal difiere de L0.
#
# Cubre la rama de VERIFICACIÓN del criterio de cierre de Fase 2 (senda §4: "make raw
# reconstruye la capa L0 desde cero O verifica su integridad, sin pasos manuales").
# Objetivo LOCAL: usa navegador headless (chromote) contra el portal en vivo; NO corre
# en CI. La verificación cruzada offline que sí corre en CI vive en
# scripts/check_l0_integrity.R.
#
# La retropolada (BCR.PIB_T.SERIE_RETROPOLADA_1990_2005) queda EXCLUIDA: no es una serie
# del componente vista-serie sino un .xlsx estático de www.bcr.gob.sv/documental/, serie
# histórica cerrada (termina 2005-T4), captura manual (Regla 9 de CLAUDE.md). Su
# integridad se verifica por la vía cruzada offline (check_l0_integrity.R).

source("src/adquisicion/bcr_captura.R")      # bcr_capturar_xlsx, verificacion_xlsx
source("src/adquisicion/lib_adquisicion.R")  # calcular_sha256_norm, leer_manifiesto

# Publicaciones vista-serie con captura automatizada (una por descargar_bcr_*() en bcr.R).
.PUBLICACIONES_VERIFICAR <- c(
  "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA",
  "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_SA",
  "BCR.PIB_T.NOMINAL"
)
.FORMULA_BASE       <- "0"   # representación base; uniforme para las tres (ver bcr.R)
.RETROPOLADA_MANUAL <- "BCR.PIB_T.SERIE_RETROPOLADA_1990_2005"

manifiesto <- leer_manifiesto()

resultados <- data.frame(publicacion_id = character(), estado = character(),
                         stringsAsFactors = FALSE)

for (pid in .PUBLICACIONES_VERIFICAR) {
  filas <- manifiesto[manifiesto$publicacion_id == pid, ]
  if (nrow(filas) == 0) {
    stop("FALLO VISIBLE: no hay fila en el manifiesto para ", pid,
         ". verificar_l0.R espera al menos un vintage registrado por publicación.")
  }
  fila <- filas[nrow(filas), ]  # última captura registrada
  url  <- fila$url
  sha256_norm_esperado <- fila$sha256_norm

  message("== Verificando ", pid, " ==")
  cap <- bcr_capturar_xlsx(url, formula = .FORMULA_BASE)
  sha256_norm_obtenido <- calcular_sha256_norm(cap$bytes, "xlsx")

  estado <- if (identical(sha256_norm_obtenido, sha256_norm_esperado)) "PASS" else "CAMBIÓ"
  resultados <- rbind(resultados,
                      data.frame(publicacion_id = pid, estado = estado,
                                 stringsAsFactors = FALSE))
  message("   esperado: ", sha256_norm_esperado)
  message("   obtenido: ", sha256_norm_obtenido, "  -> ", estado)
}

message("\n== Retropolada (manual, excluida) ==")
message("   ", .RETROPOLADA_MANUAL, ": .xlsx estático de www.bcr.gob.sv/documental/, ",
        "serie histórica cerrada, captura manual (Regla 9). No se verifica en vivo; ",
        "su integridad cruzada la cubre scripts/check_l0_integrity.R.")

message("\n== Resumen ==")
for (i in seq_len(nrow(resultados))) {
  message("   ", resultados$estado[i], "  ", resultados$publicacion_id[i])
}

cambiados <- resultados[resultados$estado != "PASS", ]
if (nrow(cambiados) > 0) {
  stop("FALLO VISIBLE: ", nrow(cambiados), " publicación(es) con sha256_norm distinto ",
       "del registrado en L0: ", paste(cambiados$publicacion_id, collapse = ", "),
       ". El portal cambió respecto del vintage registrado. Si es un vintage nuevo ",
       "legítimo, capturarlo deliberadamente con descargar_bcr_*(fecha_publicacion) ",
       "usando el mes de publicación correcto - NO desde make raw (Decisión 1b, ADR-007).")
}
message("\nOK: L0 BCR (vista-serie) íntegra - 3/3 PASS.")
