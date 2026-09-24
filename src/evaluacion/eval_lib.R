# src/evaluacion/eval_lib.R
#
# Biblioteca pura del motor de evaluación de Fase 4
# (doc/metodologia/especificacion_motor_evaluacion.md). Sin I/O: no lee ni escribe disco. La
# ejercitan tests/test-evaluacion.R y src/evaluacion/verificar_motor_sintetico.R, los dos sin datos
# del proyecto, así que corre en CI.
#
# Contenido:
#   1. aritmética de períodos
#   2. diseño de orígenes y pares (origen, h)             F4-01, convención A (ADR-002, nota 2026-09-24)
#   3. conjunto de información por origen                 F4-02, regla de calendario
#   4. bucle de orígenes con las guardas G-1 a G-4
#   5. derivación de unidades y cómputo de errores        F4-04
#   6. métricas por horizonte                             protocolo §3
#   7. gramática del token de `esquema_validacion`        F4-11
#   8. pruebas de significancia: DM/HLN, Giacomini-White y MCS   protocolo §4, F4-15 a F4-17
#   9. ajuste estacional por origen y vintage: especificación y guardas G-5, G-6   F4-09b, F4-03
#
# Desviación declarada respecto de la especificación §1: el bucle de orígenes vive acá y no en
# motor_backtesting.R, porque la verificación sintética (V1-V6, V10) tiene que ejercitar el mismo
# bucle, con las mismas guardas, sin leer L3. motor_backtesting.R (paso 5) queda como orquestador de
# lectura y escritura.
#
# Regla 7 de CLAUDE.md: toda guarda falla con stop(), nunca advierte.

# ---------------------------------------------------------------------------------------------
# 1. Aritmética de períodos
# ---------------------------------------------------------------------------------------------

#' "1990-Q1" -> índice entero de trimestre (año*4 + trimestre - 1). Falla ante formato ajeno.
q_a_ind <- function(p) {
  p <- as.character(p)
  malos <- !grepl("^[0-9]{4}-Q[1-4]$", p)
  if (any(malos)) stop("período trimestral mal formado: ", paste(utils::head(p[malos], 3), collapse = ", "))
  as.integer(substr(p, 1, 4)) * 4L + as.integer(substr(p, 7, 7)) - 1L
}

#' Índice entero de trimestre -> "1990-Q1".
ind_a_q <- function(i) sprintf("%d-Q%d", as.integer(i) %/% 4L, as.integer(i) %% 4L + 1L)

#' "2005-M01" -> índice entero de mes (año*12 + mes - 1). Falla ante formato ajeno.
m_a_ind <- function(p) {
  p <- as.character(p)
  malos <- !grepl("^[0-9]{4}-M(0[1-9]|1[0-2])$", p)
  if (any(malos)) stop("período mensual mal formado: ", paste(utils::head(p[malos], 3), collapse = ", "))
  as.integer(substr(p, 1, 4)) * 12L + as.integer(substr(p, 7, 8)) - 1L
}

#' Último día del mes de índice mensual `im`.
fin_de_mes_ind <- function(im) {
  sig <- as.integer(im) + 1L                                  # primer día del mes siguiente
  as.Date(sprintf("%d-%02d-01", sig %/% 12L, sig %% 12L + 1L)) - 1L
}

#' Último día del trimestre de índice `iq`.
fin_de_trimestre_ind <- function(iq) {
  iq <- as.integer(iq)
  fin_de_mes_ind(iq %/% 4L * 12L + (iq %% 4L) * 3L + 2L)
}

# ---------------------------------------------------------------------------------------------
# 2. Diseño de orígenes (F4-01, convención A)
# ---------------------------------------------------------------------------------------------
#
# Origen `o` = último trimestre con dato observado del objetivo que entra a la muestra de
# estimación. El pronóstico a horizonte h emitido en `o` se compara contra `o + h`. Un par (o, h)
# se evalúa solo si `o + h` está observado.

DISENO_FASE4 <- list(
  primer_origen = "2013-Q1",
  ultimo_origen = "2025-Q4",
  horizontes    = c(1L, 2L, 4L, 8L),
  h_max         = 8L
)

#' Primer origen de cada grupo de comparación (F4-05). Todos terminan en DISENO_FASE4$ultimo_origen;
#' con el último target 2026-Q1 dan 52/51/49/45, 45/44/42/38 y 25/24/22/18 pares por horizonte.
GRUPOS_FASE4 <- c(G1 = "2013-Q1", G2 = "2014-Q4", G3 = "2019-Q4")

#' Índices de origen de un grupo de comparación (F4-05).
origenes_grupo <- function(grupo) {
  if (length(grupo) != 1L || !grupo %in% names(GRUPOS_FASE4)) stop("grupo de comparación no declarado: ", paste(grupo, collapse = ", "))
  origenes_diseno(GRUPOS_FASE4[[grupo]], DISENO_FASE4$ultimo_origen)
}

#' Vector de índices de origen entre dos trimestres, inclusive.
origenes_diseno <- function(primer = DISENO_FASE4$primer_origen, ultimo = DISENO_FASE4$ultimo_origen) {
  a <- q_a_ind(primer); b <- q_a_ind(ultimo)
  if (b < a) stop("último origen anterior al primero: ", primer, " .. ", ultimo)
  seq.int(a, b)
}

#' Pares (origen, h) evaluables: `o + h` no posterior al último target observado.
pares_evaluables <- function(origenes, horizontes, ultimo_target) {
  ut <- if (is.character(ultimo_target)) q_a_ind(ultimo_target) else as.integer(ultimo_target)
  g <- expand.grid(origen = as.integer(origenes), h = as.integer(horizontes))
  g <- g[g$origen + g$h <= ut, ]
  g$objetivo <- g$origen + g$h
  g <- g[order(g$h, g$origen), ]
  rownames(g) <- NULL
  g
}

#' Conteo de pares evaluables por horizonte (lo que ADR-002 publica como 52/51/49/45).
conteo_por_horizonte <- function(pares) {
  t <- table(factor(pares$h, levels = sort(unique(pares$h))))
  stats::setNames(as.integer(t), names(t))
}

# ---------------------------------------------------------------------------------------------
# 3. Conjunto de información por origen (F4-02)
# ---------------------------------------------------------------------------------------------
#
# Fecha de corte del origen `o` = cierre de `o` + rezago de publicación del PIB. Una serie con
# rezago declarado entra hasta el último período `p` con fin(p) + rezago <= corte. El objetivo no
# lleva rezago: entra exactamente hasta `o`, por definición del origen.

REZAGO_PIB_DIAS <- 92L   # mediana del calendario de divulgación del BCR (reportes_fase4/evidencia_insumos_fase4.csv)

#' Fecha de corte del conjunto de información del origen `o` (índice trimestral).
fecha_corte_origen <- function(o, rezago_pib = REZAGO_PIB_DIAS) fin_de_trimestre_ind(o) + as.integer(rezago_pib)

.fin_de_periodo <- function(periodo) {
  if (grepl("-M", periodo[1], fixed = TRUE)) fin_de_mes_ind(m_a_ind(periodo)) else fin_de_trimestre_ind(q_a_ind(periodo))
}

#' Recorta una serie (data.frame con `periodo`) al conjunto de información del origen `o`.
#' @param rezago rezago de publicación en días; NULL solo para el objetivo trimestral.
recortar_a_origen <- function(d, o, rezago = NULL, rezago_pib = REZAGO_PIB_DIAS) {
  if (!"periodo" %in% names(d)) stop("recortar_a_origen: falta la columna `periodo`")
  if (nrow(d) == 0L) return(d)
  if (is.null(rezago)) {
    if (grepl("-M", d$periodo[1], fixed = TRUE)) stop("recortar_a_origen: una serie mensual necesita su rezago de publicación")
    return(d[q_a_ind(d$periodo) <= o, , drop = FALSE])
  }
  d[.fin_de_periodo(d$periodo) + as.integer(rezago) <= fecha_corte_origen(o, rezago_pib), , drop = FALSE]
}

#' G-1: ningún período del recorte es posterior a lo que el origen podía conocer. Doble cerrojo
#' sobre recortar_a_origen(): la guarda recalcula la condición y falla si no se cumple.
guarda_recorte <- function(d, o, rezago = NULL, nombre = "serie", rezago_pib = REZAGO_PIB_DIAS) {
  if (nrow(d) == 0L) return(invisible(TRUE))
  fuera <- if (is.null(rezago)) {
    q_a_ind(d$periodo) > o
  } else {
    .fin_de_periodo(d$periodo) + as.integer(rezago) > fecha_corte_origen(o, rezago_pib)
  }
  if (any(fuera)) {
    stop(sprintf("G-1 filtración: %s trae %d período(s) fuera del conjunto de información del origen %s (primero: %s)",
                 nombre, sum(fuera), ind_a_q(o), d$periodo[which(fuera)[1]]))
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------------------------
# 4. Bucle de orígenes
# ---------------------------------------------------------------------------------------------
#
# Contrato de modelo (especificación §2): list(modelo_id, requiere, ajustar(datos, spec),
# predecir(ajuste, h)). `ajustar` recibe una lista de data.frames YA recortados y no recibe el
# origen; `predecir` devuelve el sendero h = 1..h_max del objetivo en log-nivel.
#
# Límite que el motor no puede cerrar por construcción: un modelo que capture datos completos en su
# clausura (una variable global, un entorno) evade el recorte sin que ninguna guarda lo vea. El
# contrato lo prohíbe y los modelos viven en src/evaluacion/modelos_referencia.R sin estado global;
# eso se controla en revisión de código, no en tiempo de ejecución.

#' Semilla determinista por (exp_id, modelo_id, origen): reejecutar un origen aislado reproduce el
#' mismo resultado sin depender del orden del bucle.
semilla_de <- function(exp_id, modelo_id, origen) {
  h <- digest::digest(paste(exp_id, modelo_id, origen, sep = "|"), algo = "xxhash32", serialize = FALSE)
  strtoi(substr(h, 1, 7), 16L)
}

.validar_modelo <- function(m) {
  faltan <- setdiff(c("modelo_id", "requiere", "ajustar", "predecir"), names(m))
  if (length(faltan)) stop("modelo sin campos del contrato: ", paste(faltan, collapse = ", "))
  if (!is.function(m$ajustar) || !is.function(m$predecir)) stop("modelo ", m$modelo_id, ": ajustar/predecir deben ser funciones")
  invisible(TRUE)
}

#' Corre el bucle origen -> modelo y devuelve los senderos pronosticados.
#'
#' @param series   lista nombrada de data.frames. series$objetivo trae `periodo` y `y` (log-nivel);
#'                 los predictores, `periodo` y `valor`.
#' @param modelos  lista de modelos bajo el contrato.
#' @param origenes índices trimestrales de origen.
#' @param rezagos  lista nombrada de rezagos en días por serie; el objetivo no lleva.
#' @param min_obs  mínimo de observaciones del objetivo para estimar (G-4).
#' @param exp_id   identificador del experimento; entra en la semilla.
#' @param spec     lista de especificaciones por modelo_id (opcional).
#' @return data.frame: modelo_id, origen (índice), h, log_nivel_pronosticado.
correr_backtest <- function(series, modelos, origenes, rezagos = list(), min_obs = 40L,
                            h_max = DISENO_FASE4$h_max, exp_id = "sin_exp", spec = list()) {
  if (is.null(series$objetivo)) stop("correr_backtest: falta series$objetivo")
  if (!"y" %in% names(series$objetivo)) stop("correr_backtest: el objetivo debe traer `y` (log-nivel)")
  if (!is.null(rezagos$objetivo)) stop("correr_backtest: el objetivo no lleva rezago (entra hasta el origen)")
  invisible(lapply(modelos, .validar_modelo))
  ids <- vapply(modelos, `[[`, character(1), "modelo_id")
  if (anyDuplicated(ids)) stop("modelo_id duplicado: ", paste(ids[duplicated(ids)], collapse = ", "))

  # El motor fija la semilla por (exp_id, modelo, origen), pero no debe alterar el generador del
  # llamador: sin esto, un bucle de Monte Carlo que llame al motor vería la misma secuencia en cada
  # réplica (defecto detectado por V3 de la verificación sintética, 2026-09-24).
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    semilla_previa <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
    on.exit(assign(".Random.seed", semilla_previa, envir = globalenv()), add = TRUE)
  } else {
    on.exit(if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) rm(".Random.seed", envir = globalenv()), add = TRUE)
  }

  huella_maestra <- digest::digest(series)                                      # G-2
  salida <- vector("list", length(origenes) * length(modelos)); k <- 0L

  for (o in origenes) {
    # Recorte una sola vez por origen: todos los modelos ven el mismo conjunto de información.
    info <- stats::setNames(lapply(names(series), function(nm) {
      r <- recortar_a_origen(series[[nm]], o, rezagos[[nm]])
      guarda_recorte(r, o, rezagos[[nm]], nombre = nm)                          # G-1
      r
    }), names(series))
    n_obj <- nrow(info$objetivo)
    if (n_obj == 0L || q_a_ind(info$objetivo$periodo[n_obj]) != o) {
      stop(sprintf("el objetivo no está observado en el origen %s", ind_a_q(o)))
    }

    for (m in modelos) {
      faltan <- setdiff(m$requiere, names(info))                                # G-4
      if (length(faltan)) stop(sprintf("G-4 modelo %s requiere series ausentes: %s", m$modelo_id, paste(faltan, collapse = ", ")))
      if (n_obj < min_obs) stop(sprintf("G-4 modelo %s en %s: %d obs del objetivo, mínimo %d", m$modelo_id, ind_a_q(o), n_obj, min_obs))

      set.seed(semilla_de(exp_id, m$modelo_id, o))
      ajuste  <- m$ajustar(info[m$requiere], spec[[m$modelo_id]])
      sendero <- m$predecir(ajuste, h_max)

      if (!is.numeric(sendero) || length(sendero) != h_max || any(!is.finite(sendero))) {                 # G-3
        stop(sprintf("G-3 modelo %s en %s: predecir() debe devolver %d valores finitos (devolvió %d, %d no finitos)",
                     m$modelo_id, ind_a_q(o), h_max, length(sendero), sum(!is.finite(sendero))))
      }
      if (!identical(digest::digest(series), huella_maestra)) {                                            # G-2
        stop(sprintf("G-2 modelo %s en %s alteró el estado maestro del motor", m$modelo_id, ind_a_q(o)))
      }
      k <- k + 1L
      salida[[k]] <- data.frame(modelo_id = m$modelo_id, origen = o, h = seq_len(h_max),
                                log_nivel_pronosticado = as.numeric(sendero), stringsAsFactors = FALSE)
    }
  }
  res <- do.call(rbind, salida[seq_len(k)])
  rownames(res) <- NULL
  res
}

# ---------------------------------------------------------------------------------------------
# 5. Derivación de unidades y errores (F4-04)
# ---------------------------------------------------------------------------------------------
#
# yoy(o+h) = 100 * (log Y_{o+h} - log Y_{o+h-4}): la base es observada si h <= 4 y pronosticada por
# el mismo sendero si h > 4. qoq(o+h) = 100 * (log Y_{o+h} - log Y_{o+h-1}), con la base de h = 1
# observada en el origen.

#' Agrega yoy_pp_pronosticado y qoq_pp_pronosticado a la salida de correr_backtest().
#' @param objetivo data.frame `periodo`, `y` (log-nivel observado del vintage de evaluación).
#' @param bases    opcional (F4-20): data.frame `origen` (índice), `periodo`, `y` con la historia del
#'                 objetivo tal como la veía cada origen (el ajuste estacional reestimado en ese
#'                 origen). Si se da, las bases observadas de la tasa interanual (h <= 4) y de la
#'                 trimestral (h = 1) salen de ahí y no de `objetivo`. Ninguna base puede ser
#'                 posterior a su origen.
derivar_unidades <- function(pron, objetivo, bases = NULL) {
  obs <- stats::setNames(objetivo$y, q_a_ind(objetivo$periodo))
  if (!is.null(bases)) {
    faltan <- setdiff(c("origen", "periodo", "y"), names(bases))
    if (length(faltan)) stop("derivar_unidades: a `bases` le faltan columnas: ", paste(faltan, collapse = ", "))
    bi <- q_a_ind(bases$periodo)
    if (any(bi > bases$origen)) {
      k <- which(bi > bases$origen)[1]
      stop(sprintf("derivar_unidades: la base %s del origen %s es posterior al origen (G-1)", bases$periodo[k], ind_a_q(bases$origen[k])))
    }
    if (anyDuplicated(paste(bases$origen, bi))) stop("derivar_unidades: `bases` trae períodos duplicados dentro de un origen")
    if (anyNA(bases$y)) stop("derivar_unidades: `bases` trae NA")
    base_de <- lapply(split(seq_len(nrow(bases)), bases$origen), function(i) stats::setNames(bases$y[i], bi[i]))
  }
  pron <- pron[order(pron$modelo_id, pron$origen, pron$h), ]
  clave <- paste(pron$modelo_id, pron$origen, sep = "|")
  pron$yoy_pp_pronosticado <- NA_real_
  pron$qoq_pp_pronosticado <- NA_real_
  for (cl in unique(clave)) {
    idx <- which(clave == cl)
    o <- pron$origen[idx[1]]; s <- pron$log_nivel_pronosticado[idx]; hs <- pron$h[idx]
    if (!identical(as.integer(hs), seq_along(hs))) stop("derivar_unidades: sendero incompleto en ", cl)
    hist <- if (is.null(bases)) obs else base_de[[as.character(o)]]
    if (is.null(hist)) stop("derivar_unidades: faltan las bases del origen ", ind_a_q(o))
    val <- function(i) {
      v <- unname(hist[as.character(i)])
      if (is.na(v)) stop(sprintf("derivar_unidades: falta la base %s del origen %s", ind_a_q(i), ind_a_q(o)))
      v
    }
    base4 <- vapply(hs, function(h) if (h <= 4L) val(o + h - 4L) else s[h - 4L], numeric(1))
    base1 <- vapply(hs, function(h) if (h == 1L) val(o) else s[h - 1L], numeric(1))
    pron$yoy_pp_pronosticado[idx] <- 100 * (s - base4)
    pron$qoq_pp_pronosticado[idx] <- 100 * (s - base1)
  }
  rownames(pron) <- NULL
  pron
}

#' Errores sobre los pares evaluables, en las tres unidades.
#' El observado sale siempre de `objetivo`; `bases` (opcional, F4-20) solo cambia de dónde salen las
#' bases de la tasa pronosticada (ver derivar_unidades()).
#' @return data.frame: modelo_id, origen, h, unidad, pronostico, observado, error (observado - pronostico).
calcular_errores <- function(pron, objetivo, horizontes = DISENO_FASE4$horizontes, bases = NULL) {
  pron <- derivar_unidades(pron, objetivo, bases)
  iq <- q_a_ind(objetivo$periodo)
  y <- stats::setNames(objetivo$y, iq)
  pron <- pron[pron$h %in% horizontes & pron$origen + pron$h <= max(iq), ]
  tgt <- as.character(pron$origen + pron$h)
  obs_log <- unname(y[tgt])
  obs_yoy <- 100 * (obs_log - unname(y[as.character(pron$origen + pron$h - 4L)]))
  obs_qoq <- 100 * (obs_log - unname(y[as.character(pron$origen + pron$h - 1L)]))
  if (anyNA(obs_log) || anyNA(obs_yoy) || anyNA(obs_qoq)) stop("calcular_errores: falta un observado en un par evaluable")
  arma <- function(u, p, ob) data.frame(modelo_id = pron$modelo_id, origen = pron$origen, h = pron$h,
                                        unidad = u, pronostico = p, observado = ob, error = ob - p,
                                        stringsAsFactors = FALSE)
  res <- rbind(arma("yoy_pp", pron$yoy_pp_pronosticado, obs_yoy),
               arma("qoq_pp", pron$qoq_pp_pronosticado, obs_qoq),
               arma("log_nivel", pron$log_nivel_pronosticado, obs_log))
  rownames(res) <- NULL
  res
}

# ---------------------------------------------------------------------------------------------
# 6. Métricas por horizonte (protocolo §3)
# ---------------------------------------------------------------------------------------------

#' Varianza de largo plazo de Newey-West, ventana de Bartlett de `rezagos` rezagos.
varianza_nw <- function(x, rezagos) {
  x <- x - mean(x); n <- length(x)
  v <- sum(x^2) / n
  if (rezagos > 0L && n > 1L) for (l in seq_len(min(rezagos, n - 1L))) {
    v <- v + 2 * (1 - l / (rezagos + 1)) * sum(x[(l + 1):n] * x[1:(n - l)]) / n
  }
  v
}

#' Métricas por modelo, horizonte y unidad: n, RMSE, MAE, sesgo y su error estándar NW (h-1 rezagos).
metricas_por_horizonte <- function(err) {
  g <- split(err, list(err$modelo_id, err$h, err$unidad), drop = TRUE)
  res <- do.call(rbind, lapply(g, function(d) {
    e <- d$error; n <- length(e); h <- d$h[1]
    data.frame(modelo_id = d$modelo_id[1], h = h, unidad = d$unidad[1], n_pares = n,
               rmse = sqrt(mean(e^2)), mae = mean(abs(e)), sesgo = mean(e),
               sesgo_ee_nw = sqrt(varianza_nw(e, h - 1L) / n), stringsAsFactors = FALSE)
  }))
  res <- res[order(res$unidad, res$h, res$modelo_id), ]
  rownames(res) <- NULL
  res
}

#' Agrega rmse_relativo = rmse / rmse del benchmark, por horizonte y unidad (F4-07). Falla si algún
#' modelo no tiene exactamente el mismo número de pares que el benchmark: la comparación exige la
#' misma muestra.
agregar_rmse_relativo <- function(met, benchmark = "BENCH.RW_SIN_DERIVA") {
  b <- met[met$modelo_id == benchmark, c("h", "unidad", "rmse", "n_pares")]
  if (nrow(b) == 0L) stop("agregar_rmse_relativo: el benchmark ", benchmark, " no está en las métricas")
  names(b)[3:4] <- c("rmse_bench", "n_bench")
  m <- merge(met, b, by = c("h", "unidad"), all.x = TRUE, sort = FALSE)
  distinto <- is.na(m$n_bench) | m$n_pares != m$n_bench
  if (any(distinto)) stop("agregar_rmse_relativo: modelos con pares distintos del benchmark: ",
                         paste(unique(m$modelo_id[distinto]), collapse = ", "))
  m$rmse_relativo <- m$rmse / m$rmse_bench
  m <- m[order(m$unidad, m$h, m$modelo_id), c(names(met), "rmse_relativo")]
  rownames(m) <- NULL
  m
}

# ---------------------------------------------------------------------------------------------
# 7. Token de `esquema_validacion` (F4-11)
# ---------------------------------------------------------------------------------------------
#
# Gramática: <ventana>|origen=<v>|grupo=<v>|vintage=<v>|sa=<v>|perdida=<v>
# Los seis campos son obligatorios, en ese orden, con los valores declarados en TOKEN_DOMINIOS.

TOKEN_DOMINIOS <- list(
  ventana = c("expansiva", "rodante92"),
  origen  = c("ultimo_estimado"),
  grupo   = c("G1", "G2", "G3"),
  vintage = c("revision_vigente", "real_time"),
  sa      = c("reestimado_en_origen", "l3_unico"),
  perdida = c("yoy_pp", "qoq_pp", "log_nivel")
)

construir_token <- function(ventana, grupo, vintage, sa, perdida, origen = "ultimo_estimado") {
  tok <- sprintf("%s|origen=%s|grupo=%s|vintage=%s|sa=%s|perdida=%s", ventana, origen, grupo, vintage, sa, perdida)
  validar_token(tok)
  tok
}

#' Valida un token y lo devuelve descompuesto en lista; falla ante cualquier desvío de la gramática.
validar_token <- function(tok) {
  if (!is.character(tok) || length(tok) != 1L || is.na(tok)) stop("token: debe ser un único string")
  partes <- strsplit(tok, "|", fixed = TRUE)[[1]]
  claves <- names(TOKEN_DOMINIOS)
  if (length(partes) != length(claves)) stop(sprintf("token: %d campos, se esperan %d: %s", length(partes), length(claves), tok))
  valores <- list(ventana = partes[1])
  for (i in 2:length(claves)) {
    kv <- strsplit(partes[i], "=", fixed = TRUE)[[1]]
    if (length(kv) != 2L || kv[1] != claves[i]) stop(sprintf("token: el campo %d debe ser `%s=...`, vino `%s`", i, claves[i], partes[i]))
    valores[[claves[i]]] <- kv[2]
  }
  for (cl in claves) {
    if (!valores[[cl]] %in% TOKEN_DOMINIOS[[cl]]) {
      stop(sprintf("token: valor no declarado para %s: `%s` (válidos: %s)", cl, valores[[cl]], paste(TOKEN_DOMINIOS[[cl]], collapse = ", ")))
    }
  }
  valores
}

# ---------------------------------------------------------------------------------------------
# 8. Pruebas de significancia (protocolo §4)
# ---------------------------------------------------------------------------------------------
#
# Pérdida cuadrática sobre la unidad primaria. Convención de signo en todas las pruebas por pares:
# d_t = e1_t² - e2_t², así que un estadístico positivo favorece al modelo 2 (pérdida menor).
# Los vectores de errores deben venir ordenados por origen y ser consecutivos (un par por origen),
# que es como los entrega calcular_errores() filtrado por modelo, unidad y h.
#
# Parámetros decididos por Harold el 2026-09-24 (registro: doc/metodologia/decisiones_fase4.md):
#   F4-15  DM/HLN: varianza rectangular de h-1 rezagos; si sale <= 0, respaldo Bartlett con los
#          mismos rezagos, registrado en la columna `varianza`.
#   F4-16  GW: instrumentos (1, d_{t-h}), χ²(2), varianza HAC de Bartlett con h-1 rezagos.
#   F4-17  MCS: estadístico T_max, α = 0,10, bootstrap estacionario con bloque medio
#          max(h, ceiling(n^(1/3))), B = 5000 en las corridas sobre L3.

.autocov <- function(x, k) {
  n <- length(x); x <- x - mean(x)
  sum(x[(k + 1L):n] * x[1:(n - k)]) / n
}

#' Varianza de largo plazo con ventana rectangular de `rezagos` rezagos (sin pesos).
varianza_rectangular <- function(x, rezagos) {
  v <- .autocov(x, 0L)
  if (rezagos > 0L) for (k in seq_len(min(rezagos, length(x) - 1L))) v <- v + 2 * .autocov(x, k)
  v
}

.diferencial <- function(e1, e2) {
  if (length(e1) != length(e2)) stop("prueba por pares: los dos vectores de errores tienen largos distintos")
  if (anyNA(e1) || anyNA(e2)) stop("prueba por pares: hay errores NA")
  e1^2 - e2^2
}

#' Diebold-Mariano con la corrección de Harvey, Leybourne y Newbold (1997).
#' @return list(estadistico, p_valor (bilateral, t con n-1 gl), n_pares, varianza, media_diferencial)
prueba_dm_hln <- function(e1, e2, h) {
  d <- .diferencial(e1, e2); n <- length(d); h <- as.integer(h)
  if (n < 3L) stop("DM/HLN: se necesitan al menos 3 pares, hay ", n)
  k2 <- (n + 1 - 2 * h + h * (h - 1) / n) / n
  if (k2 <= 0) stop(sprintf("DM/HLN: corrección HLN no definida con n = %d y h = %d", n, h))
  if (all(d == d[1])) {
    if (d[1] == 0) return(list(estadistico = 0, p_valor = 1, n_pares = n, varianza = "degenerada", media_diferencial = 0))
    stop("DM/HLN: diferencial de pérdidas constante y no nulo; la varianza es cero")
  }
  v <- varianza_rectangular(d, h - 1L); tipo <- "rectangular"
  if (!is.finite(v) || v <= 0) { v <- varianza_nw(d, h - 1L); tipo <- "bartlett_respaldo" }       # F4-15
  if (!is.finite(v) || v <= 0) stop("DM/HLN: varianza de largo plazo no positiva también con Bartlett")
  est <- sqrt(k2) * mean(d) / sqrt(v / n)
  list(estadistico = est, p_valor = 2 * stats::pt(-abs(est), df = n - 1L), n_pares = n,
       varianza = tipo, media_diferencial = mean(d))
}

#' Giacomini-White (2006), test condicional con instrumentos (1, d_{t-h}) (F4-16).
#' d_{t-h} es el diferencial del target h trimestres anterior: ya observado en el origen de t.
#' @return list(estadistico, p_valor (χ² con 2 gl), n_pares (usados), media_diferencial)
prueba_gw <- function(e1, e2, h) {
  d <- .diferencial(e1, e2); n <- length(d); h <- as.integer(h)
  m <- n - h
  if (m < 5L) stop(sprintf("GW: con n = %d y h = %d quedan %d pares útiles; mínimo 5", n, h, m))
  t_ <- (h + 1L):n
  Z <- cbind(1, d[t_ - h]) * d[t_]
  zbar <- colMeans(Z); Zc <- sweep(Z, 2L, zbar)
  Om <- crossprod(Zc) / m
  if (h > 1L) for (l in seq_len(min(h - 1L, m - 1L))) {
    G <- crossprod(Zc[(l + 1L):m, , drop = FALSE], Zc[1:(m - l), , drop = FALSE]) / m
    Om <- Om + (1 - l / h) * (G + t(G))
  }
  inv <- tryCatch(solve(Om), error = function(e) stop("GW: matriz de varianza singular (", conditionMessage(e), ")"))
  est <- as.numeric(m * t(zbar) %*% inv %*% zbar)
  list(estadistico = est, p_valor = stats::pchisq(est, df = 2L, lower.tail = FALSE), n_pares = m,
       media_diferencial = mean(d))
}

#' Longitud media de bloque del bootstrap del MCS (F4-17).
bloque_mcs <- function(n, h) max(as.integer(h), as.integer(ceiling(n^(1 / 3))))

#' Índices de un bootstrap estacionario (Politis y Romano 1994), circular, con bloque medio `l`.
indices_bootstrap_estacionario <- function(n, l, B) {
  p <- 1 / l
  idx <- matrix(0L, B, n)
  idx[, 1] <- sample.int(n, B, replace = TRUE)
  if (n > 1L) for (t in 2:n) {
    nuevo <- stats::runif(B) < p
    idx[, t] <- ifelse(nuevo, sample.int(n, B, replace = TRUE), idx[, t - 1L] %% n + 1L)
  }
  idx
}

#' Model Confidence Set de Hansen, Lunde y Nason (2011), estadístico T_max (F4-17).
#'
#' @param perdidas matriz n x m (filas = pares ordenados por origen, columnas = modelos con nombre).
#' @param h        horizonte, para la longitud de bloque.
#' @param semilla  entero; el generador del llamador se restaura al salir.
#' @return data.frame: modelo_id, p_mcs, en_mcs, orden_eliminacion (NA = sobrevive al final),
#'         con atributos alpha, B, bloque.
#' @param indices  opcional: matriz B x n de remuestras ya construida (solo para el oráculo V11, que
#'                 compara contra MCS::MCSprocedure con las mismas remuestras); si se da, ignora bloque.
mcs_tmax <- function(perdidas, h, alpha = 0.10, B = 5000L, semilla, bloque = NULL, indices = NULL) {
  if (!is.matrix(perdidas) || is.null(colnames(perdidas))) stop("MCS: `perdidas` debe ser matriz con nombres de columna")
  if (anyNA(perdidas)) stop("MCS: hay pérdidas NA")
  n <- nrow(perdidas); m <- ncol(perdidas)
  if (m < 2L) stop("MCS: se necesitan al menos 2 modelos")
  if (missing(semilla)) stop("MCS: la semilla es obligatoria")
  if (is.null(bloque)) bloque <- bloque_mcs(n, h)
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    semilla_previa <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
    on.exit(assign(".Random.seed", semilla_previa, envir = globalenv()), add = TRUE)
  } else {
    on.exit(if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) rm(".Random.seed", envir = globalenv()), add = TRUE)
  }
  set.seed(semilla)
  idx <- if (is.null(indices)) indices_bootstrap_estacionario(n, bloque, B) else {   # mismas remuestras en todas las etapas
    if (!is.matrix(indices) || ncol(indices) != n) stop("MCS: `indices` debe ser matriz B x n")
    B <- nrow(indices); indices
  }
  # Medias bootstrap de cada modelo: B x m
  medias_b <- sapply(seq_len(m), function(j) rowMeans(matrix(perdidas[idx, j], B, n)))
  if (is.null(dim(medias_b))) medias_b <- matrix(medias_b, nrow = B)
  medias <- colMeans(perdidas)
  vivos <- seq_len(m); p_mcs <- rep(NA_real_, m); orden <- rep(NA_integer_, m); p_acum <- 0; paso <- 0L
  while (length(vivos) > 1L) {
    dbar   <- medias[vivos] - mean(medias[vivos])                             # d_i. del conjunto vivo
    dbar_b <- medias_b[, vivos, drop = FALSE] - rowMeans(medias_b[, vivos, drop = FALSE])
    var_i  <- colMeans(sweep(dbar_b, 2L, dbar)^2)
    if (any(var_i <= 0)) stop("MCS: varianza bootstrap nula para algún modelo")
    t_i    <- dbar / sqrt(var_i)
    t_b    <- apply(sweep(sweep(dbar_b, 2L, dbar), 2L, sqrt(var_i), "/"), 1L, max)
    p_val  <- mean(t_b >= max(t_i))
    paso   <- paso + 1L
    sale   <- vivos[which.max(t_i)]
    p_acum <- max(p_acum, p_val)
    p_mcs[sale] <- p_acum; orden[sale] <- paso
    vivos <- setdiff(vivos, sale)
  }
  p_mcs[vivos] <- 1
  res <- data.frame(modelo_id = colnames(perdidas), p_mcs = p_mcs, en_mcs = p_mcs >= alpha,
                    orden_eliminacion = orden, stringsAsFactors = FALSE)
  attr(res, "alpha") <- alpha; attr(res, "B") <- B; attr(res, "bloque") <- bloque
  res
}

# ---------------------------------------------------------------------------------------------
# 9. Ajuste estacional por origen (F4-09, F4-09b) y filtro de vintage (F4-03)
# ---------------------------------------------------------------------------------------------
#
# Solo la especificación y las guardas, puras. La llamada a seasonal::seas() vive en
# motor_backtesting.R porque ejecuta el binario de X-13, que no corre en CI. F4-09b fija tres
# desvíos respecto de los defaults de seas() que usa T002: transform=log fijo, detección automática
# de outliers desactivada y los AO declarados como regresores que entran solo desde el origen que
# los alcanza. El resto de la especificación (SEATS, prueba AIC de pascua y días hábiles, selección
# automática del ARIMA) queda en los defaults, igual que en el ajuste único de L3, para que R6
# aísle el efecto de reestimar.

#' "2020-Q2" -> "ao2020.2" (sintaxis de regresores de X-13 para series trimestrales).
codigo_ao_x13 <- function(periodo) {
  i <- q_a_ind(periodo)
  sprintf("ao%d.%d", i %/% 4L, i %% 4L + 1L)
}

#' AO declarados (PIB_SA_PROPIO_Q_outliers.csv, ADR-004) que el origen `o` alcanza. Falla si el
#' catálogo declara un tipo de outlier que F4-09b no contempla.
ao_declarados_origen <- function(outliers, o) {
  if (!all(c("periodo", "tipo") %in% names(outliers))) stop("ajuste por origen: los outliers declarados necesitan `periodo` y `tipo`")
  otros <- setdiff(unique(outliers$tipo), "AO")
  if (length(otros)) stop("ajuste por origen: tipo de outlier declarado no contemplado por F4-09b: ", paste(otros, collapse = ", "))
  p <- outliers$periodo[q_a_ind(outliers$periodo) <= o]
  p[order(q_a_ind(p))]
}

#' G-5 (F4-08): ningún regresor de evento con fecha posterior al origen entra al diseño.
guarda_dummies <- function(periodos, o) {
  if (length(periodos) && any(q_a_ind(periodos) > o)) {
    stop(sprintf("G-5 dummy anticipada: el origen %s recibiría el regresor de %s",
                 ind_a_q(o), paste(periodos[q_a_ind(periodos) > o], collapse = ", ")))
  }
  invisible(TRUE)
}

#' Argumentos de seasonal::seas() para el origen `o` (F4-09b), además de la serie.
args_x13_origen <- function(outliers, o) {
  ao <- ao_declarados_origen(outliers, o)
  guarda_dummies(ao, o)
  a <- list(transform.function = "log", outlier = NULL)
  if (length(ao)) a$regression.variables <- codigo_ao_x13(ao)
  a
}

#' Comprueba que el ajuste del origen respetó F4-09b: transformación log y, como outliers, solo los
#' AO declarados que el origen alcanza (con la detección automática desactivada no debe aparecer
#' ningún otro).
verificar_ajuste_origen <- function(transform, periodos_outlier, ao_declarados, o) {
  if (length(transform) != 1L || is.na(transform) || !identical(trimws(transform), "log")) {
    stop(sprintf("ajuste por origen %s: X-13 no usó transform=log (usó `%s`)", ind_a_q(o), paste(transform, collapse = ",")))
  }
  det <- periodos_outlier[order(q_a_ind(periodos_outlier))]
  if (!identical(as.character(det), as.character(ao_declarados))) {
    stop(sprintf("ajuste por origen %s: outliers del modelo [%s] distintos de los AO declarados [%s]",
                 ind_a_q(o), paste(det, collapse = ", "), paste(ao_declarados, collapse = ", ")))
  }
  guarda_dummies(det, o)
}

#' G-6 (F4-03): filtra por `vintage_id`. `revision_vigente` conserva, en cada período, la fila del
#' vintage vigente y falla si algún período no la tiene o la tiene repetida. `real_time` no es
#' implementable hoy (el PIB no tiene vintages anteriores a 2026-06) y falla en vez de degradarse.
filtrar_vintage <- function(d, politica, vigentes) {
  if (!all(c("periodo", "vintage_id") %in% names(d))) stop("G-6: la serie necesita `periodo` y `vintage_id`")
  if (identical(politica, "real_time")) {
    stop("G-6: vintage=real_time no es implementable con el registro actual de 08_vintages.csv (F4-03, pista prospectiva)")
  }
  if (!identical(politica, "revision_vigente")) stop("G-6: política de vintage no declarada: ", paste(politica, collapse = ", "))
  r <- d[d$vintage_id %in% vigentes, , drop = FALSE]
  if (anyDuplicated(r$periodo)) stop("G-6: más de una fila del vintage vigente para un mismo período")
  sin <- setdiff(d$periodo, r$periodo)
  if (length(sin)) stop("G-6: períodos sin fila del vintage vigente: ", paste(utils::head(sin, 5), collapse = ", "))
  r <- r[order(q_a_ind(r$periodo)), , drop = FALSE]
  rownames(r) <- NULL
  r
}
