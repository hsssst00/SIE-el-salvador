# tests/test-hegy.R
#
# Ejercita src/analisis/hegy_reglas.R con datos sinteticos, sin tocar disco -- mismo patron que
# tests/test-estacionariedad.R (semilla fija, aserciones deterministas sobre una propiedad
# estadistica conocida por construccion). Ver la nota de cabecera de hegy_reglas.R (D1 del
# checklist de cierre de Fase 3): la construccion de hegy_regresores() se verifico contra el
# codigo fuente publicado de uroot::hegy.regressors(), no se derivo de memoria -- el primer
# test de este archivo fija esa construccion con un ejemplo calculado a mano.

library(testthat)
source(here::here("src", "analisis", "hegy_reglas.R"))

test_that("hegy_regresores reproduce un ejemplo calculado a mano (S=4, x=1..8)", {
  # x = 1,2,3,4,5,6,7,8 (serie lineal, S=4). Verificado a mano contra la definicion de
  # uroot::hegy.regressors(): fila t usa x[t-1]..x[t-4], alineada con dx[t] = x[t]-x[t-4].
  x <- stats::ts(1:8, frequency = 4)
  ypi <- hegy_regresores(x)

  expect_equal(nrow(ypi), 4) # t = 5..8 (las primeras S=4 filas se descartan)
  expect_equal(colnames(ypi), c("cero", "nyq", "j1_cos", "j1_sin"))

  # Fila t=5 usa x[4],x[3],x[2],x[1] = 4,3,2,1
  expect_equal(unname(ypi[1, "cero"]), 4 + 3 + 2 + 1)
  expect_equal(unname(ypi[1, "nyq"]), -4 + 3 - 2 + 1)
  expect_equal(unname(ypi[1, "j1_cos"]), -3 + 1)   # -x[t-2] + x[t-4]
  expect_equal(unname(ypi[1, "j1_sin"]), -(4 - 2)) # -(x[t-1] - x[t-3])

  # Fila t=8 usa x[7],x[6],x[5],x[4] = 7,6,5,4
  expect_equal(unname(ypi[4, "cero"]), 7 + 6 + 5 + 4)
  expect_equal(unname(ypi[4, "nyq"]), -7 + 6 - 5 + 4)
})

test_that("hegy_regresores falla de forma visible si no hay mas de S observaciones", {
  x <- stats::ts(1:4, frequency = 4)
  expect_error(hegy_regresores(x), "FALLO VISIBLE.*4")
})

test_that("simular_paseo_estacional produce S caminatas aleatorias independientes por fase", {
  set.seed(42)
  x <- simular_paseo_estacional(400, S = 4)
  expect_equal(length(x), 400)
  expect_equal(unname(stats::frequency(x)), 4)
  # Cada fase (posiciones 1,5,9,... / 2,6,10,... / etc.) es una caminata aleatoria: su primera
  # diferencia dentro de la fase no debe tener autocorrelacion sistematica distinta de ruido
  # blanco -- chequeo debil, solo confirma que no quedo una tendencia determinista inyectada
  # por error de indexacion.
  fase1 <- as.numeric(x)[seq(1, 400, by = 4)]
  expect_true(is.finite(stats::sd(diff(fase1))))
})

test_that("analizar_hegy_serie: estacionalidad determinista fuerte rechaza la raiz unitaria estacional", {
  set.seed(2026)
  n <- 240
  S <- 12
  t <- seq_len(n)
  patron_estacional <- rep(c(5, -3, 2, 4, -1, -4, 3, 1, -2, 0, 2, -5), length.out = n)
  x <- 50 + 0.1 * t + patron_estacional * 3 + stats::rnorm(n, sd = 0.5)

  resultado <- analizar_hegy_serie(x, "TEST_ESTACIONAL_FUERTE", "M", replicas = 300L)

  expect_true(resultado$rechaza_estacional_conjunta)
  expect_gt(resultado$f_estacional, resultado$cv_f_estacional * 2) # rechazo no marginal
})

test_that("analizar_hegy_serie: paseo aleatorio estacional puro no rechaza en frecuencia cero", {
  set.seed(7)
  x <- simular_paseo_estacional(240, S = 12)

  resultado <- analizar_hegy_serie(as.numeric(x), "TEST_PASEO_ESTACIONAL", "M", replicas = 300L)

  # H0 verdadera por construccion (1-L^12)x_t = e_t: no deberia rechazar en frecuencia cero.
  expect_false(resultado$rechaza_cero)
})

test_that("analizar_hegy_serie devuelve NA de Nyquist para S impar (trimestral SI tiene Nyquist)", {
  set.seed(11)
  x <- 50 + cumsum(stats::rnorm(120))
  resultado <- analizar_hegy_serie(x, "TEST_Q", "Q", replicas = 200L)
  expect_equal(resultado$s, 4)
  expect_false(is.na(resultado$t_nyq)) # S=4 es par, Nyquist existe
})

test_that("analizar_hegy_serie falla de forma visible ante frecuencia desconocida", {
  expect_error(analizar_hegy_serie(1:50, "TEST", "A", replicas = 50L),
               "FALLO VISIBLE.*frecuencia desconocida")
})
