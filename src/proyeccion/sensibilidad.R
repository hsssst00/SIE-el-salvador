# sensibilidad.R
#
# Senderos del análisis de sensibilidad del Ejercicio B (checklist de Fase 6, D6; F6-09, F6-09-a, F6-18-c de
# doc/metodologia/decisiones_fase6.md; protocolo_proyeccion.md §8). Uno a la vez, sobre la base: cada variable de
# escenario se desplaza ±1 desviación estándar de su crecimiento anual en cada año proyectado, con las demás en la
# base. Tres variables (PIB e IPC de EE. UU. y petróleo, F6-15) dan seis corridas.
#
# Los senderos no van a L3 (F6-18-c): se arman aquí, en tiempo de corrida, con la misma función de T014
# (.sendero_desde_metas() de l3_escenarios_reglas.R) y las metas anuales de la serie ESC.*.BASE de L3, y quien corre
# los deja en el manifiesto de L4. Las metas de la base se leen como los promedios anuales de su sendero, que la
# validación 1 de F6-18 ya ató a sus metas con error relativo de 1e-10; así no hace falta volver al WEO.
# Sin I/O y sin estado global.

source(here::here("src", "transformacion", "l3_escenarios_reglas.R"))   # .sendero_desde_metas(), metas_anuales()

ANIOS_FUERA_SENSIBILIDAD <- c(2020L, 2021L)   # F6-09-a: sin 2020-2021, con el criterio de F6-08
SIGNOS_SENSIBILIDAD <- c(MAS = 1, MENOS = -1)  # F6-09: ±1 desviación estándar

# Variables de escenario de la sensibilidad (F6-09, nota del 2026-10-19): prefijo de su serie ESC.* de L3 (F6-18).
VARIABLES_SENSIBILIDAD <- c(PIB_EEUU = "ESC.PIB_EEUU.VOL.SA.Q", IPC_EEUU = "ESC.IPC_EEUU.IDX.SA.Q",
                            PETROLEO = "ESC.PETROLEO_APSP.USD.NSA.Q")

#' Serie ESC.* (data.frame periodo, valor, tramo) validada: tramos «historia» y «sendero», en ese orden.
.serie_esc <- function(esc, etiqueta) {
  if (!is.data.frame(esc) || !all(c("periodo", "valor", "tramo") %in% names(esc))) stop("sensibilidad [", etiqueta, "]: se espera data.frame(periodo, valor, tramo)")
  if (!all(esc$tramo %in% c("historia", "sendero")) || !any(esc$tramo == "sendero") || is.unsorted(esc$tramo == "sendero")) {
    stop("sensibilidad [", etiqueta, "]: los tramos deben ser historia y después sendero")
  }
  esc
}

#' Desviación estándar muestral del crecimiento anual (100 · (A_y / A_{y−1} − 1), A = promedio de los cuatro
#' trimestres) de la historia de una serie trimestral, desde su primer año completo hasta el último, sin los
#' crecimientos de los años en `anios_fuera` (F6-09-a).
sd_crecimiento_anual <- function(historia_q, etiqueta, anios_fuera = ANIOS_FUERA_SENSIBILIDAD) {
  .exigir_trimestral_contigua(historia_q, etiqueta)
  a <- promedio_anual_q(historia_q)
  anios <- as.integer(names(a))
  if (any(diff(anios) != 1L)) stop("sensibilidad [", etiqueta, "]: años completos no contiguos")
  g <- 100 * (a[-1] / a[-length(a)] - 1)
  g <- g[!anios[-1] %in% anios_fuera]
  if (length(g) < 2L) stop("sensibilidad [", etiqueta, "]: menos de 2 crecimientos anuales")
  stats::sd(g)
}

#' Metas anuales de la base (año ancla Y0 = último año completo de la historia, como metas_anuales(), hasta
#' ANIO_FIN_SENDERO): los promedios anuales de su sendero ESC.*.BASE.
metas_desde_sendero <- function(esc, etiqueta) {
  esc <- .serie_esc(esc, etiqueta)
  y0 <- ultimo_anio_completo(esc[esc$tramo == "historia", c("periodo", "valor")], etiqueta)
  pa <- promedio_anual_q(esc)
  .exigir_anios(pa, y0:ANIO_FIN_SENDERO, etiqueta, "el sendero base")
}

#' Sendero de sensibilidad de una variable (F6-09-a): el crecimiento anual de la base más `signo` · `sd` en cada año
#' proyectado (Y0 + 1 .. ANIO_FIN_SENDERO), encadenado sobre la historia y desagregado con la función de T014. Devuelve
#' el data.frame de la serie ESC.* (historia + sendero) con atributo "metas"; validar_metas() con stop().
sendero_sensibilidad <- function(esc_base, sd, signo, etiqueta) {
  esc_base <- .serie_esc(esc_base, etiqueta)
  if (length(sd) != 1L || !is.finite(sd) || sd <= 0) stop("sensibilidad [", etiqueta, "]: la desviación estándar debe ser positiva")
  if (!signo %in% SIGNOS_SENSIBILIDAD) stop("sensibilidad [", etiqueta, "]: signo no declarado")
  hist <- esc_base[esc_base$tramo == "historia", c("periodo", "valor")]
  base <- metas_desde_sendero(esc_base, etiqueta)
  g <- 100 * (base[-1] / base[-length(base)] - 1) + signo * sd
  metas <- metas_anuales(hist, g, etiqueta)
  s <- .sendero_desde_metas(hist, metas, etiqueta)
  validar_metas(s, metas, etiqueta)
  attr(s, "metas") <- metas
  s
}

#' Las seis corridas de la sensibilidad. `esc_base`: lista nombrada por series_master_id con las series ESC.*.BASE de
#' L3 de las tres variables (`<prefijo>.BASE`). Devuelve una lista nombrada <VARIABLE>.<MAS|MENOS>; cada elemento es
#' `esc_base` con la serie de esa variable reemplazada por su sendero de sensibilidad (las demás en la base, F6-09-a),
#' más el atributo "sd" con las tres desviaciones estándar.
escenarios_sensibilidad <- function(esc_base) {
  ids <- paste0(VARIABLES_SENSIBILIDAD, ".BASE")
  faltan <- setdiff(ids, names(esc_base))
  if (length(faltan)) stop("escenarios_sensibilidad: faltan las series base ", paste(faltan, collapse = ", "))
  sds <- vapply(seq_along(ids), function(k) {
    e <- .serie_esc(esc_base[[ids[k]]], ids[k])
    sd_crecimiento_anual(e[e$tramo == "historia", c("periodo", "valor")], ids[k])
  }, numeric(1))
  names(sds) <- names(VARIABLES_SENSIBILIDAD)
  res <- list()
  for (k in seq_along(ids)) for (sg in names(SIGNOS_SENSIBILIDAD)) {
    e <- esc_base
    e[[ids[k]]] <- sendero_sensibilidad(esc_base[[ids[k]]], sds[[k]], SIGNOS_SENSIBILIDAD[[sg]], paste(ids[k], sg))
    res[[paste0(names(VARIABLES_SENSIBILIDAD)[k], ".", sg)]] <- e
  }
  attr(res, "sd") <- sds
  res
}
