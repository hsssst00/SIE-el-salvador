# Calendario de divulgación del BCR — procedencia y uso

**Qué es.** El BCR publica un calendario de fechas anunciadas de publicación para un
subconjunto de "variables clave" (`estadisticas.bcr.gob.sv/calendario-de-divulgacion`),
descargable en `.xlsx` desde el propio portal. Cubre solo lo que resta del año en curso
(a la fecha de esta descarga: agosto-noviembre 2026), no un histórico.

**Por qué vive acá y no en L0.** Decisión de Claude chat, 2026-08-25 (delegada por
Harold). No es una publicación de datos — nunca va a tener `serie_id` ni pasar por
L1-L4 — es metadata operativa que informa cuándo intentar una captura. `01_publicaciones`
está diseñado para productos estadísticos con periodicidad/cobertura propias, que este
objeto no tiene. Vive junto a `doc/bitacora_fuentes_fragiles.md` y
`doc/bitacora_verificaciones.md`: mismo tipo de artefacto, conocimiento sobre el proceso
de adquisición, no insumo de modelación. El CSV versionado en Git funciona como registro
de revisiones del calendario en el tiempo (diff entre descargas), sin el aparato de
manifiesto/checksum de L0.

**Procedencia de esta captura.**

| Campo | Valor |
|---|---|
| Fuente | `https://estadisticas.bcr.gob.sv/calendario-de-divulgacion` |
| Mecanismo | Descarga manual por Harold vía botón "Exportar" del portal |
| Archivo original | `calendario-anticipado.xlsx` |
| Fecha de descarga | 2026-08-25 (confirmada por Harold) |
| Cobertura del calendario | Agosto-Noviembre 2026 (4 meses; "lo que resta del año", declarado por el propio archivo) |
| Extractor | `src/adquisicion/calendario_bcr_extraer.R` (parsea a `calendario_divulgacion_bcr.csv`, formato largo) |

**Semántica de las columnas del CSV.**

- `seccion`: agrupación del propio calendario (Sector Real, Sector Fiscal, Sector
  Monetario y Financiero, Sector Externo, Población).
- `variable`: nombre de la variable tal como el BCR la declara — no normalizado contra
  `publicacion_id` (ver más abajo).
- `mes_publicacion`: mes en que el BCR anuncia que va a publicar (columna del xlsx
  original).
- `dia_publicacion`: día dentro de ese mes.
- `tipo_referencia` / `periodo_referencia`: el período que el dato publicado va a
  cubrir (mensual `AAAA-MM` o trimestral `AAAA-Tn`) — **no** es la fecha de publicación,
  es lo que el paréntesis del xlsx original indica.

**Advertencia central — no confundir con `fecha_publicacion`.** Este calendario da la
fecha **anunciada**, no la fecha **real** de publicación. El campo `fecha_publicacion`
de `registrar_descarga()` (`lib_adquisicion.R`) exige la fecha que la fuente declara en
el momento real de la captura — este calendario no la sustituye. Su uso legítimo es
decidir *cuándo intentar* una captura (candidato para resolver, aunque sea
parcialmente, la decisión abierta de Fase 2 sobre el mecanismo de captura prospectiva),
nunca para prellenar el campo de fecha en el manifiesto o en `08_vintages.csv`.

**Cruce contra `01_publicaciones` (2026-08-25).** De las 22 variables nombradas en el
calendario, 15 tienen entrada existente en el catálogo (incluida `IPC`, que corresponde
a `ONEC.IPC.BASE_2009`, no a una publicación del propio BCR). **7 no tienen entrada**:

- Ingresos mensuales de remesas familiares — sin entrada; predictor nombrado
  explícitamente en la senda §6.4, hoy no inventariado.
- Deuda del Gobierno Central Trimestral — sin entrada exacta (el catálogo tiene
  `DEUDA_PUBLICA_TOTAL_*`, mensual, "Total" no "Gobierno Central" — no asumir que es
  la misma publicación).
- Índices de Precios del Comercio Exterior - Trimestral — sin entrada (el catálogo
  solo cubre la variante mensual del mismo nombre).
- Saldo Bruto de la Deuda Externa Total — sin entrada.
- Posición de Inversión Internacional — sin entrada.
- IED: Flujo neto — sin entrada.
- Reservas Internacionales y Liquidez en Moneda Extranjera — sin entrada (distinta de
  `RESERVAS_INTERNACIONALES_NETAS`, que sí está).

Estos 7 quedan como pendiente de inventario (Fase 1 / adelanto declarado), no resueltos
por esta nota.
