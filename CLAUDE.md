# Contexto del proyecto para Claude Code

## Qué es esto

Sistema de Información Estadística (SIE) para variables macroeconómicas de El Salvador, con un ejercicio de comparación de modelos de proyección del PIB trimestral como demostración de uso.

**El SIE es el producto principal. Los modelos de proyección son la prueba de uso, no el objetivo central.** No inviertas esfuerzo desproporcionado en la sofisticación de modelos a costa de la trazabilidad, validación o documentación del sistema de datos. Si en algún momento el trabajo empieza a inclinarse hacia "mejorar el modelo" a costa de "fortalecer el sistema", señálalo — no lo asumas y sigas.

## Estado del proyecto

Fase 0 cerrada (tag `v0.2.1-fase0-enmendado`); Fase 1 —inventario del ecosistema estadístico— en curso. Ver `doc/adr/README.md` para el estado exacto de cada decisión. A la fecha de este archivo: ocho de nueve ADR cerrados; ADR-008 sigue parcial, con BCR/CEPAL en gestión y la decisión de política de L0 como únicos tramos abiertos — el estado por fuente vive en ADR-008, no acá.

**Antes de escribir cualquier código de estimación o transformación, lee los ADR relevantes en `doc/adr/`.** Son la especificación. No hay decisión metodológica de las nueve fundacionales que debas tomar tú — ya están tomadas y documentadas.

## Reglas no negociables

1. **Nunca edites manualmente `data/L0_raw/`.** Es inmutable. Todo archivo ahí llega vía script de descarga, con entrada correspondiente en `data/L0_raw/manifiesto.csv` (checksum SHA-256, URL, fecha, código HTTP). Excepción explícita, no una violación de la regla: la captura prospectiva de vintages inició de forma manual, antes de que existiera automatización de Fase 2 — así lo previó ADR-007 ("hasta entonces, la captura es manual"). Mientras eso dure, el requisito no negociable es el mismo manifiesto con procedencia trazable, no que el archivo haya llegado por script.
2. **Nunca edites los catálogos en `catalogos/` a mano fuera de lo declarado en su esquema.** Cualquier cambio de esquema pasa primero por `catalogos/datapackage.json`.
3. **Ninguna capa de datos (`L1`–`L4`) se edita directamente.** Cada una se genera por código a partir de la anterior. Si necesitas cambiar un valor derivado, cambias el código que lo genera, no el archivo.
4. **Ante una decisión metodológica no cubierta por un ADR existente, detente y pregunta.** No la resuelvas por inferencia ni la dejes implícita en el código. Esto incluye: definiciones de variables nuevas, tratamiento de datos faltantes no contemplado, elección de hiperparámetros no especificada, cualquier cosa que debería ser su propio ADR.
5. **El stack es R, cerrado (ADR-009).** No introduzcas Python u otro lenguaje salvo que exista un ADR posterior que lo autorice explícitamente.
6. **Todo script de descarga (`src/adquisicion/`) debe fallar de forma visible, no silenciosa**, ante cambios de estructura de la fuente — conforme al principio de inmutabilidad de L0.
7. **La validación falla, no advierte** (§3.5 de la senda metodológica). Un catálogo que no cumple su esquema detiene el pipeline.
8. **Toda corrida de `src/validacion/verificar_fuente_celda.R` se asienta en
   `doc/bitacora_verificaciones.md`**, en el mismo commit en que se usa su resultado. El
   verificador no corre en CI (los `.xlsx` están en `.gitignore`, ver ADR-008): esa bitácora es
   su única evidencia. Una entrada corresponde a una corrida real, nunca a la intención de
   correrla.

## Consideraciones sobre fuentes de datos

- **Ministerio de Hacienda (MH): sin repositorio sistemático.** A diferencia del BCR (URLs `/serie/` individuales por publicación, mismo patrón estructural), el Portal de Transparencia Fiscal (PTF) expone múltiples tablas estáticas como widgets independientes dentro de una misma página HTML (ej. `PTF2-Ingresos.html`), cada una con su propia fecha de "Actualizado" y sin API ni endpoint por serie. Confirmado empíricamente (2026-08-11): 4 tablas en esa página con fechas de actualización entre sep-2019 y jun-2026. Trata cada tabla de Hacienda como un artefacto aislado que requiere verificación individual — la vigencia de una tabla en esa página NO implica la vigencia de otra. Consecuencia de diseño ya aplicada: BCR es la fuente primaria sobre Hacienda para series con equivalente (ver notas cruzadas en `01_publicaciones` y en `00_instituciones.csv`, entrada MH).

## Convenciones (senda metodológica §3.4)

- Identificadores legibles y estables: `{fuente}.{concepto}.{unidad}.{ajuste}.{frecuencia}` — ej. `BCR.PIB.VOL.SA.Q`. Sufijo adicional opcional tras `{frecuencia}` para distinguir un tramo de captura distinta de la misma serie conceptual — ej. `BCR.PIB.VOL.NSA.Q.RETRO` (tramo retropolado) — ver senda metodológica §3.4.
- Períodos en ISO 8601: `2024-Q3`, `2024-07`.
- UTF-8, separador decimal punto, sin separador de miles, ausentes como celda vacía (nunca `0`, `-`, `n.d.`).
- `snake_case` en nombres de campo, sin acentos ni espacios.
- Cada directorio de catálogo lleva su propio `README.md` con diccionario de variables.

## Comandos

Ver `Makefile`. Objetivos previstos: `make raw | clean | master | eval | report`. Muchos aún no tienen script detrás — no lo inventes de una vez; impleméntalo cuando la fase correspondiente lo requiera, conforme al orden de fases de la senda metodológica (§4).

## Stack (ADR-009)

R vía `renv`. `renv.lock` está fijado (154 paquetes) y verificado en CI sobre `ubuntu-latest`; `renv::restore()` reproduce el entorno en una máquina limpia. `scripts/bootstrap_renv.R` documenta cómo se generó el lockfile a partir de `DESCRIPTION`, por si hace falta regenerarlo. Paquetes (14 imports declarados en `DESCRIPTION`): `pointblank`, `duckdb`, `seasonal`, `tempdisagg`, `fable`, `tsibble`, `vars`, `tsDyn`, `BVAR`, `midasr`, `glmnet`, `ranger`, `lightgbm`, `xml2`.

## Orden de fases (no te lo saltes)

Fase 0 → 1 (inventario) → 2 (adquisición) → 3 (normalización/validación) → 4 (protocolo de evaluación, probado con datos sintéticos **antes** de estimar nada) → 5 (estimación) → 6 (proyección condicional) → 7 (publicación). El criterio de cierre de cada fase está en la senda metodológica §4. No implementes estimación de modelos (Fase 5) antes de que el motor de evaluación de Fase 4 esté probado — es la regla más importante del documento.
