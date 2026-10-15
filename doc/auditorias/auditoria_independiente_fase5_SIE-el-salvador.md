## Auditoría independiente — cierre de Fase 5 (estimación y comparación, Ejercicio A), SIE El Salvador

**Repositorio auditado:** `github.com/hsssst00/SIE-el-salvador` (clon fresco de `origin/main`, no tarball ni árbol de trabajo).
**HEAD real de `main`:** `7093f7c` — *"Merge pull request #54 from hsssst00/fase5/cierre"* (2026-10-13 00:12 -0600). 376 commits en total.
**Commit auditado:** `7093f7c`, que contiene el registro «Cierre de Fase 5» de `doc/adr/README.md`, la nota de la senda v0.9, la evidencia y la propagación de estado. Rango de la fase: `v0.7.1-fase4..7093f7c`, 138 commits (32 merges), 136 archivos, +14 033 / −467 líneas.
**Tags:** `v0.1.0-fase0`, `v0.2.0-fase0-enmendado`, `v0.2.1-fase0-enmendado`, `v0.4.0-fase1`, `v0.5.0-fase2`, `v0.5.1-fase2`, `v0.6.0-fase3`, `v0.7.0-fase4`, `v0.7.1-fase4`. **`v0.8.0-fase5` no existe todavía**: el registro lo deja propuesto y a cargo de Harold (F3 del checklist).
**Encargada por:** Harold, 2026-10-13 (ítem F3 del checklist de Fase 5).
**Ejecutada por:** Claude (modelo configurado `claude-opus-5-5`), fuera de las sesiones que produjeron la fase.

**Método.** El de la serie (sección siguiente), con la ejecución del código que introdujo la revisión de Fase 4. Se instaló R 4.6.1 (la versión de `renv.lock`) en Ubuntu 24.04 y se restauró el entorno con `renv::restore()` (189 entradas). Sobre `7093f7c` se corrieron la batería `testthat`, la verificación sintética V1-V21 y los validadores de catálogos y de L0. La verificación sintética se corrió dos veces: con OpenBLAS y con la BLAS/LAPACK de referencia, porque la primera corrida mostró que una línea de la evidencia de Fase 4 depende de esa librería (I4). Todo lo recalculable se recalculó por separado en Python sobre el contenido commiteado. El estado de CI se leyó en las páginas públicas de GitHub Actions; la API REST devolvió 403. El historial de chats y la memoria del proyecto se consultaron **solo para ubicar la metodología de las revisiones previas**; ningún hecho de este informe sale de ahí.

---

### Metodología heredada de las revisiones anteriores

Se aplica el protocolo asentado en las siete revisiones de `doc/auditorias/` (Fase 0 a Fase 4):

1. **Fuente única de verdad:** clon fresco de `origin/main`. Nunca resúmenes de sesión, mensajes de commit ni autorreportes.
2. **Nada se rellena desde el chat.** Lo que solo se explicaría por contexto de conversación es hallazgo.
3. **Lectura del contenido, no del diff** (`git show <rev>:<ruta>`).
4. **Recálculo independiente** de toda cifra recalculable.
5. **Ejecución de los controles del propio proyecto** (desde la revisión de Fase 4).
6. **Severidad en tres niveles** (`C#`, `I#`, `M#`), con los criterios y precedentes de la revisión de Fase 4.
7. **Estructura fija del informe.** La nota de remediación la agrega quien remedia.
8. **Sin autoridad decisoria.** Las decisiones de nivel D son de Harold (regla 4 de `CLAUDE.md`).

**Batería de verificaciones recurrentes** y resultado en este cierre:

| # | Verificación | Origen | Resultado ahora |
|---|---|---|---|
| 1 | Estado de fase propagado a `CLAUDE.md` y `README.md` | F0 C2, F1v C1, F2 C1 | Limpio; segundo cierre seguido sin reincidencia |
| 2 | Celda del índice de ADR = línea `**Estado:**` | F0 C3, F1v C1 | Limpio (el guard pasa) |
| 3 | El tag apunta al commit de cierre | F0 C2 | Tag pendiente; ver pendiente 1 |
| 4 | CI en verde sobre el commit certificado | F0 C2; límite 3 de F2 | Limpio sobre `7093f7c` y `e1722fa`; **rojo sobre el commit del intento 3 (I1)** |
| 5 | `CITATION.cff` al día | F0 M4, F2 M1, F4 M1 | Limpio: el guard de la remediación de Fase 4 funcionó |
| 6 | Dependencias usadas = declaradas | F2 M1, F3 I3, F4 M2/M6 | Limpio (27 Imports, 2 Suggests, bootstrap = `DESCRIPTION`) |
| 7 | Conteos transcritos a mano | F3 M5, F4 M2 | Limpio en paquetes; **un conteo de paradas (M2)** |
| 8 | Nombres o comentarios que prometen otra cosa | F2 M2, F4 M3 | **Reincide, leve (M2)** |
| 9 | Evidencia que un tercero no puede re-derivar | F1 I3, F2 I2 | **I3** |
| 10 | Independencia de quien decide y de quien revisa | F2 I2, F4 M5 | Esta revisión; **delegación de decisiones (I2)** |
| 11 | Fallo silencioso en transformación o validación | F3 C1 | Guardas limpias; pronósticos explosivos declarados (pendiente 8) |
| 12 | Cifras de la certificación recalculadas | todas | Limpio en todo lo recalculable |
| 13 | Reglas antes que resultados | F4 I1 | **I1** |
| 14 | *Nueva:* reproducibilidad entre entornos | F5-15, F1-3 | **I4** |

---

### Resumen para orientarse

**En el fondo, el cierre de Fase 5 se sostiene.** Los 32 modelos, las 12 combinaciones y los 6 benchmarks entraron en `catalogos/06_modelos/` antes del congelamiento (`f8fe345`). Después de él solo cambió un YAML (`UNI.UC_LLT`, declarado). La corrida única quedó registrada con árbol limpio y CI verde. Cada cifra del registro que sale de la tabla versionada se recalcula igual. El informe de lectura aplica sin atajos la regla de reporte del MCS. La conclusión central es que el MCS conserva los 21 a 23 modelos en las 12 celdas y no hay ganador. Es el resultado que la senda §5.4 anticipaba como legítimo, y se reporta así.

**Ejecución en una tercera máquina:**
- Batería: **2954 PASS / 0 FAIL / 0 SKIP / 0 ERROR** en 387 bloques `test_that`.
- Verificación sintética: **V1-V21 en OK**.
- Validadores de catálogos y de L0 cruzada (75 vintages): salida 0.
- Con la BLAS de referencia, las 28 líneas de V1-V11 son **idénticas byte a byte** a `doc/evidencia_cierre_fase4.txt`.

**Hallazgo nuevo de esta revisión:** con OpenBLAS una de esas 28 líneas cambia: el hash de V10. Y el random forest de V20 da el valor de Windows (0,626) con la BLAS de referencia en Linux y el de CI (0,638) con OpenBLAS. La frontera de la reproducibilidad bit a bit no es el sistema operativo, como dice el cierre, sino la librería BLAS/LAPACK. Los manifiestos la dejan anotada dentro de `sessionInfo()`, pero ni la columna `entorno`, ni las lecturas del criterio, ni la declaración de paridad la usan (I4; ver la fe de erratas al final).

**No hay hallazgos críticos.** Hay cuatro IMPORTANTES:

- **I1:** el protocolo §6 afirma que *«ningún resultado de Fase 5 existía»* antes de los cambios posteriores al congelamiento. La evidencia commiteada muestra lo contrario: cinco experimentos `F5_G*`, incluidos los tres principales, ya estaban escritos cuando se decidió E2-2. Ningún dato cambió por eso (byte a byte), pero la afirmación es falsa. Además, la regla de citar el commit de la corrida, fijada en la remediación de Fase 4, no se aplicó.
- **I2:** las cuatro lecturas del criterio de cierre las tomó el agente, *«delegadas, se pueden reabrir»*. En Fases 1 a 4 las adoptó Harold. También son del agente los dos cambios posteriores al congelamiento y al menos otras 23 decisiones. La regla 4 de `CLAUDE.md` no registra esa delegación.
- **I3:** una parte de lo que el cierre reporta no se puede re-derivar desde el repositorio: DM/HLN, GW, el contraste de estabilidad y los pronósticos explosivos. Solo existe en `data/L4_experiments/`, que no se versiona. El entregable «pruebas DM/GW» de la senda no tiene ninguna forma versionada.
- **I4:** la paridad entre sistemas que declara el cierre está verificada solo para el BVAR. Omite `UNI.UC_LLT`, cuya convergencia depende de la plataforma, y atribuye al sistema operativo lo que depende de la BLAS.

**Ninguno pide volver a correr el motor.** I1 e I2 se resuelven con notas fechadas y conviene cerrarlos **antes de crear el tag**. I3 e I4 se resuelven generando por código, desde la L4 que ya existe, una tabla de pruebas versionada y registrando la BLAS. Hay cinco MENORES.

---

### Hallazgos — CRÍTICO

Ninguno.

---

### Hallazgos — IMPORTANTE

#### I1. El protocolo afirma que no existía ningún resultado de Fase 5 antes de los cambios posteriores al congelamiento, y la evidencia del propio repositorio dice lo contrario

El criterio de Fase 4 sigue rigiendo: *«definir las reglas después de ver los resultados invalida el ejercicio»*. Para Fase 5, el preregistro (F5-02) se congeló en `f8fe345`. La nota «E2; cambios después del congelamiento» del protocolo §6 cierra así:

> «Ningún resultado de Fase 5 existía antes de estos cambios, así que la comparación sigue preregistrada.»

La cronología que prueba git, junto con `doc/evidencia_corrida_unica_fase5.txt`, es esta:

| Momento (git, -0600) | Commit | Qué pasó |
|---|---|---|
| 10-08 12:14 | `f8fe345` | Congelamiento del preregistro |
| 10-08 13:14 / 14:35 | `e34ccad`, `39884c6` | Correcciones de los intentos 1 (G-6) y 2 (E2-1, UC). Ningún `F5_G*` había terminado |
| 10-08 14:55 | `189e629` | Merge del PR #48. **CI #333 en rojo** sobre este commit (la prueba de UC dependía de la plataforma; la arregló `b400a25`) |
| — | intento 3 sobre `189e629` | Según la evidencia, escribe `F5_G1`, `F5_G2`, `F5_G3`, `F5_G1_R1` y `F5_G2_R1` y se detiene en `F5_G3_R1`, h = 8 (GW con Ω singular) |
| 10-08 17:00 | `51cc015` | Se agrega `tabla_resultados_fase5.R`, el formato de la tabla de resultados |
| 10-08 18:44 | `cf26a62` | E2-2, primera versión (decisión delegada) |
| — | intento 4 sobre `c63f318` | Vuelve a escribir los mismos cinco experimentos y se detiene en la misma celda |
| 10-08 22:34 | `d8d045e` | E2-2 generalizada |
| 10-08 23:09 | `e1722fa` | Corrida citada (intento 5) |

La propia evidencia lo dice: *«los 130 archivos de 18 directorios (13 F5_REPRO_*, F5_G1, F5_G2, F5_G3, F5_G1_R1, F5_G2_R1) son idénticos byte a byte en los intentos 3 (189e629), 4 (c63f318) y 5 (e1722fa)»*. Para compararlos byte a byte tuvieron que existir. Cuando se decidió E2-2, el agente que la decidió tenía en disco los resultados completos de la corrida principal.

**Lo que se cumple:**
- Los 32 modelos, las 12 combinaciones, los 15 experimentos y el corte son anteriores a `f8fe345`.
- E2-1 es anterior a cualquier `F5_G*` terminado.
- E2-2 es una regla mecánica para un caso degenerado (Ω singular → NA marcado; d ≡ 0 → p = 1, como ya hacía DM/HLN).
- La identidad byte a byte de los intentos 3, 4 y 5 prueba que E2-2 no cambió ningún resultado ya escrito.
- `decisiones_fase5.md` está redactado con más cuidado que el protocolo: *«ninguna de las tres paradas escribió resultados de un experimento F5_G\* incompleto»*.

El daño es al registro, no a los datos. Es la misma familia que I1 de Fase 4, y la remediación de Fase 4 dejó para esto una regla en el protocolo §6: *«toda afirmación de que algo se fijó antes de un resultado cita el commit que lo fijó y el de la corrida»*. La nota no cita el commit de ningún intento. La sección 2 del informe de lectura afirma que sus seis reglas se fijaron antes de los resultados sin citar commits (esta revisión encontró antecedentes de las seis en `f8fe345`). Tampoco queda claro si `51cc015`, que da formato a la tabla, se escribió antes o después de que existiera `F5_G1`. El protocolo no lo lista entre los cambios posteriores al congelamiento.

*Remediación posible sin reabrir nada:* una nota de corrección fechada al pie de la nota E2 del protocolo §6 (y una línea en `decisiones_fase5.md`), sin editar el texto existente. Debe decir que los intentos 3 (`189e629`) y 4 (`c63f318`) escribieron los cinco experimentos antes de `cf26a62` y `d8d045e`, que E2-2 se decidió con esos resultados en disco y que la identidad byte a byte muestra que no los alteró. Debe listar también `51cc015` y `b400a25` entre los cambios posteriores al congelamiento. Para Fase 6, toda corrida sobre L3 que se detenga deja asentado qué directorios de L4 escribió.

#### I2. Las lecturas del criterio de cierre y los cambios posteriores al congelamiento son decisiones del agente, y la delegación no consta en la regla que gobierna esas decisiones

La nota de cierre de la senda (v0.9) y el registro de `doc/adr/README.md` dicen que las lecturas de «una sola orden», «reproducible», «todo resultado reportado» y «una semilla fijada» *«las tomó el agente … bajo la autorización de Harold del 2026-10-08 … son delegadas al agente y se pueden reabrir»*. En las cuatro fases anteriores la lectura del criterio la adoptó Harold; la de Fase 4 dice *«Las adoptó Harold el 2026-09-29»*.

Son decisiones de nivel D por definición. La regla 4 de `CLAUDE.md` (*«detente y pregunta»*) y `doc/auditorias/README.md` dejan esas decisiones en Harold, y el cierre de fase es la de mayor peso. El acta de `decisiones_fase5.md` marca como delegadas **al menos 25 fichas**:
- B2-16, B3-9, B3b-1 a B3b-7, B4-1 a B4-6, B5-1 a B5-5 y CF-1 a CF-3;
- E2-1 y E2-2, los dos cambios posteriores al congelamiento.

Con las cuatro lecturas del cierre, son 29. La autorización del 2026-10-08 (*«que el agente avance sin supervisión»*) solo aparece en notas escritas dentro del mismo flujo, sin alcance ni fecha de término. `CLAUDE.md` no cambió.

Dos hechos agravan la trazabilidad:
- **Autoría.** De los 106 commits no-merge del rango, 90 llevan la identidad local `Harold <harold@proyecto-pib-sv.local>` y 28 tienen el trailer `Co-Authored-By: Claude`. Un tercero solo puede distinguir lo que decidió Harold de lo que decidió el agente por los rótulos del texto.
- **Precedente de reapertura.** Una de las fichas delegadas ya se reabrió: Harold reemplazó B1b-1, y es la única reabierta.

La lectura de «una sola orden» merece atención aparte. La corrida citada **no** ejecutó `make eval`: corrió sus pasos uno por uno. La réplica de F1 usó procesos `Rscript motor_backtesting.R <exp_ids>` con otra agrupación (M3). La lectura que lo declara equivalente es razonable, pero la tomó quien ejecutó la corrida.

Ninguna de estas decisiones parece mal tomada. El problema es otro: un cierre cuyo criterio «se puede reabrir» no es todavía el cierre que la senda §4 pide declarar. Y lo que Harold merge es el PR, no cada lectura.

*Remediación posible:*
1. Antes del tag, una nota fechada y firmada por Harold en la senda §4 (y su línea en el registro de cierre) que **adopte** las cuatro lecturas, con los cambios que quiera, y adopte E2-1 y E2-2. Precedente: la adopción de la Fase 4.
2. Registrar el régimen de delegación en la regla 4 de `CLAUDE.md`, o en un ADR: desde cuándo rige, qué alcance tiene (implementación sí; lecturas de criterio, cambios posteriores a un congelamiento y reglas de evaluación no) y si sigue en Fase 6.

#### I3. Parte de lo que el cierre reporta solo existe en una capa no versionada; el entregable «pruebas DM/GW» no tiene forma versionada

El registro de cierre afirma sobre DM/HLN: *«Con h = 1 y 2, DM/HLN no rechaza a favor de ningún modelo … Con h = 8 rechaza a favor de muchos»*. Sobre los pronósticos explosivos: *«−348 pp a h = 8»* y *«−126 pp»*. El informe de lectura agrega en §3 dos columnas de p-valores y conteos DM, en §3.3 pronósticos puntuales, y en §4.3 GW y estabilidad. Su sección 1 declara la fuente: *«`pruebas.csv`, `pruebas_submuestras.csv` y `estabilidad.csv` de `data/L4_experiments/F5_*/`. No se versionan, pero `make eval` los regenera byte a byte (F1)»*.

`make eval` exige la L0 privada y unas seis horas en la máquina de Harold. En la práctica, nadie más que Harold puede comprobar esas afirmaciones. En Fase 4 la revisión independiente recalculó todas las cifras del cierre desde la tabla versionada. En Fase 5 eso solo alcanza para RMSE, MCS, densidades y marcas. La senda §4 lista entre los entregables de la fase *«pruebas DM/GW y conjunto de modelos de confianza»*. El MCS está en la tabla; DM y GW no están en ningún archivo versionado.

Es la familia de I3 de Fase 1 e I2 de Fase 2 (evidencia que un tercero no puede re-derivar), y además roza la lectura de «todo resultado reportado». La senda la define como las filas de `07`, la tabla y *«los valores del informe … que salen de esa tabla y de L4»*.

*Remediación posible, sin volver a correr el motor:*
- Un `src/evaluacion/tabla_pruebas_fase5.R` que concatene `pruebas.csv`, `pruebas_submuestras.csv` y `estabilidad.csv` de los 15 `F5_G*`, con sus marcas (`marca_tamano`, `varianza`, `n_pares`), en `doc/metodologia/reportes_fase5/tabla_pruebas_fase5.csv`.
- Un extracto versionado de los pronósticos que cita §3.3.
- Ambos con sha256 en la evidencia y generados desde la L4 de `e1722fa`, como se hizo con `marca_n` en F4-35.
- Lo mismo vale para Fase 6 desde el comienzo.

#### I4. La paridad entre sistemas que declara el cierre está verificada solo para el BVAR, omite `UNI.UC_LLT` y depende de la librería BLAS, no del sistema operativo

El registro de cierre dice: *«Entre Windows y Linux, el BVAR y el random forest no son bit a bit; la paridad se declara hasta el error de Monte Carlo (F1-3, V17)»*. La nota de la senda dice lo mismo. Esta revisión encontró tres problemas.

**(a) El RF no tiene verificación.** V17 cubre solo el BVAR. Para el RF hay una observación en `decisiones_fase5.md` (nota «CI de #44»): RMSE relativo 0,638 en Ubuntu contra 0,626 en Windows, con las mismas semillas. No hay ningún bloque que acote esa diferencia. Además, un random forest no tiene un «error de Monte Carlo» que la acote en el sentido de F1-3.

**(b) `UNI.UC_LLT` también depende de la plataforma, y no está en la lista.** La nota de F5-06 (`b400a25`) lo reconoce: *«qué series fallan desde el arranque por defecto depende de la plataforma (L-BFGS-B y la BLAS)»*. Esta revisión lo reprodujo sobre las 400 series sintéticas de la prueba:
- con OpenBLAS fallan 19, con la serie 14 entre las que convergen;
- con la BLAS de referencia fallan 18, entre ellas 14 y 26, las que usaba la prueba original escrita en Windows;
- solo 7 series son comunes a los dos conjuntos.

Sobre L3, entonces, los orígenes que usan el arranque alternativo de E2-1 (9 pares en la corrida de Windows) pueden ser otros en otra máquina. La diferencia sale del camino del optimizador, no del muestreo. La heredan las combinaciones que contienen a UC.

**(c) La frontera es la BLAS, y nadie la registra.** Con OpenBLAS (Linux), V10 imprime el hash `5d4a8e0e8620…` en todos los commits probados, incluido `c4e8b39`. Con la BLAS de referencia, en la misma máquina, imprime `f3bdc2c613bf…`, el de `doc/evidencia_cierre_fase4.txt`, y las 28 líneas de V1-V11 vuelven a ser idénticas byte a byte. Con el RF de V20 pasa lo mismo: 0,626 con la BLAS de referencia en Linux, igual que en Windows, y 0,638 con OpenBLAS, igual que en CI. Con la BLAS de referencia, la diferencia de V17 contra la referencia de Windows baja de ~1e-4 a ~1e-7 errores de Monte Carlo.

Lo que separa los resultados no es «Windows contra Linux» sino la librería de álgebra lineal, que `renv` no fija. La columna `entorno` de `07_experimentos.csv` guarda versión de R, plataforma y sha de `renv.lock`, no la BLAS. Los manifiestos de L4 sí incluyen la salida de `sessionInfo()`, que en Linux nombra la BLAS y la LAPACK en uso. Pero nada en el criterio ni en la declaración de paridad la usa como condición, y la comparación de F1 no la verifica. Un tercero que reproduzca en Linux con la BLAS de referencia puede acercarse bastante más a la corrida de Harold de lo que el cierre sugiere. Uno con OpenBLAS se aleja más, y ninguna regla del cierre le dice cuál de las dos debe usar.

*Remediación posible:*
1. Una nota fechada que asiente la BLAS y la LAPACK de la corrida de Harold, tomadas del `sessionInfo()` de los manifiestos de `e1722fa`, y que declare que la reproducción bit a bit exige la misma librería. Desde Fase 6, que la comparación de reproducibilidad verifique esa línea del manifiesto antes de comparar resultados.
2. Corregir con nota fechada la frase del cierre. Debe listar los modelos sensibles al entorno (BVAR, RF, `UNI.UC_LLT` y las combinaciones que los contienen) y decir que la paridad del RF y de UC no está acotada.
3. Valorar que CI fije la BLAS de referencia, para que «bit a bit» signifique lo mismo en CI y en Windows.

---

### Hallazgos — MENOR

**M1. El checklist de Fase 5 declara la fase cerrada con seis ítems en `[ ]`.** Son C1 (guarda de 20 grados de libertad), C2 (alineación y G-7), C5 (densidades), D1 (B1), D2 (B2) y D6 (B5). Los seis están fusionados y con CI verde en `main`: #31 (`8d72e83`, run #255), #32 (`ad47bc1`, #260), #33 (`821eaac`, #265), #34 (`a91b791`, #268), #37 (`ac958a8`, #283) y #45 (`c2598f4`, #323). Es la familia de M4 de Fase 4. La convención del tablero pide marcar con la evidencia citada.

**M2. Registros que no siguieron a los hechos.**
- `decisiones_fase5.md`, «Corrida única (E2)»: dice *«La corrida única se detuvo tres veces»*, y la evidencia registra cuatro paradas (maestro, UC, GW y GW otra vez).
- La cabecera de `verificar_motor_sintetico.R` (línea 32) describe V5 como *«UT solo con años cerrados»*; para Fase 5 rige el rezago supuesto de 30 días. El bloque mismo lo aclara.
- El protocolo §2.3 conserva *«su forma operativa y su implementación siguen pendientes»* sobre F4-34, resuelta el mismo 2026-09-29. La nota del 2026-10-07 aclara la tabla, no esa frase.

Es la familia de M2 de Fase 2 y M3 de Fase 4.

**M3. «Una sola orden» nunca se ejecutó como una sola orden.** La receta real son dos órdenes (`make master …` y `make eval …`), y E2 las corrió paso a paso. No existe un objetivo de `Makefile` que encadene las dos con el corte de Fase 5. Un objetivo `fase5` (o `reproducir-fase5`) con `CONJUNTO` y `SALIDA` fijos convertiría la lectura de I2 en un hecho literal.

**M4. El corte del BCR de ADR-008 (2026-10-12) venció sin registro.** ADR-008 dispone que, si no hay pronunciamiento a esa fecha, *«se documenta en este mismo ADR la ausencia de pronunciamiento»* y se resuelve la decisión de política de L0 aplazada por el caso del Banco Mundial. Al día siguiente, el ADR sigue igual y el registro de cierre no lo menciona. El de CEPAL vence el 2026-10-16. No toca el criterio de Fase 5, pero es una decisión de Harold con plazo propio. Esta revisión no puede saber si el BCR respondió.

**M5. CI no fija la versión de R y cambia de imagen en seis días.** `.github/workflows/ci.yml` usa `r-version: 'release'` y no 4.6.1, la del lockfile. `ubuntu-latest` pasa a Ubuntu 26 el 2026-10-19 (anotación de los runs #351 y #354). El CI que respalde el tag deja de ser reproducible en cuanto cambie cualquiera de las dos cosas. Conviene crear el tag antes del 19, citar en su mensaje el run sobre el commit tageado, y fijar R (y la BLAS, por I4) en el workflow.

---

### Verificaciones que resultaron limpias (con las cifras)

| Verificación | Resultado |
|---|---|
| `testthat::test_dir("tests")` sobre `7093f7c` (Ubuntu 24.04, R 4.6.1, `renv::restore()`, OpenBLAS, locale UTF-8) | **2954 PASS / 0 FAIL / 0 SKIP / 0 ERROR**, 387 bloques, 4 min 26 s; el mismo resultado con la BLAS de referencia. La prueba de UC no se salta en ninguna de las dos |
| Verificación sintética, OpenBLAS | V1-V21 OK, 12 min 11 s. Las 28 líneas de V1-V11 coinciden con la evidencia de Fase 4 salvo el hash de V10 (I4) |
| Verificación sintética, BLAS de referencia | V1-V21 OK. Las 28 líneas de V1-V11, **idénticas byte a byte** a `doc/evidencia_cierre_fase4.txt`. V17: 0 decisiones del MH distintas de 5000 en G1 y G3; diferencia máxima contra Windows ~1e-7 errores de Monte Carlo |
| `validate_catalogs.R`, `validar_integridad_catalogos.R`, `check_l0_integrity.R` | los tres con salida 0; L0 cruzada con 75 vintages |
| CI | run #354 (38355440802) sobre `7093f7c` en verde (los dos jobs, 14 min 03 s). Run #351 sobre `c74c54e`, el que cita el registro, en verde. Run #341 sobre `e1722fa`, el commit de la corrida, en verde. Merges de B1, B2a, B2b y B5 en verde |
| Preregistro (C8, F5-02) | los 51 YAML de `06_modelos/` (plantilla, 6 benchmarks, 12 combinaciones y 32 modelos) se agregaron antes de `f8fe345`. Después solo cambió `UNI.UC_LLT.yaml` (`39884c6`, E2-1, declarado). `corte_fase5.csv` no cambió desde `54dfb6c`; sha256 sin CR `901b0f79…`, el que citan la evidencia y los manifiestos |
| Cambios de código después del congelamiento | 11 archivos, +182/−27, en seis commits: `e34ccad`, `39884c6`, `51cc015`, `cf26a62`, `d8d045e` y `b400a25`. Ninguno toca un benchmark ni un YAML salvo UC |
| `catalogos/07_experimentos.csv` | 424 filas = 78 `F4_BENCH_*` (sin cambios, `c4e8b39`) + 78 `F5_REPRO_*` + 268 `F5_G*`. Las 346 de Fase 5 tienen `commit_hash` `e1722fa`. `modelo_id` resuelve contra `06_modelos/` en 424/424. Cada componente de `vintage_id` resuelve contra `08_vintages.csv`. 268 semillas distintas en 268 filas `F5_G*`. `entorno`: sha256 de `renv.lock` sin CR recalculado `fae32aacc3dc`, igual al declarado |
| `doc/metodologia/reportes_fase5/tabla_resultados_fase5.csv` | sha256 sin CR recalculado `29218ad0866b…4e94`, igual al declarado; 1960 filas, 15 experimentos, 0 bytes CR, 19 columnas |
| `tabla_resultados_fase4.csv` | sha256 `8c1581e4…`, sin cambios desde la remediación de Fase 4 |
| Cifras del registro y del informe de lectura | todas las recalculables coinciden: MCS completo en las 12 celdas (23/22/21 modelos); p_MCS mínimo 0,2232 (G3, h = 8); menor RMSE relativo con h = 1 de 0,799 (`MIX.UMIDAS.G1`), 0,445 y 0,503 (`MIX.PUENTE` en G2 y G3); `BENCH.ARP_BIC` con el menor RMSE con h = 8 en los tres grupos; en R4 `sin_2020_2021`, el paseo sin deriva sale del MCS en G1 y G2 con h = 1, 2 con n = 44/43/37/36 y nadie más sale; R7 con 80 de 112 comparaciones idénticas, cambio máximo de 0,069 fuera de `MULT.BVAR.G3` (0,719) y puente en h = 1 de 0,44 y 0,51; seis bloques con `marca_n` (G2 `pre2020` con h = 4 y 8, y G3 `sin_2020_2021` en los cuatro h); RMSE relativo del ENET de G3 de 10,5 (h = 4) y 22,9 (h = 8), dentro del MCS |
| Propagación del estado de fase | `CLAUDE.md`, `README.md` y `CITATION.cff` (0.8.0 / 2026-10-13) declaran Fase 5 cerrada y el tag propuesto. El guard pasa |
| Dependencias | 27 `Imports` y 2 `Suggests` en `DESCRIPTION`, iguales a la lista de `scripts/bootstrap_renv.R`. Todo `pkg::` de `src/` está declarado, salvo menciones en comentarios. 189 entradas en `renv.lock`; los conteos de `CLAUDE.md` y `README.md` coinciden |
| Remediación de Fase 4 | `v0.7.1-fase4` → `70e7b35`; nota de remediación al final del informe de Fase 4 e índice de `doc/auditorias/` actualizados; compuerta A1 de Fase 5 (`b9b793e`) antes del primer modelo |
| Lectura del MCS | el informe aplica la regla de reporte (no hay ganador) y dice que en G3 con h ≥ 4 pertenecer al MCS no informa nada: un modelo con RMSE relativo de 22,9 sigue dentro con p 0,22 |

---

### Límites de esta revisión

1. **No se re-ejecutó `make eval`.** Exige la L0 privada y unas seis horas. La corrida única, los 28 experimentos byte a byte y los usos de E2-1 y E2-2 descansan en `doc/evidencia_corrida_unica_fase5.txt`. Las tres corridas y la réplica se hicieron en la máquina de Harold, así que no son evidencia de un tercero.
2. **Lo que vive solo en L4** (DM/HLN, GW, estabilidad, pronósticos de §3.3) no se pudo comprobar (I3).
3. **Logs de CI.** Las páginas públicas dan la conclusión de cada run, pero no el conteo de SKIP ni la BLAS del runner. Que CI use OpenBLAS se infiere de que el RF da en CI el mismo valor que con OpenBLAS aquí (0,638).
4. **Decisiones como dadas.** Se revisó si el código y los registros cumplen lo decidido, no si las 29 decisiones delegadas son las mejores (I2 trata solo de quién las adopta).
5. **La autorización del 2026-10-08** solo consta en el texto del repositorio. Esta revisión no puede saber qué alcance le dio Harold.

---

### Pendientes consolidados

| # | Pendiente | Fuente | Naturaleza |
|---|---|---|---|
| 1 | Tag `v0.8.0-fase5`: Harold decide si va sobre `7093f7c`, como dice el registro, con la remediación en un `v0.8.1-fase5` (precedente de Fase 4), o sobre el commit que ya contenga la adopción de I2. En los dos casos, antes del 2026-10-19 y citando el run de CI del commit tageado | registro; M5 | Decisión de Harold |
| 2 | Adopción de las cuatro lecturas del criterio y de E2-1 y E2-2 con nota fechada de Harold; régimen de delegación en la regla 4 de `CLAUDE.md` o en un ADR | I2 | Decisión de Harold; antes del tag |
| 3 | Nota de corrección al protocolo §6 (E2) y a `decisiones_fase5.md`: intentos 3 y 4, `51cc015` y `b400a25`; citar commits en «fijado antes de» | I1 | Registro |
| 4 | `tabla_pruebas_fase5.csv` y extracto de pronósticos citados, generados desde la L4 de `e1722fa`, con sha256 | I3 | Evidencia; sin volver a correr el motor |
| 5 | Nota con la BLAS/LAPACK de la corrida (desde el `sessionInfo()` de los manifiestos) como condición de la reproducción bit a bit; corregir la frase de paridad (agregar UC y combinaciones, y decir que RF y UC no están acotados); valorar la BLAS de referencia en CI | I4 | Reproducibilidad |
| 6 | Marcar C1, C2, C5, D1, D2 y D6 del checklist con su evidencia | M1 | Registro |
| 7 | «tres veces» → cuatro paradas; cabecera de V5; frase de §2.3 | M2 | Cosmético |
| 8 | Objetivo `make fase5` (master + eval con el corte) | M3 | Higiene |
| 9 | ADR-008: registrar el vencimiento del corte del BCR y resolver la política de L0; CEPAL vence el 2026-10-16 | M4 | Decisión de Harold; con plazo |
| 10 | Fijar `r-version: 4.6.1` (y la BLAS) en CI | M5 | Higiene |
| — | *Compuerta sugerida para Fase 6, antes de proyectar:* regla de selección o combinación de modelos para el Ejercicio B, y guarda de plausibilidad de los pronósticos (el ENET llegó a ±348 pp sin que ninguna guarda lo detuviera), fijadas con commit antes de la primera proyección. Fase 6 llega a h = 20 | registro de cierre (abiertos); §3.3 de la lectura | Recomendación |
| — | *Abiertos por diseño, no tocar:* pronósticos explosivos no diagnosticados; tamaño de GW y del contraste de estabilidad sin verificar; manifiesto de L4 dependiente de la secuencia; rezago de UT supuesto (R7 lo acota); motor que acepta cualquier `CONJUNTO`; acta sin filas B2-1 a B2-16; V20 con dos réplicas (comprobación débil declarada); D5 | registro de cierre | Declarados |

**Fila sugerida para `doc/auditorias/README.md`** (la deposita Harold):

`| auditoria_independiente_fase5_SIE-el-salvador.md | 2026-10-13 | 7093f7c (cierre de Fase 5; tag v0.8.0-fase5 propuesto) | I1–I4, M1–M5 | — |`

---

### Veredicto

**¿Está genuinamente cerrada Fase 5, y bien certificado el cierre? En el fondo, sí. En la certificación, todavía no del todo.**

La fase hizo lo que la senda pedía:
- implementó el núcleo mínimo viable más la frecuencia mixta;
- preregistró todo antes de tocar L3;
- corrió una sola vez sobre un corte congelado;
- reprodujo los 28 experimentos byte a byte en la máquina de la corrida;
- leyó los resultados con las reglas que se había impuesto.

El resultado, sin ganador en el MCS, se reporta como resultado y no se maquilla. Esta revisión ejecutó el sistema en una tercera máquina y no encontró ni un fallo. Las cifras recalculables coinciden todas. Con la BLAS de referencia, la verificación de Fase 4 vuelve a dar idéntica byte a byte.

Los cuatro IMPORTANTES delimitan qué está certificado y quién lo certifica:
- **I1** es la reincidencia de la familia que la Fase 4 quiso cerrar con una regla: una afirmación de «antes de los resultados» sin commit que la respalde, y esta vez falsa en su letra, aunque inocua en sus datos.
- **I2** es la más importante para el proyecto: el criterio de cierre quedó leído por el agente que ejecutó la fase, en un régimen de delegación que no está escrito donde rigen las reglas. Mientras Harold no adopte esas lecturas, el cierre «se puede reabrir» por definición.
- **I3 e I4** acotan el alcance de «reproducible»: parte de lo reportado solo existe en una capa privada, y la frontera de la reproducción bit a bit es la librería BLAS, que ninguna regla del cierre fija.

Nada de esto exige volver a correr el motor. Con I1 e I2 resueltos antes del tag, y con I3 e I4 resueltos por código sobre la L4 que ya existe, «Fase 5 cerrada» significa lo que la senda §4 quiere que signifique, y Fase 6 empieza con sus reglas de selección fijadas antes de proyectar.

---

### Fe de erratas del auditor (2026-10-13, antes de depositar el informe)

La primera versión de este informe, entregada a Harold el 2026-10-13, decía en I4(c) que *«ni la columna `entorno` … ni los manifiestos de L4 la registran»* (la BLAS). Es falso en la mitad de los manifiestos. `escribir_experimento()` de `motor_backtesting.R` agrega al final de cada `manifiesto.txt` la salida de `utils::sessionInfo()`, y en Linux esa salida nombra la BLAS y la LAPACK en uso (`BLAS: …/libblas.so.3`). Se corrigieron el resumen, I4(c), su remediación 1, el pendiente 5 y el veredicto. El hallazgo se mantiene con la misma severidad: ni `entorno`, ni las lecturas del criterio, ni la declaración de paridad, ni la comparación de F1 usan la BLAS como condición de la reproducción bit a bit. El error lo detectó el propio auditor al preparar el prompt de remediación, releyendo el código del manifiesto; no lo señaló un tercero.
