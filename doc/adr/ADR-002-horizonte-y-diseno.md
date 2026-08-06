# ADR-002: Horizonte y diseño de los dos ejercicios

**Estado:** Cerrado
**Fecha:** 2026-08-06 (enmendado el mismo día tras verificación de campo y decisión de corte)
**Relacionado con:** ADR-001, ADR-003

## Contexto

La senda metodológica (§1.3) separa dos ejercicios que exigen tratamientos distintos: Ejercicio A (evaluación incondicional retrospectiva, h = 1…8) y Ejercicio B (proyección condicional prospectiva, h = 1…20). Deben fijarse formalmente: horizontes evaluados en A, período de evaluación, número de reestimaciones, y fuente de supuestos exógenos en B.

## Alternativas consideradas

- **Horizontes:** conjuntos alternativos a h = 1, 2, 4, 8.
- **Fuente de supuestos exógenos (Ejercicio B):** FMI WEO exclusivamente / híbrido FMI WEO + proyecciones específicas de EE. UU. (Fed / BEA / CBO) / Consensus Forecasts u otro agregador privado.

FMI WEO exclusivo se consideró más simple de documentar y defender, pero se descartó como única fuente porque el propio documento (§1.3) identifica a Estados Unidos como el factor dominante de incertidumbre a horizonte largo para El Salvador (dolarización, remesas, comercio), lo que justifica una fuente específica para esas variables.

## Decisión

- **Horizontes evaluados en el Ejercicio A:** h = 1, 2, 4, 8 trimestres, reportados por separado, nunca agregados en un único indicador (conforme a §5.1).
- **Fuente de supuestos exógenos para el Ejercicio B:** híbrida. FMI WEO para variables globales y regionales; proyecciones de la Reserva Federal / BEA / CBO específicamente para variables relacionadas con la actividad económica de Estados Unidos (insumo directo para el supuesto de remesas).
- **Período de evaluación y número de reestimaciones:** cerrado, con base en la N confirmada por ADR-003 (145 observaciones, 1990-T1 a 2026-T1). Ventana de estimación inicial: 1990-T1 a 2012-T4 (92 observaciones — balance entre estabilidad de la estimación inicial, relevante para BVAR y para la validación anidada de hiperparámetros de ML, y potencia estadística de las pruebas de significancia). Evaluación pseudo-fuera-de-muestra: desde 2013-T1, con reestimación en cada origen (ventana expansiva). Número de reestimaciones: 52 (un origen por trimestre, 2013-T1 a 2025-T4). Orígenes evaluables por horizonte: h=1 → 52; h=2 → 51; h=4 → 49; h=8 → 45 (decrece con h porque los orígenes más recientes no tienen aún dato real observado a ese horizonte).

## Consecuencias

- El documento de supuestos exógenos (Fase 6, entregable `doc/metodologia/supuestos_escenarios.md`) debe incluir una nota explícita reconociendo que no se garantiza consistencia interna perfecta entre las dos fuentes combinadas.
- **Enmienda registrada (2026-08-06):** ADR-003 confirmó N=145 y se fijó el corte de ventana en sesión de trabajo. Con esto, D2 queda completamente cerrado.
