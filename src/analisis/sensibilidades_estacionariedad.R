# Sensibilidades exploratorias de las pruebas de estacionariedad que cita
# doc/metodologia/reporte_exploratorio_fase3.md §3. NO forma parte del pipeline ni de `make`: no
# escribe nada en data/ ni cambia ningún veredicto publicado (`conclusion` sigue siendo el de
# src/analisis/estacionariedad.R). Solo imprime las cifras que el reporte cita, para que se
# puedan rehacer cuando cambie la base maestra.
#
# Versionado el 2026-09-23. Hasta entonces las dos sensibilidades se habían computado fuera del
# repositorio y sin registro de su especificación, y al admitir UT (8 filas nuevas) no hubo cómo
# rehacerlas. La especificación de las dummies de 2020 se RECONSTRUYÓ por su huella: es la única
# de las probadas que reproduce a la vez las cuatro cifras publicadas sobre las 64 filas del
# 2026-09-22 (41 de 64 menos negativas, 7 veredictos cambiados, 5 hacia menos rechazo,
# BCR_EXPORT_FOB_NOM_NSA_M log -2,96 -> -3,66). Además reproduce el -3,31 del log de
# PIB_SA_PROPIO_Q que el reporte retiró por salir de este mismo cómputo. Ver
# doc/evidencia_cierre_fase3.txt, "Sensibilidades exploratorias recomputadas".
#
# 1. KPSS con truncamiento "long" (trunc(12*(n/100)^0.25)) en lugar del "short" de
#    prueba_kpss(): cuántas filas rechazan estacionariedad al 5% con cada uno.
# 2. ADF con un impulso por cada período de 2020 desde el inicio de la pandemia (2020-M03 a
#    2020-M12 en mensuales, 2020-Q1 a 2020-Q4 en trimestrales), fechado en la fila de la
#    diferencia z = Δx de ese período, en las cuatro transformaciones, con los rezagos
#    re-elegidos por BIC en la grilla 0..techo de Schwert (misma muestra común que
#    .seleccion_bic_adf()). Con impulsos la distribución ya no es la de Dickey-Fuller: los
#    "cambios de veredicto" que se cuentan acá miden dirección y magnitud contra los críticos de
#    urca, no son veredictos alternativos (ver la salvedad del reporte).
#
# Requiere `make master` ya corrido (data/L3_master/ poblado).

suppressMessages(library(urca))
source(here::here("src", "analisis", "estacionariedad_reglas.R"))

dir_l3 <- here::here("data", "L3_master")
archivos <- list.files(dir_l3, pattern = "_(M|Q)\\.csv$")
FECHAS_2020 <- list(M = sprintf("2020-M%02d", 3:12), Q = sprintf("2020-Q%d", 1:4))

adf_con_impulsos_2020 <- function(x, periodos_x, tipo_transf, frecuencia) {
  spec <- .especificacion(tipo_transf)
  techo <- .max_rezagos_schwert(length(x))
  dis <- .diseno_adf(x, spec$adf_type, techo)
  pos <- which(periodos_x %in% FECHAS_2020[[frecuencia]])
  # z[i] = x[i+1] - x[i] va fechada en el período i+1: el impulso del período en la posición p
  # de x cae en la fila tt == p - 1.
  D <- vapply(pos, function(p) as.numeric(dis$tt == (p - 1L)), numeric(length(dis$tt)))
  D <- D[, colSums(D) > 0, drop = FALSE]
  colnames(D) <- paste0("imp", seq_len(ncol(D)))
  ajustar <- function(k) {
    base <- .lm_adf(dis, k)
    datos <- cbind(stats::model.frame(base), D)
    terminos <- c(attr(stats::terms(base), "term.labels"), colnames(D))
    stats::lm(stats::as.formula(paste("z_diff ~", paste(terminos, collapse = " + "))), data = datos)
  }
  n_efectivo <- length(dis$z_diff)
  ajustes <- lapply(0:techo, ajustar)
  elegido <- ajustes[[which.min(vapply(ajustes, function(a) stats::AIC(a, k = log(n_efectivo)), numeric(1)))]]
  summary(elegido)$coefficients["z_lag_1", "t value"]
}

filas <- list()
for (a in archivos) {
  serie_id <- sub("\\.csv$", "", a)
  df <- read.csv(file.path(dir_l3, a), stringsAsFactors = FALSE, na.strings = "")
  df <- df[order(df$periodo), c("periodo", "valor")]
  if (nrow(df) < 30) next  # mismo umbral que estacionariedad.R
  frecuencia <- if (grepl("_M$", serie_id)) "M" else "Q"
  candidatas <- transformaciones_candidatas(df$valor)
  for (tr in names(candidatas)) {
    x <- candidatas[[tr]]
    if (is.null(x)) next
    periodos_x <- if (tr %in% c("diff", "diff_log")) df$periodo[-1] else df$periodo
    adf <- prueba_adf(x, tr, frecuencia)
    kpss <- prueba_kpss(x, tr)
    kpss_long <- ur.kpss(x, type = .especificacion(tr)$kpss_type, lags = "long")
    filas[[length(filas) + 1]] <- data.frame(
      serie_id = serie_id, transformacion = tr,
      kpss_rechaza_short = kpss$rechaza_estacionariedad,
      kpss_rechaza_long = unname(kpss_long@teststat[1]) > unname(kpss_long@cval[1, "5pct"]),
      adf_estadistico = adf$estadistico,
      adf_estadistico_impulsos_2020 = adf_con_impulsos_2020(x, periodos_x, tr, frecuencia),
      adf_cval_5pct = adf$cval_5pct,
      stringsAsFactors = FALSE
    )
  }
}
tabla <- do.call(rbind, filas)

etiqueta <- function(rechaza_adf, rechaza_kpss) {
  ifelse(rechaza_adf & !rechaza_kpss, "estacionaria",
         ifelse(!rechaza_adf & rechaza_kpss, "no_estacionaria",
                ifelse(rechaza_adf, "ambigua_ambas_rechazan", "ambigua_ninguna_rechaza")))
}
rechaza_antes <- tabla$adf_estadistico < tabla$adf_cval_5pct
rechaza_despues <- tabla$adf_estadistico_impulsos_2020 < tabla$adf_cval_5pct
tabla$conclusion <- etiqueta(rechaza_antes, tabla$kpss_rechaza_short)
tabla$conclusion_impulsos_2020 <- etiqueta(rechaza_despues, tabla$kpss_rechaza_short)

cat(sprintf("Filas: %d (%d series)\n\n", nrow(tabla), length(unique(tabla$serie_id))))
cat(sprintf("1. KPSS: rechazos al 5%% con 'short' = %d, con 'long' = %d\n\n",
            sum(tabla$kpss_rechaza_short), sum(tabla$kpss_rechaza_long)))
cambia <- tabla$conclusion != tabla$conclusion_impulsos_2020
cat(sprintf(paste0("2. ADF con impulsos de 2020: estadístico menos negativo en %d de %d filas; ",
                   "%d veredictos cambian (%d hacia menos rechazo, %d hacia más)\n"),
            sum(tabla$adf_estadistico_impulsos_2020 > tabla$adf_estadistico), nrow(tabla),
            sum(cambia), sum(rechaza_antes & !rechaza_despues), sum(!rechaza_antes & rechaza_despues)))
print(tabla[cambia, c("serie_id", "transformacion", "adf_estadistico",
                      "adf_estadistico_impulsos_2020", "adf_cval_5pct", "conclusion",
                      "conclusion_impulsos_2020")], row.names = FALSE, digits = 3)
nsa_log <- tabla[grepl("_NSA_M$", tabla$serie_id) & tabla$transformacion == "log" &
                 tabla$conclusion == "no_estacionaria", ]
cat(sprintf("\nFilas log de series NSA mensuales publicadas no_estacionaria: %d; siguen no_estacionaria con impulsos: %d\n",
            nrow(nsa_log), sum(nsa_log$conclusion_impulsos_2020 == "no_estacionaria")))
print(nsa_log[, c("serie_id", "adf_estadistico", "adf_estadistico_impulsos_2020", "adf_cval_5pct",
                  "conclusion_impulsos_2020")], row.names = FALSE, digits = 3)
