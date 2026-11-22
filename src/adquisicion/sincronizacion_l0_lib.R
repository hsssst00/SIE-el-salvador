# sincronizacion_l0_lib.R
#
# Sincronizacion entre data/L0_raw/ y el almacen privado de L0 (repo SIE-el-salvador-L0), en las dos
# direcciones. Ficha F7-14 de doc/metodologia/decisiones_fase7.md. La usa scripts/sincronizar_l0.R
# (`make sincronizar-l0`); separada para que tests/test-sincronizacion-l0.R la ejerza.
#
# Reglas: el manifiesto manda; nunca se sobrescribe un archivo en ningun lado; todo archivo que se
# copia se verifica contra su sha256 del manifiesto antes y despues; un mismo nombre con distinto
# contenido en los dos lados detiene todo (regla 6: fallo visible).

.fallar_sync <- function(...) stop("FALLO VISIBLE [sincronizar-l0]: ", ..., call. = FALSE)

sha256_archivo <- function(ruta) {
  if (!file.exists(ruta)) return(NA_character_)
  digest::digest(file = ruta, algo = "sha256")
}

#' Plan por fila del manifiesto. `sha_l0` y `sha_almacen`: sha256 de cada archivo en cada lado (NA si
#' falta). Accion: OK (en los dos, iguales al manifiesto), SUBIR (solo en L0), BAJAR (solo en el
#' almacen), FALTA (en ningun lado) o CONFLICTO (algun lado difiere del manifiesto).
plan_sincronizacion <- function(manifiesto, sha_l0, sha_almacen) {
  esperado <- manifiesto$sha256
  accion <- ifelse(is.na(sha_l0) & is.na(sha_almacen), "FALTA",
            ifelse(!is.na(sha_l0) & sha_l0 != esperado, "CONFLICTO",
            ifelse(!is.na(sha_almacen) & sha_almacen != esperado, "CONFLICTO",
            ifelse(is.na(sha_almacen), "SUBIR",
            ifelse(is.na(sha_l0), "BAJAR", "OK")))))
  data.frame(archivo = manifiesto$archivo, vintage_id = manifiesto$vintage_id, accion = accion,
             stringsAsFactors = FALSE)
}

.git <- function(almacen, ...) {
  out <- suppressWarnings(system2("git", c("-C", shQuote(almacen), ...), stdout = TRUE, stderr = TRUE))
  st <- attr(out, "status"); if (is.null(st)) st <- 0L
  list(status = st, salida = out)
}

#' Sincroniza. Devuelve (invisible) el plan con la accion de cada fila.
sincronizar_l0 <- function(almacen = Sys.getenv("SIE_L0_STORE", unset = ""),
                           ruta_manifiesto = "data/L0_raw/manifiesto.csv",
                           dir_l0 = "data/L0_raw", push = TRUE) {
  if (!nzchar(almacen)) {
    .fallar_sync("SIE_L0_STORE no esta definida. Debe apuntar a tu clon del repo privado de L0 ",
                 "(ver .Renviron.example).")
  }
  if (!dir.exists(almacen)) .fallar_sync("SIE_L0_STORE apunta a '", almacen, "', que no existe.")
  if (!file.exists(ruta_manifiesto)) .fallar_sync("no existe ", ruta_manifiesto, ": correr desde la raiz del repo.")
  if (.git(almacen, "rev-parse", "--is-inside-work-tree")$status != 0L) {
    .fallar_sync("'", almacen, "' no es un clon de git del almacen.")
  }

  # 1. Almacen limpio y al dia con su remoto (solo avance rapido).
  st <- .git(almacen, "status", "--porcelain")
  if (st$status != 0L || length(st$salida) > 0) {
    .fallar_sync("el almacen tiene cambios sin commit:\n  ", paste(st$salida, collapse = "\n  "))
  }
  pl <- .git(almacen, "pull", "--ff-only", "--quiet")
  if (pl$status != 0L) {
    .fallar_sync("git pull --ff-only del almacen fallo (sin red, o el almacen diverge de su remoto):\n  ",
                 paste(pl$salida, collapse = "\n  "))
  }

  # 2. Plan, verificado contra el manifiesto.
  manifiesto <- utils::read.csv(ruta_manifiesto, stringsAsFactors = FALSE, colClasses = "character",
                                fileEncoding = "UTF-8")
  sha_l0 <- vapply(file.path(dir_l0, manifiesto$archivo), sha256_archivo, character(1), USE.NAMES = FALSE)
  sha_al <- vapply(file.path(almacen, manifiesto$archivo), sha256_archivo, character(1), USE.NAMES = FALSE)
  plan <- plan_sincronizacion(manifiesto, sha_l0, sha_al)
  for (a in c("CONFLICTO", "FALTA")) {
    x <- plan[plan$accion == a, ]
    if (nrow(x) > 0) {
      .fallar_sync(nrow(x), " archivo(s) en ", a,
                   if (a == "CONFLICTO") " (el contenido no coincide con el sha256 del manifiesto)" else
                     " (no estan ni en data/L0_raw/ ni en el almacen)",
                   ": ", paste(x$archivo, collapse = ", "), ". No se copio nada.")
    }
  }

  # 3. Copias, sin sobrescribir, verificadas despues de copiar.
  copiar <- function(de, a, archivos) {
    for (f in archivos) {
      destino <- file.path(a, f)
      if (file.exists(destino)) .fallar_sync("'", destino, "' aparecio durante la sincronizacion; no se sobrescribe.")
      if (!file.copy(file.path(de, f), destino, overwrite = FALSE, copy.date = TRUE)) {
        .fallar_sync("no se pudo copiar ", f, " a ", a)
      }
      if (!identical(sha256_archivo(destino), manifiesto$sha256[manifiesto$archivo == f])) {
        .fallar_sync("la copia de ", f, " en ", a, " no coincide con el manifiesto.")
      }
    }
  }
  bajar <- plan$archivo[plan$accion == "BAJAR"]
  subir <- plan$archivo[plan$accion == "SUBIR"]
  copiar(almacen, dir_l0, bajar)
  copiar(dir_l0, almacen, subir)

  # 4. Commit y push en el almacen de lo subido.
  if (length(subir) > 0) {
    ad <- .git(almacen, "add", "--", shQuote(subir))
    if (ad$status != 0L) .fallar_sync("git add en el almacen fallo:\n  ", paste(ad$salida, collapse = "\n  "))
    vids <- plan$vintage_id[plan$accion == "SUBIR"]
    msj <- paste0("L0: ", length(subir), " archivo(s) desde el manifiesto del SIE (", paste(vids, collapse = ", "), ")")
    cm <- .git(almacen, "commit", "--quiet", "-m", shQuote(msj))
    if (cm$status != 0L) .fallar_sync("git commit en el almacen fallo:\n  ", paste(cm$salida, collapse = "\n  "))
  }

  # 4b. Commits del almacen que su remoto no tiene: los de este commit y los que quedaron de una corrida
  # anterior cuyo push fallo (2026-11-22: una segunda corrida decia OK con un commit sin subir).
  rl <- .git(almacen, "rev-list", "--count", shQuote("@{u}..HEAD"))
  pendientes <- suppressWarnings(as.integer(rl$salida[1]))
  if (rl$status != 0L || is.na(pendientes)) {
    .fallar_sync("no se pudo contar los commits del almacen sin subir (la rama no sigue a su remoto?):\n  ",
                 paste(rl$salida, collapse = "\n  "))
  }
  if (pendientes > 0L) {
    if (push) {
      ps <- .git(almacen, "push", "--quiet")
      if (ps$status != 0L) {
        .fallar_sync("git push del almacen fallo; ", pendientes, " commit(s) quedaron solo en esta maquina. ",
                     "Reintentar con git push en ", almacen, ":\n  ", paste(ps$salida, collapse = "\n  "))
      }
    } else {
      message("AVISO: el almacen tiene ", pendientes, " commit(s) sin subir a su remoto (push = FALSE).")
    }
  }

  # 5. Aviso no fatal: archivos del almacen sin fila en el manifiesto.
  huerfanos <- setdiff(list.files(almacen, recursive = FALSE),
                       c(manifiesto$archivo, "manifiesto.csv", "README.md", ".git", ".gitignore",
                         ".gitkeep", "resguardo"))
  if (length(huerfanos) > 0) {
    message("AVISO: ", length(huerfanos), " archivo(s) en el almacen sin fila en el manifiesto: ",
            paste(huerfanos, collapse = ", "))
  }
  hc <- .git(almacen, "rev-parse", "--short", "HEAD")$salida
  message(sprintf("OK sincronizar-l0: %d en los dos lados, %d bajado(s) del almacen, %d subido(s) al almacen, %d commit(s) empujado(s) al remoto. Almacen en %s.",
                  sum(plan$accion == "OK"), length(bajar), length(subir), if (push) pendientes else 0L, hc))
  invisible(plan)
}
