# tests/test-tablas-informe-fase6.R
#
# Tablas del informe de Fase 6 (checklist F2), con un L4 SINTÉTICO en un directorio temporal: no se lee data/.
# Comprueba que la unión por grupo copia el texto tal cual con `grupo` delante, y que el script falla si falta un
# archivo, sobra uno, un sha256 no coincide, o un manifiesto no es de árbol limpio o de otro corte.

library(testthat)
source(here::here("src", "proyeccion", "tablas_informe_fase6.R"))

.l4_sintetico <- function(corte = "abc123") {
  d <- tempfile("l4_"); dir.create(d)
  esc <- function(rel, lin) { r <- file.path(d, rel); dir.create(dirname(r), showWarnings = FALSE, recursive = TRUE)
                              con <- file(r, open = "wb"); writeLines(lin, con, sep = "\n"); close(con) }
  for (g in GRUPOS_F6) {
    for (t in setdiff(TABLAS_GRUPO_F6, "coherencia_deflactor"))
      esc(file.path(paste0("F6_", g), paste0(t, ".csv")), c("\"x\",\"y\"", sprintf("\"%s\",1.23456789012345", g)))
    esc(file.path(paste0("F6_", g), "manifiesto.txt"), c("arbol: limpio", paste0("conjunto: c.csv  sha256 sin CR ", corte)))
  }
  esc(file.path("F6_G3", "coherencia_deflactor.csv"), c("\"h\"", "1"))
  for (t in TABLAS_COMUN_F6) esc(file.path("F6_COMUN", paste0(t, ".csv")), c("\"v\"", "7"))
  esc(file.path("F6_COMUN", "manifiesto.txt"), c("arbol: limpio", paste0("conjunto: c.csv  sha256 sin CR ", corte)))
  arch <- unlist(lapply(c(paste0("F6_", GRUPOS_F6), "F6_COMUN"), function(x) file.path(x, list.files(file.path(d, x), pattern = "\\.csv$"))))
  ref <- data.frame(archivo = arch, sha256 = vapply(arch, function(a) digest::digest(file = file.path(d, a), algo = "sha256"), character(1)))
  sha <- tempfile(fileext = ".csv"); utils::write.csv(ref, sha, row.names = FALSE)
  list(dir = d, sha = sha, ref = ref)
}

test_that("F2: une los grupos con el texto tal cual y copia F6_COMUN sin cambios", {
  s <- .l4_sintetico(); out <- tempfile("rep_")
  escritos <- escribir_tablas_fase6(s$dir, out, s$sha, corte_sha256 = "abc123")
  expect_length(escritos, length(TABLAS_GRUPO_F6) + length(TABLAS_COMUN_F6))
  a <- readLines(file.path(out, "proyeccion_anual_fase6.csv"))
  expect_identical(a, c("\"grupo\",\"x\",\"y\"", "\"G1\",\"G1\",1.23456789012345", "\"G2\",\"G2\",1.23456789012345",
                        "\"G3\",\"G3\",1.23456789012345"))
  expect_identical(readLines(file.path(out, "coherencia_deflactor_fase6.csv")), c("\"grupo\",\"h\"", "\"G3\",1"))
  expect_identical(readLines(file.path(out, "satelites_fase6.csv")), c("\"v\"", "7"))
  expect_false(any(grepl("\r", readChar(file.path(out, "proyeccion_trimestral_fase6.csv"), 1e4), fixed = TRUE)))
})

test_that("F2: falla si un sha256 no coincide, falta un archivo o sobra uno", {
  s <- .l4_sintetico(); out <- tempfile("rep_")
  cat("1\n", file = file.path(s$dir, "F6_G2", "anual.csv"), append = TRUE)
  expect_error(escribir_tablas_fase6(s$dir, out, s$sha), "sha256 distinto.*F6_G2/anual.csv")
  s <- .l4_sintetico(); file.remove(file.path(s$dir, "F6_G1", "guarda.csv"))
  expect_error(escribir_tablas_fase6(s$dir, out, s$sha), "faltan en L4: F6_G1/guarda.csv")
  s <- .l4_sintetico(); writeLines("\"z\"", file.path(s$dir, "F6_G1", "extra.csv"))
  expect_error(escribir_tablas_fase6(s$dir, out, s$sha), "sin sha256 de referencia: F6_G1/extra.csv")
})

test_that("F2: falla si un manifiesto no es de árbol limpio o es de otro corte", {
  s <- .l4_sintetico(); out <- tempfile("rep_")
  expect_error(escribir_tablas_fase6(s$dir, out, s$sha, corte_sha256 = "otro"), "no es el del preregistro")
  writeLines(c("arbol: sucio", "sha256 sin CR abc123"), file.path(s$dir, "F6_G1", "manifiesto.txt"))
  expect_error(escribir_tablas_fase6(s$dir, out, s$sha, corte_sha256 = "abc123"), "F6_G1 no viene de un árbol limpio")
})
