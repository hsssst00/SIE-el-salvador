# Checklist de Fase 5 — Estimación y comparación (Ejercicio A)

**Fecha de apertura:** 2026-10-05 · **Fase 4 cerrada:** tags `v0.7.0-fase4` (`a67bde9`) y `v0.7.1-fase4` (`70e7b35`)
**Criterio de cierre (senda §4):** *todo resultado reportado es reproducible con una sola orden y una semilla
fijada.*
**Entregables (senda §4):** catálogos `06` y `07` poblados; tablas de resultados por horizonte; pruebas DM/GW y
conjunto de modelos de confianza; análisis de robustez.

Convención de este tablero, igual que en Fases 3 y 4: una actividad se marca `[x]` solo cuando su evidencia
está asentada —corrida de CI, archivo de evidencia textual o entrada en `doc/bitacora_verificaciones.md`— y la
evidencia se cita en la propia línea. Las decisiones viven en `doc/metodologia/decisiones_fase5.md`; este
tablero no las repite. Una actividad que depende de una ficha todavía no decidida lo dice y no se marca.

---

## A. Compuerta de entrada

- [x] **A1** Densidad (F4-33) y conjunto de información de las predictoras (F4-34) implementados y en verde en
  CI. — commit `b9b793e` (remediación de Fase 4); CI verde en `main` (`707397b`).
- [x] **A2 · F5-16** Corte congelado de vintages y su lectura en el motor (`make eval` exige `CONJUNTO=`).
  — PR #28 (merge `78eb3b1`); corte fijado en `54dfb6c` (`doc/metodologia/corte_fase5.csv`).
- [x] **A3 · F5-16 (C-6, C-7)** La reproducción de Fase 4 sobre el corte (`F5_REPRO_*`) coincide con la corrida de
  cierre salvo `exp_id` y densidad. — `doc/evidencia_reproduccion_fase5.txt` (`5cf8fae`).
- [x] **A4 · F5-17** Mecanismo manual de captura de UT. — PR #25 y #26.

## B. Decisiones previas (bloquean el código)

- [x] **B1 · F5-01 a F5-05** Alcance y orden, preregistro completo, grupos y piso de muestra efectiva, alineación
  y estrategia multihorizonte. Decididas el 2026-10-05 y registradas en `decisiones_fase5.md`. La parte 2 de
  F5-04 (UT mes a mes con rezago supuesto de 30 días) se implementa en el mismo PR, en la evidencia de insumos,
  en `rezagos_predictoras()` y en `tests/test-evaluacion.R` §13.
- [x] **B2 · F5-06 a F5-10** Especificación de univariados, multivariados, frecuencia mixta, regularizados y
  árboles. Decididas el 2026-10-05 y registradas en `decisiones_fase5.md`; las rejillas finas de cada modelo se
  fijan en su YAML.
- [x] **B3 · F5-11 a F5-13** Validación anidada, densidad de los modelos nuevos y combinaciones. Decididas el
  2026-10-05 y registradas en `decisiones_fase5.md`.
- [x] **B4 · F5-14 y F5-15** Robustez y costo, y reproducibilidad. Decididas el 2026-10-05 y registradas en
  `decisiones_fase5.md`.
- [ ] **B5 · F5-14** Medición del tiempo por origen de cada familia con datos sintéticos; con esa cifra, tope,
  representantes por familia y variante de F5-11, fijados en un commit anterior a la corrida sobre L3.

## C. Infraestructura que piden las decisiones

- [ ] **C1 · F5-03** Guarda de ≥ 20 grados de libertad en el motor, con `stop()` y una prueba que verifique que
  el diseño la cumple en el primer origen de cada grupo. Con B1.
- [ ] **C2 · F5-04** `rezago_alineacion(serie, grupo)` con su prueba, y guarda de completitud del borde (los
  meses que el origen admite existen en la serie). Con B1.
- [ ] **C3 · F5-05** Contrato de modelo para la forma directa (crecimiento acumulado por `h`) en regularizados y
  árboles. Con B3.
- [ ] **C4 · F5-11** Validación anidada con K = 12 y reoptimización por origen, con su prueba de que no usa datos
  posteriores a `o`.
- [ ] **C5 · F5-12** Densidad del sistema conjunto en ARIMAX y puente (forma compañera) y de errores internos en
  regularizados y árboles, cubierta por V13 o un bloque nuevo.
- [ ] **C6 · F5-15** Bloque de CI que corre dos veces un experimento sintético con los modelos de Fase 5 y compara
  hashes.

## D. Bloques de modelos (un PR por bloque, sin apilar; orden de F5-01)

Cada bloque declara sus YAML en `catalogos/06_modelos/` (C8), lleva su canario sintético (V14 y siguientes,
F5-02) y se verifica solo con datos sintéticos y en CI. Ninguno corre sobre L3 antes de la corrida única.

- [ ] **D1 · B1** ARIMA/ARIMAX y componentes no observados.
- [ ] **D2 · B2** VAR, VECM y BVAR.
- [ ] **D3 · B3** Regularizados.
- [ ] **D4 · B3b** MIDAS y puente.
- [ ] **D5 · B4** Árboles.
- [ ] **D6 · B5** Combinaciones (al final).

## E. Preregistro y corrida única

- [ ] **E1 · F5-02** Todos los YAML de Fase 5 declarados y versionados antes de cualquier corrida sobre L3;
  commit de congelamiento citado (protocolo §6).
- [ ] **E2** Corrida única sobre L3 con el corte congelado; filas en `07_experimentos.csv` y tablas de
  resultados por horizonte, generadas en la máquina de Harold.
- [ ] **E3** Pruebas DM/GW y MCS sobre el conjunto completo, con las marcas `marca_tamano` y `marca_n`.
- [ ] **E4** Análisis de robustez (protocolo §5) sobre los modelos de Fase 5.
- [ ] **E5 · F5-04c** Experimento de robustez R7 (modelos con UT de G2 y G3 con UT a 61 días), declarado antes de la
  corrida única y con su propio `exp_id`.

## F. Cierre

- [ ] **F1** Reproducibilidad con una sola orden y una semilla fijada (criterio de la senda; forma concreta en
  F5-15): `make eval` regenera bit a bit `data/L4_experiments/<exp_id>/`, y la paridad Windows/Linux del BVAR se
  verifica o se declara su tolerancia.
- [ ] **F2** Nota «Cierre de Fase 5» en `doc/adr/README.md`, archivo de evidencia textual de la corrida y, si un
  criterio admite lecturas, nota fechada en `doc/senda_metodologica.md`.
- [ ] **F3** Revisión independiente en `doc/auditorias/` y tag de cierre.
