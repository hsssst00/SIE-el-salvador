# Nota metodológica: supuestos de escenarios exógenos (Ejercicio B)

**Decisión registrada en:** `doc/adr/ADR-002-horizonte-y-diseno.md`

**Estado (2026-10-23): borrador completo antes del congelamiento; F1 de `doc/checklist_fase6.md` se marca después
de la corrida (E3).** Las secciones 1 a 8 son lo vigente. Los supuestos citados en ellas no dependen de las
capturas del BCR que faltan antes de E1. Si E1 renueva alguno de los vintages de la sección 2, esa sección se
actualiza en el mismo PR del congelamiento. La sección 9 enumera lo que falta y cuándo se completa. Al final, en
«Registro», se conservan el texto original de ADR-002 («Resumen» y «Pendiente») y las notas fechadas del 2026-10-17
y del 2026-10-19.

Todas las cifras de proyección que se obtengan con estos supuestos son **condicionales**: dicen qué pasaría con el
PIB de El Salvador si se cumplieran los supuestos de cada escenario. No son pronósticos de lo que va a pasar. Los
escenarios tampoco tienen probabilidades asignadas.

## 1. Qué fija este documento

Este documento reúne los supuestos exógenos del Ejercicio B (ADR-002; protocolo §4): para cada escenario, qué
variable externa se supone, cuál es su valor, de qué publicación sale y con qué vintage y sha256 está en L0. También
declara las inconsistencias entre fuentes que ADR-002 manda reconocer.

Las decisiones están en `doc/metodologia/decisiones_fase6.md` (F6-05, F6-09, F6-14 a F6-18) y el método completo, en
`doc/metodologia/protocolo_proyeccion.md`. Este documento no repite el método. Solo cita las decisiones donde hace
falta para entender un supuesto.

## 2. Fuentes en L0

Todas llegaron a L0 por un *script* de `src/adquisicion/`, con su fila en `data/L0_raw/manifiesto.csv` y en
`catalogos/08_vintages.csv`, y están declaradas en `doc/metodologia/corte_fase6.csv`.

| Vintage | Qué aporta | Publicación (`fecha_publicacion`) | Archivo en L0 | sha256 |
|---|---|---|---|---|
| `FMI.WEO.v2026-10` | Escenario base: crecimiento del PIB de EE. UU., inflación de EE. UU. y precio del petróleo, anuales hasta 2031; además el crecimiento del PIB de El Salvador, solo como referencia (F6-10) | FMI, *World Economic Outlook*, octubre de 2026, base de datos (API SDMX 3.0, dataflow `IMF.RES/WEO`, extracto G001 + USA + SLV) (2026-10-13) | `FMI_weo_2026-10-19.json` | `f115cd02d510e12d8537970ed0b84a0e93853f38958f541840bdbeaa39fef7ec` |
| `FMI.WEO.CAPITULO1.v2026-10` | Adverso y favorable: desvíos de los escenarios C y A respecto de la base | FMI, WEO de octubre de 2026, capítulo 1, recuadro 1.2, libro de datos de las figuras (`ch1data.xlsx`) (2026-10-13) | `FMI_weo_capitulo1_2026_october_2026-10-19.xlsx` | `74576dbb057c6bcc1bf1f525b195ab29386c3a42fa6426d92ae14e6b0d1af961` |
| `FRED.BEA_PIB_EEUU.v2026-10` | Historia trimestral del PIB real de EE. UU. (GDPC1), de 1947-T1 a 2026-T2 | BEA, vía la API de FRED (`realtime_start` 2026-10-21) | `FRED_gdpc1_2026-10-22.json` | `31f8d6a3f207fb198af7e8b55ef66f598eb341ae60f5901e74dfb74eafe5f655` |
| `FRED.CPIAUCSL.v2026-10` | Historia mensual del IPC de EE. UU. (CPIAUCSL), de 1947-M01 a 2026-M09 | BLS, vía la API de FRED (`realtime_start` 2026-10-21) | `FRED_cpiaucsl_2026-10-22.json` | `ff2d6ceff19494472ea0a8fb1056b6e3ae3fb002bb25f0c2c94dc9d68053ff22` |
| `FMI.PCPS.POILAPSP_USD.v2026-10` | Historia mensual del precio del petróleo en USD (`G001.POILAPSP.USD.M`), de 1992-M01 a 2026-M09 | FMI, *Primary Commodity Price System* (2026-10-06) | `FMI_poilapsp_usd_2026-10-19.json` | `de4a97412b1a60a81734ac2df2546a86f4ae4c74faaf5dfadc914ce81cfa1920` |

Claves exactas dentro de cada archivo:

- WEO: `USA.NGDP_RPCH.A`, `USA.PCPIPCH.A`, `G001.POILAPSP.A` y `SLV.NGDP_RPCH.A`.
- Capítulo 1, hojas `Figure 1.2.2.` (panel «2. United States», filas 8 y 10, columnas T:Y) y `Figure 1.2.3.` (panel
  «1. Inflation», «United States», filas 10 y 12, columnas K:P).

El detalle por celda está en `catalogos/03_series.csv`. La lectura de las cuatro filas del capítulo 1 se verificó con
`verificar_fuente_celda.R` (bitácora, entrada del 2026-10-19). Las series JSON quedan fuera del alcance del
verificador: `extraer_escenarios.R` exige la clave citada y falla de forma visible si no la encuentra.

**Condiciones de uso (ADR-008).** El FMI y FRED están en tramos resueltos (*script* y *checksum*). El tramo de FRED
exige además dos cosas. Primero, el aviso de no-aval de la API de FRED en el `README.md`, con el texto exacto de
los Términos de Uso vigentes: al 2026-10-23 el `README.md` no lo tiene, aunque `src/adquisicion/fred.R` consume la
API desde Fase 2. Segundo, la revisión, serie por serie, de la marca de derechos reservados. GDPC1 y CPIAUCSL son
series de agencias federales de EE. UU. (BEA y BLS). El informe de proyección (F2) debería repetir el aviso.

## 3. Supuestos por escenario

### 3.1 Base

Los valores son los del WEO de octubre de 2026, tal como vienen en el archivo de L0. Aquí van redondeados; la
corrida usa el valor completo. 2025 es historia en el WEO; la proyección empieza en 2026.

| Año | PIB real de EE. UU., crecimiento anual (%) `USA.NGDP_RPCH` | Inflación del IPC de EE. UU., promedio anual (%) `USA.PCPIPCH` | Petróleo APSP (USD por barril, promedio anual) `G001.POILAPSP` |
|---|---|---|---|
| 2025 | 2,344 | 2,730 | 67,74 |
| 2026 | 2,328 | 3,648 | 95,74 |
| 2027 | 2,293 | 2,835 | 87,39 |
| 2028 | 2,056 | 2,113 | 78,00 |
| 2029 | 1,881 | 1,865 | 74,56 |
| 2030 | 1,753 | 1,903 | 72,29 |
| 2031 | 1,755 | 1,916 | 70,46 |

El petróleo es el promedio simple de Brent, WTI y Dubai Fateh.

### 3.2 Adverso: escenario C, «Market Correction» (F6-14)

En el escenario C de modelo del recuadro 1.2 (modelo GIMF del FMI), las ganancias de productividad de la inteligencia
artificial no llegan, cae la inversión en tecnología de EE. UU. y las acciones de EE. UU. bajan 20 % en 2026.

| Año | 2026 | 2027 | 2028 | 2029 | 2030 | 2031 |
|---|---|---|---|---|---|---|
| Nivel del PIB real de EE. UU., % de desvío de la base (figura 1.2.2, panel 2) | 0,0 | −1,5 | −1,8 | −1,4 | −0,8 | −0,5 |
| Inflación de EE. UU., pp de desvío de la base (figura 1.2.3, panel 1) | 0,0 | 0,0 | −0,1 | −0,3 | −0,2 | 0,0 |

### 3.3 Favorable: escenario A, «Strong Payoffs» (F6-05, nota del 2026-10-19)

Del mismo recuadro y el mismo modelo: más inversión en inteligencia artificial y ganancias de productividad
tempranas.

| Año | 2026 | 2027 | 2028 | 2029 | 2030 | 2031 |
|---|---|---|---|---|---|---|
| Nivel del PIB real de EE. UU., % de desvío de la base (figura 1.2.2, panel 2) | 0,0 | 0,4 | 0,7 | 1,0 | 1,1 | 1,3 |
| Inflación de EE. UU., pp de desvío de la base (figura 1.2.3, panel 1) | 0,0 | 0,1 | 0,0 | 0,0 | 0,0 | 0,0 |

### 3.4 Cómo se aplican los desvíos (F6-14)

- **PIB de EE. UU.:** el nivel anual del escenario es el nivel anual de la base × (1 + d / 100).
- **Inflación de EE. UU.:** la inflación anual del escenario es la de la base + d. El índice se encadena con esa
  inflación. La «Inflation» de la figura se lee como inflación del IPC en promedio anual (`PCPIPCH`). El recuadro no
  lo precisa (F6-14-a), pero los desvíos son de 0,3 pp o menos.
- **Petróleo:** ni A ni C lo publican, así que queda en el sendero base en los tres escenarios.
- Las cifras van con el decimal que trae la hoja; no se reconstruyen decimales desde el gráfico (F6-14-b).

### 3.5 Sensibilidad (F6-09)

Sobre el escenario base se mueve una variable a la vez (PIB de EE. UU., IPC de EE. UU. y petróleo) en ±1 desviación
estándar histórica de su crecimiento anual, sumada al crecimiento de cada año proyectado, de modo que el
desplazamiento es permanente. Son seis corridas. La desviación estándar se calcula sobre la historia de cada
variable en L3, con los años completos y sin 2020 ni 2021 (F6-09-a, F6-09-b). Sus valores salen de la corrida y se
citan desde su evidencia (sección 9).

## 4. Del supuesto anual al sendero trimestral (F6-16)

El WEO publica años y los modelos usan trimestres. Las metas anuales se encadenan con los **crecimientos** del WEO
sobre la historia propia de cada variable en L3, desde su último año completo. El sendero trimestral es el más suave
(Denton-Cholette) que promedia cada meta anual. Los trimestres completos observados quedan fijos, hasta 2031-T4.
Consecuencias que el informe declara:

- **El año del origen está observado en parte**, así que la meta de 2026 se reparte solo entre los trimestres que
  faltan. En el petróleo, el promedio del WEO para 2026 (95,74 USD) con tres trimestres observados obliga a un
  2026-T4 alto. Con el corte vigente (sha256 sin CR `cef1c939…`), la L3 da 118,22 USD en 2026-T4, un 31 % más que
  el promedio de 2026-T3 (90,17), y el sendero baja a 77,56 USD en 2027-T4. Ese petróleo entra a IPM e IPP en los
  tres escenarios. Harold decidió mantener el método el 2026-10-19. Las capturas del BCR pendientes no cambian estas
  cifras; solo las cambiaría un vintage nuevo de PCPS o del WEO.
- **Con d = 0 en 2026 y d ≠ 0 en 2027** (A y C), el suavizado curva también los trimestres libres de 2026 sin cambiar
  su promedio (F6-16-b).

## 5. Cómo llegan los supuestos a los modelos (F6-15)

Ningún modelo del PIB recibe directamente una variable de escenario. Esas variables mueven las predictoras externas
de los modelos a través de seis ecuaciones satélite (rezagos distribuidos autorregresivos en Δlog, estimadas una
vez en el origen):

| Variable de escenario | Predictoras que mueve (satélite) |
|---|---|
| PIB real de EE. UU. | remesas nominales (`SAT.REMESAS_NOM`), remesas reales (`SAT.REMESAS_REAL`), exportaciones FOB (`SAT.EXPORT_FOB`) |
| IPC de EE. UU. | ITCER (`SAT.ITCER`) |
| Petróleo | IPM (`SAT.IPM`), IPP (`SAT.IPP`) |

IVAE y UT son internas y no se condicionan (F6-03).

## 6. Nota de inconsistencia entre fuentes (ADR-002)

ADR-002 pide declarar que la combinación de fuentes no garantiza consistencia interna perfecta. En la forma en que
quedó implementada, la combinación tiene estas costuras:

1. **Proyección de un productor sobre historia de otro.** Los crecimientos del WEO se encadenan sobre la historia de
   BEA (PIB), BLS (IPC) y PCPS (petróleo), en vintages distintos. Con los vintages de la sección 2, el crecimiento
   anual de GDPC1 coincide con `USA.NGDP_RPCH` en los años históricos (diferencia máxima 0,000 pp; con el vintage
   de agosto llegaba a 0,24 pp en 2025). La inflación de CPIAUCSL coincide con `USA.PCPIPCH` a ≤ 0,01 pp (validación
   6 de F6-18). El promedio anual del petróleo de PCPS reproduce `G001.POILAPSP` (validación 5). Sin embargo, el WEO
   cerró los datos de EE. UU. el 2026-09-30, y los trimestres de 2026 que se fijan como observados vienen de FRED. Si
   la BEA o el BLS revisaron esos trimestres después de ese cierre, la meta del WEO se aplica sobre datos que el FMI
   no vio.
2. **Base y escenarios de modelos distintos.** La base es el pronóstico central del WEO. A y C salen del modelo GIMF
   y se publican solo como desvíos de esa base. Aplicarlos sobre la base supone que los desvíos se trasladan sin
   cambio, cuando el FMI no publica los niveles de A y C.
3. **El petróleo no se mueve en A ni en C.** El recuadro no publica el petróleo de esos escenarios. Una caída de la
   actividad de EE. UU. con el petróleo fijo no es, en general, lo que daría un modelo global. El riesgo del petróleo
   se ve solo en la sensibilidad.
4. **Remesas nominales y reales con satélites separadas** sobre el mismo PIB de EE. UU. (F6-15-b). El deflactor
   implícito entre ambas no queda atado. Solo afecta a `MULT.BVAR.G3`. La coherencia lo reporta como informativo
   (F6-10, nota del 2026-10-22).
5. **Las satélites son modelos nuevos** que el Ejercicio A no evaluó. Sus residuos se suponen independientes de las
   innovaciones de cada modelo del PIB (F6-15-a).
6. **ADR-002 preveía proyecciones de la Fed, la BEA o la CBO para EE. UU.** En la implementación, las proyecciones de
   EE. UU. vienen del WEO, y de la BEA y el BLS solo la historia (sección 7). Por eso la fuente «híbrida» de ADR-002
   quedó como proyección del FMI sobre historia de EE. UU. Las costuras 1 a 3 son las que eso produce.
7. **El crecimiento del PIB de El Salvador según el WEO** (`SLV.NGDP_RPCH`) no se usa como supuesto ni como
   objetivo. Es solo una referencia en la coherencia (F6-10). Una diferencia con la base del SIE no es un error de
   ninguna de las dos.

## 7. Fuentes consideradas y no usadas

- **CBO,** *The Budget and Economic Outlook: 2026 to 2036*, proyecciones trimestrales. Está capturada en L0
  (`CBO.PROYECCIONES_ECONOMICAS.v2026-02`, `CBO_proyecciones_economicas_trimestrales_2026_02_2026-10-19.csv`,
  sha256 `eda9f9eb6607461621504a973ff7609ef627ccfd02d8096219843efccf55ca7f`) y no se usa en Fase 6. Las remesas
  usan el PIB de EE. UU. y no el empleo, así que la base no mezcla dos fuentes con ocho meses de diferencia (el
  pronóstico de la CBO cerró el 2025-12-03) (F6-15).
- **SEP de la Reserva Federal.** No proyecta el empleo asalariado, llega a tres años más el largo plazo y no tiene una
  declaración de uso verificada equivalente a la de la CBO (F6-05-a).
- **Escenario de materias primas y bonos del recuadro 1.2** (modelo G20). No publica cifras de EE. UU. ni un sendero
  del petróleo después de 2027 (F6-14).
- **Comercio mundial** (`G001.TRADEPCH`). No hay historia trimestral en L0 y ni A ni C lo publican (F6-15).
- **Escenario B** («Capacity Constraints»). Sube el PIB de EE. UU. con más inflación y alza de tasas, así que no es
  el lado favorable de C (F6-05-b).

## 8. Lo que un lector debe tener presente

- Un escenario es un «si… entonces». La diferencia entre base, adverso y favorable mide la respuesta de los modelos a
  los supuestos de EE. UU., no la incertidumbre total sobre el PIB de El Salvador. Para eso están las bandas
  (F6-07).
- Los únicos canales de transmisión son los de la sección 5. Un choque interno de El Salvador (fiscal, financiero o
  climático) no está en ningún escenario.

## 9. Pendiente

- [ ] **E1.** Confirmar que los vintages de la sección 2 son los que congela el preregistro. Si alguno cambia, se
  actualizan en el mismo PR sus filas y las cifras de las secciones 3 y 4.
- [ ] **E3.** Citar, desde la evidencia de la corrida, las desviaciones estándar de la sensibilidad (sección 3.5).
- [ ] **ADR-008, FRED.** Aviso de no-aval en el `README.md`, con el texto exacto de los Términos de Uso vigentes
  (sección 2). Va antes de publicar el informe (F2).
- [ ] **F1.** Revisión final y marca en el checklist.

## Registro

## Resumen

Fuente híbrida: FMI WEO para variables globales/regionales; proyecciones de la Reserva Federal / BEA / CBO para variables relacionadas con Estados Unidos (actividad económica, insumo del supuesto de remesas).

**Nota de coherencia obligatoria:** no se garantiza consistencia interna perfecta entre las dos fuentes combinadas — debe declararse explícitamente en el documento final de supuestos (Fase 6).

## Pendiente (Fase 6, al implementar)

- [x] Fijar las publicaciones específicas de WEO y Fed/BEA/CBO a usar como fuente para cada escenario. — F6-05 y
  F6-15; capturadas en L0 con sha256 por C2 y C2b (checklist de Fase 6, 2026-10-19).
- [x] Definir 2-3 escenarios explícitos con supuestos citados. — base, adverso (C) y favorable (A), F6-05 y F6-14.
  Los supuestos citados con vintage y sha256 los reúne F1.
- [ ] Análisis de sensibilidad a los supuestos. — F6-09; implementado en D6 (PR #85), sus cifras salen de la corrida
  (E3).

## Nota (2026-10-17, F6-03 y F6-05)

Las publicaciones quedan fijadas en `doc/metodologia/decisiones_fase6.md` (F6-05, con el detalle F6-05-a delegado al
agente). Las casillas de arriba no se marcan hasta que los supuestos estén capturados en L0 con su sha256.

- **Base:** FMI, *World Economic Outlook* de octubre de 2026 (publicado el 2026-10-12), para las variables globales y
  el PIB de EE. UU.; CBO, proyecciones económicas vigentes al congelar, para el empleo de EE. UU. El SEP de la Fed no
  se usa.
- **Adverso:** un escenario de riesgo del capítulo 1 del mismo WEO, si publica magnitudes cuantitativas utilizables
  (ficha F6-14, abierta).
- **Favorable:** solo si aparece una fuente que lo publique.
- **Sensibilidad:** F6-09.
- **Cómo llegan los supuestos a los modelos:** por ecuaciones satélite, una por predictora externa (remesas, FOB,
  IPM e IPP, ITCER; F6-03). IVAE y UT no se condicionan. Las satélite son modelos nuevos que el Ejercicio A no evaluó,
  y este documento debe declararlo junto con la nota de coherencia de arriba.

El método completo está en `doc/metodologia/protocolo_proyeccion.md`.

## Nota (2026-10-19, F6-14 a F6-18)

Las fichas F6-14 a F6-18 de `doc/metodologia/decisiones_fase6.md` completan lo que la nota anterior dejaba abierto.

- **Base:** WEO de octubre de 2026 para el PIB de EE. UU., la inflación de EE. UU. y el precio del petróleo. La CBO
  quedó capturada y sin uso; el empleo de EE. UU. y el comercio mundial no se usan (F6-15).
- **Adverso:** escenario C («Market Correction») del recuadro 1.2 del capítulo 1, con sus desvíos anuales del PIB y
  de la inflación de EE. UU. El petróleo queda en la base (F6-14).
- **Favorable:** escenario A («Strong Payoffs») del mismo recuadro, con la misma traducción (F6-05, nota del
  2026-10-19).
- **De anual a trimestral:** Denton-Cholette con los trimestres observados fijos (F6-16).
- **Inconsistencias que se declaran:** el adverso y el favorable vienen de un modelo del FMI (GIMF) distinto del que
  arma la base; con C y con A el petróleo no se mueve; y las remesas nominales y reales tienen satélites separadas
  (F6-15-b).
