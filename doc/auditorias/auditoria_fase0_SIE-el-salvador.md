# Auditoría independiente — SIE El Salvador (Fase 0 y estado post-cierre)

**Repositorio auditado:** https://github.com/hsssst00/SIE-el-salvador
**Commit HEAD de `main` al momento de esta auditoría:** `6631a251` — *"Cierra enmienda de ADR-001: ajuste estacional propio como vía para la…"* (2026-08-07, 12:30 -0600)
**Tag más reciente:** `v0.1.0-fase0` → commit `1739fc85` (2026-08-06, 21:22 -0600)
**Método:** lectura directa del árbol de archivos real (tarball vía `codeload.github.com`), contenido raw de cada archivo, historial de commits y páginas de Actions (vía `github.com` directo, sin depender de memoria de conversaciones previas). No se usó `conversation_search`/`recent_chats` para completar huecos; donde algo relevante solo podría explicarse por contexto de chat, se señala como hallazgo, no se rellena.

---

## Resumen para orientarse

El repositorio está objetivamente en buen estado de higiene general — convenciones de nombres, integridad referencial entre catálogos, y disciplina de fases son mayormente sólidas. Pero la auditoría encontró **un problema estructural real**: el 7 de agosto se enmendó una decisión fundacional (ADR-001) *después* de que Fase 0 ya había sido declarada cerrada y etiquetada (`v0.1.0-fase0`, 6 de agosto), y esa enmienda no se propagó de forma completa ni se re-certificó el cierre. Eso es exactamente el escenario que la propia senda metodológica advierte evitar en su §0.

---

## Hallazgos — CRÍTICO

### C1. El documento fundacional (`senda_metodologica_1.md`) no existe en el repositorio
14 archivos lo citan 24+ veces por número de sección (`README.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `Makefile`, `catalogos/datapackage.json`, `doc/adr/README.md`, `ADR-001/002/003/005/007/009`, `doc/metodologia/protocolo_evaluacion.md`, `src/validacion/validate_catalogs.R`). El propio `README.md` enlaza a `` `doc/senda_metodologica.md` `` — ese archivo no existe en ninguna ruta del árbol real del repositorio (confirmado contra el listado completo del tarball de `main`).

**Consecuencia:** ninguna de las citas "conforme a la senda metodológica §X" es verificable por un tercero que solo tenga el repositorio. Esto falla directamente el criterio de autosuficiencia documental (dimensión 1) y los criterios transversales §10.1–§10.3 que el propio proyecto se impone.

### C2. El tag `v0.1.0-fase0` certifica un estado anterior a la enmienda de ADR-001; el cierre de Fase 0 nunca se re-certificó
Cronología reconstruida por commit (`git log` vía patches individuales):

| Commit | Fecha/hora | Mensaje |
|---|---|---|
| `1739fc85` | 06-ago 21:22 | **"Cierra Fase 0 — CI verificado"** ← tag `v0.1.0-fase0` |
| `7f346460` | 07-ago 11:42 | Primer lote de catálogos (institución, metodología, publicaciones) |
| `9c17b48a` | 07-ago 11:59 | Registra series NSA/SA y retropolado en L0 con checksum |
| `955fc5d3` | 07-ago 12:18 | Corrige atribución de causa de bloqueo de acceso |
| `6631a251` | 07-ago 12:30 | **Cierra enmienda de ADR-001** (HEAD actual de `main`) |

`doc/adr/README.md` fue modificado **una sola vez en todo el historial** — exactamente en el commit del tag (`1739fc85`) — y nunca se ha vuelto a tocar (confirmado por diff de los 9 commits). Su sección "Cierre de Fase 0" sigue citando como evidencia el run de CI `31143916968` (ligado al commit *anterior* al tag), sin ninguna mención de los 4 commits posteriores, incluida la propia enmienda de ADR-001 que invierte una decisión fundacional (D1).

No existe un tag posterior (`v0.1.1`, etc.) que capture el estado enmendado. Quien clone `v0.1.0-fase0` para reproducir "Fase 0 tal como fue cerrada" obtiene la versión *pre-enmienda* de ADR-001 (serie oficial SA = target primario), que el propio proyecto ya considera superada.

### C3. Contradicción directa entre catálogos, dentro del mismo commit que hizo la enmienda
`catalogos/03_series.csv`, fila `BCR.PIB.VOL.SA.Q`, columna `notas`:
> "**Variable objetivo primaria** (ver ADR-001)."

`catalogos/05_series_master.csv`, fila `PIB.SA.OFICIAL.Q` (que referencia exactamente esa misma serie como `series_insumo_ids`):
> `rol = target_robustness` — "Antes target primario en ADR-001 original; **rol invertido** tras hallazgo de cobertura (enmienda 2026-08-07)."

Ambos archivos fueron modificados en el commit `6631a251` (confirmado por diff): `05_series_master.csv` se actualizó correctamente, `03_series.csv` no — la fila `BCR.PIB.VOL.SA.Q` no se tocó y conserva la nota pre-enmienda. Es una contradicción fáctica verificable entre dos catálogos del mismo directorio, no solo una discrepancia con un ADR.

### C4. `ADR-004-shock-2020.md` (cerrado, nunca enmendado) describe el estado previo a la enmienda de ADR-001
Cita textual, sección Decisión:
> "...se trasplantan como variables dicotómicas declaradas (no reestimadas) **a la estimación sobre la serie oficial, que es la variable objetivo primaria**."

Tras la enmienda de ADR-001 (2026-08-07), la serie oficial SA del BCR ya **no** es la variable objetivo primaria — lo es el ajuste propio (X-13ARIMA-SEATS sobre la concatenación NSA). ADR-004 ya declara "Relacionado con: ADR-001" pero no fue enmendado ni recibió una nota cruzada tras el cambio.

### C5. `doc/metodologia/tratamiento_covid.md` hereda la misma ambigüedad
> "...trasplantadas como variables dicotómicas declaradas a la estimación **sobre la serie oficial**."

Mismo problema que C4: "la serie oficial" ya no identifica sin ambigüedad cuál es el target primario tras la enmienda.

### C6. El `renv.lock` comprometido no refleja el stack analítico cerrado en ADR-009 — el criterio de cierre de Fase 0 no está realmente satisfecho para el entorno que el proyecto necesita
`renv.lock` contiene 26 paquetes: exclusivamente infraestructura de testing (`testthat`, `jsonlite`, `here`, `callr`, `cli`, `R6`, `waldo`, etc.). **Ninguno** de los 13 paquetes de análisis fijados en la tabla de ADR-009 (`pointblank`, `duckdb`, `seasonal`, `tempdisagg`, `fable`, `tsibble`, `vars`, `tsDyn`, `BVAR`, `midasr`, `glmnet`, `ranger`, `lightgbm`) está presente.

`scripts/bootstrap_renv.R` — el script que instalaría y fijaría exactamente esos 13 paquetes — nunca se ha ejecutado en este repositorio (lo confirman explícitamente tanto `README.md` como `CLAUDE.md`: *"no se ha corrido todavía en este repositorio"*). El `renv.lock` actual es, casi con certeza, un subproducto de que `r-lib/actions/setup-renv@v2` detectó automáticamente las dependencias de los dos únicos scripts R que existen hoy (`validate_catalogs.R`, `test-catalogs.R`), no una instalación deliberada del stack declarado.

**Consecuencia:** el criterio de cierre de Fase 0 (senda §4: *"un tercero puede clonar el repositorio y reproducir el entorno sin intervención del autor"*) es cierto solo para el andamiaje de pruebas actual — no para el entorno de investigación que Fase 3 en adelante va a necesitar. La declaración "SATISFECHO" en `doc/adr/README.md` no distingue esta diferencia.

---

## Hallazgos — IMPORTANTE

### I1. `CONTRIBUTING.md` exige rama por tarea + PR contra `main` "aunque se trabaje en solitario"; no se siguió ni una vez
Verificado contra la pestaña Pull Requests del repositorio: **0 abiertos, 0 cerrados** en todo el historial. Los 9 commits están todos directamente en `main`. El propio `CONTRIBUTING.md` llama a esto "el sustituto funcional de la revisión por pares" — sustituto que, tal como está, no ha operado ni una sola vez.

### I2. Fecha inconsistente entre el manifiesto de L0 y los nombres de archivo que se supone la codifican
`data/L0_raw/manifiesto.csv`, columna `fecha_descarga` = `2026-08-06` en las 3 filas. Pero los nombres de archivo (que por convención §3.1 de la senda deben llevar `{fecha_descarga}` en el nombre) dicen `2026-08-07`: p. ej. `BCR_pib_t_indices_volumen_nsa_2026-08-07.xlsx`. El campo y el nombre de archivo que —por diseño— debería codificar ese mismo campo no coinciden.

### I3. ADR-004 (cerrado) afirma en tiempo presente algo que el catálogo no respalda
> "Otros quiebres candidatos (...) **se documentan** en el catálogo `09_rupturas`, aunque no se modelen explícitamente."

`catalogos/09_rupturas.csv` está vacío (solo encabezado, cero filas). Es una afirmación que se lee como hecho consumado sin sustento verificable en el propio repositorio (dimensión 6 — trazabilidad epistémica).

### I4. `catalogos/04_transformaciones.csv`, columna `reversible`: tipo declarado `boolean`, valor real es texto libre
Fila `T002_AJUSTE_ESTACIONAL_PROPIO`: `reversible = "parcial (factores estacionales se conservan, permiten reconstrucción aproximada de NSA)"`. El esquema en `datapackage.json` declara este catálogo como `"estado_esquema": "cerrado"` con `reversible` tipo `boolean`. La prueba automatizada actual (`tests/test-catalogs.R`) solo verifica *nombres* de columna, no tipos — por eso esto no falla CI hoy — pero ya incumple el esquema "cerrado" declarado, y romperá la validación real con `pointblank` en Fase 3 si no se corrige antes.

### I5. Violación de la convención de valores ausentes (senda §3.4 / `CLAUDE.md`: "nunca `0`, `-`, `n.d.`")
`catalogos/04_transformaciones.csv`, columnas `script_path` y `funcion`, filas `T001` y `T002`: contienen literalmente el texto `"(pendiente — Fase 3)"` en vez de celda vacía. La convención exige celda vacía para valores ausentes precisamente para evitar este tipo de texto libre no parseable.

### I6. Trabajo de capa L0 (Fase 2) realizado manualmente antes de que exista el pipeline automatizado que Fase 2 exige
`data/L0_raw/manifiesto.csv` ya tiene 3 archivos reales con checksum SHA-256, pero `src/adquisicion/` solo contiene un `.gitkeep` — no existe ningún script de descarga. Las notas en `03_series.csv` y en las YAML de `01_publicaciones` son transparentes al respecto ("Archivo descargado manualmente por Harold — la descarga automatizada devuelve la página HTML interactiva del portal"), y ADR-007 ya anticipa captura manual como estado transitorio ("Hasta entonces, la captura es manual"). No es una violación oculta — está documentada — pero es trabajo materialmente de Fase 2 ejecutado mientras el proyecto se declara en Fase 0/1. Vale la pena que quede explícito como tal, no solo implícito en notas de catálogo.

---

## Hallazgos — MENOR

### M1. Identificador `BCR.PIB.VOL.NSA.Q.RETRO` se desvía del patrón estricto de §3.4
La convención declarada es `{fuente}.{concepto}.{unidad}.{ajuste}.{frecuencia}` (5 componentes). Este identificador añade un sexto componente (`.RETRO`) no documentado como extensión permitida.

### M2. Encabezado de `doc/adr/README.md` atribuye D9 a la senda §2 de forma imprecisa
Dice "Cada decisión fundacional (D1–D9, senda metodológica §2)". Pero el propio ADR-009 aclara correctamente que el stack tecnológico "no [está] contemplada explícitamente... ni enumerada entre D1–D8 de la senda metodológica" — y en efecto, la senda (§2) abre con "Estas **ocho** decisiones deben quedar cerradas...", listando solo D1–D8. ADR-009 se autojustifica bien; el índice que lo agrupa bajo "D1–D9 §2" es la pieza imprecisa.

### M3. Modelo de campo único `url` en `01_publicaciones` no representa bien una relación 1-a-2 ya prevista en el modelo conceptual
`BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS.yaml` tiene un solo campo `url` (apunta a la variante SA), pero ese mismo `publicacion_id` cubre en la práctica 2 archivos/series (NSA y SA) con 2 vintages distintos en `08_vintages.csv`. Está documentado razonablemente en `notas`, pero el esquema no modela explícitamente la relación 1-a-muchos que el propio diagrama conceptual (§3.2) ya anticipa.

### M4. `CITATION.cff` no incluye `version` ni `repository-code`
Campos opcionales pero recomendados por el estándar CFF, particularmente relevantes ahora que existe un tag versionado (`v0.1.0-fase0`) que podría referenciarse explícitamente.

---

## Verificaciones que resultaron limpias (vale la pena decirlo)

- **Integridad referencial:** todas las claves foráneas verificadas (`publicacion_id`, `metodologia_id`, `series_insumo` en `04_transformaciones`, `transf_id`/`series_insumo_ids` en `05_series_master`, `publicacion_id`/`vintage_id` en `manifiesto.csv`) resuelven contra registros que sí existen.
- **Coincidencia de columnas CSV vs. esquema:** exacta en `03_series`, `04_transformaciones`, `05_series_master`, `07_experimentos`, `08_vintages` — nombre y orden idénticos a `datapackage.json`. Esto está activamente cubierto por `tests/test-catalogs.R`.
- **Disciplina de fases (fuera de I6):** no hay código de estimación, evaluación ni transformación materializada en `src/modelos`, `src/evaluacion`, `src/transformacion` — todos son `.gitkeep`. Ningún adelanto hacia Fase 4/5.
- **Fidelidad D1–D8 → ADR:** cada ADR revisado contra su sección correspondiente de la senda mantiene coherencia sustantiva; las elaboraciones que van más allá del texto original (p. ej. acotar la reconstrucción retrospectiva de vintages al período SCN 2008 en ADR-007) están explícitamente justificadas en el propio ADR, no son deriva silenciosa.
- **Estado de CI:** la corrida más reciente (Run 5, commit `6631a251` = HEAD actual) terminó en verde, confirmado independientemente contra la página de Actions. Matiz: el job `check-l0-integrity` es un *stub* (`echo "Pendiente..."`) que siempre "pasa" sin verificar checksums reales — el verde de CI no incluye, todavía, verificación de integridad de L0.

---

## Pendientes consolidados (dimensión 8)

| # | Pendiente | Fuente exacta | Fase |
|---|---|---|---|
| 1 | Localizar y citar nota metodológica del BCR sobre método de retropolación | `ADR-003`; `doc/metodologia/empalme_cuentas_nacionales.md` | 1 |
| 2 | Confirmar si superposición de 4 trimestres es calibración documentada o coincidencia | `doc/metodologia/empalme_cuentas_nacionales.md` | 1 |
| 3 | Registrar N de observaciones en cada actualización trimestral | `doc/metodologia/empalme_cuentas_nacionales.md` | continuo |
| 4 | Condiciones de uso/redistribución — DIGESTYC/ONEC, ISSS, organismos internacionales | `ADR-008` (estado: Parcial) | 1 |
| 5 | Localizar página específica de términos de uso/aviso legal del BCR | `ADR-008`, enmienda BCR | 1 |
| 6 | Documentar fechas exactas de outlier detectadas por `seasonal` | `doc/metodologia/tratamiento_covid.md` | 3 |
| 7 | Reportar resultado del contraste de submuestras pre/post 2020 | `doc/metodologia/tratamiento_covid.md` | 5 |
| 8 | Cruzar referencia de quiebres con `09_rupturas.csv` (ver C/I3 arriba) | `doc/metodologia/tratamiento_covid.md`; `ADR-004` | 3 |
| 9 | Verificar motor de evaluación contra datos sintéticos antes de estimar modelos reales — no negociable | `doc/metodologia/protocolo_evaluacion.md` | 4 |
| 10 | Documentar grilla de hiperparámetros y criterio de selección | `doc/metodologia/protocolo_evaluacion.md` §5.2 | 4 |
| 11 | Fijar publicaciones específicas WEO / Fed / BEA / CBO | `doc/metodologia/supuestos_escenarios.md` | 6 |
| 12 | Definir 2–3 escenarios explícitos con supuestos citados | `doc/metodologia/supuestos_escenarios.md` | 6 |
| 13 | Análisis de sensibilidad a los supuestos exógenos | `doc/metodologia/supuestos_escenarios.md` | 6 |
| 14 | Especificar `script_path`/`función` reales del ajuste estacional propio | `catalogos/04_transformaciones.csv` (T001, T002) | 3 |
| 15 | Implementar objetivos reales de `raw`, `master`, `validate`, `eval`, `report` | `Makefile` | 2–7 |
| 16 | Script real de verificación de checksums contra el manifiesto de L0 | `.github/workflows/ci.yml`, job `check-l0-integrity` | 2 |
| 17 | Scripts de descarga automatizada (hoy la captura es manual) | `src/adquisicion/` (vacío) | 2 |

---

## Veredicto

**¿Sigue siendo válido hoy el criterio de cierre de Fase 0, con todo lo agregado después del cierre formal? No, tal como está documentado.**

Leído en su sentido más estrecho y literal —"un tercero puede clonar el repositorio y hacer que `renv::restore()` + validación + pruebas corran en verde"— el criterio se cumple hoy mismo: lo confirmé de forma independiente contra la corrida de CI más reciente (verde). Pero interpretado como la senda metodológica claramente lo pretende —una base fundacional verificada, autocontenida y estable sobre la que Fase 1 en adelante puede construirse sin tener que reconstruir nada— **no se sostiene**, por tres razones concretas y verificables, no por interpretación:

1. El documento que sustenta cada decisión (la senda metodológica misma) no está en el repositorio que se supone es autosuficiente.
2. La decisión fundacional D1 (variable objetivo) fue enmendada *después* de que Fase 0 se declarara cerrada y se etiquetara como tal, y esa enmienda no se propagó por completo (C3, C4, C5) ni se volvió a certificar el cierre (C2).
3. El entorno reproducible que efectivamente se verifica en CI no es el entorno que el proyecto necesita (C6) — es el entorno mínimo que hace pasar las dos pruebas que existen hoy.

Ninguno de estos tres puntos es difícil de resolver — no hay decisión que reabrir, son huecos de propagación y de certificación, no errores de diseño. Pero mientras no se resuelvan, cualquier afirmación de que "Fase 0 está cerrada" debería leerse con esa salvedad explícita.
