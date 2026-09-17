# Reglas de integridad referencial ENTRE catálogos (no dentro de una tabla, como L2), separadas
# en una función pura para que tests/test-integridad-catalogos.R las ejerza con datos sintéticos
# sin tocar disco. src/validacion/validar_integridad_catalogos.R hace el I/O (leer los catálogos
# y los stems de 01_publicaciones/02_metodologias, reportar, fallar) y llama a
# validar_integridad_catalogos() definida acá.
#
# Origen: subsume la parte de tests/test-integridad-referencial.R que SÍ es tabular (columna de
# un catálogo que debe resolver contra otro) -- diagnosticado 2026-09-17 en doc/checklist_fase3.md,
# decisión #4. Migrado a pointblank porque cada arista de valor único es el caso de uso nativo de
# `col_vals_in_set()` (a diferencia de L2, que necesitó `specially()` para huecos/identidad -- acá
# solo las columnas MULTI-valor, series_insumo_ids y series_afectadas, lo necesitan, por la misma
# razón: no hay soporte nativo en pointblank 0.12.4 para "cada token de una lista separada por
# comas resuelve"). NO cubre 01_publicaciones/*.yaml (institucion_id, metodologia_id,
# publicacion_id==nombre de archivo): esos no son una tabla CSV, así que no calzan con
# create_agent(tbl=...) -- se quedan en tests/test-integridad-referencial.R, R base, mismo
# criterio que ya se aplicó en la migración de L2.
#
# Las 6 aristas cubiertas (ver catalogos/datapackage.json para las que además quedaron
# declaradas como "foreignKeys" formales -- solo las de valor único, Frictionless Table Schema no
# tiene una forma estándar de declarar una FK multi-valor o condicional):
#   03_series.publicacion_id      -> 01_publicaciones (valor único, foreignKeys)
#   03_series.metodologia_id      -> 02_metodologias   (valor único, opcional, foreignKeys)
#   05_series_master.transf_id    -> 04_transformaciones.transf_id (valor único, opcional, foreignKeys)
#   05_series_master.series_insumo_ids -> 03_series.serie_id (multi-valor, coma-separado)
#   08_vintages.publicacion_id    -> 01_publicaciones (valor único, foreignKeys)
#   09_rupturas.series_afectadas  -> 03_series.serie_id o 01_publicaciones, según tipo_referencia
#                                     (multi-valor Y condicional)

library(pointblank)

.multi <- function(v) {                               # separador coma-espacio, igual que antes
  v <- trimws(v)
  if (!nzchar(v)) return(character(0))
  trimws(strsplit(v, ",", fixed = TRUE)[[1]])
}

#' TRUE/FALSE por fila: ¿todos los tokens de `columna` (coma-separados) resuelven contra
#' `universo`? Fila vacía cuenta como "resuelve" (sin tokens que validar) -- igual de permisivo
#' que el resto del catálogo con campos opcionales.
.fila_tokens_resuelven <- function(columna, universo) {
  vapply(columna, function(v) all(.multi(v) %in% universo), logical(1), USE.NAMES = FALSE)
}

#' Igual que arriba, pero el universo depende de `tipo_referencia` por fila (09_rupturas: cada
#' fila declara si sus tokens son serie_id o publicacion_id). Un tipo_referencia desconocido
#' (fuera del enum de datapackage.json) se marca como fallo, no se ignora.
.fila_tokens_resuelven_condicional <- function(columna, tipo_referencia, serie_ids, pubs) {
  mapply(function(v, tr) {
    universo <- switch(tr, "serie_id" = serie_ids, "publicacion_id" = pubs, NULL)
    if (is.null(universo)) return(FALSE)
    all(.multi(v) %in% universo)
  }, columna, tipo_referencia, USE.NAMES = FALSE)
}

#' Corre la validación de integridad referencial entre catálogos.
#' @param series,transf,master,vintages,rupturas data frames ya leídos de los CSV correspondientes
#'   (03_series, 04_transformaciones, 05_series_master, 08_vintages, 09_rupturas), columnas character.
#' @param pubs,mets character vectors de stems válidos (01_publicaciones/*.yaml, 02_metodologias/*.yaml).
#' @return list(errores = character vector, vacío si todo resuelve; agentes = list de los 4
#'   ptblank_agent ya interrogados, uno por catálogo con columnas FK, para quien necesite el
#'   reporte unificado más allá del mensaje de fallo).
validar_integridad_catalogos <- function(series, transf, master, vintages, rupturas, pubs, mets) {
  serie_ids <- series$serie_id
  transf_ids <- transf$transf_id

  errores <- character(0)
  agregar_error <- function(msg) errores <<- c(errores, msg)

  # --- Chequeos de fila multi-valor / condicional, precomputados en R base (mismo motivo que
  # huecos/identidad en L2: no hay soporte nativo de pointblank para esto). ---
  insumo_resuelve <- .fila_tokens_resuelven(master$series_insumo_ids, serie_ids)
  tipo_conocido <- rupturas$tipo_referencia %in% c("serie_id", "publicacion_id")
  afectadas_resuelve <- .fila_tokens_resuelven_condicional(
    rupturas$series_afectadas, rupturas$tipo_referencia, serie_ids, pubs
  )

  # --- Registro de pasos por agente: mismo patrón que src/validacion/l2_pib_reglas.R
  # (registrar() con nombre -> índice de paso), porque get_agent_report() de pointblank 0.12.4
  # no expone las etiquetas de `label=` como columna propia -- hay que rastrear el índice del
  # paso a mano para poder traducirlo a un mensaje legible después de interrogate(). ---
  .nuevo_registro <- function() {
    idx <- list(); paso_i <- 0L
    list(
      registrar = function(nombre, agente_nuevo) {
        paso_i <<- paso_i + 1L
        idx[[nombre]] <<- paso_i
        agente_nuevo
      },
      idx = function() idx
    )
  }

  # --- Agente 03_series: publicacion_id (requerido) y metodologia_id (opcional, vacío permitido).
  # El paso de metodologia_id solo se registra si hay al menos un valor no vacío que evaluar --
  # si `preconditions` filtra TODAS las filas (todas vacías), pointblank 0.12.4 no pasa
  # vacuamente: el paso queda `eval == "ERROR"` (verificado empíricamente, mismo tipo de
  # limitación ya documentado para L2). Mismo patrón que los `if (...)` de registro condicional
  # en src/validacion/l2_pib_reglas.R. ---
  reg_series <- .nuevo_registro()
  agente_series <- create_agent(tbl = series, label = "Integridad: 03_series")
  agente_series <- reg_series$registrar("publicacion_id", agente_series |>
    col_vals_in_set(columns = vars(publicacion_id), set = pubs,
                     label = "03_series.publicacion_id -> 01_publicaciones"))
  if (any(nzchar(series$metodologia_id))) {
    agente_series <- reg_series$registrar("metodologia_id", agente_series |>
      col_vals_in_set(columns = vars(metodologia_id), set = mets,
                       preconditions = function(x) x[nzchar(x$metodologia_id), ],
                       label = "03_series.metodologia_id -> 02_metodologias (vacío permitido)"))
  }
  agente_series <- interrogate(agente_series)

  # --- Agente 05_series_master: transf_id (opcional, vía pointblank) y series_insumo_ids
  # (multi-valor, precomputado arriba, registrado como specially() para reporte unificado). ---
  reg_master <- .nuevo_registro()
  agente_master <- create_agent(tbl = master, label = "Integridad: 05_series_master")
  if (any(nzchar(master$transf_id))) {
    agente_master <- reg_master$registrar("transf_id", agente_master |>
      col_vals_in_set(columns = vars(transf_id), set = transf_ids,
                       preconditions = function(x) x[nzchar(x$transf_id), ],
                       label = "05_series_master.transf_id -> 04_transformaciones (opcional)"))
  }
  agente_master <- reg_master$registrar("series_insumo_ids", agente_master |>
    specially(fn = function(x) insumo_resuelve,
              label = "05_series_master.series_insumo_ids -> 03_series (multi-valor)"))
  agente_master <- interrogate(agente_master)

  # --- Agente 08_vintages: publicacion_id (requerido). ---
  reg_vintages <- .nuevo_registro()
  agente_vintages <- create_agent(tbl = vintages, label = "Integridad: 08_vintages")
  agente_vintages <- reg_vintages$registrar("publicacion_id", agente_vintages |>
    col_vals_in_set(columns = vars(publicacion_id), set = pubs,
                     label = "08_vintages.publicacion_id -> 01_publicaciones"))
  agente_vintages <- interrogate(agente_vintages)

  # --- Agente 09_rupturas: tipo_referencia conocido, y series_afectadas resuelve según ese tipo
  # (ambos precomputados arriba: ninguno es un check de columna simple). ---
  reg_rupturas <- .nuevo_registro()
  agente_rupturas <- create_agent(tbl = rupturas, label = "Integridad: 09_rupturas")
  agente_rupturas <- reg_rupturas$registrar("tipo_referencia", agente_rupturas |>
    specially(fn = function(x) tipo_conocido,
              label = "09_rupturas.tipo_referencia conocido (serie_id|publicacion_id)"))
  agente_rupturas <- reg_rupturas$registrar("series_afectadas", agente_rupturas |>
    specially(fn = function(x) afectadas_resuelve,
              label = "09_rupturas.series_afectadas -> según tipo_referencia (multi-valor)"))
  agente_rupturas <- interrogate(agente_rupturas)

  # --- Traducción de cada paso registrado a un mensaje de error legible, con detalle de fila
  # cuando hay extract disponible (columnas de valor único) y sin él cuando no lo hay
  # (specially() no soporta extracts, mismo hallazgo empírico que en L2). ---
  reportar <- function(agente, registro, mensajes, id_col) {
    reporte <- get_agent_report(agente, display_table = FALSE)
    extractos <- get_data_extracts(agente)
    idx <- registro$idx()
    for (nombre in names(idx)) {
      i <- idx[[nombre]]
      fila <- reporte[reporte$i == i, ]
      fallo <- is.na(fila$f_pass) || fila$f_pass < 1
      if (!fallo) next
      ext <- extractos[[as.character(i)]]
      if (!is.null(ext) && id_col %in% names(ext)) {
        agregar_error(paste0(mensajes[[nombre]], ": ", nrow(ext), " fila(s) no resuelven (",
                              paste(head(unique(ext[[id_col]]), 5), collapse = ", "), ")"))
      } else {
        n_fallo <- fila$units - fila$n_pass
        agregar_error(paste0(mensajes[[nombre]], ": ", n_fallo, " fila(s) no resuelven"))
      }
    }
  }

  reportar(agente_series, reg_series,
           list(publicacion_id = "03_series.publicacion_id -> 01_publicaciones",
                metodologia_id = "03_series.metodologia_id -> 02_metodologias"),
           "serie_id")
  reportar(agente_master, reg_master,
           list(transf_id = "05_series_master.transf_id -> 04_transformaciones",
                series_insumo_ids = "05_series_master.series_insumo_ids -> 03_series"),
           "series_master_id")
  reportar(agente_vintages, reg_vintages,
           list(publicacion_id = "08_vintages.publicacion_id -> 01_publicaciones"),
           "vintage_id")
  reportar(agente_rupturas, reg_rupturas,
           list(tipo_referencia = "09_rupturas.tipo_referencia conocido (serie_id|publicacion_id)",
                series_afectadas = "09_rupturas.series_afectadas -> según tipo_referencia"),
           "ruptura_id")

  list(errores = errores,
       agentes = list(series = agente_series, master = agente_master,
                       vintages = agente_vintages, rupturas = agente_rupturas))
}
