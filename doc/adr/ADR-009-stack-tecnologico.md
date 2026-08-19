# ADR-009: Stack tecnológico

**Estado:** Cerrado
**Fecha:** 2026-08-06
**Relacionado con:** ADR-005 (herramientas de validación)

## Contexto

Decisión no contemplada explícitamente como tal en el prompt original ni enumerada entre D1–D8 de la senda metodológica, pero necesaria por construcción: el documento menciona herramientas de R y Python de forma alternativa (`renv` para R, `uv`/`pixi` para Python; `pandera` en Python o `pointblank`/`validate` en R) sin fijar un único lenguaje. Para un equipo de un investigador más un agente de código, un solo lenguaje reduce la fricción de coordinación de forma sustancial.

## Alternativas consideradas

- **Python** (`uv` + `pandera` + DuckDB + `statsmodels`/`sktime`): cubre mejor el espectro completo desde pipeline de datos hasta aprendizaje automático.
- **R**: más fuerte en econometría pura (BVAR con priors jerárquicos, ajuste estacional vía `seasonal`, desagregación temporal vía `tempdisagg`), y es el lenguaje que el investigador ya domina.

## Decisión

**R**, como stack único y cerrado. La razón decisiva no es técnica sino de restricción real del equipo: el costo de cambiar de lenguaje es incompatible con el tiempo disponible del único desarrollador del proyecto. No es una limitación del proyecto — es la restricción que resuelve la decisión sin ambigüedad.

**Componentes:**

| Función | Paquete |
|---|---|
| Entorno reproducible | `renv` |
| Validación de esquema | `pointblank` |
| Almacén consolidado | `duckdb` |
| Ajuste estacional (X-13ARIMA-SEATS) | `seasonal` |
| Empalme / desagregación temporal | `tempdisagg` |
| ARIMA / ETS | `fable` + `tsibble` |
| VAR / VECM | `vars`, `tsDyn` |
| BVAR con priors jerárquicos | `BVAR` / `bvartools` |
| MIDAS / ecuaciones puente | `midasr` |
| Regularización lineal | `glmnet` |
| Árboles — bagging | `ranger` |
| Árboles — boosting | `lightgbm` |
| Documentación / sitio | Quarto (agnóstico de lenguaje) |
| Integración continua | GitHub Actions + `r-lib/actions` |

## Consecuencias

- Se descarta la posibilidad de aprovechar sin fricción ciertas librerías de última generación sin *binding* en R (p. ej. algunas implementaciones recientes de modelos factoriales dinámicos). Se acepta ese costo a cambio de velocidad de desarrollo real dado el equipo disponible.
- Todo código generado por Claude Code en este proyecto debe producirse en R salvo excepción explícitamente registrada en un ADR posterior.

## Nota de seguimiento — clientes de API externa (2026-08-12)

El inventario de Fase 1 incorporó tres fuentes que se consumen por API (FMI, FRED y Banco Mundial, ver `00_instituciones.csv`). Existen para las tres clientes de R publicados en CRAN, y ninguno figura en la tabla de componentes de este ADR.

**No se enmienda el stack todavía, y la omisión es deliberada.** La elección entre usar un cliente de terceros o escribir un cliente propio sobre una biblioteca HTTP genérica no puede fundamentarse hoy: depende de qué tan bien se ajuste cada paquete a los requisitos concretos de la capa L0 —control del *checksum*, fallo visible ante cambio de estructura de la fuente conforme a la regla 6 de `CLAUDE.md`, y trazabilidad de la URL exacta consultada— y eso solo se sabe al escribir el primer *script* de adquisición. Fijar la dependencia ahora sería tomar la decisión con menos información de la que se tendrá en el momento en que haga falta, sin ganar nada a cambio: no hay código de Fase 2 escrito ni bloqueado por esta indefinición.

**Disparador.** Antes de escribir el primer *script* de `src/adquisicion/` que consuma una API externa, debe decidirse y registrarse acá si se enmienda este ADR para incorporar uno o más clientes, o si se escribe cliente propio. La decisión se toma una sola vez y cubre las tres fuentes; no se resuelve caso por caso.

**Restricción que no cambia:** cualquiera sea la vía elegida, el stack sigue siendo R (regla 5 de `CLAUDE.md`). Este seguimiento es sobre qué paquetes de R, no sobre el lenguaje.

**Disparador RESUELTO (2026-08-18) — cliente híbrido.**

**Decisión de Harold:** híbrido. El fetch crudo de L0 para las tres fuentes (FMI, FRED, Banco
Mundial) se escribe con un cliente propio sobre `httr2` — la respuesta cruda de cada API
(JSON o SDMX-JSON, según corresponda) se guarda tal cual, con el mismo tratamiento que ya
reciben los archivos `.xlsx` del BCR: SHA-256, comparación contra el manifiesto, nunca
sobrescribir. Los paquetes de terceros (`imfapi`, `wbwdi`, `fred` — ver investigación abajo)
quedan reservados para Fase 3 (L0 → L1), donde parsean los archivos ya capturados en vez de
volver a consultar la red.

**Motivo.** Los tres paquetes candidatos devuelven datos ya tidificados (`tibble`), no la
respuesta cruda de la API. Checksumear esa salida en vez de la respuesta real de la fuente
viola el principio de inmutabilidad de L0 (senda §3.1): el hash dejaría de depender solo de lo
que la fuente publicó y empezaría a depender también de la versión del paquete y de cómo
decide tidificar el dato — un cambio de versión del paquete podría alterar el checksum de L0
sin que la fuente haya cambiado nada. El cliente propio sobre `httr2` mantiene a L0 consistente
con el patrón ya establecido para BCR: el archivo es el archivo, no una interpretación de él.

**Investigación previa a la decisión (Claude, 2026-08-18), verificada contra CRAN, no asumida
de memoria:**
- FMI: `imfapi` (CRAN, familia econdataverse, publicado 2025-11-19) es el cliente vigente para
  SDMX 3.0 — reemplaza a `imfp`/`imfr`, que dejaron de funcionar cuando el FMI migró desde
  SDMX 2.1.
- Banco Mundial: `WDI` (Arel-Bundock) sigue activo, pero cachea por defecto y no usa `httr2`.
  `wbwdi` (misma familia econdataverse que `imfapi`, mismo mantenedor —Christoph Scheuch—) evita
  caché por defecto explícitamente por los problemas que genera, y sí usa `httr2`.
- FRED: `fredr` (Boysel/Vaughan), el paquete que se asumía por defecto en discusiones previas
  del proyecto, **no tiene actualizaciones desde agosto de 2021**. El reemplazo activo es
  `fred` (Coverdale — paquete distinto pese al nombre parecido, publicado 2026-04-11), que
  además soporta vintages nativamente (`fred_all_vintages`, `fred_as_of`) — relevante para D7
  cuando corresponda, aunque en Fase 2 el vintage se sigue capturando vía el manifiesto propio,
  no vía este paquete.

**Pendiente de verificación práctica, no bloqueante para Fase 2:** no se confirmó todavía si
`imfapi`, `wbwdi` y `fred` pueden operar sobre un archivo ya descargado (parseo puro) o si
solo ofrecen fetch-y-parseo en un mismo paso — de ser lo segundo, su uso en Fase 3 requeriría
extraer la lógica de parseo o llamarlos igual y aceptar una segunda consulta de red no
determinante para L0. Se resuelve al llegar a Fase 3, no antes.

## Nota de seguimiento — lector de hojas de cálculo (2026-08-15)

El verificador de `fuente_celda` (`src/validacion/verificar_fuente_celda.R`, ver también
`doc/adr/ADR-005-soporte-catalogos.md`) necesita abrir los archivos `.xlsx` de `data/L0_raw/`
para confirmar que el rótulo declarado en cada fila de `catalogos/03_series.csv` sigue
coincidiendo con la celda real. Ninguno de los trece paquetes originales de este ADR lee
`.xlsx`. A diferencia de la nota de seguimiento anterior, este disparador llegó desde
validación, no desde adquisición.

**Decisión: `xml2` ahora, `readxl` diferido a Fase 3.**

- `xml2` se incorpora como import #14 (`DESCRIPTION` actualizado). Ya estaba presente en
  `renv.lock` como dependencia transitiva de otros trece paquetes, así que no amplía la
  superficie real de instalación. Un `.xlsx` es un `.zip` con XML interno; `unzip()` de R
  base descomprime, `xml2` parsea `xl/worksheets/sheetN.xml` y `xl/sharedStrings.xml`.
  Es la vía correcta para el verificador específicamente porque opera sobre números de fila
  y rótulos crudos — leer con una librería que interpreta la hoja (reordena, tipa, salta
  filas) sería contradictorio con lo que el verificador existe para comprobar.
- `readxl` no se incorpora todavía. Cuando Fase 3 necesite leer los valores numéricos de
  las series (no solo confirmar un rótulo), `xml2` deja de alcanzar razonablemente y ahí
  corresponde una enmienda formal de este ADR incorporando `readxl` como import #15.

**Disparador.** Antes de escribir el primer script de `src/transformacion/` que lea valores
(no rótulos) de un `.xlsx`, debe enmendarse este ADR para incorporar `readxl`.

**Restricción que no cambia:** el stack sigue siendo R (regla 5 de `CLAUDE.md`). Esta nota
es sobre qué paquete lee archivos de hoja de cálculo, no sobre el lenguaje.

**Registro de corridas.** El verificador no puede correr en integración continua: los `.xlsx`
de `data/L0_raw/` están en `.gitignore` por ADR-008, de modo que en el runner todas las filas
salen `NO_VERIFICABLE`. La consecuencia es que su única evidencia es el registro manual en
`doc/bitacora_verificaciones.md`, que por eso no es documentación opcional sino la contraparte
del verde de CI para esta comprobación en particular.
