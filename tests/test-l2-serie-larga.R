# Ejercita src/validacion/l2_serie_larga_reglas.R con datos sintéticos de frecuencia mensual --
# el caso que tests/test-validar-l2-pib.R no cubre (esa ejercita validar_l2(), que fija freq="Q").
# Mismo patrón: catálogo mínimo, L1 sintético válido, y una mutación por caso.

library(testthat)
source(here::here("src", "validacion", "l2_serie_larga_reglas.R"))

catalogo_base <- data.frame(serie_id = c("BCR.IVAE.VOL.SA.M"), stringsAsFactors = FALSE)

l1_valido <- function() {
  periodos <- sprintf("2024-M%02d", 1:6)
  data.frame(
    serie_id = "BCR.IVAE.VOL.SA.M",
    periodo = periodos,
    valor = seq_along(periodos) * 1.5,
    provisional = FALSE,
    stringsAsFactors = FALSE
  )
}

test_that("datos coherentes no producen errores", {
  errores <- validar_l2_serie_larga(l1_valido(), catalogo_base, freq = "M")$errores
  expect_length(errores, 0)
})

test_that("detecta periodo con formato inválido para frecuencia mensual", {
  l1 <- l1_valido()
  l1$periodo[1] <- "2024-Q1"
  errores <- validar_l2_serie_larga(l1, catalogo_base, freq = "M")$errores
  expect_true(any(grepl("formato AAAA-Mnn", errores)))
})

test_that("detecta valor ausente (NA) -- el check que ataja C1 una capa antes de L3", {
  l1 <- l1_valido()
  l1$valor[3] <- NA
  errores <- validar_l2_serie_larga(l1, catalogo_base, freq = "M")$errores
  expect_true(any(grepl("valor: .* valor\\(es\\) ausente\\(s\\)", errores)))
})

test_that("detecta serie declarada en catálogo pero ausente en L1", {
  l1 <- l1_valido()
  l1 <- l1[0, ]
  errores <- validar_l2_serie_larga(l1, catalogo_base, freq = "M")$errores
  expect_true(any(grepl("declarada en 03_series.csv pero ausente en L1", errores)))
})

test_that("detecta hueco no declarado en la secuencia de periodos mensuales", {
  l1 <- l1_valido()
  l1 <- l1[l1$periodo != "2024-M03", ]
  errores <- validar_l2_serie_larga(l1, catalogo_base, freq = "M")$errores
  expect_true(any(grepl("hueco no declarado en 2024-M03", errores)))
})

test_that("detecta duplicados en (serie_id, periodo)", {
  l1 <- l1_valido()
  l1 <- rbind(l1, l1[1, ])
  errores <- validar_l2_serie_larga(l1, catalogo_base, freq = "M")$errores
  expect_true(any(grepl("duplicada", errores)))
})
