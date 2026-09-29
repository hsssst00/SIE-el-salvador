## Auditoría independiente — cierre de Fase 4 (protocolo de evaluación), SIE El Salvador

**Repositorio auditado:** `github.com/hsssst00/SIE-el-salvador` (clon fresco de `origin/main`, no tarball ni árbol de trabajo).
**HEAD real de `main`:** `4ea39ea` — *"Actualizar el recuento de ADR en la estructura README"* (Harold, 2026-09-29 10:34 -0600). 226 commits en total.
**Commit auditado:** `a67bde9` — *"Merge pull request #23 from hsssst00/fase4/cierre"* (2026-09-29 10:07 -0600), al que apunta el tag anotado **`v0.7.0-fase4`** (objeto `9965c10`). Rango de la fase: `v0.6.0-fase3..v0.7.0-fase4`, 66 commits (14 merges), 53 archivos.
**Tags:** `v0.1.0-fase0`, `v0.2.0-fase0-enmendado`, `v0.2.1-fase0-enmendado`, `v0.4.0-fase1`, `v0.5.0-fase2`, `v0.5.1-fase2`, `v0.6.0-fase3`, `v0.7.0-fase4`.
**Encargada por:** Harold, 2026-09-29 (ítem F5 del checklist de Fase 4).
**Ejecutada por:** Claude (modelo configurado `claude-opus-5-5`), fuera de las sesiones que produjeron la fase.

**Método.** El de las revisiones anteriores (sección siguiente), con una diferencia: por primera vez la revisión **ejecuta el código del proyecto**. Se instaló R 4.6.1 —la versión que fija `renv.lock`— en Ubuntu 24.04 y se restauró el entorno completo con `renv::restore()` (188 paquetes). Con eso se corrió la verificación sintética V1-V11, la batería `testthat` y los validadores de catálogos y de L0, sobre `c4e8b39` (commit de la corrida de cierre) y sobre `a67bde9` (tag). Todo lo demás se recalculó por separado en Python a partir del contenido commiteado (`git show <rev>:<ruta>`). El estado de CI se leyó en las páginas públicas de GitHub Actions: la API REST devolvió 403. Se consultaron el historial de chats y la memoria del proyecto **solo para ubicar la metodología de las revisiones previas**; ningún hecho de este informe sale de ahí.

---

### Metodología recopilada de las revisiones independientes anteriores

Esta revisión aplica el protocolo que se fue asentando en las seis revisiones de `doc/auditorias/`, de Fase 0 a Fase 3:

1. **Fuente única de verdad.** Clon fresco de `origin/main`. Nunca el árbol de trabajo, resúmenes de sesión, mensajes de commit ni autorreportes. La interna de Fase 2 no lo cumplió, y por eso la independiente la corrigió (I2).
2. **Nada se rellena desde el chat.** Lo que solo se explicaría por contexto de conversación se registra como hallazgo (Fase 0, Fase 1, Fase 2).
3. **Lectura del contenido, no del diff.** `git show <rev>:<ruta>` para cada archivo en cada commit relevante (verificación de la remediación de Fase 1).
4. **Recálculo independiente** de toda cifra recalculable, con comparación carácter por carácter de hashes y conteos.
5. **Replicación de los controles del propio proyecto** (`check_l0_integrity.R`, `test-adr-indice.R`, `test_that`). Cuando no hubo R, las revisiones anteriores lo declararon como límite. Esta revisión sí tuvo R.
6. **Severidad en tres niveles**, con código resoluble (`C#`, `I#`, `M#`):
   - **CRÍTICO:** contradicción verificable sobre el estado del proyecto o sobre una certificación; afirmación falsa en un archivo de primera lectura; dato que el sistema puede producir incorrecto en silencio. Precedentes: C1–C6 de Fase 0, C1 de la verificación de Fase 1, C1 de la independiente de Fase 2, C1 de la revisión de Fase 3.
   - **IMPORTANTE:** toca el criterio de cierre o el estándar probatorio que el proyecto se impuso; entregable incompleto frente a su alcance; fallo en una máquina limpia. Precedentes: I1–I3 de Fase 1, I1–I2 de Fase 2, I1–I4 de Fase 3.
   - **MENOR:** cosmético, conteos, nombres, comentarios. No afecta datos ni criterio.
7. **Estructura fija del informe:** encabezado de método; resumen para orientarse; hallazgos por severidad; verificaciones limpias *con cifras*; límites (lo que no se pudo comprobar); pendientes consolidados, incluidos los abiertos por diseño que no se tocan; veredicto. La nota de remediación la agrega después quien remedia.
8. **Sin autoridad decisoria.** Las decisiones de nivel D son de Harold (regla 4 de `CLAUDE.md`, `doc/auditorias/README.md`).

**Batería de verificaciones recurrentes** (derivada de los hallazgos previos) y resultado en este cierre:

| # | Verificación | Origen | Resultado ahora |
|---|---|---|---|
| 1 | Estado de fase propagado a `CLAUDE.md` y `README.md` | F0 C2, F1v C1, F2 C1 | Limpio (el guard lo cubre) |
| 2 | Celda del índice de ADR = línea `**Estado:**` | F0 C3, F1v C1 | Limpio, 10/10 |
| 3 | El tag apunta al commit de cierre, sin deriva sustantiva | F0 C2 | Limpio; 1 commit cosmético post-tag |
| 4 | CI en verde sobre el commit certificado | F0 C2; límite 3 de F2 | Limpio, 3 runs verificados |
| 5 | `CITATION.cff` al día | F0 M4, F2 M1 | **Reincide (M1)** |
| 6 | Dependencias usadas = declaradas | F2 M1, F3 I3 | **`fabletools` (M2)** |
| 7 | Conteos transcritos a mano | F3 M5 | **Reincide (M2)** |
| 8 | Nombres o comentarios que prometen más de lo que hay | F2 M2 | **Reincide (M3)** |
| 9 | Evidencia que un tercero no puede re-derivar | F1 I3, F2 I2 | Declarada; se reprodujo la parte ejecutable |
| 10 | Independencia de la revisión de cierre | F2 I2 | Esta revisión; **hueco en Fase 3 (M5)** |
| 11 | Fallo silencioso en transformación o validación | F3 C1 | Guardas del motor revisadas: limpio |
| 12 | Cifras de la certificación recalculadas | todas | Limpio |
| 13 | **Reglas antes que resultados** (propia de esta fase) | senda §4, Fase 4 | **I1** |

---

### Resumen para orientarse

**El cierre de Fase 4 es sólido en el fondo y es el mejor certificado de la serie.** Es el primer cierre sin reincidencia del error de propagación de estado de fase: el guard de `test-adr-indice.R`, agregado tras la independiente de Fase 2, hizo su trabajo. El tag está sobre el commit de cierre y el CI está verde en ese commit y en los dos que lo rodean. Además, la evidencia textual se reproduce cuando se ejecuta.

**Resultado principal de esta revisión:** en una tercera máquina (Linux, R 4.6.1, entorno restaurado desde `renv.lock`), la verificación sintética V1-V11 sobre `c4e8b39` produce una salida **idéntica byte a byte** a la transcrita en `doc/evidencia_cierre_fase4.txt`. Las 29 líneas coinciden, incluidos el hash de V10 (`f3bdc2c613bf…`) y la tabla de tamaños de V7. La batería completa da **775 PASS / 0 FAIL / 0 SKIP** en 191 bloques `test_that` sobre `c4e8b39`, y **777 PASS** sobre el tag. La tabla de resultados tiene el sha256 declarado, y cada cifra que la nota de cierre cita de ella se recalcula igual.

**No hay hallazgos críticos.** Hay cuatro IMPORTANTES, y los cuatro tocan la disciplina que define esta fase: que el motor esté probado y las reglas fijadas **antes** de ver resultados.

- **I1:** la batería de robustez R1-R4 se especificó después de la corrida principal sobre L3. La nota de cierre atribuye al protocolo previo una anticipación (2021) que ese texto no contenía.
- **I2:** partes del protocolo que Fase 5 va a necesitar no están implementadas ni probadas, y la nota de cierre no las lista entre lo heredado: calibración y densidad; tabla de rezagos por familia y regla de años cerrados de UT.
- **I3:** la orquestación sobre datos, incluido X-13 por origen, solo se ejerce en la corrida local. Se la excluye de CI con la premisa "CI no tiene X-13", que es falsa en el entorno fijado.
- **I4:** el resumen de resultados de la nota de cierre no conserva las marcas de lectura que el propio protocolo fijó.

Ninguno pide rehacer código de evaluación ni reabrir una decisión. I2 e I3 conviene resolverlos **antes del primer modelo de Fase 5**. I1 e I4 se resuelven con una nota de corrección, conforme a la regla de no reescribir el registro.

Cinco MENORES, tres de ellos reincidencias de familias conocidas.

---

### Hallazgos — CRÍTICO

Ninguno.

---

### Hallazgos — IMPORTANTE

#### I1. La batería de robustez R1-R4 se especificó después de la corrida principal sobre L3, y la nota de cierre atribuye al protocolo previo una anticipación que no tenía

Esta fase tiene una frase no negociable en su criterio: *"Definir las reglas después de ver los resultados invalida el ejercicio"*. La cronología que prueba git, no la de las fechas escritas en los documentos, es esta:

| Momento (git, -0600) | Commit | Qué fija |
|---|---|---|
| 2026-09-23 21:58 | `2bd1050` | Protocolo con la regla de reporte del MCS y la tabla de robustez. R4 decía solo *"excluyendo los cuatro trimestres de 2020"* |
| 2026-09-24 11:37–15:29 | `38a41ba`, `6255a61`, `a78d2c6`, `3c6750a` | F4-14 a F4-22, los seis YAML de `06_modelos/` y el orquestador: todo **antes** de cualquier corrida sobre L3 |
| 2026-09-24 22:56 | `ee60dee` | Merge del motor. El checklist (C3, E1) registra la primera corrida de Harold sobre este commit el 2026-09-24: principal G1-G3 más R5 |
| 2026-09-28 11:43 | `23eb3d7` | Primera aparición en el repositorio de F4-25 a F4-29: especificación de R1 (X-13 sobre `[1990-Q1, o]`), R2 (X-13 solo sobre la NSA nativa), R3 (contraste MCO-HAC) y **la línea de R4 "sin 2020 ni 2021"** |
| 2026-09-28 16:40–16:59 | `94ee0db`, `1c0c5ff` | Primera corrida de R1-R4 y R6 |

Lo que se cumple, y está bien hecho: los benchmarks, la corrida principal, las pruebas y la regla de reporte del MCS se fijaron antes de cualquier resultado sobre L3. C8 lo certifica con un hash (`a78d2c6`, anterior a `3c6750a`). La especificación de R1-R4 precede a la primera corrida de *robustez*, como dice el acta (*"Ninguna se fijó mirando resultados de robustez"*).

Lo que no se cumple es la lectura más exigente: las cinco fichas se decidieron **con los resultados de la corrida principal ya a la vista**. En cuatro de ellas, la elección no tiene relación evidente con esos resultados. En la ampliación de R4 sí importa, por cómo se la cita al cerrar. El registro de cierre de `doc/adr/README.md` dice:

> "El empate de la corrida principal depende de los targets de 2020 y 2021, **como anticipaba el protocolo §5**."

El protocolo §5 anterior a los resultados (`2bd1050`) anticipaba **2020**: *"la pertenencia al MCS puede depender de cuatro observaciones"*. La mención de 2021 entró con F4-29 (*"[verificado 2026-09-25] Los targets de 2021 concentran el 46,7 %…"*), después de la corrida principal. El fundamento de F4-29 es descriptivo, porque es una partición de la suma de cuadrados del objetivo observado y no depende de ningún modelo, y la ficha la declara honestamente como *"ampliación fijada antes de ver R4"*. Pero la frase del cierre se la adjudica al texto previo, y de ella sale la conclusión de mayor peso interpretativo de la fase.

Hay un agravante menor de registro. Las fechas escritas en los documentos no son las de git: el acta dice "decididas el 2026-09-24" en un commit de las 21:58 del 23; F4-23 a F4-29 dicen "2026-09-25" y aparecen el 28. En una fase cuyo criterio es un orden temporal, el único reloj que un tercero puede verificar es el hash. C8 ya usa ese estándar.

*Remediación posible sin reabrir nada:* agregar una nota de corrección al registro "Cierre de Fase 4", sin editar el texto existente, que diga que la línea "sin 2020 ni 2021" se fijó después de la corrida principal y antes de la de robustez, citando `23eb3d7`. Para Fase 5, que toda afirmación de "fijado antes de" cite el commit, como C8.

#### I2. Partes del protocolo que Fase 5 necesita no están implementadas ni probadas, y la nota de cierre no las lista entre lo heredado

Criterio: *"el motor de evaluación funciona y está probado **antes** de estimar cualquier modelo sofisticado"*. Dos piezas del protocolo vigente no tienen código ni verificación, y las dos se van a necesitar con el primer modelo de Fase 5:

**(a) Evaluación de la incertidumbre.** Senda §5.3 y protocolo §3.4 piden cobertura empírica al 80 % y al 95 % y CRPS para los modelos que producen densidad. El contrato de modelo (`predecir()` devuelve el sendero puntual) no admite densidad, y en `metricas.csv` las columnas `cobertura_80`, `cobertura_95` y `crps` quedan vacías por construcción (`evaluar_errores()`, `eval_lib.R` §10). La especificación del motor lo dice (§4: *"quedan vacías mientras el contrato… devuelva solo el sendero puntual"*). El problema es otro: BVAR, los modelos de espacio de estados y las combinaciones con densidad de Fase 5 activan esa rama del protocolo. El contrato con densidad, el cómputo de cobertura y CRPS y su verificación sintética (un bloque tipo V3 para la cobertura) se escribirían entonces **durante Fase 5**, con resultados puntuales ya a la vista. Es justo lo que el criterio de Fase 4 existe para impedir.

**(b) Conjunto de información de las predictoras.** F4-02 figura como decidida, con la regla de calendario y *"UT solo con años cerrados"*. El motor implementa el mecanismo genérico (`recortar_a_origen()` con rezago en días), bien probado. Pero no existe en código la tabla de rezagos por familia del protocolo §2.3: solo `REZAGO_PIB_DIAS`. La regla de años cerrados de UT no tiene ninguna implementación (búsqueda en `src/evaluacion/`: cero coincidencias). El protocolo §2.3 conserva además la frase *"requiere decisión (F4-02)"*, que contradice el acta. Como ningún benchmark usa predictoras, nada de esto afectó los resultados de Fase 4. Pero es una regla anti-filtración, y hoy se implementaría con los modelos de Fase 5 ya en marcha.

La lista *"Lo que queda abierto y NO bloquea este cierre"* del registro de cierre no menciona ninguna de las dos.

*Remediación posible:* decisión de Harold entre dos caminos. (i) Implementar (a) y (b) con su verificación sintética en CI como compuerta **antes** de estimar el primer modelo de Fase 5, y agregarlas a la lista de herencia del cierre. (ii) Fijar con una nota fechada en la senda §4 que "el motor está probado" se refiere a pronósticos puntuales de modelos univariados, y que la evaluación de densidades y el conjunto de información de las predictoras son una compuerta previa de Fase 5 con el mismo estándar.

#### I3. La orquestación sobre datos, incluido X-13 por origen, solo se ejerce en la corrida local, con una premisa sobre CI que no se sostiene

La nota de cierre de la senda justifica la lectura doble de "probado" así: *"La primera no alcanza sola porque **CI no tiene L3 ni X-13**"*. `eval_lib.R` §9 lo repite: *"ejecuta el binario de X-13, que no corre en CI"*. La mitad de L3 es cierta, porque L0-L3 están en `.gitignore`. La mitad de X-13 no lo es en el entorno fijado:

- `x13binary` 1.1.61.2 y `seasonal` 1.10.0 están en `renv.lock`, y el job `validate-and-test` hace `setup-renv` en `ubuntu-latest`.
- En esta revisión, con ese mismo lockfile en Ubuntu 24.04, `seasonal::checkX13()` pasa. La suite corre **sin ningún SKIP** las pruebas de `test-l3-pib-objetivo.R` que llaman a `seasonal::seas()` detrás de `skip_if_not(x13_disponible)`.
- `ajustar_en_origen()` del motor, alimentada con una NSA sintética de 145 trimestres, corre en unos 7 segundos. Reproduce F4-09b tal como está decidido: en el origen 2013-Q1 no entra ningún AO; en 2020-Q2 entra `ao2020.2`; en 2025-Q4, `ao2020.2 ao2020.3`. Con `transform=log` en los tres casos. Y `verificar_ajuste_origen()` falla ante un outlier no declarado.

En consecuencia, la capa que solo ejerce la corrida local es más amplia que X-13: toda la orquestación de `motor_backtesting.R`. Incluye `serie_en_origen()`, las bases por origen de F4-20 dentro del bucle completo, las ramas R1, R2, R5 y R6, las submuestras de R3 y R4 y la escritura de 07. Esa corrida es la de mayor valor probatorio de la fase, y la de menor reproducibilidad por terceros, porque exige L0 privada. Sin embargo, `correr_experimento(ex, insumos, cache_sa)` recibe los insumos en memoria. Se puede ejercer en CI con objetivos, NSA y outliers sintéticos, sin L3.

*Remediación posible:* un bloque V12 en `verificar_motor_sintetico.R`, o un `test_that`, que corra `correr_experimento()` para una fila de cada variante sobre insumos sintéticos con estacionalidad conocida. Debe comprobar los conteos de pares, que las bases no pasen del origen, la entrada escalonada de los AO y el token. Y corregir la frase de la senda §4 y el comentario de `eval_lib.R` §9 con una nota fechada. Antes, conviene que Harold confirme en el log de CI (visible solo con sesión iniciada) que el conteo de SKIP es 0, que es lo que indica esta revisión.

#### I4. El resumen de resultados de la nota de cierre no conserva las marcas de lectura que el propio protocolo fijó

El protocolo §4 fija, antes de los resultados (F4-18): *"en esos horizontes [h = 4, 8] que un modelo quede fuera del MCS **no se lee como prueba de inferioridad**"*. El registro de cierre agrega que V9 calibra hasta n = 18 y que *"Celdas más chicas… no se interpretan"*. El párrafo "Lo que dicen los benchmarks" del mismo registro lee, sin marcas:

- *"En G3 con h = 4 y 8 excluye al paseo aleatorio sin deriva"* y *"R4: sin los targets de 2020, el paseo aleatorio sin deriva sale del MCS en h = 4 y 8 en los tres grupos"*. En la tabla, todas esas exclusiones están en celdas marcadas `distorsion_tamano_documentada`.
- *"Sin 2020 ni 2021 sale en todos los horizontes"*, que incluye G3, donde las cuatro celdas de `sin_2020_2021` tienen **n = 17**, por debajo del piso calibrado. La tabla no las marca: `marca_tamano` solo distingue horizonte, no tamaño. Hay seis bloques de celdas con n < 18: G2 `pre2020` con h = 4 (17) y h = 8 (13), y G3 `sin_2020_2021` en los cuatro horizontes (17).

La conclusión central, que el empate depende de 2020 y 2021, sí tiene respaldo legible en G1 y G2 con h = 1, 2 y `sin_2020_2021`: n entre 36 y 44, sin marca de distorsión, y el paseo sin deriva sale del MCS. Pero esa línea es la ampliación posterior de I1, y usa pares no consecutivos concatenados (aproximación declarada). Además, la sensibilidad del p-valor del MCS a la semilla es del orden de ±0,013: la celda G3 `sin_2020` con h = 8 tiene exactamente la misma muestra que la completa y da `p_mcs` 0,2826 contra 0,2956. Las celdas con `p_mcs` entre 0,07 y 0,13 están casi todas en las de n < 18.

*Remediación posible:* una columna `marca_n` en `tabla_resultados_fase4.csv` (por ejemplo `n_bajo_calibracion` cuando n < 18), generada por `tabla_resultados_fase4.R`, y una nota de corrección al párrafo del cierre que conserve las dos marcas del protocolo. Es la regla de reporte que Fase 5 va a heredar tal cual.

---

### Hallazgos — MENOR

**M1. `CITATION.cff` quedó en `version: 0.5.0` / `date-released: 2026-09-09`.** Van dos tags de fase por delante (`v0.6.0-fase3`, `v0.7.0-fase4`). Es la **tercera** aparición de la familia: M4 de Fase 0 y M1 de la independiente de Fase 2. El guard de `test-adr-indice.R` ya deriva la última fase cerrada. Extenderlo para que `CITATION.cff` declare la versión del último tag de fase cortaría la cuarta.

**M2. Dependencias y conteos que no siguieron a los cambios de Fase 4.**
- `CLAUDE.md` (Stack) dice *"`renv.lock` está fijado (187 paquetes)"* y *"25 imports declarados"*, con una lista sin `yaml`.
- `README.md` (Empezar) dice *"187 paquetes"*.
- La realidad: `DESCRIPTION` tiene 26 `Imports:` desde `0c1fd00` (`yaml`, F4-12), y `renv.lock` tiene 188 entradas desde `8c4dec7` (`MCS`).
- `modelos_referencia.R` llama a `fabletools::model()` y `fabletools::forecast()`, y `fabletools` no está en `DESCRIPTION`. Hoy no rompe nada, porque entra como dependencia de `fable`. Es la familia de I3 de Fase 3.

Relacionado: el `README.md` del tag todavía decía `ADR-001 … ADR-009` en "Estructura" (desactualizado desde ADR-010, en Fase 3). Se corrigió en `4ea39ea`, después del tag. Es inocuo, pero el snapshot certificado lo conserva.

**M3. Comentarios y rótulos que dicen algo distinto de lo vigente.**
- `eval_lib.R` §8 numera DM/HLN = F4-15, GW = F4-16 y MCS = F4-17. Pasa en el bloque de cabecera (líneas 427-432), en el comentario del respaldo Bartlett de `prueba_dm_hln` (línea 464) y en las cabeceras de `prueba_gw`, `bloque_mcs` y `mcs_tmax`. El acta, el protocolo, la especificación (§4: *"la columna `varianza` es el registro que pide F4-16"*) y `motor_backtesting.R` dicen MCS = F4-15, DM/HLN = F4-16 y GW = F4-17. Son citas por código que no resuelven a la decisión correcta.
- El comentario del objetivo `eval-sintetico` del `Makefile` dice *"Bloques vigentes: V1-V6 y V10; V7-V9 y V11 … llegan con el paso 4"*, pero los once están vigentes.
- El paso de CI sigue rotulado *"Comprobación mínima de catálogos (esquema de Fase 3 pendiente)"* con Fase 3 cerrada. Es la familia de M2 de la independiente de Fase 2.

**M4. Registro de cierre incompleto en dos lugares de lectura.** El `README.md` raíz no cita el tag en las líneas de Fase 3 ni de Fase 4, aunque sí lo hace en las de Fase 1 y 2 (y `CLAUDE.md` los cita todos). En `doc/checklist_fase4.md`, F4 (tag) sigue en `[ ]` aunque el tag existe. Esto último es inevitable dentro del commit tageado, pero conviene marcarlo al depositar esta revisión (F5).

**M5. La serie de revisiones independientes tiene un hueco en el cierre de Fase 3.** `revision_independiente_fase3_SIE-el-salvador.md` revisó `e8116f1`, con Fase 3 en curso, el 2026-09-17. El cierre de Fase 3 (`906fb56`, `v0.6.0-fase3`, del 2026-09-22/23, con la enmienda de UT y la extensión de `make trace`) no tuvo revisión de cierre por un tercero, y el checklist de Fase 3 no la preveía. Fase 4 la introdujo (F5). Esta revisión cubre de Fase 3 solo lo que Fase 4 consume: `check_l0_integrity.R` con 56 vintages, integridad referencial y la batería completa, todo en verde. No re-deriva el `make trace` 106 PASS. El índice de `doc/auditorias/` debería decirlo, con el mismo tratamiento que dio a la interna de Fase 2.

---

### Verificaciones que resultaron limpias (con las cifras)

| Verificación | Resultado |
|---|---|
| Verificación sintética V1-V11 sobre `c4e8b39`, en una tercera máquina (Ubuntu 24.04, R 4.6.1, `renv::restore()`) | salida **idéntica byte a byte** a `doc/evidencia_cierre_fase4.txt` (29 líneas, incluidos V10 `f3bdc2c613bf…`, la tabla de V7 y V11 con diferencia máxima 0 frente a `MCS::MCSprocedure`); 92 s, salida 0 |
| `testthat::test_dir("tests")` con locale UTF-8 | `c4e8b39`: **775 PASS / 0 FAIL / 0 SKIP**, 191 bloques; `a67bde9`: **777 PASS** (+2: el guard de fase suma Fase 4) |
| `validate_catalogs.R`, `validar_integridad_catalogos.R`, `check_l0_integrity.R` sobre el tag | los tres con salida 0; L0 cruzada 56/56 |
| Topología del tag | `v0.7.0-fase4`, tag anotado, apunta a `a67bde9`, que contiene la certificación, la evidencia, la senda v0.7 y la propagación. `v0.7.0-fase4..main` = 1 commit cosmético (`4ea39ea`) |
| CI (páginas públicas de Actions) | run 36583715418 sobre `c4e8b39` en verde (los dos jobs); run 36595407970 sobre `a67bde9`, el que cita el mensaje del tag, en verde; run #206 sobre `4ea39ea` en verde |
| "Los commits posteriores a `c4e8b39` no cambian `src/`, Makefile ni `renv.lock`" | cierto: `c4e8b39..v0.7.0-fase4` toca 8 archivos, ninguno de `src/`, `Makefile`, `renv.lock`, `DESCRIPTION`, `tests/` ni `.github/` |
| Propagación del estado de fase | `CLAUDE.md` y `README.md` declaran Fase 4 cerrada; el guard pasa. Primer cierre sin reincidencia de la familia C2/C1 |
| ADR ↔ índice | 10/10 coincidencias |
| Registro previo de los modelos (C8) | los 6 YAML de `06_modelos/` entran en un solo commit, `a78d2c6` (24-sep 15:09), anterior a `motor_backtesting.R` (`3c6750a`, 15:29) y a `ee60dee` (22:56). **Ninguno se modificó después**. `modelos_referencia.R` no cambió desde `38a41ba` (F4-14, 11:37), también anterior a toda corrida sobre L3 |
| `catalogos/07_experimentos.csv` | 78 filas = 13 experimentos × 6 modelos; 12 columnas idénticas al esquema; `exp_id` único con sufijo = `modelo_id`; `modelo_id` → `06_modelos/` 78/78; los 3 `vintage_id` distintos resuelven contra `08_vintages.csv`; 78/78 tokens válidos en la gramática; `commit_hash` = `c4e8b39…` en las 78; `muestra_inicio` de R1 coherente con la ventana de 92 (1990-Q2, 1992-Q1, 1997-Q1) |
| `sha256` de `renv.lock` sin CR (F4-31) | recalculado: `33e5cba2a702`, igual al de la columna `entorno`; R 4.6.1 en el lockfile |
| `doc/metodologia/reportes_fase4/tabla_resultados_fase4.csv` | sha256 recalculado `5f03e4d5af34…49e5`, igual al declarado; 552 filas = 23 bloques (experimento × muestra) × 24; 0 bytes CR; solo unidad `yoy_pp`; `marca_tamano` en todas las celdas h = 4, 8 |
| Cifras del registro de cierre | todas recalculadas: MCS completo en G1 y G2 en todos los h y en G3 con h = 1, 2; paseo sin deriva fuera en G3 con h = 4, 8; mejor RMSE relativo con h = 1 = 0,9894 (G1, paseo con deriva); R4 `sin_2020` con el paseo sin deriva fuera en h = 4, 8 en los tres grupos; `sin_2020_2021` fuera en todos los h; AR(1) en G1 = 0,778 (h = 1) y 0,393 (h = 4); 24 288 pronósticos = 3 × 2496 + 5 × 2160 + 5 × 1200 |
| Estadística del motor (revisión de código contra la literatura) | factor HLN `(n+1−2h+h(h−1)/n)/n` con t(n−1); GW con instrumentos (1, d<sub>t−h</sub>), HAC Bartlett y χ²(2); MCS T<sub>max</sub> con remuestras comunes a todas las etapas y p-valor acumulado; bootstrap estacionario circular. Sin defectos |
| Guardas del motor (familia de C1 de Fase 3) | G-1 a G-6 fallan con `stop()`; `derivar_unidades()` rechaza bases posteriores al origen, duplicadas o NA; el conteo de pares por horizonte se compara contra el diseño en cada experimento. No se encontró ruta de fallo silencioso |
| F4-09b sobre datos sintéticos (esta revisión) | los AO declarados entran solo desde el origen que los alcanza; `transform=log` fijo; un outlier no declarado detiene el ajuste |

---

### Límites de esta revisión

1. **No se re-ejecutó `make eval`.** Exige `data/L3_master/`, L1 y la L0 privada. El código de salida 0, los 13 manifiestos con `arbol: limpio` y la igualdad de 23/71 CSV entre máquinas descansan en `doc/evidencia_cierre_fase4.txt`. La "segunda máquina" de esa evidencia también tenía la L0 privada, así que no es un tercero. Lo ejecutable sin L3 sí se reprodujo.
2. **Logs de CI.** Las páginas públicas confirman la conclusión de cada run, pero los logs exigen sesión iniciada. El conteo de SKIP en CI (relevante para I3) no se pudo leer; se infiere del mismo lockfile. Las páginas se leyeron con una herramienta que resume el HTML.
3. **Locale.** Con locale POSIX, la batería da 13 FAIL y 8 ERROR (lectura de YAML con caracteres no ASCII). Con UTF-8, que es lo que usan CI y Windows con R ≥ 4.2, da 0. No se registra como hallazgo, pero un tercero en un entorno no UTF-8 no reproduciría el verde.
4. **ADR y fichas F4 como dadas.** Se revisó si el código y los registros cumplen lo decidido, no si las decisiones son las mejores.
5. **El cierre de Fase 3 no se auditó** más allá de lo que Fase 4 consume (M5).

---

### Pendientes consolidados

| # | Pendiente | Fuente | Naturaleza |
|---|---|---|---|
| 1 | Evaluación de densidad y calibración, y conjunto de información de las predictoras (tabla de rezagos, regla de UT) como compuerta **antes** del primer modelo de Fase 5, o lectura acotada de "probado" en la senda §4; agregar a la herencia del cierre | I2 | Decisión de Harold; condiciona Fase 5 |
| 2 | V12 o `test_that` que ejerza `correr_experimento()` y `ajustar_en_origen()` con insumos sintéticos en CI; corregir "CI no tiene X-13" (senda §4, `eval_lib.R` §9); confirmar SKIP = 0 en el log de CI | I3 | Cobertura de prueba; antes de Fase 5 |
| 3 | Nota de corrección al "Cierre de Fase 4": la línea R4 "sin 2020 ni 2021" es posterior a la corrida principal (`23eb3d7`); citar commits, no fechas, en afirmaciones de "fijado antes de" | I1 | Registro |
| 4 | `marca_n` (n < 18) en la tabla de resultados y nota de corrección al párrafo de resultados, con las dos marcas del protocolo | I4 | Regla de reporte que hereda Fase 5 |
| 5 | `CITATION.cff` → `0.7.0` / `2026-09-29`; extender el guard | M1 | Cosmético; tercera reincidencia |
| 6 | Conteos de `CLAUDE.md` y `README.md` (188 / 26 imports, `yaml`); `fabletools` en `DESCRIPTION` | M2 | Cosmético / higiene |
| 7 | Numeración F4-15/16/17 en `eval_lib.R` §8; comentario del `Makefile`; rótulo del paso de CI | M3 | Cosmético |
| 8 | Tags de Fase 3 y 4 en `README.md`; marcar F4 y F5 del checklist al depositar esta revisión | M4 | Cosmético |
| 9 | Registrar en `doc/auditorias/README.md` el hueco de revisión del cierre de Fase 3 | M5 | Registro |
| — | *Abiertos por diseño, no tocar:* distorsión de tamaño de DM/HLN en h = 4, 8; MCS no calibrado bajo n = 18; tamaño de GW y del contraste de estabilidad sin verificar; pista en tiempo real prospectiva y grano anual de UT; D5 (validador de FK dividido); F4-23, meses 2009 del IPC del FMI; ADR-008 con cortes **BCR 2026-10-12** y **CEPAL 2026-10-16** (en 13 y 17 días) | registro de cierre; ADR-008 | Declarados |

**Fila sugerida para `doc/auditorias/README.md`** (F5; la deposita Harold):

`| auditoria_independiente_fase4_SIE-el-salvador.md | 2026-09-29 | a67bde9 (v0.7.0-fase4) | I1–I4, M1–M5 | — |`

---

### Veredicto

**¿Está genuinamente cerrada Fase 4, y bien certificado el cierre? Sí, en el sentido en que el registro lo afirma: el motor funciona, está probado sobre procesos generadores conocidos, y los seis benchmarks se declararon y corrieron bajo reglas fijadas antes de verlos.**

Esta revisión no depende solo del texto de la evidencia. Por primera vez en la serie se ejecutó el sistema: la verificación sintética da la misma salida byte a byte en una tercera máquina y otro sistema operativo, la batería completa pasa sin fallos ni saltos, y cada cifra citada en la certificación se recalcula igual. Topología del tag, CI, propagación y registro previo de modelos: todos limpios. Es el cierre mejor certificado de las cinco fases, y el primero en que el error de propagación no reaparece.

Los cuatro IMPORTANTES no invalidan el cierre. Delimitan con precisión qué quedó probado. I1 e I4 son de registro: una ampliación de robustez posterior a la corrida principal presentada como anticipada, y un resumen de resultados que no arrastra las marcas de lectura que el protocolo se impuso. I2 e I3 miran hacia adelante y son los que más importan. La evaluación de densidades, el conjunto de información de las predictoras y la orquestación completa todavía no están probados en CI. Si Fase 5 los escribe o los prueba por primera vez con sus modelos ya corriendo, repite exactamente el escenario que el criterio de Fase 4 prohíbe. Resolverlos antes del primer modelo de Fase 5 convierte "Fase 4 cerrada" en lo que la senda quiere que signifique: que ninguna regla de evaluación se escriba después de ver un resultado.

---

### Nota de remediación (2026-09-29, Claude Code)

I1–I4 y M1–M5 quedaron remediados el mismo día, más un sexto menor (M6) que apareció al preparar
la remediación. El registro del cierre de Fase 4 no se reescribió: las correcciones entraron como
notas fechadas. El detalle, las decisiones de Harold (A1–A7) y el cambio de sha256 de la tabla de
resultados están en `doc/adr/README.md`, «Remediación de la auditoría independiente de Fase 4».

- **I1** (anticipación atribuida al protocolo): nota de corrección al final de «Cierre de Fase 4» y
  regla para Fase 5 en el protocolo §6 (`8c0435e`).
- **I2** (compuerta de Fase 5): F4-32 a F4-34. Contrato de densidad gaussiana, cobertura al 80/95 %
  y CRPS con oráculo `scoringRules` (V13), y rezagos por familia desde
  `evidencia_insumos_fase4.csv` (`b9b793e`). «UT solo años cerrados» por la opción (C), con canario
  anual en V5, y σ² del paseo sin deriva = mean(Δy²) (`7c5faa8`).
- **I3** (premisa «CI no tiene X-13»): era falsa. La suite ya ejercía `seasonal::seas()` en CI, con
  SKIP 0 en el run 36595407970. Desde V12 la orquestación de `motor_backtesting.R` con X-13 por
  origen corre en CI sobre insumos sintéticos; nota en la senda §4, v0.8 (`2c1865f`).
- **I4** (lectura de exclusiones del MCS): nota de lectura (`8c0435e`) y columna `marca_n` en la
  tabla de resultados, F4-35 (`2da3d3b`). La tabla regenerada difiere de la del cierre solo por esa
  columna: 36 de sus 552 filas llevan `n_bajo_calibracion`.
- **M1** `CITATION.cff` a 0.7.0 / 2026-09-29, con guard en `tests/test-adr-indice.R`. **M2**
  `fabletools` declarado y conteos de `CLAUDE.md` y `README.md` (189 paquetes con `scoringRules`).
  **M3** códigos F4-15/16/17 en `eval_lib.R`, comentario del `Makefile` y rótulo del paso de CI.
  **M4** tags en el `README.md` y F4 y F5 del checklist marcados. **M5** hueco de revisión del
  cierre de Fase 3 registrado en `doc/auditorias/README.md`, sin revisión retroactiva. **M6**
  (nuevo) `yaml`, `MCS` y `fabletools` en el bootstrap; V11 falla en CI si falta su oráculo
  (`81eb337`).
- **Verificación:** los runs de CI #207, #208 y #209 (`b9b793e`, `7c5faa8`, `a4576e9`) terminaron
  en verde. Esta sesión no ejecutó R localmente: la evidencia de las pruebas nuevas es la de CI.
- **Pendiente:** el tag `v0.7.1-fase4` (A6), que no sustituye a `v0.7.0-fase4`.
- **No se tocaron**, por ser abiertos por diseño: la distorsión de tamaño de DM/HLN en h = 4, 8, el
  MCS no calibrado bajo n = 18 y el resto de la lista de «Pendientes consolidados».
