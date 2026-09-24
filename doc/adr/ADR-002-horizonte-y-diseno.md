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

## Nota de aclaración — convención de indexación del origen (2026-09-24)

**Contexto.** La Decisión de este ADR publica tres cifras sobre el período de evaluación: la
ventana de estimación inicial (1990-T1 a 2012-T4, 92 observaciones), la lista de orígenes
(52, "un origen por trimestre, 2013-T1 a 2025-T4") y los orígenes evaluables por horizonte
(h=1 → 52; h=2 → 51; h=4 → 49; h=8 → 45). Al especificar el motor de evaluación de Fase 4
se verificó que las tres no se cumplen a la vez bajo ninguna convención de indexación. El ADR
no declaraba la convención.

**Evidencia (serie objetivo real, 145 obs, 1990-Q1 a 2026-Q1).** Los cuatro conteos se
reproducen exactamente con dos convenciones que difieren en un trimestre:

| Convención | Orígenes | Último target | h=1/2/4/8 | Muestra en el primer origen |
|---|---|---|---|---|
| A — origen = último período estimado, 2013-Q1 a 2025-Q4 | 52 | 2026-Q1 | 52/51/49/45 | 1990-Q1 a 2013-Q1, **93** obs |
| B — origen = último período estimado, 2012-Q4 a 2025-Q3 | 52 | 2025-Q4 | 52/51/49/45 | 1990-Q1 a 2012-Q4, **92** obs |

Las variantes cruzadas dan 51/50/48/44 (A con targets hasta 2025-Q4) y 53/52/50/46 (B con
targets hasta 2026-Q1). A coincide con la lista de orígenes y con los conteos, pero no con las
92 observaciones de la ventana inicial. B coincide con la ventana inicial y con los conteos,
pero su último origen es 2025-T3, no 2025-T4.

**Decisión (Harold, 2026-09-24): convención A.** Definición operativa:

> **Origen `o`** es el último trimestre con dato observado del objetivo que entra a la
> muestra de estimación. El pronóstico a horizonte `h` emitido en `o` se compara contra el
> período `o + h`. Los orígenes van de 2013-T1 a 2025-T4 (52), y un par `(o, h)` se evalúa
> solo si `o + h` está observado.

La única frase de la Decisión que cambia es la de la ventana inicial: **1990-T1 a 2013-T1
(93 observaciones)**, en vez de 1990-T1 a 2012-T4 (92). La lista de orígenes, el número de
reestimaciones (52) y los cuatro conteos por horizonte se mantienen.

**Por qué A y no B.** A conserva las dos cifras que el proyecto ya publicó como diseño —la
lista de orígenes y los cuatro conteos, transcritos también en
`doc/metodologia/protocolo_evaluacion.md`— y usa toda la muestra disponible. Es una aclaración
de indexación, no un cambio de diseño: el balance entre estabilidad de la estimación inicial y
potencia de las pruebas, que motivó el corte, es el mismo con 93 que con 92 observaciones.

**Consecuencia.** El motor de evaluación (`src/evaluacion/`) codifica esta convención y la
prueba contra las cuatro combinaciones de la tabla, como regresión: si alguien cambia la
aritmética de orígenes, los conteos dejan de coincidir y la prueba falla.
