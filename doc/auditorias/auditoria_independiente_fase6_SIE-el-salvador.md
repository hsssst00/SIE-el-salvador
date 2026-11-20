## Auditoría independiente — cierre de Fase 6 (proyección condicional, Ejercicio B), SIE El Salvador

**Repositorio auditado:** `github.com/hsssst00/SIE-el-salvador` (clon fresco de `origin/main`, no tarball ni árbol de trabajo).
**HEAD real de `main`:** `c898723` — *"Merge pull request #102 from hsssst00/docs/cierre-fase6"* (2026-11-19 12:29 -0600). 507 commits en total.
**Commit auditado:** `c898723`, que contiene el registro «Cierre de Fase 6» de `doc/adr/README.md`, la nota de la senda v0.12 y la propagación de estado. Rango de la fase: `0927b32..c898723` (desde la compuerta A2 del checklist), 96 commits (33 merges), 108 archivos, +11 861 / −87 líneas. Desde el último tag (`v0.8.1-fase5..c898723`) el rango suma además los PR #63 a #69, análisis posteriores de Fase 5: 112 commits, 139 archivos.
**Tags:** `v0.1.0-fase0`, `v0.2.0-fase0-enmendado`, `v0.2.1-fase0-enmendado`, `v0.4.0-fase1`, `v0.5.0-fase2`, `v0.5.1-fase2`, `v0.6.0-fase3`, `v0.7.0-fase4`, `v0.7.1-fase4`, `v0.8.0-fase5`, `v0.8.1-fase5`. **`v0.9.0-fase6` no existe todavía**: el registro lo deja propuesto y a cargo de Harold (F4 del checklist).
**Encargada por:** Harold, 2026-11-19 (ítem F4 del checklist de Fase 6).
**Ejecutada por:** Claude (modelo configurado `claude-opus-5-5`), en una sesión separada de las que produjeron la fase. Es el mismo modelo que figura como coautor en 21 commits del rango (trailer `Co-Authored-By: Claude Opus 5.5`); la independencia es de sesión y de método, no de modelo.

**Método.** El de la serie (sección siguiente). Se instaló R 4.6.1 (la versión de `renv.lock`) en Ubuntu 24.04.5 con la BLAS/LAPACK de referencia 3.12.0, la misma configuración que fija el CI desde la remediación de Fase 5, y se restauró el entorno con `renv::restore()` (189 entradas). Sobre `c898723` se corrieron la batería `testthat`, la verificación sintética V1-V23, los tres validadores de catálogos y de L0 y `make audit`. Todo lo recalculable se recalculó por separado en Python sobre el contenido commiteado, incluida la reconstrucción byte a byte de las 28 salidas de L4 desde las tablas versionadas. El estado de CI y el PR #95 se leyeron en las páginas públicas de GitHub; la API de GitHub no estuvo disponible en esta sesión. La memoria del proyecto y los informes anteriores se consultaron **solo para ubicar la metodología de las revisiones previas**; ningún hecho de este informe sale de ahí.

---

### Metodología heredada de las revisiones anteriores

Se aplica el protocolo asentado en las revisiones de `doc/auditorias/` (Fase 0 a Fase 5):

1. **Fuente única de verdad:** clon fresco de `origin/main`. Nunca resúmenes de sesión, mensajes de commit ni autorreportes.
2. **Nada se rellena desde el chat.** Lo que solo se explicaría por contexto de conversación es hallazgo.
3. **Lectura del contenido, no del diff** (`git show <rev>:<ruta>`).
4. **Recálculo independiente** de toda cifra recalculable.
5. **Ejecución de los controles del propio proyecto** (desde la revisión de Fase 4).
6. **Severidad en tres niveles** (`C#`, `I#`, `M#`), con los criterios y precedentes de las revisiones de Fase 4 y 5.
7. **Estructura fija del informe.** La nota de remediación la agrega quien remedia.
8. **Sin autoridad decisoria.** Las decisiones de nivel D son de Harold (regla 4 de `CLAUDE.md`).

**Batería de verificaciones recurrentes** y resultado en este cierre:

| # | Verificación | Origen | Resultado ahora |
|---|---|---|---|
| 1 | Estado de fase propagado a `CLAUDE.md` y `README.md` | F0 C2, F1v C1, F2 C1 | Limpio en la línea de Fase 6; tercer cierre seguido sin reincidencia. La línea de Fase 0 del `README.md` quedó atrás en ADR-008 (M5) |
| 2 | Celda del índice de ADR = línea `**Estado:**` | F0 C3, F1v C1 | Limpio (el guard pasa; `make audit` da 10/10) |
| 3 | El tag apunta al commit de cierre | F0 C2 | Tag pendiente; ver pendiente 1 |
| 4 | CI en verde sobre el commit certificado | F0 C2; límite 3 de F2 | Limpio: #535 sobre `c898723`, #532 sobre `73f6855` (el que cita el registro) y #518 sobre `1528483` (el commit de la corrida). Según `337abb2`, el CI del PR #94 falló por el contrato de `07` (M4) |
| 5 | `CITATION.cff` al día | F0 M4, F2 M1, F4 M1 | Limpio (0.9.0, 2026-11-19) |
| 6 | Dependencias usadas = declaradas | F2 M1, F3 I3, F4 M2/M6 | Limpio (27 Imports, 2 Suggests, bootstrap = `DESCRIPTION`; `renv.lock` sin cambios desde `v0.8.1-fase5`) |
| 7 | Conteos transcritos a mano | F3 M5, F4 M2, F5 M2 | Limpio (38 detalles, 42 filas, 126 senderos, 41 vintages, 28 archivos, 34 signos) |
| 8 | Nombres o comentarios que prometen otra cosa | F2 M2, F4 M3, F5 M2 | **Reincide (M3, M4, M5)** |
| 9 | Evidencia que un tercero no puede re-derivar | F1 I3, F2 I2, F5 I3 | Mejoró: las 28 salidas de L4 se reconstruyen byte a byte desde las tablas versionadas. Queda L3 (límite 2) |
| 10 | Independencia de quien decide y de quien revisa | F2 I2, F4 M5, F5 I2 | **Reincide: I2** |
| 11 | Fallo silencioso en transformación o validación | F3 C1 | Limpio: guarda y mínimo con `stop()`; V22 y V23 en verde aquí |
| 12 | Cifras de la certificación recalculadas | todas | Limpio en todo lo recalculable |
| 13 | Reglas antes que resultados | F4 I1, F5 I1 | **Reincide: I1 (y M2)** |
| 14 | Reproducibilidad entre entornos | F5 I4 | Limpio: 61 de las 64 líneas V de esta máquina son iguales a las de la corrida en Windows; las tres restantes dependen de la plataforma por diseño |
| 15 | *Nueva:* fechas verificables | F5, nota de fechas de su remediación | **M1** |
| 16 | *Nueva:* lo que decide un ADR cerrado se cumple o se enmienda | `CLAUDE.md`; índice de ADR | **I3** |

---

### Resumen para orientarse

**En el fondo, el criterio de cierre de Fase 6 se cumple.** Los cinco vintages de los que salen los supuestos están citados con publicación, archivo, sha256 y clave o celda, y esas citas coinciden entre `supuestos_escenarios.md`, `08_vintages.csv`, `manifiesto.csv`, `03_series.csv` y el corte congelado. El informe abre con un aviso de condicionalidad, y las 1 976 filas de las tablas de proyección llevan la columna `nota`. Todas las cifras recalculables del informe y del registro dan igual. Las 28 salidas de L4 que lista `sha256_salidas_fase6.csv` se reconstruyen byte a byte desde las tablas versionadas. La remediación de la auditoría de Fase 5 se nota: tablas versionadas desde el principio, `make fase6` usado literalmente como orden única, BLAS registrada por plataforma y CI con R, *runner* y BLAS fijos.

**Ejecución en una tercera máquina:**
- Batería: **3721 PASS / 0 FAIL / 0 SKIP / 0 ERROR** en 477 bloques `test_that`.
- Verificación sintética: **V1-V23 en OK**. V21b compara contra la fila Linux de la referencia y da idéntica en 24 modelos.
- Validadores de catálogos y de L0 cruzada (92 vintages): salida 0.
- 61 de 64 líneas V idénticas a las de la corrida vigente en Windows, incluidas V22 y V23.

**No hay hallazgos críticos.** Hay tres IMPORTANTES:

- **I1:** la regla de sensibilidad preregistrada se reemplazó después de que sus resultados estaban calculados, reproducidos y escritos en un borrador del informe fusionado a `main`. La regla nueva da en G1 una sensibilidad cuatro a cinco veces menor. El informe final dice que la regla anterior «no se reporta». La decisión es de Harold y quedó registrada, pero el registro no dice que se tomó con esos resultados ya en `main`.
- **I2:** tres de las cuatro lecturas del criterio de cierre son otra vez *«delegadas al agente y se pueden reabrir»*: es la misma situación que I2 de Fase 5. Además, las fichas F6-14 a F6-18 las redactó y decidió el agente bajo una delegación cuyo texto en `CLAUDE.md` cubre F6-01 a F6-13. La ratificación de Harold del 2026-11-15 es un avance real, pero cubre los 38 detalles, no esas cinco decisiones ni las lecturas.
- **I3:** ADR-002, cerrado, decidió una fuente híbrida con proyecciones de la Fed, la BEA o la CBO para la actividad de EE. UU., y descartó expresamente el WEO como fuente única. Fase 6 usó el WEO para EE. UU. y ADR-002 no tiene enmienda. La desviación está declarada en `supuestos_escenarios.md`, pero la especificación sigue diciendo lo contrario.

**Ninguno pide volver a correr `make fase6`.** I1 se resuelve con notas fechadas y reportando, junto a la vigente, la sensibilidad de la regla preregistrada, que ya está en el historial de git. I2 e I3 son decisiones de Harold que conviene tomar **antes de crear el tag**. Hay cinco MENORES.

---

### Hallazgos — CRÍTICO

Ninguno.

---

### Hallazgos — IMPORTANTE

#### I1. La regla de sensibilidad preregistrada se reemplazó cuando sus resultados ya estaban escritos en un borrador del informe, y el informe no reporta los de la regla preregistrada

El principio que rige desde Fase 4 es que *«definir las reglas después de ver los resultados invalida el ejercicio»*. F6-12 fijó para Fase 6 *«una sola corrida»*, y el protocolo de proyección §11 lo repite. El primer congelamiento (`b9e7327`, merge `b1376df`) fijaba la sensibilidad de F6-09-a y F6-09-b: ±1 desviación estándar sumada al crecimiento de *cada* año proyectado, de 2026 a 2031. La forma estaba en el código y en el §8 del protocolo congelado; el YAML del preregistro solo traía la magnitud.

La cronología que prueban git y las páginas públicas es esta:

| Momento | Commit o PR | Qué pasó |
|---|---|---|
| 2026-11-04 | `b9e7327` / `b1376df` | Primer congelamiento (E1) |
| 2026-11-04 | `0b1ca5a` (PR #94) | E3 en la PC INVE: escribe las 28 salidas, incluida la sensibilidad |
| 2026-11-04 | PR #95 (`d9dcb93`) | Borrador del informe escrito desde las salidas de E3, con su sensibilidad (cerrado sin fusionar el 2026-11-19) |
| 2026-11-10 08:50-09:38 | `35609db` (PR #96) | E4 en la PC `D:\harold` reproduce la corrida |
| 2026-11-10 10:37 | `a4c16d3` → `b084c1b` (PR #97) | Se fusionan a `main` las tablas de sensibilidad y el borrador del informe |
| 2026-11-10 | nota en F6-09 | Harold decide F6-09-c: el choque solo en 2027 |
| 2026-11-11 | `9ec2ea3`, `1528483` | Código nuevo y preregistro de reemplazo |
| 2026-11-12 | `daf5d4c` | E3 nueva sobre `1528483` |

El §5 del borrador fusionado decía, con la regla preregistrada: *«Una desviación estándar sostenida cambia el promedio de G1 en unos 1,5 pp»*. Esta revisión recalculó esas cifras desde las tablas de `a4c16d3`, y son las que cita la nota del 2026-11-12 en `decisiones_fase6.md`:

| PIB de EE. UU. ±1 DE | Regla preregistrada (F6-09-a/b) | Regla vigente (F6-09-c) |
|---|---|---|
| G1, promedio 2026-2030 (pp) y nivel de 2030 (%) | +1,64 (+8,3) / −1,47 (−7,0) | +0,35 (+1,7) / −0,37 (−1,8) |
| G2 | +0,55 (+2,7) / −0,71 (−3,4) | +0,18 (+0,9) / −0,09 (−0,5) |
| G3 | +0,44 (+2,2) / −0,58 (−2,8) | +0,10 (+0,5) / −0,10 (−0,5) |

La lectura del informe cambió con la regla. El borrador decía que la sensibilidad era *«bastante más que la distancia entre A, C y la base»*. El informe final dice que en G1 *«es el doble»*.

**Lo que se cumple:**
- La decisión es de Harold, no del agente, y está fechada.
- El preregistro de reemplazo nombra al anterior en `reemplaza`, con su sha256 y el motivo. El código se detiene si el reemplazado falta o cambió.
- El preregistro y la evidencia de la corrida reemplazada se conservan.
- BASE, ADVERSO, FAVORABLE y la trayectoria sin escenario no cambiaron. Esta revisión lo comprobó sobre git: ocho tablas son idénticas entre `a4c16d3` y `c898723`, y de las 28 salidas solo cambian nueve, todas de sensibilidad, guarda o signos.
- El motivo incluye un defecto real de implementación, que esta revisión reprodujo desde las tablas de `a4c16d3`. Como 2026 tenía trimestres observados, el ajuste se cargaba en sus trimestres libres: con +1 DE, el petróleo saltaba a 186,11 USD en 2026-T4 (118,22 en la base) y volvía a 152,42 en 2027-T1.

**Lo que no se cumple:**
1. **La regla se cambió con los resultados escritos.** La sensibilidad de la regla preregistrada estaba calculada desde el 2026-11-04, reproducida el 10 y escrita en un borrador fusionado a `main` esa misma mañana. Es la familia de I1 de Fase 4 y de Fase 5, esta vez con un resultado reportado que cambia.
2. **La nota de la decisión no lo dice.** La regla de la remediación de Fase 5 (protocolo de evaluación §6, que el protocolo de proyección §11 invoca) pide que *«toda decisión que se tome con resultados en disco lo dice»*. La nota de F6-09 justifica el cambio por los senderos de insumo. No menciona que las cifras de PIB de la regla vieja estaban en `main`. Esas cifras aparecen recién en la nota del 2026-11-12, después de la corrida nueva.
3. **El resultado no las reporta.** Según la lectura de la senda, «el resultado» es el informe. Su §5 dice: *«La regla anterior no se reporta»*. Solo da como razón el sendero del petróleo. Quien lea el entregable no sabe que la regla preregistrada daba una sensibilidad cuatro a cinco veces mayor en G1.
4. **El motivo cubre el defecto, no todo el cambio.** El salto de 2026-T4 se corregía dejando 2026 en la base. Los extremos de 2031 (11,48 y 280,26 USD) salen de sumar una desviación estándar al crecimiento de cada año hasta 2031, que es lo que la regla preregistrada decía. F6-09-c cambia también la magnitud: de un choque en cada año proyectado a uno solo, en 2027. Las tres variantes medidas que registra la nota son todas de choque en un solo año. No consta que se haya medido la variante que solo corregía el defecto: el choque anual desde 2027 con 2026 fijo.
5. **Los registros de referencia no lo recogen.** El protocolo congelado sigue describiendo en §8 la regla reemplazada, sin nota fechada, aunque su encabezado dice que *«después, cualquier cambio entra como nota fechada»*. El registro de cierre dice que el preregistro nuevo *«solo cambia la sensibilidad»*, sin decir que fue después de la corrida.

Hay un contexto que conecta este hallazgo con I2. Según el registro, la forma reemplazada (desplazamiento en cada año) era un detalle delegado al agente, F6-09-a; la línea DECIDIDO de F6-09 no fija en qué años se aplica el choque. No consta que Harold la hubiera revisado antes del congelamiento: la primera decisión suya sobre la forma es la que la reemplaza, con los resultados escritos. Un detalle delegado quedó congelado sin que quien decide lo viera.

Los senderos de insumo son deterministas: salen de L3 y de la regla. El defecto se podía ver antes de E1, como se hizo con la regla nueva en la «medición previa en el corte (antes de la E3 nueva)». Falta un canario así antes de un congelamiento.

*Remediación posible sin volver a correr nada:*
- Una nota fechada en el §5 del informe que reporte, junto a la vigente, la sensibilidad de la regla preregistrada, y que rotule F6-09-c como desvío del preregistro decidido con esos resultados en `main`. Las cifras ya están versionadas en `a4c16d3`; pueden quedar además como `sensibilidad_reemplazada_fase6.csv`, generada desde esa versión, con su sha256.
- Notas fechadas en F6-09 (que la decisión se tomó con esos resultados en `main`, `b084c1b`), en el §8 del protocolo y en el registro de cierre.
- Cuál de las dos reglas es la principal y cuál el desvío es decisión de Harold.

#### I2. Tres de las cuatro lecturas del criterio de cierre son otra vez delegadas, y cinco fichas se decidieron fuera del alcance escrito de la delegación

En la remediación de Fase 5, Harold adoptó las lecturas de aquel cierre (A1) y dio por terminada la delegación (A3 = a): *«Desde el 2026-10-14 esta regla rige sin excepciones»*. El 2026-10-17 abrió una delegación nueva para Fase 6, y el 19 la amplió a la fusión de PR. La regla 4 de `CLAUDE.md` la registra así:

> «Harold autorizó en el chat que el agente empezara Fase 6 por su cuenta y aplicara las decisiones recomendadas de las fichas F6-01 a F6-13. […] los detalles que una ficha no fijaba se rotulan "delegada al agente; se puede reabrir".»

**Lo que mejoró respecto de Fase 5:**
- La delegación está escrita donde rigen las reglas, con alcance y término. Lo pidió la remediación 2 de I2 de Fase 5.
- Harold ratificó el 2026-11-15 los 38 detalles delegados, y revisó uno por uno los 15 metodológicos. Esta revisión contó 38 códigos distintos en `decisiones_fase6.md`, y coinciden con las cuatro listas de la ratificación (15 + 19 + 2 + 2).
- F6-09-c, F6-19, la referencia del WEO y las precauciones del BVAR son decisiones de Harold, rotuladas como tales.

**Lo que reincide o queda fuera del alcance escrito:**
1. **Lecturas del criterio.** La nota de la senda v0.12 dice: *«Las tres primeras las tomó el agente bajo la autorización de Harold del 2026-10-17 […]; son delegadas al agente y se pueden reabrir»*, y el registro de cierre lo repite. Es la misma situación de I2 de Fase 5: un cierre cuyo criterio «se puede reabrir» no es todavía el cierre que la senda §4 pide declarar. Y el texto de la delegación habla de las fichas F6-01 a F6-13 y sus detalles, no de leer el criterio de cierre. La auditoría de Fase 5 recomendó dejar esas lecturas fuera de toda delegación.
2. **F6-14 a F6-18.** Según la nota del 2026-10-19 de `decisiones_fase6.md`, esas cinco fichas *«se redactaron y decidieron el 2026-10-19 […] en la opción recomendada de cada una y bajo la delegación del 2026-10-17»*. Cuando Harold autorizó, esas fichas no existían: la autorización se dio sobre las fichas F6-01 a F6-13, redactadas el 15 y el 16. La ratificación del 2026-11-15 lista detalles (F6-14-a, F6-15-c, F6-18-f…), no las cinco decisiones principales. Entre ellas está F6-15, que dejó sin uso a la CBO (ver I3).
3. **Autoría.** De los 63 commits no-merge del rango, 41 llevan la identidad `harold@proyecto-pib-sv.local` y 22 `lm23027@ues.edu.sv`; 28 tienen el trailer de Claude. Todos los runs de CI son del actor `hsssst00`, y la ampliación del 2026-10-19 deja al agente fusionar sus PR. Desde el repositorio no se puede saber quién fusionó el PR #102 del cierre.

Ninguna de estas decisiones parece mal tomada. El problema es quién las firma: el avance de fase lo declara Harold, y en las Fases 1 a 5 las lecturas del criterio terminaron adoptadas por él.

*Remediación posible:*
1. Antes del tag, una nota fechada de Harold en la senda §4 y en el registro que **adopte** las tres lecturas, con los cambios que quiera, como en la v0.10 de Fase 5. En la misma nota, que adopte las decisiones principales de F6-14 a F6-18, o reabra las que quiera.
2. Para Fase 7, si vuelve a delegar: escribir en la regla 4 las exclusiones (lecturas de un criterio de cierre, cambios posteriores a un congelamiento, desvíos de un ADR) y que una ficha nueva se le presenta a Harold antes de decidirse.

#### I3. ADR-002 decide una fuente híbrida con proyecciones específicas de EE. UU.; Fase 6 usó el WEO para EE. UU. y el ADR no tiene enmienda

ADR-002 (Cerrado) descartó el WEO como fuente única porque *«Estados Unidos [es] el factor dominante de incertidumbre a horizonte largo para El Salvador […], lo que justifica una fuente específica para esas variables»*. Su decisión dice:

> «Fuente de supuestos exógenos para el Ejercicio B: híbrida. FMI WEO para variables globales y regionales; proyecciones de la Reserva Federal / BEA / CBO específicamente para variables relacionadas con la actividad económica de Estados Unidos (insumo directo para el supuesto de remesas).»

Lo implementado es otra cosa:
- Las proyecciones del PIB y del IPC de EE. UU. son las del WEO (`USA.NGDP_RPCH`, `USA.PCPIPCH`). De la BEA y el BLS solo sale la historia.
- F6-05 (dentro del alcance escrito de la delegación) ya tomaba el PIB de EE. UU. del WEO y dejaba a la CBO solo el empleo, para las remesas.
- F6-15 (fuera de ese alcance, I2) pasó las remesas al PIB de EE. UU. del WEO y dejó la CBO capturada y sin uso.

`CLAUDE.md` dice de los ADR: *«Son la especificación. No hay decisión metodológica de las diez que debas tomar tú»*. El índice de ADR dice que un ADR *«se enmienda, no se reescribe, cuando una decisión posterior lo afecta»*. ADR-002 no tiene cambios desde el 2026-09-23 (`02ec7a6`). La columna «Documento enmendado» del acta no lo nombra para F6-05 ni para F6-15. El registro de cierre lo deja abierto: *«Si se agrega, la decide Harold»*.

**Lo que se cumple:**
- La desviación está declarada en `supuestos_escenarios.md`, sección 6, punto 6, y la nota de inconsistencia que ADR-002 exige está hecha.
- No cambia ninguna cifra ni el criterio, que pide fuente citada y no una fuente determinada.
- Las razones (la CBO cerró ocho meses antes que el WEO; las remesas usan el PIB y no el empleo) son razonables.

Pero el ADR es la especificación, y quien lo lea hoy encuentra la alternativa que el propio ADR descartó. Además, el «Registro» de `supuestos_escenarios.md` marca `[x]` en *«Fijar las publicaciones específicas de WEO y Fed/BEA/CBO»*, cuando ninguna proyección de la Fed, la BEA ni la CBO entra a la corrida.

*Remediación posible:* una enmienda fechada de Harold en ADR-002, antes del tag, que haga una de dos cosas:
- adopte el WEO también para EE. UU. en el Ejercicio B, con sus razones y la consecuencia sobre la nota de inconsistencia; o
- registre que Fase 6 se apartó del ADR, por qué y con qué disparador se revisa.

En los dos casos, una nota junto al `[x]` del «Registro» y la fila de ADR-002 en la columna «Documento enmendado» del acta.

---

### Hallazgos — MENOR

**M1. Fechas de commit y de evidencia que contradicen el orden de git.** Dos commits del 2026-11-04 son anteriores a su propio padre:
- `b9e7327` (00:30:56 -0600) es hijo de `07526a8` (12:27:44 -0600);
- `0b1ca5a` (01:22:12 -0600) es hijo de `b1376df` (13:04:04 -0600).

La evidencia de la corrida reemplazada dice que corrió *«sobre b1376df»* de 01:03:39 a 01:21:27, y sus manifiestos registran `fecha_corrida 2026-11-04T01:16:58-0600` (según `evidencia_reproduccion_fase6_2026-11-12.txt`). GitHub creó `b1376df` a las 13:04:04. Todo es consistente con un reloj de la PC INVE atrasado unas 12 horas. El contenido no se afecta: `b1376df` y `b9e7327` tienen el mismo árbol (`99f70a2a…`). Pero las horas del checklist E3 («01:03 a 01:21») y de esa evidencia no son horas reales. Además, la nota de fechas de la remediación de Fase 5 (*«La fecha verificable es la del commit»*) no vale para esos commits. Conviene una nota fechada en la evidencia y en el checklist, revisar el reloj de la PC INVE y, en las afirmaciones de «antes de», citar ancestría de commits (`git merge-base --is-ancestor`), no horas.

**M2. La medición previa del BVAR (E2) versionó más de lo que F6-13 (d) permitía mirar.** F6-13 (d) fija que se reportan *solo* dos cosas: la proporción de raíces y la distancia entre media y mediana. Dice también: *«No se mira el sendero ni las bandas»*. `evidencia_e2_medicion_bvar_fase6.csv`, versionado con el congelamiento, trae además las columnas `media_yoy_pp` y `mediana_yoy_pp`: el interanual central del BVAR sin escenario con h = 8 y 20 en cada grupo (G1: 2,65 y 2,80 de mediana). Con ese archivo se decidió congelar. La nota de E2 dice que *«no se miraron bandas»* y no menciona esos niveles. Como la decisión fue no cambiar nada, no hay efecto sobre resultados. Es la familia de I1, leve.

**M3. Documentos congelados o de evidencia sin la nota fechada que su propio estado exige.**
- El protocolo de proyección, congelado el 2026-11-04, conserva sin nota el §11 (*«El preregistro […] es `doc/metodologia/preregistro_fase6.yaml`»*), además del §8 de I1.
- Conserva también el §1 (*«cada tabla y figura del informe lo dice»*) y el §10 (*«Toda tabla lleva "condicional…"»*). Harold decidió el 2026-11-15 no tocar las tablas versionadas. Esa decisión consta solo en la nota de cierre de la senda, escrita el 19, y no en `decisiones_fase6.md`.
- `doc/evidencia_corrida_fase6.txt`, la evidencia de la corrida reemplazada, se titula todavía *«Evidencia de la corrida única de Fase 6»* y dice *«Esta es la única corrida»*. No tiene ninguna nota de que fue reemplazada; la de su reproducción sí la tiene.

**M4. El contrato de `07_experimentos.csv` no se adaptó a Fase 6 antes de la corrida, y su diccionario sigue sin adaptarse.** F6-12-b había declarado el 2026-10-22 las filas `COMBINACION` y la gramática `proyeccion_condicional|…`. Pero `tests/test-robustez-registro.R` exigía YAML para todo `modelo_id` y el token de F4-11. Según el mensaje de `337abb2`, lo destapó el CI del PR #94 y la prueba se adaptó después de la corrida, cosa que no consta en el checklist ni en las decisiones. La sección `07` de `catalogos/README.md` todavía dice que las filas las escribe `motor_backtesting.R`, que `modelo_id` resuelve contra `06_modelos/`, que el esquema se valida con `validar_token()` y que `horizontes` es `1,2,4,8`. Las 42 filas de Fase 6 no cumplen ninguna de las cuatro cosas. `CLAUDE.md` pide que cada directorio de catálogo lleve su diccionario de variables.

**M5. Registros que no siguieron a los hechos.**
- `README.md`, línea de Fase 0: *«quedan BCR y CEPAL en gestión, y la decisión de política de L0 aplazada al corte del BCR»*. Las dos cosas se resolvieron el 2026-10-14 y el 2026-10-19.
- `doc/adr/README.md`, «Estado general»: dice que *«sigue abierta»* la política de L0 (resuelta el 14) y que *«el 2026-10-19 venció el corte de CEPAL»*. El corte venció el 16; el 19 se registró.
- `CLAUDE.md`, sección del entorno: *«verificado en CI sobre `ubuntu-latest`»*. Desde la remediación de Fase 5, el CI corre en `ubuntu-24.04`.
- Informe §4: *«Su sendero es el mismo en los tres grupos (se comprobó sobre las tablas)»*. Es cierto para los 180 valores trimestrales. La banda del 80 % del promedio, que la tabla da una sola vez, cambia hasta 0,12 pp entre grupos (`BENCH.RW_CON_DERIVA` [0,5; 5,8] en G1 y [0,6; 5,8] en G2 y G3), porque las bandas anuales se simulan con una semilla que depende del grupo. La tabla muestra la de G1. Revela además un error de Monte Carlo de ese orden en las bandas anuales que no se declara.
- El registro de cierre dice que el PR #95 *«sigue abierto»*. La página pública lo muestra cerrado sin fusionar el 2026-11-19, después del commit del registro.

Es la familia de M2 de Fase 2 y de Fase 5, y de M3 de Fase 4.

---

### Verificaciones que resultaron limpias (con las cifras)

| Verificación | Resultado |
|---|---|
| `testthat::test_dir("tests")` sobre `c898723` (Ubuntu 24.04.5, R 4.6.1, `renv::restore()`, BLAS/LAPACK de referencia 3.12.0, locale UTF-8) | **3721 PASS / 0 FAIL / 0 SKIP / 0 ERROR / 0 WARN**, 477 bloques, 301 s. No escribe nada versionado (árbol limpio después) |
| Verificación sintética V1-V23, misma máquina | «bloques OK (V1-V23)», 639 s. Las 15 líneas V1-V11 de `doc/evidencia_cierre_fase4.txt` aparecen idénticas (V10 `f3bdc2c613bf…`). V20: RF 0,626, igual que en Windows. V21b compara contra la fila `Linux\|R 4.6.1\|libblas.so.3.12.0` de la referencia: idéntica en 24 modelos. De 64 líneas V, 61 son iguales byte a byte a las de `evidencia_corrida_fase6_2026-11-12.txt` (Windows), incluidas V22 y V23. Difieren V17 (informativa entre sistemas: 140 de 158 valores distintos, máx 1,6e-7 errores de Monte Carlo), V21 (sha256 por plataforma) y la etiqueta de plataforma de V21b |
| `validate_catalogs.R`, `validar_integridad_catalogos.R`, `check_l0_integrity.R` | salida 0 los tres; L0 cruzada con 92 vintages. `make audit`: índice de ADR 10/10, 9/9 auditorías citadas existen |
| CI (páginas públicas) | #535 (44588319079) sobre `c898723` en verde, 20 min 01 s. #532 sobre `73f6855`, el que cita el registro, en verde. #518 sobre `1528483`, el commit de la corrida, en verde. #533 y #534 del PR #102 en verde |
| Salidas de L4 contra tablas versionadas | Las 28 salidas de `sha256_salidas_fase6.csv` se reconstruyeron byte a byte desde las 12 tablas de `reportes_fase6/` (las de grupo, quitando la columna `grupo`; las de `F6_COMUN`, tal cual): **28/28 sha256 iguales**. La lista es la primera tabla de `evidencia_reproduccion_fase6_2026-11-12.txt` (28/28). La segunda tabla de ese archivo (9 archivos) es la lista reemplazada de `b084c1b` |
| `catalogos/07_experimentos.csv` | 466 filas = 424 idénticas a `v0.8.1-fase5` + 42 de Fase 6 (15/14/13). Las 42: `commit_hash` `152848396c05…`, `fecha_corrida` 2026-11-12, `entorno` con `renv.lock` `fae32aacc3dc`, 42 semillas distintas, `horizontes` 1-20. Sus 41 vintages resuelven contra `08` y son exactamente los del corte. `modelo_id` resuelve contra `06_modelos/` salvo las tres `COMBINACION` (M4) |
| Corte y preregistros | `corte_fase6.csv`: sha256 sin CR `4aaa33fea3d8…`, 41 vintages, 17 publicaciones. Entre los dos preregistros solo cambian `fecha_congelamiento`, `forma` y `anio_choque` de la sensibilidad, y el bloque `reemplaza`. Guarda: [−3,0676 − 2,0780; 10,9921 + 2,0780] = [−5,1456; 13,0701], n = 134 |
| Fuentes citadas (criterio) | Los cinco vintages de `supuestos_escenarios.md` §2 tienen el mismo archivo y sha256 en `08_vintages.csv` y en `manifiesto.csv`, y están en el corte. La CBO coincide y no está en el corte. Las claves y celdas citadas son las de `fuente_celda` en `03_series.csv` (cuatro celdas del capítulo 1 y seis claves JSON). El comunicado del FMI del 2026-10-01 da para El Salvador 4,5 % en 2026 y 4,0 % en 2027, iguales a la referencia de `coherencia_weo_fase6.csv` |
| Sensibilidad vigente | Desvíos de nivel recalculados desde las cifras citadas del WEO y las desviaciones estándar: ±2,183 % (PIB), ±2,718 % (IPC) y ±27,45 % (petróleo). En `senderos_sensibilidad_fase6.csv`, la razón de promedios anuales +1/−1 DE es constante de 2027 a 2031 (1,044634; 1,055878; 1,75659), y 2026 es la base (petróleo 2026-T4: 118,22 USD) |
| Regla de combinación (F6-02) | Δlog de `COMBINACION` = mediana de los Δlog de los miembros en las 180 celdas (3 grupos × 3 escenarios × 20 h): diferencia máxima 1,1e-14 |
| Agregación anual (F6-10, con `stop()`) | 304 celdas de 2027-2030: nivel = promedio de los cuatro trimestres (dif. relativa máx 5,4e-15); crecimiento (máx 5,6e-13 pp); promedio 2026-2030 = media de los cinco años (máx 6,2e-15 pp) |
| Guarda | 126 filas, 126 `pasa`, 0 exclusiones (14 senderos × 9 corridas). Las 42 filas de las tres corridas principales coinciden exactamente con el mín y el máx del interanual trimestral. `sin_calibrar` ⇔ h > 8 en las 1 520 filas trimestrales; la columna `nota` está en las 456 anuales y en las 1 520 trimestrales |
| Cifras del informe y del registro | Todas coinciden. §1: interanual de los miembros de −0,70 a 5,87 (nueve corridas) y de 0,03 a 5,24 (tres principales). §2: los 45 crecimientos y las 18 bandas de la tabla; A y C frente a la base −0,145 / +0,173 (G1), −0,053 / +0,028 (G2), −0,029 / +0,012 (G3); máximo de un año −0,943 (G1, 2027); ancho de la banda del 80 % del promedio de 3,60 a 5,40; ancho máximo del 95 % de un año 18,33 (combinación de G3) y 21,99 (`MIX.PUENTE.G2`); centro de la banda de G1 2,61. §3: los 14 miembros. §4: promedios idénticos entre grupos. §5: las 18 celdas; máximo del IPC y del petróleo 0,038 pp por miembro y 0,026 pp en la combinación. §6: las 15 diferencias contra el WEO; histórico 2,55 / 2,85; 30 de 34 signos (las 4 excepciones son de `MIX.PUENTE.G2/G3`); deflactor de 2,05 a 3,75, dentro de [−1,92; 7,26]. §7: las seis satélites |
| Corrida reemplazada | Las cifras de la regla vieja que cita la nota del 2026-11-12 coinciden con las tablas de `a4c16d3`. `proyeccion_anual`, `proyeccion_trimestral`, las tres coherencias, `diagnosticos`, `satelites` y `sd_sensibilidad` son idénticas entre `a4c16d3` y `c898723` |
| Detalles delegados | 38 códigos distintos; coinciden con las listas de la ratificación del 2026-11-15 (15 revisados uno por uno, 19 en bloque, 2 vigentes de F6-09 y 2 sin efecto) |
| Remediación de Fase 5 | Tags `v0.8.0-fase5` → `1156d48` y `v0.8.1-fase5` → `c4ae7c6`. CI con R 4.6.1, `ubuntu-24.04` y BLAS de referencia (A5). Tablas versionadas desde el principio (I3). Huella por plataforma con la BLAS en la clave (I4). Intentos detenidos asentados en las dos evidencias de E3 (regla de I1). `make fase6` lanzado literalmente como orden única (M3). Los análisis posteriores AP-1 a AP-4 agregan archivos y notas, y no tocan ninguna de las cuatro tablas versionadas de `reportes_fase5/` ni las filas de Fase 5 de `07` |
| Propagación del estado de fase | `CLAUDE.md`, `README.md` y `CITATION.cff` (0.9.0 / 2026-11-19) declaran Fase 6 cerrada y el tag propuesto. El guard pasa |
| Dependencias | 27 `Imports` y 2 `Suggests` en `DESCRIPTION`, iguales a la lista de `scripts/bootstrap_renv.R`. Todo `pkg::` de `src/` y `scripts/` está declarado, salvo `renv`. `renv.lock` con 189 entradas, sin cambios desde `v0.8.1-fase5` |

---

### Límites de esta revisión

1. **No se re-ejecutó `make fase6`.** Exige la L0 privada. La corrida vigente y su reproducción descansan en sus evidencias. Las dos se hicieron en máquinas de Harold, y la reproducción la ejecutó Claude Code en la PC INVE: no son evidencia de un tercero.
2. **L3 no es accesible.** No se pudieron comprobar el mínimo, el máximo y la desviación estándar de la guarda (n = 134), los senderos de A y C (por ejemplo, el desvío trimestral máximo de 1,9 % del PIB de EE. UU.), el fin del IVAE en 2026-M08 ni el petróleo de 2027-T4 de la base.
3. **L0 no es accesible.** Las cifras del WEO, del capítulo 1, de FRED y de PCPS se cotejaron entre los documentos y los catálogos, no contra los archivos. La API del FMI no se pudo leer (robots); solo la referencia de El Salvador en 2026 y 2027 tiene corroboración externa.
4. **Lo que solo consta en el chat.** Las autorizaciones del 2026-10-17 y del 19, la ratificación del 2026-11-15 y las decisiones de Harold del 10 y el 15 de noviembre constan en texto del repositorio escrito dentro del mismo flujo. Esta revisión no puede saber qué alcance les dio Harold.
5. **GitHub.** La API no estuvo disponible. Las páginas públicas dan la conclusión de cada run, pero no el estado de cada job ni quién fusionó cada PR. El PR #95, cerrado y con su rama borrada, se leyó solo en su página pública.
6. **Decisiones como dadas.** Se revisó si el código y los registros cumplen lo decidido y quién lo decidió, no si F6-09-c es mejor que F6-09-a/b ni si las satélites son la mejor especificación.
7. **Análisis posteriores de Fase 5** (PR #63 a #69). Están en el rango desde el último tag, pero se revisaron solo para comprobar que no alteran lo reportado en el cierre de Fase 5.

---

### Pendientes consolidados

| # | Pendiente | Fuente | Naturaleza |
|---|---|---|---|
| 1 | Tag `v0.9.0-fase6`: Harold decide si va sobre `c898723`, como dice el registro (CI #535 en verde), con la remediación en un `v0.9.1-fase6`, o sobre el commit que ya contenga las adopciones de I2 y la nota de I1, como en Fase 5 (A4 = a). En los dos casos, citando el run de CI del commit tageado | registro | Decisión de Harold |
| 2 | Adopción por Harold de las tres lecturas delegadas y de las decisiones principales de F6-14 a F6-18, con nota fechada en la senda §4 y en el registro | I2 | Decisión de Harold; antes del tag |
| 3 | Sensibilidad de la regla preregistrada reportada junto a la vigente en el informe §5, con el desvío rotulado; notas fechadas en F6-09, en el §8 del protocolo y en el registro. Cuál regla es la principal | I1 | Decisión de Harold y registro; sin volver a correr |
| 4 | Enmienda o nota fechada en ADR-002 sobre la fuente de EE. UU.; nota junto al `[x]` del «Registro» de `supuestos_escenarios.md`; ADR-002 en la columna «Documento enmendado» del acta | I3 | Decisión de Harold; antes del tag |
| 5 | Nota sobre las horas de la PC INVE en la evidencia y en el checklist; revisar su reloj; «antes de» por ancestría | M1 | Registro |
| 6 | Nota en E2: qué columnas versionó la medición además de las dos cifras de F6-13 (d) | M2 | Registro |
| 7 | Notas fechadas en el protocolo (§1, §10 y §11) y en `evidencia_corrida_fase6.txt`; la decisión de Harold del 2026-11-15 sobre las tablas, en `decisiones_fase6.md` | M3 | Registro |
| 8 | Sección `07` de `catalogos/README.md` con las filas de Fase 6; el cambio de `337abb2` en F6-12-b | M4 | Registro |
| 9 | Línea de Fase 0 del `README.md`, «Estado general» del índice de ADR, `ubuntu-latest` en `CLAUDE.md`, banda del §4 del informe, PR #95 | M5 | Cosmético |
| — | *Para Fase 7:* un canario determinista de los senderos de insumo de toda regla de escenario o sensibilidad, antes de congelar. Y, si vuelve a delegar, las exclusiones escritas en la regla 4. El criterio de Fase 7 (un investigador externo actualiza el sistema siguiendo el manual) es justamente el que ninguna revisión ha podido ejercer hasta ahora, porque L0 es privada | I1, I2; límite 1 | Recomendación |
| — | *Abiertos por diseño, no tocar:* raíces del BVAR (bandas con h > 8 con cautela), petróleo sin movimiento en A y C, satélites con residuos independientes, bandas `sin_calibrar`, 2020-2021 dentro de los residuos y precisión de las proyecciones (AP-2) | registro de cierre | Declarados |

**Fila sugerida para `doc/auditorias/README.md`** (la deposita Harold):

`| auditoria_independiente_fase6_SIE-el-salvador.md | 2026-11-19 | c898723 (cierre de Fase 6; tag v0.9.0-fase6 propuesto) | I1–I3, M1–M5 | — |`

---

### Veredicto

**¿Está genuinamente cerrada Fase 6, y bien certificado el cierre? En el fondo, sí. En la certificación, todavía no.**

La fase hizo lo que la senda pedía:
- definió tres escenarios y una sensibilidad con fuentes publicadas, capturadas a L0 por *script* y citadas hasta la celda;
- proyectó 2026-2030 con intervalos, una guarda y una combinación fijadas antes de la primera corrida;
- reprodujo bit a bit las 28 salidas en una segunda máquina;
- declaró condicionales todas sus cifras.

Esta revisión ejecutó el sistema en una tercera máquina y no encontró ni un fallo. Las cifras recalculables coinciden todas, y las tablas versionadas son, byte a byte, las salidas que certifica la corrida. Que los modelos queden entre 0,7 y 1,7 pp por debajo del WEO se reporta como resultado y no se maquilla.

Los tres IMPORTANTES delimitan qué está certificado y quién lo certifica:
- **I1** es la tercera fase seguida con un hallazgo de «reglas antes que resultados», y el de más consecuencia. Por primera vez cambió una cifra reportada, y el informe omite la que daba la regla preregistrada. La corrección pudo ser buena idea; lo que falta es decirlo como desvío y mostrar las dos.
- **I2** repite I2 de Fase 5 en lo que más pesa: el criterio de cierre quedó leído por el agente y «se puede reabrir». La ratificación de los 38 detalles muestra que el remedio funciona; falta aplicarlo a las lecturas y a las cinco fichas que se decidieron fuera del texto de la delegación.
- **I3** deja a ADR-002 diciendo lo contrario de lo implementado. La serie de ADR solo sirve de especificación si se enmienda cuando la práctica se aparta.

Nada de esto exige volver a correr `make fase6`. Con I2 e I3 resueltos por Harold antes del tag, y con I1 resuelto reportando las dos sensibilidades con su cronología, «Fase 6 cerrada» significa lo que la senda §4 quiere que signifique.

---

### Fe de erratas del auditor (2026-11-19, antes de depositar el informe)

Al preparar el prompt de remediación, el propio auditor releyó contra el repositorio cada texto citado y encontró tres imprecisiones en la versión entregada a Harold el 2026-11-19. Se corrigen aquí, sin editar el texto de arriba; ninguna cambia un hallazgo ni su severidad.

1. **M4.** Dice que *«las 42 filas de Fase 6 no cumplen ninguna de las cuatro cosas»*. No es exacto para `modelo_id`: 39 de las 42 filas resuelven contra `06_modelos/`; solo las tres `COMBINACION` no lo hacen. Las 42 sí difieren del diccionario en las otras tres cosas (quién las escribe, la gramática de `esquema_validacion` y `horizontes`).
2. **M1.** Cita *«sobre b1376df»* como texto de la evidencia de la corrida reemplazada. Esa evidencia dice *«Commit: b1376df (main, merge del PR #93, congelamiento E1)»*; «sobre `b1376df`» es la redacción del ítem E3 del checklist. El hecho no cambia.
3. **M5.** Señala `ubuntu-latest` solo en `CLAUDE.md`. `README.md` (línea 52) dice lo mismo: *«confirmado en CI sobre `ubuntu-latest`»*.

---

### Nota de remediación (2026-11-20)

Agregada por quien remedió; el informe de arriba se conserva sin editar.

| Hallazgo | Resolución | Commit (merge) |
|---|---|---|
| I1 | Nota de corrección en F6-09, en el §8 del protocolo y en el registro; sensibilidad de la regla preregistrada versionada y reportada en el §5 del informe; prueba de reconstrucción de las tablas | `5c22229` (PR #103), `04dbc3c` (PR #104) |
| I2 | Adopción por Harold de las tres lecturas (senda v0.13) y de F6-14 a F6-18; delegaciones futuras en la regla 4 de `CLAUDE.md` | `5c22229` (PR #103) |
| I3 | Enmienda de ADR-002 (A5 = a), con notas en el «Registro» de los supuestos y en el acta | `5c22229` (PR #103) |
| M1 | Nota sobre las horas de la PC INVE en la evidencia reemplazada y en el checklist | `8b20b5a` (PR #105) |
| M2 | Nota en la medición previa del BVAR | `5c22229` (PR #103) |
| M3 | Notas en el protocolo (§10, §11) y en la evidencia reemplazada; decisión del 2026-11-15 en el acta | `8b20b5a` (PR #105) |
| M4 | Diccionario de `07` para Fase 6; nota en F6-12 | `8b20b5a` (PR #105) |
| M5 | `README.md`, «Estado general» del índice de ADR, `ubuntu-24.04`, nota en el §4 del informe, nota del PR #95 | `8b20b5a` (PR #105) |

CI verde: run 541 sobre `04dbc3c` y run 544 sobre `8b20b5a`. Tags: `v0.9.0-fase6` → `04dbc3c`; `v0.9.1-fase6`, aún no creado: lo crea Harold después del merge de este depósito.

Pendiente declarado: el reloj de la PC INVE (M1) no se ha revisado todavía (A7).
