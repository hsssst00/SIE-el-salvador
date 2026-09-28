# src/evaluacion/motor_backtesting.R
#
# Orquestador del motor de evaluación de Fase 4 sobre los datos del proyecto
# (doc/metodologia/especificacion_motor_evaluacion.md §1, §3 y §4). Es la capa de lectura y
# escritura: el bucle de orígenes, sus guardas, las métricas y las pruebas viven en eval_lib.R
# (puras, ejercitadas en CI por tests/ y por verificar_motor_sintetico.R); los modelos, en
# modelos_referencia.R, declarados antes de la primera corrida en catalogos/06_modelos/.
#
# Uso:  Rscript src/evaluacion/motor_backtesting.R              corre todos los experimentos declarados
#       Rscript src/evaluacion/motor_backtesting.R F4_BENCH_G1  corre solo los exp_id indicados
#
# Lee:
#   data/L3_master/PIB_SA_PROPIO_Q.csv           observado del objetivo primario (F4-20) y R6
#   data/L3_master/PIB_SA_PROPIO_Q_outliers.csv  AO declarados (ADR-004) para el ajuste por origen
#   data/L3_master/PIB_SA_OFICIAL_Q.csv          objetivo de R5 (F4-22)
#   data/L1_staging/BCR_PIB_series_largo.csv     NSA para reestimar X-13 en cada origen: la serie
#                                                concatenada (T001) no se materializa en L3, así que
#                                                se reconstruye con concatenar_pib_nsa() (F4-19)
#   catalogos/03_series.csv, 08_vintages.csv     vintage vigente (G-6, F4-03)
#   catalogos/06_modelos/<modelo_id>.yaml        registro previo de cada modelo (C8)
#
# Escribe data/L4_experiments/<exp_id>/ (no versionado, senda §7):
#   pronosticos.csv, metricas.csv, pruebas.csv, mcs.csv, ajuste_estacional.csv (solo con
#   sa=reestimado_en_origen: orden ARIMA por origen, F4-09b; en R2, del tramo [2005-Q1, o]) y manifiesto.txt con commit, semillas,
#   sha256 de insumos y salidas, y sessionInfo().
#
# Con R3/R4 agrega metricas_submuestras.csv, pruebas_submuestras.csv, mcs_submuestras.csv (columna
# muestra_eval) y, con R3, estabilidad.csv, sin tocar las tablas de la muestra completa.
#
# Al final registra en catalogos/07_experimentos.csv una fila por (experimento, modelo), con exp_id
# `<exp_id>__<modelo_id>`, reemplazando las filas previas de los exp_id que corrió (F4-25).
#
# Decisiones que implementa: F4-01 (orígenes), F4-03 (datos revisados, G-6), F4-04 (pérdida yoy en
# pp), F4-05 (grupos), F4-07 (denominador), F4-09/F4-09b (X-13 por origen), F4-15 a F4-18 (pruebas),
# F4-19 (NSA desde L1), F4-20 (observado de L3, bases del origen), F4-21 (marca de tamaño), F4-22
# (R5 solo en G2 y G3, serie oficial tal cual) y F4-25 a F4-29 (registro 07 y robustez R1 a R4). Regla 7 de CLAUDE.md: toda guarda falla con stop().

source(here::here("src", "evaluacion", "eval_lib.R"))
source(here::here("src", "evaluacion", "modelos_referencia.R"))
source(here::here("src", "transformacion", "l3_pib_objetivo_reglas.R"))   # concatenar_pib_nsa(), T001
source(here::here("src", "transformacion", "vintage_lib.R"))

# ---------------------------------------------------------------------------------------------
# Experimentos declarados
# ---------------------------------------------------------------------------------------------
# Principal: los tres grupos con el ajuste reestimado por origen (F4-09b). Robustez del protocolo §5:
#   R1  ventana rodante de 92 trimestres; X-13 sobre [1990-Q1, o] como en la principal (F4-26)
#   R2  tramo homogéneo: X-13 y estimación solo sobre la NSA nativa [2005-Q1, o], orígenes de G2/G3 (F4-27)
#   R3  submuestras de targets pre/post 2020 con contraste de estabilidad, sobre la principal (F4-28)
#   R4  métricas sin los targets de 2020, y además sin 2020 ni 2021, sobre la principal (F4-29)
#   R5  objetivo oficial, solo G2 y G3, serie tal cual (F4-22)
#   R6  ajuste único de L3 en vez del reestimado por origen
# R3 y R4 no corren modelos: reevalúan los errores de la principal y escriben *_submuestras.csv en su
# directorio. R3 no aplica a G3: su primer target es 2020-Q1 y no tiene submuestra previa.

.exp <- function(exp_id, grupo, objetivo = "PIB_SA_PROPIO_Q", sa = "reestimado_en_origen", ventana = "expansiva",
                 r3 = FALSE, r4 = FALSE) {
  data.frame(exp_id = exp_id, grupo = grupo, objetivo = objetivo, sa = sa, ventana = ventana,
             vintage = "revision_vigente", perdida = "yoy_pp", r3 = r3, r4 = r4, stringsAsFactors = FALSE)
}
EXPERIMENTOS <- rbind(
  .exp("F4_BENCH_G1", "G1", r3 = TRUE, r4 = TRUE),
  .exp("F4_BENCH_G2", "G2", r3 = TRUE, r4 = TRUE),
  .exp("F4_BENCH_G3", "G3", r4 = TRUE),
  .exp("F4_BENCH_G2_R5", "G2", objetivo = "PIB_SA_OFICIAL_Q", sa = "l3_unico"),
  .exp("F4_BENCH_G3_R5", "G3", objetivo = "PIB_SA_OFICIAL_Q", sa = "l3_unico"),
  .exp("F4_BENCH_G1_R1", "G1", ventana = "rodante92"),
  .exp("F4_BENCH_G2_R1", "G2", ventana = "rodante92"),
  .exp("F4_BENCH_G3_R1", "G3", ventana = "rodante92"),
  .exp("F4_BENCH_G2_R2", "G2", ventana = "homogenea2005"),
  .exp("F4_BENCH_G3_R2", "G3", ventana = "homogenea2005"),
  .exp("F4_BENCH_G1_R6", "G1", sa = "l3_unico"),
  .exp("F4_BENCH_G2_R6", "G2", sa = "l3_unico"),
  .exp("F4_BENCH_G3_R6", "G3", sa = "l3_unico")
)

MIN_OBS    <- 40L                    # G-4, mínimo de observaciones del objetivo (F4-05)
ALPHA_MCS  <- 0.10                   # F4-15
B_MCS      <- 5000L                  # F4-15
BENCHMARK  <- "BENCH.RW_SIN_DERIVA"  # F4-07
UNIDADES   <- c("yoy_pp", "qoq_pp", "log_nivel")
MARCA_TAMANO <- "distorsion_tamano_documentada"   # F4-18 / F4-21, en h = 4, 8
VENTANA_RODANTE <- 92L                # F4-10
INICIO_HOMOGENEO <- "2005-Q1"         # ADR-003, F4-27

# ---------------------------------------------------------------------------------------------
# Lectura
# ---------------------------------------------------------------------------------------------

.leer_csv <- function(...) {
  ruta <- here::here(...)
  if (!file.exists(ruta)) stop("motor: no existe ", ruta)
  read.csv(ruta, stringsAsFactors = FALSE, na.strings = "")
}

#' Registro previo (C8): cada modelo que se corre tiene su YAML, con modelo_id igual al del código.
verificar_registro_modelos <- function(modelos) {
  for (m in modelos) {
    ruta <- here::here("catalogos", "06_modelos", paste0(m$modelo_id, ".yaml"))
    if (!file.exists(ruta)) stop("C8: el modelo ", m$modelo_id, " no está declarado en catalogos/06_modelos/")
    y <- yaml::read_yaml(ruta)
    if (!identical(y$modelo_id, m$modelo_id)) stop("C8: ", basename(ruta), " declara modelo_id = ", y$modelo_id)
  }
  invisible(TRUE)
}

#' vintage_id vigente de cada publicación que aparece en una serie de L3.
vigentes_de <- function(d, vintages) {
  pubs <- unique(vintages$publicacion_id[vintages$vintage_id %in% unique(d$vintage_id)])
  if (!length(pubs)) stop("G-6: ningún vintage_id de la serie está en 08_vintages.csv")
  vapply(pubs, vintage_vigente, character(1), vintages = vintages)
}

#' Objetivo observado (log-nivel) del vintage vigente, con su vintage_id por período.
leer_objetivo <- function(archivo, politica, vintages) {
  d <- .leer_csv("data", "L3_master", archivo)
  d <- filtrar_vintage(d, politica, vigentes_de(d, vintages))                    # G-6
  if (anyNA(d$valor) || any(d$valor <= 0)) stop("motor: ", archivo, " trae valores ausentes o no positivos")
  i <- q_a_ind(d$periodo)
  if (!identical(i, seq.int(i[1], length.out = length(i)))) stop("motor: ", archivo, " tiene huecos o desorden")
  data.frame(periodo = d$periodo, y = log(d$valor), vintage_id = d$vintage_id, stringsAsFactors = FALSE)
}

#' NSA concatenada (T001) desde L1, con el vintage de cada fila, que debe coincidir con el del
#' observado en L3: si L1 y L3 vienen de vintages distintos el ajuste por origen no es comparable.
leer_nsa_concat <- function(vintages, objetivo_l3) {
  l1 <- .leer_csv("data", "L1_staging", "BCR_PIB_series_largo.csv")
  cc <- concatenar_pib_nsa(l1)
  series <- .leer_csv("catalogos", "03_series.csv")
  pub <- vapply(fuente_pib_nsa_por_periodo(l1, cc$periodo), resolver_publicacion, character(1), catalogo_series = series)
  cc$vintage_id <- vapply(pub, vintage_vigente, character(1), vintages = vintages, USE.NAMES = FALSE)
  m <- merge(cc[, c("periodo", "vintage_id")], objetivo_l3[, c("periodo", "vintage_id")], by = "periodo", all = TRUE)
  if (anyNA(m) || any(m$vintage_id.x != m$vintage_id.y)) stop("G-6: la NSA de L1 y PIB_SA_PROPIO_Q de L3 no son del mismo vintage período a período")
  cc[order(q_a_ind(cc$periodo)), ]
}

# ---------------------------------------------------------------------------------------------
# Ajuste estacional por origen (F4-09b)
# ---------------------------------------------------------------------------------------------

#' X-13 sobre la NSA recortada al origen `o`. Devuelve el SA del origen y el registro del ajuste.
ajustar_en_origen <- function(nsa, outliers, o) {
  x <- recortar_a_origen(nsa, o)
  guarda_recorte(x, o, nombre = "NSA concatenada")                             # G-1 sobre el insumo de X-13
  if (q_a_ind(x$periodo[nrow(x)]) != o) stop("ajuste por origen: la NSA no llega al origen ", ind_a_q(o))
  args <- args_x13_origen(outliers, o)                                         # G-5 adentro
  i0 <- q_a_ind(x$periodo[1])
  serie <- stats::ts(x$valor, start = c(i0 %/% 4L, i0 %% 4L + 1L), frequency = 4)
  mod <- do.call(seasonal::seas, c(list(x = serie), args))
  sa <- as.numeric(seasonal::final(mod))
  if (length(sa) != nrow(x) || anyNA(sa) || any(sa <= 0)) stop("ajuste por origen ", ind_a_q(o), ": X-13 devolvió NA o una longitud distinta")
  tipo <- as.character(seasonal::outlier(mod))
  per_out <- x$periodo[!is.na(tipo)]
  ao <- ao_declarados_origen(outliers, o)
  verificar_ajuste_origen(seasonal::transformfunction(mod), per_out, ao, o)
  list(sa = data.frame(periodo = x$periodo, y = log(sa), stringsAsFactors = FALSE),
       registro = data.frame(origen = ind_a_q(o), n_obs = nrow(x),
                             arima = gsub("[[:space:]]+", " ", trimws(mod$model$arima$model)),
                             transform = seasonal::transformfunction(mod),
                             regresores = paste(mod$model$regression$variables, collapse = " "),
                             ao_declarados = paste(ao, collapse = " "), stringsAsFactors = FALSE))
}

# ---------------------------------------------------------------------------------------------
# Un experimento
# ---------------------------------------------------------------------------------------------

#' Serie del objetivo tal como la ve el origen `o` para un experimento: el SA del origen (reestimado o
#' de L3) y, si corresponde, el registro del ajuste. `cache_sa` guarda los ajustes por (tramo, origen):
#' la principal, R1 y R3/R4 comparten el de [1990-Q1, o]; R2 usa el de [2005-Q1, o].
serie_en_origen <- function(ex, o, insumos, cache_sa) {
  obs <- insumos$objetivos[[ex$objetivo]]
  if (ex$sa == "l3_unico") {
    sa <- obs[q_a_ind(obs$periodo) <= o, c("periodo", "y")]
    if (ex$ventana == "homogenea2005") sa <- sa[q_a_ind(sa$periodo) >= q_a_ind(INICIO_HOMOGENEO), ]
    return(list(sa = sa, registro = NULL, bases = FALSE))
  }
  if (ex$objetivo != "PIB_SA_PROPIO_Q") stop("motor: el ajuste por origen solo está definido para PIB_SA_PROPIO_Q")
  tramo <- if (ex$ventana == "homogenea2005") INICIO_HOMOGENEO else "1990-Q1"
  clave <- paste(tramo, o)
  if (is.null(cache_sa[[clave]])) {
    nsa <- insumos$nsa[q_a_ind(insumos$nsa$periodo) >= q_a_ind(tramo), ]
    cache_sa[[clave]] <- ajustar_en_origen(nsa, insumos$outliers, o)
  }
  a <- cache_sa[[clave]]
  list(sa = a$sa, registro = a$registro, bases = TRUE)
}

#' Corre un experimento y devuelve sus tablas.
correr_experimento <- function(ex, insumos, cache_sa) {
  token <- construir_token(ex$ventana, ex$grupo, ex$vintage, ex$sa, ex$perdida)
  if (ex$objetivo == "PIB_SA_OFICIAL_Q" && (ex$sa != "l3_unico" || ex$grupo == "G1")) stop("F4-22: R5 corre solo en G2/G3 y con la serie oficial tal cual")
  if (ex$ventana == "homogenea2005" && ex$grupo == "G1") stop("F4-27: R2 corre solo con los orígenes de G2 y G3")
  obs <- insumos$objetivos[[ex$objetivo]]
  origenes <- origenes_grupo(ex$grupo)
  modelos <- modelos_referencia()
  ids <- vapply(modelos, `[[`, character(1), "modelo_id")

  partes <- lapply(origenes, function(o) {
    so <- serie_en_origen(ex, o, insumos, cache_sa)
    estim <- if (ex$ventana == "rodante92") recortar_ventana_rodante(so$sa, VENTANA_RODANTE) else so$sa   # F4-26
    pr <- correr_backtest(list(objetivo = estim), modelos, o, min_obs = MIN_OBS, exp_id = ex$exp_id)
    base <- if (so$bases) data.frame(origen = o, periodo = so$sa$periodo, y = so$sa$y, stringsAsFactors = FALSE) else NULL
    list(pron = pr, base = base, reg = so$registro, n_estim = nrow(estim), inicio = estim$periodo[1])
  })
  pron  <- do.call(rbind, lapply(partes, `[[`, "pron"))
  bases <- do.call(rbind, lapply(partes, `[[`, "base"))                  # NULL si ningún origen trae bases
  ajuste <- NULL
  regs <- lapply(partes, `[[`, "reg")
  if (!all(vapply(regs, is.null, logical(1)))) ajuste <- cbind(exp_id = ex$exp_id, do.call(rbind, regs), stringsAsFactors = FALSE)

  err <- calcular_errores(pron, obs[, c("periodo", "y")], bases = bases)
  err <- err[order(err$unidad, err$modelo_id, err$h, err$origen), ]

  # Tablas de la muestra completa, con el conteo de pares del grupo como guarda (F4-01, F4-05).
  tab <- evaluar_errores(err, ids, ex$exp_id, ex$grupo, ex$perdida,
                         semilla_mcs = function(h) semilla_de(ex$exp_id, "MCS", h), benchmark = BENCHMARK,
                         gw = ex$ventana == "rodante92", alpha = ALPHA_MCS, B = B_MCS, marca_h_largo = MARCA_TAMANO)
  esperado <- conteo_por_horizonte(pares_evaluables(origenes, DISENO_FASE4$horizontes, obs$periodo[nrow(obs)]))
  n_obs_h <- tapply(tab$metricas$n_pares, tab$metricas$h, unique)
  if (!identical(as.integer(unlist(n_obs_h)), unname(esperado))) stop("motor: pares por horizonte distintos del diseño del grupo ", ex$grupo)

  # R3 y R4 (F4-28, F4-29): reevaluación de los mismos errores en submuestras de targets.
  sub <- NULL; estab <- NULL
  subs <- c(if (isTRUE(ex$r3)) c("pre2020", "post2020"), if (isTRUE(ex$r4)) c("sin_2020", "sin_2020_2021"))
  if (length(subs)) {
    tabs <- lapply(subs, function(nm) {
      keep <- SUBMUESTRAS_FASE4[[nm]](err$origen + err$h)
      t_ <- evaluar_errores(err[keep, ], ids, ex$exp_id, ex$grupo, ex$perdida,
                            semilla_mcs = function(h) semilla_de(ex$exp_id, paste0("MCS|", nm), h), benchmark = BENCHMARK,
                            alpha = ALPHA_MCS, B = B_MCS, marca_h_largo = MARCA_TAMANO)
      lapply(t_, function(x) cbind(muestra_eval = nm, x, stringsAsFactors = FALSE))
    })
    sub <- list(metricas = do.call(rbind, lapply(tabs, `[[`, "metricas")),
                pruebas  = do.call(rbind, lapply(tabs, `[[`, "pruebas")),
                mcs      = do.call(rbind, lapply(tabs, `[[`, "mcs")))
  }
  if (isTRUE(ex$r3)) {
    prim <- err[err$unidad == ex$perdida, ]
    estab <- do.call(rbind, lapply(DISENO_FASE4$horizontes, function(h) {
      eb <- prim[prim$h == h & prim$modelo_id == BENCHMARK, ]; eb <- eb[order(eb$origen), ]
      post <- as.integer(SUBMUESTRAS_FASE4$post2020(eb$origen + eb$h))
      do.call(rbind, lapply(setdiff(ids, BENCHMARK), function(id) {
        em <- prim[prim$h == h & prim$modelo_id == id, ]; em <- em[order(em$origen), ]
        if (!identical(em$origen, eb$origen)) stop("motor: orígenes desalineados en el contraste de estabilidad")
        r <- prueba_cambio_diferencial(eb$error, em$error, post, h)
        data.frame(exp_id = ex$exp_id, grupo = ex$grupo, h = h, unidad = ex$perdida, modelo_a = BENCHMARK, modelo_b = id,
                   media_pre = r$media_pre, cambio_post = r$cambio_post, ee_hac = r$ee_hac, estadistico = r$estadistico,
                   p_valor = r$p_valor, n_pre = r$n_pre, n_post = r$n_post,
                   marca_tamano = "tamano_no_verificado", stringsAsFactors = FALSE)
      }))
    }))
  }

  # Pronósticos con sus unidades derivadas y el vintage del observado en el target.
  pu <- derivar_unidades(pron, obs[, c("periodo", "y")], bases)
  vint <- stats::setNames(obs$vintage_id, q_a_ind(obs$periodo))
  pron_out <- data.frame(exp_id = ex$exp_id, modelo_id = pu$modelo_id, grupo = ex$grupo, origen = ind_a_q(pu$origen),
                         h = pu$h, periodo_objetivo = ind_a_q(pu$origen + pu$h),
                         log_nivel_pronosticado = pu$log_nivel_pronosticado, yoy_pp_pronosticado = pu$yoy_pp_pronosticado,
                         qoq_pp_pronosticado = pu$qoq_pp_pronosticado,
                         vintage_id_objetivo = unname(vint[as.character(pu$origen + pu$h)]), stringsAsFactors = FALSE)

  semillas <- vapply(ids, function(id) semilla_de(ex$exp_id, id, origenes[1]), numeric(1))
  list(token = token, pronosticos = pron_out, metricas = tab$metricas, pruebas = tab$pruebas, mcs = tab$mcs,
       ajuste_estacional = ajuste, sub = sub, estabilidad = estab, ids = ids, semillas = semillas,
       muestra_inicio = partes[[1]]$inicio, muestra_fin = obs$periodo[nrow(obs)],
       vintages = unique(obs$vintage_id[q_a_ind(obs$periodo) >= q_a_ind(partes[[1]]$inicio)]))
}

# ---------------------------------------------------------------------------------------------
# Escritura y manifiesto
# ---------------------------------------------------------------------------------------------

#' Commit del árbol que corre. Con git disponible, `git rev-parse HEAD` y el estado del árbol; sin
#' git, lectura directa de .git/HEAD (el árbol queda como no verificado). Sin ninguna de las dos, falla:
#' un manifiesto sin commit no hace auditable la corrida.
leer_commit <- function() {
  raiz <- here::here()
  sha <- tryCatch(suppressWarnings(system2("git", c("-C", shQuote(raiz), "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)),
                  error = function(e) character(0))
  if (length(sha) == 1L && grepl("^[0-9a-f]{40}$", sha)) {
    st <- suppressWarnings(system2("git", c("-C", shQuote(raiz), "status", "--porcelain"), stdout = TRUE, stderr = FALSE))
    return(list(sha = sha, arbol = if (length(st)) sprintf("con cambios sin commitear (%d entradas en git status)", length(st)) else "limpio"))
  }
  head <- file.path(raiz, ".git", "HEAD")
  if (!file.exists(head)) stop("motor: no se pudo determinar el commit (sin git y sin .git/HEAD)")
  h <- trimws(readLines(head, warn = FALSE)[1])
  if (grepl("^[0-9a-f]{40}$", h)) return(list(sha = h, arbol = "no verificado (git no disponible)"))
  ref <- sub("^ref: ", "", h)
  f <- file.path(raiz, ".git", ref)
  if (file.exists(f)) return(list(sha = trimws(readLines(f, warn = FALSE)[1]), arbol = "no verificado (git no disponible)"))
  pk <- file.path(raiz, ".git", "packed-refs")
  if (file.exists(pk)) {
    l <- grep(paste0(" ", ref, "$"), readLines(pk, warn = FALSE), value = TRUE)
    if (length(l) == 1L) return(list(sha = sub(" .*$", "", l), arbol = "no verificado (git no disponible)"))
  }
  stop("motor: no se pudo resolver ", ref, " en .git")
}

.sha256 <- function(ruta) digest::digest(file = ruta, algo = "sha256")
.sha256_lf <- function(ruta) {
  b <- readBin(ruta, "raw", n = file.info(ruta)$size)
  digest::digest(b[b != as.raw(13L)], algo = "sha256", serialize = FALSE)
}

escribir_experimento <- function(ex, res, commit, insumos_sha) {
  dir <- here::here("data", "L4_experiments", ex$exp_id)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  tablas <- list(pronosticos = res$pronosticos, metricas = res$metricas, pruebas = res$pruebas, mcs = res$mcs)
  if (!is.null(res$ajuste_estacional)) tablas$ajuste_estacional <- res$ajuste_estacional
  if (!is.null(res$sub)) {
    tablas$metricas_submuestras <- res$sub$metricas
    tablas$pruebas_submuestras  <- res$sub$pruebas
    tablas$mcs_submuestras      <- res$sub$mcs
  }
  if (!is.null(res$estabilidad)) tablas$estabilidad <- res$estabilidad
  opcionales <- c("ajuste_estacional", "metricas_submuestras", "pruebas_submuestras", "mcs_submuestras", "estabilidad")
  for (nm in setdiff(opcionales, names(tablas))) {                               # sin restos de corridas previas
    viejo <- file.path(dir, paste0(nm, ".csv"))
    if (file.exists(viejo)) file.remove(viejo)
  }
  sha <- character(0)
  for (nm in names(tablas)) {
    ruta <- file.path(dir, paste0(nm, ".csv"))
    con <- file(ruta, open = "wb")                                               # LF en todas las plataformas
    utils::write.csv(tablas[[nm]], con, row.names = FALSE, na = "", eol = "\n")
    close(con)
    sha[[paste0(nm, ".csv")]] <- .sha256(ruta)
  }
  lin <- c(
    paste0("exp_id: ", ex$exp_id),
    paste0("esquema_validacion: ", res$token),
    paste0("objetivo: ", ex$objetivo),
    paste0("commit_hash: ", commit$sha),
    paste0("arbol: ", commit$arbol),
    paste0("fecha_corrida: ", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
    "semillas: por (exp_id, modelo_id, origen) con semilla_de() de eval_lib.R (xxhash32); MCS por (exp_id, 'MCS', h), listada en mcs.csv",
    paste0("mcs: T_max, alpha = ", ALPHA_MCS, ", B = ", B_MCS, ", bootstrap estacionario circular, bloque max(h, ceiling(n^(1/3))) (F4-15)"),
    "calibracion: sin densidad bajo el contrato vigente (predecir() devuelve el sendero puntual); cobertura_80, cobertura_95 y crps quedan vacías (protocolo §3.4)",
    "datos: revisados, no en tiempo real (F4-03)",
    if (ex$sa == "l3_unico" && ex$objetivo == "PIB_SA_OFICIAL_Q") "limite: serie SA oficial del BCR tal cual; hereda la filtración de su ajuste bilateral (F4-22)" else NULL,
    if (ex$sa == "l3_unico" && ex$objetivo == "PIB_SA_PROPIO_Q") "sa: ajuste único de L3 (R6); hereda la filtración del ajuste sobre la muestra completa" else NULL,
    if (ex$ventana == "rodante92") paste0("ventana: rodante de ", VENTANA_RODANTE, " trimestres para estimar; X-13 sobre [1990-Q1, o] (F4-26); GW con varianza Bartlett h-1, marca tamano_no_verificado") else NULL,
    if (ex$ventana == "homogenea2005") paste0("ventana: X-13 y estimación sobre la NSA nativa [", INICIO_HOMOGENEO, ", o]; bases del ajuste propio (F4-27)") else NULL,
    if (!is.null(res$sub)) paste0("submuestras: ", paste(unique(res$sub$metricas$muestra_eval), collapse = ", "),
                                  " sobre los mismos errores; semilla MCS por (exp_id, 'MCS|<muestra>', h) (F4-28, F4-29)") else NULL,
    if (!is.null(res$sub) && any(grepl("^sin_", res$sub$metricas$muestra_eval))) "submuestras: en sin_2020 y sin_2020_2021 DM/HLN y MCS corren sobre pares no consecutivos concatenados (aproximación declarada)" else NULL,
    if (!is.null(res$estabilidad)) "estabilidad: MCO de d_t sobre (1, D_post), D_post = 1{target >= 2020-Q1}, HAC Bartlett h-1, t con n-2 gl (F4-28)" else NULL,
    paste0("semilla_registro: la del primer origen del grupo (", ind_a_q(origenes_grupo(ex$grupo)[1]), ") para cada modelo (F4-25)"),
    "",
    "insumos (sha256):", paste0("  ", names(insumos_sha), "  ", insumos_sha),
    "salidas (sha256):", paste0("  ", names(sha), "  ", sha),
    "", "sessionInfo():", utils::capture.output(utils::sessionInfo())
  )
  con <- file(file.path(dir, "manifiesto.txt"), open = "wb")
  writeLines(enc2utf8(lin), con, sep = "\n", useBytes = TRUE)
  close(con)
  invisible(sha)
}

#' CSV con comillas solo donde hacen falta, como los catálogos editados a mano, y LF.
.escribir_csv_catalogo <- function(df, ruta) {
  esc <- function(x) {
    x <- ifelse(is.na(x), "", as.character(x))
    ifelse(grepl('[",\n]', x), paste0('"', gsub('"', '""', x, fixed = TRUE), '"'), x)
  }
  lin <- c(paste(names(df), collapse = ","), if (nrow(df)) do.call(paste, c(lapply(df, esc), sep = ",")))
  con <- file(ruta, open = "wb")
  writeLines(enc2utf8(lin), con, sep = "\n", useBytes = TRUE)
  close(con)
}

#' Entorno de la corrida para 07 (sin comas): versión de R, plataforma y sha256 de renv.lock. El
#' hash se toma sin retornos de carro: así identifica el renv.lock versionado (LF) y no depende de
#' cómo la copia de trabajo convierta los fines de línea (en Windows suele quedar en CRLF).
entorno_corrida <- function() {
  lock <- here::here("renv.lock")
  s <- if (file.exists(lock)) substr(.sha256_lf(lock), 1, 12) else "sin_renv_lock"
  paste0(R.version$version.string, "; ", R.version$platform, "; renv.lock sha256:", s)
}

#' Filas de 07 de los experimentos corridos, reemplazando las previas de esos exp_id (F4-25).
registrar_experimentos <- function(filas) {
  ruta <- here::here("catalogos", "07_experimentos.csv")
  existente <- utils::read.csv(ruta, colClasses = "character", check.names = FALSE, na.strings = character(0))
  nuevas <- do.call(rbind, filas)
  nuevas[] <- lapply(nuevas, as.character)
  .escribir_csv_catalogo(actualizar_registro_experimentos(existente, nuevas), ruta)
  invisible(nrow(nuevas))
}

# ---------------------------------------------------------------------------------------------
# Principal
# ---------------------------------------------------------------------------------------------

main <- function(exp_ids = character(0)) {
  sel <- if (length(exp_ids)) EXPERIMENTOS[EXPERIMENTOS$exp_id %in% exp_ids, ] else EXPERIMENTOS
  if (length(exp_ids) && nrow(sel) != length(unique(exp_ids))) stop("motor: exp_id no declarado: ", paste(setdiff(exp_ids, EXPERIMENTOS$exp_id), collapse = ", "))
  verificar_registro_modelos(modelos_referencia())                              # C8
  commit <- leer_commit()
  vintages <- leer_vintages()
  pol <- unique(sel$vintage)
  if (length(pol) != 1L) stop("motor: una corrida usa una sola política de vintage")
  objetivos <- list()
  for (ob in unique(sel$objetivo)) objetivos[[ob]] <- leer_objetivo(paste0(ob, ".csv"), pol, vintages)
  necesita_sa <- any(sel$sa == "reestimado_en_origen")
  insumos <- list(objetivos = objetivos)
  archivos <- c(file.path("data", "L3_master", paste0(unique(sel$objetivo), ".csv")),
                file.path("catalogos", c("03_series.csv", "08_vintages.csv")))
  if (necesita_sa) {
    prop <- if (!is.null(objetivos$PIB_SA_PROPIO_Q)) objetivos$PIB_SA_PROPIO_Q else leer_objetivo("PIB_SA_PROPIO_Q.csv", pol, vintages)
    insumos$nsa <- leer_nsa_concat(vintages, prop)
    insumos$outliers <- .leer_csv("data", "L3_master", "PIB_SA_PROPIO_Q_outliers.csv")
    archivos <- c(archivos, file.path("data", "L1_staging", "BCR_PIB_series_largo.csv"),
                  file.path("data", "L3_master", "PIB_SA_PROPIO_Q_outliers.csv"))
  }
  archivos <- c(archivos, file.path("catalogos", "06_modelos", paste0(vapply(modelos_referencia(), `[[`, character(1), "modelo_id"), ".yaml")))
  insumos_sha <- vapply(unique(archivos), function(a) .sha256(here::here(a)), character(1))
  cache_sa <- new.env()
  filas <- list()
  fecha <- Sys.Date()
  entorno <- entorno_corrida()
  for (k in seq_len(nrow(sel))) {
    ex <- sel[k, ]
    t0 <- Sys.time()
    res <- correr_experimento(ex, insumos, cache_sa)
    escribir_experimento(ex, res, commit, insumos_sha)
    filas[[ex$exp_id]] <- construir_filas_experimento(ex$exp_id, res$ids, res$vintages, res$muestra_inicio, res$muestra_fin,
                                                      res$token, res$semillas, commit$sha, fecha, entorno)
    cat(sprintf("OK %-16s %s  %d pronósticos  %.0f s\n", ex$exp_id, res$token, nrow(res$pronosticos),
                as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  }
  n <- registrar_experimentos(filas)                                            # F4-25, después de todas las salidas
  cat(sprintf("07_experimentos.csv: %d filas de %d experimentos\n", n, length(filas)))
  invisible(TRUE)
}

if (sys.nframe() == 0L) main(commandArgs(trailingOnly = TRUE))
