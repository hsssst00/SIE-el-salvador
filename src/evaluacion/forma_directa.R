# src/evaluacion/forma_directa.R
#
# Forma directa por horizonte y validación anidada de Fase 5 (checklist C3, C4 y parte de C5; F5-05, F5-09,
# F5-11, F5-12 y B3-1 a B3-8 de doc/metodologia/decisiones_fase5.md). Es la infraestructura del primer PR de B3
# (B3-8). La usan los regularizados de B3 (REG.ENET.Gk, REG.PCR.Gk) y puede usarla B4 (árboles), que tiene los
# mismos predictores (F5-10). No cambia el motor: un modelo directo cumple el contrato de eval_lib.R §4 y hace todo
# dentro de ajustar(), que solo recibe datos <= o (G-1). Sin I/O y sin estado global. Usa dummies_trimestrales() de
# modelos_univariados.R, que modelos_fase5.R carga antes.
#
# Forma directa (F5-05, F5-09). En el origen o y para cada h = 1..8 hay un modelo sobre el crecimiento acumulado
#   g_h(t) = y_{t+h} - y_t      (y = log-nivel SA del objetivo, el del origen),
# con predictores en t: Δy y el Δlog de cada predictora con rezagos 0..3 (agregados trimestrales .Q hasta o, F5-04).
# Se estima con las filas t + h <= o y se pronostica en t = o. El sendero es y_o + ĝ_h (contrato §2, regla 2). Se
# estiman los ocho horizontes, aunque se evalúan 1, 2, 4 y 8, porque el contrato pide el sendero h = 1..8 y la tasa
# interanual en h > 4 y la trimestral necesitan la covarianza 8 x 8.
#
# Ventana de estimación (B3-2). En cada ventana (la final y cada interna), cada columna y g_h se residualizan sobre
# constante + 3 dummies trimestrales, por MCO en la ventana (solo constante si ninguna predictora es NSA). Cada
# columna se divide por la raíz del promedio de sus residuos al cuadrado (denominador n, la convención de glmnet).
# Por Frisch-Waugh-Lovell, los coeficientes son los de dummies sin penalizar (F5-09); la escala es la desviación no
# estacional de cada columna. La fila de pronóstico se transforma con los coeficientes y las escalas de la ventana, y
# el pronóstico de g_h es la parte determinista de la ventana más el pronóstico del modelo sobre lo residualizado.
#
# Validación anidada (C4; F5-11, B3-4). Para cada h, los K = 12 orígenes internos propios son o' = o-h-11..o-h. En
# cada uno se estima con las filas t + h <= o' (es decir, con datos <= o') y se pronostica g_h(o'), observado porque
# o' + h <= o. Se elige el candidato de menor ECM interno; un empate va al primero de la rejilla, que los modelos
# ordenan de más a menos penalizado. La rejilla de cada h la arma el modelo sobre la ventana final (B3-1: datos <= o,
# como cv.glmnet). K = 12 en todo h (B3-4): la estimación interna más chica tiene n_L - 15 - 2h filas, 9 en h = 8 en
# el primer origen de G2 y G3.
#
# Densidad (F5-12, B3-5, B3-6). Gaussiana del sendero con Σ = D R D. D² es el ECM interno de cada h en sus 12
# orígenes propios, el del candidato elegido (momento sin centrar). R son las correlaciones de los momentos sin
# centrar en los 12 orígenes internos comunes a h = 1..8 (o-19..o-8). En los orígenes comunes que no son propios de
# un h, su candidato elegido se estima de nuevo con la misma rejilla, así que el error coincide con el que habría
# dado la pasada de selección. Σ es semidefinida positiva por construcción y se exige definida positiva (B3-7).
#
# Especificación de un modelo directo (lista `esp`):
#   candidatos(Z, g, h)                      -> data.frame con la rejilla del origen y h (una fila por candidato,
#                                               de más a menos penalizado), calculada sobre la ventana final
#   estimar_predecir(Z, g, z, rejilla, cand) -> pronósticos de g en las filas de z, uno por candidato de `cand`
#                                               (índices de fila de la rejilla); Z, g y z ya transformados si
#                                               transformar = TRUE
#   transformar                              -> TRUE para aplicar la ventana de B3-2 (regularizados)
#   diagnosticar(rejilla, j)                 -> opcional: vector numérico nombrado del candidato elegido j (α, λ,
#                                               borde de la rejilla, ...)

K_VALIDACION_ANIDADA  <- 12L                  # F5-11, B3-4
REZAGOS_FORMA_DIRECTA <- 0:3                  # F5-09 (y F5-10)
H_FORMA_DIRECTA       <- DISENO_FASE4$h_max   # el sendero y la covarianza van de h = 1 a 8

# ---------------------------------------------------------------------------------------------
# Matriz de la forma directa (C3)
# ---------------------------------------------------------------------------------------------

#' Δlog de una predictora trimestral (data.frame periodo, valor) nombrado por índice; falla si no es positiva, si
#' tiene huecos o si trae NA.
.dlog_directa <- function(d, id, modelo_id) {
  if (is.null(d) || !all(c("periodo", "valor") %in% names(d))) stop(modelo_id, ": la predictora ", id, " necesita periodo y valor")
  iq <- q_a_ind(d$periodo)
  if (length(iq) < 2L) stop(modelo_id, ": la predictora ", id, " tiene menos de 2 trimestres")
  if (any(diff(iq) != 1L)) stop(modelo_id, ": la predictora ", id, " tiene trimestres faltantes o desordenados")
  if (anyNA(d$valor) || any(!is.finite(d$valor)) || any(d$valor <= 0)) stop(modelo_id, ": la predictora ", id, " trae valores no positivos o ausentes (se usa el Δlog)")
  stats::setNames(diff(log(d$valor)), iq[-1])
}

#' Matriz de predictores de la forma directa en un origen (C3; F5-05, F5-09).
#'
#' @param datos       lista del motor, ya recortada al origen: objetivo (periodo, y) y predictoras (periodo, valor).
#' @param predictoras series_master_id .Q de las predictoras del modelo (predictoras_grupo()).
#' @return list(modelo_id, o, t, X, y, y_o, con_dummies, predictoras, rezagos). `t` son los índices de las filas: desde
#'         el primer trimestre en que existen Δy y todos los Δlog con sus rezagos hasta o. `X` (filas x columnas)
#'         tiene una columna por serie y rezago, `<serie>__L<k>` (la serie del objetivo se llama `objetivo`). `y` es el
#'         log-nivel del objetivo nombrado por índice; `con_dummies` es TRUE si alguna predictora es NSA.
matriz_directa <- function(datos, predictoras, modelo_id, rezagos = REZAGOS_FORMA_DIRECTA) {
  ob <- datos$objetivo
  if (is.null(ob) || !all(c("periodo", "y") %in% names(ob))) stop(modelo_id, ": falta datos$objetivo con periodo e y")
  iy <- q_a_ind(ob$periodo)
  if (length(iy) < 2L || any(diff(iy) != 1L)) stop(modelo_id, ": el objetivo tiene trimestres faltantes o desordenados")
  if (anyNA(ob$y) || any(!is.finite(ob$y))) stop(modelo_id, ": el objetivo trae NA o valores no finitos")
  if (!is.numeric(rezagos) || !length(rezagos) || any(rezagos < 0) || anyDuplicated(rezagos)) stop(modelo_id, ": rezagos mal formados")
  o <- iy[length(iy)]
  faltan <- setdiff(predictoras, names(datos))
  if (length(faltan)) stop(modelo_id, ": faltan predictoras en los datos: ", paste(faltan, collapse = ", "))
  dl <- c(list(objetivo = stats::setNames(diff(ob$y), iy[-1])),
          stats::setNames(lapply(predictoras, function(id) .dlog_directa(datos[[id]], id, modelo_id)), predictoras))
  for (id in predictoras) {
    if (as.integer(utils::tail(names(dl[[id]]), 1)) != o) stop(modelo_id, ": ", id, " no llega al origen ", ind_a_q(o), " (F5-04)")
  }
  ini <- max(vapply(dl, function(v) as.integer(names(v))[1], integer(1))) + max(rezagos)
  if (ini > o) stop(modelo_id, " en ", ind_a_q(o), ": no hay ninguna fila con todos los rezagos")
  t_ <- ini:o
  cols <- list(); nm <- character(0)
  for (s in names(dl)) for (L in rezagos) {
    cols[[length(cols) + 1L]] <- unname(dl[[s]][as.character(t_ - L)]); nm <- c(nm, paste0(s, "__L", L))
  }
  X <- matrix(unlist(cols), nrow = length(t_)); colnames(X) <- nm
  if (anyNA(X) || any(!is.finite(X))) stop(modelo_id, " en ", ind_a_q(o), ": la matriz de predictores trae NA o valores no finitos")
  list(modelo_id = modelo_id, o = o, t = t_, X = X, y = stats::setNames(ob$y, iy), y_o = ob$y[length(ob$y)],
       con_dummies = any(grepl(".NSA.", predictoras, fixed = TRUE)), predictoras = predictoras, rezagos = rezagos)
}

#' Crecimiento acumulado g_h(t) = y_{t+h} - y_t en las filas de la matriz directa (F5-05); NA si t + h > o.
crecimiento_acumulado <- function(md, h) {
  if (length(h) != 1L || h < 1L) stop("crecimiento_acumulado: h debe ser un entero positivo")
  stats::setNames(unname(md$y[as.character(md$t + h)] - md$y[as.character(md$t)]), md$t)
}

# ---------------------------------------------------------------------------------------------
# Ventana de estimación (B3-2)
# ---------------------------------------------------------------------------------------------

.deterministas_ventana <- function(t_, con_dummies) {
  if (con_dummies) cbind(constante = 1, dummies_trimestrales(t_)) else matrix(1, length(t_), 1L, dimnames = list(NULL, "constante"))
}

#' Transformación de una ventana de estimación (B3-2): residuos de MCO de cada columna y de g sobre constante + 3
#' dummies (solo constante sin NSA) y escala de cada columna con la raíz del promedio de sus residuos al cuadrado.
#' @return list(Z, gz, B, bg, esc, con_dummies, n): Z y gz son las columnas y g transformadas; B y bg, los
#'         coeficientes deterministas de la ventana; esc, las escalas.
ventana_directa <- function(X, g, t_, con_dummies, modelo_id = "?") {
  n <- nrow(X)
  if (length(g) != n || length(t_) != n) stop(modelo_id, ": ventana con dimensiones incoherentes")
  if (anyNA(X) || anyNA(g) || any(!is.finite(X)) || any(!is.finite(g))) stop(modelo_id, ": ventana con NA o valores no finitos (B3-7)")
  W <- .deterministas_ventana(t_, con_dummies)
  if (n <= ncol(W)) stop(sprintf("%s: ventana de %d filas con %d regresores deterministas (B3-2)", modelo_id, n, ncol(W)))
  qw <- qr(W)
  if (qw$rank < ncol(W)) stop(modelo_id, ": las dummies de la ventana pierden rango (B3-2)")
  B <- qr.coef(qw, X); RX <- qr.resid(qw, X)
  bg <- qr.coef(qw, g); rg <- qr.resid(qw, g)
  esc <- sqrt(colMeans(RX^2))
  tol <- sqrt(.Machine$double.eps) * pmax(1, sqrt(colMeans(X^2)))
  if (any(!(esc > tol))) {
    stop(modelo_id, ": columnas sin variación no estacional en la ventana (B3-7): ", paste(colnames(X)[!(esc > tol)], collapse = ", "))
  }
  Z <- sweep(RX, 2L, esc, "/")
  dimnames(Z) <- dimnames(X)
  list(Z = Z, gz = as.numeric(rg), B = B, bg = as.numeric(bg), esc = esc, con_dummies = con_dummies, n = n)
}

#' Aplica la transformación de una ventana a filas nuevas `x` en los trimestres `t_`.
#' @return list(z, base): las filas transformadas y la parte determinista de g en esas filas.
aplicar_ventana <- function(vt, x, t_) {
  x <- matrix(x, ncol = length(vt$esc))
  W <- .deterministas_ventana(t_, vt$con_dummies)
  z <- sweep(x - W %*% vt$B, 2L, vt$esc, "/")
  list(z = z, base = as.numeric(W %*% vt$bg))
}

# ---------------------------------------------------------------------------------------------
# Validación anidada (C4; F5-11, B3-4)
# ---------------------------------------------------------------------------------------------

#' Orígenes internos propios de h (F5-11): los K últimos o' con o' + h <= o.
origenes_internos <- function(o, h, K = K_VALIDACION_ANIDADA) as.integer((o - h - K + 1L):(o - h))

#' Orígenes internos comunes a h = 1..h_max (B3-5): los K últimos o' con o' + h_max <= o.
origenes_comunes <- function(o, h_max = H_FORMA_DIRECTA, K = K_VALIDACION_ANIDADA) as.integer((o - h_max - K + 1L):(o - h_max))

#' Pronóstico directo de g en las filas nuevas con una ventana de estimación; uno por candidato.
.pronostico_ventana <- function(Xtr, gtr, ttr, xnw, tnw, con_dummies, esp, rejilla, cand, modelo_id) {
  if (isTRUE(esp$transformar)) {
    vt <- ventana_directa(Xtr, gtr, ttr, con_dummies, modelo_id)
    an <- aplicar_ventana(vt, xnw, tnw)
    p <- esp$estimar_predecir(vt$Z, vt$gz, an$z, rejilla, cand) + an$base
  } else {
    if (anyNA(gtr) || any(!is.finite(gtr))) stop(modelo_id, ": ventana con NA o valores no finitos (B3-7)")
    p <- esp$estimar_predecir(Xtr, gtr, matrix(xnw, ncol = ncol(Xtr)), rejilla, cand)
  }
  if (!is.numeric(p) || length(p) != length(cand) * length(tnw) || any(!is.finite(p))) {
    stop(sprintf("%s: estimar_predecir() debe devolver %d pronósticos finitos (B3-7)", modelo_id, length(cand) * length(tnw)))
  }
  as.numeric(p)
}

#' Pronósticos internos de g_h en los orígenes internos `origenes` para los candidatos `cand` (C4).
#'
#' En cada o' la ventana son las filas con t + h <= o' (g usa y hasta o') y la fila de pronóstico es la de t = o'
#' (predictores hasta o'). Ningún dato posterior a o' entra al pronóstico de o'; el valor observado g_h(o') usa y hasta
#' o' + h <= o y solo sirve para el error.
#' @return list(pred (orígenes x candidatos), obs (g_h observado en cada o'), n_filas (filas de cada ventana)).
pronosticos_internos <- function(md, h, origenes, esp, rejilla, cand) {
  g <- crecimiento_acumulado(md, h)
  P <- matrix(NA_real_, length(origenes), length(cand))
  n_filas <- integer(length(origenes))
  for (i in seq_along(origenes)) {
    op <- origenes[i]
    if (op + h > md$o) stop(sprintf("%s: el origen interno %s no tiene observado g a %d pasos", md$modelo_id, ind_a_q(op), h))
    nw <- which(md$t == op)
    if (length(nw) != 1L) {
      stop(sprintf("%s en %s: el origen interno %s (h = %d) queda antes de la primera fila con todos los rezagos (%s)",
                   md$modelo_id, ind_a_q(md$o), ind_a_q(op), h, ind_a_q(md$t[1])))
    }
    tr <- which(md$t + h <= op)
    if (!length(tr)) stop(sprintf("%s en %s: el origen interno %s (h = %d) no tiene filas de estimación", md$modelo_id, ind_a_q(md$o), ind_a_q(op), h))
    P[i, ] <- .pronostico_ventana(md$X[tr, , drop = FALSE], unname(g[tr]), md$t[tr], md$X[nw, , drop = FALSE], op,
                                  md$con_dummies, esp, rejilla, cand, md$modelo_id)
    n_filas[i] <- length(tr)
  }
  list(pred = P, obs = unname(g[as.character(origenes)]), n_filas = n_filas)
}

#' Índice del candidato de menor ECM interno; un empate va al primero (F5-11).
seleccionar_candidato <- function(ecm) {
  if (!is.numeric(ecm) || !length(ecm) || any(!is.finite(ecm))) stop("seleccionar_candidato: ECM interno no finito (B3-7)")
  which(ecm == min(ecm))[1]
}

#' Covarianza del sendero a partir de los errores internos (F5-12, B3-5, B3-6): Σ = D R D.
#'
#' @param e_propios lista (uno por h) con los K errores del candidato elegido en sus orígenes propios.
#' @param E_comunes matriz K x h_max con los errores del candidato elegido de cada h en los orígenes comunes.
#' @return matriz h_max x h_max: diag = ECM interno de cada h (sin centrar); correlaciones sin centrar de E_comunes.
cov_errores_internos <- function(e_propios, E_comunes, modelo_id = "?") {
  H <- length(e_propios)
  if (!is.matrix(E_comunes) || ncol(E_comunes) != H) stop(modelo_id, ": errores comunes mal dimensionados")
  v <- vapply(e_propios, function(e) mean(e^2), numeric(1))
  M <- crossprod(E_comunes) / nrow(E_comunes)
  dM <- diag(M)
  if (any(!is.finite(v)) || any(!(v > 0)) || any(!is.finite(M)) || any(!(dM > 0))) stop(modelo_id, ": errores internos nulos o no finitos; la covarianza no está definida (B3-7)")
  R <- M / sqrt(outer(dM, dM))
  S <- R * outer(sqrt(v), sqrt(v))
  S <- (S + t(S)) / 2
  ev <- eigen(S, symmetric = TRUE, only.values = TRUE)$values
  if (!(min(ev) > 1e-12 * max(diag(S)))) stop(sprintf("%s: la covarianza de los errores internos no es definida positiva (autovalor mínimo %.3g; B3-7)", modelo_id, min(ev)))
  S
}

# ---------------------------------------------------------------------------------------------
# Ajuste en un origen y fábrica del modelo (C3)
# ---------------------------------------------------------------------------------------------

.validar_especificacion_directa <- function(esp, modelo_id) {
  if (!is.list(esp) || !is.function(esp$candidatos) || !is.function(esp$estimar_predecir)) {
    stop(modelo_id, ": la especificación directa necesita candidatos() y estimar_predecir()")
  }
  if (!(is.logical(esp$transformar) && length(esp$transformar) == 1L && !is.na(esp$transformar))) stop(modelo_id, ": transformar debe ser TRUE o FALSE")
  if (!is.null(esp$diagnosticar) && !is.function(esp$diagnosticar)) stop(modelo_id, ": diagnosticar debe ser una función")
  invisible(TRUE)
}

#' Ajuste de un modelo directo en un origen (C3, C4): para cada h, rejilla sobre la ventana final, validación anidada
#' en los K orígenes propios, elección por ECM interno, errores del elegido en los orígenes comunes, y estimación final
#' con las filas t + h <= o y pronóstico en t = o.
ajustar_directo <- function(md, esp, h_max = H_FORMA_DIRECTA, K = K_VALIDACION_ANIDADA) {
  .validar_especificacion_directa(esp, md$modelo_id)
  o <- md$o; nw <- which(md$t == o)
  comunes <- origenes_comunes(o, h_max, K)
  por_h <- lapply(seq_len(h_max), function(h) {
    g <- crecimiento_acumulado(md, h)
    tr <- which(md$t + h <= o)
    if (length(tr) < 2L) stop(sprintf("%s en %s: %d filas para estimar a h = %d", md$modelo_id, ind_a_q(o), length(tr), h))
    if (isTRUE(esp$transformar)) {
      vt <- ventana_directa(md$X[tr, , drop = FALSE], unname(g[tr]), md$t[tr], md$con_dummies, md$modelo_id)
      rejilla <- esp$candidatos(vt$Z, vt$gz, h)
    } else {
      rejilla <- esp$candidatos(md$X[tr, , drop = FALSE], unname(g[tr]), h)
    }
    if (!is.data.frame(rejilla) || !nrow(rejilla)) stop(md$modelo_id, ": candidatos() debe devolver un data.frame con al menos una fila")
    todos <- seq_len(nrow(rejilla))
    propios <- origenes_internos(o, h, K)
    ip <- pronosticos_internos(md, h, propios, esp, rejilla, todos)
    E <- ip$obs - ip$pred                                   # K x candidatos
    ecm <- colMeans(E^2)
    j <- seleccionar_candidato(ecm)
    e_com <- stats::setNames(rep(NA_real_, length(comunes)), comunes)
    en_propios <- comunes[comunes %in% propios]
    e_com[as.character(en_propios)] <- E[match(en_propios, propios), j]
    extra <- setdiff(comunes, propios)
    if (length(extra)) {
      ie <- pronosticos_internos(md, h, extra, esp, rejilla, j)
      e_com[as.character(extra)] <- ie$obs - ie$pred[, 1]
    }
    g_hat <- .pronostico_ventana(md$X[tr, , drop = FALSE], unname(g[tr]), md$t[tr], md$X[nw, , drop = FALSE], o,
                                 md$con_dummies, esp, rejilla, j, md$modelo_id)
    list(h = h, rejilla = rejilla, eleccion = j, ecm = ecm, e_propios = E[, j], e_comunes = unname(e_com), g_hat = g_hat,
         n_filas_min = min(ip$n_filas), n_filas_final = length(tr))
  })
  g_hat <- vapply(por_h, `[[`, numeric(1), "g_hat")
  Sigma <- cov_errores_internos(lapply(por_h, `[[`, "e_propios"), vapply(por_h, `[[`, numeric(length(comunes)), "e_comunes"), md$modelo_id)
  list(modelo_id = md$modelo_id, o = o, y_o = md$y_o, g_hat = g_hat, sendero = md$y_o + g_hat, Sigma = Sigma, por_h = por_h,
       n_filas = length(md$t), n_columnas = ncol(md$X))
}

sendero_directo <- function(aj, h) {
  if (h > length(aj$sendero)) stop(sprintf("%s: el sendero directo se estimó hasta h = %d y se pidió h = %d", aj$modelo_id, length(aj$sendero), h))
  aj$sendero[seq_len(h)]
}

#' Diagnósticos por origen de un modelo directo: por h, candidato elegido, ECM interno, filas de la ventana interna
#' más chica y de la final, más los del modelo (esp$diagnosticar).
diagnosticos_directo <- function(aj, esp) {
  out <- c(n_filas = aj$n_filas, n_columnas = aj$n_columnas)
  for (ph in aj$por_h) {
    d <- c(candidato = ph$eleccion, ecm_interno = ph$ecm[ph$eleccion], n_filas_min = ph$n_filas_min, n_filas_final = ph$n_filas_final,
           if (is.function(esp$diagnosticar)) esp$diagnosticar(ph$rejilla, ph$eleccion))
    out <- c(out, stats::setNames(as.numeric(d), paste0("h", ph$h, ".", names(d))))
  }
  out
}

#' Fábrica de un modelo directo bajo el contrato del motor (C3). Sin piso de grados de libertad (F5-09).
modelo_directo <- function(modelo_id, predictoras, esp, rezagos = REZAGOS_FORMA_DIRECTA) {
  .validar_especificacion_directa(esp, modelo_id)
  list(
    modelo_id = modelo_id, requiere = c("objetivo", predictoras), piso_gl = FALSE, esp = esp,
    ajustar = function(datos, spec) ajustar_directo(matriz_directa(datos, predictoras, modelo_id, rezagos), esp),
    predecir = function(aj, h) sendero_directo(aj, h),
    predecir_densidad = function(aj, h) list(media = sendero_directo(aj, h), cov = aj$Sigma[seq_len(h), seq_len(h), drop = FALSE]),
    diagnosticar = function(aj) diagnosticos_directo(aj, esp)
  )
}
