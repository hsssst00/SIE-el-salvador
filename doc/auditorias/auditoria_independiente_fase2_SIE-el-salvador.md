## Auditoría independiente — Fase 2, SIE El Salvador

**Repositorio auditado:** `github.com/hsssst00/SIE-el-salvador` (clon fresco, no tarball).
**HEAD real de `main`:** `23c1064` — *"Cierra Fase 2: criterio de senda §4 SATISFECHO por la vía «verifica su integridad»"* (Harold, 2026-09-09, 17:36 -0600). 128 commits en total.
**Tags:** `v0.1.0-fase0`, `v0.2.0-fase0-enmendado`, `v0.2.1-fase0-enmendado`, `v0.4.0-fase1`, **`v0.5.0-fase2`** (tag anotado, objeto `95caea2a`, apunta al commit `23c1064` = HEAD). Rama `remediacion-auditoria-fase2` (`491abc1`) presente y **completamente absorbida en `main`**.
**Método:** `git clone` + `git log`/`git show`/`merge-base`; lectura directa del contenido de cada archivo; recálculo propio en Python de todo lo recalculable (conteos de manifiesto/vintages, correspondencia de `vintage_id`, comparación carácter por carácter de `sha256`/`sha256_norm` entre manifiesto y `08_vintages`, resolución de `publicacion_id` contra los 85 YAML, consistencia ADR↔índice); replicación de la lógica de `check_l0_integrity.R` sobre los datos que sí están versionados. No se usó `conversation_search`/`recent_chats`; donde algo solo podría explicarse por contexto de chat o memoria, se señala como hallazgo, no se rellena. El clon directo topó `HTTP 429` (IP compartida del entorno, misma limitación que declararon las verificaciones de Fase 1); se resolvió con reintentos y respaldo por tarball/`ls-remote`.

**Encargada por:** Harold, 2026-09-15.
**Ejecutada por:** Claude (Sonnet 5), fuera de sesión de este repositorio — informe recibido y evaluado por Claude Code en este árbol el mismo día.

---

### Resumen para orientarse

El fondo técnico del cierre de Fase 2 está **sólidamente hecho**, y en un aspecto estructural es la mejor de las tres fases auditadas: **no hay deriva post-tag**. El tag `v0.5.0-fase2` es un tag anotado que apunta al commit de cierre mismo (`v0.5.0-fase2..main` es vacío), lo que corrige por diseño el modo exacto del hallazgo C2 de Fase 0. La maquinaria de L0 —los tres checks: físico offline, cruzado offline (que ahora **sí corre en CI**, cerrando el pendiente histórico #16 que arrastraban Fase 0 y 1) y monitor de deriva en vivo— es real, correcta y consistente cuando la recalculo por mi cuenta. Los dos hallazgos que motivaron toda la sesión de cierre (A1, la cobertura falseada de `verificar_l0.R`; B1, la ausencia física silenciosa de L0) están genuinamente cerrados. La lectura del criterio ("verifica su integridad") está fijada, fechada y bien argumentada en la senda §4 (v0.5), ADR-007 y el registro "Cierre de Fase 2" del índice de ADR.

**Encontré un hallazgo CRÍTICO**, y es una reincidencia: por tercera vez, el estado de cierre de fase **no se propagó a los dos archivos que un recién llegado —y los tres agentes— leen primero**. `CLAUDE.md` sigue declarando "Fase 1 … en curso" (literalmente falso: Fase 1 cerró en `v0.4.0-fase1`) y no menciona Fase 2; el `README.md` raíz omite Fase 2 por completo y presenta Fase 1 como la frontera del proyecto. Es la forma exacta de C2 (Fase 0) y C1 (Fase 1) —y el propio proyecto construyó un test anti-regresión para esta familia (`tests/test-adr-indice.R`) que, por su alcance, no cubre ninguno de los dos archivos donde el bug reapareció.

Dos IMPORTANTES de completitud/prueba, ninguno de los cuales reabre una decisión. Menores cosméticos. Y una salvedad de contexto que conviene decir de entrada: **la auditoría interna de Fase 2 no fue independiente** —la ejecutó el mismo agente que aplicó las correcciones, en la misma sesión y sobre el árbol de trabajo, según lo declara honestamente `doc/auditorias/README.md`—, de modo que este encargo no es redundante: es la primera revisión del cierre de Fase 2 contra un clon fresco por un tercero.

---

### Hallazgos — CRÍTICO

#### C1. Reincidencia (tercera) del bug de propagación de estado de fase: `CLAUDE.md` y `README.md` raíz contradicen el cierre que el registro autoritativo certifica

El cierre está correctamente registrado en los tres lugares que mandan: `doc/adr/README.md` ("Cierre de Fase 2 (2026-09-09)", criterio **SATISFECHO**), `doc/senda_metodologica.md` §4 (nota de cierre, v0.5) y el tag `v0.5.0-fase2` sobre el commit de cierre. Pero dos archivos de primera lectura quedaron atrás:

**(a) `CLAUDE.md`, línea 11 — falso en su literalidad.**
> "Fase 0 cerrada (tag `v0.2.1-fase0-enmendado`); **Fase 1 —inventario del ecosistema estadístico— en curso.**"

Fase 1 cerró (tag `v0.4.0-fase1`) y Fase 2 también. Esta línea está dos cierres de fase atrás y afirma como presente algo que dejó de ser cierto. `CLAUDE.md` no es documentación decorativa: es el contrato operativo que Harold, Claude chat y Claude Code leen antes de tocar nada. Que diga "Fase 1 en curso" es exactamente el tipo de afirmación que la verificación de Fase 1 calificó de crítica ("es lo primero que lee un tercero, y hoy es falso en su literalidad"). La cláusula de fase no lleva el hedge "A la fecha de este archivo" que sí acota, más adelante en la misma oración, el conteo de ADR; y aunque remite a `doc/adr/README.md` "para el estado exacto de cada decisión", el enunciado de fase queda sin corregir.

**(b) `README.md` raíz, sección "## Estado" — omite Fase 2.**
La sección declara "**Fase 0 — cerrada**" y "**Fase 1 — cerrada** … Tag `v0.4.0-fase1`", y ahí termina. No existe línea de Fase 2 (`grep 'Fase 2' README.md` → cero coincidencias). Un tercero que lea "Estado" concluye que el proyecto está al final de Fase 1. A diferencia de (a) no es una afirmación falsa sino una omisión, pero deja la sección —cuyo único propósito es decir dónde está el proyecto— materialmente desactualizada, y sin mención del tag `v0.5.0-fase2`.

**Por qué CRÍTICO, y por qué no lo bajo a IMPORTANTE.** Hay contradicción interna verificable sobre un hecho que este mismo período de trabajo cambió: `doc/adr/README.md` + senda + tag dicen "Fase 2 cerrada"; `CLAUDE.md` dice "Fase 1 en curso". Es el mismo modo de fallo que las dos auditorías anteriores calificaron de crítico (C2 en Fase 0, C1 en Fase 1), y es su **tercera** aparición. El agravante propio de esta vez: el proyecto ya construyó el guard anti-regresión pensado para esta familia —`tests/test-adr-indice.R`, cuyo propio comentario cita "Fase 0, hallazgos C2/C3; verificación de Fase 1"— pero su alcance es *la celda «Estado» de cada ADR ↔ la línea `**Estado:**` del ADR*, y no toca ni el `README.md` raíz ni el estado de fase de `CLAUDE.md`. El punto ciego del test está exactamente donde reincidió el bug.

**No hay nada que reabrir.** Son tres o cuatro líneas de edición (una en `CLAUDE.md`, una entrada de Fase 2 en el "## Estado" del README con su tag) y —para cortar la recurrencia #4— extender `test-adr-indice.R`, o un test hermano, a que la fase abierta más avanzada declarada en `CLAUDE.md`/`README.md` coincida con el último "Cierre de Fase N" del índice de ADR.

---

### Hallazgos — IMPORTANTE

#### I1. La "bitácora de fuentes frágiles" —entregable nominado de Fase 2— cubre solo el BCR, pese a declararse "de cada fuente"

`doc/bitacora_fuentes_fragiles.md` abre así: *"Registro de comportamientos anómalos o de bloqueo encontrados al automatizar la adquisición de **cada fuente**. Entregable de Fase 2 (senda §4)."* Su contenido, sin embargo, son tres secciones **todas del BCR** (portal Livewire/Alpine.js con detección de bots; Reservas Internacionales con mecanismo distinto de `vista-serie`; el desajuste del calendario en SPNF). No hay sección de FMI, FRED, Banco Mundial ni UT (`grep` de esas fuentes en el archivo: una sola coincidencia incidental; las menciones a "robots"/timeout son todas del contexto `chromote`/BCR).

Esto importa porque la senda lista el entregable como "documentación de la fragilidad de **cada fuente** y del procedimiento de recuperación", y el propio documento de diseño de `src/adquisicion/` anticipaba poblarla con al menos tres fuentes ("BCR es Livewire/Alpine.js sin endpoint estable; MH tiene widgets HTML sin API; FMI tiene el comportamiento de `c[TIME_PERIOD]`"). Fragilidades reales y ya descubiertas viven hoy **fuera** del artefacto designado: la restricción `robots.txt` de UT —que es precisamente un dato de *recuperación* (nunca se re-pide en vivo, regla 9)— está en `.EXCLUIDAS` de `verificar_l0.R`; el *gotcha* de `c[TIME_PERIOD]` del FMI está en el documento de diseño. No es pérdida de información, es un entregable incompleto contra su propio alcance declarado y contra §10.6 (cada hecho en un solo lugar). El BCR está documentado con calidad; el artefacto simplemente no es lo que su encabezado y la senda dicen que es.

*Remediación posible sin abrir nada:* o bien completar la bitácora con una sección por fuente restante (aunque sea para asentar "API estable, sin fragilidad conocida; procedimiento de recuperación = re-pedido idempotente vía `.<fuente>_refetch`"), o bien acotar explícitamente el alcance del encabezado a las fuentes de portal y remitir a `verificar_l0.R`/diseño para las demás.

#### I2. El cierre se apoya en evidencia que un tercero no puede re-derivar, certificada por una auditoría que no fue independiente

Dos cosas verdaderas a la vez, y su conjunción es la brecha probatoria estructural del cierre:

- **La evidencia de `make raw` no es reproducible fuera de la máquina de Harold.** Los `.xlsx`/`.json` de L0 están en `.gitignore` (ADR-008), y `make raw` exige red, `FRED_API_KEY`, Chrome headless y —para repoblar— el almacén privado `SIE_L0_STORE`. Ni CI ni un tercero (ni yo) pueden re-derivar el "54/54 offline PASS" ni la "salida 0" de `make raw`; la única evidencia es el texto commiteado `doc/evidencia_cierre_fase2.txt`. Esto está **honestamente declarado** en el propio archivo y es consistente con ADR-008 y con el precedente de `doc/bitacora_verificaciones.md` (hallazgo I3 de Fase 1). Lo verificable —la consistencia interna de los registros y la corrección de la maquinaria— lo verifiqué; la existencia física y el código de salida, no (ver "Límites").
- **La auditoría interna de Fase 2 no fue independiente.** `doc/auditorias/README.md` lo dice sin adornos: *"A diferencia de las tres anteriores, no es independiente: la ejecutó el mismo agente que aplicó las correcciones, en la misma sesión y sobre el árbol de trabajo, no sobre un clon fresco"*, y uno de sus hallazgos (A2) resultó falso. La disciplina que el proyecto se impuso desde Fase 0 —verificar contra clon fresco, nunca contra autorreportes— no se aplicó al cierre de Fase 2 hasta este encargo.

No bloquea el cierre en el sentido de que la maquinaria funciona y la parte offline es reproducible en cualquier máquina con L0 materializada, y el `testthat` sí corre en CI. Pero significa que, hasta esta auditoría, "Fase 2 cerrada" descansaba sobre una corrida que solo Harold vio y sobre una autorrevisión. Lo registro como IMPORTANTE por consistencia con cómo Fase 1 trató la brecha análoga (I3), y para que el cierre quede con una revisión independiente asentada.

---

### Hallazgos — MENOR

#### M1. `CITATION.cff` congelado en `version: 0.1.0` / `date-released: 2026-08-06`
Existen los tags `v0.4.0-fase1` y `v0.5.0-fase2`, pero el archivo de cita sigue en la versión y fecha de Fase 0. Es la familia del M4 de Fase 0 (entonces se agregó `version`; ahora quedó atrás). Actualizar `version` a `0.5.0` y `date-released` a `2026-09-09`.

#### M2. El paso de CI "Validar esquema de catálogos" no valida esquema
El job corre `src/validacion/validate_catalogs.R`, que —según su propio encabezado— es un "Esqueleto de Fase 0" que solo confirma que `datapackage.json` es JSON válido y que los CSV declarados existen; la validación de tipos/dominios con `pointblank` está diferida a Fase 3. El script es honesto; el **nombre del paso** en `ci.yml` promete más de lo que hace. Es pre-existente (no se introdujo en Fase 2) y no es entregable de Fase 2, así que solo lo anoto: renombrar el paso a algo como "Comprobación mínima de catálogos" hasta que Fase 3 lo reemplace.

---

### Verificaciones que resultaron limpias (con las cifras)

- **Topología del tag — corrige el modo C2 de Fase 0.** `v0.5.0-fase2` es tag anotado que apunta al commit de cierre `23c1064`; `v0.5.0-fase2..main` es vacío (cero deriva post-tag). La rama `remediacion-auditoria-fase2` es ancestro de `main` y `main..remediacion-auditoria-fase2` es vacío (completamente absorbida). El registro "Cierre de Fase 2" incluso lo dice a propósito: "Tag … sobre el commit que ya contiene esta certificación … nunca antes (misma disciplina que la corrección de alcance de tag de Fase 0)".
- **Consistencia cruzada de L0 — repliqué los 4 checks de `check_l0_integrity.R` en Python: 4/4.** `manifiesto.csv` = 54 filas, `08_vintages.csv` = 54 filas; `vintage_id` 1-a-1 sin duplicados y mismo conjunto en ambas tablas; `sha256`, `sha256_norm` y `archivo`↔`archivo_raw` **idénticos** para los 54; cero `sha256_norm` vacíos.
- **Integridad referencial.** Los 30 `publicacion_id` distintos del manifiesto (y los 30 de vintages) resuelven contra los 85 YAML de `01_publicaciones`. Composición: `UT.DEMANDA_TOTAL_MENSUAL` 25 archivos + 17 BCR + 5 FRED + 5 FMI + 2 BM = 54.
- **`check_l0_integrity.R` es real y corre en CI — cierra el pendiente histórico #16** (Fase 0/1: "script real de verificación de checksums de L0 en CI"). El job `check-l0-integrity` dejó de ser el `echo "Pendiente…"` heredado. Matiz correcto y documentado: en CI verifica consistencia *cruzada de registros* (no la existencia física de los `.xlsx`, imposible con `.gitignore`); la verificación física la hace `verificar_l0_fisico.R` vía `make raw`, local.
- **`verificar_l0_fisico.R` cierra el hueco B1.** Verifica por fila del manifiesto: archivo en disco, `sha256` real y `tamano_bytes`. Modo dual bien pensado: L0 vacía (clon limpio/CI) = informativo, sale 0; con ≥1 archivo presente, toda ausencia es FAIL, sale ≠0 —justo el escenario B1 (12 archivos que desaparecen mientras el resto sigue) se detecta. Falla con `stop()` (regla 6).
- **`verificar_l0.R` cierra el hueco A1.** La lista de trabajo se **deriva del manifiesto** (antes: 3 publicaciones fijas con un "3/3 PASS" escrito a mano sobre 30 reales); cobertura por construcción. Reusa las mismas funciones de captura (`.fred_refetch`, `.bm_refetch`, `.fmi_perform`, `bcr_capturar_xlsx`) para que verificación y captura no diverjan. `ERROR` aborta (`stop`), `CAMBIO` no; exclusiones explícitas con motivo (`.EXCLUIDAS`: la retropolada estática y UT por `robots.txt`), 28 en vivo + 2 excluidas = 30.
- **Anti-regresión ADR↔índice: 0 discrepancias** sobre los 9 ADR (cada `**Estado:**` coincide con su celda en `doc/adr/README.md`). El bug de propagación *no* está presente a nivel de ADR; solo en los dos archivos fuera del alcance del test (C1).
- **La afirmación que sostiene la inocuidad de los 15 CAMBIO está verificada.** Ninguno de los 15 `publicacion_id` con CAMBIO aparece en `03_series.csv` (0/15). Contexto: de los 30 `publicacion_id` de L0, solo 5 tienen serie inventariada en `03_series.csv` (99 filas); las 25 restantes son inventario de Fase 3, a discreción de Harold. Los 15 CAMBIO están registrados en `doc/backlog_captura_vintages.md` (22 filas `CAMBIO` acumuladas).
- **Entregables de Fase 2 presentes y con cuerpo real.** `src/adquisicion/` = 2 037 líneas en 11 archivos (`lib_adquisicion.R`, `bcr.R`, `bcr_captura.R`, `fmi.R`, `fred.R`, `bm.R`, `ut.R`, `verificar_robots_ut.R`, `calendario_bcr_extraer.R`, `bcr_sondear_publicacion.R`, `README.md`) — no `.gitkeep`. Catálogo `08` inicializado (54 filas). Deps de captura (`chromote`, `httr2`, `polite`) en `DESCRIPTION` **y** en `renv.lock`.
- **B1 cerrado con honestidad.** ADR-007 "Cierre de B1 (2026-09-07)": los 12 originales "nunca se habían perdido, estaban en una segunda máquina de Harold"; la restauración parcial se revirtió. El hallazgo resultó falsa alarma, pero el script-guardián que deja es una mejora real. Documentado, no encubierto.
- **Documentos de auditoría en el repo — cierra el I2 de Fase 1.** `doc/auditorias/` contiene los cuatro informes (Fase 0, Fase 1, verificación de remediación de Fase 1, y la auditoría interna de Fase 2), más un `README.md` de índice que declara qué son y que no tienen autoridad decisoria.
- **Disciplina de commits — conforme, no hallazgo.** 37 commits en `v0.4.0-fase1..v0.5.0-fase2`, 0 merges: todos directos a `main`, que es el flujo documentado desde la remediación de Fase 1 (I1). Secuencia de cierre ordenada: fijar la lectura del criterio (`04fd0f6`) → CAMBIO deja de abortar (`5e65174`) → cierre (`23c1064`).
- **La vía de cierre es la legítima para esta L0.** El criterio ofrece "reconstruye … *o* verifica su integridad". Casi la mitad de L0 (25/54, UT) es captura manual imposible de re-adquirir automáticamente (`robots.txt`, regla 9), y la retropolada es un `.xlsx` estático cerrado: la rama "reconstruye desde cero" es materialmente inalcanzable para ellas, así que tomar la rama "verifica su integridad" no es un atajo sino la lectura correcta. `make raw` es un solo comando sin pasos manuales de descarga/edición; la captura manual de UT es una excepción de regla 9 documentada, no un paso oculto de `make raw`.

---

### Límites de esta verificación — lo que no pude comprobar

1. **Que existan físicamente los 54 archivos de L0 y que `make raw` salga 0.** Los `.xlsx`/`.json` están en `.gitignore` (ADR-008) y `make raw` exige red + `FRED_API_KEY` + Chrome headless + el almacén privado. Verifiqué que los *registros* son internamente consistentes y que la *maquinaria* es correcta; la existencia byte-a-byte y el código de salida dependen de la máquina de Harold. Es la misma distinción que Fase 1 declaró para las 98 filas de `fuente_celda`.
2. **Que `testthat` dé 556 PASS.** No hay R en este entorno. Conté 26 bloques `test_that` (14 en `test-adquisicion.R`, 6 en `test-integridad-referencial.R`, 4 en `test-catalogs.R`, 2 en `test-adr-indice.R`); "556 PASS" cuenta *expectativas* individuales, plausible dado que varios tests iteran sobre filas y aristas, pero no lo repliqué.
3. **El estado de CI sobre `23c1064`.** La API de GitHub (Actions y REST) devolvió `403/429` por rate-limit de IP compartida en todos los intentos —misma limitación que declararon las verificaciones de Fase 1—. El registro de cierre exige "confirmar que el run de CI queda en verde antes de tagear"; conviene que Harold lo confirme, aunque nada de lo tocado en el rango puede razonablemente romper los pasos que sí corren en CI.

---

### Pendientes consolidados

| # | Pendiente | Fuente exacta | Naturaleza |
|---|---|---|---|
| 1 | Propagar "Fase 2 cerrada" a `CLAUDE.md` (línea 11, hoy "Fase 1 en curso") y al "## Estado" del `README.md` raíz (con el tag), y extender el guard anti-regresión a la coincidencia de estado de fase | C1; `CLAUDE.md`, `README.md`, `tests/test-adr-indice.R` | Bloquea el cierre limpio; 3-4 líneas + test |
| 2 | Completar la bitácora de fuentes frágiles a "cada fuente", o acotar su alcance declarado | I1; `doc/bitacora_fuentes_fragiles.md` | Completitud de entregable |
| 3 | Dejar asentada esta revisión independiente del cierre (incorporarla a `doc/auditorias/`) | I2; `doc/auditorias/README.md` | Cierra la brecha de independencia |
| 4 | `CITATION.cff` → `version: 0.5.0`, `date-released: 2026-09-09` | M1 | Cosmético |
| 5 | Renombrar el paso de CI "Validar esquema de catálogos" hasta Fase 3 | M2 | Cosmético |
| — | *Abiertos por diseño (no parte de este cierre):* captura prospectiva de los 15+ CAMBIO en el backlog (continuo, regla 9); política de L0 (ADR-008, corte BCR); inventario `03_series` de las ~25 publicaciones sin serie admitida (compuerta *just-in-time* de Fase 3); integrar la verificación física de L0 a CI/pre-commit en vez de solo `make raw` local | senda §4; ADR-007/008 | No tocar |

---

### Veredicto

**¿Está genuinamente cerrada Fase 2, y bien certificado el cierre? En el fondo técnico, sí; en la certificación, todavía no del todo — por la misma razón que ya falló dos veces.**

El fondo es el más firme de las tres fases: la maquinaria de L0 (físico + cruzado + monitor en vivo) es real, correcta e independientemente consistente cuando la recalculo; los dos hallazgos que dispararon la sesión de cierre (A1 y B1) están cerrados, uno de ellos por resultar falsa alarma y documentado como tal; la lectura del criterio ("verifica su integridad") está fijada, fechada y bien razonada; el pendiente histórico del check de L0 en CI (#16) por fin existe de verdad; y —mejora estructural respecto de Fase 0— **el tag es el commit de cierre**, sin deriva posterior y con la rama de remediación absorbida. Sobre las variables y fuentes efectivamente capturadas, `make raw` es un solo comando que verifica la integridad de L0 sin pasos manuales, que es exactamente lo que el criterio pide por su segunda vía.

Lo que impide darlo por cerrado sin salvedad es C1: el estado de cierre no llegó a los dos archivos que un tercero y los tres agentes leen primero. `CLAUDE.md` afirma "Fase 1 en curso" —falso, y dos fases atrás— y el `README.md` raíz omite Fase 2. Es la tercera aparición del modo C2/C1, esta vez en archivos que el propio test anti-regresión —construido para esta familia— no cubre. No hay decisión que reabrir ni diseño que rehacer: son tres o cuatro líneas, más extender el guard para que no haya una cuarta vez. Los dos IMPORTANTES son de completitud (la bitácora que no es "de cada fuente") y de prueba (la evidencia no reproducible y la autorrevisión no independiente que este informe viene a suplir), y ninguno bloquea el funcionamiento del sistema.

Con C1 propagado —y, idealmente, I1 completado e I2 asentado con esta revisión—, el cierre de Fase 2 queda tan firme como su maquinaria, que ya lo está. Mientras tanto, "Fase 2 cerrada" es cierto en el registro que manda (ADR, senda, tag) y falso en `CLAUDE.md`, y esa contradicción interna sobre el estado del proyecto es, con precisión, lo que estas auditorías existen para no dejar pasar.

---

### Nota de remediación (2026-09-15, Claude Code)

C1, M1 y M2 quedaron corregidos el mismo día en que se recibió este informe: `CLAUDE.md` y
`README.md` ahora declaran Fase 1 y Fase 2 cerradas (tags `v0.4.0-fase1` y `v0.5.0-fase2`),
`tests/test-adr-indice.R` gana un segundo `test_that` que compara la fase declarada en ambos
archivos contra el último "Cierre de Fase N" de `doc/adr/README.md`, `CITATION.cff` pasa a
`version: 0.5.0` / `date-released: 2026-09-09`, y el paso de CI se renombra a "Comprobación
mínima de catálogos (esquema de Fase 3 pendiente)". I1 se completó el mismo día con secciones
de FMI, FRED/Banco Mundial y UT en `doc/bitacora_fuentes_fragiles.md`, usando hechos ya
documentados en `src/adquisicion/README.md` §4, `ut.R` y `.EXCLUIDAS` de
`scripts/verificar_l0.R` — sin inventar ninguno nuevo. I2 queda asentado con la incorporación
de este mismo documento a `doc/auditorias/`.
