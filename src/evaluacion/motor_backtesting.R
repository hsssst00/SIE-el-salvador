# src/evaluacion/motor_backtesting.R
#
# Orquestador del motor de evaluación de Fase 4 sobre los datos del proyecto
# (doc/metodologia/especificacion_motor_evaluacion.md §1, §3 y §4). Es la capa de lectura y
# escritura: el bucle de orígenes, sus guardas, las métricas y las pruebas viven en eval_lib.R
# (puras, ejercitadas en CI por tests/ y por verificar_motor_sintetico.R); los modelos, en
# modelos_referencia.R, declarados antes de la primera corrida en catalogos/06_modelos/.
#
# Uso:  Rscript src/evaluacion/motor_backtesting.R               corre los experimentos de Fase 5 declarados
#       Rscript src/evaluacion/motor_backtesting.R F5_REPRO_G1   corre solo los exp_id indicados
# Los exp_id F4_* están cerrados (C-8) y se rechazan; Fase 4 se reproduce con F5_REPRO_* (C-6, C-7).
#
# Corte congelado de Fase 5 (F5-16, decisiones C-1 a C-8 de doc/metodologia/decisiones_fase5.md): el
# motor exige SIE_CONJUNTO/SIE_SALIDA (make eval CONJUNTO=<corte> SALIDA=<dir>, los mismos de
# make master) y se detiene con stop() sin ellos (C-3). Las capas L1/L3 de abajo se leen con
# ruta_capa(), es decir de <SALIDA>/L1_staging y <SALIDA>/L3_master, y el vintage vigente de cada
# publicación es el que declara el corte.
#
# Lee:
#   data/L3_master/PIB_SA_PROPIO_Q.csv           observado del objetivo primario (F4-20) y R6
#   data/L3_master/PIB_SA_PROPIO_Q_outliers.csv  AO declarados (ADR-004) para el ajuste por origen
#   data/L3_master/PIB_SA_OFICIAL_Q.csv          objetivo de R5 (F4-22)
#   data/L1_staging/BCR_PIB_series_largo.csv     NSA para reestimar X-13 en cada origen: la serie
#                                                concatenada (T001) no se materializa en L3, así que
#                                                se reconstruye con concatenar_pib_nsa() (F4-19)
#   catalogos/03_series.csv, 08_vintages.csv     vintage vigente (G-6, F4-03)
#   catalogos/06_modelos/<modelo_id>.yaml        registro previo de cada modelo (C8)
#
# Escribe data/L4_experiments/<exp_id>/ (no versionado, senda §7):
#   pronosticos.csv, metricas.csv, pruebas.csv, mcs.csv, ajuste_estacional.csv (solo con
#   sa=reestimado_en_origen: orden ARIMA por origen, F4-09b; en R2, del tramo [2005-Q1, o]), diagnosticos.csv (solo si
#   algún modelo implementa diagnosticar(), B1b) y manifiesto.txt con commit, semillas,
#   sha256 de insumos y salidas, y sessionInfo().
#
# Con R3/R4 agrega metricas_submuestras.csv, pruebas_submuestras.csv, mcs_submuestras.csv (columna
# muestra_eval) y, con R3, estabilidad.csv, sin tocar las tablas de la muestra completa.
#
# Al final registra en catalogos/07_experimentos.csv una fila por (experimento, modelo), con exp_id
# `<exp_id>__<modelo_id>`, reemplazando las filas previas de los exp_id que corrió (F4-25).
#
# Decisiones que implementa: F4-01 (orígenes), F4-03 (datos revisados, G-6), F4-04 (pérdida yoy en
# pp), F4-05 (grupos), F4-07 (denominador), F4-09/F4-09b (X-13 por origen), F4-15 a F4-18 (pruebas),
# F4-19 (NSA desde L1), F4-20 (observado de L3, bases del origen), F4-21 (marca de tamaño), F4-22
# (R5 solo en G2 y G3, serie oficial tal cual) y F4-25 a F4-29 (registro 07 y robustez R1 a R4). Regla 7 de CLAUDE.md: toda guarda falla con stop().

source(here::here("src", "evaluacion", "eval_lib.R"))
source(here::here("src", "evaluacion", "modelos_referencia.R"))
source(here::here("src", "evaluacion", "modelos_fase5.R"))         # registro de Fase 5 por grupo (B1-3)
source(here::here("src", "evaluacion", "combinaciones.R"))         # B5: combinaciones (F5-13), paso del orquestador
source(here::here("src", "transformacion", "l3_pib_objetivo_reglas.R"))   # concatenar_pib_nsa(), T001
source(here::here("src", "transformacion", "vintage_lib.R"))
source(here::here("src", "transformacion", "conjunto_lib.R"))   # conjunto_activo(), ruta_capa() (F5-16)

# ---------------------------------------------------------------------------------------------
# Experimentos declarados
# ---------------------------------------------------------------------------------------------
# Principal: los tres grupos con el ajuste reestimado por origen (F4-09b). Robustez del protocolo §5:
#   R1  ventana rodante de 92 trimestres; X-13 sobre [1990-Q1, o] como en la principal (F4-26)
#   R2  tramo homogéneo: X-13 y estimación solo sobre la NSA nativa [2005-Q1, o], orígenes de G2/G3 (F4-27)
#   R3  submuestras de targets pre/post 2020 con contraste de estabilidad, sobre la principal (F4-28)
#   R4  métricas sin los targets de 2020, y además sin 2020 ni 2021, sobre la principal (F4-29)
#   R5  objetivo oficial, solo G2 y G3, serie tal cual (F4-22)
#   R6  ajuste único de L3 en vez del reestimado por origen
# R3 y R4 no corren modelos: reevalúan los errores de la principal y escriben *_submuestras.csv en su
# directorio. R3 no aplica a G3: su primer target es 2020-Q1 y no tiene submuestra previa.

.exp <- function(exp_id, grupo, objetivo = "PIB_SA_PROPIO_Q", sa = "reestimado_en_origen", ventana = "expansiva",
                 r3 = FALSE, r4 = FALSE, semilla_exp = exp_id) {
  data.frame(exp_id = exp_id, grupo = grupo, objetivo = objetivo, sa = sa, ventana = ventana,
             vintage = "revision_vigente", perdida = "yoy_pp", r3 = r3, r4 = r4, semilla_exp = semilla_exp,
             stringsAsFactors = FALSE)
}
EXPERIMENTOS <- rbind(
  .exp("F4_BENCH_G1", "G1", r3 = TRUE, r4 = TRUE),
  .exp("F4_BENCH_G2", "G2", r3 = TRUE, r4 = TRUE),
  .exp("F4_BENCH_G3", "G3", r4 = TRUE),
  .exp("F4_BENCH_G2_R5", "G2", objetivo = "PIB_SA_OFICIAL_Q", sa = "l3_unico"),
  .exp("F4_BENCH_G3_R5", "G3", objetivo = "PIB_SA_OFICIAL_Q", sa = "l3_unico"),
  .exp("F4_BENCH_G1_R1", "G1", ventana = "rodante92"),
  .exp("F4_BENCH_G2_R1", "G2", ventana = "rodante92"),
  .exp("F4_BENCH_G3_R1", "G3", ventana = "rodante92"),
  .exp("F4_BENCH_G2_R2", "G2", ventana = "homogenea2005"),
  .exp("F4_BENCH_G3_R2", "G3", ventana = "homogenea2005"),
  .exp("F4_BENCH_G1_R6", "G1", sa = "l3_unico"),
  .exp("F4_BENCH_G2_R6", "G2", sa = "l3_unico"),
  .exp("F4_BENCH_G3_R6", "G3", sa = "l3_unico")
)

# Fase 5 (F5-16, decisiones C-6 a C-8). Los F4_* de arriba son los de la corrida de cierre de Fase 4
# (v0.7.x): siguen declarados porque V12 y tabla_resultados_fase4.R los usan, pero el motor ya no los
# corre (C-8). Cada F5_REPRO_X repite F4_BENCH_X sobre el corte congelado con las semillas de F4_BENCH_X
# (semilla_exp, C-7), de modo que sus tablas reproducen las del cierre salvo exp_id y las columnas de
# densidad, que en el cierre estaban vacías (C-6). Los modelos de Fase 5 se agregan a EXPERIMENTOS_FASE5.
PATRON_EXP_CERRADOS <- "^F4_"

experimentos_reproduccion <- function(exps) {
  if (!all(grepl("^F4_BENCH_", exps$exp_id))) stop("C-6: solo se reproducen experimentos F4_BENCH_*")
  r <- exps
  r$exp_id <- sub("^F4_BENCH_", "F5_REPRO_", exps$exp_id)
  r$semilla_exp <- exps$exp_id
  r
}
EXPERIMENTOS_REPRO <- experimentos_reproduccion(EXPERIMENTOS)

# Experimentos principales de Fase 5 (decisión B1-3): uno por grupo, con los seis benchmarks más los modelos
# de Fase 5 del grupo (modelos_fase5()), y las submuestras R3/R4 sobre la principal como en Fase 4 (F5-14).
# Las variantes R1, R2, R5, R6 y R7 (F5_Gk_Rn) se declaran abajo (B5-2).
EXPERIMENTOS_PRINCIPALES_FASE5 <- rbind(
  .exp("F5_G1", "G1", r3 = TRUE, r4 = TRUE),
  .exp("F5_G2", "G2", r3 = TRUE, r4 = TRUE),
  .exp("F5_G3", "G3", r4 = TRUE)
)
# Variantes de robustez de Fase 5 (F5-14, F5-04c; protocolo §5; B5-2): R1, R2, R5 y R6 como en Fase 4, con todos los
# modelos de Fase 5 (los representantes de F5-14c solo si la cuenta final lo dispara) y sus combinaciones (F5-14e); en R1
# y R2 las predictoras se recortan al inicio de la ventana del objetivo (B5-3). R7 (F5-04c): los modelos con UT de G2 y
# G3 y los benchmarks, con UT a 61 días en lugar de 30, sin combinaciones (B5-4).
EXPERIMENTOS_VARIANTES_FASE5 <- rbind(
  .exp("F5_G1_R1", "G1", ventana = "rodante92"), .exp("F5_G2_R1", "G2", ventana = "rodante92"), .exp("F5_G3_R1", "G3", ventana = "rodante92"),
  .exp("F5_G2_R2", "G2", ventana = "homogenea2005"), .exp("F5_G3_R2", "G3", ventana = "homogenea2005"),
  .exp("F5_G2_R5", "G2", objetivo = "PIB_SA_OFICIAL_Q", sa = "l3_unico"), .exp("F5_G3_R5", "G3", objetivo = "PIB_SA_OFICIAL_Q", sa = "l3_unico"),
  .exp("F5_G1_R6", "G1", sa = "l3_unico"), .exp("F5_G2_R6", "G2", sa = "l3_unico"), .exp("F5_G3_R6", "G3", sa = "l3_unico"),
  .exp("F5_G2_R7", "G2"), .exp("F5_G3_R7", "G3")
)
EXPERIMENTOS_FASE5 <- rbind(EXPERIMENTOS_REPRO, EXPERIMENTOS_PRINCIPALES_FASE5, EXPERIMENTOS_VARIANTES_FASE5)
PATRON_EXP_R7  <- "^F5_G[123]_R7$"
REZAGO_UT_R7   <- 61L                                               # F5-04c: 1 mes de o+1, como el IVAE y el IPM
PREDICTORAS_UT <- c("UT.DEMANDA_ELEC.GWH.NSA.Q", "UT.DEMANDA_ELEC.GWH.NSA.M")
PATRON_EXP_REPRESENTANTES <- "^F5_G[123]_R[1256]$"
# F5-14c (cuenta final, decidida por Harold el 2026-10-08): en R1, R2, R5 y R6 corren los univariados de B1 y un
# representante por familia: MULT.VAR_DIF (B2), REG.ENET (B3-9), MIX.PUENTE (B3b-7) y ML.RF (B4-5).
PREFIJOS_REPRESENTANTES <- c("UNI.", "MULT.VAR_DIF.", "REG.ENET.", "MIX.PUENTE.", "ML.RF.")
es_r7    <- function(ex) grepl(PATRON_EXP_R7, ex$exp_id)
con_representantes <- function(ex) grepl(PATRON_EXP_REPRESENTANTES, ex$exp_id)
combina  <- function(ex) grepl(PATRON_EXP_PREREGISTRO, ex$exp_id) && !es_r7(ex)   # F5-13, F5-14e; R7 sin combinaciones (B5-4)

# Candado del preregistro (F5-02): los experimentos de modelos de Fase 5 no corren sobre L3 hasta que todos
# sus YAML estén declarados y versionados. Con el candado abierto (FALSE), `make eval` corría solo los
# F5_REPRO_* y pedir un F5_G* se detenía. Lo cerró el commit de congelamiento del preregistro (E1 del checklist
# de Fase 5, 2026-10-08), citado en el protocolo §6: desde ahí `make eval` corre todos los F5_*. Cambiar un YAML de
# 06_modelos/, un modelo o un experimento después de ese commit reabre el preregistro y se declara.
PATRON_EXP_PREREGISTRO <- "^F5_G"
PREREGISTRO_FASE5_CERRADO <- TRUE

#' Modelos de un experimento: los benchmarks y, en los experimentos de modelos de Fase 5, los del grupo.
modelos_experimento <- function(ex) {
  if (!grepl(PATRON_EXP_PREREGISTRO, ex$exp_id)) return(modelos_referencia())
  f5 <- modelos_fase5(ex$grupo)
  if (es_r7(ex)) f5 <- Filter(function(m) any(m$requiere %in% PREDICTORAS_UT), f5)            # F5-04c: los modelos con UT
  if (con_representantes(ex)) f5 <- Filter(function(m) any(startsWith(m$modelo_id, PREFIJOS_REPRESENTANTES)), f5)   # F5-14c
  c(modelos_referencia(), f5)
}

#' Combinaciones que escribe un experimento (F5-13): ninguna fuera de los F5_G* y de R7.
combinaciones_experimento <- function(ex) if (combina(ex)) ids_combinaciones(ex$grupo) else character(0)

#' Los miembros que declara el YAML de cada combinación del experimento son sus modelos de Fase 5 (F5-13, F5-14e).
verificar_miembros_combinaciones <- function(ex) {
  esperados <- setdiff(vapply(modelos_experimento(ex), `[[`, character(1), "modelo_id"), vapply(modelos_referencia(), `[[`, character(1), "modelo_id"))
  for (id in combinaciones_experimento(ex)) {
    y <- yaml::read_yaml(here::here("catalogos", "06_modelos", paste0(id, ".yaml")))
    declarados <- y$especificacion$hiperparametros[[if (con_representantes(ex)) "miembros_representantes" else "miembros"]]   # F5-14e
    if (!identical(as.character(unlist(declarados)), esperados)) {
      stop("C8: los miembros que declara ", id, ".yaml no son los modelos de Fase 5 de ", ex$exp_id, " (F5-13, F5-14e)")
    }
  }
  invisible(TRUE)
}

#' Recorta una predictora al inicio de la ventana del objetivo (R1 y R2 con predictoras, B5-3): las trimestrales desde el
#' trimestre `inicio`, las mensuales desde su primer mes.
recortar_inicio_predictora <- function(d, inicio) {
  q0 <- q_a_ind(inicio)
  if (nrow(d) && grepl("-M", d$periodo[1], fixed = TRUE)) d[m_a_ind(d$periodo) >= q0 %/% 4L * 12L + (q0 %% 4L) * 3L, , drop = FALSE]
  else d[q_a_ind(d$periodo) >= q0, , drop = FALSE]
}

#' Experimentos de una corrida: sin argumentos, todos los de Fase 5 que el candado del preregistro deja correr;
#' o los `exp_id` pedidos. Un F4_* se rechaza (C-8): sus directorios de L4 y sus filas de 07 son los del
#' cierre de Fase 4. Un F5_G* se rechaza mientras el preregistro esté abierto (F5-02).
seleccionar_experimentos <- function(exp_ids = character(0), declarados = EXPERIMENTOS_FASE5,
                                     preregistro_cerrado = PREREGISTRO_FASE5_CERRADO) {
  cerrados <- unique(exp_ids[grepl(PATRON_EXP_CERRADOS, exp_ids)])
  if (length(cerrados)) {
    stop("C-8: ", paste(cerrados, collapse = ", "), " es de Fase 4, cerrada; sus resultados son los de la corrida ",
         "de cierre y no se sobrescriben. Para reproducirlos sobre el corte: ",
         paste(sub("^F4_BENCH_", "F5_REPRO_", cerrados), collapse = ", "))
  }
  bloqueados <- unique(exp_ids[grepl(PATRON_EXP_PREREGISTRO, exp_ids)])
  if (length(bloqueados) && !isTRUE(preregistro_cerrado)) {
    stop("F5-02: ", paste(bloqueados, collapse = ", "), " no corre sobre L3 hasta cerrar el preregistro (todos los YAML de ",
         "Fase 5 declarados y versionados; PREREGISTRO_FASE5_CERRADO en motor_backtesting.R)")
  }
  if (!isTRUE(preregistro_cerrado)) declarados <- declarados[!grepl(PATRON_EXP_PREREGISTRO, declarados$exp_id), , drop = FALSE]
  if (!length(exp_ids)) return(declarados)
  faltan <- setdiff(exp_ids, declarados$exp_id)
  if (length(faltan)) stop("motor: exp_id no declarado: ", paste(faltan, collapse = ", "))
  declarados[declarados$exp_id %in% exp_ids, , drop = FALSE]
}

MIN_OBS    <- 40L                    # G-4, mínimo de observaciones del objetivo (F4-05)
ALPHA_MCS  <- 0.10                   # F4-15
B_MCS      <- 5000L                  # F4-15
BENCHMARK  <- "BENCH.RW_SIN_DERIVA"  # F4-07
UNIDADES   <- c("yoy_pp", "qoq_pp", "log_nivel")
MARCA_TAMANO <- "distorsion_tamano_documentada"   # F4-18 / F4-21, en h = 4, 8
VENTANA_RODANTE <- 92L                # F4-10
INICIO_HOMOGENEO <- "2005-Q1"         # ADR-003, F4-27

# ---------------------------------------------------------------------------------------------
# Lectura
# ---------------------------------------------------------------------------------------------

.leer_csv <- function(...) {
  ruta <- here::here(...)
  if (!file.exists(ruta)) stop("motor: no existe ", ruta)
  read.csv(ruta, stringsAsFactors = FALSE, na.strings = "")
}

#' Archivo de una capa generada (L1_staging, L3_master): data/<capa>/ sin conjunto, <SALIDA>/<capa>/ con
#' él (ruta_capa() de conjunto_lib.R, que falla si CONJUNTO y SALIDA vienen a medias). Toda lectura de
#' L1/L3 del motor pasa por acá (F5-16).
.leer_capa <- function(capa, archivo) {
  ruta <- ruta_capa(capa, archivo)
  if (!file.exists(ruta)) stop("motor: no existe ", ruta)
  read.csv(ruta, stringsAsFactors = FALSE, na.strings = "")
}

#' Nombre del archivo de L3 de una serie maestra (la misma regla de src/transformacion/l3_predictores.R).
archivo_l3 <- function(serie_id) paste0(gsub(".", "_", serie_id, fixed = TRUE), ".csv")

#' G-6 sobre una predictora de L3 (F5-16, B1a): cada fila debe traer el vintage que el corte declara para su
#' publicación; para las publicaciones capturadas un archivo por año (UT, PUBLICACIONES_POR_ANIO de
#' conjunto_lib.R), el del año de la fila, con la misma regla que usa L3 para etiquetarla. No filtra: L3 trae
#' una fila por período, así que una fila de otro vintage es una L3 armada con otro corte, y se detiene.
verificar_vintage_predictora <- function(d, serie_id, vintages, conjunto = NULL) {
  if (!all(c("periodo", "valor", "vintage_id") %in% names(d))) stop("G-6: ", serie_id, " necesita periodo, valor y vintage_id")
  if (!nrow(d)) stop("G-6: ", serie_id, " no trae filas")
  if (anyDuplicated(d$periodo)) stop("G-6: ", serie_id, " tiene períodos duplicados")
  if (anyNA(d$valor)) stop("motor: ", serie_id, " trae valores ausentes")
  # Una serie que combina publicaciones (p. ej. las remesas reales, deflactadas con el IPC) etiqueta cada fila con
  # sus vintage_id unidos por " + " (vintage_lib.R); cada componente se verifica contra el corte (E2, 2026-10-08).
  partes <- strsplit(d$vintage_id, " + ", fixed = TRUE)
  comp <- unlist(partes); fila <- rep(seq_len(nrow(d)), lengths(partes))
  pub <- vintages$publicacion_id[match(comp, vintages$vintage_id)]
  if (anyNA(pub)) stop("G-6: ", serie_id, " trae vintage_id que no están en 08_vintages.csv: ",
                       paste(utils::head(unique(comp[is.na(pub)]), 3), collapse = ", "))
  esperado <- character(length(comp))
  for (p in unique(pub)) {
    i <- pub == p
    esperado[i] <- if (p %in% PUBLICACIONES_POR_ANIO) {
      unname(mapa_vintage_por_anio(p, vintages, conjunto)[substr(d$periodo[fila[i]], 1L, 4L)])
    } else {
      vintage_vigente(p, vintages, conjunto)
    }
  }
  malas <- is.na(esperado) | comp != esperado
  if (any(malas)) {
    k <- which(malas)[1]
    stop(sprintf("G-6: %s trae %d fila(s) de un vintage distinto del que declara el corte (primera: %s con %s; se espera %s)",
                 serie_id, length(unique(fila[malas])), d$periodo[fila[k]], comp[k], esperado[k]))
  }
  invisible(TRUE)
}

#' Predictoras de L3 que piden los modelos de una corrida, con G-6 sobre el corte; cada una como
#' data.frame(periodo, valor), que es lo que recibe correr_backtest().
leer_predictoras <- function(ids, vintages, conjunto = NULL) {
  stats::setNames(lapply(ids, function(id) {
    d <- .leer_capa("L3_master", archivo_l3(id))
    verificar_vintage_predictora(d, id, vintages, conjunto)
    data.frame(periodo = d$periodo, valor = d$valor, stringsAsFactors = FALSE)
  }), ids)
}

#' Series que requieren los modelos (sin el objetivo), sin repetir y en orden de aparición.
predictoras_requeridas <- function(modelos) setdiff(unique(unlist(lapply(modelos, `[[`, "requiere"))), "objetivo")

#' C-3 (F5-16): en Fase 5 la evaluación corre solo contra el corte declarado. Devuelve el conjunto o
#' se detiene con el comando correcto.
exigir_conjunto <- function(conjunto) {
  if (is.null(conjunto)) {
    stop("C-3 (F5-16): el motor de Fase 5 corre solo contra un corte declarado. Uso:\n",
         "  make master CONJUNTO=doc/metodologia/corte_fase5.csv SALIDA=data/conjuntos/corte_f5\n",
         "  make eval   CONJUNTO=doc/metodologia/corte_fase5.csv SALIDA=data/conjuntos/corte_f5")
  }
  conjunto
}

#' Registro previo (C8): cada modelo que se corre tiene su YAML, con modelo_id igual al del código.
verificar_registro_modelos <- function(modelos) {
  for (m in modelos) {
    ruta <- here::here("catalogos", "06_modelos", paste0(m$modelo_id, ".yaml"))
    if (!file.exists(ruta)) stop("C8: el modelo ", m$modelo_id, " no está declarado en catalogos/06_modelos/")
    y <- yaml::read_yaml(ruta)
    if (!identical(y$modelo_id, m$modelo_id)) stop("C8: ", basename(ruta), " declara modelo_id = ", y$modelo_id)
  }
  invisible(TRUE)
}

#' vintage_id vigente de cada publicación que aparece en una serie de L3: el último de 08_vintages.csv
#' o, con `conjunto`, el que el conjunto declara (F5-16).
vigentes_de <- function(d, vintages, conjunto = NULL) {
  pubs <- unique(vintages$publicacion_id[vintages$vintage_id %in% unique(d$vintage_id)])
  if (!length(pubs)) stop("G-6: ningún vintage_id de la serie está en 08_vintages.csv")
  vapply(pubs, vintage_vigente, character(1), vintages = vintages, conjunto = conjunto)
}

#' Objetivo observado (log-nivel) del vintage vigente, con su vintage_id por período.
leer_objetivo <- function(archivo, politica, vintages, conjunto = NULL) {
  d <- .leer_capa("L3_master", archivo)
  d <- filtrar_vintage(d, politica, vigentes_de(d, vintages, conjunto))          # G-6
  if (anyNA(d$valor) || any(d$valor <= 0)) stop("motor: ", archivo, " trae valores ausentes o no positivos")
  i <- q_a_ind(d$periodo)
  if (!identical(i, seq.int(i[1], length.out = length(i)))) stop("motor: ", archivo, " tiene huecos o desorden")
  data.frame(periodo = d$periodo, y = log(d$valor), vintage_id = d$vintage_id, stringsAsFactors = FALSE)
}

#' NSA concatenada (T001) desde L1, con el vintage de cada fila, que debe coincidir con el del
#' observado en L3: si L1 y L3 vienen de vintages distintos el ajuste por origen no es comparable.
leer_nsa_concat <- function(vintages, objetivo_l3, conjunto = NULL, l1 = NULL) {
  if (is.null(l1)) l1 <- .leer_capa("L1_staging", "BCR_PIB_series_largo.csv")
  cc <- concatenar_pib_nsa(l1)
  series <- .leer_csv("catalogos", "03_series.csv")
  pub <- vapply(fuente_pib_nsa_por_periodo(l1, cc$periodo), resolver_publicacion, character(1), catalogo_series = series)
  cc$vintage_id <- vapply(pub, vintage_vigente, character(1), vintages = vintages, conjunto = conjunto, USE.NAMES = FALSE)
  m <- merge(cc[, c("periodo", "vintage_id")], objetivo_l3[, c("periodo", "vintage_id")], by = "periodo", all = TRUE)
  if (anyNA(m) || any(m$vintage_id.x != m$vintage_id.y)) stop("G-6: la NSA de L1 y PIB_SA_PROPIO_Q de L3 no son del mismo vintage período a período")
  cc[order(q_a_ind(cc$periodo)), ]
}

#' C-5 (F5-16): L1 no trae vintage_id, así que la parte «L1 vs L3» de G-6 no ve una L1 armada con otro
#' corte. L3 sale de L1 por ajustar_estacional_propio(concatenar_pib_nsa(L1)) (l3_pib_objetivo.R), y
#' X-13 propaga cualquier cambio de la NSA a toda la serie: se exige que el `ajuste` recalculado desde
#' L1 sea idéntico, período por período y sin tolerancia, al SA de L3 (`sa_l3`: periodo, valor) y que
#' sus AO coincidan con `outliers_l3` (periodo, tipo). Pura salvo el stop().
verificar_l1_contra_l3 <- function(ajuste, sa_l3, outliers_l3) {
  p1 <- as.character(ajuste$sa$periodo); p3 <- as.character(sa_l3$periodo)
  if (!identical(p1, p3)) {
    stop("C-5: el SA recalculado desde L1 y PIB_SA_PROPIO_Q de L3 no cubren los mismos períodos (L1: ",
         p1[1], "..", p1[length(p1)], ", ", length(p1), " obs; L3: ", p3[1], "..", p3[length(p3)], ", ",
         length(p3), " obs): L1 y L3 no salen del mismo corte")
  }
  a <- as.numeric(ajuste$sa$valor); b <- as.numeric(sa_l3$valor)
  dif <- which(is.na(a) | is.na(b) | a != b)
  if (length(dif)) {
    stop(sprintf("C-5: el SA recalculado desde L1 difiere del de L3 en %d período(s) (primero %s: %s frente a %s): L1 y L3 no salen del mismo corte",
                 length(dif), p1[dif[1]], format(a[dif[1]], digits = 17), format(b[dif[1]], digits = 17)))
  }
  o1 <- paste(ajuste$outliers$periodo, ajuste$outliers$tipo)
  o3 <- paste(outliers_l3$periodo, outliers_l3$tipo)
  if (!identical(o1, o3)) {
    stop("C-5: los AO del ajuste recalculado desde L1 (", paste(o1, collapse = ", "),
         ") no coinciden con PIB_SA_PROPIO_Q_outliers.csv (", paste(o3, collapse = ", "), ")")
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------------------------
# Ajuste estacional por origen (F4-09b)
# ---------------------------------------------------------------------------------------------

#' X-13 sobre la NSA recortada al origen `o`. Devuelve el SA del origen y el registro del ajuste.
ajustar_en_origen <- function(nsa, outliers, o) {
  x <- recortar_a_origen(nsa, o)
  guarda_recorte(x, o, nombre = "NSA concatenada")                             # G-1 sobre el insumo de X-13
  if (q_a_ind(x$periodo[nrow(x)]) != o) stop("ajuste por origen: la NSA no llega al origen ", ind_a_q(o))
  args <- args_x13_origen(outliers, o)                                         # G-5 adentro
  i0 <- q_a_ind(x$periodo[1])
  serie <- stats::ts(x$valor, start = c(i0 %/% 4L, i0 %% 4L + 1L), frequency = 4)
  mod <- do.call(seasonal::seas, c(list(x = serie), args))
  sa <- as.numeric(seasonal::final(mod))
  if (length(sa) != nrow(x) || anyNA(sa) || any(sa <= 0)) stop("ajuste por origen ", ind_a_q(o), ": X-13 devolvió NA o una longitud distinta")
  tipo <- as.character(seasonal::outlier(mod))
  per_out <- x$periodo[!is.na(tipo)]
  ao <- ao_declarados_origen(outliers, o)
  verificar_ajuste_origen(seasonal::transformfunction(mod), per_out, ao, o)
  list(sa = data.frame(periodo = x$periodo, y = log(sa), stringsAsFactors = FALSE),
       registro = data.frame(origen = ind_a_q(o), n_obs = nrow(x),
                             arima = gsub("[[:space:]]+", " ", trimws(mod$model$arima$model)),
                             transform = seasonal::transformfunction(mod),
                             regresores = paste(mod$model$regression$variables, collapse = " "),
                             ao_declarados = paste(ao, collapse = " "), stringsAsFactors = FALSE))
}

# ---------------------------------------------------------------------------------------------
# Un experimento
# ---------------------------------------------------------------------------------------------

#' Serie del objetivo tal como la ve el origen `o` para un experimento: el SA del origen (reestimado o
#' de L3) y, si corresponde, el registro del ajuste. `cache_sa` guarda los ajustes por (tramo, origen):
#' la principal, R1 y R3/R4 comparten el de [1990-Q1, o]; R2 usa el de [2005-Q1, o].
serie_en_origen <- function(ex, o, insumos, cache_sa) {
  obs <- insumos$objetivos[[ex$objetivo]]
  if (ex$sa == "l3_unico") {
    sa <- obs[q_a_ind(obs$periodo) <= o, c("periodo", "y")]
    if (ex$ventana == "homogenea2005") sa <- sa[q_a_ind(sa$periodo) >= q_a_ind(INICIO_HOMOGENEO), ]
    return(list(sa = sa, registro = NULL, bases = FALSE))
  }
  if (ex$objetivo != "PIB_SA_PROPIO_Q") stop("motor: el ajuste por origen solo está definido para PIB_SA_PROPIO_Q")
  tramo <- if (ex$ventana == "homogenea2005") INICIO_HOMOGENEO else "1990-Q1"
  clave <- paste(tramo, o)
  if (is.null(cache_sa[[clave]])) {
    nsa <- insumos$nsa[q_a_ind(insumos$nsa$periodo) >= q_a_ind(tramo), ]
    cache_sa[[clave]] <- ajustar_en_origen(nsa, insumos$outliers, o)
  }
  a <- cache_sa[[clave]]
  list(sa = a$sa, registro = a$registro, bases = TRUE)
}

#' Corre un experimento y devuelve sus tablas.
correr_experimento <- function(ex, insumos, cache_sa) {
  token <- construir_token(ex$ventana, ex$grupo, ex$vintage, ex$sa, ex$perdida, conjunto = insumos$conjunto$etiqueta)   # C-4
  sem <- if (is.null(ex$semilla_exp)) ex$exp_id else ex$semilla_exp                  # C-7: semillas de F4 en F5_REPRO_*
  if (ex$objetivo == "PIB_SA_OFICIAL_Q" && (ex$sa != "l3_unico" || ex$grupo == "G1")) stop("F4-22: R5 corre solo en G2/G3 y con la serie oficial tal cual")
  if (ex$ventana == "homogenea2005" && ex$grupo == "G1") stop("F4-27: R2 corre solo con los orígenes de G2 y G3")
  obs <- insumos$objetivos[[ex$objetivo]]
  origenes <- origenes_grupo(ex$grupo)
  modelos <- modelos_experimento(ex)                                            # B1-3
  ids <- vapply(modelos, `[[`, character(1), "modelo_id")
  pred <- predictoras_requeridas(modelos)
  faltan <- setdiff(pred, names(insumos$predictoras))
  if (length(faltan)) stop("motor: ", ex$exp_id, " requiere predictoras que no se leyeron: ", paste(faltan, collapse = ", "))
  rez <- if (length(pred)) rezagos_predictoras(pred) else list()                  # F4-34, F5-04
  if (es_r7(ex)) for (id in intersect(names(rez), PREDICTORAS_UT)) rez[[id]] <- REZAGO_UT_R7   # F5-04c

  partes <- lapply(origenes, function(o) {
    so <- serie_en_origen(ex, o, insumos, cache_sa)
    estim <- if (ex$ventana == "rodante92") recortar_ventana_rodante(so$sa, VENTANA_RODANTE) else so$sa   # F4-26
    preds <- insumos$predictoras[pred]
    if (length(pred) && ex$ventana != "expansiva") preds <- lapply(preds, recortar_inicio_predictora, inicio = estim$periodo[1])   # B5-3
    pr <- correr_backtest(c(list(objetivo = estim), preds), modelos, o, rezagos = rez,
                          min_obs = MIN_OBS, exp_id = sem, densidad = TRUE)                                 # F4-33
    base <- if (so$bases) data.frame(origen = o, periodo = so$sa$periodo, y = so$sa$y, stringsAsFactors = FALSE) else NULL
    list(pron = pr, base = base, reg = so$registro, n_estim = nrow(estim), inicio = estim$periodo[1],
         diag = attr(pr, "diagnosticos"),                                      # B1b: NULL si ningún modelo los emite
         y = stats::setNames(so$sa$y, q_a_ind(so$sa$periodo)))                  # B5-1: el objetivo visto en o
  })
  pron  <- do.call(rbind, lapply(partes, `[[`, "pron"))
  bases <- do.call(rbind, lapply(partes, `[[`, "base"))                  # NULL si ningún origen trae bases
  ajuste <- NULL
  regs <- lapply(partes, `[[`, "reg")
  if (!all(vapply(regs, is.null, logical(1)))) ajuste <- cbind(exp_id = ex$exp_id, do.call(rbind, regs), stringsAsFactors = FALSE)
  diagnosticos <- do.call(rbind, lapply(partes, `[[`, "diag"))
  miembros <- setdiff(ids, vapply(modelos_referencia(), `[[`, character(1), "modelo_id"))
  combs_ex <- if (length(miembros) >= 2L) combinaciones_experimento(ex) else character(0)   # con un solo miembro no hay combinación
  if (length(combs_ex)) {                                                       # B5: combinaciones (F5-13, F5-14e)
    comb <- combinar_pronosticos(pron, miembros, ex$grupo, stats::setNames(lapply(partes, `[[`, "y"), origenes))
    diagnosticos <- rbind(diagnosticos, attr(comb, "diagnosticos")); attr(comb, "diagnosticos") <- NULL
    attr(pron, "diagnosticos") <- NULL
    pron <- rbind(pron, comb)
    ids <- c(ids, ids_combinaciones(ex$grupo))
  }
  if (!is.null(diagnosticos)) {
    diagnosticos <- data.frame(exp_id = ex$exp_id, modelo_id = diagnosticos$modelo_id, origen = ind_a_q(diagnosticos$origen),
                               clave = diagnosticos$clave, valor = diagnosticos$valor, stringsAsFactors = FALSE)
  }

  err <- calcular_errores(pron, obs[, c("periodo", "y")], bases = bases)
  err <- err[order(err$unidad, err$modelo_id, err$h, err$origen), ]

  # Tablas de la muestra completa, con el conteo de pares del grupo como guarda (F4-01, F4-05).
  tab <- evaluar_errores(err, ids, ex$exp_id, ex$grupo, ex$perdida,
                         semilla_mcs = function(h) semilla_de(sem, "MCS", h), benchmark = BENCHMARK,
                         gw = ex$ventana == "rodante92", alpha = ALPHA_MCS, B = B_MCS, marca_h_largo = MARCA_TAMANO,
                         marcar_identicos = grepl(PATRON_EXP_PREREGISTRO, ex$exp_id))                  # B2-9
  esperado <- conteo_por_horizonte(pares_evaluables(origenes, DISENO_FASE4$horizontes, obs$periodo[nrow(obs)]))
  n_obs_h <- tapply(tab$metricas$n_pares, tab$metricas$h, unique)
  if (!identical(as.integer(unlist(n_obs_h)), unname(esperado))) stop("motor: pares por horizonte distintos del diseño del grupo ", ex$grupo)

  # R3 y R4 (F4-28, F4-29): reevaluación de los mismos errores en submuestras de targets.
  sub <- NULL; estab <- NULL
  subs <- c(if (isTRUE(ex$r3)) c("pre2020", "post2020"), if (isTRUE(ex$r4)) c("sin_2020", "sin_2020_2021"))
  if (length(subs)) {
    tabs <- lapply(subs, function(nm) {
      keep <- SUBMUESTRAS_FASE4[[nm]](err$origen + err$h)
      t_ <- evaluar_errores(err[keep, ], ids, ex$exp_id, ex$grupo, ex$perdida,
                            semilla_mcs = function(h) semilla_de(sem, paste0("MCS|", nm), h), benchmark = BENCHMARK,
                            alpha = ALPHA_MCS, B = B_MCS, marca_h_largo = MARCA_TAMANO,
                            marcar_identicos = grepl(PATRON_EXP_PREREGISTRO, ex$exp_id))               # B2-9
      lapply(t_, function(x) cbind(muestra_eval = nm, x, stringsAsFactors = FALSE))
    })
    sub <- list(metricas = do.call(rbind, lapply(tabs, `[[`, "metricas")),
                pruebas  = do.call(rbind, lapply(tabs, `[[`, "pruebas")),
                mcs      = do.call(rbind, lapply(tabs, `[[`, "mcs")))
  }
  if (isTRUE(ex$r3)) {
    prim <- err[err$unidad == ex$perdida, ]
    estab <- do.call(rbind, lapply(DISENO_FASE4$horizontes, function(h) {
      eb <- prim[prim$h == h & prim$modelo_id == BENCHMARK, ]; eb <- eb[order(eb$origen), ]
      post <- as.integer(SUBMUESTRAS_FASE4$post2020(eb$origen + eb$h))
      do.call(rbind, lapply(setdiff(ids, BENCHMARK), function(id) {
        em <- prim[prim$h == h & prim$modelo_id == id, ]; em <- em[order(em$origen), ]
        if (!identical(em$origen, eb$origen)) stop("motor: orígenes desalineados en el contraste de estabilidad")
        r <- prueba_cambio_diferencial(eb$error, em$error, post, h)
        data.frame(exp_id = ex$exp_id, grupo = ex$grupo, h = h, unidad = ex$perdida, modelo_a = BENCHMARK, modelo_b = id,
                   media_pre = r$media_pre, cambio_post = r$cambio_post, ee_hac = r$ee_hac, estadistico = r$estadistico,
                   p_valor = r$p_valor, n_pre = r$n_pre, n_post = r$n_post,
                   marca_tamano = "tamano_no_verificado", stringsAsFactors = FALSE)
      }))
    }))
  }

  # Pronósticos con sus unidades derivadas y el vintage del observado en el target.
  pu <- derivar_unidades(pron, obs[, c("periodo", "y")], bases)
  vint <- stats::setNames(obs$vintage_id, q_a_ind(obs$periodo))
  pron_out <- data.frame(exp_id = ex$exp_id, modelo_id = pu$modelo_id, grupo = ex$grupo, origen = ind_a_q(pu$origen),
                         h = pu$h, periodo_objetivo = ind_a_q(pu$origen + pu$h),
                         log_nivel_pronosticado = pu$log_nivel_pronosticado, yoy_pp_pronosticado = pu$yoy_pp_pronosticado,
                         qoq_pp_pronosticado = pu$qoq_pp_pronosticado,
                         vintage_id_objetivo = unname(vint[as.character(pu$origen + pu$h)]), stringsAsFactors = FALSE)

  semillas <- vapply(ids, function(id) semilla_de(sem, id, origenes[1]), numeric(1))
  dens_ids <- vapply(Filter(function(m) is.function(m$predecir_densidad), modelos), `[[`, character(1), "modelo_id")
  list(token = token, pronosticos = pron_out, densidad_ids = dens_ids, predictoras = pred, metricas = tab$metricas, pruebas = tab$pruebas, mcs = tab$mcs,
       combinaciones = combs_ex, rezago_ut = if (es_r7(ex)) REZAGO_UT_R7 else NULL,
       ajuste_estacional = ajuste, diagnosticos = diagnosticos, sub = sub, estabilidad = estab, ids = ids, semillas = semillas,
       muestra_inicio = partes[[1]]$inicio, muestra_fin = obs$periodo[nrow(obs)],
       vintages = unique(obs$vintage_id[q_a_ind(obs$periodo) >= q_a_ind(partes[[1]]$inicio)]))
}

# ---------------------------------------------------------------------------------------------
# Escritura y manifiesto
# ---------------------------------------------------------------------------------------------

#' Commit del árbol que corre. Con git disponible, `git rev-parse HEAD` y el estado del árbol; sin
#' git, lectura directa de .git/HEAD (el árbol queda como no verificado). Sin ninguna de las dos, falla:
#' un manifiesto sin commit no hace auditable la corrida.
leer_commit <- function() {
  raiz <- here::here()
  sha <- tryCatch(suppressWarnings(system2("git", c("-C", shQuote(raiz), "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)),
                  error = function(e) character(0))
  if (length(sha) == 1L && grepl("^[0-9a-f]{40}$", sha)) {
    st <- suppressWarnings(system2("git", c("-C", shQuote(raiz), "status", "--porcelain"), stdout = TRUE, stderr = FALSE))
    return(list(sha = sha, arbol = if (length(st)) sprintf("con cambios sin commitear (%d entradas en git status)", length(st)) else "limpio"))
  }
  head <- file.path(raiz, ".git", "HEAD")
  if (!file.exists(head)) stop("motor: no se pudo determinar el commit (sin git y sin .git/HEAD)")
  h <- trimws(readLines(head, warn = FALSE)[1])
  if (grepl("^[0-9a-f]{40}$", h)) return(list(sha = h, arbol = "no verificado (git no disponible)"))
  ref <- sub("^ref: ", "", h)
  f <- file.path(raiz, ".git", ref)
  if (file.exists(f)) return(list(sha = trimws(readLines(f, warn = FALSE)[1]), arbol = "no verificado (git no disponible)"))
  pk <- file.path(raiz, ".git", "packed-refs")
  if (file.exists(pk)) {
    l <- grep(paste0(" ", ref, "$"), readLines(pk, warn = FALSE), value = TRUE)
    if (length(l) == 1L) return(list(sha = sub(" .*$", "", l), arbol = "no verificado (git no disponible)"))
  }
  stop("motor: no se pudo resolver ", ref, " en .git")
}

#' C-4 (F5-16): identidad del corte para el token y el manifiesto. `etiqueta` = nombre del CSV sin
#' extensión + "@" + los 8 primeros hex del sha256 sin CR (TOKEN_PATRON_CONJUNTO de eval_lib.R).
identidad_conjunto <- function(ruta_conjunto, salida = Sys.getenv("SIE_SALIDA")) {
  if (!file.exists(ruta_conjunto)) stop("C-4: no existe el corte ", ruta_conjunto)
  sha <- .sha256_lf(ruta_conjunto)
  nombre <- tools::file_path_sans_ext(basename(ruta_conjunto))
  et <- paste0(nombre, "@", substr(sha, 1, 8))
  if (!grepl(TOKEN_PATRON_CONJUNTO, et)) stop("C-4: el nombre del corte no cabe en el token: ", et)
  list(ruta = ruta_relativa(ruta_conjunto), sha256 = sha, etiqueta = et, salida = ruta_relativa(salida))
}

#' Ruta relativa a la raíz del repo, con "/", para el manifiesto; las que caen fuera quedan absolutas.
ruta_relativa <- function(rutas, raiz = here::here()) {
  r <- normalizePath(raiz, winslash = "/", mustWork = FALSE)
  p <- normalizePath(rutas, winslash = "/", mustWork = FALSE)
  dentro <- startsWith(tolower(p), paste0(tolower(r), "/"))
  ifelse(dentro, substring(p, nchar(r) + 2L), p)
}

.sha256 <- function(ruta) digest::digest(file = ruta, algo = "sha256")
.sha256_lf <- function(ruta) {
  b <- readBin(ruta, "raw", n = file.info(ruta)$size)
  digest::digest(b[b != as.raw(13L)], algo = "sha256", serialize = FALSE)
}

escribir_experimento <- function(ex, res, commit, insumos_sha, conjunto = NULL) {
  dir <- here::here("data", "L4_experiments", ex$exp_id)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  tablas <- list(pronosticos = res$pronosticos, metricas = res$metricas, pruebas = res$pruebas, mcs = res$mcs)
  if (!is.null(res$ajuste_estacional)) tablas$ajuste_estacional <- res$ajuste_estacional
  if (!is.null(res$diagnosticos)) tablas$diagnosticos <- res$diagnosticos
  if (!is.null(res$sub)) {
    tablas$metricas_submuestras <- res$sub$metricas
    tablas$pruebas_submuestras  <- res$sub$pruebas
    tablas$mcs_submuestras      <- res$sub$mcs
  }
  if (!is.null(res$estabilidad)) tablas$estabilidad <- res$estabilidad
  opcionales <- c("ajuste_estacional", "diagnosticos", "metricas_submuestras", "pruebas_submuestras", "mcs_submuestras", "estabilidad")
  for (nm in setdiff(opcionales, names(tablas))) {                               # sin restos de corridas previas
    viejo <- file.path(dir, paste0(nm, ".csv"))
    if (file.exists(viejo)) file.remove(viejo)
  }
  sha <- character(0)
  for (nm in names(tablas)) {
    ruta <- file.path(dir, paste0(nm, ".csv"))
    con <- file(ruta, open = "wb")                                               # LF en todas las plataformas
    utils::write.csv(tablas[[nm]], con, row.names = FALSE, na = "", eol = "\n")
    close(con)
    sha[[paste0(nm, ".csv")]] <- .sha256(ruta)
  }
  lin <- c(
    paste0("exp_id: ", ex$exp_id),
    paste0("esquema_validacion: ", res$token),
    paste0("objetivo: ", ex$objetivo),
    if (length(res$predictoras)) paste0("predictoras: ", paste(res$predictoras, collapse = ", "),
                                        " (rezagos de rezagos_predictoras(); borde G-7, F5-04)") else NULL,
    paste0("commit_hash: ", commit$sha),
    paste0("arbol: ", commit$arbol),
    if (!is.null(conjunto)) paste0("conjunto: ", conjunto$ruta, "  sha256 sin CR ", conjunto$sha256,
                                   "  (corte congelado de Fase 5, F5-16; capas leídas de ", conjunto$salida, "/)") else NULL,
    paste0("fecha_corrida: ", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
    "semillas: por (exp_id, modelo_id, origen) con semilla_de() de eval_lib.R (xxhash32); MCS por (exp_id, 'MCS', h), listada en mcs.csv",
    if (!is.null(ex$semilla_exp) && ex$semilla_exp != ex$exp_id) paste0("semilla_exp: ", ex$semilla_exp,
      " (C-7: las semillas se derivan de este exp_id, el del experimento de Fase 4 que se reproduce)") else NULL,
    paste0("mcs: T_max, alpha = ", ALPHA_MCS, ", B = ", B_MCS, ", bootstrap estacionario circular, bloque max(h, ceiling(n^(1/3))) (F4-15)"),
    if ("identico_a" %in% names(res$mcs)) paste0("mcs: modelos con pérdidas idénticas en una celda se evalúan una vez y comparten p_mcs, en_mcs y orden_eliminacion ",
                                                 "con su representante, el primero en el orden de los modelos; columna identico_a (B2-9)") else NULL,
    paste0("calibracion: densidad gaussiana plug-in (F4-33) para los modelos con predecir_densidad(): ",
           paste(res$densidad_ids, collapse = ", "),
           "; los demás quedan con cobertura_80, cobertura_95 y crps vacías (protocolo §3.4)"),
    if (!is.null(res$diagnosticos)) paste0("diagnosticos: diagnosticos.csv, una fila por (modelo, origen, clave) de los modelos con diagnosticar(): ",
                                           paste(unique(res$diagnosticos$modelo_id), collapse = ", "),
                                           " (órdenes elegidos; en las ARIMAX, número de condición y correlación máxima de las predictoras, B1b-1)") else NULL,
    if (length(res$combinaciones)) paste0("combinaciones: ", paste(res$combinaciones, collapse = ", "), " sobre los modelos de Fase 5 del experimento ",
                                          "(sin benchmarks; F5-13, F5-14e); pesos de ECM_INV con δ = ", DELTA_ECM_INV, " e iguales con menos de ",
                                          MIN_ERRORES_ECM_INV, " errores, contra el objetivo visto en cada origen (B5-1), en diagnosticos.csv; sin densidad (F5-12)") else NULL,
    if (any(grepl("^(REG\\.ENET|REG\\.PCR|ML\\.RF|ML\\.LGBM)\\.", res$ids))) paste0("validación anidada de REG.ENET, REG.PCR, ML.RF y ML.LGBM: reoptimiza solo en los orígenes Q1 ",
                                                                             "y reutiliza la elección en los otros tres (variante de F5-11, F5-14d); reoptimizado en diagnosticos.csv") else NULL,
    if (con_representantes(ex)) paste0("variante con representantes (F5-14c): los univariados de B1, MULT.VAR_DIF, REG.ENET, MIX.PUENTE y ML.RF; ",
                                       "el BVAR y los demás modelos de Fase 5 no corren; sus combinaciones llevan esos miembros y no son las de la principal (F5-14e)") else NULL,
    if (!is.null(res$rezago_ut)) paste0("variante R7: UT a ", res$rezago_ut, " días en lugar de 30 (F5-04c); solo los modelos con UT y los benchmarks; sin combinaciones (B5-4)") else NULL,
    if (length(res$predictoras) && ex$ventana != "expansiva") "predictoras: recortadas al inicio de la ventana del objetivo en cada origen (B5-3)" else NULL,
    "datos: revisados, no en tiempo real (F4-03)",
    if (ex$sa == "l3_unico" && ex$objetivo == "PIB_SA_OFICIAL_Q") "limite: serie SA oficial del BCR tal cual; hereda la filtración de su ajuste bilateral (F4-22)" else NULL,
    if (ex$sa == "l3_unico" && ex$objetivo == "PIB_SA_PROPIO_Q") "sa: ajuste único de L3 (R6); hereda la filtración del ajuste sobre la muestra completa" else NULL,
    if (ex$ventana == "rodante92") paste0("ventana: rodante de ", VENTANA_RODANTE, " trimestres para estimar; X-13 sobre [1990-Q1, o] (F4-26); GW con varianza Bartlett h-1, marca tamano_no_verificado") else NULL,
    if (ex$ventana == "homogenea2005") paste0("ventana: X-13 y estimación sobre la NSA nativa [", INICIO_HOMOGENEO, ", o]; bases del ajuste propio (F4-27)") else NULL,
    if (!is.null(res$sub)) paste0("submuestras: ", paste(unique(res$sub$metricas$muestra_eval), collapse = ", "),
                                  " sobre los mismos errores; semilla MCS por (exp_id, 'MCS|<muestra>', h) (F4-28, F4-29)") else NULL,
    if (!is.null(res$sub) && any(grepl("^sin_", res$sub$metricas$muestra_eval))) "submuestras: en sin_2020 y sin_2020_2021 DM/HLN y MCS corren sobre pares no consecutivos concatenados (aproximación declarada)" else NULL,
    if (!is.null(res$estabilidad)) "estabilidad: MCO de d_t sobre (1, D_post), D_post = 1{target >= 2020-Q1}, HAC Bartlett h-1, t con n-2 gl (F4-28)" else NULL,
    paste0("semilla_registro: la del primer origen del grupo (", ind_a_q(origenes_grupo(ex$grupo)[1]), ") para cada modelo (F4-25)"),
    "",
    "insumos (sha256 del contenido sin retornos de carro, F4-31):", paste0("  ", names(insumos_sha), "  ", insumos_sha),
    "salidas (sha256):", paste0("  ", names(sha), "  ", sha),
    "", "sessionInfo():", utils::capture.output(utils::sessionInfo())
  )
  con <- file(file.path(dir, "manifiesto.txt"), open = "wb")
  writeLines(enc2utf8(lin), con, sep = "\n", useBytes = TRUE)
  close(con)
  invisible(sha)
}

#' CSV con comillas solo donde hacen falta, como los catálogos editados a mano, y LF.
.escribir_csv_catalogo <- function(df, ruta) {
  esc <- function(x) {
    x <- ifelse(is.na(x), "", as.character(x))
    ifelse(grepl('[",\n]', x), paste0('"', gsub('"', '""', x, fixed = TRUE), '"'), x)
  }
  lin <- c(paste(names(df), collapse = ","), if (nrow(df)) do.call(paste, c(lapply(df, esc), sep = ",")))
  con <- file(ruta, open = "wb")
  writeLines(enc2utf8(lin), con, sep = "\n", useBytes = TRUE)
  close(con)
}

#' Entorno de la corrida para 07 (sin comas): versión de R, plataforma y sha256 de renv.lock. El
#' hash se toma sin retornos de carro (.sha256_lf, F4-31): así identifica el renv.lock versionado (LF)
#' y no depende de cómo la copia de trabajo convierta los fines de línea (en Windows suele quedar en
#' CRLF). Los insumos del manifiesto se hashean igual; las salidas, que el motor escribe en LF, con
#' los bytes tal cual.
entorno_corrida <- function() {
  lock <- here::here("renv.lock")
  s <- if (file.exists(lock)) substr(.sha256_lf(lock), 1, 12) else "sin_renv_lock"
  paste0(R.version$version.string, "; ", R.version$platform, "; renv.lock sha256:", s)
}

#' Filas de 07 de los experimentos corridos, reemplazando las previas de esos exp_id (F4-25).
registrar_experimentos <- function(filas) {
  ruta <- here::here("catalogos", "07_experimentos.csv")
  existente <- utils::read.csv(ruta, colClasses = "character", check.names = FALSE, na.strings = character(0))
  nuevas <- do.call(rbind, filas)
  nuevas[] <- lapply(nuevas, as.character)
  .escribir_csv_catalogo(actualizar_registro_experimentos(existente, nuevas), ruta)
  invisible(nrow(nuevas))
}

# ---------------------------------------------------------------------------------------------
# Principal
# ---------------------------------------------------------------------------------------------

main <- function(exp_ids = character(0)) {
  sel <- seleccionar_experimentos(exp_ids)                                       # C-8
  conjunto <- exigir_conjunto(conjunto_activo())                               # C-3 (F5-16)
  modelos_corrida <- do.call(c, lapply(seq_len(nrow(sel)), function(k) modelos_experimento(sel[k, ])))
  modelos_corrida <- modelos_corrida[!duplicated(vapply(modelos_corrida, `[[`, character(1), "modelo_id"))]
  combs <- unique(unlist(lapply(seq_len(nrow(sel)), function(k) combinaciones_experimento(sel[k, ]))))
  verificar_registro_modelos(c(modelos_corrida, lapply(combs, function(id) list(modelo_id = id))))   # C8 (y B5)
  for (k in seq_len(nrow(sel))) verificar_miembros_combinaciones(sel[k, ])                      # F5-13, F5-14e
  commit <- leer_commit()
  vintages <- leer_vintages()
  pol <- unique(sel$vintage)
  if (length(pol) != 1L) stop("motor: una corrida usa una sola política de vintage")
  objetivos <- list()
  for (ob in unique(sel$objetivo)) objetivos[[ob]] <- leer_objetivo(paste0(ob, ".csv"), pol, vintages, conjunto)
  necesita_sa <- any(sel$sa == "reestimado_en_origen")
  insumos <- list(objetivos = objetivos, conjunto = identidad_conjunto(Sys.getenv("SIE_CONJUNTO")))   # C-4
  # Rutas absolutas de los insumos; el manifiesto las lista relativas a la raíz del repo.
  archivos <- c(normalizePath(Sys.getenv("SIE_CONJUNTO"), winslash = "/", mustWork = TRUE),   # el corte es insumo (C-4)
                vapply(paste0(unique(sel$objetivo), ".csv"), function(a) ruta_capa("L3_master", a), character(1)),
                here::here("catalogos", c("03_series.csv", "08_vintages.csv")))
  if (necesita_sa) {
    prop <- if (!is.null(objetivos$PIB_SA_PROPIO_Q)) objetivos$PIB_SA_PROPIO_Q else leer_objetivo("PIB_SA_PROPIO_Q.csv", pol, vintages, conjunto)
    l1 <- .leer_capa("L1_staging", "BCR_PIB_series_largo.csv")
    insumos$nsa <- leer_nsa_concat(vintages, prop, conjunto, l1 = l1)
    insumos$outliers <- .leer_capa("L3_master", "PIB_SA_PROPIO_Q_outliers.csv")
    verificar_l1_contra_l3(ajustar_estacional_propio(concatenar_pib_nsa(l1)),               # C-5
                           .leer_capa("L3_master", "PIB_SA_PROPIO_Q.csv"), insumos$outliers)
    archivos <- c(archivos, ruta_capa("L1_staging", "BCR_PIB_series_largo.csv"),
                  ruta_capa("L3_master", "PIB_SA_PROPIO_Q_outliers.csv"))
  }
  pred <- predictoras_requeridas(modelos_corrida)                               # B1a
  if (length(pred)) {
    insumos$predictoras <- leer_predictoras(pred, vintages, conjunto)           # G-6 sobre el corte
    archivos <- c(archivos, vapply(pred, function(id) ruta_capa("L3_master", archivo_l3(id)), character(1)))
  }
  archivos <- c(archivos, here::here("catalogos", "06_modelos", paste0(c(vapply(modelos_corrida, `[[`, character(1), "modelo_id"), combs), ".yaml")))
  archivos <- unique(unname(archivos))
  insumos_sha <- stats::setNames(vapply(archivos, .sha256_lf, character(1), USE.NAMES = FALSE), ruta_relativa(archivos))   # F4-31
  cache_sa <- new.env()
  filas <- list()
  fecha <- Sys.Date()
  entorno <- entorno_corrida()
  for (k in seq_len(nrow(sel))) {
    ex <- sel[k, ]
    t0 <- Sys.time()
    res <- correr_experimento(ex, insumos, cache_sa)
    escribir_experimento(ex, res, commit, insumos_sha, insumos$conjunto)
    filas[[ex$exp_id]] <- construir_filas_experimento(ex$exp_id, res$ids, res$vintages, res$muestra_inicio, res$muestra_fin,
                                                      res$token, res$semillas, commit$sha, fecha, entorno)
    cat(sprintf("OK %-16s %s  %d pronósticos  %.0f s\n", ex$exp_id, res$token, nrow(res$pronosticos),
                as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  }
  n <- registrar_experimentos(filas)                                            # F4-25, después de todas las salidas
  cat(sprintf("07_experimentos.csv: %d filas de %d experimentos\n", n, length(filas)))
  invisible(TRUE)
}

if (sys.nframe() == 0L) main(commandArgs(trailingOnly = TRUE))
