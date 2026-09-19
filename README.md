# Sistema de Información Estadística y modelos de proyección del PIB trimestral de El Salvador

Sistema de información estadística macroeconómica documentado, trazable, versionado, reproducible y con registro de versiones de publicación (*vintages*) para El Salvador. La comparación de modelos econométricos y de aprendizaje automático para pronóstico del PIB trimestral es la demostración de uso del sistema, no el objetivo central — ver `doc/senda_metodologica.md`.

## Estado

Los conteos de esta sección (series, archivos de L0, publicaciones) son los del **cierre de cada
fase**, no el estado presente del catálogo — que crece en fases posteriores (ej. Fase 3 admite
series predictoras nuevas). Para el conteo actual, correr `make audit`
(`scripts/auditoria_mecanica.R`), que es la fuente que calcula estos números en cada corrida en
vez de que se transcriban a mano aquí (hallazgo M5 de la revisión independiente 2026-09-17).

**Fase 0 — cerrada.** Nueve ADR registrados (ADR-001 a ADR-009); ocho cerrados, ADR-008 parcial (quedan BCR y CEPAL en gestión, y la decisión de política de L0 aplazada al corte del BCR — el estado por fuente está en ADR-008; gestión vía ADR-008 con cortes fechados, no atada al cierre de fase). Cierre verificado y revalidado en CI — ver [`doc/adr/README.md`](doc/adr/README.md) para el detalle de cada decisión y el registro de cierre.

**Fase 1 — cerrada.** Inventario del ecosistema estadístico. El criterio de cierre (senda §4) se satisface sobre las variables *admitidas*: las 98 series de `catalogos/03_series.csv` (las cuatro publicaciones de PIB del BCR) con cobertura verificada y trazabilidad `fuente_celda` 98 PASS, y la variable objetivo con N=145 observaciones documentado (D3 / empalme). Se cierra bajo la interpretación de "ingresa al proyecto" = variable admitida, no inventario completo — ver la nota de §4 de la senda y el registro de cierre en [`doc/adr/README.md`](doc/adr/README.md). Quedan abiertas, sin bloquear el cierre, la cobertura de las publicaciones inventariadas sin serie admitida (compuerta *just-in-time* de Fase 3) y las condiciones de uso (vía ADR-008). Tag `v0.4.0-fase1`.

**Fase 2 — cerrada.** Adquisición. El criterio de cierre (senda §4) se satisface por la vía "`make raw` verifica la integridad de L0" (una de las dos ramas del criterio, fijada en la nota de cierre de Fase 2 de la senda, v0.5): 54 archivos de L0 con integridad cruzada 54/54 offline (`scripts/check_l0_integrity.R`, en CI) y física (`scripts/verificar_l0_fisico.R`, local); 30 publicaciones, 25 de ellas UT de captura manual por `robots.txt` (regla 9 de este archivo). Ver el registro "Cierre de Fase 2" en [`doc/adr/README.md`](doc/adr/README.md). Tag `v0.5.0-fase2`.

## Estructura

```
doc/adr/                               decisiones de arquitectura registradas (ADR-001 … ADR-009)
doc/metodologia/                       notas metodológicas específicas (empalme, shock 2020, protocolo, supuestos)
doc/auditorias/                        revisiones independientes del repositorio (sin autoridad decisoria)
doc/bitacora_verificaciones.md         registro de corridas del verificador de fuente_celda
doc/bitacora_fuentes_fragiles.md       fragilidad de cada fuente y procedimiento de recuperación
doc/captura_bcr_livewire_hallazgo.md   hallazgo técnico de captura headless del portal del BCR (2026-08-24)
catalogos/                             las 9 tablas de metadatos del sistema, esquema en datapackage.json
data/L0_raw … L4/                      capas de datos unidireccionales — ver CLAUDE.md antes de tocar cualquiera
src/                                   código del pipeline, organizado por capa
src/adquisicion/README.md              diseño de los scripts de captura de L0
tests/                                 pruebas del pipeline
scripts/                               utilidades de configuración (bootstrap de entorno, etc.)
```

## Empezar

`renv.lock` ya existe y está fijado (187 paquetes). El bloque `Imports:` de `DESCRIPTION` es la lista de imports declarados y la fuente de su conteo — no se transcribe acá, mismo criterio que los conteos de catálogo de la sección Estado; ver también la nota de conteo en `CLAUDE.md`. Primer paso en una máquina con R:

```r
renv::restore()
```

Eso reproduce el entorno exacto en cualquier máquina limpia — confirmado en CI sobre `ubuntu-latest`. `scripts/bootstrap_renv.R` documenta cómo se generó el lockfile (`renv::snapshot()` a partir de `DESCRIPTION`) por si hace falta regenerarlo tras cambiar el stack de ADR-009.

## Licencia

Código bajo MIT (`LICENSE`). Documentación bajo CC-BY-4.0 (`LICENSE-docs`). Ver ADR-008 para la política de datos no redistribuibles.
