# Reporte exploratorio — Fase 3

**Cubre:** `doc/checklist_fase3.md`, actividad "análisis exploratorio y de estacionariedad"
(senda metodológica §4, entregable "reporte exploratorio").
**Datos fuente:** `data/L3_master/reporte_exploratorio_resumen.csv` y
`data/L3_master/reporte_estacionariedad.csv` — capa generada, no versionada, producida por
`src/analisis/exploracion_series.R` y `src/analisis/estacionariedad.R` (corrida original
2026-09-17; regenerados 2026-09-19 tras la remediación de la revisión independiente, otra vez
ese mismo día al corregir la grilla de selección de rezagos —hallazgo C2 de la discusión
metodológica, ver §2— y una tercera al ampliar el esquema del CSV y renombrar las dos etiquetas
ambiguas (hallazgos I1, I3 y M3), que no movió ningún estadístico ni ninguna clasificación).
Este
documento interpreta esas cifras; no las sustituye — ante cualquier discrepancia, el CSV es la
fuente de verdad numérica y este documento se corrige, no al revés.

## Alcance

Cubre las 16 series materializadas en `data/L3_master/` a la fecha: la variable objetivo
(`PIB_SA_PROPIO_Q`, `PIB_SA_OFICIAL_Q`) y la matriz de predictores de BCR (`IVAE`, `REMESAS`
nominal y real, `IPP`, `EXPORT_FOB`, `ITCER`, `IPM`, mensual y trimestral). No cubre series que
se admitan después — este documento se re-extiende cuando la matriz crezca, no se reescribe.

**Lo que este documento NO decide** (ver §4): la unidad de modelación de las series
predictoras, ni el orden de integración de la variable objetivo. Da evidencia para esas
decisiones futuras, no las resuelve.

## 1. Cobertura (mitad "exploratorio")

Las 16 series cubren sin huecos internos desde su primera hasta su última observación —
resultado esperado, no un hallazgo: los extractores L0→L1 ya fallan de forma visible ante un
hueco real (regla 7 de `CLAUDE.md`), así que esta corrida confirma la garantía existente, no
descubre una nueva.

| Serie | Frecuencia | n_obs | Rango |
|---|---|---:|---|
| `PIB_SA_PROPIO_Q` | Q | 145 | 1990-Q1 – 2026-Q1 |
| `PIB_SA_OFICIAL_Q` | Q | 85 | 2005-Q1 – 2026-Q1 |
| `BCR_REMESAS_NOM_NSA_M` | M | 427 | 1991-M01 – 2026-M07 |
| `BCR_REMESAS_NOM_NSA_Q` | Q | 142 | 1991-Q1 – 2026-Q2 |
| `BCR_EXPORT_FOB_NOM_NSA_M` | M | 390 | 1994-M01 – 2026-M06 |
| `BCR_EXPORT_FOB_NOM_NSA_Q` | Q | 130 | 1994-Q1 – 2026-Q2 |
| `BCR_ITCER_IDX_NSA_M` | M | 318 | 2000-M01 – 2026-M06 |
| `BCR_ITCER_IDX_NSA_Q` | Q | 106 | 2000-Q1 – 2026-Q2 |
| `BCR_IVAE_VOL_SA_M` | M | 257 | 2005-M01 – 2026-M05 |
| `BCR_IVAE_VOL_SA_Q` | Q | 85 | 2005-Q1 – 2026-Q1 |
| `BCR_IPM_IDX_NSA_M` | M | 257 | 2005-M01 – 2026-M05 |
| `BCR_IPM_IDX_NSA_Q` | Q | 85 | 2005-Q1 – 2026-Q1 |
| `BCR_IPP_IDX_NSA_M` | M | 200 | 2009-M12 – 2026-M07 |
| `BCR_REMESAS_REAL_NSA_M` | M | 200 | 2009-M12 – 2026-M07 |
| `BCR_IPP_IDX_NSA_Q` | Q | 66 | 2010-Q1 – 2026-Q2 |
| `BCR_REMESAS_REAL_NSA_Q` | Q | 66 | 2010-Q1 – 2026-Q2 |

La serie más corta (66 obs, trimestral) permite correr ADF con selección BIC de rezagos (§2) —
verificado en la corrida real, no solo supuesto —, aunque con menor potencia: la potencia
simulada del protocolo a n = 65, frente a la persistencia estimada de esa serie, es de alrededor
de 0,60, así que un no-rechazo ahí sería poco informativo. En la corrida vigente no hay ninguna
conclusión `ambigua_ninguna_rechaza`; las dos que había antes de corregir C2 (§2) eran de esta
serie, y desaparecieron al admitir 0 rezagos en la grilla de BIC.

## 2. Estacionariedad (mitad "estacionariedad")

**Metodología** (decidida por Harold vía `AskUserQuestion`, 2026-09-17): ADF + KPSS
confirmatorio (Kwiatkowski et al. 1992) sobre 4 transformaciones por serie — nivel, log-nivel,
primera diferencia, diferencia del log —, con selección de rezagos BIC/SIC para ADF. Detalle
técnico completo, incluidas las dos aproximaciones declaradas (techo de búsqueda de rezagos de
Schwert para ADF; truncamiento KPSS "short" como análogo más cercano a BIC, no una
correspondencia exacta), en los comentarios de `src/analisis/estacionariedad_reglas.R` y en
`doc/adr/ADR-009-stack-tecnologico.md` (nota de seguimiento que incorporó `urca`).

**Especificación, explícita para que la tabla se pueda leer sin abrir el código.** Nivel y
log-nivel llevan tendencia determinística esperada: ADF `type = "trend"` (estadístico tau3) y
KPSS `type = "tau"`. Primera diferencia y diferencia del log no deberían llevar tendencia
remanente: ADF `type = "drift"` (tau2) y KPSS `type = "mu"`. El nivel de significancia es **5%**
en las dos pruebas, con los valores críticos tabulados de `urca` (Dickey-Fuller para ADF,
Kwiatkowski et al. para KPSS; los de ADF dependen del tamaño de muestra). El techo de búsqueda
de rezagos es la regla de Schwert, `trunc(12·(n/100)^0,25)`, y el truncamiento de KPSS es
`trunc(4·(n/100)^0,25)` (`lags = "short"`). **La grilla de la búsqueda BIC va de 0 a ese techo**,
y la selección la hace `estacionariedad_reglas.R`, no `selectlags = "BIC"` de `urca`: esa opción
nunca evalúa el modelo con 0 rezagos, de modo que imponía un rezago mínimo en 32 de estas 64
filas y cambiaba tres veredictos (hallazgo C2, corregido 2026-09-19; `urca` sigue siendo la
fuente de los valores críticos y hay una guardia que comprueba que las dos implementaciones de
la regresión coinciden). Como admitir 0 rezagos abre la puerta a una regresión
sub-parametrizada, cada fila publica además `adf_ljung_box_p`, el valor p de Ljung-Box sobre los
residuos de la regresión elegida (§3).

**Interpretación conjunta:** una transformación se declara *estacionaria* solo si ADF rechaza
raíz unitaria Y KPSS no rechaza estacionariedad (ambas pruebas coinciden); *no_estacionaria*
solo si coinciden en el sentido contrario. Cuando las pruebas no coinciden, la conclusión es
una de dos etiquetas *ambigua*, porque las dos formas de discrepar significan cosas distintas
(ver `interpretar_conjunta()` en `src/analisis/estacionariedad_reglas.R`):

- *ambigua_ambas_rechazan*: ADF rechaza la raíz unitaria **y** KPSS rechaza la estacionariedad.
  La serie no encaja ni en I(1) puro ni en I(0) puro según estas dos pruebas, y con los
  estadísticos que se publican **no se puede decir por qué**: es compatible con un componente
  determinístico mal especificado (tendencia donde no la hay o al revés), con uno o varios
  quiebres de nivel o de tendencia, con estacionalidad no modelada (§3), con integración
  fraccionaria, con la selección de rezagos y con las propiedades de tamaño de las dos pruebas
  bajo esas desviaciones. Identificar la causa pide pruebas que este reporte no corre: quiebre
  endógeno (Zivot-Andrews, Lee-Strazicich, Bai-Perron para varios) o un estimador de *d* (GPH,
  Whittle local) para la integración fraccionaria.
- *ambigua_ninguna_rechaza*: **ninguna** rechaza su H0. Con esta muestra y esta especificación
  las pruebas no logran separar I(1) de I(0); no dice que la serie sea "intermedia", dice que
  estas dos pruebas no la distinguen. Tampoco atribuye el resultado a una causa: la falta de
  potencia frente a una raíz cercana a uno es la explicación habitual, pero un componente
  determinístico no modelado produce lo mismo.

Los dos nombres describen **la celda de la tabla 2×2** en que cayó la fila, no un diagnóstico
(renombrados 2026-09-19, hallazgo I1 de la discusión metodológica: antes eran
*ambigua_quiebre_o_fraccional* y *ambigua_baja_potencia*, que nombraban dos de las causas
posibles como si fueran la conclusión — el criterio de clasificación no cambió, así que las
corridas anteriores a esa fecha son comparables fila por fila bajo los nombres viejos).

### Resultado por serie

| Serie | nivel | log-nivel | diferencia | diferencia del log |
|---|---|---|---|---|
| `PIB_SA_PROPIO_Q` | ambigua_ambas_rechazan | ambigua_ambas_rechazan | **estacionaria** | **estacionaria** |
| `PIB_SA_OFICIAL_Q` | ambigua_ambas_rechazan | **estacionaria** | **estacionaria** | **estacionaria** |
| `BCR_IVAE_VOL_SA_M` | ambigua_ambas_rechazan | ambigua_ambas_rechazan | **estacionaria** | **estacionaria** |
| `BCR_IVAE_VOL_SA_Q` | ambigua_ambas_rechazan | **estacionaria** | **estacionaria** | **estacionaria** |
| `BCR_REMESAS_NOM_NSA_M` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_REMESAS_NOM_NSA_Q` | no_estacionaria | no_estacionaria | ambigua_ambas_rechazan | **estacionaria** |
| `BCR_REMESAS_REAL_NSA_M` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_REMESAS_REAL_NSA_Q` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_IPP_IDX_NSA_M` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_IPP_IDX_NSA_Q` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_EXPORT_FOB_NOM_NSA_M` | ambigua_ambas_rechazan | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_EXPORT_FOB_NOM_NSA_Q` | ambigua_ambas_rechazan | ambigua_ambas_rechazan | **estacionaria** | **estacionaria** |
| `BCR_ITCER_IDX_NSA_M` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_ITCER_IDX_NSA_Q` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_IPM_IDX_NSA_M` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_IPM_IDX_NSA_Q` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |

Agregado (64 combinaciones serie×transformación): 33 *estacionaria*, 21 *no_estacionaria* y 10
*ambigua_ambas_rechazan*. Ninguna fila queda en *ambigua_ninguna_rechaza*: las dos que había
antes de corregir C2 (`BCR_IPP_IDX_NSA_Q` en Δ y Δlog) pasaron a *estacionaria* cuando la grilla
de BIC admitió 0 rezagos —el modelo que BIC prefiere para esa serie—, con residuos sin
autocorrelación detectable (Ljung-Box p = 0,86). La otra fila que cambió es `PIB_SA_PROPIO_Q` en
nivel, de *no_estacionaria* a *ambigua_ambas_rechazan*. Detalle
completo en `data/L3_master/reporte_estacionariedad.csv`: estadísticos; los valores críticos de
las dos pruebas **al 1%, 5% y 10%** —no solo el del 5% que decide el veredicto, para que la
marginalidad de cada fila se vea sin recomputar la corrida (hallazgo I3)—; `adf_tipo` y
`kpss_tipo`, la especificación determinística que cada prueba mantuvo (hallazgo M3);
`adf_rezagos` —los rezagos que la selección BIC efectivamente retuvo en la regresión— y
`adf_techo_rezagos` —el máximo de búsqueda de Schwert—, que son columnas distintas; y
`adf_ljung_box_p`, el diagnóstico de autocorrelación residual de esa regresión.

Con esos valores críticos publicados se puede ver lo que antes quedaba tapado: **14 de los 64
veredictos cambian si el umbral se mueve entre el 1% y el 10%**, entre ellos el log-nivel de
`PIB_SA_OFICIAL_Q`, que es la fila que sostiene la lectura de tendencia-estacionariedad del
objetivo (§"La variable objetivo"). El 5% es el umbral de decisión de este reporte, no una
frontera natural.

**Patrón, sin sorpresas:** nivel y log-nivel son mayoritariamente
*no_estacionaria*/*ambigua_ambas_rechazan* — esperado en series macro con tendencia. La
primera diferencia y la diferencia del log son mayoritariamente *estacionaria* — esperado si las
series son integradas de orden 1, el caso típico de indicadores macroeconómicos
mensuales/trimestrales. Ninguna serie resultó *no_estacionaria* en ambas diferencias, y en la
corrida vigente **las dos diferencias son *estacionaria* en 15 de las 16 series** (la excepción
es `BCR_REMESAS_NOM_NSA_Q`, *ambigua_ambas_rechazan* en Δ y *estacionaria* en Δlog).

Las 10 *ambigua_ambas_rechazan* están en nivel/log-nivel de PIB, IVAE y exportaciones FOB
(9 casos), más la primera diferencia de `BCR_REMESAS_NOM_NSA_Q`. **La etiqueta dice en qué celda
de la tabla 2×2 cayó la fila —ADF y KPSS rechazan los dos su H0— y no identifica la causa.** Es
compatible con un quiebre estructural no modelado, como el de 2020 (§3), y también con una parte
determinística mal especificada, con la estacionalidad que estas regresiones no modelan (§3) o
con el truncamiento de KPSS: este reporte no contrasta ninguna de esas explicaciones y no debe
leerse como si lo hiciera.

### La variable objetivo: qué dice y qué no dice esta evidencia

ADR-001 ("Definición operativa de la variable objetivo") ya fijó **logaritmo del nivel** como
representación raíz de `PIB.SA.PROPIO.Q`/`PIB.SA.OFICIAL.Q`, de la que se derivan tasas
trimestral e interanual (§"Decisión" de ese ADR). Este reporte no reabre esa decisión, y tampoco
la valida: son cuatro afirmaciones distintas y conviene no fundirlas (corregido 2026-09-19,
hallazgo C1 de la discusión metodológica — la redacción anterior decía que estos resultados
"corroboran" ADR-001 y que la estacionariedad de Δlog es "exactamente la propiedad que se
necesita para que un modelo ARIMA/VAR sea válido"; ninguna de las dos cosas se sigue de lo que
se corrió).

1. **Lo que sí queda establecido.** La diferencia del log (≈ tasa de crecimiento trimestral
   continua) es *estacionaria* en las dos series objetivo, y es el resultado más firme de todo
   el cuadro: ADF de −9,90 (`PIB_SA_OFICIAL_Q`) y −10,80 (`PIB_SA_PROPIO_Q`) contra críticos de
   −2,89 y −2,88, KPSS de 0,042 y 0,096 contra 0,463, sin autocorrelación residual detectable
   (Ljung-Box p de 0,18 y 0,12) y sin que el veredicto se mueva al llevar el nivel de
   significancia a 1% o 10%, al cambiar el truncamiento de KPSS, ni al agregar términos
   estacionales o dummies de 2020 a la regresión.

2. **Esto no discrimina entre el logaritmo y el nivel.** La primera diferencia del nivel da la
   misma conclusión que la del log en 15 de las 16 series, y en las dos del objetivo ambas son
   *estacionaria* (ADF de −9,56 y −10,63). Una prueba que concluye lo mismo con y sin logaritmo
   no puede respaldar la elección del logaritmo. Esa elección se sostiene en razones que ADR-001
   ya tuvo —interpretación en tasas y elasticidades, dispersión proporcional al nivel— y lo que
   la discriminaría es otro contraste (perfil de Box-Cox, relación entre nivel y dispersión),
   que no se corrió acá.

3. **Esto no demuestra que el log-nivel sea I(1);** es *consistente* con que lo sea. Y el cuadro
   no dice lo mismo para las dos medidas del objetivo: el log-nivel de `PIB_SA_OFICIAL_Q` sale
   *estacionaria* alrededor de una tendencia —por poco: KPSS 0,135 contra un crítico de 0,146, y
   al 10% la conclusión pasa a *ambigua_ambas_rechazan*— mientras que el de
   `PIB_SA_PROPIO_Q` sale *ambigua_ambas_rechazan*. Leído al pie de la letra, el primero
   diría que esa serie es I(0) con tendencia y que su Δlog está *sobre*-diferenciada, que es el
   problema opuesto al que la diferenciación resuelve. Queda anotado como pendiente en §4.

4. **Y no acredita ningún modelo.** Que la transformación sea estacionaria es necesario, no
   suficiente: un ARIMA depende además del orden (p, q), de la invertibilidad, de la ausencia de
   autocorrelación residual y de la estabilidad de los parámetros, y nada de eso lo evalúan ADF
   ni KPSS. Para un VAR la propiedad relevante es del sistema, no de cada serie por separado: si
   las series son I(1) y están cointegradas, un VAR en diferencias omite el término de corrección
   de error (Engle y Granger 1987) — y la cointegración está explícitamente fuera del alcance de
   estas pruebas (§3).

En síntesis: la evidencia es **compatible** con ADR-001 y no da ninguna señal de alerta sobre él
—si Δlog hubiera resultado *no_estacionaria*, sí la habría—, pero compatible no es validado, y
ninguno de estos resultados es un cheque en blanco para la especificación de Fase 5.

### Las predictoras: esto informa una decisión que sigue abierta

A diferencia del objetivo, **ADR-010** (transformaciones L3 de predictores) fija desagregación
temporal, deflactación caso por caso y ausencia de tratamiento de outlier propio — pero no
menciona en ningún punto una unidad de modelación (log vs. nivel vs. diferencia) para las
predictoras. Esa decisión sigue genuinamente pendiente, y corresponde tomarla cuando Fase 5 fije
qué familias de modelo se usan (ARIMA/VAR típicamente requieren estacionariedad de sus insumos;
MIDAS y los modelos de aprendizaje automático de este proyecto —`ranger`/`lightgbm`— no
necesariamente la exigen de la misma forma). Este reporte deja la evidencia lista para esa
conversación futura: la tabla de arriba, completa por serie y transformación.

## 3. Salvedades declaradas (no silenciosas)

- **Dos aproximaciones, no correspondencias exactas** (detalladas en el código): el techo de
  búsqueda de rezagos de ADF usa la regla de Schwert; el truncamiento de KPSS usa `lags="short"`
  como el análogo más parsimonioso disponible, no una selección BIC real (KPSS no tiene una).
  El truncamiento no es neutral: con `lags="long"` los rechazos de KPSS caen de 31 a 20 sobre
  estas mismas 64 filas, así que parte de las etiquetas *ambigua_ambas_rechazan* depende de
  esta elección y no de una propiedad de las series.
- **Autocorrelación residual en 16 de las 64 regresiones ADF** (`adf_ljung_box_p` < 0,05), todas
  en cinco series: las cuatro transformaciones de `BCR_EXPORT_FOB_NOM_NSA_M`,
  `BCR_REMESAS_NOM_NSA_M` y `BCR_REMESAS_REAL_NSA_M`, más dos de `BCR_IVAE_VOL_SA_M` y dos de
  `BCR_EXPORT_FOB_NOM_NSA_Q`. El estadístico de esas filas se publica igual —el diagnóstico avisa,
  no invalida— pero su distribución nominal no es de fiar y el patrón no es casual: 14 de las 16
  son mensuales, y la causa más plausible es la estacionalidad que la especificación de las
  pruebas no modela (siguiente salvedad). Ninguna de las tres filas cuyo veredicto cambió al
  corregir C2 está entre ellas.
- **Las pruebas no incluyen componente estacional** y 12 de las 16 series son NSA (ADR-010 decidió
  que las predictoras entren a L3 en el ajuste con que las publica la fuente), así que los
  veredictos de esas series son condicionales a una parte determinística incompleta. El punto
  está abierto y esperando la nota de ADR-010; acá solo queda registrado porque es la explicación
  más plausible del diagnóstico de la salvedad anterior.
- **El shock de 2020 no tiene tratamiento de outlier propio en ninguna de las 16 series**
  (ADR-010, enmienda "ajuste estacional en predictoras" — la misma decisión cubre outliers), y
  eso afecta a las pruebas, pero no en la dirección que este reporte afirmaba hasta 2026-09-19
  (hallazgo I5/M1 de la discusión metodológica; la redacción anterior decía que un outlier no
  tratado "sesga clásicamente las pruebas hacia el no-rechazo" citando a Perron 1989). Son dos
  fenómenos distintos con sesgos opuestos: un **quiebre** en la parte determinística sí le quita
  potencia al ADF y empuja al no-rechazo (Perron 1989), mientras que un **outlier aditivo** —un
  valor atípico transitorio que no mueve el nivel de largo plazo, que es lo que 2020 parece en la
  mayoría de estas series— induce correlación de tipo MA negativa en la serie diferenciada y
  empuja al **sobre-rechazo**, o sea a declarar estacionariedad espuria (Franses y Haldrup 1994;
  Vogelsang 1999; Perron y Rodríguez 2003).
  En estos datos domina el segundo: al agregar dummies de impulso de 2020 a la regresión ADF, el
  estadístico se vuelve **menos** negativo en 41 de las 64 filas —sin tratar, el shock estaba
  inflando el rechazo— y cambian 7 veredictos, 5 de ellos hacia menos rechazo. Tampoco se sostiene
  la conjetura de que el shock explicara la no-estacionariedad de las series NSA mensuales en
  log-nivel: de esas 6 filas, 5 siguen *no_estacionaria* al tratar 2020 y ninguna se acerca a su
  crítico; la única que se comporta como se conjeturaba es `BCR_EXPORT_FOB_NOM_NSA_M`
  (−2,96 → −3,66). Esas series salen *no_estacionaria* por lo que son —índices de precios y
  remesas con tendencia clara y sin términos estacionales (siguiente salvedad)—, no por 2020.
  Estas cifras muestran dirección y magnitud, no veredictos alternativos: con dummies de impulso
  la distribución del estadístico ya no es la de Dickey-Fuller y los críticos de `urca` dejan de
  aplicar (Perron 1989; Vogelsang 1999).
- **El outlier de 2020 de la variable objetivo está declarado, no tratado.** ADR-004 lo declara en
  `PIB_SA_PROPIO_Q_outliers.csv`, pero `src/analisis/estacionariedad.R` lee de cada archivo de L3
  únicamente las columnas `periodo` y `valor`: ese archivo no entra en ninguna regresión y las
  pruebas corren sobre la serie con el shock adentro, igual que en las predictoras. La diferencia
  no es cosmética — el log-nivel de `PIB_SA_PROPIO_Q` pasa de −5,40 a −3,31 y cambia de veredicto
  cuando 2020 se trata—, así que declarar el outlier en el catálogo no protege a este análisis.
  Que las pruebas lo consuman es una decisión de especificación (arrastra los valores críticos,
  ver arriba), no un arreglo de redacción: queda como pendiente, no resuelto acá.
- **Univariante únicamente.** No se evaluó cointegración entre series (relevante si Fase 5 usa
  VAR/VECM en niveles) — está fuera del alcance de ADF/KPSS por construcción; se evaluaría con
  la prueba de Johansen si y cuando corresponda.

## 4. Lo que este reporte NO resuelve

Conforme a la regla 4 de `CLAUDE.md`, quedan marcadas como bloqueo de inferencia:

1. **Unidad de modelación de las predictoras** (nivel/log/diferencia) — no cubierta por ningún
   ADR existente (ver arriba). No se infiere de este reporte ni se decide por analogía con el
   objetivo.
2. **Tratamiento de outlier para predictoras**, si la ambigüedad/no-estacionariedad de series
   NSA resulta ser un problema práctico en Fase 5 — ADR-010 ya decidió que no se trata en L3;
   revisar esa decisión (no solo aplicarla) requeriría una enmienda explícita, no una inferencia
   de este documento. Con la misma lógica queda abierto si las pruebas de estacionariedad deben
   consumir los outliers ya declarados en el catálogo —hoy no lo hacen ni siquiera para el
   objetivo (§3)—, que es una decisión distinta de la anterior: no cambia qué entra a L3, cambia
   cómo se especifican estas regresiones.
3. **Orden de integración de la variable objetivo**, que estas pruebas no establecen de forma
   consistente entre sus dos medidas: el log-nivel de `PIB_SA_OFICIAL_Q` sale *estacionaria* con
   tendencia y el de `PIB_SA_PROPIO_Q` *ambigua_ambas_rechazan*, aunque las dos comparten
   un Δlog *estacionaria* (§2). Importa porque si la medida oficial fuera I(0) con tendencia,
   modelarla en Δlog sería sobre-diferenciarla. Distinguirlo pide algo que este reporte no corre
   —una prueba de raíz unitaria con quiebre, o comparar las dos especificaciones por su
   desempeño predictivo en el protocolo de Fase 4— y no se infiere de acá. Nada de esto reabre
   ADR-001: la representación raíz sigue siendo el log-nivel; lo que queda abierto es sobre qué
   transformación se estima cada familia de modelo.
