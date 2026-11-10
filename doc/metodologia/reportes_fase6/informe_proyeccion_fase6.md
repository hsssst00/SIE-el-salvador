# Informe de proyección condicional del PIB de El Salvador, 2026-2030 (Fase 6, Ejercicio B)

**Estado:** borrador del 2026-11-10 (checklist F2). Las cifras salen de la reproducción del 2026-11-10 (E4), no de los
archivos de la corrida única (E3), que están en la PC INVE. Es la misma especificación, el mismo corte y las mismas
semillas, y salieron los mismos conteos y los mismos registros de `07_experimentos.csv`. Pero la igualdad bit a bit
con E3 no está comprobada todavía (`doc/checklist_fase6.md`, E4). El borrador deja de serlo cuando E4 lo confirme. Si
E4 encuentra diferencias, este informe se rehace con los archivos de E3.

> **Todas las cifras de este informe son condicionales.** Dicen cuánto crecería el PIB de El Salvador **si** la
> economía de EE. UU. y el petróleo siguieran los supuestos de `doc/metodologia/supuestos_escenarios.md`, y con los
> modelos de Fase 5 tal como se estimaron. No son pronósticos incondicionales ni una previsión oficial. Cada tabla
> versionada lleva esa nota en su columna `nota`.

## 1. Qué se corrió

- **Corte:** `doc/metodologia/corte_fase6.csv` (sha256 sin CR `4aaa33fe…`), congelado el 2026-11-04 con el
  preregistro `doc/metodologia/preregistro_fase6.yaml`. Último trimestre observado del PIB: **2026-T2**. Horizonte:
  h = 1 a 20, de 2026-T3 a 2031-T2.
- **Objetivo:** PIB trimestral SA con el ajuste estacional propio, en log-nivel (ADR-001). La cifra principal es el
  crecimiento anual del promedio de los cuatro trimestres SA de cada año (F6-11).
- **Grupos:** G1 (remesas nominales y exportaciones FOB), G2 (G1 más ITCER, UT, IVAE e IPM) y G3 (las ocho familias),
  los de Fase 5 (F4-05). Cada grupo tiene su combinación.
- **Escenarios:** base (WEO de octubre de 2026), adverso (escenario C, «Market Correction», del recuadro 1.2 del WEO)
  y favorable (escenario A, «Strong Payoffs»). Más seis corridas de sensibilidad sobre la base.
- **Modelos condicionados:** en cada grupo, los modelos con al menos una predictora externa (F6-01). Las variables de
  escenario les llegan por seis ecuaciones satélite (sección 6). **Combinación:** la mediana de los miembros que pasan
  la guarda, con la mezcla de sus densidades para las bandas (F6-02, F6-07). **Trayectoria sin escenario:** los
  benchmarks y los univariados sin predictoras externas, que no dependen del escenario (sección 4).
- **Guarda de plausibilidad (F6-08):** los 126 senderos de los miembros (los seis o cuatro miembros de cada grupo en
  las nueve corridas) quedan dentro del rango congelado, de −5,15 a 13,07 pp de interanual. **Ningún modelo quedó
  fuera** (`guarda_fase6.csv`). El interanual de los miembros va de −2,2 a 8,7 pp.
- **Verificación previa:** V1-V23 OK en la misma corrida, incluidos V22 (el condicional reproduce el sendero impuesto
  en un DGP conocido) y V23 (la guarda excluye un modelo explosivo sintético).

Tablas completas en esta carpeta: `proyeccion_anual_fase6.csv`, `proyeccion_trimestral_fase6.csv` (nivel índice,
log-nivel, interanual y trimestral, con bandas del 80 y del 95 %), `sensibilidad_fase6.csv`, `guarda_fase6.csv`,
`coherencia_*_fase6.csv`, `satelites_fase6.csv` y `diagnosticos_fase6.csv`. Las escribe `make tablas-fase6`, que
antes comprueba el sha256 de cada salida contra `sha256_salidas_fase6.csv`.

## 2. Cifra principal: crecimiento anual de la combinación

Crecimiento anual del PIB real (%), mediana de los miembros (`COMBINACION`). Las bandas son las de la mezcla de
densidades de los miembros.

| Grupo | Escenario | 2026* | 2027 | 2028 | 2029 | 2030 | Promedio 2026-2030 | Banda 80 % del promedio | Banda 95 % del promedio |
|---|---|---|---|---|---|---|---|---|---|
| G1 | Base | 4,2 | 2,3 | 1,8 | 1,7 | 1,6 | **2,3** | [0,8; 4,4] | [−0,1; 5,5] |
| G1 | Adverso (C) | 4,3 | 1,4 | 1,3 | 2,0 | 2,1 | **2,2** | [0,7; 4,3] | [−0,3; 5,4] |
| G1 | Favorable (A) | 4,2 | 2,5 | 2,1 | 2,0 | 1,7 | **2,5** | [1,0; 4,6] | [0,1; 5,7] |
| G2 | Base | 4,6 | 2,8 | 2,6 | 2,5 | 2,5 | **3,0** | [0,5; 5,7] | [−0,9; 7,3] |
| G2 | Adverso (C) | 4,7 | 2,7 | 2,4 | 2,5 | 2,5 | **3,0** | [0,4; 5,6] | [−1,0; 7,3] |
| G2 | Favorable (A) | 4,6 | 2,8 | 2,6 | 2,5 | 2,5 | **3,0** | [0,6; 5,8] | [−1,0; 7,3] |
| G3 | Base | 4,7 | 2,9 | 2,6 | 2,5 | 2,5 | **3,1** | [0,4; 5,8] | [−1,1; 7,6] |
| G3 | Adverso (C) | 4,7 | 2,9 | 2,4 | 2,6 | 2,6 | **3,0** | [0,4; 5,7] | [−1,1; 7,6] |
| G3 | Favorable (A) | 4,7 | 2,9 | 2,6 | 2,6 | 2,6 | **3,1** | [0,5; 5,9] | [−1,1; 7,6] |

\* 2026 mezcla dos trimestres observados (2026-T1 y T2) con dos proyectados. Las bandas de 2028 en adelante y las del
promedio llevan la marca «sin calibrar», porque incluyen trimestres con h > 8, donde Fase 4 y 5 no pudieron medir la
cobertura.

**Lectura.**

1. **La diferencia entre grupos pesa más que la diferencia entre escenarios.** Con los mismos supuestos, G1 da 2,3 %
   de promedio y G2 y G3, 3,0 y 3,1 %. G1 solo ve a EE. UU. a través de las remesas y las exportaciones, y sus modelos
   arrastran la desaceleración de esas dos series. G2 y G3 agregan el IVAE y otros indicadores internos.
2. **Los escenarios mueven poco la mediana.** Frente a la base, el adverso resta 0,15 pp al promedio en G1, 0,05 en
   G2 y 0,03 en G3. El favorable suma 0,17, 0,03 y 0,01. La mayor diferencia en un año es la del adverso en G1 en
   2027: −0,94 pp, el año en que el PIB de EE. UU. cae 1,5 % bajo su base. Los desvíos A y C son moderados (el PIB de
   EE. UU. se aparta a lo sumo 1,8 % de la base) y de corta duración.
3. **En G1, el adverso crece más que la base en 2029 y 2030.** En el escenario C, el nivel del PIB de EE. UU. vuelve
   hacia la base desde 2029 (de −1,8 % en 2028 a −0,5 % en 2031), así que su crecimiento supera al de la base esos
   años, y G1 lo transmite. Es la forma del supuesto, no un error.
4. **Las bandas son anchas.** La banda del 80 % del promedio 2026-2030 mide entre 3,6 y 5,4 pp. La del 95 % de un
   año suelto llega a 18 pp en la combinación de G3 y a 22 pp en un miembro (`MIX.PUENTE.G2`). Las diferencias entre escenarios caben con holgura dentro de ellas. Las bandas
   heredan la varianza de los residuos de cada modelo, cuya muestra de estimación incluye 2020 y 2021, y suman la
   incertidumbre de las satélites (F6-15-a).
5. **La mezcla no está centrada en la mediana** (F6-07-a). Se reportan las dos tal cual: la mediana es la cifra
   puntual y la mezcla da las bandas. En G1, el centro de la banda del 80 % del promedio queda en 2,6 %, por encima de
   la mediana (2,3 %), porque `MULT.BVAR.G1` proyecta 3,4 % y tira la mezcla hacia arriba. En G2 y G3 la distancia es
   de 0,1 pp.

## 3. Miembros de la combinación (escenario base)

Promedio 2026-2030 de cada miembro, con su banda del 95 %. Los nueve escenarios por miembro están en
`proyeccion_anual_fase6.csv`.

| Grupo | Modelo | Promedio 2026-2030 (%) | Banda 95 % |
|---|---|---|---|
| G1 | `UNI.ARIMAX.G1` | 2,24 | [−0,2; 4,8] |
| G1 | `MULT.VAR_DIF.G1` | 2,37 | [−0,1; 5,1] |
| G1 | `MULT.VAR_NIV.G1` | 2,29 | [0,4; 4,3] |
| G1 | `MULT.VECM.G1` | 2,37 | [−0,1; 5,1] |
| G1 | `MULT.BVAR.G1` | 3,38 | [0,5; 6,4] |
| G1 | `MIX.PUENTE.G1` | 2,52 | [−0,6; 5,8] |
| G2 | `UNI.ARIMAX.G2` | 3,03 | [−1,2; 7,7] |
| G2 | `MULT.VAR_DIF.G2` | 2,92 | [−0,1; 6,2] |
| G2 | `MULT.BVAR.G2` | 3,06 | [−0,1; 6,4] |
| G2 | `MIX.PUENTE.G2` | 3,02 | [−1,8; 8,4] |
| G3 | `UNI.ARIMAX.G3` | 3,09 | [−1,8; 8,5] |
| G3 | `MULT.VAR_DIF.G3` | 2,92 | [−0,2; 6,2] |
| G3 | `MULT.BVAR.G3` | 2,96 | [−0,2; 6,4] |
| G3 | `MIX.PUENTE.G3` | 3,09 | [−1,5; 8,2] |

- `MULT.VAR_DIF.G3` tiene la misma especificación que `MULT.VAR_DIF.G2` (B2-6) y da el mismo sendero. Entra en los
  dos grupos, como en Fase 5 (F6-01-c).
- **BVAR, h > 8: lectura cautelosa.** Antes de proyectar se midió que la mayoría de las extracciones de la posterior
  del BVAR tiene una raíz mayor que 1 (78 % en G1, 99,9 % en G2 y 99,98 % en G3), casi ninguna mayor que 1,05 (E2;
  `decisiones_fase6.md`, nota del 2026-11-04). Con estos priors no es una anomalía (protocolo §3), pero puede
  ensanchar sus bandas y las de la mezcla a horizontes largos. Las bandas de `MULT.BVAR.G*` de 2028 en adelante, y las
  de la combinación de esos años, se leen con esa reserva (protocolo §10).
- **El puente no distingue escenarios en 2026-T3.** El IVAE llega a 2026-M08, así que 2026-T3 está incompleto: en ese
  trimestre el puente usa su AR mensual y no la satélite, y da el mismo valor en los tres escenarios (4,1, 4,5 y
  4,4 % de interanual en G1, G2 y G3) (F6-17-b).

## 4. Trayectoria sin escenario

Los modelos sin predictoras externas no dependen de los supuestos. Su sendero es el mismo en los tres grupos (se
comprobó sobre las tablas) y sirve de contraste.

| Modelo | Promedio 2026-2030 (%) | Banda 80 % |
|---|---|---|
| `BENCH.RW_SIN_DERIVA` | 0,91 | [−1,6; 3,6] |
| `BENCH.RW_CON_DERIVA` | 3,08 | [0,5; 5,8] |
| `BENCH.AR1` | 3,00 | [0,8; 5,3] |
| `BENCH.ARP_BIC` | 3,08 | [0,5; 5,8] |
| `BENCH.MEDIA_CRECIMIENTO` | 2,78 | sin densidad |
| `BENCH.ETS` | 2,98 | [1,2; 4,9] |
| `UNI.ARIMA` | 2,74 | [1,5; 4,0] |
| `UNI.UC_LLT` | 2,95 | [1,1; 4,9] |
| `UNI.ARIMAX_IVAE.G2` (solo G2; su única predictora es interna, F6-01-b) | 3,02 | [−0,1; 6,4] |

Salvo el paseo aleatorio sin deriva, que congela el nivel de 2026-T2, los modelos sin escenario dan entre 2,7 y
3,1 %. Es el rango de G2 y G3, y está por encima de G1.

## 5. Sensibilidad (F6-09)

Sobre la base se desplaza una variable a la vez en ±1 desviación estándar histórica de su crecimiento anual, de
forma permanente. Desviaciones (de la historia en L3, años completos, sin 2020 ni 2021): **PIB de EE. UU. 2,23 pp,
IPC de EE. UU. 2,80 pp, petróleo 25,05 pp** (`sd_sensibilidad_fase6.csv`).

Efecto sobre el crecimiento promedio 2026-2030 de la combinación, en pp, y entre paréntesis sobre el nivel de 2030,
en %:

| Grupo | PIB EE. UU. +1 de | PIB EE. UU. −1 de | IPC EE. UU. +1 de | IPC EE. UU. −1 de | Petróleo +1 de | Petróleo −1 de |
|---|---|---|---|---|---|---|
| G1 | 1,64 (8,3) | −1,47 (−7,0) | 0,00 (0,0) | 0,00 (0,0) | 0,00 (0,0) | 0,00 (0,0) |
| G2 | 0,55 (2,7) | −0,71 (−3,4) | 0,09 (0,4) | −0,05 (−0,2) | 0,03 (0,2) | −0,02 (−0,1) |
| G3 | 0,44 (2,2) | −0,58 (−2,8) | 0,09 (0,5) | −0,08 (−0,4) | 0,00 (0,0) | −0,00 (−0,0) |

- El PIB de EE. UU. es el único supuesto que mueve las cifras. Una desviación estándar sostenida cambia el promedio
  de G1 en unos 1,5 pp, y el de G2 y G3 entre 0,4 y 0,7 pp. Es bastante más que la distancia entre A, C y la base,
  porque esos escenarios se apartan de la base mucho menos que una desviación estándar y por poco tiempo.
- En G1 el IPC y el petróleo no tienen efecto: ningún modelo de G1 tiene ITCER, IPM ni IPP entre sus predictoras.
- El riesgo del petróleo, que los escenarios A y C no mueven (sección 7), se ve solo aquí, y es pequeño.

## 6. Coherencia interna (F6-10)

El ejercicio no se puede validar: no hay datos futuros contra los cuales medir. Lo que reemplaza a la validación es
esta lista, fijada antes de la corrida.

**Identidad con `stop()`.** La agregación trimestral → anual de cada sendero publicado es consistente a 1e-10. La
corrida no se detuvo.

**Informativas** (se reportan sin forzar nada):

- **Frente al WEO para El Salvador** (`SLV.NGDP_RPCH`, una referencia y no un objetivo). Diferencia del escenario
  base de la combinación contra el WEO, en pp (`coherencia_weo_fase6.csv`):

  | Año | WEO | G1 | G2 | G3 |
  |---|---|---|---|---|
  | 2026 | 4,5 | 4,2 (−0,26) | 4,6 (+0,15) | 4,7 (+0,22) |
  | 2027 | 4,0 | 2,3 (−1,70) | 2,8 (−1,22) | 2,9 (−1,06) |
  | 2028 | 3,3 | 1,8 (−1,45) | 2,6 (−0,72) | 2,6 (−0,73) |
  | 2029 | 3,3 | 1,7 (−1,56) | 2,5 (−0,77) | 2,5 (−0,75) |
  | 2030 | 3,3 | 1,6 (−1,70) | 2,5 (−0,78) | 2,5 (−0,77) |

  En 2026 los grupos coinciden con el FMI. De 2027 en adelante quedan por debajo: entre 0,7 y 1,2 pp en G2 y G3, y
  entre 1,5 y 1,7 pp en G1. Los modelos del SIE extrapolan la dinámica histórica del PIB y de sus predictoras; el FMI
  incorpora juicio sobre la economía salvadoreña que estos modelos no tienen. La diferencia no es un error de ninguno
  de los dos (supuestos, sección 6, punto 7).
- **Frente al promedio histórico** de 1991-2025 (`coherencia_historica_fase6.csv`): 2,55 % con 2020 y 2,85 % sin
  2020. G1 (2,34 %) queda por debajo de los dos. G2 (3,01 %) y G3 (3,06 %) quedan por encima de los dos, a 0,2 pp del
  promedio sin 2020.
- **Signo de la respuesta** (`coherencia_signos_fase6.csv`). Más PIB de EE. UU. da más PIB de El Salvador en la
  combinación de los tres grupos. De las 34 filas con signo esperado (cada miembro y la combinación, con +1 y −1 de),
  coinciden 30. Las cuatro que no coinciden son de **`MIX.PUENTE.G2` y `MIX.PUENTE.G3`**: responden con el signo
  contrario, aunque con un efecto mínimo (−0,05 y −0,07 pp en el promedio ante +1 de). El puente de G1 responde con el signo esperado y con fuerza (+1,55 pp). El IPC
  y el petróleo se reportan sin signo esperado.
- **Deflactor implícito de las remesas** (solo `MULT.BVAR.G3`, que recibe las nominales y las reales;
  `coherencia_deflactor_fase6.csv`). Los 20 trimestres proyectados quedan dentro del rango histórico (de −1,9 a
  7,3 pp sin 2020-2021). El sendero va de 2,0 a 3,8 pp.

## 7. Supuestos e inconsistencias que el lector debe tener presentes

El detalle, con fuente, vintage y sha256 de cada supuesto, está en `doc/metodologia/supuestos_escenarios.md`. Lo
esencial:

- **El petróleo no se mueve en A ni en C** (el recuadro 1.2 no lo publica) y queda en el sendero base en los tres
  escenarios. Su 2026-T4 sale de la meta anual del WEO para 2026 con tres trimestres observados: 118,22 USD, un 31 %
  sobre 2026-T3, y baja a 77,56 USD en 2027-T4 (F6-16). Con el corte congelado la cifra es la misma que se anticipó.
- **La base y los escenarios vienen de modelos distintos del FMI.** A y C salen del modelo GIMF y solo se publican
  como desvíos de la base; aplicarlos sobre la base supone que el desvío se traslada sin cambio.
- **Proyección de un productor sobre la historia de otro:** crecimientos del WEO encadenados sobre la historia de
  BEA, BLS y PCPS.
- **El suavizado curva 2026 en A y C.** Con desvío cero en 2026 y distinto de cero en 2027, Denton-Cholette mueve los
  trimestres libres de 2026 sin cambiar su promedio (F6-16-b). Por eso 2026 difiere entre escenarios en décimas.
- **Las satélites son modelos nuevos** que el Ejercicio A no evaluó, y sus residuos se suponen independientes de las
  innovaciones de cada modelo del PIB (F6-15-a). Se estimaron una vez en el origen (`satelites_fase6.csv`):

  | Satélite | p | q | Observaciones |
  |---|---|---|---|
  | `SAT.REMESAS_NOM` | 2 | 1 | 131 |
  | `SAT.REMESAS_REAL` | 0 | 0 | 57 |
  | `SAT.EXPORT_FOB` | 1 | 1 | 120 |
  | `SAT.ITCER` | 0 | 0 | 97 |
  | `SAT.IPM` | 0 | 2 | 77 |
  | `SAT.IPP` | 1 | 1 | 56 |

- **Las remesas nominales y reales tienen satélites separadas**, así que su deflactor implícito no queda atado
  (sección 6).
- **Solo hay canales externos.** Ningún escenario contiene un choque interno de El Salvador (fiscal, financiero o
  climático). La diferencia entre escenarios mide la respuesta de los modelos a los supuestos de EE. UU., no la
  incertidumbre total; para eso están las bandas.

## 8. Lo que este informe no dice

- No evalúa la precisión de estas proyecciones: eso le toca a la evaluación prospectiva de AP-2, cuando lleguen los
  datos.
- No elige un grupo ni un escenario como «el pronóstico». Los tres grupos y los tres escenarios se reportan igual. La
  evaluación de Fase 5 tomó a G1 y G2 como resultado principal y a G3 con advertencia de potencia (F4-05); aquí G2 y
  G3 dan casi lo mismo.
- No corrige ni recentra ninguna cifra para acercarla al WEO, al histórico o a otra referencia.

## Fuentes y avisos

- FMI, *World Economic Outlook*, octubre de 2026: base de datos y capítulo 1, recuadro 1.2. FMI, *Primary Commodity
  Price System*. BEA (GDPC1) y BLS (CPIAUCSL), vía FRED. Vintages y sha256 en `supuestos_escenarios.md`, sección 2.
- This product uses the FRED® API but is not endorsed or certified by the Federal Reserve Bank of St. Louis.
- Datos de El Salvador: Banco Central de Reserva (PIB trimestral, IVAE, remesas, comercio exterior, ITCER, IPP e IPM),
  ONEC (IPC) y Unidad de Transacciones (demanda de electricidad). Condiciones de uso por fuente en ADR-008.
