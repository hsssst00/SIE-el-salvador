# validar_conjunto.R
#
# Primer paso de `make master`. Sin SIE_CONJUNTO (make master sin CONJUNTO=) no hace nada. Con un
# conjunto de vintages declarado (make master CONJUNTO=<ruta.csv> SALIDA=<dir>) lo valida ENTERO
# antes de que ningun otro script escriba algo: formato, SALIDA que no cae en una capa vigente,
# cada vintage_id existe y es de su publicacion, su archivo esta en L0 con el sha256 del
# manifiesto, y no falta ninguna publicacion que el pipeline necesita (todas las de
# catalogos/03_series.csv). Las sobrantes se permiten y se informan. Reglas en conjunto_lib.R,
# que prueba tests/test-conjunto.R. Falla con stop() (regla 7 de CLAUDE.md).

source(here::here("src", "transformacion", "conjunto_lib.R"))

if (!nzchar(Sys.getenv("SIE_CONJUNTO", "")) && !nzchar(Sys.getenv("SIE_SALIDA", ""))) {
  cat("Sin conjunto de vintages declarado: make master usa el vintage vigente (sin cambios).\n")
  quit(status = 0)
}

conjunto <- conjunto_activo()  # exige SIE_CONJUNTO y SIE_SALIDA juntas
salida <- ruta_capa("L1_staging")  # valida SALIDA (stop si cae en una capa vigente)

dir_l0 <- here::here("data", "L0_raw")
resultado <- validar_conjunto(
  conjunto = conjunto,
  vintages = leer_vintages(),
  manifiesto = leer_manifiesto(dir_l0),
  dir_l0 = dir_l0,
  necesarias = publicaciones_necesarias(
    read.csv(here::here("catalogos", "03_series.csv"), stringsAsFactors = FALSE, na.strings = ""))
)

cat("OK conjunto: ", nrow(conjunto), " vintage(s) de ", length(unique(conjunto$publicacion_id)),
    " publicacion(es); las ", length(resultado$necesarias), " que el pipeline necesita estan cubiertas.\n",
    "Salida: ", dirname(salida), "\n", sep = "")
if (length(resultado$sobrantes) > 0) {
  cat("Publicaciones del conjunto que el pipeline no usa (permitidas): ",
      paste(resultado$sobrantes, collapse = ", "), "\n", sep = "")
}
