# AP-3 — Tamaño de Giacomini-White y del contraste de estabilidad

**Análisis posterior a los resultados** (registro: `doc/metodologia/decisiones_fase5.md`, «Análisis posteriores»).
No cambia ninguna prueba ni ningún resultado de Fase 5. Diseño aprobado por Harold el 2026-10-15 sin cambios.

**Fuente.** `src/analisis_posterior/ap3_tamano.R` (las funciones `prueba_gw()` y `prueba_cambio_diferencial()` del
motor, tal cual). Tabla: `ap3_tamano.csv`, 60 filas (2 pruebas × celdas × 3 DGP). 2 000 réplicas por celda y DGP;
todas las réplicas dieron una prueba definida. Error de Monte Carlo ≈ 0,005 al 5 % y ≈ 0,007 al 10 %.

**DGP bajo H0** (igual capacidad predictiva, esquema de V7: errores MA(h − 1) de innovaciones de varianza 1). D1:
normales independientes. D2: normales con correlación 0,9 entre modelos. D3: t5 reescalada, independientes.

## 1. Tamaño empírico al 5 % nominal

| Prueba | Celda (n) | D1 | D2 | D3 |
|---|---|---|---|---|
| GW | G1 h=1 (52) | 0,052 | 0,052 | 0,028 |
| GW | G1 h=2 (51) | 0,080 | 0,074 | 0,070 |
| GW | G1 h=4 (49) | 0,104 | 0,128 | 0,121 |
| GW | G1 h=8 (45) | 0,245 | 0,258 | 0,238 |
| GW | G2 h=1 (45) | 0,054 | 0,044 | 0,038 |
| GW | G2 h=2 (44) | 0,072 | 0,073 | 0,084 |
| GW | G2 h=4 (42) | 0,140 | 0,142 | 0,143 |
| GW | G2 h=8 (38) | 0,307 | 0,322 | 0,318 |
| GW | G3 h=1 (25) | 0,062 | 0,058 | 0,042 |
| GW | G3 h=2 (24) | 0,110 | 0,116 | 0,094 |
| GW | G3 h=4 (22) | 0,250 | 0,252 | 0,230 |
| GW | G3 h=8 (18) | 0,722 | 0,727 | 0,743 |
| Estabilidad | G1 h=1 (27/25) | 0,050 | 0,056 | 0,046 |
| Estabilidad | G1 h=2 (26/25) | 0,090 | 0,086 | 0,090 |
| Estabilidad | G1 h=4 (24/25) | 0,130 | 0,125 | 0,127 |
| Estabilidad | G1 h=8 (20/25) | 0,218 | 0,230 | 0,212 |
| Estabilidad | G2 h=1 (20/25) | 0,058 | 0,060 | 0,039 |
| Estabilidad | G2 h=2 (19/25) | 0,078 | 0,086 | 0,086 |
| Estabilidad | G2 h=4 (17/25) | 0,141 | 0,141 | 0,145 |
| Estabilidad | G2 h=8 (13/25) | 0,286 | 0,278 | 0,287 |

(n de GW: pares de DM; la prueba usa n − h. Estabilidad: n_pre/n_post.) El tamaño al 10 % sigue el mismo patrón y
está en el CSV; por ejemplo, GW en G3 con h = 8 da 0,79 a 0,81.

## 2. Lectura

- **h = 1: las dos pruebas tienen tamaño correcto** en los tres DGP. Con colas pesadas (D3) rechazan algo de menos en
  algunas celdas: GW 0,028 en G1, que es conservador.
- **h ≥ 2: las dos sobre-rechazan, y la distorsión crece con h y al bajar n.** Con h = 4, el tamaño va de 0,10 a 0,25;
  con h = 8, de 0,21 a 0,74. GW en G3 con h = 8 (10 pares útiles) rechaza H0 verdadera en el 72 % de las réplicas al 5
  %. La correlación entre modelos y las colas pesadas casi no cambian el resultado: la distorsión viene de la varianza
  HAC con pocos pares, no de la forma de los errores.
- **Para Fase 5:** la regla 5 del informe de lectura («GW y el contraste de estabilidad se informan, pero no sostienen
  conclusiones») era necesaria. Con h ≥ 2, un rechazo de cualquiera de las dos no es evidencia. Con h = 1 sí son
  interpretables, con su marca de n.

## 3. Ficha AP3-1 — Qué hacer con las dos pruebas (para que decidas; no se adopta nada)

Hay distorsión fuera de ±2 errores de Monte Carlo en casi todas las celdas con h ≥ 2, así que, como se acordó, va
una ficha.

- **(a) Restringir su uso a h = 1.** Con h ≥ 2 se publican con una marca nueva, `tamano_distorsionado_verificado`,
  que cita esta tabla.
  - A favor: no cambia ninguna prueba ni ningún resultado. Es lo que esta evidencia sostiene hoy.
  - En contra: deja sin prueba de estabilidad utilizable a los horizontes largos.
- **(b) Valores críticos de b fija** (Kiefer-Vogelsang; para DM, Coroneo e Iacone 2020), con la misma ventana.
  - A favor: es la corrección estándar en muestras chicas con HAC.
  - En contra: es una prueba nueva (la versión con b fija de la condicional de GW necesita su propia tabla de
    valores críticos), y habría que verificar su tamaño con este mismo Monte Carlo antes de usarla.
- **(c) Bootstrap** (por bloques o estacionario, como el del MCS) de los momentos de GW y de la regresión de
  estabilidad.
  - A favor: se adapta a n y h sin tablas.
  - En contra: más cómputo y otra prueba que verificar. Con 10 pares útiles (G3, h = 8) ningún bootstrap rescata
    mucho.
- **(d) (a) ahora, y (b) o (c) solo si Fase 6 o la prospectiva llegan a necesitar estas pruebas con h ≥ 2**, con su
  Monte Carlo antes de usarlas.

**Recomendación: (d).** Ni la evaluación prospectiva que adoptaste (DM con h = 1 y 2) ni las fichas de Fase 6 usan
GW ni el contraste de estabilidad.

**Nota sobre DM con h = 2.** La primaria de la prospectiva usa DM/HLN, no GW. V7 ya verificó su tamaño con h = 1 y 2
(≤ 0,063).
