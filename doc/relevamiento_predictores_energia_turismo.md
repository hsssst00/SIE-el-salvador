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

**Energía sí entra al conjunto de predictores.** Ver
`catalogos/01_publicaciones/UT.DEMANDA_TOTAL_MENSUAL.yaml` y la fila `UT` nueva en
`catalogos/00_instituciones.csv`. Mecanismo de captura: **manual**, no automatizable
— el dominio `ut.com.sv` bloquea acceso automatizado por `robots.txt`, confirmado dos
veces (`web_fetch` de Claude chat con `ROBOTS_DISALLOWED`, y formalmente con
`polite::scrape()` — ver `src/adquisicion/verificar_robots_ut.R`), lo que activa la
Regla 9 de `CLAUDE.md` — mismo tratamiento que
`BCR.PIB_T.SERIE_RETROPOLADA_1990_2005`. Confirmado por Harold: el formulario trae
**un año por consulta** — una captura íntegra 1998-2026 son ~28 consultas manuales.

## Consecuencia sobre la senda

El riesgo anticipado en la tabla de riesgos de la senda (§8) — *"Predictores mensuales
con cobertura insuficiente"* — se materializó parcialmente, no en su totalidad: de las
dos categorías con relevamiento inicial negativo, una (turismo) queda confirmada como
no disponible a la frecuencia requerida; la otra (energía) resultó sí estar disponible,
solo que en una institución que el relevamiento inicial no había cubierto. El conjunto
de predictores mensuales del proyecto queda en IVAE, remesas, comercio exterior,
precios, empleo cotizante y **energía (UT, pendiente de captura manual)** — seis de las
siete categorías nombradas en senda §6.4, con turismo como la única excluida.

## Si la disponibilidad cambia en el futuro

Si el Ministerio de Turismo (o CORSATUR) publica en el futuro una serie mensual o
trimestral accesible, esta nota queda como el registro de por qué turismo no se incluyó
en esta etapa del proyecto — no es una decisión permanente, es el estado verificado a
2026-08-26.
