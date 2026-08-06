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
  "testthat"      # pruebas
)

install.packages(paquetes)

renv::snapshot()

message("Entorno inicializado. renv.lock generado. Verificar con renv::status().")
