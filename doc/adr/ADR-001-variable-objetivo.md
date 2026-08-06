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
- **Métrica de evaluación y reporte:** tasa de variación interanual, conforme a §5.3 de la senda metodológica ("la unidad de interés para política").
- **Enfoque de agregación:** top-down como núcleo mínimo viable. Bottom-up por actividad económica queda diferido como extensión (sección 9), con revisión de esta postura antes de que la Fase 3 construya `05_series_master` — no antes.
- **Base y sistema de cuentas:** cerrado por ADR-003. Serie objetivo: serie oficial completa del BCR, 1990-T1 a 2026-T1 (145 observaciones), declarada homogénea por el BCR (retropolación oficial 1990-T1–2005-T4 + compilación nativa SCN 2008 2005-T1–2026-T1, con superposición de validación de 4 trimestres). No se requiere empalme propio.
- **Vintage de referencia:** resuelto por extensión de ADR-007 — evaluación contra el vintage disponible en cada origen de pronóstico (real-time) como criterio primario; la última revisión disponible se usa como comparación secundaria, no como referencia de evaluación.

## Consecuencias

- El catálogo `04_transformaciones` tendrá dos cadenas paralelas de ajuste estacional (oficial: *pass-through* documentado; propio: transformación ejecutable), y `05_series_master` distinguirá el rol de cada una (`target_primary` vs. `target_robustness`).
- **Enmienda registrada (2026-08-06):** ADR-003 verificó la cobertura real. Con esto, D1 queda completamente cerrado — no quedan sub-puntos pendientes.
- La muestra disponible (145 observaciones) es ligeramente mayor a la supuesta originalmente (~140), lo cual no cambia ninguna decisión de diseño ya tomada, solo la confirma.
