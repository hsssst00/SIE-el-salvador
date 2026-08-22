# `src/adquisicion/` — diseño de los scripts de captura de L0

**Qué es esto.** El patrón que comparten los scripts de adquisición, decidido una vez para no
reinventarlo en cada uno. No introduce ninguna decisión metodológica nueva: traduce a forma
ejecutable lo que ya está en la senda §3.1, en las reglas 1, 5, 6, 7 y 9 de `CLAUDE.md` y en
ADR-007 y ADR-009.

**Procedencia.** Borrador aprobado por Harold el 2026-08-18. Incorporado al repositorio el
2026-08-21 en su versión corregida contra el estado real del árbol — el hallazgo I3 de la
auditoría del 2026-08-20 señaló que tres sitios lo citaban sin que existiera. La sección 0
enumera qué cambió respecto del borrador y por qué; nada se corrigió en silencio.

---

## 0. Qué cambió respecto del borrador del 2026-08-18

- **El BCR no se descarga por URL directa a un `.xlsx`.** El borrador lo daba por sentado. Las
  pruebas del 19 y 20 de agosto (registradas en `doc/bitacora_fuentes_fragiles.md`) mostraron
  que el portal `estadisticas.bcr.gob.sv` genera el archivo en el cliente vía SheetJS, sin
  petición de red que un script sin navegador pueda golpear, y que bloquea a `httr2` incluso con
  headers de navegador completos. ADR-009, nota de seguimiento del 2026-08-20, fijó `chromote`
  —automatización CDP desatendida en R, headless— como el mecanismo para esa fuente.
- **El `vintage_id` no se deriva de la fecha de descarga.** El borrador no fijaba su formato y el
  primer código lo derivó de `Sys.Date()`. ADR-007, nota de seguimiento del 2026-08-20, fijó
  `{publicacion_id}.v{AAAA-MM}` sobre la **fecha de publicación de la fuente**. Ver sección 3.
- **Se fija el formato de captura para el BCR, con su condición de falsación.** El borrador no lo
  trataba, y el portal ofrece dos ramas en el mismo botón. Decisión de Harold del 2026-08-21, con
  su justificación, la alternativa descartada y las dos pruebas que podrían invalidarla, en la
  sección 2.1.
- **Dos pendientes del borrador ya están hechos:** `httr2` es el import #15 de `DESCRIPTION` y
  está en `renv.lock` desde el 2026-08-19 (commit `ef135df`); `doc/bitacora_fuentes_fragiles.md`
  existe y está poblada.

---

## 1. Layout de archivos

```
src/adquisicion/
├── README.md                  # este documento
├── lib_adquisicion.R          # funcion compartida: checksum, manifiesto, vintage
├── bcr.R                      # una funcion por publicacion del BCR
├── fmi.R                      # una funcion por publicacion del FMI (WEO, PCPS, BOP)   [pendiente]
├── fred.R                     # una funcion por publicacion de FRED                    [pendiente]
└── banco_mundial.R            # una funcion por publicacion del BM (GEP, GEM, WDI)     [pendiente]
```

**Un script por institución, con una función independiente por publicación adentro.** La senda
§8 pide *"scripts modulares por publicación"* como mitigación contra que un cambio de estructura
en una fuente rompa las demás. Un archivo por institución cumple eso sin multiplicar archivos: si
`BCR.PIB_T.NOMINAL` cambia de formato se rompe `descargar_bcr_pib_nominal()`, no
`descargar_bcr_pib_nsa()` ni nada del FMI. La prueba de aislamiento real es "¿puedo ejecutar y
hacer fallar una publicación sin tocar las demás?", no "¿está en su propio archivo?".

**Por qué `lib_adquisicion.R` está separado.** Las mecánicas de obtención difieren por
institución —el BCR necesita un navegador headless; FMI, FRED y BM son API con `httr2`, cada una
con su propia sintaxis de filtros— y esa parte no se puede compartir. Lo genuinamente común es
lo que pasa **después** de tener la respuesta: checksum, decidir si es vintage nuevo, escribir
el manifiesto. Eso es lo que centraliza la librería.

---

## 2. Formato y nombre del archivo de L0

### 2.1 Formato de captura para el BCR

**Decisión (Harold, 2026-08-21): las publicaciones del BCR servidas desde el portal se capturan
en `.xlsx`.** El portal ofrece dos ramas en el mismo control —el botón "Descargar datos en
Excel/CSV" abre "Formato Excel" y "Formato CSV"— y 30 de las 34 fichas de
`01_publicaciones/BCR.*.yaml` declaran, correctamente, `formato: "web / csv / xlsx"`: eso
describe lo que la fuente ofrece, no lo que el proyecto archiva.

**Salvedad de encuadre, que conviene tener a la vista antes de leer los motivos.** El principio
de L0 es archivar el archivo *tal como fue publicado*. Para esta fuente eso no se cumple con
ningún formato: el portal no sirve un archivo. Los valores viajan por el protocolo interno de
Livewire y SheetJS construye el archivo enteramente en el navegador. Lo que L0 archiva —xlsx o
csv— es un artefacto producido por nuestro propio cliente a partir de los datos del portal, no el
artefacto del publicador. Esa brecha es del diseño de L0 para esta fuente, no del formato, y
existe con cualquiera de las dos opciones. Se registra acá porque el argumento "L0 debe ser lo
que la fuente publica" **no está disponible** para defender ninguna de las dos, y sería fácil
invocarlo por costumbre.

Motivos de la decisión, en orden de peso:

1. **La cadena de trazabilidad ya está construida sobre direccionamiento por celda.** Las 98
   filas de `catalogos/03_series.csv` declaran `fuente_celda` como hoja + fila + rango de
   columnas —`hoja T2, fila 24 ("PRODUCTO INTERNO BRUTO TRIMESTRAL"…), columnas…`— y
   `src/validacion/verificar_fuente_celda.R` resuelve hoja→XML vía `workbook.xml.rels` y
   concatena los runs de `sharedStrings`. Un CSV no tiene hojas ni letras de columna, y un libro
   de varias hojas exportado a CSV son varios archivos, lo que además rompería el mapeo
   uno-a-uno entre archivo de L0 y vintage. **Este es un argumento de costo de reversión, no de
   superioridad del formato**, y conviene nombrarlo así: dice que cambiar sale caro, no que xlsx
   sea mejor.
2. **Continuidad con lo ya capturado.** Los cuatro archivos del manifiesto son `.xlsx`, y
   `registrar_descarga()` decide si hay vintage nuevo comparando SHA-256 contra la captura
   anterior. El checksum de un CSV frente al de un XLSX no compara nada.
3. **Es la rama efectivamente probada.** Las tres corridas registradas en
   `doc/bitacora_fuentes_fragiles.md` (2026-08-19 y 2026-08-20) usaron "Formato Excel". La rama
   CSV no se ejercitó nunca de punta a punta.

**Alternativa considerada y no adoptada: CSV.** A favor, con peso real: es un formato sin
contenedor propietario ni metadatos, más simple de archivar y más probable de seguir siendo
legible en veinte años; y ahorraría dos dependencias del stack — `xml2` en el verificador y
`readxl` en Fase 3 (import #16 diferido en ADR-009), en un stack que ese mismo ADR se esforzó por
mantener mínimo. En contra de trasladar acá el §D5 de la senda —que rechaza las hojas de cálculo
como soporte— conviene notar que aquel rechazo se funda en que invitan a la edición manual,
esconden lógica en fórmulas y alteran tipos en silencio; L0 es un artefacto que se congela y
nunca se abre para editar, con SHA-256 como garantía, así que el argumento no se transfiere
limpio.

**Condición de falsación: dos pruebas pendientes que pueden invertir esta decisión.** Ninguna se
puede correr hoy, porque exigen el script de `chromote` funcionando. Ambas se corren en la misma
sesión, antes de la primera captura real:

- **(F1) ¿Es determinista el `.xlsx` que produce SheetJS?** Un `.xlsx` es un contenedor ZIP y
  puede llevar timestamps de creación y orden de entradas variable. Si dos exportaciones de datos
  idénticos, sin cambio en la fuente, producen SHA-256 distintos, entonces el mecanismo central
  de `registrar_descarga()` —"mismo checksum, no hay vintage nuevo"— reporta vintage nuevo en
  cada corrida y el eje bitemporal de D7 se llena de vintages espurios desde el primer día.
  Prueba: exportar dos veces seguidas sin tocar nada y comparar checksums. **Si falla, la
  decisión se invierte** y se paga el costo de rehacer `fuente_celda` y el verificador; el CSV,
  sin contenedor, es a priori más estable.
- **(F2) ¿El CSV exporta el valor almacenado o el mostrado?** Si SheetJS vuelca el valor
  redondeado a la precisión de pantalla en lugar del valor subyacente, el CSV queda descalificado
  para un proyecto cuya tesis es la trazabilidad hasta el dato de origen, con independencia de
  F1. Prueba: exportar ambos formatos de la misma serie y comparar decimales celda a celda.

El resultado de las dos se asienta acá, en esta sección, y si F1 falla se enmienda además
ADR-007 (nota de seguimiento del `vintage_id`), porque el problema sería del mecanismo de
detección de vintage, no solo del formato.

**No se capturan ambos formatos.** Sería el mismo hecho archivado dos veces (§10.6) y volumen de
descarga duplicado sin ganancia (regla 9 de `CLAUDE.md`). F2 es una prueba puntual, no una
política de doble captura.

**Alcance.** Esta decisión cubre solo las publicaciones del BCR servidas desde el portal. No dice
nada sobre las fuentes API, que guardan `.json` por lo que sigue, ni sobre
`BCR.PIB_T.SERIE_RETROPOLADA_1990_2005`, que es un `.xlsx` servido directamente y que además está
excluida de captura automatizada por `robots.txt`.

**Fuentes API, sin extensión natural:** guardar la respuesta cruda como `.json`, que es el
formato que la API devuelve. No convertir a `.csv` ni a `.xlsx` aunque el contenido termine
siendo tabular: esa conversión pertenece a L1, no a L0.

### 2.2 Nombre del archivo

Ya establecido en la senda §3.1 y confirmado contra los cuatro archivos reales del manifiesto.
No cambia:

```
{FUENTE}_{descripcion_snake_case}_{fecha_descarga}.{ext}
```

Ejemplo real: `BCR_pib_t_indices_volumen_nsa_2026-08-06.xlsx`. `FUENTE` en mayúsculas, coincide
con `institucion_id` de `00_instituciones.csv`. `fecha_descarga` es la fecha en que el script
corrió, en ISO — **no** la fecha de publicación de la fuente, que va en `08_vintages.csv`.

**Captura vía navegador headless:** el archivo cae en la carpeta de Descargas del sistema con el
nombre que le asigna el navegador, con deduplicación tipo `(2)`/`(3)` si ya existen homónimos. El
script tiene que mover y renombrar desde ahí a esta convención; no puede asumir que el archivo
aparece con el nombre correcto.

---

### 2.3 Dos checksums: integridad de archivo vs. identidad de vintage

El `.xlsx` que genera SheetJS no es determinista byte a byte (prueba F1, 2026-08-21): dos
descargas del mismo dato dan SHA-256 distintos, porque el empaquetado ZIP varía —orden físico de
las entradas o cabeceras del contenedor— aunque las entradas descomprimidas sean byte-idénticas.
Verificado, no inferido: las nueve entradas coinciden una a una y el hash del contenido
normalizado (entradas ordenadas por nombre, concatenadas descomprimidas) es idéntico entre
descargas.

Eso rompe el uso del SHA-256 crudo como detector de vintage: reportaría vintage nuevo en cada
corrida. Pero el SHA-256 crudo sigue haciendo falta para verificar que el archivo en disco no se
corrompió. Son dos preguntas distintas, y desde 2026-08-21 (ADR-007, nota de seguimiento) el
sistema las separa en dos campos, presentes tanto en el manifiesto de L0 como en `08_vintages`:

- `sha256` — del archivo crudo tal como se descargó. Integridad.
- `sha256_norm` — del contenido normalizado. Identidad de vintage. Es el que compara el paso 3.

Para fuentes cuyo crudo ya es determinista (las API que guardan `.json`), `sha256_norm` es igual a
`sha256`; solo divergen en las fuentes tipo ZIP. El campo se llena siempre.

## 3. Contrato de `lib_adquisicion.R`

Una función principal, que todos los scripts por institución llaman:

```r
registrar_descarga(
  fuente,                  # "BCR", "FMI", "FRED", "BM" — coincide con institucion_id
  publicacion_id,          # debe existir en 01_publicaciones/*.yaml
  url,                     # URL exacta consultada, con todos los parametros
  descripcion_archivo,     # snake_case, sin fuente ni fecha
  extension,               # "xlsx", "json", etc.
  contenido_crudo,         # bytes ya obtenidos: esta funcion no decide COMO se pidieron
  codigo_http,
  fecha_publicacion,       # ISO AAAA-MM-DD, declarada por la fuente. De aca sale el vintage_id
  periodo_referencia_max,
  verificacion_forma       # funcion opcional: recibe contenido_crudo, devuelve TRUE/FALSE
)
```

**Orden de ejecución.** El orden importa y no es cosmético: **nada se escribe en `data/L0_raw/`
hasta que todas las validaciones pasaron.**

0. Valida `fecha_publicacion` (presente y en ISO) y calcula
   `vintage_id = {publicacion_id}.v{AAAA-MM}`, con `AAAA-MM` tomado de la fecha de publicación.
   Si falta o no parsea, `stop()`. La función no infiere la fecha: si la fuente no la declara de
   forma parseable, quien llama pasa una aproximación explícita y anota de qué se deriva — hay
   precedente en `BCR.PIB_T.SERIE_RETROPOLADA_1990_2005.v2019-03`, que usa la fecha de última
   modificación del archivo y lo dice en sus notas.
1. Falla con `stop()` si `codigo_http != 200` o si `verificacion_forma` devuelve `FALSE`. El
   mensaje debe decir qué falló concretamente, para que el fallo sea diagnosticable sin releer
   el script (regla 6 de `CLAUDE.md`: se falla, no se advierte).
2. Calcula dos checksums (ver §2.3): `sha256` sobre el contenido crudo —integridad del archivo en
   disco— y `sha256_norm` sobre el contenido normalizado —identidad de vintage—. Para fuentes cuyo
   crudo ya es determinista (las API con `.json`), ambos coinciden; para el `.xlsx` del BCR
   divergen, y el que decide vintage es `sha256_norm`.
3. Compara `sha256_norm` contra el manifiesto para ese `publicacion_id`. Sin fila previa → primera
   captura. Fila previa con el **mismo** `sha256_norm` → no hay vintage nuevo: no se escribe nada,
   se reporta "sin cambios respecto de la última captura (fecha)" y se retorna. Eso importa:
   distingue "el script corrió y verificó" de "el script no hizo nada". Fila previa con
   `sha256_norm` **distinto** → vintage nuevo.
3b. Verifica que el `vintage_id` no exista ya en `08_vintages.csv`. Va después del retorno
   temprano del paso 3 —una corrida repetida sobre un archivo idéntico no debe fallar acá— y
   antes de escribir. La granularidad mensual admite colisión si una publicación sale dos veces
   en el mismo mes; no se cambia la granularidad por un caso que no se ha dado, pero un duplicado
   de clave falla, no advierte (senda §3.5).
4. Escribe el archivo. Nunca sobrescribe: si la ruta existe, `stop()`.
5. Agrega una fila al manifiesto y otra a `08_vintages.csv`. **Solo agrega filas, nunca reescribe
   una existente.**

**Lo que esta función NO hace.** No decide `fecha_publicacion` ni `periodo_referencia_max`: los
dos dependen del contenido de la fuente y no son inferibles genéricamente. Cada script por
institución se los pasa, extraídos de la respuesta. Si una fuente no declara
`periodo_referencia_max` de forma parseable, el campo queda vacío —nunca `n.d.` ni `0`, senda
§3.4— y el motivo se anota en `notas`.

**Literales que se escriben al catálogo.** Deben coincidir carácter por carácter con las filas
ya existentes, porque la igualdad literal es el mecanismo de detección de deriva del proyecto.
Hoy son dos: `"primera captura — sin vintage previo con el cual comparar"` y
`"vintage nuevo — sha256 distinto del capturado el {fecha}"`. Raya larga, no guion.

---

## 4. Qué significa "fallar de forma visible", por tipo de fuente

La regla 6 de `CLAUDE.md` es un principio; acá se vuelve criterio verificable, porque si no cada
script lo interpreta distinto.

- **BCR (captura vía `chromote`).** Falla si el archivo no aparece en la carpeta de descargas
  dentro del tiempo de espera; si el archivo obtenido no es un `.xlsx` válido —firma `PK` al
  inicio, conforme al formato fijado en §2.1— en lugar de una página HTML de error guardada con
  la extensión equivocada; o si su tamaño es drásticamente menor al de la última captura conocida
  de esa publicación. Umbral sugerido: menos del 50% del tamaño anterior — un archivo real que se
  achica un 90% es casi siempre una página de error disfrazada, no un dato legítimo que decreció.
- **FMI (SDMX 3.0 vía `httr2`).** Falla si `codigo_http != 200`, o si la respuesta parsea pero el
  conteo de series u observaciones es 0. Es un bug real ya observado: `c[TIME_PERIOD]` con
  parámetros mal puestos rompe la consulta en vez de ignorarla, y devuelve HTTP 200 con cero
  series. Un script que no chequee esto guarda "cero resultados" como si fuera una descarga
  exitosa.
- **FRED y Banco Mundial (JSON vía `httr2`).** Falla si `codigo_http != 200`, o si el campo de
  datos viene vacío o con estructura distinta de la esperada. El Banco Mundial devuelve un objeto
  de error en vez del array de dos elementos `[metadata, datos]` que es su forma normal; eso hay
  que verificarlo activamente, no asumir la forma.

---

## 5. Estado actual y qué falta

**`lib_adquisicion.R`** — implementa el contrato de la sección 3. Commiteado y verificado, pero
**no ejecutado nunca de punta a punta**, porque ningún script por institución llegó a completar
una descarga.

**`bcr.R`** — implementa el enfoque `httr2` que ADR-009 descartó el 2026-08-20. Se conserva
hasta su reescritura sobre `chromote`; **no es el mecanismo vigente**. Su reescritura está
condicionada a resolver antes el desfase de versión de `chromote` (binario CRAN 0.5.1 compilado
bajo R 4.5.3, máquina de prueba en R 4.5.1) y a usar `$go_to()` en lugar de `Page$navigate()` +
`Page$loadEventFired()`, ambas condiciones fijadas por ADR-009.

**`chromote` no está en `DESCRIPTION` ni en `renv.lock`**, por decisión explícita de ADR-009: se
incorpora recién con el primer script real que lo use.

**Pruebas F1 y F2 de §2.1, pendientes.** Determinismo del `.xlsx` de SheetJS y fidelidad
numérica de su CSV. Se corren en la misma sesión, antes de la primera captura real, y su
resultado se asienta en §2.1. F1 no es una curiosidad: si el `.xlsx` no es reproducible byte a
byte, el mecanismo de detección de vintage del paso 3 deja de funcionar para esta fuente.

**Pendientes de la librería, registrados y no urgentes** (ninguno bloquea, porque el script no
corre todavía): `write.table()` con `quote = TRUE` por defecto citaría todas las columnas de
texto al anexar, rompiendo el estilo visual de los dos CSV; y no hay guarda de salto de línea
final antes de anexar, así que si un archivo terminara sin `\n` la fila nueva se concatenaría
con la última.

**Restricción de volumen.** Regla 9 de `CLAUDE.md`, anclada en ADR-009: los mecanismos
desatendidos capturan solo lo necesario, al ritmo real de publicación de cada fuente. No aplica
solo a `chromote` — aplica a todo mecanismo desatendido. `BCR.PIB_T.SERIE_RETROPOLADA_1990_2005`
sigue excluida de captura automatizada por `robots.txt`, y esa exclusión **no se reconsidera**
aunque `chromote` pudiera técnicamente eludirla.

---

## Lo que este documento NO decide

- Qué publicación se automatiza primero. Eso lo define Harold.
- Cómo se estructura la captura prospectiva continua (cron, GitHub Actions programado, o manual
  periódico). Es una decisión de operación, no de estructura de script, y puede esperar a que
  exista al menos un script funcionando.
- Nada que requiera un ADR. Si algo de la implementación termina exigiendo una decisión
  metodológica no cubierta por un ADR existente, eso se detiene y se pregunta (regla 4 de
  `CLAUDE.md`), no se resuelve acá. La prueba F1 es el caso previsible: si falla, el asunto sube
  a ADR-007.
