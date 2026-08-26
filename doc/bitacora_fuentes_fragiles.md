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
- **2026-08-20** (Claude Code, terminal — diagnóstico fuera del repo, no comprometido
  a `DESCRIPTION`/`renv.lock`): pregunta distinta de las pruebas anteriores. Todas las
  pruebas del 2026-08-19 usaron Cowork o Claude en Chrome — un navegador real con una
  sesión interactiva de por medio. ¿La detección de bots del BCR distingue
  específicamente esa modalidad, o bloquea cualquier automatización vía protocolo
  CDP (Chrome DevTools Protocol) sin humano ni LLM interactivo de por medio? Se probó
  la carga de la misma URL (`INDICES_VOLUMEN_ENCADENADOS_NSA`, referencia 2014) con dos
  frameworks distintos, cada uno en modo headless y headed, verificando presencia del
  texto esperado del indicador en el HTML servido:
  - **Playwright (Python 3.14, venv descartable fuera del clon del repo):** headless y
    headed, ambos HTTP 200 con el contenido real presente — no bloqueados.
  - **`chromote` (R, biblioteca de paquetes aislada, `Chrome$new()`/opción
    `chromote.headless` sobre el Chrome ya instalado en el sistema, sin tocar el
    `renv` del proyecto):** mismo resultado — headless y headed, ambos con el
    contenido real presente.

  Ninguno de los cuatro casos fue bloqueado. La detección de bots del BCR **no
  distingue Cowork/Claude en Chrome de automatización CDP genérica**, al menos para la
  carga inicial de la página — es consistente con que la señal de bloqueo sea la
  ausencia de un motor de renderizado real (lo que sí le faltaba a `httr2`), no alguna
  huella específica de las herramientas de Anthropic. **Importante — alcance limitado:**
  esta prueba solo cubrió la carga de página (`GET` + render), no el flujo completo de
  clic en "Descargar datos en Excel/CSV" → "Formato Excel" que sí se probó de punta a
  punta vía Cowork (ver entradas 2026-08-19 arriba); no se automatizaron esos clics ni
  la generación del `.xlsx` vía SheetJS con estos scripts. Pendiente antes de considerar
  esto una vía de automatización completa — **cerrado el mismo día, ver entrada
  siguiente.**

  Relevancia para ADR-009: que `chromote` replique el resultado de Playwright disuelve
  la tensión de stack que motivó la pregunta — no habría necesidad de introducir Python
  para este mecanismo si el flujo completo también funciona en R. No se agregó
  `chromote` como dependencia formal del proyecto en esta sesión; la decisión se cerró
  el mismo día en ADR-009, nota de seguimiento "mecanismo de captura para el BCR"
  (2026-08-20), que además difiere la incorporación a `DESCRIPTION`/`renv.lock` hasta el
  primer script real que lo use.
- **2026-08-20** (Claude Code, terminal — continuación del diagnóstico anterior, mismo
  día): cierra el pendiente de alcance señalado arriba. Se extendió el script de
  `chromote` al flujo completo: navegar → clic "Descargar datos en Excel/CSV" → clic
  "Formato Excel" → verificar archivo en disco, fijando `Browser$setDownloadBehavior`
  con carpeta destino (sin esto, Chrome headless descarta cualquier descarga en
  silencio, sin error visible).
  - En una corrida completa en modo headless, ambos clics resolvieron (`clic_ok`) y se
    descargó un archivo real:
    `PIB_T._Producción_y_gasto._Índices_de_volumen_encadenados._Serie_original_(referencia_2014).xlsx`,
    16 471 bytes, sin sufijo `.crdownload` residual — nombre y tamaño coherentes con
    esta serie. **El flujo de descarga completo también funciona vía CDP desatendido,
    no solo vía navegador real con sesión interactiva.**
  - Deriva de API encontrada y corregida: desde `chromote` 0.4.0, `headless` ya no es
    argumento de `Chrome$new()` (error textual: `unused argument (headless = TRUE)`);
    el modo headless se controla vía la opción global `chromote.headless`, confirmado
    leyendo el `NEWS.md` del paquete instalado — no por ensayo y error. El script
    original de este diagnóstico ya advertía que podía fallar por esto y no por bloqueo
    del BCR; así fue.
  - Inestabilidad aparte, no atribuible al BCR: dos corridas (una headed, una headless)
    fallaron con `Chromote: timed out waiting for event Page.loadEventFired` — carrera
    conocida, documentada en el propio `NEWS.md` de `chromote` (0.5.1 agregó `$go_to()`
    específicamente para reemplazar el patrón `Page$navigate()` +
    `Page$loadEventFired()` por ser propenso a esa carrera). No se investigó más a
    fondo porque no es evidencia de bloqueo: la corrida que evitó la carrera se
    completó limpia con archivo real.
  - Nota de entorno para cuando esto se formalice: el binario CRAN de `chromote` 0.5.1
    para Windows está compilado bajo R 4.5.3; la máquina de prueba tiene R 4.5.1. Ese
    desfase produjo *segfaults* (no errores de R) en un par de llamadas de
    introspección no relacionadas con el flujo (`args()` sobre el método
    `Chrome$new`, `tools::Rd_db()`) y una vez en una invocación `-e` inline — nunca en
    el script sustantivo corrido como archivo `.R` (limpio en dos corridas). Antes de
    construir esto como script real, conviene resolver el desfase de versión.
  - No se comprometió nada: script vive fuera del repo (carpeta temporal), no se
    agregó `chromote` a `DESCRIPTION`/`renv.lock`.
- **2026-08-24** (Cowork, sobre la página en vivo; re-corrido y verificado en vivo el mismo
  día por Claude Code, ver abajo): caracterización fina del mecanismo `vista-serie`, que
  resuelve el pendiente "combinar rango completo y desagregación en una sola descarga".
  Hallazgos completos en `doc/captura_bcr_livewire_hallazgo.md`:
  - El exportador `html_table_to_excel()` lee **del DOM** (`#tablaVariables` +
    `#tablaValores`), no de una variable JS. Las dos tablas solo alcanzan su tamaño
    completo —las 29 variables con datos— cuando el componente está en **modo tabular**
    (`data.tabular === true`, vía `cambiarTipo()`) **y** se ejecutó `filtrar` con el rango
    completo. En modo gráfico `filtrar` renderiza solo la variable graficada (~200
    celdas): eso explica las capturas headless truncadas previas. **Consecuencia de
    diseño:** basta poner el componente en modo tabular antes de `filtrar` para que
    "Formato Excel" exporte todas las variables de una sola descarga — no hace falta
    tildar los checkboxes de enfoque (`vars`/`variable[]`) que la exploración del
    2026-08-19 usaba.
  - API de control de Livewire **v2**: usar `window.livewire.components.componentsById[<id>]`;
    `window.livewire.find(id)` devuelve un **Proxy** en el que cualquier propiedad
    aparece como función (falso positivo garantizado). `set(nombre, valor, true)` =
    diferido; los cinco parámetros del filtro (`formula`, `yInicio`, `nInicio`, `yFin`,
    `nFin`) viajan juntos con la siguiente petición, así que el orden estricto de los
    `<select>` deja de importar.
  - `filtrar` en modo tabular tarda entre ~2 y ~30 s según la corrida: esperar por
    **predicado** (contador de `message.processed` + `messageInTransit === null` +
    `#tablaValores` con el nº de columnas esperado y ≥1 fila de datos de ese ancho),
    nunca por `Sys.sleep()`.
  - El rango completo se deriva de `GET /api/rangos/{idPublic}` **invocado con `fetch()`
    desde la propia página** (hereda cookies; el endpoint devuelve 403 a clientes
    externos como `curl`).
  - Reconciliación pendiente (Fase 3, no bloquea la captura): el portal sirve **29**
    variables con datos para la serie de índices NSA (31 filas de la tabla − 2
    encabezados de sección vacíos); `03_series.csv` tiene **28** filas para NSA y 28 para
    SA, pero **29** para NOMINAL. Las publicaciones de volumen quedan una fila cortas
    respecto de lo que el portal sirve y de lo que NOMINAL ya tiene — candidata plausible
    del faltante: variación de existencias, que el portal declara explícitamente que no
    publica en índices de volumen encadenados (solo la FBKF). Cuadrar antes del mapeo de
    `fuente_celda`.
  - **Re-corrida en vivo por Claude Code (mismo día, sesión separada):** el hallazgo de
    Cowork no se aceptó sin verificar — se reprodujo la coreografía completa contra la
    misma URL (idPublic 210, NSA) antes de escribir el `bcr.R` final. Esa corrida
    **corrigió un dato del handoff original:** `html_table_to_excel(type)` usa `type`
    como la extensión literal del archivo (`XLSX.writeFile(wb, titulo + '.' + type)`) —
    el valor correcto es `"xlsx"`, no `"excel"` como se había asumido sin verificar.
    Confirmado además, sobre la publicación real: 29 variables × 85 periodos (2005-T1 a
    2026-T1); descarga headless capturada sin `.crdownload` residual (92 137 bytes,
    mismo tamaño que el vintage manual de 2026-08-06); ningún campo de
    `component.data` ni del DOM expone una fecha de publicación parseable (solo el
    período de referencia, ej. `"I 2026"`) — confirma que `fecha_publicacion` sigue
    siendo argumento explícito de quien opera la captura; `chromote` 0.5.1 headless
    funciona limpio bajo R 4.6.1 en el flujo sustantivo (el segfault ya documentado el
    2026-08-20 se reprodujo, pero confinado a una llamada de introspección ajena al
    flujo, nunca en la navegación/evaluación real).
  - **Cierre de I1:** con `src/adquisicion/bcr_captura.R` y el `bcr.R` reescritos sobre
    estos hallazgos, `descargar_bcr_pib_nsa("2026-06-01")` y
    `descargar_bcr_pib_sa("2026-06-01")` corridos de punta a punta contra el portal en
    vivo devolvieron **"sin cambios respecto de la última captura (2026-08-06)"** para
    ambas publicaciones — el `sha256_norm` de la descarga automatizada coincide con el
    del vintage capturado manualmente, pese a que el `sha256` crudo difiere (esperado,
    ver F1: el empaquetado ZIP no es determinista). La automatización 1a reproduce el
    `.xlsx` publicado hasta la identidad de vintage.

- **Conclusión vigente (actualizada 2026-08-20, tras la decisión de ADR-009):** headers de
  navegador por sí solos no bastan contra `httr2` (confirmado 2026-08-19); no existe un
  endpoint estático de exportación que un script sin navegador pueda golpear directamente
  (confirmado 2026-08-19); la única vía de descarga real es reproducir la interacción de la
  interfaz. Esa vía está probada de punta a punta en dos modalidades: vía navegador real con
  sesión interactiva (Cowork o Claude en Chrome), con rango histórico completo de la serie
  agregada y, por separado, con desagregación por enfoque de producción/gasto (ambas
  2026-08-19); y vía automatización CDP desatendida, que pasa sin bloqueo tanto en Python
  (Playwright) como en R (`chromote`), esta última extendida al flujo completo de clics y
  generación del `.xlsx` vía SheetJS (2026-08-20).
  **La forma operativa ya no está abierta.** ADR-009, nota de seguimiento "mecanismo de
  captura para el BCR" (2026-08-20), fija `chromote` —automatización CDP desatendida en R,
  headless— como el mecanismo de captura para las publicaciones del BCR servidas desde
  `estadisticas.bcr.gob.sv`, y deja el flujo semi-supervisado como alternativa de respaldo,
  no como camino principal. Lo que sigue abierto es de ejecución, no de elección: resolver
  el desfase de versión (binario CRAN de `chromote` 0.5.1 compilado bajo R 4.5.3, máquina de
  prueba en R 4.5.1) y usar `$go_to()` en lugar de `Page$navigate()` +
  `Page$loadEventFired()` —ambas condición previa, según ADR-009, a que el script real entre
  a `src/adquisicion/`—; combinar rango histórico completo y desagregación en una sola
  descarga; y probar la desagregación por actividad económica individual. El uso de este
  mecanismo queda acotado por la regla 9 de `CLAUDE.md`: captura al ritmo real de
  publicación de la fuente, nunca recolección de volumen.
  Notas de diseño para cuando se automatice: (a) el archivo cae en la carpeta de
  Descargas del sistema con el nombre que asigna el navegador, con deduplicación tipo
  "(2)"/"(3)" si ya existen homónimos — `lib_adquisicion.R` va a necesitar
  mover/renombrar desde ahí a la convención `{FUENTE}_{descripcion}_{fecha}.{ext}` de la
  senda §3.1, no puede asumir que el archivo aparece ya con el nombre correcto; (b) el
  piso real de cobertura de este catálogo específico es 2005, no 1990 — ver nota de
  reconciliación arriba.

- **2026-08-25** (Claude Code, aplicando handoff): decisión firme registrada — la serie
  retropolada `BCR.PIB_T.SERIE_RETROPOLADA_1990_2005` **queda de captura manual y fuera de
  `make raw`**. No es una serie del componente `vista-serie`: es un `.xlsx` estático servido
  desde `www.bcr.gob.sv/documental/`, una serie histórica **cerrada** (termina en 2005-T4, no
  genera vintages nuevos), capturada una sola vez el 2026-08-06. Su automatización desatendida
  queda excluida por la regla 9 de `CLAUDE.md`. `make raw` (`scripts/verificar_l0.R`) la excluye
  explícitamente; su integridad se verifica por la vía cruzada offline de
  `scripts/check_l0_integrity.R`, no por re-captura en vivo.
- **2026-08-25** (Claude Code, puerta de confirmación de `descargar_bcr_pib_nominal()`):
  `formula="0"` confirmado correcto para la publicación en precios corrientes — la primera
  corrida contra el portal en vivo colgó, no dio un hash distinto. Diagnóstico aislado del
  paso que cuelga (disparo de `html_table_to_excel()`, invocado directamente vía
  `b$Runtime$evaluate` con `timeout_` explícito): con más tiempo, la llamada sí retorna y el
  `.xlsx` resultante reproduce exactamente `sha256_norm =
  f6bcfcac851f38f5e3645c6f82d99d5c387196f2f2f7e9fdfd3d12d37c3a395b` (el del vintage manual
  v2026-06). Causa raíz: el timeout por defecto de `chromote` para el comando CDP
  `Runtime.evaluate` es insuficiente para tablas grandes — SheetJS serializa el `.xlsx` de
  forma síncrona en el hilo de JS, bloqueando la respuesta a CDP más tiempo del que NSA/SA
  (29 variables) necesitan, pero no NOMINAL (30 variables). No es un problema del BCR ni de
  la fórmula: `bcr_capturar_xlsx()` (`src/adquisicion/bcr_captura.R`) ahora pasa
  `timeout_s = 300` explícito solo en el paso de disparo del exportador; NSA/SA no cambian de
  comportamiento (ya completaban por debajo del default). Confirmado con `make raw`
  (`scripts/verificar_l0.R`) en 3/3 PASS tras el ajuste.

## BCR — Reservas Internacionales y Liquidez en Moneda Extranjera: mecanismo distinto de `vista-serie`

- **2026-08-26** (Claude Code, sondeo en vivo, handoff Fase 1 Bloque 4): la publicación
  "Reservas Internacionales y Liquidez en Moneda Extranjera" **no** vive en el
  componente `vista-serie` del portal. El único enlace encontrado en
  `oferta-estadistica` para este nombre
  (`https://estadisticas.bcr.gob.sv/serie/reservas-internacionales-y-liquidez-en-moneda-extranjera`)
  devuelve **HTTP 500 (Server Error)** — enlace roto en el propio portal, confirmado
  cargando la página en vivo con `chromote` (título de la página servida: "Server
  Error", cuerpo "500 SERVER ERROR").
  - Siguiendo el enlace real que sí resuelve (`enlaces_reservas` desde
    `cartelera_es.html`, texto "Información sobre Reservas Internacionales y Liquidez
    en Moneda Extranjera" → `https://www.bcr.gob.sv/documental/Inicio/busqueda/194`):
    la fuente real de esta variable es una **fila dentro de la Cartelera Electrónica
    del Boletín de Normas de Divulgación del FMI** (`cartelera_es.html`), no una
    publicación `vista-serie` independiente. Confirmado navegando la cartelera en
    vivo: es una página HTML estática (6 tablas, una por sección: Sector Real, Fiscal,
    Monetario y Financiero, Externo, Población — sin componente Livewire), con
    columnas "Última información" y "Período anterior" — es decir, **valores
    puntuales de snapshot, no una serie histórica completa** por fila.
  - La página sí tiene un único botón "Documento de Excel"
    (`https://estadisticas.bcr.gob.sv/descargar-cartelera-xlsx/es`), pero descarga
    **toda la cartelera** (decenas de variables de las 5 secciones, cada una con solo
    último dato + dato anterior), no un archivo específico de esta fila. Capturar esta
    variable con el mecanismo actual de L0 (una publicación = una URL = un `.xlsx` con
    serie completa) no aplica sin antes decidir cómo tratar "una fila de una cartelera
    compartida" como unidad de captura — no es un caso cubierto por `bcr_captura.R`.
  - **No se escribe YAML en `01_publicaciones` para esta variable todavía**: falta
    decidir el mecanismo de captura (¿se cataloga la cartelera completa como una
    publicación de metadata operativa, como ya se hizo con el calendario de
    divulgación en `doc/calendario_divulgacion_bcr.md`? ¿se captura solo la fila
    relevante por lectura del HTML, renunciando a un `.xlsx` de origen?) antes de
    prometer una publicación que hoy no sabemos cómo traer a L0.
