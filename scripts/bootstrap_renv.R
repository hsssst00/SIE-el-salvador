# Bootstrap del entorno reproducible del proyecto.
# Correr una sola vez, en una máquina con R y acceso a CRAN.
# Genera el renv.lock real — este repositorio se creó sin acceso a CRAN,
# así que este paso no se ha ejecutado todavía.
#
# Uso:
#   source("scripts/bootstrap_renv.R")

if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv")
}

renv::init(bare = TRUE)

# Paquetes fijados en ADR-009 — no añadir aquí sin registrar el ADR correspondiente.
paquetes <- c(
  "pointblank",   # validación de esquema (ADR-005)
  "duckdb",       # almacén consolidado derivado (ADR-005)
  "seasonal",     # ajuste estacional X-13ARIMA-SEATS (ADR-001, ADR-004)
  "tempdisagg",   # empalme / desagregación temporal (D3 — no requerido tras ADR-003, se deja disponible)
  "fable",        # ARIMA / ETS
  "tsibble",      # estructura de series de tiempo (tidyverts)
  "vars",         # VAR
  "tsDyn",        # VECM
  "BVAR",         # BVAR con priors jerárquicos (Giannone-Lenza-Primiceri)
  "midasr",       # MIDAS / ecuaciones puente
  "glmnet",       # regularización lineal (ridge/LASSO/elastic net)
  "ranger",       # Random Forest
  "lightgbm",     # boosting
  "jsonlite",     # lectura de datapackage.json
  "here",         # rutas relativas al proyecto
  "testthat",     # pruebas
  # --- Fase 2, agregados despues de ADR-009 conforme fueron haciendo falta -------------
  "httr2",        # clientes de API (FMI/FRED/BM) — import #15, ADR-009 2026-08-18
  "xml2",         # lectura del XML interno de un .xlsx en verificar_fuente_celda.R
  "chromote",     # navegador headless para el portal del BCR — ADR-009 2026-08-20
  # Agregados el 2026-08-28 (hallazgo M1 de la auditoria de Fase 2): los tres se usan en
  # codigo commiteado y ninguno estaba declarado. digest venia funcionando como dependencia
  # transitiva ajena; con lib_adquisicion.R -el nucleo de Fase 2- haciendo library(digest),
  # esa excepcion dejo de sostenerse (la propia salvedad de verificar_fuente_celda.R lo
  # anticipaba). polite y readxl no estaban NI EN renv.lock: en una maquina limpia tras
  # renv::restore(), verificar_robots_ut.R y calendario_bcr_extraer.R no arrancaban.
  "digest",       # sha256 en lib_adquisicion.R, verificar_fuente_celda.R, verificar_l0_fisico.R
  "polite",       # verificacion de robots.txt en verificar_robots_ut.R (regla 9)
  "readxl"        # lectura del calendario de divulgacion en calendario_bcr_extraer.R
)

install.packages(paquetes)

# snapshot.type por defecto es "implicit": solo registra paquetes
# referenciados via library()/::/require() en el codigo del proyecto. Como
# estos 16 paquetes se fijan por ADR-009 antes de que exista codigo que los
# use (Fase 0-4), hay que nombrarlos explicitamente para que queden en el
# lockfile. Se agrega "renv" a la lista porque snapshot(packages = ...)
# restringe el snapshot a lo indicado y deja de incluirlo automaticamente.
renv::snapshot(packages = c(paquetes, "renv"))

message("Entorno inicializado. renv.lock generado. Verificar con renv::status().")
