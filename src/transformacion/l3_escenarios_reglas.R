# Reglas puras de las variables de escenario de Fase 6 (fichas F6-14, F6-16 y F6-18 de
# doc/metodologia/decisiones_fase6.md), separadas del script que toca disco
# (src/transformacion/l3_escenarios.R) para que tests/test-l3-escenarios.R las ejerza con datos
# sinteticos, mismo patron que l3_predictores_reglas.R. Ninguna funcion de este archivo lee ni
# escribe disco.
#
# Que hace cada pieza:
#   - interpolar_mes_aislado() / agregar_trimestral_promedio_mes_aislado(): T012 (IPC de EE. UU.),
#     con el tratamiento del mes aislado sin dato de F6-18-b.
#   - metas_anuales(): metas A_y de F6-16 -- ancla en el ultimo año completo de la historia
#     trimestral propia y encadena los crecimientos anuales del WEO; nunca toma niveles del WEO.
#   - denton_cholette(): el sendero trimestral mas suave (minimas primeras diferencias) que fija
#     los trimestres observados y hace que cada año proyectado promedie su meta (F6-16). Codigo
#     propio en forma cerrada (sistema KKT); sin trimestres fijos coincide con
#     tempdisagg::td(A ~ 1, conversion = "average", method = "denton-cholette"), y la prueba
#     sintetica lo contrasta.
#   - sendero_escenario_*(): las tres variantes de T014 que nombra la columna `funcion` de
#     catalogos/04_transformaciones.csv (crecimiento, desvio de nivel en %, desvio de crecimiento
#     en pp, y precio en nivel anual).
#   - validar_*(): las seis validaciones de F6-18, todas con stop() (regla 7).
#
# Los senderos de la sensibilidad (F6-09) no van a L3 (F6-18-c): se arman en L4 con estas mismas
# funciones, a partir de las metas de la base.

ESCENARIOS_FASE6 <- c("BASE", "ADVERSO", "FAVORABLE")

# Ultimo trimestre de todo sendero de escenario: 2031-T4 aunque el horizonte termine antes, porque
# la meta de 2031 necesita sus cuatro trimestres (F6-16-b). Ultimo año que publica el WEO.
ANIO_FIN_SENDERO <- 2031L

# Tolerancias de F6-18 (validacion): metas y desvios a 1e-10 (error relativo / absoluto), petroleo
# contra el WEO a 1e-6 (relativo), IPC contra el WEO a 0,01 pp.
TOL_META <- 1e-10
TOL_DESVIO <- 1e-10
TOL_PETROLEO_WEO <- 1e-6
TOL_IPC_WEO_PP <- 0.01

# Horizonte que todo sendero debe cubrir desde el origen (F6-04: h = 1 a 20).
H_MAX_FASE6 <- 20L

# --- Periodos <-> indices enteros --------------------------------------------------------------

.q_a_ind <- function(p) {
  ok <- grepl("^[0-9]{4}-Q[1-4]$", p)
  if (!all(ok)) stop("FALLO VISIBLE: periodo trimestral mal formado: ", paste(head(p[!ok], 5), collapse = ", "))
  4L * as.integer(substr(p, 1, 4)) + as.integer(substr(p, 7, 7)) - 1L
}
.ind_a_q <- function(i) sprintf("%d-Q%d", i %/% 4L, i %% 4L + 1L)
.m_a_ind <- function(p) {
  ok <- grepl("^[0-9]{4}-M(0[1-9]|1[0-2])$", p)
  if (!all(ok)) stop("FALLO VISIBLE: periodo mensual mal formado: ", paste(head(p[!ok], 5), collapse = ", "))
  12L * as.integer(substr(p, 1, 4)) + as.integer(substr(p, 7, 8)) - 1L
}
.ind_a_m <- function(i) sprintf("%d-M%02d", i %/% 12L, i %% 12L + 1L)
.anio_q <- function(p) as.integer(substr(p, 1, 4))

# Exige una serie trimestral contigua, sin NA y sin periodos repetidos.
.exigir_trimestral_contigua <- function(serie, etiqueta) {
  if (nrow(serie) == 0) stop("FALLO VISIBLE [", etiqueta, "]: serie trimestral vacia.")
  i <- .q_a_ind(serie$periodo)
  if (anyDuplicated(i)) stop("FALLO VISIBLE [", etiqueta, "]: periodos trimestrales repetidos.")
  if (is.unsorted(i) || any(diff(i) != 1L)) {
    stop("FALLO VISIBLE [", etiqueta, "]: la serie trimestral no es contigua y ordenada (",
         serie$periodo[1], " a ", serie$periodo[nrow(serie)], ", ", nrow(serie), " filas).")
  }
  if (anyNA(serie$valor)) {
    stop("FALLO VISIBLE [", etiqueta, "]: valores ausentes en ", paste(serie$periodo[is.na(serie$valor)], collapse = ", "))
  }
  invisible(TRUE)
}

# --- T012: mes aislado sin dato (F6-18-b) ------------------------------------------------------

#' Rellena un mes aislado sin dato de una serie mensual por interpolacion log-lineal entre sus dos
#' vecinos (media geometrica). Solo para el agregado trimestral: el mes interpolado no se
#' materializa como dato mensual. stop() si hay dos o mas meses seguidos sin dato, si el hueco
#' toca un borde (no hay dos vecinos) o si falta una fila de mes (la grilla mensual no es
#' contigua). Devuelve la serie con `valor` completo y una columna logica `interpolado`.
interpolar_mes_aislado <- function(mensual, etiqueta) {
  if (nrow(mensual) < 3) stop("FALLO VISIBLE [", etiqueta, "]: serie mensual con menos de 3 meses.")
  mensual <- mensual[order(mensual$periodo), c("periodo", "valor")]
  i <- .m_a_ind(mensual$periodo)
  if (anyDuplicated(i) || any(diff(i) != 1L)) {
    stop("FALLO VISIBLE [", etiqueta, "]: la grilla mensual no es contigua (falta la fila de algun mes ",
         "o hay meses repetidos); F6-18-b solo cubre un mes con fila y sin valor.")
  }
  na <- is.na(mensual$valor)
  if (any(na[c(1, length(na))])) {
    stop("FALLO VISIBLE [", etiqueta, "]: mes sin dato en el borde de la serie (",
         paste(mensual$periodo[na & seq_along(na) %in% c(1, length(na))], collapse = ", "),
         "): no tiene dos vecinos para interpolar (F6-18-b).")
  }
  corridas <- rle(na)
  if (any(corridas$values & corridas$lengths >= 2)) {
    stop("FALLO VISIBLE [", etiqueta, "]: hueco de dos meses o mas sin dato (",
         paste(mensual$periodo[na], collapse = ", "), "); F6-18-b solo admite un mes aislado.")
  }
  if (any(mensual$valor[!na] <= 0)) stop("FALLO VISIBLE [", etiqueta, "]: valores no positivos; la interpolacion es log-lineal.")
  k <- which(na)
  mensual$valor[k] <- exp((log(mensual$valor[k - 1L]) + log(mensual$valor[k + 1L])) / 2)
  mensual$interpolado <- na
  mensual
}

#' T012: promedio trimestral de una serie mensual de nivel, despues de rellenar un mes aislado sin
#' dato (interpolar_mes_aislado()). Mismas reglas de borde que agregar_trimestral_promedio() de
#' l3_predictores_reglas.R (que tiene que estar cargada). El atributo "meses_interpolados" lista
#' los meses rellenados, para el mensaje de la corrida.
agregar_trimestral_promedio_mes_aislado <- function(mensual, etiqueta) {
  completa <- interpolar_mes_aislado(mensual, etiqueta)
  q <- agregar_trimestral_promedio(completa[, c("periodo", "valor")], etiqueta)
  attr(q, "meses_interpolados") <- completa$periodo[completa$interpolado]
  q
}

# --- Metas anuales (F6-16) ---------------------------------------------------------------------

#' Ultimo año con sus cuatro trimestres en una historia trimestral contigua.
ultimo_anio_completo <- function(historia_q, etiqueta) {
  .exigir_trimestral_contigua(historia_q, etiqueta)
  conteo <- table(.anio_q(historia_q$periodo))
  completos <- as.integer(names(conteo)[conteo == 4L])
  if (length(completos) == 0) stop("FALLO VISIBLE [", etiqueta, "]: la historia no tiene ningun año completo.")
  max(completos)
}

#' Vector anual nombrado (nombres = años) a partir de una serie anual larga (periodo "AAAA",
#' valor). stop() ante periodos mal formados, repetidos o NA.
serie_anual_a_vector <- function(anual, etiqueta) {
  if (!all(grepl("^[0-9]{4}$", anual$periodo))) stop("FALLO VISIBLE [", etiqueta, "]: periodo anual mal formado.")
  if (anyDuplicated(anual$periodo)) stop("FALLO VISIBLE [", etiqueta, "]: años repetidos.")
  if (anyNA(anual$valor)) stop("FALLO VISIBLE [", etiqueta, "]: valores anuales ausentes.")
  stats::setNames(as.numeric(anual$valor), anual$periodo)
}

.exigir_anios <- function(v, anios, etiqueta, que) {
  falta <- setdiff(as.character(anios), names(v))
  if (length(falta) > 0) {
    stop("FALLO VISIBLE [", etiqueta, "]: ", que, " no cubre los años ", paste(falta, collapse = ", "), ".")
  }
  v[as.character(anios)]
}

#' Metas anuales A_y de F6-16: A_{Y0} = promedio de los cuatro trimestres del ultimo año completo
#' de la historia, y A_y = A_{y-1} * (1 + g_y / 100) hasta `anio_fin`. `crecimiento` es un vector
#' anual nombrado en %, que debe cubrir Y0+1..anio_fin. Devuelve el vector nombrado Y0..anio_fin
#' (Y0 incluido como referencia; no es una restriccion del sendero).
metas_anuales <- function(historia_q, crecimiento, etiqueta, anio_fin = ANIO_FIN_SENDERO) {
  y0 <- ultimo_anio_completo(historia_q, etiqueta)
  if (y0 >= anio_fin) stop("FALLO VISIBLE [", etiqueta, "]: el ultimo año completo (", y0, ") no es anterior a ", anio_fin, ".")
  anios <- (y0 + 1L):anio_fin
  g <- .exigir_anios(crecimiento, anios, etiqueta, "el crecimiento anual")
  a <- numeric(length(anios) + 1L)
  a[1] <- mean(historia_q$valor[.anio_q(historia_q$periodo) == y0])
  for (k in seq_along(anios)) a[k + 1L] <- a[k] * (1 + g[[k]] / 100)
  stats::setNames(a, as.character(y0:anio_fin))
}

#' Crecimiento anual en % implicito en un nivel anual: g_y = 100 * (P_y / P_{y-1} - 1). Para el
#' petroleo, cuyo WEO publica el precio y no su variacion: encadenar g_y sobre la historia propia
#' (F6-16) en vez de tomar el nivel del WEO.
crecimiento_desde_nivel <- function(nivel) {
  anios <- as.integer(names(nivel))
  if (is.unsorted(anios) || any(diff(anios) != 1L)) stop("FALLO VISIBLE: el nivel anual no tiene años contiguos.")
  stats::setNames(100 * (nivel[-1] / nivel[-length(nivel)] - 1), names(nivel)[-1])
}

# --- Denton-Cholette con trimestres fijos (F6-16) ----------------------------------------------

#' Sendero trimestral que minimiza la suma de cuadrados de las primeras diferencias sobre la grilla
#' completa, con los valores no NA de `x` fijos y la restriccion de que cada año de `metas` (vector
#' nombrado por año) promedie su meta. `anio` es el año de cada posicion de `x`. Cada año con meta
#' tiene que tener sus cuatro trimestres en la grilla y al menos uno libre. Forma cerrada: sistema
#' KKT [2 D_L'D_L, C_L'; C_L, 0] [z; lambda] = [-2 D_L' D_F c; b - C_F c], con L las posiciones
#' libres, F las fijas y c sus valores. Sin fijos es el Denton-Cholette aditivo de primeras
#' diferencias (el de tempdisagg con indicador constante). Devuelve `x` completo.
denton_cholette <- function(x, anio, metas, etiqueta) {
  n <- length(x)
  if (length(anio) != n || n < 2) stop("FALLO VISIBLE [", etiqueta, "]: grilla de Denton mal formada.")
  libres <- which(is.na(x))
  if (length(libres) == 0) stop("FALLO VISIBLE [", etiqueta, "]: Denton sin trimestres libres.")
  anios_meta <- as.integer(names(metas))
  for (y in anios_meta) {
    if (sum(anio == y) != 4L) stop("FALLO VISIBLE [", etiqueta, "]: el año ", y, " no tiene cuatro trimestres en la grilla.")
    if (!any(is.na(x[anio == y]))) stop("FALLO VISIBLE [", etiqueta, "]: el año ", y, " tiene meta y ningun trimestre libre.")
  }
  sin_meta <- setdiff(unique(anio[libres]), anios_meta)
  if (length(sin_meta) > 0) stop("FALLO VISIBLE [", etiqueta, "]: trimestres libres en años sin meta: ", paste(sin_meta, collapse = ", "))
  fijos <- setdiff(seq_len(n), libres)
  D <- diff(diag(n))
  C <- t(vapply(anios_meta, function(y) as.numeric(anio == y) / 4, numeric(n)))
  if (length(anios_meta) == 1) C <- matrix(C, nrow = 1)
  b <- as.numeric(metas)
  DL <- D[, libres, drop = FALSE]; CL <- C[, libres, drop = FALSE]
  cf <- x[fijos]
  rhs1 <- if (length(fijos)) -2 * crossprod(DL, D[, fijos, drop = FALSE] %*% cf) else matrix(0, length(libres), 1)
  rhs2 <- if (length(fijos)) b - C[, fijos, drop = FALSE] %*% cf else matrix(b, ncol = 1)
  k <- length(libres); m <- nrow(C)
  M <- rbind(cbind(2 * crossprod(DL), t(CL)), cbind(CL, matrix(0, m, m)))
  sol <- tryCatch(solve(M, c(rhs1, rhs2)), error = function(e) {
    stop("FALLO VISIBLE [", etiqueta, "]: el sistema de Denton es singular: ", conditionMessage(e))
  })
  x[libres] <- sol[seq_len(k)]
  x
}

# --- T014: senderos de escenario ---------------------------------------------------------------

#' Sendero trimestral desde la historia y las metas anuales: grilla desde el primer trimestre del
#' primer año con meta (o desde el ultimo observado, si es anterior) hasta anio_fin-T4, con todos
#' los trimestres de la historia fijos. Devuelve data.frame(periodo, valor, tramo) sobre la
#' historia completa mas el sendero, con tramo "historia" o "sendero".
.sendero_desde_metas <- function(historia_q, metas, etiqueta, anio_fin = ANIO_FIN_SENDERO) {
  .exigir_trimestral_contigua(historia_q, etiqueta)
  y0 <- as.integer(names(metas)[1])
  metas_libres <- metas[-1]
  i_hist <- .q_a_ind(historia_q$periodo)
  i_ini <- min(max(i_hist), 4L * (y0 + 1L))
  i_fin <- 4L * anio_fin + 3L
  if (max(i_hist) >= i_fin) stop("FALLO VISIBLE [", etiqueta, "]: la historia ya llega a ", anio_fin, "-Q4.")
  grilla <- i_ini:i_fin
  x <- rep(NA_real_, length(grilla))
  en_hist <- grilla %in% i_hist
  x[en_hist] <- historia_q$valor[match(grilla[en_hist], i_hist)]
  x <- denton_cholette(x, grilla %/% 4L, metas_libres, etiqueta)
  nuevos <- grilla > max(i_hist)
  rbind(
    data.frame(periodo = historia_q$periodo, valor = historia_q$valor, tramo = "historia", stringsAsFactors = FALSE),
    data.frame(periodo = .ind_a_q(grilla[nuevos]), valor = x[nuevos], tramo = "sendero", stringsAsFactors = FALSE)
  )
}

.con_metas <- function(sendero, metas) { attr(sendero, "metas") <- metas; sendero }

#' T014, base de una variable cuyo WEO publica el crecimiento anual (PIB: `NGDP_RPCH`; IPC:
#' `PCPIPCH`). `crecimiento_anual` es la serie anual larga del WEO. El atributo "metas" guarda las
#' metas anuales (lo usan las validaciones).
sendero_escenario_crecimiento <- function(historia_q, crecimiento_anual, etiqueta) {
  metas <- metas_anuales(historia_q, serie_anual_a_vector(crecimiento_anual, etiqueta), etiqueta)
  .con_metas(.sendero_desde_metas(historia_q, metas, etiqueta), metas)
}

#' T014, PIB de un escenario con desvio de NIVEL en % de la base (F6-14): A^esc_y = A^base_y *
#' (1 + d_y / 100). El desvio tiene que cubrir todos los años con meta.
sendero_escenario_desvio_nivel <- function(historia_q, crecimiento_anual, desvio_anual, etiqueta) {
  base <- metas_anuales(historia_q, serie_anual_a_vector(crecimiento_anual, etiqueta), etiqueta)
  anios <- as.integer(names(base))[-1]
  d <- .exigir_anios(serie_anual_a_vector(desvio_anual, etiqueta), anios, etiqueta, "el desvio del escenario")
  metas <- base
  metas[-1] <- base[-1] * (1 + d / 100)
  .con_metas(.sendero_desde_metas(historia_q, metas, etiqueta), metas)
}

#' T014, IPC de un escenario con desvio de la INFLACION en pp (F6-14): inflacion del escenario =
#' inflacion de la base + d_y, y el indice se encadena con ella.
sendero_escenario_desvio_crecimiento <- function(historia_q, crecimiento_anual, desvio_anual, etiqueta) {
  g <- serie_anual_a_vector(crecimiento_anual, etiqueta)
  y0 <- ultimo_anio_completo(historia_q, etiqueta)
  anios <- (y0 + 1L):ANIO_FIN_SENDERO
  d <- .exigir_anios(serie_anual_a_vector(desvio_anual, etiqueta), anios, etiqueta, "el desvio del escenario")
  g_esc <- .exigir_anios(g, anios, etiqueta, "el crecimiento anual") + d
  metas <- metas_anuales(historia_q, g_esc, etiqueta)
  .con_metas(.sendero_desde_metas(historia_q, metas, etiqueta), metas)
}

#' T014, precio cuyo WEO publica el NIVEL anual (petroleo `POILAPSP`, USD): se encadena el
#' crecimiento implicito en ese nivel (crecimiento_desde_nivel()) sobre la historia propia.
sendero_escenario_nivel_anual <- function(historia_q, nivel_anual, etiqueta) {
  g <- crecimiento_desde_nivel(serie_anual_a_vector(nivel_anual, etiqueta))
  metas <- metas_anuales(historia_q, g, etiqueta)
  .con_metas(.sendero_desde_metas(historia_q, metas, etiqueta), metas)
}

# --- Validaciones de F6-18 (todas stop()) ------------------------------------------------------

#' Promedio de cada año completo de una serie trimestral (vector nombrado por año).
promedio_anual_q <- function(serie) {
  a <- .anio_q(serie$periodo)
  conteo <- table(a)
  completos <- as.integer(names(conteo)[conteo == 4L])
  stats::setNames(vapply(completos, function(y) mean(serie$valor[a == y]), numeric(1)), completos)
}

#' (1) El promedio de cada año proyectado iguala su meta (error relativo <= TOL_META).
validar_metas <- function(sendero, metas, etiqueta) {
  pa <- promedio_anual_q(sendero)
  m <- metas[-1]
  falta <- setdiff(names(m), names(pa))
  if (length(falta)) stop("FALLO VISIBLE [V-ESC-1 ", etiqueta, "]: años con meta sin cuatro trimestres: ", paste(falta, collapse = ", "))
  err <- abs(pa[names(m)] / m - 1)
  if (any(!is.finite(err)) || max(err) > TOL_META) {
    stop("FALLO VISIBLE [V-ESC-1 ", etiqueta, "]: el promedio anual no iguala la meta; error relativo maximo ",
         signif(max(err), 3), " en ", names(m)[which.max(err)], " (tolerancia ", TOL_META, ").")
  }
  invisible(max(err))
}

#' (2) La historia de cada serie de escenario es bit a bit la de su serie historica.
validar_historia <- function(sendero, historia_q, etiqueta) {
  h <- sendero[sendero$tramo == "historia", ]
  if (!identical(h$periodo, historia_q$periodo) || !identical(h$valor, historia_q$valor)) {
    stop("FALLO VISIBLE [V-ESC-2 ", etiqueta, "]: el tramo historico no es identico a la serie historica.")
  }
  invisible(TRUE)
}

#' (2, entre escenarios) Mismos periodos e historia identica en todos los escenarios de una
#' variable. `senderos` es una lista nombrada por escenario.
validar_historia_comun <- function(senderos, etiqueta) {
  ref <- senderos[[1]]
  for (s in names(senderos)[-1]) {
    x <- senderos[[s]]
    if (!identical(x$periodo, ref$periodo) || !identical(x$tramo, ref$tramo) ||
        !identical(x$valor[x$tramo == "historia"], ref$valor[ref$tramo == "historia"])) {
      stop("FALLO VISIBLE [V-ESC-2 ", etiqueta, "]: el escenario ", s, " no comparte periodos o historia con ", names(senderos)[1], ".")
    }
  }
  invisible(TRUE)
}

#' (3) Desvio contra la base, sobre los promedios anuales de los senderos. tipo "nivel_pct":
#' esc / base - 1 = d / 100; tipo "crecimiento_pp": inflacion(esc) - inflacion(base) = d, con la
#' inflacion anual en % de los promedios anuales. A TOL_DESVIO en todos los años con meta.
validar_desvio <- function(sendero_esc, sendero_base, desvio_anual, tipo, etiqueta) {
  pe <- promedio_anual_q(sendero_esc); pb <- promedio_anual_q(sendero_base)
  anios <- intersect(names(attr(sendero_esc, "metas"))[-1], names(pb))
  d <- .exigir_anios(serie_anual_a_vector(desvio_anual, etiqueta), as.integer(anios), etiqueta, "el desvio")
  obs <- switch(tipo,
    nivel_pct = pe[anios] / pb[anios] - 1 - d / 100,
    crecimiento_pp = {
      prev <- as.character(as.integer(anios) - 1L)
      if (!all(prev %in% names(pb))) stop("FALLO VISIBLE [V-ESC-3 ", etiqueta, "]: falta el año previo para la inflacion.")
      100 * (pe[anios] / pe[prev] - 1) - 100 * (pb[anios] / pb[prev] - 1) - d
    },
    stop("FALLO VISIBLE [V-ESC-3 ", etiqueta, "]: tipo de desvio desconocido '", tipo, "'."))
  if (any(!is.finite(obs)) || max(abs(obs)) > TOL_DESVIO) {
    stop("FALLO VISIBLE [V-ESC-3 ", etiqueta, "]: el desvio contra la base no reproduce el publicado; ",
         "diferencia maxima ", signif(max(abs(obs)), 3), " en ", anios[which.max(abs(obs))], ".")
  }
  invisible(max(abs(obs)))
}

#' (4) Sin NA, niveles positivos, trimestres contiguos y fin >= o + H_MAX_FASE6.
validar_estructura <- function(sendero, origen, etiqueta) {
  .exigir_trimestral_contigua(sendero, etiqueta)
  if (any(sendero$valor <= 0)) {
    stop("FALLO VISIBLE [V-ESC-4 ", etiqueta, "]: niveles no positivos en ", paste(head(sendero$periodo[sendero$valor <= 0], 5), collapse = ", "))
  }
  fin_min <- .q_a_ind(origen) + H_MAX_FASE6
  if (.q_a_ind(sendero$periodo[nrow(sendero)]) < fin_min) {
    stop("FALLO VISIBLE [V-ESC-4 ", etiqueta, "]: el sendero termina en ", sendero$periodo[nrow(sendero)],
         " y el origen ", origen, " exige llegar a ", .ind_a_q(fin_min), ".")
  }
  invisible(TRUE)
}

#' Promedio de cada año con sus 12 meses de una serie mensual (sin NA en esos meses).
promedio_anual_m <- function(mensual) {
  a <- as.integer(substr(mensual$periodo, 1, 4))
  ok <- !is.na(mensual$valor)
  conteo <- table(a[ok])
  completos <- as.integer(names(conteo)[conteo == 12L])
  stats::setNames(vapply(completos, function(y) mean(mensual$valor[ok & a == y]), numeric(1)), completos)
}

#' (5) El promedio anual del petroleo mensual en USD iguala `POILAPSP` del WEO (error relativo <=
#' TOL_PETROLEO_WEO) en los años completos comunes. Devuelve el error maximo y los años.
validar_petroleo_weo <- function(petroleo_m, poilapsp_anual, etiqueta = "FMI.PETROLEO_APSP.USD") {
  pa <- promedio_anual_m(petroleo_m)
  w <- serie_anual_a_vector(poilapsp_anual, etiqueta)
  comunes <- intersect(names(pa), names(w))
  if (length(comunes) == 0) stop("FALLO VISIBLE [V-ESC-5 ", etiqueta, "]: sin años completos comunes con el WEO.")
  err <- abs(pa[comunes] / w[comunes] - 1)
  if (max(err) > TOL_PETROLEO_WEO) {
    stop("FALLO VISIBLE [V-ESC-5 ", etiqueta, "]: el promedio anual no reproduce POILAPSP del WEO; error relativo ",
         signif(max(err), 3), " en ", comunes[which.max(err)], " (tolerancia ", TOL_PETROLEO_WEO, ").")
  }
  invisible(list(error_max = max(err), anios = range(as.integer(comunes))))
}

#' (6) La inflacion anual del IPC mensual (promedio anual de los 12 meses observados, sin el mes
#' interpolado) difiere de `PCPIPCH` del WEO en <= TOL_IPC_WEO_PP en los años completos comunes
#' (el año y su anterior con sus 12 meses).
validar_ipc_weo <- function(ipc_m, pcpipch_anual, etiqueta = "FRED.IPC_EEUU") {
  pa <- promedio_anual_m(ipc_m)
  anios <- as.integer(names(pa))
  con_previo <- anios[(anios - 1L) %in% anios]
  infl <- stats::setNames(100 * (pa[as.character(con_previo)] / pa[as.character(con_previo - 1L)] - 1), con_previo)
  w <- serie_anual_a_vector(pcpipch_anual, etiqueta)
  comunes <- intersect(names(infl), names(w))
  if (length(comunes) == 0) stop("FALLO VISIBLE [V-ESC-6 ", etiqueta, "]: sin años completos comunes con el WEO.")
  dif <- abs(infl[comunes] - w[comunes])
  if (max(dif) > TOL_IPC_WEO_PP) {
    stop("FALLO VISIBLE [V-ESC-6 ", etiqueta, "]: la inflacion anual difiere de PCPIPCH del WEO en ",
         signif(max(dif), 3), " pp en ", comunes[which.max(dif)], " (tolerancia ", TOL_IPC_WEO_PP, " pp).")
  }
  invisible(list(dif_max = max(dif), anios = range(as.integer(comunes))))
}

#' Solo informativo (F6-18): diferencia maxima entre el crecimiento anual del PIB trimestral propio
#' y `NGDP_RPCH` del WEO, en pp, en los años completos comunes. Difiere por vintage; no detiene.
comparar_pib_weo <- function(pib_q, ngdp_rpch_anual) {
  pa <- promedio_anual_q(pib_q)
  anios <- as.integer(names(pa))
  con_previo <- anios[(anios - 1L) %in% anios]
  g <- stats::setNames(100 * (pa[as.character(con_previo)] / pa[as.character(con_previo - 1L)] - 1), con_previo)
  w <- serie_anual_a_vector(ngdp_rpch_anual, "WEO")
  comunes <- intersect(names(g), names(w))
  dif <- g[comunes] - w[comunes]
  list(dif_max = max(abs(dif)), anio = comunes[which.max(abs(dif))], anios = range(as.integer(comunes)))
}
