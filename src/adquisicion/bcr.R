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

# -----------------------------------------------------------------------------
# Lote de 11 publicaciones mensuales/trimestrales (handoff Fase 2, Bloque 3,
# 2026-08-26). Mismo patrón de aproximación de fecha_publicacion que IVAE.VIGENTE:
# el portal no declara una fecha de publicación parseable, se aproxima por el
# rezago del calendario del BCR (doc/calendario_divulgacion_bcr.csv) aplicado al
# periodo_referencia_max realmente capturado. Cada nota cita su propia fila del
# calendario y su propio periodo capturado — no es la nota de IVAE reutilizada.
#
# Queda fuera BCR.SPNF_SERIE_1994_2025: verificado en vivo (2026-08-26) que es una
# serie congelada (cobertura real hasta 2025-M12, no 2026 en adelante como el
# calendario de divulgación sugeriría para una fila mensual) — el patrón de rezago
# de este lote no le aplica. Reportado aparte en
# doc/bitacora_fuentes_fragiles.md, no capturada en este lote.
# -----------------------------------------------------------------------------

.bcr_nota_ipi_vigente_fecha <- paste(
  "fecha_publicacion NO observada directamente en la fuente (mismo patrón que",
  "BCR.IVAE.VIGENTE, ver .bcr_nota_ivae_vigente_fecha). Se aproxima por el rezago",
  "del calendario del BCR (doc/calendario_divulgacion_bcr.csv: IPI, fila 'Agosto',10",
  "-> periodo_referencia 2026-06, rezago 2 meses); con periodo_referencia_max =",
  "2026-M06 (capturado 2026-08-26), el ciclo que la publicó cae ~2026-08-01.",
  "Aproximada a 2026-08-01 (mes, día 01 por convención). Decisión de Harold,",
  "2026-08-25 (handoff Fase 2, Bloque 3)."
)

descargar_bcr_ipi_vigente <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/indice-de-produccion-industrial-serie-desestacionalizada"
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR", publicacion_id = "BCR.IPI.VIGENTE", url = url,
    descripcion_archivo = "ipi_vigente", extension = "xlsx",
    contenido_crudo = cap$bytes, codigo_http = 200L,
    fecha_publicacion = fecha_publicacion, periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx, notas_vintage = .bcr_nota_ipi_vigente_fecha
  )
}

.bcr_nota_ipp_fecha <- paste(
  "fecha_publicacion NO observada directamente en la fuente (mismo patrón que",
  "BCR.IVAE.VIGENTE). Se aproxima por el rezago del calendario del BCR",
  "(doc/calendario_divulgacion_bcr.csv: IPP, fila 'Agosto',18 -> periodo_referencia",
  "2026-07, rezago 1 mes); con periodo_referencia_max = 2026-M07 (capturado",
  "2026-08-26), el ciclo que la publicó cae ~2026-08-01. Aproximada a 2026-08-01",
  "(mes, día 01 por convención). Decisión de Harold, 2026-08-25 (handoff Fase 2,",
  "Bloque 3)."
)

descargar_bcr_ipp <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/indice-de-precios-al-productor-ipp"
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR", publicacion_id = "BCR.IPP", url = url,
    descripcion_archivo = "ipp", extension = "xlsx",
    contenido_crudo = cap$bytes, codigo_http = 200L,
    fecha_publicacion = fecha_publicacion, periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx, notas_vintage = .bcr_nota_ipp_fecha
  )
}

.bcr_nota_isi_fecha <- paste(
  "fecha_publicacion NO observada directamente en la fuente (mismo patrón que",
  "BCR.IVAE.VIGENTE). Se aproxima por el rezago del calendario del BCR",
  "(doc/calendario_divulgacion_bcr.csv: ISI, fila 'Agosto',18 -> periodo_referencia",
  "2026-07, rezago 1 mes); con periodo_referencia_max = 2026-M07 (capturado",
  "2026-08-26), el ciclo que la publicó cae ~2026-08-01. Aproximada a 2026-08-01",
  "(mes, día 01 por convención). Decisión de Harold, 2026-08-25 (handoff Fase 2,",
  "Bloque 3)."
)

descargar_bcr_isi <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/indice-subyacente-de-inflacion-isi-base-dic-2009"
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR", publicacion_id = "BCR.ISI", url = url,
    descripcion_archivo = "isi", extension = "xlsx",
    contenido_crudo = cap$bytes, codigo_http = 200L,
    fecha_publicacion = fecha_publicacion, periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx, notas_vintage = .bcr_nota_isi_fecha
  )
}

.bcr_nota_itcer_fecha <- paste(
  "fecha_publicacion NO observada directamente en la fuente (mismo patrón que",
  "BCR.IVAE.VIGENTE). Se aproxima por el rezago del calendario del BCR",
  "(doc/calendario_divulgacion_bcr.csv: ITCER, fila 'Agosto',31 -> periodo_referencia",
  "2026-07, rezago 1 mes); con periodo_referencia_max = 2026-M06 (capturado",
  "2026-08-26), el ciclo que la publicó cae ~2026-07-01. Aproximada a 2026-07-01",
  "(mes, día 01 por convención). Decisión de Harold, 2026-08-25 (handoff Fase 2,",
  "Bloque 3)."
)

descargar_bcr_itcer <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/indice-de-tipo-de-cambio-efectivo-real-mensual"
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR", publicacion_id = "BCR.ITCER", url = url,
    descripcion_archivo = "itcer", extension = "xlsx",
    contenido_crudo = cap$bytes, codigo_http = 200L,
    fecha_publicacion = fecha_publicacion, periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx, notas_vintage = .bcr_nota_itcer_fecha
  )
}

.bcr_nota_gobierno_central_consolidado_fecha <- paste(
  "fecha_publicacion NO observada directamente en la fuente (mismo patrón que",
  "BCR.IVAE.VIGENTE). Se aproxima por el rezago del calendario del BCR",
  "(doc/calendario_divulgacion_bcr.csv: Gobierno Central Consolidado, fila",
  "'Agosto',31 -> periodo_referencia 2026-07, rezago 1 mes); con",
  "periodo_referencia_max = 2026-M06 (capturado 2026-08-26), el ciclo que la",
  "publicó cae ~2026-07-01. Aproximada a 2026-07-01 (mes, día 01 por convención).",
  "Decisión de Harold, 2026-08-25 (handoff Fase 2, Bloque 3). Primera captura",
  "falló por timeout (tabla grande, 55 variables x 390 periodos): timeouts de",
  "exportación/descarga subidos en bcr_captura.R (600s/300s) antes de reintentar."
)

descargar_bcr_gobierno_central_consolidado <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/gobierno-central-consolidado-mensual"
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR", publicacion_id = "BCR.GOBIERNO_CENTRAL_CONSOLIDADO", url = url,
    descripcion_archivo = "gobierno_central_consolidado", extension = "xlsx",
    contenido_crudo = cap$bytes, codigo_http = 200L,
    fecha_publicacion = fecha_publicacion, periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx,
    notas_vintage = .bcr_nota_gobierno_central_consolidado_fecha
  )
}

.bcr_nota_panorama_sociedades_deposito_fecha <- paste(
  "fecha_publicacion NO observada directamente en la fuente (mismo patrón que",
  "BCR.IVAE.VIGENTE). Se aproxima por el rezago del calendario del BCR",
  "(doc/calendario_divulgacion_bcr.csv: Panorama de las sociedades de depósito,",
  "fila 'Agosto',31 -> periodo_referencia 2026-07, rezago 1 mes); con",
  "periodo_referencia_max = 2026-M06 (capturado 2026-08-26), el ciclo que la",
  "publicó cae ~2026-07-01. Aproximada a 2026-07-01 (mes, día 01 por convención).",
  "Decisión de Harold, 2026-08-25 (handoff Fase 2, Bloque 3). Primera captura",
  "falló por timeout (tabla grande, 37 variables x 306 periodos): timeouts de",
  "exportación/descarga subidos en bcr_captura.R (600s/300s) antes de reintentar."
)

descargar_bcr_panorama_sociedades_deposito <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/panorama-de-las-sociedades-de-depositos"
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR", publicacion_id = "BCR.PANORAMA_SOCIEDADES_DEPOSITO", url = url,
    descripcion_archivo = "panorama_sociedades_deposito", extension = "xlsx",
    contenido_crudo = cap$bytes, codigo_http = 200L,
    fecha_publicacion = fecha_publicacion, periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx,
    notas_vintage = .bcr_nota_panorama_sociedades_deposito_fecha
  )
}

.bcr_nota_panorama_banco_central_fecha <- paste(
  "fecha_publicacion NO observada directamente en la fuente (mismo patrón que",
  "BCR.IVAE.VIGENTE). Se aproxima por el rezago del calendario del BCR",
  "(doc/calendario_divulgacion_bcr.csv: Panorama del Banco Central, fila",
  "'Agosto',10 -> periodo_referencia 2026-07, rezago 1 mes); con",
  "periodo_referencia_max = 2026-M07 (capturado 2026-08-26), el ciclo que la",
  "publicó cae ~2026-08-01. Aproximada a 2026-08-01 (mes, día 01 por convención).",
  "Decisión de Harold, 2026-08-25 (handoff Fase 2, Bloque 3)."
)

descargar_bcr_panorama_banco_central <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/panorama-del-banco-central"
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR", publicacion_id = "BCR.PANORAMA_BANCO_CENTRAL", url = url,
    descripcion_archivo = "panorama_banco_central", extension = "xlsx",
    contenido_crudo = cap$bytes, codigo_http = 200L,
    fecha_publicacion = fecha_publicacion, periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx,
    notas_vintage = .bcr_nota_panorama_banco_central_fecha
  )
}

.bcr_nota_balanza_comercial_fecha <- paste(
  "fecha_publicacion NO observada directamente en la fuente (mismo patrón que",
  "BCR.IVAE.VIGENTE). Se aproxima por el rezago del calendario del BCR",
  "(doc/calendario_divulgacion_bcr.csv: Balanza Comercial de Mercancías. Valores,",
  "fila 'Agosto',27 -> periodo_referencia 2026-07, rezago 1 mes); con",
  "periodo_referencia_max = 2026-M06 (capturado 2026-08-26), el ciclo que la",
  "publicó cae ~2026-07-01. Aproximada a 2026-07-01 (mes, día 01 por convención).",
  "Decisión de Harold, 2026-08-25 (handoff Fase 2, Bloque 3)."
)

descargar_bcr_balanza_comercial <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/balanza-comercial"
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR", publicacion_id = "BCR.BALANZA_COMERCIAL", url = url,
    descripcion_archivo = "balanza_comercial", extension = "xlsx",
    contenido_crudo = cap$bytes, codigo_http = 200L,
    fecha_publicacion = fecha_publicacion, periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx, notas_vintage = .bcr_nota_balanza_comercial_fecha
  )
}

.bcr_nota_reservas_internacionales_netas_fecha <- paste(
  "fecha_publicacion NO observada directamente en la fuente (mismo patrón que",
  "BCR.IVAE.VIGENTE). Se aproxima por el rezago del calendario del BCR",
  "(doc/calendario_divulgacion_bcr.csv: Reservas Internacionales Netas BCR, fila",
  "'Agosto',7 -> periodo_referencia 2026-07, rezago 1 mes); con",
  "periodo_referencia_max = 2026-M07 (capturado 2026-08-26), el ciclo que la",
  "publicó cae ~2026-08-01. Aproximada a 2026-08-01 (mes, día 01 por convención).",
  "Decisión de Harold, 2026-08-25 (handoff Fase 2, Bloque 3)."
)

descargar_bcr_reservas_internacionales_netas <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/reservas-internacionales-netas-bcr"
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR", publicacion_id = "BCR.RESERVAS_INTERNACIONALES_NETAS", url = url,
    descripcion_archivo = "reservas_internacionales_netas", extension = "xlsx",
    contenido_crudo = cap$bytes, codigo_http = 200L,
    fecha_publicacion = fecha_publicacion, periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx,
    notas_vintage = .bcr_nota_reservas_internacionales_netas_fecha
  )
}

.bcr_nota_indices_precios_comercio_exterior_fecha <- paste(
  "fecha_publicacion NO observada directamente en la fuente (mismo patrón que",
  "BCR.IVAE.VIGENTE). Se aproxima por el rezago del calendario del BCR",
  "(doc/calendario_divulgacion_bcr.csv: Índices de Precios del Comercio Exterior -",
  "Mensual, fila 'Agosto',31 -> periodo_referencia 2026-06, rezago 2 meses); con",
  "periodo_referencia_max = 2026-M05 (capturado 2026-08-26), el ciclo que la",
  "publicó cae ~2026-07-01. Aproximada a 2026-07-01 (mes, día 01 por convención).",
  "Decisión de Harold, 2026-08-25 (handoff Fase 2, Bloque 3)."
)

descargar_bcr_indices_precios_comercio_exterior <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/indices-del-sector-externo-mensual"
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR", publicacion_id = "BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR", url = url,
    descripcion_archivo = "indices_precios_comercio_exterior", extension = "xlsx",
    contenido_crudo = cap$bytes, codigo_http = 200L,
    fecha_publicacion = fecha_publicacion, periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx,
    notas_vintage = .bcr_nota_indices_precios_comercio_exterior_fecha
  )
}

.bcr_nota_balanza_pagos_trimestral_fecha <- paste(
  "fecha_publicacion NO observada directamente en la fuente (mismo patrón que",
  "BCR.IVAE.VIGENTE, adaptado a periodicidad trimestral). Se aproxima por el",
  "rezago del calendario del BCR (doc/calendario_divulgacion_bcr.csv: Balanza de",
  "Pagos Trimestral, fila 'Septiembre',30 -> periodo_referencia 2026-T2, rezago 1",
  "trimestre = 3 meses desde el cierre del trimestre); con periodo_referencia_max",
  "= 2026-T1 (capturado 2026-08-26), el ciclo que la publicó cae ~2026-06-01",
  "(marzo, cierre de T1, + 3 meses). Aproximada a 2026-06-01 (mes, día 01 por",
  "convención). Decisión de Harold, 2026-08-25 (handoff Fase 2, Bloque 3)."
)

descargar_bcr_balanza_pagos_trimestral <- function(fecha_publicacion) {
  url <- "https://estadisticas.bcr.gob.sv/serie/ii-8-a-balanza-de-pagos-trimestral"
  cap <- bcr_capturar_xlsx(url, formula = "0")
  registrar_descarga(
    fuente = "BCR", publicacion_id = "BCR.BALANZA_PAGOS_TRIMESTRAL", url = url,
    descripcion_archivo = "balanza_pagos_trimestral", extension = "xlsx",
    contenido_crudo = cap$bytes, codigo_http = 200L,
    fecha_publicacion = fecha_publicacion, periodo_referencia_max = cap$periodo_referencia_max,
    verificacion_forma = verificacion_xlsx,
    notas_vintage = .bcr_nota_balanza_pagos_trimestral_fecha
  )
}
