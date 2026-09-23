# Checklist de Fase 3 — Normalización, validación y series maestras

> Deriva de `doc/senda_metodologica.md` §4 (Fase 3). No sustituye la senda ni el
> índice de ADR (`doc/adr/README.md`) — es un tablero de seguimiento operativo,
> vivo, para no perder de vista qué falta antes de poder escribir la nota de
> cierre en `doc/adr/README.md`. **Última actualización: 2026-09-23 — enmienda
> del alcance E1/D3: `UT.DEMANDA_ELEC` (demanda total de electricidad) entra a
> la matriz de predictores, que pasa a 8 familias y 18 series en
> `data/L3_master/`.** Decisión de Harold, sobre la contradicción entre esta
> nota de cierre (que dejaba UT fuera de la matriz) y
> `doc/relevamiento_predictores_energia_turismo.md` (2026-08-27), que ya
> declaraba que energía entra al conjunto de predictores. Ejecutado en esa
> sesión: `T011` en `04_transformaciones`, dos filas en `05_series_master`,
> `UT_DEMANDA_ELEC_GWH_NSA_M/.Q` materializadas, y exploratorio/estacionariedad/
> HEGY regenerados sobre 18 series sin que cambie ninguno de los 64 veredictos
> previos. Se cerró de paso la última casilla `[~]` del tablero (construcción de
> la matriz de predictores), que contradecía a su propio entregable. Sesión
> anterior, 2026-09-22 — operacionalización de `checklist_cierre_fase3.md` y
> cierre de Fase 3.
> Cerradas en esa sesión: E1/D3 (matriz de predictores fija en 7 familias
> BCR, enmendado el 2026-09-23 a 8), E2 (mapeo 29-vs-28 de PIB, es `FBK`), E3/D4 (columna `vintage_id` en
> `data/L3_master/`, `src/transformacion/vintage_lib.R`), A1 (UT normalizada
> al esquema largo, entra a la batería L2), D1 (componente estacional: HEGY
> propio en R + dummies en el ADF, nota de seguimiento de ADR-010), D2
> (diagnóstico de outliers del objetivo en `reporte_estacionariedad.csv`),
> G1/G2 (`verificar_fuente_celda.R` corre desde `make trace`, corrida de
> cierre en `doc/bitacora_verificaciones.md`), H1 (PR #6 fusionado), H2
> (retirada la afirmación "valida empíricamente" que C1 ya había corregido en
> el reporte pero no acá). Ver `doc/adr/README.md`, "Cierre de Fase 3", para
> el acta completa. Sesión anterior, 2026-09-17 (segunda sesión del día):
> "análisis exploratorio y de estacionariedad" completado
> por entero — la mitad "estacionariedad" (ADF+KPSS confirmatorio, BIC, 4
> transformaciones por serie) se resolvió vía `AskUserQuestion` con Harold y
> se materializó en `src/analisis/estacionariedad.R`, incorporando `urca`
> como nueva dependencia (ADR-009, nota de seguimiento). Sesión anterior del
> mismo día: arrancó la mitad "exploratorio" descriptiva
> (`src/analisis/exploracion_series.R`), se diagnosticó y luego se resolvió
> la decisión #4 (`src/validacion/validar_integridad_catalogos.R`,
> pointblank, subsume 6 de las 7 aristas del guard de integridad
> referencial). Ver detalle en las secciones correspondientes. Sesión
> anterior (2026-09-16, quinta del día): quinto y
> sexto predictor de la matriz, BCR.ITCER —tipo de
> cambio efectivo real, serie global— y BCR.IPM —índice de precios de
> importación—, admitidos sin `AskUserQuestion` por instrucción explícita de
> Harold de proceder sin supervisión turno a turno para el resto de la
> matriz; ver secciones abajo. Sesión anterior del mismo día: cuarto
> predictor, BCR.EXPORT_FOB —exportaciones FOB de la Balanza Comercial de
> Mercancías—. Sesión anterior a esa: tercer predictor, BCR.IPP —índice de
> precios al productor—. Sesión anterior a esa: enmienda de ADR-010 sobre
> ajuste estacional en predictoras, y segundo predictor de la matriz, remesas
> —nominal y real—, más su deflactor IPC. Sesión anterior a esa: migración
> parcial a pointblank de la batería L2 PIB + reporte de calidad de datos;
> ADR-010 resuelve el método de transformación L3 de la matriz de
> predictores; L3 de la variable objetivo materializado; ADR-008
> gana tramo UT; primer predictor, BCR.IVAE, admitido y materializado).

## Actividades (senda §4)

- [x] **L0 → L1 (formato largo).** `src/transformacion/extraer_bcr_pib.R`
  produce `data/L1_staging/BCR_PIB_series_largo.csv` (98 series × 8057 obs).
  `src/transformacion/ut_demanda_serie.R` cubre UT.
- [x] **Batería de validaciones (L2).** `src/validacion/l2_pib_reglas.R` +
  `validar_l2_pib.R` implementan esquema, integridad referencial bidireccional,
  duplicados, huecos e identidad contable. **Migrado a `pointblank`
  (2026-09-16)** en la parte que calza con su modelo de fila — esquema,
  huérfanas (dirección L1→catálogo) y duplicados — como pasos nativos de un
  mismo `ptblank_agent`, con extracción de las filas que fallaron
  (`get_data_extracts()`). Los checks que requieren reformular la tabla
  (ausentes en la dirección catálogo→L1, huecos por serie, identidad contable
  entre series) siguen en R base — `specially()` no soporta extracts en
  pointblank 0.12.4 cuando la función devuelve algo distinto a un vector
  lógico plano (confirmado empíricamente: además, devolver un `data.frame`
  base en modo tabla revienta el paso con `eval == "ERROR"`; hay que usar
  vector lógico o `tibble`) — pero se registran en el mismo agente sobre el
  vector ya calculado en R, sin repetir cómputo, para que el agente sea
  árbitro único y el reporte quede unificado. `validar_l2()` ahora devuelve
  `list(errores, agente)`; `tests/test-validar-l2-pib.R` actualizado al nuevo
  contrato, las 11 aserciones existentes siguen verificando lo mismo (validado
  también contra el L1 real de 98 series, cero falsos positivos).
  **Extendido a predictores y cerrado (2026-09-17 → 2026-09-22, A1 del
  checklist de cierre de Fase 3):** `src/validacion/validar_l2_predictores.R`
  y `l2_serie_larga_reglas.R` corren los checks 1-4 sobre las **8** series
  predictoras mensuales de L1 (las 7 de la matriz que alimentan
  `l3_predictores.R` más `UT.DEMANDA_ELEC.GWH.NSA.M`, que no entra a L3 pero
  sí a esta batería). UT quedaba excluida porque su L1 escribía
  `anio|mes|periodo|gwh` en vez del esquema largo `serie_id|periodo|valor|
  provisional`; `ut_demanda_serie.R` se normalizó a ese esquema (2026-09-22)
  sin tocar sus propias validaciones de conteo/huecos, y ahora corre la
  batería genérica igual que las demás. Las 8 pasan.
- [x] **Transformaciones L3** (empalmes, deflactación, ajuste estacional,
  cambios de frecuencia, logaritmos y diferencias). **Cerrado (2026-09-22,
  A2 del checklist de cierre de Fase 3):** completo para la variable
  objetivo (T001/T002) y para las 8 familias de predictores que cierran la
  matriz (E1/D3, enmendado 2026-09-23: las 7 del BCR más UT) — el resto de predictores queda diferido, no pendiente de
  esta actividad. Gana columna `vintage_id` en la misma sesión (E3/D4, ver
  entregable "Base maestra bitemporal").
  **Variable objetivo materializada (2026-09-16):** `src/transformacion/
  l3_pib_objetivo.R` + `l3_pib_objetivo_reglas.R` implementan T001 (empalme
  RETRO+nativo, `concatenar_pib_nsa()`) y T002 (ajuste estacional propio vía
  `seasonal::seas()`, `ajustar_estacional_propio()`, ADR-001/ADR-004),
  encadenados en `make master`. Salida: `data/L3_master/PIB_SA_PROPIO_Q.csv`
  (145 obs) + `PIB_SA_PROPIO_Q_outliers.csv` (2 outliers AO declarados,
  2020-Q2 y 2020-Q3) + `PIB_SA_OFICIAL_Q.csv` (85 obs, pass-through). Verificó
  y documentó de paso un hallazgo de precisión numérica en el empalme (hasta
  0.0078 de diferencia RETRO-vs-nativo en el tramo de superposición — ver
  `doc/metodologia/empalme_cuentas_nacionales.md`), sin reabrir ADR-003.
  `tests/test-l3-pib-objetivo.R` cubre ambas funciones con datos sintéticos
  (15 aserciones), incluida una corrida real de X-13ARIMA-SEATS sobre un
  shock inyectado.
  **Primer predictor materializado (2026-09-16): `BCR.IVAE.VOL.SA.M/.Q`**
  (Índice de Volumen de la Actividad Económica, senda §6.4). Ya es índice de
  volumen y ya viene SA de fuente — sin deflactación ni ajuste estacional
  propio. `src/transformacion/l3_predictores.R` +
  `l3_predictores_reglas.R` (`agregar_trimestral_promedio()`) conservan la
  serie mensual tal cual y agregan a trimestral por promedio simple de 3
  meses (ADR-010: la agregación alta→baja frecuencia es aritmética
  determinista, no usa `tempdisagg`, reservado para desagregación
  baja→alta). Salida: `BCR_IVAE_VOL_SA_M.csv` (257 obs) +
  `BCR_IVAE_VOL_SA_Q.csv` (85 obs, 2026-Q2 excluido por incompleto).
  `tests/test-l3-predictores.R` (7 aserciones).
  **Segundo predictor materializado (2026-09-16, segunda sesión):
  `BCR.REMESAS.NOM/REAL.NSA.M/.Q`** (Ingresos mensuales de remesas
  familiares, senda §6.4, sector externo). A diferencia de IVAE, esta
  publicación no tenía archivo en `data/L0_raw/` antes de esta sesión — se
  capturó en vivo, just-in-time, con `src/adquisicion/bcr.R`
  (`descargar_bcr_remesas()`), mismo mecanismo que el resto de la familia
  BCR (chromote + interceptación de descarga real). Es una serie NOMINAL
  (millones de US$ corrientes) y NSA, no un índice SA como IVAE. Por
  decisión de Harold (AskUserQuestion de esta sesión), se materializa en
  dos versiones: nominal (pass-through) y real, deflactada por un índice de
  precios (`ONEC.IPC.IDX.NSA.M`, capturado también just-in-time esta
  sesión — la URL de su ficha en `01_publicaciones` había devuelto 404 en
  el intento de verificación de Harold del 2026-08-12; reintentada en vivo,
  respondió con normalidad, ver esa ficha). Al ser flujos (no niveles), la
  agregación mensual→trimestral usa SUMA (`agregar_trimestral_suma()`,
  ADR-010), no promedio — la función compartida `.agregar_trimestral()`
  también se corrigió para no tratar como hueco un trimestre incompleto en
  el PRIMER borde de la serie (necesario porque `deflactar_serie()` puede
  arrancar a mitad de trimestre). Salidas: `BCR_REMESAS_NOM_NSA_M.csv` (427
  obs, 1991-M01 a 2026-M07), `BCR_REMESAS_NOM_NSA_Q.csv` (142 obs),
  `BCR_REMESAS_REAL_NSA_M.csv` (200 obs, acotada por el arranque de
  `ONEC.IPC.BASE_2009` en dic-2009), `BCR_REMESAS_REAL_NSA_Q.csv` (66 obs).
  `tests/test-l3-predictores.R` ampliado con 7 `test_that` nuevos
  (`agregar_trimestral_suma()`, `deflactar_serie()`, borde inicial de
  `agregar_trimestral_promedio()`).
  **Tercer predictor materializado (2026-09-16, tercera sesión):
  `BCR.IPP.IDX.NSA.M/.Q`** (Índice de Precios al Productor, senda §6.4,
  precios). El `.xlsx` ya estaba en `data/L0_raw/` desde el lote de Fase 2
  (Bloque 3, `BCR_ipp_2026-08-26.xlsx`) — no requirió captura nueva, a
  diferencia de remesas/IPC. Mismo patrón estructural que
  `ONEC.IPC.IDX.NSA.M`: el índice arranca dic-2009=100 por construcción,
  con once celdas vacías (ene-nov 2009) antes de la primera observación
  real, así que `03_series.csv` usa `col_inicio="M"` y
  `src/transformacion/extraer_bcr_ipp.R` reutiliza el forward-fill
  extendido de `extraer_onec_ipc.R` (sin él, la celda de año en `M` queda
  `NA` porque el rótulo del año solo se escribe en enero). Es un índice de
  NIVEL, no un flujo (a diferencia de `BCR.REMESAS`): se agrega a
  trimestral por PROMEDIO (`agregar_trimestral_promedio()`, ya probada),
  no por suma, mismo criterio que `BCR.IVAE.VOL.SA.Q`
  (`T007_AGREGACION_TRIMESTRAL_IPP`). NSA de fuente, sin ajuste estacional
  propio (ADR-010, enmienda de la sesión anterior) y sin deflactar (ya es
  un índice de precios, no una serie monetaria nominal — la pregunta de
  deflactación de ADR-010 no aplica). Salidas: `BCR_IPP_IDX_NSA_M.csv` (200
  obs, 2009-M12 a 2026-M07) + `BCR_IPP_IDX_NSA_Q.csv` (66 obs, 2010-Q1 a
  2026-Q2; 2009-Q4 y 2026-Q3 excluidos por borde de cobertura, mismo patrón
  que `BCR.REMESAS.REAL.NSA.Q`). No se agregó ningún `test_that` nuevo: la
  única función pura que usa (`agregar_trimestral_promedio()`) ya estaba
  cubierta.
  **Cuarto predictor materializado (2026-09-16, cuarta sesión):
  `BCR.EXPORT_FOB.NOM.NSA.M/.Q`** (Exportaciones FOB, Balanza Comercial de
  Mercancías, senda §6.4, comercio exterior). El `.xlsx` ya estaba en
  `data/L0_raw/` desde el lote de Fase 2 (Bloque 3,
  `BCR_balanza_comercial_2026-08-26.xlsx`) — no requirió captura nueva. La
  publicación trae tres series de cabecera en la misma hoja (Exportaciones
  FOB fila 6, Importaciones CIF fila 16, Balanza Comercial/saldo fila 20) más
  subpartidas (café, azúcar, algodón, camarón, Centroamérica/fuera de
  Centroamérica, maquila); ADR-010 no se pronuncia sobre cuál admitir, así
  que se preguntó explícitamente (`AskUserQuestion`, mismo patrón que la
  pregunta de deflactación de remesas) en vez de asumir todas o solo la
  primera. **Decisión de Harold: solo Exportaciones** en esta pasada —
  Importaciones y el saldo quedan como candidatos futuros, no una omisión.
  Es una serie DISTINTA de `BCR.EXPORT.NOM.NSA.Q` (Cuentas
  Nacionales/SCN2008, bienes y servicios, trimestral, ya catalogada desde
  Fase 1): esta es solo mercancías, valoración FOB, mensual — de ahí el
  concepto `EXPORT_FOB` (no `EXPORT`) en el `serie_id`, para no colisionar.
  Es un FLUJO mensual (como REMESAS, no un índice como IVAE/IPP): se agrega
  a trimestral por SUMA (`T008_AGREGACION_TRIMESTRAL_EXPORT_FOB`). NSA de
  fuente, sin ajuste estacional propio (ADR-010, enmienda) y sin deflactar
  en esta pasada (solo nominal; a diferencia de remesas no se preguntó por
  una versión real). Salidas: `BCR_EXPORT_FOB_NOM_NSA_M.csv` (390 obs,
  1994-M01 a 2026-M06) + `BCR_EXPORT_FOB_NOM_NSA_Q.csv` (130 obs, 1994-Q1 a
  2026-Q2 — los únicos 130 trimestres son todos completos, la serie mensual
  arranca y termina exactamente en borde de trimestre, a diferencia de
  REMESAS/IPP). No se agregó ningún `test_that` nuevo: reutiliza
  `agregar_trimestral_suma()`, ya cubierta.
  **Quinto y sexto predictor materializados (2026-09-16, quinta sesión):
  `BCR.ITCER.IDX.NSA.M/.Q`** (tipo de cambio efectivo real, serie global) **y
  `BCR.IPM.IDX.NSA.M/.Q`** (índice de precios de importación, senda §6.4).
  Primera tanda admitida **sin `AskUserQuestion`** — instrucción explícita de
  Harold ("realiza el procedimiento para las restantes, ya no necesitas
  supervisión") de proceder de forma autónoma para el resto de la matriz.
  Ambos `.xlsx` ya estaban en `data/L0_raw/` desde el lote de Fase 2 (Bloque
  3). Ambas publicaciones traen tres series de cabecera cada una; se admitió
  solo una por publicación, con el mismo criterio ya usado en
  `BCR.BALANZA_COMERCIAL` (serie más agregada/directa) — para ITCER, la
  **global** (no bilateral EEUU ni Centroamérica); para
  `BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR`, **Importación** (no Exportación ni
  Términos de Intercambio), que la propia ficha de `01_publicaciones` ya
  señalaba como el candidato de la senda §1.3 — no una elección nueva. Ambos
  son índices de NIVEL (como IVAE/IPP): se agregan a trimestral por
  PROMEDIO (`T009_AGREGACION_TRIMESTRAL_ITCER`,
  `T010_AGREGACION_TRIMESTRAL_IPM`). Se crearon dos metodologías nuevas
  (`catalogos/02_metodologias/ITCER_BASE2014.yaml`, `IPCE_BASE2005.yaml`)
  con el año base confirmado empíricamente (promedio de los 12 meses del año
  base ≈ 100 en ambos casos), siguiendo el mismo patrón que
  `IVAE_CIIU_REV4`/`IPP_BASE2009`. **Hallazgo de paso, corregido:** una nota
  en la fila `BCR.REMESAS.NOM.NSA.M` afirmaba que IVAE/IPI/ISI/ITCER/SPNF
  comparten el sufijo de URL `serie-desestacionalizada`; verificado contra
  las 5 fichas, solo IVAE e IPI lo llevan — corregido in situ, no cambia
  ninguna clasificación NSA existente. Salidas: `BCR_ITCER_IDX_NSA_M.csv`
  (318 obs, 2000-M01 a 2026-M06) + `_Q.csv` (106 obs, 2000-Q1 a 2026-Q2, sin
  bordes incompletos) + `BCR_IPM_IDX_NSA_M.csv` (257 obs, 2005-M01 a
  2026-M05) + `_Q.csv` (85 obs, 2005-Q1 a 2026-Q1; 2026-Q2 excluido por
  borde, solo abril-mayo). No se agregó ningún `test_that` nuevo: ambos
  reutilizan `agregar_trimestral_promedio()`, ya cubierta.
  **Octavo predictor materializado (2026-09-23): `UT.DEMANDA_ELEC.GWH.NSA.M/.Q`**
  (demanda total de electricidad del Mercado Mayorista, senda §6.4, energía).
  Primera familia de la matriz que NO es del BCR, y la única cuya L0 se capturó
  a mano (25 archivos anuales, regla 9 de `CLAUDE.md`: `robots.txt` de
  `ut.com.sv` no permite scraping). No requirió captura nueva ni extractor
  nuevo: su L1 ya existía desde 2026-08-27 (`ut_demanda_serie.R`) y ya pasaba la
  batería L2 desde el 2026-09-22. Lo que faltaba era exactamente lo que esta
  sesión agregó: fila `T011` en `04_transformaciones` (SUMA, es un flujo en GWh),
  dos filas en `05_series_master` y la entrada en el mapa `FUENTE_L1` de
  `l3_predictores.R`. Salidas: `UT_DEMANDA_ELEC_GWH_NSA_M.csv` (295 obs,
  2002-M01 a 2026-M07) + `_Q.csv` (98 obs, 2002-Q1 a 2026-Q2; 2026-Q3 excluido
  por borde, solo julio). Sí requirió código nuevo para el `vintage_id`:
  `agregar_vintage_por_anio()` en `vintage_lib.R` (+5 `test_that` en
  `tests/test-vintage-lib.R`), porque es la única publicación de la matriz con
  más de un vintage (25) y el vintage "vigente" habría etiquetado las 288
  observaciones de 2002-2025 con el archivo de 2026.
  **Pendiente:** el resto de la matriz de predictores — Exportación/Términos de
  Intercambio de `BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR`, bilaterales de
  `BCR.ITCER`, Importaciones/Balanza de `BCR.BALANZA_COMERCIAL` (todas
  declinadas, no descartadas), empleo cotizante y recaudación (senda §6.4)
  siguen sin extractor ni transformación; turismo está excluido por
  disponibilidad, no pendiente.
- [x] **Análisis exploratorio y de estacionariedad.** (2026-09-17) Ambas
  mitades completas. "Exploratorio": `src/analisis/exploracion_series.R` +
  `exploracion_series_reglas.R` leen las 18 series de `data/L3_master/`
  (target + matriz de predictores completa a la fecha; eran 16 hasta la enmienda
  de E1/D3 del 2026-09-23, que admite UT) y calculan cobertura,
  huecos internos (distintos de un simple borde de arranque/cierre tardío) y
  momentos muestrales de nivel y primera diferencia. Salidas: `data/L3_master/
  reporte_exploratorio_resumen.csv` (una fila por serie) y
  `data/L3_master/exploracion/<serie>.png` (nivel + primera diferencia) —
  capa generada, no versionada, mismo criterio que el resto de `L3_master`.
  Corrida real (2026-09-17, reejecutada 2026-09-23): 18/18 series sin huecos
  internos — consistente
  con que los extractores ya fallan de forma visible ante huecos reales
  (regla 7 de `CLAUDE.md`), así que este resultado confirma, no descubre.
  `tests/test-exploracion-series.R` (4 aserciones, datos sintéticos,
  incluye borde de año en mensual y un hueco interno real inyectado).
  **Mitad "estacionariedad" resuelta y materializada (2026-09-17, decisión
  de Harold vía `AskUserQuestion`):** estrategia ADF + KPSS confirmatorio
  (Kwiatkowski et al. 1992 — estacionaria solo si ambas coinciden en ese
  sentido, no_estacionaria solo si coinciden en el contrario, ambigua si
  discrepan), selección de rezagos BIC/SIC para ADF, sobre 4 transformaciones
  por serie (nivel, log-nivel, diferencia, diferencia del log). **Corrección
  de precisión (2026-09-17, encontrada al redactar el reporte narrativo):**
  ADR-001 NO deja abierta la unidad de modelación en general — ya fijó
  "logaritmo del nivel" como raíz para la variable objetivo específicamente
  (título del ADR: "variable objetivo"). Lo que sigue genuinamente abierto es
  la unidad de modelación para las PREDICTORAS: ADR-010 (transformaciones L3
  de predictores) no menciona logaritmo ni unidad de modelación en ningún
  punto — cubre desagregación, deflactación y outliers, no esto. El alcance
  de 4 transformaciones sigue siendo el correcto (da evidencia para esa
  decisión pendiente de predictoras, y es *compatible* con la ya tomada para
  el objetivo, sin validarla — corregido 2026-09-22, H2 del checklist de
  cierre de Fase 3: "valida empíricamente" es exactamente la afirmación que
  el hallazgo C1 retiró del reporte narrativo el 2026-09-19, ver ese reporte
  §"La variable objetivo"), pero el motivo que
  documentaba el código y el resumen de decisión #`AskUserQuestion` original
  lo describía de forma imprecisa. Implementado en `src/analisis/
  estacionariedad_reglas.R` + `estacionariedad.R`
  (`tests/test-estacionariedad.R`, 19 aserciones con ruido blanco y paseo
  aleatorio como casos de libro de texto). Requirió una dependencia nueva
  (`urca`, único paquete de los dos evaluados que soporta `selectlags="BIC"`
  en `ur.df()`) — no cerré esto por mi cuenta: es sobre el stack cerrado de
  ADR-009, así que se resolvió con una nota de seguimiento en ese ADR (mismo
  mecanismo ya usado para `httr2`/`xml2`/`chromote`), no con inferencia ni
  con un ADR nuevo. `urca` ya estaba en `renv.lock` como transitiva de
  `vars`/`tsDyn` — el conteo de 187 paquetes no cambió, solo el de imports
  declarados (20→21, `DESCRIPTION`/`CLAUDE.md` actualizados).
  **Dos aproximaciones declaradas, no correspondencias exactas** (documentadas
  en el código): el techo de búsqueda de rezagos de ADF usa la regla de
  Schwert (`urca::ur.df(lags=...)` por defecto casi no busca nada); KPSS no
  tiene un análogo exacto de BIC, se usó `lags="short"` como la opción más
  parsimoniosa disponible. Especificación determinística (trend para
  nivel/log-nivel, drift para las diferencias) fijada por convención
  económica estándar, no preguntada por separado. Salida real (18 series x
  hasta 4 transformaciones = 72 filas): `data/L3_master/
  reporte_estacionariedad.csv`. **Regenerado dos veces el 2026-09-19**: primero
  tras la remediación de la revisión independiente (31 "estacionaria", 22
  "no_estacionaria", 11 "ambigua" desdoblada en dos etiquetas, y `adf_rezagos`
  pasa a ser la selección BIC efectiva con el techo de Schwert en
  `adf_techo_rezagos`); después al corregir la grilla de selección de rezagos
  (hallazgo C2: `ur.df(selectlags="BIC")` nunca evalúa 0 rezagos), que deja la
  salida de esa fecha en **33 "estacionaria", 21 "no_estacionaria" y 10
  `ambigua_ambas_rechazan`**, ninguna `ambigua_ninguna_rechaza`. **Regenerado por
  quinta vez el 2026-09-23** al admitir UT a la matriz (enmienda de E1/D3): 18
  series y 72 filas, **37 "estacionaria", 23 "no_estacionaria" y 12
  `ambigua_ambas_rechazan`**, y las 64 filas anteriores quedan idénticas bit a
  bit —mismo estadístico, mismos rezagos, mismo veredicto—, así que la diferencia
  en los agregados son exactamente las 8 filas nuevas de UT (4 "estacionaria",
  2 "no_estacionaria", 2 `ambigua_ambas_rechazan`). Las dos
  etiquetas ambiguas se renombraron (hallazgo I1) para que nombren la celda de
  la tabla 2×2 y no una causa; el CSV publica además los valores críticos al
  1/5/10%, `adf_tipo`/`kpss_tipo` y `adf_ljung_box_p`. Patrón econométricamente
  coherente con series macro trending, no una sorpresa.
- [x] **Construcción de la matriz de predictores.** **Cerrada 2026-09-23** con
  la enmienda del alcance E1/D3 (decisión de Harold): la matriz son 8 familias
  —las 7 del BCR más `UT.DEMANDA_ELEC`—, 18 archivos en `data/L3_master/`
  contando la variable objetivo. Esta casilla había quedado en `[~]` el
  2026-09-22 mientras su propio entregable ("Matriz de predictores mensuales y
  trimestrales", abajo) se marcaba `[x]` con la misma decisión: el mismo objeto
  con dos marcas distintas. Se resuelve acá, no se reinterpreta.
  Iniciada 2026-09-16 con
  `BCR.IVAE.VOL.SA.M/.Q`, extendida el mismo día con
  `BCR.REMESAS.NOM/REAL.NSA.M/.Q`, luego con `BCR.IPP.IDX.NSA.M/.Q`, luego
  con `BCR.EXPORT_FOB.NOM.NSA.M/.Q` y luego con `BCR.ITCER.IDX.NSA.M/.Q` +
  `BCR.IPM.IDX.NSA.M/.Q` (ver arriba) — con esto se agotan los candidatos de
  la senda §6.4 que no requieren una compuerta ADR-008 nueva (todas
  publicaciones de BCR, misma institución ya cubierta por PIB/IVAE). Camino
  para el siguiente predictor, si se retoma: (1) capturar L0 en vivo si no
  existe aún (`src/adquisicion/bcr.R`, patrón
  `descargar_bcr_*`/`descargar_onec_*`) o abrir compuerta ADR-008 si es
  institución nueva; (2) estructurar `fuente_celda` en `03_series.csv` con
  verificación real de `verificar_fuente_celda.R` + entrada en
  `doc/bitacora_verificaciones.md` (regla 8); (3) extractor L0→L1 dedicado;
  (4) transformación L3 según ADR-010; (5) filas en
  `04_transformaciones`/`05_series_master`. Lo que queda disponible, no
  descartado:
  - **Sub-series de publicaciones ya admitidas**, reutilizando el mismo
    archivo L0 y el mismo extractor con otra fila en vez de la ya admitida:
    Importaciones (CIF, fila 16) y Balanza Comercial/saldo (fila 20) de
    `BCR.BALANZA_COMERCIAL` (Importaciones/Balanza fueron una elección
    explícita de Harold vía `AskUserQuestion`, no una omisión de tiempo —
    retomarlas requiere la misma pregunta, no una inferencia); Índice de
    Precios de Exportación y de Términos de Intercambio de
    `BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR`; bilateral con EEUU y con
    Centroamérica de `BCR.ITCER`.
  - **Instituciones genuinamente nuevas** (empleo cotizante, turismo,
    recaudación, senda §6.4): ninguna identificada con publicación/fuente
    concreta todavía — cada una dispararía su propia compuerta *just-in-time*
    de ADR-008 antes de admitirse, igual que UT. **Corregido 2026-09-23:**
    esta lista incluía "energía", que era falso desde el 2026-08-27 — la
    fuente estaba identificada (Unidad de Transacciones), capturada (25
    archivos anuales), catalogada (`UT.DEMANDA_ELEC.GWH.NSA.M`) y con su
    compuerta ADR-008 abierta y cerrada; ver
    `doc/relevamiento_predictores_energia_turismo.md`. Desde esa misma fecha
    alimenta L3 (T011). Turismo tampoco pertenece del todo a esta lista: está
    **excluido por disponibilidad** (única entrega anual, con casi dos años de
    rezago), no pendiente de relevamiento.
  `BCR.IPRI.BASE_1990` queda descartada como candidato (no solo declinada):
  serie cerrada (oct-2017), predecesora de IPP, sin tabla de concordancia
  verificada (09_rupturas.csv R010) — admitirla exigiría resolver el
  empalme, no solo catalogarla. `ONEC.IPC.IDX.NSA.M` (índice general de
  precios al consumidor) también ya tiene extractor y fila en
  `03_series.csv` — entró como deflactor de remesas, no como predictor
  propio; no tiene fila en `05_series_master` todavía (podría promoverse a
  predictor de inflación en una sesión futura, decisión no tomada).
- [x] **Hallazgo de esta sesión, corregido: `extraer_bcr_pib.R` y
  `validar_l2_pib.R` filtraban `03_series.csv` con una lista de EXCLUSIÓN**
  (`publicacion_id != "UT.DEMANDA_TOTAL_MENSUAL"`) en vez de inclusión — al
  agregar la fila de `BCR.IVAE.VIGENTE`, ambos scripts intentaban procesarla
  como si fuera PIB (parsear "Ene"/"Feb" como trimestre romano) y rompían la
  cadena de `make master`. Corregido a lista de inclusión (las 4
  publicaciones de PIB, explícitas) en ambos scripts — un predictor nuevo ya
  no puede volver a romper esto en silencio.
- [x] **Hallazgo de esta sesión, corregido: `verificar_fuente_celda.R` daba
  falsos FAIL en las 13 filas `*.RETRO`** (bug propio del verificador, no de
  los datos — ver `doc/bitacora_verificaciones.md`, entrada 2026-09-16, y
  detalle en el propio script). Corregido: ahora lee la fila vía `readxl`
  (misma convención que el extractor real) en vez de contra el atributo `@r`
  del XML crudo.

## Entregables (senda §4)

- [x] Catálogo `03_series` poblado — 106 filas (98 PIB + 1 UT + 1
  `BCR.IVAE.VOL.SA.M` + 1 `BCR.REMESAS.NOM.NSA.M` + 1 `ONEC.IPC.IDX.NSA.M` +
  1 `BCR.IPP.IDX.NSA.M` + 1 `BCR.EXPORT_FOB.NOM.NSA.M` + 1
  `BCR.ITCER.IDX.NSA.M` + 1 `BCR.IPM.IDX.NSA.M`, las siete últimas altas de
  2026-09-16, verificadas 105 PASS / 0 FAIL / 1 FUERA_DE_ALCANCE). **Cerrado
  (2026-09-22, E1/D3 y E2 del checklist de cierre de Fase 3; E1/D3 enmendado el
  2026-09-23):** la matriz de predictores cierra Fase 3 con 8 familias — estas 7
  del BCR más `UT.DEMANDA_ELEC.GWH.NSA.M`, que ya tenía fila en `03_series.csv`
  desde 2026-08-27 y pasa a alimentar L3. El conteo de 106 filas no cambia: la
  fila de UT ya estaba. El resto (sub-series declinadas de Balanza Comercial,
  instituciones nuevas para empleo/turismo/recaudación) se admite en fase
  posterior, decisión de Harold. El
  mapeo 29-vs-28 de variables de volumen de PIB quedó reconciliado: la
  diferencia es exactamente `FBK` (Formación Bruta de Capital total, incluye
  variación de existencias), publicada solo en NOMINAL — el portal no publica
  índice de volumen encadenado de esa línea (`doc/bitacora_fuentes_fragiles.md`).
- [x] Catálogo `04_transformaciones` poblado — **11 filas (T001–T011)**, todas
  con `script_path`/`funcion` reales. Cierra con estas 11 (mismo alcance de
  matriz que arriba): las 10 del cierre del 2026-09-22 más
  `T011_AGREGACION_TRIMESTRAL_UT_DEMANDA`, alta del 2026-09-23 con la enmienda
  de E1/D3 — agregación por SUMA, porque la demanda eléctrica es un flujo
  (GWh del mes), mismo criterio que T005/T008 y no el promedio de
  T003/T007/T009/T010. El resto de predictores queda diferido, no pendiente de
  esta fase.
- [x] Catálogo `05_series_master` poblado — **19 filas** (17 al cierre del
  2026-09-22 más `UT.DEMANDA_ELEC.GWH.NSA.M/.Q` del 2026-09-23): (`PIB.NSA.CONCAT.Q`
  intermedio + `PIB.SA.PROPIO.Q`, `PIB.SA.OFICIAL.Q`, `BCR.IVAE.VOL.SA.M/.Q`,
  `BCR.REMESAS.NOM.NSA.M/.Q`, `BCR.REMESAS.REAL.NSA.M/.Q`,
  `BCR.IPP.IDX.NSA.M/.Q`, `BCR.EXPORT_FOB.NOM.NSA.M/.Q`,
  `BCR.ITCER.IDX.NSA.M/.Q`, `BCR.IPM.IDX.NSA.M/.Q`,
  `UT.DEMANDA_ELEC.GWH.NSA.M/.Q`), **18 materializadas + 1 intermedia** (la
  intermedia nunca se escribe a disco, ver su fila). Cerrado bajo el mismo
  alcance de matriz.
- [x] Base maestra bitemporal — `data/L3_master/` tiene la variable objetivo
  (`PIB_SA_PROPIO_Q.csv`, `PIB_SA_PROPIO_Q_outliers.csv`,
  `PIB_SA_OFICIAL_Q.csv`) y ocho familias de predictores
  (`BCR_IVAE_VOL_SA_M/_Q.csv`, `BCR_REMESAS_NOM_NSA_M/_Q.csv`,
  `BCR_REMESAS_REAL_NSA_M/_Q.csv`, `BCR_IPP_IDX_NSA_M/_Q.csv`,
  `BCR_EXPORT_FOB_NOM_NSA_M/_Q.csv`, `BCR_ITCER_IDX_NSA_M/_Q.csv`,
  `BCR_IPM_IDX_NSA_M/_Q.csv`, `UT_DEMANDA_ELEC_GWH_NSA_M/_Q.csv`) — el alcance
  completo de la matriz que cierra Fase 3 (E1, enmendado 2026-09-23). Para UT la
  columna `vintage_id` NO es constante: se resuelve por año de referencia contra
  sus 25 vintages anuales (`agregar_vintage_por_anio()` en `vintage_lib.R`),
  porque el vintage "vigente" habría etiquetado las 288 observaciones de
  2002-2025 con el archivo de 2026. **"Bitemporal" resuelto
  (2026-09-22, E3/D4):** cada archivo gana una columna `vintage_id`, resuelta
  contra `08_vintages.csv` vía `src/transformacion/vintage_lib.R` — no una
  lectura documental separada. Ver la nota de cierre de Fase 3 en
  `doc/senda_metodologica.md` para la lectura completa. L4 sigue vacío salvo
  `.gitkeep` (Fase 4).
- [x] **Reporte de calidad de datos** (2026-09-16) — `pointblank::export_report()`
  sobre el agente de `validar_l2()`, escrito a `data/L2_validated/reporte_calidad_l2_pib.html`
  (HTML autocontenido) en cada corrida de `src/validacion/validar_l2_pib.R`, tanto
  si pasa como si falla. Capa generada, no versionada. Cubre solo BCR PIB — si
  se extiende el extractor a otras publicaciones (ver decisión 3 abajo), este
  reporte se extiende con ellas.
- [x] Reporte exploratorio. Resumen tabular y gráfico (mitad "exploratorio"),
  prueba formal de estacionariedad (mitad "estacionariedad") y documento
  narrativo que interpreta ambos:
  `doc/metodologia/reporte_exploratorio_fase3.md` (2026-09-17). Corrige, de
  paso, una imprecisión propia sobre el alcance de ADR-001 (ver nota arriba).
  **Corregido (2026-09-22, H2 del checklist de cierre de Fase 3):** la frase
  "valida empíricamente esa decisión para el objetivo" que estaba acá
  contradecía al propio reporte, que el hallazgo C1 (2026-09-19) corrigió
  para decir exactamente lo contrario — la evidencia es *compatible* con
  ADR-001, no lo valida (son afirmaciones distintas, ver reporte §"La
  variable objetivo", punto de apertura). Retirada; la unidad de modelación
  de las predictoras sigue explícitamente abierta (regla 4 de `CLAUDE.md`).
- [x] Matriz de predictores mensuales y trimestrales con cobertura documentada
  — **8 familias** de la senda §6.4 (`BCR.IVAE`, `BCR.REMESAS` nominal y
  real, `BCR.IPP`, `BCR.EXPORT_FOB`, `BCR.ITCER`, `BCR.IPM`, `UT.DEMANDA_ELEC`,
  mensual y trimestral). **Cerrado (2026-09-22, E1/D3) y enmendado (2026-09-23):**
  el cierre original fijaba 7 familias, todas del BCR, y dejaba la demanda
  eléctrica fuera de la matriz; Harold enmendó el alcance para incluirla, porque
  el relevamiento de 2026-08-27 ya había declarado que energía entra al conjunto
  de predictores y el dato estaba listo hasta L2. Con eso la matriz cubre **cinco
  de las siete categorías** que nombra la senda §6.4 —IVAE, remesas, comercio
  exterior, precios y energía—, más `BCR.ITCER` (tipo de cambio efectivo real),
  que la senda no lista entre esas siete. Faltan **empleo cotizante** (las
  publicaciones del ISSS están catalogadas en `01_publicaciones` pero ninguna
  serie admitida en `03_series.csv`) y **recaudación**, que se admiten en una
  fase posterior, no como continuación mecánica del mismo procedimiento;
  **turismo** está excluido por disponibilidad (única entrega anual con casi dos
  años de rezago, ver el relevamiento). Ojo con el conteo del relevamiento, que
  decía "seis de las siete": contaba empleo cotizante como cubierto por tener
  publicación catalogada, que no es lo mismo que tener serie en la matriz.

## Guards de CI a subsumir

- [x] `tests/test-integridad-referencial.R` — explícitamente marcado como
  "adelanto de Fase 3, reemplazable por pointblank sin deuda" (CLAUDE.md,
  `doc/adr/README.md`). **Subsumido parcialmente 2026-09-17** (decisión de
  Harold, sobre el diagnóstico de la decisión #4 abajo): las 6 aristas
  tabulares migraron a `src/validacion/validar_integridad_catalogos.R` +
  `integridad_catalogos_reglas.R` (pointblank, `make validate`, falla visible
  por regla 7). El test se recortó a la única arista que no es tabular
  (`01_publicaciones/*.yaml` contra `00_instituciones`/`02_metodologias`,
  no calza con `create_agent(tbl=...)`, mismo motivo que dejó huecos/
  identidad de L2 en R base). Suite completa 344/344 tras el recorte (antes
  672 — la diferencia es la cuenta de aserciones por fila que ahora vive
  dentro del agente pointblank, no un hallazgo).

## Prerrequisitos ya satisfechos

- [x] ADRs: 9/10 cerrados (001–007, 009–010). Solo ADR-008 parcial (licencias),
  con cortes fechados BCR 2026-10-12 y CEPAL 2026-10-16 — no bloquea el
  trabajo de Fase 3 ya en curso (compuerta *just-in-time* por publicación
  admitida, no global; ver nota de cierre de Fase 1).
- [x] Catálogos base completos (`00`–`09` + `datapackage.json`).
- [x] Dependencias declaradas: `pointblank`, `duckdb`, `seasonal`,
  `tempdisagg` en `DESCRIPTION` y `renv.lock` (ADR-009 cerrado).
- [x] `make master` encadena `validate` → extractores L0→L1 (PIB, UT, IVAE,
  REMESAS, IPC, IPP, EXPORT_FOB, ITCER, IPM) → validación L2 →
  `l3_pib_objetivo.R` (variable objetivo) → `l3_predictores.R` (matriz de
  predictores).

## Decisiones metodológicas pendientes — NO asumir, preguntar

Conforme a la regla 4 de CLAUDE.md, estas quedan marcadas como bloqueo de
inferencia, no como tarea a resolver de una vez:

1. ~~¿Se migra `l2_pib_reglas.R`/`validar_l2_pib.R` a `pointblank`?~~
   **Resuelto 2026-09-16** (decisión de Harold: proceder con la migración
   parcial que se recomendó — ver detalle en "Batería de validaciones" arriba).
   No cerró un ADR nuevo porque no fija una decisión metodológica sobre los
   datos, sino una decisión de implementación de la validación misma.
2. ~~Método de ajuste estacional y deflactación para L3~~ **Resuelto
   2026-09-16** (decisión de Harold, ver ADR-010): desagregación temporal vía
   `tempdisagg` (Chow-Lin con indicador cuando exista, Denton-Cholette si no);
   deflactación caso por caso, declarada por serie en `04_transformaciones`;
   sin tratamiento de outlier propio en L3 para predictoras (se decide por
   modelo en Fase 5). No afecta el tratamiento de la variable objetivo
   primaria, que sigue rigiéndose por ADR-001/ADR-004.
3. ~~Extensión del extractor L0→L1 más allá de BCR PIB~~ **Parcialmente
   resuelto 2026-09-16:** `BCR.IVAE.VOL.SA.M` admitida con extractor propio
   (`extraer_bcr_ivae.R`) — no disparó compuerta nueva de ADR-008 porque es
   la misma institución (BCR) ya cubierta por el default conservador
   aplicado a PIB. El tramo UT (institución nueva) sí requería compuerta
   propia — abierta y cerrada en la misma sesión (ADR-008, enmienda "UT",
   default conservador, mismo patrón que MH/ONEC/SECMCA). Sigue en pie para
   *instituciones* genuinamente nuevas (ninguna serie de otra fuente ha
   entrado todavía): cada una dispara su propia compuerta *just-in-time* de
   ADR-008 antes de admitirse en `03_series.csv`.
4. ~~Reemplazo o coexistencia de `tests/test-integridad-referencial.R` con
   los checks pointblank de Fase 3~~ **Resuelto 2026-09-17** (decisión de
   Harold, sobre el diagnóstico de abajo: "hacelo"). Se construyó el
   validador de FK entre catálogos que el diagnóstico identificó como
   faltante — `src/validacion/validar_integridad_catalogos.R` +
   `integridad_catalogos_reglas.R`, pointblank, corre en `make validate` —
   y se recortó el test a la única arista no tabular. Detalle en "Guards de
   CI a subsumir" arriba. Cada arista de valor único resultó ser el caso de
   uso nativo de `col_vals_in_set()` (mejor encaje que L2, que sí necesitó
   `specially()` para todo); solo las dos aristas multi-valor
   (`series_insumo_ids`, `series_afectadas`) necesitaron precómputo en R
   base, mismo patrón que huecos/identidad de L2.
   **Diagnóstico original (2026-09-17, informó la decisión):**
   verificado contra el código real, no por analogía. `test-integridad-
   referencial.R` cubre 7 aristas FK entre catálogos (`03→01`, `03→02`,
   `08→01`, `05→04`, `05→03`, `09→03`/`01` según `tipo_referencia`,
   `01→00`/`02` vía YAML). Ninguna pointblank existente las cubre hoy:
   `src/validacion/validate_catalogs.R` (el único validador de catálogos
   contra `datapackage.json`, invocado por `make validate`) sólo implementa
   `required`/`unique`/`enum` — pese a importar `pointblank`, no usa
   `ptblank_agent` ni ningún `col_vals_*`, son bucles en R base. La batería
   L2 de `validar_l2_pib.R` (la que sí migró a pointblank, 2026-09-16) valida
   otra cosa: filas de `L1` contra `03_series`, no integridad entre
   catálogos. **Hallazgo adicional de paso:** `datapackage.json` sí declara
   `"foreignKeys"` para `03_series` (`publicacion_id`→`01_publicaciones`,
   `metodologia_id`→`02_metodologias`) — pero `validate_catalogs.R` ignora
   ese campo del esquema por completo, y ningún otro recurso del
   `datapackage.json` declara `foreignKeys` (ni `04`, `05`, `08`, `09`,
   pese a que el test sí verifica esas aristas). Es decir: el esquema
   declarado ya está incompleto respecto a lo que el test cubre, y lo poco
   que declara no se aplica. **Conclusión del diagnóstico:** hoy no hay nada
   que subsumir — la pregunta real no es "¿reemplazo o coexistencia?" sino
   si construir primero el validador de FK entre catálogos (extender
   `validate_catalogs.R` + completar `foreignKeys` en `datapackage.json`
   para los 5 recursos que faltan) antes de poder decidir si el test se
   vuelve redundante. No tomé esa decisión — es la misma clase de elección
   de alcance de validación que ya se marcó como pendiente.
5. ~~¿Se deflacta `BCR.REMESAS_FAMILIARES_MENSUAL` (nominal, USD corrientes)
   a términos reales?~~ **Resuelto 2026-09-16** (decisión de Harold, primera
   aplicación concreta del principio "caso por caso" de ADR-010): ambas —
   nominal como serie base (pass-through) y real como derivada
   (`T004_DEFLACTAR_REMESAS`, deflactada por `ONEC.IPC.IDX.NSA.M`). Sienta
   precedente operativo, no metodológico nuevo: ADR-010 ya cubría la
   decisión general: cada predictor nominal que se admita de acá en
   adelante requiere la misma pregunta explícita (deflactar, no deflactar, o
   ambas), no se infiere del tipo de serie.
6. ~~¿Se ajusta estacionalmente `BCR.REMESAS` en L3?~~ **Resuelto 2026-09-16**
   (decisión de Harold, en respuesta a una pregunta del propio Harold, no de
   Claude Code — hallazgo de omisión: ADR-010 nunca cubrió ajuste estacional
   para predictoras, solo desagregación/deflactación/outliers; la omisión no
   se notó con IVAE porque esa serie ya viene SA de fuente). Sin ajuste
   estacional propio en L3 para predictoras — mismo razonamiento que ya
   regía outliers, extendido a estacionalidad. Ver ADR-010, enmienda
   "ajuste estacional en series predictoras". Corregido antes de que el
   mismo hueco se repitiera con la siguiente predictora NSA.
7. **`BCR.IPP` (tercer predictor, 2026-09-16) no disparó ninguna pregunta
   nueva** — se verificó explícitamente contra las decisiones 2, 5 y 6 antes
   de admitirlo, en vez de asumir por analogía con IVAE/REMESAS: (a)
   agregación por promedio, no suma — es un índice de nivel, mismo criterio
   ya fijado para IVAE; (b) sin deflactar — la pregunta "caso por caso" de la
   decisión 5 aplica a series monetarias nominales (dólares), no a un índice
   de precios, que no es una magnitud que se exprese en términos reales; (c)
   sin ajuste estacional propio pese a ser NSA — ya cubierto en general por
   la decisión 6, no específico de remesas. No es una decisión nueva; se dejó
   constancia de que se revisó, no que se infirió.
8. ~~¿Qué serie(s) de `BCR.BALANZA_COMERCIAL` se admiten como predictor?~~
   **Resuelto 2026-09-16** (decisión de Harold, `AskUserQuestion`): la
   publicación trae tres series de cabecera (Exportaciones FOB, Importaciones
   CIF, Balanza Comercial/saldo) y ADR-010 no se pronuncia sobre cuál(es)
   catalogar como predictor — es la misma clase de decisión de "definición de
   variable nueva" que la regla 4 de `CLAUDE.md` exige preguntar, no una
   pregunta de transformación como las anteriores. **Solo Exportaciones
   (FOB)** en esta pasada; Importaciones y Balanza quedan disponibles en el
   mismo archivo L0, declinadas por ahora, no descartadas. No se preguntó
   además por una versión real (deflactada) de exportaciones, a diferencia
   de remesas — queda abierto si se retoma esta serie en una sesión futura.
9. **Autorización de Harold para proceder sin supervisión turno a turno**
   ("realiza el procedimiento para las restantes, ya no necesitas
   supervisión", 2026-09-16) — cubre el resto de la tanda de predictores de
   esta sesión (`BCR.ITCER`, `BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR`), no
   una autorización general permanente para futuras decisiones
   metodológicas. Bajo esa instrucción, la elección de cuál serie de
   cabecera admitir de cada publicación multi-serie (decisión de la misma
   clase que la 8) se resolvió por criterio propio en vez de
   `AskUserQuestion` — global para ITCER, Importación para
   `INDICES_PRECIOS_COMERCIO_EXTERIOR` (esta última ya señalada por el
   propio catálogo, no una elección nueva) — siguiendo el mismo patrón ya
   validado por Harold en la decisión 8 (serie más agregada/directa,
   resto declinado no descartado). Documentado con el mismo nivel de
   detalle que si se hubiera preguntado, para que sea revisable. No se
   extendió el alcance a instituciones nuevas (empleo/energía/turismo/
   recaudación) ni a las sub-series que la decisión 8 ya había declinado
   explícitamente — eso excede "las restantes" tal como se entendió esta
   instrucción.
10. **`UT.DEMANDA_ELEC` (octavo predictor, 2026-09-23) no disparó ninguna
   pregunta metodológica nueva** — se verificó explícitamente contra las
   decisiones 2, 5 y 6 antes de admitirlo, mismo patrón que la decisión 7 para
   `BCR.IPP`: (a) agregación por SUMA, no promedio — es un flujo (GWh
   demandados durante el mes), mismo criterio ya fijado para REMESAS y
   EXPORT_FOB; (b) sin deflactar — la pregunta "caso por caso" de la decisión 5
   aplica a series monetarias nominales, y ésta es una magnitud física; (c) sin
   ajuste estacional propio pese a ser NSA — ya cubierto en general por la
   decisión 6. Lo que sí fue una decisión de Harold es el ALCANCE de la matriz
   (E1/D3), no el tratamiento de la serie: ver la enmienda en la cabecera.
   Queda constancia de que se revisó, no que se infirió.
