# src/analisis_posterior/ap1_explosivos.R
#
# Análisis posterior AP-1 de Fase 5 (doc/metodologia/decisiones_fase5.md, «Análisis posteriores»): diagnóstico de los
# dos pronósticos explosivos que declaró el cierre de Fase 5, REG.ENET.G3 en el origen 2021-Q1 (−348 pp a h = 8) y
# MULT.BVAR.G3 en 2020-Q2 (−126 pp a h = 8), y barrido descriptivo de toda la L4 de la corrida única.
#
# Es POSTERIOR a los resultados: no cambia ningún modelo, YAML, experimento, tabla ni MCS de Fase 5, ni los tags
# v0.8.x. Lo que encuentre entra a Fase 6 solo por ficha de decisión.
#
# Qué hace:
#   1. Reproduce cada caso con las funciones del propio pipeline (el mismo conjunto de información que arma
#      correr_backtest(), la misma semilla por exp_id, modelo y origen) sobre el corte de Fase 5, y compara el
#      sendero con data/L4_experiments/F5_G3/pronosticos.csv de la corrida citada (e1722fa).
#   2. ENET: por h, ventana, rejilla, candidato elegido, ECM interno, coeficientes, fila del origen en unidades de la
#      ventana y aporte de cada columna al pronóstico; senda completa de λ del α elegido.
#   3. BVAR: por extracción, sendero del PIB y módulo de la mayor raíz de la forma compañera; escala del último dato
#      de cada serie en el panel.
#   4. Barrido: senderos con interanual fuera del rango histórico del objetivo, por experimento y modelo.
#
# Uso (lee el corte congelado de F5-16, como make eval):
#   SIE_CONJUNTO=doc/metodologia/corte_fase5.csv SIE_SALIDA=data/conjuntos/corte_f5 Rscript src/analisis_posterior/ap1_explosivos.R
#
# Escribe en doc/metodologia/reportes_fase5/posteriores/ (LF): ap1_reproduccion.csv, ap1_enet_resumen.csv,
# ap1_enet_columnas.csv, ap1_enet_senda_lambda.csv, ap1_bvar_extracciones.csv, ap1_bvar_panel.csv y ap1_barrido.csv.
# No escribe en data/.

source(here::here("src", "evaluacion", "motor_backtesting.R"))

DIR_AP <- here::here("doc", "metodologia", "reportes_fase5", "posteriores")
CASOS_AP1 <- data.frame(exp_id = c("F5_G3", "F5_G3"), modelo_id = c("REG.ENET.G3", "MULT.BVAR.G3"),
                        origen = c("2021-Q1", "2020-Q2"), stringsAsFactors = FALSE)
TOL_REPRODUCCION_AP1 <- 1e-10   # el CSV de L4 se escribe con 15 cifras significativas

# ---------------------------------------------------------------------------------------------
# Insumos y conjunto de información (lo mismo que main() y correr_backtest(), sin escribir nada)
# ---------------------------------------------------------------------------------------------

#' Insumos del motor para los exp_id dados, como los lee main() antes del bucle de experimentos.
insumos_motor <- function(exp_ids) {
  sel <- seleccionar_experimentos(exp_ids)
  conjunto <- exigir_conjunto(conjunto_activo())                                 # C-3
  modelos <- do.call(c, lapply(seq_len(nrow(sel)), function(k) modelos_experimento(sel[k, ])))
  modelos <- modelos[!duplicated(vapply(modelos, `[[`, character(1), "modelo_id"))]
  vintages <- leer_vintages()
  pol <- unique(sel$vintage)
  if (length(pol) != 1L) stop("AP-1: una sola política de vintage")
  objetivos <- list()
  for (ob in unique(sel$objetivo)) objetivos[[ob]] <- leer_objetivo(paste0(ob, ".csv"), pol, vintages, conjunto)
  ins <- list(objetivos = objetivos, conjunto = identidad_conjunto(Sys.getenv("SIE_CONJUNTO")))
  if (any(sel$sa == "reestimado_en_origen")) {
    l1 <- .leer_capa("L1_staging", "BCR_PIB_series_largo.csv")
    ins$nsa <- leer_nsa_concat(vintages, objetivos$PIB_SA_PROPIO_Q, conjunto, l1 = l1)
    ins$outliers <- .leer_capa("L3_master", "PIB_SA_PROPIO_Q_outliers.csv")
  }
  pred <- predictoras_requeridas(modelos)
  if (length(pred)) ins$predictoras <- leer_predictoras(pred, vintages, conjunto)   # G-6
  list(sel = sel, insumos = ins)
}

#' Conjunto de información que correr_backtest() le pasa a `m` en el origen `o` del experimento `ex`.
info_en_origen <- function(ex, m, o, ins, cache_sa) {
  if (ex$ventana != "expansiva") stop("AP-1: solo experimentos con ventana expansiva")
  so <- serie_en_origen(ex, o, ins, cache_sa)
  pred <- setdiff(m$requiere, "objetivo")
  rez <- if (length(pred)) rezagos_predictoras(pred) else list()                   # F4-34, F5-04
  series <- c(list(objetivo = so$sa), ins$predictoras[pred])
  info <- stats::setNames(lapply(names(series), function(nm) {
    r <- recortar_a_origen(series[[nm]], o, rez[[nm]])
    guarda_recorte(r, o, rez[[nm]], nombre = nm)                                   # G-1
    if (nm != "objetivo") guarda_borde(r, o, rez[[nm]], nombre = nm)               # G-7
    r
  }), names(series))
  list(info = info, bases = so$sa)
}

#' Reestima `modelo_id` en el origen `origen` de `exp_id` con la semilla del motor y devuelve el ajuste y el sendero.
reproducir_caso <- function(exp_id, modelo_id, origen, im, cache_sa) {
  ex <- im$sel[im$sel$exp_id == exp_id, ]
  if (nrow(ex) != 1L) stop("AP-1: exp_id no declarado: ", exp_id)
  ms <- modelos_experimento(ex)                                                   # instancias nuevas (memo vacío)
  k <- match(modelo_id, vapply(ms, `[[`, character(1), "modelo_id"))
  if (is.na(k)) stop("AP-1: ", modelo_id, " no está en ", exp_id)
  m <- ms[[k]]
  o <- q_a_ind(origen)
  ie <- info_en_origen(ex, m, o, im$insumos, cache_sa)
  sem <- if (is.null(ex$semilla_exp)) ex$exp_id else ex$semilla_exp                # igual que correr_experimento()
  semilla <- semilla_de(sem, m$modelo_id, o)
  set.seed(semilla)
  aj <- m$ajustar(ie$info[m$requiere], NULL)
  sendero <- m$predecir(aj, DISENO_FASE4$h_max)
  pr <- data.frame(modelo_id = modelo_id, origen = o, h = seq_along(sendero), log_nivel_pronosticado = sendero)
  pu <- derivar_unidades(pr, im$insumos$objetivos$PIB_SA_PROPIO_Q[, c("periodo", "y")],
                         bases = data.frame(origen = o, periodo = ie$bases$periodo, y = ie$bases$y))
  list(ex = ex, m = m, o = o, info = ie$info, semilla = semilla, ajuste = aj, unidades = pu)
}

#' Compara el sendero reproducido con el de L4 (corrida citada).
comparar_con_l4 <- function(rc, dir_l4 = here::here("data", "L4_experiments")) {
  p <- utils::read.csv(file.path(dir_l4, rc$ex$exp_id, "pronosticos.csv"), stringsAsFactors = FALSE)
  p <- p[p$modelo_id == rc$m$modelo_id & p$origen == ind_a_q(rc$o), ]
  p <- p[order(p$h), ]
  if (nrow(p) != nrow(rc$unidades)) stop("AP-1: L4 no tiene el sendero completo de ", rc$m$modelo_id, " en ", ind_a_q(rc$o))
  d_log <- max(abs(p$log_nivel_pronosticado - rc$unidades$log_nivel_pronosticado))
  d_yoy <- max(abs(p$yoy_pp_pronosticado - rc$unidades$yoy_pp_pronosticado))
  data.frame(exp_id = rc$ex$exp_id, modelo_id = rc$m$modelo_id, origen = ind_a_q(rc$o), semilla = rc$semilla,
             yoy_h8_l4 = p$yoy_pp_pronosticado[8], yoy_h8_reproducido = rc$unidades$yoy_pp_pronosticado[8],
             max_dif_log_nivel = d_log, max_dif_yoy_pp = d_yoy,
             reproduce = d_log <= TOL_REPRODUCCION_AP1 && d_yoy <= 100 * TOL_REPRODUCCION_AP1, stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------------------------
# ENET
# ---------------------------------------------------------------------------------------------

#' Desarma el ajuste del ENET en un origen: por h, la ventana, la elección, los coeficientes y el aporte de cada
#' columna al pronóstico de g_h, con la misma transformación de ventana que usa el modelo (B3-2).
diagnosticar_enet <- function(rc) {
  m <- rc$m; o <- rc$o; aj <- rc$ajuste
  md <- matriz_directa(rc$info[m$requiere], setdiff(m$requiere, "objetivo"), m$modelo_id)
  nw <- which(md$t == o)
  resumen <- list(); columnas <- list(); senda <- list()
  for (h in seq_along(aj$por_h)) {
    ph <- aj$por_h[[h]]; rj <- ph$rejilla; j <- ph$eleccion
    g <- crecimiento_acumulado(md, h)
    tr <- which(md$t + h <= o)
    vt <- ventana_directa(md$X[tr, , drop = FALSE], unname(g[tr]), md$t[tr], md$con_dummies, m$modelo_id)
    an <- aplicar_ventana(vt, md$X[nw, , drop = FALSE], o)
    a <- rj$alpha[j]; ia <- which(rj$alpha == a)
    B <- .senda_glmnet(vt$Z, vt$gz, a, rj$lambda[ia])
    b <- B[, rj$pos[j]]
    z <- as.numeric(an$z)
    aporte <- z * b
    g_rec <- an$base + sum(aporte)
    if (abs(g_rec - ph$g_hat) > 1e-10) stop(sprintf("AP-1: el ENET desarmado no reproduce g_hat en h = %d (%.3g)", h, g_rec - ph$g_hat))
    zmax_v <- apply(abs(vt$Z), 2L, max)
    k <- which.max(abs(z))
    ecm <- ph$ecm
    resumen[[h]] <- data.frame(
      h = h, alpha = a, lambda = rj$lambda[j], lambda_pos = rj$pos[j], borde = rj$pos[j] %in% c(1L, max(rj$pos)),
      n_filas_ventana = length(tr), n_columnas = ncol(md$X), ultimo_t_ventana = ind_a_q(max(md$t[tr])),
      coef_no_nulos = sum(abs(b) > 0), norma_l1_coef = sum(abs(b)),
      ecm_interno_elegido = ecm[j], ecm_interno_mediana_rejilla = stats::median(ecm),
      ecm_interno_mas_penalizado = ecm[which(rj$alpha == a & rj$pos == 1L)],
      z_origen_max_abs = abs(z[k]), columna_z_max = colnames(md$X)[k],
      columnas_fuera_rango_ventana = sum(abs(z) > zmax_v),
      g_base = an$base, g_modelo = sum(aporte), g_hat = ph$g_hat, stringsAsFactors = FALSE)
    columnas[[h]] <- data.frame(h = h, columna = colnames(md$X), z_origen = z, z_max_abs_ventana = zmax_v, coef = b,
                                aporte_log = aporte, stringsAsFactors = FALSE)
    P <- as.numeric(matrix(z, nrow = 1L) %*% B) + an$base
    senda[[h]] <- data.frame(h = h, alpha = a, lambda_pos = rj$pos[ia], lambda = rj$lambda[ia], ecm_interno = ecm[ia],
                             g_hat = P, elegido = rj$pos[ia] == rj$pos[j], stringsAsFactors = FALSE)
  }
  list(resumen = do.call(rbind, resumen), columnas = do.call(rbind, columnas), senda = do.call(rbind, senda))
}

# ---------------------------------------------------------------------------------------------
# BVAR
# ---------------------------------------------------------------------------------------------

#' Sendero del log-PIB por extracción (la recursión de momentos_predictiva_bvar(), sin choques): S x H.
mu_por_extraccion <- function(beta, Y, lags, H) {
  S <- dim(beta)[1]; M <- dim(beta)[3]; N <- nrow(Y)
  estado <- matrix(rep(as.vector(t(Y[N:(N - lags + 1L), , drop = FALSE])), each = S), nrow = S)
  mu <- matrix(NA_real_, S, H)
  for (h in seq_len(H)) {
    yn <- vapply(seq_len(M), function(i) beta[, 1L, i] + rowSums(beta[, -1L, i, drop = FALSE][, , 1L] * estado), numeric(S))
    yn <- matrix(yn, nrow = S)
    mu[, h] <- yn[, 1L]
    estado <- if (lags > 1L) cbind(yn, estado[, seq_len(M * (lags - 1L)), drop = FALSE]) else yn
  }
  mu
}

#' Módulo de la mayor raíz de la forma compañera de cada extracción.
raiz_max_extracciones <- function(beta, lags) {
  S <- dim(beta)[1]; M <- dim(beta)[3]; Mp <- M * lags
  vapply(seq_len(S), function(s) {
    A <- t(beta[s, -1L, ])                                   # M x (M p): fila = ecuación, columnas = rezago 1, 2, ...
    C <- matrix(0, Mp, Mp); C[seq_len(M), ] <- A
    if (lags > 1L) C[(M + 1L):Mp, seq_len(M * (lags - 1L))] <- diag(M * (lags - 1L))
    max(Mod(eigen(C, only.values = TRUE)$values))
  }, numeric(1))
}

#' Vuelve a correr el BVAR del caso con la misma semilla y devuelve el diagnóstico por extracción y del panel.
diagnosticar_bvar <- function(rc) {
  m <- rc$m
  pn <- panel_bvar(rc$info[m$requiere], setdiff(m$requiere, "objetivo"), m$modelo_id)
  Y <- pn$Y
  psi <- psi_bvar(Y, m$lags, m$modelo_id, pn$o)
  set.seed(rc$semilla)
  fit <- BVAR::bvar(Y, lags = m$lags, n_draw = m$n_draw, n_burn = m$n_burn, n_thin = 1L, priors = priors_bvar(psi),
                    mh = mh_bvar(), fcast = NULL, irf = NULL, verbose = FALSE)
  mom <- momentos_predictiva_bvar(fit$beta, fit$sigma, Y, m$lags, H_BVAR)
  if (!identical(mom$media, rc$ajuste$media)) stop("AP-1: el BVAR vuelto a correr no reproduce la media del ajuste")
  mu <- mu_por_extraccion(fit$beta, Y, m$lags, H_BVAR)
  if (max(abs(colMeans(mu) - mom$media)) > 1e-12) stop("AP-1: la recursión por extracción no da la media de la predictiva")
  raiz <- raiz_max_extracciones(fit$beta, m$lags)
  base <- rc$unidades$log_nivel_pronosticado - rc$unidades$yoy_pp_pronosticado / 100   # base de la interanual en log
  yoy <- sweep(mu, 2L, base) * 100                                          # interanual por extracción, pp
  ext <- data.frame(extraccion = seq_len(nrow(mu)), raiz_max = raiz, yoy_h4 = yoy[, 4], yoy_h8 = yoy[, 8],
                    lambda = fit$hyper[, "lambda"], stringsAsFactors = FALSE)
  dY <- diff(Y)
  panel <- data.frame(serie = colnames(Y), n_obs = nrow(Y), inicio = ind_a_q(pn$t[1]), fin = ind_a_q(pn$o),
                      dlog_ultimo = dY[nrow(dY), ], dlog_sd_previa = apply(dY[-nrow(dY), , drop = FALSE], 2L, stats::sd),
                      stringsAsFactors = FALSE)
  panel$z_ultimo <- panel$dlog_ultimo / panel$dlog_sd_previa
  list(extracciones = ext, panel = panel, aceptacion = fit$meta$accepted / nrow(mu))
}

# ---------------------------------------------------------------------------------------------
# Barrido descriptivo de la L4
# ---------------------------------------------------------------------------------------------

#' Por experimento F5_G* y modelo: senderos (origen, h) con interanual fuera del rango histórico del objetivo
#' observado [mín, máx] y fuera del doble de su máximo absoluto. Descriptivo: no es una guarda ni una regla.
barrido_l4 <- function(objetivo, dir_l4 = here::here("data", "L4_experiments")) {
  y <- stats::setNames(objetivo$y, q_a_ind(objetivo$periodo))
  i <- as.integer(names(y)); i <- i[(i - 4L) %in% as.integer(names(y))]
  yoy_obs <- 100 * (y[as.character(i)] - y[as.character(i - 4L)])
  lo <- min(yoy_obs); hi <- max(yoy_obs); amax <- max(abs(yoy_obs))
  exps <- sort(grep(PATRON_EXP_PREREGISTRO, list.dirs(dir_l4, full.names = FALSE, recursive = FALSE), value = TRUE))
  do.call(rbind, lapply(exps, function(x) {
    p <- utils::read.csv(file.path(dir_l4, x, "pronosticos.csv"), stringsAsFactors = FALSE)
    do.call(rbind, lapply(split(p, p$modelo_id), function(q) {
      fuera <- q$yoy_pp_pronosticado < lo | q$yoy_pp_pronosticado > hi
      doble <- abs(q$yoy_pp_pronosticado) > 2 * amax
      data.frame(exp_id = x, modelo_id = q$modelo_id[1], n_pronosticos = nrow(q), fuera_rango_historico = sum(fuera),
                 fuera_doble_max_abs = sum(doble), origenes_fuera_doble = length(unique(q$origen[doble])),
                 yoy_min = min(q$yoy_pp_pronosticado), yoy_max = max(q$yoy_pp_pronosticado),
                 rango_hist_min = lo, rango_hist_max = hi, stringsAsFactors = FALSE)
    }))
  }))
}

# ---------------------------------------------------------------------------------------------

escribir_ap <- function(x, nombre) {
  dir.create(DIR_AP, showWarnings = FALSE, recursive = TRUE)
  escribir_tabla_resultados(x, file.path(DIR_AP, nombre))                     # LF en todas las plataformas
  cat(sprintf("%s: %d filas, sha256 %s\n", nombre, nrow(x), digest::digest(file = file.path(DIR_AP, nombre), algo = "sha256")))
}

if (sys.nframe() == 0L) {
  source(here::here("src", "evaluacion", "tabla_resultados_fase4.R"))         # escribir_tabla_resultados()
  im <- insumos_motor(unique(CASOS_AP1$exp_id))
  cache_sa <- new.env()
  casos <- lapply(seq_len(nrow(CASOS_AP1)), function(k) reproducir_caso(CASOS_AP1$exp_id[k], CASOS_AP1$modelo_id[k],
                                                                         CASOS_AP1$origen[k], im, cache_sa))
  repro <- do.call(rbind, lapply(casos, comparar_con_l4))
  escribir_ap(repro, "ap1_reproduccion.csv")
  if (!all(repro$reproduce)) stop("AP-1: algún caso no reproduce la L4 de la corrida citada; ver ap1_reproduccion.csv")
  en <- diagnosticar_enet(casos[[1]])
  escribir_ap(en$resumen, "ap1_enet_resumen.csv"); escribir_ap(en$columnas, "ap1_enet_columnas.csv")
  escribir_ap(en$senda, "ap1_enet_senda_lambda.csv")
  bv <- diagnosticar_bvar(casos[[2]])
  cat(sprintf("BVAR: aceptación %.4f\n", bv$aceptacion))
  escribir_ap(bv$extracciones, "ap1_bvar_extracciones.csv"); escribir_ap(bv$panel, "ap1_bvar_panel.csv")
  escribir_ap(barrido_l4(im$insumos$objetivos$PIB_SA_PROPIO_Q), "ap1_barrido.csv")
}
