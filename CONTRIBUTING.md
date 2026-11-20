# Convenciones de contribución

Este es actualmente un proyecto de un solo investigador con asistencia de agentes de código (Claude Code). Estas convenciones existen para mantener la trazabilidad exigida por el propio sistema, no por tamaño de equipo.

## Antes de escribir código

1. Verifica si la decisión que estás por tomar ya está cubierta por un ADR en `doc/adr/`.
2. Si no lo está y es una decisión metodológica (no una elección de implementación trivial), regístrala como ADR nuevo antes de escribir el código que depende de ella.
3. Lee `CLAUDE.md` — contiene las reglas no negociables del pipeline.

## Flujo de trabajo

- Todo cambio entra por PR contra `main`, desde una rama propia y sin apilar PR (decisión F7-12, 2026-11-20). Es el flujo que se usa desde Fase 4 y el que sigue cualquier tercero. Hasta Fase 3 se usaron commits directos a `main`.
- Un PR que reabre una decisión ya cerrada en un ADR documenta el motivo de la reapertura en su descripción antes de enmendar el ADR correspondiente.
- CI debe pasar en verde sobre la cabeza del PR antes de fusionar.
- Ningún dato en `data/L1`–`L4` se edita a mano; si el resultado está mal, se corrige el código que lo genera.
- Sujeto del commit ≤ ~72 caracteres, resumiendo el qué; el detalle (por qué, alcance, hallazgos) va al cuerpo del mensaje, sin límite de largo. Aplica hacia adelante — no se reescribe historia existente para cumplirlo (M4, auditoría de Fase 1, 2026-08-17).

## Estilo

- R: `snake_case`, siguiendo las convenciones de `doc/adr/ADR-009-stack-tecnologico.md`.
- Identificadores de series y catálogos: ver senda metodológica §3.4.
