# tests/test-estacionariedad.R
#
# Ejercita src/analisis/estacionariedad_reglas.R con datos sintéticos, sin tocar disco.
# Ruido blanco (estacionario por construcción) y paseo aleatorio (no estacionario por
# construcción, integrado de orden 1) son los dos casos de libro de texto para verificar que
# la interpretación conjunta ADF+KPSS distingue correctamente.

library(testthat)
source(here::here("src", "analisis", "estacionariedad_reglas.R"))

set.seed(42)

test_that("transformaciones_candidatas omite log si hay valores no positivos", {
  valor_positivo <- c(10, 20, 15, 30)
  valor_con_cero <- c(10, 0, 15, 30)

  t1 <- transformaciones_candidatas(valor_positivo)
  t2 <- transformaciones_candidatas(valor_con_cero)

  expect_false(is.null(t1$log))
  expect_true(is.null(t2$log))
  expect_true(is.null(t2$diff_log))
  expect_false(is.null(t2$diff))  # diff no depende de log
})

test_that("transformaciones_candidatas calcula diff correctamente", {
  valor <- c(10, 12, 15, 11)
  t <- transformaciones_candidatas(valor)
  expect_equal(t$diff, c(2, 3, -4))
  expect_equal(length(t$nivel), 4)
})

test_that("ruido blanco (estacionario por construccion): ADF rechaza raiz unitaria", {
  x <- rnorm(300, mean = 50, sd = 5)
  adf <- prueba_adf(x, "diff", "M")  # type=drift, especificacion apropiada para algo sin tendencia
  expect_true(adf$rechaza_raiz_unitaria)
})

test_that("ruido blanco: KPSS no rechaza estacionariedad", {
  x <- rnorm(300, mean = 50, sd = 5)
  kpss <- prueba_kpss(x, "diff")
  expect_false(kpss$rechaza_estacionariedad)
})

test_that("paseo aleatorio (no estacionario por construccion, I(1)): ADF no rechaza raiz unitaria", {
  x <- 100 + cumsum(rnorm(300, mean = 0, sd = 1))
  adf <- prueba_adf(x, "nivel", "M")  # type=trend
  expect_false(adf$rechaza_raiz_unitaria)
})

test_that("paseo aleatorio: KPSS rechaza estacionariedad", {
  x <- 100 + cumsum(rnorm(300, mean = 0, sd = 1))
  kpss <- prueba_kpss(x, "nivel")
  expect_true(kpss$rechaza_estacionariedad)
})

test_that("interpretar_conjunta: ambas coinciden en estacionaria", {
  adf <- list(rechaza_raiz_unitaria = TRUE)
  kpss <- list(rechaza_estacionariedad = FALSE)
  expect_equal(interpretar_conjunta(adf, kpss), "estacionaria")
})

test_that("interpretar_conjunta: ambas coinciden en no_estacionaria", {
  adf <- list(rechaza_raiz_unitaria = FALSE)
  kpss <- list(rechaza_estacionariedad = TRUE)
  expect_equal(interpretar_conjunta(adf, kpss), "no_estacionaria")
})

test_that("interpretar_conjunta: los dos casos discordantes NO colapsan en una sola etiqueta", {
  # Ambas rechazan su H0 -> ni I(1) puro ni I(0) puro: quiebre estructural o integracion
  # fraccionaria. Ninguna rechaza -> falta de potencia. Son lecturas distintas de la tabla de
  # Kwiatkowski et al. y antes se publicaban las dos como "ambigua".
  ambas_rechazan <- interpretar_conjunta(list(rechaza_raiz_unitaria = TRUE),
                                          list(rechaza_estacionariedad = TRUE))
  ninguna_rechaza <- interpretar_conjunta(list(rechaza_raiz_unitaria = FALSE),
                                           list(rechaza_estacionariedad = FALSE))

  expect_equal(ambas_rechazan, "ambigua_quiebre_o_fraccional")
  expect_equal(ninguna_rechaza, "ambigua_baja_potencia")
  expect_false(ambas_rechazan == ninguna_rechaza)
})

test_that("analizar_estacionariedad_serie: paseo aleatorio positivo produce 4 transformaciones", {
  x <- 100 + cumsum(rnorm(200, mean = 0, sd = 1))
  x <- x - min(x) + 50  # fuerza estrictamente positivo para que log() aplique
  r <- analizar_estacionariedad_serie(x, "TEST.SERIE", "M")
  expect_equal(nrow(r), 4)
  expect_setequal(r$transformacion, c("nivel", "log", "diff", "diff_log"))
  expect_true(all(r$serie_id == "TEST.SERIE"))
})

test_that("analizar_estacionariedad_serie: serie con valor no positivo omite log/diff_log", {
  # n >= ~60 para que el techo de rezagos de Schwert (.max_rezagos_schwert) no exceda los
  # grados de libertad disponibles -- mismo piso que la serie L3 mas corta del proyecto real
  # (BCR_IPP_IDX_NSA_Q, 66 obs).
  x <- c(rnorm(60, mean = 50, sd = 5), -5) # un valor negativo al final
  r <- analizar_estacionariedad_serie(x, "TEST.NEG", "Q")
  expect_equal(nrow(r), 2)
  expect_setequal(r$transformacion, c("nivel", "diff"))
})

test_that("prueba_adf publica los rezagos EFECTIVOS de la seleccion, no el techo de Schwert", {
  # Regresion: ur.df() devuelve en su slot @lags el techo que se le paso en `lags=`, no la
  # seleccion. Publicar @lags hacia que la columna de rezagos del reporte no describiera la
  # regresion cuyo estadistico se publica a su lado (verificado en las 64 filas del reporte real:
  # BCR_EXPORT_FOB_NOM_NSA_M en nivel publicaba 16 con un estadistico de 1 rezago).
  set.seed(2026)
  x <- 100 + cumsum(rnorm(300))
  techo <- trunc(12 * (300 / 100)^0.25)

  adf <- prueba_adf(x, "nivel", "M")
  ajuste <- ur.df(x, type = "trend", lags = techo, selectlags = "BIC")

  expect_equal(adf$techo_rezagos, techo)
  expect_equal(ajuste@lags, techo)   # el slot que NO se debe publicar: es el techo, no la seleccion
  # Un paseo aleatorio no necesita 15 rezagos: si `rezagos` vuelve a ser el techo, esto falla.
  expect_lt(adf$rezagos, adf$techo_rezagos)
})

test_that("la grilla de la seleccion BIC incluye 0 rezagos, que es lo que urca nunca evalua", {
  # Hallazgo C2: en urca 1.3-4 la seleccion se arma con `critRes <- rep(NA, lags)` y se llena en
  # `for (i in 2:(lags))`, asi que el modelo sin rezagos de la diferencia queda fuera de la
  # comparacion y el minimo posible es 1. Para un paseo aleatorio el modelo verdadero NO tiene
  # rezagos de la diferencia: BIC sobre 0..techo elige 0 y urca no puede.
  set.seed(2026)
  x <- 100 + cumsum(rnorm(400))
  techo <- trunc(12 * (400 / 100)^0.25)

  adf <- prueba_adf(x, "nivel", "Q")
  urca_bic <- ur.df(x, type = "trend", lags = techo, selectlags = "BIC")

  expect_equal(adf$rezagos, 0)
  expect_gte(.rezagos_efectivos(urca_bic), 1)
  # Y el estadistico publicado es el del modelo elegido, no el de urca: si alguien vuelve a
  # delegar la seleccion en selectlags="BIC", estos dos numeros se igualan y este test falla.
  expect_false(isTRUE(all.equal(adf$estadistico,
                                unname(urca_bic@teststat[1, "tau3"]), tolerance = 1e-8)))
})

test_that("cuando la seleccion propia es >= 1 rezago, el estadistico coincide con urca", {
  # La contraparte del test anterior: sobre la grilla 1..techo las dos implementaciones son la
  # misma regresion sobre la misma muestra comun, asi que deben dar el mismo numero. Es la
  # guardia contra las dos fuentes de verdad -- .verificar_contra_urca() la aplica en cada
  # llamada sobre el modelo del techo, y aca se comprueba sobre el modelo elegido.
  # Un AR(2) estacionario necesita exactamente un rezago de la diferencia en la regresion ADF,
  # asi que BIC sobre 0..techo elige 1 y las dos grillas coinciden.
  set.seed(7)
  n <- 300
  e <- rnorm(n)
  x <- numeric(n)
  for (t in 3:n) x[t] <- 0.6 * x[t - 1] + 0.3 * x[t - 2] + e[t]
  x <- x + 50
  techo <- trunc(12 * (n / 100)^0.25)

  adf <- prueba_adf(x, "diff", "M")    # "diff" fija type="drift"; x ya viene sin tendencia
  urca_bic <- ur.df(x, type = "drift", lags = techo, selectlags = "BIC")

  expect_gte(adf$rezagos, 1)
  expect_equal(adf$rezagos, .rezagos_efectivos(urca_bic))
  expect_equal(adf$estadistico, unname(urca_bic@teststat[1, "tau2"]), tolerance = 1e-8)
})

test_that("prueba_adf publica el diagnostico de Ljung-Box y exige una frecuencia conocida", {
  set.seed(11)
  x <- 100 + cumsum(rnorm(200))

  adf <- prueba_adf(x, "nivel", "M")
  expect_true(is.numeric(adf$ljung_box_p))
  expect_gte(adf$ljung_box_p, 0)
  expect_lte(adf$ljung_box_p, 1)

  # La frecuencia fija los rezagos del diagnostico (12 mensual / 4 trimestral): un valor
  # desconocido no se adivina. La validacion falla, no advierte (regla 7 de CLAUDE.md).
  expect_error(prueba_adf(x, "nivel", "A"), "frecuencia desconocida")
})

test_that("analizar_estacionariedad_serie publica la columna adf_ljung_box_p", {
  set.seed(2028)
  x <- 100 + cumsum(rnorm(200))
  x <- x - min(x) + 50

  r <- analizar_estacionariedad_serie(x, "TEST.LJUNG", "M")

  expect_true("adf_ljung_box_p" %in% names(r))
  expect_true(all(is.na(r$adf_ljung_box_p) | (r$adf_ljung_box_p >= 0 & r$adf_ljung_box_p <= 1)))
})

test_that("analizar_estacionariedad_serie publica rezagos efectivos y techo en columnas distintas", {
  set.seed(2027)
  x <- 100 + cumsum(rnorm(200))
  x <- x - min(x) + 50  # estrictamente positivo para que log() aplique

  r <- analizar_estacionariedad_serie(x, "TEST.REZAGOS", "M")

  expect_true(all(c("adf_rezagos", "adf_techo_rezagos") %in% names(r)))
  expect_true(all(r$adf_rezagos <= r$adf_techo_rezagos))
  expect_true(any(r$adf_rezagos < r$adf_techo_rezagos))
})
