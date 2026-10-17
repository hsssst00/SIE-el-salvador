# AP-1 — Diagnóstico de los pronósticos explosivos de Fase 5

**Análisis posterior a los resultados** (registro: `doc/metodologia/decisiones_fase5.md`, «Análisis posteriores»).
No cambia ningún modelo, YAML, experimento, tabla ni MCS de Fase 5, ni los tags `v0.8.x`. Lo que sigue entra a Fase
6 solo por ficha de decisión.

**Fuente.** `src/analisis_posterior/ap1_explosivos.R`, sobre el corte `corte_fase5.csv` y la L4 de la corrida
citada (`e1722fa`). Todas las cifras salen de los CSV `ap1_*.csv` de esta carpeta.

## 1. Reproducción

Los dos casos del cierre de Fase 5 se reestimaron con las funciones del propio pipeline: el mismo conjunto de
información que arma `correr_backtest()` y la misma semilla por experimento, modelo y origen. Los dos reproducen la
L4 (`ap1_reproduccion.csv`):

| Caso | Semilla | Interanual h = 8 en L4 | Reproducido | máx. \|dif\| log-nivel |
|---|---|---|---|---|
| `REG.ENET.G3`, origen 2021-Q1 | 232280639 | −347,97 pp | −347,97 pp | 5,3e-15 |
| `MULT.BVAR.G3`, origen 2020-Q2 | 14390607 | −125,99 pp | −125,99 pp | 3,6e-15 |

## 2. `REG.ENET.G3` en 2021-Q1

**Mecanismo.** El −348 pp de h = 8 no nace en h = 8. Con h > 4 la interanual es `s_8 − s_4`, y el sendero en h = 4
es g_4 = +3,38 log-puntos (+338 pp en h = 4). En h = 8, g_8 = −0,10, así que la interanual en h = 8 hereda la
explosión de h = 4. h = 7 también es explosivo (g_7 = +2,64).

**Por qué explota en h = 4** (`ap1_enet_resumen.csv`, `ap1_enet_columnas.csv`):

- **Fila del origen fuera del rango de la ventana.** La forma directa usa rezagos 0..3, y en 2021-Q1 el rezago 3 del
  PIB es el Δlog de 2020-Q2. Esa columna está a 33,2 desviaciones de la ventana, cuando dentro de la ventana el
  máximo es 2,1. En h = 4 hay 17 de 36 columnas fuera del rango de su ventana, y la última fila de esa ventana es
  2020-Q1: ninguna fila de estimación contiene el choque en esa columna.
- **Penalización mínima.** En h = 4 la validación anidada eligió α = 1 (lasso) en la posición 100 de 100 de la
  rejilla: el extremo menos penalizado, λ_max · 10⁻³. Quedan 35 coeficientes no nulos con 37 filas, casi una
  interpolación.
- **La validación no lo ve.** Los 12 orígenes internos de h = 4 (2017-Q2 a 2020-Q1) son todos anteriores al choque,
  y el ECM interno es casi plano en λ (`ap1_enet_senda_lambda.csv`). Con α = 1, va de 0,00635 en el candidato más
  penalizado a 0,00628 en el elegido, un 1 % de diferencia. Sobre esa misma senda, g_4 va de +0,02 a +3,38. El
  argmin cae en el borde por una diferencia del 1 % en el ECM de 12 orígenes internos.
- **Aportes a g_4:** el rezago 3 del PIB aporta +1,92 (z = −33,2 por un coeficiente de −0,058), las remesas reales
  y nominales (rezago 3) +0,87 y −0,85, el FOB (rezago 2) −0,78, el IVAE (rezago 3) +0,72 y UT (rezago 3) +0,44.

En h = 1 el mismo origen eligió el extremo más penalizado (posición 1): los coeficientes son casi nulos y el
pronóstico es razonable. El problema aparece donde la validación elige poca penalización.

## 3. `MULT.BVAR.G3` en 2020-Q2

**El panel** (`ap1_bvar_panel.csv`) tiene 9 series de 2010-Q1 a 2020-Q2: 42 trimestres y 38 observaciones
efectivas con p = 4, para 37 coeficientes por ecuación. El último dato es el choque: el Δlog del PIB es −0,220 (−30,2
desviaciones de los Δ previos), el del IVAE −0,199 (−20,0), el del FOB −0,607 (−8,7) y el de UT −0,172 (−7,8).

**Las extracciones** (`ap1_bvar_extracciones.csv`, 5 000 retenidas, aceptación del MH 0,257):

| | Mediana | Media | p1 | p5 | Mínimo |
|---|---|---|---|---|---|
| Interanual h = 8 (pp) | +5,3 | −126,0 | −1 981 | −649 | −19 259 |
| Interanual h = 4 (pp) | −33,5 | −50,5 | −271 | −164 | −867 |
| Mayor raíz de la compañera | 1,021 | 1,071 | — | — | máx. 2,141 |

- El 99,98 % de las extracciones tiene una raíz mayor que 1. Eso es lo esperable en log-niveles, y casi todas están
  cerca de 1. El 29,2 % pasa de 1,05.
- La correlación entre esa raíz y \|interanual h = 8\| es 0,77.
- El pronóstico puntual del modelo es la **media** de la predictiva (B2-10). Esa media la domina la cola de
  extracciones explosivas: sin el 1 % de cada cola, la media es −85 pp; la mediana es +5,3 pp.

## 4. Barrido de la L4

`ap1_barrido.csv`, 268 filas (experimento × modelo de los 15 `F5_G*`). El rango histórico de la interanual observada
del objetivo es [−22,3; +25,3] pp. Como umbral **descriptivo**, no como guarda, se cuenta lo que supera el doble de
su máximo absoluto (50,5 pp):

| Modelo | Pronósticos sobre 50,5 pp | Orígenes |
|---|---|---|
| `REG.ENET.G3` | 43 (en `F5_G3` y sus variantes) | 2020-Q2 a 2021-Q4 |
| `UNI.UC_LLT` | 14 (R2 y R5 de G2 y G3) | 2020-Q2 |
| `MULT.BVAR.G3` | 11 (`F5_G3` y R7) | 2020-Q2 |
| `MULT.VAR_DIF.G2`, `MULT.VAR_DIF.G3` | 3 cada uno (R6) | 2020-Q2 |

Ningún otro modelo supera ese umbral. Todos los casos tienen el choque de 2020 en el conjunto de información del
origen. El ENET es el único afectado después de 2020-Q2, porque sus rezagos 0..3 arrastran el choque durante varios
trimestres.

## 5. Clasificación

| Caso | Implementación | Estimación | Especificación |
|---|---|---|---|
| `REG.ENET.G3` | **Descartada**: reproduce la L4 con diferencias de 1e-15 y los aportes por columna reconstruyen g_h exactamente; el código hace lo que dicen B3-1 a B3-7 | **Sí, en la selección**: con orígenes internos sin el choque, el ECM es plano y el argmin cae en el borde menos penalizado de la rejilla (B3-1) | **Sí**: la forma directa lineal no se protege de una fila de predictores fuera del rango de la ventana; el tratamiento de 2020 de ADR-004 (AO en el X-13 del objetivo) no alcanza a las predictoras ni a sus rezagos |
| `MULT.BVAR.G3` | **Descartada**: la media se reproduce bit a bit y la recursión por extracción promedia a ella | No hay indicio: la aceptación está dentro de la banda (0,25-0,45) | **Sí, en el pronóstico puntual**: la media de una predictiva de cola pesada, en log-niveles y con el origen en el choque, la dominan las extracciones explosivas, y no hay restricción de estacionariedad |

Los demás casos del barrido (UC, VAR_DIF en R6) son todos del origen 2020-Q2. Su sendero prolonga la caída del
trimestre de origen. Es la misma familia (especificación frente al choque), con una magnitud mucho menor.

## 6. Lo que no se puede concluir

- Si otra especificación habría ganado en Fase 5: no se corrió ninguna alternativa, y hacerlo sería una nueva
  comparación posterior a los resultados.
- Si el problema aparece fuera del episodio de 2020: en la L4 no hay ningún otro caso sobre el umbral, pero el umbral
  es descriptivo y la muestra tiene un solo choque de esa magnitud.

## 7. Implicaciones para Fase 6 (para las fichas; no se decide aquí)

- **F6-08 (guarda de plausibilidad).** Los casos reales caen todos sobre el doble del máximo histórico absoluto. Una
  guarda de rango los habría detectado, pero el umbral sigue siendo tuyo.
- **F6-02 (combinación).** La mediana entre modelos no se mueve por un miembro explosivo. La media sí.
- **El BVAR en el Ejercicio B.** Con h = 20, las extracciones con raíz mayor que 1 se componen durante más pasos:
  1,05^20 ≈ 2,65 frente a 1,05^8 ≈ 1,48. Antes de usar la media del BVAR en B hace falta una ficha: mediana,
  truncamiento de las extracciones explosivas o restricción de estacionariedad.
- **Forma directa.** Si algún modelo directo vuelve a usarse, conviene una guarda de extrapolación de la fila del
  origen (cuántas desviaciones de la ventana). F6-01 ya los deja fuera de B.
