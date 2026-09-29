# Registro de decisiones de arquitectura (ADR)

Proyecto: Sistema de Información Estadística y modelos de proyección del PIB trimestral de El Salvador

Cada decisión fundacional (D1–D8, senda metodológica §2) se registra como un ADR independiente, más D9 (stack tecnológico) y D10 (transformaciones L3 de la matriz de predictores), adiciones propias del proyecto no enumeradas en §2 — ver ADR-009 y ADR-010. Formato: contexto, alternativas consideradas, decisión, consecuencias. Un ADR se enmienda, no se reescribe, cuando una decisión posterior lo afecta.

| ADR | Decisión | Estado |
|---|---|---|
| [001](./ADR-001-variable-objetivo.md) | Definición operativa de la variable objetivo | Cerrado |
| [002](./ADR-002-horizonte-y-diseno.md) | Horizonte y diseño de los dos ejercicios | Cerrado |
| [003](./ADR-003-empalme-cuentas-nacionales.md) | Tratamiento del empalme de cuentas nacionales | Cerrado |
| [004](./ADR-004-shock-2020.md) | Tratamiento de quiebres estructurales y shock de 2020 | Cerrado |
| [005](./ADR-005-soporte-catalogos.md) | Soporte tecnológico de los catálogos | Cerrado |
| [006](./ADR-006-vocabulario-metadatos.md) | Vocabulario de metadatos | Cerrado |
| [007](./ADR-007-politica-vintages.md) | Política de versiones de publicación (vintages) | Cerrado |
| [008](./ADR-008-licencias.md) | Licencias y condiciones de redistribución | Parcial — BCR (corte 2026-10-12), FMI y FRED resueltos; ISSS, MH, ONEC/DIGESTYC, SECMCA y UT resueltos por decisión de no perseguir esclarecimiento; Banco Mundial y BID aplazados a la resolución del BCR; CEPAL en gestión (corte 2026-10-16) |
| [009](./ADR-009-stack-tecnologico.md) | Stack tecnológico | Cerrado |
| [010](./ADR-010-transformaciones-l3-predictores.md) | Método de transformación L3 de la matriz de predictores (desagregación temporal, deflactación, outliers, ajuste estacional) | Cerrado |

> **Regla de este índice.** La celda "Estado" de cada fila es copia literal de la línea
> `**Estado:**` del ADR correspondiente. Si divergen, el ADR manda y el índice está
> desactualizado. Se verifica con un `grep`; en Fase 3 corresponde un `test_that()` que
> lo compruebe automáticamente.

**Estado general:** nueve de diez ADR cerrados. Solo ADR-008 queda parcial. Su alcance pendiente se redujo en tres tandas. El 2026-08-12: los tramos FMI y FRED quedaron resueltos con el default conservador, y el tramo Banco Mundial quedó relevado con decisión aplazada. El 2026-08-17: el tramo ISSS quedó resuelto por decisión de no perseguir esclarecimiento —no por relevamiento pendiente—, se abrió el tramo CEPAL con consulta enviada y fecha de corte 2026-10-16, y se registró el tramo BID, enganchado al mismo disparador que el del Banco Mundial. El 2026-08-18: los tramos MH, ONEC/DIGESTYC y SECMCA quedaron resueltos por decisión de no perseguir esclarecimiento, mismo patrón que ISSS. Sigue abierta la decisión de si el proyecto adopta una política única de L0 o una política por fuente — aplazada hasta conocer el régimen de redistribución del BCR, con fecha de corte 2026-10-12.

ADR-007 y ADR-009 permanecen cerrados y llevan, desde el 2026-08-12, notas de seguimiento con disparador explícito: clientes de API externa en ADR-009 (se decide antes del primer *script* de `src/adquisicion/` que consuma una API), y alcance de *vintages* de predictores externos en ADR-007 (fuera del núcleo mínimo viable).

El 2026-09-24, la planificación de Fase 4 agregó notas a seis ADR sin reabrir ninguno:
aclaración de la convención de indexación del origen en ADR-002; enmienda del vintage de
referencia del ejercicio retrospectivo en ADR-001, con referencia cruzada en ADR-007;
seguimiento del ajuste estacional del objetivo dentro de cada origen en ADR-004, con referencia
cruzada en ADR-001; dependencias del motor de evaluación en ADR-009; y unidad de modelación de
las predictoras en ADR-010. Los diez siguen con el mismo estado.

## Cierre de Fase 0 (2026-08-07)

Confirmado en CI (GitHub Actions, ubuntu-latest):
https://github.com/hsssst00/SIE-el-salvador/actions/runs/31143916968 —
Status: Success (57s). Un tercero (el runner de GitHub, sin intervención
del autor) clona el repositorio y reproduce el entorno: `renv::restore()`,
validación de catálogos y la batería de pruebas corren en verde sobre Linux.

**Criterio de cierre de Fase 0 (senda metodológica §4): SATISFECHO.**

Limitación conocida, no bloqueante: en Windows local, `make test` produce
un segfault de proceso al cierre de sesión, no relacionado con el código
del proyecto — ver doc/entorno_windows.md. No afecta la señal de CI.

**Alcance exacto de este cierre, para no confundirlo con el revalidado más
abajo:** el tag `v0.1.0-fase0` (commit `1739fc8`) certifica un estado
*pre-enmienda de ADR-001* — la variable objetivo primaria era entonces la
serie oficial SA del BCR, antes de que la enmienda del 2026-08-07 la
invirtiera con la serie oficial NSA (ver ADR-001, ADR-004) — y un entorno
*pre-C6*: `renv.lock` todavía no fijaba realmente los 13 paquetes de
ADR-009 (eso se cerró en el commit `cd3e36a`, 2026-08-08). El run
31143916968 es válido para lo que certificaba en su momento; no es
evidencia de que el entorno o la enmienda actuales estén verificados.

## Cierre de Fase 0 — revalidado (2026-08-08)

Con la enmienda de ADR-001/ADR-004 cerrada, `renv.lock` fijando los 13
paquetes reales de ADR-009 (commit `cd3e36a`) y la remediación de Fase 0
aplicada (ver reparto de tareas: Bloque 1 completo, Bloque 2 y menores de
Bloque 3 resueltos), se revalida el cierre sobre el estado actual del
repositorio.

Confirmado en CI (GitHub Actions, ubuntu-latest):
https://github.com/hsssst00/SIE-el-salvador/actions/runs/31240588025 —
commit `8ab59c3`, Status: Success (1m18s). Mismo criterio que el cierre
original: `renv::restore()`, validación de catálogos (incluida la
extensión de esquema de `04_transformaciones` y el catálogo `09_rupturas`
recién poblado) y la batería de pruebas corren en verde sobre Linux.

**Criterio de cierre de Fase 0 (senda metodológica §4): SATISFECHO, sobre
el estado enmendado y con el entorno real fijado.**

Tag: `v0.2.0-fase0-enmendado`.

### Corrección de alcance del tag (2026-08-08)

El tag `v0.2.0-fase0-enmendado` apunta al commit `58e6efce`. El commit
`df02e43a` (actualización del encabezado de `doc/senda_metodologica.md`
a v0.2, con bloque de historial de versiones) quedó fuera de ese tag —
es posterior a él. Consecuencia: el snapshot certificado por
`v0.2.0-fase0-enmendado` contiene §3.4 de la senda metodológica con la
documentación del sufijo `.RETRO` (hallazgo M1), pero el encabezado del
mismo documento todavía se rotula como "Versión: 0.1 — documento de
trabajo", sin bloque de historial. Es la misma forma del hallazgo C2 de
la auditoría de Fase 0: el tag certifica un estado anterior al estado
real.

`v0.2.1-fase0-enmendado` es el tag que certifica el estado completo y
consistente (contenido de §3.4 y encabezado alineados) y es el que debe
usarse para reproducir "Fase 0 tal como quedó cerrada". `v0.2.0-fase0-enmendado`
se conserva sin modificar, por disciplina de trazabilidad — no se mueve,
borra ni recrea.

Confirmado en CI (GitHub Actions, ubuntu-latest):
https://github.com/hsssst00/SIE-el-salvador/actions/runs/31293195404 —
commit `ad33c266`, Status: Success. Mismo criterio que los cierres
anteriores: `renv::restore()`, validación de catálogos y la batería de
pruebas corren en verde sobre Linux.

Tag: `v0.2.1-fase0-enmendado`, sobre el commit `ad33c266`.

## Cierre de Fase 1 (2026-08-24)

**Criterio de cierre de Fase 1 (senda metodológica §4): SATISFECHO,** bajo la
interpretación de "ingresa al proyecto" fijada en la nota de cierre de §4 de la
senda (2026-08-24): el criterio se certifica sobre las variables *admitidas*
(series en `03_series.csv`), no sobre el inventario completo de `01_publicaciones`.

El criterio tiene dos mitades, ambas satisfechas:

1. **"El número real de observaciones de la variable objetivo está establecido y
   documentado."** `doc/metodologia/empalme_cuentas_nacionales.md` fija la serie de
   PIB trimestral en 1990-T1 a 2026-T1, **145 observaciones** (64 retropoladas +
   85 nativas, con el solape documentado). D3 resuelto; empalme documentado.

2. **"Ninguna variable ingresa al proyecto sin registro verificado de disponibilidad,
   cobertura y frecuencia."** Las 98 variables admitidas —las 98 filas de
   `catalogos/03_series.csv`— pertenecen a las cuatro publicaciones de PIB del BCR
   (NSA 28, SA 28, NOMINAL 29, retropolada 13), con cobertura verificada contra el
   portal y trazabilidad `fuente_celda` verificada **98 PASS / 0 FAIL / 0
   NO_VERIFICABLE** (`doc/bitacora_verificaciones.md`, corrida del 2026-08-17 sobre el
   commit `f7bae34`). `03_series.csv` es byte-idéntico entre `f7bae34` y este cierre,
   de modo que esa verificación certifica el catálogo actual, no un estado anterior.

**Relación con la auditoría de Fase 1** (`doc/auditorias/auditoria_fase1_SIE-el-salvador.md`).
Su veredicto "no satisfecho" se emitió bajo la lectura amplia del criterio y antes de
la remediación. Los hallazgos I1–I3 y M1–M4 de esa auditoría, y el C1 de su
verificación, están remediados (ver `doc/auditorias/` y el historial hasta
`bde69f68`). Bajo la interpretación estrecha fijada ahora en §4, las coberturas no
verificadas y las condiciones de uso abiertas que la auditoría citaba no vinculan el
cierre, porque tocan publicaciones de las que no ha ingresado ninguna serie.

**Lo que queda abierto y NO bloquea este cierre:** cobertura no verificada de las
publicaciones inventariadas sin serie admitida (FRED, FMI.WEO, BM.WDI, ONEC.IPC,
etc.) — compuerta *just-in-time* al admitir una serie suya en Fase 3; condiciones de
uso abiertas — vía ADR-008 con cortes fechados (BCR 2026-10-12, CEPAL 2026-10-16); la
reconciliación 29-vs-28 de variables de volumen — mapeo de `fuente_celda` en Fase 3
(`doc/bitacora_fuentes_fragiles.md`). Ninguno toca una variable ya admitida.

**Reproducibilidad.** Este cierre es de documentación: no cambia catálogos ni código,
así que la señal de CI es la continuidad del verde ya establecido sobre `main`. La
evidencia sustantiva del cierre es la verificación de trazabilidad (98 PASS) y el
recuento de la variable objetivo (N=145), no una corrida nueva de CI. Confirmar que
el run de CI sobre el commit de cierre queda en verde antes de tagear.

**Tag: `v0.4.0-fase1`,** sobre el commit que ya contiene esta certificación y la nota
de cierre de la senda §4 — nunca antes, para no repetir la corrección de alcance de
tag que hubo que hacer en Fase 0. El tag certifica el estado completo y propagado.

## Sprint de automatización — Fase 1/2  (2026-09-03 al 2026-09-09)

Tres guards y herramientas de automatización añadidos en este período, sin abrir
ninguna decisión D1–D9 ni modificar ADR existentes:

- `tests/test-adr-indice.R` (commit `7dfcd38`): guard CI contra deriva de
  propagación ADR → índice. Implementa la regla ya escrita en este índice
  ("en Fase 3 corresponde un test_that() que lo compruebe automáticamente").
- `tests/test-integridad-referencial.R` (commit `330a7d1`): guard CI de
  integridad referencial entre catálogos. Adelanto de Fase 3 por decisión de
  Harold; reemplazable por pointblank sin deuda.
- `scripts/auditoria_mecanica.R` + `make audit` (commit `b73c7b5`): factsheet
  de orientación pre-auditoría. Herramienta de Harold, no parte del pipeline.

Próxima ronda de automatización: validación pointblank de catálogos en Fase 3.

## Cierre de Fase 2 (2026-09-09)

**Criterio de cierre de Fase 2 (senda metodológica §4): SATISFECHO,** por la vía "verifica su
integridad" del criterio ("`make raw` reconstruye la capa L0 desde cero *o* verifica su
integridad, sin pasos manuales"), con la lectura fijada en la nota de cierre de Fase 2 de la
senda (v0.5, 2026-09-09).

**La lectura, en breve.** La integridad de L0 —regla 1, L0 inmutable— la certifican los dos
checks offline, ambos parte de `make raw`: `verificar_l0_fisico.R` (el archivo en disco es byte
a byte el registrado) y `check_l0_integrity.R` (`manifiesto.csv` ↔ `08_vintages.csv`).
`verificar_l0.R` en vivo es un monitor de deriva (ADR-007, nota del 2026-09-09): un `CAMBIO` es
un vintage nuevo por capturar, no un defecto de L0, y desde el 2026-09-09 no aborta `make raw`
—solo `ERROR` lo hace—. Esto resuelve el hallazgo A1 de la auditoría de Fase 2, que fijaba el
cierre "a una corrida de distancia" sin advertir que el verde total en vivo solo existe en la
ventana breve tras una captura.

**Evidencia (máquina de Harold, L0 completa materializada, `FRED_API_KEY` configurada,
2026-09-09):**

- `scripts/verificar_l0_fisico.R`: **54 PASS / 0 FAIL / 0 AUSENTE**, salida 0.
- `scripts/check_l0_integrity.R`: OK, 54 vintages consistentes, salida 0.
- `testthat::test_dir("tests")`: **556 PASS / 0 FAIL**.
- **Corrida completa de `make raw`** (los 16 renders headless del BCR incluidos): **54/54
  offline → 13 PASS / 15 `CAMBIO` / 0 `ERROR` en vivo (de 28 publicaciones; 2 excluidas por
  diseño) → salida 0.** Salida guardada en `doc/evidencia_cierre_fase2.txt` — `make raw` no
  corre en CI (el navegador headless sale a la red; ADR-008 mantiene los `.xlsx` en
  `.gitignore`), así que ese archivo es su única evidencia, mismo patrón que
  `doc/bitacora_verificaciones.md`.
- Los 15 `CAMBIO` son series de frecuencia mensual con un mes nuevo publicado en las ~2 semanas
  desde la captura; ninguna tiene fila en `03_series.csv`. Desglose, triaje y `sha256_norm`
  observados en `doc/backlog_captura_vintages.md`.

**Cambios de este período, sin abrir ninguna decisión D1–D9:**

- `scripts/verificar_l0.R`: `CAMBIO` dejó de ser fatal (decisión de Harold, 2026-09-09; ADR-007,
  nota del 2026-09-09). Sin esto la vía "verifica su integridad" sería inalcanzable como estado
  estable.
- `scripts/materializar_l0.R` + `make materializar-l0`: repuebla `data/L0_raw/` en una máquina
  nueva desde un almacén canónico local (copia de trabajo de un repo **privado** de L0; un repo
  privado no redistribuye, no toca ADR-008). Verificada por round-trip.
- `doc/backlog_captura_vintages.md`: registro operativo permanente de la captura prospectiva
  (no un entregable que se cierre; sigue vivo en Fase 3 y más allá).

**Reproducibilidad.** El cierre se apoya en los checks offline (reproducibles en cualquier
máquina con L0 materializada) y en el testthat que sí corre en CI. La rama en vivo de `make raw`
es intrínsecamente no reproducible bit a bit (las fuentes publican); su evidencia es la salida
guardada, no una corrida repetible.

**Tag: `v0.5.0-fase2`,** sobre el commit que ya contiene esta certificación, la evidencia y la
nota de senda §4 — nunca antes (misma disciplina que la corrección de alcance de tag de Fase 0).
Confirmar que el run de CI sobre el commit de cierre queda en verde antes de tagear.

## Remediación de la auditoría independiente de Fase 2 (2026-09-15)

`v0.5.0-fase2` certificó el fondo técnico del cierre, pero `doc/auditorias/auditoria_independiente_fase2_SIE-el-salvador.md`
(primera revisión de ese cierre contra un clon fresco, por un tercero) encontró un CRÍTICO: `CLAUDE.md`
seguía declarando "Fase 1 … en curso" y `README.md` omitía Fase 2 por completo — tercera reincidencia
del modo de falla ya visto en C2 (Fase 0) y C1 (Fase 1). Remediado el mismo día:

- `CLAUDE.md` y `README.md` declaran Fase 1 y Fase 2 cerradas, con sus tags.
- `tests/test-adr-indice.R` gana un segundo `test_that` que compara la fase declarada en ambos
  archivos contra el último "Cierre de Fase N" de este índice, para que una cuarta reincidencia
  falle en CI en vez de esperar a la próxima auditoría.
- `doc/bitacora_fuentes_fragiles.md` se completa con FMI, FRED/Banco Mundial y UT (hallazgo I1).
- La auditoría independiente queda incorporada a `doc/auditorias/` (cierra I2).
- `CITATION.cff` (M1) y el nombre del paso de CI de validación de catálogos (M2), cosméticos.
- `renv.lock`: `Matrix` 1.7-3 → 1.7-6 — ajuste no relacionado con la auditoría, hecho porque
  `renv::restore()` fallaba en la máquina de Harold; sin causa raíz diagnosticada, solo se igualó
  a la versión ya instalada localmente. CI (run 117, ubuntu-latest) confirmó verde tras el cambio.

**Tag: `v0.5.1-fase2`,** sobre el commit que ya contiene esta nota de remediación — nunca antes,
misma disciplina que `v0.5.0-fase2`. No sustituye a `v0.5.0-fase2`, que se conserva sin modificar
por disciplina de trazabilidad (mismo patrón que `v0.2.0-fase0-enmendado` →
`v0.2.1-fase0-enmendado`).

## Cierre de Fase 3 (2026-09-22)

**Criterio de cierre de Fase 3 (senda metodológica §4): SATISFECHO.** El criterio tiene dos
mitades — "cada valor de la base maestra puede rastrearse hasta la celda del archivo original
que lo originó" y "la cadena de transformaciones que lo produjo es ejecutable como código" —,
ambas certificadas, más dos lecturas que esta nota fija (mismo patrón que "ingresa al proyecto"
en Fase 1 y "verifica su integridad" en Fase 2; el detalle completo de las dos lecturas está en
`doc/senda_metodologica.md`, nota de cierre de Fase 3, v0.6):

- **Alcance de la matriz de predictores (E1/D3, ENMENDADO 2026-09-23):** cierra con **8
  familias** — las 7 del BCR (`IVAE`, `REMESAS` nominal y real, `IPP`, `EXPORT_FOB`, `ITCER`,
  `IPM`) más `UT.DEMANDA_ELEC` (demanda total de electricidad), mensual y trimestral. La
  redacción original de este registro (2026-09-22) cerraba con las 7 del BCR y dejaba UT fuera
  de la matriz; eso contradecía el relevamiento de energía y turismo (2026-08-27), que ya había
  declarado que energía entra al conjunto de predictores. Harold resolvió la contradicción en
  favor del relevamiento: UT entra, octavo predictor y primera institución distinta del BCR. El
  resto —sub-series declinadas de Balanza Comercial, instituciones nuevas para empleo, turismo y
  recaudación— sigue diferido a una fase posterior. Detalle de la enmienda y de sus
  consecuencias en `doc/senda_metodologica.md` (nota de cierre de Fase 3) y en
  `doc/evidencia_cierre_fase3.txt`. **Consecuencia declarada:** la única fila FUERA_DE_ALCANCE
  de `make trace` es la de UT (vintage vigente CSV, no `.xlsx`), así que desde esta enmienda una
  de las 8 familias de la matriz no tiene trazabilidad valor→celda comprobada mecánicamente —
  extender el verificador a vintages CSV es deuda abierta, no criterio relajado. **Remediado el
  mismo 2026-09-23, antes del tag:** rama CSV por año en `verificar_fuente_celda.R` (checksum,
  año del nombre y encabezado citado en los 25 archivos de UT); `make trace` → 106 PASS / 0 FAIL
  / 0 FUERA_DE_ALCANCE. Ver `doc/senda_metodologica.md` (nota de cierre de Fase 3).
- **Lectura de "base maestra bitemporal" (E3/D4):** la dimensión de vintage vive EN la base
  maestra, no en una lectura documental aparte. Cada archivo de `data/L3_master/` publica una
  columna `vintage_id`, resuelta contra `catalogos/08_vintages.csv` por la(s) publicación(es) de
  origen de cada fila (`src/transformacion/vintage_lib.R`) — constante dentro del archivo salvo
  en `PIB_SA_PROPIO_Q.csv`, donde varía por período porque T001 empalma dos publicaciones
  (RETRO y nativa).

**Evidencia (máquina de Harold, L0 completa materializada, commit de este cierre):**

- **G1 — trazabilidad valor→celda:** `make trace` (`src/validacion/verificar_fuente_celda.R`)
  → **105 PASS / 0 FAIL / 0 NO_VERIFICABLE / 1 FUERA_DE_ALCANCE** (de 106 filas de
  `03_series.csv`; la fuera de alcance es `UT.DEMANDA_ELEC.GWH.NSA.M`, cuyo vintage vigente es
  un CSV derivado, no un `.xlsx` — ver el script). Salida 0. Entrada correspondiente en
  `doc/bitacora_verificaciones.md` (regla 8 de `CLAUDE.md`). Revalidado el 2026-09-23 tras la
  enmienda de E1/D3 con el mismo resultado: la admisión de UT a la matriz no toca ninguna
  columna `fuente_celda` y `03_series.csv` sigue en 106 filas. Tras la rama CSV del verificador
  (mismo día, antes del tag): **106 PASS / 0 FAIL / 0 NO_VERIFICABLE / 0 FUERA_DE_ALCANCE**.
- **G3 — cadena ejecutable:** `make master` de punta a punta (`validate` → 9 extractores L0→L1
  → `validar_l2_pib.R`/`validar_l2_predictores.R` → `l3_pib_objetivo.R` → `l3_predictores.R`),
  las **18** salidas de `data/L3_master/` materializadas con su columna `vintage_id` (16 el
  2026-09-22; las dos de UT se agregan con la enmienda de E1/D3 del 2026-09-23). Salida 0 en
  cada paso.
- **H3 — batería completa:** `testthat::test_dir("tests")` y `scripts/auditoria_mecanica.R`.
  Detalle en `doc/evidencia_cierre_fase3.txt` (`make raw`/`make master`/`make test` no corren en
  CI del modo completo — los `.xlsx` están en `.gitignore` por ADR-008 —, así que ese archivo es
  su única evidencia, mismo patrón que `doc/evidencia_cierre_fase2.txt`).

**D1 y D2, resueltos en esta sesión** (detalle y límites en la nota de seguimiento de ADR-010 y
en `doc/metodologia/reporte_exploratorio_fase3.md` §3):

- **D1 — componente estacional en las pruebas de estacionariedad.** `src/analisis/hegy_reglas.R`
  implementa HEGY (Hylleberg, Engle, Granger y Yoo 1990; extensión de Beaulieu y Miron 1993) en
  R puro, verificado contra el código fuente publicado de `uroot::hegy.regressors()` — no se
  agregó `uroot` como dependencia, la decisión sigue abierta en ADR-009. Las **18** series
  rechazan raíz unitaria estacional conjunta (Δ₁ es la diferenciación correcta);
  `estacionariedad_reglas.R` publica además una especificación ADF con dummies estacionales,
  significativas al 5% en 38 de 72 filas (todas NSA), y 9 veredictos se mueven al modelarla
  (cifras de la corrida del 2026-09-23, sobre 18 series; eran 16 series, 30 de 64 filas y 5
  veredictos el 2026-09-22, antes de la enmienda de E1/D3).
- **D2 — ¿las pruebas consumen los outliers declarados en el catálogo?** No, por decisión — el
  veredicto publicado sigue sin tratar 2020, pero `reporte_estacionariedad.csv` gana
  `adf_estadistico_con_outliers` como columna de diagnóstico (no comparable contra los críticos
  de Dickey-Fuller), confirmando que la sensibilidad es real y grande.

**H1 fusionado, H2 corregido:** el PR #6 (etiquetas descriptivas y esquema completo del CSV: I1,
I3, M2, M3) se fusionó sin cambios sobre `main`. La afirmación "valida empíricamente esa decisión
para el objetivo" que `doc/checklist_fase3.md` seguía citando —exactamente lo que el hallazgo C1
había retirado del reporte narrativo el 2026-09-19— se corrigió en el tablero.

**Lo que queda abierto y NO bloquea este cierre** (declarado, no silenciado — Fase 4 lo hereda a
la vista):

- **D5** — el validador de FK entre catálogos sigue dividido entre
  `validar_integridad_catalogos.R` (pointblank, 6 aristas tabulares) y
  `tests/test-integridad-referencial.R` (la arista no tabular de `01_publicaciones`, que no
  calza con `create_agent(tbl=...)`).
- **Unidad de modelación de las predictoras** (nivel/log/diferencia) — no cubierta por ningún
  ADR, no se infiere por analogía con el objetivo (regla 4 de `CLAUDE.md`).
- **Si el veredicto publicado de estacionariedad debe pasar a consumir los outliers declarados**
  (D2 dejó el diagnóstico, no la especificación principal — exige valores críticos simulados,
  trabajo de fondo).
- **Orden de integración de la variable objetivo**, inconsistente entre `PIB_SA_OFICIAL_Q` y
  `PIB_SA_PROPIO_Q` en log-nivel (reporte exploratorio §2).

**Reproducibilidad.** El cierre se apoya en G1/G3 (reproducibles en cualquier máquina con L0
materializada) y en la batería de tests que corre en CI. `make trace` y `make raw`/`make master`
completos no corren en CI por las mismas razones que Fase 2: dependen de los `.xlsx` de L0, que
`.gitignore` excluye por ADR-008.

**Tag: `v0.6.0-fase3`,** sobre el commit que ya contiene esta certificación, la evidencia y la
nota de senda §4 — nunca antes (misma disciplina que los cierres anteriores). Confirmar que el
run de CI sobre el commit de cierre queda en verde antes de tagear.

## Cierre de Fase 4 (2026-09-29)

**Criterio de cierre de Fase 4 (senda metodológica §4): SATISFECHO.** «El motor de evaluación
funciona y está probado **antes** de estimar cualquier modelo sofisticado». Esta nota fija dos
lecturas, con el mismo patrón que los cierres anteriores; el detalle está en
`doc/senda_metodologica.md`, nota de cierre de Fase 4:

- **«El motor está probado»:** los once bloques V1-V11 de `verificar_motor_sintetico.R` en verde
  en CI, que es donde corren los que no requieren L3, más la corrida local de `make eval` sobre el
  commit de cierre, registrada en `doc/evidencia_cierre_fase4.txt`.
- **«Modelos de referencia implementados»:** los seis benchmarks de §6.1, declarados en
  `catalogos/06_modelos/` antes de la primera corrida sobre L3 (C8, commit `a78d2c6`) y corridos en
  los grupos G1, G2 y G3 con la batería de robustez R1-R6.

Ningún modelo de §6.2 a §6.7 se estimó en esta fase.

**Evidencia.**

- **CI:** run [36583715418](https://github.com/hsssst00/SIE-el-salvador/actions/runs/36583715418)
  sobre `c4e8b39` (push a `main`), en verde: `validate-and-test` (pruebas unitarias y V1-V11) y
  `check-l0-integrity`.
- **Corrida local** (máquina de Harold, R 4.6.1, la de `renv.lock`, árbol limpio):
  `make eval` sobre `c4e8b39`, código de salida 0. V1-V11 OK, 13 experimentos, 24.288 pronósticos,
  78 filas en `catalogos/07_experimentos.csv` y 552 en
  `doc/metodologia/reportes_fase4/tabla_resultados_fase4.csv`. Salida textual en
  `doc/evidencia_cierre_fase4.txt`, junto con `seasonal::checkX13()` (A3d).
- **Reproducibilidad entre máquinas:** la tabla de resultados sale con el mismo sha256
  (`5f03e4d5…`) en la máquina de Harold y en una segunda. Sobre `94ee0db`, los 71 CSV de
  `data/L4_experiments/` coincidieron byte a byte entre las dos.

**Entregables (senda §4).** `src/evaluacion/`: `eval_lib.R`, `modelos_referencia.R`,
`motor_backtesting.R`, `verificar_motor_sintetico.R` y `tabla_resultados_fase4.R`. El documento
de protocolo es `doc/metodologia/protocolo_evaluacion.md`, con la especificación y el acta
F4-01 a F4-31 en `doc/metodologia/`. Los resultados de los benchmarks están en la tabla de
resultados, más `data/L4_experiments/`, que no se versiona.

**Lo que dicen los benchmarks, en la unidad primaria (interanual, pp).**
- Corrida principal: el MCS al 10 % conserva los seis modelos en G1 y G2 en todos los horizontes,
  y en G3 con h = 1 y 2. En G3 con h = 4 y 8 excluye al paseo aleatorio sin deriva. El mejor RMSE
  relativo en h = 1 es 0,989 (G1).
- R4: sin los targets de 2020, el paseo aleatorio sin deriva sale del MCS en h = 4 y 8 en los tres
  grupos. Sin 2020 ni 2021 sale en todos los horizontes; en G1 el AR(1) queda en 0,778 con h = 1
  y en 0,393 con h = 4.
- El empate de la corrida principal depende de los targets de 2020 y 2021, como anticipaba el
  protocolo §5.

**Lo que queda abierto y NO bloquea este cierre** (declarado, no silenciado; Fase 5 lo hereda):

- Tamaño de DM/HLN en h = 4 y 8: V7 da hasta 0,152 (G3, h = 8). `pruebas.csv` y `mcs.csv` lo
  marcan con `distorsion_tamano_documentada` (F4-18, F4-21).
- MCS con pocos pares: V9 calibra hasta n = 18. Celdas más chicas, como R3 `pre2020` en G2 con
  h = 8 (n = 13), no se interpretan.
- El tamaño de GW (R1) y el del contraste de estabilidad (R3) no están verificados: llevan la
  marca `tamano_no_verificado`. En `sin_2020` y `sin_2020_2021`, DM/HLN y MCS tratan como
  contiguos los pares de cada lado del hueco, como aproximación declarada.
- D5: el validador de claves foráneas entre catálogos sigue dividido entre dos scripts.
- La pista en tiempo real (F4-03) es prospectiva; el grano de UT es anual.
- Pregunta sin resolver, sin efecto en esta fase: de dónde salen los meses 2009-M01 a M11 del IPC
  que publica el FMI (F4-23).

**Tag: `v0.7.0-fase4`,** sobre el commit que ya contiene esta certificación, la evidencia y la
nota de la senda §4, nunca antes. Antes de tagear hay que confirmar que el run de CI sobre ese
commit queda en verde.

### Nota de corrección (2026-09-29) — auditoría independiente de Fase 4, hallazgo I1

La frase «El empate de la corrida principal depende de los targets de 2020 y 2021, como anticipaba
el protocolo §5» atribuye al protocolo una anticipación que solo era parcial. El protocolo anterior
a cualquier resultado sobre L3 (`2bd1050`) anticipaba el peso de **2020** en R4. La línea «sin 2020
ni 2021» entró con F4-29 (`23eb3d7`, 2026-09-28): después de la corrida principal sobre `ee60dee`
(2026-09-24) y antes de la primera corrida de robustez (`94ee0db`). Su fundamento es descriptivo (la
partición de la suma de cuadrados del objetivo observado) y no depende de ningún modelo, pero es una
ampliación posterior a la corrida principal, no una anticipación. Lo mismo vale para las
especificaciones de R1, R2 y R3 (F4-26 a F4-28). Los benchmarks, la corrida principal, las pruebas y
la regla de reporte del MCS sí se fijaron antes de cualquier resultado (C8, `a78d2c6`). El texto
original se conserva sin editar.

### Nota de lectura (2026-09-29) — auditoría independiente de Fase 4, hallazgo I4

Las exclusiones del MCS que cita el párrafo «Lo que dicen los benchmarks» se leen con las dos marcas
que el protocolo fijó antes de los resultados.

- En h = 4 y h = 8 (`distorsion_tamano_documentada`, F4-18), que un modelo quede fuera del MCS no es
  prueba de inferioridad. Eso incluye la exclusión del paseo aleatorio sin deriva en G3 y en R4
  `sin_2020`.
- Las celdas con menos de 18 pares están bajo el piso calibrado por V9 y no se interpretan: G2
  `pre2020` con h = 4 (17) y h = 8 (13), y G3 `sin_2020_2021` en los cuatro horizontes (17).
- El paseo aleatorio sin deriva también queda fuera del MCS en R3 `pre2020`, en G1 y G2 y en los
  cuatro horizontes. Con h = 4 y 8 vale la primera marca, y G2 `pre2020` con h = 4, 8 está además
  bajo el piso de n. Con h = 1 y 2 (entre 19 y 27 pares) la exclusión no lleva marca, pero es una
  submuestra de R3 (F4-28), fijada después de la corrida principal (ver la nota I1).

La lectura que sí se sostiene sin marcas es la de G1 y G2 con h = 1, 2 en `sin_2020_2021` (entre 36
y 44 pares). Esa línea es la ampliación de F4-29 (ver la nota I1) y trata como contiguos los pares a
ambos lados del hueco.

## Remediación de la auditoría independiente de Fase 4 (2026-09-29)

`v0.7.0-fase4` certificó el cierre de Fase 4 (`a67bde9`). La auditoría independiente de ese cierre
(`doc/auditorias/auditoria_independiente_fase4_SIE-el-salvador.md`, clon fresco, por un tercero)
encontró cuatro IMPORTANTES y cinco MENORES; al preparar la remediación apareció un sexto menor (M6).
El registro del cierre de Fase 4 no se reescribió: las correcciones entraron como notas fechadas.

- **I1** (anticipación atribuida al protocolo): nota de corrección al final de «Cierre de Fase 4» y
  regla para Fase 5 en el protocolo §6 (`8c0435e`; fechas y línea sobre R3 `pre2020` en este commit).
- **I2** (compuerta de Fase 5): F4-32 a F4-34.
  - Contrato de densidad gaussiana (`predecir_densidad()` → media y covarianza del sendero),
    cobertura al 80/95 % y CRPS con oráculo `scoringRules` (V13), y rezagos por familia desde
    `evidencia_insumos_fase4.csv` (`b9b793e`).
  - Forma operativa de «UT solo años cerrados»: el año `a` desde el origen (a+1)-Q1, con canario
    anual en V5, y σ² = mean(Δy²) en el paseo sin deriva (`7c5faa8`).
- **I3** (premisa «CI no tiene X-13»): era falsa. La suite ya ejercía `seasonal::seas()` en CI, y el
  run 36595407970 da SKIP 0. Desde V12 la orquestación de `motor_backtesting.R` con X-13 por origen
  corre en CI sobre insumos sintéticos. Nota en la senda §4, v0.8 (`2c1865f`); comentario del objetivo
  `eval` del `Makefile` en este commit.
- **I4** (lectura de exclusiones del MCS): nota de lectura (`8c0435e`) y columna `marca_n` en la tabla
  de resultados (F4-35, `2da3d3b`).
- **M1** `CITATION.cff` a 0.7.0 / 2026-09-29, con guard en `tests/test-adr-indice.R`. **M2**
  `fabletools` declarado y conteos de `CLAUDE.md`/`README.md`. **M3** códigos F4-15/16/17 en
  `eval_lib.R`, comentario del `Makefile` y rótulo del paso de CI. **M4** tags en el `README.md`.
  **M6** `yaml`, `MCS` y `fabletools` en el bootstrap; V11 falla en CI si falta su oráculo
  (`81eb337`). `scoringRules` (Suggests, `b9b793e`) lleva el lockfile a 189 paquetes; conteo
  corregido en este commit.
- **M5** (hueco de revisión del cierre de Fase 3): registrado en el índice de `doc/auditorias/`, sin
  revisión retroactiva (A5 = a).

**Decisiones de Harold (2026-09-29):** A1 = (i) → F4-32; A2 → F4-33, con densidad en los dos paseos;
A3 → F4-34, con rezagos desde la evidencia de insumos y UT por la opción (C); A4 = (a) → F4-35;
A5 = (a); A6 = tag `v0.7.1-fase4`; A7 = textos de los anexos 1 y 2, más la línea sobre R3 `pre2020`.

**Cambio de sha256 de la tabla de resultados (F4-35).** `tabla_resultados_fase4.csv` pasa de
`5f03e4d5af34d39e1f8a1c3e369c42d9dd4b566326df72d534e19e46e02b49e5` (cierre de Fase 4, citado sin cambios
en `doc/evidencia_cierre_fase4.txt`) a
`8c1581e4bde943e78f36a34a25957371bb90e5608f4ecfe2f1ae34a747325151`. Se regeneró con
`Rscript src/evaluacion/tabla_resultados_fase4.R` desde la L4 de la corrida de `c4e8b39`, sin volver a
correr el motor (en este commit). Sin la columna `marca_n`, la tabla nueva es idéntica byte a byte a
la anterior; 36 de sus 552 filas llevan `n_bajo_calibracion`.

**Cambio en la salida del motor (F4-33).** Desde `b9b793e`, `make eval` llena `cobertura_80`,
`cobertura_95` y `crps` en `metricas.csv` para los cinco benchmarks con densidad. `pronosticos.csv` no
cambia: con F4_BENCH_G3 y F4_BENCH_G3_R6 sobre L3, reescrito es idéntico como texto al de la corrida
de `c4e8b39`. La salida de V1-V11 sigue idéntica a la de `doc/evidencia_cierre_fase4.txt`.

**CI:** run 36624458468 en verde sobre `b9b793e`; run `<run>` sobre este commit.

**Tag: `v0.7.1-fase4`** (A6), sobre el commit que ya contiene esta sección y con el run de CI citado
en el mensaje, nunca antes. No sustituye a `v0.7.0-fase4` (`a67bde9`), que no se mueve.
