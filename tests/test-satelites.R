# tests/test-satelites.R
#
# Ecuaciones satélite de Fase 6 (checklist D3; F6-15, F6-15-a, F6-17-a de doc/metodologia/decisiones_fase6.md), con
# datos SINTÉTICOS: no se lee data/. Comprueba que el ADL recupera un DGP conocido y elige su (p, q) por BIC en una
# muestra común, que la muestra corta en `o` y deja fuera 2020-2021, que el sendero es la recursión de la ecuación con
# el Z del escenario y los trimestres observados después de `o` como dato, que Σ_X es G (Σ_e ⊗ I_h) G' con G la
# derivada exacta del sendero respecto de las innovaciones, el formato de senderos_x que pide predecir_condicional(),
# la regla de la serie BASE de F6-18 y las guardas. La prueba de Denton frente a tempdisagg de F6-16 está en
# tests/test-l3-escenarios.R.

library(testthat)
source(here::here("src", "proyeccion", "satelites.R"))

.O_SAT <- q_a_ind("2026-Q2")

#' Serie trimestral sintética (data.frame periodo, valor) de un Δlog nombrado por índice, desde nivel 100.
.nivel <- function(d) {
  i <- as.integer(names(d))
  data.frame(periodo = ind_a_q(c(i[1] - 1L, i)), valor = 100 * exp(cumsum(c(0, d))), stringsAsFactors = FALSE)
}

#' DGP: Δlog Z AR(1) y Δlog X = c + δ'D + φ Δlog X_{t−1} + β_0 Δlog Z_t + β_1 Δlog Z_{t−1} + e, hasta `hasta`.
.dgp <- function(semilla, desde = "1995-Q1", hasta = ind_a_q(.O_SAT + 20L), phi = 0.5, beta = c(0.8, 0.4), sd_e = 0.01) {
  set.seed(semilla)
  i <- q_a_ind(desde):q_a_ind(hasta); n <- length(i)
  dz <- as.numeric(stats::arima.sim(list(ar = 0.4), n, sd = 0.01)) + 0.005
  D <- dummies_trimestrales(i); g <- c(0.03, -0.02, 0.01)
  dx <- numeric(n); e <- stats::rnorm(n, 0, sd_e)
  for (t in seq_len(n)) {
    dx[t] <- 0.002 + sum(D[t, ] * g) + (if (t > 1) phi * dx[t - 1] else 0) + beta[1] * dz[t] + (if (t > 1) beta[2] * dz[t - 1] else 0) + e[t]
  }
  list(x = .nivel(stats::setNames(dx, i)), z = .nivel(stats::setNames(dz, i)))
}
.hasta <- function(d, o) d[q_a_ind(d$periodo) <= o, , drop = FALSE]

test_that("ajustar_satelite recupera el DGP y elige (p, q) = (1, 1) por BIC", {
  d <- .dgp(1, desde = "1960-Q1")
  s <- ajustar_satelite(d$x, d$z, .O_SAT, "SAT.PRUEBA")
  expect_identical(c(s$p, s$q), c(1L, 1L))
  expect_equal(s$phi, 0.5, tolerance = 0.1)
  expect_equal(s$beta, c(0.8, 0.4), tolerance = 0.3)
  expect_equal(s$gamma, c(0.03, -0.02, 0.01), tolerance = 0.3)
  expect_identical(nrow(s$grilla), 25L)
  expect_identical(s$grilla$bic[which.min(s$grilla$bic)], min(s$grilla$bic))
})

test_that("el BIC de cada candidato se calcula en la misma muestra y el elegido se reestima con su muestra máxima", {
  d <- .dgp(2)
  s <- ajustar_satelite(d$x, d$z, .O_SAT, "SAT.PRUEBA")
  dx <- .dlog_satelite(.hasta(d$x, .O_SAT), "x", "t"); dz <- .dlog_satelite(.hasta(d$z, .O_SAT), "z", "t")
  t_b <- .filas_satelite(dx, dz, .O_SAT, 4L, 4L)
  expect_identical(unname(s$gl[["n_obs"]]), length(t_b))
  i <- which(s$grilla$p == 2L & s$grilla$q == 0L)
  X <- .diseno_satelite(dx, dz, t_b, 2L, 0L)
  rss <- sum(stats::lm.fit(X, unname(dx[as.character(t_b)]))$residuals^2)
  expect_equal(s$grilla$bic[i], length(t_b) * log(rss / length(t_b)) + ncol(X) * log(length(t_b)))
  t_e <- .filas_satelite(dx, dz, .O_SAT, s$p, s$q)
  expect_identical(names(s$residuos), as.character(t_e))
  expect_gt(length(t_e), length(t_b) - 1L)
  f <- stats::lm.fit(.diseno_satelite(dx, dz, t_e, s$p, s$q), unname(dx[as.character(t_e)]))
  expect_equal(unname(f$coefficients[1]), s$c0)
})

test_that("la muestra termina en o y deja fuera las filas de 2020 y 2021 (F6-15)", {
  d <- .dgp(3)
  s <- ajustar_satelite(d$x, d$z, .O_SAT, "SAT.PRUEBA")
  anios <- as.integer(names(s$residuos)) %/% 4L
  expect_false(any(anios %in% c(2020L, 2021L)))
  expect_identical(max(as.integer(names(s$residuos))), .O_SAT)
  # Los datos posteriores a o no cambian el ajuste.
  s2 <- ajustar_satelite(.hasta(d$x, .O_SAT), .hasta(d$z, .O_SAT), .O_SAT, "SAT.PRUEBA")
  expect_identical(s2[c("p", "q", "c0", "phi", "beta", "gamma")], s[c("p", "q", "c0", "phi", "beta", "gamma")])
  # Un choque en 2020 tampoco, salvo por los rezagos de las filas de 2022.
  i20 <- which(substr(d$x$periodo, 1, 4) == "2020" & substr(d$x$periodo, 6, 7) == "Q2")
  x3 <- d$x; x3$valor[i20] <- x3$valor[i20] * 0.5
  x3$valor[(i20 + 1L):nrow(x3)] <- x3$valor[(i20 + 1L):nrow(x3)] * 0.5   # solo cambia Δlog de 2020-Q2
  s3 <- ajustar_satelite(x3, d$z, .O_SAT, "SAT.PRUEBA")
  expect_equal(s3$residuos, s$residuos)
})

test_that("proyectar_satelite itera la ecuación con el Z del escenario desde el primer trimestre sin dato", {
  d <- .dgp(4)
  s <- ajustar_satelite(d$x, d$z, .O_SAT, "SAT.PRUEBA")
  h <- 20L
  pr <- proyectar_satelite(s, .hasta(d$x, .O_SAT), d$z, h)
  expect_identical(names(pr$dlog), periodos_fase6(.O_SAT, h))
  expect_identical(pr$desde, 1L)
  dx <- .dlog_satelite(d$x, "x", "t"); dz <- .dlog_satelite(d$z, "z", "t")
  v <- dx[as.integer(names(dx)) <= .O_SAT]
  for (t in .O_SAT + seq_len(h)) {
    val <- s$c0 + sum(dummies_trimestrales(t) * s$gamma) + sum(s$phi * v[as.character(t - seq_len(s$p))]) + sum(s$beta * dz[as.character(t - 0:s$q)])
    v <- c(v, stats::setNames(val, t))
  }
  expect_equal(unname(pr$dlog), unname(v[as.character(.O_SAT + seq_len(h))]), tolerance = 1e-12)
  # Otro sendero de Z cambia el de X en la dirección de β_0.
  z2 <- d$z; fut <- q_a_ind(z2$periodo) > .O_SAT; z2$valor[fut] <- z2$valor[fut] * exp(0.01 * seq_len(sum(fut)))
  pr2 <- proyectar_satelite(s, .hasta(d$x, .O_SAT), z2, h)
  expect_equal(unname(pr2$dlog[1] - pr$dlog[1]), s$beta[1] * 0.01, tolerance = 1e-10)
})

test_that("los trimestres completos observados después de o entran como dato y la satélite arranca después (F6-17-a)", {
  d <- .dgp(5)
  s <- ajustar_satelite(d$x, d$z, .O_SAT, "SAT.PRUEBA")
  x2 <- .hasta(d$x, .O_SAT + 2L)
  pr <- proyectar_satelite(s, x2, d$z, 8L)
  dx <- .dlog_satelite(x2, "x", "t")
  expect_identical(pr$desde, 3L)
  expect_identical(unname(pr$dlog[1:2]), unname(dx[as.character(.O_SAT + 1:2)]))
  # Con todo el horizonte observado no hay satélite.
  pr_obs <- proyectar_satelite(s, d$x, d$z, 8L)
  expect_identical(pr_obs$desde, 9L)
})

test_that("Σ_X es G (Σ_e ⊗ I_h) G', con G la derivada exacta del sendero respecto de las innovaciones (F6-15-a)", {
  h <- 6L
  d1 <- .dgp(6); d2 <- .dgp(7, desde = "2000-Q1", phi = 0.3, beta = c(1.2, 0))
  a <- list(A = ajustar_satelite(d1$x, d1$z, .O_SAT, "SAT.A"), B = ajustar_satelite(d2$x, d2$z, .O_SAT, "SAT.B"))
  p <- list(A = proyectar_satelite(a$A, .hasta(d1$x, .O_SAT), d1$z, h),
            B = proyectar_satelite(a$B, .hasta(d2$x, .O_SAT + 2L), d2$z, h))       # B con dos trimestres de dato
  sx <- senderos_satelites(a, p, c("A", "B"))
  expect_identical(dim(sx$dlog), c(h, 2L)); expect_identical(colnames(sx$dlog), c("A", "B"))
  expect_identical(dim(sx$cov), c(2L * h, 2L * h))
  # Σ_e: covarianza muestral en los trimestres comunes.
  com <- intersect(names(a$A$residuos), names(a$B$residuos))
  expect_equal(unname(sx$Sigma_e), unname(stats::cov(cbind(a$A$residuos[com], a$B$residuos[com]))))
  # G por recursión con una innovación unitaria en la fila r: el sendero se mueve ψ_{s−r} en s >= r.
  G <- matrix(0, 2L * h, 2L * h)
  for (c_ in 1:2) {
    s <- a[[c_]]; pr <- p[[c_]]
    for (r in seq_len(h)) if (r >= pr$desde) {
      e <- numeric(h); e[r] <- 1; v <- numeric(h)
      for (t in seq_len(h)) v[t] <- e[t] + (if (s$p) sum(s$phi * vapply(seq_len(s$p), function(i) if (t - i >= 1) v[t - i] else 0, numeric(1))) else 0)
      G[(c_ - 1L) * h + seq_len(h), (c_ - 1L) * h + r] <- v
    }
  }
  expect_equal(sx$cov, G %*% kronecker(sx$Sigma_e, diag(h)) %*% t(G), tolerance = 1e-12)
  expect_true(all(sx$cov[h + 1:2, ] == 0))                      # filas observadas de B, sin error
  expect_equal(sx$cov[1, 1], sx$Sigma_e[1, 1])
  expect_false(sx$cov[h + 4, 4] == 0)                         # covarianza cruzada entre satélites
  expect_true(all(eigen(sx$cov, symmetric = TRUE, only.values = TRUE)$values > -1e-14))
})

test_that("senderos_satelites da el formato que acepta predecir_condicional() (F6-06-c)", {
  source(here::here("src", "proyeccion", "condicional.R"))
  h <- 20L; ids <- c("BCR.REMESAS.NOM.NSA.Q", "BCR.EXPORT_FOB.NOM.NSA.Q")
  ds <- list(.dgp(8), .dgp(9))
  a <- stats::setNames(lapply(seq_along(ids), function(i) ajustar_satelite(ds[[i]]$x, ds[[i]]$z, .O_SAT, SATELITES_FASE6[[ids[i]]])), ids)
  p <- stats::setNames(lapply(seq_along(ids), function(i) proyectar_satelite(a[[i]], .hasta(ds[[i]]$x, .O_SAT), ds[[i]]$z, h)), ids)
  sx <- senderos_satelites(a, p, ids)
  m <- senderos_modelo(sx, rev(ids), 8L, "PRUEBA")
  expect_identical(colnames(m$dx), rev(ids))
  expect_equal(m$Sx[1:8, 1:8], sx$cov[h + 1:8, h + 1:8])
  # Predictoras externas de los elegibles (F6-15): remesas en los 14, FOB en 12, ITCER e IPM en 6, IPP en 3.
  reg <- do.call(c, lapply(DISENO_FASE6$grupos, function(g) modelos_fase6(g)$condicionables))
  usa <- table(unlist(lapply(reg, predictoras_externas)))
  expect_identical(as.integer(usa[c("BCR.REMESAS.NOM.NSA.Q", "BCR.EXPORT_FOB.NOM.NSA.Q", "BCR.ITCER.IDX.NSA.Q", "BCR.IPM.IDX.NSA.Q", "BCR.IPP.IDX.NSA.Q", "BCR.REMESAS.REAL.NSA.Q")]),
                   c(14L, 12L, 6L, 6L, 3L, 1L))
})

test_that("serie_escenario usa la BASE cuando el escenario no publica la variable (F6-18)", {
  disp <- c(paste0("ESC.PIB_EEUU.VOL.SA.Q.", c("BASE", "ADVERSO", "FAVORABLE")), "ESC.PETROLEO_APSP.USD.NSA.Q.BASE")
  expect_identical(serie_escenario("BCR.REMESAS.NOM.NSA.Q", "ADVERSO", disp), "ESC.PIB_EEUU.VOL.SA.Q.ADVERSO")
  expect_identical(serie_escenario("BCR.IPM.IDX.NSA.Q", "ADVERSO", disp), "ESC.PETROLEO_APSP.USD.NSA.Q.BASE")
  expect_error(serie_escenario("BCR.ITCER.IDX.NSA.Q", "BASE", disp), "no hay")
  expect_error(serie_escenario("BCR.IVAE.VOL.SA.Q", "BASE", disp), "no tiene satélite")
  expect_error(serie_escenario("BCR.REMESAS.NOM.NSA.Q", "OTRO", disp), "no declarado")
})

test_that("guardas de la satélite (F6-15, F6-17-a)", {
  d <- .dgp(10)
  expect_error(ajustar_satelite(.hasta(d$x, .O_SAT - 1L), d$z, .O_SAT, "SAT.PRUEBA"), "no llega al origen")
  expect_error(ajustar_satelite(d$x, .hasta(d$z, .O_SAT - 1L), .O_SAT, "SAT.PRUEBA"), "no llega al origen")
  # Pocos grados de libertad: 2016-Q1..2026-Q2 sin 2020-2021 y sin las 5 primeras filas deja 29 < 13 + 20.
  corta <- .dgp(11, desde = "2016-Q1")
  expect_error(ajustar_satelite(corta$x, corta$z, .O_SAT, "SAT.PRUEBA"), "grados de libertad")
  # Z con Δlog constante: colineal con la constante.
  zc <- d$z; zc$valor <- 100 * exp(0.01 * seq_len(nrow(zc)))
  expect_error(ajustar_satelite(d$x, zc, .O_SAT, "SAT.PRUEBA"), "pierde rango")
  # Raíz dentro del círculo: Δlog X explosivo.
  set.seed(12); i <- q_a_ind("1960-Q1"):.O_SAT
  dz <- stats::setNames(stats::rnorm(length(i), 0, 0.01), i)
  dxu <- numeric(length(i)); dxu[1] <- 0.05
  for (t in 2:length(i)) dxu[t] <- 1.01 * dxu[t - 1] + 0.5 * dz[t] + stats::rnorm(1, 0, 0.001)
  dxu <- stats::setNames(dxu, i)
  expect_error(ajustar_satelite(.nivel(dxu), .nivel(dz), .O_SAT, "SAT.PRUEBA"), "raíz")
  s <- ajustar_satelite(d$x, d$z, .O_SAT, "SAT.PRUEBA")
  expect_error(proyectar_satelite(s, d$x, .hasta(d$z, .O_SAT + 5L), 8L), "no llega")
  expect_error(proyectar_satelite(s, .hasta(d$x, .O_SAT - 1L), d$z, 8L), "no llega al origen")
  p <- proyectar_satelite(s, d$x, d$z, 8L)
  expect_error(senderos_satelites(list(A = s), list(A = p), c("A", "B")), "falta la satélite")
  expect_error(senderos_satelites(list(A = s, B = s), list(A = p, B = proyectar_satelite(s, d$x, d$z, 6L)), c("A", "B")), "mismo h")
})
