# tests/test-predictoras-fase5.R
#
# Infraestructura de Fase 5 (bloque B1a; decisiones F5-03, F5-04, B1-3 y B1-4 de
# doc/metodologia/decisiones_fase5.md): composición de predictoras por grupo (F4-05), alineación con el
# origen, guardas G-7 (borde) y G-8 (grados de libertad), lectura de predictoras del corte con G-6,
# experimentos F5_G* y candado del preregistro (F5-02). Todo con datos SINTÉTICOS: no se lee data/.

library(testthat)
source(here::here("src", "evaluacion", "motor_backtesting.R"))   # main() no corre al hacer source

.mensual <- function(desde, hasta, f = function(i) 100 + i) {
  i <- m_a_ind(desde):m_a_ind(hasta)
  data.frame(periodo = sprintf("%d-M%02d", i %/% 12L, i %% 12L + 1L), valor = f(seq_along(i)), stringsAsFactors = FALSE)
}
.trimestral <- function(desde, hasta, f = function(i) 100 + i) {
  i <- q_a_ind(desde):q_a_ind(hasta)
  data.frame(periodo = ind_a_q(i), valor = f(seq_along(i)), stringsAsFactors = FALSE)
}

test_that("F4-05: la composición por grupo coincide con la del script de evidencia de insumos", {
  s <- readLines(here::here("scripts", "evidencia_insumos_fase4.R"), encoding = "UTF-8")
  a <- grep("^grupos <- list\\(", s); b <- a + which(grepl("^\\)", s[(a + 1):length(s)]))[1]
  bloque <- paste(s[a:b], collapse = "\n")
  for (g in c("G1", "G2", "G3")) {
    m <- regmatches(bloque, regexpr(paste0(g, "_[a-z]+ = c\\([^)]*\\)"), bloque))
    archivos <- regmatches(m, gregexpr("[A-Z0-9_]+\\.csv", m))[[1]]
    esperado <- setdiff(sub("\\.csv$", "", archivos), "PIB_SA_PROPIO_Q")
    expect_setequal(gsub(".", "_", predictoras_grupo(g), fixed = TRUE), esperado)
  }
  expect_identical(predictoras_grupo("G1", "M"), c("BCR.REMESAS.NOM.NSA.M", "BCR.EXPORT_FOB.NOM.NSA.M"))
  expect_length(predictoras_grupo("G2"), 6L); expect_length(predictoras_grupo("G3"), 8L)
  expect_true(all(predictoras_grupo("G1") %in% predictoras_grupo("G2")) && all(predictoras_grupo("G2") %in% predictoras_grupo("G3")))
  sm <- utils::read.csv(here::here("catalogos", "05_series_master.csv"), stringsAsFactors = FALSE)
  for (g in names(GRUPOS_PREDICTORAS)) for (f in c("Q", "M")) expect_true(all(predictoras_grupo(g, f) %in% sm$series_master_id), info = paste(g, f))
  expect_error(predictoras_grupo("G4"), "grupo no declarado")
})

test_that("F5-04: rezago_alineacion da desfase 0 en las .Q y el borde irregular en las .M, uniforme en el grupo", {
  for (g in c("G1", "G2", "G3")) for (id in predictoras_grupo(g, "Q")) {
    a <- rezago_alineacion(id, g)
    expect_identical(a$desfase, 0L, info = paste(g, id))       # los trimestrales entran hasta o
  }
  esperado_m <- c("BCR.REMESAS.NOM.NSA.M" = 2L, "BCR.EXPORT_FOB.NOM.NSA.M" = 2L, "BCR.ITCER.IDX.NSA.M" = 2L,
                  "UT.DEMANDA_ELEC.GWH.NSA.M" = 2L, "BCR.IVAE.VOL.SA.M" = 1L, "BCR.IPM.IDX.NSA.M" = 1L,
                  "BCR.IPP.IDX.NSA.M" = 2L, "BCR.REMESAS.REAL.NSA.M" = 2L)
  for (id in predictoras_grupo("G3", "M")) expect_identical(rezago_alineacion(id, "G3")$desfase, esperado_m[[id]], info = id)
  # coincide con los meses de o+1 que publica la evidencia de insumos
  ev <- utils::read.csv(do.call(here::here, as.list(RUTA_EVIDENCIA_INSUMOS)), stringsAsFactors = FALSE)
  for (id in names(esperado_m)) {
    k <- ev$bloque == "rezago_publicacion" & ev$item == id & ev$metrica == "meses_trimestre_siguiente_conocidos_min"
    if (any(k)) expect_identical(as.integer(ev$valor[k]), esperado_m[[id]], info = id)
  }
  ev2 <- ev; ev2 <- rbind(ev2, data.frame(bloque = "rezago_publicacion", item = "X.LENTA.M", metrica = "rezago_dias_supuesto",
                                          valor = "200", nota = "", fecha_generacion = "", stringsAsFactors = FALSE))
  expect_identical(rezago_alineacion("X.LENTA.Q", "G1", evidencia = ev2)$desfase, 2L)    # una serie lenta va hacia atrás
  expect_error(rezago_alineacion("X.SIN_FREQ", "G1", evidencia = ev2), "no tiene rezago|no termina")
})

test_that("ultimo_admitido sigue la regla de calendario de §2.3", {
  o <- q_a_ind("2019-Q4")                       # corte = 2019-12-31 + 92 = 2020-04-01
  expect_identical(ultimo_admitido(o, 30L, TRUE), m_a_ind("2020-M02"))
  expect_identical(ultimo_admitido(o, 61L, TRUE), m_a_ind("2020-M01"))
  expect_identical(ultimo_admitido(o, 92L, TRUE), m_a_ind("2019-M12"))
  expect_identical(ultimo_admitido(o, 30L, FALSE), o)
  expect_identical(ultimo_admitido(o, 200L, FALSE), o - 2L)
  expect_error(ultimo_admitido(o, "anual_cerrado", TRUE), "número de días")
})

test_that("G-7: una predictora que no llega al borde que admite el calendario detiene el motor", {
  o <- q_a_ind("2019-Q4")
  completa <- .mensual("2010-M01", "2025-M12")
  r <- recortar_a_origen(completa, o, 30L)
  expect_silent(guarda_borde(r, o, 30L, nombre = "x"))
  corta <- recortar_a_origen(.mensual("2010-M01", "2020-M01"), o, 30L)       # falta 2020-M02
  expect_error(guarda_borde(corta, o, 30L, nombre = "x"), "^G-7 borde incompleto: x llega hasta 2020-M01 en el origen 2019-Q4 y el calendario admite hasta 2020-M02")
  q <- recortar_a_origen(.trimestral("2010-Q1", "2019-Q3"), o, 30L)
  expect_error(guarda_borde(q, o, 30L, nombre = "xq"), "llega hasta 2019-Q3 .* admite hasta 2019-Q4")
  expect_error(guarda_borde(completa[0, ], o, 30L, nombre = "x"), "no trae ningún período")
  expect_silent(guarda_borde(corta, o, REZAGO_ANUAL_CERRADO, nombre = "x"))   # la rama anual tiene su guarda
  expect_silent(guarda_borde(corta, o, NULL, nombre = "x"))
  # en el bucle: un modelo que pide una predictora corta no llega a ajustarse
  obj <- data.frame(periodo = ind_a_q(q_a_ind("2005-Q1") + 0:63), y = 4.6 + 0.01 * (0:63), stringsAsFactors = FALSE)
  espia <- list(modelo_id = "PRUEBA.ESPIA", requiere = c("objetivo", "x"),
                ajustar = function(datos, spec) list(y_o = utils::tail(datos$objetivo$y, 1)), predecir = function(aj, h) rep(aj$y_o, h))
  expect_error(correr_backtest(list(objetivo = obj, x = .mensual("2004-M01", "2020-M01")), list(espia), o, rezagos = list(x = 30L)),
               "^G-7 borde incompleto")
  expect_silent(correr_backtest(list(objetivo = obj, x = .mensual("2004-M01", "2021-M12")), list(espia), o, rezagos = list(x = 30L)))
})

test_that("G-8: un modelo con piso_gl debe declarar gl y dejar al menos 20 grados de libertad", {
  obj <- data.frame(periodo = ind_a_q(q_a_ind("2005-Q1") + 0:63), y = 4.6 + 0.01 * (0:63), stringsAsFactors = FALSE)
  o <- q_a_ind("2019-Q4")
  con_gl <- function(n_par, declara = TRUE) list(
    modelo_id = "PRUEBA.GL", requiere = "objetivo", piso_gl = TRUE,
    ajustar = function(datos, spec) { n <- nrow(datos$objetivo) - 1L; c(list(y_o = utils::tail(datos$objetivo$y, 1)), if (declara) list(gl = c(n_obs = n, n_par = n_par))) },
    predecir = function(aj, h) rep(aj$y_o, h))
  n <- sum(q_a_ind(obj$periodo) <= o) - 1L
  expect_silent(correr_backtest(list(objetivo = obj), list(con_gl(n - PISO_GL)), o))
  expect_error(correr_backtest(list(objetivo = obj), list(con_gl(n - PISO_GL + 1L)), o),
               sprintf("^G-8 modelo PRUEBA.GL en 2019-Q4: %d observaciones efectivas y %d parámetros dejan 19 grados de libertad; el piso es 20", n, n - 19L))
  expect_error(correr_backtest(list(objetivo = obj), list(con_gl(3L, declara = FALSE)), o), "no trae gl")
  sin_piso <- con_gl(n); sin_piso$piso_gl <- FALSE                       # penalizados y árboles: sin piso (F5-09)
  expect_silent(correr_backtest(list(objetivo = obj), list(sin_piso), o))
  malo <- con_gl(1L); malo$piso_gl <- "si"
  expect_error(correr_backtest(list(objetivo = obj), list(malo), o), "piso_gl debe ser TRUE o FALSE")
  expect_identical(PISO_GL, 20L)
})

test_that("G-6 sobre predictoras: cada fila con el vintage que declara el corte, también por año (UT)", {
  v <- data.frame(vintage_id = c("PUB.v1", "PUB.v2", "UT.DEMANDA_TOTAL_MENSUAL.v2019-12", "UT.DEMANDA_TOTAL_MENSUAL.v2020-12",
                                 "UT.DEMANDA_TOTAL_MENSUAL.v2020-12b"),
                  publicacion_id = c("PUB", "PUB", "UT.DEMANDA_TOTAL_MENSUAL", "UT.DEMANDA_TOTAL_MENSUAL", "UT.DEMANDA_TOTAL_MENSUAL"),
                  periodo_referencia_max = c("2020-M06", "2020-M07", "2019-M12", "2020-M12", "2020-M12"), stringsAsFactors = FALSE)
  cj <- data.frame(publicacion_id = c("PUB", "UT.DEMANDA_TOTAL_MENSUAL", "UT.DEMANDA_TOTAL_MENSUAL"),
                   vintage_id = c("PUB.v1", "UT.DEMANDA_TOTAL_MENSUAL.v2019-12", "UT.DEMANDA_TOTAL_MENSUAL.v2020-12"), stringsAsFactors = FALSE)
  x <- cbind(.trimestral("2019-Q1", "2020-Q2"), vintage_id = "PUB.v1")
  expect_silent(verificar_vintage_predictora(x, "PUB.X.Q", v, cj))
  expect_error(verificar_vintage_predictora(x, "PUB.X.Q", v), "vintage distinto")   # sin corte, el vigente es v2
  x2 <- x; x2$vintage_id[3] <- "PUB.v2"
  expect_error(verificar_vintage_predictora(x2, "PUB.X.Q", v, cj), "1 fila\\(s\\) de un vintage distinto .* 2019-Q3 con PUB.v2; se espera PUB.v1")
  ut <- .trimestral("2019-Q1", "2020-Q4"); ut$vintage_id <- ifelse(substr(ut$periodo, 1, 4) == "2019", "UT.DEMANDA_TOTAL_MENSUAL.v2019-12", "UT.DEMANDA_TOTAL_MENSUAL.v2020-12")
  expect_silent(verificar_vintage_predictora(ut, "UT.DEMANDA_ELEC.GWH.NSA.Q", v, cj))
  ut2 <- ut; ut2$vintage_id[8] <- "UT.DEMANDA_TOTAL_MENSUAL.v2020-12b"                 # recaptura fuera del corte
  expect_error(verificar_vintage_predictora(ut2, "UT.DEMANDA_ELEC.GWH.NSA.Q", v, cj), "vintage distinto")
  x3 <- x; x3$vintage_id[1] <- "OTRA.v9"
  expect_error(verificar_vintage_predictora(x3, "PUB.X.Q", v, cj), "no están en 08_vintages.csv")
  expect_error(verificar_vintage_predictora(rbind(x, x[1, ]), "PUB.X.Q", v, cj), "duplicados")
  expect_identical(archivo_l3("UT.DEMANDA_ELEC.GWH.NSA.Q"), "UT_DEMANDA_ELEC_GWH_NSA_Q.csv")
})

test_that("B1-3 y F5-02: experimentos F5_G*, sus modelos y el candado del preregistro", {
  expect_identical(EXPERIMENTOS_PRINCIPALES_FASE5$exp_id, c("F5_G1", "F5_G2", "F5_G3"))
  expect_identical(EXPERIMENTOS_PRINCIPALES_FASE5$grupo, c("G1", "G2", "G3"))
  expect_identical(EXPERIMENTOS_PRINCIPALES_FASE5$r3, c(TRUE, TRUE, FALSE))
  expect_true(all(EXPERIMENTOS_PRINCIPALES_FASE5$r4))
  expect_identical(EXPERIMENTOS_PRINCIPALES_FASE5$semilla_exp, EXPERIMENTOS_PRINCIPALES_FASE5$exp_id)
  expect_false(PREREGISTRO_FASE5_CERRADO)
  expect_identical(seleccionar_experimentos()$exp_id, EXPERIMENTOS_REPRO$exp_id)
  expect_error(seleccionar_experimentos("F5_G1"), "^F5-02: F5_G1 no corre sobre L3 hasta cerrar el preregistro")
  expect_identical(seleccionar_experimentos(preregistro_cerrado = TRUE)$exp_id, EXPERIMENTOS_FASE5$exp_id)
  expect_identical(seleccionar_experimentos("F5_G2", preregistro_cerrado = TRUE)$exp_id, "F5_G2")
  ids_bench <- vapply(modelos_referencia(), `[[`, character(1), "modelo_id")
  for (k in 1:3) {
    ex <- EXPERIMENTOS_PRINCIPALES_FASE5[k, ]
    ids <- vapply(modelos_experimento(ex), `[[`, character(1), "modelo_id")
    expect_identical(ids[seq_along(ids_bench)], ids_bench)
    expect_identical(ids[-seq_along(ids_bench)], vapply(modelos_fase5(ex$grupo), `[[`, character(1), "modelo_id"))
  }
  expect_identical(vapply(modelos_experimento(EXPERIMENTOS_REPRO[1, ]), `[[`, character(1), "modelo_id"), ids_bench)
  expect_error(modelos_fase5("G9"), "grupo no declarado")
})

test_that("correr_experimento pasa las predictoras del grupo con sus rezagos y la alineación (sintético)", {
  # Un modelo de prueba con predictoras sustituye al registro: así se ejerce la vía completa sin L3.
  # El objetivo sintético de V12 (y de tests/test-corte-motor.R): con un paseo puro, AR(p)-BIC replica al
  # paseo con deriva y el MCS se detiene por varianza bootstrap nula.
  set.seed(20260924L + 12L)
  per <- ind_a_q(q_a_ind("1990-Q1") + 0:144)
  dy <- numeric(length(per)); e <- stats::rnorm(length(per), 0, 0.008)
  for (t in 2:length(per)) dy[t] <- 0.003 + 0.5 * dy[t - 1] + e[t]
  y <- 4.6 + cumsum(dy)
  i20 <- match(c("2020-Q2", "2020-Q3"), per); y[i20] <- y[i20] + c(-0.20, -0.08)
  obj <- data.frame(periodo = per, y = y, vintage_id = "SINT.v1", stringsAsFactors = FALSE)
  ids_q <- predictoras_grupo("G3", "Q")
  pred <- stats::setNames(lapply(ids_q, function(id) .trimestral("2002-Q1", "2026-Q2")), ids_q)
  vistos <- new.env()
  espia <- list(modelo_id = "PRUEBA.ESPIA_G3", requiere = c("objetivo", ids_q), piso_gl = TRUE,
                ajustar = function(datos, spec) {
                  o <- max(q_a_ind(datos$objetivo$periodo))
                  assign(ind_a_q(o), vapply(ids_q, function(id) utils::tail(datos[[id]]$periodo, 1), character(1)), envir = vistos)
                  list(y_o = utils::tail(datos$objetivo$y, 1), gl = c(n_obs = 40, n_par = 12))
                },
                # distinto del paseo sin deriva: con pérdidas idénticas el MCS se detiene, por diseño
                predecir = function(aj, h) aj$y_o + 0.002 * seq_len(h))
  ex <- EXPERIMENTOS_PRINCIPALES_FASE5[EXPERIMENTOS_PRINCIPALES_FASE5$exp_id == "F5_G3", ]
  ex$sa <- "l3_unico"                                                         # sin X-13 en esta prueba
  insumos <- list(objetivos = list(PIB_SA_PROPIO_Q = obj), predictoras = pred, conjunto = list(etiqueta = "corte_sint@0123abcd"))
  orig <- modelos_fase5
  assign("modelos_fase5", function(grupo) list(espia), envir = globalenv())
  on.exit(assign("modelos_fase5", orig, envir = globalenv()), add = TRUE)
  r <- correr_experimento(ex, insumos, new.env())
  expect_identical(r$predictoras, ids_q)
  expect_true("PRUEBA.ESPIA_G3" %in% r$ids)
  expect_match(r$token, "\\|conjunto=corte_sint@0123abcd$")
  for (o in c("2019-Q4", "2022-Q2", "2025-Q4")) expect_true(all(vistos[[o]] == o), info = o)   # .Q hasta o (F5-04)
  # una predictora requerida que no se leyó detiene el experimento
  insumos2 <- insumos; insumos2$predictoras <- insumos2$predictoras[-1]
  expect_error(correr_experimento(ex, insumos2, new.env()), "requiere predictoras que no se leyeron: BCR.REMESAS.NOM.NSA.Q")
  ex_r1 <- ex; ex_r1$ventana <- "rodante92"
  expect_error(correr_experimento(ex_r1, insumos, new.env()), "con predictoras no está implementada")
})
