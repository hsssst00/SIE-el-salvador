# Pruebas de src/evaluacion/paridad_bvar.R (V17; checklist F1, decisiones F1-1 a F1-3). No ajustan el BVAR: el
# ajuste de producción corre en V17 de la verificación sintética.
source(here::here("src", "evaluacion", "eval_lib.R"))
source(here::here("src", "evaluacion", "modelos_multivariados.R"))
source(here::here("src", "evaluacion", "paridad_bvar.R"))

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
  escribir_referencia_paridad_bvar(a, ruta)
  expect_false(any(readBin(ruta, "raw", file.size(ruta)) == as.raw(13L)))
  r <- leer_referencia_paridad_bvar(ruta)
  expect_identical(r$bytes, a$bytes); expect_identical(r$i, a$i); expect_identical(r$j, a$j)
  cmp <- comparar_paridad_bvar(a, r)
  expect_identical(cmp$n_distintos, 0L); expect_true(cmp$entradas_iguales)
  expect_identical(c(cmp$dif_media, cmp$dif_rel_cov, cmp$dif_aceptacion), c(0, 0, 0))
  expect_identical(cmp$sha256, sha256_doubles(a$valor[-1]))
  unlink(ruta)
})

test_that("F1-1: comparar_paridad_bvar detecta una diferencia de un ulp y mide su magnitud", {
  a <- .actual_falso(); r <- a
  a$valor[2] <- a$valor[2] + 4 * .Machine$double.eps; a$bytes[2] <- bytes_hex(a$valor[2])   # un ulp en [4, 8)
  a$valor[6] <- a$valor[6] * 1.5; a$bytes[6] <- bytes_hex(a$valor[6])                         # cov relativa 0,5
  cmp <- comparar_paridad_bvar(a, r)
  expect_identical(cmp$n_distintos, 2L); expect_true(cmp$entradas_iguales)
  expect_true(cmp$dif_media > 0 && cmp$dif_media < 1e-14)
  expect_equal(cmp$dif_rel_cov, 0.5)
  expect_identical(names(cmp$maximos), c("media", "cov")); expect_equal(unname(cmp$maximos[["cov"]]), 0.5)
  expect_identical(c(cmp$n_exactos_distintos, cmp$n_fuera_tolerancia), c(0L, 1L)); expect_false(cmp$dentro_tolerancia)
  r$bytes[1] <- strrep("cd", 32)
  expect_false(comparar_paridad_bvar(a, r)$entradas_iguales)
})

test_that("F1-3: tolerancia entre sistemas: media absoluta 1e-6, demás relativos 1e-5, entradas, tamaños y aceptación exactos", {
  expect_identical(c(TOL_MEDIA_PARIDAD_BVAR, TOL_REL_PARIDAD_BVAR), c(1e-6, 1e-5))
  expect_identical(CAMPOS_EXACTOS_PARIDAD_BVAR, c("sha256_entradas", "n_obs", "n_series", "aceptacion"))
  r <- .actual_falso()
  con <- function(k, v) { a <- r; a$valor[k] <- v; a$bytes[k] <- bytes_hex(v); comparar_paridad_bvar(a, r) }
  expect_true(con(2L, r$valor[2] + 5e-7)$dentro_tolerancia)                  # media, absoluta
  expect_false(con(2L, r$valor[2] + 2e-6)$dentro_tolerancia)
  expect_true(con(5L, r$valor[5] * (1 + 5e-6))$dentro_tolerancia)            # covarianza, relativa
  c2 <- con(5L, r$valor[5] * (1 + 2e-5))
  expect_false(c2$dentro_tolerancia); expect_identical(c2$n_fuera_tolerancia, 1L)
  c3 <- con(7L, r$valor[7] + 1e-12)                                          # aceptación: exacta
  expect_false(c3$dentro_tolerancia); expect_identical(c3$n_exactos_distintos, 1L); expect_identical(c3$n_fuera_tolerancia, 0L)
  a <- r; a$bytes[1] <- strrep("cd", 32)                                     # entradas: exactas
  expect_false(comparar_paridad_bvar(a, r)$dentro_tolerancia)
  r0 <- r; r0$bytes[6] <- bytes_hex(0)                                       # referencia 0 y valor distinto de 0
  expect_false(comparar_paridad_bvar(r, r0)$dentro_tolerancia)
  a0 <- r0; a0$valor[6] <- 0
  expect_true(comparar_paridad_bvar(a0, r0)$dentro_tolerancia)
})

test_that("F1-1: filas distintas o columnas inesperadas detienen la comparación (Regla 7)", {
  a <- .actual_falso()
  expect_error(comparar_paridad_bvar(a, a[-3, ]), "no tienen las mismas filas")
  b <- a; b$campo[4] <- "otra"
  expect_error(comparar_paridad_bvar(a, b), "no tienen las mismas filas")
  ruta <- tempfile(fileext = ".csv"); utils::write.csv(a[, 1:6], ruta, row.names = FALSE)
  expect_error(leer_referencia_paridad_bvar(ruta), "columnas")
  expect_error(leer_referencia_paridad_bvar(tempfile()), "no existe la referencia")
  expect_error(escribir_referencia_paridad_bvar(a[, 1:6], tempfile()), "columnas inesperadas")
  unlink(ruta)
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
