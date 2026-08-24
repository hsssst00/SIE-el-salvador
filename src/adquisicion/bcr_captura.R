# =============================================================================
# bcr_captura.R — motor de captura de la familia `vista-serie` del portal del BCR
# (estadisticas.bcr.gob.sv — Laravel + Livewire v2 + Alpine 3 + SheetJS).
#
# QUÉ HACE Y QUÉ NO
# -----------------
# Reproduce la interacción de la interfaz con un navegador headless (chromote) y
# obtiene EL MISMO .xlsx que baja un usuario al hacer clic en "Formato Excel":
# el archivo lo genera SheetJS del lado del cliente y se intercepta la descarga
# real (`Browser$setDownloadBehavior`). NO reconstruye el archivo ni lo captura
# como JSON — el artefacto de L0 es el .xlsx del publicador (README §2.1/§2.3;
# continuidad con los 4 vintages del manifiesto; F1).
#
# El extractor DOM (`.BCR_EXTRACT`) se usa solo para METADATOS y verificación
# cruzada (conteo de variables, último periodo), no como artefacto L0.
#
# HALLAZGO CLAVE (verificado en vivo 2026-08-24, doc/captura_bcr_livewire_hallazgo.md):
# ambas tablas del DOM (#tablaVariables / #tablaValores) solo alcanzan su tamaño
# completo (todas las variables) cuando el componente está en MODO TABULAR y se
# ejecutó `filtrar` con el rango completo. En modo gráfico `filtrar` renderiza
# solo la variable graficada (~200 celdas). `filtrar` tabular puede tardar hasta
# 15-30 s (2-3 s en pruebas recientes, pero no se asume): se espera por
# PREDICADO, nunca por `Sys.sleep()`.
#
# NAVEGACIÓN: `b$go_to(url)`, no `Page$navigate()` + `Page$loadEventFired()`
# (carrera documentada; chromote 0.5.1 agregó `$go_to()` para reemplazarla —
# bitácora 2026-08-20, ADR-009).
#
# El exportador `html_table_to_excel(type)` (definido globalmente por la página)
# lee del DOM directamente (#tablaVariables + #tablaValores, no de una variable
# JS) y hace `XLSX.writeFile(workbook, titulo + '.' + type)` — `type` es
# literalmente la extensión del archivo que SheetJS usa para inferir el formato
# de salida. Confirmado en vivo (2026-08-24) leyendo el código fuente de la
# función en la página: el valor correcto es "xlsx", no "excel".
# =============================================================================

library(chromote)
library(jsonlite)

.BCR_EXPORT_ARG <- "xlsx"

`%||%` <- function(a, b) if (is.null(a)) b else a

.bcr_eval <- function(b, expr, await = FALSE) {
  res <- b$Runtime$evaluate(expression = expr, returnByValue = TRUE, awaitPromise = await)
  if (!is.null(res$exceptionDetails)) {
    stop("Error JS: ", res$exceptionDetails$exception$description %||% res$exceptionDetails$text)
  }
  res$result$value
}

.bcr_wait <- function(b, expr, timeout_s = 240, intervalo = 0.5, que = "condición") {
  t0 <- Sys.time()
  repeat {
    ok <- tryCatch(isTRUE(.bcr_eval(b, expr)), error = function(e) FALSE)
    if (ok) return(invisible(TRUE))
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > timeout_s) {
      stop("FALLO VISIBLE: timeout (", timeout_s, "s) esperando: ", que)
    }
    Sys.sleep(intervalo)
  }
}

# Referencia al componente vista-serie, cacheada en window.__BCR, con un hook que
# cuenta cada `message.processed` (base del predicado de espera).
.BCR_BOOT <- '
(function () {
  var byId = window.livewire && window.livewire.components && window.livewire.components.componentsById;
  if (!byId) return false;
  var key = Object.keys(byId).filter(function (k) { return byId[k].name === "vista-serie"; })[0];
  if (!key) return false;
  window.__BCR = { id: key, n: 0 };
  window.livewire.hook("message.processed", function () { window.__BCR.n++; });
  return true;
})()'

# OJO: window.livewire.find(id) devuelve un Proxy donde cualquier propiedad
# aparece como función. Hay que usar componentsById (hallazgo 2026-08-24).
.BCR_CMP <- 'window.livewire.components.componentsById[window.__BCR.id]'

# Extractor DOM: lee #tablaVariables + #tablaValores. Solo metadatos/cross-check.
.BCR_EXTRACT <- r"---(
(function () {
  'use strict';
  var clean = function (s) {
    return (s || '').replace(/ /g, ' ').replace(/\s+/g, ' ').trim();
  };
  var cellText = function (td) {
    var k = td.cloneNode(true);
    var junk = k.querySelectorAll('.matriz, .padreMatriz, script, style');
    for (var i = 0; i < junk.length; i++) junk[i].remove();
    return clean(k.textContent);
  };
  var tV = document.getElementById('tablaVariables');
  var tD = document.getElementById('tablaValores');
  if (!tV || !tD || tD.rows.length < 3) {
    return JSON.stringify({ ok: false, error: 'tablas ausentes o vacias' });
  }
  var meta = {};
  try {
    var d = window.livewire.components.componentsById[window.__BCR.id].data;
    meta = {
      id_publicacion: d.idPublic, nombre_cuadro: d.nombreCuadro,
      unidades: d.unidadesCuadro, tipo_serie: d.tipoSerie, formula: d.formula,
      decimales: d.defaultDecimal, tabular: d.tabular,
      variables_meta: (d.variablesAGraficar || []).map(function (v) {
        return { id: v.graficar, nombre_es: v.nombre_es, nombre_en: v.nombre_en };
      })
    };
  } catch (e) { meta = { error: String(e) }; }
  var anios = [], c0 = tD.rows[0].cells;
  for (var i = 0; i < c0.length; i++) {
    var y = cellText(c0[i]);
    for (var j = 0; j < c0[i].colSpan; j++) anios.push(y);
  }
  var simbolos = Array.prototype.map.call(tD.rows[1].cells, cellText);
  var nPer = simbolos.length;
  var idx = [];
  for (var r = 2; r < tD.rows.length; r++) {
    if (tD.rows[r].cells.length === nPer) idx.push(r);
  }
  var valores = idx.map(function (r) {
    return Array.prototype.map.call(tD.rows[r].cells, cellText);
  });
  return JSON.stringify({
    ok: true, meta: meta, n_periodos: nPer, n_variables: idx.length,
    anios: anios, simbolos: simbolos,
    filas_vacias: valores.filter(function (f) {
      return f.every(function (v) { return v === ''; });
    }).length
  });
})()
)---"

# Verificación de forma del artefacto de L0: un .xlsx es un ZIP, empieza con "PK".
verificacion_xlsx <- function(bytes) {
  if (length(bytes) < 2) return(FALSE)
  identical(as.integer(bytes[1:2]), c(0x50L, 0x4bL))
}

# Símbolo romano de periodo -> Tn (formato de periodo_referencia_max en 08_vintages)
.bcr_periodo_T <- function(simbolo) {
  simbolo <- sub("\\s*\\(.*\\)$", "", simbolo)   # quita marca "(e)"/"(p)"
  unname(c(I = "T1", II = "T2", III = "T3", IV = "T4")[simbolo])
}

# Espera a que aparezca un .xlsx nuevo y estable en `dir` (sin .crdownload).
.bcr_esperar_descarga <- function(dir, antes, timeout_s = 120, intervalo = 0.5) {
  t0 <- Sys.time()
  repeat {
    nuevos <- setdiff(list.files(dir), antes)
    xlsx <- nuevos[grepl("\\.xlsx$", nuevos) & !grepl("\\.crdownload$", nuevos)]
    if (length(xlsx) >= 1) {
      ruta <- file.path(dir, xlsx[1])
      s1 <- file.info(ruta)$size; Sys.sleep(0.4); s2 <- file.info(ruta)$size
      if (!is.na(s1) && identical(s1, s2) && s1 > 0) return(ruta)
    }
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > timeout_s) {
      stop("FALLO VISIBLE: no apareció un .xlsx en '", dir, "' tras ", timeout_s,
           "s. En headless, sin Browser$setDownloadBehavior el archivo se descarta ",
           "en silencio (bitácora 2026-08-20).")
    }
    Sys.sleep(intervalo)
  }
}

# -----------------------------------------------------------------------------
# bcr_capturar_xlsx()
#   Devuelve list(bytes, ruta, id_publicacion, periodo_referencia_max,
#                 n_variables, n_variables_con_datos, n_periodos, url, capturado_en).
#   `bytes` es el .xlsx real del portal, listo para registrar_descarga().
# -----------------------------------------------------------------------------
bcr_capturar_xlsx <- function(url, formula = "0", timeout_s = 240,
                              dir_descarga = tempfile("bcr_dl_"), verbose = TRUE) {
  msg <- function(...) if (isTRUE(verbose)) message("[bcr] ", ...)
  dir.create(dir_descarga, showWarnings = FALSE, recursive = TRUE)

  b <- ChromoteSession$new()
  on.exit(try(b$close(), silent = TRUE), add = TRUE)

  # Sin esto, Chrome headless descarta cualquier descarga en silencio (bitácora 2026-08-20).
  b$Browser$setDownloadBehavior(behavior = "allow", downloadPath = normalizePath(dir_descarga))

  msg("navegando: ", url)
  b$go_to(url)   # <- no Page$navigate() (carrera documentada, ADR-009)

  # 1. montar el componente
  .bcr_wait(b, .BCR_BOOT, timeout_s = 60, que = "montaje de vista-serie")
  id_pub <- .bcr_eval(b, sprintf("%s.data.idPublic", .BCR_CMP))
  msg("idPublic = ", id_pub)

  # 2. rango completo (fetch desde la propia página; hereda cookies, evita el 403)
  rangos <- fromJSON(.bcr_eval(
    b, sprintf("fetch('/api/rangos/%s',{headers:{Accept:'application/json'}}).then(r=>r.text())", id_pub),
    await = TRUE), simplifyVector = FALSE)
  anios_disp <- vapply(rangos, function(x) as.integer(x$year), integer(1))
  nper_anio  <- vapply(rangos, function(x) length(x$periodos$simbolo), integer(1))
  y_ini <- anios_disp[1]; n_ini <- 1L
  y_fin <- anios_disp[length(anios_disp)]; n_fin <- nper_anio[length(nper_anio)]
  n_esperado <- sum(nper_anio)   # rango completo => todos los periodos
  msg("rango completo ", y_ini, "-I .. ", y_fin, "  => ", n_esperado, " periodos")

  # 3. filtro diferido + modo tabular (los valores diferidos viajan con la
  #    siguiente petición Livewire; por eso el orden de los <select> no importa)
  n0 <- .bcr_eval(b, "window.__BCR.n")
  cambio <- .bcr_eval(b, sprintf('
    (function () { var c = %s;
      c.set("formula","%s",true); c.set("yInicio","%s",true); c.set("nInicio","%s",true);
      c.set("yFin","%s",true); c.set("nFin","%s",true);
      if (!c.data.tabular) { c.call("cambiarTipo"); return true; } return false; })()',
    .BCR_CMP, formula, y_ini, n_ini, y_fin, n_fin))
  if (isTRUE(cambio)) {
    .bcr_wait(b, sprintf(
      'window.__BCR.n > %d && %s.messageInTransit === null && %s.data.tabular === true',
      n0, .BCR_CMP, .BCR_CMP), timeout_s = timeout_s, que = "cambiarTipo / vista tabular")
  }

  # 4. filtrar y esperar la matriz completa por predicado
  n1 <- .bcr_eval(b, "window.__BCR.n")
  .bcr_eval(b, sprintf('(function(){ %s.call("filtrar"); return true; })()', .BCR_CMP))
  msg("esperando filtrar() ...")
  .bcr_wait(b, sprintf('
    (function () {
      if (window.__BCR.n <= %d) return false;
      var c = %s; if (c.messageInTransit !== null) return false;
      var t = document.getElementById("tablaValores");
      if (!t || t.rows.length < 3) return false;
      if (t.rows[1].cells.length !== %d) return false;
      var n = 0; for (var i = 2; i < t.rows.length; i++) if (t.rows[i].cells.length === %d) n++;
      return n > 0;
    })()', n1, .BCR_CMP, n_esperado, n_esperado),
    timeout_s = timeout_s, que = "filtrar() / matriz completa")

  # 5. metadatos + cross-check (extractor DOM; NO es el artefacto L0)
  meta <- fromJSON(.bcr_eval(b, .BCR_EXTRACT), simplifyVector = FALSE)
  if (!isTRUE(meta$ok)) stop("FALLO VISIBLE: extractor DOM: ", meta$error)
  n_con_datos <- meta$n_variables - meta$filas_vacias
  ult <- length(meta$anios)
  periodo_ref_max <- paste0(meta$anios[[ult]], "-", .bcr_periodo_T(meta$simbolos[[ult]]))
  msg("DOM: ", meta$n_variables, " filas (", n_con_datos, " con datos) x ",
      meta$n_periodos, " periodos; ult=", periodo_ref_max)

  # 6. disparar el exportador del portal e interceptar la descarga REAL (1a)
  antes <- list.files(dir_descarga)
  ok_disparo <- .bcr_eval(b, sprintf(
    '(function(){ if (typeof html_table_to_excel !== "function") return false;
       html_table_to_excel("%s"); return true; })()', .BCR_EXPORT_ARG))
  if (!isTRUE(ok_disparo)) {
    stop("FALLO VISIBLE: html_table_to_excel no está disponible o no se pudo invocar.")
  }
  ruta_xlsx <- .bcr_esperar_descarga(dir_descarga, antes, timeout_s = 120)
  bytes <- readBin(ruta_xlsx, "raw", file.info(ruta_xlsx)$size)
  if (!verificacion_xlsx(bytes)) {
    stop("FALLO VISIBLE: el archivo descargado no tiene firma PK (.xlsx). Ruta: ", ruta_xlsx)
  }
  msg("descargado: ", basename(ruta_xlsx), " (", length(bytes), " bytes)")

  list(bytes = bytes, ruta = ruta_xlsx, id_publicacion = id_pub,
       periodo_referencia_max = periodo_ref_max, n_variables = meta$n_variables,
       n_variables_con_datos = n_con_datos, n_periodos = meta$n_periodos,
       url = url, capturado_en = Sys.time())
}
