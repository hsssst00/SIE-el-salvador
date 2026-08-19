# Bitácora de fuentes frágiles

Registro de comportamientos anómalos o de bloqueo encontrados al automatizar la
adquisición de cada fuente. Entregable de Fase 2 (senda §4).

## BCR — portal Livewire/Alpine.js, detección de bots confirmada

- **2026-08-18** (Claude, chat): `web_fetch` simple sin headers de navegador contra
  `estadisticas.bcr.gob.sv/serie/...` fue bloqueado ("Site blocked the request (bot
  detection)").
- **2026-08-19** (Claude Code): `httr2` con headers de navegador (User-Agent, Accept,
  Accept-Language, Referer) contra la misma URL también fue bloqueado. La respuesta llegó
  con `codigo_http = 200` pero `Content-Type: text/html` — es decir, el bloqueo no se
  manifiesta como un error HTTP sino como una página normal en lugar del `.xlsx`. La
  verificación de forma (`verificacion_xlsx`, firma ZIP "PK") habría fallado también; el
  chequeo de `Content-Type` detuvo la ejecución primero. No se guardó ningún archivo ni se
  escribió ninguna fila en el manifiesto — falló de forma visible conforme a la regla 6 de
  CLAUDE.md.
- **2026-08-19** (Claude, chat, vía Claude en Chrome — navegador real de Harold):
  investigación de la hipótesis pendiente del punto anterior. Con un interceptor de
  `fetch` puesto en la propia página y lectura directa de las solicitudes de red
  disparadas por la interfaz:
  - El botón "Descargar datos en Excel/CSV" **no golpea ningún endpoint de
    exportación**. La página carga `xlsx@0.15.1` (SheetJS) y genera el archivo `.xlsx`
    enteramente del lado del cliente, en memoria, a partir de datos ya cargados — cero
    solicitudes de red al hacer clic. La hipótesis de un "endpoint real de exportación
    de Livewire" queda **descartada por evidencia directa**: no existe tal endpoint
    porque no hay generación de archivo del lado del servidor.
  - Sí existen dos endpoints REST abiertos, sin sesión, con CORS
    (`Access-Control-Allow-Origin: *`) y rate-limit de 60/ventana (headers
    `x-ratelimit-*`): `GET /api/rangos/{id}` (años/trimestres disponibles) y
    `GET /api/serie/{id}` — singular; `/api/series/{id}` en plural da 404 (nombre del
    indicador + catálogo de variables). Ambos dan **metadatos, no valores observados**.
  - Los valores reales viajan por el protocolo interno de Livewire: `POST
    /livewire/message/vista-serie`, con cuerpo `fingerprint` + `serverMemo` (estado del
    componente, atado a la carga de página) y headers `X-CSRF-TOKEN`, `X-Livewire`,
    `X-Socket-ID`. La respuesta es ~500 KB de HTML re-renderizado (`effects.html`), no
    JSON limpio — el gráfico parsea ese HTML después. Es un protocolo con estado, no
    replicable de forma simple con un cliente sin sesión de navegador como `httr2`.
- **2026-08-19** (Claude, chat, vía Claude en Chrome — prueba end-to-end, confirmada por
  Harold): con la página recargada en limpio y sin tocar filtros, clic real en
  "Descargar datos en Excel/CSV" → "Formato Excel" produjo un archivo `.xlsx` válido en
  la máquina de Harold
  (`PIB_T._Producción_y_gasto._Índices_de_volumen_encadenados._Serie_original_(referencia_2014) (2).xlsx`
  — el sufijo "(2)" es deduplicación de Chrome por un archivo homónimo preexistente de
  una descarga manual anterior). Harold confirmó que el archivo abre correctamente y
  contiene los datos del rango por defecto (9 observaciones, 2024-1 a 2026-1). **El
  mecanismo de navegador real funciona de punta a punta.** Pendiente: no se probó
  todavía el rango histórico completo (Desde el año más antiguo disponible) — decisión
  de Harold (2026-08-19) fue documentar este hallazgo antes de seguir probando esa
  extensión.
- **Conclusión vigente:** headers de navegador por sí solos no bastan contra `httr2`
  (confirmado 2026-08-19), y no existe un endpoint estático de exportación que un script
  sin navegador pueda golpear directamente (confirmado 2026-08-19) — la única vía de
  descarga real es reproducir la interacción de la interfaz. La automatización vía
  navegador real (Cowork o Claude en Chrome) queda **validada como mecanismo**; falta
  decidir su forma operativa final (script recurrente vía Cowork, flujo
  semi-supervisado, u otra) y probar el rango histórico completo antes de considerar
  esto entregable de Fase 2 para `BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA`. Nota de
  diseño para cuando se automatice: el archivo cae en la carpeta de Descargas del
  sistema con el nombre que asigna el navegador (con deduplicación tipo "(2)" si ya
  existe uno homónimo) — `lib_adquisicion.R` va a necesitar mover/renombrar desde ahí a
  la convención `{FUENTE}_{descripcion}_{fecha}.{ext}` de la senda §3.1, no puede asumir
  que el archivo aparece ya con el nombre correcto.
