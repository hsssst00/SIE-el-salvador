# Calendario de `make raw` completo

Fija cuándo correr, a mano y en local, la verificación completa de L0 (`make raw`, que
encadena `verificar_l0_fisico.R` y `verificar_l0.R` sin alcance parcial). Este archivo solo
agenda: el procedimiento de cada ventana vive en `doc/backlog_captura_vintages.md`
(secciones «Ventana mensual» y «Ventana trimestral de UT»), y rige la regla 9 de `CLAUDE.md`:
una sola pasada por ventana, nunca repetida.

**Por qué es local.** El workflow `Aviso de captura (BCR y demás)` falló en su única corrida
(2026-10-01, 23 ERROR: FRED sin `FRED_API_KEY` en el runner, BCR sin causa confirmada). Hasta
que se resuelva, no se confía en él como único aviso: el calendario de abajo es el recordatorio
que sí cuenta.

## Regla

- **Mensual:** días 1 a 3 de cada mes, `make raw` completo.
- **Trimestral (UT, además de la mensual):** enero, abril, julio y octubre.
- Cada corrida se anota en `doc/bitacora_verificaciones.md` si usa el verificador de celda
  (regla 8), y los `CAMBIO` se registran en `doc/backlog_captura_vintages.md`.

## Precheck rápido: `make raw-rapido`

Antes de la pasada completa, `make raw-rapido` mira solo el portal del BCR, en dos niveles:
(1) calendario, sin red (`make raw-calendario` corre solo esto): `TOCA` / `NO_TOCA` /
`SIN_CALENDARIO` según las fechas anunciadas; (2) sondeo del último período que sirve la fuente,
solo para `TOCA` y `SIN_CALENDARIO`, sin renderizar tablas. **No ve revisiones de valores de
períodos viejos** (p. ej. una revisión del PIB-T con el mismo último trimestre): eso solo lo
detecta `make raw` completo, que sigue siendo lo que cierra cada ventana. Una pasada por ventana
(regla 9). Lógica en `src/adquisicion/verificacion_rapida.R`.

## Próximas ventanas

| Ventana | Fechas | Alcance |
|---|---|---|
| 2026-10 | 1–3 oct | **Parcial.** Hecho el 2026-10-01: 9 series BCR. Falta la captura trimestral de UT (octubre), lo que `make raw-rapido` marque como `NUEVO_PERIODO` (hoy el nivel 1 señala `BALANZA_PAGOS_TRIMESTRAL`, `IPI.VIGENTE` e `ITCER`, además de PIB-T NSA/NOMINAL sin calendario) y la pasada completa de `make raw` |
| 2026-11 | 1–3 nov | `make raw` completo |
| 2026-12 | 1–3 dic | `make raw` completo |
| 2027-01 | 1–3 ene | `make raw` completo + captura trimestral UT |
| 2027-02 | 1–3 feb | `make raw` completo |
| 2027-03 | 1–3 mar | `make raw` completo |
| 2027-04 | 1–3 abr | `make raw` completo + captura trimestral UT |
| 2027-05 | 1–3 may | `make raw` completo |
| 2027-06 | 1–3 jun | `make raw` completo |
| 2027-07 | 1–3 jul | `make raw` completo + captura trimestral UT |
| 2027-08 | 1–3 ago | `make raw` completo |
| 2027-09 | 1–3 sep | `make raw` completo |
| 2027-10 | 1–3 oct | `make raw` completo + captura trimestral UT |

Última ventana cumplida: 2026-10-01 (captura de 9 series BCR, commit `1c08c66`).
Al cerrar cada ventana, mover esta línea a la fecha real de la corrida.
