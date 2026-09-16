# Checklist de Fase 3 — Normalización, validación y series maestras

> Deriva de `doc/senda_metodologica.md` §4 (Fase 3). No sustituye la senda ni el
> índice de ADR (`doc/adr/README.md`) — es un tablero de seguimiento operativo,
> vivo, para no perder de vista qué falta antes de poder escribir la nota de
> cierre en `doc/adr/README.md`. Última actualización: 2026-09-16 (migración
> parcial a pointblank de la batería L2 PIB + reporte de calidad de datos;
> ADR-010 resuelve el método de transformación L3 de la matriz de predictores;
> L3 de la variable objetivo materializado; ADR-008 gana tramo UT; primer
> predictor (BCR.IVAE) admitido y materializado — ver secciones abajo).

## Actividades (senda §4)

- [x] **L0 → L1 (formato largo).** `src/transformacion/extraer_bcr_pib.R`
  produce `data/L1_staging/BCR_PIB_series_largo.csv` (98 series × 8057 obs).
  `src/transformacion/ut_demanda_serie.R` cubre UT.
- [~] **Batería de validaciones (L2).** `src/validacion/l2_pib_reglas.R` +
  `validar_l2_pib.R` implementan esquema, integridad referencial bidireccional,
  duplicados, huecos e identidad contable. **Migrado a `pointblank`
  (2026-09-16)** en la parte que calza con su modelo de fila — esquema,
  huérfanas (dirección L1→catálogo) y duplicados — como pasos nativos de un
  mismo `ptblank_agent`, con extracción de las filas que fallaron
  (`get_data_extracts()`). Los checks que requieren reformular la tabla
  (ausentes en la dirección catálogo→L1, huecos por serie, identidad contable
  entre series) siguen en R base — `specially()` no soporta extracts en
  pointblank 0.12.4 cuando la función devuelve algo distinto a un vector
  lógico plano (confirmado empíricamente: además, devolver un `data.frame`
  base en modo tabla revienta el paso con `eval == "ERROR"`; hay que usar
  vector lógico o `tibble`) — pero se registran en el mismo agente sobre el
  vector ya calculado en R, sin repetir cómputo, para que el agente sea
  árbitro único y el reporte quede unificado. `validar_l2()` ahora devuelve
  `list(errores, agente)`; `tests/test-validar-l2-pib.R` actualizado al nuevo
  contrato, las 11 aserciones existentes siguen verificando lo mismo (validado
  también contra el L1 real de 98 series, cero falsos positivos).
- [~] **Transformaciones L3** (empalmes, deflactación, ajuste estacional,
  cambios de frecuencia, logaritmos y diferencias).
  **Variable objetivo materializada (2026-09-16):** `src/transformacion/
  l3_pib_objetivo.R` + `l3_pib_objetivo_reglas.R` implementan T001 (empalme
  RETRO+nativo, `concatenar_pib_nsa()`) y T002 (ajuste estacional propio vía
  `seasonal::seas()`, `ajustar_estacional_propio()`, ADR-001/ADR-004),
  encadenados en `make master`. Salida: `data/L3_master/PIB_SA_PROPIO_Q.csv`
  (145 obs) + `PIB_SA_PROPIO_Q_outliers.csv` (2 outliers AO declarados,
  2020-Q2 y 2020-Q3) + `PIB_SA_OFICIAL_Q.csv` (85 obs, pass-through). Verificó
  y documentó de paso un hallazgo de precisión numérica en el empalme (hasta
  0.0078 de diferencia RETRO-vs-nativo en el tramo de superposición — ver
  `doc/metodologia/empalme_cuentas_nacionales.md`), sin reabrir ADR-003.
  `tests/test-l3-pib-objetivo.R` cubre ambas funciones con datos sintéticos
  (15 aserciones), incluida una corrida real de X-13ARIMA-SEATS sobre un
  shock inyectado.
  **Primer predictor materializado (2026-09-16): `BCR.IVAE.VOL.SA.M/.Q`**
  (Índice de Volumen de la Actividad Económica, senda §6.4). Ya es índice de
  volumen y ya viene SA de fuente — sin deflactación ni ajuste estacional
  propio. `src/transformacion/l3_predictores.R` +
  `l3_predictores_reglas.R` (`agregar_trimestral_promedio()`) conservan la
  serie mensual tal cual y agregan a trimestral por promedio simple de 3
  meses (ADR-010: la agregación alta→baja frecuencia es aritmética
  determinista, no usa `tempdisagg`, reservado para desagregación
  baja→alta). Salida: `BCR_IVAE_VOL_SA_M.csv` (257 obs) +
  `BCR_IVAE_VOL_SA_Q.csv` (85 obs, 2026-Q2 excluido por incompleto).
  `tests/test-l3-predictores.R` (7 aserciones). **Pendiente:** el resto de la
  matriz de predictores — ningún otro predictor tiene extractor ni
  transformación todavía.
- [ ] **Análisis exploratorio y de estacionariedad.**
- [~] **Construcción de la matriz de predictores.** Iniciada 2026-09-16 con
  `BCR.IVAE.VOL.SA.M/.Q` (ver arriba). Camino para el siguiente predictor:
  (1) estructurar `fuente_celda` en `03_series.csv` con verificación real de
  `verificar_fuente_celda.R` + entrada en `doc/bitacora_verificaciones.md`
  (regla 8); (2) extractor L0→L1 dedicado; (3) transformación L3 según
  ADR-010; (4) filas en `04_transformaciones`/`05_series_master`. El BCR ya
  tiene ~35 publicaciones más adquiridas en L0 (`catalogos/01_publicaciones/
  BCR.*.yaml`) bajo el mismo default conservador de ADR-008 que IVAE —
  candidatos de la senda §6.4 sin compuerta nueva: remesas
  (`BCR.REMESAS_FAMILIARES_MENSUAL`), comercio exterior
  (`BCR.BALANZA_COMERCIAL`, `BCR.INDICES_PRECIOS_COMERCIO_EXTERIOR`), precios
  (`BCR.IPP`, `BCR.IPRI.BASE_1990`, `BCR.ITCER`).
- [x] **Hallazgo de esta sesión, corregido: `extraer_bcr_pib.R` y
  `validar_l2_pib.R` filtraban `03_series.csv` con una lista de EXCLUSIÓN**
  (`publicacion_id != "UT.DEMANDA_TOTAL_MENSUAL"`) en vez de inclusión — al
  agregar la fila de `BCR.IVAE.VIGENTE`, ambos scripts intentaban procesarla
  como si fuera PIB (parsear "Ene"/"Feb" como trimestre romano) y rompían la
  cadena de `make master`. Corregido a lista de inclusión (las 4
  publicaciones de PIB, explícitas) en ambos scripts — un predictor nuevo ya
  no puede volver a romper esto en silencio.
- [x] **Hallazgo de esta sesión, corregido: `verificar_fuente_celda.R` daba
  falsos FAIL en las 13 filas `*.RETRO`** (bug propio del verificador, no de
  los datos — ver `doc/bitacora_verificaciones.md`, entrada 2026-09-16, y
  detalle en el propio script). Corregido: ahora lee la fila vía `readxl`
  (misma convención que el extractor real) en vez de contra el atributo `@r`
  del XML crudo.

## Entregables (senda §4)

- [~] Catálogo `03_series` poblado — 100 filas (98 PIB + 1 UT + 1
  `BCR.IVAE.VOL.SA.M`, alta 2026-09-16, verificada 99 PASS / 0 FAIL / 1
  FUERA_DE_ALCANCE). Falta el mapeo completo para la reconciliación 29-vs-28
  de variables de volumen de PIB (`doc/bitacora_fuentes_fragiles.md`,
  pendiente de Fase 1) y el resto de la matriz de predictores.
- [~] Catálogo `04_transformaciones` poblado — 3 filas (T001, T002, T003),
  todas con `script_path`/`funcion` reales; faltan las filas del resto de la
  matriz de predictores (ADR-010).
- [~] Catálogo `05_series_master` poblado — 4 filas (`PIB.SA.PROPIO.Q`,
  `PIB.SA.OFICIAL.Q`, `BCR.IVAE.VOL.SA.M`, `BCR.IVAE.VOL.SA.Q`), todas
  materializadas; faltan las filas del resto de predictores.
- [~] Base maestra bitemporal — `data/L3_master/` tiene la variable objetivo
  (`PIB_SA_PROPIO_Q.csv`, `PIB_SA_PROPIO_Q_outliers.csv`,
  `PIB_SA_OFICIAL_Q.csv`) y el primer predictor (`BCR_IVAE_VOL_SA_M.csv`,
  `BCR_IVAE_VOL_SA_Q.csv`), pero cubre solo eso, no el resto de la matriz de
  predictores. L4 sigue vacío salvo `.gitkeep`.
- [x] **Reporte de calidad de datos** (2026-09-16) — `pointblank::export_report()`
  sobre el agente de `validar_l2()`, escrito a `data/L2_validated/reporte_calidad_l2_pib.html`
  (HTML autocontenido) en cada corrida de `src/validacion/validar_l2_pib.R`, tanto
  si pasa como si falla. Capa generada, no versionada. Cubre solo BCR PIB — si
  se extiende el extractor a otras publicaciones (ver decisión 3 abajo), este
  reporte se extiende con ellas.
- [ ] Reporte exploratorio.
- [~] Matriz de predictores mensuales y trimestrales con cobertura documentada
  — 1 de ~8 candidatos de la senda §6.4 (`BCR.IVAE`, mensual y trimestral).

## Guards de CI a subsumir

- [ ] `tests/test-integridad-referencial.R` — explícitamente marcado como
  "adelanto de Fase 3, reemplazable por pointblank sin deuda" (CLAUDE.md,
  `doc/adr/README.md`). Sigue activo; no se ha reemplazado.

## Prerrequisitos ya satisfechos

- [x] ADRs: 9/10 cerrados (001–007, 009–010). Solo ADR-008 parcial (licencias),
  con cortes fechados BCR 2026-10-12 y CEPAL 2026-10-16 — no bloquea el
  trabajo de Fase 3 ya en curso (compuerta *just-in-time* por publicación
  admitida, no global; ver nota de cierre de Fase 1).
- [x] Catálogos base completos (`00`–`09` + `datapackage.json`).
- [x] Dependencias declaradas: `pointblank`, `duckdb`, `seasonal`,
  `tempdisagg` en `DESCRIPTION` y `renv.lock` (ADR-009 cerrado).
- [x] `make master` encadena `validate` → extractores L0→L1 (PIB, UT, IVAE) →
  validación L2 → `l3_pib_objetivo.R` (variable objetivo) →
  `l3_predictores.R` (matriz de predictores).

## Decisiones metodológicas pendientes — NO asumir, preguntar

Conforme a la regla 4 de CLAUDE.md, estas quedan marcadas como bloqueo de
inferencia, no como tarea a resolver de una vez:

1. ~~¿Se migra `l2_pib_reglas.R`/`validar_l2_pib.R` a `pointblank`?~~
   **Resuelto 2026-09-16** (decisión de Harold: proceder con la migración
   parcial que se recomendó — ver detalle en "Batería de validaciones" arriba).
   No cerró un ADR nuevo porque no fija una decisión metodológica sobre los
   datos, sino una decisión de implementación de la validación misma.
2. ~~Método de ajuste estacional y deflactación para L3~~ **Resuelto
   2026-09-16** (decisión de Harold, ver ADR-010): desagregación temporal vía
   `tempdisagg` (Chow-Lin con indicador cuando exista, Denton-Cholette si no);
   deflactación caso por caso, declarada por serie en `04_transformaciones`;
   sin tratamiento de outlier propio en L3 para predictoras (se decide por
   modelo en Fase 5). No afecta el tratamiento de la variable objetivo
   primaria, que sigue rigiéndose por ADR-001/ADR-004.
3. ~~Extensión del extractor L0→L1 más allá de BCR PIB~~ **Parcialmente
   resuelto 2026-09-16:** `BCR.IVAE.VOL.SA.M` admitida con extractor propio
   (`extraer_bcr_ivae.R`) — no disparó compuerta nueva de ADR-008 porque es
   la misma institución (BCR) ya cubierta por el default conservador
   aplicado a PIB. El tramo UT (institución nueva) sí requería compuerta
   propia — abierta y cerrada en la misma sesión (ADR-008, enmienda "UT",
   default conservador, mismo patrón que MH/ONEC/SECMCA). Sigue en pie para
   *instituciones* genuinamente nuevas (ninguna serie de otra fuente ha
   entrado todavía): cada una dispara su propia compuerta *just-in-time* de
   ADR-008 antes de admitirse en `03_series.csv`.
4. **Reemplazo o coexistencia de `tests/test-integridad-referencial.R`** con
   los checks pointblank de Fase 3 — decidir si se subsume sin deuda (como
   ya está anotado) o si se mantiene como doble verificación.
