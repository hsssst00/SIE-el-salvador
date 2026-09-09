# Backlog de captura de vintages

Registro operativo de la **captura prospectiva** que ADR-007 declara compromiso firme. Cada vez
que `scripts/verificar_l0.R` (el monitor en vivo, `make raw` / `make raw-api`) reporta un
`CAMBIO` o un `ERROR`, se asienta acá: qué publicación, cuándo se detectó, y qué se hizo.

**No es un entregable de Fase 2 que se cierre.** Es un registro permanente: sigue vivo en
Fase 3 y más allá, al ritmo real de publicación de cada fuente.

## Reglas

- Un `CAMBIO` significa que la fuente publicó un vintage nuevo. **No es un defecto de L0** — el
  archivo archivado sigue siendo el vintage que era (ver ADR-007, nota del 2026-09-09).
- Capturar una entrada pendiente es un acto deliberado vía `descargar_*()` de
  `src/adquisicion/`, al ritmo de publicación de la fuente (trimestral para el PIB, mensual
  para la mayoría del BCR y los índices de precios de commodities del FMI, etc.). **Nunca en
  bucle** (regla 9 de `CLAUDE.md`).
- Que una entrada quede pendiente un tiempo no bloquea ninguna fase. Lo que bloquearía sería
  capturar de forma exhaustiva o repetida.
- Al capturar, `registrar_descarga()` escribe la fila nueva en `manifiesto.csv` y
  `08_vintages.csv` con su propia `fecha_descarga`; se marca acá la entrada como capturada con
  el `vintage_id` resultante.
- Un `ERROR` no es un `CAMBIO`: la fuente no respondió o respondió algo inesperado. Se examina
  antes de concluir nada (¿fuente caída?, ¿falta credencial?, ¿cambió la estructura? — esto
  último es hallazgo de `doc/bitacora_fuentes_fragiles.md`, no de este backlog).

## Entradas

| Publicación | Detectado | Estado del monitor | `sha256_norm` registrado → observado | Acción | Capturado |
|---|---|---|---|---|---|
| `FMI.PCPS.PALLFNF` | 2026-09-09 | `CAMBIO` | `6d64a2cf…2724128f` → `f38ef529…3b02628b` | Pendiente de captura | — |
| `FMI.PCPS.PFOOD` | 2026-09-09 | `CAMBIO` | `0a5e5018…f8ac2ce9` → `cb0472cf…923cc536` | Pendiente de captura | — |
| `FMI.PCPS.POILAPSP` | 2026-09-09 | `CAMBIO` | `a87c6118…b29702f3` → `04d0f81b…ca03b7cc2` | Pendiente de captura | — |

### Notas por entrada

**`FMI.PCPS.*` — 3 series de precios de commodities (2026-09-09).** Detectadas en una corrida de
`make raw-api` el 2026-09-09; captura original 2026-08-28. Las tres son índices de precios de
actualización mensual (`PALLFNF` = todos los productos primarios sin combustibles, `PFOOD` =
alimentos, `POILAPSP` = petróleo, promedio spot). Un vintage nuevo mensual es el comportamiento
esperado de la fuente. `FMI.BOP` y `FMI.QNEA`, capturadas el mismo día, siguieron en `PASS`.
Pendiente: confirmar en la corrida completa de `make raw` (máquina con L0 completa) y capturar
el vintage de septiembre de las tres.

**FRED — `ERROR` en la corrida del 2026-09-09, no concluyente.** Las 5 publicaciones de FRED
dieron `ERROR` ("`FRED_API_KEY` no está definida") porque la máquina donde se corrió no tiene
`.Renviron` configurado. No es un `ERROR` de la fuente: es un artefacto del entorno. Se
re-verifica en la corrida completa de `make raw` sobre la máquina con la clave configurada.
