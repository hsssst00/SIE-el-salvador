# ADR-003: Tratamiento del empalme de cuentas nacionales

**Estado:** Cerrado
**Fecha:** 2026-08-06 (enmendado el 2026-08-09 tras documentar el método de retropolación del BCR)
**Relacionado con:** ADR-001 (variable objetivo), ADR-002 (horizonte y diseño), ADR-004 (shock 2020), ADR-007 (vintages)

## Contexto

El prompt original asumía series trimestrales continuas desde ~1990 sin verificar si la serie utilizable bajo la metodología vigente cubría todo ese período, o si era ella misma un empalme entre dos sistemas de cuentas nacionales distintos. La senda metodológica (§2, D3) marcó esto como la restricción que condiciona todo el diseño y exigió verificarla antes de cerrar cualquier otra decisión dependiente.

## Verificación realizada (portal del BCR — Base de Datos Económica y Financiera)

- Serie bajo metodología SCN 2008 (compilación nativa): **2005-T1 a 2026-T1** — 85 observaciones.
- Serie retropolada oficial del BCR: **1990-T1 a 2005-T4** — 64 observaciones, declarada explícitamente por el BCR como "serie homogénea, retropolada".
- Superposición de 4 trimestres (2005-T1 a 2005-T4) entre ambas series — probable período de calibración/validación de la retropolación contra la compilación nativa.
- Cobertura total efectiva única: **1990-T1 a 2026-T1 — 145 observaciones.**
- Próxima publicación: 30 de septiembre de 2026 (añadirá 2026-T2).

## Alternativas consideradas

- **Empalme propio** (Denton, Denton-Cholette, Chow-Lin, enlace por tasas de variación) — necesario únicamente si no existiera retropolación oficial. Descartado: el BCR ya ofrece una serie retropolada declarada homogénea; repetir el ejercicio sería trabajo redundante y menos autorizado que la fuente oficial.
- **Restringir el proyecto solo al tramo de compilación nativa** (2005-T1 en adelante, 85 obs) como muestra única — descartado como estrategia principal: reduce la muestra en más del 40% sin necesidad, existiendo una alternativa oficial más amplia. Se conserva como variante de robustez.

## Decisión

- **Serie objetivo:** la serie oficial completa del BCR, 1990-T1 a 2026-T1 (145 observaciones), tal como el BCR la declara — homogénea, sin empalme propio adicional.
- **No se requiere método de empalme propio.** La retropolación ya fue realizada y validada por el BCR.
- **Variante de robustez:** reestimar el conjunto de modelos únicamente sobre el tramo de compilación nativa (2005-T1 a 2026-T1, 85 observaciones), como prueba de sensibilidad a la inclusión del tramo retropolado. Coincide con lo ya previsto en la senda metodológica original y con el alcance acotado de reconstrucción de vintages fijado en ADR-007.
- **Pendiente, no bloqueante:** localizar y citar la nota metodológica específica del BCR sobre el método de retropolación, para `doc/metodologia/empalme_cuentas_nacionales.md` (entregable de Fase 1).

## Consecuencias

- Cierra el sub-punto "base y sistema de cuentas" de ADR-001 (ver enmienda en ese archivo).
- Provee la N real (145) que faltaba para cerrar "período de evaluación" y "número de reestimaciones" en ADR-002.
- El tramo retropolado (1990-T1 a 2005-T4) incluye dos quiebres ya identificados en ADR-004 (dolarización 2001, terremotos 2001) — no requieren tratamiento adicional al ya previsto allí, pero conviene cruzar referencias en el catálogo `09_rupturas`.
- El riesgo "cobertura de la serie de PIB menor a lo supuesto" (senda metodológica, §8), marcado probabilidad e impacto altos, **no se materializó**: la cobertura real (145 obs) iguala o supera el supuesto original (~140 obs).
- **Nota de consistencia (2026-08-07):** este ADR no distinguió, al momento de cerrarse, si la retropolación oficial 1990-2005 aquí verificada aplica a la serie NSA, a la SA, o a ambas. La enmienda de ADR-001 resolvió esa ambigüedad: la retropolación solo existe para la serie NSA (`BCR.PIB.VOL.NSA.Q.RETRO`); no hay evidencia de una retropolación oficial de la serie SA. Las 145 observaciones homogéneas verificadas aquí corresponden, en consecuencia, a la concatenación NSA — que es la misma sobre la que se aplica el ajuste estacional propio que construye la variable objetivo primaria (ver ADR-001, ADR-004). Esto no reabre la decisión de este ADR: sigue sin requerirse empalme propio: la retropolación oficial del BCR (serie NSA) sigue siendo la fuente.

## Enmienda (2026-08-09)

`doc/metodologia/empalme_cuentas_nacionales.md` documentó el método de retropolación del BCR — Hernández, Mario Roger (2018), *Sistema de Cuentas Nacionales de El Salvador SCNES*, cap. 4: método de interpolación de series, con origen en 2005 = 100 retropolado año por año hasta 1990 — y con eso quedan actualizados dos puntos de este ADR:

- **Pendiente resuelto.** El punto de "Decisión" que quedaba "pendiente, no bloqueante" (localizar y citar la nota metodológica del BCR sobre retropolación) está resuelto — ver la nota metodológica citada arriba.
- **Corrección de la caracterización de la superposición.** La "Verificación realizada" de 2026-08-06 describía la superposición de 4 trimestres (2005-T1 a 2005-T4) como "probable período de calibración/validación de la retropolación contra la compilación nativa" — una hipótesis razonable en su momento, sin fuente citada. La nota metodológica identifica la causa real: la retropolación del BCR fija 2005 como año de origen (índice = 100) y reconstruye hacia atrás desde ahí, y la compilación nativa 2005-2026 usa ese mismo año como base de sus propios índices de volumen encadenados. Ambas series comparten año base por diseño metodológico — el traslape de exactamente 4 trimestres es consecuencia estructural de eso, no un período de calibración.

Esto no reabre la decisión de este ADR: la serie objetivo (145 observaciones, sin empalme propio) y la variante de robustez descritas en "Decisión" siguen siendo las mismas. Lo que cambia es la explicación de un hecho ya verificado, ahora con fuente documentada.
