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
  adf <- prueba_adf(x, "diff")  # type=drift, especificacion apropiada para algo sin tendencia
  expect_true(adf$rechaza_raiz_unitaria)
})

test_that("ruido blanco: KPSS no rechaza estacionariedad", {
  x <- rnorm(300, mean = 50, sd = 5)
  kpss <- prueba_kpss(x, "diff")
  expect_false(kpss$rechaza_estacionariedad)
})

test_that("paseo aleatorio (no estacionario por construccion, I(1)): ADF no rechaza raiz unitaria", {
  x <- 100 + cumsum(rnorm(300, mean = 0, sd = 1))
  adf <- prueba_adf(x, "nivel")  # type=trend
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
  r <- analizar_estacionariedad_serie(x, "TEST.SERIE")
  expect_equal(nrow(r), 4)
  expect_setequal(r$transformacion, c("nivel", "log", "diff", "diff_log"))
  expect_true(all(r$serie_id == "TEST.SERIE"))
})

test_that("analizar_estacionariedad_serie: serie con valor no positivo omite log/diff_log", {
  # n >= ~60 para que el techo de rezagos de Schwert (.max_rezagos_schwert) no exceda los
  # grados de libertad disponibles -- mismo piso que la serie L3 mas corta del proyecto real
  # (BCR_IPP_IDX_NSA_Q, 66 obs).
  x <- c(rnorm(60, mean = 50, sd = 5), -5) # un valor negativo al final
  r <- analizar_estacionariedad_serie(x, "TEST.NEG")
  expect_equal(nrow(r), 2)
  expect_setequal(r$transformacion, c("nivel", "diff"))
})

test_that("prueba_adf publica los rezagos EFECTIVOS de la seleccion BIC, no el techo de Schwert", {
  # Regresion: ur.df() devuelve en su slot @lags el techo que se le paso en `lags=`, no la
  # seleccion BIC. Publicar @lags hacia que la columna de rezagos del reporte no describiera la
  # regresion cuyo estadistico se publica a su lado (verificado en las 64 filas del reporte real:
  # BCR_EXPORT_FOB_NOM_NSA_M en nivel publicaba 16 con un estadistico de 1 rezago).
  set.seed(2026)
  x <- 100 + cumsum(rnorm(300))
  techo <- trunc(12 * (300 / 100)^0.25)

  adf <- prueba_adf(x, "nivel")
  ajuste <- ur.df(x, type = "trend", lags = techo, selectlags = "BIC")

  expect_equal(adf$techo_rezagos, techo)
  expect_equal(ajuste@lags, techo)   # el slot que NO se debe publicar: es el techo, no la seleccion
  expect_equal(adf$rezagos,
               sum(grepl("^z\\.diff\\.lag", rownames(ajuste@testreg$coefficients))))
  # Un paseo aleatorio no necesita 15 rezagos: si `rezagos` vuelve a ser el techo, esto falla.
  expect_lt(adf$rezagos, adf$techo_rezagos)
})

test_that("analizar_estacionariedad_serie publica rezagos efectivos y techo en columnas distintas", {
  set.seed(2027)
  x <- 100 + cumsum(rnorm(200))
  x <- x - min(x) + 50  # estrictamente positivo para que log() aplique

  r <- analizar_estacionariedad_serie(x, "TEST.REZAGOS")

  expect_true(all(c("adf_rezagos", "adf_techo_rezagos") %in% names(r)))
  expect_true(all(r$adf_rezagos <= r$adf_techo_rezagos))
  expect_true(any(r$adf_rezagos < r$adf_techo_rezagos))
})
