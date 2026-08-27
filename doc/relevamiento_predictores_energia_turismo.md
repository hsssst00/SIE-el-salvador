# Relevamiento: energía y turismo como predictores

**Fecha:** 2026-08-26, actualizado el mismo día tras hallazgo posterior. **Verificado
por:** Harold, directamente (relevamiento propio de fuentes).

## Contexto

La senda metodológica (§6.4) nombra "energía" y "turismo" entre los predictores
mensuales que el proyecto debería aprovechar, junto con IVAE, remesas, comercio
exterior, precios, empleo cotizante y recaudación — estos últimos siete ya están
cubiertos en el catálogo (`catalogos/01_publicaciones/`). Un cruce contra el calendario
de divulgación del BCR y una búsqueda inicial (Claude chat, 2026-08-26) identificó
candidatas institucionales para energía (SIGET, CNE, DGEHM) y turismo (CORSATUR,
Ministerio de Turismo) — ninguna de las diez instituciones ya inventariadas en
`00_instituciones.csv` cubría estas dos categorías.

## Turismo — excluido

Harold revisó directamente las fuentes candidatas de turismo. Resultado: solo el
**Ministerio de Turismo** ofrece algo, y es una **entrega anual**, con el último dato
disponible en **2024**. No hay serie mensual ni trimestral accesible.

**Turismo queda excluido del conjunto de predictores del proyecto.** Frecuencia anual
con casi dos años de rezago es incompatible con el horizonte de evaluación del proyecto
(h = 1, 2, 4, 8 trimestres; predictores mensuales pensados para *nowcasting*, senda
§6.4). No se cataloga como publicación en `01_publicaciones`.

## Energía — resuelto, no excluido (corrección tras hallazgo posterior)

El relevamiento inicial (SIGET, CNE, DGEHM) tampoco encontró ninguna base de datos
utilizable. **Pero Harold identificó una candidata que ese relevamiento no había
cubierto: la Unidad de Transacciones (UT), administrador del Mercado Mayorista de
Electricidad.** Verificado directamente por Harold contra el portal (2026-08-26): un
menú de "Reportes Estadísticos" con una serie **"Demanda Total (GWh)", mensual, con
cobertura desde 1998**, exportable a html/pdf/xls/csv.

**Energía sí entra al conjunto de predictores — capturado y registrado (estado final,
2026-08-27).** Ver `catalogos/01_publicaciones/UT.DEMANDA_TOTAL_MENSUAL.yaml`, la fila
`UT` en `catalogos/00_instituciones.csv`, los 25 vintages en `catalogos/08_vintages.csv`
(2002-2026), la serie larga validada en `data/L1_staging/UT_DEMANDA_TOTAL_MENSUAL.csv`
(vía `src/transformacion/ut_demanda_serie.R`, 295 filas), y la entrada
`UT.DEMANDA_ELEC.GWH.NSA.M` en `catalogos/03_series.csv`. Mecanismo de captura:
**manual**, no automatizable — el dominio `ut.com.sv` bloquea acceso automatizado por
`robots.txt`, confirmado dos veces (`web_fetch` de Claude chat con
`ROBOTS_DISALLOWED`, y formalmente con `polite::scrape()` — ver
`src/adquisicion/verificar_robots_ut.R`, sin recurrir a `chromote` pese a que
técnicamente podría evadir el bloqueo), lo que activa la Regla 9 de `CLAUDE.md` —
mismo tratamiento que `BCR.PIB_T.SERIE_RETROPOLADA_1990_2005`. El formulario trae **un
año por consulta**; Harold descargó los 25 disponibles a mano.

**1998-2001, decisión cerrada (Harold, 2026-08-27):** el dato subyacente existe (visible
en la vista embebida del portal), pero ningún formato de archivo (CSV, PDF, XLS) lo
exporta para esos 4 años. No se transcriben manualmente — quedan fuera de la serie por
ahora, documentados en el YAML de la publicación, revisable solo si UT corrige su
mecanismo de exportación para años antiguos.

## Consecuencia sobre la senda

El riesgo anticipado en la tabla de riesgos de la senda (§8) — *"Predictores mensuales
con cobertura insuficiente"* — se materializó parcialmente, no en su totalidad: de las
dos categorías con relevamiento inicial negativo, una (turismo) queda confirmada como
no disponible a la frecuencia requerida; la otra (energía) resultó sí estar disponible,
solo que en una institución que el relevamiento inicial no había cubierto. El conjunto
de predictores mensuales del proyecto queda en IVAE, remesas, comercio exterior,
precios, empleo cotizante y **energía (UT, capturado 2002-2026)** — seis de las
siete categorías nombradas en senda §6.4, con turismo como la única excluida.

## Si la disponibilidad cambia en el futuro

Si el Ministerio de Turismo (o CORSATUR) publica en el futuro una serie mensual o
trimestral accesible, esta nota queda como el registro de por qué turismo no se incluyó
en esta etapa del proyecto — no es una decisión permanente, es el estado verificado a
2026-08-26.