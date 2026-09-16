# Reglas puras de transformacion L1 -> L3 para la matriz de predictores (ADR-010), separadas
# del script que toca disco (l3_predictores.R) para que tests/test-l3-predictores.R las ejerza
# con datos sinteticos, mismo patron que src/validacion/l2_pib_reglas.R y
# src/transformacion/l3_pib_objetivo_reglas.R.
#
# ADR-010 fija: tempdisagg para desagregacion temporal (frecuencia baja -> alta, con serie
# indicadora si existe), deflactacion caso por caso, sin tratamiento de outlier propio en L3
# para predictoras. Agregar mensual -> trimestral es el caso INVERSO (alta -> baja): un
# promedio aritmetico simple, determinista, sin necesitar un metodo de benchmarking como
# Chow-Lin/Denton -- por eso esta funcion no usa tempdisagg. Ver ADR-010, seccion "Alternativas
# consideradas".

#' Agrega una serie mensual (periodo "YYYY-Mnn") a trimestral (periodo "YYYY-Qn") por promedio
#' simple de los 3 meses del trimestre. Apropiado para indices de nivel/volumen -- no para
#' flujos que deban sumarse en vez de promediarse.
#'
#' El ultimo trimestre puede estar incompleto (la fuente aun no publico todos sus meses); se
#' descarta en vez de promediar con menos de 3 observaciones. Cualquier OTRO trimestre con menos
#' de 3 meses es un hueco real en L1 y falla de forma visible (regla 7 de CLAUDE.md).
agregar_trimestral_promedio <- function(mensual, etiqueta) {
  anio <- as.integer(substr(mensual$periodo, 1, 4))
  mes <- as.integer(substr(mensual$periodo, 7, 8))
  trimestre <- ceiling(mes / 3)
  periodo_q <- sprintf("%d-Q%d", anio, trimestre)

  conteo <- table(periodo_q)
  ultimo_trimestre <- periodo_q[which(mensual$periodo == max(mensual$periodo))]
  incompletos <- names(conteo)[conteo != 3]
  incompletos_no_finales <- setdiff(incompletos, ultimo_trimestre)

  if (length(incompletos_no_finales) > 0) {
    stop("FALLO VISIBLE [", etiqueta, "]: trimestre(s) con menos de 3 meses en L1, ",
         "antes del final de la serie (hueco real, no borde de publicación): ",
         paste(incompletos_no_finales, collapse = ", "))
  }

  agregada <- aggregate(
    valor ~ periodo_q,
    data = data.frame(periodo_q = periodo_q, valor = mensual$valor, stringsAsFactors = FALSE),
    FUN = mean
  )
  names(agregada) <- c("periodo", "valor")
  agregada <- agregada[!(agregada$periodo %in% incompletos), ]
  agregada <- agregada[order(agregada$periodo), ]
  rownames(agregada) <- NULL
  agregada
}
