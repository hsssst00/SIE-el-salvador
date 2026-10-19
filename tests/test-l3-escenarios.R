# tests/test-l3-escenarios.R
#
# Pruebas sinteticas de las reglas de las variables de escenario de Fase 6
# (src/transformacion/l3_escenarios_reglas.R; F6-14, F6-16 y F6-18 de decisiones_fase6.md) y de la
# etapa de escenario en los conjuntos de vintages (conjunto_lib.R, F6-18-d). No se lee data/: solo
# los catalogos versionados, en la ultima prueba.

library(testthat)

source(here::here("src", "transformacion", "l3_predictores_reglas.R"))
source(here::here("src", "transformacion", "l3_escenarios_reglas.R"))
source(here::here("src", "transformacion", "conjunto_lib.R"))

.mensual <- function(desde, n, valor) {
  i0 <- .m_a_ind(desde)
  data.frame(periodo = .ind_a_m(i0 + seq_len(n) - 1L), valor = valor, stringsAsFactors = FALSE)
}
.trimestral <- function(desde, valor) {
  i0 <- .q_a_ind(desde)
  data.frame(periodo = .ind_a_q(i0 + seq_along(valor) - 1L), valor = valor, stringsAsFactors = FALSE)
}
.anual <- function(anios, valor) data.frame(periodo = as.character(anios), valor = valor, stringsAsFactors = FALSE)

test_that("T012: un mes aislado sin dato se rellena con la media geometrica de sus vecinos (F6-18-b)", {
  m <- .mensual("2020-M01", 12, 100 * 1.01^(0:11))
  m$valor[5] <- NA
  r <- interpolar_mes_aislado(m, "X")
  expect_equal(r$valor[5], sqrt(m$valor[4] * m$valor[6]))
  expect_identical(r$interpolado, seq_len(12) == 5)
  q <- agregar_trimestral_promedio_mes_aislado(m, "X")
  expect_identical(attr(q, "meses_interpolados"), "2020-M05")
  expect_equal(q$valor[2], mean(r$valor[4:6]))
  expect_identical(q$periodo, c("2020-Q1", "2020-Q2", "2020-Q3", "2020-Q4"))
})

test_that("T012: dos meses seguidos sin dato, un mes sin dato en el borde o una fila faltante son stop()", {
  m <- .mensual("2020-M01", 12, 100 + 0:11)
  dos <- m; dos$valor[5:6] <- NA
  expect_error(interpolar_mes_aislado(dos, "X"), "hueco de dos meses")
  borde <- m; borde$valor[12] <- NA
  expect_error(interpolar_mes_aislado(borde, "X"), "borde de la serie")
  expect_error(interpolar_mes_aislado(m[-7, ], "X"), "no es contigua")
  # T013 usa agregar_trimestral_promedio() sin interpolar: un mes sin dato detiene la corrida.
  sin <- m; sin$valor[5] <- NA
  expect_error(agregar_trimestral_promedio(sin, "X"), "ausente")
})

test_that("metas_anuales: ancla en el ultimo año completo y encadena crecimientos (F6-16)", {
  h <- .trimestral("2023-Q1", c(100, 101, 102, 103, 104, 105, 106, 107, 108, 109))  # 2023-2024 completos; 2025 hasta Q2
  g <- stats::setNames(c(2, 3, 1, 1, 1, 1, 1, 1), 2024:2031)
  a <- metas_anuales(h, g, "X")
  expect_identical(names(a), as.character(2024:2031))
  expect_equal(a[["2024"]], mean(104:107))
  expect_equal(a[["2025"]], mean(104:107) * 1.03)
  expect_equal(a[["2031"]], mean(104:107) * 1.03 * 1.01^6)
  expect_error(metas_anuales(h, g[-3], "X"), "no cubre los años 2026")
  expect_equal(crecimiento_desde_nivel(c(`2020` = 50, `2021` = 60)), c(`2021` = 20))
})

test_that("Denton-Cholette propio sin trimestres fijos coincide con tempdisagg (F6-16, contraste)", {
  anual <- c(100, 103, 101, 106, 110, 108)
  x <- denton_cholette(rep(NA_real_, 24), rep(2015:2020, each = 4), stats::setNames(anual, 2015:2020), "X")
  td <- tempdisagg::td(stats::ts(anual, start = 2015, frequency = 1) ~ 1, to = "quarterly",
                       conversion = "average", method = "denton-cholette")
  expect_equal(x, as.numeric(stats::predict(td)), tolerance = 1e-8)
  expect_equal(as.numeric(tapply(x, rep(1:6, each = 4), mean)), anual, tolerance = 1e-12)
})

test_that("Denton con trimestres fijos: respeta los fijos, las metas y es el optimo", {
  h <- .trimestral("2024-Q1", c(100, 102, 103, 104, 106, 107))   # 2024 completo, 2025 hasta Q2
  metas <- c(`2024` = mean(c(100, 102, 103, 104)), `2025` = 108, `2026` = 112, `2027` = 115)
  s <- .sendero_desde_metas(h, metas, "X", anio_fin = 2027L)
  expect_identical(s$periodo, .ind_a_q(.q_a_ind("2024-Q1") + 0:15))
  expect_identical(s$tramo, rep(c("historia", "sendero"), c(6, 10)))
  expect_identical(s$valor[1:6], h$valor)
  pa <- promedio_anual_q(s)
  expect_equal(unname(pa[c("2025", "2026", "2027")]), unname(metas[-1]), tolerance = 1e-12)
  # Optimalidad: cualquier perturbacion de los libres que conserva los promedios anuales aumenta la
  # suma de cuadrados de las primeras diferencias.
  obj <- function(v) sum(diff(v)^2)
  libres <- 7:16
  anio <- .anio_q(s$periodo)[libres]
  C <- t(vapply(2025:2027, function(y) as.numeric(anio == y), numeric(length(libres))))
  nucleo <- qr.Q(qr(t(C)), complete = TRUE)[, -(1:3)]
  set.seed(1)
  for (k in 1:20) {
    v <- s$valor; v[libres] <- v[libres] + nucleo %*% stats::rnorm(ncol(nucleo), sd = 0.5)
    expect_gt(obj(v), obj(s$valor))
  }
})

test_that("Denton: año con meta sin trimestre libre o grilla incompleta son stop()", {
  expect_error(denton_cholette(c(1, 2, 3, 4, NA, NA, NA, NA), rep(1:2, each = 4), c(`1` = 2.5, `2` = 6), "X"),
               "ningun trimestre libre")
  expect_error(denton_cholette(c(NA, NA, NA), c(1, 1, 1), c(`1` = 2), "X"), "cuatro trimestres")
})

test_that("T014: desvio de nivel (PIB) y de inflacion (IPC) se reproducen en los promedios anuales (F6-14)", {
  h <- .trimestral("2023-Q1", 100 * 1.005^(0:13))           # hasta 2026-Q2
  g <- .anual(2024:2031, c(2.5, 2.4, 2.3, 2.2, 2.1, 2.0, 1.9, 1.8))
  d <- .anual(2026:2031, c(0, -1.5, -1.8, -1.4, -0.8, -0.5))
  base <- sendero_escenario_crecimiento(h, g, "B")
  adv <- sendero_escenario_desvio_nivel(h, g, d, "A")
  pb <- promedio_anual_q(base); pa <- promedio_anual_q(adv)
  expect_equal(unname(pa[as.character(2026:2031)] / pb[as.character(2026:2031)] - 1), d$valor / 100, tolerance = 1e-12)
  expect_equal(unname(100 * (pb[as.character(2026:2031)] / pb[as.character(2025:2030)] - 1)), g$valor[3:8], tolerance = 1e-10)
  validar_metas(adv, attr(adv, "metas"), "A")
  validar_historia(adv, h, "A")
  validar_historia_comun(list(BASE = base, ADVERSO = adv), "V")
  expect_lt(validar_desvio(adv, base, d, "nivel_pct", "A"), 1e-12)
  di <- .anual(2026:2031, c(0, 0, -0.1, -0.3, -0.2, 0))
  ipc <- sendero_escenario_desvio_crecimiento(h, g, di, "I")
  expect_lt(validar_desvio(ipc, base, di, "crecimiento_pp", "I"), 1e-10)
  expect_error(validar_desvio(ipc, base, .anual(2026:2031, c(0, 0, 0, -0.3, -0.2, 0)), "crecimiento_pp", "I"), "V-ESC-3")
  expect_error(sendero_escenario_desvio_nivel(h, g, d[-1, ], "A"), "no cubre los años 2026")
})

test_that("T014: el petroleo encadena el crecimiento implicito en el nivel anual", {
  h <- .trimestral("2024-Q1", c(80, 82, 84, 86, 70, 72, 74, 76, 90))   # hasta 2026-Q1
  niv <- .anual(2024:2031, c(83, 73, 95, 87, 78, 75, 72, 70))
  s <- sendero_escenario_nivel_anual(h, niv, "P")
  pa <- promedio_anual_q(s)
  expect_equal(unname(pa[as.character(2026:2031)]), mean(c(70, 72, 74, 76)) * niv$valor[3:8] / niv$valor[2], tolerance = 1e-12)
})

test_that("validaciones de F6-18: cada una detiene ante su falla", {
  h <- .trimestral("2023-Q1", 100 * 1.005^(0:13))
  g <- .anual(2024:2031, rep(2, 8))
  s <- sendero_escenario_crecimiento(h, g, "B")
  mal <- s; mal$valor[nrow(mal)] <- mal$valor[nrow(mal)] * (1 + 1e-6)
  expect_error(validar_metas(mal, attr(s, "metas"), "B"), "V-ESC-1")
  h2 <- h; h2$valor[3] <- h2$valor[3] + 1e-9
  expect_error(validar_historia(s, h2, "B"), "V-ESC-2")
  otro <- s; otro$valor[2] <- otro$valor[2] + 1
  expect_error(validar_historia_comun(list(BASE = s, ADVERSO = otro), "V"), "V-ESC-2")
  expect_silent(validar_estructura(s, "2026-Q2", "B"))
  expect_error(validar_estructura(s, "2027-Q1", "B"), "V-ESC-4 .* exige llegar a 2032-Q1")
  neg <- s; neg$valor[1] <- -1
  expect_error(validar_estructura(neg, "2026-Q2", "B"), "no positivos")
  pm <- .mensual("2020-M01", 30, 50 + (1:30))
  w <- .anual(2020:2021, c(mean(51:62), mean(63:74)))
  expect_lt(validar_petroleo_weo(pm, w)$error_max, 1e-12)
  w$valor[2] <- w$valor[2] * (1 + 1e-5)
  expect_error(validar_petroleo_weo(pm, w), "V-ESC-5")
  ipc <- .mensual("2019-M01", 36, 100 * 1.002^(0:35))
  pa <- promedio_anual_m(ipc)
  infl <- .anual(2020:2021, 100 * (pa[c("2020", "2021")] / pa[c("2019", "2020")] - 1))
  expect_lt(validar_ipc_weo(ipc, infl)$dif_max, 1e-10)
  hueco <- ipc; hueco$valor[30] <- NA     # 2021 deja de ser completo y queda fuera de la comparacion
  expect_identical(validar_ipc_weo(hueco, infl)$anios, c(2020L, 2020L))
  infl$valor[1] <- infl$valor[1] + 0.02
  expect_error(validar_ipc_weo(ipc, infl), "V-ESC-6")
})

test_that("etapa de escenario: todo o nada en un conjunto (F6-18-d)", {
  series <- data.frame(serie_id = c("A.M", "E1.Q", "E2.A", "M.Q"), publicacion_id = c("PUB_A", "PUB_E1", "PUB_E2", "PUB_A"),
                       stringsAsFactors = FALSE)
  master <- data.frame(series_master_id = c("A.Q", "ESC.X.BASE", "ESC.Y"), rol = c("predictor", "escenario", "escenario"),
                       series_insumo_ids = c("A.M", "E1.Q, E2.A", "A.M"), stringsAsFactors = FALSE)
  esc <- publicaciones_de_escenario(series, master)
  expect_identical(esc, c("PUB_E1", "PUB_E2"))            # PUB_A tambien alimenta un predictor: no es de escenario
  expect_true(etapa_escenario_activa(NULL, esc))
  expect_false(etapa_escenario_activa(data.frame(publicacion_id = "PUB_A", vintage_id = "PUB_A.v1"), esc))
  expect_true(etapa_escenario_activa(data.frame(publicacion_id = c("PUB_A", "PUB_E1", "PUB_E2")), esc))
  expect_error(etapa_escenario_activa(data.frame(publicacion_id = c("PUB_A", "PUB_E1")), esc), "todo o nada")
  expect_identical(publicaciones_necesarias(series), c("PUB_A", "PUB_E1", "PUB_E2"))
  expect_identical(publicaciones_necesarias(series, master, data.frame(publicacion_id = "PUB_A")), "PUB_A")
  expect_identical(publicaciones_necesarias(series, master, NULL), c("PUB_A", "PUB_E1", "PUB_E2"))
})

test_that("catalogos: las publicaciones de escenario son las cinco de F6-18 y T014 cubre las siete ESC.*", {
  series <- utils::read.csv(here::here("catalogos", "03_series.csv"), stringsAsFactors = FALSE, na.strings = "")
  master <- utils::read.csv(here::here("catalogos", "05_series_master.csv"), stringsAsFactors = FALSE, na.strings = "")
  transf <- utils::read.csv(here::here("catalogos", "04_transformaciones.csv"), stringsAsFactors = FALSE, na.strings = "")
  expect_identical(publicaciones_de_escenario(series, master),
                   sort(c("FMI.PCPS.POILAPSP_USD", "FMI.WEO", "FMI.WEO.CAPITULO1", "FRED.BEA_PIB_EEUU", "FRED.CPIAUCSL")))
  esc <- master[master$rol == "escenario", ]
  expect_setequal(esc$series_master_id[grepl("^ESC\\.", esc$series_master_id)],
                  c(paste0("ESC.PIB_EEUU.VOL.SA.Q.", ESCENARIOS_FASE6), paste0("ESC.IPC_EEUU.IDX.SA.Q.", ESCENARIOS_FASE6),
                    "ESC.PETROLEO_APSP.USD.NSA.Q.BASE"))
  propias <- transf[transf$script_path == "src/transformacion/l3_escenarios.R", ]
  expect_setequal(propias$serie_producto, esc$series_master_id[!is.na(esc$transf_id)])
  for (f in unique(sub("\\(\\)$", "", propias$funcion))) expect_true(exists(f, mode = "function"), info = f)
})
