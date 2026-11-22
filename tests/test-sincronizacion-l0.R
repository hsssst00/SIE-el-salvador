# tests/test-sincronizacion-l0.R
#
# Pruebas de la sincronizacion entre data/L0_raw/ y el almacen de L0 (src/adquisicion/sincronizacion_l0_lib.R;
# F7-14). El plan se prueba sin git; el flujo completo, con un almacen y su remoto falsos en tempdir().

library(testthat)
source(here::here("src", "adquisicion", "sincronizacion_l0_lib.R"))

.man <- data.frame(archivo = c("a.csv", "b.csv", "c.csv"), vintage_id = c("A.v1", "B.v1", "C.v1"),
                   sha256 = c("ha", "hb", "hc"), stringsAsFactors = FALSE)

test_that("plan_sincronizacion: OK, SUBIR, BAJAR, FALTA y CONFLICTO", {
  p <- plan_sincronizacion(.man, sha_l0 = c("ha", "hb", NA), sha_almacen = c("ha", NA, "hc"))
  expect_equal(p$accion, c("OK", "SUBIR", "BAJAR"))
  p2 <- plan_sincronizacion(.man, sha_l0 = c(NA, "xx", "hc"), sha_almacen = c(NA, "hb", "zz"))
  expect_equal(p2$accion, c("FALTA", "CONFLICTO", "CONFLICTO"))
})

.sys <- function(...) {
  out <- suppressWarnings(system2("git", c(...), stdout = TRUE, stderr = TRUE))
  st <- attr(out, "status"); if (!is.null(st) && st != 0L) stop(paste(out, collapse = "\n"))
  out
}

test_that("sincronizar_l0: baja, sube con commit y push, es idempotente y se detiene ante conflicto o cambios", {
  skip_if(!nzchar(Sys.which("git")), "git no disponible")
  raiz <- file.path(tempdir(), paste0("sync_", as.integer(stats::runif(1, 1, 1e8))))
  almacen <- file.path(raiz, "almacen"); remoto <- file.path(raiz, "remoto.git"); l0 <- file.path(raiz, "L0_raw")
  dir.create(almacen, recursive = TRUE); dir.create(l0)
  writeLines("dato a", file.path(almacen, "a.csv"))
  writeLines("dato b", file.path(l0, "b.csv"))
  man <- data.frame(archivo = c("a.csv", "b.csv"), vintage_id = c("A.v1", "B.v1"),
                    sha256 = c(sha256_archivo(file.path(almacen, "a.csv")), sha256_archivo(file.path(l0, "b.csv"))),
                    stringsAsFactors = FALSE)
  ruta_man <- file.path(raiz, "manifiesto.csv"); utils::write.csv(man, ruta_man, row.names = FALSE)

  .sys("-C", almacen, "init", "--quiet")
  .sys("-C", almacen, "config", "user.name", "prueba"); .sys("-C", almacen, "config", "user.email", "prueba@ejemplo")
  .sys("-C", almacen, "add", "a.csv"); .sys("-C", almacen, "commit", "--quiet", "-m", "inicial")
  .sys("clone", "--quiet", "--bare", almacen, remoto)
  rama <- .sys("-C", almacen, "rev-parse", "--abbrev-ref", "HEAD")
  .sys("-C", almacen, "remote", "add", "origin", remoto); .sys("-C", almacen, "fetch", "--quiet", "origin")
  .sys("-C", almacen, "branch", "--quiet", paste0("--set-upstream-to=origin/", rama))

  p <- sincronizar_l0(almacen, ruta_man, l0)
  expect_equal(p$accion, c("BAJAR", "SUBIR"))
  expect_true(file.exists(file.path(l0, "a.csv")))
  expect_true(file.exists(file.path(almacen, "b.csv")))
  ult <- .sys("--git-dir", remoto, "log", "-1", "--format=%s", rama)
  expect_match(ult, "L0: 1 archivo\\(s\\) desde el manifiesto del SIE \\(B.v1\\)")

  p2 <- sincronizar_l0(almacen, ruta_man, l0)   # idempotente: nada que copiar, ningun commit nuevo
  expect_equal(p2$accion, c("OK", "OK"))
  expect_identical(.sys("--git-dir", remoto, "log", "-1", "--format=%s", rama), ult)

  # Un commit que quedo sin subir (push fallido en una corrida anterior) se sube en la siguiente.
  writeLines("nota", file.path(almacen, "README.md"))
  .sys("-C", almacen, "add", "README.md"); .sys("-C", almacen, "commit", "--quiet", "-m", "pendiente sin push")
  expect_false(identical(.sys("--git-dir", remoto, "rev-parse", rama), .sys("-C", almacen, "rev-parse", "HEAD")))
  p3 <- sincronizar_l0(almacen, ruta_man, l0)
  expect_equal(p3$accion, c("OK", "OK"))
  expect_identical(.sys("--git-dir", remoto, "rev-parse", rama), .sys("-C", almacen, "rev-parse", "HEAD"))

  writeLines("dato b alterado", file.path(l0, "b.csv"))
  expect_error(sincronizar_l0(almacen, ruta_man, l0), "CONFLICTO")
  writeLines("dato b", file.path(l0, "b.csv"))

  writeLines("basura", file.path(almacen, "sin_commit.txt"))
  expect_error(sincronizar_l0(almacen, ruta_man, l0), "cambios sin commit")
  unlink(raiz, recursive = TRUE)
})

test_that("sincronizar_l0 exige SIE_L0_STORE", {
  expect_error(sincronizar_l0(almacen = ""), "SIE_L0_STORE no esta definida")
})
