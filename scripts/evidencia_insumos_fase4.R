# Evidencia de insumos de Fase 4 (senda §4, Fase 4; checklist_fase4.md B4).
#
# Regenera doc/metodologia/reportes_fase4/evidencia_insumos_fase4.csv a partir de lo que ya
# está en el repositorio: data/L3_master/, catalogos/08_vintages.csv y
# doc/calendario_divulgacion_bcr.csv. No estima ningún modelo. Publica las cifras que citan el
# protocolo de evaluación y las notas de ADR de Fase 4, para que ninguna quede transcrita a mano.
#
# Bloques:
#   serie_L3             cobertura de cada archivo de L3 y observaciones al cierre de la ventana
#                        inicial (convención A de ADR-002: 2013-Q1)
#   origenes_evaluables  pares (origen, h) evaluables bajo las cuatro lecturas de ADR-002
#   origenes_por_grupo   primer origen viable y pares por grupo de comparación (F4-05)
#   rezago_publicacion   rezago mediano de divulgación por familia y meses del trimestre o+1
#                        conocidos al publicarse el PIB de o, min/max sobre los 52 orígenes (F4-02)
#   peso_del_shock_2020  dispersión de la tasa interanual del objetivo en la muestra de
#                        evaluación, con y sin 2020 (F4-08)
#   vintages             lo que 08_vintages.csv permite para una evaluación real-time (F4-03)
#
# Uso: Rscript scripts/evidencia_insumos_fase4.R   (desde la raíz; exige L3 materializada)

source_root <- here::here()
ruta <- function(...) file.path(source_root, ...)

# --- aritmética de períodos --------------------------------------------------------------
q_a_ind <- function(p) {                      # "1990-Q1" -> índice entero de trimestre
  as.integer(substr(p, 1, 4)) * 4L + as.integer(sub(".*-Q", "", p)) - 1L
}
ind_a_q <- function(i) sprintf("%d-Q%d", i %/% 4L, i %% 4L + 1L)
m_a_ind <- function(p) {                      # "2005-M01" -> índice entero de mes
  as.integer(substr(p, 1, 4)) * 12L + as.integer(sub(".*-M", "", p)) - 1L
}
fin_de_mes <- function(anio, mes) {           # último día del mes
  sig <- ifelse(mes == 12L, sprintf("%d-01-01", anio + 1L), sprintf("%d-%02d-01", anio, mes + 1L))
  as.Date(sig) - 1L
}
fin_de_trimestre <- function(iq) fin_de_mes(iq %/% 4L, (iq %% 4L + 1L) * 3L)

fila <- function(bloque, item, metrica, valor, nota = "") {
  data.frame(bloque = bloque, item = item, metrica = metrica,
             valor = as.character(valor), nota = nota, stringsAsFactors = FALSE)
}

# --- constantes del diseño (ADR-002 enmendado por la nota del 2026-09-24) ---------------
PRIMER_ORIGEN <- q_a_ind("2013-Q1")
ULTIMO_ORIGEN <- q_a_ind("2025-Q4")
HORIZONTES    <- c(1L, 2L, 4L, 8L)
MIN_OBS_GRUPO <- 40L

l3 <- ruta("data", "L3_master")
archivos <- sort(setdiff(list.files(l3, pattern = "\\.csv$"),
                         c(list.files(l3, pattern = "_outliers\\.csv$"),
                           list.files(l3, pattern = "^reporte_"))))
if (length(archivos) == 0L) stop("data/L3_master/ no tiene series materializadas: correr make master")

objetivo <- read.csv(file.path(l3, "PIB_SA_PROPIO_Q.csv"), stringsAsFactors = FALSE)
iq_obj   <- q_a_ind(objetivo$periodo)
ULTIMO_TARGET <- max(iq_obj)

salida <- list()

# --- serie_L3 ----------------------------------------------------------------------------
for (a in archivos) {
  d <- read.csv(file.path(l3, a), stringsAsFactors = FALSE)
  trimestral <- grepl("-Q", d$periodo[1])
  idx <- if (trimestral) q_a_ind(d$periodo) else m_a_ind(d$periodo)
  corte <- if (trimestral) PRIMER_ORIGEN else PRIMER_ORIGEN %/% 4L * 12L + 2L  # 2013-M03
  salida[[length(salida) + 1L]] <- rbind(
    fila("serie_L3", a, "n_obs", nrow(d)),
    fila("serie_L3", a, "inicio", d$periodo[1]),
    fila("serie_L3", a, "fin", d$periodo[nrow(d)]),
    fila("serie_L3", a, "huecos", max(idx) - min(idx) + 1L - length(idx)),
    fila("serie_L3", a, "valores_ausentes", sum(is.na(d$valor))),
    fila("serie_L3", a, "n_vintages", length(unique(d$vintage_id))),
    fila("serie_L3", a, "obs_al_primer_origen", sum(idx <= corte),
         "convención A: el primer origen es 2013-Q1 (2013-M03 en mensuales)")
  )
}

# --- origenes_evaluables: las cuatro lecturas de ADR-002 --------------------------------
lecturas <- list(
  A_origenes_2013Q1_2025Q4_target_hasta_ultimo = c(q_a_ind("2013-Q1"), q_a_ind("2025-Q4"), ULTIMO_TARGET),
  A_origenes_2013Q1_2025Q4_target_hasta_2025Q4 = c(q_a_ind("2013-Q1"), q_a_ind("2025-Q4"), q_a_ind("2025-Q4")),
  B_origenes_2012Q4_2025Q3_target_hasta_2025Q4 = c(q_a_ind("2012-Q4"), q_a_ind("2025-Q3"), q_a_ind("2025-Q4")),
  B_origenes_2012Q4_2025Q4_target_hasta_ultimo = c(q_a_ind("2012-Q4"), q_a_ind("2025-Q4"), ULTIMO_TARGET)
)
for (nm in names(lecturas)) {
  l <- lecturas[[nm]]; ors <- seq(l[1], l[2])
  primera_muestra <- sum(iq_obj <= l[1])
  for (h in HORIZONTES) {
    salida[[length(salida) + 1L]] <- fila("origenes_evaluables", nm, paste0("h", h),
      sum(ors + h <= l[3]), sprintf("muestra en el primer origen: %d obs", primera_muestra))
  }
}

# --- origenes_por_grupo (F4-05) ----------------------------------------------------------
grupos <- list(
  G1_largo = c("PIB_SA_PROPIO_Q.csv", "BCR_REMESAS_NOM_NSA_Q.csv", "BCR_EXPORT_FOB_NOM_NSA_Q.csv"),
  G2_medio = c("PIB_SA_PROPIO_Q.csv", "BCR_REMESAS_NOM_NSA_Q.csv", "BCR_EXPORT_FOB_NOM_NSA_Q.csv",
               "BCR_ITCER_IDX_NSA_Q.csv", "UT_DEMANDA_ELEC_GWH_NSA_Q.csv",
               "BCR_IVAE_VOL_SA_Q.csv", "BCR_IPM_IDX_NSA_Q.csv"),
  G3_corto = c("PIB_SA_PROPIO_Q.csv", "BCR_REMESAS_NOM_NSA_Q.csv", "BCR_EXPORT_FOB_NOM_NSA_Q.csv",
               "BCR_ITCER_IDX_NSA_Q.csv", "UT_DEMANDA_ELEC_GWH_NSA_Q.csv",
               "BCR_IVAE_VOL_SA_Q.csv", "BCR_IPM_IDX_NSA_Q.csv",
               "BCR_IPP_IDX_NSA_Q.csv", "BCR_REMESAS_REAL_NSA_Q.csv")
)
for (g in names(grupos)) {
  inicios <- vapply(grupos[[g]], function(a) {
    q_a_ind(read.csv(file.path(l3, a), stringsAsFactors = FALSE)$periodo[1])
  }, integer(1))
  primer <- max(PRIMER_ORIGEN, max(inicios) + MIN_OBS_GRUPO - 1L)
  ors <- seq(primer, ULTIMO_ORIGEN)
  for (h in HORIZONTES) {
    salida[[length(salida) + 1L]] <- fila("origenes_por_grupo", g, paste0("h", h),
      sum(ors + h <= ULTIMO_TARGET),
      sprintf("primer origen %s; mínimo %d obs de la serie más corta", ind_a_q(primer), MIN_OBS_GRUPO))
  }
}

# --- rezago_publicacion (F4-02) ----------------------------------------------------------
cal <- read.csv(ruta("doc", "calendario_divulgacion_bcr.csv"), stringsAsFactors = FALSE,
                encoding = "UTF-8")
MESES <- c("Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto",
           "Septiembre", "Octubre", "Noviembre", "Diciembre")
cal$mes_pub <- match(trimws(cal$mes_publicacion), MESES)
if (anyNA(cal$mes_pub)) stop("calendario: mes_publicacion con nombre no reconocido")
ref_fin <- mapply(function(p, tipo) {
  a <- as.integer(substr(p, 1, 4))
  if (tipo == "mensual") fin_de_mes(a, as.integer(substr(p, 6, 7)))
  else fin_de_mes(a, as.integer(substr(p, nchar(p), nchar(p))) * 3L)
}, cal$periodo_referencia, cal$tipo_referencia)
ref_fin <- as.Date(ref_fin, origin = "1970-01-01")
anio_pub <- ifelse(cal$mes_pub >= as.integer(format(ref_fin, "%m")),
                   as.integer(format(ref_fin, "%Y")), as.integer(format(ref_fin, "%Y")) + 1L)
fecha_pub <- as.Date(sprintf("%d-%02d-%02d", anio_pub, cal$mes_pub, cal$dia_publicacion))
cal$rezago <- as.integer(fecha_pub - ref_fin)
rezago_mediano <- function(patron) {
  r <- cal$rezago[grepl(patron, cal$variable, fixed = TRUE)]
  if (length(r) == 0L) stop("calendario: sin filas para ", patron)
  stats::median(r)
}

REZAGO_PIB <- rezago_mediano("PIB T. Producción y gasto")
familias <- list(
  BCR.IVAE.VOL.SA.M        = "Índice de Volumen de la Actividad Económica (IVAE)",
  BCR.REMESAS.NOM.NSA.M    = "Ingresos mensuales de remesas familiares",
  BCR.REMESAS.REAL.NSA.M   = "Ingresos mensuales de remesas familiares",
  BCR.EXPORT_FOB.NOM.NSA.M = "Balanza Comercial de Mercancías. Valores",
  BCR.IPP.IDX.NSA.M        = "Índice de Precios al Productor (IPP)",
  BCR.ITCER.IDX.NSA.M      = "Índice de Tipo de Cambio Efectivo Real - Mensual",
  BCR.IPM.IDX.NSA.M        = "Índices de Precios del Comercio Exterior - Mensual"
)
origenes <- seq(PRIMER_ORIGEN, ULTIMO_ORIGEN)
pub_pib  <- fin_de_trimestre(origenes) + REZAGO_PIB

# Meses del trimestre o+1 publicados a la fecha de publicación del PIB de o.
meses_conocidos <- function(o, pub, rezago) {
  primer_mes <- ((o + 1L) %% 4L) * 3L + 1L
  anio <- (o + 1L) %/% 4L
  sum(vapply(0:2, function(k) fin_de_mes(anio, primer_mes + k) + rezago <= pub, logical(1)))
}
for (f in names(familias)) {
  L <- rezago_mediano(familias[[f]])
  k <- mapply(meses_conocidos, origenes, pub_pib, MoreArgs = list(rezago = L))
  salida[[length(salida) + 1L]] <- rbind(
    fila("rezago_publicacion", f, "rezago_dias_mediano", L, familias[[f]]),
    fila("rezago_publicacion", f, "meses_trimestre_siguiente_conocidos_min", min(k),
         sprintf("sobre los %d orígenes, a la publicación del PIB de o (%s días)", length(origenes), REZAGO_PIB)),
    fila("rezago_publicacion", f, "meses_trimestre_siguiente_conocidos_max", max(k),
         sprintf("sobre los %d orígenes, a la publicación del PIB de o (%s días)", length(origenes), REZAGO_PIB))
  )
}
salida[[length(salida) + 1L]] <- rbind(
  fila("rezago_publicacion", "PIB_SA_PROPIO_Q", "rezago_dias_mediano", REZAGO_PIB,
       "calendario de divulgación del BCR, PIB trimestral"),
  fila("rezago_publicacion", "UT_DEMANDA_ELEC_GWH_NSA_M", "grano_de_disponibilidad", "anual",
       "vintages anuales con fecha de publicación sintética (31-dic; 31-jul para 2026)")
)

# --- peso_del_shock_2020 (F4-08) ---------------------------------------------------------
lg  <- log(objetivo$valor)
yoy <- c(rep(NA_real_, 4L), 100 * diff(lg, lag = 4L))
qoq <- c(NA_real_, 100 * diff(lg))
en_eval <- iq_obj >= PRIMER_ORIGEN + 1L & iq_obj <= ULTIMO_TARGET    # targets de h=1
es_2020 <- substr(objetivo$periodo, 1, 4) == "2020"
y_eval <- yoy[en_eval]
salida[[length(salida) + 1L]] <- rbind(
  fila("peso_del_shock_2020", "PIB_SA_PROPIO_Q", "n_targets_h1", sum(en_eval)),
  fila("peso_del_shock_2020", "PIB_SA_PROPIO_Q", "sd_yoy_pp", round(stats::sd(y_eval), 4)),
  fila("peso_del_shock_2020", "PIB_SA_PROPIO_Q", "sd_yoy_pp_sin_2020",
       round(stats::sd(yoy[en_eval & !es_2020]), 4)),
  fila("peso_del_shock_2020", "PIB_SA_PROPIO_Q", "yoy_pp_2020Q2", round(yoy[objetivo$periodo == "2020-Q2"], 4)),
  fila("peso_del_shock_2020", "PIB_SA_PROPIO_Q", "qoq_pp_2020Q2", round(qoq[objetivo$periodo == "2020-Q2"], 4)),
  fila("peso_del_shock_2020", "PIB_SA_PROPIO_Q", "cuota_2020_en_suma_cuadrados_yoy",
       round(sum(yoy[en_eval & es_2020]^2) / sum(y_eval^2), 4), "targets de h=1")
)

# --- vintages (F4-03) --------------------------------------------------------------------
vin <- read.csv(ruta("catalogos", "08_vintages.csv"), stringsAsFactors = FALSE)
previos <- vin[!is.na(vin$fecha_publicacion) & vin$fecha_publicacion != "" &
               vin$fecha_publicacion < "2026-01-01", ]
pib <- vin[grepl("^BCR\\.PIB_T\\.INDICES_VOLUMEN_ENCADENADOS_NSA$", vin$publicacion_id), ]
salida[[length(salida) + 1L]] <- rbind(
  fila("vintages", "catalogo_08", "n_filas", nrow(vin)),
  fila("vintages", "catalogo_08", "fechas_publicacion_previas_a_2026", nrow(previos),
       paste("publicaciones:", paste(sort(unique(previos$publicacion_id)), collapse = ";"))),
  fila("vintages", "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA", "n_vintages", nrow(pib),
       paste(pib$vintage_id, collapse = ";"))
)

# --- escritura -----------------------------------------------------------------------------
res <- do.call(rbind, salida)
res$fecha_generacion <- format(Sys.Date())
dir_out <- ruta("doc", "metodologia", "reportes_fase4")
dir.create(dir_out, showWarnings = FALSE, recursive = TRUE)
con <- file(file.path(dir_out, "evidencia_insumos_fase4.csv"), open = "wb")  # LF, como el repo
utils::write.csv(res, con, row.names = FALSE, eol = "\n")
close(con)
cat(sprintf("evidencia_insumos_fase4.csv: %d filas\n", nrow(res)))
