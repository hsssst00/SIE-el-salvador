# Prompt para Claude Code — Remediación de la auditoría independiente de Fase 6

**Proyecto:** SIE El Salvador (`github.com/hsssst00/SIE-el-salvador`).
**Informe que se remedia:** auditoría independiente del cierre de Fase 6, commit auditado `c898723` (2026-11-19), con su fe de erratas. El texto completo va en el **Anexo A** y se deposita en el repositorio en el PR-4.
**Hallazgos:** 0 CRÍTICOS; IMPORTANTES I1–I3; MENORES M1–M5.
**Estado de partida verificado:** `origin/main` = `c898723` (clon fresco del 2026-11-19, 15:30 -0600). No existe ningún tag `v0.9*`.
**Preparado por:** Claude chat (rol de auditoría y verificación). **Ejecuta:** Claude Code en cualquiera de las dos PC del proyecto (Windows, R 4.6.1). Esta remediación no necesita L0 ni L4: todo sale del historial de git. **Decide, hace commit y fusiona:** Harold.

> **Nota del depósito (2026-11-20).** Este archivo conserva el prompt tal como Harold lo entregó, con el bloque A
> marcado con sus respuestas. En el Anexo A y el Anexo B se remite a los archivos ya depositados en lugar de repetir
> su texto: el informe está en `doc/auditorias/auditoria_independiente_fase6_SIE-el-salvador.md` y la prueba, en
> `tests/test-tablas-fase6-reconstruccion.R`.

---

## 0. Cómo trabajar (léelo entero antes de tocar nada)

1. **No hagas commits, ni push, ni tags, ni fusiones.** La delegación del 2026-10-17 y su ampliación del 2026-10-19, que te dejaba fusionar PR, terminaron con el cierre de Fase 6 (regla 4 de `CLAUDE.md`). Prepara cada PR en su rama, deja los cambios sin commit y detente. Muéstrale a Harold `git status`, `git diff --stat` y el resultado de las verificaciones del PR. Harold revisa, hace commit, abre el PR, espera el CI y fusiona. Recién entonces sigues con el PR siguiente, partiendo de `main` actualizado (`git switch main && git pull`).
2. **Las decisiones son de Harold (regla 4 de `CLAUDE.md`).** El bloque A trae las respuestas que Harold marcó antes de pasarte este prompt. Si una respuesta está vacía, no la infieras: salta los pasos que dependen de ella, dilo en tu informe y sigue con lo demás. No escribas nada rotulado «delegada al agente»: dos de los tres hallazgos importantes vienen de eso.
3. **No se reescribe ningún registro.** Auditorías, registros de cierre, notas de la senda, evidencias, actas, protocolos congelados, preregistros y el informe reciben **notas fechadas**; su texto existente no se edita. Las únicas ediciones de texto existente que pide este prompt están dichas explícitamente, con su «antes» y su «después», y son de archivos de estado (`README.md`, `CLAUDE.md`, «Estado general» del índice de ADR), no de registros.
4. **Fechas y marcadores.** Donde este prompt dice `AAAA-MM-DD`, pon la fecha del día en que preparas el cambio. Donde dice `<commit>`, `<run>` o `<… según An>`, pon el valor real o la respuesta de Harold, verificados. Nunca dejes un marcador sin reemplazar en un archivo.
5. **Anclas.** Cada inserción se ancla en un texto exacto. Los números de línea son los de `c898723` y sirven solo de referencia: después del PR-1 se corren. Si el texto ancla no aparece exactamente una vez, detente y repórtalo.
6. **Prohibido en esta remediación:**
   - correr `make fase6`, `make master`, `make eval`, `make tablas-fase6`, `make preregistro-fase6`, `make fase6-medicion-bvar` o `src/proyeccion/correr_fase6.R` (reescriben L4, `catalogos/07_experimentos.csv` o las tablas versionadas);
   - tocar `data/`, `catalogos/07_experimentos.csv`, los dos preregistros de Fase 6, `sha256_salidas_fase6.csv` y las doce tablas existentes de `doc/metodologia/reportes_fase6/`, `doc/evidencia_corrida_fase6_2026-11-12.txt`, `doc/evidencia_reproduccion_fase6*.txt` y `doc/metodologia/evidencia_e2_medicion_bvar_fase6.csv`;
   - cambiar la línea `**Estado:**` de cualquier ADR o su celda del índice;
   - mover, crear o borrar tags; `push --force`; cambiar `renv.lock`;
   - introducir otro lenguaje que no sea R (regla 5).
7. **Pruebas en Windows:** corre la suite con `Rscript -e "testthat::test_dir('tests')"`, no con `make test` (segfault conocido de `cli`, `doc/entorno_windows.md`).
8. **Guardas de `tests/test-adr-indice.R`.**
   - Dentro de la sección `## Cierre de Fase 6` de `doc/adr/README.md`, no escribas ninguna cadena con forma `vX.Y.Z-fase6` y no agregues encabezados `## `: las notas van con `### `.
   - En `CLAUDE.md` y `README.md`, ninguna frase nueva puede decir «Fase 6» y «en curso» sin un punto entre las dos palabras.
9. **Si algo no coincide con lo que este prompt da por verificado** (un texto «antes», un conteo, un sha256, un valor de una tabla), detente en ese punto y repórtalo. No ajustes el prompt a la realidad por tu cuenta.

### Paso 0 — Comprobar el punto de partida

```bash
git fetch origin && git switch main && git pull --ff-only
git log -1 --format='%H %s'          # esperado: c8987235947ba00baee4059c644c5475d2986015 Merge pull request #102 …
git status --short                   # esperado: vacío
git tag -l 'v0.9*'                   # esperado: vacío
```

Si `main` ya no está en `c898723`, detente: Harold debe regenerar o confirmar este prompt.

---

## A. Decisiones de Harold (las marca Harold antes de pasar el prompt)

> **Harold:** marca una opción por pregunta con `[x]`. Lo que quede sin marcar, Claude Code lo salta.
>
> *Nota del depósito:* el prompt se entregó con las casillas sin marcar; Harold las respondió en el chat el
> 2026-11-19, antes de que se preparara el PR-1. Se marcan aquí según esas respuestas.

**A1 · I2 — Lecturas del criterio de cierre de Fase 6** (senda §4, nota de cierre v0.12). Las tres que la nota rotula como delegadas: «supuesto exógeno», «fuente citada» y «el resultado».
- [x] (a) Las adopto tal como están escritas. *Recomendada salvo que quieras cambiar alguna.*
- [ ] (b) Las adopto con estos cambios: ____________________________________________

  Sobre la cuarta lectura, que cita tu decisión del 2026-11-15:
- [x] (c) Confirmo que el 2026-11-15 decidí corregir el texto del informe y no tocar las tablas versionadas: el aviso del informe vale para todas las tablas de su carpeta, y solo las de proyección llevan la columna `nota`.

**A2 · I2 — Decisiones principales de F6-14 a F6-18** (redactadas y decididas por el agente el 2026-10-19, fuera del texto de la delegación del 2026-10-17; tu ratificación del 2026-11-15 cubrió sus detalles, no las cinco decisiones).
- [x] (a) Las adopto tal como están en `decisiones_fase6.md`.
- [ ] (b) Las adopto, salvo: ____________________________________ (las que no adoptes quedan reabiertas, sin cambiar ninguna cifra en esta remediación)

**A3 · I2 — Delegaciones futuras.**
- [x] (a) Dejar escrito ya en la regla 4 que toda delegación futura se registra antes de usarse, nombra las fichas que cubre y nunca cubre lecturas de un criterio de cierre, cambios posteriores a un congelamiento, desvíos de un ADR cerrado ni fichas que yo no haya visto redactadas. *Recomendada.*
- [ ] (b) No escribir nada ahora; lo decido si vuelvo a delegar.

**A4 · I1 — Regla de sensibilidad principal.**
- [x] (a) F6-09-c sigue siendo la principal. La sensibilidad de la regla preregistrada (F6-09-a/b) se reporta junto a ella en el §5 del informe, y F6-09-c se rotula como desvío del preregistro decidido con esos resultados escritos. *Solo notas y una tabla nueva.*
- [ ] (b) La regla preregistrada vuelve a ser la principal y F6-09-c pasa a variante. *Cambia el §5 del informe y cifras del registro de cierre; no exige volver a correr, porque las dos están en git, pero pide un plan aparte: si marcas esta, Claude Code se detiene antes del PR-2.*

  Opcional: por qué no se midió la variante que solo corregía el defecto de 2026 (choque en cada año desde 2027, con 2026 en la base): *(vacío)*

**A5 · I3 — ADR-002 y la fuente de los supuestos de EE. UU.**
- [x] (a) Enmienda: para el Ejercicio B, el WEO es también la fuente de las proyecciones de EE. UU., con las razones de `supuestos_escenarios.md`, sección 7. *Recomendada si no piensas volver a la fuente híbrida.* Razones adicionales (opcional): *(vacío)*
- [ ] (b) Nota de desvío: la decisión híbrida de ADR-002 se mantiene; Fase 6 se apartó de ella y se revisa cuando: ____________________

**A6 · Ruta del tag** (el registro deja `v0.9.0-fase6` propuesto; CI #535 en verde sobre `c898723`).
- [x] (a) `v0.9.0-fase6` sobre el merge del PR-2, que ya contiene la adopción de I2, la enmienda de I3 y la corrección de I1; el resto de la remediación va a `v0.9.1-fase6`. *Recomendada: la auditoría pide cerrar I1, I2 e I3 antes del tag.*
- [ ] (b) `v0.9.0-fase6` sobre `c898723` ya, y toda la remediación a `v0.9.1-fase6` (precedente de Fase 4).

**A7 · M1 — Reloj de la PC INVE.**
- [ ] Lo revisé: estaba atrasado ____ horas; lo corregí el ____.
- [x] No lo he revisado todavía.

---

## PR-1 · `remediacion-f6/decisiones` — I1 (registro), I2, I3 y M2

Depende de A1, A2, A4 y A5 (y A3 para 1.5). Las partes 1.1, 1.2 y 1.8 no dependen de ninguna decisión; si A4 = (b), haz igual 1.1 sin su párrafo de decisión y 1.2 sin la cláusula del informe.

### 1.1 · I1 — Nota de corrección en F6-09

Archivo `doc/metodologia/decisiones_fase6.md`. Ancla (línea 519 en `c898723`), fin de la sección F6-09:
```
  corrida los compara con el código (F6-12, nota del 2026-11-10).
```
Inserta, después de una línea en blanco y antes de `## F6-10 — Coherencia interna…`:
```
**Nota de corrección (AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo I1).** La nota del 2026-11-10
justifica F6-09-c por los senderos de insumo, y no dice con qué resultados se tomó. Se tomó con la sensibilidad de
la regla congelada el 2026-11-04 ya calculada y escrita: la E3 de ese día (`0b1ca5a`) la produjo, el borrador del
informe del PR #95 la usó, la E4 del 2026-11-10 la reprodujo y el PR #97 (`b084c1b`) la fusionó a `main` esa
mañana, en `sensibilidad_fase6.csv` y en el §5 del borrador. Con la regla congelada, ±1 DE del PIB de EE. UU. movía
el crecimiento promedio 2026-2030 de la combinación +1,64 / −1,47 pp en G1, +0,55 / −0,71 en G2 y +0,44 / −0,58 en
G3; con la vigente, +0,35 / −0,37, +0,18 / −0,09 y +0,10 / −0,10. La perturbación reemplazada era un detalle
delegado al agente (F6-09-a). F6-09-c es, por tanto, un desvío del preregistro del 2026-11-04 decidido con
resultados escritos. No consta que se haya medido la variante que solo corregía el defecto de 2026 (choque en cada
año desde 2027, con 2026 en la base)<; motivo: …, según A4>. Las cifras de la regla congelada están en el historial
de git (`a4c16d3`). El texto de arriba se conserva sin editar.
```
Si A4 = (a), agrega a continuación, con una línea en blanco antes:
```
**Decisión de Harold (AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo I1).** F6-09-c sigue siendo la regla
principal. La sensibilidad de la regla congelada se reporta junto a ella en el §5 del informe, como resultado de la
regla preregistrada, y F6-09-c se rotula allí como desvío del preregistro.
```
Si el motivo opcional de A4 está vacío, quita la cláusula `<; motivo: …, según A4>` entera (la frase termina en «… con 2026 en la base).»).

### 1.2 · I1 — Nota en el §8 del protocolo congelado

Archivo `doc/metodologia/protocolo_proyeccion.md`. Ancla (línea 114), fin del párrafo de §8:
```
del PIB de 2030 y en el crecimiento promedio 2026-2030, por grupo, para la combinación y para cada miembro.
```
Inserta después, con una línea en blanco antes, y antes de `## 9. Coherencia interna (F6-10)`:
```
*Nota (AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo I1):* este párrafo describe la regla congelada el
2026-11-04 (F6-09-a/b). Desde el preregistro `preregistro_fase6_2026-11-11.yaml` (`1528483`) rige F6-09-c: ±1
desviación estándar solo al crecimiento de 2027, con el nivel desviado de forma persistente desde 2028 y 2026 en la
base. Harold decidió el cambio el 2026-11-10, con la sensibilidad de la regla congelada ya calculada y fusionada a
`main` (`b084c1b`). Es un desvío del preregistro<, y el informe reporta las dos reglas (§5)>. Detalle en F6-09,
nota del 2026-11-10 y nota de corrección del AAAA-MM-DD.
```
La cláusula `<, y el informe reporta las dos reglas (§5)>` va solo si A4 = (a), sin los signos `< >`.

### 1.3 · I1, I2 e I3 — Notas en el registro de cierre

Archivo `doc/adr/README.md`. Ancla (línea 675, última del archivo):
```
2026-11-19 en el mismo commit. La revisión independiente en `doc/auditorias/` y el tag (F4) quedan a cargo de Harold.
```
Agrega al final, en este orden. La primera subsección va siempre; la segunda solo si A1 y A2 están marcadas; la tercera solo si A5 está marcada.
```

### Nota de corrección (AAAA-MM-DD) — auditoría independiente de Fase 6, hallazgo I1

La evidencia «Preregistro (E1)» de este registro dice que el preregistro del 2026-11-11 solo cambia la sensibilidad.
Es cierto, y falta lo que importa para leerlo: el cambio (F6-09-c) se decidió el 2026-11-10 con la sensibilidad de
la regla congelada ya calculada (E3 del 2026-11-04), reproducida (E4 del 2026-11-10) y fusionada a `main` en el
borrador del informe (`b084c1b`). Es un desvío del preregistro decidido con resultados escritos. Con la regla
congelada, ±1 DE del PIB de EE. UU. movía el nivel de 2030 de la combinación +8,3 / −7,0 % en G1; con la vigente,
+1,7 / −1,8 %. Ver la nota de corrección de F6-09 y la nota del §8 del protocolo de proyección (AAAA-MM-DD). El
texto de este registro se conserva sin editar.

### Adopción de las lecturas y de F6-14 a F6-18 (AAAA-MM-DD) — auditoría independiente de Fase 6, hallazgo I2

Harold adopta las tres lecturas del criterio de cierre que este registro y la nota de la senda rotulaban como
delegadas (senda §4, nota de adopción de la v0.13) y las decisiones principales de F6-14 a F6-18
(`doc/metodologia/decisiones_fase6.md`, nota del AAAA-MM-DD)<, salvo …, según A2>. Dejan de ser decisiones
delegadas al agente y de estar abiertas a reapertura por esa razón.

### ADR-002 (AAAA-MM-DD) — auditoría independiente de Fase 6, hallazgo I3

El primer punto de «Lo que queda abierto» (ADR-002 y la fuente «híbrida») se resuelve con la enmienda del
AAAA-MM-DD de ADR-002: <A5 (a): para el Ejercicio B, el WEO es también la fuente de las proyecciones de EE. UU. |
A5 (b): la decisión híbrida se mantiene y Fase 6 queda registrada como desvío, con su disparador de revisión>. El
texto de arriba se conserva sin editar.
```
Si A2 = (a), quita `<, salvo …, según A2>`; si A2 = (b), escribe las fichas no adoptadas. En la tercera subsección deja solo la alternativa marcada en A5.

### 1.4 · I2 — Adopción de las lecturas en la senda §4 (A1)

Archivo `doc/senda_metodologica.md`.
- Ancla (línea 636): `El registro del cierre, con su evidencia, está en \`doc/adr/README.md\`, «Cierre de Fase 6».` Inserta **antes** de esa línea, con una línea en blanco antes y otra después:
```
**Adopción de las lecturas (AAAA-MM-DD, Harold; auditoría independiente de Fase 6, hallazgo I2).** Las tres lecturas
que esta nota rotula como delegadas («supuesto exógeno», «fuente citada» y «el resultado») dejan de serlo: Harold las
adopta <tal como están escritas | con estos cambios: …, según A1>. Con eso, el criterio de cierre de Fase 6 queda
leído por quien declara el avance de fase, como en las Fases 1 a 5.
```
- Encabezado (línea 4): `**Versión:** 0.12 — documento de trabajo, enmendado` → `**Versión:** 0.13 — documento de trabajo, enmendado`. Al final de la línea `**Fecha:**` (línea 5), agrega `; AAAA-MM-DD (v0.13)`.
- Historial: después de la entrada 0.12, que termina en `` `doc/adr/README.md`, "Cierre de Fase 6". Sin otros cambios de contenido. `` (línea 48), inserta:
```
- **0.13** (AAAA-MM-DD): añade a la nota de cierre de Fase 6 la adopción de sus lecturas por Harold (hallazgo I2 de la
  auditoría independiente de Fase 6). Sin otros cambios de contenido.
```

### 1.5 · I2 — Delegaciones futuras en `CLAUDE.md` (solo si A3 = a)

Archivo `CLAUDE.md`. Ancla (línea 39), fin del párrafo de la ampliación:
```
   fusionarlos. Rige igual que la delegación del 2026-10-17.
```
Inserta después una línea en blanco y este párrafo, indentado con tres espacios, sin tocar la línea `5. **El stack es R, cerrado (ADR-009).**` que sigue:
```
   **Delegaciones futuras (AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo I2).** Si Harold vuelve a delegar,
   la autorización se registra aquí antes de usarse y nombra por código las fichas que cubre. Nunca cubre: las
   lecturas de un criterio de cierre, los cambios posteriores a un congelamiento de preregistro, los desvíos de un
   ADR cerrado ni las fichas que Harold no haya visto redactadas. Esas decisiones se preguntan siempre.
```

### 1.6 · I2 — Adopción de F6-14 a F6-18 en el acta (A2)

Archivo `doc/metodologia/decisiones_fase6.md`. Al final del archivo (hoy termina en `en 2026-Q2. F6-05-a: la CBO no se usó, porque F6-15 tomó el PIB de EE. UU. para la satélite de remesas.`), agrega:
```

## Adopción de las decisiones principales de F6-14 a F6-18 (AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo I2)

El agente redactó y decidió F6-14 a F6-18 el 2026-10-19, en la opción recomendada de cada una, bajo la delegación del
2026-10-17, cuyo texto en `CLAUDE.md` cubría las fichas F6-01 a F6-13. La ratificación del 2026-11-15 cubrió sus
detalles, no las cinco decisiones principales. Harold las adopta <tal como están | salvo …, que quedan reabiertas,
según A2>. Las adoptadas dejan de ser decisiones delegadas.
```

### 1.7 · I3 — Enmienda de ADR-002 (A5) y sus dos notas

1. Archivo `doc/adr/ADR-002-horizonte-y-diseno.md`. Al final del archivo (hoy termina en `aritmética de orígenes, los conteos dejan de coincidir y la prueba falla.`), agrega, con una línea en blanco antes, **una** de las dos versiones. No cambies la línea `**Estado:** Cerrado`.

   Si A5 = (a):
```
## Enmienda — fuente de los supuestos de Estados Unidos en el Ejercicio B (AAAA-MM-DD)

**Hecho (Fase 6).** La «Decisión» fija una fuente híbrida: el WEO para las variables globales y regionales y
proyecciones de la Reserva Federal, la BEA o la CBO para las variables de actividad de Estados Unidos, insumo del
supuesto de remesas. En Fase 6, las proyecciones del PIB y del IPC de Estados Unidos vinieron del WEO de octubre de
2026 (F6-05); de la BEA y el BLS solo salió la historia. La CBO se capturó (`CBO.PROYECCIONES_ECONOMICAS.v2026-02`) y
quedó sin uso cuando F6-15 tomó el PIB de Estados Unidos, y no el empleo, como predictora de las remesas. Lo declara
`doc/metodologia/supuestos_escenarios.md` (sección 6, punto 6, y sección 7). Este ADR no lo registraba (auditoría
independiente de Fase 6, hallazgo I3).

**Decisión de Harold (AAAA-MM-DD).** Para el Ejercicio B, el WEO es también la fuente de las proyecciones de Estados
Unidos, por las razones de `supuestos_escenarios.md`, sección 7<; además: …, según A5>. La alternativa que este ADR
descartó («FMI WEO exclusivo») queda adoptada solo para eso.

**Consecuencia.** La razón de fondo de este ADR —que Estados Unidos es el factor dominante de incertidumbre a
horizonte largo para El Salvador— sigue en pie; en Fase 6 la tratan los escenarios A y C y la sensibilidad al PIB de
Estados Unidos (informe de proyección, secciones 2 y 5). La nota de inconsistencia entre fuentes sigue vigente
(`supuestos_escenarios.md`, sección 6).
```
   Si A5 = (b):
```
## Nota de desvío — fuente de los supuestos de Estados Unidos en el Ejercicio B (AAAA-MM-DD)

**Hecho (Fase 6).** <el mismo párrafo «Hecho (Fase 6)» de la versión (a)>

**Decisión de Harold (AAAA-MM-DD).** La decisión de este ADR (fuente híbrida) se mantiene. Fase 6 se apartó de ella
por las razones de `supuestos_escenarios.md`, sección 7, y se revisa <disparador, según A5>.
```
2. Archivo `doc/metodologia/supuestos_escenarios.md`, sección «Registro». Ancla (línea 266):
```
  F6-15; capturadas en L0 con sha256 por C2 y C2b (checklist de Fase 6, 2026-10-19).
```
   Inserta inmediatamente después (sin línea en blanco, como continuación del ítem):
```
  — Nota (AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo I3): de la Fed, la BEA y la CBO no entra ninguna
  proyección a la corrida; la BEA y el BLS dan solo la historia y la CBO quedó sin uso (F6-15). Ver la
  <enmienda | nota de desvío> del AAAA-MM-DD de ADR-002.
```
3. Archivo `doc/metodologia/decisiones_fase6.md`, acta. Ancla (línea 231), última fila de la tabla, que empieza con `| F6-19 | Cada vintage de un`. Inserta después una línea en blanco y:
```
**Nota (AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo I3).** F6-05 (PIB de EE. UU. del WEO) y F6-15 (la
CBO sin uso) afectan también a ADR-002: ver su <enmienda | nota de desvío> del AAAA-MM-DD. La columna «Documento
enmendado» de esas dos filas se conserva sin editar.
```

### 1.8 · M2 — Nota en la medición previa del BVAR (E2)

Archivo `doc/metodologia/decisiones_fase6.md`. Ancla (línea 1238), fin de la sección «Hechos verificados el 2026-11-04 (medición previa del BVAR, E2)…»:
```
  extracciones: eso cambiaría la especificación declarada en `MULT.BVAR.G*.yaml`.
```
Inserta después, con una línea en blanco antes, y antes de `## Hechos verificados el 2026-11-10 (reproducción, E4)`:
```
**Nota (AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo M2).** F6-13 (d) fijaba que la medición reporta
solo dos cifras (proporción de raíces mayores que 1 y distancia entre media y mediana) y que no se miran el sendero
ni las bandas. `evidencia_e2_medicion_bvar_fase6.csv` versionó además `media_yoy_pp` y `mediana_yoy_pp`: el
interanual central del BVAR sin escenario con h = 8 y 20 en cada grupo. La decisión de congelar se tomó con ese
archivo. La lectura del agente de arriba dice que no se miraron bandas y no menciona esos niveles. Como la decisión
fue no cambiar la especificación, no hubo efecto sobre resultados. El texto de arriba y el CSV se conservan sin
editar.
```

### Verificación del PR-1 (antes de detenerte)

```bash
Rscript -e "testthat::test_dir('tests')"     # esperado: FAIL 0. Anota PASS y SKIP: son la base del PR-2
                                              # (en Linux, sobre c898723, la auditoría obtuvo 3721 PASS / 0 SKIP; en Windows puede variar)
grep -n 'AAAA-MM-DD\|<commit>\|<run>\|según A[0-9]\|<enmienda\|<A5' CLAUDE.md doc/senda_metodologica.md doc/adr/README.md \
  doc/adr/ADR-002-horizonte-y-diseno.md doc/metodologia/decisiones_fase6.md doc/metodologia/protocolo_proyeccion.md \
  doc/metodologia/supuestos_escenarios.md     # esperado: nada
git diff --stat   # esperado: decisiones_fase6.md, protocolo_proyeccion.md, doc/adr/README.md y, según lo marcado,
                  # senda_metodologica.md (A1), CLAUDE.md (A3 = a), ADR-002 y supuestos_escenarios.md (A5)
```
Mensaje de commit sugerido para Harold: `Remediación F6 (I1, I2, I3, M2): corrección fechada de F6-09, adopción de las lecturas y de F6-14 a F6-18, enmienda de ADR-002`.

---

## PR-2 · `remediacion-f6/sensibilidad` — I1 (evidencia e informe)

Si A4 = (b), **no hagas este PR**: detente y dile a Harold que el cambio de regla principal necesita un plan propio.

### 2.1 · Copias versionadas de la sensibilidad reemplazada

Las salidas de sensibilidad de la corrida reemplazada (E3 del 2026-11-04) ya están en git, en las tablas que fusionó el PR #97 (`a4c16d3`). Se copian byte a byte con nombre propio. Usa **Git Bash**, no PowerShell (su `>` cambia la codificación):

```bash
git cat-file blob a4c16d3:doc/metodologia/reportes_fase6/sensibilidad_fase6.csv \
  > doc/metodologia/reportes_fase6/sensibilidad_reemplazada_fase6.csv
git cat-file blob a4c16d3:doc/metodologia/reportes_fase6/senderos_sensibilidad_fase6.csv \
  > doc/metodologia/reportes_fase6/senderos_sensibilidad_reemplazada_fase6.csv
sha256sum doc/metodologia/reportes_fase6/*reemplazada_fase6.csv
wc -l doc/metodologia/reportes_fase6/*reemplazada_fase6.csv
```
**Esperado:**
- `sensibilidad_reemplazada_fase6.csv`: sha256 `905394403416cfd45e94649bf0367f92b36d218fb9aa200d91bceab6b729901d`, 103 líneas.
- `senderos_sensibilidad_reemplazada_fase6.csv`: sha256 `4bd54519483c40bcf3d8d33c938b68c886ea63b0751a768e2f7445366cda3e4e`, 129 líneas.

Si no coinciden, detente y reporta. No las regeneres de otra forma.

### 2.2 · Prueba que ata las tablas versionadas a las salidas certificadas

Crea `tests/test-tablas-fase6-reconstruccion.R` con el contenido **exacto** del Anexo B. Reconstruye, desde lo versionado, cada archivo de L4 y compara su sha256: las 28 salidas vigentes contra `sha256_salidas_fase6.csv`, y las dos copias del 2.1 contra los sha256 de la corrida reemplazada, que constan en la segunda tabla de `doc/evidencia_reproduccion_fase6_2026-11-12.txt`. Quita los CR antes de hashear, así que pasa también con `core.autocrlf=true`.

Se probó en Linux con R 4.6.1 sobre `c898723` más los dos archivos del 2.1: 2 bloques y 65 PASS, también con todos los CSV convertidos a CRLF; la suite completa dio 3786 PASS / 0 FAIL / 0 SKIP. Se comprobó además que muerde: con una cifra alterada en `proyeccion_anual_fase6.csv` y otra en `sensibilidad_reemplazada_fase6.csv`, cada bloque falla.

### 2.3 · Nota en el §5 del informe (A4 = a)

Archivo `doc/metodologia/reportes_fase6/informe_proyeccion_fase6.md`. Ancla (línea 176), fin de la viñeta «La regla anterior no se reporta»:
```
  de la corrida reemplazada, no como resultado (`decisiones_fase6.md`, F6-09, nota del 2026-11-10).
```
Inserta después, con una línea en blanco antes, y antes de `## 6. Coherencia interna (F6-10)`:
```
**Nota (AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo I1).** La viñeta anterior se conserva sin editar,
pero no basta. La regla de esta sección (F6-09-c) no es la que se congeló el 2026-11-04: Harold la decidió el
2026-11-10, con la sensibilidad de la regla congelada ya calculada y fusionada a `main` en el borrador de este
informe (`b084c1b`). Es un desvío del preregistro. La regla congelada (F6-09-a/b) sumaba ±1 desviación estándar al
crecimiento de cada año proyectado, desde 2026. Su efecto sobre la combinación, en el formato de la tabla de arriba:

| Grupo | PIB EE. UU. +1 de | PIB EE. UU. −1 de | IPC EE. UU. +1 de | IPC EE. UU. −1 de | Petróleo +1 de | Petróleo −1 de |
|---|---|---|---|---|---|---|
| G1 | 1,64 (8,3) | −1,47 (−7,0) | 0,00 (0,0) | 0,00 (0,0) | 0,00 (0,0) | 0,00 (0,0) |
| G2 | 0,55 (2,7) | −0,71 (−3,4) | 0,09 (0,4) | −0,05 (−0,2) | 0,03 (0,2) | −0,02 (−0,1) |
| G3 | 0,44 (2,2) | −0,58 (−2,8) | 0,09 (0,5) | −0,08 (−0,4) | 0,00 (0,0) | −0,00 (−0,0) |

Con esa regla, el PIB de EE. UU. movía el promedio de G1 de cuatro a cinco veces más que con la vigente, y el IPC
hasta 0,09 pp en la combinación de G2 y G3. Tenía además un defecto de implementación: 2026, con trimestres
observados, cargaba el ajuste en sus trimestres libres (con +1 DE, el petróleo saltaba a 186,11 USD en 2026-T4,
contra 118,22 en la base). La base y los escenarios A y C son idénticos con las dos reglas. Las cifras salen de
`sensibilidad_reemplazada_fase6.csv` (sha256 sin CR `9053944034…`) y `senderos_sensibilidad_reemplazada_fase6.csv`
(`4bd5451948…`), en esta carpeta: copias de las salidas de la corrida reemplazada que
`tests/test-tablas-fase6-reconstruccion.R` contrasta con sus sha256 certificados.
```
**Antes de escribir la tabla, compruébala** contra `sensibilidad_reemplazada_fase6.csv` (filas `COMBINACION`): `crecimiento_promedio_pp` a dos decimales y `nivel_2030_pct` a uno, con el mismo redondeo y signo que la tabla vigente del §5 (allí G3 petróleo +1 de figura como «−0,00 (−0,0)»). Y comprueba en `senderos_sensibilidad_reemplazada_fase6.csv` que `PETROLEO.MAS` vale 186,11 en 2026-Q4, y en `senderos_sensibilidad_fase6.csv` que vale 118,22. Si algo no coincide, detente y reporta.

### Verificación del PR-2

```bash
Rscript -e "testthat::test_dir('tests')"     # esperado: FAIL 0; PASS = base del PR-1 + 65; SKIP = el de la base
git status --short   # esperado: los dos CSV nuevos, el test nuevo y el informe. Nada en data/, catalogos/ ni en las doce tablas existentes
grep -n 'AAAA-MM-DD' doc/metodologia/reportes_fase6/informe_proyeccion_fase6.md   # esperado: nada
```
Mensaje sugerido: `Remediación F6 (I1): sensibilidad de la regla preregistrada versionada y reportada junto a la vigente; prueba de reconstrucción de las tablas de Fase 6`.

**Después del merge del PR-2, si A6 = (a):** Harold confirma el CI verde sobre el merge y crea el tag anotado `v0.9.0-fase6` con un mensaje como: «Cierre de Fase 6: criterio de senda §4 SATISFECHO con las lecturas adoptadas por Harold (v0.13). Incluye la corrección de I1, la adopción de I2 y la enmienda de I3 de la auditoría independiente. CI verde: run <run>.» Claude Code no crea el tag.

---

## PR-3 · `remediacion-f6/registros` — M1, M3, M4 y M5

### 3.1 · M1 y M3 — Nota en la evidencia de la corrida reemplazada, y en el checklist

1. Archivo `doc/evidencia_corrida_fase6.txt`. Al final del archivo, agrega una línea en blanco y el bloque de abajo. Aquí el ancla es el final del archivo: su última línea, `make[1]: Leaving directory '/c/Users/INVE/Documents/SIE-el-salvador'`, aparece tres veces en él, y eso es esperado.
```
Nota AAAA-MM-DD (auditoría independiente de Fase 6, hallazgos M1 y M3).
Esta corrida fue REEMPLAZADA. El 2026-11-10 Harold sustituyó F6-09-a/b por F6-09-c; la corrida vigente es la del
2026-11-12 sobre 1528483 (doc/evidencia_corrida_fase6_2026-11-12.txt). «Esta es la única corrida» se conserva sin
editar: era cierto cuando se escribió. Sus salidas de sensibilidad están versionadas en
doc/metodologia/reportes_fase6/sensibilidad_reemplazada_fase6.csv y senderos_sensibilidad_reemplazada_fase6.csv.
Horas: las de este archivo (inicio 01:03:39, fin 01:21:27) y la fecha_corrida de sus manifiestos (01:16:58-0600)
no son la hora real. GitHub creó b1376df el 2026-11-04 a las 13:04:04 -0600, y esta corrida se hizo sobre él. El
reloj de la PC INVE estaba atrasado unas 12 horas<; según Harold: …, según A7>. Los commits b9e7327 y 0b1ca5a,
hechos en esa PC, tienen fechas anteriores a las de sus padres (07526a8 y b1376df). El contenido no cambia:
b1376df y b9e7327 tienen el mismo árbol. Para afirmar que algo fue «antes de» otra cosa rige la ancestría de
commits (git merge-base --is-ancestor), no la hora.
```
   Si el PR-2 no se hizo (A4 = b), quita la frase «Sus salidas de sensibilidad están versionadas en … senderos_sensibilidad_reemplazada_fase6.csv.». Si A7 no está marcada, quita la cláusula `<; según Harold: …, según A7>`.
2. Archivo `doc/checklist_fase6.md`. Ancla (línea 125): el ítem `- [x] **E3** Corrida única con \`make fase6\`…`, que ocupa una sola línea. Inserta inmediatamente después, como continuación del ítem:
```
  **Nota (AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo M1):** «01:03 a 01:21» son horas del reloj de la
  PC INVE, atrasado unas 12 horas: la corrida empezó después de las 13:04:04 -0600, cuando GitHub creó `b1376df`.
  Detalle en la nota del AAAA-MM-DD de `doc/evidencia_corrida_fase6.txt`.
```

### 3.2 · M3 — Notas en el protocolo congelado y registro de la decisión del 2026-11-15

1. `doc/metodologia/protocolo_proyeccion.md`, §10 (solo si A1(c) está marcada). Ancla (línea 136): `  tabla con bandas de ese modelo.` Inserta después, con una línea en blanco antes, y antes de `## 11.`:
```
*Nota (AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo M3):* §1 dice que «cada tabla y figura del informe»
lo declara condicional, y la primera viñeta de esta sección, que toda tabla lleva la leyenda. Harold decidió el
2026-11-15 no tocar las tablas versionadas: el aviso al comienzo del informe vale para todas las tablas de su
carpeta, y solo las de proyección anual y trimestral lo repiten en su columna `nota` (`decisiones_fase6.md`,
sección del AAAA-MM-DD). El informe no tiene figuras.
```
2. Mismo archivo, §11. Ancla (línea 154): `` `catalogos/07_experimentos.csv` (F4-25).`` (con dos espacios de indentación). Inserta después, con una línea en blanco antes, y antes de `## 12.`:
```
*Nota (AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo M3):* el preregistro vigente es
`doc/metodologia/preregistro_fase6_2026-11-11.yaml` (`1528483`), que reemplaza al que nombra esta sección. Hubo dos
corridas completas sobre datos reales: la del 2026-11-04, reemplazada, y la vigente, del 2026-11-12 (F6-12, nota
del 2026-11-10; §8, nota del AAAA-MM-DD).
```
3. `doc/metodologia/decisiones_fase6.md` (solo si A1(c) está marcada). Al final del archivo (después de la sección que agregó el 1.6), agrega:
```

## Decisión de Harold del 2026-11-15: el aviso de condicionalidad y las tablas (registrada el AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo M3)

En la revisión de F2 del 2026-11-15, Harold decidió corregir el texto del informe y no tocar las tablas
versionadas. El aviso al comienzo de `informe_proyeccion_fase6.md` vale para todas las tablas de `reportes_fase6/`;
las de proyección anual y trimestral lo repiten en su columna `nota`, y las demás no la llevan. Se aparta del
protocolo de proyección, §1 y §10 (nota del AAAA-MM-DD allí). Hasta esta fecha constaba solo en la nota de cierre
de la senda.
```

### 3.3 · M4 — Diccionario de `07_experimentos.csv` y nota en F6-12

1. `catalogos/README.md`. Ancla (línea 160), última de la sección `07_experimentos.csv`: `` válido y que `exp_id` y `ruta_resultados` sigan la regla.`` Inserta después, con una línea en blanco antes:
```
**Filas de Fase 6 (F6-12-b; nota del AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo M4).** Desde Fase 6 la
tabla tiene también filas del Ejercicio B, con otro escritor y otro contrato. Las escribe
`src/proyeccion/correr_fase6.R` al final de `make fase6`: una por (grupo, modelo), más una por grupo con
`modelo_id` = `COMBINACION`, la mediana de F6-02, que no tiene YAML en `06_modelos/`. En esas filas, `exp_id` es
`F6_<grupo>__<modelo_id>`; `vintage_id`, los vintages del corte unidos con « + »; `esquema_validacion` sigue la
gramática `proyeccion_condicional|origen=…|grupo=…|conjunto=<corte>@<8 caracteres del sha256 sin CR>|corridas=…`,
no el token de F4-11; `horizontes` es `1` a `20`, y `ruta_resultados`, `data/L4_experiments/F6_<grupo>/`.
`tests/test-robustez-registro.R` valida esa gramática y acepta `COMBINACION` sin YAML desde `337abb2`.
```
   Comprueba antes, sobre `catalogos/07_experimentos.csv`, que las 42 filas `F6_*` cumplen cada afirmación del párrafo (en particular, que el `vintage_id` de cada fila es exactamente el conjunto de vintages de `corte_fase6.csv`). Si alguna no se cumple, detente.
2. `doc/metodologia/decisiones_fase6.md`, F6-12. Ancla (línea 678): `- **Dónde corre.** La E3 nueva corre en la PC de Harold \`D:\harold\`. E4 se reproduce en la PC INVE cuando vuelva.` Inserta después, con una línea en blanco antes, y antes de `## F6-13`:
```
**Nota (AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo M4).** El contrato de las filas de `07` que fija
F6-12-b no llegó a `tests/test-robustez-registro.R` ni al diccionario de `catalogos/README.md` antes de la corrida.
Según el mensaje de `337abb2`, el CI del PR #94 rechazó las 42 filas de la E3 del 2026-11-04, y la prueba se adaptó
después de la corrida, en ese commit, sin cambiar la corrida. El diccionario se completó el AAAA-MM-DD.
```

### 3.4 · M5 — Registros que no siguieron a los hechos

1. `README.md`, línea 13 (párrafo «Fase 0 — cerrada.»). Edición explícita:
   - Antes: `ADR-008 parcial (quedan BCR y CEPAL en gestión, y la decisión de política de L0 aplazada al corte del BCR — el estado por fuente está en ADR-008;`
   - Después: `ADR-008 parcial (los cortes del BCR y de CEPAL vencieron sin pronunciamiento y la política de L0 es por fuente desde el 2026-10-14; queda abierta la condición de CEPAL sobre obras derivadas — el estado por fuente está en ADR-008;`
2. `doc/adr/README.md`, párrafo «Estado general» (línea 25). Dos ediciones explícitas:
   - Antes: `Sigue abierta la decisión de si el proyecto adopta una política única de L0 o una política por fuente — aplazada hasta conocer el régimen de redistribución del BCR, con fecha de corte 2026-10-12.`
   - Después: `La decisión entre una política única de L0 y una por fuente, aplazada hasta el corte del BCR (2026-10-12), se tomó el 2026-10-14: política por fuente.`
   - Antes: `El 2026-10-19 venció el corte de CEPAL sin pronunciamiento`
   - Después: `El corte de CEPAL (2026-10-16) venció sin pronunciamiento, y se registró el 2026-10-19`

   Comprueba que la línea `**Estado:**` de ADR-008 y su celda del índice no cambian.
3. `CLAUDE.md`, línea 91: `verificado en CI sobre \`ubuntu-latest\`` → `verificado en CI sobre \`ubuntu-24.04\``. `README.md`, línea 52: `confirmado en CI sobre \`ubuntu-latest\`` → `confirmado en CI sobre \`ubuntu-24.04\``. Comprueba antes, en `.github/workflows/ci.yml`, que los dos jobs dicen `runs-on: ubuntu-24.04`.
4. Informe §4. Archivo `doc/metodologia/reportes_fase6/informe_proyeccion_fase6.md`, ancla (línea 141): `3,1 %. Es el rango de G2 y G3, y está por encima de G1.` Inserta después, con una línea en blanco antes:
```
**Nota (AAAA-MM-DD, auditoría independiente de Fase 6, hallazgo M5).** Las bandas de esta tabla son las de G1. El
sendero trimestral de estos modelos es idéntico en los tres grupos, pero las bandas del promedio se simulan con una
semilla que depende del grupo y difieren hasta 0,12 pp: `UNI.UC_LLT` da [1,1; 4,9] en G1, [1,0; 5,0] en G2 y
[1,0; 4,9] en G3. Las de cada grupo están en `proyeccion_anual_fase6.csv`. Es un error de Monte Carlo de ese orden
en las bandas anuales.
```
   Comprueba antes esos tres pares en `proyeccion_anual_fase6.csv` (corrida `SIN_ESCENARIO`, cifra `promedio`, columnas `crecimiento_inf80` y `crecimiento_sup80`, a un decimal).
5. Registro de cierre. `doc/adr/README.md`, al final del archivo (después de lo que agregó el PR-1), agrega solo si `gh pr view 95 --json state,closedAt` confirma que el PR #95 está cerrado sin fusionar (si `gh` no está disponible, pregúntale a Harold y usa la fecha que él te dé):
```

### Nota (AAAA-MM-DD) — auditoría independiente de Fase 6, hallazgo M5

El PR #95 se cerró sin fusionar el <fecha de closedAt>, después de este registro, que en «Higiene» lo da por abierto.
El texto de arriba se conserva sin editar.
```

### Verificación del PR-3

```bash
Rscript -e "testthat::test_dir('tests')"      # FAIL 0; mismos PASS y SKIP que en el PR-2
grep -rn 'AAAA-MM-DD\|según A[0-9]\|<fecha de closedAt>' README.md CLAUDE.md catalogos/README.md doc/adr/README.md \
  doc/checklist_fase6.md doc/evidencia_corrida_fase6.txt doc/metodologia/protocolo_proyeccion.md \
  doc/metodologia/decisiones_fase6.md doc/metodologia/reportes_fase6/informe_proyeccion_fase6.md
  # esperado: una sola línea, la que ya existía en catalogos/README.md: | `fecha_corrida` | fecha de la corrida (AAAA-MM-DD) |
git diff --stat
```
Mensaje sugerido: `Remediación F6 (M1, M3, M4, M5): notas fechadas en la evidencia reemplazada, el protocolo y el acta; diccionario de 07 para Fase 6; estado al día`.

---

## PR-4 · `remediacion-f6/deposito` — depósito del informe y registro de la remediación

Se hace al final, cuando los PR anteriores estén fusionados y con CI verde.

1. Crea `doc/auditorias/auditoria_independiente_fase6_SIE-el-salvador.md` con el contenido **exacto** del Anexo A (desde `## Auditoría independiente — cierre de Fase 6` hasta el final de la fe de erratas).
2. Al final de ese archivo, agrega:
```

---

### Nota de remediación (AAAA-MM-DD)

Agregada por quien remedió; el informe de arriba se conserva sin editar.

| Hallazgo | Resolución | Commit (merge) |
|---|---|---|
| I1 | Nota de corrección en F6-09, en el §8 del protocolo y en el registro; sensibilidad de la regla preregistrada versionada y reportada en el §5 del informe; prueba de reconstrucción de las tablas | <commit PR-1>, <commit PR-2> |
| I2 | Adopción por Harold de las tres lecturas (senda v0.13) y de F6-14 a F6-18<; delegaciones futuras en la regla 4 de `CLAUDE.md`, si A3 = a> | <commit PR-1> |
| I3 | <Enmienda | Nota de desvío> de ADR-002 (A5 = <a/b>), con notas en el «Registro» de los supuestos y en el acta | <commit PR-1> |
| M1 | Nota sobre las horas de la PC INVE en la evidencia reemplazada y en el checklist | <commit PR-3> |
| M2 | Nota en la medición previa del BVAR | <commit PR-1> |
| M3 | Notas en el protocolo (§10, §11) y en la evidencia reemplazada; decisión del 2026-11-15 en el acta | <commit PR-3> |
| M4 | Diccionario de `07` para Fase 6; nota en F6-12 | <commit PR-3> |
| M5 | `README.md`, «Estado general» del índice de ADR, `ubuntu-24.04`, nota en el §4 del informe<, nota del PR #95> | <commit PR-3> |

CI verde: <run sobre el último merge>. Tags: `v0.9.0-fase6` → <commit>; `v0.9.1-fase6` → <commit, cuando Harold lo cree>.
```
3. Copia este prompt, tal como Harold te lo pasó (con el bloque A marcado), a `doc/auditorias/prompt_remediacion_auditoria_fase6.md`, como se hizo con el de Fase 5.
4. En `doc/auditorias/README.md`, agrega dos filas a la tabla, después de la del prompt de Fase 5 (`| \`prompt_remediacion_auditoria_fase5.md\` | …`):
```
| `auditoria_independiente_fase6_SIE-el-salvador.md` | 2026-11-19 | `c898723` (cierre de Fase 6) | I1–I3, M1–M5 | Remediados en <commits> — ver la nota de remediación al final del propio informe |
| `prompt_remediacion_auditoria_fase6.md` | 2026-11-19 | `c898723` | — | No es una auditoría: instrucciones de remediación del informe anterior, con el bloque de decisiones A1–A7 tal como se entregó; se conserva como registro del procedimiento |
```
5. En `doc/adr/README.md`, agrega al final del archivo una sección nueva (este `##` es correcto aquí: no empieza con «Cierre de Fase», así que el guard no la toma por un cierre):
```

## Remediación de la auditoría independiente de Fase 6 (AAAA-MM-DD)

La auditoría independiente del cierre de Fase 6 (`doc/auditorias/auditoria_independiente_fase6_SIE-el-salvador.md`,
commit auditado `c898723`) encontró I1–I3 y M1–M5, sin críticos. Resolución por hallazgo y commits: ver la nota de
remediación al final del propio informe. Decisiones de Harold registradas en esta remediación: adopción de las
lecturas (A1) y de F6-14 a F6-18 (A2); delegaciones futuras (A3 = <a/b>); F6-09-c como regla principal, con la
preregistrada reportada al lado (A4 = a); ADR-002 (A5 = <a/b>); ruta del tag (A6 = <a/b>). Ninguna cifra de la
proyección cambió: no se volvió a correr `make fase6`.
```
6. Propagación del tag (familia C2/C1 de las auditorías anteriores). Si `v0.9.0-fase6` ya existe:
   - `README.md`, línea 25, al final: `Tag \`v0.9.0-fase6\` (propuesto); la revisión independiente en \`doc/auditorias/\` está pendiente.` → `Tag \`v0.9.0-fase6\`; revisión independiente en \`doc/auditorias/\`.`
   - `CLAUDE.md`, línea 11: `(tag \`v0.9.0-fase6\` propuesto; revisión independiente pendiente en \`doc/auditorias/\`;` → `(tag \`v0.9.0-fase6\`; revisión independiente en \`doc/auditorias/\`;`
   Si el tag todavía no existe, no toques esas líneas y dilo.
7. En `doc/checklist_fase6.md`, ítem **F4**: `- [ ] **F4** Revisión independiente en \`doc/auditorias/\` y tag de cierre.` → `- [x] **F4** Revisión independiente en \`doc/auditorias/\` y tag de cierre.`, y agrega debajo la línea `  — AAAA-MM-DD: revisión independiente depositada (\`<commit>\`) e indexada; tag \`v0.9.0-fase6\` → \`<commit>\` (run <run>).`
8. Verificación final: `Rscript -e "testthat::test_dir('tests')"` en verde; `grep -rn 'AAAA-MM-DD\|<commit\|<run\|<a/b>' README.md CLAUDE.md doc/adr/README.md doc/checklist_fase6.md doc/auditorias/README.md` sin resultados, y lo mismo en la nota de remediación del informe depositado. El cuerpo del informe depositado y el prompt depositado sí contienen `AAAA-MM-DD` y marcadores dentro de su propio texto citado: eso es correcto y no se toca.

**Después del merge:** Harold crea `v0.9.1-fase6` (con A6 = a, `v0.9.0-fase6` ya está sobre el merge del PR-2; con A6 = b, sobre `c898723`) con un mensaje como: «Remediación de la auditoría independiente de Fase 6 (I1–I3, M1–M5). No sustituye a v0.9.0-fase6. CI verde: run <run>.» `CITATION.cff` queda en `0.9.0`, como en las remediaciones de Fase 4 y Fase 5.

---

## Informe final que entregas a Harold (después de cada PR)

Un mensaje corto con: rama; `git diff --stat`; resultado literal de las verificaciones (línea de resumen de `testthat`, sha256 y conteos de los archivos nuevos, cifras comprobadas); lo que saltaste y por qué (decisión vacía, ancla que no apareció, valor distinto), y el mensaje de commit sugerido. Nada más: Harold decide el commit y la fusión, y Claude chat verifica después cada PR contra `origin/main` por clon fresco.

---

## Anexo A — Informe de auditoría a depositar

Contenido exacto de `doc/auditorias/auditoria_independiente_fase6_SIE-el-salvador.md` (desde `## Auditoría independiente — cierre de Fase 6` hasta el final de la fe de erratas). En este depósito, el informe ya está en ese archivo; no se repite aquí.

## Anexo B — `tests/test-tablas-fase6-reconstruccion.R`

Contenido exacto de la prueba de reconstrucción de las tablas de Fase 6. En este depósito, la prueba ya está en `tests/test-tablas-fase6-reconstruccion.R`; no se repite aquí.
