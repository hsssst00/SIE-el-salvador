# tests/test-analisis-posterior-ap4.R
#
# Análisis posterior AP-4 de Fase 5 (src/analisis_posterior/ap4_familias.R), con datos SINTÉTICOS: no se lee data/.
# Comprueba la familia por prefijo, los representantes por grupo (los de Harold, 2026-10-15), que los errores
# reconstruidos de pronosticos.csv tienen que dar el RMSE y el MAE de metricas.csv (si no, se detiene), las métricas de
# extremos y el resumen por familia.

library(testthat)
source(here::here("src", "analisis_posterior", "ap4_familias.R"))

.l4_ap4 <- function(raiz, exp_id, obj, alterar_rmse = FALSE) {
  d <- file.path(raiz, exp_id); dir.create(d, recursive = TRUE)
  y <- stats::setNames(obj$y, q_a_ind(obj$periodo))
  origenes <- q_a_ind("2005-Q1") + 0:19
  mods <- c("BENCH.RW_SIN_DERIVA", "UNI.ARIMA", "MIX.PUENTE.G9")
  set.seed(3)
  p <- do.call(rbind, lapply(mods, function(m) do.call(rbind, lapply(origenes, function(o) {
    hs <- 1:8; obs <- 100 * (y[as.character(o + hs)] - y[as.character(o + hs - 4L)])
    data.frame(exp_id = exp_id, modelo_id = m, grupo = "G9", origen = ind_a_q(o), h = hs,
               yoy_pp_pronosticado = unname(obs) + stats::rnorm(8, 0, if (m == "MIX.PUENTE.G9") 0.5 else 1))
  }))))
  utils::write.csv(p, file.path(d, "pronosticos.csv"), row.names = FALSE)
  pv <- p[p$h %in% DISENO_FASE4$horizontes, ]
  o <- q_a_ind(pv$origen); obs <- 100 * (y[as.character(o + pv$h)] - y[as.character(o + pv$h - 4L)])
  e <- unname(obs) - pv$yoy_pp_pronosticado
  met <- do.call(rbind, lapply(split(data.frame(m = pv$modelo_id, h = pv$h, e = e), list(pv$modelo_id, pv$h)), function(x)
    data.frame(exp_id = exp_id, modelo_id = x$m[1], grupo = "G9", h = x$h[1], unidad = "yoy_pp", n_pares = nrow(x),
               rmse = sqrt(mean(x$e^2)) + if (alterar_rmse) 0.01 else 0, mae = mean(abs(x$e)), crps = if (x$m[1] == "BENCH.RW_SIN_DERIVA") NA else 1,
               cobertura_80 = 0.8, cobertura_95 = 0.95)))
  utils::write.csv(met, file.path(d, "metricas.csv"), row.names = FALSE)
  mcs <- data.frame(exp_id = exp_id, grupo = "G9", h = met$h, unidad = "yoy_pp", modelo_id = met$modelo_id,
                    p_mcs = 0.5, en_mcs = met$modelo_id != "UNI.ARIMA")
  utils::write.csv(mcs, file.path(d, "mcs.csv"), row.names = FALSE)
}
.obj_ap4 <- function() {
  per <- ind_a_q(q_a_ind("2000-Q1") + 0:120)
  set.seed(1); data.frame(periodo = per, y = 4 + cumsum(0.005 + stats::rnorm(length(per), 0, 0.01)), stringsAsFactors = FALSE)
}

test_that("AP-4: familia por prefijo y representantes de Harold por grupo", {
  expect_identical(familia_de(c("BENCH.ARP_BIC", "MULT.VAR_DIF.G1", "COMB.MEDIA.G3")), c("BENCH", "MULT", "COMB"))
  expect_identical(representantes_grupo("G2"), c("BENCH.RW_SIN_DERIVA", "UNI.ARIMA", "MULT.VAR_DIF.G2", "REG.ENET.G2",
                                                 "MIX.PUENTE.G2", "ML.RF.G2", "COMB.MEDIA.G2"))
  expect_setequal(familia_de(representantes_grupo("G1")), FAMILIAS_AP4)
})

test_that("AP-4: los errores reconstruidos tienen que dar las métricas de L4; extremos y resumen por familia", {
  raiz <- tempfile("l4_"); on.exit(unlink(raiz, recursive = TRUE)); obj <- .obj_ap4()
  .l4_ap4(raiz, "F5_G9", obj)
  mb <- miembros_experimento("F5_G9", "G9", obj, dir_l4 = raiz)
  expect_identical(nrow(mb), 3L * 4L)
  expect_true(all(mb$rmse_recortado <= mb$rmse + 1e-12) && all(mb$max_abs_error >= mb$mae))
  expect_identical(mb$n_pares, rep(20L, 12))
  fa <- familias_desde_miembros(mb)
  expect_identical(nrow(fa), 3L * 4L)
  expect_identical(unique(fa$familia), c("BENCH", "UNI", "MIX"))
  expect_true(all(is.na(fa$crps_mediana[fa$familia == "BENCH"])))
  expect_identical(fa$prop_en_mcs[fa$familia == "UNI"], rep(0, 4))
  .l4_ap4(raiz, "F5_G8", obj, alterar_rmse = TRUE)
  expect_error(miembros_experimento("F5_G8", "G9", obj, dir_l4 = raiz), "no dan el RMSE/MAE")
})
