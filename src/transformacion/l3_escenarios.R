# L1 -> L3 de las variables de escenario de Fase 6 (F6-14, F6-16 y F6-18 de
# doc/metodologia/decisiones_fase6.md; checklist C3). Reglas en l3_escenarios_reglas.R, que
# tests/test-l3-escenarios.R ejerce con datos sinteticos.
#
# Catalogo-dirigido como l3_predictores.R: recorre las filas de catalogos/04_transformaciones.csv
# cuyo script_path es este archivo, en orden, y resuelve `funcion` con match.fun(). El primer insumo
# de cada fila es una serie de L1 (ESCENARIOS_series_largo.csv) o el producto de una fila anterior;
# los demas son series anuales de L1. Ademas materializa las series maestras de rol `escenario` sin
# transf_id (pass-through, hoy FRED.PIB_EEUU.VOL.SA.Q) y las de rol `referencia` (pass-through anual,
# hoy FMI.PIB_SLV_VAR.PCT.NSA.A, la comparacion informativa de F6-10; nota del 2026-10-22).
#
# Salidas en data/L3_master/ (capa generada, no versionada), un CSV por serie maestra con el punto
# cambiado por guion bajo: periodo, valor, vintage_id y, en las ESC.*, tramo (historia | sendero).
# El tramo historico lleva el vintage de su serie historica; el sendero, el de todos los insumos.
#
# Despues de construir todo corre las seis validaciones de F6-18 (stop(), regla 7) e informa, sin
# detener, la diferencia del PIB de EE. UU. contra el WEO (difiere por vintage). El origen `o` de la
# validacion 4 es el ultimo trimestre de PIB_SA_PROPIO_Q.csv en esta misma L3 (F6-04), asi que este
# script corre despues de l3_pib_objetivo.R.
#
# Con un conjunto que no declara ninguna publicacion de escenario (corte_fase5.csv), la etapa se
# omite (F6-18-d).

source(here::here("src", "transformacion", "l3_predictores_reglas.R"))
source(here::here("src", "transformacion", "l3_escenarios_reglas.R"))
source(here::here("src", "transformacion", "conjunto_lib.R"))

SCRIPT <- "src/transformacion/l3_escenarios.R"
series_catalogo <- read.csv(here::here("catalogos", "03_series.csv"), stringsAsFactors = FALSE, na.strings = "")
master_catalogo <- read.csv(here::here("catalogos", "05_series_master.csv"), stringsAsFactors = FALSE, na.strings = "")
transformaciones <- read.csv(here::here("catalogos", "04_transformaciones.csv"), stringsAsFactors = FALSE, na.strings = "")
transformaciones <- transformaciones[transformaciones$script_path == SCRIPT, ]
vintages <- leer_vintages()
conjunto <- conjunto_activo()

PUBLICACIONES_ESCENARIO <- publicaciones_de_escenario(series_catalogo, master_catalogo)
if (!etapa_escenario_activa(conjunto, PUBLICACIONES_ESCENARIO)) {
  cat("Etapa de escenario omitida: el conjunto no declara ninguna publicacion de escenario; es un corte anterior a Fase 6.\n")
  quit(status = 0)
}
if (nrow(transformaciones) == 0) stop("FALLO VISIBLE: 04_transformaciones.csv no tiene filas con script_path == '", SCRIPT, "'.")

maestras <- master_catalogo[!is.na(master_catalogo$rol) & master_catalogo$rol == "escenario", ]
fuera <- setdiff(maestras$transf_id[!is.na(maestras$transf_id)], transformaciones$transf_id)
if (length(fuera) > 0) stop("FALLO VISIBLE: series maestras de escenario con transf_id ajeno a este script: ", paste(fuera, collapse = ", "))

l1 <- read.csv(ruta_capa("L1_staging", "ESCENARIOS_series_largo.csv"), stringsAsFactors = FALSE,
               na.strings = "", colClasses = c(serie_id = "character", periodo = "character", valor = "numeric"))
ruta_l3 <- function(id) ruta_capa("L3_master", paste0(gsub("\\.", "_", id), ".csv"))
dir.create(ruta_capa("L3_master"), showWarnings = FALSE, recursive = TRUE)

leer_l1 <- function(serie_id) {
  s <- l1[l1$serie_id == serie_id, c("periodo", "valor")]
  if (nrow(s) == 0) stop("FALLO VISIBLE [", serie_id, "]: la serie no esta en ESCENARIOS_series_largo.csv.")
  s <- s[order(s$periodo), ]; rownames(s) <- NULL
  s
}

# vintage_id por serie (cruda o producto), igual que en l3_predictores.R: el de su publicacion
# (03_series.csv) o, para un producto, el de sus insumos.
vintage_registro <- new.env(parent = emptyenv())
vintage_de <- function(id) {
  if (exists(id, envir = vintage_registro, inherits = FALSE)) return(get(id, envir = vintage_registro))
  v <- vintage_vigente(resolver_publicacion(id, series_catalogo), vintages, conjunto)
  assign(id, v, envir = vintage_registro); v
}
vintage_de_insumos <- function(ids) paste(unique(vapply(ids, vintage_de, character(1))), collapse = " + ")

registro <- new.env(parent = emptyenv())
resolver <- function(id) {
  if (exists(id, envir = registro, inherits = FALSE)) return(get(id, envir = registro))
  s <- leer_l1(id); assign(id, s, envir = registro); s
}

escribir <- function(id, serie, vid_hist, vid_sendero = NULL) {
  out <- serie
  if ("tramo" %in% names(out)) {
    out$vintage_id <- ifelse(out$tramo == "historia", vid_hist, vid_sendero)
    out <- out[, c("periodo", "valor", "tramo", "vintage_id")]
  } else {
    out$vintage_id <- vid_hist
    out <- out[, c("periodo", "valor", "vintage_id")]
  }
  write.csv(out, ruta_l3(id), row.names = FALSE, na = "")
  cat("OK: ", id, " (", nrow(out), " obs, ", out$periodo[1], " a ", out$periodo[nrow(out)], ") -> ", ruta_l3(id), "\n", sep = "")
}

# --- Pass-through: maestras de escenario sin transf_id ------------------------------------------
for (i in which(is.na(maestras$transf_id))) {
  id <- maestras$series_master_id[i]
  if (!identical(trimws(maestras$series_insumo_ids[i]), id)) {
    stop("FALLO VISIBLE [", id, "]: una maestra sin transf_id es un pass-through y su unico insumo debe ser ella misma.")
  }
  s <- resolver(id)
  .exigir_trimestral_contigua(s, id)
  escribir(id, s, vintage_de(id))
}

# --- Referencias (rol `referencia`, 2026-10-22, F6-10): pass-through anual, sin transf_id ---------
referencias <- master_catalogo[!is.na(master_catalogo$rol) & master_catalogo$rol == "referencia", ]
for (i in seq_len(nrow(referencias))) {
  id <- referencias$series_master_id[i]
  if (!is.na(referencias$transf_id[i]) || !identical(trimws(referencias$series_insumo_ids[i]), id) || referencias$freq[i] != "A") {
    stop("FALLO VISIBLE [", id, "]: una referencia es un pass-through anual sin transf_id cuyo unico insumo es ella misma.")
  }
  s <- resolver(id)
  serie_anual_a_vector(s, id)
  escribir(id, s, vintage_de(id))
}

# --- Filas de 04 (T012, T013, T014_*) en orden -------------------------------------------------
senderos <- list()
for (i in seq_len(nrow(transformaciones))) {
  fila <- transformaciones[i, ]
  insumos <- trimws(strsplit(fila$series_insumo, ",", fixed = TRUE)[[1]])
  fn <- match.fun(sub("\\(\\)$", "", fila$funcion))
  args <- c(lapply(insumos, resolver), list(etiqueta = fila$serie_producto))
  res <- do.call(fn, args)
  assign(fila$serie_producto, res, envir = registro)
  vid_ins <- vintage_de_insumos(insumos)
  if ("tramo" %in% names(res)) {
    senderos[[fila$serie_producto]] <- list(serie = res, insumos = insumos, transf_id = fila$transf_id)
    escribir(fila$serie_producto, res, vintage_de(insumos[1]), vid_ins)
  } else {
    assign(fila$serie_producto, vid_ins, envir = vintage_registro)
    escribir(fila$serie_producto, res, vid_ins)
    mi <- attr(res, "meses_interpolados")
    if (length(mi) > 0) cat("   ", fila$transf_id, ": mes(es) sin dato interpolado(s) log-linealmente (F6-18-b): ", paste(mi, collapse = ", "), "\n", sep = "")
  }
}

# --- Validaciones de F6-18 --------------------------------------------------------------------
pib_objetivo <- read.csv(ruta_capa("L3_master", "PIB_SA_PROPIO_Q.csv"), stringsAsFactors = FALSE)
origen <- max(pib_objetivo$periodo)

esperadas <- maestras$series_master_id[grepl("^ESC\\.", maestras$series_master_id)]
if (!setequal(esperadas, names(senderos))) {
  stop("FALLO VISIBLE: las series ESC.* de 05_series_master.csv (", paste(sort(esperadas), collapse = ", "),
       ") no son las que produjo T014 (", paste(sort(names(senderos)), collapse = ", "), ").")
}

variable_de <- function(id) sub("\\.[A-Z]+$", "", id)       # ESC.PIB_EEUU.VOL.SA.Q.BASE -> ESC.PIB_EEUU.VOL.SA.Q
escenario_de <- function(id) sub("^.*\\.", "", id)

for (id in names(senderos)) {
  s <- senderos[[id]]
  if (!escenario_de(id) %in% ESCENARIOS_FASE6) stop("FALLO VISIBLE [", id, "]: sufijo de escenario desconocido.")
  validar_metas(s$serie, attr(s$serie, "metas"), id)                         # (1)
  validar_historia(s$serie, get(s$insumos[1], envir = registro), id)         # (2)
  validar_estructura(s$serie, origen, id)                                    # (4)
}
for (v in unique(vapply(names(senderos), variable_de, character(1)))) {
  ids <- names(senderos)[vapply(names(senderos), variable_de, character(1)) == v]
  base <- paste0(v, ".BASE")
  if (!base %in% ids) stop("FALLO VISIBLE [", v, "]: falta la serie BASE.")
  validar_historia_comun(lapply(stats::setNames(c(base, setdiff(ids, base)), c(base, setdiff(ids, base))),
                                function(x) senderos[[x]]$serie), v)          # (2)
  for (id in setdiff(ids, base)) {                                           # (3)
    s <- senderos[[id]]
    if (length(s$insumos) != 3) stop("FALLO VISIBLE [", id, "]: un escenario distinto de BASE necesita su serie de desvio como tercer insumo.")
    tipo <- switch(transformaciones$funcion[transformaciones$transf_id == s$transf_id],
                   "sendero_escenario_desvio_nivel()" = "nivel_pct",
                   "sendero_escenario_desvio_crecimiento()" = "crecimiento_pp",
                   stop("FALLO VISIBLE [", id, "]: funcion sin tipo de desvio."))
    err <- validar_desvio(s$serie, senderos[[base]]$serie, get(s$insumos[3], envir = registro), tipo, id)
    cat(sprintf("V-ESC-3 %s: desvio contra la base reproducido (dif. max. %.2e)\n", id, err))
  }
}
cat("V-ESC-1, V-ESC-2 y V-ESC-4: OK en ", length(senderos), " series ESC.* (origen ", origen, ", fin >= o + ", H_MAX_FASE6, ").\n", sep = "")

r5 <- validar_petroleo_weo(resolver("FMI.PETROLEO_APSP.USD.NSA.M"), resolver("FMI.PETROLEO_APSP.USD.NSA.A"))  # (5)
cat(sprintf("V-ESC-5: promedio anual del petroleo en USD = POILAPSP del WEO en %d-%d (error relativo max. %.2e)\n",
            r5$anios[1], r5$anios[2], r5$error_max))
r6 <- validar_ipc_weo(resolver("FRED.IPC_EEUU.IDX.SA.M"), resolver("FMI.IPC_EEUU_VAR.PCT.NSA.A"))            # (6)
cat(sprintf("V-ESC-6: inflacion anual de CPIAUCSL frente a PCPIPCH del WEO en %d-%d (dif. max. %.2e pp)\n",
            r6$anios[1], r6$anios[2], r6$dif_max))
rp <- comparar_pib_weo(resolver("FRED.PIB_EEUU.VOL.SA.Q"), resolver("FMI.PIB_EEUU_VAR.PCT.NSA.A"))
cat(sprintf("Informativo: crecimiento anual de GDPC1 frente a NGDP_RPCH del WEO en %d-%d, dif. max. %.3f pp (%s); difiere por vintage.\n",
            rp$anios[1], rp$anios[2], rp$dif_max, rp$anio))
cat("OK: variables de escenario en L3 validadas (F6-18).\n")
