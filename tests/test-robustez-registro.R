# tests/test-robustez-registro.R
#
# Piezas del bloque E de Fase 4 que viven en eval_lib.R y no necesitan X-13 ni datos del proyecto:
# ventana rodante de R1 (F4-26), contraste de estabilidad y submuestras de R3/R4 (F4-28, F4-29),
# evaluación de un conjunto de errores (la misma para la muestra completa y las submuestras) y
# filas de catalogos/07_experimentos.csv (F4-25), más la integridad referencial de 07 contra
# 06_modelos y 08_vintages. Corre en CI.

library(testthat)
source(here::here("src", "evaluacion", "eval_lib.R"))

.serie <- function(n, inicio = "1990-Q1") {
  i0 <- q_a_ind(inicio)
  data.frame(periodo = ind_a_q(i0 + seq_len(n) - 1L), y = log(100) + 0.01 * seq_len(n), stringsAsFactors = FALSE)
}

test_that("R1: la ventana rodante conserva los últimos 92 períodos y falla si no alcanzan", {
  d <- .serie(93)
  r <- recortar_ventana_rodante(d, 92L)
  expect_identical(nrow(r), 92L)
  expect_identical(r$periodo[1], "1990-Q2")
  expect_identical(r$periodo[92], d$periodo[93])
  expect_identical(rownames(r), as.character(1:92))
  expect_error(recortar_ventana_rodante(.serie(91), 92L), "91 obs")
})

test_that("R3: el contraste de estabilidad reproduce medias por submuestra y la varianza HC0 con h = 1", {
  set.seed(1)
  e1 <- rnorm(30); e2 <- rnorm(30, sd = 0.8); post <- rep(0:1, c(18, 12))
  r <- prueba_cambio_diferencial(e1, e2, post, 1L)
  d <- e1^2 - e2^2
  expect_equal(r$media_pre, mean(d[post == 0]))
  expect_equal(r$cambio_post, mean(d[post == 1]) - mean(d[post == 0]))
  # Con un regresor binario, la varianza HC0 del coeficiente es la suma de las de las dos medias.
  u <- d - ifelse(post == 1, mean(d[post == 1]), mean(d[post == 0]))
  ee <- sqrt(sum(u[post == 0]^2) / 18^2 + sum(u[post == 1]^2) / 12^2)
  expect_equal(r$ee_hac, ee)
  expect_equal(r$p_valor, 2 * pt(-abs(r$cambio_post / ee), df = 28))
  expect_equal(c(r$n_pre, r$n_post), c(18, 12))
})

test_that("R3: con h > 1 el HAC suma autocovarianzas y las guardas fallan", {
  set.seed(2)
  e1 <- rnorm(40); e2 <- rnorm(40); post <- rep(0:1, each = 20)
  r1 <- prueba_cambio_diferencial(e1, e2, post, 1L)
  r4 <- prueba_cambio_diferencial(e1, e2, post, 4L)
  expect_equal(r4$cambio_post, r1$cambio_post)
  expect_false(isTRUE(all.equal(r4$ee_hac, r1$ee_hac)))
  expect_error(prueba_cambio_diferencial(e1[1:22], e2[1:22], rep(0:1, c(20, 2)), 1L), "3 pares por submuestra")
  expect_error(prueba_cambio_diferencial(e1, e2, rep(2, 40), 1L), "0/1")
  expect_error(prueba_cambio_diferencial(e1, e2, post[-1], 1L), "largos distintos")
})

test_that("R3/R4: submuestras de targets con los orígenes de G1 y h = 1", {
  t <- origenes_grupo("G1") + 1L
  t <- t[t <= q_a_ind("2026-Q1")]
  expect_identical(length(t), 52L)
  n <- vapply(SUBMUESTRAS_FASE4, function(f) sum(f(t)), numeric(1))
  expect_identical(unname(n), c(27, 25, 48, 44))
  expect_identical(names(n), c("pre2020", "post2020", "sin_2020", "sin_2020_2021"))
  expect_true(all(SUBMUESTRAS_FASE4$pre2020(t) != SUBMUESTRAS_FASE4$post2020(t)))
})

.errores_sinteticos <- function(n_orig = 24L) {
  set.seed(3)
  ob <- .serie(80, "2000-Q1")
  ob$y <- ob$y + cumsum(rnorm(80, sd = 0.005))
  origenes <- q_a_ind("2005-Q1") + seq_len(n_orig) - 1L
  pr <- do.call(rbind, lapply(origenes, function(o) {
    y0 <- ob$y[q_a_ind(ob$periodo) == o]
    rbind(data.frame(modelo_id = "M.BENCH", origen = o, h = 1:8, log_nivel_pronosticado = rep(y0, 8), stringsAsFactors = FALSE),
          data.frame(modelo_id = "M.OTRO", origen = o, h = 1:8, log_nivel_pronosticado = y0 + 0.01 * (1:8), stringsAsFactors = FALSE))
  }))
  calcular_errores(pr, ob)
}

test_that("evaluar_errores: tablas completas, GW opcional y MCS reproducible por semilla", {
  err <- .errores_sinteticos()
  ids <- c("M.BENCH", "M.OTRO")
  a <- evaluar_errores(err, ids, "EXP", "G1", "yoy_pp", semilla_mcs = function(h) 100L + h, benchmark = "M.BENCH", B = 199L)
  b <- evaluar_errores(err[sample(nrow(err)), ], ids, "EXP", "G1", "yoy_pp", semilla_mcs = function(h) 100L + h,
                       benchmark = "M.BENCH", B = 199L, gw = TRUE)
  expect_identical(nrow(a$metricas), 2L * 4L * 3L)                              # modelos x horizontes x unidades
  expect_equal(a$metricas$rmse_relativo[a$metricas$modelo_id == "M.BENCH"], rep(1, 12))
  expect_identical(a$pruebas$prueba, rep("dm_hln", 4))
  expect_identical(sort(unique(b$pruebas$prueba)), c("dm_hln", "gw"))
  expect_identical(b$pruebas$marca_tamano[b$pruebas$prueba == "gw"], rep("tamano_no_verificado", 4))
  expect_identical(nrow(a$mcs), 8L)
  expect_identical(a$mcs$semilla, rep(100L + c(1L, 2L, 4L, 8L), each = 2))
  expect_equal(a$metricas, b$metricas)                                           # no depende del orden de entrada
  expect_equal(a$mcs, b$mcs)
  expect_identical(a$mcs$marca_tamano, rep(c("", "", "distorsion_tamano_documentada", "distorsion_tamano_documentada"), each = 2))
})

test_that("evaluar_errores: una submuestra de targets reduce los pares y conserva las columnas", {
  err <- .errores_sinteticos()
  keep <- SUBMUESTRAS_FASE4$sin_2020(err$origen + err$h) & (err$origen + err$h) > q_a_ind("2008-Q4")
  a <- evaluar_errores(err, c("M.BENCH", "M.OTRO"), "EXP", "G1", "yoy_pp", function(h) 1L, benchmark = "M.BENCH", B = 99L)
  s <- evaluar_errores(err[keep, ], c("M.BENCH", "M.OTRO"), "EXP", "G1", "yoy_pp", function(h) 1L, benchmark = "M.BENCH", B = 99L)
  expect_identical(names(s$metricas), names(a$metricas))
  expect_true(all(s$metricas$n_pares < a$metricas$n_pares))
})

.fila <- function(exp = "F4_BENCH_G1", token = construir_token("expansiva", "G1", "revision_vigente", "reestimado_en_origen", "yoy_pp")) {
  construir_filas_experimento(exp, c("M.A", "M.B"), c("V2", "V1", "V2"), "1990-Q1", "2026-Q1", token,
                              c(11, 12), strrep("a", 40), as.Date("2026-09-28"), "R 4.6.1")
}

test_that("07: una fila por modelo con exp_id compuesto y campos normalizados (F4-25)", {
  f <- .fila()
  expect_identical(f$exp_id, c("F4_BENCH_G1__M.A", "F4_BENCH_G1__M.B"))
  expect_identical(unique(f$vintage_id), "V1 + V2")
  expect_identical(unique(f$horizontes), "1,2,4,8")
  expect_identical(f$semilla, c(11L, 12L))
  expect_identical(unique(f$fecha_corrida), "2026-09-28")
  expect_identical(unique(f$ruta_resultados), "data/L4_experiments/F4_BENCH_G1/")
  expect_identical(names(f), names(utils::read.csv(here::here("catalogos", "07_experimentos.csv"), nrows = 1L, check.names = FALSE)))
  expect_error(.fila(token = "expansiva|origen=ultimo_estimado|grupo=G9|vintage=revision_vigente|sa=l3_unico|perdida=yoy_pp"), "token")
  expect_error(construir_filas_experimento("E", "M", "V", "1990-Q1", "2026-Q1", construir_token("expansiva", "G1", "revision_vigente", "l3_unico", "yoy_pp"),
                                           1, "abc", Sys.Date(), "R"), "commit_hash")
  expect_error(construir_filas_experimento("E", c("M", "N"), "V", "1990-Q1", "2026-Q1", construir_token("expansiva", "G1", "revision_vigente", "l3_unico", "yoy_pp"),
                                           1, strrep("b", 40), Sys.Date(), "R"), "una semilla por modelo")
})

test_that("07: volver a correr un experimento reemplaza sus filas sin tocar las demás", {
  g1 <- .fila(); g2 <- .fila("F4_BENCH_G2")
  r <- actualizar_registro_experimentos(g1[0, ], rbind(g1, g2))
  expect_identical(nrow(r), 4L)
  g1b <- g1; g1b$commit_hash <- strrep("c", 40)
  r2 <- actualizar_registro_experimentos(r, g1b)
  expect_identical(nrow(r2), 4L)
  expect_identical(r2$commit_hash[startsWith(r2$exp_id, "F4_BENCH_G1__")], rep(strrep("c", 40), 2))
  expect_identical(r2$commit_hash[startsWith(r2$exp_id, "F4_BENCH_G2__")], rep(strrep("a", 40), 2))
  expect_error(actualizar_registro_experimentos(r[, -1], g1b), "columnas")
  expect_error(actualizar_registro_experimentos(r[0, ], rbind(g1, g1)), "duplicado")
})

test_that("07: las filas registradas resuelven contra 06_modelos y 08_vintages", {
  reg <- utils::read.csv(here::here("catalogos", "07_experimentos.csv"), colClasses = "character", check.names = FALSE)
  if (nrow(reg) == 0L) {
    expect_identical(nrow(reg), 0L)
  } else {
    modelos <- sub("\\.yaml$", "", list.files(here::here("catalogos", "06_modelos"), pattern = "^[^_].*\\.yaml$"))
    vint <- utils::read.csv(here::here("catalogos", "08_vintages.csv"), colClasses = "character")$vintage_id
    expect_true(all(reg$modelo_id %in% modelos))
    expect_identical(reg$exp_id, paste0(sub("__.*$", "", reg$exp_id), "__", reg$modelo_id))
    expect_false(anyDuplicated(reg$exp_id) > 0L)
    for (tk in unique(reg$esquema_validacion)) expect_silent(validar_token(tk))
    expect_true(all(unlist(strsplit(reg$vintage_id, " + ", fixed = TRUE)) %in% vint))
    expect_true(all(grepl("^[0-9a-f]{40}$", reg$commit_hash)))
    expect_identical(reg$ruta_resultados, paste0("data/L4_experiments/", sub("__.*$", "", reg$exp_id), "/"))
  }
})
