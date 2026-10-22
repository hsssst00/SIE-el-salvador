# reporte.R
#
# Unidades de reporte, sensibilidad y coherencia interna del Ejercicio B (checklist de Fase 6, D6; F6-09, F6-10,
# F6-11, F6-11-a, F6-11-b de doc/metodologia/decisiones_fase6.md; protocolo_proyeccion.md §8 a §10).
#
#   Cifra principal (F6-11)  crecimiento anual = 100 · (A_y / A_{y−1} − 1), con A_y el promedio del año calendario
#                            de los niveles trimestrales SA (exp del log-nivel: la historia observada y el sendero).
#                            Años del año del origen a ANIO_FIN_REPORTE; el año del origen se marca con sus
#                            trimestres observados; 2031 solo en trimestres (F6-11-a). Promedio 2026-2030 = media
#                            aritmética de los crecimientos anuales (F6-11-b).
#   Bandas anuales (F6-11-b) las de la mezcla de F6-07 en la unidad anual, que no es lineal en el log-nivel: por
#                            simulación con N_SIM_ANUAL extracciones por miembro de su normal y semilla fija.
#   Tablas (F6-11)           trimestral (nivel índice, log-nivel, interanual y trimestral, con bandas y la marca
#                            sin_calibrar) y anual, con la nota de condicionalidad en cada fila.
#   Sensibilidad (F6-09)     cambio del nivel del PIB de 2030 (%) y del crecimiento promedio 2026-2030 (pp) frente a
#                            la base, para la combinación y cada miembro.
#   Coherencia (F6-10)       con stop(): las tablas trimestral y anual son agregaciones exactas de un único sendero.
#                            Informativas: frente al PIB de El Salvador en el WEO; promedio 2026-2030 frente al
#                            histórico con y sin 2020; signo de la respuesta en la sensibilidad; deflactor implícito
#                            de las remesas frente a su historia (nota del 2026-10-22 en F6-10).
# Sin I/O y sin estado global salvo el generador, que bandas_anuales() fija con la semilla que recibe.

source(here::here("src", "proyeccion", "combinacion.R"))   # unidades_sendero(), bandas_mezcla(), DISENO_FASE6
source(here::here("src", "proyeccion", "sensibilidad.R"))  # SIGNOS_SENSIBILIDAD

ANIO_FIN_REPORTE <- 2030L     # F6-11: cifra anual 2026-2030; 2031 solo en trimestres (F6-11-a)
N_SIM_ANUAL <- 10000L         # F6-11-b: extracciones por miembro para las bandas anuales
TOL_COHERENCIA <- 1e-10       # F6-10: identidades de agregación
NOTA_CONDICIONAL <- "condicional a los supuestos de doc/metodologia/supuestos_escenarios.md"   # F6-11, protocolo §10
ID_COMBINACION <- "COMBINACION"   # fila de la mediana de F6-02 en las tablas

# ---------------------------------------------------------------------------------------------
# Cifra anual (F6-11, F6-11-a, F6-11-b)
# ---------------------------------------------------------------------------------------------

#' Años de la cifra anual: del año del origen a ANIO_FIN_REPORTE.
anios_reporte <- function(o) {
  a0 <- as.integer(o) %/% 4L
  if (a0 > ANIO_FIN_REPORTE) stop("anios_reporte: el origen ", ind_a_q(o), " es posterior a ", ANIO_FIN_REPORTE)
  a0:ANIO_FIN_REPORTE
}

#' Promedios anuales de los niveles (exp del log-nivel) de una o más trayectorias. `Y` es una matriz n x h de
#' log-niveles proyectados (una fila por trayectoria), `y_hist` los log-niveles observados nombrados por índice
#' trimestral y `o` el origen. Devuelve una matriz n x (length(anios) + 1): el año anterior al primero y `anios`.
.promedios_anuales <- function(Y, y_hist, o, anios) {
  h <- ncol(Y); anios_a <- c(anios[1] - 1L, anios)
  idx <- lapply(anios_a, function(a) 4L * a + 0:3)
  if (max(unlist(idx)) > o + h) stop("cifra anual: el sendero no cubre ", max(anios))
  matrix(vapply(idx, function(ii) {
    obs <- ii[ii <= o]; pro <- ii[ii > o] - o
    if (length(obs) && anyNA(y_hist[as.character(obs)])) stop("cifra anual: falta la historia de ", paste(ind_a_q(obs), collapse = ", "))
    s <- if (length(obs)) sum(exp(y_hist[as.character(obs)])) else 0
    (s + rowSums(exp(Y[, pro, drop = FALSE]))) / 4
  }, numeric(nrow(Y))), nrow(Y))
}

#' Crecimientos anuales (%) y su promedio desde la matriz de promedios anuales.
.crecimientos <- function(A) {
  g <- 100 * (A[, -1, drop = FALSE] / A[, -ncol(A), drop = FALSE] - 1)
  cbind(g, rowMeans(g))
}

#' Cifra anual de un sendero de log-niveles (h valores desde o+1) sobre el objetivo observado. Devuelve un data.frame:
#' anio, nivel (promedio anual del índice), crecimiento_pct y trimestres_observados; con atributo "promedio" =
#' crecimiento promedio de los años del reporte (F6-11-b).
anual_sendero <- function(sendero, objetivo, o) {
  obj <- .objetivo_fase6(objetivo, "anual_sendero")
  if (obj$i[nrow(obj)] != o) stop("anual_sendero: el objetivo termina en ", ind_a_q(obj$i[nrow(obj)]), " y el origen es ", ind_a_q(o))
  anios <- anios_reporte(o)
  A <- .promedios_anuales(matrix(sendero, 1L), stats::setNames(obj$y, obj$i), o, anios)
  g <- .crecimientos(A)
  r <- data.frame(anio = anios, nivel = A[1, -1], crecimiento_pct = g[1, seq_along(anios)],
                  trimestres_observados = vapply(anios, function(a) sum(4L * a + 0:3 <= o), integer(1)))
  attr(r, "promedio") <- g[1, length(anios) + 1L]
  r
}

#' Raíz de una covarianza semidefinida positiva (R con R R' = S), por autovalores.
.raiz_cov <- function(S) {
  e <- eigen((S + t(S)) / 2, symmetric = TRUE)
  e$vectors %*% diag(sqrt(pmax(e$values, 0)), nrow(S))
}

#' Bandas de la cifra anual y del promedio de la mezcla con pesos iguales de las normales N(media, cov) de
#' `densidades` (F6-07 en la unidad de F6-11; F6-11-b): `n_sim` extracciones de cada miembro, con la semilla `semilla`,
#' y cuantiles (1 − q)/2 y (1 + q)/2 de las extracciones juntas. Devuelve un data.frame: cifra (el año o
#' "promedio"), nivel, inferior, superior, sin_calibrar (algún trimestre proyectado de ese año con h > h_calibrado).
bandas_anuales <- function(densidades, objetivo, o, semilla, niveles = DISENO_FASE6$niveles, n_sim = N_SIM_ANUAL,
                           h_calibrado = DISENO_FASE6$h_calibrado) {
  if (!is.list(densidades) || !length(densidades)) stop("bandas_anuales: no hay densidades")
  if (length(semilla) != 1L || !is.finite(semilla)) stop("bandas_anuales: la semilla es obligatoria (reproducibilidad, F6-12)")
  obj <- .objetivo_fase6(objetivo, "bandas_anuales")
  anios <- anios_reporte(o); y_hist <- stats::setNames(obj$y, obj$i)
  set.seed(semilla)
  G <- do.call(rbind, lapply(densidades, function(d) {
    validar_densidad(d, d$media, "bandas_anuales")
    h <- length(d$media)
    Z <- matrix(stats::rnorm(n_sim * h), n_sim, h)
    Y <- sweep(Z %*% t(.raiz_cov(d$cov)), 2L, d$media, "+")
    .crecimientos(.promedios_anuales(Y, y_hist, o, anios))
  }))
  ult_h <- c(pmax(4L * anios + 3L - as.integer(o), 0L), max(4L * anios + 3L - as.integer(o)))
  cifras <- c(as.character(anios), "promedio")
  do.call(rbind, lapply(niveles, function(q) data.frame(
    cifra = cifras, nivel = q,
    inferior = apply(G, 2L, stats::quantile, probs = (1 - q) / 2, names = FALSE),
    superior = apply(G, 2L, stats::quantile, probs = (1 + q) / 2, names = FALSE),
    sin_calibrar = ult_h > h_calibrado, stringsAsFactors = FALSE)))
}

# ---------------------------------------------------------------------------------------------
# Tablas de reporte (F6-11)
# ---------------------------------------------------------------------------------------------

#' Tabla trimestral de una trayectoria: h, periodo, nivel_indice, log_nivel, yoy_pp, qoq_pp y, si se dan `bandas`
#' (salida de bandas_mezcla()), sus columnas en ancho (<unidad>_inf80, <unidad>_sup80, ...), más sin_calibrar y nota.
tabla_trimestral <- function(sendero, objetivo, o, bandas = NULL, h_calibrado = DISENO_FASE6$h_calibrado) {
  u <- unidades_sendero(sendero, objetivo, o); h <- length(sendero)
  t_ <- data.frame(h = seq_len(h), periodo = periodos_fase6(o, h), nivel_indice = exp(u[, "log_nivel"]), u, stringsAsFactors = FALSE)
  if (!is.null(bandas)) for (un in UNIDADES_FASE6) for (q in sort(unique(bandas$nivel))) {
    b <- bandas[bandas$unidad == un & bandas$nivel == q, ]
    if (!identical(b$h, seq_len(h))) stop("tabla_trimestral: las bandas de ", un, " no cubren h = 1..", h)
    t_[[sprintf("%s_inf%d", un, round(100 * q))]] <- b$inferior
    t_[[sprintf("%s_sup%d", un, round(100 * q))]] <- b$superior
  }
  t_$sin_calibrar <- t_$h > h_calibrado
  t_$nota <- NOTA_CONDICIONAL
  t_
}

#' Tabla anual de una trayectoria (anual_sendero()) con sus bandas anuales en ancho, si se dan, y la fila del promedio.
tabla_anual <- function(sendero, objetivo, o, bandas = NULL) {
  a <- anual_sendero(sendero, objetivo, o)
  t_ <- data.frame(cifra = c(as.character(a$anio), "promedio"), nivel = c(a$nivel, NA),
                   crecimiento_pct = c(a$crecimiento_pct, attr(a, "promedio")),
                   trimestres_observados = c(a$trimestres_observados, NA), stringsAsFactors = FALSE)
  if (!is.null(bandas)) {
    for (q in sort(unique(bandas$nivel))) {
      b <- bandas[bandas$nivel == q, ]
      if (!identical(b$cifra, t_$cifra)) stop("tabla_anual: las bandas no cubren las mismas cifras")
      t_[[sprintf("crecimiento_inf%d", round(100 * q))]] <- b$inferior
      t_[[sprintf("crecimiento_sup%d", round(100 * q))]] <- b$superior
    }
    t_$sin_calibrar <- b$sin_calibrar
  }
  t_$nota <- NOTA_CONDICIONAL
  t_
}

# ---------------------------------------------------------------------------------------------
# Sensibilidad (F6-09)
# ---------------------------------------------------------------------------------------------

#' Cambio frente a la base de un sendero de sensibilidad: nivel del PIB de ANIO_FIN_REPORTE (%, promedio anual del
#' índice) y crecimiento promedio de los años del reporte (pp).
efecto_sensibilidad <- function(sendero_sens, sendero_base, objetivo, o) {
  s <- anual_sendero(sendero_sens, objetivo, o); b <- anual_sendero(sendero_base, objetivo, o)
  k <- which(s$anio == ANIO_FIN_REPORTE)
  c(nivel_2030_pct = 100 * (s$nivel[k] / b$nivel[k] - 1), crecimiento_promedio_pp = attr(s, "promedio") - attr(b, "promedio"))
}

#' Tabla de sensibilidad de un grupo: `base` y cada elemento de `corridas` (lista nombrada <VARIABLE>.<MAS|MENOS>) son
#' listas nombradas por modelo_id de senderos de log-nivel (la combinación con ID_COMBINACION). Una fila por corrida
#' y modelo presente en las dos.
tabla_sensibilidad <- function(base, corridas, objetivo, o) {
  do.call(rbind, lapply(names(corridas), function(cr) {
    ids <- intersect(names(base), names(corridas[[cr]]))
    do.call(rbind, lapply(ids, function(id) {
      e <- efecto_sensibilidad(corridas[[cr]][[id]], base[[id]], objetivo, o)
      data.frame(corrida = cr, variable = sub("\\.[A-Z]+$", "", cr), signo = sub("^.*\\.", "", cr), modelo_id = id,
                 nivel_2030_pct = e[["nivel_2030_pct"]], crecimiento_promedio_pp = e[["crecimiento_promedio_pp"]],
                 stringsAsFactors = FALSE)
    }))
  }))
}

# ---------------------------------------------------------------------------------------------
# Coherencia interna (F6-10)
# ---------------------------------------------------------------------------------------------

#' Identidades con stop() (F6-10.1): la tabla trimestral es un único sendero (el trimestral acumula al log-nivel desde
#' el origen, el interanual sale de ese log-nivel y de la historia, y el nivel índice es su exp) y la tabla anual es
#' la agregación de ese sendero sobre la historia. `etiqueta` nombra la trayectoria en el mensaje.
verificar_agregacion <- function(trimestral, anual, objetivo, o, etiqueta = "?") {
  obj <- .objetivo_fase6(objetivo, "verificar_agregacion")
  y_o <- obj$y[obj$i == o]
  if (length(y_o) != 1L) stop("coherencia [", etiqueta, "]: el objetivo no tiene el origen ", ind_a_q(o))
  s <- trimestral$log_nivel
  falla <- function(que, err) if (err > TOL_COHERENCIA) stop(sprintf("coherencia [%s]: %s (error máximo %.3g, tolerancia %g)", etiqueta, que, err, TOL_COHERENCIA))
  falla("el trimestral no acumula al log-nivel", max(abs(y_o + cumsum(trimestral$qoq_pp) / 100 - s)))
  falla("el interanual no sale del log-nivel", max(abs(unidades_sendero(s, objetivo, o)[, "yoy_pp"] - trimestral$yoy_pp)))
  falla("el nivel índice no es el exp del log-nivel", max(abs(trimestral$nivel_indice / exp(s) - 1)))
  a <- anual_sendero(s, objetivo, o)
  fa <- anual[anual$cifra != "promedio", ]
  if (!identical(fa$cifra, as.character(a$anio))) stop("coherencia [", etiqueta, "]: la tabla anual no tiene los años del reporte")
  falla("la tabla anual no es la agregación del sendero trimestral", max(abs(fa$nivel / a$nivel - 1), abs(fa$crecimiento_pct - a$crecimiento_pct)))
  falla("el promedio anual no es la media de los crecimientos", abs(anual$crecimiento_pct[anual$cifra == "promedio"] - mean(a$crecimiento_pct)))
  invisible(TRUE)
}

#' Informativa: crecimiento anual de la trayectoria frente al del PIB de El Salvador en el WEO (`weo`, vector nombrado
#' por año, en %). Solo los años que están en los dos.
coherencia_weo <- function(anual, weo) {
  a <- anual[anual$cifra != "promedio", ]
  comunes <- intersect(a$cifra, names(weo))
  data.frame(anio = as.integer(comunes), sendero = a$crecimiento_pct[match(comunes, a$cifra)], weo = unname(weo[comunes]),
             diferencia_pp = a$crecimiento_pct[match(comunes, a$cifra)] - unname(weo[comunes]))
}

#' Informativa: crecimiento anual promedio histórico del objetivo (promedios anuales del índice, años completos antes
#' del año del origen), con y sin 2020, frente al promedio de la trayectoria.
coherencia_historica <- function(anual, objetivo, o) {
  obj <- .objetivo_fase6(objetivo, "coherencia_historica")
  a <- tapply(exp(obj$y), obj$i %/% 4L, function(v) if (length(v) == 4L) mean(v) else NA_real_)
  a <- a[!is.na(a) & as.integer(names(a)) < as.integer(o) %/% 4L]
  g <- 100 * (a[-1] / a[-length(a)] - 1)
  data.frame(promedio_sendero = anual$crecimiento_pct[anual$cifra == "promedio"], historico_con_2020 = mean(g),
             historico_sin_2020 = mean(g[names(g) != "2020"]), desde = as.integer(names(g)[1]), hasta = as.integer(utils::tail(names(g), 1)))
}

#' Informativa: signo de la respuesta del nivel de 2030 en cada corrida de la sensibilidad. Solo el PIB de EE. UU.
#' tiene signo esperado (F6-10: más PIB de EE. UU. da más PIB de El Salvador); los demás se reportan sin esperado.
coherencia_signos <- function(tabla_sens) {
  esperado <- c(PIB_EEUU = 1)
  s <- SIGNOS_SENSIBILIDAD[tabla_sens$signo] * esperado[tabla_sens$variable]
  data.frame(tabla_sens[c("corrida", "modelo_id")], signo_respuesta = sign(tabla_sens$nivel_2030_pct),
             signo_esperado = unname(s), coincide = sign(tabla_sens$nivel_2030_pct) == unname(s), stringsAsFactors = FALSE)
}

#' Informativa (F6-10, nota del 2026-10-22): deflactor implícito de las remesas en los senderos de las satélites,
#' Δlog nominal − Δlog real, como interanual (pp), frente al rango histórico de ese mismo cociente sin 2020-2021.
#' `dlog`: matriz de Δlog trimestral con las dos columnas, filas o+1..; `nom` y `real`: historia trimestral de L3
#' (data.frame periodo, valor) de las dos remesas.
coherencia_deflactor <- function(dlog, nom, real, o, anios_fuera = ANIOS_FUERA_GUARDA) {
  ids <- c("BCR.REMESAS.NOM.NSA.Q", "BCR.REMESAS.REAL.NSA.Q")
  if (!all(ids %in% colnames(dlog))) stop("coherencia_deflactor: el sendero no trae las dos remesas")
  i_n <- q_a_ind(nom$periodo); i_r <- q_a_ind(real$periodo); comun <- intersect(i_n, i_r)
  d <- stats::setNames(log(nom$valor[match(comun, i_n)]) - log(real$valor[match(comun, i_r)]), comun)
  yoy_h <- 100 * (d[-(1:4)] - d[seq_len(length(d) - 4L)])
  yoy_h <- yoy_h[!as.integer(names(yoy_h)) %/% 4L %in% anios_fuera]
  h <- nrow(dlog); dd <- unname(c(d[as.character(as.integer(o) - 3:0)], d[as.character(o)] + cumsum(dlog[, ids[1]] - dlog[, ids[2]])))
  if (anyNA(dd)) stop("coherencia_deflactor: el deflactor histórico no llega a ", ind_a_q(o))
  yoy_p <- 100 * (dd[4L + seq_len(h)] - dd[seq_len(h)])
  data.frame(h = seq_len(h), periodo = periodos_fase6(o, h), deflactor_yoy_pp = unname(yoy_p),
             historico_min = min(yoy_h), historico_max = max(yoy_h), dentro = yoy_p >= min(yoy_h) & yoy_p <= max(yoy_h))
}
