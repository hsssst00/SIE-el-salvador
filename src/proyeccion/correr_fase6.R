# correr_fase6.R
#
# Orquestación del Ejercicio B (checklist de Fase 6, D7; F6-01 a F6-19 de doc/metodologia/decisiones_fase6.md;
# protocolo_proyeccion.md §2 a §11). Une las piezas de D1-D6 en una sola corrida:
#
#   1. Satélites (F6-15): una por predictora externa, estimadas una vez en el origen y comunes a los tres grupos.
#   2. Por grupo: cada modelo de modelos_fase6() se ajusta una vez en `o` con su YAML de Fase 5 (F6-04), con la
#      semilla semilla_de(exp_id, modelo_id, o) del motor (F5-15). Los trimestrales ven sus .Q hasta `o`; el puente,
#      todos sus meses observados (F6-17).
#   3. Por corrida (BASE, ADVERSO, FAVORABLE y las seis de sensibilidad, F6-05, F6-09): el sendero de cada predictora
#      externa sale de su satélite con la variable de escenario de la corrida, y cada elegible proyecta con
#      predecir_condicional(). La regla de §7 (guarda, mínimo, mediana y mezcla) da la combinación.
#   4. Reporte (F6-11) y coherencia (F6-10) de las tres corridas principales; la sensibilidad se reporta como cambio
#      frente a la base; la trayectoria sin escenario de los demás modelos va aparte (F6-01).
#
# El núcleo (correr_fase6_nucleo()) no hace I/O y se prueba con datos sintéticos en tests/test-correr-fase6.R. main()
# lee el corte congelado, exige el preregistro de E1 (PREREGISTRO_FASE6, con la guarda calculada sobre el corte) y un
# árbol limpio, corre y escribe data/L4_experiments/F6_*/ con manifiesto y las filas de catalogos/07_experimentos.csv.
# El modo `medicion` (F6-13 d, ítem E2 del checklist) solo ajusta el BVAR de cada grupo y reporta las dos cifras de
# la ficha; no proyecta ni mira senderos.
#
# Uso: make fase6   (o make fase6-medicion-bvar para E2)

source(here::here("src", "proyeccion", "reporte.R"))      # combinacion, condicional, motor_backtesting, sensibilidad
source(here::here("src", "proyeccion", "satelites.R"))

PREREGISTRO_FASE6 <- here::here("doc", "metodologia", "preregistro_fase6.yaml")   # F6-12: lo escribe E1
CORTE_FASE6 <- "corte_fase6.csv"                                                   # F6-04
TOL_PREREGISTRO <- 1e-10
exp_fase6 <- function(grupo) paste0("F6_", grupo)

# ---------------------------------------------------------------------------------------------
# Preregistro (F6-12, E1)
# ---------------------------------------------------------------------------------------------

#' Contenido del preregistro de Fase 6: las constantes del código que la corrida usa y la guarda calculada sobre el
#' objetivo del corte (F6-08-a). Lo escribe scripts/armar_preregistro_fase6.R al congelar (E1).
armar_preregistro_fase6 <- function(objetivo, o, corte_sha256, fecha = Sys.Date()) {
  r <- rango_guarda(objetivo)
  list(
    preregistro = "fase6", estado = "congelado", fecha_congelamiento = format(as.Date(fecha)),
    corte = paste0("doc/metodologia/", CORTE_FASE6), corte_sha256_sin_cr = corte_sha256, origen = ind_a_q(o),
    h_max = DISENO_FASE6$h_max, grupos = DISENO_FASE6$grupos, escenarios = DISENO_FASE6$escenarios,
    regla = list(combinacion = "mediana_dy", min_miembros = DISENO_FASE6$min_miembros),                     # F6-02
    guarda = list(objetivo = "PIB_SA_PROPIO_Q", anios_fuera = ANIOS_FUERA_GUARDA, minimo = r$minimo,        # F6-08
                  maximo = r$maximo, X = r$X, n = r$n, inferior = r$inferior, superior = r$superior),
    intervalos = list(niveles = DISENO_FASE6$niveles, h_calibrado = DISENO_FASE6$h_calibrado,               # F6-07
                      mezcla = "pesos_iguales", n_sim_anual = N_SIM_ANUAL),
    sensibilidad = list(variables = names(VARIABLES_SENSIBILIDAD), desviaciones = 1,                        # F6-09
                        anios_fuera = ANIOS_FUERA_SENSIBILIDAD),
    coherencia = list(stop = "agregacion", informativas = c("weo_slv", "historico", "signos", "deflactor_remesas"))  # F6-10
  )
}

#' Escribe el preregistro con 17 dígitos significativos (yaml usa 7 por omisión y la guarda se compara a 1e-10) y LF.
escribir_preregistro_fase6 <- function(p, ruta = PREREGISTRO_FASE6) {
  con <- file(ruta, open = "wb"); on.exit(close(con))
  writeLines(enc2utf8(c("# Preregistro de Fase 6 (F6-12, ítem E1 del checklist). Lo escribe scripts/armar_preregistro_fase6.R; no se edita a mano.",
                        sub("\n$", "", yaml::as.yaml(p, precision = 17L)))), con, sep = "\n", useBytes = TRUE)
  invisible(ruta)
}

#' Lee el preregistro y comprueba que sus constantes son las del código. stop() si falta, si no está congelado o si
#' algo difiere.
leer_preregistro_fase6 <- function(ruta = PREREGISTRO_FASE6) {
  if (!file.exists(ruta)) stop("F6-12: no existe ", ruta_relativa(ruta), ". El preregistro se congela en E1 (scripts/armar_preregistro_fase6.R) antes de la primera proyección.")
  p <- yaml::read_yaml(ruta)
  if (!identical(p$preregistro, "fase6") || !identical(p$estado, "congelado")) stop("F6-12: ", ruta_relativa(ruta), " no es un preregistro de Fase 6 congelado")
  ref <- armar_preregistro_fase6(data.frame(periodo = ind_a_q(0:5 + 8000L), y = c(0, 1, 3, 2, 5, 4)), 8005L, "x")
  for (k in c("h_max", "grupos", "escenarios", "regla", "intervalos", "sensibilidad", "coherencia")) {
    if (!isTRUE(all.equal(p[[k]], ref[[k]]))) stop("F6-12: el preregistro y el código difieren en `", k, "`")
  }
  if (!isTRUE(all.equal(p$guarda$anios_fuera, ref$guarda$anios_fuera))) stop("F6-12: el preregistro y el código difieren en guarda$anios_fuera")
  p
}

#' Comprueba el preregistro contra el corte y el objetivo de la corrida: mismo corte (sha256 sin CR), mismo origen y
#' la guarda recalculada igual a la congelada. Devuelve el rango de la guarda.
verificar_preregistro <- function(p, objetivo, o, corte_sha256) {
  if (!identical(p$corte_sha256_sin_cr, corte_sha256)) stop("F6-12: el corte de la corrida no es el que congeló el preregistro")
  if (!identical(p$origen, ind_a_q(o))) stop("F6-12: el origen del corte es ", ind_a_q(o), " y el preregistro congeló ", p$origen)
  r <- rango_guarda(objetivo)
  for (k in c("minimo", "maximo", "X", "inferior", "superior", "n")) {
    if (abs(r[[k]] - p$guarda[[k]]) > TOL_PREREGISTRO * max(1, abs(r[[k]]))) stop("F6-08: la guarda recalculada difiere de la congelada en `", k, "`")
  }
  list(inferior = p$guarda$inferior, superior = p$guarda$superior)
}

# ---------------------------------------------------------------------------------------------
# Satélites y corridas
# ---------------------------------------------------------------------------------------------

#' Satélites de las predictoras `ids` (.Q) en el origen (F6-15): ajustar_satelite() con la predictora completa y la
#' historia de su variable de escenario.
ajustar_satelites <- function(ids, series, z_hist, o) {
  stats::setNames(lapply(ids, function(id) {
    v <- .variable_satelite(id)
    if (is.null(series[[id]]) || is.null(z_hist[[v$z_historia]])) stop("satélites: falta la serie de ", id, " o ", v$z_historia)
    ajustar_satelite(series[[id]], z_hist[[v$z_historia]], o, v$satelite_id)
  }), ids)
}

#' Corridas de la proyección (F6-05, F6-09): las tres principales sobre las series ESC.* de L3 y las seis de la
#' sensibilidad sobre las series base desplazadas. Cada una: list(escenario, series) con `series` las ESC.* que ve.
corridas_fase6 <- function(esc, sens) {
  c(stats::setNames(lapply(DISENO_FASE6$escenarios, function(e) list(escenario = e, series = esc, principal = TRUE)), DISENO_FASE6$escenarios),
    lapply(sens, function(s) list(escenario = "BASE", series = s, principal = FALSE)))
}

#' Proyecciones de las satélites `ids` en una corrida (F6-15, F6-17-a).
proyectar_satelites <- function(sat, ids, series, corrida, h = DISENO_FASE6$h_max) {
  stats::setNames(lapply(ids, function(id) {
    z <- corrida$series[[serie_escenario(id, corrida$escenario, names(corrida$series))]]
    proyectar_satelite(sat[[id]], series[[id]], z, h)
  }), ids)
}

# ---------------------------------------------------------------------------------------------
# Un grupo
# ---------------------------------------------------------------------------------------------

#' Datos de un modelo en el origen: el objetivo; sus .Q hasta `o` (F5-04, como en Fase 5) y sus .M completas (el
#' puente usa todos los meses observados, F6-17).
.datos_modelo <- function(m, objetivo, series, o) {
  req <- setdiff(m$requiere, "objetivo")
  falta <- setdiff(req, names(series))
  if (length(falta)) stop(m$modelo_id, ": faltan las series ", paste(falta, collapse = ", "))
  c(list(objetivo = objetivo), stats::setNames(lapply(req, function(id) {
    d <- series[[id]]
    if (grepl("\\.M$", id)) d else d[q_a_ind(d$periodo) <= o, , drop = FALSE]
  }), req))
}

.tablas_trayectoria <- function(sendero, dens_bandas, dens_anual, objetivo, o, semilla, etiqueta) {
  tq <- tabla_trimestral(sendero, objetivo, o, dens_bandas)
  ta <- tabla_anual(sendero, objetivo, o, if (length(dens_anual)) bandas_anuales(dens_anual, objetivo, o, semilla) else NULL)
  verificar_agregacion(tq, ta, objetivo, o, etiqueta)                                       # F6-10.1
  list(trimestral = tq, anual = ta)
}

#' Corre un grupo (F6-01): ajusta sus modelos, proyecta cada corrida, aplica la regla y arma las tablas. `ins`:
#' list(objetivo, o, series, esc, sens, weo_slv); `sat`: las satélites ajustadas.
correr_grupo_fase6 <- function(grupo, ins, sat, rango, n_draw = N_DRAW_BVAR, n_burn = N_BURN_BVAR) {
  o <- ins$o; h <- DISENO_FASE6$h_max; exp_id <- exp_fase6(grupo); obj <- ins$objetivo
  reg <- modelos_fase6(grupo, n_draw, n_burn)
  ajustes <- list()
  for (m in c(reg$condicionables, reg$sin_escenario)) {
    set.seed(semilla_de(exp_id, m$modelo_id, o))                                            # F5-15
    aj <- m$ajustar(.datos_modelo(m, obj, ins$series, o), NULL)
    if (isTRUE(m$piso_gl)) guarda_gl(aj, m$modelo_id, o)                                    # G-8
    ajustes[[m$modelo_id]] <- aj
  }
  ext <- unique(unlist(lapply(reg$condicionables, predictoras_externas)))
  corridas <- corridas_fase6(ins$esc, ins$sens)
  filas <- list(trimestral = list(), anual = list(), guarda = list(), deflactor = list())
  senderos <- list()
  for (cr in names(corridas)) {
    proy <- proyectar_satelites(sat, ext, ins$series, corridas[[cr]], h)
    res <- list()
    for (m in reg$condicionables) {
      sx <- senderos_satelites(sat, proy, predictoras_externas(m))
      res[[m$modelo_id]] <- m$predecir_condicional(ajustes[[m$modelo_id]], h, sx)
      if (cr == "BASE" && all(c("BCR.REMESAS.NOM.NSA.Q", "BCR.REMESAS.REAL.NSA.Q") %in% colnames(sx$dlog))) {
        filas$deflactor[[m$modelo_id]] <- cbind(modelo_id = m$modelo_id, coherencia_deflactor(sx$dlog, ins$series[["BCR.REMESAS.NOM.NSA.Q"]],
                                                                                           ins$series[["BCR.REMESAS.REAL.NSA.Q"]], o))
      }
    }
    cg <- combinar_grupo(res, obj, o, rango, etiqueta = paste0(grupo, "/", cr))              # F6-08, F6-02, F6-07
    filas$guarda[[cr]] <- cbind(corrida = cr, cg$guarda)
    senderos[[cr]] <- c(list(COMBINACION = cg$sendero$log_nivel), lapply(res, `[[`, "sendero"))
    if (!corridas[[cr]]$principal) next
    dens <- lapply(res, `[`, c("media", "cov"))
    tr <- c(list(COMBINACION = .tablas_trayectoria(cg$sendero$log_nivel, cg$bandas, dens[cg$miembros], obj, o,
                                                    semilla_de(exp_id, paste0(ID_COMBINACION, "|", cr), o), paste0(grupo, "/", cr, "/", ID_COMBINACION))),
            stats::setNames(lapply(names(res), function(id) {
              .tablas_trayectoria(res[[id]]$sendero, cg$bandas_modelo[cg$bandas_modelo$modelo_id == id, -1L], dens[id], obj, o,
                                  semilla_de(exp_id, paste0(id, "|", cr), o), paste0(grupo, "/", cr, "/", id))
            }), names(res)))
    for (id in names(tr)) {
      pasa <- if (id == ID_COMBINACION) NA else cg$guarda$pasa[cg$guarda$modelo_id == id]
      filas$trimestral[[paste(cr, id)]] <- cbind(corrida = cr, modelo_id = id, pasa_guarda = pasa, tr[[id]]$trimestral)
      filas$anual[[paste(cr, id)]] <- cbind(corrida = cr, modelo_id = id, pasa_guarda = pasa, tr[[id]]$anual)
    }
  }
  # Trayectoria sin escenario (F6-01): aparte, con su densidad si la tiene.
  for (m in reg$sin_escenario) {
    t_ <- trayectoria_sin_escenario(m, ajustes[[m$modelo_id]], h)
    d <- if (is.null(t_$media)) list() else list(list(media = t_$media, cov = t_$cov))
    tr <- .tablas_trayectoria(t_$sendero, if (length(d)) bandas_mezcla(d, obj, o) else NULL, d, obj, o,
                              semilla_de(exp_id, paste0(m$modelo_id, "|SIN_ESCENARIO"), o), paste0(grupo, "/SIN_ESCENARIO/", m$modelo_id))
    filas$trimestral[[paste("SIN_ESCENARIO", m$modelo_id)]] <- cbind(corrida = "SIN_ESCENARIO", modelo_id = m$modelo_id, pasa_guarda = NA, tr$trimestral)
    filas$anual[[paste("SIN_ESCENARIO", m$modelo_id)]] <- cbind(corrida = "SIN_ESCENARIO", modelo_id = m$modelo_id, pasa_guarda = NA, tr$anual)
  }
  apilar <- function(l) { if (!length(l)) return(NULL); r <- do.call(rbind, l); rownames(r) <- NULL; r }
  trimestral <- .apilar_columnas(filas$trimestral); anual <- .apilar_columnas(filas$anual)
  sens <- tabla_sensibilidad(senderos$BASE, senderos[!vapply(corridas, `[[`, logical(1), "principal")], obj, o)   # F6-09
  base_comb <- anual[anual$corrida == "BASE" & anual$modelo_id == ID_COMBINACION, ]
  list(grupo = grupo, exp_id = exp_id, o = o,
       modelos = c(vapply(c(reg$condicionables, reg$sin_escenario), `[[`, character(1), "modelo_id")),
       trimestral = trimestral, anual = anual, guarda = apilar(filas$guarda), sensibilidad = sens,
       coherencia_signos = coherencia_signos(sens),                                                    # F6-10.2
       coherencia_weo = if (length(ins$weo_slv)) coherencia_weo(base_comb, ins$weo_slv) else NULL,
       coherencia_historica = coherencia_historica(base_comb, obj, o),
       coherencia_deflactor = apilar(filas$deflactor),
       diagnosticos = .diagnosticos_grupo(c(reg$condicionables, reg$sin_escenario), ajustes))
}

#' rbind de tablas con columnas distintas (los modelos sin densidad no traen bandas): rellena con NA.
.apilar_columnas <- function(l) {
  if (!length(l)) return(NULL)
  cols <- unique(unlist(lapply(l, names)))
  r <- do.call(rbind, lapply(l, function(d) { for (k in setdiff(cols, names(d))) d[[k]] <- NA; d[cols] }))
  rownames(r) <- NULL
  r
}

#' Diagnósticos de los ajustes (los de diagnosticar(), como en Fase 5).
.diagnosticos_grupo <- function(modelos, ajustes) {
  d <- lapply(modelos, function(m) if (is.function(m$diagnosticar)) {
    v <- m$diagnosticar(ajustes[[m$modelo_id]]); data.frame(modelo_id = m$modelo_id, clave = names(v), valor = unname(v), stringsAsFactors = FALSE)
  })
  do.call(rbind, d)
}

#' Tabla de las satélites ajustadas (órdenes, coeficientes y guardas, F6-15).
tabla_satelites <- function(sat) {
  do.call(rbind, lapply(names(sat), function(id) {
    s <- sat[[id]]
    data.frame(predictora = id, satelite_id = s$satelite_id, p = s$p, q = s$q, c0 = s$c0,
               gamma = paste(signif(s$gamma, 10), collapse = ";"), phi = paste(signif(s$phi, 10), collapse = ";"),
               beta = paste(signif(s$beta, 10), collapse = ";"), s2 = s$s2, n_est = s$n_est, raiz_min = s$raiz_min,
               stringsAsFactors = FALSE)
  }))
}

#' Núcleo de la corrida (sin I/O): satélites, sensibilidad y los grupos pedidos. `ins` como en correr_grupo_fase6()
#' más `z_hist` (historias de las variables de escenario) y sin `sens` (se arma aquí, F6-18-c).
correr_fase6_nucleo <- function(ins, rango, grupos = DISENO_FASE6$grupos, n_draw = N_DRAW_BVAR, n_burn = N_BURN_BVAR) {
  ids_sat <- unique(unlist(lapply(grupos, function(g) unlist(lapply(modelos_fase6(g, n_draw, n_burn)$condicionables, predictoras_externas)))))
  sat <- ajustar_satelites(ids_sat, ins$series, ins$z_hist, ins$o)
  ins$sens <- escenarios_sensibilidad(ins$esc[paste0(VARIABLES_SENSIBILIDAD, ".BASE")])
  sens_series <- do.call(rbind, lapply(names(ins$sens), function(cr) {
    v <- sub("\\.[A-Z]+$", "", cr); id <- paste0(VARIABLES_SENSIBILIDAD[[v]], ".BASE"); s <- ins$sens[[cr]][[id]]
    data.frame(corrida = cr, serie = id, s[s$tramo == "sendero", c("periodo", "valor")], stringsAsFactors = FALSE)
  }))
  list(satelites = tabla_satelites(sat), sd_sensibilidad = attr(ins$sens, "sd"), senderos_sensibilidad = sens_series,
       grupos = stats::setNames(lapply(grupos, correr_grupo_fase6, ins = ins, sat = sat, rango = rango, n_draw = n_draw, n_burn = n_burn), grupos))
}

# ---------------------------------------------------------------------------------------------
# Medición previa del BVAR (F6-13 d, ítem E2)
# ---------------------------------------------------------------------------------------------

#' Las dos cifras de F6-13 (d) de un BVAR ajustado con extracciones: proporción de extracciones con módulo máximo de
#' la compañera > 1 y > 1,05, y |media − mediana| de la predictiva del interanual del PIB en h = 8 y h = 20 (pp), sin
#' escenario. La predictiva es la mezcla con pesos iguales de las normales de cada extracción.
medicion_bvar <- function(aj, horizontes = c(8L, DISENO_FASE6$h_max)) {
  if (is.null(aj$beta)) stop(aj$modelo_id, ": el ajuste no guardó las extracciones")
  S <- dim(aj$beta)[1]; M <- dim(aj$beta)[3]; lags <- aj$lags; H <- max(horizontes); N <- nrow(aj$Y)
  x0 <- c(1, as.vector(t(aj$Y[N:(N - lags + 1L), , drop = FALSE])))
  raiz <- numeric(S); mu <- sdv <- matrix(NA_real_, S, length(horizontes))
  for (j in seq_len(S)) {
    B <- matrix(aj$beta[j, , ], ncol = M)
    A <- lapply(seq_len(lags), function(l) t(B[1L + (l - 1L) * M + seq_len(M), , drop = FALSE]))
    raiz[j] <- raiz_max_var(A)
    x <- x0; m_ <- numeric(H)
    for (t_ in seq_len(H)) { yn <- drop(x %*% B); m_[t_] <- yn[1]; x <- c(1, yn, if (lags > 1L) x[1L + seq_len(M * (lags - 1L))]) }
    C <- cov_sendero_var(pesos_ma_var(A, H), matrix(aj$sigma[j, , ], M), acumular = FALSE)
    mu[j, ] <- 100 * (m_[horizontes] - m_[horizontes - 4L])
    sdv[j, ] <- 100 * sqrt(pmax(C[cbind(horizontes, horizontes)] + C[cbind(horizontes - 4L, horizontes - 4L)] - 2 * C[cbind(horizontes, horizontes - 4L)], 0))
  }
  med <- mediana_mezcla_normal(mu, sdv)
  data.frame(modelo_id = aj$modelo_id, extracciones = S, prop_raiz_mayor_1 = mean(raiz > 1), prop_raiz_mayor_1_05 = mean(raiz > 1.05),
             h = horizontes, media_yoy_pp = colMeans(mu), mediana_yoy_pp = med, distancia_pp = abs(colMeans(mu) - med),
             stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------------------------
# I/O (main)
# ---------------------------------------------------------------------------------------------

#' Serie de L3 con G-6 sobre el corte; conserva `tramo` en las ESC.*.
.leer_l3_fase6 <- function(id, vintages, conjunto) {
  d <- .leer_capa("L3_master", archivo_l3(id))
  verificar_vintage_predictora(d, id, vintages, conjunto)                                    # G-6
  keep <- intersect(c("periodo", "valor", "tramo"), names(d))
  d[keep]
}

#' Insumos de la corrida desde la L3 del corte: objetivo, series de los modelos y de las satélites, historias y
#' senderos de escenario y la referencia del WEO. Devuelve list(ins, archivos, vintages_usados).
leer_insumos_fase6 <- function(vintages, conjunto) {
  objetivo <- leer_objetivo("PIB_SA_PROPIO_Q.csv", "revision_vigente", vintages, conjunto)     # G-6
  o <- origen_fase6(objetivo)
  master <- .leer_csv("catalogos", "05_series_master.csv")
  req <- unique(unlist(lapply(DISENO_FASE6$grupos, function(g) {
    r <- modelos_fase6(g); c(lapply(c(r$condicionables, r$sin_escenario), function(m) setdiff(m$requiere, "objetivo")),
                             lapply(r$condicionables, predictoras_externas))
  })))
  ids_q <- unique(c(req, "BCR.REMESAS.NOM.NSA.Q", "BCR.REMESAS.REAL.NSA.Q"))
  z_ids <- unique(VARIABLES_SATELITE$z_historia)
  esc_ids <- master$series_master_id[!is.na(master$rol) & master$rol == "escenario" & startsWith(master$series_master_id, "ESC.")]
  ref_ids <- master$series_master_id[!is.na(master$rol) & master$rol == "referencia"]
  if (!identical(ref_ids, "FMI.PIB_SLV_VAR.PCT.NSA.A")) stop("F6-10: se espera una sola referencia, FMI.PIB_SLV_VAR.PCT.NSA.A")
  leer <- function(ids) stats::setNames(lapply(ids, .leer_l3_fase6, vintages = vintages, conjunto = conjunto), ids)
  series <- lapply(leer(ids_q), function(d) d[c("periodo", "valor")])
  ref <- leer(ref_ids)[[1]]
  ins <- list(objetivo = objetivo[c("periodo", "y")], o = o, series = series,
              z_hist = lapply(leer(z_ids), function(d) d[c("periodo", "valor")]), esc = leer(esc_ids),
              weo_slv = stats::setNames(ref$valor, ref$periodo))
  archivos <- c(ruta_capa("L3_master", "PIB_SA_PROPIO_Q.csv"),
                vapply(c(ids_q, z_ids, esc_ids, ref_ids), function(id) ruta_capa("L3_master", archivo_l3(id)), character(1)))
  list(ins = ins, archivos = unname(archivos))
}

.escribir_csv_lf <- function(df, ruta) {
  con <- file(ruta, open = "wb"); on.exit(close(con))
  utils::write.csv(df, con, row.names = FALSE, na = "", eol = "\n")
  .sha256(ruta)
}

#' Escribe un directorio de L4 con sus tablas y su manifiesto (F4-31: insumos con sha256 sin CR; salidas con los
#' bytes tal cual).
escribir_l4_fase6 <- function(nombre, tablas, lineas, insumos_sha) {
  dir <- here::here("data", "L4_experiments", nombre)
  if (dir.exists(dir)) unlink(list.files(dir, full.names = TRUE))
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  sha <- vapply(names(tablas), function(nm) .escribir_csv_lf(tablas[[nm]], file.path(dir, paste0(nm, ".csv"))), character(1))
  lin <- c(lineas, "", "insumos (sha256 del contenido sin retornos de carro, F4-31):", paste0("  ", names(insumos_sha), "  ", insumos_sha),
           "salidas (sha256):", paste0("  ", names(tablas), ".csv  ", sha), "", "sessionInfo():", utils::capture.output(utils::sessionInfo()))
  con <- file(file.path(dir, "manifiesto.txt"), open = "wb"); on.exit(close(con))
  writeLines(enc2utf8(lin), con, sep = "\n", useBytes = TRUE)
  invisible(sha)
}

main <- function(args = character(0)) {
  modo <- if (length(args)) args[1] else "proyeccion"
  if (!modo %in% c("proyeccion", "medicion")) stop("correr_fase6: modo desconocido: ", modo, " (proyeccion | medicion)")
  conjunto <- exigir_conjunto(conjunto_activo())
  ident <- identidad_conjunto(Sys.getenv("SIE_CONJUNTO"))
  if (basename(ident$ruta) != CORTE_FASE6) stop("F6-04: Fase 6 corre sobre ", CORTE_FASE6, " y se pidió ", ident$ruta)
  commit <- leer_commit()
  vintages <- leer_vintages()
  li <- leer_insumos_fase6(vintages, conjunto)
  ins <- li$ins; o <- ins$o
  # C-5: L3 y L1 del corte dan el mismo ajuste estacional propio (el objetivo es el SA reestimado en el origen, §2).
  verificar_l1_contra_l3(ajustar_estacional_propio(concatenar_pib_nsa(.leer_capa("L1_staging", "BCR_PIB_series_largo.csv"))),
                         .leer_capa("L3_master", "PIB_SA_PROPIO_Q.csv"), .leer_capa("L3_master", "PIB_SA_PROPIO_Q_outliers.csv"))
  cabecera <- c(paste0("commit_hash: ", commit$sha), paste0("arbol: ", commit$arbol),
                paste0("conjunto: ", ident$ruta, "  sha256 sin CR ", ident$sha256, "  (capas leídas de ", ident$salida, "/)"),
                paste0("origen: ", ind_a_q(o)), paste0("fecha_corrida: ", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")))
  if (modo == "medicion") {                                                                    # F6-13 d (E2)
    med <- do.call(rbind, lapply(DISENO_FASE6$grupos, function(g) {
      m <- modelos_fase6(g)$condicionables; m <- m[[which(vapply(m, `[[`, character(1), "modelo_id") == paste0("MULT.BVAR.", g))]]
      set.seed(semilla_de(exp_fase6(g), m$modelo_id, o))
      medicion_bvar(m$ajustar(.datos_modelo(m, ins$objetivo, ins$series, o), NULL))
    }))
    print(med, row.names = FALSE)
    escribir_l4_fase6("F6_MEDICION_BVAR", list(medicion_bvar = med),
                      c("medicion: F6-13 (d), antes de proyectar; solo las dos cifras de la ficha, sin senderos ni bandas", cabecera,
                        "semillas: semilla_de(F6_<grupo>, MULT.BVAR.<grupo>, origen), las mismas de la corrida"),
                      stats::setNames(vapply(li$archivos, .sha256_lf, character(1)), ruta_relativa(li$archivos)))
    return(invisible(med))
  }
  if (!identical(commit$arbol, "limpio")) stop("F6-12: la corrida única de Fase 6 exige un árbol limpio (", commit$arbol, ")")
  prereg <- leer_preregistro_fase6()
  rango <- verificar_preregistro(prereg, ins$objetivo, o, ident$sha256)                      # F6-08 congelada
  res <- correr_fase6_nucleo(ins, rango)
  archivos <- c(normalizePath(Sys.getenv("SIE_CONJUNTO"), winslash = "/"), PREREGISTRO_FASE6, li$archivos,
                here::here("catalogos", c("03_series.csv", "05_series_master.csv", "08_vintages.csv")),
                here::here("catalogos", "06_modelos", paste0(unique(c(unlist(lapply(res$grupos, `[[`, "modelos")), SATELITES_FASE6)), ".yaml")))
  insumos_sha <- stats::setNames(vapply(unique(archivos), .sha256_lf, character(1)), ruta_relativa(unique(archivos)))
  comun <- c(cabecera, paste0("preregistro: ", ruta_relativa(PREREGISTRO_FASE6), "  (F6-12)"),
             sprintf("guarda: [%.6f, %.6f] pp del interanual (F6-08, congelada)", rango$inferior, rango$superior),
             "condicional: todas las cifras son condicionales a los supuestos de doc/metodologia/supuestos_escenarios.md (F6-11)")
  escribir_l4_fase6("F6_COMUN", list(satelites = res$satelites, senderos_sensibilidad = res$senderos_sensibilidad,
                                     sd_sensibilidad = data.frame(variable = names(res$sd_sensibilidad), sd_pp = unname(res$sd_sensibilidad))),
                    c("exp_id: F6_COMUN (satélites F6-15 y senderos de sensibilidad F6-18-c, comunes a los grupos)", comun), insumos_sha)
  filas <- list(); fecha <- Sys.Date(); entorno <- entorno_corrida()
  vids <- paste(sort(unique(unlist(strsplit(vintages$vintage_id[vintages$vintage_id %in% conjunto$vintage_id], " + ", fixed = TRUE)))), collapse = " + ")
  for (g in names(res$grupos)) {
    r <- res$grupos[[g]]
    tablas <- Filter(Negate(is.null), r[c("trimestral", "anual", "guarda", "sensibilidad", "coherencia_signos", "coherencia_weo",
                                          "coherencia_historica", "coherencia_deflactor", "diagnosticos")])
    escribir_l4_fase6(r$exp_id, tablas, c(paste0("exp_id: ", r$exp_id), comun,
                                          "semillas: por (exp_id, modelo_id, origen) con semilla_de(); bandas anuales por (exp_id, '<modelo>|<corrida>', origen)"), insumos_sha)
    ids <- c(r$modelos, ID_COMBINACION)
    filas[[g]] <- data.frame(exp_id = paste0(r$exp_id, "__", ids), modelo_id = ids, vintage_id = vids,
                             muestra_inicio = ins$objetivo$periodo[1], muestra_fin = ind_a_q(o),
                             esquema_validacion = sprintf("proyeccion_condicional|origen=%s|grupo=%s|conjunto=%s|corridas=%s", ind_a_q(o), g,
                                                          ident$etiqueta, paste(c(DISENO_FASE6$escenarios, "SENSIBILIDAD_6"), collapse = "+")),
                             horizontes = paste(seq_len(DISENO_FASE6$h_max), collapse = ","),
                             semilla = vapply(ids, function(id) semilla_de(r$exp_id, id, o), numeric(1)),
                             commit_hash = commit$sha, fecha_corrida = format(fecha), entorno = entorno,
                             ruta_resultados = paste0("data/L4_experiments/", r$exp_id, "/"), stringsAsFactors = FALSE)
    cat(sprintf("OK %s  %d filas trimestrales, %d anuales, %d exclusiones de la guarda\n", r$exp_id, nrow(r$trimestral), nrow(r$anual), sum(!r$guarda$pasa)))
  }
  n <- registrar_experimentos(filas)                                                           # F4-25
  cat(sprintf("07_experimentos.csv: %d filas de Fase 6\n", n))
  invisible(res)
}

if (sys.nframe() == 0L) main(commandArgs(trailingOnly = TRUE))
