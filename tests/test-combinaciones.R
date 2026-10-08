# tests/test-combinaciones.R
#
# Combinaciones de Fase 5, bloque B5 (F5-13, F5-14e, F5-12 y B5-1 a B5-4 de doc/metodologia/decisiones_fase5.md), con datos
# SINTÉTICOS: no se lee data/. Comprueba los cuatro esquemas contra cálculos independientes, que los pesos inversos al ECM
# usan solo errores de pares con o' + h <= o contra el objetivo visto en o (B5-1), los pesos iguales hasta 8 errores, las
# guardas y, de punta a punta en correr_experimento(), las combinaciones de la principal, la variante R7 (B5-4) y el recorte
# de las predictoras en R1 (B5-3).

library(testthat)
source(here::here("src", "evaluacion", "motor_backtesting.R"))

.pron_sint <- function(semilla, ids = paste0("M", 1:11), origenes = q_a_ind("2013-Q1") + 0:19, H = 8L) {
  set.seed(semilla)
  do.call(rbind, lapply(ids, function(id) do.call(rbind, lapply(origenes, function(o) {
    data.frame(modelo_id = id, origen = o, h = seq_len(H), log_nivel_pronosticado = 4 + 0.005 * seq_len(H) + stats::rnorm(H, 0, 0.01),
               sd_log_nivel = 0.01, sd_yoy_pp = 1, sd_qoq_pp = 1, stringsAsFactors = FALSE)
  }))))
}
.y_sint <- function(semilla, hasta = q_a_ind("2026-Q1")) {
  set.seed(semilla); i <- q_a_ind("1990-Q1"):hasta
  stats::setNames(3.9 + cumsum(0.005 + stats::rnorm(length(i), 0, 0.01)), i)
}

test_that("F5-13: media, mediana, recortada al 10 % y pesos iguales antes de 8 errores", {
  pron <- .pron_sint(1); y <- .y_sint(2); org <- sort(unique(pron$origen))
  yo <- stats::setNames(lapply(org, function(o) y[as.integer(names(y)) <= o]), org)
  cmb <- combinar_pronosticos(pron, paste0("M", 1:11), "G1", yo)
  expect_identical(unique(cmb$modelo_id), ids_combinaciones("G1"))
  expect_true(all(is.na(cmb$sd_log_nivel)))                                          # F5-12: sin densidad
  o <- org[5]; h <- 3L
  x <- pron$log_nivel_pronosticado[pron$origen == o & pron$h == h]
  v <- function(id) cmb$log_nivel_pronosticado[cmb$modelo_id == id & cmb$origen == o & cmb$h == h]
  expect_equal(v("COMB.MEDIA.G1"), mean(x), tolerance = 1e-14)
  expect_equal(v("COMB.MEDIANA.G1"), stats::median(x), tolerance = 1e-14)
  expect_equal(v("COMB.RECORTADA.G1"), mean(sort(x)[2:10]), tolerance = 1e-14)        # 11 miembros: uno de cada lado
  expect_equal(v("COMB.ECM_INV.G1"), mean(x), tolerance = 1e-14)                     # o − h − 2013-Q1 + 1 = 2 errores < 8
  d <- attr(cmb, "diagnosticos")
  expect_identical(d$valor[d$origen == o & d$clave == "h3.n_errores"], 2)
})

test_that("F5-13, B5-1: pesos inversos al ECM descontado con δ = 0,9 y solo errores de pares con o' + h <= o", {
  pron <- .pron_sint(3); y <- .y_sint(4); org <- sort(unique(pron$origen)); m <- paste0("M", 1:11)
  yo <- stats::setNames(lapply(org, function(o) y[as.integer(names(y)) <= o]), org)
  cmb <- combinar_pronosticos(pron, m, "G2", yo)
  for (h in c(1L, 6L)) {
    o <- org[length(org)]
    prev <- org[org + h <= o]
    expect_gte(length(prev), 8L)
    E <- sapply(m, function(id) sapply(prev, function(op) {
      s <- pron$log_nivel_pronosticado[pron$modelo_id == id & pron$origen == op][order(pron$h[pron$modelo_id == id & pron$origen == op])]
      e <- function(j) y[as.character(op + j)] - s[j]
      unname(if (h <= 4L) 100 * e(h) else 100 * (e(h) - e(h - 4L)))
    }))
    w <- 1 / colSums(0.9^((o - h) - prev) * E^2); w <- w / sum(w)
    x <- pron$log_nivel_pronosticado[pron$origen == o & pron$h == h][match(m, pron$modelo_id[pron$origen == o & pron$h == h])]
    expect_equal(cmb$log_nivel_pronosticado[cmb$modelo_id == "COMB.ECM_INV.G2" & cmb$origen == o & cmb$h == h], sum(w * x), tolerance = 1e-12, info = h)
    d <- attr(cmb, "diagnosticos")
    expect_equal(d$valor[d$origen == o & d$clave %in% paste0("h", h, ".peso.", m)], unname(w), tolerance = 1e-12)
  }
  # B5-1: el objetivo posterior a o no entra; alterar lo que solo se ve después de o no cambia la combinación de o
  o <- org[12]
  yo2 <- yo; yo2[[as.character(o)]] <- yo[[as.character(o)]]                          # la vista de o queda igual
  for (k in which(org > o)) yo2[[k]] <- yo[[k]] + 0.5
  c2 <- combinar_pronosticos(pron, m, "G2", yo2)
  sin_attr <- function(x) { attr(x, "diagnosticos") <- NULL; x }
  expect_identical(sin_attr(cmb)[cmb$origen <= o, ], sin_attr(c2)[c2$origen <= o, ])
  d1 <- attr(cmb, "diagnosticos"); d2 <- attr(c2, "diagnosticos")
  expect_identical(d1[d1$origen <= o, ], d2[d2$origen <= o, ])
  # guardas
  expect_error(combinar_pronosticos(pron, c(m, "M99"), "G2", yo), "miembros sin pronósticos: M99")
  expect_error(combinar_pronosticos(pron[-1, ], m, "G2", yo), "senderos completos")
  expect_error(combinar_pronosticos(pron, "M1", "G2", yo), "al menos dos miembros")
})

test_that("B5-2 a B5-4: variantes declaradas, R7 con los modelos con UT y sin combinaciones, y el candado F5-02", {
  v <- EXPERIMENTOS_VARIANTES_FASE5
  expect_identical(v$exp_id, c("F5_G1_R1", "F5_G2_R1", "F5_G3_R1", "F5_G2_R2", "F5_G3_R2", "F5_G2_R5", "F5_G3_R5",
                               "F5_G1_R6", "F5_G2_R6", "F5_G3_R6", "F5_G2_R7", "F5_G3_R7"))
  expect_true(all(grepl(PATRON_EXP_PREREGISTRO, v$exp_id)))                           # F5-02: bloqueadas hasta E1
  for (k in seq_len(nrow(v))) expect_error(seleccionar_experimentos(v$exp_id[k]), "^F5-02", info = v$exp_id[k])
  r7 <- v[v$exp_id == "F5_G2_R7", ]
  ids <- vapply(modelos_experimento(r7), `[[`, character(1), "modelo_id")
  f5 <- setdiff(ids, vapply(modelos_referencia(), `[[`, character(1), "modelo_id"))
  expect_true(all(vapply(modelos_fase5("G2")[match(f5, vapply(modelos_fase5("G2"), `[[`, character(1), "modelo_id"))],
                         function(m) any(m$requiere %in% PREDICTORAS_UT), logical(1))))
  expect_false("UNI.ARIMA" %in% ids); expect_true("UNI.ARIMAX.G2" %in% ids)
  expect_identical(combinaciones_experimento(r7), character(0))
  expect_identical(combinaciones_experimento(EXPERIMENTOS_PRINCIPALES_FASE5[1, ]), ids_combinaciones("G1"))
  expect_identical(combinaciones_experimento(v[v$exp_id == "F5_G3_R6", ]), ids_combinaciones("G3"))
  expect_identical(combinaciones_experimento(EXPERIMENTOS_REPRO[1, ]), character(0))
  d <- data.frame(periodo = ind_a_q(q_a_ind("2000-Q1") + 0:20), valor = 1)
  expect_identical(recortar_inicio_predictora(d, "2003-Q2")$periodo[1], "2003-Q2")
  dm <- data.frame(periodo = sprintf("2003-M%02d", 1:12), valor = 1)
  expect_identical(recortar_inicio_predictora(dm, "2003-Q2")$periodo[1], "2003-M04")
})

test_that("B5, F5-13: de punta a punta, la principal escribe las combinaciones; R7 cambia el rezago de UT; R1 recorta", {
  set.seed(20260924L + 12L)
  per <- ind_a_q(q_a_ind("1990-Q1") + 0:144)
  dy <- numeric(length(per)); e <- stats::rnorm(length(per), 0, 0.008)
  for (t in 2:length(per)) dy[t] <- 0.003 + 0.5 * dy[t - 1] + e[t]
  obj <- data.frame(periodo = per, y = 4.6 + cumsum(dy), vintage_id = "SINT.v1", stringsAsFactors = FALSE)
  ids_q <- predictoras_grupo("G2", "Q")
  pred <- stats::setNames(lapply(ids_q, function(id) data.frame(periodo = ind_a_q(q_a_ind("1995-Q1"):q_a_ind("2026-Q2")), valor = 100,
                                                                    stringsAsFactors = FALSE)), ids_q)
  pred$UT.DEMANDA_ELEC.GWH.NSA.M <- data.frame(periodo = sprintf("%d-M%02d", rep(1995:2026, each = 12), rep(1:12, 32)), valor = 100)
  vistos <- new.env()
  espia <- function(id, req, d) list(modelo_id = id, requiere = c("objetivo", req), piso_gl = FALSE,
    ajustar = function(datos, spec) {
      o <- max(q_a_ind(datos$objetivo$periodo))
      assign(paste(id, ind_a_q(o)), c(inicio_obj = datos$objetivo$periodo[1], vapply(req, function(r) paste(datos[[r]]$periodo[1], utils::tail(datos[[r]]$periodo, 1)), character(1))), envir = vistos)
      list(y_o = utils::tail(datos$objetivo$y, 1))
    },
    predecir = function(aj, h) aj$y_o + d * seq_len(h))
  ms <- list(espia("PRUEBA.A", ids_q[1], 0.002), espia("PRUEBA.UT", "UT.DEMANDA_ELEC.GWH.NSA.M", 0.004), espia("PRUEBA.B", ids_q[2], 0.006))
  orig <- modelos_fase5
  assign("modelos_fase5", function(grupo) ms, envir = globalenv())
  on.exit(assign("modelos_fase5", orig, envir = globalenv()), add = TRUE)
  insumos <- list(objetivos = list(PIB_SA_PROPIO_Q = obj), predictoras = pred, conjunto = list(etiqueta = "corte_sint@0123abcd"))
  ex <- EXPERIMENTOS_PRINCIPALES_FASE5[EXPERIMENTOS_PRINCIPALES_FASE5$exp_id == "F5_G2", ]; ex$sa <- "l3_unico"; ex$r3 <- FALSE; ex$r4 <- FALSE
  r <- correr_experimento(ex, insumos, new.env())
  expect_true(all(ids_combinaciones("G2") %in% r$ids))
  expect_identical(r$combinaciones, ids_combinaciones("G2"))
  pc <- r$pronosticos[r$pronosticos$modelo_id == "COMB.MEDIA.G2" & r$pronosticos$h == 2, ]
  pa <- r$pronosticos[r$pronosticos$modelo_id %in% c("PRUEBA.A", "PRUEBA.UT", "PRUEBA.B") & r$pronosticos$h == 2, ]
  expect_equal(pc$log_nivel_pronosticado, as.numeric(tapply(pa$log_nivel_pronosticado, pa$origen, mean)), tolerance = 1e-12)
  expect_true(any(grepl("^h1\\.peso\\.", r$diagnosticos$clave[r$diagnosticos$modelo_id == "COMB.ECM_INV.G2"])))
  expect_true(all(is.na(r$metricas$cobertura_80[startsWith(r$metricas$modelo_id, "COMB.")])))
  ut_ppal <- vistos[["PRUEBA.UT 2016-Q1"]][["UT.DEMANDA_ELEC.GWH.NSA.M"]]
  # R7: solo el modelo con UT, UT a 61 días (1 mes de o+1 en lugar de 2) y sin combinaciones
  r7 <- EXPERIMENTOS_VARIANTES_FASE5[EXPERIMENTOS_VARIANTES_FASE5$exp_id == "F5_G2_R7", ]; r7$sa <- "l3_unico"
  rr7 <- correr_experimento(r7, insumos, new.env())
  expect_false(any(c("PRUEBA.A", "PRUEBA.B") %in% rr7$ids)); expect_true("PRUEBA.UT" %in% rr7$ids)
  expect_false(any(startsWith(rr7$ids, "COMB.")))
  ut_r7 <- vistos[["PRUEBA.UT 2016-Q1"]][["UT.DEMANDA_ELEC.GWH.NSA.M"]]
  expect_identical(c(ut_ppal, ut_r7), c("1995-M01 2016-M05", "1995-M01 2016-M04"))
  # R1 con predictoras: la ventana del objetivo recorta también las predictoras (B5-3)
  r1 <- EXPERIMENTOS_VARIANTES_FASE5[EXPERIMENTOS_VARIANTES_FASE5$exp_id == "F5_G2_R1", ]; r1$sa <- "l3_unico"
  rr1 <- correr_experimento(r1, insumos, new.env())
  v <- vistos[["PRUEBA.A 2025-Q4"]]
  expect_identical(unname(v[["inicio_obj"]]), ind_a_q(q_a_ind("2025-Q4") - 91L))
  expect_identical(strsplit(v[[ids_q[1]]], " ")[[1]][1], ind_a_q(q_a_ind("2025-Q4") - 91L))
})
