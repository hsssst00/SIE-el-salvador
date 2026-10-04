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

test_that("C-6/C-7: F5_REPRO_* repite cada F4_BENCH_* con sus semillas", {
  expect_identical(nrow(EXPERIMENTOS_FASE5), nrow(EXPERIMENTOS))
  expect_identical(nrow(EXPERIMENTOS), 13L)
  expect_identical(EXPERIMENTOS_FASE5$exp_id, sub("^F4_BENCH_", "F5_REPRO_", EXPERIMENTOS$exp_id))
  expect_identical(EXPERIMENTOS_FASE5$semilla_exp, EXPERIMENTOS$exp_id)
  expect_identical(EXPERIMENTOS$semilla_exp, EXPERIMENTOS$exp_id)          # en Fase 4, la de siempre
  otras <- setdiff(names(EXPERIMENTOS), c("exp_id", "semilla_exp"))
  expect_identical(EXPERIMENTOS_FASE5[, otras], EXPERIMENTOS[, otras])
  expect_error(experimentos_reproduccion(EXPERIMENTOS_FASE5), "C-6")
})

test_that("C-8: los exp_id F4_* se rechazan; por defecto corren los de Fase 5", {
  expect_identical(seleccionar_experimentos()$exp_id, EXPERIMENTOS_FASE5$exp_id)
  expect_identical(seleccionar_experimentos(c("F5_REPRO_G3_R6", "F5_REPRO_G1"))$exp_id, c("F5_REPRO_G1", "F5_REPRO_G3_R6"))
  expect_error(seleccionar_experimentos("F4_BENCH_G1"), "C-8: F4_BENCH_G1 es de Fase 4")
  expect_error(seleccionar_experimentos("F4_BENCH_G1"), "F5_REPRO_G1", fixed = TRUE)
  expect_error(seleccionar_experimentos(c("F5_REPRO_G1", "F4_BENCH_G2_R5")), "C-8")
  expect_error(seleccionar_experimentos("F5_REPRO_G9"), "exp_id no declarado: F5_REPRO_G9")
})

test_that("C-7: F5_REPRO_G3_R6 reproduce F4_BENCH_G3_R6 salvo exp_id (insumos sintéticos)", {
  # El mismo objetivo sintético que V12 de verificar_motor_sintetico.R: Δy AR(1) con φ = 0,5 y dos AO en
  # 2020-Q2/Q3. Con un paseo puro, AR(p)-BIC replica al paseo con deriva y el MCS se detiene.
  set.seed(20260924L + 12L)
  per <- ind_a_q(q_a_ind("1990-Q1") + 0:144)
  dy <- numeric(length(per)); e <- stats::rnorm(length(per), 0, 0.008)
  for (t in 2:length(per)) dy[t] <- 0.003 + 0.5 * dy[t - 1] + e[t]
  y <- 4.6 + cumsum(dy)
  i20 <- match(c("2020-Q2", "2020-Q3"), per); y[i20] <- y[i20] + c(-0.20, -0.08)
  insumos <- list(objetivos = list(PIB_SA_PROPIO_Q = data.frame(periodo = per, y = y, vintage_id = "SINT.v1", stringsAsFactors = FALSE)),
                  conjunto = list(etiqueta = "corte_sint@0123abcd"))
  f4 <- correr_experimento(EXPERIMENTOS[EXPERIMENTOS$exp_id == "F4_BENCH_G3_R6", ], insumos, new.env())
  f5 <- correr_experimento(EXPERIMENTOS_FASE5[EXPERIMENTOS_FASE5$exp_id == "F5_REPRO_G3_R6", ], insumos, new.env())
  sin_id <- function(d) { d$exp_id <- NULL; d }
  for (tb in c("pronosticos", "metricas", "pruebas", "mcs")) {
    expect_true(all(f5[[tb]]$exp_id == "F5_REPRO_G3_R6"), info = tb)
    expect_identical(sin_id(f5[[tb]]), sin_id(f4[[tb]]), info = tb)
  }
  expect_identical(f5$semillas, f4$semillas)
  expect_identical(f5$token, f4$token)
  expect_match(f5$token, "\\|conjunto=corte_sint@0123abcd$")
  # con otra semilla el MCS sí cambia: la herencia no es trivial
  otro <- EXPERIMENTOS_FASE5[EXPERIMENTOS_FASE5$exp_id == "F5_REPRO_G3_R6", ]; otro$semilla_exp <- otro$exp_id
  f5b <- correr_experimento(otro, insumos, new.env())
  expect_identical(sin_id(f5b$pronosticos), sin_id(f4$pronosticos))     # los benchmarks son deterministas
  expect_false(identical(f5b$semillas, f4$semillas))
})

test_that("C-1/C-2: el corte congelado de Fase 5 no cambia y es coherente con los catálogos", {
  ruta <- here::here("doc", "metodologia", "corte_fase5.csv")
  b <- readBin(ruta, "raw", n = file.info(ruta)$size)
  expect_identical(digest::digest(b[b != as.raw(13L)], algo = "sha256", serialize = FALSE),
                   "901b0f7959b5cc40b82f376f469eaaa80adb931ecfcee4d7624910440021ff17")
  cj <- leer_conjunto(ruta)
  expect_identical(nrow(cj), 36L)
  series <- utils::read.csv(here::here("catalogos", "03_series.csv"), stringsAsFactors = FALSE, na.strings = "")
  expect_setequal(unique(cj$publicacion_id), unique(stats::na.omit(series$publicacion_id)))
  v <- leer_vintages()
  expect_true(all(cj$vintage_id %in% v$vintage_id))
  expect_identical(vintage_vigente("BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA", v, cj), "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA.v2026-06")
  expect_identical(vintage_vigente("BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_SA", v, cj), "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_SA.v2026-06")
  expect_identical(vintage_vigente("BCR.PIB_T.SERIE_RETROPOLADA_1990_2005", v, cj), "BCR.PIB_T.SERIE_RETROPOLADA_1990_2005.v2019-03")
  expect_identical(identidad_conjunto(ruta, salida = tempdir())$etiqueta, "corte_fase5@901b0f79")
})
