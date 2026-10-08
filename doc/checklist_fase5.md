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
  Estado 2026-10-07: medidos B1 (UNI.ARIMA 3-4 s por origen; ARIMAX < 1 s) y B2a (VAR y VECM < 0,1 s por origen);
  faltan BVAR (B2b), B3, B3b y B4. Estado 2026-10-07 (B2b): BVAR medido: 16-19 s por origen en G1, 18 s en G2 y 21-26 s en G3,
  unos 38 minutos para los orígenes de los tres principales y unos 23 más para R7; faltan B3, B3b y B4.
  Estado 2026-10-08: tope y reglas decididos (F5-14a a F5-14f en `decisiones_fase5.md`, «Tope de costo y
  representantes»): 8 horas por pasada de `make eval`, secuencial; con B1 y B2 la proyección es de unas 4 h 15 min.
  Representante de B2: `MULT.VAR_DIF`. Faltan el costo y el representante de B3, B3b y B4, y la cuenta final antes de
  E1. Estado 2026-10-08 (PR 2 de B3): B3 medido (ENET 1,5-3,0 s y PCR 0,35-0,46 s por origen; unos 23 minutos más por
  pasada, unos 278 en total) y representante `REG.ENET` (B3-9). Faltan B3b y B4 y la cuenta final.

## C. Infraestructura que piden las decisiones

- [ ] **C1 · F5-03** Guarda de ≥ 20 grados de libertad en el motor, con `stop()` y una prueba que verifique que
  el diseño la cumple en el primer origen de cada grupo. Guarda G-8 implementada en B1a
  (`tests/test-predictoras-fase5.R`); la prueba sobre el primer origen de cada grupo llega con los modelos de B1b.
  Estado 2026-10-05: la prueba está en `tests/test-modelos-univariados.R` (ARIMAX de G1, G2, G3 e IVAE en el primer
  origen con las fechas de inicio de L3: 75, 38 y 39 observaciones; abrir la grilla de G2 o los rezagos de G3 dispara
  G-8); se marca con la evidencia de CI al fusionar el PR de B1b. Estado 2026-10-07: B2a extiende la prueba a los VAR
  y al VECM en `tests/test-modelos-multivariados.R` (56, 57, 57, 23 y 43 grados de libertad libres; p = 4 en G2
  dispara G-8). Estado 2026-10-07: el BVAR no tiene piso (B2-7); `tests/test-modelo-bvar.R` lo corre con la
  configuración de producción en el primer origen de cada grupo con las fechas de inicio de L3 (77, 40 y 40
  observaciones).
- [ ] **C2 · F5-04** `rezago_alineacion(serie, grupo)` con su prueba, y guarda de completitud del borde (los
  meses que el origen admite existen en la serie). Implementadas en B1a (G-7; `tests/test-predictoras-fase5.R`); se
  marca con la evidencia de CI al fusionar. Estado 2026-10-05: B1a fusionado (PR #31, `8d72e83`) con CI verde en push y
  pull_request; queda para marcar en la revisión de Harold.
- [x] **C3 · F5-05** Contrato de modelo para la forma directa (crecimiento acumulado por `h`) en regularizados y
  árboles. Con B3. Estado 2026-10-08: B3-1 a B3-8 decididas. El PR 1 de B3 (B3-8) trae la forma directa en
  `src/evaluacion/forma_directa.R`: `matriz_directa()`, `crecimiento_acumulado()`, la ventana de B3-2 y la fábrica
  `modelo_directo()`. Las pruebas están en `tests/test-forma-directa.R`. Se marca con la evidencia de CI al fusionar.
  **Cierre (2026-10-08):** PR #41 fusionado por Harold (merge `13eba72`), CI verde en el PR (runs 37726823262 y
  37726826461) y en `main` (run 37773963675).
- [x] **C4 · F5-11** Validación anidada con K = 12 y reoptimización por origen, con su prueba de que no usa datos
  posteriores a `o`. Estado 2026-10-08: en el PR 1 de B3 (`pronosticos_internos()`, `ajustar_directo()`). Las pruebas
  de `tests/test-forma-directa.R` comprueban dos cosas: que el pronóstico de cada origen interno o' no cambia al
  alterar los datos posteriores a o', y que su ventana son las filas con t + h ≤ o'. Prueban además las filas de B3-4
  en el primer origen de cada grupo. Se marca con la evidencia de CI al fusionar. **Cierre (2026-10-08):** PR #41
  (merge `13eba72`), CI verde en `main` (run 37773963675).
- [ ] **C5 · F5-12** Densidad del sistema conjunto en ARIMAX y puente (forma compañera) y de errores internos en
  regularizados y árboles, cubierta por V13 o un bloque nuevo. Estado 2026-10-05: la parte de ARIMAX llega con B1b
  (`cov_sistema_arimax()`, prueba contra la simulación de sus recursiones y cobertura en V14); faltan puente (B3b),
  regularizados y árboles. Estado 2026-10-07: VAR y VECM (pesos MA, B2-1) con prueba contra `predict()` y contra la
  simulación de las recursiones, y cobertura en V15 (B2a). Estado 2026-10-07: BVAR con los momentos exactos de la
  predictiva posterior con choques (B2-10), con prueba contra la recursión y los pesos MA de cada extracción y contra
  una simulación de senderos, y cobertura en V16 (B2b).
  Estado 2026-10-08: el PR 1 de B3 trae la covarianza de errores internos de los regularizados (Σ = D · R · D, B3-5 y
  B3-6; `cov_errores_internos()`), con prueba de su forma; la cobertura llega con V18 en el PR 2. Faltan puente (B3b)
  y árboles (B4). Estado 2026-10-08 (PR 2 de B3): cobertura en V18 con una holgura inferior declarada de 0,10 (la
  densidad de errores internos subcubre; límite en `decisiones_fase5.md`).
- [ ] **C6 · F5-15** Bloque de CI que corre dos veces un experimento sintético con los modelos de Fase 5 y compara
  hashes.

## D. Bloques de modelos (un PR por bloque, sin apilar; orden de F5-01)

Cada bloque declara sus YAML en `catalogos/06_modelos/` (C8), lleva su canario sintético (V14 y siguientes,
F5-02) y se verifica solo con datos sintéticos y en CI. Ninguno corre sobre L3 antes de la corrida única.

- [ ] **D1 · B1** ARIMA/ARIMAX y componentes no observados. Estado 2026-10-05: B1a fusionado (PR #31); B1b en su PR
  (`UNI.ARIMA`, `UNI.UC_LLT`, `UNI.ARIMAX.G1/.G2/.G3`, `UNI.ARIMAX_IVAE.G2`, sus YAML y V14).
- [ ] **D2 · B2** VAR, VECM y BVAR. Estado 2026-10-07: B2-1 a B2-8 decididas; B2a en su PR (`MULT.VAR_DIF.G1/.G2/.G3`,
  `MULT.VAR_NIV.G1`, `MULT.VECM.G1`, sus YAML y V15); B2b (BVAR) después, sin apilar. B2-9 (deduplicación de pérdidas
  idénticas en el MCS) decidida; va en un PR del motor antes de E1. Estado 2026-10-07: B2a fusionado (PR #33,
  `821eaac`); B2-9 en su PR (`mcs_tmax_dedup()`, solo en `F5_G*`; los `F5_REPRO_*` no cambian). Estado 2026-10-07:
  B2-9 fusionado (PR #34, `a91b791`); B2-10 a B2-16 decididas; B2b en su PR (`MULT.BVAR.G1/.G2/.G3`, sus YAML y V16).
- [ ] **D3 · B3** Regularizados. Estado 2026-10-08: B3-1 a B3-8 decididas. B3 va en dos PR, uno después del otro
  (B3-8). El PR 1 es la infraestructura: forma directa, validación anidada y covarianza de errores internos. El PR 2
  trae `REG.ENET.Gk` y `REG.PCR.Gk`, sus YAML, V18 y el costo por origen. Estado 2026-10-08: PR 1 fusionado (#41,
  `13eba72`); el PR 2 en su rama (`REG.ENET.G1/.G2/.G3`, `REG.PCR.G1/.G2/.G3`, sus YAML, V18, costo y representante,
  B3-9).
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
  verifica o se declara su tolerancia. Estado 2026-10-07: el BVAR ya existe (B2b); en una misma máquina es bit a bit
  (prueba en `tests/test-modelo-bvar.R` y V16). Falta comparar Windows y Linux.
  Nota 2026-10-07: la forma de la comparación está decidida (F1-1 y F1-2 en `decisiones_fase5.md`): el bloque V17
  compara byte a byte un BVAR fijo contra una referencia generada en Windows y corre en CI (Ubuntu) en cada push.
  Nota 2026-10-07: entre Windows y Ubuntu no es bit a bit (media 9,7e-8 en log-nivel; covarianza 8,7e-7 relativo;
  misma aceptación). La tolerancia quedó declarada en F1-3. Falta la parte de `make eval` bit a bit sobre L4, que se
  comprueba con la corrida única (E2).
  Nota 2026-10-07 (más tarde): F1-3 reabierta. En otro runner de Ubuntu cambian 4 de 5 000 decisiones del MH y la
  diferencia llega al error de Monte Carlo. La paridad entre sistemas queda declarada hasta ese error. V17 exige bit a
  bit en Windows y fuera de Windows solo informa.
- [ ] **F2** Nota «Cierre de Fase 5» en `doc/adr/README.md`, archivo de evidencia textual de la corrida y, si un
  criterio admite lecturas, nota fechada en `doc/senda_metodologica.md`.
- [ ] **F3** Revisión independiente en `doc/auditorias/` y tag de cierre.
