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
  ajuste <- ajustar_estacional_propio(concat)

  expect_equal(nrow(ajuste$sa), n)
  expect_false(anyNA(ajuste$sa$valor))
  expect_true(all(c("periodo", "tipo") %in% names(ajuste$outliers)))
  expect_true("2010-Q3" %in% ajuste$outliers$periodo)
})
