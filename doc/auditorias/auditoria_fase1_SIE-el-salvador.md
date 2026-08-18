## Auditoría independiente — Fase 1, SIE El Salvador

**Repositorio auditado:** `github.com/hsssst00/SIE-el-salvador` (clon fresco, no tarball)  
**HEAD real de `main` al momento de la auditoría:** `f7bae34` — _"Actualiza cobertura_temporal de BM.GEP.yaml…"_ (2026-08-17, 13:39 -0600). El repositorio contiene 59 commits en total; el trabajo de Fase 1 abarca del `fdc2425` (2026-08-09) al HEAD, más los adelantos de `03_series.csv` iniciados el 2026-08-13.  
**Tags:** `v0.1.0-fase0`, `v0.2.0-fase0-enmendado`, `v0.2.1-fase0-enmendado`. No hay tag de Fase 1 — correcto, porque Fase 1 no se declara cerrada en ninguna parte del repositorio.  
**Método:** `git clone` + `git log`/`git show`/diffs commit por commit; lectura directa de los 67 YAML de `01_publicaciones`, los 3 CSV de catálogo poblados, el manifiesto de L0 y el script verificador completo; verificación externa independiente de los términos de uso de CEPAL; consulta del estado de CI (con la limitación de método que se declara abajo).

----------

### Resumen para orientarse

El estado general es notablemente mejor que el que encontró la auditoría de Fase 0: la integridad referencial es total, la disciplina epistémica ("hecho documentado" vs. "decisión de diseño" vs. "relevamiento pendiente de verificación de Harold") se aplica de verdad en la enorme mayoría de las fichas, y el incidente de pisado de contenido en `65a2102` fue detectado y reparado _dentro del propio historial_ antes de esta auditoría. **No encontré ningún hallazgo crítico** — ninguna contradicción entre catálogos, ninguna certificación falsa, ningún dato que un tercero leería como verificado sin serlo… con tres excepciones de registro que clasifico como IMPORTANTES, porque las tres tocan exactamente el criterio de cierre de Fase 1 ("registro verificado de disponibilidad, cobertura y frecuencia") o el estándar probatorio que ADR-008 se impuso a sí mismo.

El veredicto anticipado: el criterio de cierre de Fase 1 **no está satisfecho hoy**, y el repositorio —a diferencia del episodio de Fase 0— **no afirma lo contrario**. La fase está genuinamente en curso.

----------

### Hallazgos — CRÍTICO

Ninguno.

----------

### Hallazgos — IMPORTANTE

#### I1. Los términos restrictivos de CEPAL y la consulta a `cepalstat@cepal.org` no están registrados en ninguna parte del repositorio

`catalogos/01_publicaciones/CEPAL.CEPALSTAT.yaml`, campo `condiciones_uso`, dice únicamente: _"No verificadas en esta sesión. Pendiente verificación directa de Harold."_ Busqué `cepalstat@`, `terminos-condiciones` y variantes en todo el árbol (`.md`, `.yaml`, `.csv`): cero resultados fuera de la ficha misma. Ni la ficha, ni `00_instituciones.csv` (fila CEPAL), ni `ADR-008` mencionan (a) los términos generales del sitio de la CEPAL ni (b) consulta alguna enviada a la institución.

Verifiqué los términos de forma independiente: la cláusula 4 del convenio estándar de uso del sitio de la CEPAL autoriza a bajar y copiar materiales exclusivamente para uso personal y sin fines comerciales, sin ningún derecho a revender, redistribuir ni crear obras derivadas. Es decir: **CEPAL es, hoy, la fuente con el régimen más restrictivo de todo el catálogo** — más restrictivo que el default conservador de ADR-008 — y la ficha lo rotula como simple "no verificado", que un tercero leería como "nadie lo miró todavía", no como "se miró y es restrictivo".

Salvedad epistémica que me corresponde declarar: la existencia de la consulta enviada a `cepalstat@cepal.org` me consta solo por el encargo de esta auditoría, no por el repositorio — lo que puedo afirmar con verificación propia es que los términos restrictivos existen y que ninguna de las dos cosas está registrada. El punto de comparación es el propio ADR-008, enmienda BCR: ahí el proyecto registró la consulta con tabla de fechas, fecha de corte (2026-10-12) y la justificación explícita de que sin fechas asentadas _"la decisión quedaría indistinguible de no haber consultado nunca"_. La gestión con CEPAL está hoy exactamente en esa situación de indistinguibilidad que el ADR declaró inaceptable para el BCR.

#### I2. `BCR.IVOPI.BASE_1990.yaml` y `BCR.IVAE.PROMEDIO_MOVIL_12M.yaml` declaran cobertura como hecho liso, mientras el commit más reciente que tocó a su hermana los declara pendientes

El commit `e1184fb` (2026-08-17, _"Confirma cobertura temporal de BCR.IPRI.BASE_1990…"_) dice en su cuerpo, textual: _"BCR.IVOPI.BASE_1990 y BCR.IVAE.PROMEDIO_MOVIL_12M, que comparten la misma URL, siguen pendientes de verificación individual."_ Pero ese commit solo modificó el YAML de IPRI (confirmado por `--stat`), y los otros dos YAML dicen hoy, sin ningún marcador epistémico:

-   `BCR.IVOPI.BASE_1990.yaml`, `cobertura_temporal`: `"ene-1990 a dic-2017."`
-   `BCR.IVAE.PROMEDIO_MOVIL_12M.yaml`, `cobertura_temporal`: `"ene-1991 a dic-2017."`

El pendiente vive únicamente en el mensaje de commit — que no es parte del catálogo. Un tercero que lea solo los YAML (que es el contrato del sistema) toma esas coberturas como establecidas, cuando la URL que las sustenta devolvió error 500 el 2026-08-12 y su verificación individual sigue abierta según el propio registro del proyecto. Es exactamente la taxonomía que Fase 1 exige respetar, colapsada en dos fichas.

#### I3. No existe evidencia registrada en el repositorio de que `verificar_fuente_celda.R` haya corrido nunca contra los archivos reales — ni sobre las 50 filas iniciales ni sobre las 98 actuales

El script (`src/validacion/verificar_fuente_celda.R`, 286 líneas) está bien construido — ver "verificaciones limpias" — y las 98 filas de `03_series.csv` parsean su patrón (lo verifiqué yo). Pero:

-   El commit que lo agrega (`b615c45`) tiene mensaje de una sola línea, sin declaración de corrida ni resultado.
-   El commit que agrega las 48 series posteriores al script (`d547ca1`) tampoco declara verificación.
-   Ninguna de las 98 filas de `03_series.csv` menciona el verificador ni un resultado PASS en `notas` (grep: 0 coincidencias).
-   El workflow de CI (`.github/workflows/ci.yml`) no lo ejecuta — y ejecutarlo en CI daría 98× `NO_VERIFICABLE` porque los `.xlsx` están en `.gitignore`, así que la única evidencia posible de una corrida real es una declaración registrada, y no la hay.

Esto importa porque el propio historial demuestra que el riesgo es real: `c60e808` corrigió una `fuente_celda` de la serie que sostiene la variable objetivo primaria que citaba Impuestos Netos e Importaciones en vez de los totales del PIB — _"Un script escrito contra el catálogo habría extraído impuestos netos"_, en palabras del propio commit. El mecanismo para impedir la reincidencia existe; el registro de que se usó, no. Nótese además que 48 de las 98 filas (49%) entraron al catálogo _después_ de que el script existiera, en un solo commit sin declaración de verificación.

----------

### Hallazgos — MENOR

#### M1. Comentario del verificador desactualizado respecto del catálogo que verifica

`src/validacion/verificar_fuente_celda.R`, encabezado (líneas 6-9): justifica comparar contra `fuente_celda` y no contra `nombre_oficial` porque _"son literales distintos en 7 de 50 filas"_. El catálogo tiene hoy 98 filas y el conteo real de divergencias es **11 de 98** (lo calculé contra el CSV actual). El argumento de diseño sigue siendo válido; el número que lo ilustra quedó congelado en el estado previo al lote de 48 series.

#### M2. `BM.GEP.yaml`: el rótulo "Confirmada" en `cobertura_temporal` refiere a metadata de la página del catálogo, no a datos

El campo dice _"Confirmada por Claude vía fetch directo de la página oficial del catálogo (2026-08-17): 2023-2027, periodicidad Annual"_. Lo confirmado es la _declaración_ de la página del datacatalog, no la cobertura observada en la API (que para GEP nunca se consultó a nivel de datos). La ficha es transparente sobre la vía, y `notas` conserva el "pendiente verificación directa de Harold contra la API" — pero el verbo "Confirmada" en el campo estructurado puede leerse más fuerte de lo que la evidencia sostiene. Es la distinción hecho-documentado / verificación-de-dato aplicada a medias.

#### M3. El bloque justificativo de la decisión ISSS se repite íntegro y textual en 5 archivos

Las 5 YAML de `ISSS.*` llevan en `condiciones_uso` el mismo párrafo de ~150 palabras (decisión de Harold 2026-08-17 + motivo + cruce a R014), copiado verbatim. El cruce a R014 es correcto y necesario; la narrativa completa quintuplicada roza el criterio transversal §10.6 de la senda ("cada hecho registrado en un solo lugar"). El lugar natural del razonamiento es R014 (donde ya está) o la fila ISSS de `00_instituciones.csv`; las fichas podrían llevar solo la decisión y la referencia.

#### M4. Sujetos de commit largos (cosmético)

Ocho sujetos superan los 72 caracteres (p. ej. `904f6ac`, 130+ caracteres). Ninguno es un prompt pegado ni nada desprolijo — el estilo imperativo de una línea se mantiene en los 59 commits, con cuerpos extensos y bien escritos donde corresponde. Solo anoto la longitud por consistencia con la convención habitual de Git.

----------

### Verificaciones que resultaron limpias

-   **`03_series.csv`: 98 filas exactas**, cero `serie_id` duplicados, cero `fuente_celda` vacías, las 98 parsean el patrón regex del verificador, y las 15 columnas coinciden en nombre y orden con `datapackage.json` (cuya extensión `+anio_referencia_indice` está documentada inline en `estado_esquema`).
-   **Integridad referencial completa:** todo `publicacion_id` de `03_series` resuelve contra un YAML real; toda `metodologia_id` contra `02_metodologias`; los 4 `vintage_id` del manifiesto coinciden uno a uno con `08_vintages.csv`, con SHA-256 idénticos en ambos lados; `institucion_id` de las 67 YAML resuelve contra las 10 filas de `00_instituciones.csv`; `publicacion_id` interno de cada YAML coincide con su nombre de archivo.
-   **El pisado de `65a2102` fue restaurado por completo.** Comparé el diff de lo perdido (hallazgo GEM/§6.4, checklist de 4 puntos, nota de redundancia de BOP, condiciones CC-BY) contra el HEAD: todo el contenido previo está presente en `BM.GEM.yaml` y `FMI.BOP.yaml`, fusionado con la verificación de cobertura nueva, con los puntos del checklist marcados RESUELTO/SIGUE ABIERTO individualmente. `b0ccaad` hizo lo que su mensaje dice.
-   **`00_instituciones.csv`: CEPAL y BID están, con contenido real y de calidad** — la fila BID documenta la corrección Socrata→CKAN con verificación por curl contra `status_show`; la fila CEPAL documenta la discrepancia de entorno JSON/xlsx con la honestidad de no atribuir causa.
-   **Cruce ISSS × R014 consistente:** `R014_ISSS_ESTADISTICAS_RESERVA` existe, su `series_afectadas` lista exactamente las 5 publicaciones ISSS con `tipo_referencia=publicacion_id`, y nada en las YAML contradice a R014. La distinción "confirmado directamente por Harold" (nota aclaratoria e índice de reserva) vs. "relevamiento pendiente" (cobertura, conteos) está explícita en las notas de R014.
-   **`09_rupturas.csv` no fue tocado por el trabajo de licencias:** su último cambio es del 2026-08-12 (`e1b6025`); los commits de condiciones de uso del 2026-08-17 no lo modifican. Las 14 rupturas registradas son todas metodológicas o de disponibilidad, ninguna espuria.
-   **El verificador está bien escrito.** Resuelve hoja→XML vía `workbook.xml.rels` (sin asumir `sheetN.xml`), concatena runs múltiples de `sharedStrings` (sin lo cual rótulos con marcador de nota al pie se truncarían), verifica checksum contra el manifiesto antes de abrir el archivo, distingue `FAIL` de `NO_VERIFICABLE` exactamente como el encargo describe, y falla con `stop()` — no advierte — conforme a la regla 7 de `CLAUDE.md`. El uso de `digest` como transitiva no declarada está autojustificado en el encabezado con criterio y con condición de reversión.
-   **Distinción Harold/Claude sostenida en el bloque de licencias:** BID.LATIN_MACRO_WATCH y BID.SOCIAL_INDICATORS dicen "Verificado directamente por Harold" (con package_id y DOI distintos, verificados por separado, no por extensión); BM.GEM y BM.GEP dicen "CONFIRMADO por Claude vía fetch" y conservan el pendiente de Harold en notas. El commit `03a8708` describe con precisión lo que hizo.
-   **Adelantos de fase declarados, no silenciosos:** el trabajo sobre `03_series.csv` es materialmente de Fase 3 (la senda lo lista como entregable de esa fase), igual que la captura de L0 lo era de Fase 2 — y como entonces, está hecho a la vista, con mensajes de commit que documentan las identidades contables verificadas (aditividad de nominales, no-aditividad de volumen encadenado advertida en 54 de las 56 fichas de volumen, FBK vs. FBKF como series distintas).
-   **La senda metodológica está en el repositorio** (`doc/senda_metodologica.md`, v0.2 con historial de versiones), el enlace del README resuelve, y Fase 1 se sigue describiendo como en curso — no hay ninguna declaración de cierre que auditar contra la realidad.
-   **CI:** el badge del workflow `ci.yml` sobre `main` muestra **passing**. Limitación de método que declaro en vez de disimular: la API de GitHub Actions me devolvió `403 rate limit` (IP compartida de este entorno, sin autenticación) en todos los intentos, así que no pude confirmar de forma independiente el mapeo corrida↔commit para `f7bae34` específicamente; el badge refleja la última corrida completada del workflow en la rama por defecto. El job `check-l0-integrity` sigue siendo el _stub_ heredado (`echo "Pendiente…"`), pendiente #16 de Fase 2 — sin cambio de estado, no es hallazgo nuevo.

----------

### Pendientes consolidados

#

Pendiente

Fuente exacta

Fase

1

Registrar en el repositorio los términos restrictivos de CEPAL y la gestión de consulta (fechas, corte), al estándar de la enmienda BCR

I1; `ADR-008`; `CEPAL.CEPALSTAT.yaml`

1

2

Propagar el estado "pendiente de verificación individual" a `cobertura_temporal` de IVOPI e IVAE.PM12, o verificarlas

I2; commit `e1184fb`

1

3

Registrar (idealmente en nota de catálogo o bitácora) la corrida del verificador sobre las 98 filas contra los archivos reales

I3; `d547ca1`

1

4

Consulta BCR sobre redistribución — corte 2026-10-12; a esa fecha se resuelve también la política de L0 del Banco Mundial

`ADR-008`, enmiendas 2026-08-12

1

5

Condiciones de uso abiertas en 52 de 67 publicaciones (BCR en bloque vía consulta; ONEC, SECMCA, MH sin gestión registrada)

campos `condiciones_uso`

1

6

Cobertura temporal no verificada en 8 publicaciones: las 3 de FRED, FMI.WEO/BOP/PCPS, BM.WDI, ONEC.IPC.BASE_1992

campos `cobertura_temporal`

1

7

GEM: rezago de publicación (punto 3) y retransmisión vs. información propia (punto 4) siguen abiertos

`BM.GEM.yaml`, checklist

1

8

Dataflows FMI no evaluados: IIP, ITG, IMTS, ITS

`FMI.BOP.yaml`, notas

1

9

Paralelo QNEA↔BOP del corte de consumo de hogares/ISFLSH

`FMI.BOP.yaml`

1

10

Disparador ADR-009: decisión cliente-de-API vs. cliente propio antes del primer script de adquisición

`ADR-009`, nota 2026-08-12

2

11

Disparador ADR-009: enmienda `readxl` antes del primer script de `src/transformacion/` que lea valores

`ADR-009`, nota 2026-08-15

3

12

Script real de verificación de checksums de L0 en CI (stub heredado)

`.github/workflows/ci.yml`

2

13

Series de las ~63 publicaciones restantes aún no inventariadas en `03_series` (adelanto de Fase 3, ritmo a discreción)

`03_series.csv`

3

----------

### Veredicto

**¿Está genuinamente satisfecho el criterio de cierre de Fase 1? No — y el repositorio no pretende que lo esté, que es la diferencia decisiva con el episodio auditado en Fase 0.**

El criterio de la senda es doble: _"ninguna variable ingresa al proyecto sin registro verificado de disponibilidad, cobertura y frecuencia"_ y _"el número real de observaciones de la variable objetivo está establecido y documentado"_. La segunda mitad está cumplida y cerrada desde la enmienda de ADR-003 (D3 resuelto, empalme documentado, 145 observaciones trazables a celda — con la corrección `c60e808` como prueba de que el mecanismo de trazabilidad se ejercita de verdad). La primera mitad no: hay 8 publicaciones con cobertura declarada como no verificada —entre ellas las tres de FRED y el FMI.WEO, que no son periféricas sino las fuentes estructurales del predictor de actividad de EE.UU. y de los supuestos exógenos del Ejercicio B—, 52 publicaciones con condiciones de uso abiertas cuyo mecanismo de cierre fechado existe solo para BCR y Banco Mundial, y los tres huecos de registro I1–I3, de los cuales el de CEPAL es el que más urge cerrar porque contradice el estándar probatorio que ADR-008 fijó con sus propias palabras.

Nada de esto exige reabrir decisión alguna: I1 e I2 son propagaciones de información que ya existe fuera del repositorio hacia adentro de él, e I3 es una línea de registro. El patrón de fondo es idéntico al de la auditoría anterior —el trabajo se hace bien, el registro de que se hizo a veces se queda en la sesión de chat o en el mensaje de commit en vez de en el catálogo— pero con una mejora sustantiva: esta vez no hay ninguna certificación que desdiga la realidad, y la maquinaria de honestidad epistémica (marcadores Harold/Claude, inferencia/hecho, RESUELTO/SIGUE ABIERTO) está funcionando en el grueso del inventario. Fase 1 está donde dice estar: en curso, con el terreno firme y los pendientes a la vista.
