# Lectura de resultados de Fase 5 (checklist E3 y E4)

**Fecha:** 2026-10-13. **Corrida leída:** la corrida única de E2 sobre `e1722fa` (2026-10-08/09, máquina de Harold,
árbol limpio), registrada en `doc/evidencia_corrida_unica_fase5.txt`.

Este informe no corre nada nuevo ni cambia ningún resultado. Cumple el protocolo §4 y se escribe **después** de ver
los resultados. Por eso separa dos cosas: las reglas de lectura fijadas antes de la corrida (§2), que se aplican tal
cual, y las observaciones descriptivas (§3 a §5), que no fueron hipótesis preregistradas y se rotulan así.

## 1. Fuentes

- RMSE, RMSE relativo, pertenencia y p-valor del MCS, coberturas, CRPS y las marcas `marca_tamano` y `marca_n`:
  `doc/metodologia/reportes_fase5/tabla_resultados_fase5.csv` (1960 filas, 15 experimentos; sha256 sin CR
  `29218ad0866b29cb…`).
- DM/HLN, GW y el contraste de estabilidad: `pruebas.csv`, `pruebas_submuestras.csv` y `estabilidad.csv` de
  `data/L4_experiments/F5_*/`. No se versionan, pero `make eval` los regenera byte a byte (F1).
- Pronósticos puntuales citados en §3.3: `pronosticos.csv` de `F5_G3`.

Unidad: variación interanual en puntos porcentuales (`yoy_pp`). La referencia del RMSE relativo y de DM/HLN es
`BENCH.RW_SIN_DERIVA`. El diferencial es `d = e_RW² − e_modelo²`, así que `d > 0` favorece al modelo.

## 2. Reglas de lectura fijadas antes de los resultados

1. **El resultado es el MCS, no el mínimo del RMSE** (protocolo §4). Si el MCS contiene varios modelos, el
   resultado es el conjunto, y la tabla de RMSE se lee junto con la pertenencia al MCS.
2. **h = 4 y 8 llevan la marca `distorsion_tamano_documentada` («d»)** (F4-18). DM/HLN sobre-rechaza en esos
   horizontes, y quedar fuera del MCS no prueba inferioridad. El tamaño empírico que acompaña a cada p-valor
   (F4-21) es el de V7 en `doc/evidencia_cierre_fase4.txt` (`c4e8b39`). Los `n` de esa tabla son los de la
   corrida principal de Fase 5, porque los orígenes son los mismos. V7 volvió a pasar en E2 (bloques V1-V21 OK),
   pero esa salida de consola no se transcribió.

| Grupo | h | n | Tamaño empírico al 5 % (V7) |
|---|---|---|---|
| G1 | 1 | 52 | 0,0440 |
| G1 | 2 | 51 | 0,0495 |
| G1 | 4 | 49 | 0,0805 |
| G1 | 8 | 45 | 0,1165 |
| G2 | 1 | 45 | 0,0470 |
| G2 | 2 | 44 | 0,0565 |
| G2 | 4 | 42 | 0,0720 |
| G2 | 8 | 38 | 0,1195 |
| G3 | 1 | 25 | 0,0395 |
| G3 | 2 | 24 | 0,0565 |
| G3 | 4 | 22 | 0,1140 |
| G3 | 8 | 18 | 0,1525 |

3. **Las celdas con n < 18 (`n_bajo_calibracion`) no se interpretan** (V9, nota I4 del cierre de Fase 4). En
   Fase 5 son R3 `pre2020` de G2 con h = 4 (17) y h = 8 (13), y R4 `sin_2020_2021` de G3 en los cuatro horizontes
   (17).
4. **La potencia es baja.** Según V8, una pérdida 20 % menor se detecta entre 7 % y 16 % de las veces. No rechazar
   no equivale a equivalencia.
5. **GW y el contraste de estabilidad de R3 llevan `tamano_no_verificado`.** Se informan, pero no sostienen
   conclusiones.
6. **Multiplicidad.** DM/HLN compara cada modelo con el paseo aleatorio, de 13 a 22 comparaciones por celda y sin
   ajuste. El procedimiento que controla la multiplicidad es el MCS. Además, el p-valor DM del modelo con menor RMSE
   corresponde a un modelo elegido después de ver el RMSE.

## 3. E3: corrida principal (`F5_G1`, `F5_G2`, `F5_G3`)

| Grupo | h | n | Modelos | En el MCS | p_MCS mín. | Menor RMSE relativo | p DM del menor | DM a favor / en contra (5 %) | Marca |
|---|---|---|---|---|---|---|---|---|---|
| G1 | 1 | 52 | 23 | 23 | 0,728 | 0,799 (MIX.UMIDAS) | 0,144 | 0 / 0 | — |
| G1 | 2 | 51 | 23 | 23 | 0,704 | 0,865 (MIX.PUENTE) | 0,292 | 0 / 0 | — |
| G1 | 4 | 49 | 23 | 23 | 0,696 | 0,813 (MIX.PUENTE) | 0,219 | 0 / 0 | d |
| G1 | 8 | 45 | 23 | 23 | 0,262 | 0,912 (BENCH.ARP_BIC) | 0,001 | 16 / 0 | d |
| G2 | 1 | 45 | 22 | 22 | 0,574 | 0,445 (MIX.PUENTE) | 0,139 | 0 / 0 | — |
| G2 | 2 | 44 | 22 | 22 | 0,671 | 0,775 (MIX.PUENTE) | 0,260 | 0 / 0 | — |
| G2 | 4 | 42 | 22 | 22 | 0,536 | 0,832 (MIX.PUENTE) | 0,264 | 0 / 0 | d |
| G2 | 8 | 38 | 22 | 22 | 0,708 | 0,922 (BENCH.ARP_BIC) | 0,003 | 8 / 0 | d |
| G3 | 1 | 25 | 21 | 21 | 0,444 | 0,503 (MIX.PUENTE) | 0,143 | 0 / 0 | — |
| G3 | 2 | 24 | 21 | 21 | 0,737 | 0,788 (MIX.PUENTE) | 0,290 | 0 / 2 | — |
| G3 | 4 | 22 | 21 | 21 | 0,384 | 0,645 (MIX.PUENTE) | 0,135 | 3 / 0 | d |
| G3 | 8 | 18 | 21 | 21 | 0,223 | 0,436 (BENCH.ARP_BIC) | 0,000 | 10 / 0 | d |

«DM a favor / en contra» cuenta los modelos con p < 0,05 cuyo diferencial favorece al modelo o al paseo
aleatorio. «Marca d» indica h = 4 u 8.

### 3.1 Lectura según las reglas de §2

- **El MCS al 10 % conserva todos los modelos en las 12 celdas** (de 21 a 23 por grupo, benchmarks incluidos). El
  p-valor más bajo del MCS es 0,223 (G3, h = 8). Por la regla 1, el resultado de la corrida principal es el
  conjunto completo: ningún modelo de Fase 5 se distingue estadísticamente de los benchmarks ni de los demás.
- **h = 1 y 2: DM no rechaza a favor de ningún modelo frente al paseo aleatorio.** El menor RMSE relativo va de
  0,45 a 0,87, con p-valores de 0,14 a 0,29. En G3, h = 2, `COMB.MEDIA.G3` y `COMB.ECM_INV.G3` pierden contra el
  paseo aleatorio al 5 % (p 0,047 y 0,044), en una celda sin marca (ver §3.3).
- **h = 8: muchos modelos le ganan al paseo aleatorio por DM** (16 en G1, 8 en G2 y 10 en G3), pero con la marca
  «d». Entre ellos están los benchmarks con deriva o con media de crecimiento (`BENCH.AR1`, `ARP_BIC`,
  `MEDIA_CRECIMIENTO`, `RW_CON_DERIVA`), y el menor RMSE en los tres grupos es de `BENCH.ARP_BIC`. La
  interpretación es descriptiva: a ese plazo, el paseo aleatorio sin deriva pronostica crecimiento interanual nulo,
  y la ventaja viene de modelar el crecimiento medio, no de las predictoras.

### 3.2 Observación descriptiva: el orden por RMSE

En h = 1, 2 y 4, el menor RMSE de los tres grupos es de `MIX.PUENTE`, salvo G1 con h = 1, donde lo tiene
`MIX.UMIDAS` (0,799). Las mayores reducciones están en G2 y G3 con h = 1 (0,45 y 0,50). El orden se repite en las
variantes (§4.1), pero el MCS no lo distingue y DM no rechaza. Por la regla 1, no se declara ganador.

### 3.3 Observación descriptiva: pronósticos explosivos aislados en G3

- `REG.ENET.G3`, origen 2021-Q1: pronostica −348 pp a h = 8 y +338 pp a h = 4, frente a una mediana entre modelos
  de 1 a 2 pp en ese origen. Su RMSE relativo es 22,9 a h = 8 (RMSE de 83 pp) y 10,5 a h = 4.
- `MULT.BVAR.G3`, origen 2020-Q2: pronostica −126 pp a h = 8. Su RMSE relativo es 8,4.
- Aun así, los dos siguen dentro del MCS (p 0,22 y 0,42 a h = 8; p 0,38 el ENET a h = 4). Con 18 a 22 pares, una
  sola pérdida enorme infla la varianza del bootstrap y el MCS no puede excluirlos. Esto ilustra la regla 4: en G3,
  con h ≥ 4, que un modelo pertenezca al MCS no informa nada.
- Las combinaciones por media heredan esa explosión. `COMB.MEDIA.G3` y `COMB.ECM_INV.G3` tienen RMSE relativo de
  1,12, 1,47 y 2,37 en h = 2, 4 y 8, mientras que `COMB.MEDIANA.G3` (1,07, 0,97 y 0,55) y `COMB.RECORTADA.G3`
  (1,10, 1,13 y 0,64) no la heredan. Eso explica las dos pérdidas significativas de §3.1.
- La explosión del ENET coincide con el límite declarado B3-4: pocas filas en la estimación directa a h = 8 frente
  a 36 columnas penalizadas, en un origen Q1 donde reoptimiza (F5-14d) con 2020 dentro de la ventana. **No se
  diagnosticó más allá de esto.** Un diagnóstico sería un análisis posterior a los resultados, y queda como
  pendiente declarado (§6). En R2 la explosión no se repite: el RMSE relativo del ENET de G3 a h = 8 baja a 3,0.

### 3.4 Densidades

Mediana de la cobertura al 80 % de los modelos de Fase 5 (las combinaciones no tienen densidad, F5-12):

| Muestra | Grupo | h=1 | h=2 | h=4 | h=8 |
|---|---|---|---|---|---|
| completa | G1 | 0,81 | 0,84 | 0,84 | 0,82 |
| completa | G2 | 0,81 | 0,84 | 0,81 | 0,80 |
| completa | G3 | 0,80 | 0,75 | 0,82 | 0,89 |
| R3 pre2020 | G1 | 0,85 | 0,92 | 1,00 | 1,00 |
| R3 pre2020 | G2 | 0,85 | 1,00 | 1,00 | 1,00 |
| R3 post2020 | G1 | 0,80 | 0,76 | 0,72 | 0,72 |
| R3 post2020 | G2 | 0,80 | 0,72 | 0,70 | 0,70 |

La cobertura al 95 % de la principal tiene una mediana entre 0,83 y 0,94. En la muestra completa la calibración
parece adecuada, pero eso esconde dos tramos: antes de 2020 los intervalos son demasiado anchos (cobertura de 0,85
a 1,00) y después son estrechos en h = 2 a 8 (0,70 a 0,76). R3 es una submuestra con `tamano_no_verificado` en su
contraste, así que esto es descriptivo. El menor CRPS es de `MIX.PUENTE` en h = 1 y 2 de los tres grupos, y de
`UNI.ARIMA` en h = 8.

## 4. E4: robustez (protocolo §5)

R1, R2, R5 y R6 corren con los univariados de B1 y un representante por familia (`MULT.VAR_DIF`, `REG.ENET`,
`MIX.PUENTE`, `ML.RF`), más las combinaciones de esos miembros (F5-14c, F5-14e). **`MIX.UMIDAS` no está en esas
variantes**, así que el orden por RMSE compite con menos modelos. R7 repite los modelos con UT de G2 y G3. R3 y R4
reevalúan los errores de la principal.

### 4.1 `MIX.PUENTE` en todas las variantes (h = 1, 2)

RMSE relativo al paseo aleatorio sin deriva y p-valor de DM/HLN. `MIX.PUENTE` está dentro del MCS en todas las
celdas. Esta tabla sigue a un modelo elegido por su RMSE en la principal, así que es descriptiva.

| Variante | Muestra | G1 h=1 | G1 h=2 | G2 h=1 | G2 h=2 | G3 h=1 | G3 h=2 |
|---|---|---|---|---|---|---|---|
| principal | completa | 0,80 (p 0,171) | 0,86 (p 0,292) | 0,45 (p 0,139) | 0,78 (p 0,260) | 0,50 (p 0,143) | 0,79 (p 0,290) |
| R1 | completa | 0,80 (p 0,152) | 0,81 (p 0,302) | 0,45 (p 0,139) | 0,77 (p 0,259) | 0,51 (p 0,142) | 0,78 (p 0,289) |
| R2 | completa | — | — | 0,45 (p 0,136) | 0,77 (p 0,258) | 0,53 (p 0,138) | 0,77 (p 0,292) |
| R3 | pre2020 | 0,83 (p 0,085) | 0,57 (p 0,005) | 0,69 (p 0,018) | 0,51 (p 0,000) | — | — |
| R3 | post2020 | 0,80 (p 0,188) | 0,88 (p 0,359) | 0,44 (p 0,148) | 0,78 (p 0,288) | — | — |
| R4 | sin_2020 | 0,90 (p 0,367) | 0,86 (p 0,004) | 0,76 (p 0,070) | 0,56 (p 0,096) | 0,76 (p 0,189) | 0,59 (p 0,173) |
| R4 | sin_2020_2021 | 0,96 (p 0,743) | 0,68 (p 0,003) | 0,85 (p 0,196) | 0,62 (p 0,002) | 0,91 (p 0,597) (n<18) | 0,68 (p 0,090) (n<18) |
| R5 | completa | — | — | 0,25 (p 0,140) | 0,79 (p 0,281) | 0,26 (p 0,151) | 0,78 (p 0,299) |
| R6 | completa | 0,78 (p 0,176) | 0,87 (p 0,308) | 0,39 (p 0,143) | 0,79 (p 0,275) | 0,41 (p 0,149) | 0,79 (p 0,307) |
| R7 | completa | — | — | 0,44 (p 0,141) | 0,78 (p 0,265) | 0,51 (p 0,144) | 0,79 (p 0,293) |

- En R1, R2, R5, R6 y R7, el RMSE relativo y los p-valores casi no se mueven respecto de la principal. Ningún
  p-valor baja de 0,13.
- **R5** (PIB oficial desestacionalizado): el RMSE relativo con h = 1 baja a 0,25 y 0,26, pero el objetivo hereda
  la filtración del ajuste bilateral del BCR (F4-22), así que no se lee como mejora del modelo.
- **R3 `pre2020` y R4** (`sin_2020` en G1; `sin_2020_2021` en G1 y G2): con h = 2, DM rechaza a favor del puente
  (p de 0,000 a 0,005; n de 19 a 47; sin marca). Pero en esas celdas el MCS conserva al puente junto con casi todos
  los demás modelos (§4.2), así que no se distingue de ellos.

### 4.2 Exclusiones del MCS en las variantes

Solo hay exclusiones en R3 y R4. R1, R2, R5, R6 y R7 conservan todos los modelos en todas las celdas.

| Variante | Muestra | Grupo | h | n | Fuera del MCS | Marcas |
|---|---|---|---|---|---|---|
| R3 | pre2020 | G1 | 1 | 27 | BENCH.RW_SIN_DERIVA | — |
| R3 | pre2020 | G1 | 2 | 26 | BENCH.RW_SIN_DERIVA | — |
| R3 | pre2020 | G1 | 4 | 24 | BENCH.RW_SIN_DERIVA, ML.LGBM, MULT.VAR_NIV | d |
| R3 | pre2020 | G1 | 8 | 20 | BENCH.RW_SIN_DERIVA, ML.LGBM, ML.RF, MULT.VAR_NIV | d |
| R3 | pre2020 | G2 | 1 | 20 | BENCH.RW_SIN_DERIVA, REG.PCR | — |
| R3 | pre2020 | G2 | 2 | 19 | BENCH.RW_SIN_DERIVA, MULT.BVAR | — |
| R3 | pre2020 | G2 | 4 | 17 | BENCH.RW_SIN_DERIVA, MULT.BVAR, REG.PCR | d, n<18 |
| R3 | pre2020 | G2 | 8 | 13 | BENCH.RW_SIN_DERIVA, ML.LGBM, MULT.BVAR, REG.ENET, REG.PCR | d, n<18 |
| R4 | sin_2020 | G1 | 4 | 45 | BENCH.RW_SIN_DERIVA | d |
| R4 | sin_2020 | G1 | 8 | 41 | BENCH.RW_SIN_DERIVA, MULT.VAR_NIV | d |
| R4 | sin_2020_2021 | G1 | 1 | 44 | BENCH.RW_SIN_DERIVA | — |
| R4 | sin_2020_2021 | G1 | 2 | 43 | BENCH.RW_SIN_DERIVA | — |
| R4 | sin_2020_2021 | G1 | 4 | 41 | BENCH.RW_SIN_DERIVA, MULT.VAR_NIV | d |
| R4 | sin_2020_2021 | G1 | 8 | 37 | BENCH.RW_SIN_DERIVA, MULT.VAR_NIV | d |
| R4 | sin_2020 | G2 | 8 | 34 | BENCH.RW_SIN_DERIVA | d |
| R4 | sin_2020_2021 | G2 | 1 | 37 | BENCH.RW_SIN_DERIVA | — |
| R4 | sin_2020_2021 | G2 | 2 | 36 | BENCH.RW_SIN_DERIVA | — |
| R4 | sin_2020_2021 | G2 | 4 | 34 | BENCH.RW_SIN_DERIVA, ML.RF | d |
| R4 | sin_2020_2021 | G3 | 2 | 17 | BENCH.RW_SIN_DERIVA, MIX.UMIDAS | n<18 |

- **La lectura que se sostiene sin marcas** es la misma de Fase 4: en G1 y G2, con h = 1 y 2, sin los targets de
  2020 ni 2021 (n de 36 a 44), el paseo aleatorio sin deriva sale del MCS y todos los demás modelos quedan dentro.
  A diferencia de Fase 4 (nota I1), en Fase 5 esa línea (F4-29) estaba fijada antes del congelamiento del
  preregistro (`f8fe345`). Sigue vigente la aproximación declarada de tratar como contiguos los pares a ambos lados
  del hueco.
- **R3 `pre2020` con h = 1 y 2** (n de 19 a 27, sin marca): sale el paseo aleatorio en G1 y G2, y además
  `REG.PCR.G2` (h = 1) y `MULT.BVAR.G2` (h = 2). Es una submuestra corta, de un período de crecimiento estable en
  que el paseo sin deriva está en desventaja mecánica.
- Las demás exclusiones están en celdas con marca «d» o con n < 18, y no se interpretan (reglas 2 y 3).

### 4.3 GW (R1) y estabilidad (R3)

- **GW** (`tamano_no_verificado`): en G1 y G2 no rechaza en ninguna celda. En G3 rechaza al 5 % en 1 de 16 comparaciones
  con h = 2, 7 con h = 4 (3 con diferencial a favor del modelo) y 14 con h = 8 (8 a favor). Una celda quedó no
  definida: G3, h = 8, `UNI.ARIMA`, con Ω singular (E2-2).
- **Contraste de estabilidad pre/post 2020** (`tamano_no_verificado`): 4 de 172 contrastes son significativos al
  5 %, todos con h = 1: `BENCH.ETS` y `MULT.BVAR.G1` en G1, `BENCH.ETS` y `ML.LGBM.G2` en G2. Los cuatro tienen
  cambio negativo, es decir, la ventaja frente al paseo aleatorio se reduce después de 2020. Por azar se esperarían
  unos 9 de 172, así que no hay indicio de inestabilidad sistemática.

### 4.4 R7: rezago supuesto de UT (61 en lugar de 30 días)

De 112 comparaciones de RMSE relativo (14 modelos × 4 horizontes × G2 y G3), 80 son idénticas a la principal. Solo
cambian `MIX.PUENTE`, `MIX.UMIDAS`, `ML.RF` y `MULT.BVAR`. Fuera de `MULT.BVAR.G3` con h = 8 (+0,72, dominado por
el pronóstico explosivo de §3.3), el cambio máximo es de 0,069 (`MIX.UMIDAS.G3`, h = 8). El
puente con h = 1 queda en 0,44 (G2) y 0,51 (G3). El supuesto de 30 días de F5-04 no determina ningún resultado.

## 5. Qué se puede afirmar y qué no

**Se puede afirmar:**

1. En la corrida principal, el MCS al 10 % es el conjunto completo en las 12 celdas. Ningún modelo de Fase 5 supera
   de forma estadísticamente distinguible al paseo aleatorio ni a los demás benchmarks.
2. Sin los targets de 2020 y 2021, en G1 y G2 con h = 1 y 2, el paseo aleatorio sin deriva queda fuera del MCS. Los
   modelos de Fase 5 y los otros benchmarks no se distinguen entre sí.
3. El rezago supuesto de UT (R7) no cambia la lectura.

**Descriptivo, sin respaldo inferencial:**

4. `MIX.PUENTE` tiene el menor RMSE con h = 1, 2 y 4 en casi todas las celdas y variantes. Las variantes comparten
   targets, así que esa repetición no es evidencia independiente.
5. En G3 hay pronósticos explosivos aislados (`REG.ENET.G3`, `MULT.BVAR.G3`) que el MCS no excluye. Las
   combinaciones por mediana y recortada los resisten, y las de media no.
6. Las densidades tienen buena cobertura media, pero con intervalos anchos antes de 2020 y estrechos después.

**No se puede afirmar:**

- Que el puente «gana» o un ranking entre modelos de Fase 5.
- Inferioridad de un modelo por quedar fuera del MCS con h = 4, 8, ni nada que salga de celdas con n < 18.
- Conclusiones a partir de GW o del contraste de estabilidad (tamaño no verificado).

## 6. Pendientes que este informe deja declarados

- Diagnóstico de los pronósticos explosivos de `REG.ENET.G3` (2021-Q1) y `MULT.BVAR.G3` (2020-Q2): sería un análisis
  posterior a los resultados, fuera del preregistro. Si se hace, entra como extensión con su propio registro.
- Tamaño de GW y del contraste de estabilidad, sin verificar desde Fase 4.
- La calibración de las densidades por tramo (§3.4) es descriptiva; no hay prueba preregistrada para ella.
