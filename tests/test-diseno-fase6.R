# tests/test-diseno-fase6.R
#
# Diseño de Fase 6 (checklist D1; F6-04, F6-06) y huella de Fase 5 (huella_fase5.R, V21b). Sintético: no lee data/.

library(testthat)
source(here::here("src", "proyeccion", "diseno_fase6.R"))
source(here::here("src", "evaluacion", "huella_fase5.R"))

test_that("D1 (F6-06): DISENO_FASE4 no cambia", {
  expect_identical(DISENO_FASE4, list(primer_origen = "2013-Q1", ultimo_origen = "2025-Q4",
                                      horizontes = c(1L, 2L, 4L, 8L), h_max = 8L))
  expect_identical(GRUPOS_FASE4, c(G1 = "2013-Q1", G2 = "2014-Q4", G3 = "2019-Q4"))
})

test_that("D1 (F6-04, F6-07, F6-02, F6-05): DISENO_FASE6 declara lo que fijan las fichas", {
  expect_identical(DISENO_FASE6$h_max, 20L)
  expect_identical(DISENO_FASE6$h_calibrado, 8L)
  expect_identical(DISENO_FASE6$niveles, c(0.80, 0.95))
  expect_identical(DISENO_FASE6$min_miembros, 3L)
  expect_identical(DISENO_FASE6$grupos, c("G1", "G2", "G3"))
  expect_identical(DISENO_FASE6$escenarios, c("BASE", "ADVERSO", "FAVORABLE"))
})

test_that("D1 (F6-04): origen y trimestres proyectados", {
  obj <- data.frame(periodo = c("2026-Q1", "2026-Q2"))
  o <- origen_fase6(obj)
  expect_identical(ind_a_q(o), "2026-Q2")
  p <- periodos_fase6(o)
  expect_length(p, 20L)
  expect_identical(p[c(1, 18, 20)], c("2026-Q3", "2030-Q4", "2031-Q2"))   # 2030-Q4 en h = 18 (F6-04)
  expect_error(origen_fase6(obj[0, , drop = FALSE]), "no trae filas")
  expect_error(origen_fase6(obj[2:1, , drop = FALSE]), "ordenado")
})

test_that("D1 (V21b): la huella cambia con un byte y no con el orden de las filas", {
  p <- data.frame(modelo_id = rep(c("A", "B"), each = 4), origen = rep(1:2, 4), h = rep(c(1L, 1L, 2L, 2L), 2),
                  log_nivel_pronosticado = c(4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.4), stringsAsFactors = FALSE)
  d <- data.frame(modelo_id = "A", origen = 1L, clave = "p", valor = 2, stringsAsFactors = FALSE)
  h <- huella_por_modelo(p, d)
  expect_identical(h$modelo_id, c("A", "B"))
  expect_identical(huella_por_modelo(p[8:1, ], d), h)
  q <- p; q$log_nivel_pronosticado[6] <- q$log_nivel_pronosticado[6] + 4 * .Machine$double.eps
  hq <- huella_por_modelo(q, d)
  expect_identical(hq$sha256[1], h$sha256[1]); expect_false(identical(hq$sha256[2], h$sha256[2]))
  d2 <- d; d2$valor <- 3
  expect_false(identical(huella_por_modelo(p, d2)$sha256[1], h$sha256[1]))
})

test_that("D1 (V21b): comparar_huella distingue igual, distinta y sin referencia", {
  act <- data.frame(modelo_id = c("A", "B"), sha256 = c("aa", "bb"), stringsAsFactors = FALSE)
  ref <- data.frame(plataforma = c("P1", "P1", "P2"), modelo_id = c("A", "B", "A"), sha256 = c("aa", "bb", "zz"),
                    stringsAsFactors = FALSE)
  expect_identical(comparar_huella(act, ref, "P1")$estado, "igual")
  c2 <- comparar_huella(act, ref, "P2")
  expect_identical(c2$estado, "distinta"); expect_identical(c2$distintos, "A"); expect_identical(c2$sobran, "B")
  expect_identical(comparar_huella(act[1, ], ref, "P1")$faltan, "B")
  expect_identical(comparar_huella(act, ref, "P3")$estado, "sin_referencia")
  expect_identical(filas_huella(act[1, ], "P1"), "\"P1\",\"A\",\"aa\"")
})

test_that("D1 (V21b): la referencia versionada tiene la forma declarada", {
  r <- leer_referencia_huella()
  expect_identical(names(r), COLUMNAS_HUELLA_FASE5)
})
