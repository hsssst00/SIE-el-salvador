# Fase 4 — registro de decisiones de diseño

**Fecha:** 2026-09-24 · **Estado:** las trece fichas y la F4-09b decididas por Harold el mismo día (ver el Acta).
**Para qué sirve este documento.** Fase 4 no puede implementarse sin cerrar trece puntos.
Nueve son decisiones de diseño que el protocolo propone y Harold confirma o cambia; dos
exigen enmendar un ADR cerrado porque la realidad verificada del sistema contradice lo que
el ADR supuso; dos son deudas que Fase 3 difirió explícitamente. Ninguna se resuelve
mirando resultados de modelos: por el criterio de cierre de Fase 4, todas se cierran antes
de la primera estimación.

**Cómo leer cada ficha.** *Especificación vigente* es lo que hoy dicen los documentos
vinculantes. *Evidencia* son cifras comprobadas contra el árbol del repositorio en esta
fecha (todas en `doc/metodologia/reportes_fase4/evidencia_insumos_fase4.csv`, regenerable con `scripts/evidencia_insumos_fase4.R`). *Recomendación* es juicio de
especificación, no hecho verificado.

**Prioridad.** F4-03, F4-09 y F4-05 condicionan la arquitectura del motor: si cambian
después de escribirlo, hay que reescribir el bucle de orígenes. Las demás condicionan
tablas y documentos, no estructura.

---

## Acta de decisiones (2026-09-24)

Las trece fichas y la F4-09b quedaron resueltas en la opción recomendada. F4-06 se corrigió el mismo día (Δlog también para el IVAE). Cada ficha lleva la línea
**DECIDIDO** con el texto operativo; esta tabla es el índice.

| Código | Decisión adoptada | Documento a enmendar |
|---|---|---|
| F4-01 | Convención A; ventana inicial de 93 obs | ADR-002, nota de aclaración |
| F4-02 | Regla de calendario; UT solo años cerrados | ninguno (protocolo) |
| F4-03 | Datos revisados + pista real-time prospectiva | ADR-001 (enmienda), ADR-007 (cruce) |
| F4-04 | Pérdida interanual en pp | ninguno |
| F4-05 | Tres grupos G1/G2/G3 | ninguno (protocolo y token) |
| F4-06 | Regla uniforme a priori: Δlog en las ocho familias | nota de seguimiento de ADR-010 |
| F4-07 | Paseo aleatorio sin deriva como denominador | ninguno |
| F4-08 | Incluir 2020 + R4 obligatoria; dummies no anticipadas | ninguno |
| F4-09 | Ajuste estacional reestimado por origen | notas de seguimiento de ADR-001/ADR-004 |
| F4-10 | Rodante de 92 trimestres | ninguno |
| F4-11 | Token en `esquema_validacion` | ninguno |
| F4-12 | DM/GW/MCS propios, oráculo en Suggests, `yaml` a Imports | ADR-009, nota de seguimiento |
| F4-13 | Cierre por alcance | ninguno (se menciona en la nota de ADR-010) |
| F4-09b | Orden ARIMA automático por origen, `transform=log` fijo, AO declarados no anticipados | ADR-004 (nota) y ADR-001 (cruce) |
| F4-14 | AR(p)-BIC: `p` se selecciona con la muestra común y se reestima con la muestra máxima | ninguno (especificación del motor §5) |

### Punto nuevo que abre F4-09: F4-09b — selección de la especificación X-13 en cada origen

**DECIDIDO por Harold el 2026-09-24:** orden ARIMA seleccionado automáticamente en cada origen con datos ≤ origen; `transform=log` fijo (con los defaults de `seasonal` la transformación enviada es `auto`); detección automática de outliers desactivada, y los AO declarados entran solo desde el origen que los alcanza (2020-Q2 desde el origen 2020-Q2, 2020-Q3 desde 2020-Q3). El orden elegido se guarda por origen en L4. Registro: nota de seguimiento en ADR-004 con referencia cruzada en ADR-001.

La opción adoptada reestima el ajuste estacional en los 52 orígenes. El código vigente
(`l3_pib_objetivo_reglas.R`) llama `seasonal::seas()` con **selección automática** y descarta
el objeto del modelo tras leer los outliers — el hallazgo M2 de la revisión independiente de
Fase 3 ya había señalado que la especificación vive en prosa en `04_transformaciones` (T002:
`ARIMA(1 1 1)(0 1 1)`, `transform=log`, dos AO) y no está fijada en el código. Reestimar por
origen obliga a decidir qué se reestima:

- **(a) Selección automática dentro de cada origen** (recomendada): es lo que un analista
  habría hecho en tiempo real; el orden ARIMA y la transformación pueden cambiar entre
  orígenes, así que el motor guarda el orden seleccionado por origen como columna del
  artefacto de L4 y una prueba reporta su estabilidad. Resuelve M2 por la vía de registrar,
  no de congelar.
- **(b) Especificación congelada con `seasonal::static()`** tras la primera estimación,
  reestimando solo coeficientes: más estable y comparable entre orígenes, pero usa una
  especificación elegida con la muestra completa — la misma clase de filtración que F4-09
  vino a eliminar.

No bloquea el orden de implementación 1-4 del motor; sí bloquea el paso 5.

### F4-14 — muestra de estimación del benchmark AR(p)-BIC

**DECIDIDO por Harold el 2026-09-24.** El orden `p ∈ 0..8` se selecciona por BIC comparando los nueve
candidatos en la misma muestra común (la de `p = 8`); el `p` elegido se reestima con la muestra
máxima, descartando solo las `p` observaciones que sus rezagos exigen. En el primer origen eso son 91
observaciones en vez de 84. Era la única decisión que la especificación dejaba implícita (decía dónde se
selecciona, no dónde se estima). Efecto en la verificación sintética V4: el RMSE relativo medio pasa de
0,821 a 0,820 con DGP AR(1) y de 1,0076 a 1,0068 con DGP paseo aleatorio.

---

## F4-01 — Convención de indexación del origen

**DECIDIDO por Harold el 2026-09-24:** opción (a) — origen = último período estimado, de 2013-Q1 a 2025-Q4, target en origen+h, targets hasta 2026-Q1. Se corrige en ADR-002 la frase de la ventana inicial: 1990-T1 a 2013-T1, 93 observaciones.

**Enmienda un ADR cerrado.**

- **Especificación vigente.** ADR-002: ventana de estimación inicial 1990-T1 a 2012-T4 (92
  observaciones); evaluación desde 2013-T1; 52 reestimaciones, "un origen por trimestre,
  2013-T1 a 2025-T4"; orígenes evaluables 52 / 51 / 49 / 45.
- **Evidencia.** Con la serie real (145 obs, fin 2026-Q1) los cuatro conteos se reproducen
  bajo dos convenciones distintas: (A) origen = último período estimado, de 2013-Q1 a
  2025-Q4, targets hasta 2026-Q1 — primera muestra de 93 obs; (B) origen = último período
  estimado, de 2012-Q4 a 2025-Q3, targets hasta 2025-Q4 — primera muestra de 92 obs. Las
  variantes cruzadas dan 51 / 50 / 48 / 44 y 53 / 52 / 50 / 46. Las tres frases de ADR-002
  no son simultáneamente satisfacibles.
- **Opciones.** (a) Adoptar A y corregir en ADR-002 la frase de la ventana inicial a
  1990-T1–2013-T1, 93 obs. (b) Adoptar B y corregir la frase de la lista de orígenes a
  2012-T4–2025-T3, aceptando que 2026-Q1 no se evalúa. (c) Adoptar B con targets hasta
  2026-Q1 y actualizar los cuatro conteos a 53 / 52 / 50 / 46.
- **Recomendación: (a).** Preserva las dos cifras que el proyecto ya publicó como diseño
  (la lista de orígenes y los cuatro conteos, que además están transcritos en el protocolo
  vigente) y usa toda la muestra. La corrección es de una línea y es una aclaración de
  indexación, no un cambio de diseño.
- **Si se posterga:** el motor no puede escribirse; toda cifra de conteo de orígenes queda
  ambigua a un trimestre.
- **Documento a enmendar:** ADR-002, nota de aclaración fechada.

## F4-02 — Conjunto de información en cada origen y grano anual de UT

**DECIDIDO por Harold el 2026-09-24:** opción (a) — regla de calendario: cada serie entra hasta el último período cuya fecha de publicación declarada sea ≤ la del PIB del origen; UT solo con años cerrados.

- **Especificación vigente.** Nada lo fija. La senda (§5.5, §6.4) supone que el borde
  irregular es aprovechable; ningún ADR define qué observación de cada predictor existía en
  cada origen.
- **Evidencia.** Rezagos medianos del calendario de divulgación del BCR, en días tras el
  cierre del período: PIB trimestral 92; IVAE 61; índices de precios del comercio exterior
  61; ITCER 30; remesas 24; balanza comercial 24; IPP 10; IPC 8. Al publicarse el PIB del
  trimestre `o` se conocen 2 meses del trimestre `o+1` para IPP, remesas, exportaciones e
  ITCER, y 1 mes para IVAE e IPM, igual en los 52 orígenes (corregido el 2026-09-24: la
  primera versión decía 3 y 2 por un desfase de índice). UT tiene 25 vintages anuales con fecha sintética
  (31-dic; 31-jul para 2026): su grano de disponibilidad es anual.
- **Opciones.** (a) Regla de calendario: cada serie entra hasta el último período cuya
  fecha de publicación declarada sea ≤ la fecha de publicación del PIB del origen; UT entra
  solo con años completos cerrados antes de esa fecha. (b) Regla estilizada uniforme: todos
  los predictores entran hasta el trimestre `o` y nada más, renunciando al borde irregular.
  (c) Regla por familia de modelo: (b) para los modelos trimestrales y (a) solo para MIDAS
  y ecuaciones puente.
- **Recomendación: (a),** con UT restringida a años cerrados. Es la que hace verificable la
  ventaja informativa del SIE, es la que cita la senda como estándar de bancos centrales, y
  el calendario ya está en el repositorio, así que la regla es ejecutable y auditable. (b)
  desperdicia precisamente lo que el sistema aporta; (c) introduce dos conjuntos de
  información en un mismo MCS, que es lo que la prueba prohíbe.
- **Si se posterga:** los modelos con predictores no son implementables sin decidir esto en
  el código, que es exactamente la forma de filtración que el criterio de cierre busca
  evitar.
- **Documento a enmendar:** ninguno; se declara en el protocolo. Si se adopta (a), conviene
  una fila por familia en el protocolo con el rezago usado, para que el calendario no viva
  solo en el código.

## F4-03 — Vintage contra el que se evalúa

**DECIDIDO por Harold el 2026-09-24:** opción (a) — el ejercicio retrospectivo se declara con datos revisados en cada tabla, el motor filtra por vintage_id desde el primer día y se abre la pista real-time prospectiva. Requiere nota de enmienda a ADR-001 y mención cruzada en ADR-007.

**Enmienda un ADR cerrado. Es la decisión más pesada de Fase 4.**

- **Especificación vigente.** ADR-001: "evaluación contra el vintage disponible en cada
  origen de pronóstico (real-time) como criterio primario; la última revisión disponible se
  usa como comparación secundaria, no como referencia de evaluación". ADR-007 fija captura
  prospectiva como compromiso firme y reconstrucción retrospectiva como mejor empeño. La
  nota de cierre de Fase 3 dejó `vintage_id` en cada archivo de L3 para que Fase 4 "pueda
  filtrar por `vintage_id` en vez de reconstruir la dimensión desde cero".
- **Evidencia.** `08_vintages.csv` tiene 56 filas; solo 24 con fecha de publicación
  anterior a 2026 y **todas** son de `UT.DEMANDA_TOTAL_MENSUAL`. El PIB trimestral tiene un
  único vintage (`BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA.v2026-06`); el retropolado
  `v2019-03` no registra fecha de publicación. Ninguna publicación del BCR tiene un vintage
  previo a 2026-06. Para los 52 orígenes de 2013-2025 no existe el PIB tal como se conocía
  entonces.
- **Opciones.** (a) Declarar el ejercicio retrospectivo como evaluación con datos revisados
  e invertir, solo para él, el orden primario/secundario de ADR-001; mantener el filtro por
  `vintage_id` en el motor y abrir la pista real-time prospectiva. (b) Intentar la
  reconstrucción retrospectiva de vintages del PIB (ADR-007 vía b) antes de Fase 5: costo
  alto, resultado incierto, y bloquea el cronograma. (c) Restringir la evaluación a los
  orígenes con vintage disponible: hoy serían cero.
- **Recomendación: (a).** Es lo único ejecutable, y la honestidad del ejercicio se conserva
  declarando el límite en cada tabla en vez de fingir tiempo real. La pista prospectiva
  convierte la limitación en un resultado futuro del propio SIE: con un vintage por
  trimestre el ejercicio real-time se vuelve informativo hacia ~2030, y el estudio de
  revisiones del PIB (extensión 2 de la senda §9) es el subproducto natural.
- **Si se posterga:** el motor puede escribirse igual (filtra por `vintage_id` en ambos
  casos), pero ninguna tabla de Fase 5 puede rotularse, y el criterio primario de un ADR
  cerrado quedaría incumplido sin registro.
- **Documento a enmendar:** ADR-001, nota de enmienda; mención cruzada en ADR-007.

## F4-04 — Unidad en que se computa la pérdida

**DECIDIDO por Harold el 2026-09-24:** opción (a) — pérdida primaria sobre la tasa interanual en pp, con la asimetría entre h ≤ 4 y h = 8 declarada; Δlog trimestral y log-nivel como secundarias.

- **Especificación vigente.** ADR-001: unidad de estimación = logaritmo del nivel; "métrica
  de evaluación y reporte: tasa de variación interanual". La senda §5.3 pide las métricas
  "en la unidad de interés".
- **Evidencia.** Aritmética, no empírica: `yoy(o+h) = 100·(log Y_{o+h} − log Y_{o+h−4})`.
  Para h ≤ 4 la base `Y_{o+h−4}` está observada en el origen; para h = 8 la base es un
  pronóstico del mismo sendero.
- **Opciones.** (a) Pérdida primaria sobre la tasa interanual en pp, secundarias sobre
  `Δlog` trimestral y log-nivel. (b) Pérdida primaria sobre `Δlog` trimestral, interanual
  como presentación. (c) Pérdida sobre el log-nivel.
- **Recomendación: (a),** por consistencia con ADR-001, declarando en el protocolo la
  asimetría entre h ≤ 4 y h = 8 para que nadie lea el deterioro del RMSE interanual a h=8
  como un hallazgo económico cuando en parte es construcción de la métrica.
- **Si se posterga:** el motor puede almacenar pronósticos de log-nivel y derivar todas las
  unidades después, así que esto no bloquea el código, solo la tabla principal.
- **Documento a enmendar:** ninguno.

## F4-05 — Muestra común: un solo MCS o grupos de comparación

**DECIDIDO por Harold el 2026-09-24:** opción (a) — tres grupos de comparación G1 (52/51/49/45), G2 desde 2014-Q4 (45/44/42/38) y G3 desde 2019-Q4 (25/24/22/18), cada uno con su benchmark y su MCS; ninguna prueba cruza grupos.

- **Especificación vigente.** La senda §5.4 pide MCS como prueba principal; nada dice sobre
  predictores con cobertura desigual.
- **Evidencia.** Observaciones disponibles en el primer origen (2013-Q1): PIB 93, remesas nominales 89, exportaciones 77, ITCER 53, UT 45, IVAE 33, IPM 33, IPP 13, remesas reales 13. Con un mínimo de 40 observaciones para estimar, un modelo con IPP o
  remesas reales no tiene primer origen viable hasta 2019-Q4 y deja 25 / 24 / 22 / 18
  orígenes; con mínimo de 60, 5 / 4 / 2 / 0. Desde 2005-Q1 (IVAE, IPM y tramo homogéneo) el
  primer origen viable es 2014-Q4 con 45 / 44 / 42 / 38.
- **Opciones.** (a) Tres grupos (G1 largo, G2 medio desde 2014-Q4, G3 corto desde 2019-Q4),
  cada uno con su MCS y sus benchmarks, sin pruebas que cruzen grupos. (b) Un solo MCS
  recortado a los 25 orígenes de G3. (c) Un solo MCS sobre G1 y excluir del ejercicio
  principal los predictores cortos (IPP, remesas reales, y en la práctica IVAE e IPM).
- **Recomendación: (a).** (b) tira 27 orígenes de los 52 disponibles para todos los
  modelos y deja h=8 con 18 pérdidas; (c) descarta el IVAE, que es el predictor mensual de
  actividad y el argumento central de §6.4 de la senda. Con (a) el resultado principal vive
  en G1/G2 y G3 se publica con su advertencia de potencia.
- **Si se posterga:** condiciona la arquitectura: el motor necesita saber si el conjunto de
  orígenes es global o por grupo.
- **Documento a enmendar:** ninguno; se declara en el protocolo y se codifica en
  `esquema_validacion`.

## F4-06 — Unidad de modelación de las predictoras

**DECIDIDO por Harold el 2026-09-24:** opción (a), **corregida el mismo día** — regla uniforme declarada a priori: **Δlog para las ocho familias, sin excepción** (la recomendación original proponía Δ en puntos para el IVAE; se corrigió porque el IVAE es un índice de volumen como el objetivo y ADR-001 deriva todo de log-niveles; en los datos la diferencia es mínima: sd de Δ 1,22/3,98 frente a sd de Δlog 1,36/3,97 en las dos mitades). Se registra en una nota de seguimiento de ADR-010. Verificado: con `conclusion_con_estacional`, las ocho familias trimestrales salen `estacionaria` en Δlog, así que la regla coincide en el resultado con el criterio de la nota de ADR-010 del 2026-09-22, que deja de ser el criterio.

**Deuda que Fase 3 difirió explícitamente (nota de cierre, "lo que queda abierto").**

- **Especificación vigente.** ADR-010 fija las transformaciones L3 (desagregación,
  deflactación, outliers, ajuste estacional) pero no la transformación con que las
  predictoras entran a los modelos. El reporte exploratorio de Fase 3 publica el veredicto
  de estacionariedad de 72 filas (18 series × 4 transformaciones).
- **Evidencia.** El veredicto publicado se computó sobre la muestra completa hasta 2026; su
  sensibilidad ya está cuantificada en Fase 3 (14 de 64 filas cambian entre el umbral del
  1% y el 10%; 11 al pasar KPSS a `long`; 5 con dummies estacionales; 7 con dummies de
  impulso de 2020; 40 de 64 resisten las cinco perturbaciones).
- **Opciones.** (a) Regla uniforme declarada a priori por naturaleza de la variable:
  `Δlog` para flujos e índices de precios (remesas, exportaciones, IPP, IPM, ITCER,
  demanda eléctrica), `Δ` para índices de volumen ya desestacionalizados (IVAE). (b) Regla
  por serie según el veredicto publicado al 5%. (c) Tratar la transformación como
  hiperparámetro elegido dentro de cada ventana, igual que los órdenes.
- **Recomendación: (a),** con (c) como extensión y (b) descartada. (b) elige la
  transformación con un veredicto estimado sobre datos posteriores al origen: es filtración
  de la misma clase que evaluar contra la serie revisada, y además sobre una etiqueta que
  el propio análisis de Fase 3 mostró frágil en 24 de 64 filas. (c) es la más pura pero
  multiplica el cómputo y no es implementable de forma limpia en BVAR.
- **Si se posterga:** bloquea Fase 5, no Fase 4 (los benchmarks de §6.1 no usan
  predictoras). Conviene cerrarla igual ahora, porque decidirla después de ver resultados
  es exactamente lo que el criterio de cierre prohíbe.
- **Documento a enmendar:** nota de seguimiento en ADR-010, o declaración en el protocolo
  si se prefiere no tocar el ADR.

## F4-07 — Benchmark que sirve de denominador

**DECIDIDO por Harold el 2026-09-24:** opción (a) — denominador del RMSE relativo: paseo aleatorio sin deriva sobre el log-nivel; el paseo con deriva y el promedio histórico compiten, no son denominador.

- **Especificación vigente.** Senda §5.3: "métricas relativas al benchmark ingenuo (RMSE
  relativo)"; §6.1 lista cuatro referencias obligatorias sin decir cuál es el denominador.
- **Evidencia.** Ninguna; es convención.
- **Opciones.** (a) Paseo aleatorio sin deriva sobre el log-nivel. (b) Paseo aleatorio con
  deriva. (c) Promedio histórico de la tasa de crecimiento.
- **Recomendación: (a)** como denominador único, con (b) y (c) reportados como
  competidores. Es la referencia sin parámetros estimados, así que el RMSE relativo no
  depende de la ventana; y deja a (b) y (c) disponibles como resultados —que un modelo no
  supere al paseo con deriva es informativo y se pierde si ese es el denominador.
- **Si se posterga:** solo afecta la presentación.
- **Documento a enmendar:** ninguno.

## F4-08 — Tratamiento de 2020 en la pérdida

**DECIDIDO por Harold el 2026-09-24:** opción (a) — métrica primaria con los 52 targets y tabla sin 2020 obligatoria (R4); las dummies de 2020 solo entran en la estimación de orígenes posteriores al trimestre que marcan.

- **Especificación vigente.** ADR-004 decide el tratamiento del shock **en la estimación**
  (outlier aditivo en el ajuste estacional; submuestras pre/post como robustez). No dice
  nada sobre 2020 como período **evaluado**.
- **Evidencia.** Sobre los 52 targets de h=1 (2013-Q2 a 2026-Q1) la variación interanual
  del objetivo tiene desviación estándar 5,33 pp, y 3,68 pp excluyendo 2020 (corregido el
  2026-09-24: la primera versión incluía 2013-Q1, que es origen y no target, y daba 5,28 y 3,65); 2020-Q2 marca
  −22,29 pp interanual y −21,44 pp trimestral; los cuatro trimestres de 2020 concentran
  32,8% de la suma de cuadrados de la variación interanual observada en los 52 targets de
  h=1. Además, las dos fechas de outlier declaradas en
  `PIB_SA_PROPIO_Q_outliers.csv` son 2020-Q2 y 2020-Q3, ambas AO.
- **Opciones.** (a) Incluir todo en la métrica primaria y publicar la tabla sin 2020 como
  robustez obligatoria (R4). (b) Excluir 2020 de la métrica primaria. (c) Pérdida robusta
  (MAE como primaria, o pérdida winsorizada).
- **Recomendación: (a).** El shock ocurrió y un pronóstico que no lo vio debe pagarlo; pero
  con 32,8% del cuadrado concentrado en cuatro observaciones la pertenencia al MCS puede
  decidirse ahí, y eso hay que mostrarlo en vez de discutirlo. Punto adicional que
  recomiendo fijar en el mismo acto: **las dummies de 2020 declaradas en el catálogo solo
  pueden entrar en la estimación de orígenes posteriores al trimestre que marcan** —usarlas
  en un origen de 2015 sería filtración.
- **Si se posterga:** no bloquea el motor; sí bloquea la interpretación de Fase 5.
- **Documento a enmendar:** ninguno; nota en el protocolo con referencia cruzada a ADR-004.

## F4-09 — Ajuste estacional dentro del origen

**DECIDIDO por Harold el 2026-09-24:** opción (a) — el ajuste estacional se reestima DENTRO de cada origen, con las fechas AO de 2020-Q2 y 2020-Q3 declaradas fijas; el ajuste único de L3 queda como contraste (R6). Prerrequisito verificado: `seasonal::checkX13()` corrido por Harold en la máquina del proyecto el 2026-09-24 pasa ("'seasonal' should work fine"). La falla que se observaba desde el sandbox de desarrollo (error de programa 133 al correr `seas()` con un `.spc` en una ruta temporal de unos 170 caracteres) era del entorno, no del binario.

**Filtración estructural verificable; condiciona la arquitectura del motor.**

- **Especificación vigente.** ADR-001 y ADR-004: la variable objetivo primaria se construye
  con X-13ARIMA-SEATS propio en L3, una sola vez, sobre la muestra completa, con las fechas
  de outlier detectadas y declaradas.
- **Evidencia.** `PIB_SA_PROPIO_Q.csv` es el producto de un ajuste estacional único sobre
  1990-Q1–2026-Q1. Los filtros de X-13 son bilaterales: el valor desestacionalizado de
  2013-Q1 incorpora información de trimestres posteriores a 2013-Q1. El pronóstico se
  evaluaría, entonces, contra un target que no existía en el origen. (Que el ajuste es de
  factores y no de nivel se ve en que el objetivo conserva la caída: −21,44 pp en 2020-Q2.)
- **Opciones.** (a) Aceptar el ajuste único de L3 y declarar el ejercicio como
  pseudo-fuera-de-muestra sobre la serie desestacionalizada tal como se conoce hoy,
  registrando la filtración como límite conocido. (b) Reestimar el ajuste estacional dentro
  de cada origen (52 corridas de X-13 por variante), con las fechas de outlier de ADR-004
  **declaradas fijas** en vez de redetectadas, y usar el ajuste único como robustez (R6).
  (c) Evaluar contra la serie NSA y dejar la estacionalidad dentro del modelo.
- **Recomendación: (b)** como primaria, si X-13ARIMA-SEATS está disponible en la máquina
  donde corre `make eval` — hay que verificarlo: la batería de pruebas del proyecto deja
  SKIP por ausencia de X-13 en este entorno, y esa dependencia no puede correr en CI.
  Si no lo está, (a) con la filtración declarada, y (b) como deuda abierta. (c) cambia la
  variable objetivo y reabriría ADR-001.
- **Si se posterga:** es lo que más cuesta después. Con (b) el ajuste estacional es un paso
  *dentro* del bucle de orígenes; con (a) es un insumo previo. Cambiar de una a otra
  después de escribir el motor obliga a reescribir el bucle.
- **Documento a enmendar:** nota de seguimiento en ADR-001/ADR-004 si se adopta (b), porque
  cambia el lugar donde se aplica el tratamiento decidido en ADR-004 (dentro del bucle, con
  fechas declaradas) sin cambiar la decisión.

## F4-10 — Longitud de la ventana rodante

**DECIDIDO por Harold el 2026-09-24:** opción (a) — ventana rodante de 92 trimestres, que coincide con la expansiva en el primer origen.

- **Especificación vigente.** Senda §5.1: rodante como robustez, sin longitud.
- **Evidencia.** Ninguna; es diseño.
- **Opciones.** (a) 92 trimestres, igual a la muestra inicial de la convención B. (b) 60
  trimestres (15 años). (c) 40 trimestres.
- **Recomendación: (a).** Hace que rodante y expansiva coincidan en el primer origen, así
  que la diferencia entre las dos series de métricas aísla el descarte de la cola antigua.
  (c) deja muy poca muestra para BVAR y para la validación anidada.
- **Si se posterga:** solo afecta R1.
- **Documento a enmendar:** ninguno.

## F4-11 — Registro del experimento: token o extensión de esquema

**DECIDIDO por Harold el 2026-09-24:** opción (a) — la variante de protocolo se codifica como token en esquema_validacion, con gramática validada por prueba; no se extiende el esquema del catálogo.

- **Especificación vigente.** `catalogos/07_experimentos.csv` tiene doce columnas
  declaradas y hoy contiene solo la cabecera; `catalogos/06_modelos/_plantilla.yaml` declara
  `modelo_id`, `familia`, `especificacion{variables, ordenes, hiperparametros,
  transformaciones_ref}`, `justificacion`, `referencia_bibliografica`.
- **Evidencia.** El esquema no tiene columna para grupo de comparación, unidad de pérdida,
  política de vintage ni política de ajuste estacional — las cuatro cosas que F4-05, F4-04,
  F4-03 y F4-09 deciden.
- **Opciones.** (a) Codificarlas como token estructurado en `esquema_validacion`
  (`expansiva|origen=ultimo_estimado|grupo=G1|vintage=revision_vigente|sa=l3_unico|perdida=yoy_pp`),
  con la gramática declarada en el protocolo y una prueba que la valide. (b) Extender el
  esquema con cuatro columnas nuevas, tocando `datapackage.json` y `validate_catalogs.R`.
- **Recomendación: (a)** para la primera corrida y (b) si el número de variantes crece:
  evita una migración de esquema y una superficie nueva de validación en el mismo commit
  donde nace el motor, y el token es legible en el CSV. Con una prueba que rechace tokens
  mal formados, la diferencia práctica frente a columnas es pequeña.
- **Si se posterga:** el motor no puede escribir su fila de registro.
- **Documento a enmendar:** ninguno con (a); `datapackage.json` con (b).

## F4-12 — Paquetes que el motor necesita y no están fijados

**DECIDIDO por Harold el 2026-09-24:** opción (a) — DM/HLN y GW implementados en eval_lib.R; MCS propio verificado contra el paquete MCS declarado en Suggests (skip cuando falta); yaml pasa a Imports para leer 06_modelos/. Requiere nota de seguimiento de ADR-009.

- **Especificación vigente.** ADR-009 fija el stack y su nota de seguimiento exige decidir
  antes de introducir dependencias nuevas. `DESCRIPTION` declara 25 entradas en `Imports:`,
  entre ellas `fable`, `tsibble`, `vars`, `tsDyn`, `BVAR`, `midasr`, `glmnet`, `ranger`,
  `lightgbm`, `seasonal`, `tempdisagg` y `urca`.
- **Evidencia.** Los benchmarks de §6.1 son cubribles con `fable` (paseo aleatorio con y
  sin deriva, media, ETS, ARIMA) sin dependencias nuevas. **No hay** paquete para
  Diebold-Mariano/HLN, ni para Giacomini-White, ni para Model Confidence Set; tampoco hay
  lector de YAML en `Imports`, y `06_modelos/` es un directorio de YAML.
- **Opciones.** (a) Implementar DM/HLN, GW y MCS en `src/evaluacion/eval_lib.R`, verificados
  por simulación (tamaño nominal) y contra valores publicados, y resolver el YAML con el
  patrón ya usado en el repo para catálogos no tabulares. (b) Agregar `MCS` y `yaml` a
  `Imports` con nota de seguimiento de ADR-009. (c) Híbrido: implementación propia de
  DM/HLN y GW (son pocas líneas y la corrección de HLN es explícita), y `MCS` en `Suggests`
  como oráculo de verificación en las pruebas —presente en desarrollo, omitido con SKIP en
  CI—, replicando el patrón aceptado en Fase 3 con `urca` como fuente de valores críticos.
- **Recomendación: (c),** más `yaml` en `Imports` si el motor va a leer `06_modelos/*.yaml`
  (la alternativa es declarar los modelos en JSON con `jsonlite`, que ya está fijado, pero
  rompe la convención de la senda §3.3 para catálogos narrativos).
- **Si se posterga:** el motor no puede correr sus pruebas de significancia.
- **Documento a enmendar:** ADR-009, nota de seguimiento fechada.

## F4-13 — Si el veredicto publicado de estacionariedad debe consumir los outliers declarados

**DECIDIDO por Harold el 2026-09-24:** opción (a) — se cierra por alcance: el veredicto de estacionariedad de Fase 3 es diagnóstico exploratorio, su sensibilidad ya está publicada y no alimenta ninguna decisión aguas abajo bajo la regla uniforme de F4-06. No se toca estacionariedad.R.

**Deuda que Fase 3 difirió explícitamente.**

- **Especificación vigente.** El reporte exploratorio de Fase 3 §4 lo deja como pendiente;
  `estacionariedad.R` lee solo `periodo` y `valor`, así que las dos fechas AO declaradas en
  `PIB_SA_PROPIO_Q_outliers.csv` no entran en ninguna regresión.
- **Evidencia.** Ya cuantificada en Fase 3: con dummies de impulso de 2020 el estadístico
  ADF se vuelve menos negativo en 41 de 64 filas y cambian 7 veredictos.
- **Opciones.** (a) Cerrarla como decisión de alcance: el veredicto de Fase 3 es diagnóstico
  exploratorio, la sensibilidad ya está publicada, y Fase 4/5 no lo usa para elegir
  transformaciones (ver F4-06), así que no se toca el código. (b) Extender
  `estacionariedad.R` para consumir los outliers del catálogo y publicar columnas con y sin
  dummies, regenerando el reporte.
- **Recomendación: (a)** si se adopta la regla uniforme de F4-06, porque entonces el
  veredicto no es insumo de ninguna decisión aguas abajo y (b) sería trabajo sin
  consecuencia. Si se adopta (b) en F4-06, entonces (b) acá pasa a ser obligatorio.
- **Si se posterga:** no bloquea nada de Fase 4, pero queda como pendiente heredado en el
  cierre.
- **Documento a enmendar:** reporte exploratorio de Fase 3 y nota de ADR-010, según la
  opción.

---

## Resumen para responder

| Código | Decisión | Bloquea | Recomendación |
|---|---|---|---|
| F4-01 | Convención del origen | arquitectura | A + corregir ADR-002 |
| F4-02 | Conjunto de información por origen | modelos con predictores | regla de calendario; UT solo años cerrados |
| F4-03 | Vintage de evaluación | rótulo de todo resultado | datos revisados + pista real-time prospectiva; enmendar ADR-001 |
| F4-04 | Unidad de la pérdida | tabla principal | interanual en pp, con la asimetría declarada |
| F4-05 | Muestra común | arquitectura | tres grupos G1/G2/G3 |
| F4-06 | Unidad de modelación de predictoras | Fase 5 | regla uniforme a priori |
| F4-07 | Benchmark denominador | presentación | paseo aleatorio sin deriva |
| F4-08 | 2020 en la pérdida | interpretación | incluir + tabla sin 2020; dummies solo desde su propio trimestre |
| F4-09 | Ajuste estacional en el origen | arquitectura | reestimar por origen si X-13 está disponible |
| F4-10 | Ventana rodante | R1 | 92 trimestres |
| F4-11 | Registro del experimento | registro | token en `esquema_validacion` |
| F4-12 | Paquetes nuevos | pruebas de significancia | DM/GW propios, MCS con oráculo en Suggests |
| F4-13 | Outliers en el veredicto de Fase 3 | nada | cerrar por alcance si F4-06 es uniforme |
