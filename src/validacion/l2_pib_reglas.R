# Reglas de la batería L2 para BCR_PIB_series_largo.csv, factorizadas en una
# función pura para que tests/test-validar-l2-pib.R pueda ejercerlas con datos
# sintéticos sin pasar por el archivo real. src/validacion/validar_l2_pib.R
# hace el I/O (leer L1 y el catálogo, reportar, fallar) y llama a validar_l2()
# definida acá. Ver ese archivo para la descripción de cada uno de los 5 checks
# (senda metodológica §3.5).
#
# Checks 1-4 (esquema, integridad referencial, duplicados, continuidad) viven en
# src/validacion/l2_serie_larga_reglas.R (2026-09-17, remediación del hallazgo I1 de la
# revisión independiente: eran agnósticos al PIB y la batería original no corría sobre las
# ocho series predictoras -- ver src/validacion/validar_l2_predictores.R, que usa el mismo
# módulo). Este archivo llama a validar_l2_serie_larga() para esos cuatro y agrega el check 5
# encima, que sí es específico del PIB nominal (identidad contable del enfoque de producción) y
# no tiene equivalente agnóstico -- se calcula aparte, en R base, sin pasar por el agente
# pointblank de los checks 1-4 (fusionar agentes a mitad de interrogate() no está soportado
# limpiamente en pointblank 0.12.4).

source(here::here("src", "validacion", "l2_serie_larga_reglas.R"))

VAB_RAMAS <- c(
  "BCR.VAB_AGRICULTURA.NOM.NSA.Q", "BCR.VAB_MINAS.NOM.NSA.Q", "BCR.VAB_MANUFACTURA.NOM.NSA.Q",
  "BCR.VAB_ELECTRICIDAD.NOM.NSA.Q", "BCR.VAB_AGUA.NOM.NSA.Q", "BCR.VAB_CONSTRUCCION.NOM.NSA.Q",
  "BCR.VAB_COMERCIO.NOM.NSA.Q", "BCR.VAB_TRANSPORTE.NOM.NSA.Q", "BCR.VAB_ALOJAMIENTO.NOM.NSA.Q",
  "BCR.VAB_INFO_COM.NOM.NSA.Q", "BCR.VAB_FINANCIERO.NOM.NSA.Q", "BCR.VAB_INMOBILIARIO.NOM.NSA.Q",
  "BCR.VAB_PROFESIONAL.NOM.NSA.Q", "BCR.VAB_SERV_APOYO.NOM.NSA.Q", "BCR.VAB_ADMIN_PUBLICA.NOM.NSA.Q",
  "BCR.VAB_ENSENANZA.NOM.NSA.Q", "BCR.VAB_SALUD.NOM.NSA.Q", "BCR.VAB_ARTE_RECREACION.NOM.NSA.Q",
  "BCR.VAB_OTROS_SERVICIOS.NOM.NSA.Q"
)
TOLERANCIA_AGREGADOS <- 0.05

#' Corre la batería de validaciones L2 sobre un data frame L1 ya cargado.
#' @param l1 data frame con columnas serie_id, periodo, valor, provisional.
#' @param catalogo data frame de 03_series.csv, YA filtrado a las series que
#'   corresponden a este L1 (sin UT.DEMANDA_TOTAL_MENSUAL).
#' @return list(errores = character vector de mensajes, vacío si todo cumple;
#'   agente = el ptblank_agent de los checks 1-4 ya interrogado, para quien
#'   necesite el reporte unificado más allá del mensaje de FALLO).
validar_l2 <- function(l1, catalogo) {
  # --- Checks 1-4: esquema, integridad referencial, duplicados, continuidad ---
  base <- validar_l2_serie_larga(l1, catalogo, freq = "Q", label = "L2 BCR PIB")
  errores <- base$errores
  agregar_error <- function(msg) errores <<- c(errores, msg)

  valor_numerico <- is.numeric(l1$valor)

  # --- 5. Coherencia de agregados (identidad contable, precios corrientes).
  # Álgebra entre series reordenadas a ancho -- no es un check de fila, no tiene equivalente
  # agnóstico en validar_l2_serie_larga(). ---
  mal_vab <- character(0)
  mal_pib <- character(0)
  if (valor_numerico) {
    serie_ancha <- function(sid) {
      s <- l1[l1$serie_id == sid, c("periodo", "valor")]
      setNames(s$valor, s$periodo)
    }
    vab_total <- serie_ancha("BCR.VAB.NOM.NSA.Q")
    impuestos <- serie_ancha("BCR.IMPUESTOS_NETOS.NOM.NSA.Q")
    pib <- serie_ancha("BCR.PIB.NOM.NSA.Q")

    if (length(vab_total) == 0 || length(impuestos) == 0 || length(pib) == 0) {
      agregar_error("coherencia de agregados: falta VAB total, impuestos netos o PIB nominal para verificar la identidad")
    } else {
      ramas_anchas <- lapply(VAB_RAMAS, serie_ancha)
      n_por_rama <- vapply(ramas_anchas, length, integer(1))
      if (any(n_por_rama == 0)) {
        agregar_error(paste0("coherencia de agregados: rama(s) VAB ausente(s) en L1: ",
                              paste(VAB_RAMAS[n_por_rama == 0], collapse = ", ")))
      } else {
        periodos_vab <- names(vab_total)
        suma_ramas <- Reduce(`+`, lapply(ramas_anchas, function(r) r[periodos_vab]))
        dif_vab <- suma_ramas - vab_total[periodos_vab]
        mal_vab <- periodos_vab[abs(dif_vab) > TOLERANCIA_AGREGADOS]

        periodos_pib <- intersect(names(vab_total), intersect(names(impuestos), names(pib)))
        dif_pib <- (vab_total[periodos_pib] + impuestos[periodos_pib]) - pib[periodos_pib]
        mal_pib <- periodos_pib[abs(dif_pib) > TOLERANCIA_AGREGADOS]
      }
    }
  }

  if (length(mal_vab) > 0) {
    agregar_error(paste0("identidad suma(VAB ramas) = VAB total rota en: ",
                          paste(mal_vab, collapse = ", ")))
  }
  if (length(mal_pib) > 0) {
    agregar_error(paste0("identidad VAB total + impuestos netos = PIB rota en: ",
                          paste(mal_pib, collapse = ", ")))
  }

  list(errores = errores, agente = base$agente)
}
