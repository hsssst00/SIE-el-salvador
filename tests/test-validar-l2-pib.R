library(testthat)
source(here::here("src", "validacion", "l2_pib_reglas.R"))

catalogo_base <- data.frame(
  serie_id = c(VAB_RAMAS, "BCR.VAB.NOM.NSA.Q", "BCR.IMPUESTOS_NETOS.NOM.NSA.Q", "BCR.PIB.NOM.NSA.Q"),
  stringsAsFactors = FALSE
)

l1_valido <- function() {
  periodos <- c("2024-Q1", "2024-Q2", "2024-Q3")
  # valor arbitrario pero distinto por rama, para que la suma no sea trivial
  ramas <- lapply(seq_along(VAB_RAMAS), function(i) i * 10 + seq_along(periodos))
  vab_total <- Reduce(`+`, ramas)
  impuestos <- c(2, 2, 2)
  pib <- vab_total + impuestos

  data.frame(
    serie_id = rep(catalogo_base$serie_id, each = length(periodos)),
    periodo = rep(periodos, times = nrow(catalogo_base)),
    valor = c(unlist(ramas), vab_total, impuestos, pib),
    provisional = FALSE,
    stringsAsFactors = FALSE
  )
}

test_that("datos coherentes no producen errores", {
  errores <- validar_l2(l1_valido(), catalogo_base)
  expect_length(errores, 0)
})

test_that("detecta serie_id vacío", {
  l1 <- l1_valido()
  l1$serie_id[1] <- ""
  errores <- validar_l2(l1, catalogo_base)
  expect_true(any(grepl("serie_id: valores vacíos", errores)))
})

test_that("detecta periodo con formato inválido", {
  l1 <- l1_valido()
  l1$periodo[1] <- "2024-13"
  errores <- validar_l2(l1, catalogo_base)
  expect_true(any(grepl("formato AAAA-Qn", errores)))
})

test_that("detecta valor no numérico", {
  l1 <- l1_valido()
  l1$valor <- as.character(l1$valor)
  errores <- validar_l2(l1, catalogo_base)
  expect_true(any(grepl("valor: columna no numérica", errores)))
})

test_that("detecta serie huérfana (no está en el catálogo)", {
  l1 <- l1_valido()
  extra <- l1[l1$serie_id == "BCR.VAB_AGRICULTURA.NOM.NSA.Q", ]
  extra$serie_id <- "BCR.SERIE_INEXISTENTE.NOM.NSA.Q"
  l1 <- rbind(l1, extra)
  errores <- validar_l2(l1, catalogo_base)
  expect_true(any(grepl("sin entrada en 03_series.csv", errores)))
})

test_that("detecta serie declarada en catálogo pero ausente en L1", {
  l1 <- l1_valido()
  l1 <- l1[l1$serie_id != "BCR.VAB_MINAS.NOM.NSA.Q", ]
  errores <- validar_l2(l1, catalogo_base)
  expect_true(any(grepl("declarada en 03_series.csv pero ausente en L1", errores)))
})

test_that("detecta duplicados en (serie_id, periodo)", {
  l1 <- l1_valido()
  l1 <- rbind(l1, l1[1, ])
  errores <- validar_l2(l1, catalogo_base)
  expect_true(any(grepl("duplicada", errores)))
})

test_that("detecta hueco no declarado en la secuencia de periodos", {
  l1 <- l1_valido()
  l1 <- l1[l1$periodo != "2024-Q2", ]
  errores <- validar_l2(l1, catalogo_base)
  expect_true(any(grepl("hueco no declarado en 2024-Q2", errores)))
})

test_that("detecta identidad suma(VAB ramas) = VAB total rota", {
  l1 <- l1_valido()
  l1$valor[l1$serie_id == "BCR.VAB.NOM.NSA.Q"] <-
    l1$valor[l1$serie_id == "BCR.VAB.NOM.NSA.Q"] + 100
  errores <- validar_l2(l1, catalogo_base)
  expect_true(any(grepl("suma\\(VAB ramas\\) = VAB total rota", errores)))
})

test_that("detecta identidad VAB + impuestos = PIB rota", {
  l1 <- l1_valido()
  l1$valor[l1$serie_id == "BCR.PIB.NOM.NSA.Q"] <-
    l1$valor[l1$serie_id == "BCR.PIB.NOM.NSA.Q"] + 100
  errores <- validar_l2(l1, catalogo_base)
  expect_true(any(grepl("VAB total \\+ impuestos netos = PIB rota", errores)))
})

test_that("tolera discrepancias de redondeo por debajo de la tolerancia", {
  l1 <- l1_valido()
  l1$valor[l1$serie_id == "BCR.PIB.NOM.NSA.Q"][1] <-
    l1$valor[l1$serie_id == "BCR.PIB.NOM.NSA.Q"][1] + 0.02
  errores <- validar_l2(l1, catalogo_base)
  expect_length(errores, 0)
})
