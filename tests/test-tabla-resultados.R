# tests/test-tabla-resultados.R
#
# Tabla de resultados de Fase 4 (E4/E5, F4-30): etiquetas de variante sobre los experimentos
# declarados en el motor, y armado de la tabla larga sobre directorios de L4 sintéticos, con sus
# guardas. No lee datos del proyecto: corre en CI.

library(testthat)
source(here::here("src", "evaluacion", "tabla_resultados_fase4.R"))

.l4_sintetico <- function(raiz, exp_id, grupo, submuestras = FALSE, quitar_mcs = FALSE, n_pares = 10L) {
  d <- file.path(raiz, exp_id); dir.create(d, recursive = TRUE)
  mods <- c("M.A", "M.B"); hs <- c(1L, 2L)
  g <- expand.grid(modelo_id = mods, h = hs, unidad = c("yoy_pp", "qoq_pp"), stringsAsFactors = FALSE)
  met <- data.frame(exp_id = exp_id, modelo_id = g$modelo_id, grupo = grupo, h = g$h, unidad = g$unidad, n_pares = n_pares,
                    rmse = seq_len(nrow(g)) / 10, mae = seq_len(nrow(g)) / 20, rmse_relativo = 1, sesgo = 0, sesgo_ee_nw = 0.1,
                    cobertura_80 = NA, cobertura_95 = NA, crps = NA, stringsAsFactors = FALSE)
  gm <- expand.grid(modelo_id = mods, h = hs, stringsAsFactors = FALSE)
  mcs <- data.frame(exp_id = exp_id, grupo = grupo, h = gm$h, unidad = "yoy_pp", modelo_id = gm$modelo_id, p_mcs = 0.5,
                    en_mcs = TRUE, orden_eliminacion = NA, alpha = 0.1, replicas = 99L, bloque = 3L, semilla = 1L,
                    marca_tamano = "", stringsAsFactors = FALSE)
  if (quitar_mcs) mcs <- mcs[-1, ]
  utils::write.csv(met, file.path(d, "metricas.csv"), row.names = FALSE, na = "")
  utils::write.csv(mcs, file.path(d, "mcs.csv"), row.names = FALSE, na = "")
  if (submuestras) {
    ms <- c("pre2020", "sin_2020")
    utils::write.csv(do.call(rbind, lapply(ms, function(m) cbind(muestra_eval = m, met))), file.path(d, "metricas_submuestras.csv"), row.names = FALSE, na = "")
    utils::write.csv(do.call(rbind, lapply(ms, function(m) cbind(muestra_eval = m, mcs))), file.path(d, "mcs_submuestras.csv"), row.names = FALSE, na = "")
  }
  invisible(d)
}

test_that("variantes de los 13 experimentos declarados en el motor", {
  v <- vapply(seq_len(nrow(EXPERIMENTOS)), function(k) variante_de(EXPERIMENTOS[k, ]), character(1))
  expect_identical(as.vector(table(factor(v, VARIANTES_ORDEN))), c(3L, 3L, 2L, 0L, 0L, 2L, 3L))
  expect_identical(v[EXPERIMENTOS$exp_id == "F4_BENCH_G2_R5"], "R5")
})

test_that("tabla larga: unidad primaria, submuestras etiquetadas como R3/R4 y orden estable", {
  raiz <- tempfile("l4_"); on.exit(unlink(raiz, recursive = TRUE))
  .l4_sintetico(raiz, "X_G1", "G1", submuestras = TRUE)
  .l4_sintetico(raiz, "X_G1_R1", "G1")
  exps <- rbind(.exp("X_G1", "G1", r3 = TRUE, r4 = TRUE), .exp("X_G1_R1", "G1", ventana = "rodante92"))
  t <- armar_tabla_resultados(raiz, exps)
  expect_identical(nrow(t), 4L + 2L * 4L + 4L)                                 # completa + 2 submuestras + R1
  expect_identical(unique(t$unidad), "yoy_pp")
  expect_identical(unique(t$variante), c("principal", "R1", "R3", "R4"))
  expect_identical(unique(t$exp_id[t$variante %in% c("R3", "R4")]), "X_G1")
  expect_true(is.logical(t$en_mcs))
  expect_identical(names(t)[c(1, 2, 12)], c("variante", "muestra_eval", "en_mcs"))
  expect_identical(names(t)[14:15], c("marca_tamano", "marca_n"))
  expect_equal(t$rmse[t$variante == "principal" & t$h == 1 & t$modelo_id == "M.A"], 0.1)
  f <- tempfile(fileext = ".csv"); escribir_tabla_resultados(t, f)
  expect_false(any(readBin(f, "raw", file.info(f)$size) == as.raw(13L)))       # LF
})

test_that("guardas: directorio faltante, MCS incompleto y submuestras no declaradas", {
  raiz <- tempfile("l4_"); on.exit(unlink(raiz, recursive = TRUE))
  .l4_sintetico(raiz, "X_G1", "G1", submuestras = TRUE)
  .l4_sintetico(raiz, "X_G2", "G2", quitar_mcs = TRUE)
  expect_error(armar_tabla_resultados(raiz, .exp("X_G3", "G3")), "falta el directorio")
  expect_error(armar_tabla_resultados(raiz, .exp("X_G2", "G2")), "no casan")
  expect_error(armar_tabla_resultados(raiz, .exp("X_G1", "G1")), "no son las declaradas")
})
test_that("marca_n: n_bajo_calibracion bajo el piso de V9 (F4-35), vacía en el piso y encima", {
  raiz <- tempfile("l4_"); on.exit(unlink(raiz, recursive = TRUE))
  .l4_sintetico(raiz, "X_G1", "G1", n_pares = 10L)
  .l4_sintetico(raiz, "X_G2", "G2", n_pares = 18L)
  t <- armar_tabla_resultados(raiz, rbind(.exp("X_G1", "G1"), .exp("X_G2", "G2")))
  expect_identical(N_MIN_CALIBRADO_MCS, 18L)
  expect_true(all(t$marca_n[t$n_pares == 10L] == "n_bajo_calibracion"))
  expect_true(all(t$marca_n[t$n_pares == 18L] == ""))
  f <- tempfile(fileext = ".csv"); escribir_tabla_resultados(t, f)
  r <- utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "NA")
  expect_identical(names(r)[ncol(r)], "marca_n")
  expect_identical(sum(r$marca_n == "n_bajo_calibracion", na.rm = TRUE), 4L)
})
