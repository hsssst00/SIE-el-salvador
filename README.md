# Sistema de Información Estadística y modelos de proyección del PIB trimestral de El Salvador

Sistema de información estadística macroeconómica documentado, trazable, versionado, reproducible y con registro de versiones de publicación (*vintages*) para El Salvador. La comparación de modelos econométricos y de aprendizaje automático para pronóstico del PIB trimestral es la demostración de uso del sistema, no el objetivo central — ver `doc/senda_metodologica.md`.

## Estado

**Fase 0 — decisiones fundacionales.** Ocho de nueve ADR cerrados. Ver [`doc/adr/README.md`](doc/adr/README.md) para el detalle de cada decisión y lo que queda pendiente.

## Estructura

```
doc/adr/            decisiones de arquitectura registradas (ADR-001 … ADR-009)
doc/metodologia/     notas metodológicas específicas (empalme, shock 2020, protocolo, supuestos)
catalogos/           las 9 tablas de metadatos del sistema, esquema en datapackage.json
data/L0_raw … L4/    capas de datos unidireccionales — ver CLAUDE.md antes de tocar cualquiera
src/                 código del pipeline, organizado por capa
tests/               pruebas del pipeline
scripts/             utilidades de configuración (bootstrap de entorno, etc.)
```

## Empezar

Este repositorio se creó sin acceso a un espejo de CRAN, así que `renv.lock` todavía no existe de verdad. Primer paso en una máquina con R:

```r
source("scripts/bootstrap_renv.R")
```

Eso inicializa `renv`, instala los paquetes listados en `doc/adr/ADR-009-stack-tecnologico.md`, y genera el `renv.lock` real. A partir de ahí, `renv::restore()` reproduce el entorno en cualquier máquina limpia — ese es el criterio de cierre de Fase 0.

## Licencia

Código bajo MIT (`LICENSE`). Documentación bajo CC-BY-4.0 (`LICENSE-docs`). Ver ADR-008 para la política de datos no redistribuibles.
