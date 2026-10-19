# Fase 6 — registro de decisiones de diseño

**Fecha:** 2026-10-17 · **Estado:** F6-01 a F6-13 decididas el 2026-10-17 en la opción recomendada de cada ficha,
por autorización de Harold (ver «Origen de estas decisiones»). Las fichas de especificación F6-14 en adelante están
abiertas.

**Nota (2026-10-19).** F6-14 a F6-18 quedaron decididas el 2026-10-19 en la opción recomendada, bajo la misma
autorización, con los hechos verificados ese día (recuadro 1.2 y fuentes de las satélites).

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

## Hechos verificados el 2026-10-19 (captura C2)

- **WEO de octubre de 2026 en L0.** Vintage `FMI.WEO.v2026-10`, archivo `FMI_weo_2026-10-19.json` (sha256
  `f115cd02d510e12d8537970ed0b84a0e93853f38958f541840bdbeaa39fef7ec`), por `descargar_fmi_weo()` de
  `src/adquisicion/fmi.R`. Es un extracto de la API con G001, USA y SLV y todos sus indicadores (173 series, anuales
  hasta 2031), para no adelantar la elección de satélites. Con `attributes=all` la respuesta trae el
  `PUBLICATION_DATE` del dataset (2026-10-13), que es la `fecha_publicacion`. El `updatedAfter` bisecado que usan
  BOP/QNEA/PCPS da 2026-10-09 en este dataflow, que es un refresco interno anterior a la publicación, y por eso no se
  usa. `COUNTRY_UPDATE_DATE`: USA 2026-09-30, SLV 2026-09-17; G001 no lo trae. Dos descargas seguidas dan el mismo
  sha256.
- **Capítulo 1 del WEO en L0.** Vintage `FMI.WEO.CAPITULO1.v2026-10`, archivo
  `FMI_weo_capitulo1_2026_october_2026-10-19.xlsx` (sha256
  `74576dbb057c6bcc1bf1f525b195ab29386c3a42fa6426d92ae14e6b0d1af961`), publicación nueva porque no sale de la API y
  porque con `FMI.WEO` colisionaría en `vintage_id`. Las figuras de escenarios para F6-14 son la 1.2.2 («Impact of
  Scenarios on the Level of GDP») y la 1.2.3 («Impact of Scenarios on the Other Key Macroeconomic Variables»), del
  recuadro 1.2. `fecha_publicacion` = `Last-Modified` del servidor (2026-10-13).
- **CBO: www.cbo.gov bloquea el acceso automatizado.** Responde 403 con un desafío de DataDome a un cliente sin
  navegador. Por la regla 9 no se evade. El canal programático es el repositorio público de la propia CBO,
  `US-CBO/cbo-data` (licencia de dominio público, 17 U.S.C. § 105 con renuncia mundial), que publica las
  proyecciones económicas en CSV por vintage. Vintage `CBO.PROYECCIONES_ECONOMICAS.v2026-02`, archivo
  `CBO_proyecciones_economicas_trimestrales_2026_02_2026-10-19.csv` (sha256
  `eda9f9eb6607461621504a973ff7609ef627ccfd02d8096219843efccf55ca7f`), por `src/adquisicion/cbo.R`. Es
  **trimestral**, 2023-T1 a 2036-T4, con `empl_payroll_nf` observado hasta 2025-T2. Sale de *The Budget and Economic
  Outlook: 2026 to 2036* (2026-02-11), con el pronóstico cerrado el 2025-12-03, es decir, ocho meses antes que el WEO.
  El repositorio no trae un vintage posterior a 2026-02. Las dos cosas entran a F6-15 y F6-16.
- **Copias.** Los tres archivos están en `data/L0_raw/` de la copia de Harold y en el almacén privado
  `SIE-el-salvador-L0` (commit `a6ea856`; el sha256 de cada blob coincide con el del manifiesto).

## Hechos verificados el 2026-10-19 (recuadro 1.2 y fuentes de las satélites)

- **Capítulo 1 en PDF.** `https://www.imf.org/-/media/files/publications/weo/2026/october/english/ch1.pdf`, 46
  páginas, 1 242 447 bytes, sha256 `56935fc42267b24a779f2b3b08886efec3a6ddacf26831ecab3188129ace7c70`,
  `Last-Modified` 2026-10-13. Se leyó para saber qué es cada escenario; las cifras salen del xlsx de L0. No se
  capturó a L0. El recuadro 1.2 («Risk Assessment Surrounding the Baseline Projection») ocupa las páginas 25 a 30 y
  tiene tres partes: bandas de confianza (figura 1.2.1), un escenario de materias primas y bonos y tres escenarios de
  inteligencia artificial.
- **Escenario de materias primas y bonos** (modelo G20 del FMI). El conflicto en Oriente Medio dura hasta fines de
  junio de 2027; el petróleo llega a 130 USD de 2026-T4 a 2027-T1 y vuelve a la base hacia 2027-T4, y queda 17 % y
  40 % sobre la base en el promedio de 2026 y 2027. Las primas por plazo suben 60 pb desde 2026-T4. El cuadro 1.2.1
  da, en pp de desvío de la base, el crecimiento del PIB de 2026 y 2027: Mundo −0,2 y −0,5, avanzadas −0,2 y −0,5,
  emergentes −0,3 y −0,6. El texto agrega el nivel del PIB de las avanzadas, −0,7 % hacia 2031. **No publica cifras
  de EE. UU.** Es el escenario «del petróleo a 130 USD» de las reseñas citadas el 2026-10-17.
- **Escenarios de inteligencia artificial** (modelo GIMF). **A, «Strong Payoffs»:** más inversión en IA y ganancias
  de productividad tempranas; es favorable. **B, «Capacity Constraints»:** el mismo gasto con oferta restringida en
  Asia, más inflación en EE. UU. y alza de tasas. **C, «Market Correction»:** las ganancias de productividad no
  llegan, cae la inversión en tecnología de EE. UU. y las acciones de EE. UU. bajan 20 % en 2026; es adverso.
  Valores de la hoja del vintage `FMI.WEO.CAPITULO1.v2026-10`, años 2026 a 2031:

  | Serie (EE. UU.) | Escenario A | Escenario B | Escenario C |
  |---|---|---|---|
  | Nivel del PIB, % de desvío (figura 1.2.2, panel 2) | 0,0 / 0,4 / 0,7 / 1,0 / 1,1 / 1,3 | 0,0 / 0,1 / 0,2 / 0,5 / 0,6 / 0,7 | 0,0 / −1,5 / −1,8 / −1,4 / −0,8 / −0,5 |
  | Inflación, pp de desvío (figura 1.2.3, panel 1) | 0,0 / 0,1 / 0,0 / 0,0 / 0,0 / 0,0 | 0,0 / 0,3 / 0,4 / 0,3 / 0,2 / 0,0 | 0,0 / 0,0 / −0,1 / −0,3 / −0,2 / 0,0 |

  El texto dice que con C el PIB mundial queda 1,1 % debajo de la base hacia 2028; la hoja trae −1,2 para el Mundo en
  2028. El dato de EE. UU. coincide (−1,8 en texto y hoja). Las figuras no traen petróleo, comercio mundial ni empleo.
- **Petróleo en L0 frente al WEO.** La serie capturada, `G001.POILAPSP.INDEX.M` (`FMI.PCPS.POILAPSP.v2026-08`), no
  es el precio que proyecta el WEO: de 2015 a 2025 su crecimiento anual difiere del de `G001.POILAPSP` del WEO entre
  −3,4 y +8,8 pp. En cambio, `G001.POILAPSP.USD.M` de la misma API (consultado el 2026-10-19, sin capturar) da un
  promedio anual igual al del WEO en todos esos años, que a su vez es el promedio simple de Brent, WTI y Dubai. No se
  verificó por qué el índice difiere.
- **PIB y precios de EE. UU. en L0 frente al WEO.** El crecimiento anual de GDPC1 (`FRED.BEA_PIB_EEUU.v2026-08`)
  difiere del de `USA.NGDP_RPCH` hasta 0,24 pp (2025) en 1993-2025; la media de 2015 a 2025 es 0,06 pp. Es diferencia de
  vintage. La inflación anual de CPIAUCSL (`FRED.CPIAUCSL.v2026-08`) coincide con `USA.PCPIPCH` a tres decimales en
  todos los años completos; 2025 no está completo porque falta 2025-10.
- **El WEO no publica** empleo asalariado de EE. UU. Sí publica, entre los precios de materias primas, `POILAPSP`,
  `PFOODW`, `PALLFNFW` y `PNFUELW`. No se verificó si `PFOODW` y `PALLFNFW` son los mismos conceptos que `PFOOD` y
  `PALLFNF` del PCPS en L0.
- **Predictoras externas de los elegibles** (YAML de `catalogos/06_modelos/`): remesas nominales en los 14; FOB en
  12; ITCER e IPM en 6 (G2 y G3); IPP en 3 (G3); remesas reales en 1 (`MULT.BVAR.G3`). Detalle en F6-15.
- **Catálogos.** `03_series.csv` no tiene series de FRED, del FMI ni de la CBO, y el `rol` de `05_series_master.csv`
  no admite un valor para variables de escenario. Las dos cosas entran a F6-18.

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
| F6-14 | Adverso = escenario C del recuadro 1.2 (corrección del mercado de IA); desvíos anuales de PIB e inflación de EE. UU.; el petróleo queda en la base | protocolo de proyección §4 |
| F6-15 | Seis satélite ADL en Δlog (PIB de EE. UU. para remesas y FOB, IPC de EE. UU. para ITCER, petróleo para IPM e IPP); error por varianza total; la CBO queda sin uso | protocolo §5; `CBO.PROYECCIONES_ECONOMICAS.yaml` y ADR-008 (notas 2026-10-19) |
| F6-16 | Denton-Cholette con los trimestres observados fijos y metas anuales encadenadas con los crecimientos del WEO | protocolo §4 |
| F6-17 | En el puente manda el dato observado de o+1; desde el primer trimestre sin meses, el agregado de la satélite | protocolo §6 |
| F6-18 | Series `ESC.*` por escenario en L3 con rol nuevo `escenario`; petróleo en USD (publicación nueva); validación con `stop()` | protocolo §5; checklist (C2b) |

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

**Nota (2026-10-19).** F6-15 eligió el PIB de EE. UU. para remesas y FOB, el IPC de EE. UU. para ITCER y el
petróleo para IPM e IPP. El empleo de EE. UU., el comercio mundial y los índices de alimentos y general de materias
primas no se usan.

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

**Nota (2026-10-19), favorable.** Se cumplió la condición de la opción (b): el recuadro 1.2 del capítulo 1 del mismo
WEO publica un escenario favorable con cifras para EE. UU., el **A** («Strong Payoffs»). Entra como escenario
favorable, con la misma traducción que el adverso de F6-14 y sus desvíos de las figuras 1.2.2 y 1.2.3. Los escenarios
del Ejercicio B quedan en base, adverso (C), favorable (A) y sensibilidad.

**Delegada al agente; se puede reabrir (F6-05-b):** el favorable es A y no B. B también sube el PIB de EE. UU., pero
con más inflación y alza de tasas; no es el lado favorable de C. A y C salen del mismo modelo (GIMF), del mismo
recuadro y con las mismas variables.

**Nota (2026-10-19), empleo.** F6-15 eligió el PIB de EE. UU. del WEO para la satélite de remesas. La línea «Empleo de
EE. UU.» y F6-05-a quedan sin efecto: la CBO queda capturada en L0 (`CBO.PROYECCIONES_ECONOMICAS.v2026-02`) y sin
uso en Fase 6, con nota fechada en su YAML y en el tramo CBO de ADR-008. La razón de no usar el SEP de la Fed sigue
valiendo.

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

**Nota (2026-10-19).** Con F6-15, las variables de escenario son tres: PIB de EE. UU., IPC de EE. UU. y petróleo.
La sensibilidad son seis corridas (±1 desviación estándar de cada una), con sus senderos armados como dice F6-18-c.

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

## Fichas de especificación F6-14 a F6-18

**Nota (2026-10-19).** Hasta esta fecha esta sección listaba las cinco fichas como abiertas. Se redactaron y
decidieron el 2026-10-19 con los hechos de «Hechos verificados el 2026-10-19 (recuadro 1.2 y fuentes de las
satélites)», en la opción recomendada de cada una y bajo la delegación del 2026-10-17 (regla 4 de `CLAUDE.md`). Cada
ficha conserva su pregunta original.

## F6-14 — Escenario adverso y traducción de sus desviaciones

**Pregunta (la de la lista abierta).** Cuál de los escenarios del capítulo 1 del WEO de octubre de 2026 y cómo se
traducen sus desviaciones (que pueden venir solo como anuales o regionales) a las variables de escenario, incluido
el empleo de EE. UU.

**Contexto verificado.** El recuadro 1.2 tiene dos bloques de escenarios (detalle en los hechos del 2026-10-19):

- **Materias primas y bonos** (modelo G20). Publica petróleo +17 % y +40 % sobre la base en el promedio de 2026 y
  2027, con 130 USD de 2026-T4 a 2027-T1, y el crecimiento del Mundo, de las avanzadas y de las emergentes en 2026 y
  2027 (cuadro 1.2.1). **No publica cifras de EE. UU.** ni un sendero del petróleo después de 2027 fuera de «vuelve a
  la base hacia 2027-T4».
- **Inteligencia artificial** (modelo GIMF). A es favorable, B es mixto y C es adverso. Para EE. UU. publica, de
  2026 a 2031, el nivel del PIB en % de desvío de la base (figura 1.2.2) y la inflación en pp (figura 1.2.3).

Las predictoras externas que mueve cada variable de escenario están en F6-15: el PIB de EE. UU. llega a remesas y FOB,
es decir, a los 14 elegibles; el petróleo llega a IPM e IPP, que solo están en 6 elegibles de G2 y G3.

**Opciones.**

- **(a) Escenario C** («Market Correction»). Trae EE. UU. en todo el horizonte, con las dos variables que usan las
  satélite de F6-15, y viene del mismo modelo y del mismo recuadro que el A (favorable). No mueve el petróleo.
- **(b) Materias primas y bonos.** Mueve el petróleo, pero el PIB de EE. UU. tendría que suponerse igual al de las
  avanzadas, y solo hay crecimiento de 2026 y 2027 más un nivel en 2031. Hacen falta supuestos sin fuente para
  2028-2031 y para el perfil trimestral del petróleo.
- **(c) Los dos como adversos.** F6-05 fija **un** escenario de riesgo; esta opción reabre F6-05 y habría que
  preguntarle a Harold.

**Implicación práctica.** Con (a), el adverso entra por remesas y FOB (todos los grupos) y por ITCER (G2 y G3), y el
petróleo queda en la base. Con (b) entraría casi solo por IPM e IPP en G2 y G3, y el canal de EE. UU. sería un
supuesto propio. El riesgo de petróleo se sigue viendo en la sensibilidad de F6-09.

**Recomendación:** (a).

**DECIDIDO (opción recomendada (a), delegación del 2026-10-17):** el escenario adverso es el **C** del recuadro 1.2.
Traducción a las variables de escenario (F6-18), año a año, de 2026 a 2031:

- **PIB de EE. UU.:** nivel anual del adverso = nivel anual de la base × (1 + d_y / 100), con d_y de la figura 1.2.2,
  panel 2 (EE. UU.), fila «Scenario C»: 0,0 / −1,5 / −1,8 / −1,4 / −0,8 / −0,5.
- **Inflación de EE. UU.:** inflación anual del adverso = la de la base + d_y (pp), con d_y de la figura 1.2.3, panel
  1, línea de EE. UU., fila «Scenario C»: 0,0 / 0,0 / −0,1 / −0,3 / −0,2 / 0,0. El índice se encadena con esa
  inflación.
- **Petróleo:** el escenario C no lo publica. Queda en el sendero base y el informe lo declara.
- **Empleo de EE. UU.:** no se usa (F6-15).
- Las cifras se leen de la hoja del vintage `FMI.WEO.CAPITULO1.v2026-10` en L0, no del PDF. El PDF solo fija qué
  es cada letra. El paso a trimestres es F6-16.

**Delegada al agente; se puede reabrir (F6-14-a):** la «Inflation» de la figura 1.2.3 se lee como la inflación del
IPC en promedio anual, la variable `PCPIPCH` de la base de datos del WEO. El recuadro no lo precisa. Con C los desvíos
son de 0,3 pp o menos, así que la lectura importa poco.

**Delegada al agente; se puede reabrir (F6-14-b):** las cifras van con el decimal que trae la hoja. No se
reconstruyen decimales a partir del gráfico.

## F6-15 — Especificación de las satélite

**Pregunta (la de la lista abierta).** Forma, rezagos, muestra, dummies para las predictoras NSA y elección en las
filas con dos candidatas de F6-03.

**Contexto verificado.** Predictoras externas de los 14 elegibles, según sus YAML:

| Predictora (L3, trimestral) | Modelos elegibles que la usan |
|---|---|
| `BCR.REMESAS.NOM.NSA.Q` | los 14 |
| `BCR.EXPORT_FOB.NOM.NSA.Q` | 12 (todos menos `MULT.VAR_DIF.G2` y `.G3`) |
| `BCR.ITCER.IDX.NSA.Q`, `BCR.IPM.IDX.NSA.Q` | 6 (`UNI.ARIMAX`, `MULT.BVAR` y `MIX.PUENTE` de G2 y G3) |
| `BCR.IPP.IDX.NSA.Q` | 3 (los mismos, solo G3) |
| `BCR.REMESAS.REAL.NSA.Q` | 1 (`MULT.BVAR.G3`) |

El puente usa las versiones mensuales, pero su ecuación solo toma los agregados trimestrales (F6-17). Las seis son
NSA. Fuentes: la base del WEO trae PIB e inflación de EE. UU., petróleo y comercio mundial (anuales) y no trae empleo
asalariado; A y C publican solo PIB e inflación de EE. UU.; la CBO trae empleo trimestral, pero su vintage es del
2026-02. No hay historia trimestral del comercio mundial en L0.

**Opciones para las filas con dos candidatas.**

- **Remesas:** (a) PIB de EE. UU. o (b) empleo de EE. UU. de la CBO. Con (b), la base mezclaría dos fuentes con ocho
  meses de diferencia, y el adverso y el favorable necesitarían pasar el desvío del PIB a empleo con una elasticidad
  sin fuente.
- **FOB:** (a) PIB de EE. UU. o (b) comercio mundial. Con (b) no hay historia trimestral para estimar, y ni A ni C
  publican comercio.
- **IPM e IPP:** (a) solo el petróleo o (b) el petróleo más alimentos o el índice general. El WEO publica `PFOODW` y
  `PALLFNFW`, y no está verificado que sean los mismos conceptos que `PFOOD` y `PALLFNF` de L0.
- **ITCER:** (a) la inflación de EE. UU. o (b) el diferencial con la inflación local. La inflación local es interna
  (como IVAE y UT en F6-03), no tiene serie en L3 y ningún escenario publica su desvío.

**Opciones de forma.** (a) Rezagos distribuidos autorregresivos en Δlog, estimados por MCO; (b) niveles con
corrección de error; (c) elasticidad fija sin estimar. (b) exige una relación de largo plazo que el Ejercicio A no
evaluó, y (c) es un supuesto sin fuente.

**Recomendación:** (a) en todas las filas y forma (a).

**DECIDIDO (opción recomendada, delegación del 2026-10-17):**

| Satélite | Predictora | Variable de escenario |
|---|---|---|
| `SAT.REMESAS_NOM` | `BCR.REMESAS.NOM.NSA.Q` | PIB de EE. UU. |
| `SAT.REMESAS_REAL` | `BCR.REMESAS.REAL.NSA.Q` | PIB de EE. UU. |
| `SAT.EXPORT_FOB` | `BCR.EXPORT_FOB.NOM.NSA.Q` | PIB de EE. UU. |
| `SAT.ITCER` | `BCR.ITCER.IDX.NSA.Q` | IPC de EE. UU. |
| `SAT.IPM` | `BCR.IPM.IDX.NSA.Q` | petróleo (promedio APSP, USD) |
| `SAT.IPP` | `BCR.IPP.IDX.NSA.Q` | petróleo (promedio APSP, USD) |

- **Ecuación:** Δlog X_t = c + δ'D_t + Σ_{i=1..p} φ_i Δlog X_{t−i} + Σ_{j=0..q} β_j Δlog Z_{t−j} + e_t, con D las
  dummies T2..T4 (las seis predictoras son NSA) y Z la variable de escenario trimestral de F6-18.
- **Rezagos:** p en 0..4 y q en 0..4, por BIC sobre la misma muestra (las filas con cuatro rezagos disponibles), como
  B2-2. El término contemporáneo β_0 está siempre: sin él la satélite no transmite el escenario.
- **Muestra:** desde el primer trimestre con las dos series hasta el origen `o`, sin las filas cuyo trimestre está en
  2020 o 2021. Eso equivale a ocho dummies de impulso y sigue el criterio de F6-08-a y F6-09-a.
- **Estimación:** una sola vez, en `o` (F6-04). Una satélite por predictora, común a G1-G3, a los modelos
  trimestrales y al puente. Cada una lleva su YAML en `catalogos/06_modelos/` antes de correr (D3).
- **Sendero:** la ecuación se itera con el sendero de Z del escenario y los rezagos observados de X.
- **Guardas (`stop()`):** matriz sin rango completo; raíz del polinomio en φ con módulo ≥ 1; menos de 20 grados de
  libertad (el `PISO_GL` de Fase 5).

**Delegada al agente; se puede reabrir (F6-15-a), cómo se suma el error de la satélite:** por varianza total. Si el
pronóstico del modelo dado el sendero apilado de sus predictoras externas X es normal, con media lineal en X
(matriz J) y covarianza Σ_y, y la satélite da X ~ N(m, Σ_X) dado el sendero de Z, la densidad del modelo es
N(μ(m), Σ_y + J Σ_X J'). Σ_X sale de los pesos MA de cada satélite y de la covarianza contemporánea de sus residuos,
estimada en la muestra común de las satélites que usa ese modelo, como en B3b-6. En el BVAR, J y Σ_y van por
extracción y Σ_X es común. Va con estimador plug-in, sin incertidumbre de parámetros, como en Fase 5. Se supone que los
residuos de la satélite son independientes de las innovaciones del modelo, y el informe lo declara.

**Delegada al agente; se puede reabrir (F6-15-b):** las remesas nominales y las reales tienen cada una su satélite
sobre el mismo Z. El deflactor implícito (cociente entre ambas) no queda atado. Solo afecta a `MULT.BVAR.G3` y se
declara.

**Consecuencias (2026-10-19).** La CBO queda capturada y sin uso en Fase 6, como preveía F6-05-a. Va nota fechada en
su YAML, en F6-05 y en el tramo CBO de ADR-008. El comercio mundial tampoco se usa (protocolo §4).

## F6-16 — De supuestos anuales a trimestrales

**Pregunta (la de la lista abierta).** El WEO proyecta años; la CBO publica trimestres. Desagregación temporal (por
ejemplo, Denton-Cholette con `tempdisagg`, ya en el stack) o crecimiento trimestral constante.

**Contexto verificado.** Con F6-15, las tres variables de escenario (PIB e IPC de EE. UU. y petróleo) vienen del WEO,
anuales, y tienen historia trimestral en L0 (FRED y PCPS). El año del origen está observado en parte: el PIB de EE.
UU. hasta 2026-T2 en el vintage de L0, y el IPC y el petróleo mensuales hasta 2026-07. Entre el WEO y FRED el
crecimiento anual del PIB de EE. UU. difiere hasta 0,24 pp (2025) por vintage. `tempdisagg` 1.2.0 está en el
`renv.lock`.

**Opciones.**

- **(a) Denton-Cholette** con los trimestres observados fijos: el sendero trimestral más suave (mínimas primeras
  diferencias) cuyo promedio de cada año iguala el supuesto anual.
- **(b) Crecimiento trimestral constante dentro de cada año.** Da saltos de pendiente en cada enero y no respeta
  exactamente el promedio anual cuando el año está observado en parte.
- **(c) Perfil intra-anual de la CBO** para el PIB de EE. UU. Mezcla fuente y vintage, y no sirve para el IPC ni el
  petróleo.

**Recomendación:** (a).

**DECIDIDO (opción recomendada (a), delegación del 2026-10-17):**

- **Metas anuales:** A_y = promedio de los cuatro trimestres del año y. El año ancla es el último año completo de la
  historia trimestral en L3; de ahí en adelante, A_y = A_{y−1} · (1 + g_y / 100), con g_y el crecimiento anual del
  WEO del escenario (F6-14). Se encadenan **crecimientos** del WEO sobre la historia propia, no niveles.
- **Sendero:** se fijan los trimestres observados y se eligen los demás, hasta 2031-T4, para minimizar Σ (x_t −
  x_{t−1})² desde el último trimestre observado, con la restricción de que cada año proyectado promedie A_y. Los
  trimestres observados del año del origen entran en su promedio. Es un problema de mínimos cuadrados con
  restricciones lineales y se resuelve en forma cerrada con código propio.
- **Contraste:** sin trimestres fijos, el código propio debe coincidir con
  `tempdisagg::td(A ~ 1, conversion = "average", method = "denton-cholette")` (prueba sintética en D3).

**Delegada al agente; se puede reabrir (F6-16-a):** solo se fijan trimestres **completos**. Un trimestre con uno o dos
meses observados cuenta como no observado.

**Delegada al agente; se puede reabrir (F6-16-b):** el sendero se resuelve hasta 2031-T4 aunque el horizonte termine
antes, porque la meta de 2031 necesita sus cuatro trimestres. Una propiedad que se declara: con d_2026 = 0 y d_2027 ≠ 0
(A y C), el suavizado curva también los trimestres libres de 2026 sin cambiar su promedio.

## F6-17 — El puente con senderos trimestrales

**Pregunta (la de la lista abierta).** Cómo se combinan el borde mensual observado de o+1 y el sendero trimestral de
la satélite.

**Contexto verificado.** La ecuación del puente (F5-05, B3b) usa solo los agregados trimestrales de sus predictoras
mensuales. En Fase 5, los meses de o+1 que admite el calendario entran observados (F5-04) y un AR(p)-BIC mensual
completa el resto hasta el último mes de o+8 (B3b-4). El Δlog trimestral no depende de si el agregado es suma o
promedio. Las predictoras externas del puente son remesas y FOB (G1-G3), ITCER e IPM (G2 y G3) e IPP (G3); las
internas son IVAE y UT (G2 y G3).

**Opciones.**

- **(a) El dato observado manda.** En o+1, los meses observados más el AR mensual de Fase 5 para los que faltan; desde
  el primer trimestre sin meses observados, el agregado trimestral sale de la satélite.
- **(b) Satélite desde o+1,** sin usar los meses observados de o+1. Pierde el dato que da su ventaja al puente.
- **(c) Satélites mensuales.** Doce veces más parámetros, y los escenarios no son mensuales.

**Recomendación:** (a).

**DECIDIDO (opción recomendada (a), delegación del 2026-10-17):**

- **Predictoras externas.** Si o+1 tiene sus tres meses observados, su agregado es dato. Si tiene uno o dos, los que
  faltan se completan con el AR mensual de B3b-4, y la satélite no se usa en o+1 para esa predictora. Desde el primer
  trimestre sin meses observados, Δlog X_Q viene de la satélite de F6-15. Para las externas no hace falta un sendero
  mensual más allá de o+1.
- **Predictoras internas (IVAE y UT).** El AR mensual de Fase 5 hasta el último mes de o+20 (antes, o+8).
- **Densidad.** El sistema lineal de B3b-5 y B3b-6, reducido a los AR mensuales que siguen en uso (los de las
  internas y los de los meses que faltan en o+1), más el término de la satélite (F6-15-a). Se suponen independientes
  los residuos de los AR mensuales y los de las satélites.

**Delegada al agente; se puede reabrir (F6-17-a), regla general del borde para todos los modelos:** un trimestre
**completo** observado de una predictora externa posterior a `o` entra como dato en todos los elegibles: en la
ARIMAX como regresor conocido y en el VAR, el VECM y el BVAR como parte del sendero condicionado. La satélite arranca
en el primer trimestre sin dato completo. Si una predictora no llega a `o`, rige la guarda de Fase 5 (`stop()`); las
satélites no rellenan huecos anteriores al origen.

**Delegada al agente; se puede reabrir (F6-17-b):** si o+1 está incompleto, el puente usa en o+1 el AR mensual y los
modelos trimestrales usan la satélite, así que en ese trimestre los escenarios no difieren para el puente. Se declara;
cuántos meses de o+1 hay se sabe al congelar.

## F6-18 — Variables de escenario en L3

**Pregunta (la de la lista abierta).** Identificadores, transformaciones y validación de las series nuevas (regla 4:
definición de variables nuevas).

**Contexto verificado.** `03_series.csv` no tiene ninguna serie de FRED, del FMI ni de la CBO: las publicaciones
y sus vintages existen, las series no. El campo `rol` de `05_series_master.csv` admite solo `target_primary`,
`target_robustness`, `predictor` e `intermediate` (`datapackage.json`). La serie de petróleo de L0
(`G001.POILAPSP.INDEX.M`) **no** es el precio que proyecta el WEO: su crecimiento anual difiere del de `POILAPSP` del
WEO hasta 8,8 pp (2022). La unidad en USD de la misma API (`G001.POILAPSP.USD.M`) da un promedio anual idéntico al del
WEO de 2015 a 2025. Al IPC de EE. UU. de L0 le falta 2025-10.

**Opciones.** (a) Series de escenario completas en L3 (historia + proyección) por escenario, construidas por una
transformación declarada; (b) solo la historia en L3 y los senderos armados en tiempo de corrida, en L4. Con (b),
los senderos no pasan por la validación de Fase 3 ni quedan en el linaje de L3.

**Recomendación:** (a).

**DECIDIDO (opción recomendada (a), delegación del 2026-10-17):**

- **Captura previa (C2b del checklist).** `G001.POILAPSP.USD.M` entra a L0 como publicación nueva,
  `FMI.PCPS.POILAPSP_USD`, por el esquema (regla 2). No se usa la unidad `INDEX` ya capturada. Antes de congelar
  también se renuevan los vintages de FRED del PIB y del IPC de EE. UU. (C4).
- **`03_series.csv`:** `FRED.PIB_EEUU.VOL.SA.Q` (GDPC1), `FRED.IPC_EEUU.IDX.SA.M` (CPIAUCSL),
  `FMI.PETROLEO_APSP.USD.NSA.M`; del WEO, `FMI.PIB_EEUU_VAR.PCT.NSA.A` (`USA.NGDP_RPCH`),
  `FMI.IPC_EEUU_VAR.PCT.NSA.A` (`USA.PCPIPCH`) y `FMI.PETROLEO_APSP.USD.NSA.A` (`G001.POILAPSP`); del capítulo 1,
  `FMI.DESV_PIB_EEUU_ESC_A.PCT.NSA.A`, `FMI.DESV_PIB_EEUU_ESC_C.PCT.NSA.A`, `FMI.DESV_INFL_EEUU_ESC_A.PP.NSA.A` y
  `FMI.DESV_INFL_EEUU_ESC_C.PP.NSA.A`, con `hoja` y celdas, verificadas con `verificar_fuente_celda.R` y asentadas
  en la bitácora (regla 8).
- **`04_transformaciones.csv`:** `T012` agregación trimestral del IPC de EE. UU. (promedio de 3 meses), `T013`
  agregación trimestral del petróleo (promedio) y `T014_SENDERO_ESCENARIO` (traducción de F6-14 y desagregación de
  F6-16).
- **`05_series_master.csv`:** `FRED.PIB_EEUU.VOL.SA.Q`, `FRED.IPC_EEUU.IDX.SA.Q` y `FMI.PETROLEO_APSP.USD.NSA.Q`
  (historia) y `ESC.PIB_EEUU.VOL.SA.Q.{BASE,ADVERSO,FAVORABLE}`, `ESC.IPC_EEUU.IDX.SA.Q.{BASE,ADVERSO,FAVORABLE}`
  y `ESC.PETROLEO_APSP.USD.NSA.Q.BASE` (historia + proyección hasta 2031-T4). Rol nuevo `escenario`, agregado
  primero a `datapackage.json` (regla 2). Una variable que un escenario no publica usa la serie `BASE`; no se
  duplica.
- **Validación (`stop()`, regla 7):** (1) el promedio anual de cada año proyectado iguala su meta con error relativo
  ≤ 1e-10; (2) la historia de cada serie `ESC.*` es bit a bit la de su serie histórica y la misma en todos los
  escenarios; (3) adverso / base − 1 = d_y / 100 en el PIB y la diferencia de inflación = d_y, a 1e-10; (4) sin NA,
  niveles positivos, trimestres contiguos y fin ≥ `o` + 20; (5) el promedio anual del petróleo en USD iguala la
  historia de `POILAPSP` del WEO con error relativo ≤ 1e-6 en los años completos comunes; (6) la inflación anual del
  IPC de FRED difiere de `PCPIPCH` del WEO en ≤ 0,01 pp en los años completos comunes. El PIB de EE. UU. solo se
  informa (difiere por vintage).

**Delegada al agente; se puede reabrir (F6-18-a), identificadores:** el prefijo `ESC` marca una serie construida por el
SIE con más de una fuente, como `PIB.SA.PROPIO.Q` en el objetivo. El sufijo tras la frecuencia nombra el escenario.
Es un uso nuevo del sufijo de la senda §3.4 (allí distingue tramos de captura) y queda declarado aquí.

**Delegada al agente; se puede reabrir (F6-18-b), dato faltante:** un mes aislado sin dato en una serie mensual de
escenario (hoy 2025-10 del IPC de EE. UU.) se interpola log-linealmente entre sus vecinos, solo para el agregado
trimestral, con nota en el catálogo. Un hueco de dos meses o más es `stop()`.

**Delegada al agente; se puede reabrir (F6-18-c):** los senderos de la sensibilidad (F6-09) no van a L3. Se arman en
L4 con la misma función de `T014`, a partir de las metas anuales de la base y de las desviaciones estándar de
F6-09-a, y quedan en el manifiesto.
