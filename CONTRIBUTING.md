# Convenciones de contribución

Este es actualmente un proyecto de un solo investigador con asistencia de agentes de código (Claude Code). Estas convenciones existen para mantener la trazabilidad exigida por el propio sistema, no por tamaño de equipo.

## Antes de escribir código

1. Verifica si la decisión que estás por tomar ya está cubierta por un ADR en `doc/adr/`.
2. Si no lo está y es una decisión metodológica (no una elección de implementación trivial), regístrala como ADR nuevo antes de escribir el código que depende de ella.
3. Lee `CLAUDE.md` — contiene las reglas no negociables del pipeline.

## Flujo de trabajo

- Commits directos a `main`, siempre que CI pase en verde — es el flujo real usado en este proyecto de un solo investigador; no hay revisión por pares que una rama/PR pudiera sustituir.
- PR contra `main` reservado para un caso específico: reabrir una decisión ya cerrada en un ADR. La discusión del PR documenta el motivo de la reapertura antes de enmendar el ADR correspondiente.
- CI debe pasar en verde antes de integrar, en ambos casos.
- Ningún dato en `data/L1`–`L4` se edita a mano; si el resultado está mal, se corrige el código que lo genera.
- Sujeto del commit ≤ ~72 caracteres, resumiendo el qué; el detalle (por qué, alcance, hallazgos) va al cuerpo del mensaje, sin límite de largo. Aplica hacia adelante — no se reescribe historia existente para cumplirlo (M4, auditoría de Fase 1, 2026-08-17).

## Estilo

- R: `snake_case`, siguiendo las convenciones de `doc/adr/ADR-009-stack-tecnologico.md`.
- Identificadores de series y catálogos: ver senda metodológica §3.4.
