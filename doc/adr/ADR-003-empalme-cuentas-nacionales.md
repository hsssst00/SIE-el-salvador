# ADR-003: Tratamiento del empalme de cuentas nacionales

**Estado:** Cerrado
**Fecha:** 2026-08-06
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
