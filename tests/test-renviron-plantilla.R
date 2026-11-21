# Guarda de la plantilla de .Renviron (Fase 7, F7-05; pedido de Harold durante el ensayo del
# 2026-T2). Toda variable SIE_* o FRED_* que lea el codigo con Sys.getenv() tiene que estar
# documentada en .Renviron.example, como variable a completar o en el bloque «NUNCA aqui».
# Ademas, la plantilla no puede asignar SIE_CONJUNTO ni SIE_SALIDA: definidas en .Renviron, harian
# que make master construyera un corte congelado en vez de la L3 vigente.

.leer_texto <- function(ruta) paste(readLines(ruta, encoding = "UTF-8", warn = FALSE), collapse = "\n")

test_that(".Renviron.example documenta toda variable SIE_* o FRED_* que lee el codigo", {
  archivos <- c(
    list.files(here::here("src"), pattern = "\\.R$", recursive = TRUE, full.names = TRUE),
    list.files(here::here("scripts"), pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  )
  expect_gt(length(archivos), 0L)
  patron <- "Sys\\.getenv\\(\\s*[\"']((SIE|FRED)_[A-Z0-9_]+)[\"']"
  usadas <- unique(unlist(lapply(archivos, function(a) {
    m <- regmatches(.leer_texto(a), gregexpr(patron, .leer_texto(a), perl = TRUE))[[1]]
    sub(patron, "\\1", m, perl = TRUE)
  })))
  expect_true(all(c("FRED_API_KEY", "SIE_L0_STORE") %in% usadas),
              info = "la busqueda de Sys.getenv() dejo de encontrar las variables conocidas")

  plantilla <- .leer_texto(here::here(".Renviron.example"))
  faltan <- usadas[!vapply(usadas, function(v) grepl(v, plantilla, fixed = TRUE), logical(1))]
  expect_identical(faltan, character(0),
                   info = paste("variables leidas por el codigo y ausentes de .Renviron.example:",
                                paste(faltan, collapse = ", ")))
})

test_that(".Renviron.example no asigna SIE_CONJUNTO ni SIE_SALIDA", {
  lineas <- readLines(here::here(".Renviron.example"), encoding = "UTF-8", warn = FALSE)
  asignadas <- sub("=.*$", "", grep("^[A-Za-z_][A-Za-z0-9_]*=", lineas, value = TRUE))
  expect_false(any(c("SIE_CONJUNTO", "SIE_SALIDA") %in% asignadas))
})
