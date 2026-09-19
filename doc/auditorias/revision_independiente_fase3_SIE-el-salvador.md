## Revisión independiente — Fase 3 en curso, SIE El Salvador

**Fecha:** 2026-09-17 · **Commit revisado:** `e8116f1` (HEAD de `main`) · **Método:** clon fresco
descargado desde GitHub, revisión contra el contenido real del árbol. Sin autoridad decisoria:
identifica hallazgos; lo que decide es el ADR correspondiente (`doc/auditorias/README.md`).

### Resumen para orientarse

El repositorio está en mejor estado que la mayoría de proyectos de tesis que se revisan: 10 ADR,
84 publicaciones catalogadas, 106 series en `03_series.csv`, 56 *vintages* con doble checksum,
CI con dos trabajos, 7 archivos de prueba, y una bitácora de verificaciones donde cada alta de
serie de Fase 3 tiene su corrida asentada (regla 8 cumplida en las cinco altas del 2026-09-16).
La integridad referencial entre catálogos resuelve limpia en todas las aristas planas que
comprobé (las dos con excepciones están en I4), y
las reglas de transformación están separadas de los scripts que tocan disco, con pruebas sobre
datos sintéticos. Nada de lo que sigue cambia ese juicio general.

Los hallazgos se concentran en un punto y son del mismo tipo: **el sistema confía en que L1 esté
bien formado, pero para las series predictoras nada lo comprueba.** Un hallazgo crítico
(pérdida silenciosa de observaciones en la agregación mensual→trimestral, reproducido), cuatro
importantes y cinco menores.

Lo que **no** pude verificar, y conviene tenerlo presente al leer: `data/L0_raw/` y las capas
L1–L4 no están versionadas (`.gitignore`), así que no vi ningún dato real — solo catálogos,
código y documentación. No corrí `make raw`, `make master` ni `make test`: sin L0 no hay entrada.
La revisión es estática más una reproducción aislada de las funciones puras de L3.

---

### Hallazgos — CRÍTICO

#### C1. La agregación mensual→trimestral pierde observaciones en silencio ante un valor ausente

`src/transformacion/l3_predictores_reglas.R`, `.agregar_trimestral()`. El control de huecos
cuenta **períodos**, no **valores**:

- línea 30: `conteo <- table(periodo_q)` — cuenta filas por trimestre;
- línea 33: `incompletos <- names(conteo)[conteo != 3]`;
- línea 42: `agregada <- aggregate(valor ~ periodo_q, ...)` — la interfaz de fórmula de
  `aggregate()` aplica `na.action = na.omit` **por defecto**, así que descarta la fila con
  `valor` ausente antes de aplicar `FUN`.

Consecuencia: un mes presente pero con celda vacía pasa el control de huecos (el período existe,
el trimestre tiene 3 filas) y luego desaparece de la suma. El trimestre se calcula sobre 2 meses
y se escribe en L3 con un `OK:` en consola. Para una serie de flujo (remesas, exportaciones FOB)
eso subestima el trimestre en ~⅓; para un índice de nivel, el promedio se toma sobre 2
observaciones sin dejar rastro.

Reproducido sobre las funciones del repositorio, sin modificarlas (R 4.5.3):

```r
source("src/transformacion/l3_predictores_reglas.R")
m <- data.frame(periodo = sprintf("2020-M%02d", 1:6), valor = c(10, NA, 10, 10, 10, 10))
agregar_trimestral_suma(m, "DEMO_FLUJO")      # 2020-Q1 = 20  (debería fallar, no devolver 20)
agregar_trimestral_promedio(m, "DEMO_NIVEL")  # 2020-Q1 = 10  (promedio de 2 meses)
```

La entrada que lo dispara no es hipotética: los extractores construyen la fila desde el rango
declarado en `03_series.csv` (`col_inicio`…`col_fin`) y una celda **genuinamente vacía** produce
`valor = NA` sin detener nada — el control `faltantes_reales` de
`src/transformacion/extraer_bcr_remesas.R` (y sus ocho gemelos) es `is.na(vals) & !is.na(vals_raw)
& trimws(vals_raw) != ""`, es decir, falla ante un valor **no numérico**, no ante uno **ausente**,
que es la convención del propio proyecto para "dato no disponible". Hoy el rango declarado termina
exactamente en el último mes publicado (verificado en `BCR.IVAE.VOL.SA.M`: `B`…`IX` = 257 columnas
= 2005-M01…2026-M05), así que probablemente L1 no contiene ausentes todavía; no puedo confirmarlo
porque L1 no se versiona. La ventana se abre en la próxima recaptura en que `col_fin` se extienda
por delante de lo publicado, o ante un hueco interior de la fuente.

Esto contradice la regla 7 (`CLAUDE.md`): la validación falla, no advierte. Y contradice el
espíritu de la regla 6, aplicado a la transformación en vez de a la descarga.

**Corrección mínima** — en `.agregar_trimestral()`, antes del control de huecos:

```r
if (anyNA(mensual$valor)) {
  stop("FALLO VISIBLE [", etiqueta, "]: valor(es) ausente(s) en L1 en el/los período(s): ",
       paste(mensual$periodo[is.na(mensual$valor)], collapse = ", "))
}
```

y un caso en `tests/test-l3-predictores.R` con un mes en `NA` (los 11 casos actuales no ejercen
ninguna ruta con ausentes: la cadena `NA` no aparece en el archivo). Si en algún momento un
ausente debiera ser admisible, eso es una decisión metodológica no cubierta por ADR-010 → regla 4.

---

### Hallazgos — IMPORTANTE

#### I1. La batería L2 cubre el PIB y nada más; las predictoras entran a L3 sin validar

`src/validacion/validar_l2_pib.R` restringe el universo a las cuatro publicaciones de PIB
(línea 36, `PUBLICACIONES_PIB`) — correctamente, es lo que su nombre promete. Pero el pipeline
de `make master` produce **nueve** archivos de L1 (PIB, IVAE, REMESAS, IPC, IPP, BALANZA
COMERCIAL, ITCER, ÍNDICES DE PRECIOS DE COMERCIO EXTERIOR, UT DEMANDA) y solo el primero pasa
por una batería. Las otras ocho van directo a `l3_predictores.R`.

Entre los cinco controles de L2 que las predictoras se saltan está `col_vals_not_null` sobre
`valor` (`src/validacion/l2_pib_reglas.R`) — precisamente el que atajaría C1 aguas arriba. Los
otros cuatro (esquema, integridad referencial en ambos sentidos contra `03_series.csv`,
duplicados en la clave, continuidad de períodos) también son aplicables tal cual a una serie
mensual. El entregable de Fase 3 de la senda §4 es una batería de validaciones de la capa L2, no
una batería para el PIB.

Recomendación: extraer de `l2_pib_reglas.R` los cuatro controles agnósticos al concepto a un
`validar_l2_serie_larga(l1, catalogo, freq)` y correrlo sobre los nueve archivos, dejando la
identidad contable de agregados (control 5) donde está, específica del PIB nominal. Es una
refactorización, no un diseño nuevo.

#### I2. `make validate` no comprueba tipos ni claves foráneas, y la única FK del *datapackage* no puede resolver

`src/validacion/validate_catalogs.R` implementa cuatro controles: campo presente, `required`,
`unique`, `enum`. El `type` de cada campo se lee (línea 28, `ftype <- field$type`) y **nunca se
usa**. En `catalogos/datapackage.json` hay 80 campos con tipo declarado — 73 `string`, 4
`integer`, 2 `date`, 1 `boolean` — y ninguno se verifica; las restricciones declaradas son 7
`required`+`unique`, 5 `required` y 3 `enum` sobre 80 campos. El mensaje de éxito
("todos los esquemas cumplen `datapackage.json`") promete bastante más de lo que el script
comprueba. `pointblank` se carga en ese archivo y no se usa.

Además, las dos únicas claves foráneas declaradas en el *datapackage*
(`catalogos/datapackage.json`, líneas 51–52) apuntan a los recursos `01_publicaciones` y
`02_metodologias`, que **no están declarados como recursos** en ese archivo (los recursos son
`00`, `03`, `04`, `05`, `07`, `08`, `09`). Ningún validador conforme a Frictionless podría
resolverlas; el script propio no lo nota porque no valida FKs en absoluto. Que la integridad
referencial esté sana hoy se debe a `tests/test-integridad-referencial.R`, que es —como su propia
cabecera dice— un adelanto de esta validación.

Recomendación, en el orden en que rinde: declarar los dos catálogos YAML como recursos del
*datapackage* (o mover esas FKs a donde sí puedan resolver), y sustituir los cuatro controles
artesanales por `pointblank` (`col_is_character`/`col_is_integer`/`col_vals_in_set`/
`rows_distinct`), que ya es dependencia declarada y es lo que la senda §3.5 anticipa para Fase 3.

#### I3. Dependencias usadas en código commiteado y no declaradas en `DESCRIPTION`

Mismo patrón que el hallazgo M1 de la auditoría de Fase 2 (que se remedió para `digest`, `polite`
y `readxl`), reaparecido en cuatro paquetes:

| Paquete | Dónde se usa | En `renv.lock` | En `DESCRIPTION` |
|---|---|---|---|
| `here` | 11 archivos (`l3_*.R`, `validar_l2_pib.R`, 5 tests, `auditoria_mecanica.R`) | sí (1.0.2) | **no** |
| `testthat` | los 7 archivos de `tests/` | sí (3.3.2) | **no** |
| `dplyr` | `validate_catalogs.R`, `ut_demanda_serie.R` | sí | **no** |
| `stringr` | `calendario_bcr_extraer.R` | sí | **no** |

Hoy no rompe nada porque el lockfile los tiene (187 paquetes). El riesgo es el mecanismo de
recuperación: `scripts/bootstrap_renv.R` regenera el lockfile *a partir de `DESCRIPTION`*, así
que una regeneración —el escenario que ese script existe para cubrir— produciría un entorno sin
`here` ni `testthat`, y con eso no arrancan los scripts de L3 ni ninguna prueba. Es exactamente
el fallo que M1 documentó, con otros nombres.

Relacionado y del mismo tamaño: `validate_catalogs.R` usa `%||%` (líneas 29, 33, 44…) sin
definirlo ni importarlo de `rlang`. Ese operador existe en R base **desde 4.4.0**; `DESCRIPTION`
no declara `Depends: R (>= 4.4)` y `renv.lock` fija la versión de R de la máquina que lo generó.
En CI pasa porque `setup-r` instala `release`. En una máquina con R 4.3 el primer objetivo del
pipeline (`make validate`) falla con "object '%||%' not found".

#### I4. El catálogo `04_transformaciones` declara `funcion` y `script_path` por fila, pero el código no los lee

`catalogos/04_transformaciones.csv` es, de hecho, una especificación ejecutable: cada fila trae
`series_insumo`, `serie_producto`, `script_path` y `funcion` (`agregar_trimestral_promedio()`,
`agregar_trimestral_suma()`, `deflactar_serie()`…). `src/transformacion/l3_predictores.R` no la
usa: repite a mano un bloque de seis líneas por serie (leer → filtrar → ordenar → agregar →
escribir → `cat`) seis veces, con el nombre de la función y el del archivo de salida escritos en
el código. Hay dos fuentes de verdad para el mismo hecho —qué función agrega qué serie— y nada
comprueba que coincidan. Añadir el séptimo predictor es copiar y pegar el bloque, con el riesgo
habitual: el `etiqueta =` que se olvida de cambiar.

Síntoma ya presente de esa desconexión: `T001_CONCAT_PIB_NSA` declara como producto
`PIB.NSA.CONCAT.Q`, que **no existe** en `05_series_master.csv` (los 16 registros incluyen
`PIB.SA.PROPIO.Q` y `PIB.SA.OFICIAL.Q`, no el intermedio). De los diez productos declarados en
`04`, nueve resuelven contra `05` y ese no. No es un error de dato —el intermedio existe solo en
memoria, nunca se escribe— pero deja al catálogo afirmando un producto que el sistema no registra
en ninguna parte, y `tests/test-integridad-referencial.R` no cubre esa arista (cubre `05 → 04`,
no `04 → 05`).

Recomendación: hacer que `l3_predictores.R` recorra las filas de `04_transformaciones.csv`
resolviendo `funcion` con `match.fun()` (el catálogo pasa a ser la especificación que ya dice ser),
y añadir al test de integridad referencial la arista `04.serie_producto → 05.series_master_id`,
con el criterio explícito para intermedios: registrarlos en `05` con un `rol` propio, o declarar
en `04` que un producto intermedio no se registra.

---

### Hallazgos — MENOR

**M1. L2 no se materializa como capa; el pipeline real es L0→L1→L3.** Nada escribe datos en
`data/L2_validated/`: lo único que aparece ahí es `reporte_calidad_l2_pib.html`
(`validar_l2_pib.R`, línea 50). Los dos scripts de L3 leen de `data/L1_staging/`. Es una decisión
defendible (L2 como compuerta, no como capa persistida) y está dicha en los comentarios, pero la
senda §3.1 describe capas unidireccionales donde cada una se genera de la anterior, y `05_series_master.linaje_l0`
cita archivos de L0. Conviene que lo diga un ADR o una enmienda de §3.1, no un comentario.

**M2. La especificación de X-13 está registrada en prosa, no fijada en el código.**
`04_transformaciones.csv` (T002) documenta el resultado real de la corrida del 2026-09-16:
`ARIMA(1 1 1)(0 1 1)`, `transform=log`, dos outliers AO en 2020-Q2 y 2020-Q3. El código llama
`seasonal::seas(x)` con selección automática (`l3_pib_objetivo_reglas.R`, línea 69) y descarta el
objeto del modelo tras leer `outlier()`. Con el próximo *vintage* la selección puede cambiar —y
cambiar toda la historia de la variable objetivo— sin que nada avise, dejando la celda `parametros`
afirmando algo falso. Dado ADR-007, la opción natural es congelar la especificación con
`seasonal::static(modelo)` tras la primera estimación y guardarla como artefacto de L3 por
*vintage*, o al menos fallar de forma visible si el modelo seleccionado difiere del declarado.
`x13binary` (1.1.61.2) sí está en el lockfile, de modo que la mitad binaria del problema ya está
resuelta.

**M3. Rutas relativas mezcladas con `here::here()`.** `l3_pib_objetivo.R` (línea 16),
`l3_predictores.R` (líneas 52, 67, 71, 94, 108, 122…), `validar_l2_pib.R` y
`validate_catalogs.R` leen con rutas relativas al directorio de trabajo, mientras que los
`source()` de esos mismos archivos usan `here::here()`. Funciona porque el `Makefile` corre desde
la raíz; se rompe en cuanto algo los invoque desde otro directorio.

**M4. `catalogos/` no tiene README con diccionario de variables.** La convención de `CLAUDE.md`
(§Convenciones) dice: "Cada directorio de catálogo lleva su propio `README.md` con diccionario de
variables". No hay ninguno: los cuatro README del repositorio son el raíz, `doc/adr/`,
`doc/auditorias/` y `src/adquisicion/`. El `datapackage.json` trae `description` por campo, así
que el diccionario existe en forma de máquina — falta la puerta de entrada legible, o retirar la
convención si se considera subsumida.

**M5. Conteos desactualizados en `README.md`.** Dice "155 paquetes: los 13 de ADR-009 más `xml2` y
`httr2`"; el lockfile tiene 187 y `CLAUDE.md` ya lo corrigió (remediación de M1 de Fase 2). La
corrección no se propagó al README. Mismo tipo de deriva, menos grave, en la sección Estado: los
conteos de cierre de Fase 1 y 2 (98 series, 54 archivos de L0) son correctos **como registro de
cierre**, pero se leen como estado presente; hoy `03_series.csv` tiene 106 filas (98 de PIB + 8
predictoras admitidas en Fase 3) y el manifiesto 56 archivos. Dado que `make audit` ya calcula
todos esos números, la salida de `scripts/auditoria_mecanica.R` es la fuente que el README
debería citar en vez de reescribir a mano.

---

### Verificaciones que resultaron limpias (con las cifras)

| Verificación | Resultado |
|---|---|
| Campos declarados en `datapackage.json` vs cabecera real de los 7 CSV | 7/7 idénticos, mismo orden |
| Claves naturales duplicadas o vacías en los 7 catálogos | 0 |
| `03_series.publicacion_id` → `01_publicaciones/*.yaml` | 106/106 resuelven |
| `03_series.metodologia_id` → `02_metodologias/*.yaml` | 103/103 no vacíos resuelven (3 vacíos, permitido) |
| `01_publicaciones.institucion_id` → `00_instituciones` | 84/84 |
| `predecesor_id`/`sucesor_id` en `02_metodologias` | todos resuelven |
| `08_vintages.publicacion_id` → `01_publicaciones` | 56/56 |
| `08_vintages.archivo_raw` → `manifiesto.csv` | 56/56 |
| `05_series_master.transf_id` → `04` y `series_insumo_ids` → `03` | 16/16 |
| `09_rupturas.series_afectadas` según `tipo_referencia` | 14/14 (5 `serie_id`, 9 `publicacion_id`) |
| YAML de `01_` y `02_` parseables y con las claves canónicas de `_plantilla.yaml` | 84/84 y 15/15, 9 y 8 claves, cero parse errors |
| `publicacion_id` interno == nombre de archivo | 84/84 |
| Convención de identificadores `{fuente}.{concepto}.{unidad}.{ajuste}.{frecuencia}` | 106/106 `serie_id` y 16/16 `series_master_id` conformes |
| `script_path` de `04_transformaciones` existe en el árbol | 2/2 |
| `parametros` y `metodologia_ref` declarados por fila (exigencia de ADR-010) | 10/10 filas, con el método y el deflactor explícitos |
| Bitácora de verificaciones vs altas de Fase 3 | las 5 sesiones del 2026-09-16 asentadas, una por alta (regla 8) |
| Separación reglas puras / scripts de disco + pruebas sintéticas | 3/3 módulos (`l2_pib`, `l3_pib_objetivo`, `l3_predictores`), 28 `test_that` en los 3 |

Dos cosas que merecen mención aparte porque son poco comunes y están bien hechas: la tolerancia
de empalme de `concatenar_pib_nsa()` (0.01, justificada por la precisión publicada de cada tabla,
con la diferencia máxima real medida y documentada) y el criterio de trimestre incompleto de borde
vs hueco interior en `.agregar_trimestral()`. Ambas son del tipo de decisión que normalmente queda
implícita en el código y acá está razonada en el catálogo y en la nota metodológica.

### Límites de esta revisión

- No vi datos: `data/L0_raw/` y L1–L4 no se versionan. Todo lo que dependa del contenido real de
  los `.xlsx` (correspondencia `fuente_celda`, checksums, cobertura efectiva) queda fuera; para
  eso la evidencia del repositorio son `doc/bitacora_verificaciones.md` y
  `doc/evidencia_cierre_fase2.txt`, que leí pero no pude re-ejecutar.
- No corrí `make validate`, `make test` ni `make master` (sin L0 no hay entrada; y el stack R del
  proyecto, con `renv::restore()`, no está instalado en este entorno). La reproducción de C1 usó
  solo las funciones puras de L3, que no dependen de paquetes.
- No revisé en profundidad `src/adquisicion/` (Fase 2, ya auditada dos veces, la última contra un
  clon fresco) ni los ADR como decisiones metodológicas: acepté cada ADR como dado y revisé si el
  código y los catálogos cumplen lo que el ADR dice. La única excepción es M2, donde el
  incumplimiento es potencial y del propio registro.
- `07_experimentos.csv` está vacío y `catalogos/06_modelos/` solo tiene su plantilla: es lo
  esperado antes de Fase 4, no un hallazgo.

### Orden sugerido de atención

1. **C1** — dos líneas de código y un caso de prueba. Es lo único que puede producir un dato
   silenciosamente incorrecto en la capa que alimenta a los modelos.
2. **I1** — refactorizar la batería L2 para que cubra las nueve series de L1. Subsume C1 aguas
   arriba y es un entregable de la fase en curso, no trabajo extra.
3. **I3** — cuatro líneas en `DESCRIPTION` más `Depends: R (>= 4.4)`. Barato y evita un fallo
   difícil de diagnosticar en una máquina nueva.
4. **I2** — cerrar la validación de esquema con `pointblank` (tipos + FKs) y arreglar los recursos
   del *datapackage*. Es el entregable de validación de Fase 3; al implementarlo, el test de
   integridad referencial se subsume como ya anticipa su cabecera.
5. **I4** — que `l3_predictores.R` lea `04_transformaciones.csv`. Conviene hacerlo **antes** de
   admitir más predictores, no después: cada serie nueva multiplica el bloque copiado.
6. **M2** — congelar la especificación de X-13. Antes de la primera corrida de evaluación de Fase 4,
   porque a partir de ahí la variable objetivo tiene que ser estable entre corridas.
7. **M1, M3, M4, M5** — deuda de documentación y consistencia; ninguna bloquea Fase 3.

### Nota sobre Fase 4 y los modelos

Nada de esto toca el diseño de la comparación de modelos, y es coherente con la prioridad
declarada en `CLAUDE.md` (el SIE es el producto; los modelos son la prueba de uso). Pero vale
señalar la dependencia: el protocolo de evaluación de Fase 4 —validación con origen móvil,
métricas, pruebas de Diebold-Mariano— mide diferencias que suelen ser de centésimas de RMSE.
Una observación trimestral construida sobre dos meses en vez de tres (C1), o una variable objetivo
cuya especificación de ajuste estacional cambia entre corridas (M2), producen diferencias de ese
mismo orden. Las dos son del tipo de defecto que no se detecta mirando resultados de modelos:
se detecta acá, o no se detecta.

---

### Nota de remediación (2026-09-17/18, Claude Code)

C1, I1–I4 y M1–M5 quedaron remediados en dos sesiones consecutivas.

La primera (2026-09-17, commit `a6ec10e`) cerró: **C1** (`.agregar_trimestral()` falla visible
ante `NA` en `valor` antes de agregar, con dos casos nuevos en `tests/test-l3-predictores.R`);
**I1** (checks 1–4 de la batería L2 extraídos a `src/validacion/l2_serie_larga_reglas.R` para
cualquier frecuencia, y `validar_l2_predictores.R` nuevo corriendo esa batería sobre las 7 series
predictoras, encadenado en `make master` antes de `l3_predictores.R`); **I2** (`validate_catalogs.R`
empieza a usar el `type` declarado, vía `pointblank::col_vals_regex()`); **I3** (`DESCRIPTION`
gana `Depends: R (>= 4.4)` y declara `here`/`testthat`/`dplyr`/`stringr`); **I4**
(`l3_predictores.R` reescrito para iterar `catalogos/04_transformaciones.csv` y resolver `funcion`
con `match.fun()`, en vez de seis bloques copiados); **M2** (`ajustar_estacional_propio()` falla
visible si los outliers que detecta `seas()` no coinciden con los declarados en `04`, con test de
regresión); **M3** (rutas relativas homogeneizadas con `here::here()` en los archivos señalados);
**M4** (`catalogos/README.md` nuevo, con diccionario de variables); **M5** (conteo de paquetes del
`README.md` corregido y nota que remite a `make audit` en vez de cifras de cierre transcritas).

Dos puntos de I4 y M1 quedaron deliberadamente sin resolver en esa primera pasada por requerir una
decisión de Harold, no una corrección mecánica (regla 4 de `CLAUDE.md`): si `PIB.NSA.CONCAT.Q`
(producto intermedio de T001, nunca persistido a disco) debía registrarse en
`05_series_master.csv`, declararse como excepción en `04`, o dejarse sin marcar; y si "L2 es una
compuerta, no una capa persistida" debía documentarse vía un ADR nuevo o una enmienda a la senda
metodológica. Harold resolvió ambos vía `AskUserQuestion` el 2026-09-18 (commit `82d06a0`):
`PIB.NSA.CONCAT.Q` se registró en `05` con `rol=intermediate` (nuevo valor de enum en
`datapackage.json`), y `doc/senda_metodologica.md` §3.1 ganó el párrafo que aclara que L2 certifica
L1 en memoria antes de que L3 la lea, sin materializar un archivo propio.

La primera pasada de I2 rompió CI dos veces seguidas: `col_vals_in_set()` no acepta el argumento
`na_pass` en la versión de pointblank fijada en `renv.lock`, y un catálogo sin filas de datos
(`07_experimentos.csv`, solo cabecera) se marcaba como fallido en vez de trivialmente conforme
(pointblank devuelve `f_pass = NA` cuando no hay unidades de prueba). Ninguno de los dos se detectó
antes de empujar porque la sesión no tenía R instalado para correr las pruebas localmente — el
mismo límite que esta revisión ya declaraba en su sección "Límites de esta revisión". Harold lo
corrigió el mismo 2026-09-18 (commit `543722b`), verificado en verde con los 372 tests de la suite
completa (incluidos los añadidos por esta remediación) corriendo por primera vez contra el código
corregido.
