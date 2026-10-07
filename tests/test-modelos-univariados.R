# tests/test-modelos-univariados.R
#
# Modelos univariados de Fase 5 (bloque B1b; F5-06, F5-12, B1-1 a B1-5 y B1b-1 de
# doc/metodologia/decisiones_fase5.md), con datos SINTÉTICOS: no se lee data/. Comprueba el registro por grupo,
# la regla de diferencias, las tres densidades contra oráculos independientes (fable, KalmanForecast y una
# simulación del sistema ARIMAX), la proyección de las predictoras, la guarda de colinealidad, el piso de grados
# de libertad en el primer origen de cada grupo con las fechas de inicio reales de L3 (checklist C1) y el canal
# de diagnósticos del motor.

library(testthat)
source(here::here("src", "evaluacion", "motor_backtesting.R"))   # eval_lib, modelos_referencia, modelos_fase5

# Inicios de las predictoras trimestrales en L3 (los de F4-05 y de evidencia_insumos_fase4.csv).
.INICIOS_L3 <- c("BCR.REMESAS.NOM.NSA.Q" = "1991-Q1", "BCR.EXPORT_FOB.NOM.NSA.Q" = "1994-Q1", "BCR.ITCER.IDX.NSA.Q" = "2000-Q1",
                 "UT.DEMANDA_ELEC.GWH.NSA.Q" = "2002-Q1", "BCR.IVAE.VOL.SA.Q" = "2005-Q1", "BCR.IPM.IDX.NSA.Q" = "2005-Q1",
                 "BCR.IPP.IDX.NSA.Q" = "2010-Q1", "BCR.REMESAS.REAL.NSA.Q" = "2010-Q1")

.objetivo_sint <- function(semilla, phi = 0.3, sd = 0.01) {
  set.seed(semilla)
  per <- ind_a_q(q_a_ind("1990-Q1") + 0:144)
  dy <- 0.005 + as.numeric(stats::arima.sim(list(ar = phi), length(per), sd = sd))
  data.frame(periodo = per, y = 4 + cumsum(dy), stringsAsFactors = FALSE)
}
.predictoras_sint <- function(semilla, ids = names(.INICIOS_L3), hasta = "2026-Q2") {
  set.seed(semilla)
  stats::setNames(lapply(ids, function(id) {
    i <- q_a_ind(.INICIOS_L3[[id]]):q_a_ind(hasta)
    est <- if (grepl(".NSA.", id, fixed = TRUE)) 0.03 * sin(pi * (i %% 4L) / 2) else 0
    data.frame(periodo = ind_a_q(i), valor = 100 * exp(cumsum(0.004 + stats::rnorm(length(i), 0, 0.02)) + est), stringsAsFactors = FALSE)
  }), ids)
}
.hasta <- function(d, o) d[q_a_ind(d$periodo) <= o, , drop = FALSE]

test_that("F5-06, B1-3: modelos_fase5 devuelve los univariados de cada grupo bajo el contrato", {
  esperados <- list(G1 = c("UNI.ARIMA", "UNI.UC_LLT", "UNI.ARIMAX.G1"),
                    G2 = c("UNI.ARIMA", "UNI.UC_LLT", "UNI.ARIMAX.G2", "UNI.ARIMAX_IVAE.G2"),
                    G3 = c("UNI.ARIMA", "UNI.UC_LLT", "UNI.ARIMAX.G3"))
  for (g in names(esperados)) {
    ms <- modelos_fase5(g)
    ids <- vapply(ms, `[[`, character(1), "modelo_id")
    expect_identical(ids[startsWith(ids, "UNI.")], esperados[[g]], info = g)       # B2a agrega los MULT.* después
    for (m in ms) {
      expect_silent(.validar_modelo(m))
      expect_true(isTRUE(m$piso_gl) || startsWith(m$modelo_id, "MULT.BVAR."), info = m$modelo_id)   # B2-7: el BVAR, sin piso
      expect_true(is.function(m$predecir_densidad) && is.function(m$diagnosticar), info = m$modelo_id)
    }
    ax <- ms[[3]]
    expect_identical(ax$requiere, c("objetivo", predictoras_no_penalizadas(g)))     # F5-06 con B1b-2
  }
  # B1b-1 y B1b-2: en G3 los modelos sin penalización llevan solo las remesas nominales; G1 y G2 sin cambios
  expect_identical(predictoras_no_penalizadas("G1"), predictoras_grupo("G1"))
  expect_identical(predictoras_no_penalizadas("G2"), predictoras_grupo("G2"))
  expect_identical(predictoras_no_penalizadas("G3"), setdiff(predictoras_grupo("G3"), "BCR.REMESAS.REAL.NSA.Q"))
  expect_identical(predictoras_no_penalizadas("G3", "M"), setdiff(predictoras_grupo("G3", "M"), "BCR.REMESAS.REAL.NSA.M"))
  expect_length(predictoras_no_penalizadas("G3"), 7L)
  expect_true("BCR.REMESAS.NOM.NSA.Q" %in% predictoras_no_penalizadas("G3"))
  expect_false("BCR.REMESAS.REAL.NSA.Q" %in% modelo_arimax_grupo("G3")$requiere)
  expect_true(all(predictoras_no_penalizadas("G2") %in% predictoras_no_penalizadas("G3")))   # G2 ⊂ G3 encadenado
  expect_identical(modelo_arimax_ivae()$requiere, c("objetivo", "BCR.IVAE.VOL.SA.Q"))
  # grillas de B1-2
  expect_identical(modelo_arimax_grupo("G1")$rezagos_x, 0:1); expect_identical(nrow(modelo_arimax_grupo("G1")$grilla), 9L)
  expect_identical(modelo_arimax_grupo("G2")$rezagos_x, 0:1); expect_identical(nrow(modelo_arimax_grupo("G2")$grilla), 6L)
  expect_true(all(rowSums(modelo_arimax_grupo("G2")$grilla) <= 2L))
  expect_identical(modelo_arimax_grupo("G3")$rezagos_x, 0L); expect_identical(nrow(modelo_arimax_grupo("G3")$grilla), 9L)
  expect_identical(nrow(modelo_arimax_ivae()$grilla), 9L)
  expect_error(modelo_arimax_grupo("G4"), "grupo no declarado")
})

test_that("diferencias_kpss: 0 en ruido blanco, 1 en paseo aleatorio, 2 en una serie I(2)", {
  set.seed(101); e <- stats::rnorm(120)
  expect_identical(diferencias_kpss(e), 0L)
  expect_identical(diferencias_kpss(cumsum(e)), 1L)
  expect_identical(diferencias_kpss(cumsum(cumsum(e))), 2L)
  expect_identical(diferencias_kpss(cumsum(cumsum(cumsum(e)))), 2L)             # tope d_max = 2
})

test_that("pesos_arima generaliza pesos_ar_dy y da los pesos MA en d = 0", {
  expect_equal(pesos_arima(c(0.5, -0.2), numeric(0), 1L, 8L), pesos_ar_dy(c(0.5, -0.2), 8L), tolerance = 1e-14)
  expect_equal(pesos_arima(numeric(0), numeric(0), 1L, 5L), pesos_ar_dy(numeric(0), 5L), tolerance = 1e-14)
  C <- pesos_arima(numeric(0), c(0.4, 0.1), 0L, 4L)
  expect_equal(C[4, ], c(0, 0.1, 0.4, 1)); expect_equal(C[2, 1], 0.4)
  C2 <- pesos_arima(numeric(0), numeric(0), 2L, 3L)                                # (1 - B)^2: ψ = 1, 2, 3
  expect_equal(C2[3, ], c(3, 2, 1))
})

test_that("UNI.ARIMA: el sendero es el de fable y la densidad reproduce su varianza de pronóstico", {
  obj <- .hasta(.objetivo_sint(11), q_a_ind("2015-Q4"))
  m <- modelo_arima_fase5()
  aj <- m$ajustar(list(objetivo = obj), NULL)
  expect_identical(aj$d, diferencias_kpss(obj$y))
  fc <- fabletools::forecast(aj$m, h = 8)
  dens <- m$predecir_densidad(aj, 8L)
  expect_silent(validar_densidad(dens, m$predecir(aj, 8L)))
  expect_equal(diag(dens$cov), as.numeric(distributional::variance(fc$y)), tolerance = 1e-8)
  expect_identical(aj$gl[["n_par"]], 9L); expect_identical(aj$gl[["n_obs"]], nrow(obj) - aj$d)
  dg <- m$diagnosticar(aj)
  expect_identical(names(dg), c("p", "d", "q", "constante")); expect_true(all(dg[c("p", "q")] <= 4))
  # con d = 2 no hay constante (sería una tendencia cuadrática en el log-nivel)
  set.seed(27); y2 <- 4 + cumsum(cumsum(stats::rnorm(100, 0, 0.003)))
  o2 <- data.frame(periodo = ind_a_q(q_a_ind("1995-Q1") + 0:99), y = y2, stringsAsFactors = FALSE)
  aj2 <- expect_silent(m$ajustar(list(objetivo = o2), NULL))
  expect_identical(aj2$d, 2L); expect_false(aj2$constante)
  expect_equal(diag(m$predecir_densidad(aj2, 4L)$cov), as.numeric(distributional::variance(fabletools::forecast(aj2$m, h = 4)$y)), tolerance = 1e-8)
})

test_that("UNI.UC_LLT: la diagonal de la covarianza conjunta es la varianza de KalmanForecast", {
  obj <- .hasta(.objetivo_sint(12), q_a_ind("2018-Q2"))
  m <- modelo_uc_llt()
  aj <- m$ajustar(list(objetivo = obj), NULL)
  kf <- stats::KalmanForecast(8L, aj$mod)
  dens <- m$predecir_densidad(aj, 8L)
  expect_silent(validar_densidad(dens, m$predecir(aj, 8L)))
  expect_equal(diag(dens$cov), as.numeric(kf$var), tolerance = 1e-10)
  expect_equal(dens$media, as.numeric(kf$pred))
  # en un paseo aleatorio puro con ruido (pendiente fija) la covarianza entre horizontes es la acumulada
  mod <- list(T = matrix(c(1, 0, 1, 1), 2), Z = c(1, 0), P = diag(0, 2), V = diag(c(1, 0)), h = 0)
  expect_equal(cov_estado_uc(mod, 3L), outer(1:3, 1:3, pmin))
})

test_that("seleccionar_ar_bic_x sin dummies coincide con seleccionar_ar_bic y proyecta con dummies", {
  set.seed(13); x <- stats::setNames(as.numeric(stats::arima.sim(list(ar = 0.6), 90)) / 100, q_a_ind("2000-Q1") + 0:89)
  a <- seleccionar_ar_bic(unname(x), p_max = 4L); b <- seleccionar_ar_bic_x(x, dummies = FALSE, p_max = 4L)
  expect_identical(b$p, a$p); expect_equal(b$c0, a$c0); expect_equal(b$phi, a$phi); expect_equal(b$s2, a$s2); expect_equal(b$bic, a$bic)
  expect_identical(names(b$residuos), names(x)[(b$p + 1L):length(x)])
  # con estacionalidad determinista, la proyección repite el patrón de las dummies
  iq <- q_a_ind("2000-Q1") + 0:79
  xs <- stats::setNames(c(0, 0.05, -0.03, 0.01)[iq %% 4L + 1L] + stats::rnorm(80, 0, 1e-4), iq)
  s <- seleccionar_ar_bic_x(xs, dummies = TRUE, p_max = 4L)
  pr <- .proyectar_ar_x(s, 4L)
  expect_identical(names(pr), as.character(utils::tail(iq, 1) + 1:4))
  expect_equal(unname(pr), c(0, 0.05, -0.03, 0.01)[(utils::tail(iq, 1) + 1:4) %% 4L + 1L], tolerance = 1e-3)
  expect_error(seleccionar_ar_bic_x(unname(xs)), "nombrada por trimestres")
})

test_that("ARIMAX: la covarianza del sistema conjunto coincide con la simulación de sus recursiones (F5-12, B1-5)", {
  obj <- .objetivo_sint(14)
  pred <- .predictoras_sint(15, ids = c("BCR.REMESAS.NOM.NSA.Q", "BCR.EXPORT_FOB.NOM.NSA.Q"))
  o <- q_a_ind("2016-Q4")
  m <- modelo_arimax("PRUEBA.ARIMAX", names(pred), rezagos_x = 0:1, p_max = 2L, q_max = 2L)
  datos <- c(list(objetivo = .hasta(obj, o)), lapply(pred, .hasta, o = o))
  aj <- m$ajustar(datos, NULL)
  h <- 6L
  S <- cov_sistema_arimax(aj, h)
  expect_silent(validar_densidad(list(media = m$predecir(aj, h), cov = S), m$predecir(aj, h)))
  # Simulación independiente: recursiones del AR de cada predictora, del ARMA del error y de la ecuación de Δy
  # con innovaciones w_r ~ N(0, Σ); el error del sendero es la desviación respecto de la trayectoria sin
  # innovaciones (el pasado es común y se cancela).
  k <- length(aj$predictoras); ar <- aj$ar; ma <- aj$ma; R <- 40000L
  set.seed(16); W <- matrix(stats::rnorm(R * h * (k + 1L)), ncol = k + 1L) %*% chol(aj$Sigma)
  camino <- function(w) {                                    # w: h x (k+1); devuelve el error del log-nivel
    xe <- matrix(0, h + 1L, k)                               # fila 1 = origen (error 0)
    for (i in seq_len(k)) {
      phi <- aj$ars[[i]]$phi
      for (s in seq_len(h)) xe[s + 1L, i] <- w[s, 1L + i] + (if (length(phi)) sum(phi * rev(utils::tail(c(rep(0, length(phi)), xe[1:s, i]), length(phi)))) else 0)
    }
    eta <- numeric(h)
    for (s in seq_len(h)) {
      pa <- c(rep(0, length(ar)), eta[seq_len(s - 1L)]); pe <- c(rep(0, length(ma)), w[seq_len(s - 1L), 1L])
      eta[s] <- w[s, 1L] + (if (length(ar)) sum(ar * rev(utils::tail(pa, length(ar)))) else 0) +
        (if (length(ma)) sum(ma * rev(utils::tail(pe, length(ma)))) else 0)
    }
    ddy <- eta
    for (i in seq_len(k)) for (l in seq_along(aj$rezagos_x)) ddy <- ddy + aj$beta[[i]][l] * xe[(1:h) + 1L - aj$rezagos_x[l], i]
    cumsum(ddy)
  }
  E <- t(vapply(seq_len(R), function(r) camino(W[(r - 1L) * h + seq_len(h), , drop = FALSE]), numeric(h)))
  Se <- crossprod(E) / R
  expect_lt(max(abs(diag(Se) / diag(S) - 1)), 0.04)
  expect_lt(max(abs(stats::cov2cor(Se) - stats::cov2cor(S))), 0.03)
  # con Σ diagonal la covarianza es menor o igual en h = 1 solo si la covarianza cruzada es positiva: aquí
  # se comprueba la forma, Σ completa por construcción (B1-5)
  expect_identical(dim(aj$Sigma), c(k + 1L, k + 1L))
  expect_true(any(abs(aj$Sigma[upper.tri(aj$Sigma)]) > 0))
})

test_that("ARIMAX: muestra común, regresores futuros y sendero (B1-1, F5-04, F5-05)", {
  obj <- .objetivo_sint(17)
  pred <- .predictoras_sint(18, ids = c("BCR.REMESAS.NOM.NSA.Q", "BCR.EXPORT_FOB.NOM.NSA.Q"))
  o <- q_a_ind("2013-Q1")
  m <- modelo_arimax_grupo("G1")
  aj <- m$ajustar(c(list(objetivo = .hasta(obj, o)), lapply(pred, .hasta, o = o)), NULL)
  # muestra: de 1994-Q3 (Δlog del FOB desde 1994-Q2 y su rezago) hasta o
  expect_identical(aj$gl[["n_obs"]], o - q_a_ind("1994-Q3") + 1L)
  expect_identical(aj$gl[["n_par"]], 1L + 4L + 3L + 4L)
  Xf <- .xreg_futuro(aj, 3L)
  expect_equal(as.numeric(Xf[1, 2]), as.numeric(aj$dx[["BCR.REMESAS.NOM.NSA.Q"]][as.character(o)]))   # rezago 1 en h = 1: observado en o
  expect_equal(as.numeric(Xf[1, 1]), as.numeric(.proyectar_ar_x(aj$ars[[1]], 1L)))                      # rezago 0 en h = 1: proyectado
  expect_identical(ncol(Xf), 4L + 3L)
  expect_equal(m$predecir(aj, 3L), aj$y_o + cumsum(as.numeric(stats::predict(aj$fit, n.ahead = 3L, newxreg = Xf)$pred)))
  # una predictora que no llega al origen detiene el ajuste
  corto <- c(list(objetivo = .hasta(obj, o)), lapply(pred, .hasta, o = o - 1L))
  expect_error(m$ajustar(corto, NULL), "no llega al origen 2013-Q1")
  neg <- c(list(objetivo = .hasta(obj, o)), lapply(pred, .hasta, o = o)); neg[[2]]$valor[5] <- -1
  expect_error(m$ajustar(neg, NULL), "no positivos")
})

test_that("B1b-1: la guarda numérica detiene la ARIMAX ante pérdida de rango o colinealidad extrema", {
  obj <- .objetivo_sint(19)
  pred <- .predictoras_sint(20, ids = c("BCR.REMESAS.NOM.NSA.Q", "BCR.EXPORT_FOB.NOM.NSA.Q"))
  o <- q_a_ind("2016-Q4")
  dup <- pred; dup[["BCR.EXPORT_FOB.NOM.NSA.Q"]] <- dup[["BCR.REMESAS.NOM.NSA.Q"]][q_a_ind(dup[["BCR.REMESAS.NOM.NSA.Q"]]$periodo) >= q_a_ind("1994-Q1"), ]
  m <- modelo_arimax("PRUEBA.ARIMAX", names(pred), rezagos_x = 0L, p_max = 1L, q_max = 1L)
  expect_error(m$ajustar(c(list(objetivo = .hasta(obj, o)), lapply(dup, .hasta, o = o)), NULL), "pierde rango")
  casi <- dup; set.seed(21)
  casi[[2]]$valor <- casi[[2]]$valor * exp(stats::rnorm(nrow(casi[[2]]), 0, 1e-7))
  expect_error(m$ajustar(c(list(objetivo = .hasta(obj, o)), lapply(casi, .hasta, o = o)), NULL), "número de condición .* > 1e\\+04 \\(B1b-1\\)")
  # con correlación alta pero sin pérdida de rango (como remesas nominales y reales, ~0,99) el modelo corre
  alta <- dup; alta[[2]]$valor <- alta[[2]]$valor * exp(cumsum(stats::rnorm(nrow(alta[[2]]), 0, 0.003)))
  aj <- m$ajustar(c(list(objetivo = .hasta(obj, o)), lapply(alta, .hasta, o = o)), NULL)
  expect_gt(aj$cor_max, 0.9); expect_lt(aj$kappa, KAPPA_MAX_ARIMAX)
})

test_that("C1, F5-03: G-8 pasa en el primer origen de cada grupo con las fechas de inicio de L3 y la grilla es el límite", {
  obj <- .objetivo_sint(22)
  pred <- .predictoras_sint(23)
  rez <- rezagos_predictoras(names(pred))
  esperado <- c(G1 = 75L, G2 = 38L, G3 = 39L)                                      # B1-2
  for (g in names(esperado)) {
    o1 <- origenes_grupo(g)[1]
    ms <- c(list(modelo_arimax_grupo(g)), if (g == "G2") list(modelo_arimax_ivae()))
    r <- correr_backtest(c(list(objetivo = obj), pred[predictoras_grupo(g)]), ms, o1, rezagos = rez[predictoras_grupo(g)], densidad = TRUE)
    d <- attr(r, "diagnosticos")
    expect_identical(as.integer(d$valor[d$modelo_id == ms[[1]]$modelo_id & d$clave == "n_obs"]), esperado[[g]], info = g)
    gl <- ms[[1]]$ajustar(c(list(objetivo = .hasta(obj, o1)), lapply(pred[predictoras_no_penalizadas(g)], .hasta, o = o1)), NULL)$gl
    expect_identical(unname(gl[["n_obs"]] - gl[["n_par"]]), c(G1 = 63L, G2 = 20L, G3 = 24L)[[g]], info = g)   # holgura sobre el piso
    expect_true(all(is.finite(r$sd_log_nivel)), info = g)
  }
  # G2 está justo en el piso: abrir la grilla a p + q <= 3 lo rompe en el primer origen
  ancho <- modelo_arimax("UNI.ARIMAX.G2", predictoras_grupo("G2"), rezagos_x = 0:1, p_max = 2L, q_max = 2L, pq_max = 3L)
  expect_error(correr_backtest(c(list(objetivo = obj), pred[predictoras_grupo("G2")]), list(ancho), origenes_grupo("G2")[1],
                               rezagos = rez[predictoras_grupo("G2")]),
               "^G-8 modelo UNI.ARIMAX.G2 en 2014-Q4: 38 observaciones efectivas y 19 parámetros dejan 19 grados de libertad")
  # G3 (7 predictoras, B1b-2) con rezagos 0..1 y p + q = 2 no cabe: 1 + 14 + 3 + 2 = 20 parámetros con 38 observaciones
  g3_01 <- modelo_arimax("UNI.ARIMAX.G3", predictoras_no_penalizadas("G3"), rezagos_x = 0:1, p_max = 1L, q_max = 1L)
  expect_error(correr_backtest(c(list(objetivo = obj), pred[predictoras_grupo("G3")]), list(g3_01), origenes_grupo("G3")[1],
                               rezagos = rez[predictoras_grupo("G3")]),
               "^G-8 modelo UNI.ARIMAX.G3 en 2019-Q4: 38 observaciones efectivas y 20 parámetros dejan 18 grados de libertad")
})

test_that("diagnosticar: el motor recoge los diagnósticos por origen y valida su forma", {
  obj <- .objetivo_sint(24)
  base <- list(modelo_id = "PRUEBA.DIAG", requiere = "objetivo",
               ajustar = function(datos, spec) list(y_o = utils::tail(datos$objetivo$y, 1), n = nrow(datos$objetivo)),
               predecir = function(aj, h) rep(aj$y_o, h), diagnosticar = function(aj) c(n = aj$n, uno = 1))
  ors <- q_a_ind(c("2013-Q1", "2013-Q2"))
  r <- correr_backtest(list(objetivo = obj), list(base, modelo_rw_sin_deriva()), ors)
  d <- attr(r, "diagnosticos")
  expect_identical(names(d), c("modelo_id", "origen", "clave", "valor"))
  expect_identical(d$clave, c("n", "uno", "n", "uno")); expect_identical(d$valor[c(1, 3)], c(93, 94))
  expect_null(attr(correr_backtest(list(objetivo = obj), list(modelo_rw_sin_deriva()), ors), "diagnosticos"))   # Fase 4 intacta
  malo <- base; malo$diagnosticar <- function(aj) c(1, 2)
  expect_error(correr_backtest(list(objetivo = obj), list(malo), ors), "nombres únicos")
  malo2 <- base; malo2$diagnosticar <- "no"
  expect_error(correr_backtest(list(objetivo = obj), list(malo2), ors), "diagnosticar debe ser una función")
})

test_that("correr_experimento lleva los diagnósticos a res$diagnosticos con exp_id y origen en texto", {
  # El objetivo sintético de V12 y de test-predictoras-fase5.R (con un paseo puro el AR(p)-BIC replica al paseo
  # con deriva y el MCS se detiene por varianza bootstrap nula).
  set.seed(20260924L + 12L)
  per <- ind_a_q(q_a_ind("1990-Q1") + 0:144)
  dy <- numeric(length(per)); e <- stats::rnorm(length(per), 0, 0.008)
  for (t in 2:length(per)) dy[t] <- 0.003 + 0.5 * dy[t - 1] + e[t]
  y <- 4.6 + cumsum(dy)
  i20 <- match(c("2020-Q2", "2020-Q3"), per); y[i20] <- y[i20] + c(-0.20, -0.08)
  obj <- data.frame(periodo = per, y = y, vintage_id = "SINT.v1", stringsAsFactors = FALSE)
  pred <- .predictoras_sint(26, ids = predictoras_grupo("G1"))
  ex <- EXPERIMENTOS_PRINCIPALES_FASE5[EXPERIMENTOS_PRINCIPALES_FASE5$exp_id == "F5_G1", ]
  ex$sa <- "l3_unico"; ex$r3 <- FALSE; ex$r4 <- FALSE        # con este objetivo sintético el MCS de alguna submuestra de los
                                                              # benchmarks se detiene por varianza bootstrap nula
  insumos <- list(objetivos = list(PIB_SA_PROPIO_Q = obj), predictoras = pred, conjunto = list(etiqueta = "corte_sint@0123abcd"))
  orig <- modelos_fase5
  assign("modelos_fase5", function(grupo) list(modelo_arimax_grupo(grupo)), envir = globalenv())
  on.exit(assign("modelos_fase5", orig, envir = globalenv()), add = TRUE)
  r <- correr_experimento(ex, insumos, new.env())
  expect_identical(names(r$diagnosticos), c("exp_id", "modelo_id", "origen", "clave", "valor"))
  expect_identical(unique(r$diagnosticos$origen), ind_a_q(origenes_grupo("G1")))
  expect_true(all(r$diagnosticos$modelo_id == "UNI.ARIMAX.G1"))
  expect_true("UNI.ARIMAX.G1" %in% r$densidad_ids)
  ex_ref <- EXPERIMENTOS_REPRO[EXPERIMENTOS_REPRO$grupo == "G1", ][1, ]; ex_ref$sa <- "l3_unico"; ex_ref$r3 <- FALSE; ex_ref$r4 <- FALSE
  expect_null(correr_experimento(ex_ref, insumos, new.env())$diagnosticos)                     # F5_REPRO_*: sin diagnósticos
})
