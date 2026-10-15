# tests/test-tabla-pruebas.R
#
# Tabla de pruebas de Fase 5 (remediación del hallazgo I3 de la auditoría independiente de Fase 5): armado sobre
# directorios de L4 sintéticos con manifiesto, verificación de los sha256 contra el manifiesto, marca_n por celda y
# extracto de pronósticos. No lee datos del proyecto: corre en CI.

library(testthat)
source(here::here("src", "evaluacion", "tabla_pruebas_fase5.R"))

.escribir <- function(df, ruta) { con <- file(ruta, open = "wb"); utils::write.csv(df, con, row.names = FALSE, na = "", eol = "\n"); close(con) }

.l4_pruebas <- function(raiz, exp_id, grupo, n = 20L, sub = FALSE, estab = FALSE, commit = "e1722fa0000000000000000000000000000000aa", arbol = "limpio",
                        alterar = NULL) {
  d <- file.path(raiz, exp_id); dir.create(d, recursive = TRUE)
  mods <- c("M.A", "M.B"); hs <- c(1L, 8L)
  fila <- function(h, prueba, m) data.frame(exp_id = exp_id, grupo = grupo, h = h, unidad = c("yoy_pp", "qoq_pp"),
    prueba = prueba, modelo_a = "BENCH.RW_SIN_DERIVA", modelo_b = m, estadistico = 1.5, p_valor = 0.2,
    n_pares = if (prueba == "gw") n - h else n, varianza = if (prueba == "gw") "bartlett" else "rectangular",
    media_diferencial = 0.1, marca_tamano = if (prueba == "gw") "tamano_no_verificado" else if (h >= 4) "distorsion_tamano_documentada" else "",
    stringsAsFactors = FALSE)
  pr <- do.call(rbind, c(lapply(hs, function(h) do.call(rbind, lapply(mods, function(m) rbind(fila(h, "dm_hln", m), fila(h, "gw", m)))))))
  arch <- list(pruebas.csv = pr)
  if (sub) arch$pruebas_submuestras.csv <- do.call(rbind, lapply(c("pre2020", "sin_2020_2021"), function(ms) {
    x <- pr; x$n_pares <- ifelse(x$prueba == "gw", 17L - x$h, 17L); cbind(muestra_eval = ms, x) }))
  if (estab) arch$estabilidad.csv <- data.frame(exp_id = exp_id, grupo = grupo, h = 1L, unidad = "yoy_pp",
    modelo_a = "BENCH.RW_SIN_DERIVA", modelo_b = mods, media_pre = 0.1, cambio_post = 0.2, ee_hac = 0.3, estadistico = 0.5,
    p_valor = 0.6, n_pre = 28L, n_post = 24L, marca_tamano = "tamano_no_verificado", stringsAsFactors = FALSE)
  arch$pronosticos.csv <- data.frame(exp_id = exp_id, modelo_id = rep(mods, each = 4), grupo = grupo,
    origen = rep(c("2020-Q2", "2021-Q1"), 4), h = rep(c(4L, 4L, 8L, 8L), 2), periodo_objetivo = "2023-Q1",
    log_nivel_pronosticado = 4.6, yoy_pp_pronosticado = c(1, -348, 2, 3, -126, 1, 2, 2), qoq_pp_pronosticado = 0.5,
    vintage_id_objetivo = "SINT.v1", stringsAsFactors = FALSE)
  sha <- character(0)
  for (nm in names(arch)) { .escribir(arch[[nm]], file.path(d, nm)); sha[[nm]] <- digest::digest(file = file.path(d, nm), algo = "sha256") }
  if (!is.null(alterar)) cat("x\n", file = file.path(d, alterar), append = TRUE)   # cambia el archivo después de hashearlo
  writeLines(c(paste0("exp_id: ", exp_id), paste0("commit_hash: ", commit), paste0("arbol: ", arbol), "",
               "salidas (sha256):", paste0("  ", names(sha), "  ", sha), "", "sessionInfo():", "R version 4.6.1"),
             file.path(d, "manifiesto.txt"))
  invisible(d)
}

.exps <- function(ids, r3 = FALSE, r4 = FALSE) data.frame(exp_id = ids, r3 = r3, r4 = r4, stringsAsFactors = FALSE)
.C <- "e1722fa0000000000000000000000000000000aa"
.com <- function(ids) stats::setNames(rep(.C, length(ids)), ids)

test_that("tabla de pruebas: unidad primaria, submuestras como R3/R4, estabilidad y marca_n por celda (no por fila)", {
  raiz <- tempfile("l4_"); on.exit(unlink(raiz, recursive = TRUE))
  .l4_pruebas(raiz, "F5_G1", "G1", n = 20L, sub = TRUE, estab = TRUE)
  .l4_pruebas(raiz, "F5_G3_R1", "G3", n = 18L)
  tabs <- armar_tablas_pruebas_fase5(raiz, rbind(.exps("F5_G1", r3 = TRUE, r4 = TRUE), .exps("F5_G3_R1")),
                                     commits = .com(c("F5_G1", "F5_G3_R1")))
  t <- tabs$pruebas
  expect_identical(names(t), COLUMNAS_PRUEBAS_F5)
  expect_true(all(t$unidad == "yoy_pp"))
  expect_setequal(unique(t$variante), c("principal", "R3", "R4", "R1"))
  # En F5_G3_R1 la celda tiene n = 18 (en el piso): sin marca, aunque GW en h = 8 tenga n_pares = 10.
  r1 <- t[t$exp_id == "F5_G3_R1", ]
  expect_true(any(r1$prueba == "gw" & r1$n_pares < N_MIN_CALIBRADO_MCS))
  expect_true(all(r1$marca_n == ""))
  # Submuestras con n = 17: marcadas.
  expect_true(all(t$marca_n[t$muestra_eval != "completa"] == MARCA_N_BAJO))
  expect_identical(nrow(tabs$estabilidad), 2L)
  expect_identical(names(tabs$estabilidad), COLUMNAS_ESTABILIDAD_F5)
  # Escritura en LF y estable.
  f <- tempfile(fileext = ".csv"); escribir_tabla_resultados(t, f)
  expect_false(any(readBin(f, "raw", file.size(f)) == as.raw(13L)))
})

test_that("tabla de pruebas: guardas de manifiesto, commit, árbol, sha256 y declaración r3/r4", {
  raiz <- tempfile("l4_"); on.exit(unlink(raiz, recursive = TRUE))
  .l4_pruebas(raiz, "F5_G1", "G1", alterar = "pruebas.csv")
  expect_error(armar_tablas_pruebas_fase5(raiz, .exps("F5_G1"), commits = .com("F5_G1")), "no coincide con su manifiesto")
  .l4_pruebas(raiz, "F5_G2", "G2", commit = "abc1234")
  expect_error(armar_tablas_pruebas_fase5(raiz, .exps("F5_G2"), commits = .com("F5_G2")), "no de la corrida")
  .l4_pruebas(raiz, "F5_G3", "G3", arbol = "sucio")
  expect_error(armar_tablas_pruebas_fase5(raiz, .exps("F5_G3"), commits = .com("F5_G3")), "árbol limpio")
  .l4_pruebas(raiz, "F5_G1_R6", "G1")
  expect_error(armar_tablas_pruebas_fase5(raiz, .exps("F5_G1_R6", r4 = TRUE), commits = .com("F5_G1_R6")), "submuestras")
  expect_error(armar_tablas_pruebas_fase5(raiz, .exps("F5_G2_R6"), commits = .com("F5_G2_R6")), "falta el directorio")
})

test_that("extracto de pronósticos: corte transversal completo de los orígenes y horizontes citados", {
  raiz <- tempfile("l4_"); on.exit(unlink(raiz, recursive = TRUE))
  .l4_pruebas(raiz, "F5_G3", "G3")
  e <- armar_extracto_pronosticos_fase5(raiz, commits = .com("F5_G3"))
  expect_identical(names(e), COLUMNAS_EXTRACTO_F5)
  expect_identical(nrow(e), 8L)                        # 2 modelos × 2 orígenes × 2 horizontes
  expect_true(-348 %in% e$yoy_pp_pronosticado)
  expect_error(armar_extracto_pronosticos_fase5(raiz, citas = data.frame(exp_id = "F5_G3", origen = "2019-Q1"), commits = .com("F5_G3")), "orígenes citados")
})

test_that("commits registrados: uno por experimento, leído de 07_experimentos.csv", {
  f <- tempfile(fileext = ".csv"); on.exit(unlink(f))
  .escribir(data.frame(exp_id = c("F5_G1__M.A", "F5_G1__M.B", "F5_G1_R1__M.A", "F5_G2__M.A", "F5_G2__M.B"),
                       commit_hash = c("aaa", "aaa", "bbb", "ccc", "ddd"), stringsAsFactors = FALSE), f)
  expect_identical(unname(commits_registrados(c("F5_G1", "F5_G1_R1"), f)), c("aaa", "bbb"))
  expect_error(commits_registrados("F5_G2", f), "único commit")
  expect_error(commits_registrados("F5_G3", f), "único commit")
})

test_that("contraste de marca_n contra la tabla de resultados", {
  p <- data.frame(exp_id = "F5_G1", muestra_eval = c("completa", "pre2020"), h = 1L, marca_n = c("", MARCA_N_BAJO), stringsAsFactors = FALSE)
  r <- data.frame(exp_id = "F5_G1", muestra_eval = c("completa", "pre2020"), h = 1L, marca_n = c(NA, MARCA_N_BAJO), stringsAsFactors = FALSE)
  expect_true(contrastar_marca_n(p, r))
  r$marca_n[2] <- NA
  expect_error(contrastar_marca_n(p, r), "no coincide")
})
