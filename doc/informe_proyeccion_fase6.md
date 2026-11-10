# Informe de proyección condicional del PIB de El Salvador, 2026-2031 (Fase 6, Ejercicio B)

**Estado:** informe de la corrida única (E3) del 2026-11-04. Borrador para revisión: F2 de `doc/checklist_fase6.md` se
marca cuando Harold lo revise.

> **Todas las cifras de este informe son condicionales.** Dicen qué pasaría con el PIB de El Salvador si se cumplieran
> los supuestos de EE. UU. de cada escenario (`doc/metodologia/supuestos_escenarios.md`). No son pronósticos
> incondicionales, los escenarios no tienen probabilidades asignadas y el ejercicio no se puede validar contra datos
> (senda metodológica §1.3). Las cifras con horizonte mayor que 8 trimestres no están calibradas.

## 1. Qué se corrió

- **Ejercicio:** proyección condicional del PIB trimestral desestacionalizado, origen 2026-Q2, horizonte de 20
  trimestres (hasta 2031-Q2), con los modelos de Fase 5 reestimados una sola vez en el origen.
- **Grupos de predictoras:** G1, G2 y G3 (F4-05). En cada uno, la proyección es la **mediana** de los modelos
  condicionables del grupo (F6-02), con bandas de la mezcla de sus densidades en pesos iguales (F6-07).
- **Escenarios:** base (WEO de octubre de 2026), adverso (escenario C, «Market Correction», recuadro 1.2 del WEO) y
  favorable (escenario A, «Strong Payoffs»). Las variables de escenario son el PIB real de EE. UU., su inflación y el
  petróleo (F6-05, F6-14).
- **Corrida:** `make fase6` sobre `b1376df`, árbol limpio, preregistro congelado el 2026-11-04. Corte
  `corte_fase6` (sha256 sin CR `4aaa33fe…`). Evidencia: `doc/evidencia_corrida_fase6.txt`. Salidas en
  `data/L4_experiments/F6_G1`, `F6_G2`, `F6_G3` y `F6_COMUN` (están en `.gitignore`; las reproduce `make fase6`).
- **Guarda de plausibilidad:** rango del interanual [−5,15; 13,07] pp, fijado antes de proyectar. **Ningún modelo fue
  excluido** (0 de 54 combinaciones modelo-corrida en G1 y de 36 en G2 y G3). Los interanuales proyectados quedaron
  entre −2,21 y 8,74 pp.

## 2. Resultado principal: crecimiento anual del PIB real, escenario base

Crecimiento anual (%) del promedio de los niveles trimestrales SA, con banda del 80 % entre corchetes.
Condicional a los supuestos del escenario base.

| Año | G1 | G2 | G3 |
|---|---|---|---|
| 2026 (a) | 4,24 [3,06; 5,51] | 4,65 [2,99; 6,13] | 4,72 [2,99; 6,25] |
| 2027 | 2,30 [−1,15; 6,28] | 2,78 [−2,21; 8,21] | 2,94 [−2,34; 8,49] |
| 2028 (b) | 1,85 [−1,63; 5,95] | 2,58 [−2,55; 8,09] | 2,57 [−2,80; 8,27] |
| 2029 (b) | 1,74 [−1,77; 5,92] | 2,53 [−2,72; 8,00] | 2,55 [−2,84; 8,25] |
| 2030 (b) | 1,60 [−1,94; 5,80] | 2,52 [−2,76; 7,95] | 2,53 [−2,98; 8,19] |
| **Promedio 2026-2030 (b)** | **2,34** [0,81; 4,41] | **3,01** [0,53; 5,69] | **3,06** [0,44; 5,82] |

(a) 2026 mezcla dos trimestres observados (T1 y T2) con dos proyectados. (b) Marcado «sin calibrar»: incluye
trimestres con h > 8; el promedio 2026-2030 lo lleva siempre. 2031 se reporta solo en trimestres: el interanual de
2031-Q2 en la base es 1,73 % (G1), 2,51 % (G2) y 2,52 % (G3).

**Lectura.** Los tres grupos proyectan una desaceleración desde 2026 hacia un crecimiento de entre 1,6 y 2,5 % a
2030. Las bandas son anchas: la del 80 % para 2027 va de −1,2 a 6,3 % en G1 y de −2,3 a 8,5 % en G3. El promedio
2026-2030 es la cifra que mejor resume la trayectoria, pero su banda del 95 % incluye el cero en los tres grupos
(G1 de −0,12 a 5,54; G3 de −1,12 a 7,63).

## 3. Escenarios

Crecimiento promedio 2026-2030 (%) y crecimiento de 2027 (%), que es el año de mayor desvío en los escenarios.

| | Promedio 2026-30: base | adverso | favorable | 2027: base | adverso | favorable |
|---|---|---|---|---|---|---|
| G1 | 2,34 | 2,20 | 2,52 | 2,30 | 1,35 | 2,52 |
| G2 | 3,01 | 2,96 | 3,04 | 2,78 | 2,66 | 2,84 |
| G3 | 3,06 | 3,03 | 3,07 | 2,94 | 2,88 | 2,94 |

**Lectura.**
- La diferencia entre escenarios es pequeña frente a las bandas. Solo G1 la transmite de forma visible: en 2027 el
  adverso baja el crecimiento 0,95 pp y el favorable lo sube 0,22 pp.
- G2 y G3 casi no responden (0,05 pp o menos en el promedio). Ahí el escenario cambia poco porque los desvíos del
  recuadro 1.2 son modestos (el adverso es −1,8 % del nivel del PIB de EE. UU. como máximo, en 2028) y porque esos
  modelos transmiten poco el PIB de EE. UU. (ver §5).
- Esto mide cómo responden los modelos a los supuestos de EE. UU., no la incertidumbre total sobre El Salvador.
  Un choque interno (fiscal, financiero, climático) no está en ningún escenario.

## 4. Qué hay detrás de la mediana: los modelos de cada grupo

Crecimiento promedio 2026-2030 (%) en el escenario base, por miembro de la combinación.

| G1 | % | G2 | % | G3 | % |
|---|---|---|---|---|---|
| UNI.ARIMAX | 2,24 | MULT.VAR_DIF | 2,92 | MULT.VAR_DIF | 2,92 |
| MULT.VAR_NIV | 2,29 | **Combinación** | **3,01** | MULT.BVAR | 2,96 |
| **Combinación** | **2,34** | MIX.PUENTE | 3,02 | **Combinación** | **3,06** |
| MULT.VAR_DIF | 2,38 | UNI.ARIMAX | 3,03 | UNI.ARIMAX | 3,09 |
| MULT.VECM | 2,38 | MULT.BVAR | 3,06 | MIX.PUENTE | 3,09 |
| MIX.PUENTE | 2,52 | | | | |
| MULT.BVAR | 3,38 | | | | |

- **G2 y G3** son muy parecidos entre sí y sus miembros caen en un rango de 0,2 pp.
- **G1** es más disperso: el BVAR (3,38 %) queda 0,9 pp por encima del miembro siguiente. La mediana lo absorbe, y
  por eso se eligió la mediana y no la media (F6-02). Las bandas del BVAR con h > 8 son de lectura cautelosa: más de
  la mitad de sus extracciones tiene una raíz mayor que 1 (medición E2, `decisiones_fase6.md`).
- **Trayectoria sin escenario** (benchmarks y modelos sin variables externas, promedio 2026-2030): entre 2,74 y
  3,08 % para ARIMA, ETS, AR(1), AR(p), media de crecimiento, caminata con deriva y componentes no observados. La
  caminata aleatoria sin deriva da 0,91 %. La combinación del escenario base queda por debajo (G1) o dentro del
  rango (G2 y G3) de esa trayectoria sin escenario. No se analizó qué explica que G1 quede por debajo.

## 5. Sensibilidad: una variable a la vez

Cada variable se desplaza una desviación estándar histórica de su crecimiento anual, sumada en cada año proyectado
y con las demás en la base. Desviaciones estándar (L3, sin 2020 ni 2021): PIB de EE. UU. 2,23 pp; IPC de EE. UU.
2,80 pp; petróleo 25,06 pp. Cambio de la combinación frente a la base: nivel del PIB en 2030 (%) y crecimiento
promedio 2026-2030 (pp).

| Variable | G1 +1 DE | G1 −1 DE | G2 +1 DE | G2 −1 DE | G3 +1 DE | G3 −1 DE |
|---|---|---|---|---|---|---|
| PIB de EE. UU. (nivel 2030) | +8,26 | −7,01 | +2,68 | −3,39 | +2,17 | −2,78 |
| PIB de EE. UU. (crec. prom.) | +1,64 | −1,47 | +0,55 | −0,71 | +0,44 | −0,58 |
| IPC de EE. UU. (nivel 2030) | 0 | 0 | +0,45 | −0,25 | +0,45 | −0,41 |
| IPC de EE. UU. (crec. prom.) | 0 | 0 | +0,09 | −0,05 | +0,09 | −0,08 |
| Petróleo (nivel 2030) | 0 | 0 | +0,16 | −0,07 | +0,01 | −0,01 |
| Petróleo (crec. prom.) | 0 | 0 | +0,03 | −0,02 | 0,00 | 0,00 |

**Lectura.**
- El PIB de EE. UU. es, por mucho, el canal dominante. En G1 es el único: ningún miembro de G1 usa el IPC ni el
  petróleo, así que su efecto es exactamente cero.
- La sensibilidad desplaza el nivel de EE. UU. mucho más que los escenarios (+2,23 pp cada año, acumulado, frente a
  desvíos de entre −1,8 y +1,3 % en el nivel). Por eso la respuesta a ±1 DE es varias veces la diferencia entre
  escenarios.
- G1 reacciona unas tres veces más que G2 y G3 al PIB de EE. UU. (1,6 frente a 0,4-0,6 pp en el crecimiento
  promedio). Es la misma diferencia que se ve entre escenarios y vale la pena entender antes de dar peso a un grupo
  sobre otro.

## 6. Coherencia interna

El ejercicio no se puede validar con datos, así que su control es la coherencia (protocolo §9).

- **Agregación trimestral a anual (detiene la corrida si falla):** pasó en los tres grupos.
- **Frente al WEO para El Salvador** (informativa). Diferencia del crecimiento de la base menos el WEO, en pp
  (WEO: 4,5; 4,0; 3,3; 3,3; 3,3 % para 2026 a 2030):

  | | 2026 | 2027 | 2028 | 2029 | 2030 |
  |---|---|---|---|---|---|
  | G1 | −0,26 | −1,70 | −1,45 | −1,56 | −1,70 |
  | G2 | +0,15 | −1,22 | −0,72 | −0,77 | −0,78 |
  | G3 | +0,22 | −1,06 | −0,73 | −0,75 | −0,77 |

  Los tres grupos proyectan menos crecimiento que el WEO desde 2027, G1 más que G2 y G3. En 2026 la diferencia es pequeña
  (dos trimestres son observados).
- **Frente al histórico 1991-2025** (informativa): promedio de la base 2,34 % (G1), 3,01 % (G2) y 3,06 % (G3); el
  histórico es 2,55 % con 2020 y 2,85 % sin 2020. G1 queda por debajo de ambos y G2 y G3, por encima del histórico con
  2020.
- **Signo de la respuesta a cada variable** (informativa): coincide con el esperado en todos los casos donde hay un
  signo esperado, salvo en el puente de G2 y de G3 (`MIX.PUENTE.G2` y `MIX.PUENTE.G3`), en las dos corridas del PIB de
  EE. UU.: responden con signo contrario al esperado (bajan cuando el PIB de EE. UU. sube y al revés). No distorsionan la combinación porque es una mediana, pero es un
  hallazgo del modelo, no de los datos. No hay signo esperado declarado para el IPC y el petróleo.
- **Deflactor implícito de las remesas** (informativa): solo es calculable en G3, donde el BVAR es el único miembro con
  las remesas nominales y reales. Sus 20 trimestres proyectados quedan dentro del rango histórico sin 2020-2021
  (−1,92 a 7,26 pp); en 2026-Q3 el interanual es 3,03 pp y en 2031-Q2, 2,5. En G1 y G2 no hay modelo con las dos
  remesas y no se calculó.

## 7. Qué dicen y qué no dicen estos resultados

- **Dicen** cómo responden los modelos de Fase 5, reestimados en 2026-Q2, a los supuestos de EE. UU. del WEO de
  octubre de 2026 y a dos escenarios de su recuadro 1.2.
- **No dicen** qué va a pasar. Las bandas son de la mezcla de densidades de los modelos, no de una distribución
  verificada. Con h > 8 no tienen calibración, y no puede haberla para el futuro.
- **Lo que queda abierto.**
  - Por qué G1 reacciona más que G2 y G3 al PIB de EE. UU. y por qué proyecta menos crecimiento (§§3, 5 y 6). No se
    analizó qué miembro o qué predictora lo explica.
  - Si el puente (`MIX.PUENTE.G2` y `G3`) responde con signo contrario por su especificación o por la estimación.
  - Si hay que dar más peso a un grupo. El protocolo no elige entre G1, G2 y G3; este informe tampoco.
- **Sobre este informe.** Las cifras salen de `anual.csv`, `sensibilidad.csv`, `coherencia_*.csv` y `guarda.csv`
  de cada grupo, y de `sd_sensibilidad.csv` de `F6_COMUN`. No se editó ninguna. Falta la reproducción en la máquina
  de Harold (E4).
