# AP-4 — Comparación por familias de modelos (Fase 5, corrida principal)

**Análisis posterior a los resultados** (registro: `doc/metodologia/decisiones_fase5.md`, «Análisis posteriores»).
No cambia ningún modelo, YAML, experimento, tabla ni MCS de Fase 5, ni los tags. El MCS de representantes (§4) es
un contraste nuevo, posterior a los resultados.

**Fuente.** `src/analisis_posterior/ap4_familias.R`, sobre la L4 de `e1722fa` (`F5_G1`, `F5_G2`, `F5_G3`) y el
objetivo observado del corte. Los errores se reconstruyen desde `pronosticos.csv` y el script se detiene si no
reproducen el RMSE y el MAE de `metricas.csv`; en las 264 combinaciones de modelo, grupo y h los reprodujeron. Las
tablas son `ap4_miembros.csv` (264 filas), `ap4_familias.csv` (84) y `ap4_mcs_representantes.csv` (84). Familia =
prefijo del `modelo_id`. Unidad: interanual en pp.

**Cómo leer las columnas «mejor»:** el mejor miembro de una familia con 6 modelos (BENCH) tiene más oportunidades de
salir bajo que el de una familia con 2 (MIX, REG, ML). Por eso cada métrica se da también para el miembro mediano.

## 1. Precisión puntual (RMSE)

Menor RMSE de la familia (del mejor miembro):

| | h = 1 | h = 2 | h = 4 | h = 8 |
|---|---|---|---|---|
| G1 | MIX 3,16 (`UMIDAS`) | MIX 4,43 (`PUENTE`) | MIX 4,86 (`PUENTE`) | BENCH 5,65 (`ARP_BIC`); todas las familias entre 5,65 y 5,68 |
| G2 | MIX 1,88 (`PUENTE`) | MIX 4,24 | MIX 5,32 | BENCH 6,14; UNI y MIX 6,16 |
| G3 | MIX 2,82 (`PUENTE`) | MIX 5,74 | MIX 4,42 | BENCH 1,58; UNI 1,75; MIX 1,82 |

Es lo que ya decía la tabla de Fase 5: con h ≤ 4, la ventaja descriptiva de la frecuencia mixta; con h = 8, ninguna
familia se separa. En G3 con h = 4 y 8, el RMSE mediano de REG es 39,6 y 44,0, por el ENET explosivo (AP-1).

## 2. Calidad probabilística (CRPS y cobertura)

- **CRPS mediano.** MIX tiene el menor CRPS mediano con h = 1 y 2 en los tres grupos (G1: 1,19 y 1,87; G2: 1,22 y
  2,02; G3: 1,87 y 3,31) y con h = 4 en G1 (2,26) y G2 (2,65). En G3 con h = 4, MIX y BENCH quedan casi empatados
  (3,05 y 3,06). Con h = 8, el menor es BENCH en G2 (2,69) y G3 (1,40), y UNI en G1 (2,36, con BENCH en 2,38). COMB
  no tiene densidad (F5-12).
- **Cobertura al 80 % (mediana de la familia).** En G1 y G2, con h = 1, REG y ML quedan por debajo del nominal (G1: 0,70 y
  0,71; G2: 0,76 y 0,79), y BENCH, UNI y MULT por encima (0,83 a 0,85). En G1 con h = 2 se repite (REG y ML en 0,72).
  Las densidades de errores internos de los modelos directos (F5-12) resultan más estrechas que lo que realizan. En
  G3 con h = 1 las familias quedan entre 0,78 y 0,82.

## 3. Robustez ante extremos

**El nivel del RMSE lo fijan los targets de 2020-2021.** Por ejemplo, en G1 con h = 1 el RMSE mediano de BENCH es
4,33 con todos los targets y 0,92 sin los de 2020-2021. El RMSE recortado (sin el 10 % de errores cuadráticos más
grandes) da también 0,92.

**Sin 2020-2021, la ventaja de MIX en h = 1 desaparece** (RMSE mediano sin esos targets):

| h = 1 | BENCH | UNI | MULT | MIX | REG | ML | COMB |
|---|---|---|---|---|---|---|---|
| G1 | 0,92 | 0,95 | 0,93 | 1,11 | 0,99 | 1,04 | 0,94 |
| G2 | 0,90 | 0,88 | 1,02 | 1,12 | 1,12 | 1,16 | 0,89 |
| G3 | 1,00 | 1,05 | 1,18 | 1,69 | 1,51 | 1,40 | 1,03 |

En h = 1, el RMSE más bajo de MIX con todos los targets viene de los trimestres del choque, que el borde irregular
del puente y la U-MIDAS captan antes. Fuera de ese episodio, MIX está entre las familias de mayor RMSE en h = 1.
Esto es descriptivo y comparte los targets con Fase 5. Lo que haría falta para saber si se mantiene es la evaluación
prospectiva de AP-2.

**Error absoluto máximo.** En las celdas con targets de 2020, el peor error de cada familia está entre 19 y 54 pp, y
lo dan los trimestres del choque. En G3 con h = 8 no hay targets de 2020, y el peor error baja a 6 a 16 pp en BENCH,
UNI, MIX y ML. Las excepciones son REG en G3 (42 pp con h = 1, 334 con h = 4 y 349 con h = 8, el ENET de AP-1) y
MULT en G3 (75,8 con h = 4 y 128,8 con h = 8, el BVAR de AP-1), y COMB en G3 con h = 8 (31,5 pp, que hereda de esos miembros).

## 4. MCS de representantes

Representantes fijados por Harold antes de calcular (commit `502e88a`): `BENCH.RW_SIN_DERIVA`, `UNI.ARIMA`,
`MULT.VAR_DIF.Gk`, `REG.ENET.Gk`, `MIX.PUENTE.Gk`, `ML.RF.Gk` y `COMB.MEDIA.Gk`. Configuración de Fase 5 (T_max,
α = 0,10, B = 5 000, deduplicación B2-9), con la semilla propia `semilla_de("AP4_REP_<grupo>", "MCS", h)`.

**Resultado: los siete representantes quedan dentro del MCS en las 12 celdas de grupo × h.** El p-valor más bajo
es 0,121 (`REG.ENET.G3`, h = 8). `MIX.PUENTE` tiene p = 1 en todas las celdas salvo G3 con h = 8 (0,468). Con siete
modelos en lugar de 21 a 23, el MCS tampoco distingue entre familias. Valen las marcas de tamaño y potencia de Fase 4
(h = 4 y 8, y G3).

## 5. Lo que no se puede concluir

- Que una familia sea mejor que otra: el MCS no las distingue, y el ordenamiento descriptivo cambia al sacar
  2020-2021.
- Que la ventaja del puente en h = 1 se mantenga: con todos los targets depende del episodio de 2020-2021. La
  respuesta es la evaluación prospectiva (AP-2).

## 6. Implicaciones para Fase 6 (para las fichas; no se decide aquí)

- **F6-02.** No hay base inferencial para pesar familias; una combinación sin pesos por desempeño es coherente con
  esto.
- **F6-07.** Las densidades de los modelos directos cubren de menos con h = 1 en G1 y G2, pero F6-01 ya los deja fuera de
  B. En esas celdas, las de los econométricos cubren algo de más, lo que es conservador para bandas.
- **Horizontes largos.** Con h = 8, todas las familias quedan juntas (G1: mejores entre 5,65 y 5,68, medianas entre 5,66
  y 5,72). No hay evidencia de que
  la elección de familia importe mucho a horizonte largo, salvo por los casos explosivos.
