# Sistema de Información Estadística y modelos de proyección del PIB trimestral de El Salvador

Sistema de información estadística macroeconómica documentado, trazable, versionado, reproducible y con registro de versiones de publicación (*vintages*) para El Salvador. La comparación de modelos econométricos y de aprendizaje automático para pronóstico del PIB trimestral es la demostración de uso del sistema, no el objetivo central — ver `doc/senda_metodologica.md`.

## Estado

**Fase 0 — cerrada.** Nueve ADR registrados (ADR-001 a ADR-009); ocho cerrados, ADR-008 parcial (quedan BCR y CEPAL en gestión, y la decisión de política de L0 aplazada al corte del BCR — el estado por fuente está en ADR-008; tarea de Fase 1, no bloqueante). Cierre verificado y revalidado en CI — ver [`doc/adr/README.md`](doc/adr/README.md) para el detalle de cada decisión y el registro de cierre.

## Estructura

```
doc/adr/             decisiones de arquitectura registradas (ADR-001 … ADR-009)
doc/metodologia/     notas metodológicas específicas (empalme, shock 2020, protocolo, supuestos)
doc/auditorias/      revisiones independientes del repositorio (sin autoridad decisoria)
doc/bitacora_verificaciones.md   registro de corridas del verificador de fuente_celda
doc/bitacora_fuentes_fragiles.md fragilidad de cada fuente y procedimiento de recuperación
doc/captura_bcr_livewire_hallazgo.md   hallazgo técnico de captura headless del portal del BCR (2026-08-24)
catalogos/           las 9 tablas de metadatos del sistema, esquema en datapackage.json
data/L0_raw … L4/    capas de datos unidireccionales — ver CLAUDE.md antes de tocar cualquiera
src/                 código del pipeline, organizado por capa
src/adquisicion/README.md        diseño de los scripts de captura de L0
tests/               pruebas del pipeline
scripts/             utilidades de configuración (bootstrap de entorno, etc.)
```

## Empezar

`renv.lock` ya existe y está fijado (155 paquetes: los 13 de ADR-009 más `xml2` y `httr2`). Primer paso en una máquina con R:

```r
renv::restore()
```

Eso reproduce el entorno exacto en cualquier máquina limpia — confirmado en CI sobre `ubuntu-latest`. `scripts/bootstrap_renv.R` documenta cómo se generó el lockfile (`renv::snapshot()` a partir de `DESCRIPTION`) por si hace falta regenerarlo tras cambiar el stack de ADR-009.

## Licencia

Código bajo MIT (`LICENSE`). Documentación bajo CC-BY-4.0 (`LICENSE-docs`). Ver ADR-008 para la política de datos no redistribuibles.
