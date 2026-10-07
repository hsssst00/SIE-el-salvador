# Fase 5 — registro de decisiones de diseño

**Fecha:** 2026-10-03, actualizado el 2026-10-05 · **Estado:** F5-16 y F5-17 decididas por Harold el
2026-09-30; las decisiones de implementación del corte congelado (C-1 a C-8, abajo), el 2026-10-03; F5-01 a
F5-15 y F5-04c, el 2026-10-05. Con eso las diecisiete fichas de Fase 5 están decididas.

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
| F5-04c | Experimento de robustez R7: los modelos con UT de G2 y G3 con UT a 61 días | protocolo §5 (nota 2026-10-05) |
| F5-05 | Iterada en los econométricos; directa en regularizados y ML | ninguno |
| F5-06 | Una ARIMAX por grupo con todas las predictoras, más una ARIMAX-IVAE en G2; UC con `StructTS` entra | ninguno aquí |
| F5-07 | G1 con VAR en diferencias, VAR en niveles, VECM y BVAR; G2 y G3 con VAR en diferencias y BVAR; UT entra al BVAR | ninguno aquí |
| F5-08 | U-MIDAS sin restricciones y ecuación puente | ninguno aquí |
| F5-09 | Un solo elastic net con α elegido, más PCR; PLS y predictores dirigidos fuera | ninguno aquí |
| F5-10 | Random forest (`ranger`) y LightGBM; sin importancia por permutación | ninguno aquí |
| F5-11 | Validación anidada con K = 12, reoptimizando en cada origen (solo en Q1 si el costo medido no da) | ninguno aquí |
| F5-12 | Densidad analítica en los lineales (sistema conjunto en ARIMAX y puente); predictiva posterior en el BVAR; covarianza de errores internos en regularizados y árboles; combinaciones fuera | protocolo §3, punto 4 (nota 2026-10-05) |
| F5-13 | Miembros: todos los modelos de Fase 5 del grupo; media, mediana, recortada al 10 % e inversa al ECM con δ = 0,9 | ninguno aquí |
| F5-14 | Principal, R3, R4 y R7 para todos; R1, R2, R5 y R6 bajo un tope medido con datos sintéticos | protocolo §5 (nota 2026-10-05) |
| F5-15 | Un hilo, semilla del motor y doble corrida en CI; tolerancia declarada solo para la paridad Windows/Linux del BVAR | protocolo §6 (nota 2026-10-05) |
| B1-1 a B1-5 | Implementación de B1: forma y grillas del ARIMAX, experimentos por grupo, B1 en dos PR, densidad del sistema ARIMAX | especificación del motor §3 (nota 2026-10-05) |
| B1b-1 | Remesas nominales y reales juntas en la ARIMAX de G3: se mantienen, con guarda numérica (decisión delegada al agente) | `UNI.ARIMAX.G3.yaml`; especificación del motor §2 y §4 (nota 2026-10-05, B1b) |
| B1b-1 (reabierta) | Por parsimonia, la ARIMAX de G3 lleva solo las remesas nominales (decisión de Harold; reemplaza a la fila anterior) | `UNI.ARIMAX.G3.yaml`; nota fechada en «Implementación del bloque B1b» |
| B1b-2 | En G3, todos los modelos sin penalización llevan una sola remesa (la nominal); BVAR, regularizados y árboles, las ocho | `predictoras_no_penalizadas()` en `eval_lib.R`; F5-06 y F5-07 (notas 2026-10-05) |
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

## F5-04c — Robustez del rezago supuesto de UT

**DECIDIDO por Harold el 2026-10-05.** UT entra a modelos de G2 y G3 (F5-04, F5-06 a F5-10), así que un rezago
real mayor que el supuesto de 30 días daría a esos modelos una ventaja que no es real.

- Un **experimento de robustez aparte**, código **R7** (el código lo asignó el agente, siguiendo R1 a R6 del
  protocolo §5), que repite los modelos con UT de G2 y G3 con UT a **61 días** (como el IVAE y el IPM: 1 mes de
  `o+1` en lugar de 2), con su propio `exp_id`. No agrega columnas al MCS principal.
- Se declara antes de la corrida única (F5-02), con su nota fechada en el protocolo §5. El costo de cómputo
  de los modelos con UT (el BVAR es el más caro) entra a F5-14, todavía pendiente.
- Descartadas: sumar una variante sin UT (responde otra pregunta, el valor de UT) y no hacer experimento,
  que dejaría los resultados de G2 y G3 dependiendo de un supuesto sin acotar.

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

## Nota previa a F5-06 y siguientes (2026-10-05)

Las fichas v4 de F5-06 a F5-10 daban por vigente que UT «va hacia atrás» (1 a 4 trimestres de atraso, regla de
años cerrados de F4-34). Con F5-04 ese hecho dejó de valer: UT entra como las demás mensuales, con el trimestre
`o` completo y 2 meses de `o+1`. Lo decidido abajo ya lo incorpora. En cada ficha, la tabla de «especificación
propuesta» es la base de los YAML y no una decisión cerrada en sus parámetros finos (rejillas, orden máximo,
número de rondas): esos se fijan en cada YAML (C8), que Harold revisa en el PR de su bloque.

## F5-06 — Univariados (§6.2): ARIMA, ARIMAX y componentes no observados

**DECIDIDO por Harold el 2026-10-05:** las dos opciones recomendadas.

- **ARIMAX.** Una por grupo con **todas** las predictoras del grupo (G1: 2; G2: 6, UT incluida; G3: 8), más una
  sola ARIMAX con el IVAE en G2 como referencia, porque el IVAE es el candidato más obvio. Los `modelo_id`
  siguen F5-03: `UNI.ARIMAX.G1`, `.G2`, `.G3`; el de la referencia lo fija su YAML.
- **Componentes no observados.** Entra `UNI.UC_LLT`: tendencia lineal local con `stats::StructTS(type = "trend")`
  sobre el log-nivel SA, G1 a G3, sin dependencias nuevas (`KFAS` no está fijado).
- **Base de los YAML (tabla de la ficha v4).** `UNI.ARIMA` con `fable::ARIMA` sobre el log-nivel SA, BIC, `d` por
  KPSS dentro del origen, sin parte estacional; las ARIMAX suman el Δlog de las predictoras (rezagos 0..1,
  alineadas según F5-04), con dummies estacionales para las NSA y las predictoras proyectadas por AR(p)-BIC
  (F5-05).
- **Piso de F5-03.** Cuenta aproximada con las cifras de las fichas (39 datos en Δlog en el primer origen, 3
  dummies): en G2 con rezagos 0..1 quedan unos 24 grados de libertad, es decir `p + q ≤ 3` con constante; en G3
  las 8 predictoras con rezagos 0..1 suman 16 + 3 dummies = 19 parámetros antes de `p`, `q` y la constante, sin
  margen. Los YAML de G2 y G3 acotan rezagos y grilla de antemano, y la guarda de F5-03 lo verifica en el primer
  origen de cada grupo.
- Descartadas: una ARIMAX por predictora, solo las de grupo sin la referencia IVAE, y dejar el UC fuera del núcleo.
- **Nota (2026-10-05, B1b-1 y B1b-2).** En G3, «todas las predictoras del grupo» se lee como las de
  `predictoras_no_penalizadas("G3")`: la ARIMAX de G3 lleva 7, sin las remesas reales (ver «Implementación del bloque
  B1b»).

## F5-07 — Multivariados (§6.3): VAR, VECM y BVAR

**DECIDIDO por Harold el 2026-10-05:** las opciones recomendadas, más una decisión nueva sobre UT.

- **Modelos por grupo.** G1: `MULT.VAR_DIF.G1`, `MULT.VAR_NIV.G1`, `MULT.VECM.G1` (PIB SA + remesas + FOB) y
  `MULT.BVAR.G1`. G2: `MULT.VAR_DIF.G2` (PIB SA + IVAE + remesas) y `MULT.BVAR.G2`. G3: `MULT.VAR_DIF.G3` y
  `MULT.BVAR.G3`. La ficha no decía qué VAR corre en G3: se completó con las mismas tres variables que en G2 al
  preparar la pregunta, y Harold lo confirmó al elegir la opción.
- **UT entra al BVAR.** El BVAR usa todas las series trimestrales del grupo, UT incluida (7 series en G2 y 9 en G3,
  con 39 datos y p = 4; en G1, 3). La ficha la excluía por el atraso de 1 a 4 trimestres, que ya no existe. Así el
  BVAR ve el mismo conjunto de predictoras que los demás modelos del grupo.
- **Base de los YAML.** `vars::VAR` con p ∈ 1..4 por BIC y dummies estacionales exógenas para las NSA; VAR en
  niveles sin imponer raíces unitarias; VECM por Johansen dentro del origen (si r = 0 se estima el VAR en
  diferencias y se registra); BVAR de Giannone, Lenza y Primiceri (2015) con `BVAR::bvar`: Minnesota jerárquica,
  *sum-of-coefficients* y *single-unit-root*, log-niveles, p = 4, 10 000 extracciones y 5 000 de quemado.
- **Costo.** El BVAR con MCMC en cada origen es la pieza más cara; se mide en F5-14, pendiente.
- Descartadas: VAR solo en G1 con G2 y G3 solo BVAR, y sumar VAR en niveles y VECM en G2.
- **Nota (2026-10-05, B1b-2).** En G3 el VAR (y el VECM, si aplica) lleva la remesa nominal, no la real
  (`predictoras_no_penalizadas()`); el BVAR, con su penalización, conserva las 9 series de G3.

## F5-08 — Frecuencia mixta (§6.4): U-MIDAS y ecuaciones puente

**DECIDIDO por Harold el 2026-10-05:** la opción recomendada.

- `MIX.UMIDAS.Gk` y `MIX.PUENTE.Gk` por grupo. U-MIDAS **sin restricciones** con `midasr` 0.9 (ya fijado): Δlog
  trimestral del PIB SA sobre los Δlog mensuales de las predictoras del grupo, 0..5 meses de rezago más los
  meses conocidos de `o+1`, directo por `h` (F5-05). Sin optimización no lineal, reproducible con pocos datos.
- Los orígenes siguen siendo trimestrales y el *nowcasting* mensual queda fuera del MCS (protocolo §7). UT aporta 2
  meses de `o+1`, como el ITCER. El piso de F5-03 acota los rezagos mensuales en cada grupo y se declara en el
  YAML.
- Ecuación puente: cada mensual se completa hasta el final del horizonte con un AR(p)-BIC mensual (dummies si es
  NSA) y se agrega con la regla de T00x; regresión del Δlog trimestral del PIB SA sobre los agregados
  contemporáneos, más un AR(1) del PIB.
- Descartadas: MIDAS con polinomio (Almon o beta), que exige optimización no lineal con 39 datos, y tener ambos.

## F5-09 — Regularizados (§6.5)

**DECIDIDO por Harold el 2026-10-05:** las dos opciones recomendadas.

- `REG.ENET.Gk`: **un solo** modelo con `glmnet`, α ∈ {0, 0,5, 1} y λ elegidos por validación anidada (F5-11),
  dummies sin penalizar; y `REG.PCR.Gk` con componentes principales (`prcomp`), k ∈ 1..5 por validación anidada.
  Predictores en `t`: Δlog del PIB con rezagos 0..3 y Δlog de cada predictora del grupo con rezagos 0..3,
  alineadas según F5-04, más las dummies; estandarización dentro de la ventana de estimación; directo por `h`
  (F5-05). El piso de 20 grados de libertad de F5-03 no aplica a los modelos penalizados.
- **PLS y predictores dirigidos (Bai y Ng, 2008) quedan fuera del núcleo**, declarados como extensión: `pls` no está
  fijado en `renv.lock` (verificado el 2026-10-05) e incluirlo exigiría una nota de seguimiento de ADR-009.
- Descartada: ridge, LASSO y elastic net como tres modelos, que triplican las columnas del MCS con modelos casi
  idénticos.

## F5-10 — Árboles (§6.6)

**DECIDIDO por Harold el 2026-10-05:** la opción recomendada.

- `ML.RF.Gk` con `ranger` 0.18.0 (500 árboles, `mtry` ∈ {⌈p/3⌉, ⌈√p⌉}, `min.node.size` ∈ {3, 5}) y `ML.LGBM.Gk` con
  `lightgbm` 4.7.0 (`num_leaves` ∈ {4, 8}, `learning_rate` = 0,05, `min_data_in_leaf` = 5, rondas por
  validación anidada, máximo 500), con los mismos predictores que F5-09 y directos por `h`. Los dos paquetes ya
  están fijados; `randomForest` y `xgboost` no.
- Un representante de *bagging* y uno de *boosting*, como pide la senda. Con 39-90 datos LightGBM está en el
  límite de lo razonable, y el resultado probable (que no le gane al paseo) es informativo.
- La importancia por permutación (no por impureza, senda §6.6) queda fuera de Fase 5.
- Descartada: solo RF con LightGBM como extensión.

---

## F5-11 — Validación anidada (esquema común para regularizados y ML)

**DECIDIDO por Harold el 2026-10-05:** la opción recomendada.

- Dentro de cada origen `o` y cada `h`, validación pseudo-fuera-de-muestra interna sobre los últimos **K = 12**
  orígenes internos de `[inicio, o]`: se estima con datos ≤ `o'` y se evalúa el crecimiento acumulado en
  `o' + h ≤ o`; se elige el hiperparámetro que minimiza el ECM interno. Aplica a α y λ del elastic net, `k` del
  PCR, las rejillas de RF y las rondas de LightGBM. G-1 impide usar datos posteriores a `o`, porque `ajustar()`
  no los recibe.
- **Reoptimización en cada origen**, simétrica con la selección por BIC de los econométricos. Si el costo
  medido con datos sintéticos (F5-14) supera el tope, se pasa a reoptimizar solo en los orígenes Q1 y reutilizar
  la elección en los otros tres; esa variante se declara en el YAML **antes** de la corrida sobre L3.
- Con 39 datos en el primer origen de G2 y G3, K = 12 deja unos 27 para la primera estimación interna.
- Descartada: K proporcional ⌊n/4⌋, que cambia el criterio de selección a lo largo de la muestra.

## F5-12 — Densidad de los modelos nuevos

**DECIDIDO por Harold el 2026-10-05:** las dos opciones recomendadas. El motor evalúa la gaussiana conjunta del
sendero (F4-33, `predecir_densidad()`); lo que no la emite queda con las columnas vacías y se declara.

- **Lineales gaussianos (ARIMA, UC, VAR, VECM):** covarianza analítica con los pesos MA (`cov_desde_pesos()`, ya en
  `eval_lib.R`). *Plug-in* en los parámetros.
- **ARIMAX y puente:** el modelo y el AR(p)-BIC de sus predictoras (F5-05) se tratan como un **sistema lineal
  conjunto** y la covarianza sale de su forma compañera. Sigue siendo *plug-in* en los parámetros, pero no ignora
  la incertidumbre de las predictoras proyectadas. Descartadas: la covarianza condicional a la proyección, que
  subestima la varianza, y dejarlos sin densidad.
- **BVAR:** media y covarianza de la **predictiva posterior**, que sí incluye la incertidumbre de parámetros. Como
  el contrato exige `media` = sendero, el sendero puntual del BVAR es la **media** posterior y no la mediana; el
  manifiesto lo declara.
- **Regularizados y árboles:** gaussiana con la covarianza empírica `h × h` de los errores **fuera de muestra
  internos** del crecimiento acumulado (los de F5-11, o los OOB en RF). Se declara que la varianza sale de errores
  internos y no de un modelo de probabilidad. Encaja en el contrato sin cambiar el motor. Con K = 12 pares
  internos esa covarianza es ruidosa; se reporta como límite. Descartadas: dejarlos fuera de la calibración y los
  cuantiles (extensión 6 de la senda, que exige un CRPS por muestras en el motor y un bloque nuevo en V13).
- **Combinaciones:** fuera de la calibración (una mezcla de gaussianas no es gaussiana).
- Enmienda el protocolo §3, punto 4, que dejaba fuera a los «árboles sin bootstrap».

## F5-13 — Combinaciones (§6.7)

**DECIDIDO por Harold el 2026-10-05:** las dos opciones recomendadas.

- **Miembros:** todos los modelos de Fase 5 del grupo, **sin los benchmarks**, fijados en el YAML de cada
  combinación antes de la corrida única (F5-02). Así la combinación mide lo que aportan los modelos nuevos y los
  benchmarks siguen siendo la referencia. Descartados: sumar los benchmarks, que contamina la comparación contra
  ellos, y elegir miembros por desempeño, que es selección con resultados.
- **Esquemas, cuatro por grupo:** media simple, mediana, media recortada al 10 % y pesos inversos al ECM con
  descuento δ = 0,9 (Stock y Watson, 2004). En el origen `o` y horizonte `h` solo se usan los errores de pares con
  `o' + h ≤ o`; hasta acumular **8** errores los pesos son iguales, y se declara. La regla es la misma en los tres
  grupos.
- Descartadas: la regresión de combinación restringida (con 18-52 pares por celda; la senda la condiciona a que el
  número de orígenes lo permita), solo los tres esquemas sin parámetros, y los orígenes de calentamiento antes de
  2013-Q1, que solo serían viables en G1.
- Implementación: las combinaciones no caben en `correr_backtest()` como un modelo más; son un paso posterior del
  orquestador sobre `pronosticos.csv` (B5, al final).

## F5-14 — Batería de robustez y costo de cómputo

**DECIDIDO por Harold el 2026-10-05:** la opción recomendada.

- **Siempre, para todos los modelos de Fase 5:** la principal, R3 y R4 (submuestras de la principal, cómputo
  cero) y R7 (UT a 61 días, F5-04c; solo los modelos con UT de G2 y G3).
- **R1, R2, R5 y R6:** para todos los modelos, salvo que el tiempo medido supere un **tope declarado**. Si lo
  supera, esas cuatro corren solo para los univariados, las combinaciones y **un representante por familia**,
  decididos antes de ver resultados.
- **Paso previo:** medir el tiempo por origen de cada familia con datos sintéticos (sin mirar L3). Con esa cifra se
  fijan el tope y, si hace falta, los representantes, en un commit anterior a la corrida sobre L3 (protocolo §6,
  nota I1). La misma medición decide la variante de F5-11.
- Referencia hoy, en la máquina de Harold: los 13 experimentos de benchmarks tardan unos 5 minutos y V1-V13 unos 5
  a 6. El BVAR y la validación anidada son las piezas que multiplican el tiempo.
- Descartadas: todos los modelos en todos los experimentos, y solo la principal con R3, R4 y R7.

## F5-15 — Reproducibilidad bit a bit

**DECIDIDO por Harold el 2026-10-05:** la opción recomendada.

- `ranger` con `num.threads = 1`; `lightgbm` con `num_threads = 1`, `deterministic = TRUE` y
  `force_row_wise = TRUE`; la semilla del motor (`semilla_de()`) pasada explícitamente (`seed =`). Todo fijado en
  los YAML. `fable::ARIMA` con `stepwise = FALSE` es determinista.
- **BVAR:** semilla del motor. Sus resultados dependen de la BLAS, así que la paridad Windows/Linux se verifica
  como en el cierre de Fase 4 y, si no es bit a bit, se declara la tolerancia. Esa tolerancia aplica solo a la
  comparación entre sistemas operativos: en una misma máquina, `make eval` debe regenerar bit a bit
  `data/L4_experiments/<exp_id>/` (protocolo §6).
- **CI:** un bloque nuevo corre dos veces el mismo experimento sintético con los modelos de Fase 5 y compara los
  hashes, como V10 hace hoy con los seis benchmarks.
- Costo declarado: un solo hilo hace más lentos RF y LightGBM, y entra a la medición de F5-14.
- Descartadas: sin el bloque de CI de doble corrida, y multihilo con tolerancia, que rompería el «bit a bit» del
  protocolo §6.

---

## Implementación del bloque B1 (decidida por Harold el 2026-10-05)

Al bajar F5-03, F5-04, F5-06 y F5-12 a código aparecieron cinco puntos que las fichas no fijaban. Todos se
resolvieron en la opción recomendada.

- **B1-1 · Forma del ARIMAX.** `fable::ARIMA(y ~ x)` es una regresión con errores ARIMA y, si elige d = 1, diferencia
  también los regresores: con la ficha literal el modelo regresaría Δy sobre ΔΔlog x, contra F4-06. **DECIDIDO:**
  el ARIMAX trabaja en Δy con **d = 1 fijo**: `Δy_t = c + β'x_t + η_t`, con η ARMA(p, q) por BIC, `x` = Δlog de las
  predictoras (rezagos según B1-2) y dummies estacionales si hay predictoras NSA. El sendero es `y_o` más la suma de
  los Δy pronosticados. `UNI.ARIMA` sigue con d por KPSS. Descartada: la regresión sobre log-niveles con d por KPSS,
  que con d = 0 es una regresión en niveles y con d = 2 trabaja en segundas diferencias.
- **B1-2 · Grillas del ARIMAX, fijas en todos los orígenes del grupo.** Cuentas con L3 en el primer origen de cada
  grupo (constante y 3 dummies si hay NSA): G1 (2 predictoras, inicio común 1994-Q1) tiene 75 observaciones; G2 (6,
  inicio común 2005-Q1) con rezagos 0..1 tiene 38 observaciones y 16 parámetros, así que `p + q ≤ 2`; G3 (8, inicio
  común 2010-Q1) con rezagos 0..1 no cabe ni con p = q = 0. **DECIDIDO:** G1 rezagos 0..1 con p, q ≤ 2; G2 rezagos
  0..1 con p + q ≤ 2; G3 solo rezago 0 con p, q ≤ 2; ARIMAX-IVAE de G2 (IVAE es SA, sin dummies) rezagos 0..1 con
  p, q ≤ 2. Descartadas: solo rezago 0 en todos, y candidatos filtrados por origen (no es «acotado de antemano»).
- **B1-3 · Experimentos.** **DECIDIDO:** un experimento principal por grupo, `F5_G1`, `F5_G2` y `F5_G3`, con los seis
  benchmarks y todos los modelos de Fase 5 del grupo (registro `modelos_fase5()` en
  `src/evaluacion/modelos_fase5.R`), con R3 y R4 sobre la principal como en Fase 4; las variantes como `F5_Gk_Rn`.
  Así hay un solo MCS por grupo y horizonte. Descartado: un experimento por grupo y familia.
- **B1-4 · Dos PR, uno después del otro y sin apilar.** **DECIDIDO:** B1a, infraestructura (lectura de predictoras del
  corte con G-6, composición de grupos de F4-05 en código, `rezago_alineacion()`, guarda de completitud del borde,
  guarda de grados de libertad y experimentos); B1b, cuando B1a esté en `main`, los modelos (ARIMA, ARIMAX,
  ARIMAX-IVAE y UC), sus YAML, densidades y el canario V14. Es una excepción declarada a «un PR por bloque» de F5-01.
- **B1-5 · Covarianza de las innovaciones del sistema ARIMAX (F5-12).** **DECIDIDO:** la covarianza muestral
  contemporánea **completa** de los residuos del ARIMAX y de los AR de sus predictoras, en la misma muestra del
  origen. Sigue siendo *plug-in*. Descartada: la diagonal (innovaciones independientes).

**Decisiones menores del agente en B1a** (revertibles en un commit; ninguna cambia un resultado de Fase 4):

- Las dos guardas nuevas se llaman **G-7** (borde incompleto, F5-04) y **G-8** (grados de libertad, F5-03), después de
  G-1 a G-6. G-7 corre en `correr_backtest()` sobre toda predictora con rezago en días; G-8, sobre los modelos que
  declaran `piso_gl = TRUE` en su contrato y devuelven `gl = c(n_obs, n_par)` en su ajuste. Los benchmarks no
  declaran `piso_gl` y los modelos penalizados y de árboles lo declararán `FALSE` (F5-09). `PISO_GL = 20` vive en
  `eval_lib.R`.
- **Candado del preregistro (F5-02):** `PREREGISTRO_FASE5_CERRADO <- FALSE` en `motor_backtesting.R`. Mientras esté
  abierto, `make eval` corre solo los `F5_REPRO_*` y pedir un `F5_G*` se detiene con `stop()`; los `F5_G*` se ejercen
  con datos sintéticos en `tests/`. Lo cierra el commit de congelamiento del preregistro (E1 del checklist).
- La composición de predictoras de cada grupo (`GRUPOS_PREDICTORAS`, `predictoras_grupo()`) se toma de las listas de
  `scripts/evidencia_insumos_fase4.R` con las que se calcularon los primeros orígenes de F4-05, y una prueba compara
  las dos.

**Punto para B1b (no decidido).** Por esa composición, G3 trae a la vez remesas nominales y reales, cuyos Δlog
trimestrales correlacionan alrededor de 0,99 (evidencia de F4-23). En la ARIMAX de G3, con todas las predictoras del
grupo (F5-06), eso es casi colinealidad. Se presenta como pregunta antes de escribir el YAML de `UNI.ARIMAX.G3`.

## Implementación del bloque B1b (2026-10-05)

- **B1b-1 · Remesas nominales y reales en la ARIMAX de G3.** Se presentó como pregunta con tres opciones (mantener las
  dos con una guarda numérica, quitar las reales de la ARIMAX de G3, o sustituirlas por el deflactor implícito). Harold
  **delegó la decisión al agente** («use your best judgment», 2026-10-05), que tomó la opción recomendada:
  **se mantienen las dos**, como dice F5-06. Razón: Δlog real = Δlog nominal − Δlog deflactor (IPC, T004), así que en
  una regresión lineal tener las dos equivale a tener la nominal más la inflación del deflactor; los valores ajustados y
  el pronóstico puntual no dependen de cómo se reparte el efecto entre las dos, y la colinealidad solo infla la varianza
  de los coeficientes individuales y cuesta un grado de libertad (G3 tiene holgura con rezago 0). Se agrega una
  **guarda numérica** (Regla 7): la ARIMAX se detiene si la matriz de regresores con la constante pierde rango o si el
  número de condición de los regresores estandarizados supera 1e4, y `diagnosticos.csv` reporta en cada origen el
  número de condición y la correlación máxima entre predictoras. Descartadas: quitar las reales (contradice F5-06; la
  ARIMAX de G3 sería la de G2 más el IPP) y sustituirlas por el deflactor (crea una serie derivada que no está en el
  catálogo, del lado de transformación). Revertible en un commit si Harold prefiere otra opción.

**Decisiones menores del agente en B1b** (revertibles en un commit; ninguna cambia un resultado de Fase 4):

- **d por KPSS sin `feasts`.** `fable::ARIMA` calcula `d` con `feasts`, que no está en `renv.lock`. `diferencias_kpss()`
  aplica la misma regla con `urca::ur.kpss` (ya en Imports): KPSS en nivel con rezagos «short», se diferencia mientras
  rechaza al 5 %, hasta `d = 2`; rechazar con p < 0,05 equivale a superar el valor crítico del 5 % de la tabla que
  `feasts` interpola. El `d` elegido se pasa fijo a `fable::ARIMA`. Sin dependencias nuevas.
- **Constante del ARIMA solo con d ≤ 1** (regla de `forecast::auto.arima`): con `d = 2` sería una tendencia cuadrática
  en el log-nivel, que `fable` admite con una advertencia. Con `d ≤ 1` la elige `fable` por BIC.
- **Estimación de las ARIMAX con `stats::arima(method = "ML")`** sobre Δy con los regresores (forma de B1-1). Un
  candidato que no converge (error u `optim` con código distinto de 0) se descarta y se cuenta en `diagnosticos.csv`;
  si no converge ninguno, el motor se detiene.
- **G-8 con el mayor candidato de la grilla:** los modelos reportan `n_par` = constante + regresores + max(p + q) (en
  el ARIMA, p_max + q_max + 1), así que la guarda verifica en cada origen que toda la grilla cabe en el piso, que es lo
  que pide «acotado de antemano» (B1-2). En el primer origen de G2 quedan exactamente 20 grados de libertad.
- **AR(p)-BIC de las predictoras** (`seleccionar_ar_bic_x()`, F5-05): p en 0..4 sobre la muestra común de p = 4 y
  reestimado con la muestra máxima, con la historia de cada predictora hasta el origen (no la muestra común de la
  ARIMAX). La covarianza Σ de B1-5 se calcula con `stats::cov` (denominador n − 1) en los períodos donde existen todos
  los residuos.
- **Canal de diagnósticos.** Campo opcional `diagnosticar(ajuste)` en el contrato; `correr_backtest()` lo recoge por
  origen y el motor escribe `diagnosticos.csv` solo si algún modelo lo implementa. Los benchmarks no lo implementan, así
  que los `F5_REPRO_*` no cambian (prueba en `tests/test-modelos-univariados.R`).
- **`modelo_id` de la ARIMAX de referencia: `UNI.ARIMAX_IVAE.G2`** (F5-06 dejó el nombre al YAML).
- **UC:** si `StructTS` no converge (`optim` con código distinto de 0), el motor se detiene (Regla 7).
- **V14** (canario de B1b en la verificación sintética): DGP con predictora adelantada; la ARIMAX debe batir al
  AR(p)-BIC en h = 1, 2 con razón de RMSE < 0,8, cubrir al nominal en h = 1, 2, 4 dentro de ±3 ee de MC más una
  holgura de 0,03 (densidad *plug-in* con unas 90 observaciones), y no empeorar al AR(p)-BIC en más de 10 % en h = 1
  con una predictora placebo. 20 y 10 réplicas.
- **Costo observado (dato para B5 y F5-14, en el sandbox):** `UNI.ARIMA` con búsqueda exhaustiva tarda unos 3 a 4 s por
  origen (50 ajustes de `fable`); las ARIMAX, menos de 1 s. Del orden de 10 minutos para los tres experimentos
  principales; la medición formal es la de B5.

**Nota (2026-10-05, posterior; B1b-1 reabierta y B1b-2, decididas por Harold).** Al revisar el PR #32, Harold preguntó
por la interpretación de tener las dos remesas y luego, por parsimonia, si no convenía tener solo una. El agente
precisó lo dicho en B1b-1: la invariancia vale para los valores ajustados dentro de la muestra, pero no del todo
fuera de ella. Las dos remesas se proyectan con AR separados, y el modelo trae de forma implícita la inflación del IPC
con un coeficiente impreciso (β_r = −coeficiente de π), que se multiplica por una inflación grande si la relación
cambia fuera de la muestra, como en 2021-2022, dentro de la ventana de evaluación de G3. Los coeficientes individuales
no son interpretables; solo lo es la suma β_n + β_r. Se reabrió B1b-1 como pregunta (Regla 4), antes de cualquier
corrida sobre L3 y sin el PR fusionado.

- **B1b-1 (reabierta). DECIDIDO:** la ARIMAX de G3 lleva **solo las remesas nominales**: 7 predictoras, las 6 de G2 más
  el IPP. Razón: parsimonia con 39 observaciones en el primer origen; G1 ⊂ G2 ⊂ G3 queda encadenado, así que la
  diferencia con la ARIMAX de G2 mide solo el aporte del IPP; la nominal es el dato primario (las reales se derivan con
  T004) y su AR tiene historia desde 1991; la información de precios entra por el IPP y el IPM. Descartadas: solo las
  reales (la comparación con G2 mezclaría dos cambios y su AR solo tiene historia desde 2010) y mantener las dos (lo
  delegado, que esta nota reemplaza). La guarda de rango y número de condición sigue activa para todas las ARIMAX.
  Con 7 predictoras y rezago 0 quedan 24 grados de libertad en el primer origen de G3; las grillas de B1-2 no cambian
  (con rezagos 0..1 cabría solo p = q = 0: 38 observaciones y 18 parámetros).
- **B1b-2 · Alcance. DECIDIDO:** la regla es general para G3: **todos los modelos sin penalización** (ARIMAX, VAR, VECM,
  ecuación puente y U-MIDAS) llevan una sola remesa, la nominal; BVAR, regularizados (ENET, PCR) y árboles reciben las
  ocho predictoras del grupo, porque su penalización o su estructura manejan la redundancia. Vive en
  `predictoras_no_penalizadas(grupo)` y `PREDICTORAS_EXCLUIDAS_NO_PENALIZADOS` de `eval_lib.R`, que usan los bloques
  B2 y B3b. Descartado: decidirlo bloque por bloque.
- **Interpretación de G3 (para el informe):** con esta regla, lo que G3 agrega sobre G2 en los modelos sin
  penalización es el IPP; en los penalizados y los árboles, además, las remesas reales, que equivalen a la inflación del
  IPC (y, por la dolarización, a precios relativos con EE. UU.). Cuando un modelo trae las dos remesas, sus coeficientes
  individuales no se interpretan.

## Implementación del bloque B2 (decidida por Harold el 2026-10-06)

Al bajar F5-07 y F5-12 a código aparecieron ocho puntos que la ficha no fijaba. Se presentaron como preguntas antes de
escribir código (Regla 4) y todos se resolvieron en la opción recomendada. Las cuentas de grados de libertad usan las
fechas de inicio de L3 (PIB 1990-Q1, remesas 1991-Q1, FOB 1994-Q1, IVAE 2005-Q1); no se miró ningún valor.

- **B2-1 · Forma de los VAR y densidad.** **DECIDIDO:** `MULT.VAR_DIF` en Δ de los log-niveles y `MULT.VAR_NIV.G1` en
  log-niveles, los dos con constante y dummies estacionales centradas (`vars`, `season = 4`) cuando alguna serie es
  NSA. Densidad con los pesos MA de la forma VAR (`vars::Phi`) y Σ *plug-in*; en el VAR en diferencias los pesos se
  acumulan hasta el log-nivel. Descartada: VAR en niveles con tendencia lineal (con raíz unitaria implica una tendencia
  cuadrática en el pronóstico).
- **B2-2 · Rejilla de p.** **DECIDIDO:** G1 p ∈ 1..4; G2 y G3 p ∈ 1..3, fija en todos los orígenes del grupo, por BIC
  (SC de `vars::VARselect`, misma muestra para todos los candidatos). En el primer origen de G2 y de G3 el VAR en
  diferencias con p = 4 deja 19 grados de libertad por ecuación (35 observaciones, 16 parámetros), bajo el piso de
  F5-03; con p = 3 quedan 23 en G2. Descartadas: p ∈ 1..2 en todos, y 1..4 filtrado por origen (no es «acotado de
  antemano», como en B1-2).
- **B2-3 · Johansen.** **DECIDIDO:** traza al 5 % (`urca::ca.jo`, `type = "trace"`), `ecdet = "none"` (constante no
  restringida, caso 3: deriva en niveles y relaciones sin tendencia), K = max(2, p del BIC del VAR en niveles con p en
  1..4) y dummies centradas. Con unas 77 observaciones la traza asintótica tiende a sobrerrechazar; se declara como
  límite. Descartadas: traza con la corrección de Reinsel y Ahn, y máximo autovalor.
- **B2-4 · Casos límite del rango.** **DECIDIDO:** con r = 0 se estima el VECM anidado, un VAR en Δ con K − 1 rezagos
  (sin una selección nueva); con r = 3 (rango completo), un VAR en niveles con K rezagos. El `modelo_id` sigue siendo
  `MULT.VECM.G1`, y r y la forma usada van a `diagnosticos.csv`. Descartado: reusar la especificación de
  `MULT.VAR_DIF.G1` con r = 0 (copiaría a otro miembro del MCS).
- **B2-5 · Estacionalidad del BVAR.** **DECIDIDO:** `BVAR::bvar` (1.0.5) no admite regresores exógenos (su firma es
  `data, lags, n_draw, n_burn, n_thin, priors, mh, fcast, irf, verbose`). Cada serie NSA se ajusta dentro del origen:
  se regresa su log-nivel sobre dummies trimestrales centradas con la historia hasta o y se usa el residuo más la
  media. El PIB y el IVAE ya son SA, y solo se pronostica el PIB. Descartadas: X-13 por origen para cada NSA (costo y
  puntos de falla) y dejar que los rezagos absorban la estacionalidad (el prior Minnesota encoge el rezago 4). Se
  implementa en B2b.
- **B2-6 · VAR de G3.** **DECIDIDO:** `MULT.VAR_DIF.G3` queda como lo fijó F5-07: con B1b-2 tiene las mismas tres series
  que el de G2 (PIB, IVAE, remesas nominales), su muestra empieza en 2005-Q1 y en los orígenes comunes sus pronósticos
  coinciden con los de `MULT.VAR_DIF.G2`; el YAML lo declara. Sirve de VAR pequeño de referencia en el MCS de G3.
  Descartadas: recortarlo a 2010-Q1 y agregar el IPP (reabría F5-07).
- **B2-7 · BVAR.** **DECIDIDO:** `hyper = "auto"` (λ de la Minnesota y los hiperparámetros de *sum-of-coefficients* y
  *single-unit-root* jerárquicos; ψ fijo en las varianzas de residuos AR, el valor por defecto del paquete), MH con
  ajuste de la tasa de aceptación solo en el quemado, sin adelgazar (5 000 extracciones retenidas). Densidad: media y
  covarianza de las extracciones de la predictiva posterior, con choques, del log-PIB en h = 1..8 (F5-12). Sin piso de
  grados de libertad (`piso_gl = FALSE`). Descartado: `hyper = "full"` (ψ jerárquico). Se implementa en B2b, donde se
  verifica que `predict.bvar` incluya los choques.
- **B2-8 · Dos PR, uno después del otro y sin apilar.** **DECIDIDO:** B2a, VAR y VECM (YAML, registro, densidad contra
  un oráculo, G-8 con los inicios de L3, canario V15 y medición del tiempo); B2b, cuando B2a esté en `main`, el BVAR con
  su canario y su medición. Es otra excepción declarada a «un PR por bloque» de F5-01, como B1-4.

**Decisiones menores del agente en B2a** (revertibles en un commit; ninguna cambia un resultado de Fase 4):

- **Σ de las innovaciones, la de `vars` en cada clase:** `crossprod(resid) / (obs − regresores por ecuación)` en un VAR
  (la de `vars:::.fecov`) y `crossprod(resid) / obs` en un `vec2var` (la de `vars:::.fecovvec2var`). Así la diagonal de
  la covarianza del sendero reproduce la varianza de `predict()` en niveles (prueba en
  `tests/test-modelos-multivariados.R`).
- **G-8 con el mayor candidato:** en los VAR, `n_obs` = observaciones de la ecuación con p_max y `n_par` = k · p_max + 1
  + 3 (constante y dummies); en el VECM, el mayor caso es el VAR en niveles con K = 4 (16 parámetros por ecuación).
  Grados de libertad libres en el primer origen: `MULT.VAR_DIF.G1` 56, `MULT.VAR_NIV.G1` 57, `MULT.VECM.G1` 57,
  `MULT.VAR_DIF.G2` 23 y `MULT.VAR_DIF.G3` 43.
- **Muestra:** cada modelo empieza donde empiezan todas sus series (como las ARIMAX), no en el inicio común del grupo.
- **Guardas (Regla 7):** una predictora que no llega al origen, valores no positivos, trimestres faltantes o una Σ que no
  es definida positiva detienen el motor. No hay guarda de estabilidad: el módulo máximo de las raíces de la forma
  compañera va a `diagnosticos.csv` (cerca de 1 en el VAR en niveles si hay raíz unitaria).
- **Diagnósticos por origen:** VAR, p elegido, observaciones y módulo máximo de las raíces; VECM, K, r, forma usada
  (0 = diferencias, 1 = VECM, 2 = niveles), observaciones, módulo máximo de las raíces y los estadísticos de traza.
- **V15** (canario de B2a): VAR_DIF sobre un DGP VAR(1) en diferencias, con razón de RMSE contra el AR(p)-BIC < 0,8 en
  h = 1, 2 y cobertura en h = 1, 2, 4 dentro de ±3 ee de MC más 0,03; VECM sobre un DGP cointegrado con corrección en
  el PIB, con r = 1 en al menos el 80 % de los orígenes, razón de RMSE contra el VAR_DIF < 0,9 en h = 2, 4 y la misma
  cobertura; sin cointegración, r = 0 en al menos el 80 %. 20, 10 y 10 réplicas. En h = 8 la ventaja del VECM casi
  desaparece en la pérdida interanual (razón ≈ 0,97 en la calibración) y no se exige.
- **Costo observado (dato para B5 y F5-14, sandbox, datos sintéticos):** menos de 0,1 s por origen en los cinco modelos
  (VAR_DIF.G1 0,10 s; VAR_NIV.G1 0,08 s; VECM.G1 0,08 s; VAR_DIF.G2 y .G3 0,07 s). Unos 18 s para todos los orígenes de
  los tres grupos.
- **Riesgo declarado para el MCS:** si en todos los orígenes de G1 la traza da r = 0 y K − 1 coincide con el p de
  `MULT.VAR_DIF.G1`, los dos modelos tienen pérdidas idénticas, y si quedan como los dos últimos del MCS en algún
  horizonte, `mcs_tmax()` se detiene por varianza bootstrap nula (Regla 7). Se presenta como pregunta antes de cerrar
  el preregistro.

**Nota (2026-10-07, B2-9, decidida por Harold).** El riesgo anterior se presentó como pregunta con tres opciones:
deduplicar en el MCS, mantener el `stop()` y quitar `MULT.VAR_DIF.G1`.

- **B2-9 · Pérdidas idénticas en el MCS. DECIDIDO:** si dos o más modelos tienen pérdidas idénticas en una celda (grupo ×
  horizonte × muestra), el MCS corre con uno de ellos y todos comparten su p-valor y su pertenencia al conjunto;
  `mcs.csv` lo marca con una columna nueva. Se implementa en un PR pequeño del motor, cuando B2a esté en `main` y antes
  de cerrar el preregistro (E1), con su prueba y con la verificación de que V11 y los `F5_REPRO_*` no cambian. Cubre
  también duplicados futuros (combinaciones, variantes). Descartadas: mantener el `stop()` (la decisión llegaría
  después de ver resultados de L3, contra F5-02) y quitar `MULT.VAR_DIF.G1` (reabría F5-07 y perdía el VAR en
  diferencias de referencia en los orígenes con r > 0).

**Implementación de B2-9 (2026-10-07; decisiones menores del agente, revertibles en un commit):**

- `mcs_tmax_dedup()` en `eval_lib.R` agrupa las columnas de pérdidas exactamente iguales (`identical`, sin
  tolerancia), corre `mcs_tmax()` sobre el primer modelo de cada grupo (en el orden de los modelos del experimento:
  benchmarks y luego el registro de Fase 5) y copia a los demás su `p_mcs`, `en_mcs` y `orden_eliminacion`.
  `identico_a` lleva el `modelo_id` del representante, o queda vacío. Sin duplicados devuelve lo mismo que `mcs_tmax()`,
  bit a bit. Si todos los modelos de la celda son idénticos, todos quedan con p_mcs = 1.
- **Solo en los experimentos de Fase 5 (`F5_G*`, `PATRON_EXP_PREREGISTRO`)**, en la muestra completa y en las
  submuestras de R3 y R4. Ahí `mcs.csv` y `mcs_submuestras.csv` llevan siempre la columna `identico_a`, y el manifiesto
  lo declara. En Fase 4 y en los `F5_REPRO_*` el MCS sigue siendo `mcs_tmax()` tal cual. Razón, hallada al verificar:
  con un objetivo sintético AR(1), `BENCH.ARP_BIC` elige p = 1 en todos los orígenes y repite a `BENCH.AR1`. El
  `mcs_tmax()` de siempre no se detiene mientras esa pareja no quede al final, así que deduplicar también ahí cambiaría
  sus tablas. Con el código anterior y el nuevo, los 13 `F5_REPRO_*` dan tablas idénticas sobre insumos sintéticos
  (digest de pronósticos, métricas, pruebas, MCS, submuestras y estabilidad).
- **Consecuencia para Fase 5:** si en un grupo el AR(p)-BIC repite al AR(1), o el VECM con r = 0 repite al VAR en
  diferencias, el MCS de los `F5_G*` los cuenta una vez. Así la corrida única no se detiene por esa causa.

**Nota (2026-10-07, B2b, decidida por Harold salvo B2-16).** Al bajar B2-5 y B2-7 a código aparecieron siete puntos
que no fijaban. Se presentaron como preguntas antes de cerrar el código del modelo (Regla 4). No se miró ningún valor
de L3: los hallazgos salen del código del paquete y de datos sintéticos.

- **B2-10 · Densidad del BVAR. DECIDIDO:** los momentos exactos de la predictiva posterior con choques. Para cada
  extracción retenida (β_j, Σ_j), μ_j sale de la recursión del VAR y C_j de los pesos MA de la fila del PIB. La media es
  el promedio de los μ_j y la covarianza es el promedio de los C_j más cov(μ_j), por la ley de varianza total. Hallazgo
  que la motivó: en BVAR 1.0.5, `predict.bvar` no da la predictiva posterior con choques. Suma un solo choque por
  horizonte, `t(crossprod(sigma[j, , ], z))`, sin propagarlo por la dinámica, y `object$sigma` es la covarianza Σ_j y
  no su Cholesky, así que la varianza del choque es Σ²_j. Prueba empírica con un VAR(1) bivariado: la varianza de
  `predict` en h = 1 fue 16,33 / 4,495, con E[Σ] = 3,825 / 1,848 y E[Σ²] = 15,654 / 4,323, y no creció con h. En
  log-niveles Σ² es despreciable y la densidad sale angosta. La prueba de `tests/test-modelo-bvar.R` vigila las dos
  cosas. Descartadas: una simulación propia de senderos (agrega error de Monte Carlo, ≈ 2 % en las varianzas, y más
  dependencia del RNG en la paridad entre sistemas) y `predict.bvar` tal cual (no cumple F5-12). Cambia la letra de
  B2-7 («de las extracciones»): son los momentos exactos de la misma distribución.
- **B2-11 · Metropolis-Hastings. DECIDIDO:** `bv_mh(scale_hess = 0.01, adjust_acc = TRUE, adjust_burn = 0.75,
  acc_lower = 0.25, acc_upper = 0.45, acc_change = 0.01)`, los valores por defecto con el ajuste activado (el paquete
  trae `adjust_acc = FALSE`). La aceptación de cada origen va a `diagnosticos.csv`, sin guarda. Descartadas: ajustar
  durante todo el quemado (`adjust_burn = 1`) y un `stop()` por aceptación fuera de un rango, que podría detener la
  corrida única.
- **B2-12 · Priors. DECIDIDO:** los valores por defecto del paquete (los de GLP 2015), escritos explícitamente en
  `priors_bvar()`: λ con moda 0,2 y de 0,4 en [1e-4, 5]; α = 2 fijo; b = 1; var de la constante 1e7; SOC y SUR con moda 1
  y de 1 en [1e-4, 50]. ψ se reabrió en B2-15 y B2-16.
- **B2-13 · Muestra del ajuste estacional. DECIDIDO:** las dummies de B2-5 se estiman en la muestra del modelo (las
  filas de `panel_var()`, como las dummies de los VAR de B2a), no con la historia propia de cada serie.
- **B2-14 · Tendencia en la regresión auxiliar (reabre la letra de B2-5). DECIDIDO:** log-nivel ~ constante +
  tendencia lineal + dummies, y se resta solo el componente estacional. Con solo dummies, la deriva se cuela en los
  factores: cada trimestre tiene un tiempo medio distinto en la muestra, y el sesgo va de ±d a ±1,5·d según el trimestre
  en que termina la muestra, así que cambia con el origen. En una simulación (paseo con deriva d = 0,01, 77
  observaciones, 2 000 réplicas), el sesgo fue de −0,010 y +0,010 en Q2 y Q4, con RMSE de 0,0105; con la tendencia, el
  sesgo es 0,000 y el RMSE 0,003. Descartadas: estimar los efectos sobre Δlog e integrarlos (más complejo, resultado
  casi igual) y B2-5 literal.
- **B2-15 · ψ sin `auto_psi`. DECIDIDO (no es la opción recomendada):** ψ por MCO, con un AR(4) con constante en cada
  serie de la muestra del modelo y sin optimización numérica. Hallazgo: cuando `arima(4,0,0)` sobre el log-nivel emite
  un aviso, `auto_psi` lo vuelve a correr fuera de su `tryCatch`, y en una réplica sintética de V16 ese segundo intento
  falló con «non-finite finite-difference value». En la corrida única eso detendría el motor (Regla 7). La opción
  recomendada era reimplementar `auto_psi` con toda la cadena dentro de `tryCatch`, que conservaba el valor por
  defecto. Descartada también: dejar `auto_psi`.
- **B2-16 · Unidades de ψ. DECIDIDO por el agente (decisión delegada por Harold; se puede reabrir):** ψ es la varianza
  residual σ² (denominador n − 5), con límites ψ/100 y 100·ψ. El paquete documenta ψ por defecto como σ, pero `bvar` lo
  usa en unidades de varianza: como escala de la inversa Wishart, diag(ψ), y en λ² / (l^α ψ_j) en la Minnesota, como en
  GLP, donde ψ es la varianza residual del AR. En log-niveles σ ≈ 0,01-0,02 frente a σ² ≈ 1e-4, así que con σ el prior
  infla Σ. Calibración de V16 (13 orígenes): con ψ = σ (10 réplicas), cobertura al 80 % de 0,985 / 0,962 / 0,869 en
  h = 1 / 2 / 4 y al 95 % de 1,000; con ψ = σ² (6 réplicas), 0,744 / 0,705 / 0,731 y 0,949 / 0,949 / 0,885. La razón
  de RMSE contra el AR(p)-BIC en h = 1 fue 0,651 frente a 0,643. Descartadas: σ (densidad demasiado ancha, por una
  cuestión de unidades) y σ con los datos en 100·log (la discrepancia cambia de tamaño pero no desaparece).

**Implementación de B2b (2026-10-07; decisiones menores del agente, revertibles en un commit):**

- **Código:** `modelo_bvar()`, `ajustar_bvar()`, `panel_bvar()`, `factores_estacionales()`, `psi_bvar()`,
  `priors_bvar()`, `mh_bvar()` y `momentos_predictiva_bvar()` en `modelos_multivariados.R`; `modelo_bvar_grupo()` va
  al final de `modelos_fase5(grupo)`. Las series son las de `predictoras_grupo(grupo)`, en ese orden: 3 en G1, 7 en G2
  y 9 en G3.
- **Momentos una vez por origen:** `ajustar()` los calcula para h = 1..8 (`H_BVAR = DISENO_FASE4$h_max`) y
  `predecir()`/`predecir_densidad()` recortan; pedir h > 8 detiene. cov(μ_j) lleva denominador S: son los momentos de la
  mezcla empírica de las S extracciones. `bvar()` corre con `fcast = NULL` e `irf = NULL`, así que no se usa el RNG
  después del MCMC.
- **Factores estacionales** centrados sobre los cuatro trimestres (suman cero en el año, como las dummies centradas
  de `vars`), no sobre la muestra.
- **Escala:** log-niveles sin reescalar, como B2a.
- **Guardas (Regla 7):** las de `panel_var()`; extracciones no finitas o mal dimensionadas; ψ no finito o degenerado;
  covarianza de la predictiva no definida positiva; h > 8. No hay guarda sobre la aceptación (B2-11).
- **Diagnósticos por origen:** `n_obs` (filas − 4), `n_series`, `aceptacion`, las medias posteriores de `lambda`, `soc`
  y `sur`, y `psi_pib`.
- **Muestras con las fechas de inicio de L3:** en el primer origen hay 77 observaciones en G1 (desde 1994-Q1), 40 en
  G2 (desde 2005-Q1) y 40 en G3 (desde 2010-Q1). Son 73, 36 y 36 efectivas, frente a 13, 29 y 37 parámetros por
  ecuación. F5-07 decía «39 datos» para G3; son 40.
- **V16** corre con 2 000 extracciones y 1 000 de quemado, en uno de cada cuatro orígenes y con 6 réplicas, por el
  costo del canario. La configuración de producción se prueba en `tests/test-modelo-bvar.R`, en el primer origen de
  cada grupo.
- **Costo observado (dato para B5 y F5-14; sandbox Windows, datos sintéticos con las fechas de inicio de L3,
  configuración de producción, medido en el primer y el último origen de cada grupo):**
  - `MULT.BVAR.G1`: 15,6-18,7 s por origen (52 orígenes);
  - `MULT.BVAR.G2`: 17,9 s (45 orígenes);
  - `MULT.BVAR.G3`: 21,4-25,9 s (25 orígenes).

  Son unos 38 minutos para los tres experimentos principales, y R7 repite G2 y G3 (unos 23 minutos más). El cálculo
  de los momentos tarda menos de 1 s por origen; el resto es el MCMC. La aceptación del MH fue de 0,16 a 0,38, más
  baja con 7 y 9 series y en los orígenes tardíos. Con este costo, el BVAR es la familia que decide el tope de R1, R2,
  R5 y R6 en B5.
- **Paridad Windows/Linux (F1 del checklist, F5-15):** pendiente. En una misma máquina el resultado es bit a bit
  (`tests/test-modelo-bvar.R` y V16).

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
