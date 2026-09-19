# tests/test-l3-pib-objetivo.R
#
# Ejercita src/transformacion/l3_pib_objetivo_reglas.R con datos sinteticos,
# sin tocar disco. Mismo patron que tests/test-validar-l2-pib.R.

library(testthat)
source(here::here("src", "transformacion", "l3_pib_objetivo_reglas.R"))

.serie_sintetica <- function(id, periodos, valores) {
  data.frame(serie_id = id, periodo = periodos, valor = valores, stringsAsFactors = FALSE)
}

.periodos_q <- function(anio_ini, trim_ini, n) {
  anios <- rep(anio_ini:(anio_ini + ceiling(n / 4)), each = 4)
  trims <- rep(1:4, times = length(anios) / 4)
  todos <- sprintf("%d-Q%d", anios, trims)
  offset <- trim_ini - 1L
  todos[(offset + 1L):(offset + n)]
}

test_that("concatenar_pib_nsa empalma retro + nativo y descarta la superposicion", {
  periodos_retro  <- .periodos_q(1990, 1, 24) # 1990-Q1 .. 1995-Q4
  periodos_nativo <- .periodos_q(1995, 1, 8)  # 1995-Q1 .. 1996-Q4 (solape 1995 completo)

  l1 <- rbind(
    .serie_sintetica("BCR.PIB.VOL.NSA.Q.RETRO", periodos_retro, seq(100, 100 + 23 * 0.5, by = 0.5)),
    .serie_sintetica("BCR.PIB.VOL.NSA.Q", periodos_nativo, c(111.5, 112.0, 112.5, 113.0, 113.5, 114.0, 114.5, 115.0))
  )
  # Ajustar overlap 1995-Q1..1995-Q4 de RETRO para que coincida (redondeado a 2 decimales) con nativo.
  idx_overlap <- l1$serie_id == "BCR.PIB.VOL.NSA.Q.RETRO" & l1$periodo %in% c("1995-Q1", "1995-Q2", "1995-Q3", "1995-Q4")
  l1$valor[idx_overlap] <- c(111.5, 112.0, 112.5, 113.0)

  concat <- concatenar_pib_nsa(l1)

  expect_equal(nrow(concat), 28) # 1990-Q1 .. 1996-Q4 = 28 trimestres, sin duplicar el solape
  expect_equal(concat$periodo[1], "1990-Q1")
  expect_equal(concat$periodo[nrow(concat)], "1996-Q4")
  expect_false(any(duplicated(concat$periodo)))
  # El tramo de superposicion queda representado por el valor de la serie nativa.
  expect_equal(concat$valor[concat$periodo == "1995-Q1"], 111.5)
})

test_that("concatenar_pib_nsa falla de forma visible si la superposicion no coincide", {
  periodos_retro  <- .periodos_q(1990, 1, 24)
  periodos_nativo <- .periodos_q(1995, 1, 8)

  l1 <- rbind(
    .serie_sintetica("BCR.PIB.VOL.NSA.Q.RETRO", periodos_retro, seq(100, 100 + 23 * 0.5, by = 0.5)),
    .serie_sintetica("BCR.PIB.VOL.NSA.Q", periodos_nativo, c(111.5, 112.0, 112.5, 113.0, 113.5, 114.0, 114.5, 115.0))
  )
  # No se ajusta el overlap: los valores de RETRO (111.0, 111.5, 112.0, 112.5) no coinciden con nativo.

  expect_error(concatenar_pib_nsa(l1), "FALLO VISIBLE.*T001_CONCAT_PIB_NSA")
})

test_that("concatenar_pib_nsa falla de forma visible ante un hueco en la serie resultante", {
  periodos_retro  <- .periodos_q(1990, 1, 24)
  periodos_nativo <- .periodos_q(1995, 1, 8)

  l1 <- rbind(
    .serie_sintetica("BCR.PIB.VOL.NSA.Q.RETRO", periodos_retro, seq(100, 100 + 23 * 0.5, by = 0.5)),
    .serie_sintetica("BCR.PIB.VOL.NSA.Q", periodos_nativo, c(111.5, 112.0, 112.5, 113.0, 113.5, 114.0, 114.5, 115.0))
  )
  idx_overlap <- l1$serie_id == "BCR.PIB.VOL.NSA.Q.RETRO" & l1$periodo %in% c("1995-Q1", "1995-Q2", "1995-Q3", "1995-Q4")
  l1$valor[idx_overlap] <- c(111.5, 112.0, 112.5, 113.0)
  # Introducir un hueco: eliminar 1996-Q2 de la serie nativa.
  l1 <- l1[!(l1$serie_id == "BCR.PIB.VOL.NSA.Q" & l1$periodo == "1996-Q2"), ]

  expect_error(concatenar_pib_nsa(l1), "FALLO VISIBLE.*T001_CONCAT_PIB_NSA")
})

test_that("construir_pib_oficial hace pass-through de BCR.PIB.VOL.SA.Q", {
  periodos <- .periodos_q(2005, 1, 12)
  valores <- seq(90, 101)
  l1 <- .serie_sintetica("BCR.PIB.VOL.SA.Q", periodos, valores)

  oficial <- construir_pib_oficial(l1)

  expect_equal(nrow(oficial), 12)
  expect_equal(oficial$periodo, periodos)
  expect_equal(oficial$valor, valores)
})

test_that("construir_pib_oficial falla de forma visible ante un hueco", {
  periodos <- .periodos_q(2005, 1, 12)
  valores <- seq(90, 101)
  l1 <- .serie_sintetica("BCR.PIB.VOL.SA.Q", periodos, valores)
  l1 <- l1[l1$periodo != "2006-Q3", ]

  expect_error(construir_pib_oficial(l1), "FALLO VISIBLE.*PIB.SA.OFICIAL.Q")
})

test_that("ajustar_estacional_propio produce una serie SA completa y declara un outlier inyectado", {
  x13_disponible <- tryCatch({
    invisible(seasonal::seas(ts(rnorm(40, 100, 1), start = c(2000, 1), frequency = 4)))
    TRUE
  }, error = function(e) FALSE)
  skip_if_not(x13_disponible, "X-13ARIMA-SEATS no disponible en este entorno")

  set.seed(42)
  n <- 60 # 15 anios, suficiente para que X-13 identifique un modelo estable
  periodos <- .periodos_q(2000, 1, n)
  tendencia <- 100 + seq_len(n) * 0.3
  estacional <- rep(c(0, 2, -1, 1.5), length.out = n)
  ruido <- rnorm(n, sd = 0.3)
  valores <- tendencia + estacional + ruido
  # Pulso aditivo grande en una fecha conocida (shock transitorio, tipo AO2020).
  idx_shock <- which(periodos == "2010-Q3")
  valores[idx_shock] <- valores[idx_shock] + 15

  concat <- data.frame(periodo = periodos, valor = valores, stringsAsFactors = FALSE)
  # Los tres `*_esperado(a) = NULL` desactivan la guardia contra la especificación declarada de
  # T002 (hallazgo M2), que compara contra la corrida real de BCR.PIB -- outliers, orden ARIMA y
  # transformación -- y no aplica a esta serie sintética.
  ajuste <- ajustar_estacional_propio(concat, outliers_esperados = NULL,
                                      arima_esperado = NULL, transform_esperada = NULL)

  expect_equal(nrow(ajuste$sa), n)
  expect_false(anyNA(ajuste$sa$valor))
  expect_true(all(c("periodo", "tipo") %in% names(ajuste$outliers)))
  expect_true("2010-Q3" %in% ajuste$outliers$periodo)
})

test_that("ajustar_estacional_propio falla de forma visible si los outliers no calzan con lo declarado", {
  x13_disponible <- tryCatch({
    invisible(seasonal::seas(ts(rnorm(40, 100, 1), start = c(2000, 1), frequency = 4)))
    TRUE
  }, error = function(e) FALSE)
  skip_if_not(x13_disponible, "X-13ARIMA-SEATS no disponible en este entorno")

  set.seed(42)
  n <- 60
  periodos <- .periodos_q(2000, 1, n)
  tendencia <- 100 + seq_len(n) * 0.3
  estacional <- rep(c(0, 2, -1, 1.5), length.out = n)
  ruido <- rnorm(n, sd = 0.3)
  valores <- tendencia + estacional + ruido
  idx_shock <- which(periodos == "2010-Q3")
  valores[idx_shock] <- valores[idx_shock] + 15

  concat <- data.frame(periodo = periodos, valor = valores, stringsAsFactors = FALSE)
  # outliers_esperados por defecto (OUTLIERS_T002_DECLARADOS: 2020-Q2/2020-Q3 AO) no calza con
  # el shock sintético de 2010-Q3 -- exactamente el escenario que M2 quiere que falle visible.
  expect_error(ajustar_estacional_propio(concat), "FALLO VISIBLE.*T002_AJUSTE_ESTACIONAL_PROPIO")
})

# --- Guardia de especificación de T002, ejercida sin X-13 -------------------------------------
# verificar_especificacion_t002() es pura: recibe los tres valores ya extraídos del objeto de
# seas(), no el objeto. Eso permite cubrir la guardia completa en cualquier entorno, incluidos
# los que no tienen el binario de X-13ARIMA-SEATS (donde los dos tests de arriba se saltan).

.OUTLIERS_OK <- OUTLIERS_T002_DECLARADOS

test_that("verificar_especificacion_t002: la especificación declarada de T002 pasa", {
  expect_true(verificar_especificacion_t002(.OUTLIERS_OK, "(1 1 1)(0 1 1)", "log"))
})

test_that("verificar_especificacion_t002 tolera el prefijo ARIMA y el espaciado del .mdl", {
  # La celda `parametros` escribe "ARIMA(1 1 1)(0 1 1)"; el string de modelo$model$arima$model lo
  # arma read_mdl() a partir del .mdl que escribe el binario de X-13, cuyo espaciado no lo fija R.
  expect_true(verificar_especificacion_t002(.OUTLIERS_OK, "ARIMA(1 1 1)(0 1 1)", "log"))
  expect_true(verificar_especificacion_t002(.OUTLIERS_OK, " (1 1 1)(0 1 1) ", "log"))
})

test_that("verificar_especificacion_t002 falla si el orden ARIMA seleccionado cambió", {
  expect_error(verificar_especificacion_t002(.OUTLIERS_OK, "(0 1 1)(0 1 1)", "log"),
               "FALLO VISIBLE.*T002_AJUSTE_ESTACIONAL_PROPIO.*ARIMA")
})

test_that("verificar_especificacion_t002 falla si la transformación seleccionada cambió", {
  expect_error(verificar_especificacion_t002(.OUTLIERS_OK, "(1 1 1)(0 1 1)", "none"),
               "FALLO VISIBLE.*T002_AJUSTE_ESTACIONAL_PROPIO.*transform")
})

test_that("verificar_especificacion_t002 falla si el orden ARIMA no se pudo leer del objeto", {
  # modelo$model es NULL cuando read_mdl() no encuentra o no puede parsear el .mdl: eso no es
  # "sin cambios", es "no se verificó" -- y la validación falla, no advierte.
  expect_error(verificar_especificacion_t002(.OUTLIERS_OK, NULL, "log"),
               "FALLO VISIBLE.*no se pudo leer el orden ARIMA")
})

test_that("verificar_especificacion_t002 sigue fallando ante outliers distintos a los declarados", {
  otros <- data.frame(periodo = "2010-Q3", tipo = "AO", stringsAsFactors = FALSE)
  expect_error(verificar_especificacion_t002(otros, "(1 1 1)(0 1 1)", "log"),
               "FALLO VISIBLE.*T002_AJUSTE_ESTACIONAL_PROPIO.*outliers")
})
