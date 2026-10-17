# Fase 6 — registro de decisiones de diseño

**Fecha:** 2026-10-17 · **Estado:** F6-01 a F6-13 decididas el 2026-10-17 en la opción recomendada de cada ficha,
por autorización de Harold (ver «Origen de estas decisiones»). Las fichas de especificación F6-14 en adelante están
abiertas.

**Para qué sirve este documento.** Es el equivalente de `decisiones_fase5.md` para Fase 6: cada ficha lleva la
línea **DECIDIDO** con el texto operativo, y el Acta es el índice. Las correcciones posteriores entran como notas
fechadas; no se reescribe lo registrado. El protocolo que aplica estas decisiones es
`doc/metodologia/protocolo_proyeccion.md`; el tablero de avance, `doc/checklist_fase6.md`.

## Origen de estas decisiones

Las fichas F6-01 a F6-13 se redactaron en el chat entre el 2026-10-15 y el 2026-10-16 (borrador v3, sobre
`c4ae7c6` más los PR #63 a #69), sin tocar el repo, con contexto verificado, opciones, implicación práctica y una
recomendación cada una. El 2026-10-17 Harold autorizó que el agente empezara Fase 6 por su cuenta y aplicara las
decisiones recomendadas. Por eso cada ficha dice «DECIDIDO (opción recomendada, autorización de Harold del
2026-10-17)». Los detalles que una ficha no fijaba se rotulan **«delegada al agente; se puede reabrir»**, igual
que en Fase 5, y la regla 4 de `CLAUDE.md` registra la delegación.

## Hechos verificados el 2026-10-17 que entran a las fichas

- **`main` = `0927b32`.** Los PR #63 a #69 (residuos de la verificación y análisis posteriores AP-1 a AP-4) están
  fusionados. Los análisis posteriores entran aquí solo como evidencia; no cambian modelos, YAML, tabla ni MCS de
  Fase 5.
- **`BVAR` 1.0.5 sí trae pronóstico condicional.** `bv_fcast(horizon, cond_path, cond_vars)` lleva a
  `BVAR:::cond_fcast()`, que resuelve el sendero condicionado con la descomposición en valores singulares de la
  matriz de respuestas ortogonalizadas y sortea los choques libres con `rnorm()` (forma de Waggoner y Zha). La ficha
  F6-06 suponía que no existía. No está verificado que sea correcto: su `predict()` incondicional resultó inválido
  para la predictiva (B2b) y la forma condicional usa las respuestas al impulso que calcula el propio paquete.
- **El U-MIDAS es de forma directa.** Los YAML `MIX.UMIDAS.Gk` declaran «directa por h = 1..8» (F5-05, B3b). No
  puede recibir un sendero futuro de sus predictoras, así que cae en la clase (iii) de F6-01, no en la (i).
- **La ARIMAX-IVAE no tiene predictoras externas.** `UNI.ARIMAX_IVAE.G2` usa solo IVAE, que es interna (F6-03), y
  por eso no responde a ningún escenario.
- **CBO.** Su política declara que sus productos no tienen derechos de autor, son de dominio público y pueden
  copiarse y distribuirse completos, con el pedido de reconocerla como fuente
  (`https://www.cbo.gov/about/privacy`). La Junta de la Reserva Federal no tiene, verificada, una declaración
  equivalente. Ver la enmienda de ADR-008 del 2026-10-17.
- **WEO de octubre de 2026.** Publicado el 2026-10-12 (rueda de prensa del 2026-10-13). El capítulo 1 trae al
  menos dos escenarios adversos de modelo: precios del petróleo cerca de 130 USD por barril hasta el primer
  trimestre de 2027, con el crecimiento mundial de 2027 unos 0,5 pp debajo de la base, y una corrección de la
  inversión en inteligencia artificial, con el producto mundial 1,1 % debajo de la base hacia 2028. Las cifras salen
  de reseñas del informe; falta verificar en la fuente qué desviaciones publica para EE. UU. y para las variables de
  escenario (F6-14).
- **La base de datos del WEO está en la API SDMX 3.0 del FMI**, la misma que ya usa `src/adquisicion/fmi.R`
  (dataflow `IMF.RES/WEO`). Consultada el 2026-10-17, trae proyecciones anuales hasta 2031 de, entre otras,
  `USA.NGDP_R`, `USA.PCPIPCH`, `USA.LUR`, `G001.NGDP_RPCH`, `G001.TRADEPCH` y `G001.POILAPSP`, con
  `COUNTRY_UPDATE_DATE` de septiembre de 2026 (EE. UU.: 2026-09-30), y también `SLV.NGDP_RPCH`, que usa la
  coherencia de F6-10. El crecimiento mundial de 2026 que devuelve (3,06 %) coincide con el 3,1 % que anunció el
  informe. La consulta no capturó nada en L0. La API sirve el WEO vigente, así que la captura (C2) tiene que fijar
  el vintage por fecha y sha256.
- **Rango del interanual del PIB en el corte de Fase 5** (100 · Δ₄ log del PIB SA propio, 1991-Q1 a 2026-Q1). Sin
  2020-2021: mínimo −3,08 (2009-Q1), máximo 11,00 (1992-Q4), desviación estándar 2,08. Con todo: −22,29 (2020-Q2) y
  25,27 (2021-Q2). Se cita solo para dimensionar F6-08; el rango que rige se calcula sobre `corte_fase6` al
  congelar.

---

## Acta de decisiones

| Código | Decisión adoptada | Documento enmendado |
|---|---|---|
| F6-01 | Solo los modelos condicionables proyectan en el Ejercicio B; los incondicionales se reportan aparte como «trayectoria sin escenario»; la forma directa queda fuera | ninguno |
| F6-02 | Mediana de los elegibles que pasan la guarda, con cada modelo reportado; mínimo 3 por grupo o `stop()` | ninguno |
| F6-03 | Ecuaciones satélite declaradas, una por predictora externa; IVAE y UT no se condicionan | `supuestos_escenarios.md` (nota 2026-10-17) |
| F6-04 | Corte nuevo `corte_fase6`, congelado con el último vintage publicado; origen = último trimestre observado (hoy 2026-Q2); h = 1 a 20 | ninguno |
| F6-05 | Base + adverso + sensibilidad, todo con fuente; favorable solo si aparece una fuente que lo publique | `supuestos_escenarios.md` (nota 2026-10-17); ADR-008 (enmienda CBO) |
| F6-06 | Condicionamiento duro; contrato `predecir_condicional()` en un `DISENO_FASE6` con `h_max = 20`, sin tocar `DISENO_FASE4` | ninguno |
| F6-07 | Intervalos por modelo y mezcla con pesos iguales para la combinación; 80 y 95 %; marca «sin calibrar» para h > 8 | ninguno |
| F6-08 | Exclusión registrada fuera del rango histórico sin 2020-2021 ampliado en 1 desviación estándar | ninguno |
| F6-09 | Sensibilidad uno a la vez, ±1 desviación estándar del crecimiento anual de cada variable de escenario | ninguno |
| F6-10 | Lista de coherencia: identidades con `stop()` y tres informativas | ninguno |
| F6-11 | Cifra principal: crecimiento anual 2026-2030 (promedio del año de los niveles SA); además interanual trimestral y nivel | ninguno |
| F6-12 | Preregistro y reproducibilidad con el esquema de Fase 5; protocolo propio; canarios V22 y V23; `make fase6` | protocolo de proyección (nuevo) |
| F6-13 | Medir raíces y distancia media-mediana del BVAR antes de proyectar, con lo que se mira fijado aquí; luego mediana de la predictiva como sendero | ninguno |

---

## F6-01 — Qué modelos son elegibles para proyectar condicionalmente

**DECIDIDO (opción recomendada (a), autorización de Harold del 2026-10-17).**

- **Elegibles para el Ejercicio B:** los modelos que pueden recibir un sendero de al menos una predictora externa
  (F6-03): `UNI.ARIMAX.G1`, `UNI.ARIMAX.G2`, `UNI.ARIMAX.G3`, `MULT.VAR_DIF.G1`, `MULT.VAR_DIF.G2`,
  `MULT.VAR_DIF.G3`, `MULT.VAR_NIV.G1`, `MULT.VECM.G1`, `MULT.BVAR.G1`, `MULT.BVAR.G2`, `MULT.BVAR.G3`,
  `MIX.PUENTE.G1`, `MIX.PUENTE.G2` y `MIX.PUENTE.G3`. Son 6 en G1, 4 en G2 y 4 en G3.
- **Trayectoria sin escenario (se reporta aparte, no entra a la combinación):** los seis benchmarks, `UNI.ARIMA`,
  `UNI.UC_LLT` y `UNI.ARIMAX_IVAE.G2`.
- **Fuera:** los de forma directa (`REG.ENET.*`, `REG.PCR.*`, `ML.RF.*`, `ML.LGBM.*` y `MIX.UMIDAS.*`) y las
  combinaciones de Fase 5 (`COMB.*`), que no tienen densidad y se reemplazan por la regla de F6-02.

**Delegadas al agente; se pueden reabrir:**

- **F6-01-a.** `MIX.UMIDAS.*` pasa de «condicionable con reservas» a forma directa, porque su YAML lo declara así
  (hecho verificado arriba).
- **F6-01-b.** `UNI.ARIMAX_IVAE.G2` pasa a la trayectoria sin escenario, porque su única predictora es interna. El
  criterio general: un modelo es condicionable si al menos una de sus predictoras tiene satélite.
- **F6-01-c.** `MULT.VAR_DIF.G3` es idéntico a `MULT.VAR_DIF.G2` (B2-6). Entra en los dos grupos, como en Fase 5,
  y el informe lo declara. Dentro de cada grupo los miembros son distintos entre sí.

## F6-02 — Regla de selección o combinación (compuerta de la auditoría de Fase 5)

**DECIDIDO (opción recomendada (a), autorización de Harold del 2026-10-17):** el sendero que se reporta por grupo y
escenario es la **mediana**, trimestre a trimestre, de los senderos de los elegibles de F6-01 que pasan la guarda de
F6-08. Cada modelo se reporta además por separado. La mediana se toma sobre el crecimiento trimestral Δy y el nivel
se reconstruye acumulando desde el último dato observado, para que la identidad de agregación de F6-10 se cumpla.

- **Mínimo de miembros:** 3 por grupo y escenario después de la guarda. Si quedan menos, `stop()`.
- Descartadas: la media (un miembro explosivo la mueve; AP-1), los pesos por desempeño en A (el MCS no distingue
  modelos ni familias; AP-4) y un modelo único preregistrado.
- Se fija con commit antes de la primera proyección sobre datos reales (compuerta de la auditoría).

**Delegada al agente; se puede reabrir (F6-02-a):** la mediana sobre Δy y no sobre el interanual ni el nivel. Con
pocos miembros, la mediana del nivel y la del crecimiento pueden venir de modelos distintos en cada trimestre; con
Δy, el nivel y el interanual quedan como derivados de un único sendero.

## F6-03 — Cómo llega el escenario a las predictoras del modelo

**DECIDIDO (opción recomendada (a), autorización de Harold del 2026-10-17):** ecuaciones satélite declaradas, una
por predictora externa, con lista cerrada:

| Predictora del modelo | Variable de escenario candidata | Historia en L0 |
|---|---|---|
| Remesas nominales y reales | empleo o PIB de EE. UU. | `FRED.PAYEMS`, `FRED.BEA_PIB_EEUU` |
| Exportaciones FOB | PIB de EE. UU. o comercio mundial | `FRED.BEA_PIB_EEUU`; comercio mundial sin historia en L0 |
| IPM e IPP | precios de materias primas | `FMI.PCPS.POILAPSP`, `FMI.PCPS.PALLFNF`, `FMI.PCPS.PFOOD` |
| ITCER | inflación de EE. UU. frente a la local | `FRED.CPIAUCSL` |

- **IVAE y UT son internas:** no se condicionan y las proyecta el propio modelo.
- Las satélite son modelos nuevos que el Ejercicio A no evaluó. Se especifican con las reglas de Fase 5 (muestra
  hasta el origen, criterio de información, YAML antes de correr) y su error entra a la proyección.
- Las variables de escenario que hoy están solo en L0 pasan a L3 por el circuito de Fase 3 (catálogo,
  transformación, validación) antes de usarse.
- La nota de ADR-002 sobre la inconsistencia entre fuentes se mantiene y va a `supuestos_escenarios.md`.

La forma de cada satélite y la elección en las filas con dos candidatas («o») son la ficha de especificación F6-15.

## F6-04 — Origen, corte de datos y horizonte

**DECIDIDO (opción recomendada (a), autorización de Harold del 2026-10-17):** un corte nuevo
`doc/metodologia/corte_fase6.csv`, congelado como en F5-16, con el último vintage publicado al congelar. El origen es
el último trimestre con PIB observado en ese corte (hoy 2026-Q2, con el PIB `v2026-09`) y el horizonte, h = 1 a 20.
Los modelos se reestiman una sola vez, en el origen, con sus YAML de Fase 5 sin cambios.

**Delegada al agente; se puede reabrir (F6-04-a):** si el BCR publica el PIB de 2026-T3 antes del congelamiento
(E1 del checklist), el corte lo toma y el origen pasa a 2026-Q3. La regla es «último vintage al congelar», no una
fecha. En ese caso h = 18 llega a 2031-Q1 y 2030-Q4 queda en h = 17.

## F6-05 — Escenarios: cuántos y de dónde

**DECIDIDO (opción recomendada (a), autorización de Harold del 2026-10-17):** base, adverso y sensibilidad, todo
con fuente citada. Favorable (opción b) solo si aparece una fuente que lo publique, con nota fechada antes del
congelamiento.

- **Base:** WEO de octubre de 2026 para las variables globales y el PIB de EE. UU.
- **Empleo de EE. UU.:** las proyecciones económicas de la CBO vigentes al congelar.
- **Adverso:** un escenario de riesgo del capítulo 1 del WEO de octubre de 2026, si publica magnitudes
  cuantitativas utilizables para las variables de escenario. Cuál de los dos y cómo se traducen sus desviaciones es
  la ficha F6-14.
- **Sensibilidad:** F6-09.
- Cada fuente se captura a L0 como vintage inmutable, con su sha256, antes de congelar.

**Delegada al agente; se puede reabrir (F6-05-a):** para el empleo de EE. UU. se usa la CBO y no el SEP de la Fed.
Razones: la CBO declara sus productos de dominio público, mientras que la Fed no tiene una declaración equivalente
verificada; la CBO proyecta diez años, lo que cubre 2031-Q2, mientras que el SEP llega a tres años más el largo
plazo; y el SEP no proyecta el empleo asalariado. Con eso solo hace falta el tramo de la CBO en ADR-008.

## F6-06 — Método de condicionamiento

**DECIDIDO (opción recomendada (a), autorización de Harold del 2026-10-17):** condicionamiento duro. El sendero del
escenario se trata como conocido. En la ARIMAX y el puente se enchufa en lugar de la proyección AR de la predictora.
En el VAR, el VECM y el BVAR se usa el pronóstico condicional: la variable condicionada sigue el sendero y las demás
responden. Los intervalos son condicionales al sendero; la incertidumbre del escenario se muestra con los escenarios
y la sensibilidad.

- **Contrato:** un campo opcional `predecir_condicional(ajuste, h, senderos_x)` del contrato de modelo (junto a
  `predecir` y `predecir_densidad`), en un diseño aparte,
  `DISENO_FASE6`, con `h_max = 20`. `DISENO_FASE4` no cambia, y CI comprueba que los `F5_REPRO_*` siguen bit a bit.
- **Canario V22:** en un DGP sintético conocido, el pronóstico condicional reproduce exactamente el sendero
  impuesto y recupera la media y la covarianza condicionales analíticas.

**Delegada al agente; se puede reabrir (F6-06-a):** en los modelos lineales gaussianos (VAR, VECM y, por extracción,
el BVAR) el pronóstico condicional se calcula en código propio como la distribución normal del vector apilado de
pronósticos condicionada a las restricciones lineales del sendero, sobre los momentos que ya calcula el motor
(B2-10). Bajo condicionamiento duro esto es lo mismo que Waggoner y Zha y no depende de la identificación de los
choques. `BVAR:::cond_fcast()` no se usa en producción. Sirve como contraste en una prueba si V22 confirma que
coincide con el código propio.

## F6-07 — Intervalos

**DECIDIDO (opción recomendada (a), autorización de Harold del 2026-10-17):** intervalos por modelo y, para la
combinación, la mezcla con pesos iguales de las densidades de los miembros que pasan la guarda. Bandas del 80 y
del 95 %. Toda banda con h > 8 lleva la marca «sin calibrar» en la tabla, como la marca «d» de Fase 4.

**Delegada al agente; se puede reabrir (F6-07-a):** la mezcla no está centrada en la mediana de F6-02. El informe
reporta las dos cosas tal cual, sin recentrar la mezcla, y lo declara.

## F6-08 — Guarda de plausibilidad (compuerta de la auditoría de Fase 5)

**DECIDIDO (opción recomendada (a), autorización de Harold del 2026-10-17):** exclusión registrada. Un modelo cuyo
sendero puntual del interanual sale del rango permitido en algún h = 1..20 sale de la combinación de ese grupo y
escenario. Se reporta igual, marcado, y la exclusión va al manifiesto. Si después de la guarda quedan menos
miembros que el mínimo de F6-02, `stop()`.

**Delegada al agente; se puede reabrir (F6-08-a), los dos datos que la ficha dejaba a Harold:**

- **Rango histórico sin 2020-2021.** Los interanuales con período en 2020 o 2021 no entran al mínimo ni al máximo,
  igual que en R4 (F4-29) y en coherencia con ADR-004. El origen de Fase 6 no está en un choque. Con 2020-2021, el
  rango (−22 a 25 pp en el corte de Fase 5) dejaría pasar casi cualquier sendero no explosivo.
- **X = una desviación estándar del interanual sin 2020-2021**, la segunda de las dos formas que proponía la ficha.
  Es una regla y no una constante elegida a ojo.
- **Rango permitido:** `[mín − X, máx + X]`. Interanual = 100 · Δ₄ log del PIB SA propio, la unidad de Fase 4 y
  Fase 5. Se calcula en L3 de `corte_fase6` al congelar y se escribe en el YAML de Fase 6. En el corte de Fase 5
  daría [−5,16, 13,08].
- La guarda mira el sendero puntual de cada modelo, no sus bandas.

## F6-09 — Análisis de sensibilidad

**DECIDIDO (opción recomendada (a), autorización de Harold del 2026-10-17):** uno a la vez. Cada variable de
escenario se mueve ±1 desviación estándar histórica de su crecimiento anual, y se reporta el cambio en el PIB de 2030
(nivel y crecimiento promedio 2026-2030), sobre el escenario base.

**Delegada al agente; se puede reabrir (F6-09-a):**

- La desviación estándar se calcula con los crecimientos anuales de cada variable de escenario en L3, desde su
  primer año completo hasta el último año completo del corte, sin 2020-2021, con el mismo criterio que F6-08.
- La perturbación es un desplazamiento permanente: se suma ±1 desviación estándar al crecimiento anual de la
  variable en cada año proyectado, desde el primer año con proyección hasta el final del horizonte.
- Las demás variables de escenario quedan en su sendero base. No se mueve una variable de escenario por su
  correlación con otra.

## F6-10 — Coherencia interna (lo que reemplaza a la validación)

**DECIDIDO (opción recomendada, autorización de Harold del 2026-10-17):** la lista tal cual. Cualquier ítem nuevo
entra con nota fechada antes de la corrida.

1. **Identidades, con `stop()`:**
   - la agregación trimestral → anual de cada sendero es consistente;
   - las remesas reales son las nominales entre el deflactor de ADR-010, cuando las dos se condicionan (el BVAR de
     G3 recibe las dos).
2. **Informativas, se reportan sin forzar nada:**
   - diferencia entre el crecimiento anual del escenario base y el del PIB de El Salvador en el propio WEO (una
     referencia, no un objetivo);
   - crecimiento promedio 2026-2030 frente al promedio histórico, con y sin 2020;
   - signo de la respuesta a cada variable de escenario en la sensibilidad (por ejemplo, más PIB de EE. UU. da más
     PIB de El Salvador).

## F6-11 — Unidad de reporte

**DECIDIDO (opción recomendada (a), autorización de Harold del 2026-10-17):** la cifra principal es el crecimiento
anual 2026-2030, con el promedio del año calendario de los niveles trimestrales SA. Se reportan además el interanual
trimestral y el nivel índice. El año del origen lleva trimestres observados y se marca. La unidad de modelación no
cambia (ADR-001).

**Delegada al agente; se puede reabrir (F6-11-a):** 2031 se reporta solo en trimestres (h = 20 llega a 2031-Q2) y
no tiene cifra anual.

## F6-12 — Preregistro y reproducibilidad

**DECIDIDO (opción recomendada, autorización de Harold del 2026-10-17):** el esquema de Fase 5.

- El corte, los supuestos en L0, los YAML de las satélite, la regla de F6-02, la guarda de F6-08 y la lista de
  F6-10 se congelan con commit antes de la primera proyección sobre datos reales.
- Una sola corrida. Si se detiene, se asienta qué escribió (regla del protocolo de evaluación §6).
- Reproducción bit a bit en la máquina de Harold con la BLAS de referencia; canarios sintéticos en CI: V22 (el
  condicional reproduce el sendero en un DGP conocido) y V23 (la guarda excluye un modelo explosivo sintético y el
  mínimo de miembros dispara `stop()`).
- `make fase6` como orden única.
- Fase 6 tiene su propio protocolo, `doc/metodologia/protocolo_proyeccion.md`, porque el §7 del protocolo de
  evaluación deja fuera el Ejercicio B.

## F6-13 — Pronóstico puntual del BVAR con h = 20

**DECIDIDO (opción recomendada (d) seguida de (a), autorización de Harold del 2026-10-17).**

- **(d) Medición previa.** En el origen de Fase 6, antes de cualquier proyección condicional y sin escenario, se
  corre el BVAR de cada grupo con la especificación de Fase 5 y se reportan solo:
  1. la proporción de extracciones cuya matriz compañera tiene módulo máximo mayor que 1 y mayor que 1,05;
  2. la distancia absoluta entre la media y la mediana de la predictiva del interanual con h = 8 y h = 20, en pp.

  No se mira el sendero ni las bandas. Las dos cifras van a la evidencia del preregistro.
- **(a) Sendero.** En el Ejercicio B, el sendero puntual del BVAR es la **mediana** de la predictiva posterior, por
  trimestre, y la densidad sigue usando todas las extracciones. En el Ejercicio A nada cambia (B2-10 sigue con la
  media).

**Delegada al agente; se puede reabrir (F6-13-a):** la medición no reabre (a) por sí sola. Si sale algo que la
ficha no anticipó (por ejemplo, que la mayoría de las extracciones sea explosiva), se le pregunta a Harold con una
ficha nueva antes de congelar.

---

## Fichas de especificación abiertas

Estas fichas se redactan con contexto verificado y una recomendación cuando haya datos para decidirlas. Ninguna
está decidida.

- **F6-14 — Escenario adverso.** Cuál de los escenarios del capítulo 1 del WEO de octubre de 2026 y cómo se
  traducen sus desviaciones (que pueden venir solo como anuales o regionales) a las variables de escenario,
  incluido el empleo de EE. UU. Se decide al capturar el capítulo y sus datos de gráficos.
- **F6-15 — Especificación de las satélite.** Forma, rezagos, muestra, dummies para las predictoras NSA y elección
  en las filas con dos candidatas de F6-03.
- **F6-16 — De supuestos anuales a trimestrales.** El WEO proyecta años; la CBO publica trimestres. Desagregación
  temporal (por ejemplo, Denton-Cholette con `tempdisagg`, ya en el stack) o crecimiento trimestral constante.
- **F6-17 — El puente con senderos trimestrales.** Cómo se combinan el borde mensual observado de o+1 y el sendero
  trimestral de la satélite.
- **F6-18 — Variables de escenario en L3.** Identificadores, transformaciones y validación de las series nuevas
  (regla 4: definición de variables nuevas).
