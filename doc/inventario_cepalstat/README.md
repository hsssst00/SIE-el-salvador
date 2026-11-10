# Inventario de indicadores de CEPALSTAT

**Qué es.** La lista de indicadores de CEPALSTAT, en los temas macroeconómicos del SIE, con su cobertura para
El Salvador. Es un inventario: dice qué hay en la fuente, no admite ninguna serie.

**Por qué vive acá y no en `catalogos/`.** Decisión de Harold, 2026-11-10. ADR-008 (enmienda del 2026-10-19)
fija como condición de admisión que ninguna serie de CEPAL entre a `catalogos/03_series.csv` sin resolver antes
si transformarla y publicar el resultado choca con la cláusula 4 de los términos de CEPAL (obras derivadas). Esta
lista no toca esa condición: no hay series de CEPAL en `03_series`, `04_transformaciones`, `05_series_master` ni
`08_vintages`, ni archivos de CEPAL en `data/L0_raw/`. Promover un indicador de esta lista al catálogo sigue
exigiendo resolver primero la condición de ADR-008.

**Cómo se generó.** `scripts/inventario_cepalstat.R`, una sola pasada (regla 9 de `CLAUDE.md`) con 2 s entre
llamadas:

1. Pide el árbol temático (`/thematic-tree`) y se queda con las hojas de dos ramas: **Económicos** completa (PIB y
   cuentas nacionales, comercio internacional y balanza de pagos, precios, sector público, sector financiero y
   monetario, estadísticas sectoriales) y **Estadísticas de los Subsectores Eléctrico y de Hidrocarburos de
   Centroamérica y la República Dominicana**. Quedan fuera los temas demográficos, sociales, ambientales y el
   resto de los transversales (ODS, género, ciudades, etc.).
2. Por cada indicador pide `/indicator/{id}/data` filtrado a El Salvador y resume la respuesta.

Las respuestas crudas **no se guardan**: ni en L0 ni en otro lugar. Es el default conservador de ADR-008 para CEPAL
(se publica el script y un checksum, no el archivo). El checksum es el sha256 del `body` de la respuesta, porque
el `header` trae marca de tiempo y máquina y cambia en cada llamada.

## Hallazgos de la API que condicionan la lectura

- **La dimensión de país cambia entre indicadores.** En la estándar (id 208), El Salvador es el miembro 230. Otras
  dimensiones, como la de cuentas nacionales trimestrales, tienen un miembro por año base ("El Salvador [año base
  1990]", "[año base 2005]", "[año base 2014]"). El script prueba primero con 230 y, si no hay filas, busca los
  miembros "El Salvador…" en la dimensión de país de la propia respuesta.
- **Un resultado vacío es real, no un error del filtro.** Comprobado con el indicador 286 (PIB trimestral por
  tipo de gasto, a precios constantes): filtrado por "Costa Rica [año base 1991]" devuelve 719 filas, y filtrado
  por los tres miembros de El Salvador, 0. CEPALSTAT no publica PIB trimestral de El Salvador.
- **La API corta en 10 000 filas sin avisar.** Se nota en las consultas sin filtro de país. Si una respuesta
  filtrada llega a ese tope, `respuesta_truncada` sale `TRUE`.
- **Período mixto.** Algunos indicadores (p. ej. los agregados monetarios) traen en una misma dimensión
  «Periodo» filas anuales, trimestrales y mensuales.
- **Fuente original.** Cada fila de datos cita su fuente (`source_id`). Muchas series de El Salvador en CEPALSTAT
  son del BCR o del FMI, es decir, de fuentes que el SIE ya consulta directamente. `fuentes_originales` lo
  registra.

## Diccionario de `indicadores.csv`

Una fila por indicador. Ausentes como celda vacía.

| Campo | Descripción |
|---|---|
| `indicator_id` | Id del indicador en CEPALSTAT. |
| `ruta_tematica` | Ruta en el árbol temático. Si el indicador cuelga de varias ramas, van separadas por ` \| `. |
| `nombre_indicador` | `metadata$indicator_name` de la respuesta. |
| `area` | `metadata$area` (p. ej. «Mensual», «Sector externo», «Cuentas nacionales trimestrales»). |
| `unidad` | `metadata$unit`. |
| `tiene_datos_slv` | `TRUE` si la consulta filtrada a El Salvador devolvió alguna fila. |
| `freq` | Frecuencias presentes, de mayor a menor (`M`, `Q`, `A`), separadas por `; `. |
| `inicio`, `fin` | Primer y último período con dato, en ISO 8601 (`1980`, `1990-Q1`, `1980-01`), **de la frecuencia más alta presente** (la primera de `freq`). |
| `n_obs` | Filas de datos para El Salvador, todas las dimensiones y frecuencias juntas. |
| `respuesta_truncada` | `TRUE` si `n_obs` llegó al tope de 10 000 filas de la API. |
| `n_series` | Combinaciones distintas de dimensiones no temporales (país incluido) y frecuencia. Un indicador «PIB por tipo de gasto» con 9 rubros y 1 frecuencia da 9. |
| `miembros_slv` | Miembros de la dimensión de país que trajeron datos (p. ej. variantes por año base). |
| `dimensiones_adicionales` | Dimensiones que no son país ni tiempo, con el número de miembros con dato entre paréntesis. |
| `fuentes_originales` | Organismo y publicación de origen de las filas de El Salvador, `SIGLA: descripción`, separados por ` \| `. |
| `ultima_actualizacion` | `metadata$last_update`, tal como lo da la API (formato `Mmm DD AAAA HH:MMxM`). |
| `advertencia` | Algo que el script no supo resolver solo (etiquetas de período o dimensiones temporales no reconocidas, respuesta truncada). Hay que revisarlo a mano. |
| `url_consulta` | URL exacta de la última llamada para ese indicador (la filtrada que valió). |
| `codigo_http` | Código HTTP de esa llamada. |
| `sha256_body` | sha256 del `body` JSON de la respuesta, re-serializado con `jsonlite::toJSON(auto_unbox = TRUE, digits = NA)`. |
| `fecha_consulta` | Inicio de la corrida, con zona horaria. |

## Corrida

**2026-11-10.** La pasada completa empezó a las 14:52 (UTC−6): árbol temático con sha256 del `body`
`fb833e55…3353860`, 334 hojas en los temas incluidos, 322 indicadores distintos, todos con HTTP 200. Después se
volvieron a consultar con `ids=` 13 indicadores (15:24; el 1901, otra vez a las 15:25), por dos defectos del script que la primera pasada
destapó y que ya están corregidos:

- **El mes se leía del `order` del miembro.** Ese orden no es 1–12 en todos los indicadores: en el 1901 (TCRE)
  salía `2013-00 … 2025-90`. Ahora se lee del nombre. Se volvieron a consultar los 9 indicadores con dimensión
  «Meses».
- **Faltaban dos casos de período.** «Promedio anual» dentro de «Meses» (en el 1901) ahora cuenta como fila
  anual. «Año_decadas» (promedios por década, 3376–3379) se deja con advertencia y sin `freq`.

### Resultado

160 de 322 indicadores tienen datos para El Salvador. Ninguna respuesta llegó al tope de 10 000 filas.

| Rama (primer nivel bajo «Económicos») | Indicadores | Con datos SLV |
|---|---|---|
| PIB y Cuentas Nacionales | 121 | 37 |
| Comercio Internacional y Balanza de Pagos | 91 | 42 |
| Estadísticas sectoriales y productividad | 37 | 19 |
| Precios | 17 | 14 |
| Sector público | 13 | 10 |
| Sector financiero y monetario | 11 | 7 |
| Subsectores Eléctrico y de Hidrocarburos (CA y RD) | 32 | 31 |

Un indicador que cuelga de varias ramas se cuenta en la primera de `ruta_tematica`.

**Frecuencia de los 160:** 139 anuales, 8 mensuales, 1 mensual con promedio anual, 7 con filas mensuales,
trimestrales y anuales (tasas de interés, agregados monetarios, tasa de política monetaria), 1 trimestral y 4
decenales (con advertencia).

**Lo sub-anual es casi todo del BCR.** El IPC y sus componentes, el índice de precios al por mayor, las tasas de
interés, los agregados monetarios y la balanza de pagos trimestral (547: 55 rubros, 1999-T1 a 2026-T2) citan al BCR
como fuente original. El SIE ya toma del BCR directamente lo que usa de eso. Las excepciones son el tipo de
cambio real efectivo (1901) y el nominal (2179), que son elaboración de CEPAL. **CEPALSTAT no publica PIB trimestral
de El Salvador**: los cuatro indicadores de «Trimestrales» vuelven vacíos.

**Fuente original de los 160** (un indicador puede citar más de una): CEPAL, elaboración propia sobre información
oficial, 76; BCR 36; MINEC 22; DGEHM 17; FMI 8; SIGET 8; Banco Mundial 7; CEL 5; OMT 3; EOR, FAO, ONU y UNSD 1
cada uno; sin fuente citada 6.

**Vigencia:** 89 de los 160 tienen dato en 2025 o después.
