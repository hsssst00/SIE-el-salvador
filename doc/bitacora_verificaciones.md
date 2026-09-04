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

## 2026-08-28 — commit del catálogo: el commit de remediación de la auditoría de Fase 2 (padre: `7858a21`)

- **Estado del árbol verificado:** el que introduce ese mismo commit — posterior a la corrección
  de `verificar_fuente_celda.R` (hallazgos B2/B3) y a la enmienda de registro de las dos filas
  de `BM.WDI.*` (hallazgo A4) y de la fecha `2026-08-29` en las notas de las cinco filas del FMI
  (hallazgo M5). La corrida se hizo sobre el árbol de trabajo, antes de commitear; el hash no
  puede ser autorreferencial, así que se identifica por su padre. Es el único commit de
  `main` cuyo mensaje empieza con "Remedia la auditoría de Fase 2".
- **Corrida:** `Rscript src/validacion/verificar_fuente_celda.R`, sin modificaciones sobre el
  script más allá de la corrección que esta misma remediación introduce, con los 42 archivos
  de `data/L0_raw/` presentes localmente.
- **Resultado: 98 PASS / 0 FAIL / 0 NO_VERIFICABLE / 1 FUERA_DE_ALCANCE** (de 99 filas).
  Código de salida 0.
- **FUERA_DE_ALCANCE (1):** `UT.DEMANDA_ELEC.GWH.NSA.M` — el vintage vigente de
  `UT.DEMANDA_TOTAL_MENSUAL` es `UT_demanda_total_2026_2026-08-26.csv`, no un `.xlsx`; este
  verificador resuelve hoja/fila/rótulo dentro de un `.xlsx`. Estado nuevo, introducido en
  esta misma corrección: antes esta fila daba `FAIL` (ver abajo). Su trazabilidad **no** la
  comprueba este script.
- **FAIL: ninguno.**

**Lo que esta entrada asienta, y que es el motivo de que exista.** Entre el commit `0fbda08`
(2026-08-26, alta de la fila de UT en `03_series.csv`) y esta corrida, este verificador
**fallaba en `main`** con `1 FAIL` y código de salida 1, por dos causas distintas: (a) exigía
que un `publicacion_id` tuviera una sola fila en el manifiesto, supuesto que el diseño
append-only de ADR-007 contradice, y (b) no tenía forma de expresar "esta fila no la puedo
verificar" para una serie derivada de CSV. No hubo entrada de bitácora en ese período —
correcto según la regla 8, que prohíbe asentar corridas que no ocurrieron— pero el efecto
práctico fue que el rojo pasó dos días inadvertido, porque el script no corre en CI (los
`.xlsx` están en `.gitignore`, ADR-008) y su única evidencia posible es esta bitácora.

**Verificación física de L0, en la misma sesión.** `Rscript scripts/verificar_l0_fisico.R`
(script nuevo, hallazgo B1): **42 PASS / 0 FAIL / 12 AUSENTE** de 54 filas del manifiesto.
Los 42 archivos presentes coinciden en `sha256` y en `tamano_bytes` con lo declarado —
integridad intacta. Los 12 ausentes son el lote BCR completo del 2026-08-26; no están en
`data/L0_raw/` ni en ninguna otra ruta de `D:\` o `C:\Users\harold`. Qué hacer con esas filas
es decisión de política de L0, pendiente de Harold; el script sale con código 1 mientras tanto,
que es lo correcto.

**Verificación en vivo contra las fuentes de API.** `Rscript scripts/verificar_l0.R api`:
**12/12 PASS** (5 FRED, 5 FMI, 2 BM) — `sha256_norm` recalculado coincide con el registrado.
La rama BCR (16 publicaciones vía navegador headless) **no se corrió** en esta sesión: son 16
renders completos de tabla y su ejecución es un acto deliberado del operador al ritmo de
publicación de la fuente (regla 9 de `CLAUDE.md`), no algo que un agente dispare por su cuenta.
Queda pendiente una corrida de `make raw` completa.

## 2026-08-30 — recaptura parcial de los 12 archivos perdidos (hallazgo B1), INTERRUMPIDA

Corrida de `Rscript scripts/restaurar_l0_perdido.R aplicar`, autorizada por Harold el
2026-08-28 (opción "recapturar y cotejar `sha256_norm`"). **El proceso se detuvo a mitad**, en
la sexta de doce publicaciones. Se asienta igual porque produjo evidencia real, y porque un
resultado parcial que no se registra es indistinguible de no haber corrido.

- **Cotejadas antes de la interrupción: 5 de 12, las 5 con `sha256_norm` IDÉNTICO al registrado**
  — `BCR.IPI.VIGENTE`, `BCR.IPP`, `BCR.ISI`, `BCR.ITCER`, `BCR.PANORAMA_BANCO_CENTRAL`. Es decir:
  el portal sigue sirviendo exactamente el mismo dato que se archivó el 2026-08-26, y esos cinco
  vintages son restaurables. Interrumpida durante `BCR.BALANZA_COMERCIAL` (captura completada,
  cotejo no alcanzado).
- **No se escribió NADA:** ni un archivo en `data/L0_raw/` ni una fila de catálogo. El script
  acumula las escrituras y las aplica juntas al final, precisamente para que una interrupción no
  deje el catálogo a medio reescribir. Verificado después: 0 archivos del lote `2026-08-26` en
  `data/L0_raw/`, y el diff de `manifiesto.csv` / `08_vintages.csv` sigue conteniendo solo las
  correcciones A4 y M5.
- **Estado:** los 12 siguen ausentes. `scripts/verificar_l0_fisico.R` sigue en 42 PASS / 12
  AUSENTE, salida 1 — correcto.
- **Pendiente:** volver a correr el script completo. Es idempotente respecto de lo ya hecho:
  recalcula la lista de ausentes al arrancar, así que una corrida nueva reintenta las 12 (o las
  que queden) sin necesitar limpieza previa.

## 2026-08-30 (segunda sesión) — restauración de L0 completada: 6 de 12 recuperados

Corrida completa de `scripts/restaurar_l0_perdido.R aplicar`, en cuatro tandas acotadas (se
agregó el argumento de tanda y `--omitir=` precisamente después de que la corrida única del
turno anterior muriera a mitad y perdiera su trabajo).

**Resultado definitivo: 6 restaurados, 6 IRRECUPERABLES.**

| Publicación | `sha256_norm` | Resultado |
|---|---|---|
| `BCR.IPI.VIGENTE` | idéntico | restaurado |
| `BCR.IPP` | idéntico | restaurado |
| `BCR.ISI` | idéntico | restaurado |
| `BCR.PANORAMA_BANCO_CENTRAL` | idéntico | restaurado |
| `BCR.RESERVAS_INTERNACIONALES_NETAS` | idéntico | restaurado |
| `BCR.BALANZA_PAGOS_TRIMESTRAL` | idéntico | restaurado |
| `BCR.ITCER` | distinto | **irrecuperable** — el portal pasó de 318 períodos (hasta 2026-M06) a 319 (hasta 2026-M07) |
| `BCR.BALANZA_COMERCIAL` | distinto | **irrecuperable** |
| `BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR` | distinto | **irrecuperable** — mismo período final (2026-M06) y contenido distinto: es una **revisión**, no una extensión |
| `BCR.GOBIERNO_CENTRAL_CONSOLIDADO` | distinto | **irrecuperable** |
| `BCR.PANORAMA_SOCIEDADES_DEPOSITO` | distinto | **irrecuperable** |
| `BCR.SPNF_VIGENTE` | distinto | **irrecuperable** |

**Un dato que la propia corrida produjo y que conviene no perder.** `BCR.ITCER` fue cotejado
**dos veces el mismo día**: en la corrida interrumpida de la mañana dio `sha256_norm` idéntico
(318 períodos, hasta 2026-M06) y en la de la tarde ya no (319 períodos, hasta 2026-M07). El BCR
publicó el mes nuevo entre ambas. Es decir: la ventana de recuperación se cerró **durante** la
propia remediación. Esto no es anecdótico — es la demostración empírica de la premisa de
ADR-007: *"cada publicación del BCR no archivada desde hoy es información irrecuperable"*.

De los 6 irrecuperables, `INDICES_PRECIOS_COMERCIO_EXTERIOR` es el caso más caro: su período de
referencia no avanzó, así que lo que cambió fue el dato ya publicado. Se perdió el vintage
anterior de una revisión, que es exactamente el objeto de estudio que el eje bitemporal existe
para medir.

**Estado tras la restauración:**

- `scripts/verificar_l0_fisico.R`: **48 PASS / 0 FAIL / 6 AUSENTE**, salida 1 (era 42/0/12).
- `scripts/check_l0_integrity.R`: salida 0.
- `src/validacion/verificar_fuente_celda.R`: 98 PASS / 0 FAIL / 1 FUERA_DE_ALCANCE, salida 0.
- `testthat`: 58 PASS, 0 FAIL.

De cada fila restaurada cambiaron `sha256` y, en un caso, `tamano_bytes`; `sha256_norm`,
`vintage_id`, `fecha_publicacion`, `periodo_referencia_max` y `fecha_descarga` quedaron intactos.
El motivo está anotado en `notas` de cada fila, con el valor histórico del `sha256`.

**Pendiente, y es decisión de Harold (regla 4):** qué se hace con las 6 filas irrecuperables.
Mientras no se resuelva, `verificar_l0_fisico.R` sale con código 1 — correctamente.

### Corrección de alcance (2026-09-04)

La entrada anterior rotula seis publicaciones como **IRRECUPERABLES**. El rótulo es correcto
respecto de lo que se probó —el portal del BCR ya no sirve ese contenido— e **incorrecto si se
lee como "el archivo se perdió para siempre"**. Harold reportó que conserva copias de archivos
de L0 en otra máquina, sin acceso en el momento de esta corrida. La vía de recuperación no está
agotada.

Léase entonces: **"no recuperable desde el portal"**. Las seis filas quedan en espera de esa
comprobación, no marcadas como pérdida.

**Cómo comprobarlo cuando esa máquina esté disponible.** Calcular el `sha256` de cada archivo
candidato y compararlo contra el valor **histórico** de su fila:

- Para las seis **no restauradas**, el valor histórico es el que sigue hoy en la columna
  `sha256` del manifiesto: no se tocó.
- Para las seis **restauradas**, el valor histórico está en `notas` de su fila de
  `08_vintages.csv`, porque la restauración reemplazó el de la columna por el del archivo
  recapturado.

Si aparece un original, lo correcto es reponerlo y devolver su `sha256` histórico desde la nota.
Un archivo original vale más que uno recapturado aunque `sha256_norm` pruebe que el contenido es
el mismo: es el artefacto que efectivamente se archivó, y es el único que hace verdadera la
columna de integridad tal como se escribió el día de la captura.
