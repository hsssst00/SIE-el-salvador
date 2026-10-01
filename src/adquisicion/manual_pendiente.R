# manual_pendiente.R
#
# Estado MANUAL_PENDIENTE de `make raw` (scripts/verificar_l0.R) para las publicaciones que se
# capturan A MANO y de forma periodica, y que por eso no se pueden verificar en vivo: hoy solo
# UT.DEMANDA_TOTAL_MENSUAL (robots.txt de ut.com.sv prohibe el scraping; regla 9 de CLAUDE.md).
# Decision de Harold, 2026-09-30 (ADR-007, nota de seguimiento de esa fecha): `make raw` lista a UT
# como MANUAL_PENDIENTE con los dias desde la ultima captura y los años anteriores al actual que no
# llegan a diciembre, y SALE 0, como un CAMBIO -- no es un fallo de L0, es la senal de que toca
# mirar la ventana trimestral (doc/backlog_captura_vintages.md).
#
# Separado del script para que tests/test-manual-pendiente.R lo ejerza con un manifiesto y un
# catalogo sinteticos, sin red y sin tocar L0.

source(here::here("src", "transformacion", "vintage_lib.R"))
source(here::here("src", "transformacion", "ut_demanda_lib.R"))

PUBLICACIONES_MANUALES_PERIODICAS <- c("UT.DEMANDA_TOTAL_MENSUAL")

#' Estado de una publicacion capturada a mano por año. `manifiesto` y `vintages` son los
#' data.frame de manifiesto.csv y 08_vintages.csv; `hoy` es la fecha de referencia. Devuelve
#' list(publicacion_id, ultima_captura, dias, anios_sin_diciembre), donde `ultima_captura` es el
#' mayor `fecha_descarga` del manifiesto para la publicacion (la ultima captura REGISTRADA: una
#' ventana en la que todo salio sin cambios no deja fila) y `anios_sin_diciembre` los años
#' anteriores al de `hoy` cuyo vintage vigente no llega a diciembre. Falla visible si la
#' publicacion no tiene filas en el manifiesto o en el catalogo.
estado_manual_pendiente <- function(publicacion_id, manifiesto, vintages, hoy = Sys.Date()) {
  filas <- manifiesto[manifiesto$publicacion_id == publicacion_id, ]
  if (nrow(filas) == 0) {
    stop("FALLO VISIBLE: publicacion_id '", publicacion_id, "' no tiene ninguna fila en ",
         "manifiesto.csv -- no se puede calcular su estado MANUAL_PENDIENTE.")
  }
  ultima <- max(as.Date(filas$fecha_descarga))

  mapa <- mapa_vintage_por_anio(publicacion_id, vintages)
  periodo_max <- vintages$periodo_referencia_max[match(mapa, vintages$vintage_id)]
  mes_final <- mes_de_periodo_max(periodo_max)
  anio_actual <- as.integer(format(hoy, "%Y"))
  sin_diciembre <- as.integer(names(mapa)) < anio_actual & mes_final < 12L

  list(
    publicacion_id = publicacion_id,
    ultima_captura = ultima,
    dias = as.integer(as.Date(hoy) - ultima),
    anios_sin_diciembre = setNames(mes_final[sin_diciembre], names(mapa)[sin_diciembre])
  )
}

#' Una linea legible por publicacion pendiente, para `make raw`.
formatear_manual_pendiente <- function(estado) {
  anios <- estado$anios_sin_diciembre
  sin_dic <- if (length(anios) == 0) {
    "ninguno"
  } else {
    paste0(names(anios), " (último mes con dato: ", unname(anios), ")", collapse = ", ")
  }
  paste0(estado$publicacion_id, ": ", estado$dias, " días desde la última captura registrada (",
         estado$ultima_captura, "); años anteriores al actual que no llegan a diciembre: ", sin_dic,
         ". Ventanas de enero, abril, julio y octubre: doc/backlog_captura_vintages.md.")
}
