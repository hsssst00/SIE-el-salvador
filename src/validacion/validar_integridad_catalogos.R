# Integridad referencial ENTRE catálogos (03_series, 05_series_master, 08_vintages, 09_rupturas
# contra 01_publicaciones/02_metodologias/03_series/04_transformaciones entre sí). Debe FALLAR,
# no advertir (regla 7 de CLAUDE.md, senda §3.5).
#
# Reglas en src/validacion/integridad_catalogos_reglas.R (validar_integridad_catalogos()), para
# que tests/test-integridad-catalogos.R las ejerza con datos sintéticos sin tocar disco. Ver ese
# archivo para el detalle de las 6 aristas cubiertas y por qué NO cubre 01_publicaciones/*.yaml
# (se queda en tests/test-integridad-referencial.R, R base, mismo motivo que la migración de L2).
#
# Se corre como parte de `make validate`, junto a validate_catalogs.R (esquema de columnas).

source(here::here("src", "validacion", "integridad_catalogos_reglas.R"))

.stems <- function(subdir) {
  archivos <- list.files(here::here("catalogos", subdir), pattern = "\\.yaml$")
  archivos <- archivos[!startsWith(archivos, "_")]   # excluir _plantilla.yaml
  sub("\\.yaml$", "", archivos)
}

.csv <- function(nombre) {
  read.csv(here::here("catalogos", nombre), stringsAsFactors = FALSE,
           colClasses = "character", check.names = FALSE)
}

pubs <- .stems("01_publicaciones")
mets <- .stems("02_metodologias")

series    <- .csv("03_series.csv")
transf    <- .csv("04_transformaciones.csv")
master    <- .csv("05_series_master.csv")
vintages  <- .csv("08_vintages.csv")
rupturas  <- .csv("09_rupturas.csv")

resultado <- validar_integridad_catalogos(series, transf, master, vintages, rupturas, pubs, mets)
errores <- resultado$errores

if (length(errores) > 0) {
  cat("\nINTEGRIDAD REFERENCIAL ENTRE CATÁLOGOS FALLIDA (", length(errores), " problema(s)):\n\n", sep = "")
  for (e in errores) cat("  - ", e, "\n", sep = "")
  stop("Catálogos con aristas de integridad referencial rotas.")
}

message("Integridad referencial entre catálogos OK (03_series, 05_series_master, 08_vintages, 09_rupturas).")
