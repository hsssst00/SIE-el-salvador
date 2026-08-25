# bcr.R — una función por publicación del BCR servida desde estadisticas.bcr.gob.sv.
#
# La mecánica de captura (navegador headless + Livewire + descarga real del .xlsx)
# vive en bcr_captura.R. Acá solo se fija, por publicación, la URL exacta, el
# publicacion_id, la descripción de archivo y la llamada a registrar_descarga.
# Una función por publicación para que un cambio de formato en una rompa solo esa
# (senda §8, "scripts modulares por publicación").
#
# fecha_publicacion: el portal no declara una fecha de publicación parseable (verificado
# en vivo 2026-08-24: el campo visible "Datos actualizados hasta:" viene vacío y solo
# expone el período de referencia, no una fecha de publicación) — los 4 vintages del
# manifiesto la aproximan al mes reportado, día 01, y lo anotan (ver 08_vintages.csv).
# registrar_descarga la exige y no la infiere. Por eso es argumento explícito: quien
# corre la captura pasa el mes de publicación conocido de la fuente en formato
# AAAA-MM-01.
#
# codigo_http = 200L: el .xlsx se genera del lado del cliente (SheetJS), no hay un
# status HTTP del archivo; se pasa el de la navegación y el gate real de forma es
# verificacion_xlsx (firma PK) sobre los bytes.

source("src/adquisicion/bcr_captura.R")
source("src/adquisicion/lib_adquisicion.R")

.bcr_nota_fecha_aproximada <- paste(
  "fecha_publicacion aproximada al mes de publicación; día 01 por convención",
  "(el portal no declara una fecha de publicación parseable - verificado en vivo",
  "2026-08-24, ver doc/captura_bcr_livewire_hallazgo.md)."
)

descargar_bcr_pib_nsa <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/pib-t-produccion-y-gasto-indices-de-volumen-encadenados-serie-original-referencia-2014-indices-de-volumen-encadenados"
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR",
    publicacion_id = "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA",
    url = url,
    descripcion_archivo = "pib_t_indices_volumen_nsa",
    extension = "xlsx",
    contenido_crudo = cap$bytes,
    codigo_http = 200L,
    fecha_publicacion = fecha_publicacion,
    periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx,
    notas_vintage = .bcr_nota_fecha_aproximada
  )
}

descargar_bcr_pib_sa <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/pib-t-produccion-y-gasto-indices-de-volumen-encadenados-serie-desestacionalizada-referencia-2014-indices-de-volumen-encadenado"
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR",
    publicacion_id = "BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_SA",
    url = url,
    descripcion_archivo = "pib_t_indices_volumen_sa",
    extension = "xlsx",
    contenido_crudo = cap$bytes,
    codigo_http = 200L,
    fecha_publicacion = fecha_publicacion,
    periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx,
    notas_vintage = .bcr_nota_fecha_aproximada
  )
}

.bcr_nota_ivae_vigente_fecha <- paste(
  "fecha_publicacion NO observada directamente en la fuente (verificado en vivo",
  "2026-08-25: la página solo expone 'Datos actualizados hasta: Mayo 2026' -cobertura,",
  "no fecha de publicación- y 'Próxima fecha de publicación: 31 agosto 2026' -la",
  "SIGUIENTE, no la del vintage capturado). Se aproxima por el patrón de rezago del",
  "propio calendario del BCR (doc/calendario_divulgacion_bcr.csv: publicación de",
  "agosto cubre referencia 2026-06, rezago de 2 meses); con periodo_referencia_max =",
  "2026-M05, el ciclo que la publicó cae ~julio 2026. Aproximada a 2026-07-01 (mes,",
  "día 01 por convención - mismo patrón que .bcr_nota_fecha_aproximada). Decisión de",
  "Harold, 2026-08-25 (handoff Fase 2, Bloque 2, Paso 2.4): usar la fecha del ciclo",
  "anterior inferida por patrón, no la próxima fecha anunciada."
)

descargar_bcr_ivae_vigente <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/indice-de-volumen-de-la-actividad-economica-ivae-serie-desestacionalizada"
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR",
    publicacion_id = "BCR.IVAE.VIGENTE",
    url = url,
    descripcion_archivo = "ivae_vigente",
    extension = "xlsx",
    contenido_crudo = cap$bytes,
    codigo_http = 200L,
    fecha_publicacion = fecha_publicacion,
    periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx,
    notas_vintage = .bcr_nota_ivae_vigente_fecha
  )
}

descargar_bcr_pib_nominal <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/producto-interno-bruto-trimestral-pib-t-produccion-y-gasto-a-precios-corrientes-en-millones-de-us"
  # formula = "0": representación base del componente vista-serie. En las publicaciones
  # de índices, "0" da los índices; en esta publicación en precios corrientes, "0" da
  # los valores en millones de US$. Confirmado en vivo (puerta de confirmación del
  # handoff de Fase 2, 2026-08-25): la captura con formula="0" reproduce el sha256_norm
  # del vintage manual v2026-06 registrado en el manifiesto.
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR",
    publicacion_id = "BCR.PIB_T.NOMINAL",
    url = url,
    descripcion_archivo = "pib_t_nominal",
    extension = "xlsx",
    contenido_crudo = cap$bytes,
    codigo_http = 200L,
    fecha_publicacion = fecha_publicacion,
    periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx,
    notas_vintage = .bcr_nota_fecha_aproximada
  )
}
