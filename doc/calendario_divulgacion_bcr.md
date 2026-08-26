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
parcialmente, la decisión abierta de Fase 2 sobre el mecanismo de captura prospectiva).

**Excepción explícita, confirmada por Harold (2026-08-25).** La regla anterior prohíbe
tomar la fecha *anunciada* de un evento específico como si fuera la fecha *real* de
publicación — eso sigue vigente. No prohíbe usar el **patrón de rezago** que el
calendario revela (cuántos meses pasan entre el período de referencia y su publicación,
comparando varias columnas) para *aproximar* una fecha cuando la fuente no declara
ninguna y el patrón es estable. Primer uso: `BCR.IVAE.VIGENTE.v2026-07`
(`catalogos/08_vintages.csv`) — la página solo exponía la cobertura y la *próxima*
fecha de publicación, ninguna de las dos la fecha real de este vintage; se aproximó por
el rezago de 2 meses que el calendario muestra de forma consistente para esta variable,
y Harold confirmó el patrón contra el histórico antes de aceptarlo. Cada uso de esta
excepción debe declarar en `notas_vintage` el cálculo completo y estar avalado
explícitamente, no aplicarse por defecto.

**Cruce contra `01_publicaciones` (2026-08-25, actualizado 2026-08-26).** De las 22
variables nombradas en el calendario, 20 tienen entrada existente en el catálogo
(incluida `IPC`, que corresponde a `ONEC.IPC.BASE_2009`, no a una publicación del
propio BCR). **2 no tienen entrada todavía**:

- IED: Flujo neto — ambigüedad entre dos publicaciones candidatas (por sector
  económico receptor y por país de procedencia), ninguna de las dos un agregado sin
  desagregar; pendiente de decisión de Harold (ver handoff Fase 1, Bloque 3).
- Reservas Internacionales y Liquidez en Moneda Extranjera — sondeada en vivo
  (2026-08-26): no es una publicación `vista-serie` sino una fila dentro de la
  Cartelera Electrónica FMI (`cartelera_es.html`), con descarga de Excel a nivel de
  toda la cartelera, no de la fila individual, y con valores puntuales (último dato +
  dato del período anterior), no una serie histórica completa. Documentado en
  `doc/bitacora_fuentes_fragiles.md`; no se cataloga todavía como publicación de
  `01_publicaciones` hasta definir un mecanismo de captura para este tipo de fuente.

Las 5 variables restantes del cruce original (remesas familiares mensuales, deuda del
Gobierno Central trimestral, índices de precios del comercio exterior trimestral,
saldo bruto de la deuda externa total y posición de inversión internacional) ya
cuentan con entrada en `01_publicaciones`, con `cobertura_temporal` confirmada por
sondeo en vivo (`src/adquisicion/bcr_sondear_publicacion.R`, 2026-08-26).