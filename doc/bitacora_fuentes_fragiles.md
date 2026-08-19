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
  mecanismo de navegador real funciona de punta a punta.**
- **2026-08-19** (Claude, chat, vía Claude en Chrome — prueba de rango histórico
  completo, confirmada por Harold): decisión de Harold fue documentar primero y recién
  después probar la extensión al rango completo; esta entrada cierra ese pendiente.
  Lectura directa de las opciones reales del `<select>` "Desde" (no asumida): el año más
  antiguo disponible en este catálogo (`INDICES_VOLUMEN_ENCADENADOS_NSA`, serie
  referencia 2014) es **2005**, no 1990 — a diferencia de la cobertura 1990-Q1 que D3
  documenta para la serie retropolada (`BCR.PIB.VOL.NSA.Q.RETRO`). Son publicaciones
  distintas con coberturas distintas; no asumir que esta serie de índices por
  referencia 2014 alcanza 1990 solo porque otra publicación del BCR sí lo hace —
  **pendiente de reconciliar contra `03_series.csv`/`empalme_cuentas_nacionales.md` si
  esta serie específica termina siendo la que se usa como insumo.** Con el filtro fijado
  en 2005-I a 2026-I, "Buscar" actualizó el gráfico a 85 observaciones trimestrales
  (2005-Q1 a 2026-Q1 — aritmética exacta: 21 años × 4 + 1), confirmado leyendo
  `chart1.w.globals` en la propia página, no por inspección visual. El clic subsiguiente
  en "Formato Excel" produjo un tercer archivo en la máquina de Harold
  (sufijo "(3)", mismo patrón de deduplicación de Chrome) que Harold confirmó contiene
  las 85 observaciones completas.
- **Precisión sobre el alcance de las dos primeras pruebas, y prueba de desagregación
  (Harold indica el mecanismo; Claude, chat, lo verifica directamente, 2026-08-19):**
  ninguna de las dos descargas anteriores tocó selección de variables — ambas
  descargaron **la serie agregada** (el índice total del PIB). Harold señaló que la
  desagregación por enfoque no se controla desde el panel "Filtro de Gráfica" (vista
  Gráfica) sino desde la vista **"Tabla de Datos"**, marcando ahí los checkboxes de los
  dos enfoques de la cuenta. Verificado directamente, no solo tomado como dato: en la
  vista "Tabla de Datos" el DOM tiene **dos juegos de checkboxes por concepto** — uno
  con `wire:model.defer="filtroVariables"` (control de un solo valor, ligado a la
  gráfica) y otro con `wire:model.defer="vars"` y `name="variable[]"` (selección
  múltiple real, valores numéricos por variable — ej. `17269` = "Enfoque de la
  producción", `17292` = "Enfoque del gasto"). Marcar ambos checkboxes del segundo juego
  y aplicar con el botón "Filtrar" **de ese formulario** (distinto del "Filtrar" del
  panel "Filtro de Gráfica", aunque tienen el mismo texto) y luego clic en "Formato
  Excel" produjo un cuarto archivo que Harold confirmó **viene desagregado** (múltiples
  columnas/filas por concepto), a diferencia de los dos anteriores. **Queda confirmado,
  no solo teorizado:** el mismo mecanismo de navegador real (generación client-side vía
  SheetJS) sirve tanto para la serie agregada como para la desagregación por enfoque de
  producción y de gasto — relevante para cuando se retome el enfoque *bottom-up* (senda
  §9, extensión 3). No probado todavía: desagregación a nivel de actividad económica
  individual (las filas "A. Agricultura...", "B. Explotación de minas...", etc., más
  allá de los dos enfoques agregados) ni combinación con el rango histórico completo en
  la misma descarga.
- **Conclusión vigente:** headers de navegador por sí solos no bastan contra `httr2`
  (confirmado 2026-08-19); no existe un endpoint estático de exportación que un script
  sin navegador pueda golpear directamente (confirmado 2026-08-19); la única vía de
  descarga real es reproducir la interacción de la interfaz, y esa vía **ya se probó de
  punta a punta con el rango histórico completo de la serie agregada, y por separado con
  desagregación por enfoque de producción/gasto** (ambas confirmadas 2026-08-19 — falta
  combinar ambas pruebas en una sola descarga y probar desagregación por actividad
  económica individual). La automatización vía navegador real (Cowork o Claude en
  Chrome) queda **validada como mecanismo para lo relevante de Fase 2**; falta decidir
  su forma operativa final (script recurrente vía Cowork, flujo semi-supervisado, u
  otra) antes de considerar esto entregable de Fase 2 para
  `BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA`.
  Notas de diseño para cuando se automatice: (a) el archivo cae en la carpeta de
  Descargas del sistema con el nombre que asigna el navegador, con deduplicación tipo
  "(2)"/"(3)" si ya existen homónimos — `lib_adquisicion.R` va a necesitar
  mover/renombrar desde ahí a la convención `{FUENTE}_{descripcion}_{fecha}.{ext}` de la
  senda §3.1, no puede asumir que el archivo aparece ya con el nombre correcto; (b) el
  piso real de cobertura de este catálogo específico es 2005, no 1990 — ver nota de
  reconciliación arriba.
