# AP-2 (parte descriptiva) — Estabilidad de `MIX.PUENTE` en el tiempo

**Análisis posterior a los resultados y no independiente.** Usa los mismos targets que Fase 5, así que describe
cómo se reparte la ventaja del puente en el tiempo, pero **no** reduce el riesgo de haberlo notado por suerte. Eso le
toca a la evaluación prospectiva de AP-2, que tiene su propio borrador de protocolo y se preregistra aparte. No
cambia nada de Fase 5.

**Fuente.** `src/analisis_posterior/ap2_estabilidad_puente.R`, sobre la L4 de `e1722fa` (corrida principal) y el
objetivo observado del corte. Los errores reconstruidos reproducen el RMSE de `metricas.csv`. Las tablas son
`ap2_bloques.csv` (845 filas) y `ap2_ventanas.csv` (323). El puesto 1 es el menor RMSE; compiten 23 modelos en G1, 22
en G2 y 21 en G3. Unidad: interanual en pp.

## 1. Por bloques de targets

Puesto del puente entre todos los modelos (y su RMSE relativo al paseo sin deriva), por bloque de targets:

| Grupo | Bloque | h = 1 | h = 2 | h = 4 | h = 8 |
|---|---|---|---|---|---|
| G1 | 2013-2016 | 8 (0,85) | 1 (0,64) | 1 (0,42) | 7 (0,33) |
| G1 | 2017-2019 | 17 (0,79) | 4 (0,39) | 5 (0,19) | 3 (0,19) |
| G1 | 2020-2021 | 2 (0,79) | 1 (0,88) | 2 (0,88) | 15 (0,99) |
| G1 | 2022-2026 | 22 (1,07) | 18 (0,77) | 11 (0,54) | 5 (0,46) |
| G2 | 2013-2016 | 2 (0,75) | 20 (0,65) | 14 (0,38) | — |
| G2 | 2017-2019 | 4 (0,59) | 7 (0,35) | 16 (0,27) | 14 (0,22) |
| G2 | 2020-2021 | 1 (0,40) | 1 (0,79) | 1 (0,90) | 11 (0,99) |
| G2 | 2022-2026 | 14 (0,96) | 13 (0,68) | 1 (0,37) | 6 (0,48) |
| G3 | 2020-2021 | 1 (0,48) | 1 (0,79) | 1 (0,69) | — |
| G3 | 2022-2026 | 13 (0,91) | 12 (0,68) | 1 (0,37) | 6 (0,48) |

(«—»: el bloque tiene menos de 4 targets.)

## 2. Ventanas móviles de 12 targets

| Grupo | h | Ventanas | Puesto 1 | Entre los 3 primeros | Puesto mediano | Peor puesto |
|---|---|---|---|---|---|---|
| G1 | 1 | 41 | 17 % | 61 % | 2 | 23 |
| G1 | 2 | 40 | 25 % | 42 % | 4 | 21 |
| G1 | 4 | 38 | 26 % | 42 % | 6 | 19 |
| G1 | 8 | 34 | 0 % | 3 % | 6 | 16 |
| G2 | 1 | 34 | 50 % | 62 % | 1,5 | 18 |
| G2 | 2 | 33 | 45 % | 48 % | 5 | 19 |
| G2 | 4 | 31 | 55 % | 65 % | 1 | 22 |
| G2 | 8 | 27 | 0 % | 4 % | 7 | 19 |
| G3 | 1 | 14 | 36 % | 36 % | 13 | 15 |
| G3 | 2 | 13 | 38 % | 38 % | 10 | 15 |
| G3 | 4 | 11 | 73 % | 73 % | 1 | 10 |
| G3 | 8 | 7 | 0 % | 0 % | 6 | 9 |

## 3. Lectura

- **Con h = 1, la ventaja del puente es sobre todo del episodio 2020-2021.** En ese bloque queda en el puesto 1 o 2
  en los tres grupos. En 2022-2026 cae al puesto 22 (G1), 14 (G2) y 13 (G3), y en G1 su RMSE pasa a ser mayor que el
  del paseo (1,07). Coincide con AP-4, donde la ventaja de MIX en h = 1 desaparece sin los targets de 2020-2021.
- **Con h = 4 es más estable:** en G2 y G3 es el primero en el bloque 2022-2026, y su RMSE es menor que el del paseo
  en todos los bloques y grupos. Su puesto, sin embargo, va del 1 al 16 según el bloque.
- **Con h = 8 nunca es el primero en ninguna ventana.**
- Nada de esto es inferencial: con 12 targets por ventana y ventanas solapadas, las diferencias de puesto entre
  modelos cercanos son en buena parte ruido. Si la ventaja se mantiene fuera de la muestra, lo dirá la evaluación
  prospectiva.
