# ADR-010: Método de transformación L3 para la matriz de predictores (desagregación temporal, deflactación, outliers)

**Estado:** Cerrado
**Fecha:** 2026-09-16
**Relacionado con:** ADR-004 (tratamiento del shock de 2020, variable objetivo primaria), ADR-009 (stack tecnológico — `tempdisagg` ya declarado)

## Contexto

Fase 3 requiere construir la matriz de predictores en la frecuencia común del
ejercicio (trimestral) a partir de series con distinta frecuencia nativa
(mensual, anual), distinta unidad (nominal/real) y distinto comportamiento
frente al shock de 2020. `doc/checklist_fase3.md` marcaba esto como decisión
metodológica pendiente ("qué paquete — `seasonal` vs. `tempdisagg` para
desagregación temporal—, qué serie de referencia, qué tratamiento de
outliers"), no cubierta por ningún ADR existente ni por
`doc/metodologia/empalme_cuentas_nacionales.md`.

Esto es distinto de la decisión ya resuelta en ADR-001 (enmendado) y ADR-004:
esos ADR fijan el método de ajuste estacional y tratamiento de outlier
**solo para la variable objetivo primaria** (PIB, vía X-13ARIMA-SEATS sobre la
concatenación NSA). No se extendían, ni lo pretendían, al resto de la matriz
de predictores. Este ADR cubre exactamente ese resto.

Decisión de Harold, 2026-09-16, en respuesta a consulta directa de Claude Code
conforme a la regla 4 de `CLAUDE.md` (decisión metodológica no cubierta por
ADR existente → detenerse y preguntar, no inferir).

## Alternativas consideradas

**Desagregación temporal (frecuencia nativa → trimestral):**
- *Interpolación simple* (splines, relleno lineal) — descartada como método
  general: ignora información de series relacionadas de mayor frecuencia
  cuando existen, e introduce menos disciplina metodológica que un método de
  benchmarking reconocido.
- *`tempdisagg`* (Chow-Lin, Denton-Cholette) — ya declarado en `DESCRIPTION` y
  fijado en `renv.lock` desde ADR-009; no introduce dependencia nueva.
- Paquete distinto no evaluado en profundidad: no hay motivo para apartarse de
  una dependencia ya cerrada por ADR-009 cuando cubre el caso de uso.

**Deflactación (series nominales → reales):**
- *Regla única* (un solo IPC general para todas las series nominales) —
  descartada: distorsionaría series que ya tienen un deflactor propio más
  apropiado (p. ej. deflactores implícitos del PIB por rama o componente de
  demanda), forzándolas a uno genérico menos preciso.
- *Deflactor implícito del PIB por rama/componente, siempre que exista* —
  válida pero no universal: no todas las series predictoras tienen un
  deflactor de rama disponible.
- *Caso por caso, declarado explícitamente por serie* — permite usar el
  deflactor más apropiado a la naturaleza de cada serie sin forzar una regla
  que no calza uniformemente.

**Tratamiento de outliers en series predictoras (no el target):**
- *Mismo enfoque que el target* (detección nativa AO/LS/TC vía X-13ARIMA-SEATS,
  aplicada a cada predictora) — descartado: el razonamiento de ADR-004 para
  centralizar el tratamiento en una sola fase aguas arriba aplica al target
  porque **todos los modelos comparten la misma variable objetivo** y evitar
  lógica distinta por familia de modelo es la ganancia buscada. Las
  predictoras no comparten esa restricción: cada modelo tiene su propia
  superficie de decisión frente a atípicos (árboles y `lightgbm` son
  relativamente robustos a outliers puntuales; un VAR o una ecuación puente no
  lo son de la misma forma), y fijar un tratamiento único en L3 impondría una
  decisión de modelado aguas arriba de donde corresponde (Fase 5).
- *Sin tratamiento de outlier propio en L3* — deja la decisión donde varía
  por modelo.
- *Otro criterio* (recorte/winsorización solo para series clave) — descartado
  por ahora: no hay lista de "series clave" que lo justifique de forma no
  arbitraria; se puede reabrir si Fase 5 encuentra necesidad concreta.

## Decisión

1. **Desagregación temporal:** `tempdisagg`. Chow-Lin cuando exista una serie
   indicadora de mayor frecuencia correlacionada con la serie a desagregar;
   Denton-Cholette en su defecto (sin indicador). El método y la serie
   indicadora (si aplica) usados para cada serie predictora se declaran por
   fila en `catalogos/04_transformaciones.csv` (`parametros`), con
   `metodologia_ref` apuntando a este ADR.
2. **Deflactación:** caso por caso, por serie — no hay deflactor único de
   proyecto. El deflactor usado (fuente y serie específica) para cada serie
   predictora nominal se declara explícitamente en
   `catalogos/04_transformaciones.csv` (`parametros`), con `metodologia_ref`
   apuntando a este ADR, en el momento en que esa serie se incorpora al
   extractor L0→L1.
3. **Outliers en series predictoras:** sin tratamiento de outlier propio en
   L3. Las predictoras entran a la matriz maestra (L3/L4) sin ajuste de
   atípicos; cualquier tratamiento de outlier lo decide y declara cada modelo
   individualmente en Fase 5, conforme a su propia sensibilidad. Esto no
   aplica a la variable objetivo primaria, que sigue rigiéndose por ADR-004.

## Consecuencias

- Cada fila de `04_transformaciones` correspondiente a una serie predictora
  desagregada temporalmente o deflactada debe declarar método/deflactor en
  `parametros` y citar este ADR en `metodologia_ref` — no basta con dejarlo
  implícito en el código del script.
- Los scripts de `src/transformacion/` para L3 importan `tempdisagg` por
  serie (no asumen un único método para toda la matriz) y no aplican ningún
  paso de detección/ajuste de outlier a las predictoras.
- Fase 5 hereda la responsabilidad de decidir, por modelo, su propio
  tratamiento de atípicos sobre las predictoras — este ADR no la resuelve,
  solo delimita que no ocurre en L3.
- No reabre ADR-001 ni ADR-004: ambos siguen rigiendo, sin cambios, el
  tratamiento de la variable objetivo primaria.
- **Pendiente, no bloqueante (Fase 3):** catalogar el deflactor específico de
  cada serie predictora admitida es trabajo incremental, caso por caso, a
  medida que cada serie se incorpora al extractor — no se resuelve de una
  sola vez en este ADR.

## Enmienda — ajuste estacional en series predictoras (2026-09-16, sesión posterior)

**Hallazgo de omisión.** Este ADR fija desagregación temporal, deflactación y
tratamiento de outliers para la matriz de predictores, pero no se pronunció
sobre **ajuste estacional**. La omisión no se notó al admitir
`BCR.IVAE.VOL.SA.M` (primer predictor) porque esa serie ya viene
desestacionalizada de la fuente — la pregunta no se planteaba. Se hizo visible
al admitir `BCR.REMESAS.NOM.NSA.M`, la primera predictora genuinamente NSA de
la matriz (el BCR no publica una versión desestacionalizada de remesas, a
diferencia de IVAE/IPI/ISI/ITCER/SPNF): la serie se materializó en L3 (nominal
y real) sin que Claude Code se detuviera a preguntar, pese a que la regla 4 de
`CLAUDE.md` exige detenerse ante una decisión metodológica no cubierta por
ningún ADR. Detectado por Harold, no por el propio proceso — corregido acá
antes de que se repita con la siguiente predictora NSA.

**Decisión de Harold:** sin ajuste estacional propio en L3 para series
predictoras. Se extiende a la estacionalidad el mismo razonamiento ya fijado
en la Decisión 3 (outliers): cada modelo de Fase 5 tiene su propia superficie
de decisión frente a la estacionalidad (dummies estacionales, comparaciones
interanuales/YoY en vez de niveles, modelos que ya incorporan un componente
estacional, etc.), y fijar un tratamiento único en L3 impondría una decisión
de modelado aguas arriba de donde corresponde. No aplica a la variable
objetivo primaria, que sigue rigiéndose sin cambios por ADR-001/ADR-004.

**Consecuencia.** Las series predictoras entran a L3/L4 en el ajuste con que
las publica su fuente — SA si la fuente ya la publica así (p. ej. IVAE), NSA
si no (p. ej. REMESAS) — sin ningún paso de ajuste estacional propio del
proyecto en ninguno de los dos casos. El campo `adjustment` de
`03_series.csv`/`05_series_master.csv` para cada predictora refleja
simplemente lo que la fuente entrega, no una elección del proyecto.

## Nota de seguimiento — componente estacional en las pruebas de estacionariedad (2026-09-22)

**Contexto.** El hallazgo I4 de la discusión metodológica de Fase 3 (2026-09-18) dejó abierta
una pregunta que la enmienda anterior no resuelve: si las predictoras NSA entran a L3 sin ajuste
estacional propio, ¿deberían las *pruebas de estacionariedad* de `src/analisis/estacionariedad.R`
modelar ese componente al evaluarlas? Hasta esta nota, no lo hacían — ADF y KPSS corrían con la
misma especificación determinística (constante/tendencia, sin dummies) sobre las 16 series,
12 de ellas NSA. El reporte exploratorio (`doc/metodologia/reporte_exploratorio_fase3.md`, §3) ya
declaraba esto como salvedad, ligado al patrón de autocorrelación residual (Ljung-Box) que
aparece sobre todo en series mensuales.

**Qué se corrió (D1 del checklist de cierre de Fase 3).** Dos piezas de evidencia nuevas, ambas
en R puro — no se agregó ningún paquete al stack (ADR-009 sigue sin pronunciarse sobre `uroot`):

1. **HEGY** (Hylleberg, Engle, Granger y Yoo 1990; extensión mensual de Beaulieu y Miron 1993),
   implementado en `src/analisis/hegy_reglas.R` y corrido por `src/analisis/hegy.R` sobre el log
   de las 16 series. La construcción de los regresores se verificó contra el código fuente
   publicado de `uroot::hegy.regressors()` (no se derivó de memoria — ver la nota de cabecera de
   `hegy_reglas.R`), y los valores críticos son simulados (5000 réplicas por serie, paseo
   aleatorio estacional bajo H0, mismo n/rezagos/deterministicos que la regresión aplicada) en
   vez de tabulados. Resultado, en `data/L3_master/reporte_hegy.csv` (corrida del commit de esta
   nota): **las 16 series rechazan la raíz unitaria estacional conjunta** (F entre 23,5 y 982,
   contra críticos simulados de 4,3 a 6,3 — ningún rechazo es marginal), y **solo
   `PIB_SA_PROPIO_Q` rechaza también en frecuencia cero** (t=-4,37 contra crítico -3,36; las
   otras 15 no rechazan ahí, consistente con el ADF ya publicado en el reporte exploratorio).
2. **Dummies estacionales en el ADF**, agregadas directamente a `estacionariedad_reglas.R`
   (`prueba_adf()` ahora computa, además de la especificación publicada, una variante con S-1
   dummies con su propia selección de rezagos por BIC, más el F de significancia conjunta de esas
   dummies) — el CSV publica ambas especificaciones lado a lado. Los críticos de `urca` sirven
   para las dos: agregar dummies deterministicas no cambia la distribución asintótica del
   estadístico de Dickey-Fuller. Sobre la corrida vigente (post-C2, `data/L3_master/
   reporte_estacionariedad.csv`): **30 de 64 filas** tienen dummies conjuntamente significativas
   al 5% (las 30 son NSA, ninguna SA — coherente con que las SA ya vienen sin estacionalidad de
   fuente), y **5 de 64 veredictos cambian** al modelarla — los cinco de `no_estacionaria` a
   `ambigua_ambas_rechazan`, y los cinco son log/nivel de `BCR_REMESAS_REAL_NSA_M/.Q` más el log
   de `BCR_EXPORT_FOB_NOM_NSA_M`.

**Qué implica.** 1) **Δ₁ es la diferenciación correcta**: HEGY descarta que la estacionalidad
observada sea una raíz unitaria estacional — no hace falta Δ₁₂/Δ₄ en ninguna de las 16 series, y
la tabla de estacionariedad del reporte exploratorio no necesita rehacerse por este motivo. 2) La
estacionalidad que sí hay es **determinística**, y por eso no desaparece al diferenciar: sigue
significativa en la mitad de las series NSA. 3) Las pruebas de estacionariedad quedaban **mal
especificadas** mientras no incluyeran el componente estacional — ya corregido en el código (ver
arriba); el veredicto oficial (`conclusion`, columna sin dummies) se mantiene como la lectura
publicada del reporte exploratorio, y `conclusion_con_estacional` es la lectura que corresponde
usar para decidir la especificación de Fase 5.

**Decisión (fija esta nota, no reabre la enmienda anterior):**

- ADR-010 se mantiene sin cambios: las predictoras NSA siguen entrando a L3 sin ajuste estacional
  propio — HEGY confirma que no hay nada que quitar por diferenciación estacional, así que no hay
  motivo para revisar esa decisión.
- **Las predictoras NSA entran a Fase 5 con términos estacionales explícitos** en cualquier
  familia de modelo que las use en niveles o en Δ₁ sin de por sí modelar estacionalidad: dummies
  de mes/trimestre en los modelos lineales (ARIMA-X, regresión, MIDAS), o la variable de
  calendario como regresor adicional en los de aprendizaje automático (`ranger`, `lightgbm`). Es
  una restricción de diseño que Fase 4 puede verificar, no una sugerencia.
- El diagnóstico Ljung-Box del reporte exploratorio (16 de 64 filas, 14 mensuales) queda explicado
  por esta misma estacionalidad determinística no modelada — no por otra causa distinta.

**Límites, heredados de la evidencia y sin resolver acá:**

- Los críticos de HEGY son simulados bajo un paseo aleatorio estacional gaussiano con la
  especificación exacta de cada serie, no las superficies de respuesta publicadas de Beaulieu y
  Miron (1993). Para rechazos tan lejos del crítico (el más ajustado es un factor ~4) la
  diferencia no cambia ninguna conclusión, pero si HEGY se vuelve una prueba permanente del
  pipeline (no solo evidencia de esta nota), conviene evaluar una tabla publicada.
- El shock de 2020 no está tratado en ninguna de las regresiones de HEGY (mismo límite que el
  reporte exploratorio declara para ADF/KPSS — ver D2 abajo).
- HEGY es univariante y sobre el logaritmo de cada serie; no dice nada sobre cointegración
  estacional entre predictoras y PIB, pregunta de Fase 5 si se usan niveles.
- No se corrió Canova-Hansen (H0 complementaria: estacionalidad determinística estable vs.
  evolutiva). Con HEGY rechazando de forma tan poco marginal, aporta poco a esta decisión.

Registrado también como nota fechada en `doc/senda_metodologica.md`, Fase 3 (mismo criterio que
las lecturas de "ingresa al proyecto" y "verifica su integridad" en Fases 1 y 2).

## Nota de seguimiento — unidad de modelación de las predictoras (2026-09-24)

**Contexto.** El cierre de Fase 3 dejó explícitamente diferido a Fase 4/5 con qué
transformación entran las predictoras a los modelos. Este ADR fija las transformaciones que
producen L3 (agregación temporal, deflactación, outliers, ajuste estacional), pero no la
unidad de modelación.

**Decisión (Harold, 2026-09-24; ficha F4-06).** Regla uniforme, declarada antes de estimar
cualquier modelo: **las ocho familias de la matriz de predictores entran como Δlog** —
`IVAE`, `REMESAS` nominal y real, `IPP`, `EXPORT_FOB`, `ITCER`, `IPM` y `UT.DEMANDA_ELEC`—, en
la misma unidad que la variación trimestral del objetivo (ADR-001: log-nivel como raíz del
linaje). La regla no tiene excepciones y no se elige por serie.

**Por qué no se elige por serie con el veredicto de estacionariedad.** El veredicto que publica
el reporte exploratorio de Fase 3 se estimó con la muestra completa hasta 2026. Usarlo para
elegir la transformación en un origen de 2013 sería filtración, de la misma clase que evaluar
contra la serie revisada. Además, el propio análisis de Fase 3 mostró que la etiqueta es frágil
(40 de 64 filas resisten las cinco perturbaciones de sensibilidad).

**Relación con la nota del 2026-09-22.** Esa nota dice que `conclusion_con_estacional` es la
lectura que corresponde usar para decidir la especificación de Fase 5. En cuanto a la unidad de
modelación, el criterio pasa a ser la regla uniforme de esta nota. Se comprobó que ambas
coinciden en el resultado: con `conclusion_con_estacional`, las ocho familias en frecuencia
trimestral salen `estacionaria` en Δlog. La nota del 22 sigue vigente en lo demás, en
particular en su restricción de diseño: **las predictoras NSA entran a Fase 5 con términos
estacionales explícitos**. Diferenciar en log no elimina la estacionalidad determinística que
esa nota documentó, así que la restricción sigue siendo necesaria bajo esta regla.

**Extensión no adoptada.** Tratar la transformación como hiperparámetro elegido por validación
anidada dentro de cada ventana sería la opción más pura respecto de la simetría de la senda
§5.2. No se adopta ahora porque multiplica el cómputo y no se implementa de forma limpia en
BVAR, pero queda disponible como robustez de Fase 5.

**Consecuencia sobre la deuda de outliers del veredicto (ficha F4-13).** Como el veredicto de
estacionariedad ya no alimenta ninguna decisión aguas abajo, la pregunta de si debería consumir
los outliers declarados se cierra por alcance: su sensibilidad a las dummies de 2020 ya está
publicada (41 de 64 estadísticos ADF se vuelven menos negativos y cambian 7 veredictos), y
`estacionariedad.R` no se modifica.
