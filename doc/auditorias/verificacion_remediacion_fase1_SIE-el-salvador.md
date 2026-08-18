# Verificación independiente — remediación de hallazgos I1–I3 y M1–M4, Fase 1

**Repositorio:** https://github.com/hsssst00/SIE-el-salvador
**HEAD de `main` al momento de esta verificación:** `bde69f68` — *"Ajusta tabla de Estructura"* (2026-08-17, 15:49:35 -0600)
**Commits entre el estado auditado y HEAD:** exactamente dos.

| Commit | Padre | Fecha | Mensaje |
|---|---|---|---|
| `f7bae34` | `03a8708` | 17-ago 13:39 | Actualiza `cobertura_temporal` de `BM.GEP.yaml` *(estado auditado)* |
| `35c89aa` | `f7bae34` | 17-ago 15:48 | Remedia hallazgos I1-I3 y M1-M4 de auditoría de Fase 1 |
| `bde69f6` | `35c89aa` | 17-ago 15:49 | Ajusta tabla de Estructura *(HEAD)* |

**Método:** clon completo del repositorio y lectura directa del contenido de cada archivo en cada commit (`git show <rev>:<path>`), no del diff. Recálculo propio en Python de las cifras verificables (conteos de filas, cruce de `publicacion_id`, divergencia `fuente_celda` vs. `nombre_oficial`, comparación de checksums carácter por carácter). Replicación manual de los cuatro `test_that()` de `tests/test-catalogs.R` (R no está disponible en este entorno). `web_fetch` propio de las dos versiones de los Términos y condiciones de CEPAL. No se usó `conversation_search` ni `recent_chats`; donde algo solo podría explicarse por contexto de chat, se señala como hallazgo.

---

## Resumen para orientarse

**El contenido sustantivo de los siete ítems está bien hecho.** Recalculé de forma independiente todo lo que era recalculable y coincide: la cifra de M1 da 11/98 exactos; las 98 filas de `03_series.csv` se reparten 28/28/13/29 entre las 4 publicaciones del manifiesto, lo que hace `0 NO_VERIFICABLE` aritméticamente consistente; los 4 SHA-256 de la bitácora coinciden carácter por carácter; el dato de $0.04/página no se perdió al recortar el bloque ISSS; M4 no contiene lenguaje de reescritura de historia; el alcance del commit es exactamente el declarado (14 archivos, ninguno fuera).

Verifiqué además por mi cuenta la cláusula 4 de CEPAL en **ambas** versiones oficiales —española e inglesa— y el texto respalda literalmente lo que el ADR afirma.

**El problema está en la propagación, no en el contenido.** El commit declara haber actualizado el "estado global de licencias", y actualizó la línea `**Estado:**` del propio ADR-008 — pero dejó el índice de ADR (`doc/adr/README.md`) y el `README.md` raíz afirmando lo contrario sobre ISSS. Es, con precisión, la misma forma de los hallazgos C2/C3 de la auditoría de Fase 0, y en el mismo archivo (`doc/adr/README.md`) que aquella auditoría ya había señalado por no actualizarse tras una enmienda.

---

## Hallazgos — CRÍTICO

### C1. La enmienda de ISSS de ADR-008 no se propagó: tres sitios del repositorio siguen declarando pendiente lo que el ADR declara resuelto

El commit `35c89aa` añadió a `doc/adr/ADR-008-licencias.md` una enmienda cuyo título es explícito:

> `## Enmienda — condiciones de la fuente ISSS: resuelto por decisión, no por relevamiento (2026-08-17)`

y reescribió la línea de estado del encabezado para que diga `ISSS resuelto por decisión de no perseguir esclarecimiento`. El cuerpo de la enmienda insiste en el punto: *"queda resuelto por decisión de no perseguir esclarecimiento, **no por relevamiento pendiente**"*.

Tres sitios contradicen eso hoy, en HEAD:

**(a) `doc/adr/README.md`, línea 16 — tabla de estado de los ADR:**
> `| [008](./ADR-008-licencias.md) | Licencias y condiciones de redistribución | Parcial — resueltos BCR (default conservador), FMI y FRED; pendientes ONEC/DIGESTYC, ISSS y decisión de política de L0 (Fase 1) |`

**(b) `doc/adr/README.md`, línea 19 — párrafo "Estado general":**
> "Su alcance pendiente se redujo el 2026-08-12: los tramos FMI y FRED quedaron resueltos con el default conservador, y siguen abiertos las condiciones de DIGESTYC/ONEC e ISSS..."

Ninguno de los dos menciona CEPAL, que este mismo commit incorporó como tramo en gestión con fecha de corte.

**(c) `README.md` raíz, línea 7:**
> "ADR-008 parcial (pendiente el relevamiento de condiciones de uso de fuentes distintas al BCR — tarea de Fase 1, no bloqueante)"

Es lo primero que lee un tercero, y hoy es falso en su literalidad: FMI, FRED e ISSS son fuentes distintas del BCR y están resueltas; Banco Mundial está relevado con decisión aplazada y disparador; CEPAL está en gestión con corte.

**(d) Adicionalmente**, las 5 YAML de ISSS abren su `condiciones_uso` con `"No verificado — pendiente relevamiento (ADR-008)."` seguido inmediatamente de la decisión de no perseguir esclarecimiento. La frase "pendiente relevamiento" es exactamente la que el ADR usa para contrastar. Consecuencia operativa concreta: un `grep "pendiente relevamiento" catalogos/` para inventariar lo abierto devuelve hoy cinco falsos positivos.

**Por qué CRÍTICO.** No es una discrepancia de matiz ni una interpretación: son afirmaciones fácticas opuestas sobre un hecho que este mismo commit cambió, entre dos archivos del mismo directorio. El mensaje de commit afirma haber actualizado el "estado global de licencias" y demostrablemente no lo hizo fuera del propio ADR. Y es una reincidencia: la auditoría de Fase 0 ya había registrado que `doc/adr/README.md` *"fue modificado una sola vez en todo el historial... y nunca se ha vuelto a tocar"* tras una enmienda fundacional. El archivo volvió a quedar atrás por la misma razón.

No hay decisión que reabrir. Es propagación, y son tres o cuatro líneas de edición.

---

## Hallazgos — IMPORTANTE

### I1. El BID está ausente de ADR-008 pese a tener licencia verificada directamente por Harold y a ser invocado como precedente dentro del propio ADR

La línea `**Estado:**` que este commit reescribió enumera el régimen de cada fuente: BCR, FMI, FRED, ISSS, Banco Mundial, CEPAL, DIGESTYC/ONEC. **No menciona el BID.** Grep sobre todo `doc/`: la única aparición de "BID" en `ADR-008-licencias.md` está dentro del registro de la gestión de CEPAL —
> "...análoga a la de Banco Mundial y BID"

— es decir, el ADR trata el régimen del BID como hecho establecido para argumentar sobre CEPAL, sin registrarlo en ninguna parte propia.

Mientras tanto, el catálogo sí lo tiene, y con el estándar probatorio más alto del proyecto. `catalogos/01_publicaciones/BID.LATIN_MACRO_WATCH.yaml`:
> "Verificado directamente por Harold (2026-08-17) contra los metadatos del paquete CKAN: licencia cc-by (Creative Commons Attribution 4.0 International)... Campo isopen=True, private=False."

Ídem `BID.SOCIAL_INDICATORS.yaml`. `BID` es una de las 10 filas de `00_instituciones.csv`.

Esto importa más de lo que parece por una razón interna al propio ADR: su nota de estándar probatorio (2026-08-12) establece que **relajar el default exige verificación directa previa** — y que por eso el tramo Banco Mundial quedó aplazado, porque su CC-BY provenía de relevamiento de Claude sin confirmar. El BID cumple la condición que el BM no cumplía. No se está pidiendo tomar la decisión aquí; se está señalando que una fuente con licencia abierta directamente verificada no figura en el documento que gobierna esa clase de decisión.

### I2. `auditoria_fase1_SIE-el-salvador.md` no existe en el repositorio, y esta remediación añade una referencia nueva a sus códigos de hallazgo

`git ls-files | grep -i auditor` no devuelve nada. Sin embargo, la remediación incorpora al repositorio esta línea nueva en `CONTRIBUTING.md`:
> "...Aplica hacia adelante — no se reescribe historia existente para cumplirlo **(M4, auditoría de Fase 1, 2026-08-17)**."

Un tercero con solo el repositorio no puede saber qué es M4. Es la misma forma del hallazgo C1 de la auditoría de Fase 0 (documento fundacional citado 24+ veces y ausente del árbol), que se remedió commiteando `doc/senda_metodologica.md`.

**Precisión sobre el alcance:** el patrón es previo, no lo introdujo esta remediación — `doc/adr/README.md:77` y `doc/senda_metodologica.md:9` ya citaban la auditoría de Fase 0 y su hallazgo M1, y ese documento tampoco está en el repositorio. Esta remediación agrega un sitio más.

**Consecuencia concreta que topé en esta verificación:** el mensaje de commit de `35c89aa` rotula como **I1** la corrección de cobertura temporal y como **I2** el cierre de `condiciones_uso`; el encargo de verificación los rotula al revés. Uno de los dos tiene la numeración cambiada y **no hay forma de determinar cuál desde el repositorio**. No lo relleno por contexto de chat: lo dejo como hallazgo de documentación insuficiente, que es exactamente lo que es.

---

## Hallazgos — MENOR

### M1. `doc/bitacora_verificaciones.md` es un archivo huérfano: nada lo referencia y ninguna regla obliga a actualizarlo

Busqué "bitacora_verificaciones" en todo el árbol: **cero coincidencias fuera del propio archivo**. No aparece en `README.md` (ni siquiera en el bloque de Estructura), ni en `CLAUDE.md`, ni en `CONTRIBUTING.md`, ni en el `Makefile`, ni en `.github/workflows/ci.yml`, ni en `ADR-009`, que es el ADR donde vive la nota de seguimiento sobre el verificador y que sí lo referencia (`ADR-009`, línea 56) pero apunta a `ADR-005`, no a la bitácora.

El propio archivo declara: *"Cada entrada corresponde a una corrida real, no a una intención de correrla."* Es la regla correcta, pero no está anclada en ninguna parte del sistema operativo del proyecto. Y el verificador **no puede correr en CI** por diseño (los `.xlsx` están en `.gitignore`, confirmado: `data/L0_raw/*` con excepción solo para `manifiesto.csv` y `.gitkeep`), así que la bitácora es el *único* canal de evidencia de esa verificación. Un canal único que depende de la memoria para mantenerse es exactamente la fragilidad que la senda §10.5 busca eliminar.

### M2. El puntero de las 5 YAML de ISSS manda a `R014` por un dato que `R014` no contiene

El texto recortado dice:
> "narrativa completa (discontinuación, reserva de información LAIP, **costo $0.04/página**) en 09_rupturas.csv R014_ISSS_ESTADISTICAS_RESERVA y en la fila ISSS de 00_instituciones.csv"

Leí la fila `R014_ISSS_ESTADISTICAS_RESERVA` completa, campo por campo: **no contiene "$0.04" ni ninguna referencia al costo de reproducción.** El dato sí está en `00_instituciones.csv` (ver verificación limpia abajo), de modo que **no hay pérdida de información** — el puntero simplemente nombra dos destinos y uno de los dos no tiene ese elemento. Se arregla o corrigiendo el puntero, o agregando la frase a `R014`.

### M3. Divergencia de procedencia entre el ADR y la YAML sobre qué URL de CEPAL se verificó — y la salvedad del ADR ya no se sostiene

`ADR-008` dice que se hizo fetch directo de la versión **en inglés** y que *"La URL en español específica que Harold cita no se re-verificó por fetch directo en esta sesión (restricción de la herramienta de navegación de Claude, no del hallazgo en sí)"*.

`CEPAL.CEPALSTAT.yaml` cita **solo la URL en español** y afirma: *"la existencia y el texto de la cláusula 4 fueron confirmados por Claude vía fetch directo (no snippet)"*. Leída sola, la YAML sugiere que se verificó la URL que cita, que no es lo que pasó.

Además: **traje la URL en español completa en esta sesión, sin restricción alguna.** La salvedad del ADR no describe una limitación del entorno sino de aquella sesión. Recomendación constructiva: el párrafo entero de "estándar probatorio" puede reemplazarse por una sola frase —*la cláusula 4 es verificable por cualquiera en la URL citada*— que es una posición más fuerte y no depende de un correo privado.

### M4. La nota de IVOPI describe una edición de catálogo que nunca llegó al repositorio

La nota dice: *"...sin confirmar a qué publicación se refería **antes de editar el catálogo**"*. El historial del archivo es `362d4fd` (2026-08-09) → `35c89aa` (2026-08-17), sin nada en medio; y `git show 362d4fd:...BCR.IVOPI.BASE_1990.yaml` da `cobertura_temporal: "ene-1990 a dic-2017."` — el valor original y el final son el mismo. El paso en falso existió en el borrador de sesión, no en el repositorio.

Esto **no** es un intento de borrar el error: el registro está y es honesto, que era lo esencial del encargo. Es solo que un tercero que reconstruya la historia con `git log` buscará un commit con "ene-1991" en IVOPI y no lo encontrará. Una frase — "el valor erróneo no llegó a commitearse" — cierra el punto. (Mismo origen, menor: el mensaje de commit dice "corrige `cobertura_temporal` de ... y de `BCR.IVOPI.BASE_1990`"; en IVOPI no se corrigió el valor, se anotó su historia.)

### M5. El ámbito de aplicación de la cláusula 4 a CEPALSTAT no está señalado como salvedad del hallazgo

Los Términos que verifiqué gobiernan `www.cepal.org` ("este Sitio"). CEPALSTAT vive en `statistics.cepal.org` y su API en `api-cepalstat.cepal.org` — que es la URL que la propia YAML declara en el campo `url`. El "Hallazgo" y la "Decisión aplicada" del ADR aplican la cláusula a CEPALSTAT sin registrar esa distancia; la pregunta sí aparece, pero solo dentro de la descripción del correo a CEPAL (punto (b) de la consulta).

No cambia ninguna decisión —el default conservador es robusto al error en ambas direcciones, por la propia lógica del ADR del 2026-08-12— pero el proyecto suele marcar este tipo de brecha explícitamente y acá no lo hizo.

---

## Verificaciones que resultaron limpias

Vale la pena decir qué se comprobó y salió bien, con las cifras.

**M1 del encargo — cifra "11 de 98" del comentario del verificador: recalculada de forma independiente y correcta.** Apliqué el mismo patrón que usa el script (`hoja ([^,]+), fila (\d+) \("([^"]+)"`) sobre las 98 filas de `03_series.csv` en `f7bae34` y comparé el rótulo citado contra `nombre_oficial`: 98 filas parsean, 87 iguales, **11 distintas**. Las 11 son coherentes con la explicación del comentario: 3 de redacción propia en filas de PIB agregado y 8 con marcador de nota al pie del BCR (`1/`, `2/`).

**I3 del encargo — la bitácora es aritméticamente consistente.** Los 4 `publicacion_id` del manifiesto son únicos, y las 98 filas de `03_series.csv` se reparten **exactamente** entre ellos: `..._NSA` 28, `..._SA` 28, `..._RETROPOLADA_1990_2005` 13, `..._NOMINAL` 29 = 98. Coincide dígito por dígito con lo que la propia bitácora declara. Como `verificar_fila()` devuelve `FAIL` (no `NO_VERIFICABLE`) cuando un `publicacion_id` falta del manifiesto, un solo `publicacion_id` huérfano habría hecho imposible el resultado declarado; no hay ninguno.

**Los 4 SHA-256 de la bitácora coinciden carácter por carácter con `manifiesto.csv`.** Comparación programática de los 64 caracteres de cada uno; 4/4 exactos, ningún archivo del manifiesto omitido.

**I1 del encargo — la cláusula 4 de CEPAL dice lo que el ADR afirma.** Hice `web_fetch` de las dos versiones oficiales. La española autoriza bajar y copiar los Materiales *"para su uso personal, sin fines comerciales, sin ningún derecho a revender, redistribuir, o crear otros trabajos a partir de los mismos"*; la inglesa dice lo mismo con "resell, redistribute or create derivative works therefrom". Es el punto 4 en ambas. La caracterización del ADR —más restrictiva que Banco Mundial, comparable al FMI, no un régimen de datos abiertos— es exacta.

**El matiz de "obras derivadas" está genuinamente señalado como abierto, no resuelto de facto.** El ADR lo titula "Matiz que excede el default de este ADR — pendiente, no resuelto por esta enmienda", dice que el default conservador *"probablemente no cubre por sí solo la actividad real que el proyecto ya realiza"*, y —el punto más fuerte— declara que el vencimiento del plazo **no** lo cierra: *"El vencimiento sin respuesta deja ese riesgo documentado como abierto, no resuelto por omisión"*. Es tratamiento honesto, no una resolución encubierta.

**Coherencia CEPAL entre ADR y catálogo: sin discrepancias.** Misma dirección (`cepalstat@cepal.org`), misma fecha de envío (2026-08-17), mismo corte (2026-10-16), misma cláusula, misma pregunta doble (términos generales vs. licencia específica tipo CC-BY "como en Banco Mundial y BID"). Nada que corregir acá.

**Aritmética del corte: correcta.** 2026-08-17 → 2026-10-16 son **exactamente 60 días**. El corte del BCR (2026-08-12 → 2026-10-12) son 61, pero ese ADR dice "aproximadamente sesenta días", así que ambos caben en el criterio declarado; la diferencia de un día viene de que el del BCR es "mismo día, dos meses después" y el de CEPAL es 60 días exactos. Nota al margen: dos meses exactos desde el envío a CEPAL caería en sábado 2026-10-17, así que el viernes 16 es la elección razonable de todos modos.

**Días de la semana declarados en ADR-008: los tres correctos.** 2026-08-07 = viernes, 2026-08-12 = miércoles, 2026-08-17 = lunes.

**Consistencia de fechas nuevas.** Extraje todas las fechas ISO de las líneas *añadidas* por `35c89aa`: `2026-06-11`, `2026-08-09`, `2026-08-12`, `2026-08-17`, `2026-10-12`, `2026-10-16`. Ninguna sin explicación — `2026-06-11` y `2026-08-12` son preexistentes que se conservan, `2026-10-12` es el corte del BCR que se cita en el encabezado, y `2026-08-09` es la fecha real del commit `362d4fd` que la nota de IVOPI cita como origen del valor (verificado: `362d4fd` es del 2026-08-09).

**I2 del encargo — la historia de revisión está documentada con honestidad, que es lo verificable.** `BCR.IVOPI.BASE_1990.yaml` declara `ene-1990 a dic-2017` y su nota narra los tres pasos en orden, incluido *"Error atribuible a Claude: se actuó sobre una respuesta breve y ambigua sin confirmar a qué publicación se refería"*. El error **no** fue limpiado. `BCR.IVAE.PROMEDIO_MOVIL_12M.yaml` documenta la corrección de ene-1991 → ene-1990 con la misma fecha y el mismo respaldo. Ambas afirmaciones sobre el estado original son verificables contra `362d4fd` y coinciden: IVOPI era `ene-1990`, IVAE.PM12 era `ene-1991`. La consistencia interna que la nota invoca también se sostiene: `BCR.IVAE.BASE_1990.yaml` declara `ene-1990 a dic-2017`.

**M3 del encargo — no se perdió información al recortar el bloque ISSS.** El dato específico sobrevive en `00_instituciones.csv`, fila ISSS, en forma equivalente y explícita: *"Portal opera bajo LAIP, no un modelo de datos abiertos: reproducción de documentos cuesta $0.04/página vía solicitud formal."* La frase que el recorte eliminó de esa misma fila ("Sin licencia abierta declarada") quedó cubierta por "no un modelo de datos abiertos", y la referencia a ADR-008 se conserva. El dato además sigue apareciendo dentro del propio `condiciones_uso` recortado.

**M2 del encargo — el cambio de redacción de `BM.GEP.yaml` es sustantivo, no cosmético.** Pasó de "Confirmada por Claude vía fetch directo..." a distinguir explícitamente: *"Es el metadato publicado en la página del catálogo, no una verificación de los datos observados vía API: la cobertura real de las observaciones que devuelve la API no se ha consultado."* Hace exactamente la distinción pedida.

**M4 del encargo — sin lenguaje de reescritura de historia.** Grepé `rebase`, `amend`, `force`, `squash`, `filter-branch`: **cero** en `CONTRIBUTING.md`. La única aparición de "reescrib" es la prohibición misma. Y la regla se cumple hacia adelante: `35c89aa` tiene sujeto de 54 caracteres y `bde69f6` de 26 (los cuatro commits previos van de 74 a 116, sin tocar).

**Alcance del commit: exactamente el esperado.** `35c89aa` toca 14 archivos — 13 modificados + `doc/bitacora_verificaciones.md` nuevo. Ni uno fuera. El diff acumulado `f7bae34..bde69f6` da 15 archivos: esos 14 más `README.md`.

**Integridad de filas: intacta.** `00_instituciones.csv` = 10 filas de datos y `03_series.csv` = 98 filas en `f7bae34`, `35c89aa` y `bde69f6`. Más aún: el contenido de `03_series.csv` es **byte a byte idéntico** en los tres commits.

**Validez de YAML y CSV.** Los 9 YAML tocados parsean con `yaml.safe_load` y todos conservan las 9 claves canónicas del `_plantilla.yaml`. Los 7 CSV del `datapackage.json` tienen encabezado idéntico en nombre y orden al esquema declarado, y ninguna fila con número de campos distinto al encabezado.

**Los "cuatro checks" del mensaje de commit: replicados y correctos.** Son los cuatro `test_that()` de `tests/test-catalogs.R`: (1) `datapackage.json` es JSON válido, (2) todos los catálogos declarados existen, (3) los catálogos de esquema cerrado tienen las columnas declaradas —`03_series`, `04_transformaciones`, `07_experimentos`, `08_vintages`—, (4) el manifiesto de L0 tiene sus 9 columnas en orden. Los repliqué en Python: **4/4 PASS**. La afirmación del mensaje de commit es cierta.

**`bde69f6` es efectivamente cosmético.** Su diff completo es una línea de `README.md`: un espacio añadido tras `doc/adr/`, que lleva la columna de descripciones de 20 a 21 caracteres, alineándola con las otras seis filas del bloque. No toca ninguno de los 14 archivos de la remediación.

---

## Límites de esta verificación — lo que no pude comprobar

Los dejo explícitos para que no se lean como respaldados.

1. **Que las 98 filas realmente hicieron PASS.** Eso exige los cuatro `.xlsx`, que están en `.gitignore` por diseño. Lo verificado es que la cifra es **aritméticamente consistente** y que los checksums citados son exactos — no que el contenido de las celdas coincida. La distinción es real y no la cierro.
2. **Que "ene-1990" sea el valor verdadero** de la cobertura de IVOPI e IVAE.PM12. Depende de la verificación de Harold contra el portal. Lo verificable —que el catálogo documenta su propia historia de revisión sin borrar el error— sí se comprobó.
3. **El contenido del correo a CEPAL.** El ADR declara que se conserva fuera del repositorio, mismo criterio ya establecido para el BCR. Es política deliberada, no omisión. Pero la nota de estándar probatorio del ADR *sí* apoya parte de su fuerza en el contenido de ese correo, y eso no es verificable por un tercero (ver M3, donde propongo que ya no hace falta que lo sea).
4. **El estado de CI sobre `35c89aa` y `bde69f6`.** La API de GitHub Actions me devolvió `403 rate limit exceeded` (IP compartida) en dos intentos, y la página de commits no expone el estado de los checks en el HTML servido. `CONTRIBUTING.md` exige CI en verde antes de integrar; conviene confirmarlo, aunque nada de lo que cambió estos dos commits puede razonablemente romperlo (los cuatro checks pasan localmente).

---

## Veredicto

**La remediación de I1–I3 y M1–M4 está sustantivamente bien hecha, pero no puede darse por cerrada todavía.**

Ítem por ítem, el trabajo resiste la verificación independiente. Recalculé todo lo recalculable en vez de aceptarlo, y no encontré una sola cifra mal: 11/98, 28+28+13+29=98, 4 checksums exactos, 4 checks replicados en verde, 14 archivos y ni uno más, 10 y 98 filas intactas, 9 YAML válidos, 60 días exactos, tres días de la semana correctos. Fui a la fuente primaria de CEPAL en sus dos idiomas y el ADR la representa fielmente. Los dos puntos donde más fácil habría sido hacer trampa —borrar el paso en falso de IVOPI, o perder el dato de $0.04/página al recortar ISSS— se resolvieron bien y de forma verificable. El matiz de obras derivadas está señalado como abierto de un modo que además resiste el vencimiento del plazo, que es más honesto de lo que el encargo pedía.

Lo que impide cerrarlo es C1: el commit declaró actualizar el "estado global de licencias" y lo hizo solo dentro del ADR. El índice de ADR y el `README.md` raíz siguen contando otra historia sobre ISSS, y ninguno menciona a CEPAL. Es la reincidencia de la forma exacta de C2/C3 de la auditoría de Fase 0, en el mismo archivo. No hay nada que reabrir ni rediseñar — son tres o cuatro líneas — pero mientras no se propague, "ADR-008 actualizado con el estado global de licencias" es una afirmación que el repositorio contradice a sí mismo.

Los dos IMPORTANTE son de la misma familia de completitud: el BID quedó fuera del ADR que gobierna licencias pese a tener la verificación directa que ese mismo ADR exige, y la auditoría que da nombre a todos estos códigos de hallazgo sigue sin estar en el repositorio —lo que ya tiene una consecuencia palpable: no pude determinar si la numeración I1/I2 correcta es la del mensaje de commit o la del encargo, y no la adiviné.

Con C1 propagado, yo daría los siete ítems por genuinamente cerrados.
