# ADR-005: Soporte tecnológico de los catálogos

**Estado:** Cerrado
**Fecha:** 2026-08-06
**Relacionado con:** ADR-006, ADR-009

## Contexto

El prompt original establece que "nunca deberán proponerse procesos manuales si existe una alternativa automatizable" y a la vez que el sistema se construirá "mediante hojas de cálculo estructuradas". Ambas cosas son incompatibles: las hojas de cálculo invitan a la edición manual no registrada, no producen *diffs* legibles en control de versiones, ocultan lógica dentro de fórmulas de celda fuera del alcance de la revisión, y alteran silenciosamente tipos de dato.

## Alternativas consideradas

- Hojas de cálculo estructuradas (propuesta original) — descartada por las razones anteriores.
- Base de datos relacional desde el inicio — descartada para el núcleo mínimo viable por sobre-ingeniería prematura; queda como extensión (sección 9, extensión 5).

## Decisión

- Catálogos en **texto plano versionado en Git**.
- **CSV** con esquema declarado para catálogos de estructura homogénea y muchos registros: `03_series`, `04_transformaciones`, `05_series_master`, `07_experimentos`, `08_vintages`, `09_rupturas`.
- **YAML**, un archivo por registro, para catálogos con pocos registros y campos narrativos largos: `01_publicaciones`, `02_metodologias`, `06_modelos`.
- Esquema validado formalmente con **Frictionless Data Table Schema** (`datapackage.json`).
- Validación automática en el pipeline con **`pointblank`** (R — sustituye a `pandera`/`validate`, alineado con ADR-009).
- **DuckDB** como artefacto consolidado derivado, generado por código, nunca editado a mano.

## Consecuencias

- La eventual migración a base de datos relacional (extensión diferida) es un *script* de carga, no un rediseño del modelo conceptual.
- Si se requiere una interfaz de edición cómoda, se exporta una vista a hoja de cálculo, pero la fuente de verdad permanece en texto plano.
- El pipeline debe fallar —no advertir— ante incumplimientos de esquema, conforme a §3.5 de la senda metodológica.
