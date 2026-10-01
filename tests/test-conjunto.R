# tests/test-conjunto.R
#
# Pruebas del conjunto de vintages declarado (PR-3): src/transformacion/conjunto_lib.R y el
# argumento `conjunto` de vintage_lib.R / ut_demanda_lib.R. Todo con catalogos, manifiesto y
# archivos SINTETICOS en un directorio temporal: no se toca L0 ni los catalogos reales (salvo las
# comprobaciones de cobertura, que solo LEEN texto del repo). La no-regresion contra la L1/L3
# reales (byte a byte, sha256 sin CR) se corre en la maquina que tiene L0; aqui va su version
# sintetica: un conjunto armado con los vintages vigentes reproduce la serie por defecto.

library(testthat)

source(here::here("src", "transformacion", "vintage_lib.R"))
source(here::here("src", "transformacion", "ut_demanda_lib.R"))
source(here::here("src", "transformacion", "conjunto_lib.R"))

# --- Escenario sintetico ------------------------------------------------------------------------
# PUB_A: dos vintages (v1 y v2). PUB_B: uno. UT: un vintage por año 2020-2022 (2022 parcial, 3
# meses) y una recaptura de 2020. Cada archivo existe en `dir_l0` y el manifiesto declara su
# sha256 real.
csv_ut <- function(ruta, anio, gwh) {
  lineas <- c(
    ',"Unidad de Transacciones, S.A. de C.V.",,,,',
    ',Demanda Total (GWH),,,,',
    ',,,,,Fecha y hora del Reporte:',
    sprintf(',,Anio: %s,,26/08/2026 5.36 PM,', anio),
    'MES,,,GWH,,',
    sprintf('%s,,,%s,,', names(MESES_ES)[seq_along(gwh)], sprintf("%.2f", gwh))
  )
  writeLines(lineas, ruta)
}

escenario <- function() {
  dir_l0 <- tempfile("l0_conj_"); dir.create(dir_l0)
  filas <- list(
    list("PUB_A.v1", "PUB_A", "2026-06", "A_v1.txt", "contenido a1"),
    list("PUB_A.v2", "PUB_A", "2026-07", "A_v2.txt", "contenido a2"),
    list("PUB_B.v1", "PUB_B", "2026-07", "B_v1.txt", "contenido b1")
  )
  for (f in filas) writeLines(f[[5]], file.path(dir_l0, f[[4]]))
  ut <- list(list(2020, 12, ""), list(2021, 12, ""), list(2022, 3, ""), list(2020, 12, "_recaptura"))
  for (u in ut) {
    archivo <- sprintf("UT_%d%s.csv", u[[1]], u[[3]])
    csv_ut(file.path(dir_l0, archivo), u[[1]], 500 + (u[[1]] %% 100) + seq_len(u[[2]]) + nchar(u[[3]]))
    filas[[length(filas) + 1]] <- list(sprintf("UT.v%d-%02d%s", u[[1]], u[[2]], u[[3]]),
                                       PUBLICACION_UT, ut_periodo_max(u[[1]], u[[2]]), archivo, NULL)
  }
  vintages <- data.frame(
    vintage_id = vapply(filas, `[[`, "", 1), publicacion_id = vapply(filas, `[[`, "", 2),
    periodo_referencia_max = vapply(filas, `[[`, "", 3), archivo_raw = vapply(filas, `[[`, "", 4),
    stringsAsFactors = FALSE)
  sha <- vapply(vintages$archivo_raw, function(a)
    digest::digest(file.path(dir_l0, a), algo = "sha256", file = TRUE), "", USE.NAMES = FALSE)
  vintages$sha256 <- sha
  manifiesto <- data.frame(archivo = vintages$archivo_raw, sha256 = sha,
                           vintage_id = vintages$vintage_id,
                           publicacion_id = vintages$publicacion_id, stringsAsFactors = FALSE)
  list(vintages = vintages, manifiesto = manifiesto, dir_l0 = dir_l0)
}

# Conjunto "como hoy": el ultimo vintage de cada publicacion / de cada año.
conjunto_ok <- function() {
  data.frame(
    publicacion_id = c("PUB_A", "PUB_B", rep(PUBLICACION_UT, 3)),
    vintage_id = c("PUB_A.v2", "PUB_B.v1", "UT.v2020-12_recaptura", "UT.v2021-12", "UT.v2022-03"),
    stringsAsFactors = FALSE)
}
NECESARIAS <- c("PUB_A", "PUB_B", PUBLICACION_UT)

# --- leer_conjunto ------------------------------------------------------------------------------

test_that("leer_conjunto lee un CSV valido y recorta espacios", {
  ruta <- tempfile(fileext = ".csv")
  writeLines(c("publicacion_id,vintage_id", "PUB_A , PUB_A.v2", "PUB_B,PUB_B.v1"), ruta)
  cj <- leer_conjunto(ruta)
  expect_equal(cj$vintage_id, c("PUB_A.v2", "PUB_B.v1"))
  expect_equal(cj$publicacion_id, c("PUB_A", "PUB_B"))
})

test_that("leer_conjunto falla visible ante archivo ausente, columnas malas, vacios o duplicados", {
  expect_error(leer_conjunto(tempfile()), "FALLO VISIBLE.*no existe")
  mal <- function(lineas) { r <- tempfile(fileext = ".csv"); writeLines(lineas, r); r }
  expect_error(leer_conjunto(mal(c("vintage_id,publicacion_id", "a,b"))), "columnas")
  expect_error(leer_conjunto(mal("publicacion_id,vintage_id")), "ningun vintage")
  expect_error(leer_conjunto(mal(c("publicacion_id,vintage_id", "PUB_A,"))), "vacias")
  expect_error(leer_conjunto(mal(c("publicacion_id,vintage_id", "PUB_A,x", "PUB_A,x"))), "duplicadas")
})

# --- vintage_vigente / mapa / agregar_* con conjunto --------------------------------------------

test_that("sin conjunto, vintage_vigente sigue siendo la ULTIMA fila (comportamiento de siempre)", {
  e <- escenario()
  expect_equal(vintage_vigente("PUB_A", e$vintages), "PUB_A.v2")
  expect_equal(vintage_vigente("PUB_A", e$vintages, conjunto = NULL), "PUB_A.v2")
})

test_that("con conjunto, vintage_vigente devuelve el declarado, aunque no sea el ultimo", {
  e <- escenario()
  cj <- data.frame(publicacion_id = "PUB_A", vintage_id = "PUB_A.v1", stringsAsFactors = FALSE)
  expect_equal(vintage_vigente("PUB_A", e$vintages, cj), "PUB_A.v1")
})

test_that("con conjunto, falla visible si la publicacion no esta, si el vintage es ajeno o si hay varios", {
  e <- escenario()
  sin_b <- data.frame(publicacion_id = "PUB_A", vintage_id = "PUB_A.v1", stringsAsFactors = FALSE)
  expect_error(vintage_vigente("PUB_B", e$vintages, sin_b), "no declara ningun vintage.*PUB_B")
  ajeno <- data.frame(publicacion_id = "PUB_A", vintage_id = "PUB_B.v1", stringsAsFactors = FALSE)
  expect_error(vintage_vigente("PUB_A", e$vintages, ajeno), "no son de esa publicacion")
  dos <- data.frame(publicacion_id = c("PUB_A", "PUB_A"), vintage_id = c("PUB_A.v1", "PUB_A.v2"),
                    stringsAsFactors = FALSE)
  expect_error(vintage_vigente("PUB_A", e$vintages, dos), "declara 2 vintages")
})

test_that("mapa_vintage_por_anio: con conjunto toma el vintage declarado de cada año", {
  e <- escenario()
  expect_equal(unname(mapa_vintage_por_anio(PUBLICACION_UT, e$vintages)),
               c("UT.v2020-12_recaptura", "UT.v2021-12", "UT.v2022-03"))
  original <- data.frame(publicacion_id = PUBLICACION_UT,
                         vintage_id = c("UT.v2020-12", "UT.v2021-12", "UT.v2022-03"),
                         stringsAsFactors = FALSE)
  mapa <- mapa_vintage_por_anio(PUBLICACION_UT, e$vintages, original)
  expect_equal(names(mapa), c("2020", "2021", "2022"))
  expect_equal(unname(mapa), original$vintage_id)
})

test_that("mapa_vintage_por_anio: dos vintages declarados del mismo año detienen", {
  e <- escenario()
  dos <- data.frame(publicacion_id = PUBLICACION_UT,
                    vintage_id = c("UT.v2020-12", "UT.v2020-12_recaptura"), stringsAsFactors = FALSE)
  expect_error(mapa_vintage_por_anio(PUBLICACION_UT, e$vintages, dos), "mas de un vintage para el mismo año")
})

test_that("agregar_vintage_* propagan el conjunto", {
  e <- escenario()
  cj <- data.frame(publicacion_id = c("PUB_A", "PUB_B"), vintage_id = c("PUB_A.v1", "PUB_B.v1"),
                   stringsAsFactors = FALSE)
  serie <- data.frame(periodo = c("2020-Q1", "2020-Q2"), valor = 1:2, stringsAsFactors = FALSE)
  expect_equal(agregar_vintage_constante(serie, "PUB_A", e$vintages, cj)$vintage_id, rep("PUB_A.v1", 2))
  expect_equal(agregar_vintage_constante(serie, "PUB_A", e$vintages)$vintage_id, rep("PUB_A.v2", 2))
  por_fila <- agregar_vintage_por_fila(serie, c("PUB_A", "PUB_B"), e$vintages, cj)
  expect_equal(por_fila$vintage_id, c("PUB_A.v1", "PUB_B.v1"))
  ut <- data.frame(periodo = c("2020-M05", "2021-M01"), valor = 1:2, stringsAsFactors = FALSE)
  orig <- data.frame(publicacion_id = PUBLICACION_UT, vintage_id = c("UT.v2020-12", "UT.v2021-12"),
                     stringsAsFactors = FALSE)
  expect_equal(agregar_vintage_por_anio(ut, PUBLICACION_UT, e$vintages, orig)$vintage_id,
               c("UT.v2020-12", "UT.v2021-12"))
})

# --- archivo_l0_vigente -------------------------------------------------------------------------

test_that("archivo_l0_vigente: sin conjunto es la ultima fila; con conjunto, el declarado", {
  e <- escenario()
  expect_equal(archivo_l0_vigente("PUB_A", NULL, e$vintages, e$dir_l0), file.path(e$dir_l0, "A_v2.txt"))
  cj <- data.frame(publicacion_id = "PUB_A", vintage_id = "PUB_A.v1", stringsAsFactors = FALSE)
  # verifica el sha256 contra manifiesto.csv de dir_l0: lo escribimos como lo lee el pipeline
  write.csv(e$manifiesto, file.path(e$dir_l0, "manifiesto.csv"), row.names = FALSE)
  expect_equal(archivo_l0_vigente("PUB_A", cj, e$vintages, e$dir_l0), file.path(e$dir_l0, "A_v1.txt"))
})

test_that("archivo_l0_vigente con conjunto detiene si el archivo cambio de contenido o falta", {
  e <- escenario()
  write.csv(e$manifiesto, file.path(e$dir_l0, "manifiesto.csv"), row.names = FALSE)
  cj <- data.frame(publicacion_id = "PUB_B", vintage_id = "PUB_B.v1", stringsAsFactors = FALSE)
  writeLines("alterado", file.path(e$dir_l0, "B_v1.txt"))
  expect_error(archivo_l0_vigente("PUB_B", cj, e$vintages, e$dir_l0), "sha256.*no coincide")
  file.remove(file.path(e$dir_l0, "B_v1.txt"))
  expect_error(archivo_l0_vigente("PUB_B", cj, e$vintages, e$dir_l0), "no está")
})

# --- validar_conjunto ---------------------------------------------------------------------------

validar <- function(e, cj, necesarias = NECESARIAS)
  validar_conjunto(cj, e$vintages, e$manifiesto, e$dir_l0, necesarias)

test_that("validar_conjunto acepta un conjunto completo (incluida UT con un vintage por año)", {
  e <- escenario()
  r <- validar(e, conjunto_ok())
  expect_equal(r$sobrantes, character(0))
})

test_that("validar_conjunto permite sobrantes y los informa, sujetos a las mismas guardas", {
  e <- escenario()
  r <- validar(e, conjunto_ok(), necesarias = c("PUB_B", PUBLICACION_UT))
  expect_equal(r$sobrantes, "PUB_A")
  e2 <- escenario()
  writeLines("alterado", file.path(e2$dir_l0, "A_v2.txt"))
  expect_error(validar(e2, conjunto_ok(), necesarias = c("PUB_B", PUBLICACION_UT)), "sha256.*no coincide")
})

test_that("validar_conjunto detiene: vintage inexistente, ajeno, faltante, varios o sha256 distinto", {
  e <- escenario()
  cj <- conjunto_ok()
  inex <- cj; inex$vintage_id[1] <- "PUB_A.v9"
  expect_error(validar(e, inex), "no existen en catalogos/08_vintages.csv.*PUB_A.v9")
  ajeno <- cj; ajeno$vintage_id[1] <- "PUB_B.v1"
  expect_error(validar(e, ajeno), "no pertenecen a la publicacion declarada")
  expect_error(validar(e, cj[cj$publicacion_id != "PUB_B", ]), "necesita: PUB_B")
  dos <- rbind(cj, data.frame(publicacion_id = "PUB_A", vintage_id = "PUB_A.v1"))
  expect_error(validar(e, dos), "declara 2 vintages para 'PUB_A'")
  mismo_anio <- rbind(cj, data.frame(publicacion_id = PUBLICACION_UT, vintage_id = "UT.v2020-12"))
  expect_error(validar(e, mismo_anio), "mas de un vintage para el mismo año")
  writeLines("alterado", file.path(e$dir_l0, "B_v1.txt"))
  expect_error(validar(e, cj), "sha256.*no coincide")
})

test_that("validar_conjunto detiene si el archivo del vintage no esta en L0", {
  e <- escenario()
  file.remove(file.path(e$dir_l0, "A_v2.txt"))
  expect_error(validar(e, conjunto_ok()), "no está")
})

test_that("validar_conjunto detiene si el manifiesto y el catalogo discrepan", {
  e <- escenario()
  e$manifiesto$archivo[e$manifiesto$vintage_id == "PUB_B.v1"] <- "otro.txt"
  expect_error(validar(e, conjunto_ok()), "no concuerda entre 08_vintages.csv")
})

# --- construir_serie_ut con conjunto (la no-regresion sintetica) --------------------------------

test_that("un conjunto armado con los vintages vigentes reproduce la serie de UT por defecto", {
  e <- escenario()
  por_defecto <- construir_serie_ut(e$vintages, e$manifiesto, e$dir_l0)
  con_conjunto <- construir_serie_ut(e$vintages, e$manifiesto, e$dir_l0,
                                     conjunto = conjunto_ok()[conjunto_ok()$publicacion_id == PUBLICACION_UT, ])
  expect_identical(con_conjunto, por_defecto)
})

test_that("un conjunto con el vintage original de 2020 (no la recaptura) cambia solo ese año", {
  e <- escenario()
  por_defecto <- construir_serie_ut(e$vintages, e$manifiesto, e$dir_l0)
  original <- data.frame(publicacion_id = PUBLICACION_UT,
                         vintage_id = c("UT.v2020-12", "UT.v2021-12", "UT.v2022-03"),
                         stringsAsFactors = FALSE)
  distinta <- construir_serie_ut(e$vintages, e$manifiesto, e$dir_l0, conjunto = original)
  expect_equal(distinta$gwh[distinta$anio != 2020], por_defecto$gwh[por_defecto$anio != 2020])
  expect_false(isTRUE(all.equal(distinta$gwh[distinta$anio == 2020], por_defecto$gwh[por_defecto$anio == 2020])))
})

test_that("con conjunto, el año maximo es el del conjunto: un conjunto que corta en 2021 es valido", {
  e <- escenario()
  corte <- data.frame(publicacion_id = PUBLICACION_UT, vintage_id = c("UT.v2020-12", "UT.v2021-12"),
                      stringsAsFactors = FALSE)
  serie <- construir_serie_ut(e$vintages, e$manifiesto, e$dir_l0, conjunto = corte)
  expect_equal(range(serie$anio), c(2020L, 2021L))
  expect_equal(nrow(serie), 24L)
})

test_that("con conjunto, construir_serie_ut verifica el sha256 del archivo al usarlo", {
  e <- escenario()
  writeLines("alterado", file.path(e$dir_l0, "UT_2021.csv"))
  expect_error(construir_serie_ut(e$vintages, e$manifiesto, e$dir_l0,
                                  conjunto = conjunto_ok()[conjunto_ok()$publicacion_id == PUBLICACION_UT, ]),
               "sha256.*no coincide")
})

# --- ruta_capa / SALIDA -------------------------------------------------------------------------

con_env <- function(conjunto, salida, expr) {
  ant <- Sys.getenv(c("SIE_CONJUNTO", "SIE_SALIDA"), unset = NA)
  on.exit({
    for (n in names(ant)) if (is.na(ant[[n]])) Sys.unsetenv(n) else do.call(Sys.setenv, setNames(list(ant[[n]]), n))
  })
  Sys.setenv(SIE_CONJUNTO = conjunto, SIE_SALIDA = salida)
  force(expr)
}

test_that("sin variables, ruta_capa y conjunto_activo se comportan como siempre", {
  con_env("", "", {
    expect_null(conjunto_activo())
    expect_equal(ruta_capa("L1_staging", "x.csv"), here::here("data", "L1_staging", "x.csv"))
    expect_equal(ruta_capa("L3_master"), here::here("data", "L3_master"))
  })
})

test_that("con conjunto y salida, ruta_capa escribe bajo SALIDA/<capa>", {
  salida <- file.path(tempdir(), "mi_salida")
  ruta <- tempfile(fileext = ".csv"); writeLines(c("publicacion_id,vintage_id", "PUB_A,PUB_A.v1"), ruta)
  con_env(ruta, salida, {
    expect_equal(conjunto_activo()$vintage_id, "PUB_A.v1")
    esperado <- file.path(normalizePath(salida, winslash = "/", mustWork = FALSE), "L2_validated", "r.html")
    expect_equal(ruta_capa("L2_validated", "r.html"), esperado)
  })
})

test_that("CONJUNTO y SALIDA se exigen juntas", {
  ruta <- tempfile(fileext = ".csv"); writeLines(c("publicacion_id,vintage_id", "PUB_A,PUB_A.v1"), ruta)
  con_env(ruta, "", {
    expect_error(conjunto_activo(), "sin SIE_SALIDA")
    expect_error(ruta_capa("L1_staging"), "sin SIE_SALIDA")
  })
  con_env("", file.path(tempdir(), "s"), {
    expect_error(conjunto_activo(), "sin SIE_CONJUNTO")
    expect_error(ruta_capa("L1_staging"), "sin SIE_CONJUNTO")
  })
})

test_that("SALIDA no puede caer en una capa vigente ni ser data/ mismo", {
  raiz <- here::here()
  for (mala in c("data", "data/L0_raw", "data/L1_staging", "data/L1_staging/sub", "data/L2_validated",
                 "data/L3_master", "data/L4_experiments/x", "DATA/l3_master")) {
    expect_error(validar_salida(file.path(raiz, mala), raiz), "capa vigente", info = mala)
  }
  expect_silent(validar_salida(file.path(raiz, "data", "conjuntos", "corte_1"), raiz))
  expect_silent(validar_salida(file.path(tempdir(), "fuera"), raiz))
})

# --- Cobertura contra el repo real (solo lectura de texto) --------------------------------------

test_that("PUBLICACIONES_POR_ANIO coincide con la publicacion por año de UT", {
  expect_equal(PUBLICACIONES_POR_ANIO, PUBLICACION_UT)
})

test_that("cada publicacion de 03_series.csv aparece en algun extractor de L1", {
  series <- read.csv(here::here("catalogos", "03_series.csv"), stringsAsFactors = FALSE, na.strings = "")
  necesarias <- publicaciones_necesarias(series)
  fuentes <- c(list.files(here::here("src", "transformacion"), pattern = "^extraer_.*\\.R$", full.names = TRUE),
               here::here("src", "transformacion", "ut_demanda_lib.R"))
  texto <- paste(unlist(lapply(fuentes, readLines, warn = FALSE)), collapse = "\n")
  sin_extractor <- necesarias[!vapply(necesarias, function(p) grepl(p, texto, fixed = TRUE), logical(1))]
  expect_equal(sin_extractor, character(0))
})

test_that("los extractores seleccionan su archivo de L0 solo con archivo_l0_vigente()", {
  extractores <- list.files(here::here("src", "transformacion"), pattern = "^extraer_.*\\.R$", full.names = TRUE)
  expect_equal(length(extractores), 8L)
  for (f in extractores) {
    txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
    expect_true(grepl("archivo_l0_vigente(", txt, fixed = TRUE), info = basename(f))
    expect_false(grepl("archivo_raw[nrow(", txt, fixed = TRUE), info = basename(f))
    expect_false(grepl("08_vintages.csv\", stringsAsFactors", txt, fixed = TRUE), info = basename(f))
  }
})

test_that("make master valida el conjunto antes de escribir nada", {
  mk <- readLines(here::here("Makefile"), warn = FALSE)
  i <- grep("^master:", mk)
  expect_equal(trimws(mk[i + 1]), "Rscript src/transformacion/validar_conjunto.R")
})
