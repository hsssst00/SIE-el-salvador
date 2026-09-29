# tests/test-evaluacion.R
#
# Ejercita src/evaluacion/eval_lib.R con datos construidos, sin tocar disco ni datos del proyecto
# (especificación del motor §8). Corre en CI.

library(testthat)
source(here::here("src", "evaluacion", "eval_lib.R"))
source(here::here("src", "evaluacion", "modelos_referencia.R"))

.obj_lineal <- function(inicio = "1990-Q1", n = 145L, pendiente = 0.01) {
  data.frame(periodo = ind_a_q(q_a_ind(inicio) + 0:(n - 1L)), y = log(100) + pendiente * (0:(n - 1L)),
             stringsAsFactors = FALSE)
}
.mensual <- function(inicio, n) {
  i0 <- m_a_ind(inicio)
  data.frame(periodo = sprintf("%d-M%02d", (i0 + 0:(n - 1L)) %/% 12L, (i0 + 0:(n - 1L)) %% 12L + 1L),
             valor = seq_len(n), stringsAsFactors = FALSE)
}

# --- 1. períodos -------------------------------------------------------------------------------

test_that("índices trimestrales y mensuales van y vuelven, y rechazan formatos ajenos", {
  expect_identical(ind_a_q(q_a_ind(c("1990-Q1", "2013-Q1", "2026-Q1"))), c("1990-Q1", "2013-Q1", "2026-Q1"))
  expect_identical(q_a_ind("2013-Q2") - q_a_ind("2013-Q1"), 1L)
  expect_identical(m_a_ind("2020-M03") - m_a_ind("2019-M12"), 3L)
  expect_error(q_a_ind("2013-T1"), "mal formado")
  expect_error(q_a_ind("2013Q1"), "mal formado")
  expect_error(m_a_ind("2020-03"), "mal formado")
  expect_error(m_a_ind("2020-M13"), "mal formado")
})

test_that("fin de mes y de trimestre respetan años bisiestos", {
  expect_identical(fin_de_mes_ind(m_a_ind("2020-M02")), as.Date("2020-02-29"))
  expect_identical(fin_de_mes_ind(m_a_ind("2019-M02")), as.Date("2019-02-28"))
  expect_identical(fin_de_mes_ind(m_a_ind("2019-M12")), as.Date("2019-12-31"))
  expect_identical(fin_de_trimestre_ind(q_a_ind("2020-Q1")), as.Date("2020-03-31"))
  expect_identical(fin_de_trimestre_ind(q_a_ind("2019-Q4")), as.Date("2019-12-31"))
})

# --- 2. diseño de orígenes (F4-01) -------------------------------------------------------------

test_that("la convención A reproduce los conteos de ADR-002 y las lecturas alternativas dan los suyos", {
  h <- c(1L, 2L, 4L, 8L)
  a  <- conteo_por_horizonte(pares_evaluables(origenes_diseno("2013-Q1", "2025-Q4"), h, "2026-Q1"))
  a2 <- conteo_por_horizonte(pares_evaluables(origenes_diseno("2013-Q1", "2025-Q4"), h, "2025-Q4"))
  b  <- conteo_por_horizonte(pares_evaluables(origenes_diseno("2012-Q4", "2025-Q3"), h, "2025-Q4"))
  b2 <- conteo_por_horizonte(pares_evaluables(origenes_diseno("2012-Q4", "2025-Q4"), h, "2026-Q1"))
  expect_identical(unname(a),  c(52L, 51L, 49L, 45L))
  expect_identical(unname(a2), c(51L, 50L, 48L, 44L))
  expect_identical(unname(b),  c(52L, 51L, 49L, 45L))
  expect_identical(unname(b2), c(53L, 52L, 50L, 46L))
  expect_length(origenes_diseno(), 52L)
  expect_error(origenes_diseno("2025-Q4", "2013-Q1"), "anterior")
})

test_that("con la convención A la muestra del primer origen tiene 93 observaciones", {
  expect_identical(nrow(recortar_a_origen(.obj_lineal(), q_a_ind("2013-Q1"))), 93L)
})

# --- 3. conjunto de información (F4-02) --------------------------------------------------------

test_that("la regla de calendario deja 1 mes del trimestre siguiente con rezago 61 y 2 con rezago <= 30", {
  o <- q_a_ind("2019-Q4")                                   # corte: 2019-12-31 + 92 = 2020-04-01
  expect_identical(fecha_corte_origen(o), as.Date("2020-04-01"))
  m <- .mensual("2019-M01", 24L)
  ult <- function(rez) utils::tail(recortar_a_origen(m, o, rezago = rez)$periodo, 1)
  expect_identical(ult(61L), "2020-M01")                    # IVAE, IPM
  expect_identical(ult(30L), "2020-M02")                    # ITCER
  expect_identical(ult(24L), "2020-M02")                    # remesas, exportaciones
  expect_identical(ult(10L), "2020-M02")                    # IPP: el tercer mes termina el 31-mar, publica el 10-abr
})

test_that("el objetivo entra exactamente hasta el origen y una mensual sin rezago falla", {
  obj <- .obj_lineal()
  r <- recortar_a_origen(obj, q_a_ind("2019-Q4"))
  expect_identical(utils::tail(r$periodo, 1), "2019-Q4")
  expect_error(recortar_a_origen(.mensual("2019-M01", 6L), q_a_ind("2019-Q4")), "necesita su rezago")
})

test_that("G-1 rechaza una serie con períodos fuera del conjunto de información", {
  obj <- .obj_lineal()
  expect_error(guarda_recorte(obj, q_a_ind("2013-Q1"), nombre = "objetivo"), "^G-1 filtración: objetivo")
  expect_true(guarda_recorte(recortar_a_origen(obj, q_a_ind("2013-Q1")), q_a_ind("2013-Q1")))
  m <- .mensual("2019-M01", 24L)
  expect_error(guarda_recorte(m, q_a_ind("2019-Q4"), rezago = 61L), "^G-1")
})

# --- 4. bucle de orígenes ---------------------------------------------------------------------

test_that("correr_backtest aplica las guardas G-3 y G-4 y el contrato", {
  s <- list(objetivo = .obj_lineal())
  o <- origenes_diseno()[1:3]
  corto <- list(modelo_id = "P.CORTO", requiere = "objetivo", ajustar = function(d, sp) NULL, predecir = function(a, h) rep(1, h - 1L))
  expect_error(correr_backtest(s, list(corto), o), "^G-3")
  pide <- list(modelo_id = "P.PIDE", requiere = c("objetivo", "remesas"), ajustar = function(d, sp) NULL, predecir = function(a, h) rep(1, h))
  expect_error(correr_backtest(s, list(pide), o), "^G-4 .* ausentes: remesas")
  expect_error(correr_backtest(s, list(modelo_rw_sin_deriva()), o, min_obs = 100L), "^G-4 .* mínimo 100")
  expect_error(correr_backtest(s, list(modelo_rw_sin_deriva(), modelo_rw_sin_deriva()), o), "duplicado")
  expect_error(correr_backtest(s, list(list(modelo_id = "X", requiere = "objetivo")), o), "contrato")
  expect_error(correr_backtest(s, list(modelo_rw_sin_deriva()), o, rezagos = list(objetivo = 92L)), "no lleva rezago")
  expect_error(correr_backtest(list(objetivo = s$objetivo[1:90, ]), list(modelo_rw_sin_deriva()), o), "no está observado")
})

test_that("correr_backtest devuelve un sendero de h_max por modelo y origen", {
  p <- correr_backtest(list(objetivo = .obj_lineal()), list(modelo_rw_sin_deriva(), modelo_rw_con_deriva()), origenes_diseno())
  expect_identical(nrow(p), 2L * 52L * 8L)
  expect_setequal(unique(p$modelo_id), c("BENCH.RW_SIN_DERIVA", "BENCH.RW_CON_DERIVA"))
})

test_that("correr_backtest no altera el generador aleatorio del llamador", {
  s <- list(objetivo = .obj_lineal())
  estocastico <- list(modelo_id = "P.ESTOC", requiere = "objetivo", ajustar = function(d, sp) stats::rnorm(8),
                      predecir = function(a, h) a[seq_len(h)])
  set.seed(99); esperado <- stats::runif(3)
  set.seed(99); invisible(correr_backtest(s, list(estocastico), origenes_diseno()[1:2])); obtenido <- stats::runif(3)
  expect_identical(obtenido, esperado)
  # y dos réplicas de un bucle que llama al motor no reciben la misma secuencia
  set.seed(7)
  r1 <- stats::rnorm(1); invisible(correr_backtest(s, list(estocastico), origenes_diseno()[1])); r2 <- stats::rnorm(1)
  expect_false(identical(r1, r2))
})

test_that("la semilla depende de (exp_id, modelo_id, origen) y es determinista", {
  expect_identical(semilla_de("E", "M", 100L), semilla_de("E", "M", 100L))
  expect_false(identical(semilla_de("E", "M", 100L), semilla_de("E", "M", 101L)))
  expect_false(identical(semilla_de("E", "M", 100L), semilla_de("E2", "M", 100L)))
})

# --- 5. unidades y errores (F4-04) ---------------------------------------------------------------

test_that("la tasa interanual usa base observada hasta h=4 y pronosticada después", {
  obj <- .obj_lineal(pendiente = 0.01)
  o <- q_a_ind("2019-Q4")
  p <- derivar_unidades(correr_backtest(list(objetivo = obj), list(modelo_rw_sin_deriva()), o), obj)
  y <- stats::setNames(obj$y, q_a_ind(obj$periodo))
  # RW sin deriva: sendero plano en y_o
  expect_equal(p$yoy_pp_pronosticado[p$h == 1], 100 * (y[[as.character(o)]] - y[[as.character(o - 3L)]]))
  expect_equal(p$yoy_pp_pronosticado[p$h == 4], 0)                  # base observada = y_o
  expect_equal(p$yoy_pp_pronosticado[p$h == 8], 0)                  # base pronosticada = y_o
  expect_equal(p$qoq_pp_pronosticado, rep(0, 8))
})

test_that("calcular_errores solo evalúa pares observados y el RW con deriva no yerra en una serie lineal", {
  obj <- .obj_lineal()
  p <- correr_backtest(list(objetivo = obj), list(modelo_rw_con_deriva()), origenes_diseno())
  e <- calcular_errores(p, obj)
  expect_identical(unname(conteo_por_horizonte(e[e$unidad == "yoy_pp", ])), c(52L, 51L, 49L, 45L))
  expect_setequal(unique(e$unidad), c("yoy_pp", "qoq_pp", "log_nivel"))
  expect_lt(max(abs(e$error)), 1e-10)
})

# --- 6. métricas ------------------------------------------------------------------------------

test_that("las métricas coinciden con cálculos a mano", {
  err <- data.frame(modelo_id = "M", origen = 1:4, h = 1L, unidad = "yoy_pp", pronostico = 0,
                    observado = c(1, -1, 2, -2), error = c(1, -1, 2, -2))
  m <- metricas_por_horizonte(err)
  expect_equal(m$rmse, sqrt(10 / 4))
  expect_equal(m$mae, 1.5)
  expect_equal(m$sesgo, 0)
  expect_equal(m$n_pares, 4L)
  expect_equal(varianza_nw(c(1, -1, 2, -2), 0L), mean(c(1, -1, 2, -2)^2))
})

test_that("el RMSE relativo del benchmark es 1 y exige la misma muestra", {
  err <- rbind(
    data.frame(modelo_id = "BENCH.RW_SIN_DERIVA", origen = 1:4, h = 1L, unidad = "yoy_pp", pronostico = 0, observado = 1, error = 1),
    data.frame(modelo_id = "OTRO", origen = 1:4, h = 1L, unidad = "yoy_pp", pronostico = 0.5, observado = 1, error = 0.5))
  m <- agregar_rmse_relativo(metricas_por_horizonte(err))
  expect_equal(m$rmse_relativo[m$modelo_id == "BENCH.RW_SIN_DERIVA"], 1)
  expect_equal(m$rmse_relativo[m$modelo_id == "OTRO"], 0.5)
  expect_error(agregar_rmse_relativo(metricas_por_horizonte(err[-8, ])), "pares distintos")
  expect_error(agregar_rmse_relativo(metricas_por_horizonte(err[err$modelo_id == "OTRO", ])), "no está en las métricas")
})

# --- 7. token (F4-11) --------------------------------------------------------------------------

test_that("el token canónico se construye y valida, y los desvíos fallan", {
  tok <- construir_token("expansiva", "G1", "revision_vigente", "reestimado_en_origen", "yoy_pp")
  expect_identical(tok, "expansiva|origen=ultimo_estimado|grupo=G1|vintage=revision_vigente|sa=reestimado_en_origen|perdida=yoy_pp")
  expect_identical(validar_token(tok)$grupo, "G1")
  expect_error(validar_token("expansiva|origen=ultimo_estimado|vintage=revision_vigente|sa=l3_unico|perdida=yoy_pp"), "5 campos")
  expect_error(validar_token(sub("G1", "G4", tok)), "valor no declarado para grupo")
  expect_error(validar_token(sub("expansiva", "rodante40", tok)), "valor no declarado para ventana")
  expect_error(validar_token(sub("grupo=G1|vintage=revision_vigente", "vintage=revision_vigente|grupo=G1", tok, fixed = TRUE)), "debe ser `grupo=")
  expect_error(validar_token(c(tok, tok)), "único string")
})

# --- 11. densidad predictiva gaussiana (F4-33; remediación de la auditoría de Fase 4, E1) ---------

test_that("CRPS gaussiano: forma cerrada contra la integral de la definición y valores conocidos", {
  expect_equal(crps_normal(0, 0, 1), 2 * dnorm(0) - 1 / sqrt(pi), tolerance = 1e-15)
  expect_equal(crps_normal(0, 0, 1), 0.2336949772, tolerance = 1e-9)
  for (caso in list(c(0.3, 0, 1), c(-2.1, 0.5, 0.7), c(4, 1, 2.5))) {
    y <- caso[1]; mu <- caso[2]; s <- caso[3]
    integ <- integrate(function(x) pnorm(x, mu, s)^2, -Inf, y, rel.tol = 1e-12)$value +
             integrate(function(x) (1 - pnorm(x, mu, s))^2, y, Inf, rel.tol = 1e-12)$value
    expect_equal(crps_normal(y, mu, s), integ, tolerance = 1e-8)
  }
  expect_equal(crps_normal(3, 1, 2), 2 * crps_normal(1, 0, 1), tolerance = 1e-14)   # escala
})

test_that("cobertura y CRPS sobre casos armados a mano; sin densidad quedan NA", {
  cal <- calibracion_densidad(c(0, 1.5, -2, 3), rep(1, 4))
  expect_identical(unname(cal[c("cobertura_80", "cobertura_95")]), c(0.25, 0.5))
  expect_equal(unname(cal["crps"]), mean(crps_normal(c(0, 1.5, -2, 3), 0, 1)))
  expect_true(all(is.na(calibracion_densidad(c(0, 1), c(1, NA)))))
  expect_true(all(is.na(calibracion_densidad(c(0, 1), NULL))))
  expect_error(calibracion_densidad(c(0, 1), c(1, 0)), "inválida")
})

test_that("validar_densidad rechaza densidades mal formadas", {
  s <- c(1, 2, 3); S <- diag(3)
  expect_silent(validar_densidad(list(media = s, cov = S), s))
  expect_error(validar_densidad(list(media = s), s), "list\\(media, cov\\)")
  expect_error(validar_densidad(list(media = s[1:2], cov = S), s), "`media` debe tener 3")
  expect_error(validar_densidad(list(media = s + 1e-3, cov = S), s), "no coincide con el sendero")
  expect_error(validar_densidad(list(media = s, cov = diag(2)), s), "matriz 3x3")
  A <- S; A[1, 2] <- 0.5
  expect_error(validar_densidad(list(media = s, cov = A), s), "no es simétrica")
  expect_error(validar_densidad(list(media = s, cov = diag(c(1, 0, 1))), s), "no positivas")
  B <- matrix(c(1, 2, 0, 2, 1, 0, 0, 0, 1), 3)
  expect_error(validar_densidad(list(media = s, cov = B), s), "semidefinida")
  mala <- list(modelo_id = "PRUEBA.DENSIDAD_MALA", requiere = "objetivo",
               ajustar = function(datos, spec) list(y_o = utils::tail(datos$objetivo$y, 1)),
               predecir = function(aj, h) rep(aj$y_o, h),
               predecir_densidad = function(aj, h) list(media = rep(aj$y_o, h), cov = -diag(h)))
  obj <- .obj_lineal()
  expect_error(correr_backtest(list(objetivo = obj), list(mala), q_a_ind("2013-Q1"), densidad = TRUE),
               "densidad mal formada: modelo PRUEBA.DENSIDAD_MALA en 2013-Q1")
  expect_silent(correr_backtest(list(objetivo = obj), list(mala), q_a_ind("2013-Q1")))   # sin densidad no se evalúa
})

test_that("covarianzas del sendero: paseo, AR(1) y ETS contra fórmulas y contra fable", {
  S <- cov_desde_pesos(pesos_ar_dy(numeric(0), 8L), 2)
  expect_equal(S, 2 * outer(1:8, 1:8, pmin))
  sd_u <- sd_unidades_densidad(S)
  expect_equal(sd_u[, "sd_yoy_pp"], 100 * sqrt(2 * c(1:4, 4, 4, 4, 4)))
  expect_equal(sd_u[, "sd_qoq_pp"], rep(100 * sqrt(2), 8))
  # AR(1) en Δy: var(y_{o+2}) = σ² (1 + (1 + φ)²)
  expect_equal(cov_desde_pesos(pesos_ar_dy(0.5, 2L), 1)[2, 2], 1 + 1.5^2)
  # ETS(A,A,N): la diagonal es la varianza marginal que publica fable.
  set.seed(7); y <- cumsum(c(4.6, 0.005 + rnorm(99, 0, 0.01)))
  d <- list(objetivo = data.frame(periodo = ind_a_q(q_a_ind("2000-Q1") + 0:99), y = y))
  m <- modelo_ets(); aj <- m$ajustar(d, NULL); de <- m$predecir_densidad(aj, 8L)
  expect_equal(diag(de$cov), distributional::variance(fabletools::forecast(aj, h = 8)$y), tolerance = 1e-10)
  expect_equal(de$media, m$predecir(aj, 8L))
})

test_that("correr_backtest: sin densidad la salida no cambia; con densidad agrega sd_* y NA donde no hay", {
  obj <- .obj_lineal(); obj$y <- obj$y + 0.01 * sin(seq_along(obj$y))
  ors <- origenes_diseno("2013-Q1", "2014-Q4")
  mods <- modelos_referencia()
  p0 <- correr_backtest(list(objetivo = obj), mods, ors)
  p1 <- correr_backtest(list(objetivo = obj), mods, ors, densidad = TRUE)
  expect_identical(names(p0), c("modelo_id", "origen", "h", "log_nivel_pronosticado"))
  expect_identical(p1[, names(p0)], p0)
  expect_identical(names(p1), c(names(p0), COLUMNAS_SD_DENSIDAD))
  sin_dens <- p1$modelo_id == "BENCH.MEDIA_CRECIMIENTO"
  expect_true(all(is.na(p1$sd_yoy_pp[sin_dens])) && all(p1[!sin_dens, COLUMNAS_SD_DENSIDAD] > 0))
  e1 <- calcular_errores(p1, obj); e0 <- calcular_errores(p0, obj)
  expect_identical(e1[, names(e0)], e0)
  m <- metricas_por_horizonte(e1)
  expect_true(all(is.na(m$crps[m$modelo_id == "BENCH.MEDIA_CRECIMIENTO"])))
  expect_true(all(m$crps[m$modelo_id != "BENCH.MEDIA_CRECIMIENTO"] > 0))
  expect_identical(names(metricas_por_horizonte(e0)), c("modelo_id", "h", "unidad", "n_pares", "rmse", "mae", "sesgo", "sesgo_ee_nw"))
})

# --- 12. rezagos de publicación de las predictoras (F4-34; remediación, E3) ---------------------

test_that("rezagos por familia: los de la tabla del protocolo §2.3, desde la evidencia de insumos", {
  r <- rezagos_predictoras(c("BCR.IPP.IDX.NSA.M", "BCR.REMESAS.NOM.NSA.M", "BCR.REMESAS.REAL.NSA.M",
                             "BCR.EXPORT_FOB.NOM.NSA.M", "BCR.ITCER.IDX.NSA.M", "BCR.IVAE.VOL.SA.M", "BCR.IPM.IDX.NSA.M"))
  expect_identical(unlist(r, use.names = FALSE), c(10L, 24L, 24L, 24L, 30L, 61L, 61L))
  # los agregados trimestrales heredan el rezago de su fuente mensual
  expect_identical(rezagos_predictoras("BCR.IVAE.VOL.SA.Q")[[1]], 61L)
  # la constante del PIB coincide con la misma fuente
  ev <- utils::read.csv(do.call(here::here, as.list(RUTA_EVIDENCIA_INSUMOS)), stringsAsFactors = FALSE)
  expect_identical(as.integer(ev$valor[ev$bloque == "rezago_publicacion" & ev$item == "PIB_SA_PROPIO_Q" &
                                       ev$metrica == "rezago_dias_mediano"]), REZAGO_PIB_DIAS)
})

test_that("rezagos: falla si un modelo requiere una predictora sin rezago declarado", {
  expect_error(rezagos_predictoras("BCR.NO_EXISTE.M"), "no tiene rezago de publicación declarado")
  m <- list(modelo_id = "PRUEBA.PUENTE", requiere = c("objetivo", "BCR.IVAE.VOL.SA.M", "BCR.SIN_CALENDARIO.M"))
  expect_error(rezagos_modelo(m), "BCR.SIN_CALENDARIO.M no tiene rezago")
  expect_identical(rezagos_modelo(list(requiere = "objetivo")), list())
  expect_identical(rezagos_modelo(list(requiere = c("objetivo", "BCR.ITCER.IDX.NSA.M"))), list(BCR.ITCER.IDX.NSA.M = 30L))
})

# --- 13. UT solo con años cerrados (F4-34, opción C; remediación, E4) ----------------------------

.ut_mensual <- function(desde = "2016-M01", hasta = "2020-M12") {
  i <- m_a_ind(desde):m_a_ind(hasta)
  data.frame(periodo = sprintf("%d-M%02d", i %/% 12L, i %% 12L + 1L), valor = seq_along(i), stringsAsFactors = FALSE)
}

test_that("UT: el año a entra desde el origen (a+1)-Q1; caso borde 2019-Q3 con la fecha sintética de v2019-12", {
  expect_identical(anio_max_cerrado(q_a_ind(c("2019-Q3", "2019-Q4", "2020-Q1"))), c(2018L, 2018L, 2019L))
  # El corte del origen 2019-Q3 coincide con la fecha de publicación (sintética) del vintage de 2019.
  vg <- utils::read.csv(here::here("catalogos", "08_vintages.csv"), stringsAsFactors = FALSE)
  f19 <- vg$fecha_publicacion[vg$vintage_id == "UT.DEMANDA_TOTAL_MENSUAL.v2019-12"]
  expect_identical(format(fecha_corte_origen(q_a_ind("2019-Q3"))), f19)
  d <- .ut_mensual()
  for (caso in list(c("2019-Q3", "2018-M12"), c("2019-Q4", "2018-M12"), c("2020-Q1", "2019-M12"))) {
    r <- recortar_a_origen(d, q_a_ind(caso[1]), REZAGO_ANUAL_CERRADO)
    expect_identical(utils::tail(r$periodo, 1), caso[2], info = caso[1])
    expect_silent(guarda_recorte(r, q_a_ind(caso[1]), REZAGO_ANUAL_CERRADO))
  }
  q <- data.frame(periodo = ind_a_q(q_a_ind("2017-Q1") + 0:15), valor = 1:16, stringsAsFactors = FALSE)
  expect_identical(utils::tail(recortar_a_origen(q, q_a_ind("2019-Q3"), REZAGO_ANUAL_CERRADO)$periodo, 1), "2018-Q4")
})

test_that("UT: la guarda G-1 rechaza meses de un año no cerrado y rezagos_predictoras marca UT como anual", {
  d <- .ut_mensual(hasta = "2019-M01")
  expect_error(guarda_recorte(d, q_a_ind("2019-Q3"), REZAGO_ANUAL_CERRADO, nombre = "ut"),
               "^G-1 filtración anual: ut trae 1 período\\(s\\) de años no cerrados en el origen 2019-Q3")
  expect_identical(rezagos_predictoras("UT.DEMANDA_ELEC.GWH.NSA.M")[[1]], REZAGO_ANUAL_CERRADO)
  expect_identical(rezagos_predictoras("UT.DEMANDA_ELEC.GWH.NSA.Q")[[1]], REZAGO_ANUAL_CERRADO)
  expect_error(anio_de_periodo("2019/03"), "mal formado")
})

test_that("UT en el motor: un modelo que pide UT nunca ve el año del origen", {
  vistos <- new.env()
  espia <- list(modelo_id = "PRUEBA.ESPIA_UT", requiere = c("objetivo", "UT.DEMANDA_ELEC.GWH.NSA.M"),
                ajustar = function(datos, spec) {
                  o <- max(q_a_ind(datos$objetivo$periodo))
                  assign(ind_a_q(o), max(anio_de_periodo(datos$UT.DEMANDA_ELEC.GWH.NSA.M$periodo)), envir = vistos)
                  list(y_o = utils::tail(datos$objetivo$y, 1))
                },
                predecir = function(aj, h) rep(aj$y_o, h))
  obj <- .obj_lineal()
  ors <- q_a_ind(c("2019-Q3", "2019-Q4", "2020-Q1"))
  correr_backtest(list(objetivo = obj, UT.DEMANDA_ELEC.GWH.NSA.M = .ut_mensual(hasta = "2025-M12")), list(espia), ors,
                  rezagos = rezagos_modelo(espia))
  expect_identical(unlist(mget(c("2019-Q3", "2019-Q4", "2020-Q1"), envir = vistos), use.names = FALSE), c(2018L, 2018L, 2019L))
})
