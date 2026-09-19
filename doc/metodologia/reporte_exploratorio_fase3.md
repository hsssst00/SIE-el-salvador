# Reporte exploratorio — Fase 3

**Cubre:** `doc/checklist_fase3.md`, actividad "análisis exploratorio y de estacionariedad"
(senda metodológica §4, entregable "reporte exploratorio").
**Datos fuente:** `data/L3_master/reporte_exploratorio_resumen.csv` y
`data/L3_master/reporte_estacionariedad.csv` — capa generada, no versionada, producida por
`src/analisis/exploracion_series.R` y `src/analisis/estacionariedad.R` (regenerados 2026-09-19,
tras la remediación de la revisión independiente; la corrida original fue 2026-09-17). Este
documento interpreta esas cifras; no las sustituye — ante cualquier discrepancia, el CSV es la
fuente de verdad numérica y este documento se corrige, no al revés.

## Alcance

Cubre las 16 series materializadas en `data/L3_master/` a la fecha: la variable objetivo
(`PIB_SA_PROPIO_Q`, `PIB_SA_OFICIAL_Q`) y la matriz de predictores de BCR (`IVAE`, `REMESAS`
nominal y real, `IPP`, `EXPORT_FOB`, `ITCER`, `IPM`, mensual y trimestral). No cubre series que
se admitan después — este documento se re-extiende cuando la matriz crezca, no se reescribe.

**Lo que este documento NO decide** (ver §4): la unidad de modelación de las series
predictoras. Da evidencia para esa decisión futura, no la resuelve.

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
verificado en la corrida real, no solo supuesto —, aunque con menor potencia: es justamente la
que concentra las conclusiones `ambigua_baja_potencia` (ver §2).

## 2. Estacionariedad (mitad "estacionariedad")

**Metodología** (decidida por Harold vía `AskUserQuestion`, 2026-09-17): ADF + KPSS
confirmatorio (Kwiatkowski et al. 1992) sobre 4 transformaciones por serie — nivel, log-nivel,
primera diferencia, diferencia del log —, con selección de rezagos BIC/SIC para ADF. Detalle
técnico completo, incluidas las dos aproximaciones declaradas (techo de búsqueda de rezagos de
Schwert para ADF; truncamiento KPSS "short" como análogo más cercano a BIC, no una
correspondencia exacta), en los comentarios de `src/analisis/estacionariedad_reglas.R` y en
`doc/adr/ADR-009-stack-tecnologico.md` (nota de seguimiento que incorporó `urca`).

**Interpretación conjunta:** una transformación se declara *estacionaria* solo si ADF rechaza
raíz unitaria Y KPSS no rechaza estacionariedad (ambas pruebas coinciden); *no_estacionaria*
solo si coinciden en el sentido contrario. Cuando las pruebas no coinciden, la conclusión es
una de dos etiquetas *ambigua*, porque las dos formas de discrepar significan cosas distintas
(ver `interpretar_conjunta()` en `src/analisis/estacionariedad_reglas.R`):

- *ambigua_quiebre_o_fraccional*: ADF rechaza la raíz unitaria **y** KPSS rechaza la
  estacionariedad. Ambas rechazan su H0; la serie no encaja ni en I(1) puro ni en I(0) puro, lo
  que la literatura asocia a un quiebre estructural en la parte determinística (que ninguna de
  las dos especificaciones contempla) o a integración fraccionaria.
- *ambigua_baja_potencia*: **ninguna** rechaza su H0. Con esta muestra las pruebas no logran
  separar I(1) de I(0); no dice que la serie sea "intermedia", dice que estas dos pruebas no la
  distinguen.

### Resultado por serie

| Serie | nivel | log-nivel | diferencia | diferencia del log |
|---|---|---|---|---|
| `PIB_SA_PROPIO_Q` | no_estacionaria | ambigua_quiebre_o_fraccional | **estacionaria** | **estacionaria** |
| `PIB_SA_OFICIAL_Q` | ambigua_quiebre_o_fraccional | **estacionaria** | **estacionaria** | **estacionaria** |
| `BCR_IVAE_VOL_SA_M` | ambigua_quiebre_o_fraccional | ambigua_quiebre_o_fraccional | **estacionaria** | **estacionaria** |
| `BCR_IVAE_VOL_SA_Q` | ambigua_quiebre_o_fraccional | **estacionaria** | **estacionaria** | **estacionaria** |
| `BCR_REMESAS_NOM_NSA_M` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_REMESAS_NOM_NSA_Q` | no_estacionaria | no_estacionaria | ambigua_quiebre_o_fraccional | **estacionaria** |
| `BCR_REMESAS_REAL_NSA_M` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_REMESAS_REAL_NSA_Q` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_IPP_IDX_NSA_M` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_IPP_IDX_NSA_Q` | no_estacionaria | no_estacionaria | ambigua_baja_potencia | ambigua_baja_potencia |
| `BCR_EXPORT_FOB_NOM_NSA_M` | ambigua_quiebre_o_fraccional | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_EXPORT_FOB_NOM_NSA_Q` | ambigua_quiebre_o_fraccional | ambigua_quiebre_o_fraccional | **estacionaria** | **estacionaria** |
| `BCR_ITCER_IDX_NSA_M` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_ITCER_IDX_NSA_Q` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_IPM_IDX_NSA_M` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |
| `BCR_IPM_IDX_NSA_Q` | no_estacionaria | no_estacionaria | **estacionaria** | **estacionaria** |

Agregado (64 combinaciones serie×transformación): 31 *estacionaria*, 22 *no_estacionaria*, 9
*ambigua_quiebre_o_fraccional* y 2 *ambigua_baja_potencia* (11 ambiguas en total). Detalle
completo en `data/L3_master/reporte_estacionariedad.csv` (estadísticos, valores críticos,
`adf_rezagos` —los rezagos que la selección BIC efectivamente retuvo en la regresión— y
`adf_techo_rezagos` —el máximo de búsqueda de Schwert—, que son columnas distintas).

**Patrón, sin sorpresas:** nivel y log-nivel son mayoritariamente
*no_estacionaria*/*ambigua_quiebre_o_fraccional* — esperado en series macro con tendencia. La
primera diferencia y la diferencia del log son mayoritariamente *estacionaria* — esperado si las
series son integradas de orden 1, el caso típico de indicadores macroeconómicos
mensuales/trimestrales. Ninguna serie resultó *no_estacionaria* en ambas diferencias.

Las dos etiquetas ambiguas se reparten de forma distinta y no deben leerse juntas:

- Las 9 *ambigua_quiebre_o_fraccional* están en nivel/log-nivel de PIB, IVAE y exportaciones
  FOB (8 casos), más uno en la primera diferencia de `BCR_REMESAS_NOM_NSA_Q` (su `diff_log` sí
  es *estacionaria*). Es compatible con quiebres estructurales no modelados, como el de 2020
  (§3), pero este reporte no lo contrasta.
- Las 2 *ambigua_baja_potencia* son ambas de `BCR_IPP_IDX_NSA_Q` en primera diferencia y
  diferencia del log (66 obs, la serie más corta): ninguna prueba rechaza su H0. No descarta
  que sea estacionaria; refleja la menor potencia con menos observaciones. Es la única serie con
  ambigüedad persistente incluso diferenciada por esta vía.

### La variable objetivo: esto valida una decisión ya tomada, no abre una nueva

ADR-001 ("Definición operativa de la variable objetivo") ya fijó **logaritmo del nivel** como
representación raíz de `PIB.SA.PROPIO.Q`/`PIB.SA.OFICIAL.Q`, de la que se derivan tasas
trimestral e interanual (§"Decisión" de ese ADR). Este reporte no reabre esa decisión — la
corrobora empíricamente: la diferencia del log (≈ tasa de crecimiento trimestral continua) es
*estacionaria* para ambas series objetivo, que es exactamente la propiedad que se necesita para
que un modelo ARIMA/VAR estimado sobre esa transformación sea válido. Si hubiera resultado
*no_estacionaria*, sería una señal de alerta sobre ADR-001 que ameritaría revisarlo; no fue el
caso.

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
- **El shock de 2020 no tiene tratamiento de outlier propio en las predictoras** (ADR-010,
  enmienda "ajuste estacional en predictoras" — la misma decisión cubre outliers). Un outlier no
  tratado sesga clásicamente las pruebas de raíz unitaria hacia el no-rechazo (menor potencia de
  ADF ante quiebres, Perron 1989) — puede ser parte de por qué varias series NSA mensuales
  resultan *no_estacionaria* incluso en log-nivel con tendencia. La variable objetivo primaria
  no tiene este problema: su outlier de 2020 sí está declarado (ADR-004,
  `PIB_SA_PROPIO_Q_outliers.csv`).
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
   de este documento.
