# Fase 5 — registro de decisiones de diseño

**Fecha:** 2026-10-03 · **Estado:** F5-16 y F5-17 decididas por Harold el 2026-09-30; las decisiones de
implementación del corte congelado (C-1 a C-8, abajo), el 2026-10-03. F5-01 a F5-15 siguen pendientes de
respuesta y entran a este documento cuando se decidan (Regla 4); hasta entonces sus fichas no son
vinculantes.

**Para qué sirve este documento.** Es el equivalente de `decisiones_fase4.md` para Fase 5: cada ficha lleva
la línea **DECIDIDO** con el texto operativo, y el Acta es el índice. Las correcciones posteriores entran
como notas fechadas; no se reescribe lo registrado.

---

## Acta de decisiones

| Código | Decisión adoptada | Documento enmendado |
|---|---|---|
| F5-16 | Captura mensual en L0; evaluación de Fase 5 contra un corte de `vintage_id` congelado | protocolo §2.4 (nota 2026-10-03); especificación del motor §3 (nota 2026-10-03) |
| F5-17 | UT trimestral y manual (Regla 9) | ninguno aquí; ADR-007 (nota 2026-09-30) |
| C-1 a C-8 | Implementación del corte congelado: composición, ubicación, guardas y registro | los mismos que F5-16 |

---

## F5-16 — Cadencia de actualización y corte de evaluación de Fase 5

**DECIDIDO por Harold el 2026-09-30.**

- **Captura (L0).** Periodicidad **mensual**: una ventana fija el día 1-3 de cada mes captura todo lo que el
  BCR publicó el mes anterior, de modo que no se pierde ningún vintage mensual (ADR-007: un vintage no
  capturado es irrecuperable). Descartadas: la trimestral atada al PIB, que pierde 2 de cada 3 vintages
  mensuales, y la captura por evento.
- **Evaluación.** Durante Fase 5 se **congela un corte**: el objetivo y las predictoras se filtran por los
  `vintage_id` que declara el corte. Las capturas nuevas entran a L0 y a `08_vintages.csv`, pero no a la
  evaluación, hasta el cierre de Fase 5.
- **Cómo se materializa: «L3 del corte desde L0».** L1 y L3 guardan un solo vintage por serie y no están
  versionados; solo L0 conserva cada vintage. El corte se declara en un CSV (`publicacion_id,vintage_id`);
  `make master CONJUNTO=<corte> SALIDA=<dir>` reconstruye L1/L2/L3 del corte desde L0 en un directorio
  propio (PR #27, `conjunto_lib.R`), y el motor lee de ahí. `make master` sin argumentos sigue actualizando
  la L3 vigente. Descartadas: no correr `make master` durante Fase 5 (un clon fresco no reconstruye el corte)
  y versionar la copia de L3 (choca con ADR-008).

## F5-17 — Mecanismo de actualización de UT (captura manual)

**DECIDIDO por Harold el 2026-09-30.**

UT no se automatiza: el `robots.txt` de ut.com.sv lo prohíbe (Regla 9). Captura **trimestral y manual**, en
las ventanas de enero, abril, julio y octubre: el año en curso y el último año que en L0 todavía no llega a
diciembre. Los años cerrados no se vuelven a bajar (límite declarado: una revisión de un año cerrado no se
detecta). `fecha_publicacion` sintética = último día del `periodo_referencia_max`. L3 y el motor se detienen
con `stop()` si un origen admite, por F4-34, un año cuyo archivo no llega a diciembre. Implementado en los
PR #25 y #26 y en `a7714f1` (guarda del año completo en la rama anual).

---

## Implementación del corte congelado (decidida por Harold el 2026-10-03)

Diagnóstico previo (2026-10-03, sin commits): con la captura de octubre, el vintage vigente del PIB en
`08_vintages.csv` pasó a `v2026-09`, y G-6 detiene `make eval` solo porque la L3 local quedó en `v2026-06`.
Una `make master` sin corte habría movido la evaluación, en silencio, a los datos nuevos.

- **C-1 · Composición.** **DECIDIDO:** los 36 vintages de 12 publicaciones de
  `doc/metodologia/corte_fase5.csv`, que son los de la L3 de la corrida de cierre de Fase 4: PIB NSA, SA y
  nominal `v2026-06`; retropolado `v2019-03`; IVAE `v2026-07`; remesas `v2026-08`; IPC `v2026-09`; balanza
  comercial (FOB) `v2026-07`; IPP `v2026-08`; ITCER `v2026-07`; índices de precios del comercio exterior
  (IPM) `v2026-07`; UT `v2002-12` a `v2025-12` y `v2026-07` (25). Es la propuesta de la ficha F5-16 más dos
  publicaciones que la ficha omitía: PIB SA `v2026-06` (lo usa R5) y PIB nominal `v2026-06`
  (`validar_conjunto()` exige todas las publicaciones de `03_series.csv`). Consecuencia: el PIB 2026-T2 no
  entra; el objetivo sigue en 1990-Q1..2026-Q1 (145 obs).
- **C-2 · Ubicación.** **DECIDIDO:** versionado en `doc/metodologia/corte_fase5.csv` (sha256 sin CR
  `901b0f7959b5cc40b82f376f469eaaa80adb931ecfcee4d7624910440021ff17`). Lo fija el commit que agrega el
  archivo (`git log -- doc/metodologia/corte_fase5.csv`); toda corrida de Fase 5 lo cita (protocolo §6).
  `tests/test-corte-motor.R` falla si el archivo cambia. La L1/L3 del corte que arma `make master` va en
  `data/conjuntos/corte_f5/` (no versionado).
- **C-3 · Sin corte.** **DECIDIDO:** `make eval` sin `CONJUNTO=` se detiene con `stop()` en el motor.
  `eval-sintetico` no cambia. No hay `CONJUNTO` por defecto en el Makefile: el `export` es global y también
  afectaría a `make master`.
- **C-4 · Registro.** **DECIDIDO:** ruta y sha256 sin CR del corte en `manifiesto.txt` (el corte entra
  además a la lista de insumos), y un séptimo campo opcional en el token de `esquema_validacion`:
  `|conjunto=<nombre>@<sha8>`, p. ej. `|conjunto=corte_fase5@901b0f79`. El esquema de `07_experimentos.csv`
  no cambia y ninguna fila de Fase 4 se toca.
- **C-5 · L1 frente a L3.** **DECIDIDO** (corregida el mismo día: la primera formulación suponía que L3 traía
  la NSA, y no la trae). L1 no tiene `vintage_id`. El motor recalcula
  `ajustar_estacional_propio(concatenar_pib_nsa(L1))` y exige igualdad **exacta** de período, valor y AO
  con `PIB_SA_PROPIO_Q.csv` y `PIB_SA_PROPIO_Q_outliers.csv` de la misma capa; si no, `stop()`. Con G-6 sobre
  el corte, prueba que L1 es la L1 de la que salió la L3 del corte. Evidencia (2026-10-03, L1/L3 locales del
  2026-09-30): diferencia 0 y texto idéntico; cambiar en 0,01 % un solo valor NSA cambia los 145 períodos.
  Límite: dos vintages con la NSA idéntica no se distinguen, pero tampoco cambian el ajuste por origen.
- **C-6 · Reproducción.** **DECIDIDO:** la corrida que reproduce Fase 4 sobre el corte usa `exp_id`
  `F5_REPRO_*` (uno por cada `F4_BENCH_*`), en `data/L4_experiments/` y en `07_experimentos.csv`. Criterio
  de aceptación: `make master CONJUNTO=… SALIDA=…` reproduce los sha256 sin CR de los cuatro insumos del
  motor de la corrida de cierre (`c4e8b39`), y cada `F5_REPRO_*` reproduce las tablas de su `F4_BENCH_*`
  salvo la columna `exp_id` y las columnas `cobertura_80`, `cobertura_95` y `crps` de `metricas.csv`, que en
  la corrida de cierre estaban vacías.
- **C-7 · Semillas de la reproducción.** **DECIDIDO:** cada `F5_REPRO_X` declara `semilla_exp = F4_BENCH_X`
  y el motor siembra con ella (modelos y MCS). El manifiesto lo declara.
- **C-8 · Experimentos de Fase 4.** **DECIDIDO:** los `exp_id` `F4_*` quedan cerrados: el motor se detiene
  con `stop()` si se le piden. `make eval CONJUNTO=…` corre por defecto los experimentos de Fase 5 (hoy, los
  `F5_REPRO_*`). `EXPERIMENTOS` de Fase 4 sigue declarado para V12 y para `tabla_resultados_fase4.R`, que
  relee los directorios del cierre.

**Uso.**

```
make master CONJUNTO=doc/metodologia/corte_fase5.csv SALIDA=data/conjuntos/corte_f5
make eval   CONJUNTO=doc/metodologia/corte_fase5.csv SALIDA=data/conjuntos/corte_f5
```
