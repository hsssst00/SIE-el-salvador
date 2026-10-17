# Protocolo de la evaluación prospectiva AP-2 (preregistro)

**Estado:** decidido por Harold el 2026-10-15 (fichas AP2-1 a AP2-5, todas en la opción recomendada). Falta
implementarlo (ver §6). Este documento fija las reglas **antes** del primer target de la prospectiva. Ninguna
lectura descriptiva puede cambiarlas. Un cambio de regla crea una prospectiva nueva con su propio documento.

**Por qué existe.** La ventaja descriptiva de `MIX.PUENTE` en Fase 5 se notó después de ver los resultados, y la
parte descriptiva de AP-2 (`reportes_fase5/posteriores/ap2_estabilidad_puente.md`) muestra que con h = 1 se concentra
en 2020-2021. Retrospectivamente, toda evaluación comparte targets con Fase 5. Fuera de muestra de verdad solo están
los trimestres que todavía no se publicaron.

## 1. Qué se compara (AP2-1)

- **Hipótesis primaria:** en cada grupo k ∈ {G1, G2, G3} y h ∈ {1, 2}, `MIX.PUENTE.Gk` tiene menor pérdida cuadrática
  esperada que `BENCH.RW_SIN_DERIVA` (el benchmark del protocolo, F4-07). Son 6 comparaciones.
- **Descripción:** los 50 modelos de Fase 5 (32 modelos, 12 combinaciones y 6 benchmarks), con sus YAML congelados,
  se reestiman en cada origen nuevo, igual que en la corrida única. Sus métricas se reportan, pero no son hipótesis.

## 2. Regla de lectura (AP2-2)

- **Primaria:** DM/HLN (la de F4-16, con su varianza y sus gl) **unilateral** al 5 %, H1: E[d_t] > 0 con
  d = e_RW² − e_puente². Se reportan los 6 p-valores sin ajustar y con Holm. La conclusión se lee con Holm.
- **Secundaria:** el MCS (configuración de Fase 5: T_max, α = 0,10, B = 5 000, deduplicación B2-9) de los 7
  representantes de AP-4 (`decisiones_fase5.md`, «Representantes de AP-4»), que ya incluyen al puente.

## 3. Datos (AP2-3)

- **Tiempo real.** En cada origen, los modelos ven solo los vintages publicados hasta la fecha de esa corrida, tomados
  de L0 con su `fecha_publicacion`. El borde irregular es el que efectivamente se publicó, no el simulado por F5-04.
- **Target:** el valor del trimestre en el vintage del PIB publicado **4 trimestres después** del target, para que
  entren las primeras revisiones. La unidad y el ajuste estacional del objetivo son los de Fase 5 (X-13 reestimado en
  el origen, F4-09).

## 4. Congelamiento (AP2-4)

- Modelos, YAML, motor y esta regla se fijan en un commit con tag propio, `prospectiva-v1`, que se crea al terminar la
  implementación (§6). Cualquier cambio de código en un modelo o en el motor crea una prospectiva nueva
  (`prospectiva-v2`, …) y no edita la vieja.
- Cada trimestre se corre con una orden única que escribe su propia L4 y una fila de registro con el commit, el
  vintage de cada insumo y la fecha.
- **Primer origen:** 2026-Q2. Su target h = 1 (2026-Q3) no estaba publicado al congelar.

## 5. Cuándo se lee (AP2-5)

- **Lectura primaria:** cuando haya 20 targets valorados con h = 1 en los tres grupos (orígenes 2026-Q2 a 2031-Q1;
  el último target se valora con el vintage de 4 trimestres después). Ese día se aplica §2 una sola vez.
- **Lecturas descriptivas** una vez al año, sin inferencia. No cambian la regla ni la fecha de la lectura primaria.
- Referencia de potencia: V8 da 7-16 % ante una pérdida 20 % menor con n de 18 a 52. Con 20 targets, no rechazar no
  dirá que el puente no es mejor.

## 6. Lo que falta implementar (antes de que se publique el PIB de 2026-T3)

1. Un objetivo de `Makefile` (`make prospectiva ORIGEN=<trimestre>`) que arme el conjunto de información en tiempo
   real desde L0 por `fecha_publicacion`, corra los 50 modelos en ese único origen y escriba su L4 y su registro.
2. La valoración de los targets con el vintage de 4 trimestres después y el armado de §2. Las pruebas sintéticas van
   en CI.
3. El tag `prospectiva-v1` sobre el commit que cierre los puntos 1 y 2, con CI en verde.

## 7. Relación con Fase 6

La prospectiva no bloquea Fase 6. Hasta la lectura primaria, ninguna decisión de Fase 6 puede apoyarse en la ventaja
del puente como si estuviera verificada fuera de muestra.
