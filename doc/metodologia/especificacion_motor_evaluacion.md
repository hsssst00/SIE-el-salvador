# Especificación del motor de evaluación — Fase 4

**Fecha:** 2026-09-24
**Estado:** especificación vigente; las decisiones que condicionan (F4-01, F4-03, F4-05, F4-09,
F4-09b, F4-11, F4-12) están cerradas en `doc/metodologia/decisiones_fase4.md`. Al abrirse esta
versión no había código escrito.
**Criterio de cierre que esta especificación debe satisfacer (senda §4, Fase 4):** *"el
motor de evaluación funciona y está probado antes de estimar cualquier modelo sofisticado.
Definir las reglas después de ver los resultados invalida el ejercicio."*
**Estado verificado del andamiaje:** `src/evaluacion/` contiene solo `.gitkeep`;
`src/modelos/` también; el target `eval` del Makefile es un `echo` de pendiente;
`data/L4_experiments/` está vacío; `catalogos/07_experimentos.csv` tiene solo la cabecera
de doce columnas; `catalogos/06_modelos/` tiene `.gitkeep` y `_plantilla.yaml`.

Las decisiones F4-01, F4-03, F4-05 y F4-09 condicionan esta especificación y están marcadas
donde muerden.

---

## 1. Separación de responsabilidades

Se mantiene el patrón que ya usa el repositorio (reglas puras en `*_reglas.R`, orquestador
delgado que lee y escribe):

| Archivo | Responsabilidad | Ejercitado por |
|---|---|---|
| `src/evaluacion/eval_lib.R` | Funciones puras: aritmética de orígenes, recorte al conjunto de información, **bucle de orígenes con sus guardas**, métricas, DM/HLN, GW, MCS, gramática del token de `esquema_validacion`. Sin I/O. | `tests/test-evaluacion.R` (CI) |
| `src/evaluacion/modelos_referencia.R` | Los seis benchmarks de §6.1 bajo el contrato de modelo. Sin I/O. | `tests/test-modelos-referencia.R` (CI) |
| `src/evaluacion/motor_backtesting.R` | Orquestador: lee L3, la NSA de L1 para el ajuste por origen (F4-19) y `06_modelos/`, corre X-13 en cada origen, llama al bucle de `eval_lib.R` y escribe L4. La fila de `07_experimentos.csv` llega con el paso 6. | `make eval` (local) |
| `src/evaluacion/verificar_motor_sintetico.R` | Verificación del motor sobre procesos generadores conocidos. No lee L3. | `make eval-sintetico` (**CI**) |

**Corrección al implementar (2026-09-24).** El bucle de orígenes pasó de `motor_backtesting.R` a
`eval_lib.R`, porque los canarios de V5 y V6 tienen que ejercitar el mismo bucle, con las mismas
guardas, sin leer L3. El orquestador queda como capa de lectura y escritura.

El punto clave de diseño: **la verificación sintética no necesita datos del proyecto**, así
que puede correr en integración continua, a diferencia de `make trace` o `make master`. El
criterio de cierre de Fase 4 queda así certificado por CI y no solo por una corrida local.

## 2. Contrato de modelo

Un modelo es una lista con cuatro campos. El motor nunca inspecciona su interior.

```r
modelo <- list(
  modelo_id = "BENCH.RW_SIN_DERIVA",          # coincide con 06_modelos/<modelo_id>.yaml
  requiere  = c("PIB_SA_PROPIO_Q"),           # series de L3 que necesita
  ajustar   = function(datos, spec) { ... },  # datos ya recortados al origen
  predecir  = function(ajuste, h) { ... }     # devuelve vector de longitud h, en log-nivel
)
```

Reglas del contrato:

1. `ajustar()` recibe un data frame **ya recortado** por el motor. No recibe el origen como
   argumento y no tiene forma de pedir más datos: el recorte es responsabilidad exclusiva
   del motor, de modo que ningún modelo pueda introducir filtración por descuido.
2. `predecir()` devuelve el sendero completo `h = 1..8` en **log-nivel** del objetivo. Todas
   las unidades de reporte (interanual, trimestral, nivel) se derivan después, en un solo
   lugar. Un modelo que internamente trabaje en diferencias acumula él mismo su sendero.
3. `ajustar()` debe ser determinista dado `(datos, spec, semilla)`. La semilla se fija por
   `(exp_id, modelo_id, origen)` —no una sola vez por corrida— para que la reejecución de
   un origen aislado reproduzca el mismo resultado. **El motor restaura al salir el generador
   aleatorio del llamador** (corrección del 2026-09-24): sin eso, un bucle de Monte Carlo que
   llame al motor recibe la misma secuencia en cada réplica. V3 detectó ese defecto en la
   primera implementación.
4. Selección de órdenes e hiperparámetros ocurre **dentro** de `ajustar()`. El motor no
   selecciona nada; solo reestima.

## 3. Bucle de orígenes

```
para cada grupo de comparación g:                  # F4-05
  origenes <- origenes_del_grupo(g)                # F4-01
  para cada origen o en origenes:
    info   <- recortar_a_origen(L3, o, calendario) # F4-02
    objetivo_sa <- desestacionalizar(info, outliers_declarados)   # F4-09, opción (b)
    para cada modelo m en modelos_del_grupo(g):
      verificar_requisitos(m, info)                # stop() si falta una serie
      ajuste <- m$ajustar(datos_de(info, m$requiere), spec_de(m))
      guardar_pronostico(m, o, m$predecir(ajuste, 8))
```

Orden de los bucles: grupo → origen → modelo, para que el recorte y el ajuste estacional se
computen **una vez por origen** y todos los modelos del grupo vean exactamente el mismo
conjunto de información. Esto es lo que hace verdadera la premisa del MCS.

### Guardas que fallan, no advierten (regla 7 de `CLAUDE.md`)

| Guarda | Qué comprueba | Cuándo falla |
|---|---|---|
| G-1 recorte | ninguna fila con `periodo > o` (para series trimestrales) ni con fecha de disponibilidad posterior a la publicación del PIB de `o` (mensuales) | `stop()` antes de llamar a cualquier modelo |
| G-2 inmutabilidad | hash del data frame recortado antes y después de `ajustar()` | `stop()` si un modelo mutó su insumo |
| G-3 longitud | `predecir()` devuelve exactamente 8 valores finitos | `stop()` |
| G-4 requisitos | toda serie de `m$requiere` existe en el recorte y alcanza el mínimo de observaciones declarado del grupo | `stop()` con el conteo real |
| G-5 dummies | ninguna dummy de evento (2020-Q2, 2020-Q3) con fecha posterior a `o` entra al diseño | `stop()` — F4-08 |
| G-6 vintage | toda fila usada tiene `vintage_id` con fecha de publicación ≤ la del origen, cuando la corrida se declara `vintage=real_time` | `stop()` — F4-03 |
| G-7 determinismo | dos ejecuciones del mismo origen con la misma semilla dan idéntico resultado | `stop()` en la prueba, no en producción |

G-1 y G-6 son la razón de existir del motor. Todo lo demás es contabilidad.

**Nota (2026-10-03, F5-16, decisiones C-3 a C-8 de `decisiones_fase5.md`).** Desde Fase 5, la capa de
lectura de `motor_backtesting.R` agrega cuatro guardas, todas con `stop()`:

- **Corte requerido (C-3).** Sin `SIE_CONJUNTO` (`make eval CONJUNTO=… SALIDA=…`) el motor no corre.
- **G-6 sobre el corte.** L1 y L3 se leen con `ruta_capa()` (de `<SALIDA>/`), y el vintage vigente de cada
  publicación es el que declara el corte (`vintage_vigente(…, conjunto)`).
- **L1 frente a L3 (C-5).** El SA recalculado desde la NSA de L1 debe ser idéntico, valor por valor, al de
  L3, y los AO deben coincidir.
- **Fase 4 cerrada (C-8).** Un `exp_id` `F4_*` se rechaza; la reproducción usa `F5_REPRO_*`, con las semillas
  del experimento que reproduce (C-7).

El token de §4 admite un séptimo campo opcional, `|conjunto=<nombre>@<sha8>` (C-4).

**Nota (2026-10-05, F5-03, F5-04, B1-3; bloque B1a).** Para los modelos de Fase 5 con predictoras, la capa de lectura
y el bucle agregan:

- **Lectura de predictoras.** `leer_predictoras()` lee de `<SALIDA>/L3_master` las series que piden los modelos de la
  corrida, con **G-6 por fila** (`verificar_vintage_predictora()`): cada fila trae el vintage que el corte declara
  para su publicación, y UT el de su año. Sus sha256 entran al manifiesto.
- **G-7 · borde incompleto** (`guarda_borde()`, en `correr_backtest()`): tras el recorte, toda predictora con rezago en
  días llega exactamente al último período que el calendario admite en el origen (`ultimo_admitido()`).
- **G-8 · grados de libertad** (`guarda_gl()`): un modelo con `piso_gl = TRUE` devuelve `gl = c(n_obs, n_par)` y debe
  dejar al menos `PISO_GL = 20`.
- **Alineación.** `rezago_alineacion(serie, grupo)` da el desfase uniforme de una predictora en los orígenes del grupo:
  0 trimestres para las `.Q` (entran hasta `o`) y los meses de `o+1` para las `.M`.
- **Experimentos `F5_G1`, `F5_G2`, `F5_G3`** con los benchmarks y `modelos_fase5(grupo)`, bloqueados sobre L3 por el
  candado del preregistro (F5-02) hasta el commit de congelamiento.

## 4. Persistencia

```
data/L4_experiments/<exp_id>/
├── pronosticos.csv        exp_id, modelo_id, grupo, origen, h, periodo_objetivo,
│                          log_nivel_pronosticado, yoy_pp_pronosticado, qoq_pp_pronosticado,
│                          vintage_id_objetivo
├── metricas.csv           exp_id, modelo_id, grupo, h, unidad, n_pares, rmse, mae,
│                          rmse_relativo, sesgo, sesgo_ee_nw, cobertura_80, cobertura_95, crps
├── pruebas.csv            exp_id, grupo, h, unidad, prueba (dm_hln|gw), modelo_a, modelo_b,
│                          estadistico, p_valor, n_pares, varianza, media_diferencial, marca_tamano
├── mcs.csv                exp_id, grupo, h, unidad, modelo_id, p_mcs, en_mcs, orden_eliminacion,
│                          alpha, replicas, bloque, semilla, marca_tamano
├── ajuste_estacional.csv  exp_id, origen, n_obs, arima, transform, regresores, ao_declarados
│                          (solo con sa=reestimado_en_origen; F4-09b)
├── metricas_submuestras.csv  muestra_eval + columnas de metricas.csv    (R3/R4, solo en la principal)
├── pruebas_submuestras.csv   muestra_eval + columnas de pruebas.csv     (R3/R4)
├── mcs_submuestras.csv       muestra_eval + columnas de mcs.csv         (R3/R4)
├── estabilidad.csv        exp_id, grupo, h, unidad, modelo_a, modelo_b, media_pre, cambio_post,
│                          ee_hac, estadistico, p_valor, n_pre, n_post, marca_tamano   (R3)
└── manifiesto.txt         exp_id, token, commit_hash, estado del árbol, semillas, sha256 de insumos
                           y de cada CSV anterior, sessionInfo()
```

**Actualizado el 2026-09-28 (F4-30, F4-31).** Los sha256 de insumos del manifiesto se toman sin
retornos de carro, para que identifiquen el contenido versionado y no el fin de línea de la copia de
trabajo; los de las salidas, que el motor escribe en LF, son de los bytes tal cual. Después del motor,
`make eval` corre `src/evaluacion/tabla_resultados_fase4.R`, que escribe
`doc/metodologia/reportes_fase4/tabla_resultados_fase4.csv` (versionado): la tabla de E4 y E5 en formato
largo (variante, `muestra_eval`, `exp_id`, grupo, h, unidad, `modelo_id`, `n_pares`, `rmse`, `mae`,
`rmse_relativo`, `en_mcs`, `p_mcs`, `marca_tamano`), solo en la unidad primaria `yoy_pp`.

**Actualizado al implementar (2026-09-24).** Columnas agregadas respecto de la versión anterior:
`qoq_pp_pronosticado` (unidad secundaria), `unidad`, `varianza` y `media_diferencial` en
`pruebas.csv` (la columna `varianza` es el registro que pide F4-16), `orden_eliminacion` y `bloque`
en `mcs.csv`, y `marca_tamano` en las dos (F4-21). `ajuste_estacional.csv` es el registro por
origen que pide F4-09b. `modelo_a` es siempre `BENCH.RW_SIN_DERIVA` y un estadístico positivo
favorece a `modelo_b`. `cobertura_80`, `cobertura_95` y `crps` quedan vacías mientras el contrato
de modelo devuelva solo el sendero puntual (protocolo §3.4: no se imputa una densidad). La semilla
de cada MCS es `semilla_de(exp_id, "MCS", h)`. Los CSV se escriben con fin de línea LF.

**Actualizado con el bloque E (2026-09-25, F4-25 a F4-29).** `muestra_eval` toma `pre2020`,
`post2020` (R3, G1 y G2) y `sin_2020`, `sin_2020_2021` (R4, G1-G3); las cuatro son funciones del
índice del target en `SUBMUESTRAS_FASE4`. La semilla del MCS de una submuestra es
`semilla_de(exp_id, "MCS|<muestra>", h)`. `estabilidad.csv` es la regresión de d_t sobre
(1, D_post) de `prueba_cambio_diferencial()`: `media_pre` es la media de d_t antes de 2020 y
`cambio_post` su cambio desde 2020-Q1; positivo favorece a `modelo_b`. Las tablas de la muestra
completa no cambian por agregar R3/R4. En R1, `pruebas.csv` agrega las filas `gw` con
`varianza = bartlett`; ellas y `estabilidad.csv` llevan `marca_tamano = tamano_no_verificado`.

`data/L4_experiments/` no se versiona (senda §7); `manifiesto.txt` y la fila de
`07_experimentos.csv` sí, y son lo que hace auditable la corrida sin publicar los datos.

**Filas de `07_experimentos.csv`** — una por (experimento, modelo) **[decidido 2026-09-25, F4-25]**,
con las doce columnas ya declaradas y `exp_id` = `<exp_id>__<modelo_id>`: el esquema declara
`exp_id` único y `modelo_id` con un solo valor, y cada experimento corre seis modelos. Las escribe
`registrar_experimentos()` al final de `make eval`, reemplazando las filas previas de los
experimentos que corrió. `muestra_inicio` es el primer período de la muestra de estimación en el
primer origen del grupo (1990-Q1, 2005-Q1 en R2 y R5, y el inicio de la ventana de 92 en R1);
`muestra_fin` es el último período observado del objetivo; `vintage_id` junta con « + » los vintages
del objetivo en ese tramo; `semilla` es `semilla_de(exp_id, modelo_id, primer origen)`; `entorno`
lleva la versión de R, la plataforma y los 12 primeros caracteres del sha256 de `renv.lock`.
`esquema_validacion` lleva el token de F4-11:

```
expansiva|origen=ultimo_estimado|grupo=G1|vintage=revision_vigente|sa=reestimado_en_origen|perdida=yoy_pp
```

La gramática del token vive en `eval_lib.R` con una función que la valida y una prueba que
rechaza tokens mal formados; así el CSV sigue siendo legible sin migrar el esquema.

**Fila de `06_modelos/<modelo_id>.yaml`** — se usa la plantilla existente sin cambios:
`modelo_id`, `familia` (`benchmark` para los de §6.1), `especificacion.variables`,
`especificacion.ordenes`, `especificacion.hiperparametros`,
`especificacion.transformaciones_ref` (referencia a `04_transformaciones`), `justificacion`,
`referencia_bibliografica`. Los cinco benchmarks se declaran ahí **antes** de la primera
corrida: es el registro que hace comprobable que la especificación precedió al resultado.

## 5. Modelos de referencia (senda §6.1)

Los seis se reestiman en cada origen sobre `y = log` del objetivo, muestra `[inicio, o]`:

| `modelo_id` | Especificación | Pronóstico a `h` |
|---|---|---|
| `BENCH.RW_SIN_DERIVA` | ninguno | `ŷ_{o+h} = y_o` |
| `BENCH.RW_CON_DERIVA` | deriva `δ = media(Δy)` en la muestra | `ŷ_{o+h} = y_o + h·δ` |
| `BENCH.AR1` | AR(1) sobre `Δy` con constante, MCO | recursión a 8 pasos, acumulada a nivel |
| `BENCH.ARP_BIC` | AR(p) sobre `Δy`, `p ∈ 0..8` por BIC en la **misma** submuestra para todos los `p` (la trampa que Fase 3 documentó en `urca`: la grilla arranca en 0 y la muestra de comparación es común). El `p` elegido se **reestima con la muestra máxima**, descartando solo las `p` observaciones que sus rezagos exigen (decisión de Harold, 2026-09-24: la muestra común sirve para comparar, no para estimar) | recursión a 8 pasos |
| `BENCH.MEDIA_CRECIMIENTO` | media histórica de la tasa interanual `yoy` | `yoy` constante; el nivel se deriva de la base observada o pronosticada según `h` |
| `BENCH.ETS` | `fable::ETS(y ~ error("A") + trend("A") + season("N"))`, sin selección automática (el objetivo es SA, así que no lleva componente estacional) | sendero de 8 pasos |

`BENCH.RW_SIN_DERIVA` es el denominador del RMSE relativo (F4-07). Ninguno de los seis
requiere paquetes fuera de `Imports` **[verificado]**: `fable` y `tsibble` ya están
fijados.

Nota de diseño: `BENCH.MEDIA_CRECIMIENTO` es el único cuya representación natural es la tasa
interanual, no el log-nivel; el contrato exige que devuelva log-nivel, así que su
implementación hace explícito con qué base lo compone —observada para `h ≤ 4`, pronosticada
para `h = 8`— que es la asimetría de F4-04.

## 6. Verificación sobre datos sintéticos

`verificar_motor_sintetico.R` es el artefacto que cierra Fase 4. Corre sin L3, con semilla
fija, y cada bloque falla con `stop()`:

| Código | Qué verifica | Criterio |
|---|---|---|
| V1 | **Aritmética de orígenes.** Serie sintética trimestral de 145 observaciones con las mismas fechas que el objetivo. | El motor produce exactamente 52 / 51 / 49 / 45 pares evaluados para h = 1, 2, 4, 8 (F4-01, convención A) |
| V2 | **Pronóstico del modelo verdadero.** DGP AR(1) en `Δy` con `φ` conocido. | El sendero de `predecir()` coincide con `φ^h·Δy_o` acumulado, a tolerancia `1e-10`, cuando se le pasan los coeficientes verdaderos |
| V3 | **RMSE teórico.** 2000 réplicas del mismo AR(1) en `Δy`. | RMSE(h) del log-nivel simulado dentro de ±3 errores de Monte Carlo de `σ·sqrt(Σ_{k=0}^{h−1} ((1−φ^{k+1})/(1−φ))²)`; para el paseo aleatorio, de `σ·sqrt(h)`. (Corregido el 2026-09-24: la fórmula anterior, `σ·sqrt((1−φ^{2h})/(1−φ²))`, es la de pronosticar una serie AR(1) en sí misma, no el log-nivel acumulado de un AR(1) en diferencias.) |
| V4 | **Ordenamiento correcto.** Un DGP AR(1) fuerte. | El AR(p) por BIC bate al paseo aleatorio, y el paseo aleatorio bate al AR(p) cuando el DGP *es* un paseo aleatorio. Un motor con el signo del error invertido falla acá |
| V5 | **Canario de filtración.** Un modelo de prueba que busca en su insumo los períodos posteriores al origen. | Con un recorte correcto no los encuentra, devuelve NA y el motor **falla** con G-3. G-1 se prueba sobre una serie sin recortar. Si el canario lograra RMSE ≈ 0, el motor estaría roto |
| V6 | **Canario de mutación.** Un modelo que modifica su insumo. | El estado maestro y el insumo que ven los modelos siguientes quedan intactos. En R un `data.frame` se copia al modificarse, así que el bloque certifica esa inmunidad en vez de esperar un fallo; G-2 queda como vigilancia (corregido el 2026-09-24) |
| V7 | **Tamaño de DM/HLN.** Dos modelos con pérdidas intercambiables, 2000 réplicas, `n` igual al de cada grupo y horizonte (52, 45, 25 y sus derivados) | **Revisado 2026-09-24 (F4-18):** en h = 1, 2, tasa de rechazo al 5% bajo la cota binomial superior del 99% (0,063); en h = 4, 8 la tasa se reporta. Errores MA(h−1). El contraste sin HLN se hizo en la exploración previa (sobre-rechazo de hasta 0,40) y no se repite en el bloque |
| V8 | **Potencia de DM/HLN.** Un modelo con pérdida 20% menor. | Potencia reportada por `n` y `h`; no hay criterio de aprobación, es la cifra que dice si el ejercicio puede distinguir algo — sobre todo en G3 con 18 pares |
| V9 | **Cobertura del MCS.** Seis modelos, uno con pérdida 20% menor, en (n, h) = (52, 1), (45, 8), (18, 8); 200 réplicas y B = 500 para que corra en CI (revisado 2026-09-24: la versión anterior pedía diez modelos y 1000 réplicas). | El dominante pertenece al MCS con frecuencia ≥ 1−α menos 2 errores de Monte Carlo en todas las celdas; con seis modelos equivalentes, el MCS completo con la misma cota en h = 1 y reportado en h = 8 (F4-18) |
| V10 | **Reproducibilidad.** Dos corridas completas con la misma semilla. | `sha256` idéntico de los cuatro CSV de salida |
| V11 | **Oráculo externo.** `MCS` 0.2.0 fijado en `renv.lock` (Suggests). El paquete remuestrea con bloques móviles fijos y el motor con bootstrap estacionario, así que se compara con las **mismas remuestras**: los índices del paquete se reconstruyen con su semilla y se pasan a `mcs_tmax(indices = )`. | `p_mcs` idéntico a tolerancia `1e-12` con 6 y con 4 modelos; `skip` si el paquete no está (F4-12) |

V5 y V6 son el corazón: prueban que el motor detecta la filtración en vez de suponer que no
la hay. **Límite que ningún bloque cierra:** un modelo que capture datos completos en su
clausura (una variable global, un entorno) evade el recorte sin que ninguna guarda lo vea. El
contrato lo prohíbe, y se controla en revisión de código, no en tiempo de ejecución. Es el mismo patrón que Fase 3 adoptó con `.verificar_contra_urca()`: la duplicación
queda comprobada, no asumida.

## 7. Targets del Makefile

```make
# Fase 4 — verificacion del motor sobre datos sinteticos. NO lee data/L3_master/, asi que
# corre en CI: es la evidencia del criterio de cierre de Fase 4.
eval-sintetico:
	Rscript src/evaluacion/verificar_motor_sintetico.R

# Fase 4/5 — motor de evaluacion. Exige L3 materializada; la verificacion sintetica es
# prerrequisito y se corre primero para fallar barato.
eval: eval-sintetico
	Rscript src/evaluacion/motor_backtesting.R
```

`.github/workflows/` gana `eval-sintetico` en el mismo job que `validate-and-test`. Con eso,
el criterio de cierre de Fase 4 tiene evidencia de CI (patrón de los cierres de Fase 0 y 1)
en vez de solo un archivo de evidencia textual.

## 8. Pruebas unitarias

`tests/test-evaluacion.R` — sobre `eval_lib.R`, sin datos del proyecto:

- aritmética de orígenes para las cuatro combinaciones de la tabla de F4-01 (las dos
  convenciones y sus variantes), como prueba de regresión de la decisión tomada;
- recorte al conjunto de información con el calendario de rezagos: para un origen dado,
  IVAE llega hasta el primer mes del trimestre siguiente y remesas hasta el segundo; el tercer mes no está nunca (F4-02);
- métricas contra casos calculados a mano (RMSE de un vector conocido, sesgo, `rmse_relativo`
  = 1 cuando el modelo es el benchmark);
- DM/HLN contra un caso publicado y contra la degeneración conocida (pérdidas idénticas →
  estadístico 0, `p = 1`);
- gramática del token de `esquema_validacion`: acepta el token canónico, rechaza el que
  omite `grupo` o trae un valor no declarado;
- conversión log-nivel → interanual → trimestral, ida y vuelta.

`tests/test-modelos-referencia.R` — cada benchmark sobre una serie construida:
`RW_SIN_DERIVA` devuelve el último valor ocho veces; `RW_CON_DERIVA` sobre una serie
exactamente lineal en logs devuelve la extrapolación exacta; `ARP_BIC` sobre ruido blanco
elige `p = 0`.

## 9. Orden de implementación sugerido

1. `eval_lib.R` (aritmética, recorte, métricas) + sus pruebas. No depende de ninguna
   decisión pendiente salvo F4-01.
2. `modelos_referencia.R` + pruebas. Depende de F4-04 solo para el reporte, no para el
   cómputo.
3. `verificar_motor_sintetico.R` V1-V6, V10. Cierra la mitad mecánica del criterio.
4. DM/HLN, GW y MCS en `eval_lib.R` + V7-V9, V11. Depende de F4-12. **Hecho** (PR #13; parámetros en F4-15 a F4-18).
5. `motor_backtesting.R` sobre L3 y la primera corrida de benchmarks. Depende de F4-03,
   F4-05 y F4-09. **Implementado** con F4-19 a F4-22: cinco experimentos declarados en el script
   (`F4_BENCH_G1`, `_G2`, `_G3` con ajuste por origen; `F4_BENCH_G2_R5` y `_G3_R5` con el objetivo
   oficial).
6. Batería R1-R4 y R6 y filas en `07_experimentos.csv`. **Implementado** con F4-25 a F4-29: trece
   experimentos (R1 en G1-G3, R2 en G2-G3, R6 en G1-G3; R3 y R4 como submuestras de la principal).
   Quedan la evidencia textual y el cierre.

Los pasos 1-4 no necesitan datos y pueden escribirse mientras las decisiones del tablero
están abiertas; el paso 5 no debe empezar antes de F4-09, que es la que decide si el ajuste
estacional vive dentro del bucle.
