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
