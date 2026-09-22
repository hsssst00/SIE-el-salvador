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

## 2026-09-07 — cierre de B1: los 12 originales aparecieron, se revierte la restauración parcial

Verificado en la máquina de Harold que faltaba consultar (la reportada el 2026-09-04, sin
acceso en ese momento). Los **12 archivos del lote del 2026-08-26 están ahí**, con sus fechas
de modificación originales (09:56–10:45 del 26-ago) y **coinciden en `sha256` y `tamano_bytes`,
byte a byte, con el manifiesto anterior a toda la remediación** (commit `7858a21`). Ninguno se
había perdido.

**Consecuencia para las 6 filas que la restauración del 2026-08-30 había "recuperado" por
recaptura** (`IPI.VIGENTE`, `IPP`, `ISI`, `PANORAMA_BANCO_CENTRAL`,
`RESERVAS_INTERNACIONALES_NETAS`, `BALANZA_PAGOS_TRIMESTRAL`): esa restauración fue innecesaria
y dejó el manifiesto declarando el `sha256` de un archivo recapturado en vez del original, que
nunca había desaparecido. Se revirtió: `sha256` vuelve al valor original en las 6 filas de
`manifiesto.csv` y `08_vintages.csv` (ya estaba anotado en `notas` desde la restauración, así
que la reversión es exacta, no una suposición), y el archivo original reemplaza al recapturado
en `data/L0_raw/`. `tamano_bytes` no requirió cambio: ya coincidía. Las notas de cada fila NO se
borraron — se les agregó la corrección al final, con el `sha256` original citado.

**Las otras 6 filas** (`ITCER`, `BALANZA_COMERCIAL`, `INDICES_PRECIOS_COMERCIO_EXTERIOR`,
`GOBIERNO_CENTRAL_CONSOLIDADO`, `PANORAMA_SOCIEDADES_DEPOSITO`, `SPNF_VIGENTE`) nunca se habían
tocado — seguían con su `sha256` histórico intacto — y coinciden sin cambios.

**Estado final: `scripts/verificar_l0_fisico.R` en esta máquina — 12 PASS / 0 FAIL** sobre las
12 filas del lote BCR (el resto de las 42 AUSENTE son archivos de otras fuentes que esta
máquina nunca tuvo localmente, no una regresión). `check_l0_integrity.R`: OK, 54 vintages
consistentes. **B1 queda cerrado**: los 12 archivos de L0 del lote del 2026-08-26 están
íntegros y coinciden con lo registrado.

## 2026-09-16 — alta de BCR.IVAE.VOL.SA.M y corrección de un falso positivo en el propio verificador

- **Estado del árbol verificado:** el commit que agrega la fila `BCR.IVAE.VOL.SA.M` a
  `03_series.csv` (primer predictor de la matriz, senda §6.4) y corrige
  `src/validacion/verificar_fuente_celda.R` (padre: `4126457`). El hash no puede ser
  autorreferencial — mismo patrón que la entrada del 2026-08-28.
- **Primera corrida** (`Rscript src/validacion/verificar_fuente_celda.R`, script tal como
  estaba antes de esta sesión, con los archivos de `data/L0_raw/` presentes localmente):
  **86 PASS / 13 FAIL / 0 NO_VERIFICABLE / 1 FUERA_DE_ALCANCE** (de 100 filas). Las 13 FAIL son
  exactamente las 13 filas `*.RETRO` (hojas `T1`/`T2` de
  `BCR_pib_t_retropolado_1990_2005_2026-08-06.xlsx`): `BCR.PIB.VOL.NSA.Q.RETRO`,
  `BCR.CONSUMO_FINAL/PRIV/PUB.VOL.NSA.Q.RETRO`, `BCR.FBKF.VOL.NSA.Q.RETRO`,
  `BCR.EXPORT/IMPORT.VOL.NSA.Q.RETRO` y sus equivalentes `NOM`. `BCR.IVAE.VOL.SA.M` (la fila
  nueva) dio **PASS** en esta misma corrida.
- **Diagnóstico, no asumido: se verificó celda por celda contra el XML crudo del `.xlsx` y
  contra `readxl::read_excel()` en paralelo (ver script de diagnóstico, no versionado).** Las
  hojas `T1`/`T2` de ese archivo tienen una fila 1 física sin ninguna celda hija
  (`<row r="1"/>` vacía, confirmado). `readxl` omite esa fila vacía de su salida y recorre el
  resto de las filas una posición hacia arriba; el XML crudo sigue contando esa fila vacía como
  la fila 1. Resultado: para esas dos hojas, "fila N" vale una cosa distinta según se lea con
  `readxl` (lo que hace `src/transformacion/extraer_bcr_pib.R`, el extractor real) o contra el
  atributo `@r` del XML crudo (lo que hacía la versión anterior de este verificador). Las demás
  hojas (`worksheet`, usada por las tres publicaciones NSA/SA/NOMINAL) no tienen esa fila vacía
  inicial, por eso sus 86 filas ya daban PASS bajo cualquiera de las dos convenciones.
- **No es un defecto de dato.** `fila_dato` de las 13 filas `*.RETRO` ya apunta a la fila
  correcta bajo la convención de `readxl` — la misma que usa el extractor — y los valores que
  `extraer_bcr_pib.R` produce con esos `fila_dato` coinciden con la serie nativa del BCR dentro
  de la tolerancia ya documentada en `doc/metodologia/empalme_cuentas_nacionales.md` (máx.
  0.0078 sobre índices ~80, atribuible a redondeo de publicación, no a fila equivocada). El FAIL
  era del verificador, no de `03_series.csv`.
- **Es, con alta probabilidad, la causa real de las dos "correcciones" previas de estas mismas
  filas** (commit `c60e808`, 2026-08-13, y la re-corrección del 2026-09-15 documentada en las
  notas de `03_series.csv`): ambas rondas describen desplazamientos de una fila en `T1`/`T2` sin
  identificar por qué el conteo parecía moverse. Esta sesión no reabre esas correcciones —
  `fila_dato` no cambió — pero deja registrada la explicación estructural que faltaba.
- **Corrección aplicada:** `verificar_fuente_celda.R` ahora lee la fila citada en `fuente_celda`
  con `readxl::read_excel()` (misma librería y misma convención de índice que el extractor), en
  vez de resolver hoja → XML → `sharedStrings` a mano. Se eliminaron `resolver_ruta_hoja()`,
  `leer_shared_strings()`, `texto_celda()` y el `unzip()` a un directorio temporal — quedan sin
  uso una vez que la lectura de fila pasa por `readxl`. El cálculo de checksum (`digest`, sobre
  el archivo crudo) no cambió.
- **Segunda corrida, sobre el árbol de trabajo con la corrección aplicada:**
  **99 PASS / 0 FAIL / 0 NO_VERIFICABLE / 1 FUERA_DE_ALCANCE** (de 100 filas). Código de salida
  0. FUERA_DE_ALCANCE: `UT.DEMANDA_ELEC.GWH.NSA.M` (sin cambios — su vintage vigente sigue
  siendo un `.csv`, no un `.xlsx`).
- **`testthat::test_dir("tests")` tras la corrección: 598 PASS / 0 FAIL** (no hay test que
  ejercite `verificar_fuente_celda.R` directamente — no corre en CI, ver cabecera de este
  archivo — pero la batería completa sigue en verde).

## 2026-09-16 (segunda sesión) — alta de BCR.REMESAS.NOM.NSA.M y ONEC.IPC.IDX.NSA.M

- **Estado del árbol verificado:** el commit que agrega las filas `BCR.REMESAS.NOM.NSA.M` y
  `ONEC.IPC.IDX.NSA.M` a `03_series.csv` (padre: `f2f7894`). El hash no puede ser
  autorreferencial — mismo patrón que las dos entradas anteriores.
- **Contexto:** segundo predictor de la matriz (senda §6.4, sector externo: remesas), más su
  deflactor (ADR-010: deflactación caso por caso). Ninguna de las dos publicaciones tenía
  archivo en `data/L0_raw/` antes de esta sesión — a diferencia de `BCR.IVAE.VOL.SA.M`, no
  venían de los lotes de captura de Fase 2 (Bloque 2/3). Se capturaron en vivo, just-in-time,
  con el mismo mecanismo de `src/adquisicion/bcr_captura.R` (chromote + interceptación de
  descarga real) ya usado para el resto de la familia BCR — captura puntual de dos
  publicaciones nuevas, no recolección de volumen (regla 9 de `CLAUDE.md`).
  - `BCR.REMESAS_FAMILIARES_MENSUAL`: id_publicación 64 (coincide con el sondeo ya registrado
    en `01_publicaciones/BCR.REMESAS_FAMILIARES_MENSUAL.yaml`), 427 períodos (1991-01 a
    2026-07). Registrada como `BCR_remesas_familiares_mensual_2026-09-16.xlsx`,
    `BCR.REMESAS_FAMILIARES_MENSUAL.v2026-08`.
  - `ONEC.IPC.BASE_2009`: la URL declarada en su ficha de `01_publicaciones` había devuelto 404
    en el intento de verificación directa de Harold (2026-08-12, ver nota "Pendiente reintentar
    o localizar la URL correcta" en esa ficha). Reintentada en vivo el 2026-09-16: la URL
    respondió con normalidad (id_publicación 48, unidades "Indice Diciembre 2009=100", coincide
    con lo declarado) — el 404 de agosto fue una falla puntual, no un cambio de estructura ni
    una URL incorrecta. 212 períodos (2009-01 a 2026-08; enero-noviembre de 2009 son celdas
    vacías por construcción — confirmado, consistente con la nota ya registrada en esa ficha).
    Registrada como `BCR_ipc_base_2009_2026-09-16.xlsx`, `ONEC.IPC.BASE_2009.v2026-09`.
- Archivos `.xlsx` verificados (checksum SHA-256 contra `manifiesto.csv`):
  - `BCR_remesas_familiares_mensual_2026-09-16.xlsx`:
    `589488e326c9ded098dcd7291068fd7dcf48bd4431bae2785a13ee03550cc60d`
  - `BCR_ipc_base_2009_2026-09-16.xlsx`:
    `ec9bdabd7e78e7bcf0103952027f6cbc6b49a328988af094a3aee892b148bb75`
- **Resultado: 101 PASS / 0 FAIL / 0 NO_VERIFICABLE / 1 FUERA_DE_ALCANCE** (de 102 filas).
  `BCR.REMESAS.NOM.NSA.M` y `ONEC.IPC.IDX.NSA.M` ambas **PASS** en la primera corrida —
  `fuente_celda` se redactó y verificó contra el archivo real antes de admitir las filas, no al
  revés. FUERA_DE_ALCANCE: `UT.DEMANDA_ELEC.GWH.NSA.M` (sin cambios).
- Notas: corrida ejecutada por Claude Code (Sonnet 5) contra el árbol de trabajo local de
  Harold, con los archivos de `data/L0_raw/` presentes. No requirió cambios al script del
  verificador (a diferencia de la sesión anterior el mismo día).

## 2026-09-16 (tercera sesión) — alta de BCR.IPP.IDX.NSA.M

- **Estado del árbol verificado:** árbol de trabajo local de Harold, sobre el commit que agrega
  la fila `BCR.IPP.IDX.NSA.M` a `03_series.csv` (tercer predictor de la matriz, senda §6.4,
  precios; padre: `e585e70`). Corrida antes de commitear, mismo patrón que la entrada del
  2026-08-28 — el hash no puede ser autorreferencial.
- **Contexto:** a diferencia de `BCR.REMESAS`/`ONEC.IPC` (capturadas just-in-time la sesión
  anterior), `BCR_ipp_2026-08-26.xlsx` ya estaba en `data/L0_raw/` desde el lote de Fase 2
  (Bloque 3) — no requirió captura nueva. Es un índice de precios (nivel, no flujo), con el
  mismo patrón estructural de `ONEC.IPC.IDX.NSA.M` (arranca dic-2009=100 por construcción, once
  celdas vacías ene-nov 2009 antes de la primera observación real, `col_inicio="M"`). `fuente_celda`
  se redactó y verificó contra el archivo real antes de admitir la fila.
- Archivo `.xlsx` verificado (checksum SHA-256 contra `manifiesto.csv`):
  - `BCR_ipp_2026-08-26.xlsx`: `1949c55a464f87c55e2703610e7ec9af1616ae7541f579688fd0fca09ca70eec`
- **Resultado: 102 PASS / 0 FAIL / 0 NO_VERIFICABLE / 1 FUERA_DE_ALCANCE** (de 103 filas).
  `BCR.IPP.IDX.NSA.M` **PASS** en la primera corrida. FUERA_DE_ALCANCE: `UT.DEMANDA_ELEC.GWH.NSA.M`
  (sin cambios). Código de salida 0.
- `testthat::test_dir("tests")` tras esta alta: **640 PASS / 0 FAIL** — no se agregó ningún test
  nuevo (el extractor reutiliza `agregar_trimestral_promedio()`, ya cubierta por
  `tests/test-l3-predictores.R`; el ajuste de forward-fill extendido en
  `extraer_bcr_ipp.R` copia el de `extraer_onec_ipc.R`, ya probado en producción).
- Notas: corrida ejecutada por Claude Code (Sonnet 5) contra el árbol de trabajo local de
  Harold, con los archivos de `data/L0_raw/` presentes. No requirió cambios al script del
  verificador.

## 2026-09-16 (cuarta sesión) — alta de BCR.EXPORT_FOB.NOM.NSA.M

- **Estado del árbol verificado:** árbol de trabajo local de Harold, sobre el commit que agrega
  la fila `BCR.EXPORT_FOB.NOM.NSA.M` a `03_series.csv` (cuarto predictor de la matriz, senda
  §6.4, comercio exterior). Corrida antes de commitear, mismo patrón que entradas anteriores —
  el hash no puede ser autorreferencial.
- **Contexto:** `BCR_balanza_comercial_2026-08-26.xlsx` ya estaba en `data/L0_raw/` desde el
  lote de Fase 2 (Bloque 3) — no requirió captura nueva. La publicación trae tres series de
  cabecera (Exportaciones FOB, Importaciones CIF, Balanza Comercial/saldo); por decisión de
  Harold (`AskUserQuestion` de esta sesión), se admite solo Exportaciones. Es la Balanza
  Comercial de Mercancías (solo mercancías, valoración FOB, mensual) — **no** la misma serie que
  `BCR.EXPORT.NOM.NSA.Q` ya catalogada (Cuentas Nacionales/SCN2008, bienes y servicios,
  trimestral), de ahí el concepto distinto `EXPORT_FOB` en el `serie_id` para no colisionar.
  `fuente_celda` se redactó y verificó contra el archivo real antes de admitir la fila.
- Archivo `.xlsx` verificado (checksum SHA-256 contra `manifiesto.csv`):
  - `BCR_balanza_comercial_2026-08-26.xlsx`: `d38efe6cabd4391ab22563657d59106745e6629d4820d02a93c1b29ae09246ce`
- **Resultado: 103 PASS / 0 FAIL / 0 NO_VERIFICABLE / 1 FUERA_DE_ALCANCE** (de 104 filas).
  `BCR.EXPORT_FOB.NOM.NSA.M` **PASS** en la primera corrida. FUERA_DE_ALCANCE:
  `UT.DEMANDA_ELEC.GWH.NSA.M` (sin cambios). Código de salida 0.
- `testthat::test_dir("tests")` tras esta alta: **644 PASS / 0 FAIL** (el incremento de 640 a
  644 viene de aserciones paramétricas sobre filas de catálogo — p.ej.
  `tests/test-integridad-referencial.R` — que escalan con el número de filas, no de tests
  nuevos escritos a mano; ningún `test_that` nuevo se agregó, el extractor reutiliza
  `agregar_trimestral_suma()`, ya cubierta).
- Notas: corrida ejecutada por Claude Code (Sonnet 5) contra el árbol de trabajo local de
  Harold, con los archivos de `data/L0_raw/` presentes. No requirió cambios al script del
  verificador.

## 2026-09-16 (quinta sesión) — alta de BCR.ITCER.IDX.NSA.M y BCR.IPM.IDX.NSA.M

- **Estado del árbol verificado:** árbol de trabajo local de Harold, sobre el commit que agrega
  ambas filas a `03_series.csv` (quinto y sexto predictor de la matriz, senda §6.4: tipo de
  cambio real y precios de importación). Corrida antes de commitear — el hash no puede ser
  autorreferencial.
- **Contexto:** Harold instruyó proceder con el resto de la matriz de predictores sin
  supervisión turno a turno ("realiza el procedimiento para las restantes, ya no necesitas
  supervisión", 2026-09-16). Ambos `.xlsx` ya estaban en `data/L0_raw/` desde el lote de Fase 2
  (Bloque 3) — no requirieron captura nueva. Ambas publicaciones traen más de una serie de
  cabecera; se admitió solo una de cada una, siguiendo el mismo criterio ya establecido
  (serie más agregada/directa, o la que el propio catálogo ya señalaba):
  - `BCR.ITCER`: tres series (global, bilateral EEUU, con Centroamérica) — se admitió
    **global**. Bilaterales quedan disponibles, no descartadas.
  - `BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR`: tres series (Exportación, Importación, Términos de
    Intercambio) — se admitió **Importación**, que `01_publicaciones/
    BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR.yaml` ya señalaba como el candidato de la senda §1.3;
    no fue una elección nueva de esta sesión. Exportación y Términos de Intercambio quedan
    disponibles, no descartadas.
  - Se crearon dos entradas nuevas en `catalogos/02_metodologias/` (`ITCER_BASE2014.yaml`,
    `IPCE_BASE2005.yaml`) para poder declarar `base_year`/`metodologia_id` en `03_series.csv`,
    con el año base confirmado empíricamente (promedio de los 12 meses del año base ≈ 100 en
    ambos casos) en vez de solo citado de la nota de pie del archivo.
  - **Corrección de paso:** al verificar el patrón de URLs con sufijo
    `serie-desestacionalizada`, se encontró que una nota ya existente en la fila
    `BCR.REMESAS.NOM.NSA.M` (de la segunda sesión del día) afirmaba incorrectamente que
    IVAE/IPI/ISI/ITCER/SPNF llevaban ese sufijo — verificado contra las 5 fichas de
    `01_publicaciones`, solo IVAE e IPI realmente lo llevan. Corregido in situ en esa fila con
    una nota de corrección fechada; no cambia la clasificación NSA de ninguna fila (esa
    clasificación nunca dependió de esa lista).
- Archivos `.xlsx` verificados (checksum SHA-256 contra `manifiesto.csv`):
  - `BCR_itcer_2026-08-26.xlsx`: `0e675be1b357ffe0792d656b558cba7e0f1c3719063efb0b92669882d046173a`
  - `BCR_indices_precios_comercio_exterior_2026-08-26.xlsx`:
    `8b758835bb582e20b12c3122f5bfa4edb7d06a9203dc71bcb980b3cf14d4c706`
- **Resultado: 105 PASS / 0 FAIL / 0 NO_VERIFICABLE / 1 FUERA_DE_ALCANCE** (de 106 filas).
  `BCR.ITCER.IDX.NSA.M` y `BCR.IPM.IDX.NSA.M` ambas **PASS** en la primera corrida.
  FUERA_DE_ALCANCE: `UT.DEMANDA_ELEC.GWH.NSA.M` (sin cambios). Código de salida 0.
- `testthat::test_dir("tests")` tras estas altas: **654 PASS / 0 FAIL** — ningún `test_that`
  nuevo escrito a mano; ambos extractores reutilizan `agregar_trimestral_promedio()`, ya
  cubierta.
- Notas: corrida ejecutada por Claude Code (Sonnet 5) contra el árbol de trabajo local de
  Harold, con los archivos de `data/L0_raw/` presentes. No requirió cambios al script del
  verificador.

## 2026-09-22 — corrida de cierre de Fase 3 (G1 del checklist de cierre)

- **Contexto:** operacionalización de `checklist_cierre_fase3.md`. Esta corrida es la
  evidencia de G1 ("trazabilidad valor → celda, certificada en una corrida real") para el
  cierre de Fase 3 — ver `doc/adr/README.md`, "Cierre de Fase 3", y
  `doc/evidencia_cierre_fase3.txt`. `catalogos/03_series.csv` no cambió en esta sesión
  (106 filas, mismo contenido que la corrida del 2026-09-16 quinta sesión); se corrió de
  nuevo porque el criterio de cierre exige una corrida real sobre el commit que la cita,
  no reusar una entrada anterior.
- **Resultado: 105 PASS / 0 FAIL / 0 NO_VERIFICABLE / 1 FUERA_DE_ALCANCE** (de 106 filas).
  FUERA_DE_ALCANCE: `UT.DEMANDA_ELEC.GWH.NSA.M` (sin cambios — su vintage vigente sigue
  siendo un CSV derivado, no un `.xlsx`). Código de salida 0.
- `testthat::test_dir("tests")` en la misma sesión: **459 PASS / 0 FAIL / 0 SKIP** (incluye
  58 aserciones nuevas: `tests/test-hegy.R`, `tests/test-vintage-lib.R`, y los `test_that`
  agregados a `tests/test-estacionariedad.R`/`tests/test-l3-pib-objetivo.R` para D1/D2/E3).
  Nota de discrepancia: la entrada anterior de esta bitácora (arriba) registra 654 PASS en
  la misma suite — no se investigó la diferencia, ajena al alcance de esta sesión; el
  número que rige para el cierre de Fase 3 es el de esta corrida, verificado directamente.
- Notas: corrida ejecutada por Claude Code (Sonnet 5) contra el árbol de trabajo local de
  Harold, con los archivos de `data/L0_raw/` presentes. No requirió cambios al script del
  verificador.
