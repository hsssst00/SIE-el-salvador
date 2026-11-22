# Fase 7 — registro de decisiones

**Fecha:** 2026-11-20 · **Estado:** F7-02, F7-03 y F7-05 a F7-12 decididas por Harold el 2026-11-20 en la opción
recomendada de cada ficha. F7-01 y F7-04 siguen **abiertas**: dependen de la persona que haga la prueba externa.

**Para qué sirve este documento.** Es el equivalente de `decisiones_fase6.md` para Fase 7: cada ficha lleva la línea
**DECIDIDO** con el texto operativo, y el Acta es el índice. Las correcciones posteriores entran como notas fechadas;
no se reescribe lo registrado. El tablero de avance es `doc/checklist_fase7.md`.

## Origen de estas decisiones

Las fichas F7-01 a F7-12 se redactaron en el chat el 2026-11-20, sobre `0634301` (`v0.9.1-fase6`) y sin tocar el
repo, con hechos verificados, opciones, implicación práctica y una recomendación cada una. El mismo día Harold eligió
decidir primero las que no dependen de nadie más y las tomó todas en la opción recomendada. No hubo delegación: desde
el cierre de Fase 6 la regla 4 de `CLAUDE.md` rige sin excepciones. F7-12 crea una delegación nueva, acotada, que se
registra en la regla 4 en este mismo commit, antes de usarse.

## Hechos verificados el 2026-11-20 que entran a las fichas

- **El repo ya es público** (API de GitHub), con licencia MIT detectada. No tiene GitHub Pages, *releases* ni
  *webhooks*: Zenodo no está conectado.
- **L0 no se puede publicar casi entera.** De las 92 filas de `data/L0_raw/manifiesto.csv` (BCR 46, UT 26, FMI 8,
  FRED 7, BM 2, ONEC 2, CBO 1), 89 siguen el default conservador de ADR-008. Solo BM y CBO admiten publicar el crudo
  (enmiendas del 2026-10-14 y del 2026-10-17). Un clon limpio no reconstruye L3 sin el almacén privado
  (`scripts/materializar_l0.R`). La auditoría independiente de Fase 6 lo señala como el límite que ninguna revisión
  pudo ejercer.
- **La L3 vigente está un trimestre atrás de L0.** `data/L3_master/` (sin `CONJUNTO=`) se generó por última vez el
  2026-09-30 y su PIB termina en 2026-Q1 (`BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA.v2026-06`). L0 tiene el
  2026-T2 (`…v2026-09`) desde la captura del 2026-10-01, y `doc/metodologia/corte_fase6.csv` ya lo usa. El paso 6 de
  la ventana mensual de `doc/backlog_captura_vintages.md` («`make master` … si algo capturado alimenta L3») no se
  corrió en octubre. Para el sistema vigente, el trimestre siguiente es el 2026-T2.
- **El PIB 2026-T3 no está anunciado** en `doc/calendario_divulgacion_bcr.csv`.
- **Quarto ya está en ADR-009** (tabla de componentes, «Documentación / sitio»). `make report` todavía no hace nada y
  `src/reportes/` está vacío.
- **AP-2 está sin implementar.** `doc/metodologia/protocolo_prospectiva_ap2.md` §6 pide implementarla antes de que se
  publique el PIB de 2026-T3.

## Acta

| Ficha | Tema | Estado | Fecha |
|---|---|---|---|
| F7-01 | Quién es el «investigador externo» | ABIERTA | — |
| F7-02 | Qué cuenta como «la publicación del trimestre siguiente» | DECIDIDO | 2026-11-20 |
| F7-03 | Hasta qué capa llega «actualizar el sistema» | DECIDIDO | 2026-11-20 |
| F7-04 | Cómo obtiene L0 el investigador externo | ABIERTA | — |
| F7-05 | Manual de usuario y manual de actualización | DECIDIDO | 2026-11-20 |
| F7-06 | Sitio de documentación | DECIDIDO | 2026-11-20 |
| F7-07 | *Vignettes* | DECIDIDO | 2026-11-20 |
| F7-08 | DOI | DECIDIDO | 2026-11-20 |
| F7-09 | Versión de cierre | DECIDIDO | 2026-11-20 |
| F7-10 | Prospectiva AP-2 | DECIDIDO | 2026-11-20 |
| F7-11 | Registro del cierre | DECIDIDO | 2026-11-20 |
| F7-12 | Flujo de trabajo y delegación | DECIDIDO | 2026-11-20 |
| F7-13 | Captura fuera de ventana (D3) asistida | DECIDIDO | 2026-11-21 |
| F7-14 | Sincronización de L0 con el almacén | DECIDIDO | 2026-11-22 |

---

## Bloque A — lecturas del criterio de cierre

El criterio de cierre (senda §4) es «un investigador externo puede actualizar el sistema con la publicación del
trimestre siguiente siguiendo únicamente el manual». F7-01 a F7-04 son sus lecturas. Por la regla 4 se preguntan
siempre; ninguna delegación las cubre. Al cerrar la fase van a la nota de cierre de Fase 7 de la senda.

### F7-01. Quién es el «investigador externo» — ABIERTA

Opciones redactadas: (a) una persona real, distinta de Harold y del agente, que no haya trabajado en el repo y corre el
manual en su máquina, dejando una bitácora textual; (b) Harold en una máquina limpia; (c) el agente sobre un clon
limpio o en CI. Recomendada: (a), con (b) como ensayo previo. Queda abierta porque depende de conseguir a esa persona.

### F7-02. Qué cuenta como «la publicación del trimestre siguiente»

**DECIDIDO (Harold, 2026-11-20).** Dos tiempos:
1. **Ensayo, ahora, sin actor externo:** llevar la L3 vigente de 2026-Q1 a 2026-Q2 (PIB `v2026-09`, ya en L0)
   siguiendo el borrador de `doc/manual_actualizacion.md`, y corregir el manual con lo que falle. El ensayo no ejerce
   la captura del PIB, porque ya se hizo el 2026-10-01; la captura se ejerce en la ventana mensual siguiente.
2. **Prueba del criterio:** el primer PIB trimestral que publique el BCR **después de congelar el manual** con el tag
   `manual-v1`. Si el manual se congela antes de que se publique el 2026-T3, es ese trimestre; si no, el siguiente. El
   manual no se edita entre el tag y la prueba; una corrección crea `manual-v2` y mueve la prueba al trimestre
   siguiente.

### F7-03. Hasta qué capa llega «actualizar el sistema»

**DECIDIDO (Harold, 2026-11-20).** De L0 a la L3 vigente certificada: captura con su `descargar_*()`,
`data/L0_raw/manifiesto.csv` y `catalogos/08_vintages.csv`, `make validate`, `make master` sin `CONJUNTO=`, `make
trace` con su entrada en `doc/bitacora_verificaciones.md` (regla 8), las pruebas y el CI en verde sobre el PR. Los
ejercicios de Fase 5 y Fase 6 (cortes congelados, preregistros, `data/L4_experiments/`) no forman parte de la
actualización y no se vuelven a correr.

### F7-04. Cómo obtiene L0 el investigador externo — ABIERTA

Opciones redactadas: (a) acceso de lectura al repo privado de L0 para la persona nombrada, solo para la prueba, con una
nota fechada en ADR-008 que registre si eso es o no redistribución; (b) reconstruir L0 desde las fuentes con sus
propias capturas; (c) (a) más publicar ya los crudos de BM y CBO que admite la política del 2026-10-14. Recomendada:
(a), con (c) opcional. Queda abierta porque depende de F7-01 y porque la lectura de ADR-008 es de Harold.

## Bloque B — forma de los entregables

### F7-05. Manual de usuario y manual de actualización

**DECIDIDO (Harold, 2026-11-20).** Dos documentos. `doc/manual_usuario.md`, para quien consulta y usa las series y los
catálogos: qué hay, cómo se lee la base bitemporal, cómo se cita y qué es condicional. `doc/manual_actualizacion.md`,
para quien opera el sistema; el criterio de cierre se juzga solo contra este. Se agrega `manual_usuario.md` al árbol
de §7 de la senda.

**Nota (2026-11-20).** Primer borrador de `doc/manual_actualizacion.md` para el ensayo (checklist C1). Detalles fijados
por el agente, **delegada al agente; se puede reabrir** (F7-12): la estructura de once secciones y cuatro anexos, la
huella de L3 por sha256 guardada fuera del repo (sección 4) y el anexo D con la situación de partida del ensayo.
Hecho verificado al redactarlo: `src/transformacion/extraer_bcr_pib.R` lee hasta el `periodo_referencia_max` del
vintage (F6-19), así que un trimestre nuevo del PIB no exige editar `fin` ni `col_fin` en `03_series.csv`. Sí lo exige
un año nuevo de UT, como ya decía el backlog.

### F7-06. Sitio de documentación

**DECIDIDO (Harold, 2026-11-20).** Sitio Quarto que reúne los `.md` de `doc/` sin duplicarlos, publicado en GitHub
Pages por un *workflow* desde `main`. La versión de la CLI de Quarto se fija en el *workflow* y lo que se ejecuta usa
`freeze`. Como `renv` no fija la CLI de Quarto, la versión se registra en una nota de seguimiento de ADR-009 en el
mismo PR que agrega el *workflow*.

### F7-07. *Vignettes*

**DECIDIDO (Harold, 2026-11-20).** Tres: (1) catálogos y trazabilidad de una serie desde L3 hasta la celda, que corre
en CI; (2) consulta de la base bitemporal por `vintage_id`, con `freeze` sobre L3 y con el commit y la fecha a la
vista; (3) lectura de los resultados de Fase 5 y Fase 6 desde las tablas versionadas de `doc/metodologia/`, que corre
en CI. **Derivados:** Harold confirma que publicar series derivadas del BCR (los valores de L3 de la *vignette* 2)
está permitido. ADR-008 restringe la redistribución de los crudos, no la de los derivados, y los informes de Fase 5 y
Fase 6 ya publican derivados. La condición de CEPAL sobre obras derivadas sigue vigente y no aplica, porque ninguna
serie de CEPAL está admitida.

### F7-08. DOI

**DECIDIDO (Harold, 2026-11-20).** Harold conecta Zenodo con su cuenta de GitHub ahora (no es delegable). El primer
*GitHub Release* sale en el cierre, con `v1.0.0-fase7`. Los metadatos salen de `CITATION.cff`, que gana `abstract`,
`keywords` y, si Harold los da, ORCID y afiliación; no se agrega `.zenodo.json`, porque Zenodo ignora
`CITATION.cff` cuando hay uno. El DOI de concepto entra al `README.md` y a `CITATION.cff` en un commit posterior al
*release*. El archivo que guarda Zenodo no incluye L0, que no está en el repo (ADR-008).

**Nota (2026-11-20).** Harold conectó Zenodo con su cuenta de GitHub: el repo tiene un *webhook* activo de
`zenodo.org` para el evento `release` (API de GitHub). Dio su ORCID, que entra a `CITATION.cff`; no dio afiliación, así
que no se agrega. Detalles fijados por el agente, **delegada al agente; se puede reabrir** (F7-12): `type: software`;
el texto de `abstract`; la lista de `keywords`; y `license` sigue en `MIT` sola, porque el campo describe el código y
la licencia de la documentación (CC-BY-4.0) ya consta en `LICENSE-docs` y en el resumen. `version` y `date-released`
no cambian hasta el cierre (F7-09). El archivo se validó contra el esquema JSON de CFF 1.2.0.

### F7-09. Versión de cierre

**DECIDIDO (Harold, 2026-11-20).** `v1.0.0-fase7`. En el commit de cierre, `CITATION.cff` pasa a 1.0.0 con la fecha del
cierre (lo exige `tests/test-adr-indice.R`) y `DESCRIPTION` se alinea a 1.0.0.

## Bloque C — proceso

### F7-10. Prospectiva AP-2

**DECIDIDO (Harold, 2026-11-20).** AP-2 sigue su propio protocolo (`doc/metodologia/protocolo_prospectiva_ap2.md`) y
su plazo, en PR aparte y fuera de los criterios de Fase 7. La implementación arranca ya, para llegar antes de que se
publique el PIB de 2026-T3. El manual de actualización la menciona como un paso opcional que existe solo cuando esté el
tag `prospectiva-v1`.

### F7-11. Registro del cierre

**DECIDIDO (Harold, 2026-11-20).** Como en las fases anteriores: «Cierre de Fase 7» en `doc/adr/README.md`; nota de
cierre de Fase 7 en la senda §4 con las lecturas de F7-01 a F7-04; la bitácora de la prueba externa, sin editar, en
`doc/evidencia_cierre_fase7.txt`; y una revisión independiente aparte en `doc/auditorias/`.

### F7-12. Flujo de trabajo y delegación

**DECIDIDO (Harold, 2026-11-20).** Todo cambio entra por PR contra `main` con el CI en verde, y `CONTRIBUTING.md` lo
dice así en este mismo commit. Harold delega al agente los **detalles de implementación** de F7-05 a F7-09 (redacción
de los documentos, configuración de Quarto y del *workflow*, *vignettes*, `CITATION.cff` y `DESCRIPTION`) y la
**fusión** de los PR que solo implementan esas fichas, con el CI en verde sobre la cabeza del PR y sin apilar. El
texto de la delegación, con sus exclusiones, está en la regla 4 de `CLAUDE.md`. Los detalles que fije el agente se
rotulan **«delegada al agente; se puede reabrir»**.

### F7-13. Captura fuera de ventana (ADR-007 D3) asistida

**Hecho (ensayo con el 2026-T2, 2026-11-21).** La sección 6.3 del borrador del manual era confusa: listaba las tres
condiciones de D3 sin decir cómo comprobarlas ni qué escribir. Harold propuso automatizar la decisión.

**DECIDIDO (Harold, 2026-11-21), opción recomendada.** Se automatiza la decisión con confirmación por publicación:
una pasada de `raw-rapido`, las condiciones de D3 comprobadas contra el calendario y `08_vintages.csv`, la tabla de
candidatas y una pregunta «s/n» por cada una antes de llamar a su `descargar_*()`. Va con una nota de seguimiento en
ADR-007 que fija que «a mano» incluye esa confirmación. Se descartaron: solo la decisión, con el comando para copiar;
y todo automático, que contradice D3 («nunca en bucle») y exigiría enmendar ADR-007 y la regla 9.

**Detalles de implementación** (fuera de la delegación de F7-12; los revisa Harold en el PR):
- Es una función de consola, `source("src/adquisicion/captura_d3.R"); captura_d3()`, no un objetivo de `make`. La
  confirmación necesita la consola: un `Rscript` lanzado por `make` o por `system()` no puede leer la respuesta. Un
  objetivo de `make` que solo mostrara la tabla obligaría a una segunda pasada de `raw-rapido` para capturar (regla 9).
- `scripts/verificar_l0_rapido.R` guarda el último período que sirve la fuente en `trabajo$periodo_fuente`; su salida
  no cambia.
- La fecha de publicación es el día 01 del mes en que el calendario anuncia **ese** período; si el calendario no lo
  anuncia, la publicación no cumple (b) y espera la ventana.

**Mapeo del PIB en el calendario.** El calendario mapeaba solo la serie desestacionalizada del PIB (`CALENDARIO_BCR_VARIABLE` en
`src/adquisicion/verificacion_rapida.R`). La original (NSA, de la que sale `PIB_SA_PROPIO_Q`) y la nominal no tienen
fila, así que nunca cumplen (b): el día que se publique un trimestre nuevo, D3 permitiría capturar la SA pero no la
NSA. Decidir si las dos se leen con la fila de la SA era un cambio de mapeo de Harold.

**DECIDIDO (Harold, 2026-11-21), opción recomendada.** NSA y nominal se leen con la fila del PIB desestacionalizado en
`CALENDARIO_BCR_VARIABLE`. El BCR publica las tres juntas: tienen el mismo mes de publicación en todos sus vintages de
`08_vintages.csv` (`v2026-06` y `v2026-09`). Con eso, D3 permite capturar las tres el mismo día, y `raw-rapido` deja de
sondear NSA y nominal cuando el calendario dice `NO_TOCA`. Si alguna vez el BCR las publica por separado, el nivel 2 de
`raw-rapido` lo ve igual.

**Nota (2026-11-21, más tarde).** Primera ventana real con `captura_d3()`, en la copia principal de Harold:
`BCR.GOBIERNO_CENTRAL_CONSOLIDADO` falló por timeout del portal (`doc/bitacora_fuentes_fragiles.md`), y la consola no
aceptó la respuesta a la segunda pregunta (`BCR.IPI.VIGENTE`). Nada se escribió en L0. Se reemplaza la pregunta
`readline()` por dos llamadas, `planear_d3()` y `capturar_d3("<publicacion_id>")`, que funcionan igual en la consola,
con Ctrl+Enter, en un chunk o con `Rscript`. El detalle de que es una función de consola y no un `make` se mantiene:
`planear_d3()` hace la única pasada de `raw-rapido`, y `capturar_d3()` usa su plan sin volver a sondear.

### F7-14. Sincronización de L0 con el almacén privado

**Hecho (2026-11-22).** Las cinco capturas D3 del 2026-11-21 (`BCR.IPI.VIGENTE`, `BCR.ISI`,
`BCR.PANORAMA_BANCO_CENTRAL`, `BCR.RESERVAS_INTERNACIONALES_NETAS` y `ONEC.IPC.BASE_2009`, todas `v2026-11`) quedaron
en `data/L0_raw/` de la copia de Harold y no en el almacén. `make materializar-l0` solo copia del almacén a L0, y la
dirección inversa era un `git add` manual (cabecera de `scripts/materializar_l0.R`). Una copia nueva no podría
materializar L0 cuando el manifiesto registre esas filas. Harold pidió un mecanismo.

**DECIDIDO (Harold, 2026-11-22), opción recomendada.** `make sincronizar-l0` (`scripts/sincronizar_l0.R`, lógica en
`src/adquisicion/sincronizacion_l0_lib.R`), en las dos direcciones y con push:
1. El almacén tiene que estar limpio y avanzar solo por avance rápido (`git pull --ff-only`); si no, se detiene.
2. Cada fila del manifiesto se clasifica: en los dos lados, solo en L0 (se sube), solo en el almacén (se baja), en
   ninguno o con contenido distinto del `sha256` del manifiesto. Los dos últimos casos detienen todo antes de copiar.
3. Nunca sobrescribe, y verifica el `sha256` de cada copia.
4. Lo subido va en un commit del almacén que nombra los `vintage_id`, seguido de `git push`.
5. Termina con `verificar_l0_fisico.R`.

`make materializar-l0` sigue siendo la vía para una máquina nueva. Se descartaron: el mismo mecanismo sin push, y subir
al almacén dentro de cada captura, que mezclaría captura y archivo.

**Prueba.** `tests/test-sincronizacion-l0.R`: el plan, sin git, y el flujo completo con un almacén y su remoto falsos
(baja, sube con commit y push, es idempotente, y se detiene ante un conflicto o ante cambios sin commit). El flujo
completo corre en CI (Linux); en el sandbox Windows del agente, git no puede clonar un repo local.

**Nota (2026-11-22, más tarde).** Primera corrida real: el commit del almacén con las cinco capturas del 2026-11-21
(`ca5a9d6`) quedó en la copia de Harold sin llegar a GitHub (`main` del almacén seguía en `6956bed`). Una segunda
corrida informó «97 en los dos lados, 0 subido(s)» y «OK», porque solo miraba los archivos y no los commits sin subir.
Corrección: después del commit, `sincronizar_l0()` cuenta los commits que el remoto no tiene (`@{u}..HEAD`) y los sube.
Si el push falla, se detiene diciendo cuántos commits quedaron solo en la máquina. Se detiene también si no puede
contarlos. La prueba de integración cubre el caso.

