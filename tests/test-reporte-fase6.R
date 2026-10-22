# tests/test-reporte-fase6.R
#
# Sensibilidad, reporte y coherencia de Fase 6 (checklist D6; F6-09, F6-09-a, F6-10, F6-11, F6-11-a, F6-11-b, F6-18-c de
# doc/metodologia/decisiones_fase6.md), con datos SINTÉTICOS: no se lee data/. Comprueba la desviación estándar del
# crecimiento anual sin 2020-2021, que el sendero de sensibilidad desplaza el crecimiento anual de las metas en ±1 sd y
# deja la historia intacta, la cifra anual contra el cálculo a mano, las bandas anuales (reproducibles con la semilla y
# degeneradas sin varianza), las identidades de F6-10 y que fallan si se adultera una tabla, y las informativas.

library(testthat)
source(here::here("src", "proyeccion", "reporte.R"))

.O_R <- q_a_ind("2026-Q2")
.obj_r <- function(semilla = 3) {
  set.seed(semilla)
  i <- q_a_ind("1995-Q1"):.O_R
  data.frame(periodo = ind_a_q(i), y = log(100) + cumsum(0.006 + stats::rnorm(length(i), 0, 0.008)), stringsAsFactors = FALSE)
}
.hist_q <- function(semilla, desde = "1990-Q1", hasta = "2026-Q2", g = 0.006) {
  set.seed(semilla)
  i <- q_a_ind(desde):q_a_ind(hasta)
  data.frame(periodo = ind_a_q(i), valor = 100 * exp(cumsum(g + stats::rnorm(length(i), 0, 0.01))), stringsAsFactors = FALSE)
}
.weo <- function(g = 2) data.frame(periodo = as.character(2000:2031), valor = g, stringsAsFactors = FALSE)
.esc_base <- function(semilla) sendero_escenario_crecimiento(.hist_q(semilla), .weo(), "prueba")

test_that("sd_crecimiento_anual reproduce el cálculo a mano sin 2020-2021", {
  h <- .hist_q(1, hasta = "2025-Q4")
  h$valor[q_a_ind(h$periodo) %/% 4L == 2020L] <- h$valor[q_a_ind(h$periodo) %/% 4L == 2020L] * 0.8
  a <- tapply(h$valor, q_a_ind(h$periodo) %/% 4L, mean)
  g <- 100 * (a[-1] / a[-length(a)] - 1)
  expect_equal(sd_crecimiento_anual(h, "p"), sd(g[!names(g) %in% c("2020", "2021")]))
  expect_lt(sd_crecimiento_anual(h, "p"), sd(g))
  expect_error(sd_crecimiento_anual(h[-5, ], "p"), "contigua")
})

test_that("metas_desde_sendero recupera las metas de T014 de la serie base", {
  e <- .esc_base(2)
  m <- metas_desde_sendero(e, "p")
  expect_equal(unname(m), unname(attr(e, "metas")), tolerance = 1e-10)
  expect_equal(names(m), names(attr(e, "metas")))
})

test_that("sendero_sensibilidad desplaza el crecimiento anual de cada año proyectado y deja la historia intacta", {
  e <- .esc_base(4); base <- attr(e, "metas")
  for (sg in c(1, -1)) {
    s <- sendero_sensibilidad(e, 0.7, sg, "p")
    m <- attr(s, "metas")
    expect_equal(unname(100 * (m[-1] / m[-length(m)] - 1)), unname(100 * (base[-1] / base[-length(base)] - 1) + sg * 0.7), tolerance = 1e-10)
    for (col in c("periodo", "valor")) expect_identical(s[[col]][s$tramo == "historia"], e[[col]][e$tramo == "historia"])
    expect_equal(utils::tail(s$periodo, 1), "2031-Q4")
  }
  expect_error(sendero_sensibilidad(e, 0, 1, "p"), "positiva")
  expect_error(sendero_sensibilidad(e, 0.7, 2, "p"), "signo")
})

test_that("escenarios_sensibilidad arma seis corridas y en cada una mueve una sola variable", {
  ids <- paste0(VARIABLES_SENSIBILIDAD, ".BASE")
  base <- stats::setNames(lapply(5:7, .esc_base), ids)
  cr <- escenarios_sensibilidad(base)
  expect_setequal(names(cr), c(outer(names(VARIABLES_SENSIBILIDAD), c("MAS", "MENOS"), paste, sep = ".")))
  expect_equal(names(attr(cr, "sd")), names(VARIABLES_SENSIBILIDAD))
  for (n in names(cr)) {
    movida <- ids[match(sub("\\..*$", "", n), names(VARIABLES_SENSIBILIDAD))]
    for (id in setdiff(ids, movida)) expect_identical(cr[[n]][[id]], base[[id]])
    expect_false(identical(cr[[n]][[movida]]$valor, base[[movida]]$valor))
  }
  expect_error(escenarios_sensibilidad(base[1:2]), "faltan")
})

test_that("anual_sendero promedia niveles del año calendario con la historia y marca el año del origen", {
  obj <- .obj_r(); s <- utils::tail(obj$y, 1) + 0.01 * seq_len(20)
  a <- anual_sendero(s, obj, .O_R)
  expect_equal(a$anio, 2026:2030)
  expect_equal(a$trimestres_observados, c(2L, 0L, 0L, 0L, 0L))
  y <- c(stats::setNames(obj$y, q_a_ind(obj$periodo)), stats::setNames(s, .O_R + 1:20))
  A <- function(an) mean(exp(y[as.character(4L * an + 0:3)]))
  expect_equal(a$nivel[1], A(2026)); expect_equal(a$crecimiento_pct[1], 100 * (A(2026) / A(2025) - 1))
  expect_equal(a$crecimiento_pct[3], 100 * (exp(0.04) - 1))
  expect_equal(attr(a, "promedio"), mean(a$crecimiento_pct))
  expect_error(anual_sendero(s[1:10], obj, .O_R), "no cubre")
})

test_that("bandas_anuales: reproducibles con la semilla, degeneradas sin varianza y con la marca sin_calibrar", {
  obj <- .obj_r(); s <- utils::tail(obj$y, 1) + 0.012 * seq_len(20)
  d <- list(media = s, cov = 1e-4 * outer(1:20, 1:20, pmin))
  b1 <- bandas_anuales(list(d), obj, .O_R, semilla = 7L, n_sim = 2000L)
  expect_identical(b1, bandas_anuales(list(d), obj, .O_R, semilla = 7L, n_sim = 2000L))
  expect_false(identical(b1$inferior, bandas_anuales(list(d), obj, .O_R, semilla = 8L, n_sim = 2000L)$inferior))
  a <- anual_sendero(s, obj, .O_R)
  f80 <- b1[b1$nivel == 0.80, ]
  expect_true(all(f80$inferior[1:5] < a$crecimiento_pct & f80$superior[1:5] > a$crecimiento_pct))
  expect_equal(f80$sin_calibrar, c(FALSE, FALSE, TRUE, TRUE, TRUE, TRUE))   # 2026-Q4 h = 2, 2027-Q4 h = 6, 2028-Q4 h = 10
  d0 <- list(media = s, cov = diag(1e-30, 20))
  b0 <- bandas_anuales(list(d0), obj, .O_R, semilla = 1L, n_sim = 50L)
  expect_equal(b0$inferior[b0$nivel == 0.95], c(a$crecimiento_pct, attr(a, "promedio")), tolerance = 1e-8)
  expect_error(bandas_anuales(list(d), obj, .O_R, semilla = NA), "semilla")
})

test_that("verificar_agregacion pasa con las tablas del reporte y falla si se adultera una", {
  obj <- .obj_r(); s <- utils::tail(obj$y, 1) + cumsum(0.004 + 0.002 * sin(1:20))
  d <- list(media = s, cov = 1e-4 * outer(1:20, 1:20, pmin))
  tq <- tabla_trimestral(s, obj, .O_R, bandas_mezcla(list(d), obj, .O_R))
  ta <- tabla_anual(s, obj, .O_R, bandas_anuales(list(d), obj, .O_R, semilla = 1L, n_sim = 500L))
  expect_true(all(c("yoy_pp_inf80", "yoy_pp_sup95", "log_nivel_inf95", "qoq_pp_sup80") %in% names(tq)))
  expect_true(all(tq$nota == NOTA_CONDICIONAL) && all(ta$nota == NOTA_CONDICIONAL))
  expect_equal(tq$sin_calibrar, tq$h > 8L)
  expect_silent(verificar_agregacion(tq, ta, obj, .O_R, "G1/BASE"))
  t2 <- tq; t2$qoq_pp[7] <- t2$qoq_pp[7] + 1e-6
  expect_error(verificar_agregacion(t2, ta, obj, .O_R, "G1/BASE"), "no acumula")
  a2 <- ta; a2$crecimiento_pct[3] <- a2$crecimiento_pct[3] + 1e-6
  expect_error(verificar_agregacion(tq, a2, obj, .O_R, "G1/BASE"), "agregación")
  a3 <- ta; a3$crecimiento_pct[a3$cifra == "promedio"] <- 0
  expect_error(verificar_agregacion(tq, a3, obj, .O_R), "promedio")
})

test_that("tabla_sensibilidad y coherencia_signos miden el cambio frente a la base", {
  obj <- .obj_r(); y_o <- utils::tail(obj$y, 1)
  base <- list(COMBINACION = y_o + 0.005 * 1:20, M1 = y_o + 0.006 * 1:20)
  mas <- lapply(base, function(s) s + 0.01); menos <- lapply(base, function(s) s - 0.01)
  ts <- tabla_sensibilidad(base, list(PIB_EEUU.MAS = mas, PIB_EEUU.MENOS = menos, IPC_EEUU.MAS = mas), obj, .O_R)
  expect_equal(nrow(ts), 6L)
  expect_equal(ts$nivel_2030_pct[ts$corrida == "PIB_EEUU.MAS"], rep(100 * (exp(0.01) - 1), 2))
  expect_equal(ts$variable[1], "PIB_EEUU"); expect_equal(ts$signo[3], "MENOS")
  cs <- coherencia_signos(ts)
  expect_true(all(cs$coincide[startsWith(cs$corrida, "PIB_EEUU")]))
  expect_true(all(is.na(cs$signo_esperado[startsWith(cs$corrida, "IPC_EEUU")])))
})

test_that("informativas: WEO, promedio histórico con y sin 2020 y deflactor implícito de las remesas", {
  obj <- .obj_r(); s <- utils::tail(obj$y, 1) + 0.006 * 1:20
  ta <- tabla_anual(s, obj, .O_R)
  w <- coherencia_weo(ta, c("2026" = 2.5, "2027" = 2.2, "2035" = 1))
  expect_equal(w$anio, 2026:2027)
  expect_equal(w$diferencia_pp, ta$crecimiento_pct[1:2] - c(2.5, 2.2))
  hi <- coherencia_historica(ta, obj, .O_R)
  expect_equal(c(hi$desde, hi$hasta), c(1996L, 2025L))
  expect_equal(hi$promedio_sendero, ta$crecimiento_pct[ta$cifra == "promedio"])
  # Deflactor constante de 1 % trimestral en la historia y en el sendero: interanual de 4 pp, dentro del rango.
  nom <- .hist_q(9, desde = "2010-Q1")
  real <- data.frame(periodo = nom$periodo, valor = nom$valor / exp(0.01 * seq_len(nrow(nom))), stringsAsFactors = FALSE)
  dl <- cbind(BCR.REMESAS.NOM.NSA.Q = rep(0.02, 20), BCR.REMESAS.REAL.NSA.Q = rep(0.01, 20))
  cd <- coherencia_deflactor(dl, nom, real, .O_R)
  expect_equal(cd$deflactor_yoy_pp, rep(4, 20), tolerance = 1e-10)
  expect_equal(c(cd$historico_min[1], cd$historico_max[1]), c(4, 4), tolerance = 1e-10)
  expect_true(all(cd$dentro | abs(cd$deflactor_yoy_pp - 4) < 1e-10))
  expect_error(coherencia_deflactor(dl[, 1, drop = FALSE], nom, real, .O_R), "dos remesas")
})
