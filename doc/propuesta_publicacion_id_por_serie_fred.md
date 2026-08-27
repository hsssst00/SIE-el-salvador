# Propuesta — un `publicacion_id` por serie de FRED

**Estado:** propuesta, pendiente de revisión (Claude chat) antes de implementar.
**Fecha:** 2026-08-27.
**Disparador:** bloqueo de colisión de `vintage_id` al ejecutar el handoff de Fase 2
(primer script de adquisición FRED, 5 series). Reportado por Claude Code; el handoff
pedía explícitamente no resolverlo con un parche improvisado ni repitiendo la fecha
sintética que se usó para UT.
**Decide, si se aprueba:** una nota de seguimiento en `doc/adr/ADR-007-politica-vintages.md`
(mismo peso que las notas del 2026-08-20 y 2026-08-21), no un ADR nuevo.

---

## 1. El problema

`registrar_descarga()` deriva `vintage_id = {publicacion_id}.v{AAAA-MM}`, con `AAAA-MM`
tomado de `fecha_publicacion` (ADR-007, nota del 2026-08-20). La clave asume **un
`publicacion_id` = un flujo de publicación con un solo calendario de divulgación**.

La nota del 2026-08-12 de ADR-007 lo razonó así de forma expresa: *"un vintage … de una
serie de FRED entra en el catálogo sin tocar el esquema"* — asumiendo *una serie de
FRED ↔ un `publicacion_id`*.

`FRED.INDICADORES_MENSUALES_EEUU` rompe ese supuesto. Es una ficha paraguas sobre 4+
series (`INDPRO`, `PAYEMS`, `UNRATE`, `CPIAUCSL`, e índices de precios de importación y
exportación), cada una un flujo de publicación independiente:

- llamada propia a `fred/series/observations` (el endpoint es por `series_id`);
- calendario de divulgación propio (BLS publica empleo el primer viernes; IPC a
  mediados de mes; la Fed el G.17; etc.);
- `realtime_start` nativo propio por observación — el concepto bitemporal nativo de
  FRED/ALFRED.

Las 4 series mensuales, capturadas hoy (2026-08-27), tienen su observación más reciente
en julio 2026, publicada en agosto 2026 → `realtime_start` de las 4 cae en `2026-08` →
las 4 derivan el mismo `vintage_id`: `FRED.INDICADORES_MENSUALES_EEUU.v2026-08`. La 1.ª
llamada registra; la 2.ª/3.ª/4.ª fallan en el Paso 3b de `registrar_descarga()`
(`vintage_id` ya existe con `sha256` distinto). `GDPC1` no colisiona: su `publicacion_id`
es `FRED.BEA_PIB_EEUU`.

## 2. Alternativas

### B1 — un `publicacion_id` por serie de FRED  *(recomendada)*

| | |
|---|---|
| **`publicacion_id` (mensuales)** | `FRED.INDPRO`, `FRED.PAYEMS`, `FRED.UNRATE`, `FRED.CPIAUCSL` — planos, el `series_id` de FRED tal cual |
| **`publicacion_id` (PIB)** | `FRED.BEA_PIB_EEUU` se mantiene (1:1 con `GDPC1` por ahora; decisión de Harold, 2026-08-27 — no se renombra a `FRED.GDPC1`) |
| **`vintage_id`** | `FRED.INDPRO.v2026-08`, … — sin colisión |
| **Gramática de `vintage_id` (ADR-007)** | sin cambio |
| **`registrar_descarga()` / `check_l0_integrity.R`** | sin cambio (tratan `vintage_id` como cadena opaca) |
| **`FRED.INDICADORES_MENSUALES_EEUU.yaml`** | se conserva, **re-encuadrado** como ficha de familia / contexto, no como objetivo de captura |

**Convención de nombre:** plano, `FRED.<SERIES_ID>`. El `series_id` de FRED *es* el
identificador de publicación canónico y estable de esta fuente: es la clave del
endpoint y es lo que ALFRED versiona. Espeja el modelado del BCR — un `publicacion_id`
por serie servida.

**Re-encuadre de `FRED.INDICADORES_MENSUALES_EEUU.yaml`.** Su "ADVERTENCIA DE ALCANCE"
actual dice que la ficha es deliberadamente genérica porque *"la selección concreta de
series se hace después"* (Fase 3, `03_series`). Se reescribe para afirmar la distinción
que el proyecto ya sostiene: **capturar L0 de una serie candidata ≠ seleccionarla como
predictor.** La adquisición de L0 es Fase 2; la matriz de predictores es Fase 3, y se
registra en `03_series`. Partir el `publicacion_id` no compromete nada sobre predictores.
La ficha pasa a documentar el grupo, las `condiciones_uso` compartidas, el límite con
Fase 3, y a apuntar a las fichas por serie.

**Por qué se recomienda**

1. **No toca un ADR fundacional.** Solo una nota de seguimiento en ADR-007 con la regla:
   *cuando una fuente publica por serie, con fechas de tiempo real nativas por serie, se
   modela un `publicacion_id` por serie.*
2. **Corrige un desajuste de modelado real** en vez de enmascararlo. La ficha genérica
   fue un marcador de posición de Fase 1 ("la fuente existe, es accesible por API, tiene
   condiciones de uso conocidas"); Fase 2 toca el cable y aprende la unidad real de
   publicación.
3. **`realtime_start` se mantiene como la `fecha_publicacion` real.** Sin fechas
   sintéticas — a diferencia de UT, que no tenía ninguna fecha real que usar. El handoff
   rechaza expresamente repetir aquí el mecanismo de UT.
4. **Mejora el aislamiento (senda §8):** un cambio de estructura en una serie de FRED
   rompe solo su propio registro, no los demás.
5. **Costo casi nulo ahora:** `grep` confirma cero referencias a estos `publicacion_id`
   fuera de sus propias fichas — sin vintages, sin filas en `03_series`. El costo solo
   crece; antes de la primera captura es el momento barato.

**Costo:** 4 fichas yaml nuevas + 1 ficha paraguas re-encuadrada. El contenido ya
existe (verificado en vivo el 2026-08-18, en el campo `cobertura_temporal` de la ficha
actual). Las fichas de `01_publicaciones` no tienen prueba de esquema automatizada; se
sigue `_plantilla.yaml` (9 campos). `datapackage.json` declara `publicacion_id` como
clave foránea desde `03_series` y `09_rupturas`, pero ninguna de esas dos referencia
las fichas FRED hoy.

### B2 — extender la gramática de `vintage_id` con una sub-clave

`vintage_id = {publicacion_id}[.{sub_id}].v{AAAA-MM}`, con `sub_id` (p. ej. el
`series_id`) provisto solo cuando un `publicacion_id` lleva varios flujos
independientes. `registrar_descarga()` gana un parámetro opcional;
`check_l0_integrity.R` no se afecta.

- **A favor:** conserva la ficha genérica única; respeta al pie de la letra el "no fijar
  el conjunto acá".
- **En contra:** enmienda la gramática de `vintage_id`, que la nota del 2026-08-20 de
  ADR-007 fijó. Todo lector futuro de un `vintage_id` debe conocer el componente
  opcional. Más pesado, conceptualmente, para un caso que B1 disuelve por completo.

## 3. Recomendación

**B1.** B2 preserva una decisión de modelado de catálogo que era ella misma provisional,
al costo de complicar un identificador fundacional. B1 alinea el catálogo con la forma
en que FRED efectivamente publica, y la gramática de `vintage_id` no se mueve.

## 4. Si se aprueba B1 — pasos (handoff aparte, no ahora)

1. Nota de seguimiento en `doc/adr/ADR-007-politica-vintages.md`: la regla por serie y su
   fundamento.
2. Fichas yaml nuevas desde `_plantilla.yaml`: `FRED.INDPRO`, `FRED.PAYEMS`,
   `FRED.UNRATE`, `FRED.CPIAUCSL`. Contenido tomado de los bloques `cobertura_temporal`
   ya verificados. `FRED.BEA_PIB_EEUU.yaml` no se toca.
3. Re-encuadrar `FRED.INDICADORES_MENSUALES_EEUU.yaml` como ficha de familia.
4. `fred.R`: `descargar_fred_serie(series_id, publicacion_id = paste0("FRED.", series_id),
   frecuencia)` — `publicacion_id` derivable del `series_id`, o pasado explícito.
5. Captura: 5 llamadas → 5 `publicacion_id` distintos → 5 `vintage_id` distintos, sin
   colisión.

## 5. Lo que esta propuesta NO hace

- No implementa nada. Ninguna ficha creada, ningún yaml editado, `fred.R` no escrito.
- No decide qué series terminan en `03_series` como predictores — eso es Fase 3.
- No renombra `FRED.BEA_PIB_EEUU` (decisión de Harold: se queda).
- No toca `FRED.ALFRED_VINTAGES.yaml`.
