# Contexto del proyecto para Claude Code

## Qué es esto

Sistema de Información Estadística (SIE) para variables macroeconómicas de El Salvador, con un ejercicio de comparación de modelos de proyección del PIB trimestral como demostración de uso.

**El SIE es el producto principal. Los modelos de proyección son la prueba de uso, no el objetivo central.** No inviertas esfuerzo desproporcionado en la sofisticación de modelos a costa de la trazabilidad, validación o documentación del sistema de datos. Si en algún momento el trabajo empieza a inclinarse hacia "mejorar el modelo" a costa de "fortalecer el sistema", señálalo — no lo asumas y sigas.

## Estado del proyecto

Fase 0 (decisiones fundacionales) — ver `doc/adr/README.md` para el estado exacto. A la fecha de este archivo: ocho de nueve ADR cerrados; solo queda pendiente la parte de ADR-008 sobre condiciones de redistribución de fuentes distintas al BCR (tarea de Fase 1, no bloqueante).

**Antes de escribir cualquier código de estimación o transformación, lee los ADR relevantes en `doc/adr/`.** Son la especificación. No hay decisión metodológica de las nueve fundacionales que debas tomar tú — ya están tomadas y documentadas.

## Reglas no negociables

1. **Nunca edites manualmente `data/L0_raw/`.** Es inmutable. Todo archivo ahí llega vía script de descarga, con entrada correspondiente en `data/L0_raw/manifiesto.csv` (checksum SHA-256, URL, fecha, código HTTP).
2. **Nunca edites los catálogos en `catalogos/` a mano fuera de lo declarado en su esquema.** Cualquier cambio de esquema pasa primero por `catalogos/datapackage.json`.
3. **Ninguna capa de datos (`L1`–`L4`) se edita directamente.** Cada una se genera por código a partir de la anterior. Si necesitas cambiar un valor derivado, cambias el código que lo genera, no el archivo.
4. **Ante una decisión metodológica no cubierta por un ADR existente, detente y pregunta.** No la resuelvas por inferencia ni la dejes implícita en el código. Esto incluye: definiciones de variables nuevas, tratamiento de datos faltantes no contemplado, elección de hiperparámetros no especificada, cualquier cosa que debería ser su propio ADR.
5. **El stack es R, cerrado (ADR-009).** No introduzcas Python u otro lenguaje salvo que exista un ADR posterior que lo autorice explícitamente.
6. **Todo script de descarga (`src/adquisicion/`) debe fallar de forma visible, no silenciosa**, ante cambios de estructura de la fuente — conforme al principio de inmutabilidad de L0.
7. **La validación falla, no advierte** (§3.5 de la senda metodológica). Un catálogo que no cumple su esquema detiene el pipeline.

## Convenciones (senda metodológica §3.4)

- Identificadores legibles y estables: `{fuente}.{concepto}.{unidad}.{ajuste}.{frecuencia}` — ej. `BCR.PIB.VOL.SA.Q`.
- Períodos en ISO 8601: `2024-Q3`, `2024-07`.
- UTF-8, separador decimal punto, sin separador de miles, ausentes como celda vacía (nunca `0`, `-`, `n.d.`).
- `snake_case` en nombres de campo, sin acentos ni espacios.
- Cada directorio de catálogo lleva su propio `README.md` con diccionario de variables.

## Comandos

Ver `Makefile`. Objetivos previstos: `make raw | clean | master | eval | report`. Muchos aún no tienen script detrás — no lo inventes de una vez; impleméntalo cuando la fase correspondiente lo requiera, conforme al orden de fases de la senda metodológica (§4).

## Stack (ADR-009)

R vía `renv`. Ver `scripts/bootstrap_renv.R` para inicializar el entorno — no se ha corrido todavía en este repositorio (creado sin acceso a CRAN). Paquetes: `pointblank`, `duckdb`, `seasonal`, `tempdisagg`, `fable`, `tsibble`, `vars`, `tsDyn`, `BVAR`, `midasr`, `glmnet`, `ranger`, `lightgbm`.

## Orden de fases (no te lo saltes)

Fase 0 → 1 (inventario) → 2 (adquisición) → 3 (normalización/validación) → 4 (protocolo de evaluación, probado con datos sintéticos **antes** de estimar nada) → 5 (estimación) → 6 (proyección condicional) → 7 (publicación). El criterio de cierre de cada fase está en la senda metodológica §4. No implementes estimación de modelos (Fase 5) antes de que el motor de evaluación de Fase 4 esté probado — es la regla más importante del documento.
