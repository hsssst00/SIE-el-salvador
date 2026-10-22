# tests/test-combinacion-fase6.R
#
# Guarda, combinación e intervalos de Fase 6 (checklist D4; F6-02, F6-02-a, F6-07, F6-07-a, F6-07-b, F6-08, F6-08-a de
# doc/metodologia/decisiones_fase6.md), con datos SINTÉTICOS: no se lee data/. Comprueba el rango de la guarda contra
# el cálculo a mano y sin 2020-2021, el interanual del sendero con bases observadas, la exclusión de un sendero
# explosivo y los bordes, la mediana sobre Δy y el mínimo de miembros, que la mezcla de un solo miembro da las bandas
# normales exactas, que los cuantiles de la mezcla cumplen su función de distribución y la marca «sin calibrar».

library(testthat)
source(here::here("src", "proyeccion", "combinacion.R"))

.O_C <- q_a_ind("2026-Q2")
.obj_c <- function(semilla = 11, desde = "1995-Q1") {
  set.seed(semilla)
  i <- q_a_ind(desde):.O_C
  data.frame(periodo = ind_a_q(i), y = 4 + cumsum(0.006 + stats::rnorm(length(i), 0, 0.008)), stringsAsFactors = FALSE)
}
#' Sendero de log-nivel con crecimiento trimestral constante `g` desde el origen.
.sendero_c <- function(obj, g, h = 20L) obj$y[nrow(obj)] + g * seq_len(h)
#' Resultado de predecir_condicional() sintético: sendero = media, cov de un paseo aleatorio con varianza s2.
.res_c <- function(sendero, s2 = 1e-4) {
  h <- length(sendero); C <- s2 * outer(seq_len(h), seq_len(h), pmin)
  list(sendero = sendero, media = sendero, cov = C, J = matrix(0, h, 1))
}

test_that("rango_guarda reproduce el cálculo a mano y deja fuera los interanuales de 2020 y 2021", {
  obj <- .obj_c()
  obj$y[obj$periodo == "2020-Q2"] <- obj$y[obj$periodo == "2020-Q2"] - 0.25   # choque que no debe entrar
  r <- rango_guarda(obj)
  n <- nrow(obj); yoy <- 100 * (obj$y[5:n] - obj$y[1:(n - 4)]); anio <- as.integer(substr(obj$periodo[5:n], 1, 4))
  x <- yoy[!anio %in% c(2020L, 2021L)]
  expect_equal(r$minimo, min(x)); expect_equal(r$maximo, max(x)); expect_equal(r$X, sd(x)); expect_equal(r$n, length(x))
  expect_equal(c(r$inferior, r$superior), c(min(x) - sd(x), max(x) + sd(x)))
  expect_lt(min(yoy[anio == 2020L]), r$inferior)   # sin 2020, el choque queda fuera del rango
  expect_error(rango_guarda(obj[-10, ]), "faltantes")
  expect_error(rango_guarda(obj[1:5, ]), "menos de 6")
})

test_that("unidades_sendero usa las bases observadas con h <= 4 y el propio sendero después", {
  obj <- .obj_c(); s <- .sendero_c(obj, 0.01)
  u <- unidades_sendero(s, obj, .O_C)
  n <- nrow(obj)
  expect_equal(unname(u[1:4, "yoy_pp"]), 100 * (s[1:4] - obj$y[(n - 3):n]))
  expect_equal(unname(u[5:20, "yoy_pp"]), rep(4, 16))
  expect_equal(unname(u[1, "qoq_pp"]), 100 * (s[1] - obj$y[n]))
  expect_equal(unname(u[, "log_nivel"]), s)
})

test_that("aplicar_guarda excluye el sendero que sale del rango en algún h y marca el primero", {
  obj <- .obj_c(); rango <- list(inferior = -2, superior = 8)
  explosivo <- .sendero_c(obj, 0.01); explosivo[13:20] <- explosivo[13:20] + 0.05 * (1:8)^2
  g <- aplicar_guarda(list(A = .sendero_c(obj, 0.01), B = explosivo), obj, .O_C, rango)
  expect_equal(g$pasa, c(TRUE, FALSE))
  yoy_b <- unidades_sendero(explosivo, obj, .O_C)[, "yoy_pp"]
  expect_equal(g$h_fuera[2], which(yoy_b > 8)[1]); expect_true(is.na(g$h_fuera[1]))
  # Los bordes están permitidos: un sendero cuyo interanual máximo es igual al superior pasa.
  borde <- .sendero_c(obj, 0.02)
  sup <- max(unidades_sendero(borde, obj, .O_C)[, "yoy_pp"])
  expect_true(aplicar_guarda(list(C = borde), obj, .O_C, list(inferior = -100, superior = sup))$pasa)
  expect_error(aplicar_guarda(list(.sendero_c(obj, 0.01)), obj, .O_C, rango), "nombrada")
  expect_error(aplicar_guarda(list(A = c(1, NA)), obj, .O_C, rango), "no es finito")
})

test_that("combinar_mediana toma la mediana de los Δy, acumula desde y_o y exige el mínimo de miembros", {
  y_o <- 5
  s <- list(a = y_o + cumsum(c(0.01, 0.03, 0.00)), b = y_o + cumsum(c(0.02, 0.01, 0.05)), c = y_o + cumsum(c(0.04, 0.02, 0.01)))
  expect_equal(combinar_mediana(s, y_o), y_o + cumsum(c(0.02, 0.02, 0.01)))
  # Con miembros idénticos, la combinación es ese sendero.
  expect_equal(combinar_mediana(list(s$a, s$a, s$a), y_o), s$a)
  # Con 4 miembros, el promedio de los dos centrales de Δy.
  s4 <- c(s, list(d = y_o + cumsum(c(0.03, 0.00, 0.02))))
  expect_equal(combinar_mediana(s4, y_o), y_o + cumsum(c(0.025, 0.015, 0.015)))
  expect_error(combinar_mediana(s[1:2], y_o, etiqueta = "G2/BASE"), "G2/BASE tiene 2 miembros")
  expect_error(combinar_mediana(list(1:2, 1:3, 1:2), 0), "mismo largo")
})

test_that("bandas_mezcla con un solo miembro da las bandas normales exactas en las tres unidades", {
  obj <- .obj_c(); r <- .res_c(.sendero_c(obj, 0.012))
  b <- bandas_mezcla(list(r[c("media", "cov")]), obj, .O_C)
  expect_setequal(unique(b$unidad), UNIDADES_FASE6); expect_setequal(unique(b$nivel), c(0.80, 0.95))
  mu <- unidades_sendero(r$media, obj, .O_C); sd_ <- sd_unidades_densidad(r$cov)
  for (u in UNIDADES_FASE6) for (q in c(0.80, 0.95)) {
    f <- b[b$unidad == u & b$nivel == q, ]
    z <- stats::qnorm((1 + q) / 2)
    expect_equal(f$inferior, unname(mu[, u] - z * sd_[, match(u, UNIDADES_FASE6)]), tolerance = 1e-8)
    expect_equal(f$superior, unname(mu[, u] + z * sd_[, match(u, UNIDADES_FASE6)]), tolerance = 1e-8)
  }
  expect_equal(b$sin_calibrar, b$h > 8L)
  expect_equal(b$periodo[1:2], c("2026-Q3", "2026-Q4"))
})

test_that("los cuantiles de la mezcla cumplen su función de distribución y la mezcla no se recentra", {
  obj <- .obj_c()
  dens <- list(.res_c(.sendero_c(obj, 0.000), 4e-5), .res_c(.sendero_c(obj, 0.015), 1e-4), .res_c(.sendero_c(obj, 0.030), 2e-4))
  b <- bandas_mezcla(lapply(dens, `[`, c("media", "cov")), obj, .O_C)
  f <- b[b$unidad == "yoy_pp" & b$nivel == 0.80, ]
  mu <- sapply(dens, function(d) unidades_sendero(d$media, obj, .O_C)[, "yoy_pp"])
  sd_ <- sapply(dens, function(d) sd_unidades_densidad(d$cov)[, "sd_yoy_pp"])
  Fm <- function(x, t_) mean(stats::pnorm(x, mu[t_, ], sd_[t_, ]))
  expect_equal(vapply(1:20, function(t_) Fm(f$inferior[t_], t_), 0), rep(0.10, 20), tolerance = 1e-9)
  expect_equal(vapply(1:20, function(t_) Fm(f$superior[t_], t_), 0), rep(0.90, 20), tolerance = 1e-9)
  # La banda del 95 % contiene a la del 80 %.
  f95 <- b[b$unidad == "yoy_pp" & b$nivel == 0.95, ]
  expect_true(all(f95$inferior < f$inferior & f95$superior > f$superior))
  expect_error(bandas_mezcla(list(dens[[1]][c("media", "cov")], list(media = 1:3, cov = diag(3))), obj, .O_C), "mismo largo")
})

test_that("combinar_grupo aplica guarda, mínimo, mediana y mezcla en ese orden", {
  obj <- .obj_c(); rango <- rango_guarda(obj)
  explosivo <- .sendero_c(obj, 0.01) + c(rep(0, 10), 0.08 * (1:10)^2)
  res <- list(A = .res_c(.sendero_c(obj, 0.004)), B = .res_c(.sendero_c(obj, 0.006)),
              C = .res_c(.sendero_c(obj, 0.008)), X = .res_c(explosivo))
  cg <- combinar_grupo(res, obj, .O_C, rango, etiqueta = "G1/BASE")
  expect_equal(cg$guarda$pasa, c(TRUE, TRUE, TRUE, FALSE))
  expect_equal(cg$miembros, c("A", "B", "C"))
  expect_equal(cg$sendero$log_nivel, .sendero_c(obj, 0.006))
  esperada <- bandas_mezcla(lapply(res[c("A", "B", "C")], `[`, c("media", "cov")), obj, .O_C)
  expect_equal(cg$bandas, esperada)
  # El excluido se reporta igual, con sus bandas.
  expect_setequal(unique(cg$bandas_modelo$modelo_id), c("A", "B", "C", "X"))
  # Sin el tercer miembro, el mínimo dispara stop().
  expect_error(combinar_grupo(res[c("A", "B", "X")], obj, .O_C, rango, etiqueta = "G2/ADVERSO"), "G2/ADVERSO tiene 2 miembros")
  # El objetivo debe terminar en el origen.
  expect_error(combinar_grupo(res, obj[-nrow(obj), ], .O_C, rango), "termina en")
})

test_that("mediana_mezcla_normal sigue siendo el cuantil 0,5 de la mezcla (F6-13 a)", {
  mu <- matrix(c(0, 1, 2, 0.5, 0.5, 0.5), 3); sd_ <- matrix(c(1, 1, 2, 0.1, 0.2, 0.3), 3)
  expect_identical(mediana_mezcla_normal(mu, sd_), cuantil_mezcla_normal(mu, sd_, 0.5))
  expect_equal(mean(stats::pnorm(mediana_mezcla_normal(mu, sd_)[1], mu[, 1], sd_[, 1])), 0.5, tolerance = 1e-10)
})
