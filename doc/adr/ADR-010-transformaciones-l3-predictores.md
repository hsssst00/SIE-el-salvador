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
