# tests/test-catalogo-modelos.R
#
# Coherencia del catálogo catalogos/06_modelos/*.yaml (checklist de Fase 4, C8). El catálogo es el
# registro previo de cada modelo: se declara antes de la primera corrida sobre L3, así que esta
# prueba comprueba que lo declarado y lo implementado no se separen sin que nada avise.
#
#   1. claves idénticas a _plantilla.yaml, en el mismo orden;
#   2. modelo_id igual al nombre del archivo y familia dentro del dominio que declara la plantilla;
#   3. especificacion.variables resuelve contra 05_series_master.csv y transformaciones_ref contra
#      04_transformaciones.csv (aristas nuevas del grafo de integridad referencial);
#   4. los BENCH.* declarados son exactamente los que implementa src/evaluacion/modelos_referencia.R,
#      y las grillas declaradas del AR(1) y del AR(p)-BIC coinciden con las del código;
#   5. (Fase 5, B1b) los modelos no benchmark declarados son exactamente los del registro modelos_fase5() de
#      los tres grupos, sus variables son las que piden al motor y las grillas del ARIMA y de las ARIMAX
#      coinciden con las del código (preregistro F5-02); (B2a) también las rejillas de los VAR y del VECM;
#      (B2b) y los órdenes del BVAR (rezagos, extracciones, quemado); (B3) y las rejillas de ENET y PCR; (B3b) y los órdenes de
#      U-MIDAS y puente; (B4) y las rejillas del RF y de LightGBM (árboles, mtry por grupo, tamaño de nodo, hojas, tasa, rondas).
#
# No lee datos del proyecto: corre en CI. Lee YAML con `yaml`, en Imports desde Fase 4 (F4-12).

library(testthat)
source(here::here("src", "evaluacion", "eval_lib.R"))
source(here::here("src", "evaluacion", "modelos_referencia.R"))
source(here::here("src", "evaluacion", "modelos_fase5.R"))
source(here::here("src", "evaluacion", "combinaciones.R"))         # B5

.dir_modelos <- here::here("catalogos", "06_modelos")
.leer_modelo <- function(archivo) yaml::read_yaml(file.path(.dir_modelos, archivo))
.archivos_modelo <- function() {
  a <- list.files(.dir_modelos, pattern = "\\.yaml$")
  a[!startsWith(a, "_")]                                    # excluir _plantilla.yaml
}

test_that("06_modelos: hay al menos un modelo declarado", {
  expect_gt(length(.archivos_modelo()), 0L)
})

test_that("06_modelos: cada YAML tiene exactamente las claves de la plantilla", {
  pl <- .leer_modelo("_plantilla.yaml")
  for (a in .archivos_modelo()) {
    m <- .leer_modelo(a)
    expect_identical(names(m), names(pl), info = a)
    expect_identical(names(m$especificacion), names(pl$especificacion), info = a)
  }
})

test_that("06_modelos: modelo_id coincide con el archivo, familia en el dominio y textos no vacíos", {
  # El dominio de `familia` vive en el comentario de la plantilla; se lee de ahí para no duplicarlo.
  linea <- grep("^familia:", readLines(file.path(.dir_modelos, "_plantilla.yaml"), encoding = "UTF-8"), value = TRUE)
  dominio <- trimws(strsplit(sub("^.*#", "", linea), "|", fixed = TRUE)[[1]])
  expect_true(length(dominio) >= 2L)
  for (a in .archivos_modelo()) {
    m <- .leer_modelo(a)
    expect_identical(m$modelo_id, sub("\\.yaml$", "", a), info = a)
    expect_true(m$familia %in% dominio, info = a)
    expect_true(is.character(m$justificacion) && nzchar(m$justificacion), info = a)
    expect_true(is.character(m$referencia_bibliografica) && nzchar(m$referencia_bibliografica), info = a)
  }
})

test_that("06_modelos: variables y transformaciones_ref resuelven contra 05 y 04", {
  sm <- read.csv(here::here("catalogos", "05_series_master.csv"), stringsAsFactors = FALSE)
  tr <- read.csv(here::here("catalogos", "04_transformaciones.csv"), stringsAsFactors = FALSE)
  for (a in .archivos_modelo()) {
    e <- .leer_modelo(a)$especificacion
    v <- unlist(e$variables); t_ <- unlist(e$transformaciones_ref)
    expect_true(length(v) > 0L, info = a)
    expect_true(all(v %in% sm$series_master_id), info = paste(a, paste(setdiff(v, sm$series_master_id), collapse = ", ")))
    expect_true(all(t_ %in% tr$transf_id), info = paste(a, paste(setdiff(t_, tr$transf_id), collapse = ", ")))
  }
})

test_that("06_modelos: los BENCH.* declarados son exactamente los seis de modelos_referencia()", {
  ids_codigo <- vapply(modelos_referencia(), `[[`, character(1), "modelo_id")
  declarados <- vapply(.archivos_modelo(), function(a) .leer_modelo(a)$modelo_id, character(1), USE.NAMES = FALSE)
  bench <- declarados[vapply(.archivos_modelo(), function(a) identical(.leer_modelo(a)$familia, "benchmark"), logical(1))]
  expect_setequal(bench, ids_codigo)
})

test_that("06_modelos: las grillas declaradas del AR(1) y del AR(p)-BIC son las del código", {
  ar1 <- .leer_modelo("BENCH.AR1.yaml")$especificacion$ordenes
  expect_identical(as.integer(ar1$p), 1L)
  arp <- .leer_modelo("BENCH.ARP_BIC.yaml")$especificacion
  expect_identical(as.integer(arp$ordenes$p_min), 0L)
  expect_identical(as.integer(arp$ordenes$p_max), as.integer(formals(modelo_arp_bic)$p_max))
  expect_identical(arp$hiperparametros$criterio, "BIC")
})

test_that("06_modelos: los modelos de Fase 5 declarados son los de modelos_fase5() y piden las mismas series", {
  reg <- do.call(c, lapply(c("G1", "G2", "G3"), modelos_fase5))
  reg <- reg[!duplicated(vapply(reg, `[[`, character(1), "modelo_id"))]
  ids <- vapply(reg, `[[`, character(1), "modelo_id")
  declarados <- vapply(.archivos_modelo(), function(a) .leer_modelo(a)$modelo_id, character(1), USE.NAMES = FALSE)
  no_bench <- declarados[vapply(.archivos_modelo(), function(a) !.leer_modelo(a)$familia %in% c("benchmark", "combinacion"), logical(1))]
  expect_setequal(no_bench, ids)
  for (m in reg) {
    v <- unlist(.leer_modelo(paste0(m$modelo_id, ".yaml"))$especificacion$variables)
    expect_identical(v, c("PIB.SA.PROPIO.Q", setdiff(m$requiere, "objetivo")), info = m$modelo_id)
  }
})

test_that("06_modelos: las grillas declaradas del ARIMA y de las ARIMAX son las del código (B1-2)", {
  a <- .leer_modelo("UNI.ARIMA.yaml")$especificacion$ordenes
  expect_identical(as.integer(c(a$p_max, a$q_max, a$d_max)), unname(unlist(ORDENES_UNI_ARIMA[c("p_max", "q_max", "d_max")])))
  for (m in list(modelo_arimax_grupo("G1"), modelo_arimax_grupo("G2"), modelo_arimax_grupo("G3"), modelo_arimax_ivae())) {
    o <- .leer_modelo(paste0(m$modelo_id, ".yaml"))$especificacion$ordenes
    pq <- if (is.null(o$pq_max)) as.integer(o$p_max) + as.integer(o$q_max) else as.integer(o$pq_max)
    expect_identical(as.integer(unlist(o$rezagos_predictoras)), as.integer(m$rezagos_x), info = m$modelo_id)
    g <- grilla_arma(as.integer(o$p_max), as.integer(o$q_max), pq)
    expect_identical(unname(as.matrix(g)), unname(as.matrix(m$grilla)), info = m$modelo_id)
    expect_identical(as.integer(o$p_max_ar_predictoras), P_MAX_PREDICTORAS, info = m$modelo_id)
    expect_identical(as.integer(o$diferencias_objetivo), 1L, info = m$modelo_id)
  }
})

test_that("06_modelos: las rejillas declaradas de los VAR y del VECM son las del código (B2-2, B2-3)", {
  for (g in c("G1", "G2", "G3")) for (m in modelos_multivariados_grupo(g)) {
    o <- .leer_modelo(paste0(m$modelo_id, ".yaml"))$especificacion$ordenes
    if (startsWith(m$modelo_id, "MULT.VECM")) {
      expect_identical(as.integer(c(o$p_min_niveles, o$p_max_niveles, o$K_min)), c(1L, P_MAX_VECM, 2L), info = m$modelo_id)
    } else {
      expect_identical(as.integer(c(o$p_min, o$p_max)), c(1L, m$p_max), info = m$modelo_id)
      expect_identical(as.integer(o$diferencias), if (m$forma == "dif") 1L else 0L, info = m$modelo_id)
    }
  }
})

test_that("06_modelos: los órdenes declarados del BVAR son los del código (B2-7)", {
  for (g in c("G1", "G2", "G3")) {
    m <- modelo_bvar_grupo(g)
    o <- .leer_modelo(paste0(m$modelo_id, ".yaml"))$especificacion$ordenes
    expect_identical(as.integer(c(o$lags, o$n_draw, o$n_burn, o$n_thin)), c(m$lags, m$n_draw, m$n_burn, 1L), info = m$modelo_id)
  }
})

test_that("06_modelos: las rejillas declaradas de los regularizados son las del código (F5-09, F5-11, B3-1)", {
  for (g in c("G1", "G2", "G3")) {
    e <- .leer_modelo(paste0("REG.ENET.", g, ".yaml"))$especificacion$ordenes
    expect_identical(as.integer(unlist(e$rezagos)), as.integer(REZAGOS_FORMA_DIRECTA), info = g)
    expect_identical(as.integer(c(e$K_validacion, e$h_max, e$n_lambda)), c(K_VALIDACION_ANIDADA, H_FORMA_DIRECTA, N_LAMBDA_ENET), info = g)
    expect_identical(as.numeric(unlist(e$alfas)), ALFAS_ENET, info = g)
    expect_identical(as.numeric(e$razon_lambda), RAZON_LAMBDA_ENET, info = g)
    p <- .leer_modelo(paste0("REG.PCR.", g, ".yaml"))$especificacion$ordenes
    expect_identical(as.integer(unlist(p$rezagos)), as.integer(REZAGOS_FORMA_DIRECTA), info = g)
    expect_identical(as.integer(c(p$K_validacion, p$h_max, p$k_min, p$k_max)), c(K_VALIDACION_ANIDADA, H_FORMA_DIRECTA, 1L, K_MAX_PCR), info = g)
  }
})

test_that("06_modelos: los órdenes declarados de U-MIDAS y puente son los del código (F5-08, B3b-1, B3b-4)", {
  for (g in c("G1", "G2", "G3")) {
    u <- .leer_modelo(paste0("MIX.UMIDAS.", g, ".yaml"))$especificacion$ordenes
    expect_identical(as.integer(unlist(u$lags_mensuales)), as.integer(LAGS_UMIDAS[[g]]), info = g)
    expect_identical(as.integer(c(u$K_validacion, u$h_max)), c(K_VALIDACION_ANIDADA, H_FORMA_DIRECTA), info = g)
    p <- .leer_modelo(paste0("MIX.PUENTE.", g, ".yaml"))$especificacion$ordenes
    expect_identical(as.integer(c(p$p_max_ar_mensual, p$rezagos_pib, p$h_max)), c(P_MAX_AR_MENSUAL, 1L, DISENO_FASE4$h_max), info = g)
  }
})

test_that("06_modelos: las rejillas declaradas de los árboles son las del código (F5-10, F5-11, B4-3, B4-4)", {
  for (g in c("G1", "G2", "G3")) {
    m <- modelo_rf_grupo(g)
    e <- .leer_modelo(paste0(m$modelo_id, ".yaml"))$especificacion$ordenes
    p <- 4L * (1L + length(predictoras_grupo(g)))                          # Δy y cada predictora con rezagos 0..3
    expect_identical(as.integer(unlist(e$rezagos)), as.integer(REZAGOS_FORMA_DIRECTA), info = g)
    expect_identical(as.integer(c(e$K_validacion, e$h_max, e$num_arboles, e$columnas, e$num_threads)),
                     c(K_VALIDACION_ANIDADA, H_FORMA_DIRECTA, NUM_ARBOLES_RF, p, 1L), info = g)
    expect_identical(m$esp$num_arboles, NUM_ARBOLES_RF, info = g)
    expect_identical(as.integer(unlist(e$mtry)), mtry_rf(p), info = g)
    expect_identical(as.integer(unlist(e$min_node_size)), NODO_MIN_RF, info = g)
    declarada <- data.frame(min_node_size = rep(as.integer(unlist(e$min_node_size)), each = length(unlist(e$mtry))),
                            mtry = rep(as.integer(unlist(e$mtry)), times = length(unlist(e$min_node_size))))
    expect_identical(m$esp$candidatos(matrix(0, 2L, p), numeric(2), 1L), declarada, info = g)
    l <- modelo_lgbm_grupo(g)
    o <- .leer_modelo(paste0(l$modelo_id, ".yaml"))$especificacion$ordenes
    expect_identical(as.integer(unlist(o$rezagos)), as.integer(REZAGOS_FORMA_DIRECTA), info = g)
    expect_identical(as.integer(c(o$K_validacion, o$h_max, o$min_data_in_leaf, o$num_threads)),
                     c(K_VALIDACION_ANIDADA, H_FORMA_DIRECTA, DATOS_HOJA_LGBM, 1L), info = g)
    expect_identical(as.integer(unlist(o$num_leaves)), HOJAS_LGBM, info = g)
    expect_identical(as.numeric(o$learning_rate), TASA_LGBM, info = g)
    expect_identical(as.integer(c(o$rondas_min, o$rondas_max, o$paso_rondas)), c(PASO_RONDAS_LGBM, RONDAS_MAX_LGBM, PASO_RONDAS_LGBM), info = g)
    rl <- l$esp$candidatos(matrix(0, 2L, p), numeric(2), 1L)
    expect_identical(unique(rl$num_leaves), as.integer(unlist(o$num_leaves)), info = g)
    expect_identical(unique(rl$rondas), seq.int(as.integer(o$rondas_min), as.integer(o$rondas_max), by = as.integer(o$paso_rondas)), info = g)
  }
})

test_that("06_modelos: las combinaciones declaradas son las de B5, con los miembros del registro y los parámetros del código (F5-13)", {
  declarados <- vapply(.archivos_modelo(), function(a) .leer_modelo(a)$modelo_id, character(1), USE.NAMES = FALSE)
  comb <- declarados[vapply(.archivos_modelo(), function(a) identical(.leer_modelo(a)$familia, "combinacion"), logical(1))]
  expect_setequal(comb, unlist(lapply(c("G1", "G2", "G3"), ids_combinaciones)))
  for (g in c("G1", "G2", "G3")) for (id in ids_combinaciones(g)) {
    e <- .leer_modelo(paste0(id, ".yaml"))$especificacion
    expect_identical(as.character(unlist(e$variables)), "PIB.SA.PROPIO.Q", info = id)
    expect_identical(as.character(unlist(e$hiperparametros$miembros)), miembros_combinacion(g), info = id)   # F5-13: sin benchmarks
    expect_false(any(startsWith(unlist(e$hiperparametros$miembros), "BENCH.")), info = id)
  }
  for (g in c("G1", "G2", "G3")) {
    expect_identical(as.numeric(.leer_modelo(paste0("COMB.RECORTADA.", g, ".yaml"))$especificacion$hiperparametros$recorte), RECORTE_COMBINACION)
    h <- .leer_modelo(paste0("COMB.ECM_INV.", g, ".yaml"))$especificacion$hiperparametros
    expect_identical(c(as.numeric(h$delta), as.numeric(h$min_errores)), c(DELTA_ECM_INV, as.numeric(MIN_ERRORES_ECM_INV)))
  }
})
