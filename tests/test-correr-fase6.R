# tests/test-correr-fase6.R
#
# Orquestación de Fase 6 (checklist D7; F6-01 a F6-13 de doc/metodologia/decisiones_fase6.md), con datos SINTÉTICOS: no
# se lee data/. Corre el núcleo de `make fase6` (correr_fase6_nucleo()) de punta a punta sobre insumos sintéticos con
# los inicios de L3, con menos extracciones del BVAR para que sea rápido, y comprueba la forma de las salidas, que las
# corridas difieren por escenario, la sensibilidad, que reejecutar reproduce bit a bit (F5-15), el preregistro (F6-12)
# y la medición previa del BVAR (F6-13 d).

library(testthat)
source(here::here("src", "proyeccion", "correr_fase6.R"))

.O_C6 <- q_a_ind("2026-Q2")
.INICIOS_C6 <- c("BCR.REMESAS.NOM.NSA" = 1991L, "BCR.EXPORT_FOB.NOM.NSA" = 1994L, "BCR.ITCER.IDX.NSA" = 2000L,
                 "UT.DEMANDA_ELEC.GWH.NSA" = 2002L, "BCR.IVAE.VOL.SA" = 2005L, "BCR.IPM.IDX.NSA" = 2005L,
                 "BCR.IPP.IDX.NSA" = 2010L, "BCR.REMESAS.REAL.NSA" = 2010L)

#' Insumos sintéticos de la corrida: objetivo, predictoras .M (hasta 2026-M08) y sus .Q de trimestres completos,
#' historias de las variables de escenario (que mueven a las predictoras), series ESC.* armadas con T014 y la referencia.
.insumos_c6 <- function(semilla = 61) {
  set.seed(semilla)
  iq <- q_a_ind("1990-Q1"):.O_C6
  z <- list(FRED.PIB_EEUU.VOL.SA.Q = cumsum(0.006 + stats::rnorm(length(iq), 0, 0.006)),
            FRED.IPC_EEUU.IDX.SA.Q = cumsum(0.007 + stats::rnorm(length(iq), 0, 0.004)),
            FMI.PETROLEO_APSP.USD.NSA.Q = cumsum(0.004 + stats::rnorm(length(iq), 0, 0.08)))
  z_hist <- lapply(z, function(v) data.frame(periodo = ind_a_q(iq), valor = 100 * exp(v), stringsAsFactors = FALSE))
  dz <- lapply(z, function(v) c(0, diff(v)))
  obj <- data.frame(periodo = ind_a_q(iq), y = log(100) + cumsum(0.005 + 0.4 * dz$FRED.PIB_EEUU.VOL.SA.Q + stats::rnorm(length(iq), 0, 0.007)),
                    stringsAsFactors = FALSE)
  carga <- c(BCR.REMESAS.NOM.NSA = "FRED.PIB_EEUU.VOL.SA.Q", BCR.REMESAS.REAL.NSA = "FRED.PIB_EEUU.VOL.SA.Q",
             BCR.EXPORT_FOB.NOM.NSA = "FRED.PIB_EEUU.VOL.SA.Q", BCR.ITCER.IDX.NSA = "FRED.IPC_EEUU.IDX.SA.Q",
             BCR.IPM.IDX.NSA = "FMI.PETROLEO_APSP.USD.NSA.Q", BCR.IPP.IDX.NSA = "FMI.PETROLEO_APSP.USD.NSA.Q")
  series <- list()
  for (f in names(.INICIOS_C6)) {
    im <- m_a_ind(sprintf("%d-M01", .INICIOS_C6[[f]])):m_a_ind("2026-M08")
    zq <- if (f %in% names(carga)) rep(dz[[carga[[f]]]] / 3, each = 3)[match(im %/% 3L, rep(iq, each = 3))] else 0
    zq[is.na(zq)] <- 0
    est <- if (grepl(".NSA", f, fixed = TRUE)) 0.03 * sin(2 * pi * (im %% 12L) / 12) else 0
    x <- 100 * exp(cumsum(0.0015 + 0.8 * zq + stats::rnorm(length(im), 0, 0.008)) + est)
    series[[paste0(f, ".M")]] <- data.frame(periodo = sprintf("%d-M%02d", im %/% 12L, im %% 12L + 1L), valor = x, stringsAsFactors = FALSE)
    q <- im %/% 3L; qs <- as.integer(names(which(table(q) == 3L)))
    agr <- if (grepl("REMESAS|EXPORT_FOB|DEMANDA_ELEC", f)) sum else mean
    series[[paste0(f, ".Q")]] <- data.frame(periodo = ind_a_q(qs), valor = as.numeric(tapply(x, q, agr)[as.character(qs)]), stringsAsFactors = FALSE)
  }
  weo <- function(g) data.frame(periodo = as.character(1990:2031), valor = g, stringsAsFactors = FALSE)
  d_a <- data.frame(periodo = as.character(2026:2031), valor = c(0, 0.6, 0.8, 0.6, 0.3, 0.1), stringsAsFactors = FALSE)
  d_c <- data.frame(periodo = as.character(2026:2031), valor = c(0, -1.5, -1.8, -1.4, -0.8, -0.5), stringsAsFactors = FALSE)
  p <- z_hist$FRED.PIB_EEUU.VOL.SA.Q; ipc <- z_hist$FRED.IPC_EEUU.IDX.SA.Q
  esc <- list(
    ESC.PIB_EEUU.VOL.SA.Q.BASE = sendero_escenario_crecimiento(p, weo(2), "b"),
    ESC.PIB_EEUU.VOL.SA.Q.ADVERSO = sendero_escenario_desvio_nivel(p, weo(2), d_c, "c"),
    ESC.PIB_EEUU.VOL.SA.Q.FAVORABLE = sendero_escenario_desvio_nivel(p, weo(2), d_a, "a"),
    ESC.IPC_EEUU.IDX.SA.Q.BASE = sendero_escenario_crecimiento(ipc, weo(2.5), "b"),
    ESC.IPC_EEUU.IDX.SA.Q.ADVERSO = sendero_escenario_desvio_crecimiento(ipc, weo(2.5), transform(d_c, valor = valor / 5), "c"),
    ESC.IPC_EEUU.IDX.SA.Q.FAVORABLE = sendero_escenario_desvio_crecimiento(ipc, weo(2.5), transform(d_a, valor = valor / 5), "a"),
    ESC.PETROLEO_APSP.USD.NSA.Q.BASE = sendero_escenario_crecimiento(z_hist$FMI.PETROLEO_APSP.USD.NSA.Q, weo(-1), "b"))
  list(objetivo = obj, o = .O_C6, series = series, z_hist = z_hist, esc = esc,
       weo_slv = stats::setNames(c(3.9, 3.5, 3.2, 3, 3, 3), as.character(2025:2030)))
}

.ins_c6 <- .insumos_c6()
.rango_c6 <- rango_guarda(.ins_c6$objetivo)
.r_c6 <- correr_fase6_nucleo(.ins_c6, .rango_c6, grupos = c("G1", "G3"), n_draw = 400L, n_burn = 200L)

test_that("D7: el núcleo corre G1 y G3 de punta a punta y arma las tablas de F6-11", {
  expect_setequal(names(.r_c6$grupos), c("G1", "G3"))
  expect_setequal(.r_c6$satelites$predictora, names(SATELITES_FASE6))
  expect_equal(names(.r_c6$sd_sensibilidad), names(VARIABLES_SENSIBILIDAD))
  for (g in c("G1", "G3")) {
    r <- .r_c6$grupos[[g]]
    tq <- r$trimestral; ta <- r$anual
    expect_setequal(unique(tq$corrida), c(DISENO_FASE6$escenarios, "SIN_ESCENARIO"))
    cond <- vapply(modelos_fase6(g, 400L, 200L)$condicionables, `[[`, character(1), "modelo_id")
    for (cr in DISENO_FASE6$escenarios) {
      expect_setequal(unique(tq$modelo_id[tq$corrida == cr]), c(ID_COMBINACION, cond))
      expect_equal(sum(tq$corrida == cr & tq$modelo_id == ID_COMBINACION), DISENO_FASE6$h_max)
      expect_equal(ta$cifra[ta$corrida == cr & ta$modelo_id == ID_COMBINACION], c(as.character(2026:2030), "promedio"))
    }
    expect_true(all(tq$nota == NOTA_CONDICIONAL) && all(ta$nota == NOTA_CONDICIONAL))
    expect_equal(tq$sin_calibrar, tq$h > DISENO_FASE6$h_calibrado)
    expect_false(any(is.na(tq$yoy_pp_inf95[tq$corrida != "SIN_ESCENARIO"])))
    # La guarda corre en las 9 corridas, sobre todos los elegibles.
    expect_equal(nrow(r$guarda), 9L * length(cond))
    # Sensibilidad: 6 corridas x (combinación + elegibles).
    expect_equal(nrow(r$sensibilidad), 6L * (1L + length(cond)))
    expect_true(all(c("nivel_2030_pct", "crecimiento_promedio_pp") %in% names(r$sensibilidad)))
    expect_equal(r$coherencia_weo$anio, 2026:2030)
    expect_equal(nrow(r$coherencia_historica), 1L)
  }
})

test_that("D7: el escenario llega al PIB y la sensibilidad mueve el nivel de 2030", {
  tq <- .r_c6$grupos$G1$trimestral
  comb <- function(cr) tq$log_nivel[tq$corrida == cr & tq$modelo_id == ID_COMBINACION]
  expect_false(isTRUE(all.equal(comb("BASE"), comb("ADVERSO"))))
  expect_false(isTRUE(all.equal(comb("BASE"), comb("FAVORABLE"))))
  # El año del origen arranca igual: los desvíos de 2026 son cero y la historia es común.
  s <- .r_c6$grupos$G1$sensibilidad
  pib <- s[s$variable == "PIB_EEUU" & s$modelo_id == ID_COMBINACION, ]
  expect_true(all(pib$nivel_2030_pct != 0))
  expect_true(sign(pib$nivel_2030_pct[pib$signo == "MAS"]) != sign(pib$nivel_2030_pct[pib$signo == "MENOS"]))
})

test_that("D7: el deflactor implícito de las remesas sale solo del modelo que recibe las dos (MULT.BVAR.G3)", {
  expect_null(.r_c6$grupos$G1$coherencia_deflactor)
  d <- .r_c6$grupos$G3$coherencia_deflactor
  expect_equal(unique(d$modelo_id), "MULT.BVAR.G3")
  expect_equal(nrow(d), DISENO_FASE6$h_max)
})

test_that("D7: reejecutar el núcleo reproduce bit a bit (F5-15)", {
  set.seed(999)
  r2 <- correr_fase6_nucleo(.ins_c6, .rango_c6, grupos = "G1", n_draw = 400L, n_burn = 200L)
  expect_identical(r2$grupos$G1, .r_c6$grupos$G1)
  s1 <- .r_c6$satelites[.r_c6$satelites$predictora %in% r2$satelites$predictora, ]; rownames(s1) <- NULL
  expect_identical(r2$satelites, s1)
})

test_that("D7: el núcleo se detiene si la guarda deja menos de 3 miembros (F6-02)", {
  angosto <- list(inferior = .rango_c6$superior - 0.01, superior = .rango_c6$superior)
  expect_error(correr_fase6_nucleo(.ins_c6, angosto, grupos = "G3", n_draw = 400L, n_burn = 200L), "mínimo es 3")
})

test_that("D7 (F6-12): el preregistro se arma, se lee y detiene la corrida ante cualquier diferencia", {
  tmp <- tempfile(fileext = ".yaml")
  p <- armar_preregistro_fase6(.ins_c6$objetivo, .O_C6, "abc", fecha = "2026-10-30")
  escribir_preregistro_fase6(p, tmp)
  leido <- leer_preregistro_fase6(tmp)
  expect_equal(verificar_preregistro(leido, .ins_c6$objetivo, .O_C6, "abc"), .rango_c6[c("inferior", "superior")], tolerance = 1e-12)
  expect_error(verificar_preregistro(leido, .ins_c6$objetivo, .O_C6, "otro"), "corte")
  expect_error(verificar_preregistro(leido, .ins_c6$objetivo[-nrow(.ins_c6$objetivo), ], .O_C6 - 1L, "abc"), "origen")
  o2 <- .ins_c6$objetivo; o2$y[10] <- o2$y[10] + 0.5
  expect_error(verificar_preregistro(leido, o2, .O_C6, "abc"), "guarda recalculada")
  p2 <- p; p2$regla$min_miembros <- 2L; escribir_preregistro_fase6(p2, tmp)
  expect_error(leer_preregistro_fase6(tmp), "regla")
  p3 <- p; p3$estado <- "borrador"; escribir_preregistro_fase6(p3, tmp)
  expect_error(leer_preregistro_fase6(tmp), "congelado")
  expect_error(leer_preregistro_fase6(tempfile()), "E1")
})

test_that("D7 (F6-13 d): medicion_bvar cuenta raíces explosivas y mide media contra mediana", {
  M <- 2L; lags <- 1L; S <- 5L
  estable <- rbind(c(0.01, 0.002), diag(c(0.5, 0.4)))
  explosiva <- rbind(c(0.01, 0.002), diag(c(1.08, 0.4)))
  arma <- function(B) list(modelo_id = "P", lags = lags, Y = matrix(c(4.6, 4.61, 3, 3.01), 2),
                           beta = aperm(array(B, c(dim(B), S)), c(3, 1, 2)), sigma = aperm(array(diag(1e-4, M), c(M, M, S)), c(3, 1, 2)))
  m1 <- medicion_bvar(arma(estable))
  expect_equal(m1$prop_raiz_mayor_1, c(0, 0)); expect_equal(m1$h, c(8L, 20L))
  expect_equal(m1$distancia_pp, c(0, 0), tolerance = 1e-8)        # extracciones idénticas: la mezcla es una normal
  m2 <- medicion_bvar(arma(explosiva))
  expect_equal(m2$prop_raiz_mayor_1_05, c(1, 1))
  mix <- arma(estable); mix$beta[1:2, , ] <- aperm(array(explosiva, c(dim(explosiva), 2L)), c(3, 1, 2))
  m3 <- medicion_bvar(mix)
  expect_equal(m3$prop_raiz_mayor_1, c(0.4, 0.4)); expect_true(all(m3$distancia_pp > 0))
})
