# tests/test-evaluacion-origen.R
#
# Piezas del paso 5 del motor que viven en eval_lib.R y no necesitan X-13 ni datos del proyecto:
# grupos de comparación (F4-05), bases por origen para las tasas pronosticadas (F4-20),
# especificación y guardas del ajuste estacional por origen (F4-09b, G-5) y filtro de vintage
# (F4-03, G-6). Corre en CI.

library(testthat)
source(here::here("src", "evaluacion", "eval_lib.R"))

.obj <- function(n = 60L, inicio = "2000-Q1") {
  i0 <- q_a_ind(inicio)
  data.frame(periodo = ind_a_q(i0 + seq_len(n) - 1L), y = log(100) + 0.01 * seq_len(n) + 0.002 * sin(seq_len(n)),
             stringsAsFactors = FALSE)
}
.pron <- function(o, s, modelo = "M") data.frame(modelo_id = modelo, origen = o, h = seq_along(s), log_nivel_pronosticado = s,
                                                stringsAsFactors = FALSE)

test_that("grupos de F4-05: 52/51/49/45, 45/44/42/38 y 25/24/22/18 pares con último target 2026-Q1", {
  esperado <- list(G1 = c(52L, 51L, 49L, 45L), G2 = c(45L, 44L, 42L, 38L), G3 = c(25L, 24L, 22L, 18L))
  for (g in names(esperado)) {
    pares <- pares_evaluables(origenes_grupo(g), DISENO_FASE4$horizontes, "2026-Q1")
    expect_identical(unname(conteo_por_horizonte(pares)), esperado[[g]], info = g)
  }
  expect_error(origenes_grupo("G4"), "no declarado")
})

test_that("bases iguales al objetivo reproducen exactamente la derivación sin bases", {
  ob <- .obj(); o <- q_a_ind("2010-Q4")
  s <- ob$y[ob$periodo == "2010-Q4"] + 0.01 * (1:8)
  hist <- ob[q_a_ind(ob$periodo) <= o, ]
  b <- data.frame(origen = o, periodo = hist$periodo, y = hist$y)
  expect_identical(derivar_unidades(.pron(o, s), ob, b), derivar_unidades(.pron(o, s), ob))
})

test_that("con bases del origen, la tasa pronosticada usa la historia del origen y el observado no cambia", {
  ob <- .obj(); o <- q_a_ind("2010-Q4")
  s <- ob$y[ob$periodo == "2010-Q4"] + 0.01 * (1:8)
  hist <- ob[q_a_ind(ob$periodo) <= o, ]
  b <- data.frame(origen = o, periodo = hist$periodo, y = hist$y + 0.003)   # otro ajuste estacional
  d <- derivar_unidades(.pron(o, s), ob, b)
  y_de <- function(p) hist$y[hist$periodo == p] + 0.003
  esp_yoy <- c(vapply(1:4, function(h) 100 * (s[h] - y_de(ind_a_q(o + h - 4L))), numeric(1)), 100 * (s[5:8] - s[1:4]))
  expect_equal(d$yoy_pp_pronosticado, esp_yoy, tolerance = 1e-12)
  expect_equal(d$qoq_pp_pronosticado, 100 * (s - c(y_de(ind_a_q(o)), s[1:7])), tolerance = 1e-12)
  e_con <- calcular_errores(.pron(o, s), ob, bases = b); e_sin <- calcular_errores(.pron(o, s), ob)
  expect_identical(e_con$observado, e_sin$observado)
  expect_false(isTRUE(all.equal(e_con$pronostico[e_con$unidad == "yoy_pp"], e_sin$pronostico[e_sin$unidad == "yoy_pp"])))
  expect_identical(e_con$pronostico[e_con$unidad == "log_nivel"], e_sin$pronostico[e_sin$unidad == "log_nivel"])
})

test_that("bases posteriores al origen, faltantes o duplicadas hacen fallar la derivación", {
  ob <- .obj(); o <- q_a_ind("2010-Q4"); s <- rep(ob$y[44], 8)
  hist <- ob[q_a_ind(ob$periodo) <= o + 1L, ]
  expect_error(derivar_unidades(.pron(o, s), ob, data.frame(origen = o, periodo = hist$periodo, y = hist$y)), "posterior al origen")
  corta <- ob[q_a_ind(ob$periodo) <= o - 2L, ]
  expect_error(derivar_unidades(.pron(o, s), ob, data.frame(origen = o, periodo = corta$periodo, y = corta$y)), "falta la base")
  expect_error(derivar_unidades(.pron(o, s), ob, data.frame(origen = o - 1L, periodo = corta$periodo, y = corta$y)), "faltan las bases")
  h2 <- ob[q_a_ind(ob$periodo) <= o, ]; dup <- rbind(h2, h2[nrow(h2), ])
  expect_error(derivar_unidades(.pron(o, s), ob, data.frame(origen = o, periodo = dup$periodo, y = dup$y)), "duplicados")
})

test_that("F4-09b: los AO declarados entran solo desde el origen que los alcanza", {
  out <- data.frame(periodo = c("2020-Q3", "2020-Q2"), tipo = "AO", stringsAsFactors = FALSE)
  a1 <- args_x13_origen(out, q_a_ind("2020-Q1"))
  expect_identical(a1$transform.function, "log")
  expect_true("outlier" %in% names(a1) && is.null(a1$outlier))
  expect_false("regression.variables" %in% names(a1))
  expect_identical(args_x13_origen(out, q_a_ind("2020-Q2"))$regression.variables, "ao2020.2")
  expect_identical(args_x13_origen(out, q_a_ind("2025-Q4"))$regression.variables, c("ao2020.2", "ao2020.3"))
  expect_error(args_x13_origen(data.frame(periodo = "2020-Q2", tipo = "LS"), q_a_ind("2021-Q1")), "no contemplado")
})

test_that("G-5: una dummy posterior al origen hace fallar", {
  expect_error(guarda_dummies("2020-Q3", q_a_ind("2020-Q2")), "G-5")
  expect_silent(guarda_dummies(character(0), q_a_ind("2013-Q1")))
})

test_that("verificar_ajuste_origen exige transform=log y exactamente los AO declarados", {
  o <- q_a_ind("2021-Q1")
  expect_silent(verificar_ajuste_origen("log", c("2020-Q3", "2020-Q2"), c("2020-Q2", "2020-Q3"), o))
  expect_error(verificar_ajuste_origen("none", c("2020-Q2", "2020-Q3"), c("2020-Q2", "2020-Q3"), o), "transform=log")
  expect_error(verificar_ajuste_origen("log", c("2020-Q2", "2020-Q3", "2009-Q1"), c("2020-Q2", "2020-Q3"), o), "distintos")
  expect_error(verificar_ajuste_origen("log", character(0), "2020-Q2", o), "distintos")
})

test_that("G-6: revision_vigente conserva el vintage vigente y real_time falla", {
  d <- data.frame(periodo = c("2005-Q1", "2005-Q2", "2005-Q2"), valor = 1:3, vintage_id = c("A.v1", "A.v1", "A.v0"),
                  stringsAsFactors = FALSE)
  r <- filtrar_vintage(d, "revision_vigente", "A.v1")
  expect_identical(r$valor, 1:2)
  expect_error(filtrar_vintage(d, "revision_vigente", "A.v0"), "sin fila del vintage vigente")
  expect_error(filtrar_vintage(d, "revision_vigente", c("A.v1", "A.v0")), "más de una fila")
  expect_error(filtrar_vintage(d, "real_time", "A.v1"), "real_time")
  expect_error(filtrar_vintage(d, "otra", "A.v1"), "no declarada")
})
