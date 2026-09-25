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
#   sa=reestimado_en_origen: orden ARIMA por origen, F4-09b) y manifiesto.txt con commit, semillas,
#   sha256 de insumos y salidas, y sessionInfo().
#
# No escribe la fila de catalogos/07_experimentos.csv: es el paso 6 del orden de implementación.
#
# Decisiones que implementa: F4-01 (orígenes), F4-03 (datos revisados, G-6), F4-04 (pérdida yoy en
# pp), F4-05 (grupos), F4-07 (denominador), F4-09/F4-09b (X-13 por origen), F4-15 a F4-18 (pruebas),
# F4-19 (NSA desde L1), F4-20 (observado de L3, bases del origen), F4-21 (marca de tamaño) y F4-22
# (R5 solo en G2 y G3, serie oficial tal cual). Regla 7 de CLAUDE.md: toda guarda falla con stop().

source(here::here("src", "evaluacion", "eval_lib.R"))
source(here::here("src", "evaluacion", "modelos_referencia.R"))
source(here::here("src", "transformacion", "l3_pib_objetivo_reglas.R"))   # concatenar_pib_nsa(), T001
source(here::here("src", "transformacion", "vintage_lib.R"))

# ---------------------------------------------------------------------------------------------
# Experimentos declarados
# ---------------------------------------------------------------------------------------------
# Principal: los tres grupos con el ajuste reestimado por origen. R5: objetivo oficial, solo G2 y
# G3 (en 2013-Q1 tiene 33 obs, menos que el mínimo de G-4) y sin reajuste (es el SA del BCR).

EXPERIMENTOS <- data.frame(
  exp_id   = c("F4_BENCH_G1", "F4_BENCH_G2", "F4_BENCH_G3", "F4_BENCH_G2_R5", "F4_BENCH_G3_R5"),
  grupo    = c("G1", "G2", "G3", "G2", "G3"),
  objetivo = c(rep("PIB_SA_PROPIO_Q", 3), rep("PIB_SA_OFICIAL_Q", 2)),
  sa       = c(rep("reestimado_en_origen", 3), rep("l3_unico", 2)),
  ventana  = "expansiva",
  vintage  = "revision_vigente",
  perdida  = "yoy_pp",
  stringsAsFactors = FALSE
)

MIN_OBS    <- 40L                    # G-4, mínimo de observaciones del objetivo (F4-05)
ALPHA_MCS  <- 0.10                   # F4-15
B_MCS      <- 5000L                  # F4-15
BENCHMARK  <- "BENCH.RW_SIN_DERIVA"  # F4-07
UNIDADES   <- c("yoy_pp", "qoq_pp", "log_nivel")
MARCA_TAMANO <- "distorsion_tamano_documentada"   # F4-18 / F4-21, en h = 4, 8

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

#' Corre un experimento y devuelve sus tablas. `cache_sa` es un entorno compartido entre
#' experimentos: el ajuste de un origen se computa una sola vez y lo ven todos los grupos.
correr_experimento <- function(ex, insumos, cache_sa) {
  token <- construir_token(ex$ventana, ex$grupo, ex$vintage, ex$sa, ex$perdida)
  if (ex$ventana != "expansiva") stop("motor: ventana ", ex$ventana, " no implementada en este paso (R1 va con la batería de robustez)")
  if (ex$objetivo == "PIB_SA_OFICIAL_Q" && (ex$sa != "l3_unico" || ex$grupo == "G1")) stop("F4-22: R5 corre solo en G2/G3 y con la serie oficial tal cual")
  obs <- insumos$objetivos[[ex$objetivo]]
  origenes <- origenes_grupo(ex$grupo)
  modelos <- modelos_referencia()

  if (ex$sa == "reestimado_en_origen") {
    if (ex$objetivo != "PIB_SA_PROPIO_Q") stop("motor: el ajuste por origen solo está definido para PIB_SA_PROPIO_Q")
    partes <- lapply(origenes, function(o) {
      clave <- as.character(o)
      if (is.null(cache_sa[[clave]])) cache_sa[[clave]] <- ajustar_en_origen(insumos$nsa, insumos$outliers, o)
      a <- cache_sa[[clave]]
      pr <- correr_backtest(list(objetivo = a$sa), modelos, o, min_obs = MIN_OBS, exp_id = ex$exp_id)
      list(pron = pr, base = data.frame(origen = o, periodo = a$sa$periodo, y = a$sa$y, stringsAsFactors = FALSE),
           reg = a$registro)
    })
    pron  <- do.call(rbind, lapply(partes, `[[`, "pron"))
    bases <- do.call(rbind, lapply(partes, `[[`, "base"))
    ajuste <- cbind(exp_id = ex$exp_id, do.call(rbind, lapply(partes, `[[`, "reg")), stringsAsFactors = FALSE)
  } else {
    pron <- correr_backtest(list(objetivo = obs[, c("periodo", "y")]), modelos, origenes, min_obs = MIN_OBS, exp_id = ex$exp_id)
    bases <- NULL; ajuste <- NULL
  }

  err <- calcular_errores(pron, obs[, c("periodo", "y")], bases = bases)
  err <- err[order(err$unidad, err$modelo_id, err$h, err$origen), ]

  # Métricas, con el conteo de pares del grupo como guarda (F4-01, F4-05).
  met <- agregar_rmse_relativo(metricas_por_horizonte(err), BENCHMARK)
  esperado <- conteo_por_horizonte(pares_evaluables(origenes, DISENO_FASE4$horizontes, obs$periodo[nrow(obs)]))
  n_obs_h <- tapply(met$n_pares, met$h, unique)
  if (!identical(as.integer(unlist(n_obs_h)), unname(esperado))) stop("motor: pares por horizonte distintos del diseño del grupo ", ex$grupo)
  met <- data.frame(exp_id = ex$exp_id, modelo_id = met$modelo_id, grupo = ex$grupo, h = met$h, unidad = met$unidad,
                    n_pares = met$n_pares, rmse = met$rmse, mae = met$mae, rmse_relativo = met$rmse_relativo,
                    sesgo = met$sesgo, sesgo_ee_nw = met$sesgo_ee_nw,
                    cobertura_80 = NA_real_, cobertura_95 = NA_real_, crps = NA_real_, stringsAsFactors = FALSE)

  # Pruebas por pares contra el denominador y MCS, sobre la unidad primaria (protocolo §4).
  ids <- vapply(modelos, `[[`, character(1), "modelo_id")
  prim <- err[err$unidad == ex$perdida, ]
  pruebas <- list(); mcs <- list()
  for (h in DISENO_FASE4$horizontes) {
    eh <- prim[prim$h == h, ]
    orig_ref <- sort(unique(eh$origen))
    E <- matrix(NA_real_, length(orig_ref), length(ids), dimnames = list(orig_ref, ids))
    for (id in ids) {
      d <- eh[eh$modelo_id == id, ]; d <- d[order(d$origen), ]
      if (!identical(as.integer(d$origen), as.integer(orig_ref))) stop("motor: orígenes desalineados entre modelos en h = ", h, " (", id, ")")
      E[, id] <- d$error
    }
    marca <- if (h >= 4L) MARCA_TAMANO else ""
    for (id in setdiff(ids, BENCHMARK)) {
      r <- prueba_dm_hln(E[, BENCHMARK], E[, id], h)
      pruebas[[length(pruebas) + 1L]] <- data.frame(exp_id = ex$exp_id, grupo = ex$grupo, h = h, unidad = ex$perdida,
        prueba = "dm_hln", modelo_a = BENCHMARK, modelo_b = id, estadistico = r$estadistico, p_valor = r$p_valor,
        n_pares = r$n_pares, varianza = r$varianza, media_diferencial = r$media_diferencial, marca_tamano = marca,
        stringsAsFactors = FALSE)
    }
    semilla <- semilla_de(ex$exp_id, "MCS", h)
    res <- mcs_tmax(E^2, h, alpha = ALPHA_MCS, B = B_MCS, semilla = semilla)
    mcs[[length(mcs) + 1L]] <- data.frame(exp_id = ex$exp_id, grupo = ex$grupo, h = h, unidad = ex$perdida,
      modelo_id = res$modelo_id, p_mcs = res$p_mcs, en_mcs = res$en_mcs, orden_eliminacion = res$orden_eliminacion,
      alpha = attr(res, "alpha"), replicas = attr(res, "B"), bloque = attr(res, "bloque"), semilla = semilla,
      marca_tamano = marca, stringsAsFactors = FALSE)
  }

  # Pronósticos con sus unidades derivadas y el vintage del observado en el target.
  pu <- derivar_unidades(pron, obs[, c("periodo", "y")], bases)
  vint <- stats::setNames(obs$vintage_id, q_a_ind(obs$periodo))
  pron_out <- data.frame(exp_id = ex$exp_id, modelo_id = pu$modelo_id, grupo = ex$grupo, origen = ind_a_q(pu$origen),
                         h = pu$h, periodo_objetivo = ind_a_q(pu$origen + pu$h),
                         log_nivel_pronosticado = pu$log_nivel_pronosticado, yoy_pp_pronosticado = pu$yoy_pp_pronosticado,
                         qoq_pp_pronosticado = pu$qoq_pp_pronosticado,
                         vintage_id_objetivo = unname(vint[as.character(pu$origen + pu$h)]), stringsAsFactors = FALSE)

  list(token = token, pronosticos = pron_out, metricas = met, pruebas = do.call(rbind, pruebas),
       mcs = do.call(rbind, mcs), ajuste_estacional = ajuste)
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

escribir_experimento <- function(ex, res, commit, insumos_sha) {
  dir <- here::here("data", "L4_experiments", ex$exp_id)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  tablas <- list(pronosticos = res$pronosticos, metricas = res$metricas, pruebas = res$pruebas, mcs = res$mcs)
  if (!is.null(res$ajuste_estacional)) tablas$ajuste_estacional <- res$ajuste_estacional
  viejo <- file.path(dir, "ajuste_estacional.csv")
  if (is.null(res$ajuste_estacional) && file.exists(viejo)) file.remove(viejo)
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
  for (k in seq_len(nrow(sel))) {
    ex <- sel[k, ]
    t0 <- Sys.time()
    res <- correr_experimento(ex, insumos, cache_sa)
    escribir_experimento(ex, res, commit, insumos_sha)
    cat(sprintf("OK %-16s %s  %d pronósticos  %.0f s\n", ex$exp_id, res$token, nrow(res$pronosticos),
                as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  }
  invisible(TRUE)
}

if (sys.nframe() == 0L) main(commandArgs(trailingOnly = TRUE))
