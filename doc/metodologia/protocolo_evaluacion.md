# Protocolo de evaluación predictiva

**Estado:** vigente. Decisiones de diseño cerradas por Harold el 2026-09-24 (registro en
`doc/metodologia/decisiones_fase4.md`). Reemplaza la versión anterior de este archivo, que
resumía ADR-002 y dejaba dos pendientes; ambos quedan cubiertos acá (§2.6 y §6). Las notas de
ADR que este documento cita como registro de cada decisión entran por un PR separado.
**Fecha:** 2026-09-24
**Alcance:** Ejercicio A de la senda metodológica §1.3 — evaluación incondicional
retrospectiva del PIB trimestral. El Ejercicio B (proyección condicional 2026-2030) se
gobierna por Fase 6 y no está cubierto acá.
**Decisiones vinculantes que este documento implementa, no reabre:** ADR-001 (variable
objetivo y unidad de modelación), ADR-002 (horizontes, ventana y número de
reestimaciones), ADR-003 (N y variante de robustez del tramo homogéneo), ADR-004 (shock de
2020), ADR-009 (stack), ADR-010 (transformaciones L3 de predictores).

Cada afirmación va marcada:

- **[decidido]** — resuelto por Harold el 2026-09-24; el texto operativo y el registro están en `doc/metodologia/decisiones_fase4.md`, §Acta.
- **[verificado]** — comprobado contra los archivos del repositorio el 2026-09-24; la cifra está en `doc/metodologia/reportes_fase4/evidencia_insumos_fase4.csv`, que regenera
  `scripts/evidencia_insumos_fase4.R`.
- **[heredado]** — fijado por un ADR cerrado; se transcribe, no se decide acá.
- **[propuesto]** — ya no quedan marcas de este tipo: todas las decisiones de diseño pasaron a
  **[decidido]** el 2026-09-24.

---

## 1. Objeto de la evaluación

**Variable objetivo [heredado, ADR-001 enmendado].** `PIB_SA_PROPIO_Q` — PIB real
trimestral, índice de volumen encadenado, desestacionalizado con X-13ARIMA-SEATS propio
sobre la concatenación de la serie retropolada oficial (1990-T1 a 2005-T4) y la
compilación nativa NSA (2005-T1 a 2026-T1). **[verificado]** 145 observaciones, 1990-Q1 a
2026-Q1, sin huecos ni valores ausentes, con dos `vintage_id`
(`BCR.PIB_T.SERIE_RETROPOLADA_1990_2005.v2019-03` y
`BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA.v2026-06`).

`PIB_SA_OFICIAL_Q` **[verificado]** 85 observaciones, 2005-Q1 a 2026-Q1, es serie de
robustez, no objetivo primario (ADR-001, cierre de la enmienda del 2026-08-07).

**Unidad de estimación [heredado, ADR-001].** Logaritmo del nivel como representación raíz
del linaje de transformaciones. Cada familia de modelo deriva de ahí la transformación que
requiera; no se abren cadenas de cálculo paralelas.

**Unidad de la pérdida [decidido 2026-09-24, F4-04].** La métrica primaria se computa sobre la tasa
de variación interanual en puntos porcentuales, `100·(log Y_t − log Y_{t−4})`, conforme a
ADR-001 ("métrica de evaluación y reporte: tasa de variación interanual"). Consecuencia que
debe declararse y que el motor debe hacer explícita: para h ≤ 4 la base interanual
`Y_{o+h−4}` es un valor **observado** en el origen, así que el error interanual a esos
horizontes hereda el error del nivel pronosticado y nada más; para h = 8 la base es ella
misma un pronóstico del propio modelo, y el error interanual combina dos errores del mismo
sendero. Las métricas secundarias se computan sobre `Δlog` trimestral y sobre el log-nivel,
en la misma corrida, para que la comparación no dependa de una sola representación.

---

## 2. Esquema de validación

### 2.1 Convención de indexación del origen [decidido 2026-09-24, F4-01]

ADR-002 publica tres cifras que solo son mutuamente consistentes bajo una convención
explícita, y hoy el documento no la declara. **[verificado]** Con la serie objetivo real
(145 obs, fin 2026-Q1), los conteos 52 / 51 / 49 / 45 que ADR-002 declara para
h = 1, 2, 4, 8 se reproducen exactamente bajo dos lecturas distintas:

| Convención | Origen | Orígenes | Último target | h=1 | h=2 | h=4 | h=8 | Muestra de estimación en el primer origen |
|---|---|---|---|---|---|---|---|---|
| **A** | último período estimado, de 2013-Q1 a 2025-Q4 | 52 | 2026-Q1 | 52 | 51 | 49 | 45 | 1990-Q1 a 2013-Q1 = **93** obs |
| **B** | último período estimado, de 2012-Q4 a 2025-Q3 | 52 | 2025-Q4 | 52 | 51 | 49 | 45 | 1990-Q1 a 2012-Q4 = **92** obs |
| A con target ≤ 2025-Q4 | — | 51 | 2025-Q4 | 51 | 50 | 48 | 44 | 93 obs |
| B con target ≤ 2026-Q1 | — | 53 | 2026-Q1 | 53 | 52 | 50 | 46 | 92 obs |

La convención **A** coincide literalmente con "un origen por trimestre, 2013-T1 a 2025-T4"
y con los cuatro conteos, pero su primera muestra de estimación tiene 93 observaciones, no
las 92 que ADR-002 declara. La convención **B** coincide con "ventana de estimación
inicial: 1990-T1 a 2012-T4 (92 observaciones)" y con los conteos, pero su último origen es
2025-Q3 y descarta 2026-Q1 como período evaluado.

**Decidido (2026-09-24): A.** Adoptada la convención **A** y corregir en ADR-002 la sola frase de la ventana inicial
(1990-T1 a 2013-T1, 93 observaciones), porque A preserva las dos cifras que el proyecto ya
publicó como diseño —la lista de orígenes y los cuatro conteos— y usa toda la muestra
disponible. La definición operativa queda:

> **Origen `o`** es el último trimestre con dato observado del objetivo que entra a la
> muestra de estimación. El pronóstico a horizonte `h` emitido en el origen `o` se compara
> contra el período `o + h`. Los orígenes van de 2013-Q1 a 2025-Q4 (52) y un par
> `(o, h)` se evalúa solo si `o + h` está observado.

### 2.2 Ventana, reestimación y horizontes [heredado, ADR-002]

- Ventana expansiva como diseño principal: la muestra de estimación es `[1990-Q1, o]`.
- Reestimación completa en cada origen — órdenes, hiperparámetros y coeficientes.
- Horizontes h = 1, 2, 4, 8, reportados por separado y nunca agregados en un indicador
  único.
- Ventana rodante como robustez. **[decidido 2026-09-24, F4-10]** Longitud fija de 92 trimestres
  (23 años), igual a la muestra de estimación del primer origen bajo la convención B, de
  modo que la rodante y la expansiva coincidan exactamente en el primer origen y se
  separen a partir de ahí: así la diferencia entre las dos series de métricas es atribuible
  al descarte de la cola antigua y no a un cambio simultáneo de tamaño inicial.

### 2.3 Conjunto de información en cada origen [decidido 2026-09-24, F4-02]

El PIB trimestral se publica con rezago **[verificado]** de 92 días mediana tras el cierre
del trimestre (calendario de divulgación del BCR, `doc/calendario_divulgacion_bcr.csv`).
Es decir: cuando el dato del trimestre `o` existe, ya transcurrió el trimestre `o+1` casi
completo, y de los predictores mensuales hay información posterior a `o`. El tercer mes de
`o+1` nunca está publicado a esa fecha: termina el día anterior a la publicación del PIB.
Corregido el 2026-09-24: la primera versión de esta tabla decía 3 y 2 meses por un desfase de
índice en el cálculo; la cifra vigente la regenera `scripts/evidencia_insumos_fase4.R`, y una
reimplementación independiente la confirma.

| Familia | Rezago mediano (días tras el cierre del período) | Meses del trimestre `o+1` conocidos al publicarse el PIB de `o` (igual en los 52 orígenes) |
|---|---|---|
| `BCR.IPP.IDX.NSA.M` | 10 | 2 |
| `BCR.REMESAS.NOM.NSA.M` / `REAL` | 24 | 2 |
| `BCR.EXPORT_FOB.NOM.NSA.M` | 24 | 2 |
| `BCR.ITCER.IDX.NSA.M` | 30 | 2 |
| `BCR.IVAE.VOL.SA.M` | 61 | 1 |
| `BCR.IPM.IDX.NSA.M` | 61 | 1 |
| `UT.DEMANDA_ELEC.GWH.NSA.M` | grano anual **[verificado]** | ver F4-02 |
| `PIB_SA_PROPIO_Q` (objetivo) | 92 | — |

**Regla decidida (2026-09-24).** El conjunto de información del origen `o` es el de la fecha de
publicación del PIB de `o` (cierre de `o` + 92 días): cada serie mensual entra hasta el
último mes `m` tal que `fin(m) + rezago(serie) ≤ fecha_publicacion(PIB de o)`. Los
predictores trimestrales entran hasta `o` inclusive salvo que su propio rezago lo impida.
Esta regla es la que hace que el borde irregular sea una ventaja del SIE y no una
filtración: sin ella, un modelo con predictores usaría trimestres completos que en el
origen no existían.

La demanda eléctrica de UT tiene grano de disponibilidad **anual** —sus 25 vintages son un
archivo por año con fecha de publicación sintética (31-dic, 31-jul para 2026)—, así que
para ella la regla anterior no es aplicable tal cual y requiere decisión (F4-02).

### 2.4 Vintage contra el que se evalúa [decidido 2026-09-24, F4-03]

ADR-001 fija como criterio **primario** "evaluación contra el vintage disponible en cada
origen de pronóstico (real-time)", con la última revisión como comparación secundaria.
**[verificado]** Eso hoy no es implementable para los orígenes 2013-2025: de las 56 filas
de `catalogos/08_vintages.csv`, solo 24 tienen fecha de publicación anterior a 2026 y todas
son de `UT.DEMANDA_TOTAL_MENSUAL`; el PIB trimestral tiene un único vintage
(`v2026-06`), y el retropolado `v2019-03` no registra fecha de publicación. No existe, en
el sistema, el PIB "tal como se conocía" en ningún origen del período de evaluación.

El protocolo, por lo tanto, declara dos pistas y no confunde una con la otra:

1. **Pista retrospectiva (la que produce el resultado de Fase 5).** Se evalúa contra el
   vintage vigente del objetivo, filtrando explícitamente por `vintage_id` en L3 — la
   columna existe desde el cierre de Fase 3 —, y se declara en toda tabla que el ejercicio
   usa datos revisados, no datos en tiempo real. La consecuencia conocida (sobreestimación
   de la precisión alcanzable en operación) se reporta como límite, no se estima.
2. **Pista en tiempo real (prospectiva).** El motor filtra por `vintage_id` desde el primer
   día, de modo que cuando el registro prospectivo acumule vintages del PIB —el primero
   capturado es `v2026-06`— la misma corrida, sin cambios de código, produzca la evaluación
   real-time que ADR-001 pide. Con un vintage nuevo por trimestre, el ejercicio se vuelve
   informativo a partir de ~2030 con 16 orígenes, o antes si se reconstruyen vintages
   históricos (ADR-007, vía (b)).

Esto requiere una nota de enmienda a ADR-001: su criterio primario no es alcanzable en el
horizonte de Fase 5 y el orden primario/secundario queda invertido **para el ejercicio
retrospectivo**.

### 2.5 Muestra común y grupos de comparación [decidido 2026-09-24, F4-05]

Las pruebas de Diebold-Mariano y el Model Confidence Set exigen que los modelos comparados
tengan **el mismo conjunto de pares (origen, h)**. Los predictores no empiezan todos en
1990 **[verificado]**, y en el primer origen la asimetría es grande:

| Serie trimestral | Inicio | Obs. en el primer origen (2013-Q1) |
|---|---|---|
| `PIB_SA_PROPIO_Q` | 1990-Q1 | 93 |
| `BCR_REMESAS_NOM_NSA_Q` | 1991-Q1 | 89 |
| `BCR_EXPORT_FOB_NOM_NSA_Q` | 1994-Q1 | 77 |
| `BCR_ITCER_IDX_NSA_Q` | 2000-Q1 | 53 |
| `UT_DEMANDA_ELEC_GWH_NSA_Q` | 2002-Q1 | 45 |
| `BCR_IVAE_VOL_SA_Q` | 2005-Q1 | 33 |
| `BCR_IPM_IDX_NSA_Q` | 2005-Q1 | 33 |
| `BCR_IPP_IDX_NSA_Q` | 2010-Q1 | 13 |
| `BCR_REMESAS_REAL_NSA_Q` | 2010-Q1 | 13 |

**[verificado]** Exigiendo un mínimo de 40 observaciones para estimar, un modelo que use
IPP o remesas reales no tiene su primer origen viable hasta 2019-Q4 y deja 25 / 24 / 22 / 18
orígenes por horizonte; con un mínimo de 60 observaciones, 5 / 4 / 2 / 0. Un solo MCS sobre
todos los modelos obligaría a recortar todo el ejercicio a esos 25 orígenes.

**Decidido (2026-09-24):** tres grupos de comparación, cada uno con su propio conjunto de orígenes, su
propio benchmark y su propio MCS; ninguna prueba de significancia cruza grupos.

| Grupo | Predictores admitidos | Primer origen | Orígenes h=1/2/4/8 |
|---|---|---|---|
| **G1 — largo** | ninguno (univariados) + remesas nominales + exportaciones FOB | 2013-Q1 | 52 / 51 / 49 / 45 |
| **G2 — medio** | G1 + ITCER + UT + IVAE + IPM | 2014-Q4 | 45 / 44 / 42 / 38 |
| **G3 — corto** | las 8 familias (incluye IPP y remesas reales) | 2019-Q4 | 25 / 24 / 22 / 18 |

Los benchmarks de §6.1 de la senda se corren en los tres grupos, de modo que las métricas
relativas sean comparables entre grupos aunque las absolutas no lo sean. El resultado
principal del proyecto es el de G1 y G2; G3 se reporta con la advertencia explícita de
potencia.

### 2.6 Selección de órdenes e hiperparámetros [heredado, senda §5.2]

Dentro de cada ventana de estimación, sin excepción y con simetría entre familias:

- Órdenes de ARIMA/VAR/ETS: por criterio de información calculado **solo** con datos
  `≤ o`.
- Hiperparámetros de ML y de métodos regularizados: validación anidada que respeta el
  orden temporal dentro de `[inicio, o]`, con grilla y criterio de selección declarados en
  `catalogos/06_modelos/<modelo_id>.yaml` antes de la primera corrida.
- La transformación de los predictores (nivel / log / diferencia) **no** se elige mirando
  el veredicto de estacionariedad publicado en Fase 3: ese veredicto se computó sobre la
  muestra completa y usarlo aquí sería filtración. Ver F4-06.

---

## 3. Métricas [heredado, senda §5.3; detalle propuesto]

Por modelo, por grupo y por horizonte, sobre el conjunto común de pares (origen, h):

1. **RMSE** y **MAE** en puntos porcentuales de la tasa interanual (unidad primaria).
2. **RMSE relativo** al benchmark declarado del grupo. **[decidido 2026-09-24, F4-07]** El
   denominador es el paseo aleatorio sin deriva sobre el log-nivel, que es la referencia
   ingenua sin parámetros; el paseo aleatorio con deriva y el promedio histórico de la tasa
   de crecimiento se reportan como competidores, no como denominador.
3. **Sesgo medio** del error, con su error estándar Newey-West (rezago `h−1`, que es la
   autocorrelación mecánica del error a horizonte `h`).
4. **Calibración**, solo para los modelos que producen densidad o intervalos: cobertura
   empírica de los intervalos al 80% y 95%, y CRPS. Los modelos que no producen densidad
   (árboles sin bootstrap, combinaciones simples) quedan fuera de esta tabla y eso se
   declara; no se les imputa una densidad.
5. Las mismas cuatro sobre `Δlog` trimestral y log-nivel, como tablas secundarias.

Ninguna métrica se agrega entre horizontes.

## 4. Pruebas de significancia [heredado, senda §5.4; decidido 2026-09-24, F4-15 a F4-18]

- **Diebold-Mariano con corrección Harvey-Leybourne-Newbold**, para comparaciones por
  pares contra el benchmark del grupo. Pérdida cuadrática sobre la unidad primaria,
  varianza de largo plazo con ventana rectangular de `h−1` rezagos, distribución
  `t_{n−1}`. Indispensable con estos tamaños: en G3 y h=8 hay 18 observaciones de
  pérdida **[verificado]**. Si la varianza rectangular no es positiva se usa Bartlett con
  los mismos rezagos y la salida lo registra (F4-16).
- **Giacomini-White** cuando la comparación involucra modelos reestimados en ventana
  rodante, que es el caso de la batería de robustez. Versión condicional con instrumentos
  `(1, d_{t−h})`, varianza HAC Bartlett de `h−1` rezagos y `χ²(2)` (F4-17).
- **Model Confidence Set** (Hansen, Lunde y Nason) como prueba principal de cada grupo,
  con estadístico `T_max`, `α = 0,10`, `B = 5000` réplicas de un bootstrap estacionario
  circular de bloque medio `max(h, ⌈n^(1/3)⌉)`, y la semilla declarada en el experimento (F4-15).
- **Distorsión de tamaño documentada (F4-18).** La verificación sintética (V7, V9) mostró
  que DM/HLN mantiene el tamaño nominal en h = 1, 2 pero sobre-rechaza en h = 4, 8 (hasta
  0,15 al 5% con los 18 pares de G3 a h = 8), y que con modelos equivalentes el MCS descarta
  de más a h = 8. Se mantienen ambas pruebas: los p-valores de h = 4, 8 se publican con la
  marca «distorsión de tamaño documentada» junto al tamaño empírico de su celda, y en esos
  horizontes que un modelo quede fuera del MCS no se lee como prueba de inferioridad. La
  potencia es baja (V8: una pérdida 20% menor se detecta entre 7% y 16% de las veces): no
  rechazar no equivale a equivalencia.
- **Regla de reporte, fijada antes de ver los resultados:** si el MCS contiene varios
  modelos, el resultado del proyecto es el conjunto, no el mínimo del RMSE. No se declara
  ganador único con base en una diferencia que el MCS no distingue, y la tabla de RMSE se
  publica siempre con la pertenencia al MCS en una columna adyacente.

## 5. Batería de robustez obligatoria

Cada variante se corre con el mismo motor y el mismo conjunto de orígenes del grupo, y se
reporta junto al resultado principal:

| Código | Variante | Origen de la exigencia |
|---|---|---|
| R1 | Ventana rodante de 92 trimestres | senda §5.1 |
| R2 | Tramo homogéneo: estimación solo desde 2005-Q1 **[verificado]** 45 / 44 / 42 / 38 orígenes | ADR-003 |
| R3 | Submuestras pre/post 2020 con contraste de estabilidad | ADR-004 |
| R4 | Métricas excluyendo los cuatro trimestres de 2020 como período evaluado | F4-08 |
| R5 | Objetivo alternativo `PIB_SA_OFICIAL_Q` (2005-Q1 en adelante) | ADR-001 |
| R6 | Ajuste único de L3 como contraste del ajuste reestimado por origen, que es la vía primaria | F4-09 |

**[verificado]** Sobre el peso de 2020 (R4): en la muestra de evaluación la variación interanual del objetivo, sobre los 52 targets de h=1 (2013-Q2 a 2026-Q1), tiene
desviación estándar de 5,33 pp, que baja a 3,68 pp excluyendo 2020; 2020-Q2 marca −22,29 pp interanual y −21,44 pp trimestral;
y los cuatro trimestres de 2020 concentran el 32,8% de la suma de cuadrados de la variación
interanual observada en los 52 targets de h=1. Con ese peso, la pertenencia al MCS puede
depender de cuatro observaciones, y por eso R4 no es opcional.

## 6. Registro del experimento y reproducibilidad

Cada corrida escribe una fila en `catalogos/07_experimentos.csv` con el esquema ya
declarado **[verificado]**: `exp_id, modelo_id, vintage_id, muestra_inicio, muestra_fin,
esquema_validacion, horizontes, semilla, commit_hash, fecha_corrida, entorno,
ruta_resultados`. **[decidido 2026-09-24, F4-11]** La variante de protocolo se codifica como token en
`esquema_validacion` —por ejemplo
`expansiva|origen=ultimo_estimado|grupo=G1|vintage=revision_vigente|sa=l3_unico|perdida=yoy_pp`—
para no extender el esquema del catálogo ni la superficie de validación. El detalle está en
`doc/metodologia/especificacion_motor_evaluacion.md`.

Criterio de cierre de Fase 5 (una orden, una semilla) queda satisfecho si y solo si
`make eval` regenera bit a bit `data/L4_experiments/<exp_id>/`.

## 7. Lo que este protocolo no cubre

- El Ejercicio B (Fase 6) y sus escenarios.
- El nowcasting del trimestre en curso (senda §6.4, extensión 1): el borde irregular de
  §2.3 lo habilita, pero el ejercicio de nowcasting tiene su propio conjunto de orígenes
  (uno por publicación mensual, no uno por trimestre) y no entra al MCS de este protocolo.
- La especificación de los modelos de Fase 5 más allá de los benchmarks de §6.1 de la
  senda, que son los que Fase 4 implementa y prueba.


---

## 8. Ajuste estacional del objetivo dentro de cada origen (F4-09 y F4-09b)

**[decidido 2026-09-24]** En cada origen `o`, X-13ARIMA-SEATS corre sobre la concatenación NSA
`[1990-Q1, o]` con:

- `transform=log` fijo (con los defaults de `seasonal` la transformación enviada es `auto`, y
  podría cambiar entre orígenes);
- orden ARIMA seleccionado automáticamente solo con datos `≤ o`, y guardado por origen en L4;
- detección automática de outliers desactivada; los AO declarados en
  `PIB_SA_PROPIO_Q_outliers.csv` entran solo desde el origen que los alcanza (2020-Q2 desde el
  origen 2020-Q2; 2020-Q3 desde el 2020-Q3).

El ajuste único de L3 queda como contraste (R6). Registro: ADR-004, nota de seguimiento del
2026-09-24, con referencia cruzada en ADR-001.

**Prerrequisito verificado (2026-09-24).** Prerrequisito verificado: `seasonal::checkX13()` corrido por Harold en la máquina del proyecto el 2026-09-24 pasa ("'seasonal' should work fine"). La falla que se observaba desde el sandbox de desarrollo (error de programa 133 al correr `seas()` con un `.spc` en una ruta temporal de unos 170 caracteres) era del entorno, no del binario. En cualquier caso no corre en CI: la evidencia
de las corridas con ajuste por origen va a `doc/evidencia_cierre_fase4.txt`, no a un run de CI.

## 9. Unidad de modelación de las predictoras (F4-06)

**[decidido 2026-09-24]** Las ocho familias entran como Δlog, sin excepción y sin elegir por
serie. Las predictoras NSA llevan términos estacionales explícitos (restricción de ADR-010, nota
del 2026-09-22, que sigue vigente). Registro: ADR-010, nota de seguimiento del 2026-09-24.
