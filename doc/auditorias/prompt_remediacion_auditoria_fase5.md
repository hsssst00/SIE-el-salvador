# Prompt para Claude Code — Remediación de la auditoría independiente de Fase 5

**Proyecto:** SIE El Salvador (`github.com/hsssst00/SIE-el-salvador`).
**Informe que se remedia:** auditoría independiente del cierre de Fase 5, commit auditado `7093f7c` (2026-10-13). El texto completo va en el **Anexo A** y se deposita en el repositorio en el PR-5.
**Hallazgos:** 0 CRÍTICOS; IMPORTANTES I1–I4; MENORES M1–M5.
**Estado de partida verificado:** `origin/main` = `7093f7c` (clon fresco del 2026-10-13, 15:10 -0600). No existe ningún tag `v0.8*`.
**Preparado por:** Claude chat (rol de auditoría y verificación). **Ejecuta:** Claude Code en la máquina del proyecto (Windows, R 4.6.1), con la L4 de la corrida única en disco. **Decide y hace commit:** Harold.

---

## 0. Cómo trabajar (léelo entero antes de tocar nada)

1. **No hagas commits, ni push, ni tags.** Prepara cada PR en su rama, deja los cambios sin commit y detente. Muéstrale a Harold `git status` y `git diff --stat`, y el resultado de las verificaciones del PR. Harold revisa, hace commit, abre el PR, espera el CI y fusiona. Recién entonces sigues con el PR siguiente, partiendo de `main` actualizado (`git switch main && git pull`).
2. **Las decisiones son de Harold (regla 4 de `CLAUDE.md`).** El bloque A trae las respuestas que Harold marcó antes de pasarte este prompt. Si una respuesta está vacía, no la infieras: salta los pasos que dependen de ella, dilo en tu informe y sigue con lo demás. No escribas nada rotulado «delegada al agente»: esta remediación existe en parte porque hubo demasiadas.
3. **No se reescribe ningún registro.** Auditorías, registros de cierre, notas de la senda, evidencias, actas de decisiones y el informe de lectura reciben **notas fechadas**; su texto existente no se edita. Las únicas ediciones de texto existente que pide este prompt están dichas explícitamente, con su «antes» y su «después».
4. **Fechas.** Donde este prompt dice `AAAA-MM-DD`, pon la fecha del día en que preparas el cambio. Donde dice `<commit>` o `<run>`, pon el valor real, verificado. Nunca dejes un marcador sin reemplazar en un archivo.
5. **Prohibido en esta remediación:**
   - correr `make eval`, `make fase5`, `make master` o `src/evaluacion/motor_backtesting.R` (reescriben `catalogos/07_experimentos.csv` y L4, y tardan horas);
   - tocar `data/L0_raw/`, `data/L4_experiments/`, `catalogos/07_experimentos.csv`, `doc/metodologia/reportes_fase5/tabla_resultados_fase5.csv` o `doc/evidencia_cierre_fase4.txt`;
   - mover, crear o borrar tags; `push --force`; cambiar `renv.lock`;
   - introducir otro lenguaje que no sea R (regla 5).
6. **Pruebas en Windows:** corre la suite con `Rscript -e "testthat::test_dir('tests')"`, no con `make test` (segfault conocido de `cli`, `doc/entorno_windows.md`).
7. **Si algo no coincide con lo que este prompt da por verificado** (un número de línea, un texto «antes», un conteo esperado, un sha256), detente en ese punto y repórtalo. No ajustes el prompt a la realidad por tu cuenta.

### Paso 0 — Comprobar el punto de partida

```bash
git fetch origin && git switch main && git pull --ff-only
git log -1 --format='%H %s'          # esperado: 7093f7cba0dd743f12edb36136938c64c2e33447 Merge pull request #54 …
git status --short                   # esperado: vacío
git tag -l 'v0.8*'                   # esperado: vacío
```

Si `main` ya no está en `7093f7c`, detente: Harold debe regenerar o confirmar este prompt.

---

## A. Decisiones de Harold (las marca Harold antes de pasar el prompt)

> **Harold:** marca una opción por pregunta con `[x]`. Lo que quede sin marcar, Claude Code lo salta.

**A1 · I2 — Lecturas del criterio de cierre de Fase 5** (senda §4, nota de cierre v0.9: «una sola orden», «reproducible», «todo resultado reportado», «una semilla fijada»).
- [ ] (a) Las adopto tal como están escritas. *Recomendada salvo que quieras cambiar alguna.*
- [ ] (b) Las adopto con estos cambios: ____________________________________________

**A2 · I2 — Cambios posteriores al congelamiento** (E2-1: arranques alternativos de `UNI.UC_LLT`; E2-2: GW degenerada o NA marcado).
- [ ] (a) Adopto E2-1 y E2-2 tal como están.
- [ ] (b) Adopto con estos cambios o reservas: ____________________________________

**A3 · I2 — Régimen de delegación al agente** (autorización del 2026-10-08, «que el agente avance sin supervisión»).
- [ ] (a) Terminó con el cierre de Fase 5. Desde ahora rige la regla 4 sin excepciones. *Recomendada.*
- [ ] (b) Sigue vigente, acotada: el agente puede fijar detalles de implementación que una ficha no fija, rotulados como delegados; nunca lecturas de un criterio de cierre, cambios posteriores a un congelamiento, reglas de evaluación o de lectura de resultados, ni registros de cierre. Rige hasta: ______________

**A4 · Ruta del tag** (el registro de cierre deja `v0.8.0-fase5` propuesto; `ubuntu-latest` cambia de imagen el 2026-10-19).
- [ ] (a) `v0.8.0-fase5` sobre el merge del PR-1 (que ya contiene la adopción de A1–A3 y la corrección de I1), antes del 2026-10-19; el resto de la remediación va a `v0.8.1-fase5`. *Recomendada: la auditoría pide cerrar I1 e I2 antes del tag.*
- [ ] (b) `v0.8.0-fase5` sobre `7093f7c` ya, y toda la remediación a `v0.8.1-fase5` (precedente de Fase 4).

**A5 · M5 e I4 — CI** (marca las que apruebes; son independientes).
- [ ] (a) Fijar `r-version: '4.6.1'` en los dos jobs.
- [ ] (b) Fijar `runs-on: ubuntu-24.04` en los dos jobs (en lugar de `ubuntu-latest`).
- [ ] (c) Fijar la BLAS/LAPACK de referencia en el job `validate-and-test`.

**A6 · M4 — ADR-008, corte del BCR (vencido el 2026-10-12)**
- ¿Hubo pronunciamiento del BCR? [ ] No · [ ] Sí, el ____ (resumen: _______________________________)
- Política de L0 que estaba aplazada al BCR: [ ] (i) única para todas las fuentes · [ ] (ii) por fuente · [ ] (iii) la aplazo otra vez hasta: ____
- Tramos Banco Mundial y BID (enganchados al mismo disparador): ______________________________

**A7 · I3 — Formato de la tabla de pruebas** (Anexo B: `tabla_pruebas_fase5.csv`, `tabla_estabilidad_fase5.csv` y `extracto_pronosticos_fase5.csv`, en `doc/metodologia/reportes_fase5/`, también en `make eval`).
- [ ] (a) Apruebo el formato del Anexo B tal cual. *Recomendada.*
- [ ] (b) Con estos cambios: ____________________________________________

---

## PR-1 · `remediacion-f5/notas` — I1, I2 y M2 (depende de A1, A2 y A3)

Si A1, A2 o A3 están vacías, haz solo las partes 1.1, 1.2, 1.6 y 1.7, y dilo.

### 1.1 · I1 — Nota de corrección en el protocolo §6

Archivo `doc/metodologia/protocolo_evaluacion.md`. Inserta un párrafo nuevo **entre** estas dos piezas (líneas 418-420 y 422-424 en `7093f7c`), sin tocarlas:

Antes (fin del párrafo existente, se conserva):
```
pronósticos no se guardaron ni se miraron. Ningún otro modelo, YAML ni experimento cambió. Ningún resultado de Fase 5
existía antes de estos cambios, así que la comparación sigue preregistrada.
```
Párrafo nuevo (después de una línea en blanco):
```
**Nota de corrección (AAAA-MM-DD, auditoría independiente de Fase 5, hallazgo I1).** La frase «Ningún resultado de
Fase 5 existía antes de estos cambios» es inexacta; el texto de arriba se conserva sin editar. Los intentos 3 (sobre
`189e629`) y 4 (sobre `c63f318`) escribieron completos en `data/L4_experiments/` cinco experimentos `F5_G*`: `F5_G1`,
`F5_G2`, `F5_G3`, `F5_G1_R1` y `F5_G2_R1` (`doc/evidencia_corrida_unica_fase5.txt`). Los dos intentos son anteriores a
E2-2 (`cf26a62` y `d8d045e`), que se decidió con esos resultados en disco. E2-1 (`39884c6`) sí es anterior a cualquier
`F5_G*` terminado. E2-2 no alteró los resultados ya escritos: los 130 archivos de esos 18 directorios (excluidas del
manifiesto las líneas de commit, árbol y fecha) son idénticos byte a byte en los intentos 3, 4 y 5. A la lista de cambios posteriores al congelamiento se agregan dos que
no cambian ningún modelo, YAML ni experimento: `51cc015` (formato de la tabla de resultados de Fase 5) y `b400a25`
(prueba de los arranques de UC). El intento 3 se lanzó sobre `189e629`, con el CI de `main` en rojo (run #333) por esa
prueba; la corrida citada (`e1722fa`) tiene CI en verde (run #341).
```

Y después de la regla existente de Fase 4 (que termina en `(precedente: C8, \`a78d2c6\`).`), antes de `## 7. Lo que este protocolo no cubre`, agrega:
```
**[AAAA-MM-DD, auditoría independiente de Fase 5, hallazgo I1]** Toda corrida sobre L3 que se detenga antes de
terminar asienta en su evidencia qué directorios de `data/L4_experiments/` dejó escritos y sobre qué commit. Toda
decisión que se tome con resultados en disco lo dice, aunque esos resultados no se hayan mirado.
```

### 1.2 · I1 y M2 — Nota de corrección en el acta de Fase 5

Archivo `doc/metodologia/decisiones_fase5.md`, sección `## Corrida única (E2): cambios después del congelamiento (2026-10-08)`. Inserta antes de la línea `---` que cierra la sección (línea 1477 en `7093f7c`, justo antes de `## F5-16 — Cadencia de actualización…`), con una línea en blanco antes y otra después:
```
**Nota de corrección (AAAA-MM-DD, auditoría independiente de Fase 5, hallazgos I1 y M2).** La corrida se detuvo
cuatro veces, no tres: en el maestro (intento 1), en `UNI.UC_LLT` (intento 2) y dos veces en la misma celda de GW
(intentos 3 y 4; `doc/evidencia_corrida_unica_fase5.txt`). Los intentos 3 y 4 escribieron completos cinco experimentos
`F5_G*` antes de E2-2; el detalle está en la nota de corrección del protocolo §6. El texto de arriba se conserva sin
editar.
```
Si A2 está marcada, agrega a continuación:
```
**Adopción (AAAA-MM-DD, Harold; auditoría independiente de Fase 5, hallazgo I2).** E2-1 y E2-2 dejan de ser decisiones
delegadas: Harold las adopta <tal como están | con estos cambios: …, según A2>.
```

### 1.3 · I2 — Adopción de las lecturas en la senda §4 (A1)

Archivo `doc/senda_metodologica.md`.
- Después de la línea `El registro del cierre, con su evidencia, está en \`doc/adr/README.md\`, «Cierre de Fase 5».` (línea 579), inserta (con línea en blanco antes):
```
**Adopción de las lecturas (AAAA-MM-DD, Harold; auditoría independiente de Fase 5, hallazgo I2).** Las cuatro lecturas
de esta nota dejan de ser decisiones delegadas al agente: Harold las adopta <tal como están escritas | con estos
cambios: …, según A1>. Con eso, el criterio de cierre de Fase 5 queda leído por quien declara el avance de fase, como
en las Fases 1 a 4.
```
- Encabezado: `**Versión:** 0.9 — documento de trabajo, enmendado` → `**Versión:** 0.10 — documento de trabajo, enmendado`, y al final de la línea `**Fecha:**` agrega `; AAAA-MM-DD (v0.10)`.
- Historial: después de la entrada `- **0.9** (2026-10-13): …` (termina en `Sin otros cambios de contenido.`), inserta:
```
- **0.10** (AAAA-MM-DD): añade a la nota de cierre de Fase 5 la adopción de sus lecturas por Harold (hallazgo I2 de la
  auditoría independiente de Fase 5). Sin otros cambios de contenido.
```

### 1.4 · I2 — Registro de cierre (A1, A2)

Archivo `doc/adr/README.md`. Al final del archivo (hoy termina la sección `## Cierre de Fase 5 (2026-10-13)` con `…quedan a cargo de Harold.`), agrega:
```

### Nota de corrección (AAAA-MM-DD) — auditoría independiente de Fase 5, hallazgo I1

La evidencia «Preregistro» de este registro remite al protocolo §6 para los cambios posteriores al congelamiento. Esa
nota afirmaba que ningún resultado de Fase 5 existía antes de ellos, y no era exacto: los intentos 3 y 4 de la corrida
única escribieron cinco experimentos `F5_G*` antes de E2-2, sin que E2-2 los alterara (ver la nota de corrección del
protocolo §6, AAAA-MM-DD). El texto de este registro se conserva sin editar.

### Adopción de las lecturas y de E2-1 y E2-2 (AAAA-MM-DD) — auditoría independiente de Fase 5, hallazgo I2

Harold adopta las cuatro lecturas del criterio de cierre (senda §4, nota de adopción de la v0.10) y los cambios E2-1
y E2-2 (`doc/metodologia/decisiones_fase5.md`). Dejan de ser decisiones delegadas al agente y de estar abiertas a
reapertura por esa razón.
```
**Cuidado con el guard de `CITATION.cff`** (`tests/test-adr-indice.R`): dentro de la sección `## Cierre de Fase 5` no escribas ninguna cadena con forma `vX.Y.Z-fase5` distinta de `v0.8.0-fase5`, y no agregues ningún encabezado `## ` nuevo en este PR.

### 1.5 · I2 — Régimen de delegación en `CLAUDE.md` (A3)

Archivo `CLAUDE.md`. Debajo de la regla 4 (línea 20, que empieza `4. **Ante una decisión metodológica no cubierta por un ADR existente, detente y pregunta.**`), agrega un párrafo indentado con tres espacios, sin cambiar el texto de la regla:

Si A3 = (a):
```
   **Delegación al agente en Fase 5 (AAAA-MM-DD, auditoría independiente de Fase 5, hallazgo I2).** Entre el
   2026-10-08 y el 2026-10-13, Harold autorizó que el agente avanzara sin supervisión en Fase 5 y fijara detalles de
   implementación, rotulados «delegada al agente» en `doc/metodologia/decisiones_fase5.md`. Esa autorización terminó
   con el cierre de Fase 5. Desde el AAAA-MM-DD esta regla rige sin excepciones.
```
Si A3 = (b):
```
   **Delegación al agente (AAAA-MM-DD, auditoría independiente de Fase 5, hallazgo I2).** Desde el 2026-10-08, y hasta
   <fecha o evento de A3>, el agente puede fijar detalles de implementación que una ficha no fija, rotulados «delegada
   al agente; se puede reabrir». Nunca puede decidir lecturas de un criterio de cierre, cambios posteriores a un
   congelamiento de preregistro, reglas de evaluación o de lectura de resultados, ni el contenido de un registro de
   cierre: esas decisiones se preguntan siempre.
```

### 1.6 · M2 — Cabecera de V5 en la verificación sintética

Archivo `src/evaluacion/verificar_motor_sintetico.R`, línea 32 (solo un comentario; la salida no cambia).
- Antes: `#   V5   (extensión F4-34, al final del archivo) canario de predictora anual: UT solo con años cerrados`
- Después: `#   V5   (extensión F4-34, al final del archivo) canario de predictora anual (rama retenida sin series; UT usa 30 días desde F5-04)`

### 1.7 · M2 — Frase del protocolo §2.3

Archivo `doc/metodologia/protocolo_evaluacion.md`. Inmediatamente después del párrafo que termina en `remediación de la auditoría de Fase 4, A3 y E4).` (línea 144) y antes de `**[decidido 2026-09-29, F4-34]**`, agrega:
```
**Nota (AAAA-MM-DD, auditoría independiente de Fase 5, hallazgo M2).** «Siguen pendientes» describe el 2026-09-29 por
la mañana: F4-34 fijó la forma operativa ese mismo día (párrafo siguiente) y para Fase 5 la reemplazó F5-04.
```

### Verificación del PR-1 (antes de detenerte)

```bash
Rscript -e "testthat::test_dir('tests')"     # esperado: FAIL 0. Anota PASS y SKIP de esta corrida: son la base de los PR siguientes
                                              # (en Linux, sobre 7093f7c, la auditoría obtuvo 2954 PASS / 0 SKIP; en Windows puede variar)
grep -n 'AAAA-MM-DD\|<commit>\|<run>\|según A[0-9]' doc/metodologia/protocolo_evaluacion.md doc/metodologia/decisiones_fase5.md doc/senda_metodologica.md doc/adr/README.md CLAUDE.md   # esperado: nada
git diff --stat                               # esperado: solo los 6 archivos de 1.1-1.7
```
Mensaje de commit sugerido para Harold: `Remediación F5 (I1, I2, M2): correcciones fechadas, adopción de las lecturas del cierre y régimen de delegación`.

**Después del merge del PR-1, si A4 = (a):** Harold confirma el CI verde sobre el merge y crea el tag anotado `v0.8.0-fase5` con un mensaje como: «Cierre de Fase 5: criterio de senda §4 SATISFECHO con las lecturas adoptadas por Harold (v0.10). Incluye la corrección I1 y la adopción I2 de la auditoría independiente. CI verde: run <run>.» Claude Code no crea el tag.

---

## PR-2 · `remediacion-f5/evidencia` — I3 e I4 (depende de A7 para I3)

### 2.1 · I3 — Tabla de pruebas, de estabilidad y extracto de pronósticos

1. Crea `src/evaluacion/tabla_pruebas_fase5.R` con el contenido **exacto** del Anexo B, y `tests/test-tabla-pruebas.R` con el del Anexo C. Los dos se probaron en Linux con R 4.6.1 sobre `7093f7c`: 23 PASS, y la suite completa 2977 PASS / 0 FAIL / 0 SKIP.
2. `Makefile`, objetivo `eval`: después de la línea `	Rscript src/evaluacion/tabla_resultados_fase5.R` agrega `	Rscript src/evaluacion/tabla_pruebas_fase5.R` (con tabulador). En el comentario del objetivo, al final de `# doc/metodologia/reportes_fase4/tabla_resultados_fase4.csv (F4-30).`, no cambies nada; agrega debajo una línea `# Fase 5: también tabla_resultados_fase5.csv y, desde la remediación I3 de su auditoría, tabla_pruebas_fase5.csv, tabla_estabilidad_fase5.csv y extracto_pronosticos_fase5.csv.`
3. Genera las tres tablas **desde la L4 que ya tienes en disco** (no corras el motor):
   ```bash
   Rscript src/evaluacion/tabla_pruebas_fase5.R
   ```
   El script comprueba, antes de leer cada archivo, que su sha256 es el que lista el `manifiesto.txt` del experimento, que el manifiesto es del commit registrado en `07_experimentos.csv` (hoy `e1722fa9371c…`, para los 15) y que el árbol estaba limpio. Además contrasta `marca_n` con `tabla_resultados_fase5.csv`.
   **Esperado:** `tabla_pruebas_fase5.csv` con **2056** filas (1860 DM/HLN + 196 GW), `tabla_estabilidad_fase5.csv` con **172**, `extracto_pronosticos_fase5.csv` con **84** (21 modelos × 2 orígenes × 2 horizontes).
   **Si el script se detiene** (por ejemplo, en `F5_G3_R1` o `F5_G3_R2`, cuyos manifiestos reescribió la segunda pasada del 2026-10-09), **detente y reporta el mensaje exacto**. No regeneres ningún experimento ni edites un manifiesto: lo decide Harold. Si los conteos no son los esperados, también detente y reporta.
4. Comprueba en el extracto que `REG.ENET.G3`, origen 2021-Q1, da −348 pp (h = 8) y +338 pp (h = 4), y que `MULT.BVAR.G3`, origen 2020-Q2, da −126 pp (h = 8), redondeados como los cita el informe de lectura §3.3. Si no coinciden, detente y reporta.
5. Nota en `doc/metodologia/reportes_fase5/lectura_resultados_fase5.md`, inmediatamente después de la línea 17 (`- Pronósticos puntuales citados en §3.3: \`pronosticos.csv\` de \`F5_G3\`.`):
   ```
   - **Nota (AAAA-MM-DD, auditoría independiente de Fase 5, hallazgo I3).** Desde la remediación de I3, las cifras de DM/HLN, GW y
     estabilidad que cita este informe están versionadas en `tabla_pruebas_fase5.csv` (sha256 sin CR `<sha>`) y
     `tabla_estabilidad_fase5.csv` (`<sha>`), y los pronósticos de §3.3 en `extracto_pronosticos_fase5.csv` (`<sha>`), en
     esta misma carpeta. Las genera `src/evaluacion/tabla_pruebas_fase5.R` desde la L4 de `e1722fa`, sin volver a correr
     el motor. El texto de este informe no cambia.
   ```
   (Los tres sha256 van reales: los imprime el script al generar.)

### 2.2 · I4 — BLAS/LAPACK de la corrida y alcance de la paridad

1. Extrae de los 28 `data/L4_experiments/F5_*/manifiesto.txt` el bloque de `sessionInfo()` desde `Matrix products:` hasta la línea anterior a `locale:`. Comprueba que es idéntico en los 28 y transcríbelo literal. Si en Windows ese bloque solo dice `Matrix products: default`, agrega la salida de `Rscript --vanilla -e "La_library(); La_version(); extSoftVersion()['BLAS']"` en la misma máquina, y declara que es una lectura de hoy sobre la misma instalación de R.
2. Nota al final de `doc/evidencia_corrida_unica_fase5.txt` (después de la nota del 2026-10-13, con una línea en blanco):
   ```
   Nota AAAA-MM-DD (remediación de I3 e I4 de la auditoría independiente de Fase 5).
   BLAS/LAPACK de la corrida: <bloque transcrito, idéntico en los 28 manifiestos>
   La reproducción bit a bit de F1 se hizo con esa librería y la exige: la auditoría mostró que en Linux, con la
   BLAS/LAPACK de referencia, V1-V11 y el random forest de V20 dan lo mismo que en Windows, y con OpenBLAS no.
   Tablas de pruebas generadas desde la L4 de esta corrida (src/evaluacion/tabla_pruebas_fase5.R), sin volver a
   correr el motor; cada archivo leído coincide con el sha256 de su manifiesto:
     tabla_pruebas_fase5.csv          <n> filas  sha256 <sha>
     tabla_estabilidad_fase5.csv      <n> filas  sha256 <sha>
     extracto_pronosticos_fase5.csv   <n> filas  sha256 <sha>
   ```
3. Nota de corrección en `doc/adr/README.md`, al final de la sección `## Cierre de Fase 5` (después de lo que agregó el PR-1):
   ```

   ### Nota de corrección (AAAA-MM-DD) — auditoría independiente de Fase 5, hallazgos I3 e I4

   **I3.** Las cifras de DM/HLN, GW y estabilidad y los pronósticos citados en este registro están versionados, desde
   esta remediación, en `doc/metodologia/reportes_fase5/` (`tabla_pruebas_fase5.csv`, `tabla_estabilidad_fase5.csv` y
   `extracto_pronosticos_fase5.csv`), generados desde la L4 de `e1722fa`.

   **I4.** La frase «Entre Windows y Linux, el BVAR y el random forest no son bit a bit; la paridad se declara hasta el
   error de Monte Carlo» se conserva sin editar, con tres precisiones:
   1. Lo que separa los resultados es la librería BLAS/LAPACK, no el sistema operativo. La de la corrida única está en
      la nota del AAAA-MM-DD de `doc/evidencia_corrida_unica_fase5.txt`, y la reproducción bit a bit la exige.
   2. La paridad hasta el error de Monte Carlo está verificada solo para el BVAR (V17). La del random forest y la de
      `UNI.UC_LLT`, cuya convergencia depende de la plataforma (nota de E2-1 en F5-06), no están acotadas, y tampoco
      las de las combinaciones que los contienen.
   3. Un tercero que reproduzca en otra máquina debe usar la misma BLAS/LAPACK para esperar resultados bit a bit.
   ```
   (Mismo cuidado con el guard: ninguna otra cadena `vX.Y.Z-fase5` en esta sección.)
4. Nota en la senda, debajo de la nota de adopción del PR-1:
   ```
   **Nota (AAAA-MM-DD, auditoría independiente de Fase 5, hallazgo I4).** En la lectura de «reproducible», «entre
   sistemas operativos» se lee «entre librerías BLAS/LAPACK»: con la misma librería, Linux reproduce lo que da Windows
   en V1-V11 y en el random forest de V20. La paridad hasta el error de Monte Carlo está verificada solo para el BVAR;
   la del random forest, la de `UNI.UC_LLT` y la de las combinaciones que los contienen no están acotadas. La BLAS/LAPACK
   de la corrida única está en `doc/evidencia_corrida_unica_fase5.txt`.
   ```
   Encabezado `**Versión:**` → 0.11, `**Fecha:**` agrega `; AAAA-MM-DD (v0.11)`, y en el historial, después de la entrada 0.10:
   ```
   - **0.11** (AAAA-MM-DD): añade a la nota de cierre de Fase 5 la precisión sobre BLAS/LAPACK y el alcance de la
     paridad entre sistemas (hallazgo I4 de la auditoría independiente de Fase 5). Sin otros cambios de contenido.
   ```

### Verificación del PR-2

```bash
Rscript -e "testthat::test_dir('tests')"                 # esperado: FAIL 0; PASS = base del PR-1 + 23; SKIP = el de la base
Rscript src/evaluacion/verificar_motor_sintetico.R        # esperado, última línea: verificación sintética: bloques OK (V1-V21)
Rscript src/evaluacion/tabla_pruebas_fase5.R              # segunda corrida: mismos tres sha256 (LF, deterministas)
git status --short   # esperado: el script, la prueba, el Makefile, las tres tablas nuevas, el informe de lectura,
                     # la evidencia, doc/adr/README.md y la senda. NADA en data/, catalogos/ ni tabla_resultados_fase5.csv
```
Mensaje sugerido: `Remediación F5 (I3, I4): tabla de pruebas, estabilidad y extracto versionados desde la L4 de e1722fa; BLAS de la corrida y alcance de la paridad`.

---

## PR-3 · `remediacion-f5/higiene` — M1, M3 y M5 (M5 depende de A5)

### 3.1 · M1 — Checklist de Fase 5

Archivo `doc/checklist_fase5.md`. En cada uno de estos ítems cambia `- [ ]` por `- [x]` y agrega, como última línea del ítem (indentada con dos espacios, como las demás), la evidencia indicada:

| Ítem (línea en `7093f7c`) | Línea a agregar |
|---|---|
| **C1 · F5-03** (61) | `**Cierre (AAAA-MM-DD, remediación M1 de la auditoría independiente de Fase 5):** G-8 en B1a (PR #31, \`8d72e83\`, run #255); prueba del primer origen en B1b (PR #32, \`ad47bc1\`, run #260) y B2a (PR #33, \`821eaac\`, run #265); BVAR sin piso (B2-7), probado en el PR #37 (\`ac958a8\`, run #283).` |
| **C2 · F5-04** (71) | `**Cierre (AAAA-MM-DD, remediación M1):** PR #31 (\`8d72e83\`), CI verde en \`main\` (run #255).` |
| **C5 · F5-12** (87) | `**Cierre (AAAA-MM-DD, remediación M1):** V14 (PR #32, run #260), V15 (#33, run #265), V16 (#37, run #283), V18 (#42, \`3623032\`, run #306), V19 (#43, \`f6028fd\`, run #309) y V20 (#44, \`acacc3f\`, run #316); la cobertura del RF con dos réplicas es una comprobación débil declarada.` |
| **D1 · B1** (112) | `**Cierre (AAAA-MM-DD, remediación M1):** B1a (PR #31, run #255) y B1b (PR #32, run #260).` |
| **D2 · B2** (114) | `**Cierre (AAAA-MM-DD, remediación M1):** B2a (PR #33, run #265), B2-9 (PR #34, \`a91b791\`, run #268) y B2b (PR #37, run #283).` |
| **D6 · B5** (130) | `**Cierre (AAAA-MM-DD, remediación M1):** PR #45 (\`c2598f4\`, run #323).` |

No marques **F3**: se marca en el PR-5.

### 3.2 · M3 — Una sola orden

Archivo `Makefile`.
- En `.PHONY` (línea 5), agrega `fase5` al final.
- Después del objetivo `eval` (después de su última línea de receta), agrega:
```make

# Fase 5 — el criterio de cierre con una sola orden (remediación M3 de la auditoría independiente de Fase 5): master y
# eval con el corte congelado de F5-16, la misma secuencia que la corrida única (doc/evidencia_corrida_unica_fase5.txt).
# LOCAL: exige L0 materializada y X-13; tarda unas 6-7 horas y reescribe data/L4_experiments/ y las filas F5 de
# catalogos/07_experimentos.csv. La reproducción bit a bit exige además la BLAS/LAPACK de la corrida (nota I4).
fase5:
	$(MAKE) master CONJUNTO=doc/metodologia/corte_fase5.csv SALIDA=data/conjuntos/corte_f5
	$(MAKE) eval CONJUNTO=doc/metodologia/corte_fase5.csv SALIDA=data/conjuntos/corte_f5
```
**No lo ejecutes.** Comprueba solo la sintaxis con `make -n fase5` (debe listar los pasos de `validate`, `master`, `eval-sintetico` y `eval` sin ejecutarlos).

### 3.3 · M5 e I4 — CI (según A5)

Archivo `.github/workflows/ci.yml`.
- **A5(a):** en las líneas 18 y 49, `r-version: 'release'` → `r-version: '4.6.1'`.
- **A5(b):** en las líneas 9 y 44, `runs-on: ubuntu-latest` → `runs-on: ubuntu-24.04`.
- **A5(c):** en el job `validate-and-test`, después del paso `Instalar dependencias de sistema` y antes de `uses: r-lib/actions/setup-renv@v2`, agrega:
```yaml
      # BLAS/LAPACK de referencia (remediación I4 de la auditoría independiente de Fase 5): la reproducción bit a bit
      # depende de la librería de álgebra lineal, y la máquina de la corrida única usa la de referencia. Con OpenBLAS,
      # V10 y el random forest de V20 dan otros valores que en Windows.
      - name: Fijar BLAS/LAPACK de referencia
        run: |
          sudo apt-get install -y libblas3 liblapack3
          sudo update-alternatives --set libblas.so.3-x86_64-linux-gnu /usr/lib/x86_64-linux-gnu/blas/libblas.so.3
          sudo update-alternatives --set liblapack.so.3-x86_64-linux-gnu /usr/lib/x86_64-linux-gnu/lapack/liblapack.so.3
          Rscript --vanilla -e 'b <- sessionInfo()$BLAS; cat("BLAS:", b, "\n"); if (grepl("openblas", b, ignore.case = TRUE)) stop("CI sigue con OpenBLAS")'
```
- Comprueba la sintaxis YAML (por ejemplo, `Rscript -e "yaml::read_yaml('.github/workflows/ci.yml')"`).
- **Para Harold, después del push:** en el log del run, el paso nuevo debe imprimir una ruta `…/blas/libblas.so.3…`, y la línea V20 de la verificación sintética debe decir `RMSE RF / AR(p)-BIC 0.626` (con OpenBLAS decía 0.638). Si el paso falla en el runner, el arreglo lo decide Harold: no lo resuelvas quitando la comprobación.

### Verificación del PR-3

```bash
Rscript -e "testthat::test_dir('tests')"      # FAIL 0; mismos PASS y SKIP que en el PR-2
make -n fase5                                  # lista pasos, no ejecuta nada
git diff --stat                                # checklist, Makefile y ci.yml
```
Mensaje sugerido: `Remediación F5 (M1, M3, M5): checklist con evidencia, objetivo make fase5 y CI con R y BLAS fijados`.

---

## PR-4 · `remediacion-f5/adr008` — M4 (solo si A6 está respondida)

Si A6 está vacía, sáltalo y dilo: es una decisión de Harold con plazo propio (CEPAL vence el 2026-10-16).

1. En `doc/adr/ADR-008-licencias.md`, agrega al final una enmienda nueva con las respuestas de A6, sin editar las anteriores:
```
## Enmienda — vencimiento del corte del BCR (AAAA-MM-DD)

**Hecho.** <Sin pronunciamiento del BCR al 2026-10-12 | Pronunciamiento del BCR del …: resumen de A6>. La gestión
consta en la enmienda del BCR de este ADR (consulta del 2026-08-07, ampliación de usos del 2026-08-12).

**Decisión de Harold (AAAA-MM-DD).** Para el BCR, <se mantiene el default conservador de este ADR | …>. Política de L0
aplazada a esta fecha: <única | por fuente | aplazada hasta …>. Tramos Banco Mundial y BID: <respuesta de A6>.
```
2. Si con eso cambia el estado del ADR, cambia la línea `**Estado:**` (línea 3) **y** la celda del ADR-008 en la tabla de `doc/adr/README.md` (línea 16) con **exactamente el mismo texto**: lo exige el guard `tests/test-adr-indice.R`. Redacta el texto nuevo con lo que dijo Harold y muéstraselo antes de seguir.
3. Verificación: `Rscript -e "testthat::test_dir('tests')"` en verde.

---

## PR-5 · `remediacion-f5/cierre` — depósito del informe y registro de la remediación

Se hace al final, cuando los PR anteriores estén fusionados y con CI verde.

1. Crea `doc/auditorias/auditoria_independiente_fase5_SIE-el-salvador.md` con el contenido **exacto** del Anexo A (desde `## Auditoría independiente — cierre de Fase 5` hasta el final de la fe de erratas).
2. Al final de ese archivo, agrega:
```

---

### Nota de remediación (AAAA-MM-DD)

Agregada por quien remedió; el informe de arriba se conserva sin editar.

| Hallazgo | Resolución | Commit (merge) |
|---|---|---|
| I1 | Notas de corrección en el protocolo §6, el acta de Fase 5 y el registro de cierre; regla nueva para corridas detenidas | <commit PR-1> |
| I2 | Adopción de las lecturas y de E2-1 y E2-2 por Harold; régimen de delegación en `CLAUDE.md` (A3 = <a/b>) | <commit PR-1> |
| I3 | `tabla_pruebas_fase5.csv`, `tabla_estabilidad_fase5.csv` y `extracto_pronosticos_fase5.csv`, versionados desde la L4 de `e1722fa` | <commit PR-2> |
| I4 | BLAS/LAPACK de la corrida en la evidencia; nota sobre el alcance de la paridad; <CI con la BLAS de referencia, si A5(c)> | <commit PR-2> <, PR-3> |
| M1 | Checklist de Fase 5 marcado con evidencia | <commit PR-3> |
| M2 | Notas en el acta y el protocolo; cabecera de V5 | <commit PR-1> |
| M3 | Objetivo `make fase5` | <commit PR-3> |
| M4 | <Enmienda de ADR-008 | Pendiente de decisión de Harold> | <commit PR-4 | —> |
| M5 | <R y runner fijados en CI, según A5 | Pendiente> | <commit PR-3 | —> |

CI verde: <run sobre el último merge>. Tags: `v0.8.0-fase5` → <commit>; `v0.8.1-fase5` → <commit, cuando Harold lo cree>.
```
3. En `doc/auditorias/README.md`, agrega a la tabla, después de la fila de la auditoría de Fase 4:
```
| `auditoria_independiente_fase5_SIE-el-salvador.md` | 2026-10-13 | `7093f7c` (cierre de Fase 5) | I1–I4, M1–M5 | Remediados en <commits> — ver la nota de remediación al final del propio informe |
```
4. En `doc/adr/README.md`, agrega al final del archivo una sección nueva (este `##` es correcto aquí: no empieza con «Cierre de Fase», así que el guard no la toma por un cierre):
```

## Remediación de la auditoría independiente de Fase 5 (AAAA-MM-DD)

La auditoría independiente del cierre de Fase 5 (`doc/auditorias/auditoria_independiente_fase5_SIE-el-salvador.md`,
commit auditado `7093f7c`) encontró I1–I4 y M1–M5, sin críticos. Resolución por hallazgo y commits: ver la nota de
remediación al final del propio informe. Decisiones de Harold registradas en esta remediación: adopción de las
lecturas del criterio (A1) y de E2-1 y E2-2 (A2); régimen de delegación (A3 = <a/b>); ruta del tag (A4 = <a/b>); CI
(A5: <lo aprobado>); ADR-008 (A6: <resumen o «pendiente»>). Ningún resultado de Fase 5 cambió: no se volvió a correr
el motor. `v0.8.0-fase5` no se mueve.
```
5. Propagación del tag (familia C2/C1 de las auditorías anteriores). Si `v0.8.0-fase5` ya existe:
   - `README.md`, línea 23, al final: `Tag \`v0.8.0-fase5\` propuesto, pendiente de la revisión independiente.` → `Tag \`v0.8.0-fase5\`; revisión independiente en \`doc/auditorias/\`.`
   - `CLAUDE.md`, línea 11: `(tag \`v0.8.0-fase5\` propuesto, pendiente de la revisión independiente)` → `(tag \`v0.8.0-fase5\`; revisión independiente en \`doc/auditorias/\`)`.
   Si el tag todavía no existe, no toques esas líneas y dilo.
6. En `doc/checklist_fase5.md`, ítem **F3**: `- [ ]` → `- [x]` y agrega la línea `  **Cierre (AAAA-MM-DD):** revisión independiente depositada (\`<commit>\`) e indexada; tag \`v0.8.0-fase5\` → \`<commit>\` (run <run>).`
7. Verificación final: `Rscript -e "testthat::test_dir('tests')"` en verde; `grep -rn 'AAAA-MM-DD\|<commit\|<run\|<a/b>' doc CLAUDE.md` sin resultados en los archivos de esta remediación (la auditoría depositada sí contiene `AAAA-MM-DD` dentro de su propio texto citado: eso es correcto y no se toca).

**Después del merge:** Harold crea `v0.8.1-fase5` (si A4 = (a)) con un mensaje como: «Remediación de la auditoría independiente de Fase 5 (I1–I4, M1–M5). No sustituye a v0.8.0-fase5. CI verde: run <run>.» `CITATION.cff` queda en `0.8.0`, como en la remediación de Fase 4.

---

## Informe final que entregas a Harold (después de cada PR)

Un mensaje corto con: rama; `git diff --stat`; resultado literal de las verificaciones (líneas de resumen de `testthat` y de la verificación sintética, conteos y sha256 de las tablas nuevas); lo que saltaste y por qué (decisión vacía, guard que se detuvo, conteo distinto), y el mensaje de commit sugerido. Nada más: Harold decide el commit, y Claude chat verifica después cada PR contra `origin/main` por clon fresco.

---

## Anexo A — Informe de auditoría a depositar (contenido exacto de `doc/auditorias/auditoria_independiente_fase5_SIE-el-salvador.md`)

~~~~markdown
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
~~~~

## Anexo B — `src/evaluacion/tabla_pruebas_fase5.R` (contenido exacto)

~~~~r
# src/evaluacion/tabla_pruebas_fase5.R
#
# Tabla de pruebas de Fase 5 (remediación del hallazgo I3 de la auditoría independiente de Fase 5): DM/HLN y GW
# (pruebas.csv y pruebas_submuestras.csv) y el contraste de estabilidad de R3 (estabilidad.csv) de los F5_G* de la
# corrida única, más el extracto de los pronósticos que cita el informe de lectura (§3.3). Hasta ahora esas cifras
# vivían solo en data/L4_experiments/, que no se versiona. No recalcula nada: copia lo que escribió
# motor_backtesting.R, en la unidad primaria (yoy_pp), y antes de leer cada archivo comprueba que su sha256 es el que
# lista el manifiesto del experimento, y que el manifiesto es de la corrida registrada en catalogos/07_experimentos.csv
# (el commit_hash de las filas `<exp_id>__*`; hoy, e1722fa) y con árbol limpio.
#
# No agrega reglas de lectura. `marca_tamano` y `varianza` son las del motor. `marca_n` es la misma marca de la tabla
# de resultados (F4-35, V9): se decide por el n de la CELDA (exp_id, muestra_eval, h), que es el n_pares de DM/HLN, y
# no por el n_pares de cada fila (en GW, n_pares = n - h). Al generar, se comprueba contra tabla_resultados_fase5.csv.
#
# Uso:  Rscript src/evaluacion/tabla_pruebas_fase5.R   (lo corre `make eval` después de tabla_resultados_fase5.R)
#
# Escribe, versionados y en LF:
#   doc/metodologia/reportes_fase5/tabla_pruebas_fase5.csv
#   doc/metodologia/reportes_fase5/tabla_estabilidad_fase5.csv
#   doc/metodologia/reportes_fase5/extracto_pronosticos_fase5.csv
# Regla 7: si falta un experimento declarado, un archivo no casa con su manifiesto o las marcas no coinciden, falla.

source(here::here("src", "evaluacion", "tabla_resultados_fase5.R"))   # experimentos_tabla_fase5(), variante_f5(), etc.

#' Commit registrado en 07_experimentos.csv para cada experimento (filas `<exp_id>__<modelo_id>`); uno por experimento.
commits_registrados <- function(exp_ids, ruta07 = here::here("catalogos", "07_experimentos.csv")) {
  r <- utils::read.csv(ruta07, colClasses = "character", check.names = FALSE, na.strings = character(0))
  vapply(exp_ids, function(x) {
    c_ <- unique(r$commit_hash[startsWith(r$exp_id, paste0(x, "__"))])
    if (length(c_) != 1L || !nzchar(c_)) stop("tabla de pruebas: ", x, " no tiene un único commit registrado en 07_experimentos.csv")
    c_
  }, character(1))
}

COLUMNAS_PRUEBAS_F5 <- c("variante", "muestra_eval", "exp_id", "grupo", "h", "unidad", "prueba", "modelo_a", "modelo_b",
                         "estadistico", "p_valor", "n_pares", "varianza", "media_diferencial", "marca_tamano", "marca_n")
COLUMNAS_ESTABILIDAD_F5 <- c("variante", "exp_id", "grupo", "h", "unidad", "modelo_a", "modelo_b", "media_pre",
                             "cambio_post", "ee_hac", "estadistico", "p_valor", "n_pre", "n_post", "marca_tamano")

# Pronósticos que cita el informe de lectura de Fase 5, §3.3 (pronósticos explosivos aislados en G3). Se extrae el
# corte transversal completo de esos orígenes y horizontes (todos los modelos), no solo las filas citadas, para que la
# mediana entre modelos que cita el informe se pueda recalcular.
CITAS_PRONOSTICOS_F5 <- data.frame(exp_id = "F5_G3", origen = c("2020-Q2", "2021-Q1"), stringsAsFactors = FALSE)
HORIZONTES_CITADOS_F5 <- c(4L, 8L)
COLUMNAS_EXTRACTO_F5 <- c("exp_id", "modelo_id", "grupo", "origen", "h", "periodo_objetivo", "yoy_pp_pronosticado")

#' Lee manifiesto.txt de un experimento y devuelve commit, árbol y los sha256 de las salidas.
leer_manifiesto <- function(d) {
  ruta <- file.path(d, "manifiesto.txt")
  if (!file.exists(ruta)) stop("tabla de pruebas: falta manifiesto.txt en ", d)
  lin <- readLines(ruta, encoding = "UTF-8", warn = FALSE)
  campo <- function(nm) {
    x <- sub(paste0("^", nm, ": "), "", grep(paste0("^", nm, ": "), lin, value = TRUE))
    if (length(x) != 1L) stop("tabla de pruebas: el manifiesto de ", d, " no tiene un único campo ", nm)
    x
  }
  i <- match("salidas (sha256):", lin)
  if (is.na(i)) stop("tabla de pruebas: el manifiesto de ", d, " no lista sus salidas")
  j <- i + 1L
  sal <- character(0)
  while (j <= length(lin) && grepl("^  \\S+  [0-9a-f]{64}$", lin[j])) {
    p <- strsplit(trimws(lin[j]), "  ", fixed = TRUE)[[1]]
    sal[[p[1]]] <- p[2]
    j <- j + 1L
  }
  list(commit = campo("commit_hash"), arbol = campo("arbol"), salidas = sal)
}

#' Lee un CSV de salida del motor solo si su sha256 es el que lista el manifiesto de la corrida citada.
leer_salida_verificada <- function(d, nm, man, commit) {
  if (!identical(man$commit, commit)) stop("tabla de pruebas: ", d, " es de ", man$commit, ", no de la corrida ", commit)
  if (!identical(man$arbol, "limpio")) stop("tabla de pruebas: ", d, " no se corrió con árbol limpio")
  ruta <- file.path(d, nm)
  if (!nm %in% names(man$salidas)) stop("tabla de pruebas: ", nm, " no está en el manifiesto de ", d)
  sha <- digest::digest(file = ruta, algo = "sha256")
  if (!identical(sha, unname(man$salidas[[nm]]))) stop("tabla de pruebas: ", file.path(d, nm), " no coincide con su manifiesto")
  utils::read.csv(ruta, stringsAsFactors = FALSE, na.strings = "")
}

.exigir_columnas <- function(x, cols, que) {
  faltan <- setdiff(cols, names(x))
  if (length(faltan)) stop("tabla de pruebas: faltan columnas en ", que, ": ", paste(faltan, collapse = ", "))
  x[, cols, drop = FALSE]
}

#' Tablas de pruebas y de estabilidad a partir de los directorios de L4 de los experimentos `exps`.
armar_tablas_pruebas_fase5 <- function(dir_l4, exps = experimentos_tabla_fase5(), perdida = "yoy_pp",
                                       commits = commits_registrados(exps$exp_id)) {
  partes <- list(); estab <- list()
  for (k in seq_len(nrow(exps))) {
    ex <- exps[k, ]
    d <- file.path(dir_l4, ex$exp_id)
    if (!dir.exists(d)) stop("tabla de pruebas: falta el directorio del experimento declarado ", ex$exp_id)
    man <- leer_manifiesto(d)
    lee <- function(nm) leer_salida_verificada(d, nm, man, unname(commits[[ex$exp_id]]))
    p <- lee("pruebas.csv")
    p$muestra_eval <- "completa"
    p$variante <- variante_f5(ex)
    partes[[length(partes) + 1L]] <- p
    con_sub <- isTRUE(ex$r3) || isTRUE(ex$r4)
    if (file.exists(file.path(d, "pruebas_submuestras.csv")) != con_sub) {
      stop("tabla de pruebas: submuestras de ", ex$exp_id, " no son las declaradas (r3/r4)")
    }
    if (con_sub) {
      s <- lee("pruebas_submuestras.csv")
      s$variante <- ifelse(s$muestra_eval %in% c("pre2020", "post2020"), "R3", "R4")
      partes[[length(partes) + 1L]] <- s
    }
    if (file.exists(file.path(d, "estabilidad.csv")) != isTRUE(ex$r3)) {
      stop("tabla de pruebas: estabilidad de ", ex$exp_id, " no es la declarada (r3)")
    }
    if (isTRUE(ex$r3)) {
      e <- lee("estabilidad.csv")
      e$variante <- "R3"
      estab[[length(estab) + 1L]] <- e
    }
  }
  base <- setdiff(COLUMNAS_PRUEBAS_F5, "marca_n")
  t <- do.call(rbind, lapply(partes, .exigir_columnas, cols = base, que = "pruebas"))
  t <- t[t$unidad == perdida, , drop = FALSE]
  if (!all(t$variante %in% VARIANTES_ORDEN_F5) || !all(t$muestra_eval %in% MUESTRAS_ORDEN)) {
    stop("tabla de pruebas: variante o muestra fuera del dominio")
  }
  # marca_n por celda: el n de la celda es el n_pares de DM/HLN, igual en todos sus modelos.
  celda <- paste(t$exp_id, t$muestra_eval, t$h, sep = "|")
  dm <- t[t$prueba == "dm_hln", , drop = FALSE]
  n_celda <- tapply(dm$n_pares, paste(dm$exp_id, dm$muestra_eval, dm$h, sep = "|"), unique)
  if (any(lengths(n_celda) != 1L)) stop("tabla de pruebas: n_pares de DM/HLN distinto dentro de una celda")
  if (!all(celda %in% names(n_celda))) stop("tabla de pruebas: celda sin filas de DM/HLN")
  n_c <- unlist(n_celda)[celda]
  t$marca_n <- ifelse(n_c < N_MIN_CALIBRADO_MCS, MARCA_N_BAJO, "")
  t <- t[order(match(t$variante, VARIANTES_ORDEN_F5), t$grupo, t$exp_id, match(t$muestra_eval, MUESTRAS_ORDEN), t$h,
               t$prueba, t$modelo_b), COLUMNAS_PRUEBAS_F5]
  rownames(t) <- NULL
  e <- if (length(estab)) do.call(rbind, lapply(estab, .exigir_columnas, cols = COLUMNAS_ESTABILIDAD_F5, que = "estabilidad")) else NULL
  if (!is.null(e)) {
    e <- e[e$unidad == perdida, , drop = FALSE]
    e <- e[order(e$grupo, e$exp_id, e$h, e$modelo_b), , drop = FALSE]
    rownames(e) <- NULL
  }
  list(pruebas = t, estabilidad = e)
}

#' Extracto de los pronósticos citados en el informe de lectura (§3.3): todos los modelos de los orígenes y horizontes
#' citados.
armar_extracto_pronosticos_fase5 <- function(dir_l4, citas = CITAS_PRONOSTICOS_F5, horizontes = HORIZONTES_CITADOS_F5,
                                             commits = commits_registrados(unique(citas$exp_id))) {
  partes <- list()
  for (x in unique(citas$exp_id)) {
    d <- file.path(dir_l4, x)
    if (!dir.exists(d)) stop("extracto: falta el directorio ", x)
    p <- leer_salida_verificada(d, "pronosticos.csv", leer_manifiesto(d), unname(commits[[x]]))
    p <- p[p$origen %in% citas$origen[citas$exp_id == x] & p$h %in% horizontes, , drop = FALSE]
    falta <- setdiff(citas$origen[citas$exp_id == x], p$origen)
    if (length(falta)) stop("extracto: ", x, " no tiene los orígenes citados ", paste(falta, collapse = ", "))
    partes[[length(partes) + 1L]] <- .exigir_columnas(p, COLUMNAS_EXTRACTO_F5, "pronosticos")
  }
  t <- do.call(rbind, partes)
  t <- t[order(t$exp_id, t$origen, t$h, t$modelo_id), , drop = FALSE]
  rownames(t) <- NULL
  t
}

#' Comprueba que marca_n de la tabla de pruebas es la de la tabla de resultados en cada celda (exp_id, muestra, h).
contrastar_marca_n <- function(pruebas, resultados) {
  clave <- function(x) paste(x$exp_id, x$muestra_eval, x$h, sep = "|")
  r <- unique(data.frame(k = clave(resultados), m = ifelse(is.na(resultados$marca_n), "", resultados$marca_n),
                         stringsAsFactors = FALSE))
  if (anyDuplicated(r$k)) stop("contraste: la tabla de resultados tiene marcas distintas dentro de una celda")
  p <- unique(data.frame(k = clave(pruebas), m = pruebas$marca_n, stringsAsFactors = FALSE))
  m <- r$m[match(p$k, r$k)]
  if (anyNA(m)) stop("contraste: celdas de la tabla de pruebas que no están en la de resultados")
  if (!identical(m, p$m)) stop("contraste: marca_n de la tabla de pruebas no coincide con la de resultados")
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  dir_l4 <- here::here("data", "L4_experiments")
  dir_out <- here::here("doc", "metodologia", "reportes_fase5")
  tabs <- armar_tablas_pruebas_fase5(dir_l4)
  res <- utils::read.csv(file.path(dir_out, "tabla_resultados_fase5.csv"), stringsAsFactors = FALSE, na.strings = "")
  contrastar_marca_n(tabs$pruebas, res)
  ext <- armar_extracto_pronosticos_fase5(dir_l4)
  salidas <- list(tabla_pruebas_fase5.csv = tabs$pruebas, tabla_estabilidad_fase5.csv = tabs$estabilidad,
                  extracto_pronosticos_fase5.csv = ext)
  for (nm in names(salidas)) {
    ruta <- file.path(dir_out, nm)
    escribir_tabla_resultados(salidas[[nm]], ruta)                            # LF en todas las plataformas
    cat(sprintf("%s: %d filas, sha256 %s\n", nm, nrow(salidas[[nm]]), digest::digest(file = ruta, algo = "sha256")))
  }
}
~~~~

## Anexo C — `tests/test-tabla-pruebas.R` (contenido exacto)

~~~~r
# tests/test-tabla-pruebas.R
#
# Tabla de pruebas de Fase 5 (remediación del hallazgo I3 de la auditoría independiente de Fase 5): armado sobre
# directorios de L4 sintéticos con manifiesto, verificación de los sha256 contra el manifiesto, marca_n por celda y
# extracto de pronósticos. No lee datos del proyecto: corre en CI.

library(testthat)
source(here::here("src", "evaluacion", "tabla_pruebas_fase5.R"))

.escribir <- function(df, ruta) { con <- file(ruta, open = "wb"); utils::write.csv(df, con, row.names = FALSE, na = "", eol = "\n"); close(con) }

.l4_pruebas <- function(raiz, exp_id, grupo, n = 20L, sub = FALSE, estab = FALSE, commit = "e1722fa0000000000000000000000000000000aa", arbol = "limpio",
                        alterar = NULL) {
  d <- file.path(raiz, exp_id); dir.create(d, recursive = TRUE)
  mods <- c("M.A", "M.B"); hs <- c(1L, 8L)
  fila <- function(h, prueba, m) data.frame(exp_id = exp_id, grupo = grupo, h = h, unidad = c("yoy_pp", "qoq_pp"),
    prueba = prueba, modelo_a = "BENCH.RW_SIN_DERIVA", modelo_b = m, estadistico = 1.5, p_valor = 0.2,
    n_pares = if (prueba == "gw") n - h else n, varianza = if (prueba == "gw") "bartlett" else "rectangular",
    media_diferencial = 0.1, marca_tamano = if (prueba == "gw") "tamano_no_verificado" else if (h >= 4) "distorsion_tamano_documentada" else "",
    stringsAsFactors = FALSE)
  pr <- do.call(rbind, c(lapply(hs, function(h) do.call(rbind, lapply(mods, function(m) rbind(fila(h, "dm_hln", m), fila(h, "gw", m)))))))
  arch <- list(pruebas.csv = pr)
  if (sub) arch$pruebas_submuestras.csv <- do.call(rbind, lapply(c("pre2020", "sin_2020_2021"), function(ms) {
    x <- pr; x$n_pares <- ifelse(x$prueba == "gw", 17L - x$h, 17L); cbind(muestra_eval = ms, x) }))
  if (estab) arch$estabilidad.csv <- data.frame(exp_id = exp_id, grupo = grupo, h = 1L, unidad = "yoy_pp",
    modelo_a = "BENCH.RW_SIN_DERIVA", modelo_b = mods, media_pre = 0.1, cambio_post = 0.2, ee_hac = 0.3, estadistico = 0.5,
    p_valor = 0.6, n_pre = 28L, n_post = 24L, marca_tamano = "tamano_no_verificado", stringsAsFactors = FALSE)
  arch$pronosticos.csv <- data.frame(exp_id = exp_id, modelo_id = rep(mods, each = 4), grupo = grupo,
    origen = rep(c("2020-Q2", "2021-Q1"), 4), h = rep(c(4L, 4L, 8L, 8L), 2), periodo_objetivo = "2023-Q1",
    log_nivel_pronosticado = 4.6, yoy_pp_pronosticado = c(1, -348, 2, 3, -126, 1, 2, 2), qoq_pp_pronosticado = 0.5,
    vintage_id_objetivo = "SINT.v1", stringsAsFactors = FALSE)
  sha <- character(0)
  for (nm in names(arch)) { .escribir(arch[[nm]], file.path(d, nm)); sha[[nm]] <- digest::digest(file = file.path(d, nm), algo = "sha256") }
  if (!is.null(alterar)) cat("x\n", file = file.path(d, alterar), append = TRUE)   # cambia el archivo después de hashearlo
  writeLines(c(paste0("exp_id: ", exp_id), paste0("commit_hash: ", commit), paste0("arbol: ", arbol), "",
               "salidas (sha256):", paste0("  ", names(sha), "  ", sha), "", "sessionInfo():", "R version 4.6.1"),
             file.path(d, "manifiesto.txt"))
  invisible(d)
}

.exps <- function(ids, r3 = FALSE, r4 = FALSE) data.frame(exp_id = ids, r3 = r3, r4 = r4, stringsAsFactors = FALSE)
.C <- "e1722fa0000000000000000000000000000000aa"
.com <- function(ids) stats::setNames(rep(.C, length(ids)), ids)

test_that("tabla de pruebas: unidad primaria, submuestras como R3/R4, estabilidad y marca_n por celda (no por fila)", {
  raiz <- tempfile("l4_"); on.exit(unlink(raiz, recursive = TRUE))
  .l4_pruebas(raiz, "F5_G1", "G1", n = 20L, sub = TRUE, estab = TRUE)
  .l4_pruebas(raiz, "F5_G3_R1", "G3", n = 18L)
  tabs <- armar_tablas_pruebas_fase5(raiz, rbind(.exps("F5_G1", r3 = TRUE, r4 = TRUE), .exps("F5_G3_R1")),
                                     commits = .com(c("F5_G1", "F5_G3_R1")))
  t <- tabs$pruebas
  expect_identical(names(t), COLUMNAS_PRUEBAS_F5)
  expect_true(all(t$unidad == "yoy_pp"))
  expect_setequal(unique(t$variante), c("principal", "R3", "R4", "R1"))
  # En F5_G3_R1 la celda tiene n = 18 (en el piso): sin marca, aunque GW en h = 8 tenga n_pares = 10.
  r1 <- t[t$exp_id == "F5_G3_R1", ]
  expect_true(any(r1$prueba == "gw" & r1$n_pares < N_MIN_CALIBRADO_MCS))
  expect_true(all(r1$marca_n == ""))
  # Submuestras con n = 17: marcadas.
  expect_true(all(t$marca_n[t$muestra_eval != "completa"] == MARCA_N_BAJO))
  expect_identical(nrow(tabs$estabilidad), 2L)
  expect_identical(names(tabs$estabilidad), COLUMNAS_ESTABILIDAD_F5)
  # Escritura en LF y estable.
  f <- tempfile(fileext = ".csv"); escribir_tabla_resultados(t, f)
  expect_false(any(readBin(f, "raw", file.size(f)) == as.raw(13L)))
})

test_that("tabla de pruebas: guardas de manifiesto, commit, árbol, sha256 y declaración r3/r4", {
  raiz <- tempfile("l4_"); on.exit(unlink(raiz, recursive = TRUE))
  .l4_pruebas(raiz, "F5_G1", "G1", alterar = "pruebas.csv")
  expect_error(armar_tablas_pruebas_fase5(raiz, .exps("F5_G1"), commits = .com("F5_G1")), "no coincide con su manifiesto")
  .l4_pruebas(raiz, "F5_G2", "G2", commit = "abc1234")
  expect_error(armar_tablas_pruebas_fase5(raiz, .exps("F5_G2"), commits = .com("F5_G2")), "no de la corrida")
  .l4_pruebas(raiz, "F5_G3", "G3", arbol = "sucio")
  expect_error(armar_tablas_pruebas_fase5(raiz, .exps("F5_G3"), commits = .com("F5_G3")), "árbol limpio")
  .l4_pruebas(raiz, "F5_G1_R6", "G1")
  expect_error(armar_tablas_pruebas_fase5(raiz, .exps("F5_G1_R6", r4 = TRUE), commits = .com("F5_G1_R6")), "submuestras")
  expect_error(armar_tablas_pruebas_fase5(raiz, .exps("F5_G2_R6"), commits = .com("F5_G2_R6")), "falta el directorio")
})

test_that("extracto de pronósticos: corte transversal completo de los orígenes y horizontes citados", {
  raiz <- tempfile("l4_"); on.exit(unlink(raiz, recursive = TRUE))
  .l4_pruebas(raiz, "F5_G3", "G3")
  e <- armar_extracto_pronosticos_fase5(raiz, commits = .com("F5_G3"))
  expect_identical(names(e), COLUMNAS_EXTRACTO_F5)
  expect_identical(nrow(e), 8L)                        # 2 modelos × 2 orígenes × 2 horizontes
  expect_true(-348 %in% e$yoy_pp_pronosticado)
  expect_error(armar_extracto_pronosticos_fase5(raiz, citas = data.frame(exp_id = "F5_G3", origen = "2019-Q1"), commits = .com("F5_G3")), "orígenes citados")
})

test_that("commits registrados: uno por experimento, leído de 07_experimentos.csv", {
  f <- tempfile(fileext = ".csv"); on.exit(unlink(f))
  .escribir(data.frame(exp_id = c("F5_G1__M.A", "F5_G1__M.B", "F5_G1_R1__M.A", "F5_G2__M.A", "F5_G2__M.B"),
                       commit_hash = c("aaa", "aaa", "bbb", "ccc", "ddd"), stringsAsFactors = FALSE), f)
  expect_identical(unname(commits_registrados(c("F5_G1", "F5_G1_R1"), f)), c("aaa", "bbb"))
  expect_error(commits_registrados("F5_G2", f), "único commit")
  expect_error(commits_registrados("F5_G3", f), "único commit")
})

test_that("contraste de marca_n contra la tabla de resultados", {
  p <- data.frame(exp_id = "F5_G1", muestra_eval = c("completa", "pre2020"), h = 1L, marca_n = c("", MARCA_N_BAJO), stringsAsFactors = FALSE)
  r <- data.frame(exp_id = "F5_G1", muestra_eval = c("completa", "pre2020"), h = 1L, marca_n = c(NA, MARCA_N_BAJO), stringsAsFactors = FALSE)
  expect_true(contrastar_marca_n(p, r))
  r$marca_n[2] <- NA
  expect_error(contrastar_marca_n(p, r), "no coincide")
})
~~~~
