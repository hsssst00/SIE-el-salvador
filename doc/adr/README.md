# Registro de decisiones de arquitectura (ADR)

Proyecto: Sistema de Información Estadística y modelos de proyección del PIB trimestral de El Salvador

Cada decisión fundacional (D1–D9, senda metodológica §2) se registra como un ADR independiente. Formato: contexto, alternativas consideradas, decisión, consecuencias. Un ADR se enmienda, no se reescribe, cuando una decisión posterior lo afecta.

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
