# Reglas puras de la mitad "estacionariedad" del análisis exploratorio de Fase 3 (senda §4),
# separadas del script que toca disco (estacionariedad.R) para que tests/test-estacionariedad.R
# las ejerza con datos sintéticos -- mismo patrón que el resto de Fase 3.
#
# Decisiones fijadas por Harold vía `AskUserQuestion` (2026-09-17, ver doc/checklist_fase3.md):
#   - Estrategia: ADF + KPSS confirmatorio (se declara estacionaria una transformación solo si
#     ADF rechaza raíz unitaria Y KPSS no rechaza estacionariedad; si ambos coinciden en sentido
#     contrario, no_estacionaria; si discrepan, ambigua -- tabla de interpretación estándar,
#     Kwiatkowski et al. 1992). Los dos casos discordantes de esa tabla se publican con
#     etiquetas distintas desde 2026-09-18, porque significan cosas distintas -- ver
#     interpretar_conjunta().
#   - Selección de rezagos: BIC/SIC para ADF.
#   - Alcance: nivel, log-nivel, primera diferencia y diferencia del log, por serie.
#
# Paquete: `urca` (ADR-009, nota de seguimiento "pruebas formales de estacionariedad",
# 2026-09-17) -- es la única de las dos opciones consideradas (`urca` vs `tseries`) que soporta
# selección de rezagos por BIC en ur.df(). `ur.kpss()` no tiene un análogo exacto de BIC (no es
# una regresión con rezagos seleccionables, sino un estimador de varianza de largo plazo con un
# parámetro de truncamiento): se usa `lags = "short"`, trunc(4*(n/100)^0.25), como la opción más
# parsimoniosa disponible -- aproximación declarada, no una correspondencia exacta a BIC.
#
# Especificación determinística por transformación (fijada acá, no preguntada -- ver nota en
# doc/checklist_fase3.md): nivel y log-nivel llevan tendencia determinística esperada (índices y
# magnitudes económicas de este proyecto crecen en el tiempo) -> ADF type="trend" (tau3),
# KPSS type="tau" (estacionariedad alrededor de una tendencia). Diferencia y diferencia del log
# no deberían llevar tendencia determinística remanente -> ADF type="drift" (tau2),
# KPSS type="mu" (estacionariedad alrededor de una media constante).
#
# Máximo de rezagos para la búsqueda BIC de ADF: ur.df(lags=...) por defecto es 1 (búsqueda
# 0..1, casi no busca nada) -- hay que fijar un techo explícito para que "selectlags=BIC"
# signifique algo. Se usa la regla de Schwert trunc(12*(n/100)^0.25), convención común en
# software econométrico para el techo de búsqueda de ADF (no es la selección en sí, que sigue
# siendo BIC dentro de ese rango). El techo y la selección se publican en columnas distintas
# (`techo_rezagos` y `rezagos`): son números distintos y confundirlos hacía que la columna de
# rezagos del reporte no describiera la regresión cuyo estadístico se publica al lado.
#
# GRILLA DE LA BÚSQUEDA BIC: 0..techo, y la selección la hace este archivo, no `urca`
# (corregido 2026-09-19, hallazgo C2 de la discusión metodológica de Fase 3). Motivo: en urca
# 1.3-4, `ur.df(..., selectlags = "BIC")` arma el vector de criterios con
# `critRes <- rep(NA, lags)` y lo llena en el bucle `for (i in 2:(lags))`, de modo que el
# modelo con 0 rezagos NUNCA se evalúa y el mínimo posible es 1 (verificado leyendo el fuente
# del paquete instalado). En las 64 filas del reporte real la restricción mordía en 32: BIC
# prefería 0 rezagos y se publicaba el ajuste con 1. Eso no era la "selección BIC" que declara
# doc/metodologia/reporte_exploratorio_fase3.md, y no era inocuo -- cambiaba 3 veredictos.
#
# La selección y el estadístico publicado salen de la MISMA muestra común que define el techo
# (la que usa urca internamente: no se re-expande la muestra al elegir menos rezagos), así que
# los BIC de los candidatos son comparables y las filas cuya selección sigue siendo >= 1 dan un
# estadístico idéntico al de antes. `urca` sigue siendo la fuente de los valores críticos, y
# .verificar_contra_urca() comprueba en cada llamada que la regresión de este archivo coincide
# con la de ur.df() sobre el mismo diseño: dos implementaciones de la misma regresión, con algo
# que falla si dejan de coincidir.
#
# DIAGNÓSTICO DE AUTOCORRELACIÓN RESIDUAL: admitir 0 rezagos abre la puerta a una regresión
# sub-parametrizada, que es el caso en que el ADF distorsiona su tamaño (Ng y Perron 1995,
# 2001). Por eso cada fila publica `adf_ljung_box_p`, el valor p de Ljung-Box sobre los residuos
# de la regresión elegida, con tantos rezagos como la frecuencia de la serie. No detiene la
# corrida -- no es un defecto de datos sino un aviso de especificación -- pero deja de ser
# invisible: una fila con p pequeño publica un estadístico cuya distribución nominal no es de
# fiar, y qué hacer con ella es materia de Fase 5.

library(urca)

.max_rezagos_schwert <- function(n) trunc(12 * (n / 100)^0.25)

#' Número de rezagos que la búsqueda BIC de `urca` retuvo en su regresión.
#'
#' NO es `ajuste@lags`: ese slot devuelve el techo que se le pasó en `lags=`, no la selección
#' (verificado 2026-09-18 con urca 1.3-4 -- `ur.df(x, lags = 15, selectlags = "BIC")` deja
#' `@lags == 15` mientras la regresión publicada retiene 1 rezago). El número efectivo se lee
#' de la regresión que `ur.df()` realmente publica en `@testreg`: un término `z.diff.lag` por
#' rezago retenido (`z.diff.lag` a secas cuando es uno solo, `z.diff.lag1`, `z.diff.lag2`, ...
#' cuando son varios).
#'
#' Ya no se usa para publicar (la selección la hace .seleccion_bic_adf sobre la grilla 0..techo,
#' ver la nota de cabecera): queda porque es la forma correcta de leer lo que urca eligió, y
#' tests/test-estacionariedad.R la usa para comparar las dos selecciones.
.rezagos_efectivos <- function(ajuste) {
  sum(grepl("^z\\.diff\\.lag", rownames(ajuste@testreg$coefficients)))
}

#' Diseño de la regresión ADF sobre la muestra común que define el techo de rezagos.
#'
#' Reproduce la construcción de `urca::ur.df()`: sobre z = diff(x), la matriz `embed(z, techo+1)`
#' deja en la fila t el vector (Δx_t, Δx_{t-1}, ..., Δx_{t-techo}), el regresor de nivel es
#' x[(techo+1):n] con n = length(z), y la tendencia corre de techo+1 a n. Todos los candidatos
#' de la grilla comparten esta muestra -- si cada uno usara la suya, sus BIC no serían
#' comparables.
.diseno_adf <- function(x, tipo_adf, techo) {
  z <- diff(x)
  n <- length(z)
  if (techo + 2 > n) {
    stop("FALLO VISIBLE: techo de rezagos ", techo, " incompatible con ", length(x),
         " observaciones -- la muestra común quedaría vacía.")
  }
  matriz <- embed(z, techo + 1)
  list(z_diff = matriz[, 1],
       z_lag_1 = x[(techo + 1):n],
       tt = (techo + 1):n,
       rezagos_disponibles = matriz,
       con_tendencia = identical(tipo_adf, "trend"))
}

#' Dummies estacionales (S-1, referencia = fase 1) por POSICION dentro de `tt`, no por
#' calendario real: .diseno_adf()/prueba_adf() son puras y no reciben `periodo`, pero como la
#' muestra es consecutiva y sin huecos (L3 no los admite, ver estacionariedad.R), agrupar por
#' `(tt - 1) %% S` agrupa exactamente las mismas posiciones recurrentes que agruparia el
#' calendario real -- la etiqueta de cada dummy es arbitraria (no se sabe si "fase 3" es marzo
#' o julio) pero el agrupamiento es correcto, que es lo unico que necesita una regresion.
.dummies_estacionales <- function(tt, S) {
  fase <- factor(((tt - 1) %% S) + 1, levels = seq_len(S))
  SD <- stats::model.matrix(~fase)[, -1, drop = FALSE]
  colnames(SD) <- paste0("sd", seq_len(ncol(SD)))
  SD
}

#' Regresor de pulso para un outlier ADITIVO (AO) declarado en NIVEL, en la posición 1-based
#' `pos_en_x` dentro del vector `x` que entra a prueba_adf() -- D2 del checklist de cierre de
#' Fase 3 (diagnóstico, no cambia el veredicto publicado, ver la nota de cabecera). Válido solo
#' cuando `x` es el nivel o el log (una sola diferencia hasta z=Δx): un AO que suma δ a x[pos]
#' produce dos pulsos de igual magnitud y signo opuesto en Δx -- +1 en la fila cuyo Δx =
#' x[pos]-x[pos-1] (el outlier entra como minuendo) y -1 en la fila cuyo Δx = x[pos+1]-x[pos]
#' (el outlier sale como sustraendo) -- que en la indexación de `z` (z[i] = x[i+1]-x[i]) caen en
#' i = pos-1 (+1) e i = pos (-1).
.pulso_outlier_z <- function(tt, pos_en_x) {
  pulso <- numeric(length(tt))
  pulso[tt == (pos_en_x - 1L)] <- 1
  pulso[tt == pos_en_x] <- -1
  pulso
}

#' Ajusta por mínimos cuadrados la regresión ADF del diseño con `k` rezagos de la diferencia.
#' `dummies_S`, si no es NULL, agrega S-1 dummies estacionales (D1 del checklist de cierre de
#' Fase 3: componente estacional en la especificación de la prueba, ver la nota de cabecera de
#' este archivo). `outlier_posiciones_x`, si no es NULL, agrega un regresor de pulso (ver
#' .pulso_outlier_z()) por cada posición declarada (D2: diagnóstico de sensibilidad al shock de
#' 2020 del objetivo). Ninguno de los dos cambia la distribución asintótica del estadístico de
#' `z_lag_1` en tanto sean deterministicos (mismo argumento que ya vale para `tt`) -- pero ver
#' la nota de cabecera sobre por qué la columna con outliers se publica como diagnóstico, no
#' comparable sin más contra los críticos de `urca`.
.lm_adf <- function(dis, k, dummies_S = NULL, outlier_posiciones_x = NULL) {
  datos <- data.frame(z_diff = dis$z_diff, z_lag_1 = dis$z_lag_1)
  terminos <- "z_lag_1"
  if (dis$con_tendencia) {
    datos$tt <- dis$tt
    terminos <- c(terminos, "tt")
  }
  if (k > 0) {
    rez <- dis$rezagos_disponibles[, 2:(k + 1), drop = FALSE]
    colnames(rez) <- paste0("z_diff_lag", seq_len(k))
    datos <- cbind(datos, rez)
    terminos <- c(terminos, colnames(rez))
  }
  if (!is.null(dummies_S)) {
    SD <- .dummies_estacionales(dis$tt, dummies_S)
    datos <- cbind(datos, SD)
    terminos <- c(terminos, colnames(SD))
  }
  if (!is.null(outlier_posiciones_x) && length(outlier_posiciones_x) > 0) {
    OUT <- vapply(outlier_posiciones_x, function(p) .pulso_outlier_z(dis$tt, p), numeric(length(dis$tt)))
    colnames(OUT) <- paste0("ao", seq_along(outlier_posiciones_x))
    datos <- cbind(datos, OUT)
    terminos <- c(terminos, colnames(OUT))
  }
  stats::lm(stats::as.formula(paste("z_diff ~", paste(terminos, collapse = " + "))), data = datos)
}

#' Selección de rezagos por BIC sobre la grilla 0..techo (ver la nota de cabecera sobre por qué
#' la grilla no la puede hacer `urca`). Devuelve el número elegido y su ajuste. `dummies_S` se
#' propaga a cada candidato de la grilla (ver .lm_adf): con o sin dummies es una especificación
#' completa distinta, así que cada una elige sus propios rezagos por BIC, no comparten la
#' selección de la otra.
.seleccion_bic_adf <- function(dis, techo, dummies_S = NULL) {
  n_efectivo <- length(dis$z_diff)
  ajustes <- lapply(0:techo, function(k) .lm_adf(dis, k, dummies_S = dummies_S))
  bic <- vapply(ajustes, function(aj) stats::AIC(aj, k = log(n_efectivo)), numeric(1))
  elegido <- which.min(bic)
  list(rezagos = elegido - 1L, ajuste = ajustes[[elegido]], n_efectivo = n_efectivo)
}

#' Comprueba que la regresión de este archivo es la misma que la de `urca` sobre el mismo
#' diseño. Es la guardia contra las dos fuentes de verdad: si alguna vez dejan de coincidir
#' (cambio de versión de urca, error al armar la matriz), falla acá y no en silencio.
.verificar_contra_urca <- function(dis, techo, ajuste_urca, tau) {
  t_propio <- summary(.lm_adf(dis, techo))$coefficients["z_lag_1", "t value"]
  t_urca <- unname(ajuste_urca@teststat[1, tau])
  if (!isTRUE(all.equal(t_propio, t_urca, tolerance = 1e-8))) {
    stop("FALLO VISIBLE: la regresión ADF de estacionariedad_reglas.R dejó de coincidir con ",
         "urca::ur.df() sobre el mismo diseño (propio ", t_propio, " vs urca ", t_urca,
         "). No publicar hasta entender por qué.")
  }
  invisible(TRUE)
}

#' Valor p de Ljung-Box sobre los residuos de la regresión ADF elegida, con tantos rezagos como
#' la frecuencia de la serie (12 mensual, 4 trimestral) -- el período donde aparecería la
#' estacionalidad que la especificación no modela. `fitdf` descuenta los rezagos estimados.
.ljung_box_adf <- function(ajuste, rezagos, frecuencia) {
  rezagos_lb <- switch(frecuencia, "M" = 12L, "Q" = 4L,
                       stop("FALLO VISIBLE: frecuencia desconocida: ", frecuencia,
                            " (se esperaba \"M\" o \"Q\")"))
  residuos <- stats::residuals(ajuste)
  if (length(residuos) <= rezagos_lb + 1L) return(NA_real_)
  stats::Box.test(residuos, lag = rezagos_lb, type = "Ljung-Box",
                  fitdf = min(rezagos, rezagos_lb - 1L))$p.value
}

#' Devuelve las transformaciones candidatas de un vector de nivel, en el orden fijado por
#' Harold. Las dos basadas en logaritmo se omiten (NULL) si `valor` tiene algún valor no
#' positivo -- log() no está definido ahí; se documenta, no se fuerza.
transformaciones_candidatas <- function(valor) {
  todo_positivo <- all(valor > 0, na.rm = TRUE)
  log_valor <- if (todo_positivo) log(valor) else NULL
  list(
    nivel = valor,
    log = log_valor,
    diff = diff(valor),
    diff_log = if (!is.null(log_valor)) diff(log_valor) else NULL
  )
}

.especificacion <- function(tipo_transf) {
  if (tipo_transf %in% c("nivel", "log")) {
    list(adf_type = "trend", adf_tau = "tau3", kpss_type = "tau")
  } else if (tipo_transf %in% c("diff", "diff_log")) {
    list(adf_type = "drift", adf_tau = "tau2", kpss_type = "mu")
  } else {
    stop("tipo_transf desconocido: ", tipo_transf)
  }
}

#' ADF (Dickey-Fuller aumentado) con selección de rezagos por BIC sobre la grilla 0..techo de
#' Schwert, especificación determinística según `tipo_transf` (ver .especificacion()).
#' rechaza_raiz_unitaria = TRUE significa que el estadístico es más negativo que el valor
#' crítico al 5% -- evidencia a favor de estacionariedad.
#'
#' `rezagos` es la selección BIC efectiva (la que corresponde al estadístico devuelto) y
#' `techo_rezagos` el máximo de búsqueda de Schwert: dos números distintos. `ljung_box_p` es el
#' diagnóstico de autocorrelación residual de la regresión elegida -- ver la nota de cabecera
#' sobre la grilla y sobre por qué este valor se publica en vez de detener la corrida.
#'
#' Se devuelven los tres valores críticos (1%, 5% y 10%) y no solo el del 5% que decide el
#' veredicto: sin ellos la marginalidad de una fila es invisible y el lector no puede saber si el
#' veredicto aguanta un cambio de umbral sin recomputar la corrida entera. `tipo` es la
#' especificación determinística que se mantuvo ("trend" -> estadístico tau3, "drift" -> tau2):
#' es constante por transformación, pero publicarla evita que la tabla haya que leerla con el
#' código al lado.
#'
#' TAMBIÉN devuelve la especificación CON dummies estacionales (D1 del checklist de cierre de
#' Fase 3, nota de ADR-010 sobre componente estacional): `estadistico_con_estacional` y
#' `rechaza_raiz_unitaria_con_estacional`, seleccionando sus propios rezagos por BIC (una
#' especificación completa distinta -- ver .seleccion_bic_adf()), más el F de significancia
#' conjunta de las S-1 dummies (`f_dummies_estacionales`, su p-valor y sus grados de libertad),
#' calculado sobre el mismo k que la especificación con dummies eligió. Los críticos de `urca`
#' (`cval_*`) sirven para AMBAS especificaciones: agregar dummies deterministicas no cambia la
#' distribución asintótica del estadístico de `z_lag_1` (mismo argumento que ya vale para la
#' tendencia `tt`), así que no hace falta un segundo juego de críticos.
#'
#' `outlier_posiciones_x`, si se pasa (D2 del checklist de cierre de Fase 3: ¿las pruebas
#' consumen los outliers declarados en el catálogo?), agrega un pulso de outlier aditivo (ver
#' .pulso_outlier_z()) por posición, SOBRE EL MISMO `k` ya elegido sin dummies (`sel$rezagos`,
#' no una selección BIC propia): la pregunta es la sensibilidad de ESTA especificación al shock,
#' no una especificación nueva. `estadistico_con_outliers` se publica como DIAGNÓSTICO, NO
#' comparable sin más contra `cval_*`: con dummies de impulso la distribución del estadístico
#' deja de ser la de Dickey-Fuller (Perron 1989; Vogelsang 1999) -- ver la salvedad ya declarada
#' en el reporte exploratorio. El veredicto publicado (`rechaza_raiz_unitaria`,
#' `conclusion`) sigue siendo el de la especificación SIN outliers.
prueba_adf <- function(x, tipo_transf, frecuencia, outlier_posiciones_x = NULL) {
  spec <- .especificacion(tipo_transf)
  techo <- .max_rezagos_schwert(length(x))
  dis <- .diseno_adf(x, spec$adf_type, techo)

  # urca queda como fuente de los valores críticos (dependen del tamaño de muestra y están
  # tabulados en el paquete) y como contraparte de la guardia de equivalencia. selectlags no
  # interviene: la selección es la de .seleccion_bic_adf().
  ajuste_urca <- ur.df(x, type = spec$adf_type, lags = techo, selectlags = "Fixed")
  .verificar_contra_urca(dis, techo, ajuste_urca, spec$adf_tau)

  sel <- .seleccion_bic_adf(dis, techo)
  estadistico <- summary(sel$ajuste)$coefficients["z_lag_1", "t value"]
  cval <- ajuste_urca@cval[spec$adf_tau, ]

  S <- switch(frecuencia, "M" = 12L, "Q" = 4L,
              stop("FALLO VISIBLE: frecuencia desconocida: ", frecuencia,
                   " (se esperaba \"M\" o \"Q\")"))
  sel_dum <- .seleccion_bic_adf(dis, techo, dummies_S = S)
  estadistico_con_estacional <- summary(sel_dum$ajuste)$coefficients["z_lag_1", "t value"]
  # F de significancia conjunta de las S-1 dummies, mismo k (el de la especificación con
  # dummies) en el modelo restringido (sin dummies) para que sean anidados sobre la misma
  # muestra -- .seleccion_bic_adf() ya garantiza que ambos comparten n_efectivo.
  ajuste_restringido <- .lm_adf(dis, sel_dum$rezagos, dummies_S = NULL)
  rss_r <- sum(stats::residuals(ajuste_restringido)^2)
  rss_c <- sum(stats::residuals(sel_dum$ajuste)^2)
  df_c <- sel_dum$ajuste$df.residual
  q <- S - 1L
  f_dummies <- ((rss_r - rss_c) / q) / (rss_c / df_c)

  # D2: diagnóstico de sensibilidad al outlier declarado, sobre el mismo k ya elegido sin
  # dummies (ver la nota de cabecera). NA cuando no se pasan posiciones -- la mayoría de las
  # filas de este reporte no tienen outlier declarado en su catálogo.
  con_outliers <- !is.null(outlier_posiciones_x) && length(outlier_posiciones_x) > 0
  estadistico_con_outliers <- NA_real_
  if (con_outliers) {
    ajuste_out <- .lm_adf(dis, sel$rezagos, outlier_posiciones_x = outlier_posiciones_x)
    estadistico_con_outliers <- summary(ajuste_out)$coefficients["z_lag_1", "t value"]
  }

  list(estadistico = estadistico, tipo = spec$adf_type,
       cval_1pct = unname(cval["1pct"]), cval_5pct = unname(cval["5pct"]),
       cval_10pct = unname(cval["10pct"]),
       rezagos = sel$rezagos, techo_rezagos = techo,
       ljung_box_p = .ljung_box_adf(sel$ajuste, sel$rezagos, frecuencia),
       rechaza_raiz_unitaria = estadistico < unname(cval["5pct"]),
       estadistico_con_estacional = estadistico_con_estacional,
       rezagos_con_estacional = sel_dum$rezagos,
       rechaza_raiz_unitaria_con_estacional = estadistico_con_estacional < unname(cval["5pct"]),
       f_dummies_estacionales = f_dummies,
       f_dummies_p = stats::pf(f_dummies, q, df_c, lower.tail = FALSE),
       f_dummies_gl_num = q, f_dummies_gl_den = df_c,
       estadistico_con_outliers = estadistico_con_outliers,
       n_outliers_consumidos = length(outlier_posiciones_x))
}

#' KPSS con truncamiento "short" -- trunc(4*(n/100)^0.25), la opción más parsimoniosa del
#' paquete; NO es la regla de Schwert, que es trunc(12*(n/100)^0.25) y acá se usa solo como techo
#' de búsqueda de rezagos del ADF (son dos fórmulas distintas y conviene no darles el mismo
#' nombre). Tipo según `tipo_transf`. rechaza_estacionariedad = TRUE significa que el estadístico
#' supera el valor crítico al 5% -- evidencia en contra de estacionariedad.
#'
#' Como en prueba_adf(), se devuelven los tres valores críticos y el tipo mantenido ("tau" con
#' tendencia, "mu" sin ella). La tabla de Kwiatkowski et al. que trae `urca` no depende del
#' tamaño de muestra, así que estos tres números son constantes por tipo.
prueba_kpss <- function(x, tipo_transf) {
  spec <- .especificacion(tipo_transf)
  ajuste <- ur.kpss(x, type = spec$kpss_type, lags = "short")
  estadistico <- unname(ajuste@teststat[1])
  cval <- ajuste@cval[1, ]
  list(estadistico = estadistico, tipo = spec$kpss_type,
       cval_1pct = unname(cval["1pct"]), cval_5pct = unname(cval["5pct"]),
       cval_10pct = unname(cval["10pct"]),
       rezagos_truncamiento = ajuste@lag,
       rechaza_estacionariedad = estadistico > unname(cval["5pct"]))
}

#' Interpretación confirmatoria (Kwiatkowski et al. 1992): "estacionaria" solo si ambas
#' pruebas coinciden en ese sentido; "no_estacionaria" solo si ambas coinciden en el sentido
#' contrario. Los dos casos discordantes de la tabla NO se colapsan en una sola etiqueta: la
#' H0 propia de cada prueba es distinta, así que discrepar es información, y las dos formas de
#' discrepar sugieren cosas distintas.
#'
#'   - "ambigua_ambas_rechazan": ADF rechaza la raíz unitaria Y KPSS rechaza la estacionariedad.
#'     La serie no encaja ni en I(1) puro ni en I(0) puro según estas dos pruebas, y con los
#'     estadísticos que se publican NO se puede decir por qué: es compatible con un componente
#'     determinístico mal especificado (tendencia donde no la hay o al revés), con uno o varios
#'     quiebres de nivel o de tendencia, con estacionalidad no modelada, con integración
#'     fraccionaria, con la selección de rezagos y con las propiedades de tamaño de las dos
#'     pruebas bajo esas desviaciones. Identificar la causa pide otra prueba: quiebre endógeno
#'     (Zivot-Andrews, Lee-Strazicich, Bai-Perron para varios) o un estimador de d (GPH, Whittle
#'     local) para la integración fraccionaria. Ninguna de esas se corre acá.
#'   - "ambigua_ninguna_rechaza": NINGUNA rechaza su H0. No hay evidencia suficiente para separar
#'     I(1) de I(0) con esta muestra y esta especificación. No dice que la serie sea "intermedia",
#'     y tampoco atribuye el resultado a una causa: la falta de potencia frente a una raíz cercana
#'     a uno es la explicación habitual, pero un componente determinístico no modelado produce lo
#'     mismo, y estos estadísticos no distinguen entre las dos.
#'
#' Los nombres describen la CELDA de la tabla 2x2 en que cayó la fila, no un diagnóstico
#' (renombrados 2026-09-19, hallazgo I1 de la discusión metodológica: antes se llamaban
#' "ambigua_quiebre_o_fraccional" y "ambigua_baja_potencia", que nombraban dos de las causas
#' posibles como si fueran la conclusión; las corridas anteriores a esa fecha usan los nombres
#' viejos, con el mismo criterio de clasificación).
#'
#' La distinción entre las dos celdas es de lectura, no de tratamiento: qué hacer con cada caso
#' (más muestra, prueba con quiebre, otra transformación) no lo fija este archivo.
interpretar_conjunta <- function(adf, kpss) {
  if (adf$rechaza_raiz_unitaria && !kpss$rechaza_estacionariedad) {
    "estacionaria"
  } else if (!adf$rechaza_raiz_unitaria && kpss$rechaza_estacionariedad) {
    "no_estacionaria"
  } else if (adf$rechaza_raiz_unitaria && kpss$rechaza_estacionariedad) {
    "ambigua_ambas_rechazan"
  } else {
    "ambigua_ninguna_rechaza"
  }
}

#' Corre ADF+KPSS sobre las transformaciones disponibles de una serie y devuelve una fila por
#' transformación (las basadas en log se omiten si no aplican, ver transformaciones_candidatas()).
#'
#' `periodos` y `outliers_periodos` (D2 del checklist de cierre de Fase 3, opcionales): cuando
#' ambos se pasan, las filas "nivel" y "log" (las únicas donde el pulso de outlier de
#' .pulso_outlier_z() es válido -- ver la nota de prueba_adf()) ganan el diagnóstico
#' `adf_estadistico_con_outliers`. `outliers_periodos` son los períodos declarados en el
#' catálogo de outliers de la serie (p.ej. PIB_SA_PROPIO_Q_outliers.csv, ADR-004); la mayoría de
#' las series de este reporte no tienen catálogo de outliers y pasan NULL.
#'
#' `conclusion_con_estacional` (D1) recalcula interpretar_conjunta() con el ADF CON dummies
#' estacionales en vez del ADF publicado, misma KPSS (D1 no tocó KPSS -- ver la nota de
#' cabecera del archivo): es la lectura que ADR-010 fija como la que corresponde usar para
#' decidir la especificación de Fase 5, no un segundo veredicto que reemplace a `conclusion`.
analizar_estacionariedad_serie <- function(valor, serie_id, frecuencia,
                                            periodos = NULL, outliers_periodos = NULL) {
  candidatas <- transformaciones_candidatas(valor)
  outlier_pos <- if (!is.null(periodos) && !is.null(outliers_periodos)) {
    which(periodos %in% outliers_periodos)
  } else {
    integer(0)
  }
  filas <- list()
  for (tipo_transf in names(candidatas)) {
    x <- candidatas[[tipo_transf]]
    if (is.null(x)) next
    # El pulso de .pulso_outlier_z() solo es válido cuando `x` es nivel o log (una sola
    # diferencia hasta Δx) -- ver la nota de cabecera de prueba_adf().
    usar_outliers <- length(outlier_pos) > 0 && tipo_transf %in% c("nivel", "log")
    adf <- prueba_adf(x, tipo_transf, frecuencia,
                       outlier_posiciones_x = if (usar_outliers) outlier_pos else NULL)
    kpss <- prueba_kpss(x, tipo_transf)
    filas[[tipo_transf]] <- data.frame(
      serie_id = serie_id, transformacion = tipo_transf, n_obs = length(x),
      adf_tipo = adf$tipo,
      adf_estadistico = adf$estadistico,
      adf_cval_1pct = adf$cval_1pct, adf_cval_5pct = adf$cval_5pct,
      adf_cval_10pct = adf$cval_10pct,
      adf_rezagos = adf$rezagos, adf_techo_rezagos = adf$techo_rezagos,
      adf_ljung_box_p = adf$ljung_box_p,
      adf_rechaza_raiz_unitaria = adf$rechaza_raiz_unitaria,
      kpss_tipo = kpss$tipo,
      kpss_estadistico = kpss$estadistico,
      kpss_cval_1pct = kpss$cval_1pct, kpss_cval_5pct = kpss$cval_5pct,
      kpss_cval_10pct = kpss$cval_10pct,
      kpss_rezagos_truncamiento = kpss$rezagos_truncamiento,
      kpss_rechaza_estacionariedad = kpss$rechaza_estacionariedad,
      conclusion = interpretar_conjunta(adf, kpss),
      # D1 -- componente estacional (nota de ADR-010): especificación completa alternativa,
      # sus propios rezagos BIC, mismos críticos de urca (deterministica, no cambia la
      # asintótica). No reemplaza `conclusion`: es la lectura para Fase 5, ver la nota arriba.
      adf_estadistico_con_estacional = adf$estadistico_con_estacional,
      adf_rezagos_con_estacional = adf$rezagos_con_estacional,
      adf_rechaza_raiz_unitaria_con_estacional = adf$rechaza_raiz_unitaria_con_estacional,
      adf_f_dummies_estacionales = adf$f_dummies_estacionales,
      adf_f_dummies_p = adf$f_dummies_p,
      adf_f_dummies_gl_num = adf$f_dummies_gl_num,
      adf_f_dummies_gl_den = adf$f_dummies_gl_den,
      conclusion_con_estacional = interpretar_conjunta(
        list(rechaza_raiz_unitaria = adf$rechaza_raiz_unitaria_con_estacional), kpss
      ),
      # D2 -- diagnóstico de sensibilidad al outlier declarado (ADR-004). NA cuando la serie no
      # tiene outliers declarados o la transformación no admite el pulso (diff/diff_log). NO
      # comparable contra adf_cval_* -- ver la nota de prueba_adf().
      adf_estadistico_con_outliers = adf$estadistico_con_outliers,
      adf_n_outliers_consumidos = adf$n_outliers_consumidos,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, filas)
}
