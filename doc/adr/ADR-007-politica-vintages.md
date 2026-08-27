# ADR-007: Política de versiones de publicación (vintages)

**Estado:** Cerrado
**Fecha:** 2026-08-06
**Relacionado con:** ADR-001 (vintage de referencia), ADR-003 (alcance de reconstrucción retrospectiva)

## Contexto

El PIB trimestral se revisa. Si los modelos se evalúan contra la serie revisada más reciente, se les entrega información que no existía en el momento en que el pronóstico habría sido emitido — el resultado deja de ser replicable en operación real y sobreestima la precisión alcanzable. Identificada como el aporte más original y publicable del proyecto: no existe para El Salvador un registro de este tipo en la literatura local.

## Alternativas consideradas

- **(a) Vintages solo prospectivos:** el sistema captura y archiva cada nueva publicación desde el inicio del proyecto. Factible con certeza, pero deja fuera toda la historia de revisiones previa al proyecto.
- **(b) Reconstrucción retrospectiva exhaustiva:** rescate de publicaciones históricas (boletines, revistas trimestrales, Wayback Machine, publicaciones de SECMCA/FMI). Alto costo, resultado incierto y probablemente incompleto — coincide con el riesgo de mayor probabilidad e impacto identificado en la gestión de riesgos del proyecto (alcance excesivo para un primer proyecto académico).
- **(c) Híbrido:** (a) como compromiso firme, (b) como esfuerzo de mejor empeño con cobertura documentada explícitamente.

## Decisión

- **Estrategia: híbrida (c).** Captura prospectiva firme desde ya. Reconstrucción retrospectiva de mejor empeño, con la cobertura efectivamente lograda documentada sin importar cuán parcial resulte.
- **Alcance acotado de la reconstrucción retrospectiva:** limitada a la vigencia del SCN 2008. No se persigue reconstruir vintages publicados bajo metodologías de cuentas nacionales anteriores al empalme (ver ADR-003). Esto alinea el esfuerzo de reconstrucción con la variante de robustez de estimación sobre el tramo homogéneo, y acota explícitamente el riesgo de alcance excesivo.
- **Diseño de base:** bitemporal desde el primer día (cada observación indexada por período de referencia y por fecha de publicación), con independencia de cuánto se logre reconstruir retrospectivamente. Añadir esta dimensión después obligaría a rehacer el modelo de datos completo.
- **Granularidad del registro:** cada evento de publicación se archiva en L0 y recibe un `vintage_id` en el catálogo `08_vintages`. No se requiere una regla adicional de deduplicación: el campo `alcance_revision`, combinado con la comparación de checksum contra el manifiesto de L0 (§3.1), determina si hubo cambio real de contenido respecto del vintage anterior.

## Consecuencias

- Habilita la evaluación en tiempo real (§5.5 de la senda metodológica) y la cuantificación de la magnitud y el sesgo de las revisiones del PIB salvadoreño como resultado publicable independiente.
- Resuelve por extensión el sub-punto "vintage de referencia" de ADR-001: evaluación contra el vintage disponible en cada origen de pronóstico como criterio primario.
- Cada publicación del BCR no archivada desde hoy es información irrecuperable — la captura prospectiva debe iniciar de inmediato, incluso antes de que exista automatización (Fase 2). Hasta entonces, la captura es manual.

## Nota de alcance — vintages de predictores externos (2026-08-12)

El inventario de Fase 1 identificó dos fuentes de *vintages* que este ADR no contempló, porque al redactarse solo estaba a la vista el caso del BCR:

- **ALFRED**, el archivo de versiones del Federal Reserve Bank of St. Louis, que expone el historial de revisiones de las series estadounidenses y un *endpoint* de fechas de revisión por serie.
- **Los vintages históricos del World Economic Outlook del FMI**, publicados dos veces al año, cada uno con su propio conjunto de proyecciones.

**El diseño de datos no requiere cambio alguno.** En `08_vintages`, el `vintage_id` está ligado a `publicacion_id`, que es genérico: un *vintage* del WEO o de una serie de FRED entra en el catálogo sin tocar el esquema. La advertencia de la senda metodológica §2 (D7) sobre el costo de añadir tarde la dimensión de *vintage* no aplica acá, porque la dimensión ya existe y ya es general.

**Asimetría que sí cambia la prioridad, y que este ADR trataba de forma uniforme por no haberla visto:**

| | Vintages del BCR | Vintages de ALFRED y del WEO |
|---|---|---|
| Recuperación | Irrecuperables. Cada publicación no archivada en su momento desaparece de forma permanente. | Recuperables a demanda desde la API, en cualquier momento futuro. |
| Urgencia | Máxima. La captura prospectiva debe ocurrir aunque no exista automatización. | Ninguna. Postergarlos no cuesta información. |

Este ADR trata todos los *vintages* como eventos que hay que capturar al pasar, lo cual es correcto para el BCR y no lo es para las fuentes internacionales. La captura prospectiva del BCR conserva su carácter de compromiso firme e inmediato, sin cambio.

**Decisión de alcance.** La incorporación de *vintages* de predictores externos —y con ella la evaluación en tiempo real de los predictores, no solo de la variable objetivo (senda metodológica §5.5)— queda **fuera del núcleo mínimo viable**. Corresponde a la extensión 2 de la senda §9 ("reconstrucción retrospectiva de vintages y estudio de revisiones"), explícitamente clasificada allí como extensión y no como compromiso firme.

**Observación de diseño que sí conviene aprovechar antes de Fase 2.** ALFRED es una implementación en producción del mismo diseño bitemporal que este proyecto construye. Revisar cómo modela el concepto de período en tiempo real tiene costo bajo y puede anticipar casos que el modelo propio no resuelva. Es una revisión conceptual de referencia, no una tarea de adquisición de datos, y no reabre la decisión de alcance de esta nota.

## Nota de alcance — vintages de la variable objetivo vía el FMI (2026-08-13)

Esta nota complementa la del 2026-08-12 y registra un hallazgo verificado que, a primera vista, podría parecer que contradice la premisa de este ADR. No la contradice, pero acota su alcance con precisión y conviene dejar el análisis asentado.

**El hallazgo.** El dataflow QNEA del FMI implementa el parámetro `asOf` de SDMX 3.0, que devuelve el estado de los datos en un momento dado. Para El Salvador el mecanismo funciona: se midieron revisiones del PIB trimestral entre estados sucesivos, con un gradiente monótono ordenado por antigüedad del trimestre —desde 3e-10 de diferencia relativa en 2010-Q1 hasta 1.5% en 2023-Q4—, que es el patrón esperado de revisión de cuentas nacionales. Todo verificado por consulta directa con controles de reproducibilidad byte a byte. El detalle completo está en `catalogos/01_publicaciones/FMI.QNEA.yaml`.

**Por qué la premisa de este ADR sale intacta.** Este ADR sostiene que la reconstrucción retrospectiva de *vintages* del PIB salvadoreño es probablemente inviable, y acota el esfuerzo a la captura prospectiva. Tres hechos verificados confirman esa premisa en vez de refutarla:

1. **El archivo arranca el 2025-03-29 y ese primer estado es una carga de plataforma, no una publicación.** La misma fecha frontera, al día, aplica a Estados Unidos y a México, cuyas series arrancan en 1950 y 1993 respectivamente. Tres países con coberturas históricas incomparables saltando a datos el mismo día no es un calendario de publicación; es un volcado. La fecha además cayó en sábado.

2. **El archivo no es monótono.** El estado del 2025-06-01 contiene siete observaciones menos que el del 2025-03-29 —faltan los cuatro trimestres de 2022 y el borde derecho retrocede tres trimestres—, y el incidente afecta a varias series de El Salvador pero no a Estados Unidos ni a México. Se resolvió entre agosto y octubre de 2025. Un archivo del que desaparecen datos y luego reaparecen no es un registro fiel de publicaciones.

3. **`asOf` refleja el estado de la base del FMI, no el calendario del BCR.** El punto 2 lo demuestra: hubo estados de la base del FMI que no corresponden a ninguna publicación del BCR.

En síntesis: no hay nada que reconstruir hacia atrás. La ventana es de diecisiete meses, su extremo inicial es un artefacto de migración, y contiene al menos un estado corrupto. **La decisión de este ADR no se modifica.**

**Lo que sí se corrige de la nota del 2026-08-12.** Aquella nota clasificó los *vintages* de fuentes internacionales como "recuperables a demanda, sin urgencia", por contraste con los del BCR, que son irrecuperables. Esa clasificación es correcta pero incompleta en un punto: nada garantiza que el FMI conserve indefinidamente sus registros de validez, ni que sobrevivan a la próxima migración de plataforma —y el hallazgo del punto 1 muestra que las migraciones de plataforma del FMI sí destruyen historial anterior, porque el archivo actual no contiene nada previo al volcado de marzo de 2025.

Esto no convierte el asunto en urgente: no hay indicio de poda activa, y el archivo crece con el tiempo. Pero "recuperable a demanda" debe leerse como "recuperable mientras la plataforma actual siga en pie", no como una garantía permanente.

**Uso admisible y uso inadmisible.** Queda registrado, para que no haya que redescubrirlo:

- **Inadmisible:** construir orígenes de pronóstico en tiempo real (senda metodológica §5.5) a partir de este archivo. Un conjunto de datos en tiempo real presupone información que crece de forma monótona; el incidente de 2022 rompe ese supuesto e introduciría un artefacto de plataforma en la evaluación predictiva.
- **Admisible:** medir la magnitud de las revisiones del PIB salvadoreño, que la senda §2 (D7) plantea como resultado de interés propio. Con un archivo de diecisiete meses y un estado corrupto no alcanza para un resultado publicable, pero es la primera medición directa de una revisión que el proyecto tiene y fija un orden de magnitud.

**Sin cambio en la captura prospectiva del BCR.** Sigue siendo compromiso firme e inmediato, sin alteración. Este hallazgo no provee un sustituto ni reduce su urgencia.

## Nota de seguimiento — formato del identificador de vintage (2026-08-20)

**Disparador.** El primer borrador de `src/adquisicion/lib_adquisicion.R` derivaba el
`vintage_id` de `Sys.Date()` —la fecha de descarga— mientras las cuatro filas ya existentes de
`catalogos/08_vintages.csv` lo derivan de la fecha de publicación de la fuente. Hallazgo I2 de
la auditoría del 2026-08-20.

**Decisión: `{publicacion_id}.v{AAAA-MM}`, con `AAAA-MM` = mes de la fecha de publicación de la
fuente.** Dos razones. La primera es de definición: la senda §3.2 modela el vintage como "un
hecho de publicación con fecha, documento fuente y alcance", no como un hecho de descarga; un
identificador que codifique la fecha de descarga nombraría algo que la entidad no es. La segunda
es de no redundancia (§10.6): la fecha de descarga ya vive en `fecha_descarga` del manifiesto de
L0, y no necesita un segundo domicilio dentro de una clave.

**Consecuencias.**

- `fecha_publicacion` pasa a ser obligatoria en la práctica para `registrar_descarga()`: la
  función falla de forma visible si falta o no es ISO (regla 6 de `CLAUDE.md`). Si la fuente no
  la declara de forma parseable, quien llama pasa una aproximación explícita y anota de qué se
  deriva. El caso ya tiene precedente asentado:
  `BCR.PIB_T.SERIE_RETROPOLADA_1990_2005.v2019-03` usa la fecha de última modificación del
  archivo y lo declara en sus notas.
- La granularidad mensual admite colisión si una misma publicación se publica dos veces en el
  mismo mes. No se cambia la granularidad por un caso que no se ha dado; se agrega una
  verificación que falla si el `vintage_id` ya existe, en lugar de escribir un duplicado de
  clave (senda §3.5: los duplicados fallan, no advierten).
- Dos de las cuatro filas existentes se normalizan: la cadena base pasa a ser el
  `publicacion_id` completo. El sufijo `-SA` de una de ellas desaparece — existía porque la
  cadena base omitía la variante, y desde M3 (2026-08-08) cada variante tiene `publicacion_id`
  propio. Normalizarlas completa M3; no revierte nada. Las otras dos ya cumplían la convención.

**Lo que esta nota no cambia.** Ninguna decisión de la sección Decisión de este ADR: el diseño
bitemporal, la política híbrida (a)+(b) y el alcance del rescate retrospectivo quedan como
están. Esto es formato de identificador, no política de vintages.

## Nota de seguimiento — checksum de integridad vs. de identidad de vintage (2026-08-21)

**Disparador.** La decisión de este ADR (sección Decisión, "Granularidad del registro") afirma
que "la comparación de checksum contra el manifiesto de L0 (§3.1) determina si hubo cambio real de
contenido respecto del vintage anterior". La prueba F1 (2026-08-21, registrada en
`src/adquisicion/README.md` §2.1 y §2.3) estableció que esa afirmación no se sostiene para las
publicaciones del BCR servidas por el portal: el `.xlsx` que genera SheetJS no es determinista
byte a byte —el empaquetado ZIP varía entre descargas del mismo dato— aunque su contenido
descomprimido sea idéntico. Un checksum sobre el archivo crudo reportaría vintage nuevo en cada
corrida.

**Verificación, no inferencia.** Se descargó dos veces la misma serie sin cambio en la fuente. Las
nueve entradas del ZIP resultaron byte-idénticas entre descargas; el SHA-256 del archivo completo,
distinto; el SHA-256 del contenido normalizado (entradas ordenadas por nombre, concatenadas
descomprimidas), idéntico. La causa quedó acotada al contenedor, no al dato. Se descartó
explícitamente la hipótesis de timestamp: las fechas internas de las entradas del ZIP coincidían
al segundo en ambas descargas.

**Decisión: dos checksums, no uno.** El manifiesto de L0 y `08_vintages` llevan desde ahora dos
campos:

- `sha256` — del archivo crudo tal como se descargó. Responde "¿el archivo en disco está íntegro,
  sin corrupción?". Es el que ya existía; su semántica no cambia.
- `sha256_norm` — del contenido normalizado. Responde "¿este contenido es un vintage nuevo respecto
  del anterior?". Es el que compara el mecanismo de detección de vintage.

Para fuentes cuyo crudo ya es determinista (las API que guardan `.json`: FMI, FRED, Banco Mundial),
`sha256_norm` coincide con `sha256`. Solo divergen en fuentes tipo contenedor (el `.xlsx` del BCR).
El campo se llena siempre, sin casos especiales.

**Consecuencias.**

- La frase de la sección Decisión se lee, a partir de esta nota, referida a `sha256_norm`, no al
  checksum crudo. No se reescribe la Decisión —sigue siendo válida en su intención, que es detectar
  cambio real de contenido— pero queda anotado que el checksum que la cumple es el normalizado.
- Cambia el esquema de dos artefactos: `08_vintages` (esquema `cerrado`, `datapackage.json`
  actualizado) y el manifiesto de L0 (columna agregada, `tests/test-catalogs.R` actualizado). Es
  cambio de esquema, no de política de vintages: el diseño bitemporal y la estrategia híbrida no se
  tocan.
- Las cuatro filas ya capturadas reciben su `sha256_norm` calculado sobre el archivo real. El
  `sha256` crudo de esas filas no se recalcula ni se toca — la integridad histórica se conserva.

**Lo que esta nota no cambia.** Ninguna otra decisión de este ADR. La normalización es una
operación de lectura para computar un hash estable; no altera el archivo de L0, que se sigue
archivando crudo, tal como cae (con la salvedad de encuadre de `src/adquisicion/README.md` §2.1:
para esta fuente, "crudo" ya es un artefacto del cliente, no del publicador).

## Nota de seguimiento — granularidad de `publicacion_id` para fuentes por-serie (2026-08-27)

**Disparador.** Al ejecutar el primer script de adquisición FRED, `FRED.INDICADORES_MENSUALES_EEUU`
—una ficha paraguas sobre 4 series (`INDPRO`, `PAYEMS`, `UNRATE`, `CPIAUCSL`)— produjo
una colisión de `vintage_id`: las 4 series, capturadas el mismo día, con observación más
reciente publicada el mismo mes, derivan el mismo `vintage_id =
{publicacion_id}.v{AAAA-MM}` (nota del 2026-08-20 de este ADR). La clave asumía
implícitamente un `publicacion_id` = un flujo de publicación con un solo calendario de
divulgación — supuesto válido para el BCR (una página `vista-serie` por publicación) y
para `FRED.BEA_PIB_EEUU` (una serie, `GDPC1`), pero no para una ficha que agrupa varias
series con calendarios de divulgación independientes.

**Decisión: un `publicacion_id` por serie, cuando la fuente publica por serie con
fechas de tiempo real nativas por serie.** FRED es ese caso — cada `series_id` es su
propio endpoint, su propio calendario, y trae `realtime_start` nativo (concepto
bitemporal propio de FRED/ALFRED, no sintetizado). Se modela `FRED.INDPRO`,
`FRED.PAYEMS`, `FRED.UNRATE`, `FRED.CPIAUCSL` como publicaciones independientes,
plano `FRED.<SERIES_ID>` — el `series_id` de FRED es ya el identificador canónico y
estable de esta fuente. `FRED.BEA_PIB_EEUU` no se toca (1:1 con `GDPC1`, decisión de
Harold de no renombrar). `FRED.INDICADORES_MENSUALES_EEUU.yaml` se conserva,
re-encuadrada como ficha de familia/contexto — deja de ser objetivo de captura.

**Consecuencias.** La gramática de `vintage_id` (nota del 2026-08-20) no cambia —
sigue siendo `{publicacion_id}.v{AAAA-MM}`; lo que cambia es la granularidad de
`publicacion_id` para fuentes de este tipo. `registrar_descarga()` y
`check_l0_integrity.R` no requieren cambios (tratan `vintage_id` como cadena opaca).
Regla hacia adelante: al catalogar una fuente nueva de API, si publica por serie con
calendario propio por serie, usar un `publicacion_id` por serie desde el inicio — no
esperar a la primera colisión para corregirlo, como pasó acá.
