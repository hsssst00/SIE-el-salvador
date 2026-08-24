# Hallazgo técnico: captura headless del portal `vista-serie` del BCR

**Fecha:** 2026-08-24. **Origen:** investigación en vivo sobre la página del portal
(`estadisticas.bcr.gob.sv`), verificada por coherencia interna y, en la sesión que
produjo este documento, re-confirmada mediante corrida real de `chromote` contra la
página en vivo (Claude Code, misma fecha). Este documento es la referencia que cita
`doc/bitacora_fuentes_fragiles.md` en su entrada del 2026-08-24 — ver ahí el resumen y
la aplicación a la captura automatizada.

## Contexto

El mecanismo de captura del BCR (ADR-009, nota de seguimiento "mecanismo de captura
para el BCR", 2026-08-20) ya estaba fijado como automatización CDP desatendida vía
`chromote`, headless, reproduciendo la interacción real de la interfaz — no golpeando
un endpoint de exportación (no existe: el `.xlsx` se genera enteramente del lado del
cliente vía SheetJS). Lo que quedaba abierto era de ejecución: **cómo obtener las 29
variables de la publicación en una sola descarga**, combinando el rango histórico
completo con la desagregación por enfoque de producción/gasto, sin depender de una
sesión interactiva de navegador real.

## Hallazgos

### 1. El exportador lee del DOM, no de una variable JS

`html_table_to_excel(type)` es una función global definida por la página. Su cuerpo
(confirmado leyendo el código fuente en vivo) lee **directamente del DOM**:
`document.getElementById("tablaVariables")` y `document.getElementById("tablaValores")`,
las convierte a hojas de cálculo con `XLSX.utils.table_to_sheet`, las concatena
columna por fila, y llama `XLSX.writeFile(workbook, titulo + '.' + type)`. No hay
generación server-side ni variable JS intermedia que capturar — el archivo depende
enteramente de qué esté renderizado en esas dos tablas en el momento del clic.

El argumento `type` es literalmente la extensión de archivo que usa `XLSX.writeFile`
para inferir el formato de salida. Verificado en vivo: el valor correcto para producir
un `.xlsx` real es `"xlsx"` — no `"excel"` ni ningún otro literal.

### 2. Las tablas solo alcanzan su tamaño completo en modo tabular

Ambas tablas (`#tablaVariables`, `#tablaValores`) solo contienen las 29 variables con
datos cuando el componente Livewire está en **modo tabular** (`data.tabular === true`,
alcanzado disparando el método `cambiarTipo`) **y** se ejecutó el método `filtrar` con
el rango completo ya fijado. En modo gráfico, `filtrar` solo renderiza la variable
graficada (una fila, ~200 celdas) — esto explica capturas headless truncadas de
intentos previos que no forzaban el modo tabular antes de filtrar.

**Consecuencia de diseño:** basta poner el componente en modo tabular antes de
`filtrar` para que "Formato Excel" exporte las 29 variables en una sola descarga. No
hace falta tildar los checkboxes de enfoque (`vars`/`variable[]`, `wire:model.defer`)
que la exploración del 2026-08-19 usaba para forzar la desagregación — el modo tabular
ya la incluye.

### 3. API de control de Livewire v2

`window.livewire.find(id)` devuelve un **Proxy** en el que cualquier acceso a
propiedad se resuelve como función invocable — un falso positivo garantizado si se usa
para introspección (`typeof cmp.algo === "function"` siempre es cierto). La referencia
correcta al componente es `window.livewire.components.componentsById[id]`.

`component.set(nombre, valor, true)` con el tercer argumento `true` marca el cambio
como **diferido**: los valores no se envían de inmediato, sino que viajan junto con la
siguiente petición Livewire disparada por `component.call(metodo)`. Esto permite fijar
los cinco parámetros del filtro (`formula`, `yInicio`, `nInicio`, `yFin`, `nFin`) en
cualquier orden antes de disparar `filtrar`, sin depender del orden estricto en que un
usuario interactuaría con los `<select>` del formulario.

### 4. Espera por predicado, no por tiempo fijo

`filtrar` en modo tabular tomó entre ~2 y ~30 segundos en distintas corridas — no hay
una duración fija confiable. La espera correcta combina:

- un contador de eventos `message.processed` (hook de Livewire) para saber que al
  menos una respuesta nueva llegó;
- `component.messageInTransit === null` para confirmar que no hay una petición Livewire
  todavía en curso;
- el propio DOM: `#tablaValores` con el número de columnas esperado (periodos) y al
  menos una fila con ese mismo número de celdas.

`Sys.sleep()` de duración fija no es un sustituto válido — ni por exceso (desperdicia
tiempo en la mayoría de corridas) ni por defecto (falla en las corridas lentas).

### 5. El rango completo requiere `fetch()` desde la propia página

`GET /api/rangos/{idPublic}` da 403 a clientes externos (`curl`, `httr2` sin sesión de
navegador) pero responde con éxito cuando se invoca vía `fetch()` ejecutado en el
contexto de la página ya cargada (hereda las cookies de sesión). La forma confirmada de
la respuesta es un arreglo de objetos `{year, periodos: {simbolo: [...], numeroPeriodo}}`,
uno por año disponible; el primer año y su primer símbolo (`"I"`) marcan el piso del
rango, y el último año con su último símbolo marcan el techo.

### 6. El portal no expone una fecha de publicación parseable

Se buscó en `component.data` (todas sus llaves) y en los campos visibles del DOM
(`mensaje_datos_actualizados`, `periodo_datos_actualizados`, `notas`). El único dato
temporal expuesto de forma fiable es el **período de referencia** más reciente
(ej. `"I 2026"`, es decir 2026-T1) — no una fecha de publicación. El campo
`mensaje_datos_actualizados` que en teoría acompañaría un texto como "Datos
actualizados hasta:" aparece vacío en el estado observado. Esto confirma la práctica ya
en uso en el manifiesto: `fecha_publicacion` se aproxima al mes de publicación conocido
por quien opera la captura, día 01 por convención, y se anota como tal en `notas`
(`08_vintages.csv`) — no se infiere del portal.

### 7. Reconciliación pendiente (Fase 3, no bloquea la captura)

El portal sirve **29 variables con datos** para la serie de índices NSA — 31 filas de
`#tablaValores`, menos 2 filas de encabezado de sección vacías ("Enfoque de la
producción" / "Enfoque del gasto"). `03_series.csv` tiene 28 filas para NSA y 28 para
SA, pero 29 para NOMINAL. Las publicaciones de volumen quedan una fila corta respecto
de lo que el portal sirve y de lo que NOMINAL ya tiene. Candidata plausible del
faltante: variación de existencias / FBK — el catálogo del portal incluye una nota
explícita señalando que los índices de volumen encadenados **no se publican** para la
Variación de Existencias por la volatilidad de esa partida como cierre del PIB por el
enfoque del gasto (solo se publica para la FBKF). Esto es consistente con que el
faltante sea justamente esa fila, pero queda por cuadrar formalmente contra
`03_series.csv` antes del mapeo de `fuente_celda` — no se resuelve en este documento.

## Aplicación a la captura automatizada

Estos siete hallazgos, en conjunto, determinan el diseño de
`src/adquisicion/bcr_captura.R`: navegar con `$go_to` (no `Page$navigate` +
`Page$loadEventFired`, carrera ya documentada en ADR-009), montar el componente,
obtener el rango completo vía `fetch()` interno, fijar filtro diferido + modo tabular,
disparar `filtrar` y esperar por predicado, usar el extractor DOM solo como
metadatos/cross-check (no como artefacto), y finalmente disparar
`html_table_to_excel("xlsx")` con `Browser$setDownloadBehavior` ya armado para
interceptar la descarga real. Ver `src/adquisicion/bcr.R` para las funciones por
publicación (NSA, SA) que usan este motor.

Corrida de cierre (2026-08-24, misma sesión): `descargar_bcr_pib_nsa("2026-06-01")` y
`descargar_bcr_pib_sa("2026-06-01")` reprodujeron, vía este mecanismo, un `sha256_norm`
idéntico al de los vintages capturados manualmente el 2026-08-06 para ambas
publicaciones — la automatización reproduce el dato publicado hasta la identidad de
vintage (ver F1, `src/adquisicion/README.md` §2.3).
