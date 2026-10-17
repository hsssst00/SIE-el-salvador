# tests/test-analisis-posterior-ap1.R
#
# Análisis posterior AP-1 de Fase 5 (src/analisis_posterior/ap1_explosivos.R), con datos SINTÉTICOS: no se lee data/.
# Comprueba las piezas puras del diagnóstico: la mayor raíz de la forma compañera contra casos con raíz conocida, la
# recursión por extracción del BVAR contra la media de momentos_predictiva_bvar(), el desarme del ENET (los aportes
# por columna reconstruyen g_hat en cada h) y el barrido descriptivo sobre una L4 sintética.

library(testthat)
source(here::here("src", "analisis_posterior", "ap1_explosivos.R"))

.beta_var <- function(S, consts, A_list) {
  M <- length(consts); p <- length(A_list)
  b <- array(0, c(S, 1L + M * p, M))
  for (s in seq_len(S)) {
    b[s, 1L, ] <- consts
    for (l in seq_len(p)) b[s, 1L + (l - 1L) * M + seq_len(M), ] <- t(A_list[[l]])   # filas = regresores, columnas = ecuaciones
  }
  b
}

test_that("AP-1: mayor raíz de la forma compañera con raíces conocidas", {
  b1 <- .beta_var(2L, c(0, 0), list(diag(c(0.5, 1.2))))
  expect_equal(raiz_max_extracciones(b1, 1L), c(1.2, 1.2), tolerance = 1e-12)
  b2 <- .beta_var(1L, 0, list(matrix(1.5), matrix(-0.56)))                         # AR(2) con raíces 0,8 y 0,7
  expect_equal(raiz_max_extracciones(b2, 2L), 0.8, tolerance = 1e-12)
})

test_that("AP-1: la recursión por extracción promedia a la media de momentos_predictiva_bvar()", {
  set.seed(11)
  S <- 50L; M <- 3L; p <- 2L; H <- 8L
  beta <- array(stats::rnorm(S * (1L + M * p) * M, 0, 0.2), c(S, 1L + M * p, M))
  sigma <- array(0, c(S, M, M)); for (s in seq_len(S)) sigma[s, , ] <- diag(M) * 0.01
  Y <- matrix(cumsum(stats::rnorm(30L * M, 0, 0.1)), 30L, M)
  mu <- mu_por_extraccion(beta, Y, p, H)
  expect_identical(dim(mu), c(S, H))
  expect_equal(colMeans(mu), momentos_predictiva_bvar(beta, sigma, Y, p, H)$media, tolerance = 1e-12)
})

test_that("AP-1: el desarme del ENET reconstruye g_hat en cada h", {
  set.seed(5)
  ini <- c("BCR.REMESAS.NOM.NSA.Q" = "1991-Q1", "BCR.EXPORT_FOB.NOM.NSA.Q" = "1994-Q1", "BCR.ITCER.IDX.NSA.Q" = "2000-Q1",
           "UT.DEMANDA_ELEC.GWH.NSA.Q" = "2002-Q1", "BCR.IVAE.VOL.SA.Q" = "2005-Q1", "BCR.IPM.IDX.NSA.Q" = "2005-Q1",
           "BCR.IPP.IDX.NSA.Q" = "2010-Q1", "BCR.REMESAS.REAL.NSA.Q" = "2010-Q1")
  o <- q_a_ind("2021-Q1")
  obj <- data.frame(periodo = ind_a_q(q_a_ind("1990-Q1"):o), stringsAsFactors = FALSE)
  obj$y <- 4 + cumsum(0.005 + stats::rnorm(nrow(obj), 0, 0.01))
  m <- modelo_enet_grupo("G3")
  pred <- setdiff(m$requiere, "objetivo")
  expect_setequal(pred, names(ini))
  datos <- c(list(objetivo = obj), stats::setNames(lapply(pred, function(id) {
    i <- q_a_ind(ini[[id]]):o
    data.frame(periodo = ind_a_q(i), valor = 100 * exp(cumsum(0.004 + stats::rnorm(length(i), 0, 0.02))), stringsAsFactors = FALSE)
  }), pred))
  aj <- m$ajustar(datos, NULL)
  d <- diagnosticar_enet(list(m = m, o = o, info = datos, ajuste = aj))            # se detiene si no reconstruye g_hat
  expect_identical(d$resumen$h, 1:8)
  expect_equal(d$resumen$g_base + d$resumen$g_modelo, aj$g_hat, tolerance = 1e-10)
  expect_identical(nrow(d$columnas), 8L * ncol(matriz_directa(datos, pred, m$modelo_id)$X))
  el <- d$senda[d$senda$elegido, ]
  expect_identical(el$h, 1:8)
  expect_equal(el$g_hat, aj$g_hat, tolerance = 1e-10)
})

test_that("AP-1: barrido descriptivo de una L4 sintética", {
  raiz <- tempfile("l4_"); on.exit(unlink(raiz, recursive = TRUE))
  dir.create(file.path(raiz, "F5_G9"), recursive = TRUE); dir.create(file.path(raiz, "F5_REPRO_X"))
  per <- ind_a_q(q_a_ind("2000-Q1") + 0:19)
  tt <- seq_along(per)
  obj <- data.frame(periodo = per, y = log(100) + 0.01 * tt + 0.02 * (tt >= 10))     # interanual observada: 4 y 6 pp
  p <- data.frame(exp_id = "F5_G9", modelo_id = rep(c("M.A", "M.B"), each = 3), grupo = "G9", origen = "2004-Q1",
                  h = rep(1:3, 2), yoy_pp_pronosticado = c(5, 7, 13, 5, 5, -20))
  utils::write.csv(p, file.path(raiz, "F5_G9", "pronosticos.csv"), row.names = FALSE)
  b <- barrido_l4(obj, dir_l4 = raiz)
  expect_identical(b$exp_id, c("F5_G9", "F5_G9"))                                  # F5_REPRO_* no entra
  expect_identical(b$fuera_rango_historico, c(2L, 1L))
  expect_identical(b$fuera_doble_max_abs, c(1L, 1L))
  expect_equal(unique(b$rango_hist_min), 4, tolerance = 1e-10)
})
