# Backlog de captura de vintages

Registro operativo de la **captura prospectiva** que ADR-007 declara compromiso firme. Cada vez
que `scripts/verificar_l0.R` (el monitor en vivo, `make raw` / `make raw-api`) reporta un
`CAMBIO` o un `ERROR`, se asienta acá: qué publicación, cuándo se detectó, y qué se hizo.

**No es un entregable de Fase 2 que se cierre.** Es un registro permanente: sigue vivo en
Fase 3 y más allá, al ritmo real de publicación de cada fuente.

## Reglas

- Un `CAMBIO` significa que la fuente publicó un vintage nuevo. **No es un defecto de L0** — el
  archivo archivado sigue siendo el vintage que era (ver ADR-007, nota del 2026-09-09). Desde el
  2026-09-09 `verificar_l0.R` no aborta ante un `CAMBIO`: lo reporta y `make raw` sale 0. Solo un
  `ERROR` hace fallar `make raw`.
- Capturar una entrada pendiente es un acto deliberado vía `descargar_*()` de
  `src/adquisicion/`, al ritmo de publicación de la fuente (trimestral para el PIB, mensual
  para la mayoría del BCR y los índices de precios de commodities del FMI, etc.). **Nunca en
  bucle** (regla 9 de `CLAUDE.md`).
- Que una entrada quede pendiente un tiempo no bloquea ninguna fase. Lo que bloquearía sería
  capturar de forma exhaustiva o repetida.
- Al capturar, `registrar_descarga()` escribe la fila nueva en `manifiesto.csv` y
  `08_vintages.csv` con su propia `fecha_descarga`; se marca acá la entrada como capturada con
  el `vintage_id` resultante.
- Un `ERROR` no es un `CAMBIO`: la fuente no respondió o respondió algo inesperado. Se examina
  antes de concluir nada (¿fuente caída?, ¿falta credencial?, ¿cambió la estructura? — esto
  último es hallazgo de `doc/bitacora_fuentes_fragiles.md`, no de este backlog).

## Entradas

15 `CAMBIO` detectados en la corrida completa de `make raw` que certificó el cierre de Fase 2
(máquina de Harold, L0 completa, 2026-09-09; salida en `doc/evidencia_cierre_fase2.txt`).
Captura original entre el 2026-08-25 y el 2026-08-28. Todas son series de **frecuencia
mensual** con un mes nuevo publicado en las ~2 semanas transcurridas — cero sorpresas (ver
nota de grupo abajo). El set coincide exactamente con el de la corrida previa del mismo día.

| Publicación | Detectado | Estado | Acción | Capturado |
|---|---|---|---|---|
| `BCR.BALANZA_COMERCIAL` | 2026-09-09 | `CAMBIO` | Capturado | `BCR.BALANZA_COMERCIAL.v2026-09` (2026-10-01) |
| `BCR.GOBIERNO_CENTRAL_CONSOLIDADO` | 2026-09-09 | `CAMBIO` | Capturado | `BCR.GOBIERNO_CENTRAL_CONSOLIDADO.v2026-09` (2026-10-02) |
| `BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR` | 2026-09-09 | `CAMBIO` | Capturado | `BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR.v2026-09` (2026-10-01) |
| `BCR.ISI` | 2026-09-09 | `CAMBIO` | Capturado | `BCR.ISI.v2026-09` (2026-10-02) |
| `BCR.ITCER` | 2026-09-09 | `CAMBIO` | Capturado | `BCR.ITCER.v2026-09` (2026-10-01) |
| `BCR.IVAE.VIGENTE` | 2026-09-09 | `CAMBIO` | Capturado | `BCR.IVAE.VIGENTE.v2026-09` (2026-10-01) |
| `BCR.PANORAMA_BANCO_CENTRAL` | 2026-09-09 | `CAMBIO` | Capturado | `BCR.PANORAMA_BANCO_CENTRAL.v2026-09` (2026-10-02) |
| `BCR.PANORAMA_SOCIEDADES_DEPOSITO` | 2026-09-09 | `CAMBIO` | Capturado | `BCR.PANORAMA_SOCIEDADES_DEPOSITO.v2026-09` (2026-10-02) |
| `BCR.RESERVAS_INTERNACIONALES_NETAS` | 2026-09-09 | `CAMBIO` | Capturado | `BCR.RESERVAS_INTERNACIONALES_NETAS.v2026-09` (2026-10-02) |
| `BCR.SPNF_VIGENTE` | 2026-09-09 | `CAMBIO` | Capturado | `BCR.SPNF_VIGENTE.v2026-09` (2026-10-02) |
| `FRED.PAYEMS` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `FRED.UNRATE` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `FMI.PCPS.PALLFNF` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `FMI.PCPS.PFOOD` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `FMI.PCPS.POILAPSP` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |

El valor definitivo del vintage nuevo lo escribe `registrar_descarga()` en `manifiesto.csv` /
`08_vintages.csv` al capturarlo. `sha256_norm` **registrado → observado el 2026-09-09**
(prefijos; el detalle completo está en `doc/evidencia_cierre_fase2.txt`):

- `BCR.BALANZA_COMERCIAL`                `47d26c43…` → `94cb9e0e…`
- `BCR.GOBIERNO_CENTRAL_CONSOLIDADO`     `90269076…` → `8ac40917…`
- `BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR` `012a9fcc…` → `0b697ddc…`
- `BCR.ISI`                              `8a98a0fa…` → `65386e49…`
- `BCR.ITCER`                            `34ce75cf…` → `5569f982…`
- `BCR.IVAE.VIGENTE`                     `72a6766f…` → `94159781…`
- `BCR.PANORAMA_BANCO_CENTRAL`           `4582fc9a…` → `19013c44…`
- `BCR.PANORAMA_SOCIEDADES_DEPOSITO`     `97b8daa0…` → `abd5f270…`
- `BCR.RESERVAS_INTERNACIONALES_NETAS`   `078ecdcd…` → `76502a0c…`
- `BCR.SPNF_VIGENTE`                     `925d2ecf…` → `5d713308…`
- `FRED.PAYEMS`                          `68dea9ce…` → `9d759f6b…`
- `FRED.UNRATE`                          `3c730395…` → `5de16554…`
- `FMI.PCPS.PALLFNF`                     `6d64a2cf…` → `f38ef529…`
- `FMI.PCPS.PFOOD`                       `0a5e5018…` → `cb0472cf…`
- `FMI.PCPS.POILAPSP`                    `a87c6118…` → `04d0f81b…`

### Notas por grupo

**Las 15, en conjunto (2026-09-09).** Todas mensuales; el corte de captura fue 25–28 de agosto y
la corrida de verificación 9 de septiembre, con un mes de publicación de por medio. Lo que **no**
cambió lo confirma: `BCR.PIB_T.*` (NSA/SA/NOMINAL) y `BCR.BALANZA_PAGOS_TRIMESTRAL` son
trimestrales sin trimestre nuevo; `BCR.IPI.VIGENTE`, `BCR.IPP`, `FRED.INDPRO`, `FRED.CPIAUCSL`,
`FRED.BEA_PIB_EEUU`, `BM.WDI.*`, `FMI.BOP`, `FMI.QNEA` son o trimestrales o mensuales cuya
próxima publicación aún no salió. Ninguna serie tiene fila en `03_series.csv` todavía (son de
las 25 publicaciones capturadas sin catalogar, hallazgo L6 de la auditoría de Fase 2), así que
ningún `CAMBIO` de esta tanda toca una variable ya admitida al proyecto.

**Ritmo de captura.** No hay urgencia de capturarlas todas de una: el BCR es la única fuente
donde un vintage no capturado es irrecuperable (ADR-007), y aun ahí la política es capturar al
ritmo de publicación, no en respuesta inmediata a cada `CAMBIO`. FRED y FMI son recuperables a
demanda. Se capturan cuando se catalogue una serie suya (Fase 3) o en la próxima ventana de
captura prospectiva, lo que ocurra primero.

## Nota del 2026-09-30 — corrección, vintages intermedios y procedimiento de las ventanas

Decisiones D1 y D2 de la nota de seguimiento del 2026-09-30 en `doc/adr/ADR-007-politica-vintages.md`.

### Corrección a la nota del 2026-09-09 (sin reescribirla)

La nota «Las 15, en conjunto (2026-09-09)» dice que ningún `CAMBIO` de esa tanda toca una variable
ya admitida al proyecto. Era cierto el 2026-09-09 y dejó de serlo el 2026-09-16, cuando
`catalogos/03_series.csv` admitió IVAE, remesas, FOB, IPP, ITCER e IPM. Hoy **4 de los 15 `CAMBIO`
pendientes alimentan L3**:

| Publicación con `CAMBIO` | Serie(s) de L3 que alimenta |
|---|---|
| `BCR.BALANZA_COMERCIAL` | `BCR.EXPORT_FOB.NOM.NSA.M` y `.Q` |
| `BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR` | `BCR.IPM.IDX.NSA.M` y `.Q` |
| `BCR.ITCER` | `BCR.ITCER.IDX.NSA.M` y `.Q` |
| `BCR.IVAE.VIGENTE` | `BCR.IVAE.VOL.SA.M` y `.Q` |

Las otras once siguen sin fila en `03_series.csv`. La frase de «Ritmo de captura» («no hay urgencia
de capturarlas todas de una») sigue valiendo para ellas, no para estas cuatro. Que `BCR.IPP`
(capturada el 2026-08-26) y las dos que se recapturaron el 2026-09-16 (`BCR.REMESAS_FAMILIARES_MENSUAL`
y `ONEC.IPC.BASE_2009`) no figuren entre los 15 no las exime de la ventana mensual.

### Posible pérdida de vintages intermedios (hipótesis, no hecho)

El último vintage en L0 de esas cuatro se capturó entre el 2026-08-25 (`BCR.IVAE.VIGENTE`) y el
2026-08-26 (las otras tres), y el `CAMBIO` se detectó el 2026-09-09. El portal sirve en cada URL
solo el vintage vigente. Si el BCR ya reemplazó esos archivos más de una vez desde la captura, los
vintages publicados entre medio **se perdieron** y no hay cómo recuperarlos. No se sabe todavía
cuántos: la primera ventana lo verifica. Al capturar cada una, comparar el
`periodo_referencia_max` del vintage nuevo con el del último vintage en L0 (`08_vintages.csv`): si
avanzó más de un período, hay vintages intermedios no capturados, y se asienta acá con la fecha y
la publicación. Si avanzó uno solo, no se perdió nada.

### Ventana mensual (BCR y demás publicaciones con `CAMBIO`)

Días 1 a 3 de cada mes. Una sola pasada: no se repite dentro de la ventana (regla 9).

1. `make raw`. Es local: usa navegador headless y sale a la red. El paso offline va primero y debe
   pasar. El resultado trae los `CAMBIO` con un bloque copiable para la tabla de arriba, y
   `MANUAL_PENDIENTE` para UT (ver la ventana trimestral).
2. Por cada `CAMBIO`, capturar con su `descargar_*()` de `src/adquisicion/`, pasando
   `fecha_publicacion` como `AAAA-MM-01` del mes de publicación conocido de la fuente (convención de
   `src/adquisicion/bcr.R`; ante duda manda `doc/calendario_divulgacion_bcr.csv`). Si el
   `vintage_id` resultante ya existe, `registrar_descarga()` se detiene: no se fuerza, se avisa.
3. Para las cuatro publicaciones de la tabla de arriba, hacer además la comprobación de vintages
   intermedios (sección anterior).
4. `make raw` otra vez. Lo capturado debe salir `PASS`; lo que siga en `CAMBIO` es una publicación
   que se movió durante la ventana, y se deja para la siguiente.
5. Marcar cada entrada capturada en la tabla de «Entradas» con su `vintage_id`, como dicen las
   reglas de arriba, y registrar las nuevas con el bloque copiable.
6. `make master` y `make test` si algo capturado alimenta L3. Commitear `manifiesto.csv` y
   `08_vintages.csv`; los archivos de L0 no se versionan (ADR-008).

### Ventana trimestral de UT (enero, abril, julio y octubre)

Captura manual: el robots.txt de ut.com.sv prohíbe el scraping y la regla 9 impide evadirlo.

1. `make raw`. UT figura como `MANUAL_PENDIENTE`, con los días desde la última captura y los años
   anteriores al actual que no llegan a diciembre.
2. Elegir los años a bajar: el año en curso, más todos los años anteriores que en L0 no llegan a
   diciembre. En la ventana de enero el año en curso no tiene datos y se omite; en las demás se
   baja siempre.
3. Bajar a mano un CSV por año desde el formulario de Reportes Estadísticos de UT (salida CSV).
4. Registrar cada archivo con `src/adquisicion/ut.R`. La función recibe el archivo ya bajado.
   Ver en su salida cuál de los tres casos de la regla de identidad se dio: vintage nuevo, fecha de
   captura por colisión, o idéntico al último del año (no se registra). «Idéntico» se juzga por
   los meses y valores GWH, no por el hash del archivo: cada descarga trae su propia hora de
   reporte, y el hash cambiaría aunque los datos no.
5. `make raw` otra vez: UT sigue como `MANUAL_PENDIENTE` (nunca pasa a `PASS`, no se verifica en
   vivo). Si se registró algo, con 0 días desde la última captura; si todo salió sin cambios no hay
   fila nueva y los días siguen contando desde la última captura registrada. Sin años anteriores
   sin diciembre; si alguno queda, ese año quedó incompleto: o UT aún no publicó los meses que
   faltan, y se retoma en la ventana siguiente, o el archivo se bajó mal, y se revisa.
6. `make master` y `make test`. La L3 de UT se detiene si un año anterior al máximo no trae 12 meses.
7. Si entró el primer archivo de un año nuevo, actualizar `fin` de `UT.DEMANDA_ELEC.GWH.NSA.M` en
   `catalogos/03_series.csv`: `make trace` falla si los años con vintage en `08_vintages.csv` no
   cubren `inicio..fin`. Correr `make trace` y asentar la corrida en
   `doc/bitacora_verificaciones.md`, en el mismo commit (regla 8).
8. Commitear `manifiesto.csv` y `08_vintages.csv`. Límite declarado: una revisión de un año ya
   cerrado en L0 no se detecta.

Estado al 2026-09-30: hasta que el código del mecanismo de UT esté en `main` (ver «Estado de la
implementación» en la nota de ADR-007), no correr el paso 4: `ut.R` y `ut_demanda_serie.R` aún
tienen valores fijos de 2026.

## Nota del 2026-10-02 — ventana de octubre

Primera ventana mensual con el procedimiento de arriba. `make raw` completo en dos pasadas, ambas
el 2026-10-02 (salida de cada una en la sesión; el verificador de celda no se usó, así que no hay
entrada en `doc/bitacora_verificaciones.md`). Antes, el 2026-10-01, se capturaron 9 series BCR
(commit `1c08c66`).

**Parte BCR.** Integridad física 71/71 y 18 publicaciones en vivo: 16 `PASS`, 2 `CAMBIO`
(`BCR.BALANZA_PAGOS_TRIMESTRAL` e `BCR.IPI.VIGENTE`), 0 `ERROR`. Las dos se capturaron ese mismo
día (commit `7c460bc`). Con la captura del 2026-10-01 y esta, **las 10 publicaciones BCR de la tabla
de «Entradas» quedan capturadas** (columna «Capturado»), y las cuatro que alimentan L3 también.

**Parte API.** 12 publicaciones en vivo: 4 `PASS` (`BM.WDI.BX_TRF_PWKR_CD_DT`,
`BM.WDI.NY_GDP_MKTP_KD`, `FMI.BOP`, `FMI.QNEA`), 8 `CAMBIO`, 0 `ERROR`. Siguen **pendientes de
captura**, con el `sha256_norm` observado el 2026-10-02:

| Publicación | Detectado | Estado | Acción | Capturado |
|---|---|---|---|---|
| `FMI.PCPS.PALLFNF` | 2026-10-02 | `CAMBIO` (en la tabla de arriba desde el 2026-09-09) | Pendiente de captura | — |
| `FMI.PCPS.PFOOD` | 2026-10-02 | `CAMBIO` (ídem) | Pendiente de captura | — |
| `FMI.PCPS.POILAPSP` | 2026-10-02 | `CAMBIO` (ídem) | Pendiente de captura | — |
| `FRED.PAYEMS` | 2026-10-02 | `CAMBIO` (ídem) | Pendiente de captura | — |
| `FRED.UNRATE` | 2026-10-02 | `CAMBIO` (ídem) | Pendiente de captura | — |
| `FRED.BEA_PIB_EEUU` | 2026-10-02 | `CAMBIO` | Pendiente de captura | — |
| `FRED.CPIAUCSL` | 2026-10-02 | `CAMBIO` | Pendiente de captura | — |
| `FRED.INDPRO` | 2026-10-02 | `CAMBIO` | Pendiente de captura | — |

Detalle del 2026-10-02 (prefijos; registrado → observado; el registrado es el de L0 hoy):

- `FMI.PCPS.PALLFNF` `6d64a2cf…` → `f38ef529…`; `FMI.PCPS.PFOOD` `0a5e5018…` → `cb0472cf…`;
  `FMI.PCPS.POILAPSP` `a87c6118…` → `04d0f81b…`
- `FRED.BEA_PIB_EEUU` `56593aeb…` → `918267df…`; `FRED.CPIAUCSL` `7c1540ad…` → `cb690091…`;
  `FRED.INDPRO` `36d66eb5…` → `f2b291c3…`
- `FRED.PAYEMS` `68dea9ce…` → `2ff38aab…` (el 2026-09-09 era `9d759f6b…`: la fuente se movió otra
  vez desde entonces); `FRED.UNRATE` `3c730395…` → `4627995a…` (el 2026-09-09 era `5de16554…`)

Sigue valiendo lo dicho en «Ritmo de captura»: FRED y FMI son recuperables a demanda; ninguna de
estas ocho tiene fila en `03_series.csv` (verificado el 2026-10-02: el catálogo no tiene ninguna serie de FRED ni FMI).

**UT.** `MANUAL_PENDIENTE`: 37 días desde la última captura registrada (2026-08-26). Octubre es
mes de su ventana trimestral y **no se hizo**.

**Comprobación de vintages intermedios** (la hipótesis de arriba, ahora con datos): `periodo_
referencia_max` del vintage nuevo frente al último previo en `08_vintages.csv`.

| Publicación | Previo → nuevo | ¿Avanzó más de un período? |
|---|---|---|
| `BCR.IVAE.VIGENTE` | M05 → M07 | Sí: falta M06 |
| `BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR` | M05 → M07 | Sí: falta M06 |
| `BCR.BALANZA_COMERCIAL` | M06 → M08 | Sí: falta M07 |
| `BCR.GOBIERNO_CENTRAL_CONSOLIDADO` | M06 → M08 | Sí: falta M07 |
| `BCR.PANORAMA_SOCIEDADES_DEPOSITO` | M06 → M08 | Sí: falta M07 |
| `BCR.SPNF_VIGENTE` | M06 → M08 | Sí: falta M07 |
| `BCR.ITCER`, `BCR.IPI.VIGENTE`, `BCR.ISI`, `BCR.IPP`, `BCR.PANORAMA_BANCO_CENTRAL`, `BCR.RESERVAS_INTERNACIONALES_NETAS`, `BCR.REMESAS_FAMILIARES_MENSUAL` | un período | No |
| `BCR.BALANZA_PAGOS_TRIMESTRAL`, `BCR.PIB_T.*` (NSA, SA, NOMINAL) | T1 → T2 | No |

Las seis primeras tienen al menos un período intermedio sin vintage propio en L0. Que el período
falte no prueba que el BCR haya publicado un vintage distinto en el medio (podría haber saltado de
un archivo al siguiente sin que el intermedio se sirviera), pero ya no es recuperable: el portal
sirve solo el vigente. Entre las seis, `BCR.IVAE.VIGENTE`, `BCR.BALANZA_COMERCIAL` y
`BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR` alimentan L3.

**Herramienta nueva (2026-10-02).** `make raw-rapido` / `make raw-calendario`: precheck barato del
portal del BCR (calendario + sondeo del último período). No ve revisiones de valores de períodos
ya publicados, así que no sustituye al `make raw` del paso 1 ni al `PASS` del paso 4. Calendario de
ventanas: `doc/calendario_make_raw.md`.
