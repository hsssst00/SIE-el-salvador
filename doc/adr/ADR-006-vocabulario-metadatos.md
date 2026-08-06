# ADR-006: Vocabulario de metadatos

**Estado:** Cerrado
**Fecha:** 2026-08-06
**Relacionado con:** ADR-005

## Contexto

Evitar inventar un esquema propio de metadatos cuando existe uno interoperable ya utilizado por las fuentes primarias del proyecto.

## Alternativas consideradas

Esquema propio ad-hoc — descartado: no aporta ventaja sobre un estándar ya adoptado por las instituciones fuente, y añade una carga de diseño y de mantenimiento sin beneficio correspondiente.

## Decisión

Alinear los nombres y la semántica de los campos con **SDMX** (Statistical Data and Metadata eXchange), al menos en el nivel de conceptos: `FREQ`, `REF_AREA`, `UNIT_MEASURE`, `UNIT_MULT`, `ADJUSTMENT`, `REF_PERIOD`, `OBS_STATUS`, `TIME_PERIOD`, `DECIMALS`, `TITLE`, `SOURCE_AGENCY`.

## Consecuencias

- Interoperabilidad directa con el BCR, la SECMCA, el FMI, el Banco Mundial y la CEPAL, que ya usan SDMX — facilita incorporar series de organismos internacionales sin re-mapear conceptos.
- Sin costo de diseño adicional relevante: el vocabulario ya existe y ya es el que hablan las fuentes del proyecto.
