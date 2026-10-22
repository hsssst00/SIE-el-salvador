# combinacion.R
#
# Guarda, combinación e intervalos del Ejercicio B (checklist de Fase 6, D4; F6-02, F6-02-a, F6-07, F6-07-a,
# F6-07-b, F6-08, F6-08-a de doc/metodologia/decisiones_fase6.md; protocolo_proyeccion.md §7). Toma, para un grupo y
# un escenario, los resultados de predecir_condicional() de los elegibles (src/proyeccion/condicional.R) y aplica la
# regla de §7 en su orden:
#
#   1. Guarda (F6-08). El interanual del sendero puntual (100 · Δ₄ log, bases observadas con h <= 4, como
#      derivar_unidades()) debe quedar en [mín − X, máx + X] en todo h = 1..20. Mínimo, máximo y X (una desviación
#      estándar) salen del interanual histórico del objetivo sin los períodos de 2020 y 2021 (F6-08-a). El rango se
#      calcula con rango_guarda() y se escribe en el YAML de Fase 6 al congelar (E1); aquí solo se aplica.
#   2. Mínimo (F6-02). Menos de DISENO_FASE6$min_miembros que pasan la guarda: stop().
#   3. Mediana (F6-02, F6-02-a) trimestre a trimestre de los Δy de los senderos puntuales que pasan; el nivel se
#      acumula desde el log-nivel observado en el origen.
#   4. Intervalos (F6-07). Por modelo, de su densidad; para la combinación, la mezcla con pesos iguales de las
#      densidades de los miembros que pasan. La densidad de un miembro es la normal N(media, cov) de su
#      predecir_condicional(), también en el BVAR (F6-07-b). La mezcla no se recentra en la mediana (F6-07-a). Bandas
#      del 80 y del 95 % en log-nivel, interanual y trimestral; con h > 8, marca `sin_calibrar`.
#
# Sin I/O y sin estado global. El objetivo llega como data.frame(periodo, y) con el log-nivel SA observado hasta el
# origen, en la convención de eval_lib.R.

source(here::here("src", "proyeccion", "condicional.R"))   # DISENO_FASE6, cuantil_mezcla_normal(), eval_lib

ANIOS_FUERA_GUARDA <- c(2020L, 2021L)   # F6-08-a: el rango histórico se calcula sin los interanuales de 2020 y 2021

UNIDADES_FASE6 <- c("log_nivel", "yoy_pp", "qoq_pp")   # F6-11: nivel, interanual y trimestral (unidades de F4-04)

# ---------------------------------------------------------------------------------------------
# Unidades
# ---------------------------------------------------------------------------------------------

#' Valida el objetivo (data.frame periodo, y) y lo devuelve con `i` = índice trimestral. Falla si está vacío,
#' desordenado, con huecos o con valores no finitos.
.objetivo_fase6 <- function(objetivo, donde) {
  if (!is.data.frame(objetivo) || !all(c("periodo", "y") %in% names(objetivo)) || !nrow(objetivo)) stop(donde, ": el objetivo debe ser data.frame(periodo, y) con filas")
  i <- q_a_ind(objetivo$periodo)
  if (any(diff(i) != 1L)) stop(donde, ": el objetivo tiene trimestres faltantes, repetidos o desordenados")
  if (any(!is.finite(objetivo$y))) stop(donde, ": el objetivo trae valores no finitos")
  objetivo$i <- i
  objetivo
}

#' Sendero (log-nivel, h valores desde o+1) en las tres unidades de F4-04, con las bases observadas del objetivo
#' (derivar_unidades()). Devuelve una matriz h x 3 con colnames UNIDADES_FASE6.
unidades_sendero <- function(sendero, objetivo, o) {
  pron <- data.frame(modelo_id = "sendero", origen = as.integer(o), h = seq_along(sendero),
                     log_nivel_pronosticado = as.numeric(sendero), stringsAsFactors = FALSE)
  u <- derivar_unidades(pron, objetivo)
  r <- cbind(u$log_nivel_pronosticado, u$yoy_pp_pronosticado, u$qoq_pp_pronosticado)
  colnames(r) <- UNIDADES_FASE6
  r
}

# ---------------------------------------------------------------------------------------------
# 1. Guarda (F6-08, F6-08-a)
# ---------------------------------------------------------------------------------------------

#' Rango permitido del interanual: [mín − X, máx + X], con X la desviación estándar muestral, sobre los interanuales
#' históricos del objetivo cuyo período no cae en ANIOS_FUERA_GUARDA. El objetivo es el log-nivel SA propio de L3 del
#' corte (F6-08-a).
rango_guarda <- function(objetivo, anios_fuera = ANIOS_FUERA_GUARDA) {
  d <- .objetivo_fase6(objetivo, "rango_guarda")
  n <- nrow(d)
  if (n < 6L) stop("rango_guarda: el objetivo tiene menos de 6 trimestres")
  yoy <- 100 * (d$y[5:n] - d$y[1:(n - 4L)])
  yoy <- yoy[!as.integer(d$i[5:n]) %/% 4L %in% anios_fuera]
  if (length(yoy) < 2L) stop("rango_guarda: menos de 2 interanuales fuera de ", paste(anios_fuera, collapse = " y "))
  X <- stats::sd(yoy)
  list(inferior = min(yoy) - X, superior = max(yoy) + X, minimo = min(yoy), maximo = max(yoy), X = X, n = length(yoy))
}

#' Aplica la guarda a los senderos puntuales `senderos` (lista nombrada por modelo_id de vectores de log-nivel con h
#' valores). Devuelve un data.frame por modelo: pasa, primer h fuera del rango (NA si pasa) e interanual mínimo y
#' máximo del sendero. Los bordes del rango están permitidos.
aplicar_guarda <- function(senderos, objetivo, o, rango) {
  if (!is.list(senderos) || !length(senderos) || is.null(names(senderos)) || anyDuplicated(names(senderos))) stop("aplicar_guarda: `senderos` debe ser una lista nombrada por modelo_id, sin repetidos")
  if (!is.list(rango) || !all(c("inferior", "superior") %in% names(rango)) || !(rango$inferior < rango$superior)) stop("aplicar_guarda: `rango` mal formado")
  .objetivo_fase6(objetivo, "aplicar_guarda")
  filas <- lapply(names(senderos), function(id) {
    s <- senderos[[id]]
    if (!is.numeric(s) || !length(s) || any(!is.finite(s))) stop("aplicar_guarda: el sendero de ", id, " no es finito")
    yoy <- unidades_sendero(s, objetivo, o)[, "yoy_pp"]
    fuera <- which(yoy < rango$inferior | yoy > rango$superior)
    data.frame(modelo_id = id, pasa = !length(fuera), h_fuera = if (length(fuera)) fuera[1] else NA_integer_,
               yoy_min = min(yoy), yoy_max = max(yoy), stringsAsFactors = FALSE)
  })
  do.call(rbind, filas)
}

# ---------------------------------------------------------------------------------------------
# 2 y 3. Mínimo y mediana (F6-02, F6-02-a)
# ---------------------------------------------------------------------------------------------

#' Mediana trimestre a trimestre de los Δy de `senderos` (lista de vectores de log-nivel con h valores), con Δy_1
#' medido desde `y_o`, el log-nivel observado en el origen. Devuelve el log-nivel acumulado. stop() si hay menos de
#' `min_miembros` (F6-02).
combinar_mediana <- function(senderos, y_o, min_miembros = DISENO_FASE6$min_miembros, etiqueta = "?") {
  if (length(senderos) < min_miembros) stop(sprintf("combinar_mediana: %s tiene %d miembros después de la guarda y el mínimo es %d (F6-02)", etiqueta, length(senderos), min_miembros))
  h <- unique(lengths(senderos))
  if (length(h) != 1L) stop("combinar_mediana: ", etiqueta, ": los senderos no tienen el mismo largo")
  if (length(y_o) != 1L || !is.finite(y_o)) stop("combinar_mediana: ", etiqueta, ": `y_o` debe ser un log-nivel finito")
  dy <- vapply(senderos, function(s) diff(c(y_o, s)), numeric(h))
  dy <- matrix(dy, nrow = h)
  y_o + cumsum(apply(dy, 1L, stats::median))
}

# ---------------------------------------------------------------------------------------------
# 4. Intervalos (F6-07, F6-07-a, F6-07-b)
# ---------------------------------------------------------------------------------------------

#' Bandas de la mezcla con pesos iguales de las normales N(media, cov) de `densidades` (lista de list(media, cov) en
#' log-nivel, h valores). Con un solo miembro son las bandas de ese modelo. Cada miembro pasa a cada unidad con su
#' media (unidades_sendero()) y su desviación (sd_unidades_densidad()); la banda del nivel q es el par de cuantiles
#' (1 − q)/2 y (1 + q)/2 de la mezcla de esas marginales. Devuelve un data.frame largo: h, periodo, unidad, nivel,
#' inferior, superior, sin_calibrar.
bandas_mezcla <- function(densidades, objetivo, o, niveles = DISENO_FASE6$niveles,
                          h_calibrado = DISENO_FASE6$h_calibrado) {
  if (!is.list(densidades) || !length(densidades)) stop("bandas_mezcla: no hay densidades")
  h <- length(densidades[[1]]$media)
  if (any(lengths(lapply(densidades, `[[`, "media")) != h)) stop("bandas_mezcla: las densidades no tienen el mismo largo")
  for (d in densidades) validar_densidad(d, d$media, "bandas_mezcla")
  medias <- lapply(densidades, function(d) unidades_sendero(d$media, objetivo, o))
  sds <- lapply(densidades, function(d) sd_unidades_densidad(d$cov))
  per <- periodos_fase6(o, h)
  filas <- list()
  for (u in seq_along(UNIDADES_FASE6)) {
    mu <- do.call(rbind, lapply(medias, function(m) m[, u]))
    s <- do.call(rbind, lapply(sds, function(m) m[, u]))
    for (q in niveles) {
      filas[[length(filas) + 1L]] <- data.frame(
        h = seq_len(h), periodo = per, unidad = UNIDADES_FASE6[u], nivel = q,
        inferior = cuantil_mezcla_normal(mu, s, (1 - q) / 2), superior = cuantil_mezcla_normal(mu, s, (1 + q) / 2),
        sin_calibrar = seq_len(h) > h_calibrado, stringsAsFactors = FALSE)
    }
  }
  res <- do.call(rbind, filas)
  rownames(res) <- NULL
  res
}

# ---------------------------------------------------------------------------------------------
# Regla completa de un grupo y escenario
# ---------------------------------------------------------------------------------------------

#' Aplica la regla de §7 a `resultados` (lista nombrada por modelo_id de predecir_condicional() de los elegibles de
#' un grupo en un escenario). Devuelve:
#'   guarda       aplicar_guarda() de todos los modelos (la exclusión va al manifiesto)
#'   miembros     modelo_id de los que pasan
#'   sendero      data.frame h, periodo y las tres unidades de la mediana
#'   bandas       bandas_mezcla() de los miembros (la combinación)
#'   bandas_modelo  bandas_mezcla() de cada modelo, con modelo_id, pase o no la guarda (se reporta marcado)
combinar_grupo <- function(resultados, objetivo, o, rango, etiqueta = "?",
                           min_miembros = DISENO_FASE6$min_miembros, niveles = DISENO_FASE6$niveles) {
  if (!is.list(resultados) || is.null(names(resultados)) || anyDuplicated(names(resultados))) stop("combinar_grupo: ", etiqueta, ": `resultados` debe ser una lista nombrada por modelo_id, sin repetidos")
  h <- unique(vapply(resultados, function(r) length(r$sendero), integer(1)))
  if (length(h) != 1L) stop("combinar_grupo: ", etiqueta, ": los modelos no tienen el mismo h")
  for (id in names(resultados)) validar_condicional(resultados[[id]], h, id)
  obj <- .objetivo_fase6(objetivo, "combinar_grupo")
  if (obj$i[nrow(obj)] != o) stop("combinar_grupo: ", etiqueta, ": el objetivo termina en ", ind_a_q(obj$i[nrow(obj)]), " y el origen es ", ind_a_q(o))
  guarda <- aplicar_guarda(lapply(resultados, `[[`, "sendero"), objetivo, o, rango)
  miembros <- guarda$modelo_id[guarda$pasa]
  med <- combinar_mediana(lapply(resultados[miembros], `[[`, "sendero"), obj$y[nrow(obj)], min_miembros, etiqueta)
  sendero <- data.frame(h = seq_len(h), periodo = periodos_fase6(o, h), unidades_sendero(med, objetivo, o), stringsAsFactors = FALSE)
  bandas <- bandas_mezcla(lapply(resultados[miembros], `[`, c("media", "cov")), objetivo, o, niveles)
  bandas_modelo <- do.call(rbind, lapply(names(resultados), function(id) {
    cbind(modelo_id = id, bandas_mezcla(list(resultados[[id]][c("media", "cov")]), objetivo, o, niveles), stringsAsFactors = FALSE)
  }))
  list(guarda = guarda, miembros = miembros, sendero = sendero, bandas = bandas, bandas_modelo = bandas_modelo)
}
