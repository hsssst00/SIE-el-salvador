# Manual de actualización del SIE

**Estado:** borrador para el ensayo con el 2026-T2 (`doc/checklist_fase7.md`, C1 y C2). **No está congelado:** el
manual que juzga el criterio de cierre de Fase 7 es el que lleve el tag `manual-v1` (F7-02 de
`doc/metodologia/decisiones_fase7.md`). Las secciones que dependen de una ficha abierta lo dicen.

## 0. Para quién es y qué cubre

Este manual es para quien **opera** el sistema: incorpora una publicación nueva y deja la base maestra al día. Quien
solo **usa** las series tiene `doc/manual_usuario.md` (en preparación).

**Resultado al terminar:** la L3 vigente (`data/L3_master/`) contiene la publicación nueva, validada y con su
trazabilidad certificada, y un PR contra `main` tiene el CI en verde (F7-03).

**Qué no se actualiza.** Los ejercicios de Fase 5 y Fase 6 están congelados sobre cortes declarados
(`doc/metodologia/corte_fase5.csv`, `doc/metodologia/corte_fase6.csv`) y con preregistro. **No corras `make fase5`,
`make fase6`, `make eval` ni `make proyeccion`** como parte de una actualización: tardan horas y reescriben resultados
versionados.

**Cómo leer cada paso.** Cada paso trae el comando, lo que debe salir y qué hacer si no sale así. Si algo no coincide
y el manual no dice qué hacer, detente y anótalo en tu bitácora (anexo C): eso es un defecto del manual, no tuyo.

**Cinco reglas que no se rompen** (de `CLAUDE.md`):
1. Nunca edites a mano `data/L0_raw/` ni las capas L1 a L4. Todo se genera por código.
2. Los catálogos (`catalogos/`) solo se editan dentro de su esquema (`catalogos/datapackage.json`).
3. Ante una decisión de método que el manual no cubre (una serie nueva, un dato faltante raro), detente y pregunta.
4. La validación falla, no advierte: si un paso se detiene, no lo saltes.
5. Una sola pasada de captura por ventana. Nunca evadas un bloqueo de una fuente (regla 9).

## 1. Requisitos previos (una sola vez)

| Requisito | Para qué | Cómo comprobarlo |
|---|---|---|
| R 4.6.1 | Es la versión de `renv.lock` y del CI | `R --version` |
| Git y una cuenta de GitHub | Clonar y abrir el PR | `git --version` |
| Windows: Rtools (trae GNU Make) | Correr los objetivos del `Makefile` | `make --version` |
| Google Chrome o Chromium | `chromote` abre el portal del BCR, que arma las tablas en el navegador | Chrome abre normalmente |
| Clave propia de la API de FRED | Captura de FRED. Es gratuita y personal: https://fredaccount.stlouisfed.org | Sección 2, paso 3 |
| Acceso a L0 | Reconstruir la base maestra. Los crudos no están en el repo (ADR-008) | Sección 3. **Pendiente de F7-04** |

X-13ARIMA-SEATS no se instala aparte: lo trae el paquete `x13binary` de `renv.lock`. Se comprueba en la sección 2.

**En Windows**, `make test` puede terminar con `Segmentation fault` **después** de mostrar las pruebas en verde. No es
un fallo de las pruebas (ver `doc/entorno_windows.md`). Usa en su lugar
`Rscript -e 'testthat::test_dir("tests")'`, que sale con código 0.

## 2. Instalar el entorno

1. `git clone https://github.com/hsssst00/SIE-el-salvador.git` y abre `SIE-el-salvador.Rproj` (o entra a la carpeta
   desde una terminal). Todos los comandos se corren desde la raíz del repo.
2. En R: `renv::restore()`. Instala las versiones exactas de `renv.lock`. Debe terminar sin error.
3. Copia `.Renviron.example` a `.Renviron`, reemplaza `FRED_API_KEY=xxxx…` por tu clave y **reinicia R**. `.Renviron`
   no se versiona.
4. En R: `seasonal::checkX13()`. Debe decir que X-13 funciona.
5. En la terminal: `make validate`. Debe salir con código 0. Valida los catálogos contra su esquema y su integridad
   referencial.
6. Pruebas: `Rscript -e 'testthat::test_dir("tests")'`. Todas deben pasar.

Si el paso 2 falla en Linux por `libgit2`, instala `libgit2-dev` (es lo que hace el CI, `.github/workflows/ci.yml`).

## 3. Poner L0 en la máquina

**Pendiente de F7-04** para quien no tiene acceso al almacén. Con acceso:

1. Clona el repo privado de L0 en cualquier carpeta y define la variable `SIE_L0_STORE` con esa ruta (en `.Renviron`
   o en la sesión).
2. `make materializar-l0`. Copia los archivos que falten y después corre `scripts/verificar_l0_fisico.R`. Debe
   terminar con integridad N/N, con N igual al número de filas de `data/L0_raw/manifiesto.csv`. Si sale
   `FALTA_EN_ALMACEN`, el almacén no tiene un archivo del manifiesto: avisa al responsable del almacén y no sigas.
3. `Rscript scripts/check_l0_integrity.R`: el manifiesto y `catalogos/08_vintages.csv` coinciden.

Nunca sobrescribas un archivo de `data/L0_raw/`. Si uno está corrupto, `verificar_l0_fisico.R` lo dice; no lo
reemplaces a mano.

## 4. Antes de capturar: guardar la huella de la L3 actual

Sirve para separar lo que trae la publicación nueva de una diferencia de entorno. En R:

```r
huella_l3 <- function() {
  f <- list.files("data/L3_master", pattern = "\\.csv$", full.names = TRUE)
  data.frame(archivo = basename(f),
             sha256 = unname(vapply(f, function(x) digest::digest(file = x, algo = "sha256"), "")))
}
write.csv(huella_l3(), "~/huella_l3_antes.csv", row.names = FALSE)
```

La huella se guarda fuera del repo (`~` es tu carpeta de usuario) para que no entre en ningún commit y sobreviva si
reinicias R.

Si `data/L3_master/` está vacía (máquina nueva), corre primero `make master` y toma la huella después. Hoy no hay una
huella de referencia versionada para comparar entre máquinas (checklist, C3).

## 5. Saber cuándo hay publicación nueva

- **Ventanas:** días 1 a 3 de cada mes (`make raw` completo), más la captura de UT en enero, abril, julio y octubre. El
  calendario y la última ventana cumplida están en `doc/calendario_make_raw.md`.
- **Calendario del BCR:** `doc/calendario_divulgacion_bcr.csv` anuncia día y mes de cada publicación. `make
  raw-calendario` lo lee sin red y marca cada publicación `TOCA`, `NO_TOCA` o `SIN_CALENDARIO`.
- **Fuera de ventana:** una publicación del BCR se puede capturar después de publicada si cumple las tres condiciones
  de la sección 6.3.

## 6. Capturar

### 6.1 Ventana mensual

1. `make raw`. Primero verifica L0 en disco (debe pasar) y después pregunta a cada fuente en vivo. Cada publicación
   sale como:
   - `PASS`: la fuente sirve lo mismo que ya tienes. No hay nada que hacer.
   - `CAMBIO`: hay un vintage nuevo. Se captura en el paso 2.
   - `ERROR`: la fuente no respondió o respondió algo inesperado; `make raw` se detiene. Ver la sección 10.
   - `MANUAL_PENDIENTE`: UT, que se captura a mano (6.4).
2. Por cada `CAMBIO`, en R, carga el *script* de su fuente y llama a su función `descargar_*()` con
   `fecha_publicacion` = `AAAA-MM-01` del mes en que la fuente la publicó. Ejemplo para el PIB desestacionalizado:

   ```r
   source("src/adquisicion/bcr.R")
   descargar_bcr_pib_sa("2026-12-01")
   ```

   Las funciones están en `src/adquisicion/bcr.R`, `fmi.R`, `fred.R`, `bm.R` y `cbo.R`. Cada una guarda el archivo en
   `data/L0_raw/` y agrega una fila a `data/L0_raw/manifiesto.csv` y a `catalogos/08_vintages.csv`. Si el
   `vintage_id` ya existe, `registrar_descarga()` se detiene: **no lo fuerces**; anótalo.
3. **Vintages intermedios.** Compara el `periodo_referencia_max` del vintage nuevo con el del anterior de la misma
   publicación en `catalogos/08_vintages.csv`. Si avanzó más de un período, se perdieron vintages que el portal ya no
   sirve: anótalo en `doc/backlog_captura_vintages.md` con la fecha y la publicación.
4. `make raw` otra vez. Lo capturado debe salir `PASS`. Lo que siga en `CAMBIO` se movió durante la ventana y queda
   para la siguiente. **No repitas** la pasada.

### 6.2 El trimestre nuevo del PIB

Las tres publicaciones del PIB trimestral del BCR (`BCR.PIB_T.INDICES_VOLUMEN_ENCADENADOS_NSA`, `_SA` y
`BCR.PIB_T.NOMINAL`) se capturan como cualquier `CAMBIO`, con `descargar_bcr_pib_nsa()`, `descargar_bcr_pib_sa()` y
`descargar_bcr_pib_nominal()`. No hay que editar `fin` ni `col_fin` de esas series en `catalogos/03_series.csv`:
describen el vintage con que se registró la serie, y el extractor lee hasta el último período del vintage vigente
(F6-19).

### 6.3 Fuera de ventana (ADR-007 D3)

Solo para publicaciones del BCR, de a una. Se captura si se cumplen las tres condiciones: (a) `make raw-rapido` la marca
`NUEVO_PERIODO`; (b) `doc/calendario_divulgacion_bcr.csv` la anuncia para hoy o antes; (c) es el primer vintage de ese
período. Si falta una, espera a la ventana. Después de capturar, corre `make raw-fisico`.

### 6.4 UT (trimestral, a mano)

El `robots.txt` de ut.com.sv prohíbe la captura automática, así que se baja a mano.
1. `make raw` muestra UT como `MANUAL_PENDIENTE`, con los años anteriores que no llegan a diciembre.
2. Baja un CSV por año desde el formulario de Reportes Estadísticos de UT: el año en curso (salvo en enero) y cada año
   anterior que no llegue a diciembre.
3. En R: `source("src/adquisicion/ut.R")` y registra cada archivo con `registrar_ut_demanda_anual()` (o varios con
   `registrar_ut_demanda_lote()`). La salida dice si fue vintage nuevo, fecha de captura por colisión o idéntico al
   anterior (no se registra).
4. Si entró el primer archivo de un año nuevo, actualiza `fin` de `UT.DEMANDA_ELEC.GWH.NSA.M` en
   `catalogos/03_series.csv`; si no, `make trace` falla.

## 7. Registrar lo capturado

- Revisa con `git diff` que solo cambiaron `data/L0_raw/manifiesto.csv`, `catalogos/08_vintages.csv` y, si aplica,
  `catalogos/03_series.csv`. Los crudos no se versionan (`.gitignore`).
- Anota cada captura en la tabla «Entradas» de `doc/backlog_captura_vintages.md`.
- Sube los crudos nuevos al almacén de L0 desde su copia de trabajo (`git add` y `git push` allí). **Pendiente de
  F7-04** para quien no tiene acceso.

## 8. Reconstruir y certificar

1. `make validate`. Debe salir con código 0.
2. `make master` **sin** `CONJUNTO=` ni `SALIDA=`. Reconstruye L1, valida L2 y escribe la L3 vigente con el vintage
   más reciente de cada publicación. Qué esperar:
   - `PIB_SA_OFICIAL_Q.csv` y `PIB_SA_PROPIO_Q.csv` ganan el trimestre nuevo.
   - `PIB_SA_PROPIO_Q.csv` (ajuste estacional propio) **revisa su historia**: X-13 se reestima con el dato nuevo.
     Es lo esperado, no un error.
   - Las demás series ganan los meses o trimestres de sus vintages nuevos y conservan sus valores previos, salvo que
     la fuente los haya revisado.
   - La columna `vintage_id` de cada archivo dice de qué vintage salió cada fila.
3. Compara con la huella de la sección 4 (define otra vez `huella_l3()` si reiniciaste R):

   ```r
   antes <- read.csv("~/huella_l3_antes.csv")
   ahora <- huella_l3()
   x <- merge(antes, ahora, by = "archivo", all = TRUE, suffixes = c("_antes", "_ahora"))
   x[is.na(x$sha256_antes) | is.na(x$sha256_ahora) | x$sha256_antes != x$sha256_ahora, "archivo"]
   ```

   Los archivos que cambiaron tienen que ser los de las publicaciones que capturaste.
4. `make trace`. Rastrea cada serie de `catalogos/03_series.csv` hasta su celda en el archivo de L0. Debe dar 0 FAIL.
   Las filas `NO_VERIFICABLE` indican que falta el archivo en L0 (vuelve a la sección 3).
5. **Asienta la corrida de `make trace` en `doc/bitacora_verificaciones.md`**, en el mismo commit que la usa
   (regla 8): fecha, commit, archivos de L0 usados con su sha256 y el resultado (`N PASS / 0 FAIL`). Copia el formato
   de la última entrada.
6. Pruebas: `Rscript -e 'testthat::test_dir("tests")'`.

## 9. Publicar la actualización

1. Crea una rama, por ejemplo `actualizacion/2026-T3`, y haz commit de los catálogos, el manifiesto, la bitácora y el
   backlog. `data/L1`–`L4` no se versionan.
2. Abre un PR contra `main` y espera el CI en verde (validación de catálogos, pruebas, verificación sintética del motor
   y consistencia de L0). Se fusiona solo con el CI en verde (`CONTRIBUTING.md`).
3. Actualiza «Última ventana cumplida» en `doc/calendario_make_raw.md` y la línea «Próxima ventana» del `README.md`.
4. Opcional, solo si existe el tag `prospectiva-v1`: el origen nuevo de la prospectiva AP-2
   (`doc/metodologia/protocolo_prospectiva_ap2.md`). No forma parte de la actualización.

## 10. Cuando algo falla

| Síntoma | Qué significa | Qué hacer |
|---|---|---|
| `ERROR` en `make raw` | La fuente no respondió o cambió su estructura | No reintentes en bucle (regla 9). Busca la fuente en `doc/bitacora_fuentes_fragiles.md` |
| Timeout del portal del BCR | El portal (Livewire) tardó o bloqueó el navegador | Déjala para la ventana siguiente y anótalo en el backlog |
| El FMI devuelve una tabla vacía sin error | Parámetros de período mal puestos | `doc/bitacora_fuentes_fragiles.md`, sección del FMI |
| El Banco Mundial responde HTTP 200 con un error dentro | Comportamiento conocido de su API | `doc/bitacora_fuentes_fragiles.md`, sección de FRED y Banco Mundial |
| `registrar_descarga()` se detiene porque el vintage ya existe | Ya estaba capturado | No lo fuerces; anótalo |
| `FALTA_EN_ALMACEN` | El almacén no tiene un archivo del manifiesto | Avisa al responsable del almacén |
| La L3 de UT se detiene | Un año anterior al último no trae 12 meses | Vuelve a la sección 6.4, paso 2 |
| `make trace` da `FAIL` | Una serie no coincide con su celda en L0 | No edites nada; anótalo y pregunta |
| `make test` termina con `Segmentation fault` en Windows | Fallo de `cli` al cerrar R, no de las pruebas | `Rscript -e 'testthat::test_dir("tests")'` |

## 11. Qué no hacer nunca

- Editar `data/L0_raw/` o las capas L1 a L4 a mano.
- Agregar una serie o una fuente nueva sin preguntar (regla 4). En particular, ninguna serie de CEPAL entra sin
  resolver antes su condición sobre obras derivadas (ADR-008).
- Correr `make fase5`, `make fase6`, `make eval` o `make proyeccion` como parte de una actualización.
- Repetir una pasada de captura dentro de la misma ventana o evadir un bloqueo de una fuente (regla 9).

## Anexo A — Glosario

- **Vintage:** una versión publicada de una serie. Su `vintage_id` es `{publicacion_id}.v{AAAA-MM}`, por el mes de
  publicación.
- **L0 … L4:** capas de datos. L0, archivos tal como se publicaron (inmutable); L1, formato largo; L2, validación (no
  guarda datos, solo el reporte); L3, series maestras; L4, resultados de modelos.
- **Corte:** lista congelada de vintages (`publicacion_id`, `vintage_id`) con la que corre un ejercicio de Fase 5 o
  Fase 6.
- **`PASS`, `CAMBIO`, `ERROR`, `MANUAL_PENDIENTE`:** resultados de `make raw` (sección 6.1). **`NUEVO_PERIODO`:**
  resultado de `make raw-rapido`.

## Anexo B — Objetivos del `Makefile` que usa este manual

`validate`, `materializar-l0`, `raw`, `raw-rapido`, `raw-calendario`, `raw-fisico`, `master`, `trace` y `test`. Los
demás (`eval`, `fase5`, `fase6`, `proyeccion`, `explore`, `audit`, `clean`, …) no son parte de la actualización.

## Anexo C — Bitácora de la actualización

Una línea por paso: fecha y hora, sección del manual, comando, código de salida, duración y dudas. La bitácora no se
edita después; las correcciones van como líneas nuevas.

## Anexo D — Ensayo con el 2026-T2 (F7-02, primer tiempo)

**Situación de partida (verificada el 2026-11-20).** L0 ya tiene el PIB 2026-T2 (vintages `v2026-09`, capturados el
2026-10-01), pero la L3 vigente se generó el 2026-09-30 y su PIB termina en 2026-Q1. Desde entonces entraron a L0
vintages nuevos de todas las familias de la matriz: IVAE, remesas, IPP, balanza comercial (exportaciones FOB), ITCER,
índices de precios del comercio exterior (IPM), IPC de ONEC y UT (`v2026-08`).

**Qué se ejerce.** Las secciones 1 a 4 y 7 a 9. La captura (sección 6) ya está hecha, así que se salta; se ejerce en
la ventana del 1 al 3 de diciembre. Resultado esperado: el PIB de la L3 vigente llega a 2026-Q2 y las demás familias
avanzan a sus vintages vigentes.

**Qué se entrega.** La bitácora del anexo C en `doc/evidencia_ensayo_fase7.txt` y la lista de correcciones al manual
(checklist C4).
