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
#  10. tablas de evaluación, submuestras y registro del experimento   F4-25, F4-26, F4-28, F4-29
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
  if (identical(rezago, REZAGO_ANUAL_CERRADO)) return(d[anio_de_periodo(d$periodo) <= anio_max_cerrado(o), , drop = FALSE])   # F4-34
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
  if (identical(rezago, REZAGO_ANUAL_CERRADO)) {                                                       # F4-34
    fuera <- anio_de_periodo(d$periodo) > anio_max_cerrado(o)
    if (any(fuera)) {
      stop(sprintf("G-1 filtración anual: %s trae %d período(s) de años no cerrados en el origen %s (primero: %s; admite hasta %d, F4-34)",
                   nombre, sum(fuera), ind_a_q(o), d$periodo[which(fuera)[1]], anio_max_cerrado(o)))
    }
    # Guarda de año completo (ADR-007, captura de UT): un año que el origen trata como cerrado debe
    # traer todos sus períodos (12 meses o 4 trimestres); un año parcial no es un año cerrado.
    esperados <- if (grepl("-M", d$periodo[1], fixed = TRUE)) 12L else 4L
    n_anio <- table(anio_de_periodo(d$periodo))
    parcial <- n_anio[n_anio != esperados]
    if (length(parcial) > 0) {
      stop(sprintf("G-1 año incompleto: %s trae años tratados como cerrados en el origen %s sin sus %d períodos: %s (F4-34, ADR-007)",
                   nombre, ind_a_q(o), esperados, paste0(names(parcial), " (", parcial, ")", collapse = ", ")))
    }
    return(invisible(TRUE))
  }
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
  if (!is.null(m$predecir_densidad) && !is.function(m$predecir_densidad)) stop("modelo ", m$modelo_id, ": predecir_densidad debe ser una función")
  if (!is.null(m$piso_gl) && !(is.logical(m$piso_gl) && length(m$piso_gl) == 1L && !is.na(m$piso_gl))) stop("modelo ", m$modelo_id, ": piso_gl debe ser TRUE o FALSE")
  if (!is.null(m$diagnosticar) && !is.function(m$diagnosticar)) stop("modelo ", m$modelo_id, ": diagnosticar debe ser una función")
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
#' @param densidad si TRUE (F4-33), agrega sd_log_nivel, sd_yoy_pp y sd_qoq_pp: la desviación de la
#'                 densidad gaussiana de los modelos que implementan predecir_densidad(), NA en los
#'                 demás. Con FALSE (el default) la salida es la de siempre, columna por columna.
#' @return data.frame: modelo_id, origen (índice), h, log_nivel_pronosticado[, sd_*]. Si algún modelo implementa
#'         diagnosticar() (Fase 5, B1b), lleva el atributo "diagnosticos": data.frame modelo_id, origen, clave, valor.
correr_backtest <- function(series, modelos, origenes, rezagos = list(), min_obs = 40L,
                            h_max = DISENO_FASE4$h_max, exp_id = "sin_exp", spec = list(), densidad = FALSE) {
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
  diags <- list()

  for (o in origenes) {
    # Recorte una sola vez por origen: todos los modelos ven el mismo conjunto de información.
    info <- stats::setNames(lapply(names(series), function(nm) {
      r <- recortar_a_origen(series[[nm]], o, rezagos[[nm]])
      guarda_recorte(r, o, rezagos[[nm]], nombre = nm)                          # G-1
      if (nm != "objetivo") guarda_borde(r, o, rezagos[[nm]], nombre = nm)      # G-7 (F5-04)
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
      if (isTRUE(m$piso_gl)) guarda_gl(ajuste, m$modelo_id, o)                  # G-8 (F5-03)
      if (is.function(m$diagnosticar)) {                                        # B1b: diagnósticos por origen
        dg <- m$diagnosticar(ajuste)
        if (!is.numeric(dg) || is.null(names(dg)) || any(!nzchar(names(dg))) || anyDuplicated(names(dg))) {
          stop(sprintf("modelo %s en %s: diagnosticar() debe devolver un vector numérico con nombres únicos", m$modelo_id, ind_a_q(o)))
        }
        diags[[length(diags) + 1L]] <- data.frame(modelo_id = m$modelo_id, origen = o, clave = names(dg), valor = unname(dg),
                                                  stringsAsFactors = FALSE)
      }
      sendero <- m$predecir(ajuste, h_max)

      if (!is.numeric(sendero) || length(sendero) != h_max || any(!is.finite(sendero))) {                 # G-3
        stop(sprintf("G-3 modelo %s en %s: predecir() debe devolver %d valores finitos (devolvió %d, %d no finitos)",
                     m$modelo_id, ind_a_q(o), h_max, length(sendero), sum(!is.finite(sendero))))
      }
      if (isTRUE(densidad)) {                                                                              # F4-33
        sds <- if (is.function(m$predecir_densidad)) {
          dens <- m$predecir_densidad(ajuste, h_max)
          validar_densidad(dens, sendero, m$modelo_id, o)
          sd_unidades_densidad(dens$cov)
        } else {
          matrix(NA_real_, h_max, length(COLUMNAS_SD_DENSIDAD), dimnames = list(NULL, COLUMNAS_SD_DENSIDAD))
        }
      }
      if (!identical(digest::digest(series), huella_maestra)) {                                            # G-2
        stop(sprintf("G-2 modelo %s en %s alteró el estado maestro del motor", m$modelo_id, ind_a_q(o)))
      }
      k <- k + 1L
      salida[[k]] <- data.frame(modelo_id = m$modelo_id, origen = o, h = seq_len(h_max),
                                log_nivel_pronosticado = as.numeric(sendero), stringsAsFactors = FALSE)
      if (isTRUE(densidad)) salida[[k]] <- cbind(salida[[k]], as.data.frame(sds))
    }
  }
  res <- do.call(rbind, salida[seq_len(k)])
  rownames(res) <- NULL
  if (length(diags)) attr(res, "diagnosticos") <- do.call(rbind, diags)
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
#' Si `pron` trae las columnas sd_* de correr_backtest(densidad = TRUE), agrega `sd`: la desviación de
#' la densidad gaussiana en la unidad de la fila (NA para los modelos sin densidad).
#' @return data.frame: modelo_id, origen, h, unidad, pronostico, observado, error (observado - pronostico)[, sd].
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
  con_sd <- all(COLUMNAS_SD_DENSIDAD %in% names(pron))
  arma <- function(u, p, ob, s) {
    d <- data.frame(modelo_id = pron$modelo_id, origen = pron$origen, h = pron$h,
                    unidad = u, pronostico = p, observado = ob, error = ob - p, stringsAsFactors = FALSE)
    if (con_sd) d$sd <- s
    d
  }
  res <- rbind(arma("yoy_pp", pron$yoy_pp_pronosticado, obs_yoy, pron$sd_yoy_pp),
               arma("qoq_pp", pron$qoq_pp_pronosticado, obs_qoq, pron$sd_qoq_pp),
               arma("log_nivel", pron$log_nivel_pronosticado, obs_log, pron$sd_log_nivel))
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
#' Si `err` trae `sd` (F4-33), agrega cobertura_80, cobertura_95 y crps para los modelos con densidad;
#' sin `sd`, la salida es la de siempre.
metricas_por_horizonte <- function(err) {
  con_sd <- "sd" %in% names(err)
  g <- split(err, list(err$modelo_id, err$h, err$unidad), drop = TRUE)
  res <- do.call(rbind, lapply(g, function(d) {
    e <- d$error; n <- length(e); h <- d$h[1]
    r <- data.frame(modelo_id = d$modelo_id[1], h = h, unidad = d$unidad[1], n_pares = n,
                    rmse = sqrt(mean(e^2)), mae = mean(abs(e)), sesgo = mean(e),
                    sesgo_ee_nw = sqrt(varianza_nw(e, h - 1L) / n), stringsAsFactors = FALSE)
    if (con_sd) r <- cbind(r, as.data.frame(as.list(calibracion_densidad(e, d$sd))))
    r
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
# Gramática: <ventana>|origen=<v>|grupo=<v>|vintage=<v>|sa=<v>|perdida=<v>[|conjunto=<nombre>@<sha8>]
# Los seis primeros campos son obligatorios, en ese orden, con los valores declarados en TOKEN_DOMINIOS.
# El séptimo, opcional, identifica el corte de vintages contra el que corrió el experimento (F5-16,
# decisión C-4): nombre del CSV sin extensión y los 8 primeros hex del sha256 sin CR. Los tokens de
# Fase 4 (seis campos) siguen siendo válidos.
TOKEN_PATRON_CONJUNTO <- "^[A-Za-z0-9_.-]+@[0-9a-f]{8}$"

TOKEN_DOMINIOS <- list(
  ventana = c("expansiva", "rodante92", "homogenea2005"),   # homogenea2005: R2, F4-27
  origen  = c("ultimo_estimado"),
  grupo   = c("G1", "G2", "G3"),
  vintage = c("revision_vigente", "real_time"),
  sa      = c("reestimado_en_origen", "l3_unico"),
  perdida = c("yoy_pp", "qoq_pp", "log_nivel")
)

construir_token <- function(ventana, grupo, vintage, sa, perdida, origen = "ultimo_estimado", conjunto = NULL) {
  tok <- sprintf("%s|origen=%s|grupo=%s|vintage=%s|sa=%s|perdida=%s", ventana, origen, grupo, vintage, sa, perdida)
  if (!is.null(conjunto)) tok <- paste0(tok, "|conjunto=", conjunto)
  validar_token(tok)
  tok
}

#' Valida un token y lo devuelve descompuesto en lista; falla ante cualquier desvío de la gramática.
validar_token <- function(tok) {
  if (!is.character(tok) || length(tok) != 1L || is.na(tok)) stop("token: debe ser un único string")
  partes <- strsplit(tok, "|", fixed = TRUE)[[1]]
  claves <- names(TOKEN_DOMINIOS)
  conjunto <- NULL
  if (length(partes) == length(claves) + 1L) {                                   # campo opcional (C-4)
    kv <- strsplit(partes[length(partes)], "=", fixed = TRUE)[[1]]
    if (length(kv) != 2L || kv[1] != "conjunto") stop(sprintf("token: el campo %d solo puede ser `conjunto=...`, vino `%s`", length(partes), partes[length(partes)]))
    if (!grepl(TOKEN_PATRON_CONJUNTO, kv[2])) stop(sprintf("token: conjunto mal formado: `%s` (se espera <nombre>@<8 hex>)", kv[2]))
    conjunto <- kv[2]
    partes <- partes[-length(partes)]
  }
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
  if (!is.null(conjunto)) valores$conjunto <- conjunto
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
#   F4-15  MCS: estadístico T_max, α = 0,10, bootstrap estacionario con bloque medio
#          max(h, ceiling(n^(1/3))), B = 5000 en las corridas sobre L3.
#   F4-16  DM/HLN: varianza rectangular de h-1 rezagos; si sale <= 0, respaldo Bartlett con los
#          mismos rezagos, registrado en la columna `varianza`.
#   F4-17  GW: instrumentos (1, d_{t-h}), χ²(2), varianza HAC de Bartlett con h-1 rezagos.

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
  if (!is.finite(v) || v <= 0) { v <- varianza_nw(d, h - 1L); tipo <- "bartlett_respaldo" }       # F4-16
  if (!is.finite(v) || v <= 0) stop("DM/HLN: varianza de largo plazo no positiva también con Bartlett")
  est <- sqrt(k2) * mean(d) / sqrt(v / n)
  list(estadistico = est, p_valor = 2 * stats::pt(-abs(est), df = n - 1L), n_pares = n,
       varianza = tipo, media_diferencial = mean(d))
}

#' Giacomini-White (2006), test condicional con instrumentos (1, d_{t-h}) (F4-17).
#' d_{t-h} es el diferencial del target h trimestres anterior: ya observado en el origen de t.
#' @return list(estadistico, p_valor (χ² con 2 gl), n_pares (usados), media_diferencial)
prueba_gw <- function(e1, e2, h) {
  d <- .diferencial(e1, e2); n <- length(d); h <- as.integer(h)
  m <- n - h
  if (m < 5L) stop(sprintf("GW: con n = %d y h = %d quedan %d pares útiles; mínimo 5", n, h, m))
  t_ <- (h + 1L):n
  # E2-2 (2026-10-08, después del congelamiento; decisión delegada al agente): si el diferencial es idénticamente cero
  # (pronósticos iguales al benchmark), la prueba es degenerada como en DM/HLN (p = 1); si el instrumento d_{t-h} es
  # idénticamente cero en los pares útiles, o si Ω es singular por otra causa (p. ej., d_{t-h} · d_t nulo en todos los
  # pares útiles), la prueba condicional no está definida: NA, marcado en `varianza`.
  if (all(d == 0)) return(list(estadistico = 0, p_valor = 1, n_pares = m, media_diferencial = 0, varianza = "degenerada"))
  if (all(d[t_ - h] == 0)) return(list(estadistico = NA_real_, p_valor = NA_real_, n_pares = m, media_diferencial = mean(d),
                                       varianza = "instrumento_degenerado"))
  Z <- cbind(1, d[t_ - h]) * d[t_]
  zbar <- colMeans(Z); Zc <- sweep(Z, 2L, zbar)
  Om <- crossprod(Zc) / m
  if (h > 1L) for (l in seq_len(min(h - 1L, m - 1L))) {
    G <- crossprod(Zc[(l + 1L):m, , drop = FALSE], Zc[1:(m - l), , drop = FALSE]) / m
    Om <- Om + (1 - l / h) * (G + t(G))
  }
  inv <- tryCatch(solve(Om), error = function(e) NULL)             # E2-2: Ω singular → prueba no definida, NA marcado
  if (is.null(inv)) return(list(estadistico = NA_real_, p_valor = NA_real_, n_pares = m, media_diferencial = mean(d),
                                varianza = "singular"))
  est <- as.numeric(m * t(zbar) %*% inv %*% zbar)
  list(estadistico = est, p_valor = stats::pchisq(est, df = 2L, lower.tail = FALSE), n_pares = m,
       media_diferencial = mean(d), varianza = "bartlett")
}

#' Longitud media de bloque del bootstrap del MCS (F4-15).
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

#' Model Confidence Set de Hansen, Lunde y Nason (2011), estadístico T_max (F4-15).
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
# motor_backtesting.R porque ejecuta el binario de X-13 (en CI, solo sobre insumos sintéticos: V12). F4-09b fija tres
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

# ---------------------------------------------------------------------------------------------
# 10. Tablas de evaluación, submuestras y registro del experimento (bloque E)
# ---------------------------------------------------------------------------------------------
#
# Puras, para que el orquestador sea solo lectura y escritura y CI ejercite el cómputo con datos
# sintéticos. Decisiones de Harold del 2026-09-25 (registro: doc/metodologia/decisiones_fase4.md).

#' Últimos `n` períodos de una serie ya recortada al origen (R1, F4-26: ventana rodante de 92).
recortar_ventana_rodante <- function(d, n = 92L) {
  if (nrow(d) < n) stop(sprintf("ventana rodante: la serie tiene %d obs, se necesitan %d", nrow(d), n))
  r <- d[(nrow(d) - n + 1L):nrow(d), , drop = FALSE]
  rownames(r) <- NULL
  r
}

#' Contraste de cambio en la precisión relativa entre dos submuestras de targets (R3, F4-28).
#' Regresión de d_t = e1² - e2² sobre (1, D_post) por MCO, con varianza HAC de Bartlett de h-1
#' rezagos (la misma ventana que GW, F4-17) y t con n-2 gl sobre el coeficiente de D_post. Un
#' coeficiente positivo dice que el modelo 2 mejoró respecto del 1 en la submuestra posterior.
#' @param post vector 0/1 alineado con los errores (1 = target en la submuestra posterior).
prueba_cambio_diferencial <- function(e1, e2, post, h) {
  d <- .diferencial(e1, e2); n <- length(d); h <- as.integer(h)
  if (length(post) != n) stop("cambio de diferencial: `post` y los errores tienen largos distintos")
  if (anyNA(post) || !all(post %in% c(0, 1))) stop("cambio de diferencial: `post` debe ser 0/1")
  n1 <- sum(post); n0 <- n - n1
  if (n0 < 3L || n1 < 3L) stop(sprintf("cambio de diferencial: se necesitan 3 pares por submuestra (pre %d, post %d)", n0, n1))
  X <- cbind(1, as.numeric(post))
  XtX_inv <- solve(crossprod(X))
  b <- as.numeric(XtX_inv %*% crossprod(X, d))
  u <- as.numeric(d - X %*% b)
  Z <- X * u
  S <- crossprod(Z) / n
  L <- h - 1L
  if (L > 0L) for (l in seq_len(min(L, n - 1L))) {
    G <- crossprod(Z[(l + 1L):n, , drop = FALSE], Z[1:(n - l), , drop = FALSE]) / n
    S <- S + (1 - l / (L + 1)) * (G + t(G))
  }
  V <- n * XtX_inv %*% S %*% XtX_inv
  ee <- sqrt(V[2, 2])
  if (!is.finite(ee) || ee <= 0) stop("cambio de diferencial: error estándar HAC no positivo")
  est <- b[2] / ee
  list(media_pre = b[1], cambio_post = b[2], ee_hac = ee, estadistico = est,
       p_valor = 2 * stats::pt(-abs(est), df = n - 2L), n_pre = n0, n_post = n1)
}

#' B2-9 (decisión de Harold, 2026-10-07): modelos con pérdidas idénticas en una celda. Devuelve, por columna, el
#' modelo_id del primer modelo (en el orden de las columnas) con exactamente las mismas pérdidas, o NA si la columna
#' es su propio representante. La igualdad es exacta (identical sobre los valores, sin nombres): dos modelos que
#' pronostican lo mismo por el mismo camino de cálculo, como MULT.VECM.G1 con r = 0 y MULT.VAR_DIF.G1, coinciden bit a
#' bit.
modelos_identicos <- function(perdidas) {
  nm <- colnames(perdidas); m <- ncol(perdidas)
  rep_ <- stats::setNames(rep(NA_character_, m), nm)
  for (j in seq_len(m)) if (is.na(rep_[j]) && j < m) for (k in (j + 1L):m) {
    if (is.na(rep_[k]) && identical(unname(perdidas[, j]), unname(perdidas[, k]))) rep_[k] <- nm[j]
  }
  rep_
}

#' MCS T_max con deduplicación de pérdidas idénticas (B2-9): corre mcs_tmax() sobre un representante de cada grupo
#' de modelos idénticos y todos los del grupo comparten su p-valor, su pertenencia y su orden de eliminación. Agrega
#' la columna `identico_a` (modelo_id del representante; "" si no tiene duplicados). Sin duplicados, las columnas
#' de mcs_tmax() son las mismas, bit a bit. Si todos los modelos son idénticos entre sí, el conjunto es trivial: todos
#' quedan con p_mcs = 1.
mcs_tmax_dedup <- function(perdidas, h, alpha = 0.10, B = 5000L, semilla, bloque = NULL, indices = NULL) {
  if (!is.matrix(perdidas) || is.null(colnames(perdidas))) stop("MCS: `perdidas` debe ser matriz con nombres de columna")
  if (ncol(perdidas) < 2L) stop("MCS: se necesitan al menos 2 modelos")
  ide <- modelos_identicos(perdidas); unicos <- is.na(ide)
  if (sum(unicos) < 2L) {
    res_u <- data.frame(modelo_id = colnames(perdidas)[unicos], p_mcs = 1, en_mcs = TRUE, orden_eliminacion = NA_integer_,
                        stringsAsFactors = FALSE)
    attr(res_u, "alpha") <- alpha; attr(res_u, "B") <- B
    attr(res_u, "bloque") <- if (is.null(bloque)) bloque_mcs(nrow(perdidas), h) else bloque
  } else {
    res_u <- mcs_tmax(perdidas[, unicos, drop = FALSE], h, alpha = alpha, B = B, semilla = semilla, bloque = bloque, indices = indices)
  }
  i <- match(ifelse(unicos, colnames(perdidas), ide), res_u$modelo_id)
  res <- data.frame(modelo_id = colnames(perdidas), p_mcs = res_u$p_mcs[i], en_mcs = res_u$en_mcs[i],
                    orden_eliminacion = res_u$orden_eliminacion[i], identico_a = ifelse(unicos, "", unname(ide)),
                    stringsAsFactors = FALSE)
  for (a in c("alpha", "B", "bloque")) attr(res, a) <- attr(res_u, a)
  res
}

#' Métricas, pruebas por pares contra el benchmark y MCS de un experimento sobre un conjunto de
#' errores (muestra completa o submuestra de targets). `err` es la salida de calcular_errores(),
#' posiblemente filtrada por target. Devuelve list(metricas, pruebas, mcs).
#' @param gw         si TRUE agrega Giacomini-White por par (R1, F4-17 y F4-26).
#' @param semilla_mcs función h -> semilla entera del MCS.
#' @param marcar_identicos si TRUE (experimentos F5_G*, B2-9) el MCS deduplica pérdidas idénticas y mcs lleva la
#'                   columna `identico_a`; si FALSE (Fase 4 y F5_REPRO_*) se usa mcs_tmax() tal cual, para que esas
#'                   tablas no cambien ni un bit (con pérdidas idénticas al final de la eliminación sigue deteniéndose).
evaluar_errores <- function(err, ids, exp_id, grupo, perdida, semilla_mcs, benchmark = "BENCH.RW_SIN_DERIVA",
                            horizontes = DISENO_FASE4$horizontes, gw = FALSE, alpha = 0.10, B = 5000L,
                            marca_h_largo = "distorsion_tamano_documentada", marcar_identicos = FALSE) {
  err <- err[order(err$unidad, err$modelo_id, err$h, err$origen), ]
  met <- agregar_rmse_relativo(metricas_por_horizonte(err), benchmark)
  met <- data.frame(exp_id = exp_id, modelo_id = met$modelo_id, grupo = grupo, h = met$h, unidad = met$unidad,
                    n_pares = met$n_pares, rmse = met$rmse, mae = met$mae, rmse_relativo = met$rmse_relativo,
                    sesgo = met$sesgo, sesgo_ee_nw = met$sesgo_ee_nw,
                    cobertura_80 = if (is.null(met$cobertura_80)) NA_real_ else met$cobertura_80,     # F4-33
                    cobertura_95 = if (is.null(met$cobertura_95)) NA_real_ else met$cobertura_95,
                    crps = if (is.null(met$crps)) NA_real_ else met$crps, stringsAsFactors = FALSE)
  prim <- err[err$unidad == perdida, ]
  pruebas <- list(); mcs <- list()
  for (h in horizontes) {
    eh <- prim[prim$h == h, ]
    orig_ref <- sort(unique(eh$origen))
    E <- matrix(NA_real_, length(orig_ref), length(ids), dimnames = list(orig_ref, ids))
    for (id in ids) {
      d <- eh[eh$modelo_id == id, ]; d <- d[order(d$origen), ]
      if (!identical(as.integer(d$origen), as.integer(orig_ref))) stop("evaluar_errores: orígenes desalineados entre modelos en h = ", h, " (", id, ")")
      E[, id] <- d$error
    }
    marca <- if (h >= 4L) marca_h_largo else ""
    for (id in setdiff(ids, benchmark)) {
      r <- prueba_dm_hln(E[, benchmark], E[, id], h)
      pruebas[[length(pruebas) + 1L]] <- data.frame(exp_id = exp_id, grupo = grupo, h = h, unidad = perdida,
        prueba = "dm_hln", modelo_a = benchmark, modelo_b = id, estadistico = r$estadistico, p_valor = r$p_valor,
        n_pares = r$n_pares, varianza = r$varianza, media_diferencial = r$media_diferencial, marca_tamano = marca,
        stringsAsFactors = FALSE)
      if (isTRUE(gw)) {
        g <- prueba_gw(E[, benchmark], E[, id], h)
        pruebas[[length(pruebas) + 1L]] <- data.frame(exp_id = exp_id, grupo = grupo, h = h, unidad = perdida,
          prueba = "gw", modelo_a = benchmark, modelo_b = id, estadistico = g$estadistico, p_valor = g$p_valor,
          n_pares = g$n_pares, varianza = g$varianza, media_diferencial = g$media_diferencial,
          marca_tamano = "tamano_no_verificado", stringsAsFactors = FALSE)
      }
    }
    semilla <- semilla_mcs(h)
    res <- if (isTRUE(marcar_identicos)) mcs_tmax_dedup(E^2, h, alpha = alpha, B = B, semilla = semilla)   # B2-9
           else mcs_tmax(E^2, h, alpha = alpha, B = B, semilla = semilla)                                   # Fase 4 y F5_REPRO_*, sin cambios
    fila <- data.frame(exp_id = exp_id, grupo = grupo, h = h, unidad = perdida,
      modelo_id = res$modelo_id, p_mcs = res$p_mcs, en_mcs = res$en_mcs, orden_eliminacion = res$orden_eliminacion,
      alpha = attr(res, "alpha"), replicas = attr(res, "B"), bloque = attr(res, "bloque"), semilla = semilla,
      marca_tamano = marca, stringsAsFactors = FALSE)
    if (isTRUE(marcar_identicos)) fila$identico_a <- res$identico_a
    mcs[[length(mcs) + 1L]] <- fila
  }
  list(metricas = met, pruebas = do.call(rbind, pruebas), mcs = do.call(rbind, mcs))
}

#' Submuestras de targets de R3 (F4-28: <= 2019-Q4 / >= 2020-Q1) y R4 (F4-29: sin 2020; sin 2020
#' ni 2021). Devuelve una lista nombrada de funciones índice-de-target -> lógico (TRUE = se conserva).
SUBMUESTRAS_FASE4 <- list(
  pre2020       = function(t) t <= q_a_ind("2019-Q4"),
  post2020      = function(t) t >= q_a_ind("2020-Q1"),
  sin_2020      = function(t) t < q_a_ind("2020-Q1") | t > q_a_ind("2020-Q4"),
  sin_2020_2021 = function(t) t < q_a_ind("2020-Q1") | t > q_a_ind("2021-Q4")
)

#' Filas de catalogos/07_experimentos.csv para un experimento (F4-25): una por modelo, con
#' exp_id compuesto `<exp_id>__<modelo_id>`. Valida el token y falla ante campos vacíos.
construir_filas_experimento <- function(exp_id, modelos_ids, vintage_ids, muestra_inicio, muestra_fin, token,
                                        semillas, commit_hash, fecha_corrida, entorno,
                                        horizontes = DISENO_FASE4$horizontes) {
  validar_token(token)
  if (length(semillas) != length(modelos_ids)) stop("registro: una semilla por modelo")
  for (v in list(exp_id, commit_hash, entorno, muestra_inicio, muestra_fin)) {
    if (length(v) != 1L || is.na(v) || !nzchar(v)) stop("registro: campo obligatorio vacío")
  }
  if (!grepl("^[0-9a-f]{40}$", commit_hash)) stop("registro: commit_hash mal formado: ", commit_hash)
  data.frame(exp_id = paste0(exp_id, "__", modelos_ids), modelo_id = modelos_ids,
             vintage_id = paste(sort(unique(vintage_ids)), collapse = " + "),
             muestra_inicio = muestra_inicio, muestra_fin = muestra_fin, esquema_validacion = token,
             horizontes = paste(horizontes, collapse = ","), semilla = as.integer(semillas),
             commit_hash = commit_hash, fecha_corrida = format(as.Date(fecha_corrida), "%Y-%m-%d"),
             entorno = entorno, ruta_resultados = paste0("data/L4_experiments/", exp_id, "/"),
             stringsAsFactors = FALSE)
}

#' Reemplaza en el registro existente las filas de los experimentos que se volvieron a correr y
#' agrega las nuevas; el resultado queda ordenado por exp_id y sin duplicados.
actualizar_registro_experimentos <- function(existente, nuevas) {
  if (!identical(names(existente), names(nuevas))) stop("registro: las columnas no coinciden con 07_experimentos.csv")
  prefijo <- function(x) sub("__.*$", "", x)
  quedan <- existente[!prefijo(existente$exp_id) %in% unique(prefijo(nuevas$exp_id)), , drop = FALSE]
  r <- rbind(quedan, nuevas)
  if (anyDuplicated(r$exp_id)) stop("registro: exp_id duplicado")
  r <- r[order(r$exp_id), , drop = FALSE]
  rownames(r) <- NULL
  r
}

# ---------------------------------------------------------------------------------------------
# 11. Densidad predictiva gaussiana (F4-33, remediación de la auditoría de Fase 4, hallazgo I2a)
# ---------------------------------------------------------------------------------------------
#
# Extensión OPCIONAL del contrato de modelo: predecir_densidad(ajuste, h) devuelve
# list(media, cov), la densidad gaussiana conjunta del sendero en log-nivel: `media` (longitud h)
# es el mismo sendero de predecir() y `cov` (h x h) su matriz de covarianzas. Con la conjunta, la
# densidad de cualquier unidad lineal del sendero es gaussiana: yoy (h > 4) y qoq (h > 1) restan
# dos puntos del mismo sendero y necesitan la covarianza, no solo la marginal. La incertidumbre de
# parámetros no entra (densidad plug-in); se declara en F4-33. Los modelos sin predecir_densidad
# quedan con cobertura_80, cobertura_95 y crps vacías (protocolo §3.4).

COLUMNAS_SD_DENSIDAD <- c("sd_log_nivel", "sd_yoy_pp", "sd_qoq_pp")

#' Valida la densidad de un modelo en un origen; falla con stop() ante cualquier forma inválida.
validar_densidad <- function(dens, sendero, modelo_id = "?", o = NA_integer_) {
  donde <- sprintf("densidad mal formada: modelo %s en %s: ", modelo_id, if (is.na(o)) "?" else ind_a_q(o))
  h <- length(sendero)
  if (!is.list(dens) || !all(c("media", "cov") %in% names(dens))) stop(donde, "se espera list(media, cov)")
  mu <- dens$media; S <- dens$cov
  if (!is.numeric(mu) || length(mu) != h || any(!is.finite(mu))) stop(donde, "`media` debe tener ", h, " valores finitos")
  if (max(abs(mu - sendero)) > 1e-8 * max(1, abs(sendero))) stop(donde, "`media` no coincide con el sendero de predecir()")
  if (!is.matrix(S) || !is.numeric(S) || !identical(dim(S), c(h, h)) || any(!is.finite(S))) stop(donde, "`cov` debe ser una matriz ", h, "x", h, " finita")
  esc <- max(abs(S))
  if (max(abs(S - t(S))) > 1e-10 * esc) stop(donde, "`cov` no es simétrica")
  if (any(diag(S) <= 0)) stop(donde, "`cov` tiene varianzas no positivas")
  if (min(eigen((S + t(S)) / 2, symmetric = TRUE, only.values = TRUE)$values) < -1e-10 * esc) stop(donde, "`cov` no es semidefinida positiva")
  invisible(TRUE)
}

#' Desviaciones de la densidad en las tres unidades del motor (F4-04), a partir de la covarianza del
#' sendero en log-nivel. yoy: la base es observada si h <= 4 y pronosticada si h > 4; qoq: observada
#' si h = 1. Misma convención que derivar_unidades().
sd_unidades_densidad <- function(S) {
  h <- nrow(S); j <- seq_len(h)
  v_dif <- function(j, k) S[cbind(j, j)] + S[cbind(k, k)] - 2 * S[cbind(j, k)]
  v_yoy <- ifelse(j <= 4L, diag(S), v_dif(j, pmax(j - 4L, 1L)))
  v_qoq <- ifelse(j == 1L, diag(S), v_dif(j, pmax(j - 1L, 1L)))
  r <- cbind(sqrt(diag(S)), 100 * sqrt(pmax(v_yoy, 0)), 100 * sqrt(pmax(v_qoq, 0)))
  if (any(r <= 0)) stop("sd_unidades_densidad: desviación nula en alguna unidad")
  dimnames(r) <- list(NULL, COLUMNAS_SD_DENSIDAD)
  r
}

#' Covarianza del sendero a partir de los pesos C (h x h, triangular inferior): C[j, k] es el
#' coeficiente de la innovación del período o+k en el error de log-nivel de o+j.
cov_desde_pesos <- function(C, sigma2) sigma2 * C %*% t(C)

#' Pesos C de un AR(p) en Δy (p = 0: paseo aleatorio): psi_0 = 1, psi_m = Σ φ_i psi_{m-i}, y el error
#' de log-nivel en o+j acumula Ψ_{j-k} = Σ_{m<=j-k} psi_m sobre la innovación de o+k.
pesos_ar_dy <- function(phi, h) {
  p <- length(phi); psi <- numeric(h); psi[1] <- 1
  if (h > 1L) for (m in 2:h) {
    i <- seq_len(min(p, m - 1L))
    psi[m] <- if (length(i)) sum(phi[i] * psi[m - i]) else 0
  }
  Psi <- cumsum(psi)
  C <- matrix(0, h, h)
  for (jj in seq_len(h)) for (k in seq_len(jj)) C[jj, k] <- Psi[jj - k + 1L]
  C
}

#' Pesos C de un ETS(A,A,N): e_{o+j} + Σ_{k<j} (α + β (j - k)) e_{o+k}.
pesos_ets_aan <- function(alpha, beta, h) {
  C <- diag(h)
  for (jj in seq_len(h)) for (k in seq_len(jj - 1L)) C[jj, k] <- alpha + beta * (jj - k)
  C
}

#' CRPS de una gaussiana N(mu, sigma²) en y, forma cerrada (Gneiting y Raftery, 2007).
crps_normal <- function(y, mu, sigma) {
  z <- (y - mu) / sigma
  sigma * (z * (2 * stats::pnorm(z) - 1) + 2 * stats::dnorm(z) - 1 / sqrt(pi))
}

#' Cobertura empírica al 80 % y 95 % y CRPS medio de un conjunto de errores (observado - media) con
#' sus desviaciones. NA si falta la densidad en algún par: no se imputa (protocolo §3.4).
calibracion_densidad <- function(error, sd) {
  if (is.null(sd) || !length(sd) || anyNA(sd)) return(c(cobertura_80 = NA_real_, cobertura_95 = NA_real_, crps = NA_real_))
  if (length(sd) != length(error) || any(sd <= 0)) stop("calibracion_densidad: `sd` inválida")
  c(cobertura_80 = mean(abs(error) <= stats::qnorm(0.90) * sd),
    cobertura_95 = mean(abs(error) <= stats::qnorm(0.975) * sd),
    crps = mean(crps_normal(error, 0, sd)))
}

# ---------------------------------------------------------------------------------------------
# 12. Rezago de publicación de las predictoras (F4-34; remediación del hallazgo I2b; UT, F5-04)
# ---------------------------------------------------------------------------------------------
#
# Una sola fuente: el bloque `rezago_publicacion` de
# doc/metodologia/reportes_fase4/evidencia_insumos_fase4.csv, versionado y regenerable con
# scripts/evidencia_insumos_fase4.R. Dos métricas en días: `rezago_dias_mediano` (medido sobre el
# calendario de divulgación del BCR) y `rezago_dias_supuesto` (declarado, sin medición). Las series
# trimestrales (agregados T003-T011) heredan el rezago de su fuente mensual.
#
# UT (F5-04, decidido por Harold el 2026-10-05) lleva un rezago SUPUESTO de 30 días, como cualquier serie
# mensual: entra hasta el último mes con fin(m) + 30 <= fin(o) + 92. No hay fechas reales de publicación
# de UT para 2013-2025, y lo observado en 2026 son cotas superiores (ver el script de evidencia). Esto
# reemplaza para Fase 5 la regla «UT solo años cerrados» de F4-34.2 (opción C, 2026-09-29).
#
# La rama anual (REZAGO_ANUAL_CERRADO, anio_de_periodo(), anio_max_cerrado()) se conserva como mecanismo
# para series de grano anual: el año `a` entra solo desde el origen (a+1)-Q1, decidido por el período de
# la observación y el origen y no por una fecha de publicación sintética. Hoy ninguna serie la usa.

REZAGO_ANUAL_CERRADO <- "anual_cerrado"

#' Año de un período "AAAA-Mmm", "AAAA-Qq" o "AAAA".
anio_de_periodo <- function(periodo) {
  a <- suppressWarnings(as.integer(substr(periodo, 1L, 4L)))
  if (anyNA(a) || any(!grepl("^\\d{4}($|-M\\d{2}$|-Q[1-4]$)", periodo))) stop("anio_de_periodo: período mal formado")
  a
}

#' Último año cerrado que admite el origen `o` (índice trimestral) bajo F4-34: el anterior al del origen.
anio_max_cerrado <- function(o) as.integer(o) %/% 4L - 1L

RUTA_EVIDENCIA_INSUMOS <- c("doc", "metodologia", "reportes_fase4", "evidencia_insumos_fase4.csv")

# Métricas del bloque `rezago_publicacion` que declaran un rezago en días: la medida y la supuesta.
METRICAS_REZAGO_DIAS <- c("rezago_dias_mediano", "rezago_dias_supuesto")

.clave_rezago <- function(id) gsub("[^A-Za-z0-9]", "_", sub("\\.Q$", ".M", id))

#' Rezago en días de cada serie de `ids` (series_master_id), leído de la evidencia de insumos (métricas de
#' METRICAS_REZAGO_DIAS); para las de grano anual, REZAGO_ANUAL_CERRADO. Falla si una serie no tiene
#' rezago declarado o si lo tiene de las dos maneras a la vez.
rezagos_predictoras <- function(ids, evidencia = NULL) {
  if (is.null(evidencia)) evidencia <- utils::read.csv(do.call(here::here, as.list(RUTA_EVIDENCIA_INSUMOS)),
                                                       stringsAsFactors = FALSE, na.strings = "")
  r <- evidencia[evidencia$bloque == "rezago_publicacion", , drop = FALSE]
  anual <- r$item[r$metrica == "grano_de_disponibilidad" & r$valor == "anual"]
  med <- r[r$metrica %in% METRICAS_REZAGO_DIAS, , drop = FALSE]
  tabla <- stats::setNames(as.integer(med$valor), .clave_rezago(med$item))
  if (anyNA(tabla) || anyDuplicated(names(tabla))) stop("rezagos_predictoras: la evidencia trae rezagos inválidos o duplicados")
  ambos <- intersect(.clave_rezago(anual), names(tabla))
  if (length(ambos)) stop("rezagos_predictoras: ", paste(ambos, collapse = ", "), " declara grano anual y rezago en días a la vez")
  res <- lapply(ids, function(id) {
    k <- .clave_rezago(id)
    if (k %in% .clave_rezago(anual)) return(REZAGO_ANUAL_CERRADO)                                     # F4-34
    if (!k %in% names(tabla)) stop("rezagos_predictoras: ", id, " no tiene rezago de publicación declarado en la evidencia de insumos")
    tabla[[k]]
  })
  stats::setNames(res, ids)
}

#' Rezagos de las predictoras que requiere un modelo, con el formato de `rezagos` de correr_backtest().
#' El objetivo no lleva rezago.
rezagos_modelo <- function(modelo, evidencia = NULL) {
  pred <- setdiff(modelo$requiere, "objetivo")
  if (!length(pred)) return(list())
  rezagos_predictoras(pred, evidencia)
}

# ---------------------------------------------------------------------------------------------
# 13. Predictoras por grupo, alineación con el origen y guardas de Fase 5 (F4-05, F5-03, F5-04)
# ---------------------------------------------------------------------------------------------
#
# Composición de predictoras de cada grupo de comparación (F4-05): la misma que usa
# scripts/evidencia_insumos_fase4.R para calcular el primer origen de cada grupo, sin el objetivo; una
# prueba compara las dos. Se declara por familia; la frecuencia (.Q para los modelos trimestrales, .M
# para MIDAS y puente) la elige cada modelo.
GRUPOS_PREDICTORAS <- list(
  G1 = c("BCR.REMESAS.NOM.NSA", "BCR.EXPORT_FOB.NOM.NSA")
)
GRUPOS_PREDICTORAS$G2 <- c(GRUPOS_PREDICTORAS$G1, "BCR.ITCER.IDX.NSA", "UT.DEMANDA_ELEC.GWH.NSA", "BCR.IVAE.VOL.SA", "BCR.IPM.IDX.NSA")
GRUPOS_PREDICTORAS$G3 <- c(GRUPOS_PREDICTORAS$G2, "BCR.IPP.IDX.NSA", "BCR.REMESAS.REAL.NSA")

#' series_master_id de las predictoras de un grupo en la frecuencia pedida ("Q" o "M").
predictoras_grupo <- function(grupo, frecuencia = c("Q", "M")) {
  frecuencia <- match.arg(frecuencia)
  if (length(grupo) != 1L || !grupo %in% names(GRUPOS_PREDICTORAS)) stop("predictoras_grupo: grupo no declarado: ", paste(grupo, collapse = ", "))
  paste0(GRUPOS_PREDICTORAS[[grupo]], ".", frecuencia)
}

# B1b-2 (decisión de Harold, 2026-10-05): en G3 los modelos SIN penalización (ARIMAX, VAR, VECM, puente, U-MIDAS)
# llevan una sola remesa, la nominal (B1b-1, por parsimonia: las reales solo agregan la inflación del IPC con un
# coeficiente impreciso). BVAR, regularizados y árboles reciben todas las predictoras del grupo.
PREDICTORAS_EXCLUIDAS_NO_PENALIZADOS <- list(G1 = character(0), G2 = character(0), G3 = "BCR.REMESAS.REAL.NSA")

#' series_master_id de las predictoras de un grupo para los modelos sin penalización (B1b-2).
predictoras_no_penalizadas <- function(grupo, frecuencia = c("Q", "M")) {
  frecuencia <- match.arg(frecuencia)
  todas <- predictoras_grupo(grupo, frecuencia)
  todas[!sub("\\.[QM]$", "", todas) %in% PREDICTORAS_EXCLUIDAS_NO_PENALIZADOS[[grupo]]]
}

#' Último período (índice) que el calendario admite en el origen `o` para una serie con `rezago` en días:
#' el máximo `p` con fin(p) + rezago <= fecha_corte_origen(o). No mira datos: es la regla de §2.3.
ultimo_admitido <- function(o, rezago, mensual, rezago_pib = REZAGO_PIB_DIAS) {
  if (!is.numeric(rezago) || length(rezago) != 1L || is.na(rezago)) stop("ultimo_admitido: el rezago debe ser un número de días")
  corte <- fecha_corte_origen(o, rezago_pib)
  if (mensual) {
    ult_mes_o <- as.integer(o) %/% 4L * 12L + (as.integer(o) %% 4L) * 3L + 2L
    cand <- ult_mes_o + (-36L:12L)
    ok <- fin_de_mes_ind(cand) + as.integer(rezago) <= corte
  } else {
    cand <- as.integer(o) + (-12L:4L)
    ok <- fin_de_trimestre_ind(cand) + as.integer(rezago) <= corte
  }
  if (!any(ok)) stop("ultimo_admitido: ningún período admitido en ", ind_a_q(o), " con rezago ", rezago)
  max(cand[ok])
}

#' Alineación de una predictora con el origen en todos los orígenes de un grupo (F5-04, parte 1). Para
#' una serie trimestral devuelve `desfase` = trimestres entre el origen y el último trimestre admitido
#' (0 = entra hasta `o`, que es lo que exige F5-04 a los modelos trimestrales); para una mensual,
#' `desfase` = meses del trimestre `o+1` admitidos (el borde irregular que usan MIDAS y puente). Falla si
#' el desfase no es el mismo en todos los orígenes del grupo: la regla tiene que ser uniforme.
rezago_alineacion <- function(serie_id, grupo, evidencia = NULL, rezago_pib = REZAGO_PIB_DIAS) {
  rez <- rezagos_predictoras(serie_id, evidencia)[[1]]
  if (identical(rez, REZAGO_ANUAL_CERRADO)) stop("rezago_alineacion: ", serie_id, " es de grano anual; la alineación en días no aplica")
  mensual <- grepl("\\.M$", serie_id)
  if (!mensual && !grepl("\\.Q$", serie_id)) stop("rezago_alineacion: ", serie_id, " no termina en .M ni en .Q")
  des <- vapply(origenes_grupo(grupo), function(o) {
    u <- ultimo_admitido(o, rez, mensual, rezago_pib)
    if (mensual) u - (as.integer(o) %/% 4L * 12L + (as.integer(o) %% 4L) * 3L + 2L) else as.integer(o) - u
  }, integer(1))
  if (length(unique(des)) != 1L) {
    stop(sprintf("rezago_alineacion: %s no tiene un desfase uniforme en los orígenes de %s (%s)", serie_id, grupo,
                 paste(sort(unique(des)), collapse = ", ")))
  }
  list(serie_id = serie_id, grupo = grupo, frecuencia = if (mensual) "M" else "Q", rezago_dias = as.integer(rez),
       desfase = unique(des))
}

#' G-7 (F5-04): completitud del borde. Después del recorte, una predictora con rezago en días debe llegar
#' exactamente al último período que el calendario admite en el origen. Si llega antes, el modelo vería
#' menos información de la que la regla declara (o un hueco), y el motor se detiene. Las series de grano
#' anual tienen su propia guarda (año completo, rama anual de guarda_recorte()).
guarda_borde <- function(d, o, rezago, nombre = "serie", rezago_pib = REZAGO_PIB_DIAS) {
  if (is.null(rezago) || identical(rezago, REZAGO_ANUAL_CERRADO)) return(invisible(TRUE))
  mensual <- nrow(d) > 0L && grepl("-M", d$periodo[1], fixed = TRUE)
  if (nrow(d) == 0L) stop(sprintf("G-7 borde incompleto: %s no trae ningún período admitido en el origen %s", nombre, ind_a_q(o)))
  esperado <- ultimo_admitido(o, rezago, mensual, rezago_pib)
  ultimo <- if (mensual) m_a_ind(d$periodo[nrow(d)]) else q_a_ind(d$periodo[nrow(d)])
  if (ultimo != esperado) {
    fmt <- function(i) if (mensual) sprintf("%d-M%02d", i %/% 12L, i %% 12L + 1L) else ind_a_q(i)
    stop(sprintf("G-7 borde incompleto: %s llega hasta %s en el origen %s y el calendario admite hasta %s (rezago %d días, F5-04)",
                 nombre, fmt(ultimo), ind_a_q(o), fmt(esperado), as.integer(rezago)))
  }
  invisible(TRUE)
}

# Piso de la muestra efectiva de F5-03: observaciones efectivas menos parámetros estimados.
PISO_GL <- 20L

#' G-8 (F5-03): un modelo que declara `piso_gl = TRUE` debe devolver en su ajuste `gl = c(n_obs =, n_par =)`
#' (observaciones efectivas de la ecuación del objetivo y parámetros estimados, sin contar la varianza), y
#' n_obs - n_par >= PISO_GL. La grilla del YAML se acota para que esto no se dispare; la guarda lo comprueba.
guarda_gl <- function(ajuste, modelo_id, o) {
  gl <- if (is.list(ajuste)) ajuste$gl else NULL
  if (!is.numeric(gl) || !all(c("n_obs", "n_par") %in% names(gl)) || any(!is.finite(gl[c("n_obs", "n_par")]))) {
    stop(sprintf("G-8 modelo %s en %s: declara piso_gl y su ajuste no trae gl = c(n_obs, n_par)", modelo_id, ind_a_q(o)))
  }
  libres <- gl[["n_obs"]] - gl[["n_par"]]
  if (libres < PISO_GL) {
    stop(sprintf("G-8 modelo %s en %s: %d observaciones efectivas y %d parámetros dejan %d grados de libertad; el piso es %d (F5-03)",
                 modelo_id, ind_a_q(o), as.integer(gl[["n_obs"]]), as.integer(gl[["n_par"]]), as.integer(libres), PISO_GL))
  }
  invisible(TRUE)
}
