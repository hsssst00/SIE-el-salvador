# tests/test-proyeccion-condicional.R
#
# Proyección condicional de Fase 6 (checklist D2; F6-01, F6-06, F6-06-a, F6-13, F6-15-a, F6-17 de
# doc/metodologia/decisiones_fase6.md), con datos SINTÉTICOS: no se lee data/. Comprueba el registro de elegibles y de
# la trayectoria sin escenario, la normal condicional contra la forma cerrada, que cada modelo reproduce su sendero de
# Fase 5 cuando el sendero impuesto es la proyección que el modelo habría hecho, que J es la derivada de la media
# (diferencias finitas: la media es lineal en el sendero), que Σ_X entra como J Σ_X J', que el BVAR con extracciones
# idénticas es el VAR condicional, el borde del puente (F6-17) y las guardas.

library(testthat)
source(here::here("src", "proyeccion", "condicional.R"))

.INICIOS_F6 <- c("BCR.REMESAS.NOM.NSA" = 1991L, "BCR.EXPORT_FOB.NOM.NSA" = 1994L, "BCR.ITCER.IDX.NSA" = 2000L,
                 "UT.DEMANDA_ELEC.GWH.NSA" = 2002L, "BCR.IVAE.VOL.SA" = 2005L, "BCR.IPM.IDX.NSA" = 2005L,
                 "BCR.IPP.IDX.NSA" = 2010L, "BCR.REMESAS.REAL.NSA" = 2010L)
.ind_a_m <- function(i) sprintf("%d-M%02d", i %/% 12L, i %% 12L + 1L)

.objetivo_f6 <- function(semilla) {
  set.seed(semilla)
  per <- ind_a_q(q_a_ind("1990-Q1") + 0:145)
  data.frame(periodo = per, y = 4 + cumsum(0.005 + as.numeric(stats::arima.sim(list(ar = 0.3), length(per), sd = 0.01))),
             stringsAsFactors = FALSE)
}
#' Predictoras trimestrales sintéticas hasta `hasta`, con estacionalidad en las NSA; `ligada` hace que las remesas
#' sigan al objetivo (para que el VAR tenga respuesta).
.predictoras_q <- function(semilla, obj, hasta = "2026-Q2") {
  set.seed(semilla)
  stats::setNames(lapply(names(.INICIOS_F6), function(f) {
    i <- q_a_ind(sprintf("%d-Q1", .INICIOS_F6[[f]])):q_a_ind(hasta)
    est <- if (grepl(".NSA", f, fixed = TRUE)) 0.03 * sin(pi * (i %% 4L) / 2) else 0
    ruido <- cumsum(0.004 + stats::rnorm(length(i), 0, 0.02))
    if (f == "BCR.REMESAS.NOM.NSA") ruido <- ruido + 0.5 * obj$y[match(ind_a_q(i), obj$periodo)]
    data.frame(periodo = ind_a_q(i), valor = 100 * exp(ruido + est), stringsAsFactors = FALSE)
  }), paste0(names(.INICIOS_F6), ".Q"))
}
.predictoras_m <- function(semilla, hasta = "2026-M08") {
  set.seed(semilla)
  stats::setNames(lapply(names(.INICIOS_F6), function(f) {
    i <- m_a_ind(sprintf("%d-M01", .INICIOS_F6[[f]])):m_a_ind(hasta)
    est <- if (grepl(".NSA", f, fixed = TRUE)) 0.03 * sin(2 * pi * (i %% 12L) / 12) else 0
    data.frame(periodo = .ind_a_m(i), valor = 100 * exp(cumsum(0.0015 + stats::rnorm(length(i), 0, 0.01)) + est), stringsAsFactors = FALSE)
  }), paste0(names(.INICIOS_F6), ".M"))
}
.hasta_q <- function(d, o) d[q_a_ind(d$periodo) <= o, , drop = FALSE]
.datos_q <- function(obj, pred, ids, o) c(list(objetivo = .hasta_q(obj, o)), lapply(pred[ids], .hasta_q, o = o))
.O_F6 <- q_a_ind("2026-Q2")

.modelo <- function(grupo, id) {
  r <- modelos_fase6(grupo); todos <- c(r$condicionables, r$sin_escenario)
  todos[[which(vapply(todos, `[[`, character(1), "modelo_id") == id)]]
}
#' senderos_x con las columnas `ids` y `dx` (h x k); Σ_X opcional.
.sx <- function(dx, ids, cov = NULL) { colnames(dx) <- ids; list(dlog = dx, cov = cov) }
#' J por diferencias finitas de la media (la media es lineal en el sendero, así que el paso no importa).
.J_numerico <- function(f, dx, paso = 1e-3) {
  base <- f(dx)$media
  vapply(seq_along(dx), function(j) { d2 <- dx; d2[j] <- d2[j] + paso; (f(d2)$media - base) / paso }, numeric(length(base)))
}
#' Σ_X sintética definida positiva para n = h k componentes.
.Sx <- function(n, semilla = 5) { set.seed(semilla); A <- matrix(stats::rnorm(n * n, 0, 0.003), n); crossprod(A) + diag(1e-6, n) }

ELEGIBLES_F6_01 <- list(
  G1 = c("UNI.ARIMAX.G1", "MULT.VAR_DIF.G1", "MULT.VAR_NIV.G1", "MULT.VECM.G1", "MULT.BVAR.G1", "MIX.PUENTE.G1"),
  G2 = c("UNI.ARIMAX.G2", "MULT.VAR_DIF.G2", "MULT.BVAR.G2", "MIX.PUENTE.G2"),
  G3 = c("UNI.ARIMAX.G3", "MULT.VAR_DIF.G3", "MULT.BVAR.G3", "MIX.PUENTE.G3"))

test_that("D2 (F6-01, F6-01-a, F6-01-b): registro de elegibles, trayectoria sin escenario y fuera", {
  bench <- vapply(modelos_referencia(), `[[`, character(1), "modelo_id")
  for (g in names(ELEGIBLES_F6_01)) {
    r <- modelos_fase6(g)
    cond <- vapply(r$condicionables, `[[`, character(1), "modelo_id")
    sin <- vapply(r$sin_escenario, `[[`, character(1), "modelo_id")
    expect_identical(cond, ELEGIBLES_F6_01[[g]], info = g)
    expect_identical(sin, c(bench, "UNI.ARIMA", "UNI.UC_LLT", if (g == "G2") "UNI.ARIMAX_IVAE.G2"), info = g)
    for (m in r$condicionables) expect_true(is.function(m$predecir_condicional) && is.function(m$predecir_densidad), info = m$modelo_id)
    for (m in r$sin_escenario) expect_null(m$predecir_condicional, info = m$modelo_id)
    fuera <- setdiff(c(bench, vapply(modelos_fase5(g), `[[`, character(1), "modelo_id")), c(cond, sin))
    expect_true(all(grepl("^(REG\\.|ML\\.|MIX\\.UMIDAS\\.)", fuera)), info = g)                # forma directa (F6-01-a)
    # Mismas predictoras que en Fase 5 (F6-04: YAML sin cambios).
    f5 <- stats::setNames(modelos_fase5(g), vapply(modelos_fase5(g), `[[`, character(1), "modelo_id"))
    for (m in r$condicionables) expect_identical(m$requiere, f5[[m$modelo_id]]$requiere, info = m$modelo_id)
  }
  expect_length(unlist(ELEGIBLES_F6_01), 14L)
  expect_false(es_condicionable(modelo_arimax_ivae()))                                         # F6-01-b: IVAE es interna
  expect_true(es_condicionable(modelo_puente_grupo("G1")))                                     # .M cuenta como su .Q
  expect_error(modelos_fase6("G4"), "grupo no declarado")
  m <- modelo_ar1(); m$predecir_condicional <- 1
  expect_error(.validar_modelo(m), "predecir_condicional debe ser una función")
})

test_that("D2 (F6-06-a): la normal condicional coincide con la forma cerrada", {
  Sig <- matrix(c(0.04, 0.012, 0.012, 0.09), 2)
  Phi <- array(diag(2), c(2, 2, 1)); mu <- matrix(c(1, 2), 1)
  cn <- condicionar_var(mu, Phi, Sig, 2L, matrix(2.5, 1))
  expect_equal(cn$media, 1 + 0.012 / 0.09 * 0.5, tolerance = 1e-14)
  expect_equal(cn$cov[1, 1], 0.04 - 0.012^2 / 0.09, tolerance = 1e-14)
  # Sin covarianza de choques ni propagación cruzada, condicionar no mueve al PIB.
  A <- list(diag(c(0.5, 0.8))); Phi3 <- pesos_ma_var(A, 3L); mu3 <- matrix(1:6, 3)
  cn3 <- condicionar_var(mu3, Phi3, diag(c(0.01, 0.02)), 2L, matrix(c(9, 9, 9), 3))
  expect_equal(cn3$media, 1:3); expect_equal(max(abs(cn3$K)), 0)
  expect_equal(cn3$cov, cov_sendero_var(Phi3, diag(c(0.01, 0.02)), acumular = FALSE), tolerance = 1e-14)
  # Mediana de una mezcla: con componentes iguales es la media; con dos simétricas, el centro.
  expect_equal(mediana_mezcla_normal(matrix(c(1, 1), 2), matrix(c(0.1, 0.1), 2)), 1, tolerance = 1e-10)
  expect_equal(mediana_mezcla_normal(matrix(c(-1, 1), 2), matrix(c(0.5, 0.5), 2)), 0, tolerance = 1e-10)
})

test_that("D2 (F6-06): senderos_x se valida y se recorta por predictora y horizonte", {
  ids <- c("BCR.REMESAS.NOM.NSA.Q", "BCR.EXPORT_FOB.NOM.NSA.Q")
  dx <- matrix(seq_len(10) / 100, 5); C <- diag(seq_len(10))
  s <- senderos_modelo(.sx(dx, ids, C), "BCR.EXPORT_FOB.NOM.NSA.Q", 3L, "P")
  expect_identical(unname(s$dx[, 1]), dx[1:3, 2]); expect_equal(s$Sx, diag(c(6, 7, 8)), tolerance = 0)
  expect_identical(senderos_modelo(.sx(dx, ids), ids, 2L, "P")$Sx, matrix(0, 4, 4))
  expect_error(senderos_modelo(.sx(dx, ids), "BCR.IPM.IDX.NSA.Q", 2L, "P"), "no trae el sendero de BCR.IPM")
  expect_error(senderos_modelo(.sx(dx, ids), ids, 6L, "P"), "llega a h = 5")
  expect_error(senderos_modelo(.sx(dx, ids, diag(3)), ids, 2L, "P"), "matriz finita")
  expect_error(senderos_modelo(list(dlog = dx), ids, 2L, "P"), "colnames")
})

test_that("D2 (F6-06): ARIMAX — el sendero de su AR reproduce Fase 5; J y Σ_X; densidad sin las externas", {
  obj <- .objetivo_f6(21); pred <- .predictoras_q(22, obj); h <- 20L
  for (g in c("G1", "G2")) {
    m <- .modelo(g, paste0("UNI.ARIMAX.", g)); ids <- setdiff(m$requiere, "objetivo")
    aj <- m$ajustar(.datos_q(obj, pred, ids, .O_F6), NULL)
    ext <- ids[ids %in% names(SATELITES_FASE6)]
    dx <- vapply(ext, function(id) unname(.proyectar_ar_x(aj$ars[[id]], h)), numeric(h))
    r <- m$predecir_condicional(aj, h, .sx(dx, ext))
    expect_equal(r$sendero, m$predecir(aj, h), tolerance = 1e-12, info = g)
    expect_identical(r$media, r$sendero)
    expect_true(all(diag(r$cov) <= diag(m$predecir_densidad(aj, h)$cov) + 1e-14), info = g)
    expect_equal(r$J, .J_numerico(function(d) m$predecir_condicional(aj, h, .sx(d, ext)), dx), tolerance = 1e-7, info = g)
    Sx <- .Sx(length(dx))
    r2 <- m$predecir_condicional(aj, h, .sx(dx, ext, Sx))
    expect_equal(r2$cov, r$cov + r$J %*% Sx %*% t(r$J), tolerance = 1e-14, info = g)
    expect_identical(r2$sendero, r$sendero)
  }
  # G1 no tiene internas: la densidad es la del error ARMA integrado.
  m <- .modelo("G1", "UNI.ARIMAX.G1"); ids <- setdiff(m$requiere, "objetivo")
  aj <- m$ajustar(.datos_q(obj, pred, ids, .O_F6), NULL)
  r <- m$predecir_condicional(aj, 6L, .sx(matrix(0.01, 6, 2), ids))
  expect_equal(r$cov, cov_desde_pesos(pesos_arima(aj$ar, aj$ma, 1L, 6L), aj$Sigma[1, 1]), tolerance = 1e-14)
  expect_equal(r$J[1, 7], aj$beta[[ids[2]]][1], tolerance = 1e-15)                             # β_0 de la FOB en o+1
})

test_that("D2 (F6-06-a): VAR, VAR en niveles y VECM — el sendero incondicional reproduce Fase 5; J y Σ_X", {
  obj <- .objetivo_f6(31); pred <- .predictoras_q(32, obj); h <- 20L
  for (id in ELEGIBLES_F6_01$G1[2:4]) {
    m <- .modelo("G1", id); ids <- setdiff(m$requiere, "objetivo")
    aj <- m$ajustar(.datos_q(obj, pred, ids, .O_F6), NULL)
    f <- stats::predict(aj$fit, n.ahead = h)$fcst[1L + seq_along(ids)]
    dx <- vapply(seq_along(ids), function(i) {
      v <- unname(f[[i]][, "fcst"])
      if (aj$forma == "dif") v else diff(c(aj$fit$y[nrow(aj$fit$y), 1L + i], v))
    }, numeric(h))
    r <- m$predecir_condicional(aj, h, .sx(dx, ids))
    expect_equal(r$sendero, m$predecir(aj, h), tolerance = 1e-10, info = paste(id, aj$forma))
    expect_true(all(diag(r$cov) <= diag(m$predecir_densidad(aj, h)$cov) * (1 + 1e-10)), info = id)
    expect_equal(r$J, .J_numerico(function(d) m$predecir_condicional(aj, h, .sx(d, ids)), dx), tolerance = 1e-6, info = id)
    Sx <- .Sx(length(dx))
    expect_equal(m$predecir_condicional(aj, h, .sx(dx, ids, Sx))$cov, r$cov + r$J %*% Sx %*% t(r$J), tolerance = 1e-12, info = id)
  }
  # El VAR de G2 solo condiciona las remesas; el IVAE responde.
  m <- .modelo("G2", "MULT.VAR_DIF.G2"); ids <- setdiff(m$requiere, "objetivo")
  aj <- m$ajustar(.datos_q(obj, pred, ids, .O_F6), NULL)
  r <- m$predecir_condicional(aj, 8L, .sx(matrix(0.02, 8, 1), "BCR.REMESAS.NOM.NSA.Q"))
  expect_identical(dim(r$J), c(8L, 8L))
  expect_error(m$predecir_condicional(aj, 8L, .sx(matrix(0.02, 8, 1), "BCR.EXPORT_FOB.NOM.NSA.Q")), "no trae el sendero de BCR.REMESAS")
})

test_that("D2 (F6-06-a, F6-13): BVAR con extracciones idénticas = VAR condicional en niveles; mediana = media", {
  set.seed(41)
  Y <- apply(matrix(stats::rnorm(240, 0.005, 0.01), 80), 2, cumsum); Y[, 2] <- Y[, 2] + 0.5 * Y[, 1]
  colnames(Y) <- c("PIB", "X1", "X2")
  fit <- vars::VAR(Y, p = 2L, type = "const")
  Bc <- vars::Bcoef(fit)                                     # M x (M p + 1): y1.l1 .. yM.l2, const
  B <- t(Bc[, c(ncol(Bc), seq_len(ncol(Bc) - 1L))])           # (1 + M p) x M: constante, rezago 1, rezago 2
  Sig <- crossprod(stats::resid(fit)) / fit$obs
  beta <- aperm(array(B, c(dim(B), 3L)), c(3, 1, 2)); sigma <- aperm(array(Sig, c(3, 3, 3L)), c(3, 1, 2))
  h <- 12L; vx <- matrix(Y[80, 2:3], h, 2, byrow = TRUE) + outer(seq_len(h), c(0.006, 0.004))
  r <- condicional_extracciones_var(beta, sigma, Y, 2L, h, 2:3, vx, matrix(0, 2 * h, 2 * h))
  mu <- vapply(stats::predict(fit, n.ahead = h)$fcst, function(f) unname(f[, "fcst"]), numeric(h))
  cn <- condicionar_var(mu, pesos_ma_var(vars::Acoef(fit), h), Sig, 2:3, vx)
  expect_equal(r$media, cn$media, tolerance = 1e-10)
  expect_equal(r$cov, cn$cov, tolerance = 1e-12)
  expect_equal(r$sendero, r$media, tolerance = 1e-9)
  expect_equal(r$J, cn$K %*% kronecker(diag(2), .acumulador(h)), tolerance = 1e-10)
})

test_that("D2 (F6-06-a, F6-13): BVAR ajustado — h = 20, unidades desestacionalizadas, J, Σ_X y mezcla", {
  obj <- .objetivo_f6(51); pred <- .predictoras_q(52, obj); h <- 20L
  r6 <- modelos_fase6("G1"); m6 <- r6$condicionables[[5]]
  expect_identical(m6$modelo_id, "MULT.BVAR.G1")
  ids <- setdiff(m6$requiere, "objetivo")
  m <- modelo_bvar("PRUEBA.BVAR", ids, n_draw = 600L, n_burn = 300L, H = h, extracciones = TRUE)
  m$predecir_condicional <- function(aj, h, sx) condicional_bvar(aj, h, sx, ids)
  set.seed(53); aj <- m$ajustar(.datos_q(obj, pred, ids, .O_F6), NULL)
  expect_identical(aj$H, h); expect_identical(dim(aj$beta), c(300L, 13L, 3L))
  # El sendero en unidades del BVAR, con la estacionalidad devuelta, es el log-nivel observado más el Δlog impuesto.
  dx <- matrix(rep(c(0.01, -0.005), each = h), h)
  vx <- niveles_condicion_bvar(aj, dx, 2:3)
  bruto <- vx + aj$estacional[(aj$o + seq_len(h)) %% 4L + 1L, 2:3]
  l_o <- log(vapply(ids, function(id) utils::tail(pred[[id]]$valor[q_a_ind(pred[[id]]$periodo) <= .O_F6], 1), numeric(1)))
  expect_equal(unname(diff(rbind(l_o, bruto))), dx, tolerance = 1e-12)
  r <- m$predecir_condicional(aj, h, .sx(dx, ids))
  expect_silent(validar_condicional(r, h, "PRUEBA"))
  expect_equal(r$J, .J_numerico(function(d) m$predecir_condicional(aj, h, .sx(d, ids)), dx), tolerance = 1e-6)
  expect_true(all(abs(r$sendero - r$media) < sqrt(diag(r$cov))))                               # mediana cerca de la media
  Sx <- .Sx(2L * h)
  r2 <- m$predecir_condicional(aj, h, .sx(dx, ids, Sx))
  expect_true(all(diag(r2$cov) > diag(r$cov)))
  expect_identical(r2$media, r$media)
  expect_identical(m$predecir_condicional(aj, h, .sx(dx, ids)), r)                              # determinista dado el ajuste
  expect_error(condicional_bvar(modelo_bvar("P", ids, n_draw = 200L, n_burn = 100L)$ajustar(.datos_q(obj, pred, ids, .O_F6), NULL), h, .sx(dx, ids), ids),
               "no guardó las extracciones")
  # Fase 5 no cambia: sin extracciones, el ajuste es el de siempre.
  set.seed(53); aj5 <- modelo_bvar("PRUEBA.BVAR", ids, n_draw = 600L, n_burn = 300L, H = h)$ajustar(.datos_q(obj, pred, ids, .O_F6), NULL)
  expect_identical(aj5, aj[names(aj5)])
})

test_that("D2 (F6-17): puente — borde observado, sendero desde el primer trimestre sin meses; J y Σ_X", {
  obj <- .objetivo_f6(61); pm <- .predictoras_m(62); h <- 20L
  m <- .modelo("G2", "MIX.PUENTE.G2"); ids <- setdiff(m$requiere, "objetivo")
  rz <- rezagos_predictoras(ids)
  d <- c(list(objetivo = .hasta_q(obj, .O_F6)), stats::setNames(lapply(ids, function(id) recortar_a_origen(pm[[id]], .O_F6, rz[[id]])), ids))
  aj <- m$ajustar(d, NULL)
  expect_identical(aj$H, h)
  ext <- which(.id_q(ids) %in% names(SATELITES_FASE6)); ids_q <- .id_q(ids)[ext]
  expect_identical(.id_q(ids)[-ext], c("UT.DEMANDA_ELEC.GWH.NSA.Q", "BCR.IVAE.VOL.SA.Q"))
  dx <- aj$dX_fut[seq_len(h), ext, drop = FALSE]
  r <- m$predecir_condicional(aj, h, .sx(dx, ids_q))
  expect_identical(r$sendero, sendero_puente(aj, h))                                            # mismos Δlog: Fase 5
  # Los trimestres con meses observados no usan el sendero (F6-17): mover o+1 no cambia nada si o+1 tiene meses.
  con_meses <- aj$ult[ext] >= ultimo_mes_trimestre(.O_F6) + 1L
  expect_true(any(con_meses))
  d2 <- dx; d2[1, ] <- d2[1, ] + 0.05
  r_o1 <- m$predecir_condicional(aj, h, .sx(d2, ids_q))
  if (all(con_meses)) expect_identical(r_o1$sendero, r$sendero) else expect_false(identical(r_o1$sendero, r$sendero))
  expect_true(all(r$J[, (which(con_meses) - 1L) * h + 1L] == 0))
  expect_equal(r$J, .J_numerico(function(dd) m$predecir_condicional(aj, h, .sx(dd, ids_q)), dx), tolerance = 1e-7)
  # Sin máscara, la covarianza es la de Fase 5; con máscara, los trimestres impuestos no aportan innovaciones mensuales.
  expect_identical(cov_sistema_puente(aj, h, matrix(FALSE, h, length(ids))), cov_sistema_puente(aj, h))
  expect_true(sum(diag(r$cov)) < sum(diag(cov_sistema_puente(aj, h))))
  Sx <- .Sx(length(dx))
  expect_equal(m$predecir_condicional(aj, h, .sx(dx, ids_q, Sx))$cov, r$cov + r$J %*% Sx %*% t(r$J), tolerance = 1e-12)
  expect_error(m$predecir_condicional(aj, 21L, .sx(rbind(dx, 0), ids_q)), "se pidió h = 21")
})

test_that("D2 (F6-01): trayectoria sin escenario con h = 20", {
  obj <- .objetivo_f6(71); pred <- .predictoras_q(72, obj)
  for (m in modelos_fase6("G2")$sin_escenario) {
    ids <- setdiff(m$requiere, "objetivo")
    aj <- m$ajustar(.datos_q(obj, pred, ids, .O_F6), NULL)
    t20 <- trayectoria_sin_escenario(m, aj)
    expect_length(t20$sendero, 20L)
    expect_true(all(is.finite(t20$sendero)), info = m$modelo_id)
    expect_equal(is.null(t20$cov), m$modelo_id == "BENCH.MEDIA_CRECIMIENTO", info = m$modelo_id)
    expect_equal(t20$sendero[1:8], m$predecir(aj, 8L), tolerance = 1e-12, info = m$modelo_id)
  }
})
