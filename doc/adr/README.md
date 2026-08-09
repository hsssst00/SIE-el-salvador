# Registro de decisiones de arquitectura (ADR)

Proyecto: Sistema de Información Estadística y modelos de proyección del PIB trimestral de El Salvador

Cada decisión fundacional (D1–D8, senda metodológica §2) se registra como un ADR independiente, más D9 (stack tecnológico), adición propia del proyecto no enumerada en §2 — ver ADR-009. Formato: contexto, alternativas consideradas, decisión, consecuencias. Un ADR se enmienda, no se reescribe, cuando una decisión posterior lo afecta.

| ADR | Decisión | Estado |
|---|---|---|
| [001](./ADR-001-variable-objetivo.md) | Definición operativa de la variable objetivo | Cerrado |
| [002](./ADR-002-horizonte-y-diseno.md) | Horizonte y diseño de los dos ejercicios | Cerrado |
| [003](./ADR-003-empalme-cuentas-nacionales.md) | Tratamiento del empalme de cuentas nacionales | Cerrado |
| [004](./ADR-004-shock-2020.md) | Tratamiento de quiebres estructurales y shock de 2020 | Cerrado |
| [005](./ADR-005-soporte-catalogos.md) | Soporte tecnológico de los catálogos | Cerrado |
| [006](./ADR-006-vocabulario-metadatos.md) | Vocabulario de metadatos | Cerrado |
| [007](./ADR-007-politica-vintages.md) | Política de versiones de publicación (vintages) | Cerrado |
| [008](./ADR-008-licencias.md) | Licencias y condiciones de redistribución | Parcial — pendiente condiciones por fuente (Fase 1) |
| [009](./ADR-009-stack-tecnologico.md) | Stack tecnológico | Cerrado |

**Estado general:** ocho de nueve ADR cerrados. Solo ADR-008 queda parcial, y únicamente en la parte que depende del relevamiento de condiciones de uso de fuentes distintas al BCR (DIGESTYC/ONEC, ISSS, organismos internacionales) — tarea de Fase 1, no bloquea el cierre de Fase 0.

## Cierre de Fase 0 (2026-08-07)

Confirmado en CI (GitHub Actions, ubuntu-latest):
https://github.com/hsssst00/SIE-el-salvador/actions/runs/31143916968 —
Status: Success (57s). Un tercero (el runner de GitHub, sin intervención
del autor) clona el repositorio y reproduce el entorno: `renv::restore()`,
validación de catálogos y la batería de pruebas corren en verde sobre Linux.

**Criterio de cierre de Fase 0 (senda metodológica §4): SATISFECHO.**

Limitación conocida, no bloqueante: en Windows local, `make test` produce
un segfault de proceso al cierre de sesión, no relacionado con el código
del proyecto — ver doc/entorno_windows.md. No afecta la señal de CI.

**Alcance exacto de este cierre, para no confundirlo con el revalidado más
abajo:** el tag `v0.1.0-fase0` (commit `1739fc8`) certifica un estado
*pre-enmienda de ADR-001* — la variable objetivo primaria era entonces la
serie oficial SA del BCR, antes de que la enmienda del 2026-08-07 la
invirtiera con la serie oficial NSA (ver ADR-001, ADR-004) — y un entorno
*pre-C6*: `renv.lock` todavía no fijaba realmente los 13 paquetes de
ADR-009 (eso se cerró en el commit `cd3e36a`, 2026-08-08). El run
31143916968 es válido para lo que certificaba en su momento; no es
evidencia de que el entorno o la enmienda actuales estén verificados.

## Cierre de Fase 0 — revalidado (2026-08-08)

Con la enmienda de ADR-001/ADR-004 cerrada, `renv.lock` fijando los 13
paquetes reales de ADR-009 (commit `cd3e36a`) y la remediación de Fase 0
aplicada (ver reparto de tareas: Bloque 1 completo, Bloque 2 y menores de
Bloque 3 resueltos), se revalida el cierre sobre el estado actual del
repositorio.

Confirmado en CI (GitHub Actions, ubuntu-latest):
https://github.com/hsssst00/SIE-el-salvador/actions/runs/31240588025 —
commit `8ab59c3`, Status: Success (1m18s). Mismo criterio que el cierre
original: `renv::restore()`, validación de catálogos (incluida la
extensión de esquema de `04_transformaciones` y el catálogo `09_rupturas`
recién poblado) y la batería de pruebas corren en verde sobre Linux.

**Criterio de cierre de Fase 0 (senda metodológica §4): SATISFECHO, sobre
el estado enmendado y con el entorno real fijado.**

Tag: `v0.2.0-fase0-enmendado`.

### Corrección de alcance del tag (2026-08-08)

El tag `v0.2.0-fase0-enmendado` apunta al commit `58e6efce`. El commit
`df02e43a` (actualización del encabezado de `doc/senda_metodologica.md`
a v0.2, con bloque de historial de versiones) quedó fuera de ese tag —
es posterior a él. Consecuencia: el snapshot certificado por
`v0.2.0-fase0-enmendado` contiene §3.4 de la senda metodológica con la
documentación del sufijo `.RETRO` (hallazgo M1), pero el encabezado del
mismo documento todavía se rotula como "Versión: 0.1 — documento de
trabajo", sin bloque de historial. Es la misma forma del hallazgo C2 de
la auditoría de Fase 0: el tag certifica un estado anterior al estado
real.

`v0.2.1-fase0-enmendado` es el tag que certifica el estado completo y
consistente (contenido de §3.4 y encabezado alineados) y es el que debe
usarse para reproducir "Fase 0 tal como quedó cerrada". `v0.2.0-fase0-enmendado`
se conserva sin modificar, por disciplina de trazabilidad — no se mueve,
borra ni recrea.

*(Pendiente de completar con el run de CI y el commit exacto que certifica
`v0.2.1-fase0-enmendado`.)*
