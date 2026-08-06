# ADR-004: Tratamiento de quiebres estructurales y del shock de 2020

**Estado:** Cerrado
**Fecha:** 2026-08-06
**Relacionado con:** ADR-001 (ajuste estacional propio como insumo)

## Contexto

Con una muestra de ~140 observaciones, el trimestre de mayor contracción de 2020 domina la estimación de la matriz de covarianzas de cualquier VAR y la varianza residual de cualquier modelo con volatilidad constante. Una variable dicotómica simple no resuelve el problema: distorsiona la estimación de la dinámica.

## Alternativas consideradas

- **Dummy con decaimiento estimado (Lenza–Primiceri):** estándar de la literatura específicamente para BVAR, pero no generaliza de forma limpia a modelos de árboles ni a ecuaciones puente — exigiría un tratamiento distinto por familia de modelo.
- **Volatilidad estocástica / errores con colas gruesas:** más general en teoría, pero de aplicación no directa de forma consistente a la vez sobre ARIMA, BVAR y métodos de árboles, que no tienen un concepto equivalente de "volatilidad estimada".
- **Exclusión de los trimestres afectados de la estimación:** simple y transparente, pero descarta información sobre la recuperación 2021–2022 que probablemente es informativa. Se reserva como prueba de robustez, no como estrategia principal.
- **Estimación en dos submuestras con contraste de estabilidad:** más una prueba de diagnóstico que una estrategia de tratamiento primaria.

## Decisión

- **Estrategia principal:** tratamiento como outlier aditivo/transitorio en la fase de ajuste estacional (enfoque de Ng y coautores), aplicado una sola vez, aguas arriba, en la capa L3. Se aprovecha la detección nativa de outliers (AO/LS/TC) de X-13ARIMA-SEATS (paquete `seasonal`), que de todos modos se construye para el ajuste propio decidido en ADR-001. Las fechas de outlier detectadas se trasplantan como variables dicotómicas **declaradas** (no reestimadas) a la estimación sobre la serie oficial, que es la variable objetivo primaria.
- **Estrategia de robustez:** contraste de estabilidad en dos submuestras (pre/post 2020), reportado junto a los resultados de la estrategia principal.
- Otros quiebres candidatos (dolarización 2001, terremotos 2001, entrada en vigor del CAFTA-DR, crisis financiera global 2008–2009, adopción de bitcoin 2021, cambios de base en índices de precios y empleo) se documentan en el catálogo `09_rupturas` aunque no se modelen explícitamente.

## Consecuencias

- Cada modelo del conjunto rebalanceado (sección 6) recibe una serie ya tratada, sin necesitar lógica de tratamiento especial por familia — reduce sustancialmente la superficie de implementación frente a las alternativas descartadas.
- El contraste de submuestras funciona además como verificación indirecta de si el tratamiento de outlier fue suficiente: si las submuestras resultan estables salvo por el nivel, respalda la hipótesis de outlier transitorio en vez de cambio de régimen genuino.
- La estrategia queda acoplada a la existencia del ajuste estacional propio (ADR-001); si esa pista se abandonara, este ADR requeriría revisión.
