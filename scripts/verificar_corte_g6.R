# verificar_corte_g6.R
#
# G-6 sobre la L1/L3 que armo `make master` con un corte (checklist de Fase 6, C4; F6-04). Corre, sin
# estimar nada, las mismas guardas de lectura que el motor (src/evaluacion/motor_backtesting.R):
#   - objetivos PIB_SA_PROPIO_Q y PIB_SA_OFICIAL_Q con el vintage que el corte declara (leer_objetivo);
#   - NSA de L1 del mismo vintage que L3 período a período (leer_nsa_concat) y SA recalculado desde L1
#     idéntico al de L3, con los mismos AO (C-5, verificar_l1_contra_l3);
#   - G-6 por fila en toda serie maestra de rol `predictor` o `escenario` de 05_series_master.csv
#     (verificar_vintage_predictora), incluidas las ESC.* de F6-18.
# Informa el último trimestre del objetivo, que es el origen de F6-04. Todo falla con stop() (regla 7).
#
# Uso (después de `make master CONJUNTO=… SALIDA=…`, con las mismas rutas):
#   SIE_CONJUNTO=doc/metodologia/corte_fase6.csv SIE_SALIDA=data/conjuntos/corte_f6 Rscript scripts/verificar_corte_g6.R

source(here::here("src", "evaluacion", "motor_backtesting.R"))

conjunto <- exigir_conjunto(conjunto_activo())
vintages <- leer_vintages()
pol <- "revision_vigente"
idc <- identidad_conjunto(Sys.getenv("SIE_CONJUNTO"))
cat("Corte: ", idc$ruta, " (", nrow(conjunto), " vintages, sha256 sin CR ", idc$sha256, "), salida ", idc$salida, "\n", sep = "")

objetivos <- c("PIB_SA_PROPIO_Q", "PIB_SA_OFICIAL_Q")
obj <- list()
for (ob in objetivos) {
  obj[[ob]] <- leer_objetivo(paste0(ob, ".csv"), pol, vintages, conjunto)
  d <- obj[[ob]]
  cat(sprintf("OK G-6 objetivo %-17s %s..%s (%d obs), vintage %s\n", ob, d$periodo[1], d$periodo[nrow(d)],
              nrow(d), paste(unique(d$vintage_id), collapse = ", ")))
}

l1 <- .leer_capa("L1_staging", "BCR_PIB_series_largo.csv")
invisible(leer_nsa_concat(vintages, obj$PIB_SA_PROPIO_Q, conjunto, l1 = l1))
verificar_l1_contra_l3(ajustar_estacional_propio(concatenar_pib_nsa(l1)),
                       .leer_capa("L3_master", "PIB_SA_PROPIO_Q.csv"),
                       .leer_capa("L3_master", "PIB_SA_PROPIO_Q_outliers.csv"))
cat("OK G-6 NSA de L1 y C-5 (SA recalculado desde L1 idéntico al de L3)\n")

master <- .leer_csv("catalogos", "05_series_master.csv")
ids <- master$series_master_id[master$rol %in% c("predictor", "escenario")]
for (id in ids) {
  d <- .leer_capa("L3_master", archivo_l3(id))
  verificar_vintage_predictora(d, id, vintages, conjunto)
  cat(sprintf("OK G-6 %-9s %-34s %s..%s (%d filas)\n", master$rol[master$series_master_id == id], id,
              d$periodo[1], d$periodo[nrow(d)], nrow(d)))
}

o <- obj$PIB_SA_PROPIO_Q$periodo[nrow(obj$PIB_SA_PROPIO_Q)]
cat(sprintf("OK verificar-corte-g6: %d objetivos, NSA/C-5 y %d series de L3. Origen (F6-04): %s\n",
            length(objetivos), length(ids), o))
