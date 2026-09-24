# ADR-004: Tratamiento de quiebres estructurales y del shock de 2020

**Estado:** Cerrado
**Fecha:** 2026-08-06 (enmendado el 2026-08-07 tras enmienda de ADR-001)
**Relacionado con:** ADR-001 (ajuste estacional propio, ahora vía única de la variable objetivo primaria)

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

## Enmienda (2026-08-07)

ADR-001 cerró su enmienda: agotadas las vías de verificación, no existe una serie oficial desestacionalizada del BCR que cubra 1990–2005, de modo que la variable objetivo primaria pasa a construirse mediante ajuste estacional propio (X-13ARIMA-SEATS) sobre la concatenación de las series NSA (retropolado 1990–2005 + compilación nativa 2005–2026). La serie oficial SA del BCR, que solo cubre 2005–2026, invierte su rol: de variable objetivo primaria pasa a verificación de robustez.

Esto **no reabre la decisión de este ADR.** La estrategia principal (outlier aditivo/transitorio, detección nativa AO/LS/TC de X-13ARIMA-SEATS, aplicado una sola vez aguas arriba en L3) y la estrategia de robustez (contraste de submuestras pre/post 2020) siguen siendo las mismas. Lo que cambia es la descripción del mecanismo de la estrategia principal, que la Decisión original (párrafo de "Estrategia principal") describe de forma ahora desactualizada:

- **Ya no hay trasplante entre dos series.** El texto original describe las fechas de outlier detectadas en el ajuste propio "trasplantándose" como dummies declaradas a la estimación sobre la serie oficial (entonces la variable objetivo primaria). Bajo el ADR-001 enmendado existe una sola fase de ajuste estacional para el target primario —el ajuste propio— y el tratamiento de outlier se aplica directamente dentro de esa misma fase, sobre la misma serie que constituye la variable objetivo primaria. No hay una serie separada a la que transplantar nada.
- **La serie oficial SA del BCR, en su nuevo rol de robustez**, se contrasta en el tramo de superposición (2005–2026) contra la variable objetivo primaria ya tratada. Este proyecto no le aplica tratamiento de outlier propio; cualquier tratamiento de atípicos que la serie oficial contenga es interno al BCR y queda fuera de nuestro alcance.
- **El acoplamiento señalado en Consecuencias se refuerza, no se afloja.** Bajo el ADR-001 original, el ajuste propio era una pista paralela de robustez; bajo el ADR-001 enmendado es la única fase de ajuste estacional del target primario. Si esa pista se abandonara, no solo requeriría revisar este ADR: no quedaría fase de ajuste estacional donde aplicar el tratamiento aquí decidido.

## Nota de seguimiento — el tratamiento se aplica dentro de cada origen de evaluación (2026-09-24)

**Contexto.** Este ADR aplica el tratamiento del shock de 2020 una sola vez, aguas arriba, en
la fase de ajuste estacional de L3: X-13ARIMA-SEATS sobre la concatenación NSA 1990-2026, con
los dos AO detectados (2020-T2 y 2020-T3, declarados en
`data/L3_master/PIB_SA_PROPIO_Q_outliers.csv`). Para la evaluación pseudo-fuera-de-muestra eso
es una filtración estructural: los filtros de X-13 son bilaterales, así que el valor
desestacionalizado de cualquier origen incorpora trimestres posteriores a él, y el pronóstico
se evaluaría contra un target que en ese origen no existía.

**Decisión (Harold, 2026-09-24; fichas F4-09 y F4-09b).** Para el Ejercicio A, el ajuste
estacional del objetivo **se reestima dentro de cada origen**:

- En cada origen `o`, X-13 corre sobre la concatenación NSA `[1990-T1, o]`.
- **Transformación fija en log.** No se usa la selección automática: con los defaults de
  `seasonal`, la especificación enviada a X-13 lleva `transform = auto` y podría cambiar de un
  origen a otro.
- **Orden ARIMA seleccionado automáticamente en cada origen**, solo con datos `≤ o`. El orden
  elegido se guarda por origen en el artefacto de L4, y una prueba informa cuánto cambia entre
  orígenes.
- **Outliers: solo los declarados, y solo cuando el origen ya los alcanzó.** La detección
  automática queda desactivada. El AO de 2020-T2 entra desde el origen 2020-T2 y el de 2020-T3
  desde el origen 2020-T3. En los orígenes anteriores no entra ningún regresor de 2020.
- El ajuste único de L3 se conserva como contraste (robustez R6 del protocolo).

**Qué no cambia.** La estrategia principal sigue siendo la misma: el shock se trata como
outlier aditivo en la fase de ajuste estacional, con fechas declaradas. Cambia dónde se aplica
(dentro del bucle de orígenes, no una sola vez) y la especificación deja de elegirse con la
muestra completa. La estrategia de robustez (submuestras pre/post 2020) queda igual, y
`data/L3_master/PIB_SA_PROPIO_Q.csv` tampoco cambia.

**Por qué el orden se selecciona en cada origen y no se congela.** Congelar la especificación
con la que eligió la corrida de L3 (T002: `ARIMA(1 1 1)(0 1 1)`, `transform=log`) usaría una
especificación elegida con datos hasta 2026, que es la misma filtración que esta nota viene a
eliminar, solo que por otra vía. Congelarla en el primer origen no filtra, pero supone que
nadie habría revisado la especificación en 13 años, y esa muestra inicial no contiene el
shock. La selección por origen reproduce lo que habría hecho un analista en cada momento, y
guardar el orden elegido convierte la especificación en un dato registrado.

**Prerrequisito (2026-09-24).** `x13binary` 1.1.61.2 está en `renv.lock` y el binario
`x13ashtml.exe` existe en `renv/library` para R-4.5 y R-4.6. Su ejecución en la máquina del
proyecto queda por verificar con `seasonal::checkX13()` antes de la primera corrida del motor
sobre L3; el resultado se asienta en `doc/bitacora_verificaciones.md`. La vía no corre en CI:
las corridas con ajuste por origen se certifican con evidencia textual
(`doc/evidencia_cierre_fase4.txt`), no con un run de CI.

**Relación con el hallazgo M2 de la revisión independiente de Fase 3** (la especificación de
X-13 está registrada en prosa y no fijada en el código). Esta nota lo resuelve para la
evaluación, porque registra la especificación elegida en cada origen. No cambia el tratamiento
en L3.
