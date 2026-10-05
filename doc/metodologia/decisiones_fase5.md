# Fase 5 — registro de decisiones de diseño

**Fecha:** 2026-10-03, actualizado el 2026-10-05 · **Estado:** F5-16 y F5-17 decididas por Harold el
2026-09-30; las decisiones de implementación del corte congelado (C-1 a C-8, abajo), el 2026-10-03; F5-01 a
F5-05, el 2026-10-05. F5-06 a F5-15 siguen pendientes de respuesta y entran a este documento cuando se
decidan (Regla 4); hasta entonces sus fichas no son vinculantes.

**Para qué sirve este documento.** Es el equivalente de `decisiones_fase4.md` para Fase 5: cada ficha lleva
la línea **DECIDIDO** con el texto operativo, y el Acta es el índice. Las correcciones posteriores entran
como notas fechadas; no se reescribe lo registrado.

---

## Acta de decisiones

| Código | Decisión adoptada | Documento enmendado |
|---|---|---|
| F5-01 | Núcleo + MIDAS/puente antes de los árboles; factoriales dinámicos fuera (extensión 4) | protocolo §7 (nota 2026-10-05) |
| F5-02 | Preregistro completo: todos los YAML antes de la corrida única sobre L3 | ninguno (continúa C8 y la nota I1) |
| F5-03 | Un `modelo_id` por grupo; guarda de 20 grados de libertad | ninguno aquí; la guarda se documenta al implementarla |
| F5-04 | Parte 1: trimestres completos, borde irregular solo en MIDAS/puente. Parte 2: UT mes a mes con rezago supuesto de 30 días (reabre F4-34) | decisiones_fase4.md F4-34 y protocolo §2.3 (notas 2026-10-05); evidencia de insumos |
| F5-05 | Iterada en los econométricos; directa en regularizados y ML | ninguno |
| F5-16 | Captura mensual en L0; evaluación de Fase 5 contra un corte de `vintage_id` congelado | protocolo §2.4 (nota 2026-10-03); especificación del motor §3 (nota 2026-10-03) |
| F5-17 | UT trimestral y manual (Regla 9) | ninguno aquí; ADR-007 (nota 2026-09-30) |
| C-1 a C-8 | Implementación del corte congelado: composición, ubicación, guardas y registro | los mismos que F5-16 |

---

## F5-01 — Alcance de Fase 5 y orden en que entran las familias

**DECIDIDO por Harold el 2026-10-05:** opción (b), el núcleo de la senda §9 más la extensión 1 adentro,
antes de los árboles.

- **Orden de implementación**, un PR por bloque y sin apilar: B1 ARIMA/ARIMAX y componentes no observados →
  B2 VAR/VECM/BVAR → B3 regularizados → B3b MIDAS y puente → B4 árboles → B5 combinaciones. Las
  combinaciones van siempre al final, porque se construyen con los pronósticos de las demás.
- **Fuera de Fase 5:** los factoriales dinámicos, declarados como extensión 4. `dfms` y `KFAS` no están
  fijados en `renv.lock` (nota de ADR-009) y con 39-60 observaciones en G2/G3 un factorial tiene poco que
  ofrecer. `midasr` 0.9 sí está fijado (verificado en `renv.lock` el 2026-10-05).
- **Consecuencia:** la comparación ARIMAX contra puente/MIDAS mide cuánto aporta el borde irregular de los
  datos mensuales, que es la ventaja del SIE (ver F5-04).
- Descartadas: (a) MIDAS y puente al final, que deja el borde irregular para el final o para nunca, y (c)
  todas las familias de §6.2-§6.7 con factoriales.

## F5-02 — Cuándo se corre sobre L3: preregistro del conjunto

**DECIDIDO por Harold el 2026-10-05:** opción (b), preregistro completo.

- Todos los YAML de Fase 5 se declaran (en uno o varios PR) antes de cualquier corrida sobre L3 (C8). Cada
  bloque se desarrolla y se verifica **solo con datos sintéticos** y en CI, y la corrida sobre L3 es una
  sola, con el conjunto congelado y el corte de F5-16.
- Cada bloque lleva su propio canario sintético (V14 y siguientes): por ejemplo, un DGP donde la predictora
  sí anticipa al objetivo y el modelo con predictoras debe ganarle al paseo.
- Razón: el MCS depende de qué modelos compiten, y la lección de I1 es que ver resultados antes de fijar
  especificaciones abre la puerta a especificaciones que se ajustan a lo que se vio. Cita del commit de
  congelamiento en el protocolo §6.
- Costo declarado: no hay un número real hasta la corrida única.
- Descartadas: (a) por bloque, y (c) híbrido con corridas exploratorias, cuya disciplina depende de la
  revisión y no del procedimiento.

## F5-03 — Asignación a grupos y muestra efectiva de los modelos con predictoras

**DECIDIDO por Harold el 2026-10-05:** parte 1 opción (a); parte 2 opción (i) con el umbral propuesto.

- **Asignación.** Los univariados corren en G1, G2 y G3, como los benchmarks. Cada modelo con predictoras
  corre en el grupo más largo que admite todas sus series, y en los grupos siguientes con el conjunto
  ampliado de ese grupo, como variante declarada con su propio `modelo_id` (por ejemplo `ARIMAX.G1` y
  `ARIMAX.G2`). El `modelo_id` significa lo mismo en todas las tablas. Descartada (b), un solo `modelo_id`
  con especificación según el grupo.
- **Piso de la muestra efectiva.** Guarda nueva en el motor, con `stop()` (Regla 7): observaciones efectivas
  menos parámetros ≥ **20** grados de libertad, con una prueba que verifique que el diseño la cumple en el
  primer origen de cada grupo. La grilla de rezagos se acota de antemano para que así sea. Contexto: en el
  primer origen de G2 y de G3 un modelo con predictoras estima sobre 39 datos en Δlog, antes de rezagos y
  dummies. Descartada (ii), sin guarda y con la muestra efectiva declarada en el manifiesto.
- Pendiente de implementar con B1 (no está en el PR que registra esta decisión).

## F5-04 — Alineación de las predictoras con el origen (borde irregular y UT)

**DECIDIDO por Harold el 2026-10-05.**

- **Parte 1, modelos trimestrales no-MIDAS (ARIMAX, VAR, regularizados, árboles): opción (c).** Solo
  trimestres completos: los agregados `.Q` (T003-T011) entran hasta `o` y los meses de `o+1` se ignoran. El
  borde irregular lo usan solo MIDAS y puente (B3b). Con esto, la diferencia entre ARIMAX y puente/MIDAS en
  h = 1 mide directamente el valor del borde irregular. La regla de alineación vive en una función (por
  ejemplo `rezago_alineacion(serie, grupo)`) con su prueba, que se implementa con B1.
- **Parte 2, predictoras que terminan antes del origen (UT): se reabre F4-34.2.** Harold respondió que UT
  se actualiza mensual, aclaró que quería UT mes a mes con un rezago en meses en lugar de la regla de años
  cerrados, y fijó el rezago en **30 días**. Reemplaza el rezago uniforme de 4 trimestres que proponía la
  ficha.
  - **Naturaleza del valor: supuesto declarado, no medición.** Lo observado son dos cotas superiores, solo
    de 2026: la bajada del 2026-08-26 (reporte de las 5:36 PM) ya traía julio, rezago ≤ 26 días; el reporte
    del 2026-09-30 de las 6:07 PM (archivo `14utdemtotal1790813271680.csv`, sha256
    `993a2204f28d4579d315382d09be22ccd63649385d0b295f0c8fcb7f0a56e80c`, no registrado en
    `08_vintages.csv`) ya traía agosto, rezago ≤ 30 días. Enero a julio no cambiaron entre las dos bajadas.
    De 2013-2025 no hay ninguna fecha real: los vintages de UT son archivos anuales con fecha sintética y la
    fuente no publica calendario.
  - **Efecto.** UT se trata como cualquier serie mensual: la `.M` entra hasta el último mes `m` con
    `fin(m) + 30 ≤ fin(o) + 92`, es decir, 2 meses de `o+1` en los 52 orígenes (como el ITCER); la `.Q`
    hereda el rezago de su `.M` y entra hasta `o`. Con el rezago de la ficha original, UT llegaba 1 a 4
    trimestres detrás del origen.
  - **Implementación (mismo PR):** la fila de UT del bloque `rezago_publicacion` de
    `evidencia_insumos_fase4.csv` pasa de `grano_de_disponibilidad = anual` a la métrica
    `rezago_dias_supuesto = 30`, distinta de `rezago_dias_mediano` para que la procedencia no se confunda;
    `rezagos_predictoras()` lee las dos métricas y se detiene si una serie es anual y trae rezago en días a
    la vez. La rama anual de `eval_lib.R` (`REZAGO_ANUAL_CERRADO`) se conserva como mecanismo, hoy sin
    series, con sus pruebas y su canario en V5.
  - **Riesgo declarado y revisión.** Un rezago supuesto demasiado corto filtra información del futuro a
    favor de los modelos con UT; uno demasiado largo solo pierde un mes de borde irregular en una
    predictora. El valor se revisa con una nota fechada si las consultas manuales de los meses siguientes o
    una respuesta de UT sobre su política de actualización lo contradicen. Esas consultas son manuales: la
    Regla 9 y el `robots.txt` de UT descartan automatizarlas.
  - **Sin efecto sobre Fase 4.** Los benchmarks no usan UT: los experimentos `F5_REPRO_*` y los resultados
    de Fase 4 no cambian.
  - **Pendiente de implementar con B1:** una guarda de completitud del borde (que los meses admitidos por el
    origen existan en la serie), que sustituye para UT a la guarda de año completo de F5-17 en el motor.
- Descartadas: parte 1 (a) y (b); parte 2 rezago uniforme de 4 trimestres, proyectar los trimestres faltantes
  de UT con un AR, y excluir UT de los modelos trimestrales.

## F5-05 — Estrategia multihorizonte y proyección de las predictoras

**DECIDIDO por Harold el 2026-10-05:** opción (a), iterada para los econométricos y directa para
regularizados y ML.

- ARIMAX y puente proyectan cada predictora dentro del origen con un AR(p)-BIC en Δlog (con dummies
  estacionales si es NSA), al estilo de `seleccionar_ar_bic()`. VAR y BVAR la proyectan de forma conjunta,
  por construcción.
- Regularizados y árboles estiman un modelo por `h` sobre el crecimiento acumulado
  `log y_{t+h} − log y_t`, con información en `t`. El sendero es `y_o + ĝ_h` y cumple el contrato sin
  modelos auxiliares.
- Razón: práctica estándar (Marcellino, Stock y Watson, 2006, sobre iterado contra directo) y conserva la
  forma canónica de cada familia. Descartadas: (b) todo directo, que deja de ser un ARIMAX en sentido
  estricto, y (c) todo iterado, que obliga a proyectar todas las predictoras para árboles que no
  extrapolan.

---

## F5-16 — Cadencia de actualización y corte de evaluación de Fase 5

**DECIDIDO por Harold el 2026-09-30.**

- **Captura (L0).** Periodicidad **mensual**: una ventana fija el día 1-3 de cada mes captura todo lo que el
  BCR publicó el mes anterior, de modo que no se pierde ningún vintage mensual (ADR-007: un vintage no
  capturado es irrecuperable). Descartadas: la trimestral atada al PIB, que pierde 2 de cada 3 vintages
  mensuales, y la captura por evento.
- **Evaluación.** Durante Fase 5 se **congela un corte**: el objetivo y las predictoras se filtran por los
  `vintage_id` que declara el corte. Las capturas nuevas entran a L0 y a `08_vintages.csv`, pero no a la
  evaluación, hasta el cierre de Fase 5.
- **Cómo se materializa: «L3 del corte desde L0».** L1 y L3 guardan un solo vintage por serie y no están
  versionados; solo L0 conserva cada vintage. El corte se declara en un CSV (`publicacion_id,vintage_id`);
  `make master CONJUNTO=<corte> SALIDA=<dir>` reconstruye L1/L2/L3 del corte desde L0 en un directorio
  propio (PR #27, `conjunto_lib.R`), y el motor lee de ahí. `make master` sin argumentos sigue actualizando
  la L3 vigente. Descartadas: no correr `make master` durante Fase 5 (un clon fresco no reconstruye el corte)
  y versionar la copia de L3 (choca con ADR-008).

## F5-17 — Mecanismo de actualización de UT (captura manual)

**DECIDIDO por Harold el 2026-09-30.**

UT no se automatiza: el `robots.txt` de ut.com.sv lo prohíbe (Regla 9). Captura **trimestral y manual**, en
las ventanas de enero, abril, julio y octubre: el año en curso y el último año que en L0 todavía no llega a
diciembre. Los años cerrados no se vuelven a bajar (límite declarado: una revisión de un año cerrado no se
detecta). `fecha_publicacion` sintética = último día del `periodo_referencia_max`. L3 y el motor se detienen
con `stop()` si un origen admite, por F4-34, un año cuyo archivo no llega a diciembre. Implementado en los
PR #25 y #26 y en `a7714f1` (guarda del año completo en la rama anual).

**Nota (2026-10-05, F5-04).** La parte de arriba sobre el `stop()` del motor por un año incompleto deja de
aplicar a UT: el motor ya no la admite por años cerrados sino mes a mes con un rezago de 30 días. La captura
trimestral y manual, la fecha sintética y la guarda de L3 (cada año cerrado trae sus 12 meses, en
`src/transformacion`) siguen vigentes. La guarda de año completo de `guarda_recorte()` se conserva en la rama
anual, que hoy no usa ninguna serie.

---

## Implementación del corte congelado (decidida por Harold el 2026-10-03)

Diagnóstico previo (2026-10-03, sin commits): con la captura de octubre, el vintage vigente del PIB en
`08_vintages.csv` pasó a `v2026-09`, y G-6 detiene `make eval` solo porque la L3 local quedó en `v2026-06`.
Una `make master` sin corte habría movido la evaluación, en silencio, a los datos nuevos.

- **C-1 · Composición.** **DECIDIDO:** los 36 vintages de 12 publicaciones de
  `doc/metodologia/corte_fase5.csv`, que son los de la L3 de la corrida de cierre de Fase 4: PIB NSA, SA y
  nominal `v2026-06`; retropolado `v2019-03`; IVAE `v2026-07`; remesas `v2026-08`; IPC `v2026-09`; balanza
  comercial (FOB) `v2026-07`; IPP `v2026-08`; ITCER `v2026-07`; índices de precios del comercio exterior
  (IPM) `v2026-07`; UT `v2002-12` a `v2025-12` y `v2026-07` (25). Es la propuesta de la ficha F5-16 más dos
  publicaciones que la ficha omitía: PIB SA `v2026-06` (lo usa R5) y PIB nominal `v2026-06`
  (`validar_conjunto()` exige todas las publicaciones de `03_series.csv`). Consecuencia: el PIB 2026-T2 no
  entra; el objetivo sigue en 1990-Q1..2026-Q1 (145 obs).
- **C-2 · Ubicación.** **DECIDIDO:** versionado en `doc/metodologia/corte_fase5.csv` (sha256 sin CR
  `901b0f7959b5cc40b82f376f469eaaa80adb931ecfcee4d7624910440021ff17`). Lo fija el commit que agrega el
  archivo (`git log -- doc/metodologia/corte_fase5.csv`); toda corrida de Fase 5 lo cita (protocolo §6).
  `tests/test-corte-motor.R` falla si el archivo cambia. La L1/L3 del corte que arma `make master` va en
  `data/conjuntos/corte_f5/` (no versionado).
- **C-3 · Sin corte.** **DECIDIDO:** `make eval` sin `CONJUNTO=` se detiene con `stop()` en el motor.
  `eval-sintetico` no cambia. No hay `CONJUNTO` por defecto en el Makefile: el `export` es global y también
  afectaría a `make master`.
- **C-4 · Registro.** **DECIDIDO:** ruta y sha256 sin CR del corte en `manifiesto.txt` (el corte entra
  además a la lista de insumos), y un séptimo campo opcional en el token de `esquema_validacion`:
  `|conjunto=<nombre>@<sha8>`, p. ej. `|conjunto=corte_fase5@901b0f79`. El esquema de `07_experimentos.csv`
  no cambia y ninguna fila de Fase 4 se toca.
- **C-5 · L1 frente a L3.** **DECIDIDO** (corregida el mismo día: la primera formulación suponía que L3 traía
  la NSA, y no la trae). L1 no tiene `vintage_id`. El motor recalcula
  `ajustar_estacional_propio(concatenar_pib_nsa(L1))` y exige igualdad **exacta** de período, valor y AO
  con `PIB_SA_PROPIO_Q.csv` y `PIB_SA_PROPIO_Q_outliers.csv` de la misma capa; si no, `stop()`. Con G-6 sobre
  el corte, prueba que L1 es la L1 de la que salió la L3 del corte. Evidencia (2026-10-03, L1/L3 locales del
  2026-09-30): diferencia 0 y texto idéntico; cambiar en 0,01 % un solo valor NSA cambia los 145 períodos.
  Límite: dos vintages con la NSA idéntica no se distinguen, pero tampoco cambian el ajuste por origen.
- **C-6 · Reproducción.** **DECIDIDO:** la corrida que reproduce Fase 4 sobre el corte usa `exp_id`
  `F5_REPRO_*` (uno por cada `F4_BENCH_*`), en `data/L4_experiments/` y en `07_experimentos.csv`. Criterio
  de aceptación: `make master CONJUNTO=… SALIDA=…` reproduce los sha256 sin CR de los cuatro insumos del
  motor de la corrida de cierre (`c4e8b39`), y cada `F5_REPRO_*` reproduce las tablas de su `F4_BENCH_*`
  salvo la columna `exp_id` y las columnas `cobertura_80`, `cobertura_95` y `crps` de `metricas.csv`, que en
  la corrida de cierre estaban vacías.
- **C-7 · Semillas de la reproducción.** **DECIDIDO:** cada `F5_REPRO_X` declara `semilla_exp = F4_BENCH_X`
  y el motor siembra con ella (modelos y MCS). El manifiesto lo declara.
- **C-8 · Experimentos de Fase 4.** **DECIDIDO:** los `exp_id` `F4_*` quedan cerrados: el motor se detiene
  con `stop()` si se le piden. `make eval CONJUNTO=…` corre por defecto los experimentos de Fase 5 (hoy, los
  `F5_REPRO_*`). `EXPERIMENTOS` de Fase 4 sigue declarado para V12 y para `tabla_resultados_fase4.R`, que
  relee los directorios del cierre.

**Uso.**

```
make master CONJUNTO=doc/metodologia/corte_fase5.csv SALIDA=data/conjuntos/corte_f5
make eval   CONJUNTO=doc/metodologia/corte_fase5.csv SALIDA=data/conjuntos/corte_f5
```
