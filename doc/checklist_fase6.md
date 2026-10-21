# Checklist de Fase 6 — Proyección condicional (Ejercicio B)

**Fecha de apertura:** 2026-10-17 · **Fase 5 cerrada:** tags `v0.8.0-fase5` (`1156d48`) y `v0.8.1-fase5`
(`c4ae7c6`)
**Criterio de cierre (senda §4):** *cada supuesto exógeno tiene fuente citada y el resultado se declara
explícitamente como condicional.*
**Entregables (senda §4):** proyecciones por escenario; documento de supuestos
(`doc/metodologia/supuestos_escenarios.md`, ADR-002); análisis de sensibilidad.

Convención de este tablero, igual que en Fases 3 a 5: una actividad se marca `[x]` solo cuando su evidencia está
asentada (corrida de CI, archivo de evidencia textual o entrada en `doc/bitacora_verificaciones.md`), y la evidencia
se cita en la propia línea. Las decisiones viven en `doc/metodologia/decisiones_fase6.md`; el método, en
`doc/metodologia/protocolo_proyeccion.md`. Una actividad que depende de una ficha todavía no decidida lo dice y no
se marca.

---

## A. Compuerta de entrada

- [x] **A1** Fase 5 cerrada y su auditoría remediada. — tags `v0.8.0-fase5` (`1156d48`, run #362) y `v0.8.1-fase5`
  (`c4ae7c6`, run #384).
- [x] **A2** Análisis posteriores AP-1 a AP-4 y residuos de la verificación en `main`. — PR #63 a #69; `main` =
  `0927b32` al cerrar A2 (2026-10-16); el HEAD vigente se lee con `git log`, no acá.
- [ ] **A3** Compuerta de la auditoría de Fase 5: la regla de combinación (F6-02) y la guarda de plausibilidad
  (F6-08) fijadas con commit **antes de la primera proyección**. Decididas en `decisiones_fase6.md`; se cumple
  cuando E1 congela su implementación.

## B. Decisiones

- [x] **B1 · F6-01 a F6-05** Arquitectura: elegibles, combinación, satélites, corte y escenarios. Decididas el
  2026-10-17 en la opción recomendada (autorización de Harold), con detalles delegados al agente.
- [x] **B2 · F6-06 a F6-13** Especificación: condicionamiento, intervalos, guarda, sensibilidad, coherencia,
  reporte, preregistro y BVAR con h = 20. Decididas el 2026-10-17, igual que B1.
- [x] **B3 · F6-14** Escenario adverso y traducción de sus desviaciones. Requiere C2. — 2026-10-19: escenario C del
  recuadro 1.2; además entra el favorable (A) por la regla de F6-05.
- [x] **B4 · F6-15 a F6-18** Satélites, paso de anual a trimestral, puente con senderos trimestrales y variables de
  escenario en L3. — 2026-10-19, en la opción recomendada (delegación del 2026-10-17).

## C. Insumos

- [x] **C1** Tramo de la CBO en ADR-008. — enmienda del 2026-10-17. La Fed no se usa (F6-05-a).
- [x] **C1b** Alta de la CBO en `catalogos/00_instituciones.csv` y de su publicación de proyecciones económicas en
  `catalogos/01_publicaciones/` (con sus condiciones de uso de ADR-008), por el esquema de
  `catalogos/datapackage.json` (regla 2). — 2026-10-19: `CBO` y `CBO.PROYECCIONES_ECONOMICAS.yaml`, más
  `FMI.WEO.CAPITULO1.yaml`; `make validate` y `check_l0_integrity.R` en verde en el sandbox y en el CI del PR.
- [x] **C2** Captura a L0, por *script* de `src/adquisicion/` y con manifiesto, del WEO de octubre de 2026 (base de
  datos y datos del capítulo 1) y de las proyecciones económicas de la CBO. — 2026-10-19: vintages
  `FMI.WEO.v2026-10`, `FMI.WEO.CAPITULO1.v2026-10` y `CBO.PROYECCIONES_ECONOMICAS.v2026-02` en `08_vintages.csv` y
  el manifiesto; detalle y sha256 en «Hechos verificados el 2026-10-19» de `decisiones_fase6.md`. Crudos en el
  almacén privado de L0 (commit `a6ea856`).
- [x] **C2b** Captura a L0 del petróleo en USD (`G001.POILAPSP.USD.M`) como publicación nueva
  `FMI.PCPS.POILAPSP_USD`, con su alta por el esquema (regla 2). La serie `INDEX` de L0 no es el precio del WEO
  (F6-18). — 2026-10-19: vintage `FMI.PCPS.POILAPSP_USD.v2026-10` en `08_vintages.csv` y el manifiesto (1992-01 a
  2026-09); su promedio anual reproduce `G001.POILAPSP` del WEO en 1992-2025. Detalle y sha256 en «Hechos
  verificados el 2026-10-19 (captura C2b)» de `decisiones_fase6.md`. Crudo en el almacén privado de L0 (commit
  `c5d8361`).
- [x] **C3** Variables de escenario en L3 (catálogo, transformación, validación). Depende de B4 (F6-18). —
  2026-10-19: rol `escenario` en `datapackage.json`; 10 series en `03_series.csv`, `T012`, `T013` y las siete
  `T014_SENDERO_ESCENARIO_*` en `04_transformaciones.csv` y 10 maestras en `05_series_master.csv`;
  `src/transformacion/extraer_escenarios.R` y `l3_escenarios.R` en `make master`, con reglas en
  `l3_escenarios_reglas.R` y pruebas sintéticas en `tests/test-l3-escenarios.R`. `make master` y las seis validaciones
  de F6-18 en verde en el sandbox; `verificar_fuente_celda.R` asentado en `doc/bitacora_verificaciones.md`
  (entrada del 2026-10-19, 110 PASS / 0 FAIL / 6 FUERA_DE_ALCANCE); detalle en «Hechos verificados el 2026-10-19
  (variables de escenario en L3, C3)» de `decisiones_fase6.md`.
- [x] **C3b** Insumos de C4 que salieron de los hechos de C3: L0 repuesta en la copia de Harold y fin de lectura de
  cada vintage (F6-19). — 2026-10-20: los 17 archivos `v2026-09` del BCR repuestos y
  `BCR_panorama_banco_central_2026-10-07.xlsx` agregado en la copia de Harold; los ocho extractores `.xlsx` leen hasta
  el `periodo_referencia_max` de `08_vintages.csv` (PR #78, `085f6a0`; pruebas en `tests/test-fin-lectura.R`), sin
  editar `03`. `make master` sobre `corte_fase5` idéntico por sha256 en los 28 CSV; detalle en «F6-19» de
  `decisiones_fase6.md`.
- [ ] **C4** `doc/metodologia/corte_fase6.csv` congelado (F6-04), `make master` sobre el corte y G-6 en verde.

## D. Implementación (solo datos sintéticos)

- [ ] **D1** `DISENO_FASE6` con `h_max = 20`, sin tocar `DISENO_FASE4`; los `F5_REPRO_*` siguen bit a bit en CI.
- [ ] **D2** `predecir_condicional()` en los 14 modelos elegibles y la trayectoria sin escenario con h = 20 en los
  demás de la tabla de F6-01.
- [ ] **D3** Satélites con sus YAML y pruebas sintéticas. Depende de B4. (La prueba de Denton frente a
  `tempdisagg` de F6-16 ya está en `tests/test-l3-escenarios.R`, desde C3.)
- [ ] **D4** Guarda (F6-08), combinación por mediana (F6-02) y mezcla de densidades (F6-07).
- [ ] **D5** Canarios V22 y V23 en `verificar_motor_sintetico.R`, en verde en CI.
- [ ] **D6** Sensibilidad (F6-09), coherencia (F6-10) y tablas de reporte (F6-11).
- [ ] **D7** `make fase6` como orden única.

## E. Preregistro y corrida

- [ ] **E1** Congelamiento con commit: corte, supuestos en L0, YAML de satélites y de Fase 6, regla, guarda (con su
  rango calculado en `corte_fase6`) y lista de coherencia. El protocolo deja de ser borrador.
- [ ] **E2** Medición previa del BVAR (F6-13 d), con las dos cifras que fija la ficha, en la evidencia del
  preregistro.
- [ ] **E3** Corrida única con `make fase6` sobre árbol limpio; evidencia textual en `doc/evidencia_corrida_fase6.txt`.
- [ ] **E4** Reproducción bit a bit en la máquina de Harold.

## F. Cierre

- [ ] **F1** `supuestos_escenarios.md` completo: cada supuesto con su fuente citada (vintage y sha256 en L0) y la
  nota de inconsistencia entre fuentes de ADR-002.
- [ ] **F2** Informe de proyección por escenario, con sensibilidad y coherencia, que declara condicionales todas las
  cifras.
- [ ] **F3** Nota «Cierre de Fase 6» en `doc/adr/README.md` y, si el criterio admite lecturas, nota fechada en la
  senda.
- [ ] **F4** Revisión independiente en `doc/auditorias/` y tag de cierre.
