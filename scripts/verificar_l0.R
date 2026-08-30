# scripts/verificar_l0.R
# Motor de `make raw` (Fase 2, Decision 1b - 2026-08-25): VERIFICACION, no captura.
# Re-pide cada publicacion a su fuente, recalcula sha256_norm y lo compara contra el
# manifiesto. NO agrega vintages: la captura de un vintage nuevo es un acto deliberado y
# fechado via descargar_*() (ADR-007). Falla de forma visible (regla 6 de CLAUDE.md) si la
# fuente difiere de lo registrado en L0.
#
# Cubre la rama de VERIFICACION del criterio de cierre de Fase 2 (senda S4: "make raw
# reconstruye la capa L0 desde cero O verifica su integridad, sin pasos manuales").
#
# COBERTURA (corregida 2026-08-28, hallazgo A1 de la auditoria de Fase 2). Hasta esa fecha
# este script verificaba 3 publicaciones de una lista fija y cerraba con un "3/3 PASS"
# escrito a mano, mientras el manifiesto tenia 30 publicaciones. Ahora la lista NO se
# escribe: se DERIVA del manifiesto, de modo que toda publicacion capturada queda cubierta
# por construccion y agregar una captura nueva no puede olvidarse de agregarla aca.
# Las exclusiones son explicitas, con motivo, y se listan en cada corrida (.EXCLUIDAS).
#
# LAS DOS VERIFICACIONES HERMANAS, que este script NO duplica:
#   - scripts/verificar_l0_fisico.R  -> el archivo sigue en disco, integro (offline, local).
#   - scripts/check_l0_integrity.R   -> manifiesto <-> 08_vintages (offline, corre en CI).
# Este es el unico de los tres que sale a la red.
#
# ALCANCE DE UNA CORRIDA (regla 9 de CLAUDE.md). Verificar todo el BCR son 16 renders
# completos de tabla + exportacion .xlsx en navegador headless; una de esas tablas
# (GOBIERNO_CENTRAL_CONSOLIDADO, ~21450 celdas) necesita minutos. Eso es aceptable como acto
# deliberado del operador al ritmo de publicacion de la fuente, y NO lo es como algo que se
# corre en bucle mientras se programa. Por eso el alcance es seleccionable:
#     Rscript scripts/verificar_l0.R          # todo (lo que exige el criterio de cierre)
#     Rscript scripts/verificar_l0.R api      # solo FMI/FRED/BM: barato, sin navegador
#     Rscript scripts/verificar_l0.R bcr      # solo el portal del BCR
#     Rscript scripts/verificar_l0.R plan     # no pide NADA: solo lista que se verificaria
# El default es "todo" a proposito: el criterio de cierre se satisface con la corrida
# completa, no con la barata. `plan` existe para poder revisar la cobertura -y que este
# script carga sin errores- sin gastar una sola peticion a ninguna fuente.

source("src/adquisicion/lib_adquisicion.R")  # calcular_sha256_norm, leer_manifiesto

.ALCANCE <- local({
  a <- commandArgs(trailingOnly = TRUE)
  a <- if (length(a) == 0) "todo" else tolower(a[1])
  if (!a %in% c("todo", "api", "bcr", "plan")) {
    stop("FALLO VISIBLE: alcance '", a, "' no reconocido. Use: todo | api | bcr | plan")
  }
  a
})
.SOLO_PLAN <- identical(.ALCANCE, "plan")

# Publicaciones capturadas que NO se verifican en vivo, con el motivo. Cada una tiene que
# estar cubierta por alguna otra via, y se dice cual.
.EXCLUIDAS <- list(
  BCR.PIB_T.SERIE_RETROPOLADA_1990_2005 = paste(
    "no es una serie del componente vista-serie sino un .xlsx estatico de",
    "www.bcr.gob.sv/documental/, serie historica cerrada (termina 2005-T4), captura manual",
    "(regla 9). Cubierta por verificar_l0_fisico.R y check_l0_integrity.R."
  ),
  UT.DEMANDA_TOTAL_MENSUAL = paste(
    "robots.txt de ut.com.sv no permite el scraping de esta ruta (verificado con",
    "polite::scrape(), src/adquisicion/verificar_robots_ut.R). La regla 9 de CLAUDE.md",
    "prohibe evadirlo aunque chromote pudiera: no se re-pide en vivo, punto. Cubierta por",
    "verificar_l0_fisico.R y check_l0_integrity.R."
  )
)

# --- Como se vuelve a pedir cada fuente ------------------------------------------------
# El re-pedido reusa la MISMA funcion que arma la peticion de captura (.fred_refetch,
# .bm_refetch, .fmi_perform) para que verificacion y captura no puedan divergir: si la
# captura cambia de parametros, la verificacion cambia con ella.

.FORMULA_BASE <- "0"  # representacion base del componente vista-serie; uniforme en bcr.R

.mecanismo <- function(fuente) {
  if (fuente == "BCR") "bcr" else "api"
}

.refetch <- function(fuente, url) {
  if (fuente == "FRED") {
    .fred_refetch(url)
  } else if (fuente == "BM") {
    .bm_refetch(url)
  } else if (fuente == "FMI") {
    httr2::resp_body_raw(.fmi_perform(url))
  } else {
    stop("FALLO VISIBLE: no hay mecanismo de re-pedido para la fuente '", fuente,
         "'. Agregarlo aca antes de capturar publicaciones nuevas de esa fuente.")
  }
}

# --- Lista de trabajo, derivada del manifiesto -----------------------------------------
manifiesto <- leer_manifiesto()

# Vintage vigente por publicacion = ultima fila (el manifiesto es append-only). Misma
# convencion que registrar_descarga() paso 3 y src/validacion/verificar_fuente_celda.R.
vigentes <- do.call(rbind, lapply(unique(manifiesto$publicacion_id), function(pid) {
  filas <- manifiesto[manifiesto$publicacion_id == pid, ]
  filas[nrow(filas), ]
}))

excluidas <- vigentes[vigentes$publicacion_id %in% names(.EXCLUIDAS), ]
trabajo   <- vigentes[!vigentes$publicacion_id %in% names(.EXCLUIDAS), ]
trabajo$mecanismo <- vapply(trabajo$fuente, .mecanismo, character(1))
if (.ALCANCE %in% c("api", "bcr")) trabajo <- trabajo[trabajo$mecanismo == .ALCANCE, ]
trabajo <- trabajo[order(trabajo$mecanismo, trabajo$publicacion_id), ]

if (nrow(trabajo) == 0) {
  stop("FALLO VISIBLE: no hay ninguna publicacion que verificar con alcance '", .ALCANCE,
       "'. El manifiesto tiene ", nrow(vigentes), " publicacion(es).")
}

message("Alcance: ", .ALCANCE, " - ", nrow(trabajo), " publicacion(es) a verificar en vivo, ",
        nrow(excluidas), " excluida(s) por diseno.\n")

if (.SOLO_PLAN) {
  message("== Plan (no se pide nada a ninguna fuente) ==")
  for (i in seq_len(nrow(trabajo))) {
    message("   ", formatC(trabajo$mecanismo[i], width = -5), " ",
            formatC(trabajo$fuente[i], width = -5), " ", trabajo$publicacion_id[i])
  }
  message("\n== Excluidas de la verificacion en vivo (", nrow(excluidas), ") ==")
  for (pid in excluidas$publicacion_id) message("   ", pid, ": ", .EXCLUIDAS[[pid]])
  message("\nCobertura: ", nrow(trabajo), " en vivo + ", nrow(excluidas), " excluidas = ",
          nrow(vigentes), " publicacion(es) del manifiesto. Sin huecos por construccion.")
  quit(status = 0)
}

# Los scripts por fuente se cargan solo si hacen falta, y despues del modo `plan`: cargar
# bcr.R arrastra bcr_captura.R, que exige chromote, y no tiene por que estar instalado en una
# maquina que solo quiere verificar las API o revisar la cobertura.
if (any(trabajo$mecanismo == "bcr")) source("src/adquisicion/bcr.R")
if (any(trabajo$fuente == "FRED")) source("src/adquisicion/fred.R")
if (any(trabajo$fuente == "BM"))   source("src/adquisicion/bm.R")
if (any(trabajo$fuente == "FMI"))  source("src/adquisicion/fmi.R")

# --- Verificacion ----------------------------------------------------------------------
resultados <- data.frame(publicacion_id = character(), fuente = character(),
                         estado = character(), detalle = character(),
                         stringsAsFactors = FALSE)

for (i in seq_len(nrow(trabajo))) {
  fila <- trabajo[i, ]
  pid <- fila$publicacion_id
  sha_esperado <- fila$sha256_norm
  extension <- tolower(tools::file_ext(fila$archivo))

  message("== Verificando ", pid, " (", fila$fuente, ", ", fila$mecanismo, ") ==")

  obtenido <- tryCatch({
    if (fila$mecanismo == "bcr") {
      bcr_capturar_xlsx(fila$url, formula = .FORMULA_BASE)$bytes
    } else {
      .refetch(fila$fuente, fila$url)
    }
  }, error = function(e) e)

  if (inherits(obtenido, "error")) {
    resultados <- rbind(resultados, data.frame(
      publicacion_id = pid, fuente = fila$fuente, estado = "ERROR",
      detalle = conditionMessage(obtenido), stringsAsFactors = FALSE))
    message("   ERROR: ", conditionMessage(obtenido))
    next
  }

  sha_obtenido <- calcular_sha256_norm(obtenido, extension)
  estado <- if (identical(sha_obtenido, sha_esperado)) "PASS" else "CAMBIO"
  message("   esperado: ", sha_esperado)
  message("   obtenido: ", sha_obtenido, "  -> ", estado)
  resultados <- rbind(resultados, data.frame(
    publicacion_id = pid, fuente = fila$fuente, estado = estado,
    detalle = paste0("sha256_norm esperado ", sha_esperado, ", obtenido ", sha_obtenido),
    stringsAsFactors = FALSE))
}

# --- Resumen ---------------------------------------------------------------------------
message("\n== Excluidas de la verificacion en vivo (", nrow(excluidas), ") ==")
for (pid in excluidas$publicacion_id) message("   ", pid, ": ", .EXCLUIDAS[[pid]])

message("\n== Resumen (alcance: ", .ALCANCE, ") ==")
for (i in seq_len(nrow(resultados))) {
  message("   ", formatC(resultados$estado[i], width = -7), resultados$publicacion_id[i])
}

n_pass   <- sum(resultados$estado == "PASS")
n_cambio <- sum(resultados$estado == "CAMBIO")
n_error  <- sum(resultados$estado == "ERROR")

if (n_error > 0) {
  stop("FALLO VISIBLE: ", n_error, " publicacion(es) no se pudieron re-pedir: ",
       paste(resultados$publicacion_id[resultados$estado == "ERROR"], collapse = ", "),
       ". No es lo mismo que 'cambio': la fuente no respondio o respondio algo inesperado. ",
       "Ver el detalle arriba antes de concluir nada sobre L0.")
}

if (n_cambio > 0) {
  stop("FALLO VISIBLE: ", n_cambio, " publicacion(es) con sha256_norm distinto del ",
       "registrado en L0: ",
       paste(resultados$publicacion_id[resultados$estado == "CAMBIO"], collapse = ", "),
       ". La fuente cambio respecto del vintage registrado. Si es un vintage nuevo ",
       "legitimo, capturarlo deliberadamente con la funcion descargar_*() correspondiente ",
       "pasando la fecha de publicacion correcta - NO desde make raw (Decision 1b, ADR-007).")
}

message("\nOK: L0 integra frente a la fuente - ", n_pass, "/", nrow(trabajo), " PASS",
        if (.ALCANCE != "todo") paste0(" (alcance parcial '", .ALCANCE,
                                        "': el criterio de cierre de Fase 2 exige la corrida completa)") else "",
        ".")
