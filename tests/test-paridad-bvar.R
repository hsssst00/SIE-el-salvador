# Pruebas de src/evaluacion/paridad_bvar.R (V17; checklist F1, decisiones F1-1, F1-2 y F1-3 reabierta). No ajustan el BVAR: el
# ajuste de producción corre en V17 de la verificación sintética.
source(here::here("src", "evaluacion", "eval_lib.R"))
source(here::here("src", "evaluacion", "modelos_multivariados.R"))
source(here::here("src", "evaluacion", "paridad_bvar.R"))

.ref_falsa <- function(a, mcse = c(NA, 1e-4, 2e-4, 1e-3, 2e-3, 3e-3, NA)) { a$mcse <- mcse; a }
.actual_falso <- function() {
  v <- c(4.123456789, -1e-300, 2^-1074, 1e300, 0.1 + 0.2, 0.1)
  data.frame(grupo = c("-", rep("G1", 6)), origen = c("-", rep("2013-Q1", 6)),
             campo = c(CAMPO_ENTRADAS_PARIDAD_BVAR, rep("media", 2), rep("cov", 3), "aceptacion"),
             i = c(0L, 1L, 2L, 1L, 2L, 1L, 0L), j = c(0L, 0L, 0L, 1L, 1L, 2L, 0L),
             bytes = c(strrep("ab", 32), bytes_hex(v)), valor = c(NA, v), stringsAsFactors = FALSE)
}

test_that("F1-1: bytes_hex y double_de_hex son inversas exactas, también en subnormales y extremos", {
  x <- c(0, -0, 1, -1, pi, 0.1 + 0.2, 2^-1074, .Machine$double.xmax, -.Machine$double.eps, 1e-300)
  h <- bytes_hex(x)
  expect_true(all(nchar(h) == 16L))
  expect_identical(bytes_hex(1), "000000000000f03f")                         # IEEE 754 little-endian
  expect_identical(double_de_hex(h), x)
  expect_identical(bytes_hex(double_de_hex(h)), h)                            # distingue 0 de -0
  expect_false(identical(bytes_hex(0.3), bytes_hex(0.1 + 0.2)))
  expect_error(double_de_hex("3ff0"), "16 caracteres")
})

test_that("F1-1: la referencia se escribe con LF y se relee con los mismos bytes", {
  a <- .actual_falso(); ruta <- tempfile(fileext = ".csv")
  escribir_referencia_paridad_bvar(a, c(NA, 1e-4, 2e-4, 1e-3, 2e-3, 3e-3, NA), ruta)
  expect_false(any(readBin(ruta, "raw", file.size(ruta)) == as.raw(13L)))
  r <- leer_referencia_paridad_bvar(ruta)
  expect_identical(r$bytes, a$bytes); expect_identical(r$i, a$i); expect_identical(r$j, a$j)
  expect_identical(r$mcse, c(NA, 1e-4, 2e-4, 1e-3, 2e-3, 3e-3, NA))
  cmp <- comparar_paridad_bvar(a, r)
  expect_identical(cmp$n_distintos, 0L); expect_true(cmp$entradas_iguales)
  expect_identical(c(cmp$dif_media, cmp$dif_rel_cov, cmp$dif_aceptacion), c(0, 0, 0))
  expect_identical(unname(cmp$en_mcse), c(0, 0)); expect_identical(unname(cmp$decisiones_distintas), 0L)
  expect_identical(cmp$sha256, sha256_doubles(a$valor[-1]))
  unlink(ruta)
})

test_that("F1-1, F1-3: comparar_paridad_bvar detecta una diferencia de un ulp y la informa en MCSE y en decisiones del MH", {
  a <- .actual_falso(); r <- .ref_falsa(a)
  a$valor[2] <- a$valor[2] + 4 * .Machine$double.eps; a$bytes[2] <- bytes_hex(a$valor[2])   # un ulp en [4, 8)
  a$valor[6] <- a$valor[6] * 1.5; a$bytes[6] <- bytes_hex(a$valor[6])                         # cov relativa 0,5
  cmp <- comparar_paridad_bvar(a, r)
  expect_identical(cmp$n_distintos, 2L); expect_true(cmp$entradas_iguales)
  expect_true(cmp$dif_media > 0 && cmp$dif_media < 1e-14)
  expect_equal(cmp$dif_rel_cov, 0.5)
  expect_identical(names(cmp$maximos), c("media", "cov")); expect_equal(unname(cmp$maximos[["cov"]]), 0.5)
  expect_identical(names(cmp$en_mcse), c("media", "cov"))
  expect_equal(unname(cmp$en_mcse[["media"]]), 4 * .Machine$double.eps / 1e-4)
  expect_equal(unname(cmp$en_mcse[["cov"]]), (0.1 + 0.2) * 0.5 / 3e-3)
  a$valor[7] <- a$valor[7] + 4 / (N_DRAW_BVAR - N_BURN_BVAR); a$bytes[7] <- bytes_hex(a$valor[7])  # 4 decisiones del MH
  expect_identical(comparar_paridad_bvar(a, r)$decisiones_distintas, c(G1 = 4L))
  r$bytes[1] <- strrep("cd", 32)
  expect_false(comparar_paridad_bvar(a, r)$entradas_iguales)
})

test_that("F1-3: MCSE por medias por lotes", {
  expect_identical(LOTES_MCSE_PARIDAD_BVAR, 50L)
  expect_identical(CAMPOS_MCSE_PARIDAD_BVAR, c("media", "cov", "lambda", "soc", "sur"))
  x <- rep(1:50, each = 100)                                                 # lotes contiguos de 100
  expect_equal(mcse_lotes(x), stats::sd(1:50) / sqrt(50))
  expect_identical(mcse_lotes(rep(2, 5000)), 0)
  set.seed(3); z <- stats::rnorm(5000)
  expect_true(abs(mcse_lotes(z) / (1 / sqrt(5000)) - 1) < 0.35)             # iid: cerca de sd / sqrt(n)
  expect_error(mcse_lotes(1:4999), "no se dividen")
})

test_that("F1-1, F1-3: comparar_paridad_bvar detecta una diferencia de un ulp y la informa en MCSE y en decisiones del MH", {
  a <- .actual_falso(); r <- .ref_falsa(a)
  a$valor[2] <- a$valor[2] + 4 * .Machine$double.eps; a$bytes[2] <- bytes_hex(a$valor[2])   # un ulp en [4, 8)
  a$valor[6] <- a$valor[6] * 1.5; a$bytes[6] <- bytes_hex(a$valor[6])                         # cov relativa 0,5
  cmp <- comparar_paridad_bvar(a, r)
  expect_identical(cmp$n_distintos, 2L); expect_true(cmp$entradas_iguales)
  expect_true(cmp$dif_media > 0 && cmp$dif_media < 1e-14)
  expect_equal(cmp$dif_rel_cov, 0.5)
  expect_identical(names(cmp$maximos), c("media", "cov")); expect_equal(unname(cmp$maximos[["cov"]]), 0.5)
  expect_identical(names(cmp$en_mcse), c("media", "cov"))
  expect_equal(unname(cmp$en_mcse[["media"]]), 4 * .Machine$double.eps / 1e-4)
  expect_equal(unname(cmp$en_mcse[["cov"]]), (0.1 + 0.2) * 0.5 / 3e-3)
  a$valor[7] <- a$valor[7] + 4 / (N_DRAW_BVAR - N_BURN_BVAR); a$bytes[7] <- bytes_hex(a$valor[7])  # 4 decisiones del MH
  expect_identical(comparar_paridad_bvar(a, r)$decisiones_distintas, c(G1 = 4L))
  r$bytes[1] <- strrep("cd", 32)
  expect_false(comparar_paridad_bvar(a, r)$entradas_iguales)
})

test_that("F1-3: MCSE por medias por lotes", {
  expect_identical(LOTES_MCSE_PARIDAD_BVAR, 50L)
  expect_identical(CAMPOS_MCSE_PARIDAD_BVAR, c("media", "cov", "lambda", "soc", "sur"))
  x <- rep(1:50, each = 100)                                                 # lotes contiguos de 100
  expect_equal(mcse_lotes(x), stats::sd(1:50) / sqrt(50))
  expect_identical(mcse_lotes(rep(2, 5000)), 0)
  set.seed(3); z <- stats::rnorm(5000)
  expect_true(abs(mcse_lotes(z) / (1 / sqrt(5000)) - 1) < 0.35)             # iid: cerca de sd / sqrt(n)
  expect_error(mcse_lotes(1:4999), "no se dividen")
})

test_that("F1-2: el generador reproduce los datos de la prueba de producción y el ajuste fijo es G1 y G3", {
  s <- datos_paridad_bvar()
  expect_identical(names(s), c("objetivo", names(INICIOS_PARIDAD_BVAR)))
  expect_identical(nrow(s$objetivo), 145L)
  expect_identical(vapply(s[-1], function(d) d$periodo[1], character(1)), INICIOS_PARIDAD_BVAR)
  expect_true(all(vapply(s[-1], function(d) utils::tail(d$periodo, 1), character(1)) == "2026-Q2"))
  expect_identical(sort(names(INICIOS_PARIDAD_BVAR)), sort(predictoras_grupo("G3")))
  expect_identical(GRUPOS_PARIDAD_BVAR, c("G1", "G3"))
  expect_identical(datos_paridad_bvar(), s)
  expect_identical(RUTA_REFERENCIA_PARIDAD_BVAR, c("src", "evaluacion", "referencias", "paridad_bvar.csv"))
})
