# Bitácora de verificaciones — `verificar_fuente_celda.R`

Registro de corridas del verificador de trazabilidad (`src/validacion/verificar_fuente_celda.R`)
contra `catalogos/03_series.csv` y los `.xlsx` de `data/L0_raw/`. Solo puede ejecutarse en la
máquina de Harold (los `.xlsx` están en `.gitignore`, ver ADR-008); una corrida en cualquier otro
entorno reporta todas las filas como `NO_VERIFICABLE`, no como `FAIL`.

Cada entrada corresponde a una corrida real, no a una intención de correrla.

---

## Plantilla de entrada

```
## AAAA-MM-DD — commit del catálogo: <hash corto>

- Archivos .xlsx verificados (checksum SHA-256 contra manifiesto.csv):
  - <archivo 1>: <sha256>
  - <archivo 2>: <sha256>
  - <archivo 3>: <sha256>
  - <archivo 4>: <sha256>
- Resultado: <N> PASS / <N> FAIL / <N> NO_VERIFICABLE (de 98 filas)
- FAIL (si hay): <serie_id> — <descripción del desajuste> — <corregido en commit XXXXX / pendiente>
- Notas:
```

---

## Corridas

## 2026-08-17 — commit del catálogo: f7bae34

- Archivos .xlsx verificados (checksum SHA-256 contra manifiesto.csv):
  - `BCR_pib_t_indices_volumen_nsa_2026-08-06.xlsx`: `418ed74c1d4b3a402f3d9caaf3014fb6fae2d637527215b7846652ffa03f4a2c`
  - `BCR_pib_t_indices_volumen_sa_2026-08-06.xlsx`: `0405d5874d99a394880b2cac7f4aa42f4cd420a24dea4852e0cc31f283925d82`
  - `BCR_pib_t_retropolado_1990_2005_2026-08-06.xlsx`: `df9f21b5b0f627fe60957c2e117f83473ed634ff4c083bab040bf25be8dbccbe`
  - `BCR_pib_t_nominal_2026-08-15.xlsx`: `9b7416015adec575c5cc8d8bdd3beec932ee50061f038a46f5282e1bc272cf65`
- Resultado: **98 PASS / 0 FAIL / 0 NO_VERIFICABLE** (de 98 filas)
- FAIL: ninguno.
- Notas: corrida ejecutada por Harold contra el script tal como está commiteado (sin
  modificaciones), en su máquina, con los 4 archivos de `data/L0_raw/` presentes localmente.
  Cobertura completa: las 98 filas de `03_series.csv` en este commit se reparten exactamente
  entre las 4 publicaciones con archivo local (`BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA`: 28,
  `BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_SA`: 28, `BCR.PIB_T.SERIE_RETROPOLADA_1990_2005`: 13,
  `BCR.PIB_T.NOMINAL`: 29), por eso 0 NO_VERIFICABLE — no hay ninguna fila del catálogo, en este
  estado del proyecto, que apunte a una publicación sin archivo local todavía. Esto cambiará en
  cuanto se registren series de otras publicaciones sin `.xlsx` descargado.
