# scripts/auditoria_mecanica.R
#
# Factsheet de orientación pre-auditoría. Produce en ~3 segundos un resumen
# cuantitativo del estado del repositorio: conteos de catálogo, integridad
# referencial, estado de L0, ADR, auditorías, claves canónicas y licencias.
#
# NO es validación. No llama stop() ni warning(): los tests en tests/ y
# check_l0_integrity.R son los que detienen el pipeline. Este script reporta
# para que un auditor recalcule de forma independiente y oriente su inspección.
# Cualquier "ATENCION" en la salida es una señal de que algo vale la pena mirar;
# no es un error confirmado.
#
# Uso:
#   Rscript scripts/auditoria_mecanica.R
#   make audit
#
# Dependencias: here, jsonlite (ambas declaradas en DESCRIPTION).
# No requiere los .xlsx (en .gitignore por ADR-008): sólo lee texto.

suppressPackageStartupMessages({
  library(here)
  library(jsonlite)
})

t0 <- proc.time()

# ── helpers ────────────────────────────────────────────────────────────────────

h_sep <- function(titulo) cat("\n> ", toupper(titulo), "\n", sep = "")

h_fila <- function(etiqueta, valor, nota = "") {
  nota_str <- if (nzchar(nota)) paste0("  [", nota, "]") else ""
  cat(sprintf("  %-42s %s%s\n", etiqueta, valor, nota_str))
}

h_ok <- function(cond) if (cond) "OK" else "ATENCION"

stems <- function(subdir) {
  ff <- list.files(here("catalogos", subdir), pattern = "\\.yaml$")
  sub("\\.yaml$", "", ff[!startsWith(ff, "_")])
}

leer_csv <- function(nombre) {
  read.csv(here("catalogos", nombre),
           stringsAsFactors = FALSE, colClasses = "character",
           check.names = FALSE)
}

multi <- function(v) {
  v <- trimws(v)
  if (!nzchar(v)) return(character(0))
  trimws(strsplit(v, ",", fixed = TRUE)[[1]])
}

yaml_scalar <- function(ruta, clave) {
  lineas <- readLines(ruta, encoding = "UTF-8", warn = FALSE)
  hit    <- grep(paste0("^", clave, ":"), lineas, value = TRUE)
  if (!length(hit)) return(NA_character_)
  val <- sub(paste0("^", clave, ":\\s*"), "", hit[[1]])
  trimws(gsub("^['\"]|['\"]$", "", trimws(val)))
}

contar_resueltos <- function(vals, universo) {
  vals <- trimws(vals[nzchar(trimws(vals))])
  sum(vals %in% universo)
}

# ── HEAD git (opcional) ────────────────────────────────────────────────────────
git_head <- tryCatch({
  h <- trimws(system2("git", c("rev-parse", "--short", "HEAD"),
                      stdout = TRUE, stderr = FALSE))
  if (length(h) && nzchar(h[1])) h[1] else "?"
}, error = function(e) "?", warning = function(w) "?")

# ── cabecera ───────────────────────────────────────────────────────────────────
cat(strrep("-", 66), "\n")
cat(sprintf("  FACTSHEET  SIE El Salvador  |  %s\n",
            format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat(sprintf("  HEAD: %-12s |  scripts/auditoria_mecanica.R\n", git_head))
cat(strrep("-", 66), "\n")

# ── 1. Leer todos los catálogos (una sola vez) ─────────────────────────────────
pubs_stems <- stems("01_publicaciones")
mets_stems <- stems("02_metodologias")

csvs <- c("00_instituciones.csv", "03_series.csv", "04_transformaciones.csv",
          "05_series_master.csv", "07_experimentos.csv",
          "08_vintages.csv", "09_rupturas.csv")

datos <- lapply(setNames(csvs, csvs), leer_csv)

series    <- datos[["03_series.csv"]]
transf    <- datos[["04_transformaciones.csv"]]
master    <- datos[["05_series_master.csv"]]
vintages  <- datos[["08_vintages.csv"]]
rupturas  <- datos[["09_rupturas.csv"]]
inst_ids  <- datos[["00_instituciones.csv"]]$institucion_id
serie_ids <- series$serie_id
transf_ids<- transf$transf_id

# ── 2. Conteos de catálogo ─────────────────────────────────────────────────────
h_sep("catalogos")

h_fila("01_publicaciones/",
       sprintf("%d YAML  (+ _plantilla excluida)", length(pubs_stems)))
h_fila("02_metodologias/",
       sprintf("%d YAML  (+ _plantilla excluida)", length(mets_stems)))

for (nm in csvs) {
  n    <- nrow(datos[[nm]])
  nota <- if (nm == "07_experimentos.csv" && n == 0)
            "0 filas — esperado hasta Fase 5" else ""
  h_fila(nm, sprintf("%d filas de datos", n), nota)
}

# ── 3. Columnas vs datapackage.json ────────────────────────────────────────────
h_sep("columnas vs esquema  (datapackage.json)")

dp <- jsonlite::fromJSON(here("catalogos", "datapackage.json"),
                         simplifyVector = FALSE)
for (res in dp[["resources"]]) {
  path <- res[["path"]]
  if (!path %in% csvs) next
  esperadas <- vapply(res[["schema"]][["fields"]], `[[`, character(1), "name")
  reales    <- colnames(datos[[path]])
  ok        <- identical(reales, esperadas)
  estado    <- if (!is.null(res[["estado_esquema"]])) res[["estado_esquema"]] else "?"
  estado_c  <- if (nchar(estado) > 20) substr(estado, 1, 20) else estado
  h_fila(sprintf("%s  [%s]", path, estado_c),
         sprintf("columnas: %s", h_ok(ok)),
         if (!ok) paste("DIFERENCIA — esperadas:",
                        paste(esperadas, collapse = ", ")) else "")
}

# ── 4. Integridad referencial — resumen cuantitativo ──────────────────────────
# Pass/fail lo da tests/test-integridad-referencial.R.
# Aquí se muestran los conteos para que un auditor los recalcule.
h_sep("integridad referencial  (N/N = todos resuelven)")

n_ser     <- nrow(series)
ok_sp     <- contar_resueltos(series$publicacion_id, pubs_stems)
h_fila("03_series -> 01_publicaciones",
       sprintf("%d / %d", ok_sp, n_ser), h_ok(ok_sp == n_ser))

met_llenas <- series$metodologia_id[nzchar(trimws(series$metodologia_id))]
ok_sm_m    <- contar_resueltos(met_llenas, mets_stems)
h_fila("03_series -> 02_metodologias  (vacios OK)",
       sprintf("%d / %d con valor  (%d vacios permitidos)",
               ok_sm_m, length(met_llenas), n_ser - length(met_llenas)))

n_v   <- nrow(vintages)
ok_vp <- contar_resueltos(vintages$publicacion_id, pubs_stems)
h_fila("08_vintages -> 01_publicaciones",
       sprintf("%d / %d", ok_vp, n_v), h_ok(ok_vp == n_v))

tok_insumo <- unlist(lapply(master$series_insumo_ids, multi))
ok_tok     <- sum(tok_insumo %in% serie_ids)
h_fila("05_master.series_insumo_ids -> 03_series",
       sprintf("%d / %d tokens", ok_tok, length(tok_insumo)),
       h_ok(ok_tok == length(tok_insumo)))

tok_r_ok <- tok_r_total <- 0L
for (i in seq_len(nrow(rupturas))) {
  tr    <- trimws(rupturas$tipo_referencia[i])
  univ  <- switch(tr,
    "serie_id"       = serie_ids,
    "publicacion_id" = pubs_stems,
    character(0))
  toks         <- multi(rupturas$series_afectadas[i])
  tok_r_total  <- tok_r_total + length(toks)
  tok_r_ok     <- tok_r_ok + sum(toks %in% univ)
}
h_fila("09_rupturas.series_afectadas",
       sprintf("%d / %d tokens", tok_r_ok, tok_r_total),
       h_ok(tok_r_ok == tok_r_total))

yaml_ok <- sum(vapply(pubs_stems, function(s) {
  ruta <- here("catalogos", "01_publicaciones", paste0(s, ".yaml"))
  pid  <- yaml_scalar(ruta, "publicacion_id")
  iid  <- yaml_scalar(ruta, "institucion_id")
  isTRUE(pid == s) && isTRUE(iid %in% inst_ids)
}, logical(1)))
h_fila("01_publicaciones YAML  (pid==stem, inst OK)",
       sprintf("%d / %d", yaml_ok, length(pubs_stems)),
       h_ok(yaml_ok == length(pubs_stems)))

# ── 5. L0 / Vintages ──────────────────────────────────────────────────────────
h_sep("L0 / vintages")

pubs_con <- unique(vintages$publicacion_id)
n_con    <- length(pubs_con)
n_sin    <- length(pubs_stems) - n_con

h_fila("Total vintages registrados", as.character(nrow(vintages)))
h_fila("Publicaciones con >= 1 vintage",
       sprintf("%d de %d", n_con, length(pubs_stems)))
h_fila("Publicaciones sin ningun vintage",
       sprintf("%d  (fuentes aun no capturadas)", n_sin))

tab_v <- sort(table(vintages$publicacion_id), decreasing = TRUE)
cat("\n  Top 5 por n. de vintages:\n")
for (nm in names(tab_v)[seq_len(min(5L, length(tab_v)))])
  cat(sprintf("    %-52s %2d\n", nm, tab_v[[nm]]))

tab_s <- sort(table(series$publicacion_id), decreasing = TRUE)
cat("\n  Distribucion 03_series por publicacion_id (top 5):\n")
for (nm in names(tab_s)[seq_len(min(5L, length(tab_s)))])
  cat(sprintf("    %-52s %2d series\n", nm, tab_s[[nm]]))

# ── 6. ADR index ───────────────────────────────────────────────────────────────
h_sep("ADR  (estado del indice — consistencia verificada por test-adr-indice.R)")

idx_lin <- readLines(here("doc", "adr", "README.md"),
                     encoding = "UTF-8", warn = FALSE)
patron  <- "^\\|\\s*\\[(\\d{3})\\]\\(\\./(ADR-\\d{3}[^)]+\\.md)\\)\\s*\\|.*\\|\\s*(.*?)\\s*\\|\\s*$"
m_list  <- regmatches(idx_lin, regexec(patron, idx_lin, perl = TRUE))
filas_adr <- Filter(function(x) length(x) == 4L, m_list)

for (f in filas_adr) {
  num    <- f[[2]]
  arch   <- f[[3]]
  estado <- trimws(f[[4]])
  ruta_a <- here("doc", "adr", arch)
  if (file.exists(ruta_a)) {
    lin_a   <- readLines(ruta_a, encoding = "UTF-8", warn = FALSE)
    est_adr <- trimws(sub("^\\*\\*Estado:\\*\\*", "",
                          grep("^\\*\\*Estado:\\*\\*", lin_a, value = TRUE)[1]))
    sinc    <- isTRUE(estado == est_adr)
  } else {
    sinc <- FALSE
  }
  est_c <- if (nchar(estado) > 52) paste0(substr(estado, 1, 49), "...") else estado
  cat(sprintf("  ADR-%s  %-54s %s\n",
              num, est_c, if (sinc) "OK" else "DESSINCRONIZADO"))
}

# ── 7. doc/auditorias ─────────────────────────────────────────────────────────
h_sep("auditorias  (doc/auditorias/)")

aud_dir   <- here("doc", "auditorias")
aud_files <- setdiff(list.files(aud_dir, pattern = "\\.md$"), "README.md")
h_fila("Documentos en doc/auditorias/", as.character(length(aud_files)))

aud_idx <- file.path(aud_dir, "README.md")
if (file.exists(aud_idx)) {
  idx_aud      <- readLines(aud_idx, encoding = "UTF-8", warn = FALSE)
  pat_tabla    <- "^\\|\\s*`([^`]+\\.md)`"
  m_tabla      <- regmatches(idx_aud, regexec(pat_tabla, idx_aud, perl = TRUE))
  docs_citados <- unique(vapply(Filter(function(x) length(x) == 2L, m_tabla),
                                `[[`, character(1), 2L))
  n_existen    <- sum(docs_citados %in% aud_files)
  h_fila("Citados en indice que existen como archivo",
         sprintf("%d / %d", n_existen, length(docs_citados)),
         h_ok(n_existen == length(docs_citados)))
  if (length(aud_files) > 0L)
    h_fila("Ultimo documento (orden alfabetico)",
           sort(aud_files, decreasing = TRUE)[1])
}

# ── 8. Claves canónicas en 01_publicaciones ────────────────────────────────────
h_sep("01_publicaciones — claves canonicas  (_plantilla.yaml)")

plantilla_lin <- readLines(
  here("catalogos", "01_publicaciones", "_plantilla.yaml"),
  encoding = "UTF-8", warn = FALSE)
claves_canon  <- sub(":.*", "",
                     grep("^[a-zA-Z]", plantilla_lin, value = TRUE))
h_fila("Claves en _plantilla", paste(claves_canon, collapse = ", "))

n_completos <- sum(vapply(pubs_stems, function(s) {
  ruta   <- here("catalogos", "01_publicaciones", paste0(s, ".yaml"))
  lineas <- readLines(ruta, encoding = "UTF-8", warn = FALSE)
  claves <- sub(":.*", "", grep("^[a-zA-Z]", lineas, value = TRUE))
  all(claves_canon %in% claves)
}, logical(1)))
h_fila("YAML con todas las claves canonicas",
       sprintf("%d / %d", n_completos, length(pubs_stems)),
       h_ok(n_completos == length(pubs_stems)))

# ── 9. condiciones_uso — instantánea ──────────────────────────────────────────
h_sep("condiciones_uso — instantanea  (ADR-008 para el estado por fuente)")

prefijos <- c("Resuelto", "En gesti", "Aplazado", "Pendiente", "No verif",
              "API", "CONFIRMADO", "El FMI", "Idénti", "LICENCIA",
              "Mismas", "Términos", "Verificado")
conteos  <- integer(length(prefijos) + 1L)
names(conteos) <- c(prefijos, "Otro")

for (s in pubs_stems) {
  ruta <- here("catalogos", "01_publicaciones", paste0(s, ".yaml"))
  val  <- yaml_scalar(ruta, "condiciones_uso")
  if (is.na(val) || !nzchar(val)) {
    conteos["Otro"] <- conteos["Otro"] + 1L
    next
  }
  matched <- FALSE
  for (p in prefijos) {
    if (startsWith(val, p)) {
      conteos[p] <- conteos[p] + 1L
      matched <- TRUE
      break
    }
  }
  if (!matched) conteos["Otro"] <- conteos["Otro"] + 1L
}

for (nm in names(conteos))
  if (conteos[[nm]] > 0L) h_fila(nm, as.character(conteos[[nm]]))

abiertos <- conteos["Pendiente"] + conteos["No verif"] + conteos["Otro"]
if (abiertos > 0L)
  cat(sprintf("  Total sin resolver: %d  (ver ADR-008 para el estado por fuente)\n",
              abiertos))

# ── pie ───────────────────────────────────────────────────────────────────────
elapsed <- round((proc.time() - t0)[["elapsed"]], 1)
cat("\n", strrep("-", 66), "\n", sep = "")
cat(sprintf("  Completado en %.1f s  |  Recalcular de forma independiente para auditar.\n",
            elapsed))
cat(strrep("-", 66), "\n")
