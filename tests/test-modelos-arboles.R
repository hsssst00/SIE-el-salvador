# tests/test-modelos-arboles.R
#
# Árboles de Fase 5, bloque B4 (F5-10, F5-11, F5-12, F5-15 y B4-1 a B4-6 de doc/metodologia/decisiones_fase5.md), con
# datos SINTÉTICOS: no se lee data/. Comprueba el registro por grupo, las rejillas de B4-3 y B4-4 (con la deduplicación
# de mtry en G1), el pronóstico del RF contra ranger y el de LightGBM contra lightgbm llamados directamente con la
# semilla del generador de R, que el pronóstico de un candidato no depende de qué otros se piden, que con 9 filas
# LightGBM no parte y pronostica la media, las guardas de B3-7, que los dos corren en el primer origen de cada grupo con
# las fechas de inicio de L3 (9 filas en la ventana interna más chica de G2 y G3 a h = 8, B3-4), sus diagnósticos y que
# reejecutar con la misma semilla del motor reproduce bit a bit.
#
# Costo (sandbox Windows): LightGBM de producción cuesta unos 70 s por origen. En el primer origen corre con la
# configuración de producción en G2 y con 50 rondas como máximo en G1 y G3; la prueba de reproducibilidad usa 100 árboles
# y 20 rondas. Lo que se prueba ahí (filas, guardas, semilla) no depende del número de árboles ni de rondas.

library(testthat)
source(here::here("src", "evaluacion", "motor_backtesting.R"))   # eval_lib, modelos_referencia, modelos_fase5

.INICIOS_L3_AR <- c("BCR.REMESAS.NOM.NSA.Q" = "1991-Q1", "BCR.EXPORT_FOB.NOM.NSA.Q" = "1994-Q1", "BCR.ITCER.IDX.NSA.Q" = "2000-Q1",
                    "UT.DEMANDA_ELEC.GWH.NSA.Q" = "2002-Q1", "BCR.IVAE.VOL.SA.Q" = "2005-Q1", "BCR.IPM.IDX.NSA.Q" = "2005-Q1",
                    "BCR.IPP.IDX.NSA.Q" = "2010-Q1", "BCR.REMESAS.REAL.NSA.Q" = "2010-Q1")
.objetivo_ar <- function(semilla) {
  set.seed(semilla)
  per <- ind_a_q(q_a_ind("1990-Q1") + 0:144)
  data.frame(periodo = per, y = 4 + cumsum(0.005 + as.numeric(stats::arima.sim(list(ar = 0.3), length(per), sd = 0.01))), stringsAsFactors = FALSE)
}
.predictoras_ar <- function(semilla, ids = names(.INICIOS_L3_AR), hasta = "2026-Q2") {
  set.seed(semilla)
  stats::setNames(lapply(ids, function(id) {
    i <- q_a_ind(.INICIOS_L3_AR[[id]]):q_a_ind(hasta)
    est <- if (grepl(".NSA.", id, fixed = TRUE)) 0.03 * sin(pi * (i %% 4L) / 2) else 0
    data.frame(periodo = ind_a_q(i), valor = 100 * exp(cumsum(0.004 + stats::rnorm(length(i), 0, 0.02)) + est), stringsAsFactors = FALSE)
  }), ids)
}
.ventana_ar <- function(semilla, n = 40L, p = 28L) {
  set.seed(semilla)
  Z <- scale(matrix(stats::rnorm(n * p), n), scale = FALSE); Z <- sweep(Z, 2L, sqrt(colMeans(Z^2)), "/")
  colnames(Z) <- paste0("c", seq_len(p))
  g <- as.numeric(0.02 * abs(Z[, 1]) - 0.01 * Z[, 2] + stats::rnorm(n, 0, 0.01)) + 0.01
  list(Z = Z, g = g, z = matrix(stats::rnorm(p), 1L, dimnames = list(NULL, colnames(Z))))
}
.parametros_lgbm_directos <- function(nl, semilla) list(objective = "regression", num_leaves = nl, learning_rate = 0.05, min_data_in_leaf = 5L,
                                                     num_threads = 1L, deterministic = TRUE, force_row_wise = TRUE, seed = semilla, verbose = -1L)

test_that("F5-10, B1b-2: registro de los árboles por grupo bajo el contrato, después de los regularizados", {
  for (g in c("G1", "G2", "G3")) {
    ids <- vapply(modelos_fase5(g), `[[`, character(1), "modelo_id")
    expect_identical(ids[startsWith(ids, "ML.")], paste0(c("ML.RF.", "ML.LGBM."), g), info = g)
    expect_gt(min(which(startsWith(ids, "ML."))), max(which(startsWith(ids, "REG."))))
    for (m in modelos_arboles_grupo(g)) {
      expect_silent(.validar_modelo(m))
      expect_false(m$piso_gl, info = m$modelo_id)                                   # F5-10
      expect_identical(m$requiere, c("objetivo", predictoras_grupo(g)), info = m$modelo_id)   # B1b-2: todas
      expect_true(is.function(m$predecir_densidad) && is.function(m$diagnosticar), info = m$modelo_id)
      expect_true(m$esp$transformar, info = m$modelo_id)                             # B4-1
    }
  }
  expect_true("BCR.REMESAS.REAL.NSA.Q" %in% modelo_rf_grupo("G3")$requiere)
  expect_identical(c(NUM_ARBOLES_RF, NODO_MIN_RF, HOJAS_LGBM, TASA_LGBM, DATOS_HOJA_LGBM, RONDAS_MAX_LGBM, PASO_RONDAS_LGBM),
                   c(500, 5, 3, 4, 8, 0.05, 5, 500, 10))
  expect_identical(modelo_rf_grupo("G1")$esp$num_arboles, 500L)
  expect_identical(c(modelo_lgbm_grupo("G1")$esp$rondas_max, modelo_lgbm_grupo("G1")$esp$paso_rondas), c(500L, 10L))
  expect_error(modelos_arboles_grupo("G4"), "grupo no declarado")
})

test_that("B4-3, B4-4: rejillas de más a menos regularizado; en G1 mtry se deduplica", {
  expect_identical(mtry_rf(12), 4L)                                                 # ⌈√12⌉ = ⌈12/3⌉ = 4
  expect_identical(mtry_rf(28), c(6L, 10L))
  expect_identical(mtry_rf(36), c(6L, 12L))
  r1 <- rejilla_rf(matrix(0, 2, 12), 0, 1L)
  expect_identical(r1, data.frame(min_node_size = c(5L, 3L), mtry = c(4L, 4L)))
  r2 <- rejilla_rf(matrix(0, 2, 28), 0, 1L)
  expect_identical(r2, data.frame(min_node_size = c(5L, 5L, 3L, 3L), mtry = c(6L, 10L, 6L, 10L)))
  rl <- rejilla_lgbm(matrix(0, 2, 28), 0, 1L)
  expect_identical(nrow(rl), 100L)
  expect_identical(unlist(rl[c(1, 50, 51, 100), ], use.names = FALSE), c(4L, 4L, 8L, 8L, 10L, 500L, 10L, 500L))
  expect_identical(unique(rl$rondas), seq.int(10L, 500L, by = 10L))
  expect_error(mtry_rf(0), "número de columnas no válido")
})

test_that("F5-10, F5-15: el RF pronostica lo mismo que ranger con la semilla del generador de R, sin depender de los otros candidatos", {
  v <- .ventana_ar(1)
  rj <- rejilla_rf(v$Z, v$g, 1L)
  set.seed(11); todos <- estimar_predecir_rf(v$Z, v$g, v$z, rj, seq_len(nrow(rj)))
  set.seed(11); semilla <- sample.int(.Machine$integer.max, 1L)
  for (j in seq_len(nrow(rj))) {
    f <- ranger::ranger(x = v$Z, y = v$g, num.trees = 500L, mtry = rj$mtry[j], min.node.size = rj$min_node_size[j], num.threads = 1L, seed = semilla)
    expect_identical(todos[j], stats::predict(f, data = v$z, num.threads = 1L)$predictions, info = j)
  }
  set.seed(11); expect_identical(estimar_predecir_rf(v$Z, v$g, v$z, rj, c(3L, 1L)), todos[c(3L, 1L)])
  set.seed(12); expect_false(identical(estimar_predecir_rf(v$Z, v$g, v$z, rj, 1L), todos[1]))   # otra semilla, otro bosque
  # dos filas nuevas: un pronóstico por fila y candidato, por candidato
  z2 <- rbind(v$z, -v$z)
  set.seed(11); p2 <- estimar_predecir_rf(v$Z, v$g, z2, rj, 1:2)
  expect_identical(p2[c(1, 3)], todos[1:2])
})

test_that("F5-10, B4-4: LightGBM pronostica lo mismo que lightgbm con la semilla del generador de R, en cada número de rondas", {
  v <- .ventana_ar(2)
  rj <- rejilla_lgbm(v$Z, v$g, 1L)
  set.seed(21); todos <- estimar_predecir_lgbm(v$Z, v$g, v$z, rj, seq_len(nrow(rj)))
  set.seed(21); semilla <- sample.int(.Machine$integer.max, 1L)
  for (nl in HOJAS_LGBM) {
    ds <- lightgbm::lgb.Dataset(v$Z, label = v$g, params = list(min_data_in_leaf = 5L, verbose = -1L))
    b <- lightgbm::lgb.train(params = .parametros_lgbm_directos(nl, semilla), data = ds, nrounds = 500L, verbose = -1L)
    esperado <- vapply(seq.int(10L, 500L, by = 10L), function(r) stats::predict(b, v$z, num_iteration = r), numeric(1))
    expect_identical(todos[rj$num_leaves == nl], esperado, info = nl)
  }
  expect_gt(length(unique(todos)), 50L)                                              # con 40 filas las rondas importan
  sub <- c(73L, 7L, 55L)                                                             # entrena solo hasta la mayor ronda pedida
  set.seed(21); expect_identical(estimar_predecir_lgbm(v$Z, v$g, v$z, rj, sub), todos[sub])
  set.seed(99); expect_identical(estimar_predecir_lgbm(v$Z, v$g, v$z, rj, sub), todos[sub])   # sin componente aleatorio
})

test_that("B4-4, B3-7: con 9 filas LightGBM no parte y pronostica la media; las guardas detienen el motor", {
  v <- .ventana_ar(3, n = 9L, p = 36L)                                                # G2 y G3 a h = 8 en el primer origen
  rj <- rejilla_lgbm(v$Z, v$g, 8L)
  set.seed(31); p <- estimar_predecir_lgbm(v$Z, v$g, v$z, rj, seq_len(nrow(rj)))
  expect_identical(length(unique(p)), 1L)
  expect_equal(p[1], mean(v$g), tolerance = 1e-6)                                    # etiquetas en precisión simple
  set.seed(32); prf <- estimar_predecir_rf(v$Z, v$g, v$z, rejilla_rf(v$Z, v$g, 8L), 1:4)
  expect_true(all(is.finite(prf)))
  registerS3method("predict", "rf_de_prueba", function(object, ...) list(predictions = NaN))
  registerS3method("predict", "lgbm_de_prueba", function(object, newdata, ...) rep(NaN, nrow(newdata)))
  local_mocked_bindings(ranger = function(...) structure(list(num.trees = 10L), class = "rf_de_prueba"), .package = "ranger")
  expect_error(estimar_predecir_rf(v$Z, v$g, v$z, rejilla_rf(v$Z, v$g, 8L), 1L), "ranger devolvió 10 árboles y se pidieron 500 \\(B3-7\\)")
  local_mocked_bindings(ranger = function(...) structure(list(num.trees = 500L), class = "rf_de_prueba"), .package = "ranger")
  expect_error(estimar_predecir_rf(v$Z, v$g, v$z, rejilla_rf(v$Z, v$g, 8L), 1L), "ML.RF: pronósticos no finitos con mtry = 6 y min.node.size = 5 \\(B3-7\\)")
  local_mocked_bindings(lgb.train = function(...) list(current_iter = function() 0L), .package = "lightgbm")
  expect_error(estimar_predecir_lgbm(v$Z, v$g, v$z, rj, 1L), "con num_leaves = 4 no dejó ninguna ronda \\(B3-7\\)")
  local_mocked_bindings(lgb.train = function(...) structure(list(current_iter = function() 10L), class = "lgbm_de_prueba"), .package = "lightgbm")
  expect_error(estimar_predecir_lgbm(v$Z, v$g, v$z, rj, 51L), "ML.LGBM: pronósticos no finitos con num_leaves = 8 y 10 rondas \\(B3-7\\)")
})

test_that("B4-1, B3-4, B3-7: RF y LightGBM corren en el primer origen de cada grupo con las fechas de inicio de L3", {
  obj <- .objetivo_ar(5); pred <- .predictoras_ar(6)
  for (g in c("G1", "G2", "G3")) {
    o1 <- origenes_grupo(g)[1]; ids <- predictoras_grupo(g)
    lgbm <- if (g == "G2") modelo_lgbm_grupo(g) else modelo_directo(paste0("ML.LGBM.", g), ids, especificacion_lgbm(rondas_max = 50L))
    r <- correr_backtest(c(list(objetivo = obj), pred[ids]), list(modelo_rf_grupo(g), lgbm), o1, rezagos = rezagos_predictoras(ids), densidad = TRUE)
    expect_identical(nrow(r), 16L, info = g)
    expect_true(all(is.finite(r$sd_log_nivel)) && all(r$sd_log_nivel > 0), info = g)
    d <- attr(r, "diagnosticos")
    rf <- d[d$modelo_id == paste0("ML.RF.", g), ]; lg <- d[d$modelo_id == paste0("ML.LGBM.", g), ]
    p <- rf$valor[rf$clave == "n_columnas"]
    expect_identical(p, c(G1 = 12, G2 = 28, G3 = 36)[[g]], info = g)
    expect_true(all(c(paste0("h", 1:8, ".mtry"), paste0("h", 1:8, ".min_node_size")) %in% rf$clave), info = g)
    expect_true(all(rf$valor[grepl("\\.mtry$", rf$clave)] %in% mtry_rf(p)), info = g)
    expect_true(all(rf$valor[grepl("\\.min_node_size$", rf$clave)] %in% NODO_MIN_RF), info = g)
    expect_true(all(c(paste0("h", 1:8, ".num_leaves"), paste0("h", 1:8, ".rondas"), paste0("h", 1:8, ".borde")) %in% lg$clave), info = g)
    expect_true(all(lg$valor[grepl("\\.num_leaves$", lg$clave)] %in% HOJAS_LGBM), info = g)
    for (dd in list(rf, lg)) expect_identical(dd$valor[dd$clave == "h8.n_filas_min"], c(G1 = 46, G2 = 9, G3 = 9)[[g]], info = g)
  }
})

test_that("F5-15: reejecutar con la misma semilla del motor reproduce bit a bit; otra semilla cambia el RF y no LightGBM", {
  obj <- .objetivo_ar(7); pred <- .predictoras_ar(8)
  ids <- predictoras_grupo("G2"); org <- origenes_grupo("G2")[c(3, 9)]
  ms <- list(modelo_directo("ML.RF.G2", ids, especificacion_rf(num_arboles = 100L)),
             modelo_directo("ML.LGBM.G2", ids, especificacion_lgbm(rondas_max = 20L)))
  datos <- c(list(objetivo = obj), pred[ids])
  a <- correr_backtest(datos, ms, org, rezagos = rezagos_predictoras(ids), densidad = TRUE, exp_id = "A")
  b <- correr_backtest(datos, ms, org, rezagos = rezagos_predictoras(ids), densidad = TRUE, exp_id = "A")
  expect_identical(a, b)                                                             # sendero, densidad y diagnósticos
  c_ <- correr_backtest(datos, ms, org[1], rezagos = rezagos_predictoras(ids), densidad = TRUE, exp_id = "B")
  en_a <- function(id) a$log_nivel_pronosticado[a$modelo_id == id & a$origen == org[1]]
  expect_false(identical(c_$log_nivel_pronosticado[c_$modelo_id == "ML.RF.G2"], en_a("ML.RF.G2")))       # la semilla llega a ranger
  expect_identical(c_$log_nivel_pronosticado[c_$modelo_id == "ML.LGBM.G2"], en_a("ML.LGBM.G2"))         # B4-4: sin componente aleatorio
})
