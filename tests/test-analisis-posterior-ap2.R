# tests/test-analisis-posterior-ap2.R
#
# Análisis posterior AP-2 de Fase 5, parte descriptiva (src/analisis_posterior/ap2_estabilidad_puente.R), con errores
# SINTÉTICOS: no se lee data/. Comprueba el RMSE relativo al benchmark y el puesto por subconjunto, los bloques de
# targets (y que se omiten los de menos de 4 targets) y las ventanas móviles de 12 targets.

library(testthat)
source(here::here("src", "analisis_posterior", "ap2_estabilidad_puente.R"))

.errores_ap2 <- function() {
  ts <- q_a_ind("2013-Q1") + 0:39                                                  # targets 2013-Q1..2022-Q4
  do.call(rbind, lapply(DISENO_FASE4$horizontes, function(h) rbind(
    data.frame(modelo_id = BENCHMARK, h = h, t = ts, error = rep(c(2, -2), 20)),
    data.frame(modelo_id = "MIX.PUENTE.G9", h = h, t = ts, error = ifelse(ts >= q_a_ind("2020-Q1"), 0.5, 3) * rep(c(1, -1), 20)),
    data.frame(modelo_id = "UNI.ARIMA", h = h, t = ts, error = rep(c(1, -1), 20)))))
}

test_that("AP-2: RMSE relativo y puesto en un subconjunto", {
  r <- .rmse_subconjunto(data.frame(modelo_id = c(BENCHMARK, BENCHMARK, "A", "A"), error = c(2, -2, 1, -1)))
  expect_equal(r$rmse_relativo[r$modelo_id == "A"], 0.5)
  expect_identical(r$puesto[r$modelo_id == "A"], 1L)
})

test_that("AP-2: bloques de targets y ventanas móviles", {
  e <- .errores_ap2()
  b <- bloques_ap2(e, "G9")
  expect_setequal(unique(b$bloque), c("2013-2016", "2017-2019", "2020-2021", "2022-2026"))
  p <- b[b$modelo_id == "MIX.PUENTE.G9" & b$h == 1L, ]
  expect_identical(p$puesto[p$bloque == "2020-2021"], 1L)
  expect_identical(p$puesto[p$bloque == "2013-2016"], 3L)
  e2 <- e[e$t <= q_a_ind("2022-Q2"), ]                                             # 2022-2026 con 2 targets: se omite
  expect_false("2022-2026" %in% bloques_ap2(e2, "G9")$bloque)
  v <- ventanas_ap2(e, "G9")
  expect_identical(nrow(v), 4L * (40L - VENTANA_AP2 + 1L))
  w <- v[v$h == 1L & v$target_inicio == "2020-Q1", ]
  expect_identical(w$puesto_puente, 1L)
  expect_identical(w$mejor_modelo, "MIX.PUENTE.G9")
})
