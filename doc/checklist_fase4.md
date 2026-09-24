# Checklist de Fase 4 — Protocolo de evaluación

**Fecha de apertura:** 2026-09-24 · **decisiones del bloque A cerradas:** 2026-09-24 (Fase 3 cerrada y tageada `v0.6.0-fase3` → `906fb566`)
**Criterio de cierre (senda §4):** *el motor de evaluación funciona y está probado **antes**
de estimar cualquier modelo sofisticado. Definir las reglas después de ver los resultados
invalida el ejercicio.*
**Entregables (senda §4):** `src/evaluacion/` funcional; documento de protocolo; resultados
de los benchmarks.

Convención de este tablero, igual que en Fase 3: una actividad se marca `[x]` solo cuando su
evidencia está asentada —corrida de CI, archivo de evidencia textual o entrada en
`doc/bitacora_verificaciones.md`— y la evidencia se cita en la propia línea.

---

## A. Decisiones previas (bloquean el código)

Las trece fichas de `doc/metodologia/decisiones_fase4.md` y la F4-09b quedaron **decididas el 2026-09-24**,
todas en la opción recomendada; el acta con el texto operativo está en ese documento. Lo que
sigue abierto de este bloque no es la decisión sino su **registro** en los ADR. Los siete textos están redactados y en revisión; entran por el PR `fase4/notas-adr`, un commit por ADR.

- [x] **A1 · F4-01** Convención de indexación del origen: convención A (origen = último período estimado, 2013-Q1 a 2025-Q4; target en origen+h). Decidido 2026-09-24.
- [x] **A1b** Nota de aclaración en ADR-002 corrigiendo la ventana inicial a 1990-T1–2013-T1 (93 obs). — commit `02ec7a6` (PR #11).
- [x] **A2 · F4-03** Vintage de evaluación: datos revisados en el ejercicio retrospectivo, filtro por `vintage_id` en el motor y pista real-time prospectiva. Decidido 2026-09-24.
- [x] **A2b** Nota de enmienda en ADR-001 (su criterio primario no es alcanzable en Fase 5) y mención cruzada en ADR-007. — commits `7cdb502` (ADR-001) y `405cd6c` (ADR-007), PR #11.
- [x] **A3 · F4-09** Ajuste estacional reestimado dentro de cada origen, con las fechas AO de 2020-Q2/Q3 declaradas fijas. Prerrequisito verificado: la ejecución la confirma A3d. No corre en CI.
- [x] **A3b · F4-09b** Especificación X-13 por origen: orden ARIMA automático con datos ≤ origen, `transform=log` fijo, detección de outliers desactivada y AO declarados que solo entran desde el origen que los alcanza; orden elegido guardado en L4. Decidido 2026-09-24.
- [x] **A3d** `seasonal::checkX13()` corrido por Harold en la máquina del proyecto el 2026-09-24: pasa ("'seasonal' should work fine"). La evidencia se transcribe en `doc/evidencia_cierre_fase4.txt` al cerrar la fase. Corregido el destino: la versión anterior de este ítem mandaba el resultado a `doc/bitacora_verificaciones.md`, que es exclusiva de `verificar_fuente_celda.R` (regla 8 de `CLAUDE.md`).
- [x] **A3c** Nota de seguimiento en ADR-004 (ajuste estacional dentro de cada origen, con la especificación de F4-09b) y referencia cruzada en ADR-001. — commits `0e7145f` (ADR-004) y `7cdb502` (referencia cruzada en ADR-001), PR #11.
- [x] **A4 · F4-05** Tres grupos de comparación: G1 desde 2013-Q1 (52/51/49/45), G2 desde 2014-Q4 (45/44/42/38), G3 desde 2019-Q4 (25/24/22/18). Decidido 2026-09-24.
- [x] **A5 · F4-02** Regla de calendario para el conjunto de información del origen; UT solo con años cerrados. Decidido 2026-09-24.
- [x] **A6 · F4-04 / F4-07 / F4-08 / F4-10** Pérdida interanual en pp; denominador = paseo aleatorio sin deriva; 2020 incluido con tabla sin 2020 obligatoria y dummies no anticipadas; rodante de 92 trimestres. Decidido 2026-09-24.
- [x] **A7 · F4-06 / F4-13** Regla uniforme a priori: Δlog en las ocho familias (corregida el mismo día; la versión inicial proponía Δ para el IVAE). Deuda de outliers en el veredicto de estacionariedad cerrada por alcance. Decidido 2026-09-24.
- [x] **A7b** Nota de seguimiento en ADR-010 (unidad de modelación de las predictoras). — commit `19d24ca` (PR #11).
- [x] **A8 · F4-11 / F4-12** Token en `esquema_validacion`; DM/HLN y GW propios, MCS propio con el paquete `MCS` como oráculo en Suggests, `yaml` a Imports. Decidido 2026-09-24.
- [x] **A8b** Nota de seguimiento en ADR-009 por `yaml` en Imports y `MCS` en Suggests. — commit `6c1c917` (PR #11).

## B. Documento de protocolo (entregable 1)

- [x] **B1** `doc/metodologia/protocolo_evaluacion.md` reemplazado por el protocolo completo, con cada afirmación marcada como heredada de un ADR, verificada o propuesta. — commit `2bd1050` (PR #9); las marcas `[propuesto]` pasaron a `[decidido]` el mismo día.
- [x] **B2** El protocolo declara la regla de reporte del MCS *antes* de la primera corrida (si el conjunto contiene varios modelos, el resultado es el conjunto). — protocolo §4, "Regla de reporte, fijada antes de ver los resultados" (commit `2bd1050`).
- [x] **B3** El protocolo declara los límites del ejercicio: datos revisados en vez de tiempo real (F4-03), filtración del ajuste estacional si se adopta la opción (a) de F4-09, y potencia de G3. — protocolo §2.4 (datos revisados) y §2.5 (potencia de G3), commit `2bd1050`. El límite del ajuste estacional no aplica: F4-09 adoptó la reestimación dentro de cada origen (protocolo §8).
- [x] **B4** La evidencia numérica que el protocolo cita está en un archivo versionado y regenerable, no transcrita a mano. — `scripts/evidencia_insumos_fase4.R` → `doc/metodologia/reportes_fase4/evidencia_insumos_fase4.csv`, commit `57fc980` (PR #9), verificado contra una reimplementación independiente.

## C. Motor de evaluación (entregable 2)

- [x] **C1** `src/evaluacion/eval_lib.R` — aritmética de orígenes, recorte al conjunto de información, métricas, gramática del token. Sin I/O. — commit `45b0d96` (PR #10). Incluye también el bucle de orígenes con sus guardas (ver especificación §1).
- [x] **C2** `src/evaluacion/modelos_referencia.R` — los seis benchmarks de §6.1 bajo el contrato de modelo. — commits `45b0d96` y `38a41ba` (F4-14: AR(p)-BIC reestimado con la muestra máxima), PR #10.
- [ ] **C3** `src/evaluacion/motor_backtesting.R` — bucle grupo → origen → modelo, con las guardas G-1 a G-6 fallando con `stop()`. *Avance:* el bucle y las guardas G-1 a G-4 ya existen en `eval_lib.R`; falta el orquestador sobre L3 (paso 5).
- [x] **C4** `src/evaluacion/verificar_motor_sintetico.R` — bloques V1 a V11 implementados y en verde (paso 4). V11 contrasta el MCS propio con `MCS::MCSprocedure` 0.2.0 usando las mismas remuestras: p-valores idénticos.
- [x] **C5** `tests/test-evaluacion.R` y `tests/test-modelos-referencia.R` en verde, sin datos del proyecto. — paso "Correr pruebas" en verde en CI, run [36038592642](https://github.com/hsssst00/SIE-el-salvador/actions/runs/36038592642) sobre `22fe72e`, job `validate-and-test`. Local: 566 PASS / 0 FAIL / 3 SKIP.
- [x] **C6** Targets `eval-sintetico` y `eval` en el Makefile, con `eval` dependiendo de `eval-sintetico`. — commit `23510df` (PR #10).
- [x] **C7** `eval-sintetico` incorporado al workflow de CI. — commit `a9402d3` (Harold); el paso corre y pasa en run [36038592642](https://github.com/hsssst00/SIE-el-salvador/actions/runs/36038592642) sobre `22fe72e`, job `validate-and-test`.
- [ ] **C8** Los seis benchmarks declarados en `catalogos/06_modelos/<modelo_id>.yaml` **antes** de la primera corrida (es el registro que prueba que la especificación precedió al resultado). *Avance:* va con el paso 5, junto con el lector de YAML (`catalogos/README.md` reservaba `06_modelos/` para Fase 5).

## D. Verificación del motor (la mitad no negociable del criterio de cierre)

- [x] **D1** V1 — el motor reproduce 52 / 51 / 49 / 45 pares evaluados sobre una serie sintética con las fechas del objetivo. — paso "Verificación sintética del motor de evaluación" en verde en CI, run [36038592642](https://github.com/hsssst00/SIE-el-salvador/actions/runs/36038592642) sobre `22fe72e`, job `validate-and-test`.
- [x] **D2** V2-V3 — recuperación del pronóstico teórico y del RMSE teórico del AR(1) y del paseo aleatorio. — paso "Verificación sintética del motor de evaluación" en verde en CI, run [36038592642](https://github.com/hsssst00/SIE-el-salvador/actions/runs/36038592642) sobre `22fe72e`, job `validate-and-test`.
- [x] **D3** V4 — ordenamiento correcto en dos DGP donde se sabe qué modelo debe ganar. — paso "Verificación sintética del motor de evaluación" en verde en CI, run [36038592642](https://github.com/hsssst00/SIE-el-salvador/actions/runs/36038592642) sobre `22fe72e`, job `validate-and-test`. Con DGP paseo aleatorio el RMSE relativo medio del AR(p)-BIC es 1,0068: el criterio (≥ 1) se cumple con poco margen.
- [x] **D4** V5-V6 — el canario de filtración hace fallar al motor (G-3; G-1 sobre una serie sin recortar) y el de mutación no altera el estado maestro (en R un `data.frame` se copia al modificarse; G-2 vigila). — paso "Verificación sintética del motor de evaluación" en verde en CI, run [36038592642](https://github.com/hsssst00/SIE-el-salvador/actions/runs/36038592642) sobre `22fe72e`, job `validate-and-test`.
- [x] **D5** V7-V8 — tamaño de DM/HLN y potencia por `n` y horizonte, incluidos los 18 pares de G3 a h=8. Criterio estricto en h=1,2; h=4,8 reportado (F4-18).
- [x] **D6** V9 — cobertura del MCS: el dominante queda dentro en todas las celdas; con equivalentes, estricto en h=1 y reportado en h=8 (F4-18).
- [x] **D7** V10 — dos corridas con la misma semilla producen `sha256` idénticos. — paso "Verificación sintética del motor de evaluación" en verde en CI, run [36038592642](https://github.com/hsssst00/SIE-el-salvador/actions/runs/36038592642) sobre `22fe72e`, job `validate-and-test`.
- [ ] **D8** Corrida de CI citada como evidencia del cierre (patrón de Fase 0/1), con su número de run y su sha. *Avance:* la corrida vigente que certifica V1-V6 y V10 es run [36038592642](https://github.com/hsssst00/SIE-el-salvador/actions/runs/36038592642) sobre `22fe72e`, job `validate-and-test`; la corrida de cierre se cita cuando estén los once bloques.

## E. Resultados de los benchmarks (entregable 3)

- [ ] **E1** Primera corrida completa sobre L3 con los seis benchmarks, en los grupos definidos en A4.
- [ ] **E2** `data/L4_experiments/<exp_id>/` con `pronosticos.csv`, `metricas.csv`, `pruebas.csv`, `mcs.csv` y `manifiesto.txt`.
- [ ] **E3** Fila por corrida en `catalogos/07_experimentos.csv` con las doce columnas del esquema y el token de protocolo.
- [ ] **E4** Tabla de RMSE y MAE por horizonte y grupo, con la columna de pertenencia al MCS adyacente.
- [ ] **E5** Batería de robustez R1-R6 corrida y reportada junto al resultado principal.
- [ ] **E6** Evidencia textual de la corrida en `doc/evidencia_cierre_fase4.txt` (patrón de Fase 2 y 3, porque `make eval` exige L3 y X-13 y no puede pasar por CI). Corregido el 2026-09-24: la versión anterior pedía además una entrada en `doc/bitacora_verificaciones.md`, que es exclusiva de `verificar_fuente_celda.R` (regla 8 de `CLAUDE.md`).

## F. Cierre de la fase (tres piezas del patrón del proyecto)

- [ ] **F1** Nota `## Cierre de Fase 4` en `doc/adr/README.md`, con la evidencia de CI de D8 y la de E6.
- [ ] **F2** `doc/evidencia_cierre_fase4.txt` con comando, código de salida y salida de cada corrida que no pasa por CI.
- [ ] **F3** Nota fechada en `doc/senda_metodologica.md` §4 que fije las lecturas adoptadas, si algún criterio admite más de una — precedentes: "ingresa al proyecto" (Fase 1), "verifica su integridad" (Fase 2), alcance de la matriz y "bitemporal" (Fase 3). Candidatas de esta fase: qué significa "el motor está probado" (se propone: los once bloques V1-V11 en verde en CI para los que no requieren L3) y qué significa "modelos de referencia implementados" (se propone: los seis de §6.1, declarados en `06_modelos/` y corridos en los tres grupos).
- [ ] **F4** Tag anotado `v0.7.0-fase4` sobre el commit de cierre, con el run de CI citado en el mensaje.
- [ ] **F5** Revisión independiente depositada en `doc/auditorias/` y registrada en el índice de esa carpeta (la deposita Harold; las revisiones no tienen autoridad decisoria).

---

## Lo que esta fase hereda declarado y no debe silenciar

- **Grano bitemporal de UT.** Sus 25 vintages tienen fecha de publicación sintética (31-dic
  de cada año; 31-jul para 2026), así que la dimensión de publicación de esas dos series es
  de grano anual y fecha aproximada. Si la corrida se declara `vintage=real_time`, UT entra
  con esa restricción o no entra.
- **Deudas que Fase 3 difirió a Fase 4/5:** unidad de modelación de las predictoras (F4-06)
  y si el veredicto de estacionariedad debe consumir los outliers declarados (F4-13).
- **D5 de la senda (validador de FK entre catálogos dividido entre
  `validar_integridad_catalogos.R` y `tests/test-integridad-referencial.R`)** sigue abierto
  y no bloquea esta fase, pero `07_experimentos.csv` y `06_modelos/` son aristas nuevas del
  grafo de integridad referencial: al poblarlas hay que comprobar que `modelo_id` y
  `vintage_id` resuelven contra sus catálogos.

## Lo que esta fase NO cubre

- Los modelos de §6.2 a §6.7 de la senda (ARIMA/ARIMAX, VAR/VECM/BVAR, MIDAS y ecuaciones
  puente, regularizados, árboles, combinaciones): son Fase 5 y no deben implementarse antes
  de que este tablero esté en `[x]`.
- El nowcasting del trimestre en curso (extensión 1 de §9): el borde irregular queda
  habilitado por el motor, pero su conjunto de orígenes es otro.
- El Ejercicio B y sus escenarios (Fase 6).
