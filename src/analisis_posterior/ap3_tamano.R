# src/analisis_posterior/ap3_tamano.R
#
# Análisis posterior AP-3 de Fase 5 (doc/metodologia/decisiones_fase5.md, «Análisis posteriores»): Monte Carlo del
# tamaño de las dos pruebas que Fase 5 publicó con `tamano_no_verificado`: Giacomini-White (R1, F4-17; prueba_gw()) y
# el contraste de cambio del diferencial entre submuestras (R3, F4-28; prueba_cambio_diferencial()). Usa las funciones
# del motor tal cual. Diseño aprobado por Harold el 2026-10-15 (sin cambios): solo tamaño, 3 DGP bajo H0, 2 000 réplicas.
#
# DGP bajo H0 (igual capacidad predictiva; esquema de V7): el error de cada modelo a h pasos es la suma de h
# innovaciones de varianza 1, una MA(h − 1).
#   D1  innovaciones N(0, 1) independientes entre modelos (el DGP de V7)
#   D2  innovaciones N(0, 1) con correlación 0,9 entre modelos
#   D3  innovaciones t de Student con 5 gl reescaladas a varianza 1, independientes entre modelos
# Celdas: las de Fase 5. GW: G1, G2, G3 × h = 1, 2, 4, 8, con el n de la corrida principal (GW usa n − h pares).
# Estabilidad: G1, G2 × h = 1, 2, 4, 8, con n_pre y n_post de tabla_estabilidad_fase5.csv (pre primero).
#
# No lee datos del proyecto. Escribe doc/metodologia/reportes_fase5/posteriores/ap3_tamano.csv (LF).
# Uso: Rscript src/analisis_posterior/ap3_tamano.R

source(here::here("src", "evaluacion", "eval_lib.R"))
source(here::here("src", "evaluacion", "tabla_resultados_fase4.R"))            # escribir_tabla_resultados()

DIR_AP <- here::here("doc", "metodologia", "reportes_fase5", "posteriores")
SEMILLA_AP3 <- 20261015L
REPLICAS_AP3 <- 2000L
RHO_D2_AP3 <- 0.9
GL_D3_AP3 <- 5
CELDAS_GW_AP3 <- data.frame(grupo = rep(c("G1", "G2", "G3"), each = 4), h = rep(c(1L, 2L, 4L, 8L), 3),
                            n = c(52L, 51L, 49L, 45L, 45L, 44L, 42L, 38L, 25L, 24L, 22L, 18L))
CELDAS_ESTAB_AP3 <- data.frame(grupo = rep(c("G1", "G2"), each = 4), h = rep(c(1L, 2L, 4L, 8L), 2),
                               n_pre = c(27L, 26L, 24L, 20L, 20L, 19L, 17L, 13L), n_post = 25L)

#' Errores de dos modelos bajo H0, MA(h − 1) de innovaciones de varianza 1, según el DGP.
errores_h0 <- function(n, h, dgp) {
  m <- n + h - 1L
  innov <- switch(dgp,
    D1 = cbind(stats::rnorm(m), stats::rnorm(m)),
    D2 = { u <- stats::rnorm(m); cbind(u, RHO_D2_AP3 * u + sqrt(1 - RHO_D2_AP3^2) * stats::rnorm(m)) },
    D3 = cbind(stats::rt(m, GL_D3_AP3), stats::rt(m, GL_D3_AP3)) * sqrt((GL_D3_AP3 - 2) / GL_D3_AP3),
    stop("AP-3: DGP desconocido ", dgp))
  ma <- function(u) as.numeric(stats::filter(u, rep(1, h), sides = 1))[h:m]
  list(e1 = ma(innov[, 1]), e2 = ma(innov[, 2]))
}

#' p-valores de una prueba en R réplicas de una celda; NA si la prueba no está definida en la réplica.
p_valores_celda <- function(prueba, celda, dgp, R = REPLICAS_AP3) {
  vapply(seq_len(R), function(r) {
    if (prueba == "gw") {
      e <- errores_h0(celda$n, celda$h, dgp)
      prueba_gw(e$e1, e$e2, celda$h)$p_valor
    } else {
      n <- celda$n_pre + celda$n_post
      e <- errores_h0(n, celda$h, dgp)
      post <- c(rep(0, celda$n_pre), rep(1, celda$n_post))
      tryCatch(prueba_cambio_diferencial(e$e1, e$e2, post, celda$h)$p_valor, error = function(err) NA_real_)
    }
  }, numeric(1))
}

#' Tamaño al 5 % y al 10 % con su error de Monte Carlo, y tasa de réplicas sin prueba definida.
resumir_celda <- function(p, prueba, dgp, celda) {
  ok <- !is.na(p); R <- sum(ok)
  t05 <- mean(p[ok] < 0.05); t10 <- mean(p[ok] < 0.10)
  data.frame(prueba = prueba, dgp = dgp, grupo = celda$grupo, h = celda$h,
             n = if (is.null(celda$n)) celda$n_pre + celda$n_post else celda$n,
             n_pre = if (is.null(celda$n_pre)) NA_integer_ else celda$n_pre,
             n_post = if (is.null(celda$n_post)) NA_integer_ else celda$n_post,
             replicas = length(p), replicas_definidas = R,
             tamano_05 = t05, ee_mc_05 = sqrt(0.05 * 0.95 / R), tamano_10 = t10, ee_mc_10 = sqrt(0.10 * 0.90 / R),
             fuera_05 = abs(t05 - 0.05) > 2 * sqrt(0.05 * 0.95 / R), fuera_10 = abs(t10 - 0.10) > 2 * sqrt(0.10 * 0.90 / R),
             stringsAsFactors = FALSE)
}

#' Corre todas las celdas y DGP. La semilla depende de (prueba, DGP, celda), así que cada celda se reproduce sola.
estudio_tamano <- function(R = REPLICAS_AP3, dgps = c("D1", "D2", "D3")) {
  out <- list()
  for (prueba in c("gw", "estabilidad")) {
    celdas <- if (prueba == "gw") CELDAS_GW_AP3 else CELDAS_ESTAB_AP3
    for (dgp in dgps) for (i in seq_len(nrow(celdas))) {
      set.seed(semilla_de(paste0("AP3_", SEMILLA_AP3), paste(prueba, dgp), i))
      p <- p_valores_celda(prueba, celdas[i, ], dgp, R)
      out[[length(out) + 1L]] <- resumir_celda(p, prueba, dgp, celdas[i, ])
    }
  }
  do.call(rbind, out)
}

if (sys.nframe() == 0L) {
  res <- estudio_tamano()
  dir.create(DIR_AP, showWarnings = FALSE, recursive = TRUE)
  ruta <- file.path(DIR_AP, "ap3_tamano.csv")
  escribir_tabla_resultados(res, ruta)
  cat(sprintf("ap3_tamano.csv: %d filas, sha256 %s\n", nrow(res), digest::digest(file = ruta, algo = "sha256")))
}
