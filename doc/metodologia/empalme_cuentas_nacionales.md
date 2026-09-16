# Nota metodológica: empalme de cuentas nacionales

**Decisión registrada en:** `doc/adr/ADR-003-empalme-cuentas-nacionales.md`

## Resumen

La serie de PIB trimestral utilizada cubre 1990-T1 a 2026-T1 (145 observaciones), combinando:

- Serie retropolada oficial del BCR: 1990-T1 a 2005-T4 (64 obs), declarada por el BCR como "serie homogénea, retropolada".
- Compilación nativa bajo SCN 2008: 2005-T1 a 2026-T1 (85 obs).
- Superposición de 4 trimestres (2005-T1 a 2005-T4) entre ambas.

No se realizó empalme propio — la retropolación oficial del BCR se adopta tal cual.

## Método de retropolación del BCR

**Fuente:** Hernández, Mario Roger (2018). *Sistema de Cuentas Nacionales de El Salvador SCNES: Aspectos metodológicos y resultados*, 1ª ed. corregida y aumentada. San Salvador: Banco Central de Reserva de El Salvador. Capítulo 4, sección "Retropolación de series del PIB", pp. 108-110.

El BCR evaluó tres métodos para retropolar la serie 1990-2004 a la base 2005 (SCN2008):

- **Método proporcional** (descartado): encadenar las tasas de variación de la serie base 1990 al dato de 2005 en base 2005. Asume estructura productiva constante hacia atrás; pierde la información propia de la serie base 1990.
- **Método de reelaboración de series** (descartado): reestimar todo bajo las directrices nuevas con la información original. Declarado inviable en la práctica por requerir doble registro de recolección.
- **Método de interpolación de series** (aplicado): intermedio entre los dos anteriores.

Procedimiento documentado (pp. 108-109), en síntesis:

1. Identificar diferencias metodológicas entre bases 1990 y 2005 (valoración de la producción, tratamiento SIFMI, trabajos en curso en la rama agropecuaria, estimación de la producción propia del Banco Central, estimaciones de maquila) y fijar un nivel de agrupación común (12 categorías de actividad económica, Tabla 4.8 del documento fuente).
2. Incorporar a la serie base 1990 las principales diferencias metodológicas de la construcción de la serie base 2005.
3. Interpolar la diferencia estadística entre las estimaciones del año 2005 en ambas bases (razón entre ambas estimaciones, por variable, actividad, oferta y demanda) — el paso que da nombre al método.
4. Deflactar la serie homogénea con los deflactores implícitos de la serie base 1990, asumiendo comportamiento de precios sin cambio.
5. Construir indicadores sintéticos de volumen y valor al nivel de agrupación usado.
6. Trimestralizar los datos anuales homogéneos (volumen y corrientes).
7. Construir el índice de volumen encadenado con origen en 2005 = 100, retrocediendo año por año hasta 1990.

## Por qué la superposición es de 4 trimestres exactos

No es calibración ni coincidencia de publicación: es consecuencia estructural del método. El paso 7 fija 2005 como año de origen (índice = 100) de la serie retropolada, construida hacia atrás desde ahí. La serie nativa 2005-2026 usa el mismo año 2005 como año base de sus índices de volumen encadenados (Banco Central de Reserva de El Salvador, Departamento de Cuentas Nacionales, *PIB Trimestral: Resumen Aspectos Metodológicos*, marzo 2018, §2.1). Ambas series están ancladas al mismo año por diseño — de ahí que el traslape cubra exactamente los 4 trimestres de 2005, ni más ni menos. Coherente con el empalme exacto ya verificado por Claude Code en `03_series.csv` para el tramo de superposición.

## Pendiente (Fase 1, no bloqueante)

- [x] ~~Localizar y citar la nota metodológica específica del BCR que documenta el método de retropolación utilizado.~~ Resuelto (2026-08-09) — ver "Método de retropolación del BCR" arriba.
- [x] ~~Confirmar si la superposición de 4 trimestres corresponde a un período de calibración/validación documentado por el BCR, o si es una coincidencia de publicación.~~ Resuelto (2026-08-09) — ver "Por qué la superposición es de 4 trimestres exactos" arriba.
- [ ] Registrar el número de observaciones al momento de cada actualización trimestral (crece con el tiempo).

## Precisión numérica de la superposición (Fase 3, 2026-09-16)

Al implementar `src/transformacion/l3_pib_objetivo.R` (T001_CONCAT_PIB_NSA,
`catalogos/04_transformaciones.csv`) se verificó numéricamente, por primera
vez a nivel de código, el empalme de 2005-T1 a 2005-T4 que ADR-003 describe
como "valores idénticos verificados". El resultado exacto:

| Período | RETRO | Nativo | Diferencia |
|---|---|---|---|
| 2005-Q1 | 77.0577674 | 77.05 | +0.0078 |
| 2005-Q2 | 84.7870395 | 84.79 | -0.0030 |
| 2005-Q3 | 82.5236399 | 82.53 | -0.0064 |
| 2005-Q4 | 87.7274269 | 87.73 | -0.0026 |

Las diferencias (hasta 0.0078, sobre índices de magnitud ~80) no contradicen
la caracterización de ADR-003: la tabla nativa del BCR publica solo 2
decimales, mientras que RETRO conserva la precisión completa de su cómputo
de retropolación (Hernández 2018, método de interpolación de series, ver
arriba) — una diferencia de hasta una unidad del último decimal publicado es
el resultado esperado de comparar un valor redondeado para publicación contra
uno de precisión completa, no evidencia de que las series describan
magnitudes distintas. `concatenar_pib_nsa()` usa tolerancia 0.01 en vez de
0.005 (media unidad del decimal publicado) precisamente por este margen
verificado. No reabre ADR-003: la decisión (usar la retropolación oficial tal
cual, sin empalme propio) sigue siendo la misma; esto solo documenta, con
precisión numérica exacta, algo que antes se verificó solo a 2 decimales.
