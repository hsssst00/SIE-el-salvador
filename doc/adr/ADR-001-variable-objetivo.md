# ADR-001: Definición operativa de la variable objetivo

**Estado:** Cerrado
**Fecha:** 2026-08-06 (enmendado el mismo día tras verificación de campo)
**Relacionado con:** ADR-003 (empalme), ADR-004 (shock 2020), ADR-007 (vintages)

## Contexto

El prompt original del proyecto nunca especifica qué es "el PIB". Es la decisión de mayor consecuencia aguas abajo: condiciona estacionariedad, interpretación de las métricas de error y comparabilidad entre modelos. Requiere fijar: concepto, base y sistema de cuentas, ajuste estacional, unidad de modelación, enfoque de agregación y vintage de referencia.

## Alternativas consideradas

- **Ajuste estacional:** serie oficial del BCR únicamente / ajuste propio únicamente / ambas.
- **Unidad de modelación:** nivel sin transformar / logaritmo del nivel / tasa trimestral (t/t-1) / tasa interanual (t/t-4) como representación primaria de estimación.
- **Enfoque de agregación:** top-down (agregado) / bottom-up (suma de proyecciones por actividad económica) en el núcleo mínimo viable.

Nivel sin transformar se descartó sin necesidad de discusión adicional: el PIB tiene tendencia, no es estacionario en niveles, y ningún modelo del conjunto rebalanceado (sección 6 de la senda metodológica) se estima razonablemente sobre eso sin transformación previa.

Tasa interanual como representación primaria se descartó porque, al ser una ventana de cuatro trimestres, induce autocorrelación mecánica de tipo MA(3) que no proviene de la dinámica económica sino de la construcción de la tasa — contaminaría la selección de órdenes de ARIMA/VAR si se usara como insumo directo de estimación.

## Decisión

- **Concepto:** PIB real a precios constantes (volumen).
- **Ajuste estacional:** la serie oficial desestacionalizada del BCR es la variable objetivo primaria, sobre la que se reportan todos los resultados. Se construye en paralelo un ajuste propio con X-13ARIMA-SEATS (paquete `seasonal` en R) como pista de robustez, y como insumo directo del tratamiento de outliers de 2020 (ver ADR-004).
- **Unidad de modelación:** logaritmo del nivel como representación raíz del linaje de transformaciones en el catálogo `04_transformaciones`. De ahí se derivan de forma consistente las tasas trimestral e interanual que cada familia de modelo requiera, evitando cadenas de cálculo paralelas e independientes que podrían divergir.
- **Métrica de evaluación y reporte:** tasa de variación interanual, conforme a la recomendación de D1 en §2 de la senda metodológica ("la métrica de interés para política"); reportada en la unidad de interés según §5.3.
- **Enfoque de agregación:** top-down como núcleo mínimo viable. Bottom-up por actividad económica queda diferido como extensión (sección 9), con revisión de esta postura antes de que la Fase 3 construya `05_series_master` — no antes.
- **Base y sistema de cuentas:** cerrado por ADR-003. Serie objetivo: serie oficial completa del BCR, 1990-T1 a 2026-T1 (145 observaciones), declarada homogénea por el BCR (retropolación oficial 1990-T1–2005-T4 + compilación nativa SCN 2008 2005-T1–2026-T1, con superposición de validación de 4 trimestres). No se requiere empalme propio.
- **Vintage de referencia:** resuelto por extensión de ADR-007 — evaluación contra el vintage disponible en cada origen de pronóstico (real-time) como criterio primario; la última revisión disponible se usa como comparación secundaria, no como referencia de evaluación.

## Consecuencias

- El catálogo `04_transformaciones` tendrá dos cadenas paralelas de ajuste estacional (oficial: *pass-through* documentado; propio: transformación ejecutable), y `05_series_master` distinguirá el rol de cada una (`target_primary` vs. `target_robustness`).
- **Enmienda registrada (2026-08-06):** ADR-003 verificó la cobertura real. Con esto, D1 queda completamente cerrado — no quedan sub-puntos pendientes.
- La muestra disponible (145 observaciones) es ligeramente mayor a la supuesta originalmente (~140), lo cual no cambia ninguna decisión de diseño ya tomada, solo la confirma.

## Cierre de la enmienda (2026-08-07)

Se agotaron las vías de verificación no invasivas (inspección directa del
archivo retropolado, revisión de robots.txt/sitemap del portal interactivo)
sin encontrar evidencia de una serie oficial desestacionalizada del BCR que
cubra el tramo 1990-2005. Por decisión del investigador, se da por cerrada
la búsqueda y se adopta el plan de reserva.

**Decisión final:** la serie objetivo primaria (1990-T1 a 2026-T1, 145
observaciones) se construye mediante ajuste estacional propio
(X-13ARIMA-SEATS vía `seasonal`), aplicado sobre la concatenación de las
dos series NSA disponibles (retropolado 1990-2005 + compilación nativa NSA
2005-2026), con el tratamiento de outlier de 2020 ya decidido en ADR-004
aplicado en la misma fase. La serie oficial SA del BCR (2005-T1 a 2026-T1)
invierte su rol respecto del ADR-001 original: pasa de variable objetivo
primaria a verificación de robustez — el ajuste propio se contrasta contra
ella en el tramo de superposición (2005-2026) como evidencia indirecta de
fiabilidad en el tramo donde no existe con qué contrastar (1990-2005).

Esto no reabre D4: el tratamiento del shock de 2020 sigue siendo el ya
decidido, ahora aplicado en lo que es la única fase de ajuste estacional
para el target primario, no una de dos.

**Nota de alcance:** el cómputo real del ajuste estacional es trabajo de
Fase 3, no de esta sesión. Hoy se registran las entradas de catálogo que
documentan y planifican esta transformación; no se ejecuta ni se
materializa la capa L3 todavía.

## Enmienda — vintage de referencia del ejercicio retrospectivo (2026-09-24)

**Contexto.** La Decisión de este ADR resolvió el vintage de referencia "por extensión de
ADR-007": evaluación contra el vintage disponible en cada origen de pronóstico (*real-time*)
como criterio primario, y la última revisión como comparación secundaria. Al especificar el
motor de evaluación de Fase 4 se verificó que ese criterio no es alcanzable para el período de
evaluación que fija ADR-002.

**Evidencia (catálogo `08_vintages.csv`, 2026-09-24).** De sus 56 filas, solo 24 tienen fecha
de publicación anterior a 2026, y las 24 son de `UT.DEMANDA_TOTAL_MENSUAL` (vintages anuales
con fecha sintética). El PIB trimestral tiene un único vintage,
`BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA.v2026-06`, y el retropolado
`BCR.PIB_T.SERIE_RETROPOLADA_1990_2005.v2019-03` no registra fecha de publicación. Ninguna
publicación del BCR tiene un vintage anterior a 2026-06. Para los 52 orígenes de 2013-T1 a
2025-T4 no existe en el sistema el PIB tal como se conocía en ese momento.

**Decisión (Harold, 2026-09-24).** Se separan dos pistas y no se confunden:

1. **Ejercicio retrospectivo (el resultado de Fase 5).** Se evalúa contra el vintage vigente
   del objetivo, filtrado de forma explícita por `vintage_id` en `data/L3_master/`. **Para
   este ejercicio se invierte el orden de la Decisión original**: la última revisión es la
   referencia, y el criterio real-time queda fuera de alcance. Cada tabla de resultados
   declara que el ejercicio usa datos revisados y cita el `vintage_id` registrado en la fila
   correspondiente de `catalogos/07_experimentos.csv`. La consecuencia conocida es que se
   sobreestima la precisión alcanzable en operación real; se declara como límite, no se
   estima.
2. **Pista real-time (prospectiva).** El motor filtra por `vintage_id` desde su primera
   versión, de modo que, cuando el registro prospectivo de ADR-007 acumule vintages del PIB,
   la misma corrida produzca la evaluación real-time que esta Decisión pedía, sin cambios de
   código. El registro empieza en `v2026-06` y suma un vintage por publicación trimestral.
   Esta pista no tiene resultado en Fase 5.

**Qué no cambia.** El concepto, el ajuste estacional, la unidad de modelación (log-nivel), la
métrica de reporte (tasa interanual) y el enfoque top-down siguen como están. El criterio
real-time sigue siendo el objetivo del proyecto: esta enmienda registra que es inalcanzable
con los vintages disponibles y define qué se hace mientras tanto, sin abandonarlo.

**Relación con ADR-007.** Esto no reabre la política de vintages: la captura prospectiva sigue
siendo compromiso firme y la reconstrucción retrospectiva, mejor empeño. Si la vía (b) de
ADR-007 recuperara vintages históricos del PIB, el ejercicio retrospectivo podría rehacerse en
real-time sobre los orígenes cubiertos, y esta enmienda se revisaría.

## Nota de seguimiento — ajuste estacional del objetivo dentro de cada origen de evaluación (2026-09-24)

Para el Ejercicio A, el ajuste estacional propio que construye la variable objetivo primaria
(X-13ARIMA-SEATS sobre la concatenación NSA) se reestima dentro de cada origen de evaluación,
con transformación log fija, orden ARIMA seleccionado solo con datos hasta el origen, y los AO
de 2020 como regresores declarados que entran solo desde el origen que los alcanza. La serie
`PIB_SA_PROPIO_Q` de L3 no cambia y queda como contraste. El detalle y la justificación están
en ADR-004, nota de seguimiento del 2026-09-24. Esta nota no cambia la definición del objetivo:
cambia en qué momento del pipeline se construye para la evaluación.
