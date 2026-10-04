# tests/test-corte-motor.R
#
# Pruebas del corte congelado de Fase 5 en el motor de evaluación (F5-16, decisiones C-1 a C-8 de
# doc/metodologia/decisiones_fase5.md). Todo con catálogos y capas SINTÉTICOS en directorios
# temporales: no se lee data/. La no-regresión contra la L1/L3 reales (C-5, C-6) se corre en la máquina
# que tiene L0, con `make master` y `make eval` sobre el corte.

library(testthat)

source(here::here("src", "evaluacion", "motor_backtesting.R"))   # main() no corre al hacer source

# Fija SIE_CONJUNTO/SIE_SALIDA mientras corre `codigo` y restaura los valores previos.
con_conjunto <- function(conjunto, salida, codigo) {
  ant <- Sys.getenv(c("SIE_CONJUNTO", "SIE_SALIDA"), unset = NA)
  on.exit({
    for (nm in names(ant)) if (is.na(ant[[nm]])) Sys.unsetenv(nm) else do.call(Sys.setenv, stats::setNames(list(ant[[nm]]), nm))
  }, add = TRUE)
  Sys.unsetenv(c("SIE_CONJUNTO", "SIE_SALIDA"))
  if (!is.null(conjunto)) Sys.setenv(SIE_CONJUNTO = conjunto, SIE_SALIDA = salida)
  force(codigo)
}

# Escenario: una publicación PUB con dos vintages (v1 y v2, v2 el último de 08) y una L3 sintética
# del objetivo bajo <salida>/L3_master/ etiquetada con `vintage_l3`.
escenario_corte <- function(vintage_l3) {
  salida <- tempfile("salida_corte_"); dir.create(file.path(salida, "L3_master"), recursive = TRUE)
  per <- ind_a_q(seq.int(q_a_ind("2000-Q1"), q_a_ind("2010-Q4")))
  utils::write.csv(data.frame(periodo = per, valor = 100 * exp(0.01 * seq_along(per)), vintage_id = vintage_l3),
                   file.path(salida, "L3_master", "OBJ.csv"), row.names = FALSE)
  corte <- tempfile("corte_", fileext = ".csv")
  writeLines(c("publicacion_id,vintage_id", "PUB,PUB.v1"), corte)
  list(salida = salida, corte = corte, n = length(per),
       vintages = data.frame(vintage_id = c("PUB.v1", "PUB.v2"), publicacion_id = "PUB", stringsAsFactors = FALSE))
}

test_that("C-3: sin SIE_CONJUNTO el motor se detiene con el comando correcto", {
  expect_error(exigir_conjunto(NULL), "C-3")
  expect_error(exigir_conjunto(NULL), "make eval   CONJUNTO=doc/metodologia/corte_fase5.csv", fixed = TRUE)
  cj <- data.frame(publicacion_id = "PUB", vintage_id = "PUB.v1")
  expect_identical(exigir_conjunto(cj), cj)
  con_conjunto(NULL, NULL, expect_error(exigir_conjunto(conjunto_activo()), "C-3"))
})

test_that("G-6 con corte: la L3 del corte pasa aunque 08 ya tenga un vintage posterior", {
  e <- escenario_corte("PUB.v1")
  con_conjunto(e$corte, e$salida, {
    cj <- conjunto_activo()
    o <- leer_objetivo("OBJ.csv", "revision_vigente", e$vintages, cj)
    expect_identical(nrow(o), e$n)
    expect_true(all(o$vintage_id == "PUB.v1"))
    # sin pasar el corte, el vigente es v2 y G-6 detiene (el comportamiento de Fase 4)
    expect_error(leer_objetivo("OBJ.csv", "revision_vigente", e$vintages), "G-6: períodos sin fila del vintage vigente")
  })
})

test_that("G-6 con corte: una L3 armada con datos posteriores al corte se detiene", {
  # El riesgo del diagnóstico del 2026-10-03: L3 actualizada a v2 con make master; el corte declara v1.
  e <- escenario_corte("PUB.v2")
  con_conjunto(e$corte, e$salida,
               expect_error(leer_objetivo("OBJ.csv", "revision_vigente", e$vintages, conjunto_activo()),
                            "G-6: períodos sin fila del vintage vigente"))
})

test_that("el motor lee las capas de <SALIDA>, no de data/", {
  e <- escenario_corte("PUB.v1")
  con_conjunto(e$corte, e$salida, {
    expect_identical(normalizePath(ruta_capa("L3_master", "OBJ.csv"), winslash = "/"),
                     normalizePath(file.path(e$salida, "L3_master", "OBJ.csv"), winslash = "/"))
    expect_error(.leer_capa("L3_master", "NO_EXISTE.csv"), "motor: no existe")
  })
  # CONJUNTO sin SALIDA: falla visible de conjunto_lib.R
  ant <- Sys.getenv(c("SIE_CONJUNTO", "SIE_SALIDA"), unset = NA)
  on.exit({ for (nm in names(ant)) if (is.na(ant[[nm]])) Sys.unsetenv(nm) else do.call(Sys.setenv, stats::setNames(list(ant[[nm]]), nm)) }, add = TRUE)
  Sys.unsetenv("SIE_SALIDA"); Sys.setenv(SIE_CONJUNTO = e$corte)
  expect_error(.leer_capa("L3_master", "OBJ.csv"), "sin SIE_SALIDA")
})

test_that("ruta_relativa: relativa a la raíz con /, absoluta si cae fuera", {
  raiz <- tempfile("raiz_"); dir.create(file.path(raiz, "data", "x"), recursive = TRUE)
  expect_identical(ruta_relativa(file.path(raiz, "data", "x", "a.csv"), raiz), "data/x/a.csv")
  fuera <- tempfile("fuera_")
  expect_identical(ruta_relativa(fuera, raiz), normalizePath(fuera, winslash = "/", mustWork = FALSE))
})

test_that("C-5: el SA recalculado desde L1 debe ser idéntico al de L3", {
  per <- ind_a_q(seq.int(q_a_ind("2018-Q1"), q_a_ind("2021-Q4")))
  sa <- data.frame(periodo = per, valor = 100 + seq_along(per) / 3)
  out <- data.frame(periodo = c("2020-Q2", "2020-Q3"), tipo = "AO")
  aj <- list(sa = sa, outliers = out)
  l3 <- cbind(sa, vintage_id = "PUB.v1"); ol3 <- cbind(out, vintage_id = "PUB.v1")
  expect_true(verificar_l1_contra_l3(aj, l3, ol3))
  # una diferencia en la última cifra binaria basta (sin tolerancia)
  l3b <- l3; l3b$valor[5] <- l3b$valor[5] * (1 + .Machine$double.eps)
  expect_error(verificar_l1_contra_l3(aj, l3b, ol3), "C-5: el SA recalculado desde L1 difiere del de L3 en 1 período")
  l3c <- l3; l3c$valor[3] <- NA
  expect_error(verificar_l1_contra_l3(aj, l3c, ol3), "difiere del de L3")
  expect_error(verificar_l1_contra_l3(aj, l3[-nrow(l3), ], ol3), "no cubren los mismos períodos")
  expect_error(verificar_l1_contra_l3(aj, l3, ol3[1, ]), "AO")
  ol3d <- ol3; ol3d$tipo[2] <- "LS"
  expect_error(verificar_l1_contra_l3(aj, l3, ol3d), "AO")
})

test_that("C-4: el token admite un séptimo campo conjunto=<nombre>@<sha8>", {
  base <- construir_token("expansiva", "G1", "revision_vigente", "reestimado_en_origen", "yoy_pp")
  tok <- construir_token("expansiva", "G1", "revision_vigente", "reestimado_en_origen", "yoy_pp", conjunto = "corte_fase5@901b0f79")
  expect_identical(tok, paste0(base, "|conjunto=corte_fase5@901b0f79"))
  v <- validar_token(tok)
  expect_identical(v$conjunto, "corte_fase5@901b0f79")
  expect_identical(v$grupo, "G1")
  expect_null(validar_token(base)$conjunto)                       # los tokens de Fase 4 siguen valiendo
  expect_error(validar_token(paste0(base, "|corte=corte_fase5@901b0f79")), "solo puede ser `conjunto=")
  expect_error(validar_token(paste0(base, "|conjunto=corte_fase5@901B0F79")), "conjunto mal formado")
  expect_error(validar_token(paste0(base, "|conjunto=corte_fase5")), "conjunto mal formado")
  expect_error(validar_token(paste0(base, "|conjunto=a b@901b0f79")), "conjunto mal formado")
  expect_error(validar_token(paste0(tok, "|conjunto=otro@00000000")), "8 campos")
  expect_error(construir_token("expansiva", "G1", "revision_vigente", "l3_unico", "yoy_pp", conjunto = "x@1"), "conjunto mal formado")
})

test_that("C-4: identidad del corte, con el sha256 sin CR", {
  d <- tempfile("id_corte_"); dir.create(d)
  lf <- file.path(d, "corte_x.csv"); crlf <- file.path(d, "corte_y.csv")
  writeBin(charToRaw("publicacion_id,vintage_id\nPUB,PUB.v1\n"), lf)
  writeBin(charToRaw("publicacion_id,vintage_id\r\nPUB,PUB.v1\r\n"), crlf)
  a <- identidad_conjunto(lf, salida = d); b <- identidad_conjunto(crlf, salida = d)
  expect_identical(a$sha256, b$sha256)
  expect_identical(a$sha256, digest::digest("publicacion_id,vintage_id\nPUB,PUB.v1\n", algo = "sha256", serialize = FALSE))
  expect_identical(a$etiqueta, paste0("corte_x@", substr(a$sha256, 1, 8)))
  expect_match(a$etiqueta, TOKEN_PATRON_CONJUNTO)
  expect_error(identidad_conjunto(file.path(d, "no.csv"), salida = d), "C-4: no existe")
})
