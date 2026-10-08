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
| F1-1 y F1-2 | Paridad Windows/Linux del BVAR: bloque V17 con una referencia generada en Windows; ajuste fijo en el primer origen de G1 y G3 con la configuración de producción | checklist de Fase 5, F1 (nota 2026-10-07) |
| F1-3 | Tolerancia de la paridad del BVAR entre sistemas: entradas, tamaños y aceptación exactos; media ≤ 1e-6 en log-nivel; covarianza e hiperparámetros ≤ 1e-5 relativo. En Windows, bit a bit | protocolo §6 (nota 2026-10-07) |
| F1-3 (reabierta) | En Windows, V17 exige bit a bit; fuera de Windows solo informa, en unidades del error de Monte Carlo. La paridad del BVAR entre sistemas llega hasta el error de Monte Carlo (reemplaza a la fila anterior) | protocolo §6 (segunda nota 2026-10-07) |
| F5-14a a F5-14f | Tope de 8 h por pasada de `make eval`, secuencial; familias = bloques de F5-01, con `MULT.VAR_DIF` como representante de B2; representantes antes que la variante Q1 de F5-11; combinaciones con los miembros presentes; el BVAR sigue con 10 000 / 5 000 | protocolo §5 (nota 2026-10-08); checklist de Fase 5, B5 |
| B3-1 a B3-8 | Implementación de B3: rejilla de λ desde el λ_max del origen; estacionalidad quitada en la ventana antes de estandarizar; rezagos del PIB dentro del PCA; K = 12 en todos los h; Σ = D · R · D con momentos sin centrar; guardas duras y bordes de rejilla a `diagnosticos.csv`; dos PR | F5-09, F5-11 y F5-12 (notas 2026-10-08); especificación del motor §2 (nota 2026-10-08) |
| B3-9 | Representante de B3 para R1, R2, R5 y R6: `REG.ENET` (decisión delegada al agente; se puede reabrir) | «Tope de costo y representantes» (nota 2026-10-08) |
| B3b-1 a B3b-7 | Implementación de B3b (delegadas al agente): meses del U-MIDAS acotados por el piso (G1 con la letra de F5-08; G2 y G3 con el último mes admitido); guardas de las ARIMAX; densidad del U-MIDAS de errores internos; AR mensual p ≤ 12; agregación linealizada en la densidad del puente; covarianza completa del puente con las innovaciones mensuales del trimestre; representante `MIX.PUENTE` | F5-08 y F5-12 (notas 2026-10-08); «Tope de costo y representantes» (nota 2026-10-08) |
| B4-1 a B4-6 | Implementación de B4: ventana de B3-2; densidad de errores internos y no OOB; rejilla del RF con mtry deduplicado en G1 y semilla del generador de R que siembra el motor; rondas de LightGBM en 10..500 por `num_iteration`; representante `ML.RF`; canario V20 (decisiones delegadas al agente; se pueden reabrir) | F5-10, F5-12 y «Tope de costo y representantes» (notas 2026-10-08) |
| B5-1 a B5-5 | Implementación de B5 (delegadas al agente): errores de los pesos inversos al ECM contra el objetivo visto en el origen; variantes `F5_Gk_Rn` (R1 y R6 en los tres grupos, R2 y R5 en G2 y G3, R7 en G2 y G3); predictoras recortadas al inicio de la ventana en R1 y R2; R7 con los modelos con UT y sin combinaciones; combinaciones como paso del orquestador, con los miembros en su YAML | F5-13, F5-14 y F5-04c (esta sección); «Implementación del bloque B5» |

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

**Nota (2026-10-08, B3b; decisiones delegadas al agente).** El piso acota el U-MIDAS de G2 y G3 a un mes por predictora,
el último admitido; G1 conserva los meses de esta ficha (B3b-1). F5-12 no nombraba la densidad del U-MIDAS: es la de
errores internos de los modelos directos (B3b-3). La densidad del puente lleva la covarianza de su innovación con las
mensuales del mismo trimestre (B3b-6). Ver «Implementación del bloque B3b».
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

**Nota (2026-10-08, B3-2 y B3-3).** Al implementar B3 se precisaron dos puntos de esta ficha (ver «Implementación del
bloque B3», más abajo):

- La estandarización dentro de la ventana es la de B3-2. En la ventana, cada columna y g_h se residualizan sobre
  constante y dummies, y cada columna se divide por la desviación que queda. Por Frisch-Waugh-Lovell, esto equivale a
  las dummies sin penalizar.
- En el PCR, los rezagos del PIB entran al PCA junto con las predictoras (B3-3).

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

**Nota (2026-10-08, B4-1, B4-3 y B4-4).** Al implementar B4 se precisaron tres puntos de esta ficha (ver «Implementación
del bloque B4», más abajo; decisiones delegadas al agente):

- los dos modelos van sobre la forma directa de B3 (`forma_directa.R`), con la ventana de B3-2 (B4-1);
- en G1, p = 12 columnas y ⌈p/3⌉ = ⌈√p⌉ = 4: la rejilla de mtry se deduplica y el RF tiene 2 candidatos (B4-3);
- las rondas de LightGBM se eligen en {10, 20, ..., 500}, con un entrenamiento por num_leaves y el pronóstico en cada
  número de rondas (B4-4).

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

**Nota (2026-10-08, F5-14d).** Si la cuenta final de F5-14 supera el tope, la variante que reoptimiza solo en los
orígenes Q1 se aplica después de los representantes de F5-14, y solo si con ellos la cuenta todavía no cabe. Ver
«Tope de costo y representantes», más abajo.

**Nota (2026-10-08, B3-4).** La cifra de «unos 27 para la primera estimación interna» se contó para h = 1 y sin rezagos.
Con los rezagos 0..3 de F5-09 y la forma directa de F5-05, la estimación interna más chica tiene n_L − 15 − 2h filas,
donde n_L son los trimestres en niveles hasta el origen. En el primer origen de G2 y G3, n_L = 40, que corresponde a los
39 datos en diferencias de esta ficha. Eso da 23, 21, 17 y 9 filas en h = 1, 2, 4 y 8. Harold decidió mantener K = 12
en todos los h (B3-4, en «Implementación del bloque B3»).

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

**Nota (2026-10-08, B3-5 y B3-6).** En los regularizados, la covarianza empírica de los errores internos es
Σ = D · R · D, con momentos sin centrar:

- la varianza de cada h es el ECM interno del candidato elegido en sus 12 orígenes propios;
- las correlaciones salen de los 12 orígenes internos comunes a h = 1..8.

Ver «Implementación del bloque B3». B4 decide si los árboles usan la misma o los OOB de RF.

**Nota (2026-10-08, B4-2).** Los árboles usan la misma covarianza de errores internos que los regularizados
(Σ = D · R · D), no los OOB del RF: los OOB son errores de bootstrap dentro de la muestra y no pseudo fuera de muestra en
el tiempo (decisión delegada al agente; ver «Implementación del bloque B4»).

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

**Nota (2026-10-08, F5-14e).** En las variantes R1, R2, R5 y R6 que corran con representantes (F5-14), los
miembros de cada combinación son los modelos de Fase 5 presentes en la variante: univariados y representantes. Se
declaran en el YAML y el manifiesto dice que no es la misma combinación que la principal. Ver «Tope de costo y
representantes», más abajo.

**Nota (2026-10-08, B5).** Implementadas en `src/evaluacion/combinaciones.R`, con los 12 YAML `COMB.*.Gk` y las decisiones
B5-1 y B5-5 (delegadas al agente), en «Implementación del bloque B5».

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

**Nota (2026-10-08, F5-14a a F5-14f).** El tope es de 8 horas de reloj por pasada completa de `make eval`. Las
familias, el representante de B2, el orden de las palancas y la cuenta final están en «Tope de costo y
representantes», más abajo.

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
  Nota 2026-10-07: medida en F1. Entre Windows y Ubuntu no es bit a bit, y la tolerancia quedó declarada en F1-3
  (sección «Paridad Windows/Linux del BVAR», más abajo).

---

## Paridad Windows/Linux del BVAR (F1 del checklist; decidida por Harold el 2026-10-07)

F5-15 pide verificar la paridad del BVAR entre Windows y Linux «como en el cierre de Fase 4» y, si no es bit a bit,
declarar la tolerancia. La corrida única (E2) es en Windows; el CI corre en Ubuntu 24.04 con R 4.6.1, la versión de
`renv.lock`. En el push de `5f9f383` (PR #37), el V16 del CI imprimió los mismos valores que el sandbox Windows (RMSE
0,643 y 0,768; cobertura 0,744 / 0,705 / 0,731 y 0,949 / 0,949 / 0,885). Es un indicio a tres decimales, no una
comparación bit a bit.

- **F1-1 · Forma de la comparación. DECIDIDO (opción recomendada):** un bloque nuevo, V17, en
  `verificar_motor_sintetico.R`. Ajusta un BVAR fijo y compara los bytes de sus momentos con una referencia generada en
  Windows y versionada en el repo. Se detiene con `stop()` si algún valor difiere e imprime el sha256 de los momentos.
  El CI lo corre en cada push sin cambiar el workflow, y en una misma máquina detecta además un cambio no intencional
  del BVAR. Si cambia el código o la configuración del BVAR, la referencia se regenera en ese mismo PR con una nota
  fechada. Descartadas: la misma comparación en testthat (el hash no queda en la salida de la verificación, que es lo
  que se comparó en el cierre de Fase 4) y un script con un paso temporal del workflow (compara una sola vez y no
  protege contra regresiones).
- **F1-2 · Ajuste fijo. DECIDIDO (opción recomendada):** el primer origen de G1 (3 series, 2013-Q1) y de G3 (9 series,
  2019-Q4), con la configuración de producción (p = 4, 10 000 extracciones y 5 000 de quemado; B2-7), sobre los datos
  sintéticos de la prueba de producción de `tests/test-modelo-bvar.R` (fechas de inicio de L3, semilla fija). Se
  comparan la media y la covarianza de la predictiva en h = 1..8 (B2-10) y la aceptación del MH. Descartadas: los tres
  grupos (G2, con 7 series, no agrega un caso distinto de G3) y el ajuste corto de 1 500/500 (no es la configuración de
  E2; con más extracciones, una divergencia del MH tiene más pasos para aparecer).
- **Si Linux no iguala byte a byte,** la tolerancia se le pregunta a Harold con la magnitud medida (Regla 4).

**Implementación de F1 (2026-10-07; decisiones menores del agente, revertibles en un commit):**

- **Código:** `src/evaluacion/paridad_bvar.R` (`datos_paridad_bvar()`, `momentos_paridad_bvar()`,
  `comparar_paridad_bvar()`, lectura y escritura de la referencia), con sus pruebas en `tests/test-paridad-bvar.R`.
  La referencia es `src/evaluacion/referencias/paridad_bvar.csv`, con 159 filas: el sha256 de las entradas y 79 valores
  por grupo (8 de media, 64 de covarianza y 7 diagnósticos). Se regenera con `scripts/referencia_paridad_bvar.R`, que se
  detiene fuera de Windows.
- **Qué se compara, además de lo decidido:** los demás diagnósticos del ajuste (medias posteriores de λ, SOC y SUR, ψ
  del PIB y los tamaños) y el sha256 de los datos de entrada. No cuestan nada y separan una diferencia de los datos de
  una del BVAR.
- **Bytes y no texto:** se comparan los 8 bytes IEEE 754 de cada valor (16 caracteres hexadecimales, little-endian),
  porque el texto decimal depende de la rutina de impresión de cada sistema. La columna `valor` (`%.17g`) es solo para
  leer el archivo.
- **Siembra:** la del motor (`semilla_de()`, como en `correr_backtest()`), con `exp_id = "V17"`.
- **Salida:** la línea OK de V17 no lleva datos de la plataforma, para que la salida de la verificación siga siendo
  comparable byte a byte entre máquinas. El mensaje de `stop()` sí trae la versión de R, el sistema, la BLAS y la
  LAPACK.
- **Referencia:** generada con el código de este commit en el sandbox Windows de la máquina de Harold (R 4.6.1 ucrt,
  Windows 11 x64, build 26200). sha256 de los momentos `27ec46c0219321e226d6200692d38154994bf0f4129bfa974dc43857367563ce`.
  Un proceso nuevo la reproduce byte a byte (0 de 159 valores distintos). Costo de V17: unos 42 s en el sandbox.

**Resultado en Linux (2026-10-07).** El CI del push de `200496b` (run 37695426578; Ubuntu 24.04.5, R 4.6.1, BLAS
`libblas.so.3`, LAPACK de OpenBLAS 0.3.26, versión 3.12.0) no iguala la referencia byte a byte: difieren 152 de los 159
valores. Las entradas son idénticas, igual que los tamaños y la aceptación del MH en los dos grupos: las cadenas toman
las mismas decisiones, así que la diferencia es de redondeo y no una divergencia del MCMC. La diferencia máxima de la
media es 9,71e-8 en log-nivel, unos 1e-5 pp de la tasa interanual. La diferencia relativa máxima de la covarianza es
8,67e-7. sha256 de los momentos en Linux: `ec953e8a99641d3ba9c590686cc72640a50f61dc11070d66bf0c9db3de08a102`. En
Windows, R 4.6.1 usa su BLAS de referencia y LAPACK 3.12.1. Para dar escala, el error de Monte Carlo del mismo ajuste
en Windows (medias por lotes, 50 lotes de 100 extracciones) es de 8,9e-5 a 1,4e-3 en la media (log-nivel) y de 0,5 %
a 2,6 % en la varianza. Lo de Linux es entre 1 000 y 6 000 veces menor.

- **F1-3 · Tolerancia entre sistemas. DECIDIDO por Harold el 2026-10-07 (opción recomendada):** un margen de unas 10
  veces lo medido. En Windows sigue exigiéndose bit a bit (F5-15). En otro sistema, las entradas, los tamaños
  (`n_obs`, `n_series`) y la aceptación deben ser idénticos, porque si la aceptación difiere las cadenas divergieron y
  la diferencia ya no es de redondeo. La media admite |dif| ≤ 1e-6 en log-nivel (1e-4 pp). La covarianza y los
  hiperparámetros (λ, SOC, SUR y ψ del PIB) admiten una diferencia relativa ≤ 1e-5. V17 informa la diferencia máxima
  por campo. Ese margen queda al menos unas 90 veces por debajo del error de Monte Carlo y aguanta un cambio de OpenBLAS
  en `ubuntu-latest` sin falsas alarmas. La diferencia de λ, SOC, SUR y ψ no se había medido campo por campo: si pasa
  de 1e-5, se le vuelve a preguntar a Harold con el dato. Descartadas: una tolerancia de 2 veces lo medido (una
  actualización de la imagen del CI podría ponerlo en rojo sin cambios del proyecto) y una tolerancia ligada al error
  de Monte Carlo (más código, deja pasar cadenas que divergieron y admite más diferencia en la media).
- **Implementación (decisión menor del agente, revertible):** fuera de Windows, la línea OK de V17 informa el número de
  valores distintos, los máximos por campo y la plataforma, así que la salida de la verificación difiere entre sistemas
  solo en esa línea. En Windows la línea no cambia.

**Nota 2026-10-07 (más tarde): F1-3 reabierta.** Con el código de `7c11a5d`, el CI corrió V17 en cuatro runners de
Ubuntu (las corridas push y pull_request de `200496b` y de `7c11a5d`; misma imagen base, R 4.6.1 y OpenBLAS 0.3.26).
Salieron dos resultados distintos, y cada uno se repitió exacto en dos corridas:

- **L1** (push de `200496b`, run 37695426578; pull_request de `7c11a5d`, run 37698253588). sha256
  `ec953e8a…`. Misma aceptación que Windows. Máximos: media 9,7e-8 en log-nivel; covarianza 8,7e-7 relativo; λ 2,1e-6;
  SOC 7,4e-6; SUR 1,8e-6; ψ 5,9e-14. Queda dentro de la tolerancia anterior.
- **L2** (pull_request de `200496b`, run 37695968661; push de `7c11a5d`, run 37698247458). sha256 `bbcd84a1…`. La
  aceptación difiere en 0,0008, es decir, en 4 de las 5 000 decisiones del MH, y desde ahí las cadenas se separan.
  Máximos: media 1,7e-3 en log-nivel (unos 0,17 pp de la tasa interanual); covarianza 3,3 % relativo; λ 1,2 %; SOC
  9,5 %; SUR 0,15 %; ψ 8,7e-14. Es la escala del error de Monte Carlo y queda fuera de la tolerancia anterior.

Causa probable, no verificada: OpenBLAS elige kernels distintos según la CPU del runner, y un redondeo distinto basta
para cambiar una decisión de aceptación del MH cuando cae cerca del umbral. Con esa evidencia, la tolerancia anterior
dejaba el CI en rojo o en verde según el runner. Esto no depende del margen elegido: con cualquier diferencia de
redondeo y otros datos, alguna decisión del MH puede cambiar.

- **F1-3 (reabierta) · DECIDIDO por Harold el 2026-10-07 (opción recomendada; reemplaza a la F1-3 de arriba):**
  - En Windows, V17 sigue exigiendo bit a bit con `stop()` (F5-15). Es la guarda en la máquina de la corrida única:
    `make eval` corre antes la verificación sintética.
  - Fuera de Windows, V17 informa sin detenerse: los valores distintos, las decisiones del MH distintas por grupo y,
    por campo, el máximo de |dif| / MCSE y el máximo de la diferencia.
  - La paridad del BVAR entre sistemas queda declarada hasta el error de Monte Carlo. La corrida única (E2) se
    reproduce bit a bit solo en la máquina de Harold. En otro sistema, los resultados del BVAR pueden diferir hasta el
    orden de su error de Monte Carlo.
  - Fuera de Windows, el CI deja de vigilar el BVAR con V17. Lo siguen vigilando V16 y `tests/test-modelo-bvar.R`.
  - Descartadas: una tolerancia de Monte Carlo con `stop()` (4 MCSE, o más de 0,005 de diferencia en la aceptación).
    Es más código, el umbral es un juicio y podría fallar de vez en cuando. También se descartó fijar OpenBLAS en el
    workflow: el CI sería determinista, pero no cambia la paridad real y requiere un cambio de CI.
- **Implementación (decisiones menores del agente, revertibles en un commit):**
  - La referencia agrega la columna `mcse`. Es el error de Monte Carlo de cada momento y de las medias posteriores de
    λ, SOC y SUR, por medias por lotes (50 lotes de 100 extracciones).
  - Lo calcula `mcse_paridad_bvar()` al regenerar la referencia. La función repite el ajuste de producción con la
    misma siembra y se detiene si sus momentos no son idénticos a los de `ajustar_bvar()`.
  - Los bytes de la referencia no cambian: el sha256 de los momentos sigue siendo `27ec46c0…`.
  - MCSE en Windows: media de 1,42e-4 (h = 1) a 1,40e-3 (h = 8) en G1 y de 8,9e-5 a 1,16e-3 en G3. En h = 8 eso es
    unos 0,14 pp de la tasa interanual.
  - Se quitan las constantes de la tolerancia anterior (`TOL_MEDIA_PARIDAD_BVAR`, `TOL_REL_PARIDAD_BVAR`,
    `CAMPOS_EXACTOS_PARIDAD_BVAR`).

**Evidencia sobre `328122f` (2026-10-07).**

- **Windows** (sandbox de la máquina de Harold, R 4.6.1 ucrt):
  - verificación V1-V17 OK; V17 da 158 valores idénticos byte a byte a la referencia (sha256 `27ec46c0…`);
  - testthat 1898 PASS / 0 FAIL / 0 ERROR / 1 SKIP (31 archivos, 343 bloques).
- **CI** (runs 37700318583, push, y 37700323754, pull_request; los dos en verde):
  - testthat 1900 PASS / 0 SKIP;
  - en los dos runners salió L2 (sha256 `bbcd84a1…`): 4 decisiones del MH distintas en G3 y ninguna en G1;
  - máx |dif| / MCSE: media 1,5; covarianza 1,7; λ 1,2; SOC 1,4; SUR 0,096.

  Con eso, la diferencia de L2 frente a Windows queda en uno o dos errores de Monte Carlo.

---

## Tope de costo y representantes (F5-14, ítem B5 del checklist; decidida por Harold el 2026-10-08)

F5-14 deja para un commit anterior a la corrida sobre L3 el tope de costo, los representantes por familia de R1, R2,
R5 y R6 y, con F5-11, la variante de la validación anidada. El tope se fija ahora, antes de B3, porque los YAML de B3 y
B4 declaran la variante de F5-11. B3, B3b y B4 todavía no están medidos, así que la cuenta que decide si el tope se
supera se rehace al cerrar B4 (abajo, «Cuenta final»).

**Costo proyectado con lo medido hasta hoy.** Sandbox Windows de la máquina de Harold y datos sintéticos; las cifras
por origen son las registradas en B1b, B2a y B2b. Los grupos tienen 52, 45 y 25 orígenes, y R2 y R5 corren solo en G2
y G3.

| Pieza de una pasada de `make eval` | Minutos |
|---|---|
| Verificación V1-V17 (sandbox) | 17,0 |
| 13 `F5_REPRO_*` (benchmarks; ≈ 287 s en la máquina de Harold) | 4,8 |
| Principal (`F5_G1` a `F5_G3`) | 49,6 |
| R7 (modelos con UT de G2 y G3) | 24,9 |
| R1 / R2 / R5 / R6 | 49,6 / 29,8 / 29,8 / 49,6 |
| **Total con B1 y B2** | **≈ 255 (4 h 15 min)** |

- Supuestos de la proyección:
  - benchmarks, X-13 y MCS: 287 s entre 506 pares origen-experimento, ≈ 0,57 s por origen;
  - B1 completo: ≈ 4,9 s por origen (unos 10 minutos en los tres principales);
  - VAR y VECM: 0,07 a 0,10 s por origen;
  - BVAR: el punto medio de lo medido, 17,2 s en G1, 17,9 s en G2 y 23,7 s en G3;
  - ARIMAX con UT en R7: 0,8 s, la cota de «menos de 1 s».
- El BVAR pone 123 de los 159 minutos de R1, R2, R5 y R6 (77 %). Sin él en esas cuatro variantes, la pasada baja a
  ≈ 132 minutos (2 h 12 min).

Las seis decisiones (F5-14a a F5-14f) se tomaron en la opción recomendada.

- **F5-14a · Tope. DECIDIDO:** 8 horas de reloj para **una** pasada completa de `make eval` en la máquina de Harold
  (verificación, `F5_REPRO_*` y todos los `F5_*`). Se proyecta con el costo por origen medido en datos sintéticos por
  los orígenes de cada experimento. Una pasada cabe en una noche. La repetición que comprueba el bit a bit de E2 (F1)
  es una segunda pasada y no entra al tope. Descartadas: 4 horas, que ya se superan con B1 y B2, y 12 horas.
- **F5-14b · Ejecución. DECIDIDO:** `make eval` sigue siendo secuencial; no se paraleliza por experimento. Si la cuenta
  final supera el tope, se le vuelve a preguntar a Harold, con la cifra, si se paraleliza antes de aplicar los
  representantes. Descartada por ahora: paralelizar por experimento con procesos PSOCK y escribir el registro al
  final. Las semillas por (exp_id, modelo, origen) lo permitirían sin cambiar resultados, pero agrega código al motor
  antes de E1.
- **F5-14c · Familias y representantes. DECIDIDO:** una familia es un bloque de F5-01: B2 (multivariados), B3
  (regularizados), B3b (frecuencia mixta) y B4 (árboles). Los univariados de B1 (ARIMA, UC y las ARIMAX) corren
  siempre. El representante de B2 es `MULT.VAR_DIF` (`.G1`, `.G2` y `.G3`), que está en los tres grupos y cuesta menos
  de 0,1 s por origen. Los representantes de B3, B3b y B4 se fijan en el PR de cada bloque, con su costo medido y antes
  de E1. Si el tope se supera, la robustez del BVAR queda solo en R3, R4 y R7, y se declara. Descartadas: el BVAR como
  representante de B2, que casi no ahorra, y nombrar ya los cuatro representantes sin el costo de B3, B3b y B4.
- **F5-14d · Orden de las palancas. DECIDIDO:** si la cuenta final supera el tope, primero se aplican los
  representantes en R1, R2, R5 y R6. La variante de F5-11 que reoptimiza solo en los orígenes Q1 se aplica solo si,
  con representantes, la cuenta todavía supera el tope. Así la principal conserva la reoptimización en cada origen,
  simétrica con la selección por BIC. Descartadas: la variante Q1 primero y las dos a la vez.
- **F5-14e · Combinaciones en las variantes con representantes. DECIDIDO:** si R1, R2, R5 y R6 corren con
  representantes, sus combinaciones (F5-13) llevan los miembros presentes en la variante: univariados y
  representantes. Los miembros se declaran en el YAML y el manifiesto dice que no es la misma combinación que la
  principal. Descartada: quitar las combinaciones de esas variantes, que reabriría F5-14.
- **F5-14f · Extracciones del BVAR. DECIDIDO:** no se reabre B2-7; el BVAR sigue con 10 000 extracciones y 5 000 de
  calentamiento. El error de Monte Carlo de la media (F1-3: de 0,01 pp en h = 1 a unos 0,14 pp de la tasa interanual en
  h = 8) es más de un orden de magnitud menor que la desviación estándar de esa tasa sin 2020 (3,68 pp, protocolo §5).
  Descartada: 5 000 / 2 500, que reduce a la mitad el costo del BVAR y multiplica el error de Monte Carlo por √2.

**Cuenta final (al cerrar B4, antes de E1).**

- Se mide con datos sintéticos el costo por origen de cada modelo de Fase 5 en el primer y el último origen de su
  grupo, como se hizo con el BVAR, y se proyecta una pasada con los experimentos declarados.
- La cifra y lo que dispara entran en un commit anterior al de congelamiento del preregistro (E1), que se cita
  (protocolo §6, nota I1). Si la cuenta supera el tope, se sigue el orden de F5-14b, F5-14c y F5-14d. Si ni con las tres
  palancas cabe, se le vuelve a preguntar a Harold.
- Hasta entonces, los YAML de B3 y B4 declaran la reoptimización en cada origen. Si la cuenta final activa la variante
  Q1, ese commit los modifica antes de E1.
- Cada PR de B3, B3b y B4 registra su costo por origen, como lo hicieron B1, B2a y B2b.

**Nota (2026-10-08, B3).** El costo de B3 está medido (PR 2 de B3, en «Implementación del bloque B3»): el elastic net
cuesta de 1,5 a 3,0 s por origen y el PCR de 0,35 a 0,46 s. B3 suma unos 23 minutos por pasada, y la proyección pasa a
unos 278 minutos (4 h 38 min). El representante de B3 es `REG.ENET` (B3-9, decisión delegada al agente).

**Nota (2026-10-08, B3b).** El costo de B3b está medido («Implementación del bloque B3b»): U-MIDAS y puente cuestan menos
de 0,2 s por origen y suman unos 3 minutos por pasada (unos 281 en total). El representante de B3b es `MIX.PUENTE`
(B3b-7, decisión delegada al agente).

**Nota (2026-10-08, B4).** El costo de B4 está medido («Implementación del bloque B4»): el RF cuesta de 14 a 40 s por
origen y LightGBM de 73 a 109 s. B4 suma unos 1142 minutos por pasada, y la proyección pasa a unos 1423 minutos
(23 h 43 min), sobre el tope de 8 h. El representante de B4 es `ML.RF` (B4-5, decisión delegada al
agente). Las cifras son provisionales (se midieron con otro proceso R en paralelo); la cuenta final (F5-14b a F5-14d) se hace con todos los bloques.

---

## Implementación del bloque B3 (decidida por Harold el 2026-10-08)

Al llevar F5-05, F5-09, F5-11 y F5-12 a código aparecieron ocho puntos que las fichas no fijaban. Uno de ellos (B3-4)
viene de un dato nuevo sobre F5-11. Se le presentaron a Harold como preguntas antes de escribir código (Regla 4), y los
ocho se decidieron en la opción recomendada.

- **B3-1 · Rejilla de λ del elastic net. DECIDIDO:** en cada origen, `h` y α, 100 valores log-espaciados desde el
  λ_max de la ventana final (las filas con t + h ≤ o) hasta λ_max · 10⁻³. La misma rejilla sirve para las 12
  estimaciones internas y para la final, como en `cv.glmnet`. La rejilla usa datos ≤ o y nunca posteriores (G-1).
  Descartadas: una rejilla relativa al λ_max de cada ventana interna, en la que un mismo cociente significa
  penalizaciones distintas en ventanas distintas, y el defecto de `glmnet` (`lambda.min.ratio` de 10⁻⁴ o de 10⁻²
  según sea n ≥ p o n < p), que cambia con el grupo y con la ventana.
- **B3-2 · Estacionalidad de las predictoras NSA. DECIDIDO:** en cada ventana de estimación, la final y cada interna,
  se residualizan por MCO, dentro de la ventana, cada columna Δlog con sus rezagos y g_h sobre constante + 3 dummies
  trimestrales. Después, cada columna se estandariza con la desviación que queda. El ENET (`glmnet` con
  `standardize = FALSE`) y el PCR trabajan sobre esas columnas, y la fila de pronóstico se transforma con los
  coeficientes y las escalas de la ventana. Por Frisch-Waugh-Lovell equivale a las dummies sin penalizar de F5-09, con
  la escala no estacional de cada columna. Precisa la «estandarización dentro de la ventana de estimación» de F5-09
  (nota fechada en la ficha). Descartada: la letra de F5-09, con la estandarización de `glmnet` sobre las columnas
  crudas. Con ella, la estacionalidad domina la desviación de una NSA, así que su señal no estacional queda más
  penalizada que la de una SA, y los primeros componentes del PCR recogen estacionalidad.
- **B3-3 · Rezagos del PIB en el PCR. DECIDIDO:** entran al PCA junto con las predictoras. Es la letra de F5-09 y da
  el mismo conjunto de información que el ENET. El PCR es el MCO de g_h sobre constante + dummies + k componentes.
  Descartada: la forma DI-AR de Stock y Watson (2002), con los 4 rezagos del PIB fuera del PCA (8 + k parámetros), que
  no cabe en la estimación interna más chica de G2 y G3 a h = 8, de 9 filas.
- **B3-4 · K = 12 en horizontes largos (dato nuevo sobre F5-11). DECIDIDO:** se mantiene K = 12 en todos los h, con
  las rejillas completas. La estimación interna más chica tiene n_L − 15 − 2h filas, donde n_L son los trimestres en
  niveles hasta el origen. En el primer origen de G2 y G3 (n_L = 40) son 23, 21, 17 y 9 filas en h = 1, 2, 4 y 8, y en
  el de G1 (n_L = 77), 60, 58, 54 y 46. La estimación final tiene n_L − 4 − h filas: 35, 34, 32 y 28 en G2 y G3. Se
  declara como límite que la selección es ruidosa en h = 8 en los primeros orígenes de G2 y G3, donde de todos modos
  no se interpretan exclusiones del MCS. `diagnosticos.csv` reporta, para cada h, las filas de la ventana interna más
  chica y las de la final. Descartado: un piso de 20 filas por origen interno. Haría variar K con el origen y con h,
  lo que F5-11 descartó, y en el primer origen de G2 y G3 a h = 8 dejaría un solo origen interno.
- **B3-5 · Orígenes internos de la covarianza h × h. DECIDIDO:** Σ = D · R · D. La varianza de cada h sale de sus 12
  errores internos propios (o − h − 11..o − h), los mismos con que se eligió su hiperparámetro. Las correlaciones entre
  horizontes salen de los 12 orígenes internos comunes a h = 1..8 (o − 19..o − 8). En los orígenes comunes que no son
  propios de un h, su candidato elegido se estima también, con a lo sumo 7 estimaciones más por h. La matriz es
  semidefinida positiva por construcción. Descartadas: armar toda la matriz con los orígenes comunes, porque la
  varianza de h = 1 saldría de errores de 8 a 19 trimestres atrás, y estimar cada elemento con sus propios orígenes
  comunes y proyectar después a la matriz semidefinida positiva más cercana.
- **B3-6 · Segundo momento. DECIDIDO:** sin centrar, 1/K Σ e e'. La diagonal es el ECM interno del candidato
  elegido, y R son las correlaciones de los momentos sin centrar. Así se incluye el sesgo de los errores internos, lo
  que es coherente con un pronóstico puntual que no corrige el sesgo y con el criterio de selección. Descartada: la
  covarianza centrada (`stats::cov`, n − 1), que ignora el sesgo.
- **B3-7 · Guardas (Regla 7) y bordes de la rejilla. DECIDIDO:** `stop()` ante cualquiera de estos casos:
  - NA o valores no finitos;
  - una columna sin variación no estacional en una ventana;
  - una senda de `glmnet` incompleta o coeficientes no finitos;
  - un MCO del PCR que pierde rango o tiene menos filas que parámetros;
  - una covarianza que no es definida positiva.

  Un λ elegido en un extremo de la rejilla, o k = 5, se anota en `diagnosticos.csv` y no detiene el motor. `piso_gl =
  FALSE` (F5-09), y no se aplica la guarda de número de condición de las ARIMAX (B1b-2). Descartado: `stop()` también
  en el borde, que en la corrida única detendría toda la pasada por una sola celda.
- **B3-8 · Dos PR, uno después del otro y sin apilar. DECIDIDO:** el primero lleva la infraestructura, que B4 puede
  reutilizar: C3 (forma directa), C4 (validación anidada, con su prueba de que no usa datos posteriores al origen) y
  la covarianza de errores internos. El segundo, cuando el primero esté en `main`, lleva `REG.ENET.Gk` y `REG.PCR.Gk`
  con sus YAML, el canario V18 y el costo por origen. Es otra excepción declarada a «un PR por bloque» de F5-01, como
  B1-4 y B2-8.

**Decisiones menores del agente en el PR 1 de B3.** Son revertibles en un commit. Ninguna cambia un resultado de
Fase 4 ni de los `F5_REPRO_*`: el motor no cambia y el registro de Fase 5 tampoco.

- **Ubicación del código:** `src/evaluacion/forma_directa.R`, que se carga desde `modelos_fase5.R`. Por tema:
  - matriz y objetivo: `matriz_directa()` y `crecimiento_acumulado()`;
  - ventana de B3-2: `ventana_directa()` y `aplicar_ventana()`;
  - validación anidada (C4): `origenes_internos()`, `origenes_comunes()`, `pronosticos_internos()` y
    `seleccionar_candidato()`;
  - covarianza (B3-5 y B3-6): `cov_errores_internos()`;
  - ajuste y fábrica: `ajustar_directo()` y `modelo_directo()`.

  Un modelo directo declara una especificación con tres elementos: `candidatos()` (la rejilla del origen y de h,
  calculada sobre la ventana final), `estimar_predecir()` y `transformar` (TRUE para aplicar la ventana de B3-2). B4
  decide si los árboles la usan.
- **Muestra:** como en B1 y B2, cada modelo empieza donde empiezan todas sus series. La primera fila es la primera con
  Δy y todos los Δlog con sus rezagos.
- **Los ocho horizontes:** se estima un modelo directo para cada h = 1..8, aunque solo se evalúan 1, 2, 4 y 8. El
  contrato pide el sendero completo (G-3), y la tasa interanual en h > 4 y la trimestral necesitan la covarianza 8 × 8.
- **Escala de la estandarización:** la raíz del promedio de los residuos al cuadrado (denominador n, la convención de
  `glmnet`). Un factor común a todas las columnas no cambia los componentes ni la rejilla de B3-1, que es relativa a
  λ_max.
- **Empates en el ECM interno:** gana el primer candidato de la rejilla. Los modelos la ordenan de más a menos
  penalizado.
- **Errores del elegido en los orígenes comunes:** donde esos orígenes no son propios de un h, el candidato elegido
  se estima con la misma rejilla. Así, el error coincide con el que habría dado la pasada de selección (prueba en
  `tests/test-forma-directa.R`).
- **Guardas de la ventana (B3-7):** `stop()` también en tres casos más:
  - la ventana tiene tantas filas como regresores deterministas, o menos;
  - las dummies pierden rango;
  - un origen interno queda antes de la primera fila con todos los rezagos.
- **Diagnósticos por origen:** las filas y columnas de la matriz y, para cada h, el candidato elegido, su ECM interno
  y las filas de la ventana interna más chica y de la final. Cada modelo agrega los suyos (α, λ, borde de la rejilla,
  k).
- **Dato para el PR 2 (verificado el 2026-10-08 con `glmnet` 5.0 en el sandbox):** con `standardize = FALSE` e
  `intercept = FALSE`, λ_max = max |Z'g| / (n · max(α, 10⁻³)) coincide con el que calcula `glmnet`. En una prueba con
  9 filas y 31 columnas (p > n), la senda que genera `glmnet` con su propia rejilla se corta antes de los 100 valores:
  61 en α = 1 y 63 en α = 0,5. Con la rejilla pasada de forma explícita devuelve los 100. El PR 2 pasa la rejilla
  explícita y no toca `glmnet.control()`, que es estado global.

**PR 2 de B3 (2026-10-08): `REG.ENET.Gk` y `REG.PCR.Gk`.** Harold autorizó el 2026-10-08 que el agente avance sin
supervisión. Lo que este PR fija y las fichas no fijaban es decisión delegada al agente y se puede reabrir.

- **B3-9 · Representante de B3 (F5-14c). DECIDIDO por el agente (decisión delegada, 2026-10-08; se puede reabrir):**
  `REG.ENET.Gk`. Con el costo medido (abajo), la diferencia entre llevar el elastic net o el PCR en R1, R2, R5 y R6 es
  de unos 11 minutos por pasada, el 2 % del tope de 8 h. El elastic net es el regularizado más general: con α = 0 y
  α = 1 contiene a ridge y lasso. Descartado: el PCR, más barato, que representa a la familia por un solo mecanismo
  (componentes principales).
- **Costo observado (dato para F5-14; sandbox Windows, datos sintéticos con las fechas de inicio de L3; mediana de tres
  ajustes después de cargar `glmnet`), en segundos por origen:**

  | Modelo | G1 primero / último | G2 primero / último | G3 primero / último |
  |---|---|---|---|
  | `REG.ENET` | 1,49 / 1,60 | 2,23 / 1,94 | 2,01 / 3,00 |
  | `REG.PCR` | 0,36 / 0,36 | 0,36 / 0,39 | 0,35 / 0,46 |

  Con los puntos medios y los orígenes de cada experimento (52, 45 y 25; R2 y R5 solo en G2 y G3), B3 suma por pasada
  unos 4,7 minutos en la principal, 3,1 en R7, 4,7 en R1 y en R6 y 3,1 en R2 y en R5: unos 23 minutos. La proyección
  de F5-14 pasa de unos 255 a unos 278 minutos (4 h 38 min).
- **V18** (canario de B3, en la verificación sintética; unos 4 minutos en el sandbox):
  - el elastic net sobre un DGP con una predictora adelantada entre dos ruidos (uno NSA, que ejercita B3-2) bate al
    AR(p)-BIC con razón de RMSE < 0,8 en h = 1, 2 (0,60 y 0,75);
  - el PCR sobre un DGP de factor con tres predictoras bate al AR(p)-BIC con razón < 0,9 (0,65 y 0,79);
  - con un placebo, el elastic net no empeora al AR(p)-BIC en más de 10 % en h = 1 (1,04);
  - reejecutar dos orígenes reproduce bit a bit sendero, densidad y diagnósticos.
- **Límite declarado: la densidad de errores internos subcubre.** En V18, la cobertura al 80 % va de 0,64 a 0,81 y al
  95 % de 0,86 a 0,96 en h = 1, 2, 4, con la mayor subcobertura en h = 4. Hay dos causas: la varianza se estima con
  12 errores y el candidato elegido es el de menor ECM interno, que subestima su error fuera de muestra. V18 lo admite
  con una holgura inferior declarada de 0,10 además de 3 ee de MC (V14 a V16 usan 0,03). En la corrida única, la
  calibración de los regularizados (y de los árboles, si B4 usa la misma densidad) se lee con este límite. Corregirlo,
  por ejemplo con cuantiles t o un factor de inflación, sería una decisión metodológica nueva, que queda para Harold.

**Decisiones menores del agente en el PR 2 de B3** (revertibles en un commit; ninguna cambia un resultado de Fase 4 ni de
los `F5_REPRO_*`, que solo corren benchmarks):

- **Código:** `src/evaluacion/modelos_regularizados.R` (`rejilla_enet()`, `estimar_predecir_enet()`,
  `estimar_predecir_pcr()`, `modelos_regularizados_grupo()`), que se carga desde `modelos_fase5.R`. Los regularizados
  van en el registro después del BVAR.
- **λ_max** con la fórmula de `glmnet` para `standardize = FALSE` e `intercept = FALSE`, verificada contra el primer λ
  de `glmnet` en `tests/test-modelos-regularizados.R`. La rejilla se pasa explícita y no se toca `glmnet.control()`.
- **Senda completa por α:** aunque se pida un solo candidato, se estima la senda de las 100 λ de su α. Así el
  pronóstico de un candidato no depende de qué otros se piden, y el error del elegido en los orígenes comunes coincide
  con el de la pasada de selección.
- **PCR:** `stats::prcomp(center = FALSE, scale. = FALSE)` sobre la ventana ya transformada. MCO sin constante sobre
  los componentes: g_h y las columnas ya están residualizadas sobre la constante y las dummies. La guarda de B3-7 se
  comprueba sobre la varianza del componente k: un componente sin varianza indica pérdida de rango o menos filas que
  parámetros.
- **Diagnósticos por h:** en el ENET, α, λ, posición de λ en la rejilla y bandera de borde (posición 1 o 100); en el
  PCR, k y bandera de borde (k = 5).

---

## Implementación del bloque B3b (2026-10-08; decisiones delegadas al agente)

Harold autorizó el 2026-10-08 que el agente avance sin supervisión. Al llevar F5-08 a código aparecieron siete puntos que
la ficha no fijaba; todos son **decisiones delegadas al agente** (tomadas en la opción que se habría recomendado) y se
pueden reabrir.

- **B3b-1 · Meses del U-MIDAS por grupo (el piso de F5-03). DECIDIDO (delegada):** la predictora i entra en los meses
  m(t) + d_i, ..., m(t) + 1 (los d_i meses de t+1 que el calendario admite en el origen: 2 en remesas, FOB, ITCER, UT e
  IPP; 1 en IVAE e IPM) y, en G1, también en m(t), ..., m(t) − 5, la letra de F5-08 (16 columnas). En G2 y G3 entra solo
  en m(t) + d_i, su último mes admitido (6 y 7 columnas). El U-MIDAS es directo por h y su estimación final más chica es
  la de h = 8: en el primer origen tiene 67, 32 y 33 filas en G1, G2 y G3, y con los parámetros (columnas + constante + 3
  dummies) quedan 47, 22 y 22 grados de libertad. En G2, con un solo mes más por predictora (m(t)), quedarían 12, bajo
  el piso; con la letra de F5-08 habría más parámetros que filas. Descartadas: el U-MIDAS de G2 y G3 solo con algunas
  predictoras (reabre F5-06/F5-08 y B1b-2) y aplicar el piso solo en h = 1 (contradice F5-03).
- **B3b-2 · Guardas de los modelos de frecuencia mixta. DECIDIDO (delegada):** las de las ARIMAX (B1b-1): `stop()` si la
  matriz pierde rango o si el número de condición de los regresores estandarizados supera 1e4, y si una predictora
  mensual no llega al último mes del origen. En el U-MIDAS el número de condición se mide en la ventana final de cada h y
  el piso (G-8) se comprueba antes de la validación anidada, porque con menos filas que parámetros las ventanas internas
  no se pueden estimar.
- **B3b-3 · Densidad del U-MIDAS (F5-12 no lo nombra). DECIDIDO (delegada):** la de los modelos directos, Σ = D·R·D de
  los errores internos sin centrar (B3-5, B3-6), con la validación anidada de F5-11 solo para producir esos errores: el
  U-MIDAS tiene una sola especificación y no elige hiperparámetros, así que no tiene el sesgo de selección de B3. En V19
  cubre 0,77 a 0,78 al 80 % y 0,91 a 0,94 al 95 % en h = 1, 2, 4. Descartadas: la covarianza de los residuos dentro de
  muestra de las ocho regresiones directas (subestima más) y dejarlo sin densidad.
- **B3b-4 · AR mensual y agregación del puente. DECIDIDO (delegada):** AR(p)-BIC mensual en Δlog con p en 0..12 (un
  año, la analogía de p ≤ 4 trimestral de F5-05) y dummies mensuales si la serie es NSA, con la regla de
  `seleccionar_ar_bic_x()`. Los meses de o+1 que el calendario admite entran observados y el resto se proyecta hasta el
  último mes de o+8. El agregado trimestral sigue la regla de T00x (suma en flujos, promedio en índices); el Δlog
  trimestral es el mismo con las dos, porque difieren en un factor 3.
- **B3b-5 · Densidad del puente: linealización de la agregación. DECIDIDO (delegada):** el sistema lineal conjunto de
  F5-12 con el Δlog trimestral de un agregado linealizado en los Δlog mensuales, (Δl_m + 2 Δl_{m−1} + 3 Δl_{m−2} +
  2 Δl_{m−3} + Δl_{m−4}) / 3, con m el último mes del trimestre (log de la suma ≈ promedio de los logs; la aproximación
  de Mariano y Murasawa, 2003). El punto usa la agregación exacta. Una prueba compara la covarianza analítica con una
  simulación del sistema con la agregación exacta (diferencia de las desviaciones < 6 %).
- **B3b-6 · Innovaciones del puente. DECIDIDO (delegada):** la covarianza completa, en analogía con B1-5: Σ_u, la
  covarianza contemporánea de los residuos de los AR mensuales (independientes entre meses), y la covarianza de la
  innovación del puente con las innovaciones mensuales de los meses del mismo trimestre, estimada en los trimestres de la
  regresión. Si con esos términos la matriz conjunta del trimestre no es definida positiva, se reducen (λ, con un
  complemento de Schur de al menos 0,05 σ²_e) y λ va a `diagnosticos.csv`. Razón (dato de V19): con la innovación del
  puente independiente, la densidad subcubría (0,68 a 0,79 al 80 % en h = 1, 2, 4; en h = 1 la desviación prevista era
  14 % menor que el RMSE), porque el puente es una aproximación y su innovación correlaciona con la del mes que falta;
  con los términos cruzados cubre 0,77 a 0,84 al 80 % y 0,94 a 0,98 al 95 %. Descartada: la innovación del puente
  independiente de las mensuales.
- **B3b-7 · Representante de B3b (F5-14c). DECIDIDO (delegada):** `MIX.PUENTE.Gk`. Los dos cuestan menos de 0,2 s por
  origen; el puente es el modelo de frecuencia mixta más usado en la práctica, su densidad es analítica y conserva todas
  las predictoras con su borde en los tres grupos, mientras que el U-MIDAS de G2 y G3 queda reducido por el piso a un mes
  por predictora.

**Decisiones menores del agente en B3b** (revertibles en un commit; ninguna cambia un resultado de Fase 4 ni de los
`F5_REPRO_*`):

- **Código:** `src/evaluacion/modelos_frecuencia_mixta.R`: utilidades mensuales (`ultimo_mes_trimestre()`,
  `dummies_mensuales()`, `seleccionar_ar_bic_m()`, `.proyectar_ar_m()`), el U-MIDAS (`matriz_umidas()`,
  `especificacion_umidas()`, `modelo_umidas_grupo()`) y el puente (`ajustar_puente()`, `sendero_puente()`,
  `cov_sistema_puente()`, `modelo_puente_grupo()`). Se carga desde `modelos_fase5.R` y va en el registro después de los
  regularizados (orden de F5-01).
- **`forma_directa.R`** admite una matriz propia (`construir`) y un piso (`piso_gl` en la especificación): el ajuste
  devuelve `gl` con las filas de la estimación final de h = 8 y G-8 se comprueba antes de la validación anidada. Los
  regularizados no cambian.
- **U-MIDAS sin término autorregresivo** (la letra de F5-08: el PIB sobre los meses de las predictoras); el puente sí
  lleva su AR(1).
- **Desfase del U-MIDAS:** d_i se lee en el origen como meses entre el último mes de la predictora y el último mes de o;
  G-7 garantiza que es el del calendario. En las filas históricas se usa el mismo d_i (el borde se replica en la
  historia).
- **Diagnósticos por origen:** en el U-MIDAS, por h, el número de condición de la ventana final, el ECM interno y las
  filas; en el puente, observaciones, número de condición, φ, σ_e, meses comunes de Σ_u, λ de B3b-6 y el p de cada AR
  mensual.
- **V19** (canario de B3b, en la verificación sintética; unos 2 minutos):
  - con una predictora mensual cuyo promedio trimestral mueve al PIB y 2 meses de o+1 en el borde, el U-MIDAS y el
    puente baten al AR(p)-BIC con razón de RMSE < 0,7 en h = 1 (0,55 y 0,60);
  - cobertura del puente dentro de ±(3 ee + 0,03), como V14 a V16, y del U-MIDAS con la holgura de V18;
  - con un placebo, ninguno empeora al AR(p)-BIC en más de 10 % en h = 1 (1,01 y 1,02);
  - reejecutar dos orígenes reproduce bit a bit.
- **Costo observado (dato para F5-14; sandbox Windows, datos sintéticos con las fechas de inicio de L3, mediana de tres
  ajustes con la densidad), en segundos por origen:**

  | Modelo | G1 primero / último | G2 primero / último | G3 primero / último |
  |---|---|---|---|
  | `MIX.UMIDAS` | 0,16 / 0,20 | 0,17 / 0,18 | 0,20 / 0,20 |
  | `MIX.PUENTE` | 0,03 / 0,06 | 0,12 / 0,13 | 0,12 / 0,16 |

  B3b suma unos 40 segundos en la principal y unos 3 minutos por pasada con todas las variantes. La proyección de F5-14
  queda en unos 281 minutos (4 h 41 min).

---

## Implementación del bloque B4 (2026-10-08; decisiones delegadas al agente)

Harold autorizó el 2026-10-08 que el agente avance sin supervisión. Al llevar F5-10, F5-11, F5-12 y F5-15 a código sobre
la infraestructura de B3 (`forma_directa.R`, B3-8) aparecieron seis puntos que las fichas no fijaban. Los seis son
decisiones delegadas al agente (2026-10-08) y se pueden reabrir. Ningún dato medido las contradice.

- **B4-1 · Ventana de estimación. DECIDIDO por el agente (decisión delegada, 2026-10-08; se puede reabrir):** los
  árboles usan la ventana de B3-2 (`transformar = TRUE`). En cada ventana, la final y cada interna, las columnas y g_h se
  residualizan sobre constante + 3 dummies trimestrales y las columnas se estandarizan. Los árboles reciben así el mismo
  conjunto de información que el ENET y el PCR, sin la estacionalidad de las NSA, y el pronóstico de g_h es la parte
  determinista de la ventana más el del árbol. La estandarización no cambia las particiones; la residualización sí, y
  evita que los árboles gasten particiones en el trimestre del año. Descartada: las columnas crudas
  (`transformar = FALSE`). Con ellas las primeras particiones sobre una NSA recogen estacionalidad y los árboles se
  comparan con B3 sobre otro conjunto de información.
- **B4-2 · Densidad. DECIDIDO por el agente (decisión delegada, 2026-10-08; se puede reabrir):** RF y LightGBM usan
  Σ = D · R · D de los errores internos (B3-5, B3-6), la misma de los regularizados. Descartados: los errores OOB del RF,
  que F5-12 dejaba abiertos. Son errores de bootstrap dentro de la muestra y no pseudo fuera de muestra en el tiempo:
  cada fila OOB se pronostica con árboles que vieron filas posteriores, no miden el error a h pasos y no existen en
  LightGBM, así que las dos densidades de B4 no serían comparables. El RF corre con `oob.error = FALSE`.
- **B4-3 · Rejilla y semilla del RF. DECIDIDO por el agente (decisión delegada, 2026-10-08; se puede reabrir):**
  - 500 árboles, mtry ∈ {⌈√p⌉, ⌈p/3⌉} y min.node.size ∈ {5, 3} (F5-10), con p = columnas de la matriz directa: 12, 28
    y 36 en G1, G2 y G3. En G1 los dos mtry valen 4 y la rejilla se deduplica: 2 candidatos en G1 y 4 en G2 y G3
    (mtry 6 y 10 en G2; 6 y 12 en G3);
  - orden de más a menos regularizado: min.node.size de mayor a menor y, dentro de cada uno, mtry de menor a mayor (más
    aleatoriedad por partición). Un empate en el ECM interno va al primero;
  - `num.threads = 1`; muestreo con reemplazo de n filas por árbol y partición por varianza (los defectos de `ranger`);
  - semilla: `estimar_predecir()` no recibe `semilla_de()`. Cada llamada (cada estimación interna o final) toma
    `seed = sample.int(.Machine$integer.max, 1)` del generador de R, que el motor siembra con
    `set.seed(semilla_de(exp_id, modelo, origen))` antes de `ajustar()`, y la pasa explícitamente a `ranger` (`seed =`,
    también en `predict()`). Es la forma en que se cumple la semilla del motor de F5-15, y está declarada en los YAML.
    La misma semilla sirve a los bosques de todos los candidatos de la llamada: el ECM interno compara hiperparámetros
    con los mismos números aleatorios.

  Descartadas: una semilla fija por modelo, que no depende del experimento ni del origen, y una semilla por candidato.
- **B4-4 · Rejilla de LightGBM. DECIDIDO por el agente (decisión delegada, 2026-10-08; se puede reabrir):**
  - num_leaves ∈ {4, 8}, learning_rate = 0,05 y min_data_in_leaf = 5 (F5-10), con rondas ∈ {10, 20, ..., 500}: 100
    candidatos, de menor a mayor num_leaves y, dentro de cada uno, de menos a más rondas. Un empate va al primero;
  - un entrenamiento por num_leaves hasta la mayor ronda pedida y el pronóstico con las primeras r rondas de cada
    candidato (`predict(num_iteration = r)`). Sin bagging, las primeras r rondas no dependen de cuántas más se entrenen
    (prueba en `tests/test-modelos-arboles.R`);
  - objetivo L2, `num_threads = 1`, `deterministic = TRUE`, `force_row_wise = TRUE` (F5-15), `verbose = -1` y la semilla
    del generador de R pasada como `seed =`, como en B4-3. Sin bagging ni submuestreo de columnas (los defectos), así
    que el ajuste no tiene componente aleatorio y con otra semilla da lo mismo (prueba);
  - con menos de 10 filas (2 · min_data_in_leaf) no hay partición posible. La ventana interna más chica de G2 y G3 a
    h = 8 en los primeros orígenes tiene 9 (B3-4). LightGBM deja entonces un árbol constante y pronostica la media de
    la ventana, sin error. Con la ventana de B4-1, el pronóstico de g_h es la media estacional de la ventana;
  - unas rondas elegidas en un extremo de la rejilla (10 o 500) se anotan en `diagnosticos.csv` y no detienen el motor
    (B3-7).

  Descartadas: la parada temprana con un conjunto de validación, que exige otra partición de ventanas de 9 a 30 filas,
  y una rejilla de rondas de 1 en 1, que agrega candidatos casi idénticos y multiplica por 10 las predicciones.
- **B4-5 · Representante de B4 (F5-14c). DECIDIDO por el agente (decisión delegada, 2026-10-08; se puede reabrir):**
  `ML.RF.Gk`. Con el costo medido (abajo), LightGBM cuesta de 3,4 a 5,1 veces lo que el RF por origen, y llevarlo en
  R1, R2, R5 y R6 suma unos 608 minutos por pasada, más que el tope de 8 h por sí solo. F5-10 ya declara que con 39-90
  datos LightGBM está en el límite de lo razonable. Descartado: `ML.LGBM.Gk`.
- **B4-6 · Canario V20. DECIDIDO por el agente (decisión delegada, 2026-10-08; se puede reabrir):** V19 queda reservado
  para B3b. V20 corre el RF sobre un DGP no lineal, en el que el PIB responde al valor absoluto de una predictora
  adelantada: Δy_t = 0,004 + 0,8 (|x_{t−1}| − E|x|) + e_t, con x AR(1) de coeficiente 0,6, junto a una SA de ruido. Un
  modelo lineal no aprovecha a x, porque Δy no tiene correlación lineal con x_{t−1}. Exige cuatro cosas:
  - que el RF bata al AR(p)-BIC con razón de RMSE < 0,8 en h = 1;
  - que la densidad de errores internos cubra en h = 1, 2, 4 con la holgura declarada de V18 (subcobertura de hasta
    0,10 además de 3 ee de MC);
  - que con un placebo (β = 0) el RF no empeore al AR(p)-BIC en más de 10 % en h = 1;
  - que reejecutar reproduzca bit a bit sendero, densidad y diagnósticos del RF (dos orígenes) y de LightGBM (uno).

  Para acotar el costo a unos 4 minutos, el RF corre con 50 árboles en lugar de 500 y LightGBM con 20 rondas como
  máximo, como V16 hizo con las extracciones del BVAR. Corre en uno de cada cuatro orígenes del diseño, con 2 réplicas y
  2 de placebo. LightGBM no entra a las comparaciones de RMSE ni de cobertura: aun con 50 rondas cuesta unos 19 s por
  origen en el sandbox. En la calibración, con una réplica y 50 rondas, su razón contra el AR(p)-BIC en h = 1 fue 0,49.
  Descartado: un canario con LightGBM de producción, que tardaría más de 20 minutos.

**Costo observado (dato para F5-14; sandbox Windows, datos sintéticos con las fechas de inicio de L3 de
`tests/test-modelos-regularizados.R`; configuración de producción; después de cargar `ranger` y `lightgbm`), en
segundos por origen.** El RF es la mediana de tres ajustes. LightGBM es un solo ajuste por celda, porque cada uno tarda
de 73 a 109 s; su ajuste no tiene componente aleatorio y el tiempo de los tres ajustes del RF varió menos de 5 %.
Durante la medición corría otro proceso de R en la máquina (12 núcleos; los dos de un hilo).

| Modelo | G1 primero / último | G2 primero / último | G3 primero / último |
|---|---|---|---|
| `ML.RF` | 14,06 / 26,31 | 14,46 / 39,86 | 15,24 / 28,70 |
| `ML.LGBM` | 103,47 / 104,23 | 75,32 / 109,26 | 73,24 / 108,50 |

- Origen de cada celda: el primero de cada grupo (2013-Q1, 2014-Q4 y 2019-Q4) y el último (2025-Q4).
- Por qué cuesta tanto LightGBM: en el sandbox, una ronda cuesta unos 0,34 ms dentro de la librería, casi sin depender
  de las filas ni de las columnas (500 rondas: unos 0,25 s con num_leaves = 4 y 0,37 s con 8). Cada origen pide 192
  entrenamientos internos (8 horizontes × 12 orígenes internos × 2 valores de num_leaves), más hasta 36 en los orígenes
  comunes y en la estimación final. El RF pide 420 bosques por origen en G2 y G3 (228 en G1).

**Proyección (F5-14).** Con los puntos medios y los orígenes de cada experimento (52, 45 y 25; R7, R2 y R5 solo en G2 y
G3), B4 suma por pasada:

| Experimento | `ML.RF` | `ML.LGBM` | B4 |
|---|---|---|---|
| Principal (`F5_G1` a `F5_G3`) | 47,0 | 197,1 | 244,1 |
| R7 (modelos con UT de G2 y G3) | 29,5 | 107,1 | 136,6 |
| R1 / R6 | 47,0 | 197,1 | 244,1 cada una |
| R2 / R5 | 29,5 | 107,1 | 136,6 cada una |
| **Pasada** | **229,6** | **912,6** | **≈ 1142 (19 h 2 min)** |

- Con B4, la proyección de F5-14 pasa de unos 281 (con B3b) a unos 1423 minutos (23 h 43 min). Supera el tope de 8 h
  (F5-14a).
- Solo como referencia: con los representantes en R1, R2, R5 y R6 (`MULT.VAR_DIF`, `REG.ENET` y `ML.RF`; F5-14c), B4
  sumaría unos 534 minutos y la pasada unos 686 (11 h 26 min), todavía sobre el tope. LightGBM en la principal y en R7
  pone 304 de esos minutos.
- Este PR no aplica ninguna palanca. La cuenta final la hace el agente principal al cerrar B4, con B3b medido y en un
  commit anterior a E1, y sigue el orden de F5-14b (preguntarle a Harold si se paraleliza), F5-14c y F5-14d.

**V20** (canario de B4, en la verificación sintética; unos 3 min 40 s en el sandbox, que no están en la proyección):

- el RF bate al AR(p)-BIC en h = 1 con razón de RMSE 0,626 (< 0,8); en h = 2 y h = 4, 0,835 y 0,955 (informativas);
- con un placebo, la razón en h = 1 es 0,997 (< 1,10). En la calibración, con 4 réplicas, la razón de cada réplica fue
  de 0,81 a 1,14 (1,01 con las cuatro); con una sola réplica el placebo no es confiable, y por eso lleva dos;
- reejecutar reproduce bit a bit el RF (dos orígenes) y LightGBM (un origen).

**Límite declarado: la densidad de errores internos del RF subcubre, más en h = 2 y h = 4.** En V20, la cobertura al
80 % es 0,846, 0,731 y 0,615 en h = 1, 2 y 4, y al 95 % 0,962, 0,808 y 0,885. Las causas son las de V18: la varianza se
estima con 12 errores internos y el candidato elegido es el de menor ECM interno. La mayor subcobertura es la de h = 4
al 80 % (0,185 por debajo del nominal).

- Con 2 réplicas, el ee de MC de cada celda va de 0,038 a 0,154, así que la condición de cobertura de V20 es débil: solo
  detecta una densidad muy mal calibrada. La evidencia de cobertura de la densidad de errores internos con más réplicas
  sigue siendo V18 (6 réplicas); V20 la extiende al RF con la misma regla y deja las cifras a la vista.
- En la corrida única, la calibración de los árboles se lee con este límite, como la de los regularizados. Corregirlo
  sería una decisión metodológica nueva, que queda para Harold.

**Decisiones menores del agente en B4** (revertibles en un commit; ninguna cambia un resultado de Fase 4 ni de los
`F5_REPRO_*`, que solo corren benchmarks):

- **Código:** `src/evaluacion/modelos_arboles.R` (`rejilla_rf()`, `estimar_predecir_rf()`, `rejilla_lgbm()`,
  `estimar_predecir_lgbm()`, `modelos_arboles_grupo()`), que se carga desde `modelos_fase5.R`. Los árboles van en el
  registro después de los regularizados (y, al integrar B3b, después de `MIX.*`). No cambian `eval_lib.R`,
  `motor_backtesting.R` ni `forma_directa.R`.
- **Defectos fijados en el código y en los YAML:** en `ranger`, `replace = TRUE`, `sample.fraction = 1`,
  `splitrule = "variance"` e `importance = "none"`; en `lightgbm`, `objective = "regression"`, sin bagging y
  `serializable = FALSE`, que no guarda una copia del modelo y no cambia los pronósticos.
- **`oob.error = FALSE`:** el OOB no se usa (B4-2) y cuesta tiempo; no cambia los pronósticos (comprobado).
- **Diagnósticos por h:** en el RF, mtry y min.node.size; en LightGBM, num_leaves, rondas y bandera de borde (10 o 500
  rondas). El RF no lleva bandera de borde: sus dos hiperparámetros solo toman los valores de F5-10.
- **Guardas (B3-7):** además de las de `forma_directa.R`, `stop()` si `ranger` devuelve otro número de árboles, si
  LightGBM no deja ninguna ronda o si los pronósticos no son finitos.
- **Pruebas:** `tests/test-modelos-arboles.R` tarda unos 4 minutos en el sandbox. LightGBM de producción cuesta unos
  70 s por origen, así que el primer origen corre con la configuración de producción en G2 (el caso de 9 filas) y con
  50 rondas como máximo en G1 y G3; la prueba de reproducibilidad usa 100 árboles y 20 rondas. Lo que se prueba ahí
  (filas, guardas y semilla) no depende del número de árboles ni de rondas.

**Nota (2026-10-08, CI de #44).** En CI (Ubuntu), V20 falló en la cobertura del RF al 95 % en h = 4: 0,846 contra una
cota de 0,85 con «ee 0,0000». Las dos réplicas dieron la misma cobertura, así que la desviación entre réplicas valía 0
y no estimaba el error de Monte Carlo. Se corrige la prueba, no la cota: el ee es ahora el mayor entre esa desviación y
el error binomial con los pares de las dos réplicas, que todavía lo subestima porque los errores a h > 1 se traslapan.
La holgura de V18 (0,10) no cambia. La misma corrida mostró que el RF no es idéntico entre sistemas: la razón de RMSE en
h = 1 fue 0,638 en Ubuntu y 0,626 en el sandbox de Windows, con el mismo DGP y las mismas semillas. Como con el BVAR
(F5-15, F1-3), el bit a bit se exige en una misma máquina; E2 corre en la de Harold.

---

## Implementación del bloque B5 (2026-10-08; decisiones delegadas al agente)

Harold autorizó el 2026-10-08 que el agente avance sin supervisión. Al llevar a código F5-13 (combinaciones), las
variantes de F5-14 y R7 (F5-04c) aparecieron cinco puntos que las fichas no fijaban. Los cinco son **decisiones
delegadas al agente** y se pueden reabrir. Ninguna cambia un resultado de Fase 4 ni de los `F5_REPRO_*`: las
combinaciones y las variantes solo existen en los experimentos `F5_G*`, que siguen bajo el candado de F5-02.

- **B5-1 · Errores de los pesos inversos al ECM. DECIDIDO (delegada):** en el origen o y el horizonte h, el error de
  cada miembro en cada par (o', h) con o' + h ≤ o se mide en la pérdida del experimento (yoy_pp, F4-04) contra el
  objetivo **como se ve en o**. En la principal es el ajuste X-13 reestimado en o (F4-09b). Con h ≤ 4 la base de la
  tasa es observada; con h > 4 sale del mismo sendero, como en `derivar_unidades()`. La combinación de o no usa nada
  posterior a o (G-1). El descuento es δ^((o − h) − o'): el par más reciente pesa 1. Descartadas: los errores contra el
  vintage de evaluación, que usa datos posteriores a o, y contra el objetivo visto en cada o', que mezcla vistas del
  objetivo.
- **B5-2 · Variantes de Fase 5. DECIDIDO (delegada):** se declaran como experimentos `F5_Gk_Rn` en
  `EXPERIMENTOS_VARIANTES_FASE5` (`motor_backtesting.R`), con el `exp_id` como sufijo de la variante y sin columnas
  nuevas en la tabla de experimentos, así que las salidas de los `F5_REPRO_*` no cambian. Son R1 (ventana rodante de
  92 trimestres) y R6 (ajuste estacional único de L3) en los tres grupos; R2 (muestra homogénea desde 2005) y R5
  (objetivo oficial con su ajuste) solo en G2 y G3, como en la proyección de F5-14; y R7 en G2 y G3. R3 y R4 siguen
  como submuestras dentro de la principal. Hasta la cuenta final de F5-14, R1, R2, R5 y R6 corren todos los modelos de
  Fase 5; si la cuenta aplica los representantes (F5-14c), ese commit cambia `modelos_experimento()` y los YAML de las
  combinaciones (F5-14e).
- **B5-3 · Predictoras en las ventanas de R1 y R2. DECIDIDO (delegada):** el motor se detenía con predictoras y una
  ventana distinta de la expansiva. Ahora, en cada origen, cada predictora se recorta al inicio de la ventana del
  objetivo (`recortar_inicio_predictora()`): las trimestrales desde ese trimestre y las mensuales desde su primer mes.
  La forma directa, los VAR y el puente pierden las primeras filas que piden sus rezagos, igual que el objetivo.
  Descartada: dejarles a las predictoras su historia completa. En R1 los modelos verían así más que la ventana rodante,
  y en R2 la muestra dejaría de ser homogénea.
- **B5-4 · Alcance de R7. DECIDIDO (delegada):** R7 corre los benchmarks y los modelos de Fase 5 que piden UT, trimestral
  o mensual. En G2 son `UNI.ARIMAX.G2`, `MULT.BVAR.G2`, `REG.ENET.G2`, `REG.PCR.G2`, `MIX.UMIDAS.G2`,
  `MIX.PUENTE.G2`, `ML.RF.G2` y `ML.LGBM.G2`; en G3, los mismos con `.G3`. El rezago de UT pasa de 30 a 61 días
  (`REZAGO_UT_R7`), el de IVAE e IPM: 1 mes de o+1 en lugar de 2. R7 no lleva combinaciones: mide la sensibilidad de
  los modelos con UT al supuesto de F5-04, y una combinación sin los modelos que no usan UT no sería comparable con la
  de la principal. Descartada: correr en R7 todos los modelos, que repite los que no cambian.
- **B5-5 · Implementación de las combinaciones. DECIDIDO (delegada):** son un paso de `correr_experimento()`, después de
  `correr_backtest()` y antes de las unidades y las métricas (`src/evaluacion/combinaciones.R`, F5-13). Así entran a
  RMSE, DM/GW, MCS y R3/R4 como un modelo más, y quedan fuera de la calibración, porque no tienen densidad (F5-12).
  - Combinan el log-nivel de cada h, que equivale a combinar el crecimiento acumulado porque y_o es común.
  - La recortada usa `mean(trim = 0,1)`: con 11, 12 y 13 miembros quita uno de cada lado.
  - Los pesos y el número de errores de `COMB.ECM_INV` van a `diagnosticos.csv`.
  - Los miembros se declaran en el YAML de cada combinación (`hiperparametros.miembros`). `main()` comprueba que son los
    modelos de Fase 5 del experimento (`verificar_miembros_combinaciones()`, C8) y hashea esos YAML en el manifiesto.
  - Con menos de dos miembros, el experimento no combina; con el registro, eso solo pasa en las pruebas.

**C6 (F5-15): V21.** La verificación sintética corre dos veces el registro de Fase 5 de G2 con la configuración de
producción (12 modelos), los seis benchmarks y las cuatro combinaciones, sobre insumos sintéticos con los inicios de L3,
en el primer origen de G2. Las dos corridas usan el mismo `exp_id` y distinta semilla global, y dan un sha256 idéntico
en pronósticos, densidades y diagnósticos. Con otro `exp_id` cambian el BVAR y el RF, que usan el generador. El bloque
corre en un solo origen para acotar el costo: unos 5 minutos en el sandbox, porque LightGBM cuesta 75 s por origen en
G2. En la cuenta de F5-14 entra con la verificación.

**Pruebas:** `tests/test-combinaciones.R` comprueba los cuatro esquemas contra cálculos independientes, los pesos de
`COMB.ECM_INV` con δ = 0,9 y los pares con o' + h ≤ o, la ausencia de mirada adelante (alterar el objetivo visto después
de o no cambia la combinación de o), las guardas, las variantes declaradas y el candado de F5-02. De punta a punta en
`correr_experimento()`, comprueba la principal con combinaciones, R7 con UT a 61 días y sin combinaciones, y R1 con las
predictoras recortadas. `tests/test-catalogo-modelos.R` comprueba los 12 YAML de las combinaciones contra el registro y
las constantes del código.

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
