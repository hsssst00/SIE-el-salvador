# Backlog de captura de vintages

Registro operativo de la **captura prospectiva** que ADR-007 declara compromiso firme. Cada vez
que `scripts/verificar_l0.R` (el monitor en vivo, `make raw` / `make raw-api`) reporta un
`CAMBIO` o un `ERROR`, se asienta acá: qué publicación, cuándo se detectó, y qué se hizo.

**No es un entregable de Fase 2 que se cierre.** Es un registro permanente: sigue vivo en
Fase 3 y más allá, al ritmo real de publicación de cada fuente.

## Reglas

- Un `CAMBIO` significa que la fuente publicó un vintage nuevo. **No es un defecto de L0** — el
  archivo archivado sigue siendo el vintage que era (ver ADR-007, nota del 2026-09-09). Desde el
  2026-09-09 `verificar_l0.R` no aborta ante un `CAMBIO`: lo reporta y `make raw` sale 0. Solo un
  `ERROR` hace fallar `make raw`.
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

15 `CAMBIO` detectados en la corrida completa de `make raw` que certificó el cierre de Fase 2
(máquina de Harold, L0 completa, 2026-09-09; salida en `doc/evidencia_cierre_fase2.txt`).
Captura original entre el 2026-08-25 y el 2026-08-28. Todas son series de **frecuencia
mensual** con un mes nuevo publicado en las ~2 semanas transcurridas — cero sorpresas (ver
nota de grupo abajo). El set coincide exactamente con el de la corrida previa del mismo día.

| Publicación | Detectado | Estado | Acción | Capturado |
|---|---|---|---|---|
| `BCR.BALANZA_COMERCIAL` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `BCR.GOBIERNO_CENTRAL_CONSOLIDADO` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `BCR.ISI` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `BCR.ITCER` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `BCR.IVAE.VIGENTE` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `BCR.PANORAMA_BANCO_CENTRAL` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `BCR.PANORAMA_SOCIEDADES_DEPOSITO` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `BCR.RESERVAS_INTERNACIONALES_NETAS` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `BCR.SPNF_VIGENTE` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `FRED.PAYEMS` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `FRED.UNRATE` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `FMI.PCPS.PALLFNF` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `FMI.PCPS.PFOOD` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |
| `FMI.PCPS.POILAPSP` | 2026-09-09 | `CAMBIO` | Pendiente de captura | — |

El valor definitivo del vintage nuevo lo escribe `registrar_descarga()` en `manifiesto.csv` /
`08_vintages.csv` al capturarlo. `sha256_norm` **registrado → observado el 2026-09-09**
(prefijos; el detalle completo está en `doc/evidencia_cierre_fase2.txt`):

- `BCR.BALANZA_COMERCIAL`                `47d26c43…` → `94cb9e0e…`
- `BCR.GOBIERNO_CENTRAL_CONSOLIDADO`     `90269076…` → `8ac40917…`
- `BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR` `012a9fcc…` → `0b697ddc…`
- `BCR.ISI`                              `8a98a0fa…` → `65386e49…`
- `BCR.ITCER`                            `34ce75cf…` → `5569f982…`
- `BCR.IVAE.VIGENTE`                     `72a6766f…` → `94159781…`
- `BCR.PANORAMA_BANCO_CENTRAL`           `4582fc9a…` → `19013c44…`
- `BCR.PANORAMA_SOCIEDADES_DEPOSITO`     `97b8daa0…` → `abd5f270…`
- `BCR.RESERVAS_INTERNACIONALES_NETAS`   `078ecdcd…` → `76502a0c…`
- `BCR.SPNF_VIGENTE`                     `925d2ecf…` → `5d713308…`
- `FRED.PAYEMS`                          `68dea9ce…` → `9d759f6b…`
- `FRED.UNRATE`                          `3c730395…` → `5de16554…`
- `FMI.PCPS.PALLFNF`                     `6d64a2cf…` → `f38ef529…`
- `FMI.PCPS.PFOOD`                       `0a5e5018…` → `cb0472cf…`
- `FMI.PCPS.POILAPSP`                    `a87c6118…` → `04d0f81b…`

### Notas por grupo

**Las 15, en conjunto (2026-09-09).** Todas mensuales; el corte de captura fue 25–28 de agosto y
la corrida de verificación 9 de septiembre, con un mes de publicación de por medio. Lo que **no**
cambió lo confirma: `BCR.PIB_T.*` (NSA/SA/NOMINAL) y `BCR.BALANZA_PAGOS_TRIMESTRAL` son
trimestrales sin trimestre nuevo; `BCR.IPI.VIGENTE`, `BCR.IPP`, `FRED.INDPRO`, `FRED.CPIAUCSL`,
`FRED.BEA_PIB_EEUU`, `BM.WDI.*`, `FMI.BOP`, `FMI.QNEA` son o trimestrales o mensuales cuya
próxima publicación aún no salió. Ninguna serie tiene fila en `03_series.csv` todavía (son de
las 25 publicaciones capturadas sin catalogar, hallazgo L6 de la auditoría de Fase 2), así que
ningún `CAMBIO` de esta tanda toca una variable ya admitida al proyecto.

**Ritmo de captura.** No hay urgencia de capturarlas todas de una: el BCR es la única fuente
donde un vintage no capturado es irrecuperable (ADR-007), y aun ahí la política es capturar al
ritmo de publicación, no en respuesta inmediata a cada `CAMBIO`. FRED y FMI son recuperables a
demanda. Se capturan cuando se catalogue una serie suya (Fase 3) o en la próxima ventana de
captura prospectiva, lo que ocurra primero.
