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

#' Implementacion compartida de agregar_trimestral_promedio()/agregar_trimestral_suma(): valida
#' huecos y aplica FUN (mean o sum) a los 3 meses de cada trimestre. No exportada -- las dos
#' funciones publicas fijan FUN segun si la serie es de nivel/volumen (promedio) o de flujo
#' (suma), la distincion metodologica real; esta funcion solo evita duplicar la validacion de
#' huecos entre ambas.
#'
#' Los trimestres incompletos en el PRIMER o ULTIMO borde de `mensual` no son huecos: son el
#' límite real de la cobertura de la serie de entrada (p.ej. el trimestre en que arranca o
#' termina la publicación, o -- caso de una serie ya recortada por deflactar_serie(), que puede
#' empezar a mitad de trimestre -- el límite de la intersección con el índice de precios). Solo
#' un trimestre incompleto que NO toque ninguno de los dos bordes es un hueco real.
.agregar_trimestral <- function(mensual, etiqueta, FUN) {
  anio <- as.integer(substr(mensual$periodo, 1, 4))
  mes <- as.integer(substr(mensual$periodo, 7, 8))
  trimestre <- ceiling(mes / 3)
  periodo_q <- sprintf("%d-Q%d", anio, trimestre)

  conteo <- table(periodo_q)
  primer_trimestre <- periodo_q[which(mensual$periodo == min(mensual$periodo))]
  ultimo_trimestre <- periodo_q[which(mensual$periodo == max(mensual$periodo))]
  incompletos <- names(conteo)[conteo != 3]
  incompletos_no_borde <- setdiff(incompletos, c(primer_trimestre, ultimo_trimestre))

  if (length(incompletos_no_borde) > 0) {
    stop("FALLO VISIBLE [", etiqueta, "]: trimestre(s) con menos de 3 meses en L1, ",
         "fuera de los bordes de la serie (hueco real, no borde de cobertura): ",
         paste(incompletos_no_borde, collapse = ", "))
  }

  agregada <- aggregate(
    valor ~ periodo_q,
    data = data.frame(periodo_q = periodo_q, valor = mensual$valor, stringsAsFactors = FALSE),
    FUN = FUN
  )
  names(agregada) <- c("periodo", "valor")
  agregada <- agregada[!(agregada$periodo %in% incompletos), ]
  agregada <- agregada[order(agregada$periodo), ]
  rownames(agregada) <- NULL
  agregada
}

#' Agrega una serie mensual (periodo "YYYY-Mnn") a trimestral (periodo "YYYY-Qn") por promedio
#' simple de los 3 meses del trimestre. Apropiado para indices de nivel/volumen (p.ej.
#' BCR.IVAE.VOL.SA.M) -- no para flujos que deban sumarse en vez de promediarse (ver
#' agregar_trimestral_suma()).
#'
#' El ultimo trimestre puede estar incompleto (la fuente aun no publico todos sus meses); se
#' descarta en vez de promediar con menos de 3 observaciones. Cualquier OTRO trimestre con menos
#' de 3 meses es un hueco real en L1 y falla de forma visible (regla 7 de CLAUDE.md).
agregar_trimestral_promedio <- function(mensual, etiqueta) {
  .agregar_trimestral(mensual, etiqueta, FUN = mean)
}

#' Agrega una serie mensual de FLUJO (p.ej. BCR.REMESAS.NOM.NSA.M: millones de US$ ingresados
#' ese mes) a trimestral sumando los 3 meses del trimestre -- a diferencia de un indice de
#' nivel/volumen, un flujo trimestral es la suma de sus flujos mensuales, no su promedio (ADR-010:
#' "agregación alta→baja frecuencia es aritmética determinista"; sumar 3 flujos mensuales es la
#' operación aritmética correspondiente, promediarlos subestimaría el flujo trimestral en un
#' factor de ~3). Misma regla de huecos que agregar_trimestral_promedio().
agregar_trimestral_suma <- function(mensual, etiqueta) {
  .agregar_trimestral(mensual, etiqueta, FUN = sum)
}

#' Deflacta una serie nominal mensual con un indice de precios de la misma frecuencia y misma
#' base=100 en su mes ancla (ADR-010: deflactación caso por caso). valor_real = valor_nominal /
#' (valor_indice / 100). Une por periodo con interseccion (merge por "periodo"): los periodos que
#' solo existen en una de las dos series quedan fuera del resultado -- no se interpolan ni se
#' asumen en cero (convención "ausentes como celda vacía", CLAUDE.md). Falla de forma visible si
#' no hay ningún período en común.
deflactar_serie <- function(nominal, indice, etiqueta) {
  comun <- merge(nominal, indice, by = "periodo", suffixes = c("_nominal", "_indice"))
  if (nrow(comun) == 0) {
    stop("FALLO VISIBLE [", etiqueta, "]: la serie nominal y el índice de precios no tienen ",
         "ningún período en común.")
  }
  comun <- comun[order(comun$periodo), ]
  data.frame(
    periodo = comun$periodo,
    valor = comun$valor_nominal / (comun$valor_indice / 100),
    stringsAsFactors = FALSE
  )
}
