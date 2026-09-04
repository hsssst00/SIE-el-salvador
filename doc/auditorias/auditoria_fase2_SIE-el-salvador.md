## Auditoría — Fase 2 (adquisición y capa L0), SIE El Salvador

**Repositorio auditado:** árbol de trabajo local, rama `main`
**HEAD al momento de la auditoría:** `7858a21` — _"Parte FMI.PCPS en 3 fichas y captura POILAPSP/PALLFNF/PFOOD"_ (2026-08-28)
**Encargada por:** Harold, 2026-08-28 ("revisión exhaustiva de la fase dos del repo")
**Ejecutada por:** Claude Code (Opus 5), en la misma sesión en que se aplicó la remediación
**Método:** lectura completa de los 11 archivos de `src/adquisicion/`, los 3 scripts de `scripts/`, `src/validacion/verificar_fuente_celda.R`, `Makefile`, `.github/workflows/ci.yml`, `DESCRIPTION`, `.gitignore` y `src/adquisicion/README.md`; **ejecución real** de `check_l0_integrity.R`, `testthat::test_dir("tests")` y `verificar_fuente_celda.R`; verificación SHA-256 de los 54 archivos declarados en el manifiesto contra el disco; inspección directa del contenido de los `.json` archivados de FRED, BM y FMI; búsqueda en `D:\` y `C:\Users\harold` de los archivos ausentes; cotejo de los 85 YAML de `01_publicaciones` contra los `publicacion_id` capturados.

**Salvedad de método, que corresponde declarar.** Esta auditoría no es independiente en el sentido de las de Fase 0 y Fase 1: la ejecutó el mismo agente que después aplicó las correcciones, en la misma sesión, y no sobre un clon fresco sino sobre el árbol de trabajo. Su valor probatorio es menor. En particular, un hallazgo (A2) resultó **falso** y fue retirado tras verificación adicional — el episodio se documenta abajo en vez de borrarse, porque es información sobre la fiabilidad de este documento.

----------

### Resumen para orientarse

El diseño de Fase 2 es sólido y está documentado con un cuidado poco común: `registrar_descarga()` implementa un contrato explícito, el problema del `.xlsx` no determinista se detectó, se verificó y se resolvió con dos checksums separados, y la bitácora de fuentes frágiles registra el trabajo negativo (lo que no funcionó) además del positivo. La integridad de lo que está en disco es real: **42 de 42 archivos presentes coinciden byte a byte con su `sha256` declarado.**

El problema no está en el diseño sino en la **distancia entre lo que el sistema verifica y lo que el sistema afirma verificar**. Los tres hallazgos serios son variantes del mismo patrón: un mecanismo de control existe, está bien escrito, y no cubre lo que se creería que cubre — y nada avisa de la diferencia.

- **Doce archivos de L0 desaparecieron** y las dos verificaciones existentes siguieron en verde, porque ninguna miraba el disco.
- **El verificador de la regla 8 estaba en rojo en `main` desde hacía dos días**, y como no corre en CI, nadie se enteró.
- **`make raw`, que es el criterio de cierre de Fase 2, verificaba 3 de 30 publicaciones** y cerraba con un `"3/3 PASS"` escrito a mano que hacía parecer completa una cobertura del 10%.

El criterio de cierre de Fase 2 (senda §4) **no estaba satisfecho** al momento de la auditoría, y el repositorio no afirmaba lo contrario en ningún documento — pero el mensaje de éxito del propio script sí inducía a creerlo.

----------

### Hallazgos — BLOQUEANTE

#### B1. Doce archivos de L0 registrados en el manifiesto no existen, y ningún control lo detectaba

El lote completo del BCR capturado el 2026-08-26 —`ipi_vigente`, `ipp`, `isi`, `itcer`, `panorama_banco_central`, `balanza_comercial`, `reservas_internacionales_netas`, `indices_precios_comercio_exterior`, `balanza_pagos_trimestral`, `gobierno_central_consolidado`, `panorama_sociedades_deposito`, `spnf_vigente`— no está en `data/L0_raw/`. Busqué los doce en todo `D:\` y `C:\Users\harold`, incluidos ocultos: no aparecen. Ningún otro archivo del manifiesto falta, lo que descarta un borrado indiscriminado y apunta a que se perdió ese lote específico.

Los doce se registraron con `sha256`, `sha256_norm` y `tamano_bytes` reales, y `registrar_descarga()` escribe el archivo (paso 4) **antes** de escribir las filas del catálogo (paso 5), así que existieron en disco el 2026-08-26.

**Lo que hace a esto bloqueante no es la pérdida sino el silencio.** El repositorio tenía dos verificaciones de L0 y ninguna respondía "¿el archivo sigue ahí?":

| Script | Qué compara | Con los 12 ausentes |
|---|---|---|
| `check_l0_integrity.R` | `manifiesto.csv` ↔ `08_vintages.csv` (solo texto) | verde, y corre así en CI |
| `verificar_l0.R` | portal en vivo ↔ `sha256_norm` del manifiesto | verde (no mira el disco) y además no cubría esas publicaciones |

**Asimetría de recuperación, que conviene tener a la vista antes de decidir.** Re-capturar del portal reproduce el `sha256_norm` —es estable por construcción, esa es la conclusión de la prueba F1— de modo que la *identidad de vintage* se recupera. El `sha256` **crudo** no: el contenedor ZIP que produce SheetJS varía entre descargas del mismo dato (ADR-007, nota del 2026-08-21). Esas doce filas quedarían con una columna de integridad que ya no corresponde a ningún archivo obtenible.

**Remediado (parcial):** `scripts/verificar_l0_fisico.R`, nuevo. Verifica presencia, `sha256` y `tamano_bytes` de cada fila del manifiesto. Distingue dos modos por una regla mecánica que no necesita saber en qué máquina corre: si **cero** archivos están presentes es un clon limpio (estado normal, ADR-008: L0 está en `.gitignore`) y sale 0; si **alguno** está presente, L0 está materializada y toda ausencia es `FAIL`. Corrida del 2026-08-28: **42 PASS / 0 FAIL / 12 AUSENTE**, salida 1. Encadenado en `make raw` antes del verificador en vivo, para fallar barato.

**Decisión de Harold (2026-08-28): recapturar del portal y cotejar `sha256_norm`.** Si coincide, es el mismo dato y el vintage se restaura, aceptando que el `sha256` crudo de esas filas se reescriba al del archivo nuevo con el valor histórico anotado en `notas`. Si no coincide, el portal ya sirve otro vintage y el perdido es irrecuperable — eso vuelve a ser una decisión abierta, no algo que el script resuelva.

**Resultado (2026-08-30): 6 de 12 recuperados, 6 IRRECUPERABLES.**

| Recuperados (`sha256_norm` idéntico) | Irrecuperables (`sha256_norm` distinto) |
|---|---|
| `IPI.VIGENTE`, `IPP`, `ISI`, `PANORAMA_BANCO_CENTRAL`, `RESERVAS_INTERNACIONALES_NETAS`, `BALANZA_PAGOS_TRIMESTRAL` | `ITCER`, `BALANZA_COMERCIAL`, `INDICES_PRECIOS_COMERCIO_EXTERIOR`, `GOBIERNO_CENTRAL_CONSOLIDADO`, `PANORAMA_SOCIEDADES_DEPOSITO`, `SPNF_VIGENTE` |

**El dato más importante que produjo la remediación no es el balance sino esto: `BCR.ITCER` se cotejó dos veces el mismo día, y cambió en el medio.** En la primera corrida (interrumpida) dio `sha256_norm` idéntico con 318 períodos hasta 2026-M06; horas después, 319 períodos hasta 2026-M07. **La ventana de recuperación se cerró durante la propia remediación.** Es la confirmación empírica —no argumental— de la premisa de ADR-007: *"cada publicación del BCR no archivada desde hoy es información irrecuperable"*. El costo de B1 no fue fijo desde el 2026-08-26: crecía cada día.

De los seis perdidos, `INDICES_PRECIOS_COMERCIO_EXTERIOR` es el más caro. Su período de referencia **no avanzó** (sigue en 2026-M06) y el contenido cambió: fue una **revisión** del dato ya publicado. Es decir, se perdió el vintage previo de una revisión — exactamente el objeto de estudio que el eje bitemporal de este proyecto existe para medir, y que ADR-007 identifica como su aporte más original.

De cada fila restaurada cambiaron `sha256` y, en un caso, `tamano_bytes`; `sha256_norm`, `vintage_id`, `fecha_publicacion`, `periodo_referencia_max` y `fecha_descarga` quedaron intactos, con el valor histórico anotado en `notas`. `verificar_l0_fisico.R` pasó de 42/0/12 a **48 PASS / 0 FAIL / 6 AUSENTE**.

**Corrección de alcance (2026-09-04): "irrecuperable" significa "no recuperable desde el portal", no "perdido".** Harold reportó que tiene copias de archivos de L0 en otra máquina, sin acceso en este momento. La vía de recuperación **no está agotada**, y las seis filas no deben marcarse como pérdida definitiva hasta comprobarlo. La distinción no es cosmética: declarar una pérdida que no ocurrió falsea el registro tanto como ocultar una que sí.

Comprobación cuando esa máquina esté disponible: calcular el `sha256` de cada archivo candidato y compararlo contra el **valor histórico** de la fila, no contra el vigente. Para las seis no restauradas ese valor sigue en la columna `sha256`. Para las seis restauradas está en `notas` — porque la restauración lo reemplazó por el del archivo nuevo. Si aparece un original, lo correcto es reponerlo y devolver su `sha256` histórico desde la nota: un archivo original vale más que uno recapturado, aunque `sha256_norm` pruebe que el contenido es el mismo, porque es el artefacto que efectivamente se archivó.

**Sigue pendiente y es decisión de Harold (regla 4):** qué se hace con las seis filas si la otra máquina tampoco las tiene. Mientras no se resuelva, `verificar_l0_fisico.R` sale con código 1 — correctamente.

**El mecanismo (`scripts/restaurar_l0_perdido.R`).** Es un script aparte y no una llamada a `descargar_bcr_*()` por una razón que conviene dejar registrada: **`registrar_descarga()` no puede restaurar un archivo perdido.** Está escrita para capturar vintages nuevos, así que si el contenido coincide con el último vintage registrado su paso 3 retorna temprano con "sin cambios" y no escribe nada — correcto para una captura, exactamente lo contrario de lo que hace falta acá. Y si escribiera, usaría el nombre con la fecha de hoy, creando un archivo que ninguna fila del manifiesto menciona. El script de restauración escribe con el **nombre registrado original**, porque no es un vintage nuevo sino el mismo vintage recuperado.

#### B2. `verificar_fuente_celda.R` estaba en rojo en `main`, y el propio diseño lo hacía invisible

Corrida del script tal como estaba commiteado, antes de tocar nada:

```
UT.DEMANDA_ELEC.GWH.NSA.M | FAIL | publicacion_id 'UT.DEMANDA_TOTAL_MENSUAL'
                                   tiene 25 filas en manifiesto.csv (deberia ser unico)
Resumen: 98 PASS, 1 FAIL, 0 NO_VERIFICABLE (de 99 filas)
Execution halted
```

Rojo desde `0fbda08` (2026-08-26), dos días. No lo detectó nada porque el script **no corre en CI** —los `.xlsx` están en `.gitignore`— y su única evidencia posible es `doc/bitacora_verificaciones.md`, que tenía **una sola corrida asentada (2026-08-17, 4 archivos)** frente a 54 vintages actuales. La regla 8 se cumplía en su letra (prohíbe asentar corridas que no ocurrieron) y aun así el estado no se volvió a comprobar en once días.

Dos causas independientes, y la segunda es la grave:

1. La fila de UT no cita una celda: su `fuente_celda` es prosa que describe una serie derivada de 25 CSV. El verificador no tenía la categoría "no puedo verificar esto", así que lo trataba como fallo.
2. **`nrow(pub) > 1 → FAIL` es falso por diseño** — ver B3.

**Remediado:** el verificador resuelve ahora contra el vintage vigente (última fila del manifiesto), y las filas cuyo vintage vigente no es un `.xlsx` se reportan como `FUERA_DE_ALCANCE`, se listan una por una en cada corrida y no cuentan como `FAIL`. La distinción es por extensión del archivo, no por `publicacion_id`, para conservar el fallo que sí importa: un `fuente_celda` malformado sobre un `.xlsx` sigue siendo `FAIL`. Corrida posterior: **98 PASS / 0 FAIL / 0 NO_VERIFICABLE / 1 FUERA_DE_ALCANCE**, salida 0. Asentada en la bitácora.

#### B3. El supuesto "un `publicacion_id` = una fila del manifiesto" rompe el mecanismo central de ADR-007

Es el mismo defecto que B2, pero merece hallazgo propio porque su alcance es mayor que el síntoma. El manifiesto es *append-only con una fila por vintage*. Tener varias filas por publicación no es una anomalía: es exactamente el estado que produce la captura prospectiva que ADR-007 declara compromiso firme.

Es decir: **el verificador de la regla 8 estaba construido sobre un supuesto que el mecanismo central de ADR-007 rompe la primera vez que hace su trabajo.** Hoy sobrevivía solo porque las cuatro publicaciones con series catalogadas tienen un vintage cada una. El primer segundo vintage del PIB trimestral —el evento que todo el diseño bitemporal existe para capturar— lo habría puesto en rojo.

**Remediado:** además del arreglo de B2, la convención "el vintage vigente es la última fila del manifiesto para ese `publicacion_id`" quedó explícita en `doc/adr/ADR-007-politica-vintages.md` (nota de seguimiento del 2026-08-28) y fijada por una prueba de regresión en `tests/test-adquisicion.R`. No es una decisión nueva: es la que ya aplicaban `registrar_descarga()` (paso 3) y `verificar_l0.R`; lo que cambió es que ahora los tres coinciden y está escrito.

**Queda abierto y es de Harold:** si se quisiera que una fila de `03_series.csv` quedara anclada a un vintage concreto (una columna `vintage_id` en `03_series`), eso sí es un cambio de modelo de datos. La nota de ADR-007 lo deja planteado sin resolverlo.

----------

### Hallazgos — IMPORTANTE

#### A1. `make raw` verificaba 3 de 30 publicaciones y anunciaba "3/3 PASS"

`scripts/verificar_l0.R` llevaba una lista fija de tres publicaciones (`..._NSA`, `..._SA`, `NOMINAL`) y cerraba con un literal `"OK: L0 BCR (vista-serie) íntegra - 3/3 PASS"`. Quedaban fuera 13 publicaciones del BCR, las 25 filas de UT, las 5 de FRED, las 2 del BM y las 5 del FMI. El criterio de cierre de Fase 2 (senda §4) es *"`make raw` reconstruye la capa L0 desde cero **o verifica su integridad**, sin pasos manuales"*: con esa cobertura no se satisfacía, y el mensaje de éxito no permitía notarlo.

Agravante de forma: `"3/3"` estaba escrito a mano, así que crecer la lista sin tocar el mensaje habría producido un reporte activamente falso.

**Remediado:** la lista ya no se escribe, **se deriva del manifiesto**, de modo que toda publicación capturada queda cubierta por construcción. Las exclusiones son explícitas, llevan motivo y se imprimen en cada corrida: `BCR.PIB_T.SERIE_RETROPOLADA_1990_2005` (`.xlsx` estático, serie cerrada) y `UT.DEMANDA_TOTAL_MENSUAL` (`robots.txt` no permite la ruta; la regla 9 prohíbe evadirlo aunque `chromote` pudiera). Cobertura resultante: **28 en vivo + 2 excluidas = 30**.

El alcance de una corrida es seleccionable, porque verificar todo el BCR son 16 renders completos de tabla en navegador headless y eso es un acto deliberado al ritmo de publicación de la fuente, no algo que se corra en bucle mientras se programa (regla 9): `make raw` (todo), `make raw-api` (barato, sin navegador), `make raw-plan` (no pide nada, solo lista). El default es la corrida completa a propósito.

**Verificado:** `make raw-api` → **12/12 PASS**. La rama BCR **no se corrió**: 16 capturas headless contra el portal no son algo que un agente deba disparar por su cuenta. Queda pendiente una corrida completa de `make raw`.

#### A4. La URL registrada del Banco Mundial no reproducía la respuesta archivada

`bm.R` consultaba con `req_url_query(format = "json", per_page = 1000)` pero registraba `paste0(url, "?format=json")`. La URL guardada en `manifiesto.csv` y en `documento_fuente` devuelve la primera página con el default de 50 registros; el archivo de L0 tiene 66 observaciones. El contrato de `src/adquisicion/README.md` §3 pide *"la URL exacta consultada, con todos los parámetros"*.

Es un defecto de trazabilidad, no de dato: el archivo y sus dos checksums siempre estuvieron bien.

**Remediado:** la URL se construye ahora en un único lugar (`.bm_url_registrada()`), que es el mismo que usa el verificador para re-pedirla, de modo que captura y verificación no pueden divergir. Las dos filas afectadas se corrigieron en ambos catálogos con la corrección anotada en `notas`; ningún checksum se tocó. **Verificado después de la corrección:** la URL enmendada reproduce `sha256_norm` byte a byte.

----------

### Hallazgo retirado — A2 (FALSO)

Se reportó que `fred.R` derivaba `fecha_publicacion` de `realtime_start`, y que ese campo, sin parámetros `realtime_*`, devuelve el día de la consulta — con lo cual el `vintage_id` habría quedado atado a la fecha de descarga, justo lo que ADR-007 (nota del 2026-08-20) rechaza.

**Es falso.** El error de método fue inspeccionar **un solo archivo** (`FRED_gdpc1`, cuyo `realtime_start` de 2026-08-26 cae cerca de la fecha de descarga del 2026-08-27) y generalizar de ahí. Los cinco archivos archivados muestran:

| serie | `realtime_start` en el archivo | `last_updated` de `fred/series` |
|---|---|---|
| GDPC1 | 2026-08-26 | 2026-08-26 |
| INDPRO | 2026-08-18 | 2026-08-18 |
| PAYEMS | 2026-08-07 | 2026-08-07 |
| UNRATE | 2026-08-07 | 2026-08-07 |
| CPIAUCSL | 2026-08-12 | 2026-08-12 |

`realtime_start` es uniforme *dentro* de un archivo (todas las observaciones comparten el vintage vigente de la serie) pero **varía por serie** y coincide exactamente con lo que FRED declara en `last_updated`. El código y la nota que ya estaban en `08_vintages` eran correctos. Las cinco `fecha_publicacion` registradas son correctas.

Se llegó a modificar `fred.R` para consultar `fred/series` y se llegó a enmendar el catálogo; **ambas cosas se revirtieron.** Lo único que quedó de ese intento es (a) la extracción de `.fred_fetch_observaciones()` / `.fred_refetch()`, que sí hacía falta para A1, y (b) una nota en la cabecera de `fred.R` que deja la sospecha **refutada por escrito**, para que nadie la "arregle" de nuevo dentro de seis meses.

----------

### Hallazgos — MENOR

#### M1. Tres paquetes usados en código commiteado no estaban declarados

`polite` (`verificar_robots_ut.R`) y `readxl` (`calendario_bcr_extraer.R`) no estaban **ni en `DESCRIPTION` ni en `renv.lock`**: en una máquina limpia tras `renv::restore()`, esos dos scripts no arrancan. `digest` estaba solo como dependencia transitiva ajena, con una salvedad razonada en `verificar_fuente_celda.R` que decía *"si esto deja de sostenerse, corresponde declarar `digest` como import propio"* — dejó de sostenerse cuando `lib_adquisicion.R`, el núcleo de Fase 2, pasó a hacer `library(digest)`.

**Remediado (2026-08-30).** Los tres están en `DESCRIPTION` y en la lista de `scripts/bootstrap_renv.R`, y su árbol de dependencias quedó cerrado en `renv.lock`: **161 → 187 entradas, sin perder ninguna**. Se usó `renv::record()` y no `renv::snapshot()` a propósito — la biblioteca local estaba parcialmente desincronizada y un snapshot podía *borrar* entradas de paquetes no instalados, que es un daño mayor que el que se venía a reparar. Se verificó después que las 65 dependencias recursivas de `polite` y `readxl` están todas en el lockfile, y que los cuatro paquetes (`polite`, `readxl`, `digest`, `chromote`) cargan.

Hallazgo lateral: `CLAUDE.md` declaraba 155 paquetes y el lockfile ya tenía 161 **antes** de esta sesión. El número llevaba tiempo desactualizado.

#### M2. `registrar_descarga()` no tenía ninguna prueba

La función que materializa la regla 7 (*"la validación falla, no advierte"*) no tenía ninguna prueba que comprobara que efectivamente falla. Las 7 pruebas existentes eran todas de catálogos.

**Remediado:** `tests/test-adquisicion.R`, 13 pruebas nuevas sobre repositorios de mentira en directorios temporales (ninguna toca el manifiesto real). Cubren los fallos de los pasos 0, 1, 3b y 4; el retorno temprano de "sin cambios"; los literales exactos de `alcance_revision` (declarados con escape unicode, porque la raya larga es el mecanismo de detección de deriva); la estabilidad de `sha256_norm` frente al empaquetado ZIP (F1); y la regresión de B3. Batería completa: **58 PASS, 0 FAIL**.

Hallazgo lateral, descubierto al escribir las pruebas y documentado como comportamiento esperado: **no se pueden registrar dos vintages de la misma publicación el mismo día**, porque el nombre de archivo solo lleva `fecha_descarga`. Es el guardarraíl de "nunca sobrescribe" actuando; quien lo necesite pasa una `descripcion_archivo` distinta, que es lo que hace `ut.R` con sus 25 cortes anuales.

#### M3. La URL del FMI no basta para reproducir la respuesta

La representación que devuelve `api.imf.org` la decide el header `Accept: application/vnd.sdmx.data+json` (negociación de contenido de SDMX 3.0), que no es un parámetro y no cabe en el campo `url`. **Remediado:** se anota en `notas_vintage`, y `README.md` §3 fija la regla general — *si la respuesta depende de algo que la URL no lleva, ese algo va en `notas`; la trazabilidad es "puedo reproducir esta respuesta", no "guardé una cadena"*.

#### M4. `src/adquisicion/README.md` describía el árbol de agosto 21

Cuatro afirmaciones falsas: que `fmi.R`/`fred.R`/`banco_mundial.R` estaban `[pendiente]` (los tres existen; el último se llama `bm.R`); que `lib_adquisicion.R` *"no [fue] ejecutado nunca de punta a punta"* (54 vintages); que `bcr.R` implementaba el enfoque `httr2` descartado (usa `chromote` desde el 2026-08-24); y que `chromote` no estaba en `DESCRIPTION` ni en `renv.lock` (está en ambos). `CLAUDE.md` decía "15 imports" (son 20). **Remediado**, con la corrección declarada en el propio documento.

#### M5. Fecha futura en el registro

`fmi.R` y las notas que escribió en `08_vintages` citaban un *"diagnóstico del 2026-08-29"*, posterior a la captura (2026-08-28). Error de transcripción propagado a cuatro fichas YAML y cinco filas del catálogo. **Remediado** en los diez sitios.

#### L1. Un `.xlsx` de L0 estuvo abierto en Excel durante la auditoría

Al inicio de la revisión había un `~$BCR_pib_t_indices_volumen_nsa_2026-08-06.xlsx` en `data/L0_raw/` — archivo de bloqueo de una sesión de Excel viva sobre un artefacto de L0. Se liberó solo al cerrarse la sesión y **no hay nada que borrar**; el checksum del original coincide, no hubo daño. Se asienta igual porque es exactamente el riesgo que la regla 1 previene, y porque el `.gitignore` de L0 significa que un daño así no dejaría rastro en Git. Vale considerar poner `data/L0_raw/` en solo lectura.

#### L2. `ut.R` capturaba al hacerle `source()`

El lazo de 25 capturas corría a nivel de archivo, con `C:/Users/harold/Downloads/total` escrito a mano: abrir el script para leerlo, o cargar `registrar_ut_demanda_anual()` para usarla, disparaba una captura. **Remediado:** es `registrar_ut_demanda_lote(directorio_ut, anios)`, con el directorio como argumento y comprobación de los 25 archivos **antes** de registrar ninguno, para no dejar el lote a medias.

#### L3. El `"3/3 PASS"` escrito a mano de `verificar_l0.R`

Reportado como menor de forma y **absorbido en A1**, que reescribió el script entero: el
recuento sale ahora del número real de publicaciones verificadas. Se conserva el código de
hallazgo para que la numeración sea resoluble.

#### L4. El chequeo de `codigo_http` es inerte en las fuentes de API

`httr2::req_perform()` lanza error ante 4xx/5xx por defecto, así que `registrar_descarga()` nunca ve un `codigo_http != 200` viniendo de FRED, BM o FMI. No es un defecto —falla igual, y de forma visible— pero el guardarraíl que actúa no es el que `README.md` §4 describe. Sin remediar: cambiarlo no mejora nada y tocaría tres scripts.

#### L5. Una nota de `ut.R` imitaba el literal centinela

`ut.R` escribía en `notas` la cadena `"primera captura - sin vintage previo con el cual comparar."` —guion simple, punto final— casi idéntica al literal que `registrar_descarga()` escribe en `alcance_revision` con raya larga, que es el mecanismo de detección de deriva del proyecto. **Remediado** en el código; las 24 filas ya escritas conservan el texto viejo, sin consecuencia funcional.

#### L6. 25 de las 30 publicaciones capturadas no tienen series en `03_series.csv`

`03_series.csv` describe 99 series de 5 publicaciones (4 del BCR + UT). Las otras 25 capturadas —13 del BCR, 5 de FRED, 2 del BM, 5 del FMI— están en L0 sin ninguna serie inventariada, y por tanto sin trazabilidad a nivel de celda ni cobertura del verificador de la regla 8.

Para el BCR esto es defendible: ADR-007 declara que cada publicación no archivada hoy es información irrecuperable, y capturar antes de catalogar es la respuesta correcta a esa urgencia. **Para FRED, BM y FMI el mismo ADR dice lo contrario** — "recuperables a demanda", "ninguna urgencia"— así que ahí no había razón para adelantar la captura al inventario. Sin remediar: es observación de orden de trabajo, no defecto de código.

----------

### Verificaciones limpias

Vale la pena registrar lo que se comprobó y estaba bien, porque parte de ello es el resultado no obvio:

- **Integridad de L0:** los 42 archivos presentes coinciden con su `sha256` y su `tamano_bytes` declarados. Cero discrepancias.
- **Correspondencia de catálogos:** `check_l0_integrity.R` en verde sobre las 54 filas, antes y después de la remediación.
- **`08_vintages.csv` es UTF-8 válido**, con terminación LF y salto de línea final, pese a haberse escrito por `write.table()` en Windows.
- **Ninguna fuga de credenciales.** `FRED_API_KEY` no aparece en ningún commit, ni en el manifiesto, ni en `08_vintages`, ni dentro de los `.json` de L0. Las cinco apariciones de la cadena `api_key` en el catálogo son la frase *"api_key usada para la consulta pero NUNCA guardada"*.
- **Todos los `publicacion_id` del manifiesto tienen ficha** en `01_publicaciones`.
- **La bisección de `updatedAfter` en `fmi.R` es correcta.** Los invariantes del lazo (`lo` = último no vacío, `hi` = primer vacío) se sostienen, y las dos guardas de borde fallan de forma visible en vez de devolver una fecha inventada.
- **Las 12 publicaciones de API reproducen su `sha256_norm`** contra la fuente en vivo, tras corregir A4.

----------

### Estado del criterio de cierre de Fase 2

**No satisfecho todavía**, por dos pendientes encadenados. M1 quedó resuelto el 2026-08-30.

1. **B1 — decisión de política sobre las 6 filas irrecuperables.** Bloquea: `verificar_l0_fisico.R` sale con código 1 mientras existan, y con razón. Requiere a Harold (regla 4).
2. **A1 — una corrida completa de `make raw`.** El cableado está y la rama de API da 12/12. **Está encadenado a B1, no es independiente:** las 6 publicaciones irrecuperables tienen hoy en el portal un contenido distinto del registrado, así que una corrida completa reportaría `CAMBIO` para las 6 y fallaría — correctamente, pero por una causa ya conocida y ya diagnosticada. Correrla antes de resolver B1 sólo produciría 16 capturas headless para confirmar lo que la restauración ya estableció, que es justamente la carga inútil sobre el portal que la regla 9 prohíbe.

Dicho de otro modo: el criterio de cierre de Fase 2 no está a una corrida de distancia, está a una decisión de distancia.
