# Protocolo de proyección condicional (Ejercicio B)

**Estado:** borrador v0.2 del 2026-10-19 (v0.1 del 2026-10-17). Aplica las decisiones F6-01 a F6-18 de
`doc/metodologia/decisiones_fase6.md`; la v0.2 cerró las secciones que la v0.1 marcaba **[abierto]** (F6-14 a
F6-18). El protocolo se congela con commit en el ítem E1 de `doc/checklist_fase6.md`, antes de la primera
proyección sobre datos reales; después, cualquier cambio entra como nota fechada.
**Alcance:** Ejercicio B de la senda metodológica §1.3, proyección condicional del PIB trimestral de El Salvador a
2030, con h = 1 a 20. El Ejercicio A se rige por `protocolo_evaluacion.md`, cuyo §7 lo deja fuera.

## 1. Qué produce este ejercicio

Senderos del PIB trimestral SA condicionales a escenarios exógenos declarados, por grupo de predictoras (G1, G2 y
G3, F4-05) y por escenario, con intervalos, análisis de sensibilidad y una lista de coherencia interna. **Todas las
cifras de 2026 a 2031 son condicionales a sus supuestos y no son pronósticos incondicionales.** Así lo exige el
criterio de cierre de la senda §4, y cada tabla y figura del informe lo dice.

El ejercicio no es validable (senda §1.3): no hay errores fuera de muestra con h > 8 ni en el futuro. Lo que
reemplaza a la validación es la coherencia interna (§9).

## 2. Corte, origen y horizonte (F6-04)

- Corte `doc/metodologia/corte_fase6.csv`, congelado como en F5-16, con el último vintage publicado al congelar.
- Origen `o`: el último trimestre con PIB observado en el corte (hoy 2026-Q2; 2026-Q3 si se publica antes del
  congelamiento, F6-04-a).
- h = 1 a 20. `DISENO_FASE6` fija `h_max = 20`; `DISENO_FASE4` no cambia.
- Cada modelo se estima una sola vez, en `o`, con su YAML de Fase 5 sin cambios y la muestra que ese YAML declara.
  El ajuste estacional del objetivo sigue el §8 del protocolo de evaluación.

## 3. Modelos (F6-01, F6-13)

| Clase | Modelos | Rol |
|---|---|---|
| Condicionables | `UNI.ARIMAX.G1-G3`, `MULT.VAR_DIF.G1-G3`, `MULT.VAR_NIV.G1`, `MULT.VECM.G1`, `MULT.BVAR.G1-G3`, `MIX.PUENTE.G1-G3` | Entran a la combinación de su grupo |
| Sin escenario | benchmarks, `UNI.ARIMA`, `UNI.UC_LLT`, `UNI.ARIMAX_IVAE.G2` | Se reportan como «trayectoria sin escenario» |
| Fuera | `REG.*`, `ML.*`, `MIX.UMIDAS.*`, `COMB.*` | No proyectan en el Ejercicio B |

El sendero puntual de cada modelo es su media de pronóstico, salvo en el BVAR, que usa la mediana de la predictiva
posterior (F6-13). Antes de proyectar se mide el BVAR como dice F6-13 (d) y las cifras van a la evidencia del
preregistro.

## 4. Escenarios y fuentes (F6-05)

| Escenario | Fuente | Variables |
|---|---|---|
| Base | FMI, WEO de octubre de 2026 (base de datos) | PIB de EE. UU. (`USA.NGDP_RPCH`), inflación de EE. UU. (`USA.PCPIPCH`), petróleo (`G001.POILAPSP`) |
| Adverso | FMI, WEO de octubre de 2026, capítulo 1, recuadro 1.2, escenario C (F6-14) | PIB e inflación de EE. UU. en desvío de la base; el petróleo queda en la base |
| Favorable | el mismo recuadro, escenario A (F6-05, nota del 2026-10-19) | igual que el adverso |
| Sensibilidad | las mismas de la base | §8 |

- Cada fuente entra a L0 como vintage inmutable, con su sha256 en el manifiesto, por un *script* de
  `src/adquisicion/` (regla 1 de `CLAUDE.md`), antes de congelar.
- Condiciones de uso: FMI según su tramo de ADR-008 (*script* y *checksum*). La CBO quedó capturada y sin uso
  (F6-15); el comercio mundial y el empleo de EE. UU. no se usan.
- La combinación de fuentes no garantiza consistencia interna perfecta (ADR-002). `supuestos_escenarios.md` lo
  declara.
- Paso de anuales a trimestrales (F6-16): metas anuales encadenadas con los crecimientos del WEO desde el último año
  completo de la historia trimestral, y Denton-Cholette con los trimestres completos observados fijos, hasta 2031-T4.
  La traducción de los desvíos del adverso y del favorable está en F6-14.

## 5. Ecuaciones satélite (F6-03)

Una satélite por predictora externa (F6-15): remesas nominales y reales y FOB sobre el PIB de EE. UU., ITCER sobre
el IPC de EE. UU., IPM e IPP sobre el petróleo. Cada una vincula la predictora del modelo, en
su unidad de Fase 5 (Δlog, con dummies si es NSA, F4-06), con una variable de escenario. IVAE y UT no se
condicionan.

- Se especifican con las reglas de Fase 5: muestra hasta `o`, criterio de información, YAML en `catalogos/06_modelos/`
  antes de correr. Forma (F6-15): Δlog X_t sobre constante, dummies T2..T4, p rezagos propios y Δlog Z de t a t − q,
  con p y q en 0..4 por BIC y el término contemporáneo siempre; sin las filas de 2020 y 2021; una satélite común a
  los tres grupos.
- El sendero de cada predictora externa es la media de su satélite dado el sendero del escenario. La varianza del
  error de la satélite entra a la densidad del modelo que la recibe por varianza total, Σ_y + J Σ_X J' (F6-15-a).
- Las variables de escenario entran a L3 por el circuito de Fase 3 como series `ESC.*` por escenario, con rol
  `escenario` y validación con `stop()` (F6-18). Los senderos de la sensibilidad se arman en L4 (F6-18-c).

## 6. Condicionamiento (F6-06)

Condicionamiento duro: el sendero de cada predictora externa se trata como conocido.

- **ARIMAX y puente:** el sendero reemplaza a la proyección AR de la predictora. La densidad es la del error ARMA
  del modelo más la varianza que aporta la satélite (§5). Borde del puente (F6-17): en o+1 manda el dato
  observado (los meses que faltan, con el AR mensual de Fase 5); desde el primer trimestre sin meses observados, el
  agregado trimestral de la satélite. IVAE y UT siguen con su AR mensual hasta o+20. En todos los modelos, un
  trimestre completo observado después de `o` entra como dato (F6-17-a).
- **VAR, VECM y BVAR:** distribución normal del vector apilado de pronósticos (variables × h) condicionada a que las
  componentes de las predictoras externas igualen su sendero. En el BVAR, por extracción, con los momentos de B2-10.
  Las variables internas (PIB, IVAE, UT) responden (F6-06-a).
- **Contrato:** campo opcional `predecir_condicional(ajuste, h, senderos_x)` del contrato de modelo, que devuelve
  el sendero del objetivo y su densidad (lo que hoy dan `predecir` y `predecir_densidad`) con h = 1..20. Un modelo
  sin ese campo no es condicionable. `.validar_modelo()` lo comprueba como a `predecir_densidad`.

## 7. Combinación, intervalos y guarda (F6-02, F6-07, F6-08)

1. **Guarda.** Rango permitido del interanual (100 · Δ₄ log del PIB SA propio): `[mín − X, máx + X]`, con mínimo,
   máximo y X = una desviación estándar calculados en L3 de `corte_fase6`, sin los períodos de 2020 y 2021. Se
   escribe en el YAML de Fase 6 al congelar. Un modelo cuyo sendero puntual sale del rango en algún h sale de la
   combinación de ese grupo y escenario; se reporta marcado y la exclusión va al manifiesto.
2. **Mínimo.** Si en un grupo y escenario quedan menos de 3 miembros, `stop()`.
3. **Combinación.** Mediana trimestre a trimestre de los Δy de los miembros que pasan la guarda; el nivel se
   acumula desde el último dato observado.
4. **Intervalos.** Por modelo, de su densidad condicional. Para la combinación, mezcla con pesos iguales de las
   densidades de los miembros. Bandas del 80 y del 95 %; con h > 8, marca «sin calibrar». La mezcla no se recentra
   en la mediana (F6-07-a).

## 8. Sensibilidad (F6-09)

Uno a la vez, sobre la base: cada variable de escenario se desplaza ±1 desviación estándar de su crecimiento anual
(calculada en L3 sin 2020-2021) en cada año proyectado, con las demás en la base. Se reporta el cambio en el nivel
del PIB de 2030 y en el crecimiento promedio 2026-2030, por grupo, para la combinación y para cada miembro.

## 9. Coherencia interna (F6-10)

1. **Con `stop()`:** agregación trimestral → anual consistente (F6-10-a).
2. **Informativas:** crecimiento anual de la base frente al del PIB de El Salvador en el WEO; promedio 2026-2030
   frente al histórico con y sin 2020; signo de la respuesta a cada variable de escenario en §8; deflactor implícito
   de las remesas (nominales / reales) en el sendero frente a su rango histórico.

*Nota (2026-10-22, decisión de Harold):* la identidad de las remesas (reales = nominales / deflactor de ADR-010)
estaba en las de `stop()`. Pasó a las informativas porque las dos remesas tienen satélites independientes
(F6-15-b) y el deflactor no tiene sendero de escenario. Detalle en la nota de F6-10.

## 10. Reporte (F6-11)

- Cifra principal: crecimiento anual 2026-2030, con el promedio del año calendario de los niveles trimestrales SA.
  El año del origen se marca porque mezcla trimestres observados. 2031 solo en trimestres (F6-11-a).
- Además: interanual trimestral y nivel índice, por grupo, escenario y modelo; la trayectoria sin escenario aparte.
- Toda tabla lleva «condicional a los supuestos de `supuestos_escenarios.md`» y, para h > 8, la marca «sin
  calibrar».

## 11. Preregistro, corrida y reproducibilidad (F6-12)

- Se congelan con commit, antes de la primera proyección sobre datos reales: el corte, los supuestos en L0, los YAML
  de las satélite y de Fase 6, la regla de §7, la guarda y la lista de §9.
- Canarios sintéticos en CI antes del congelamiento: **V22** (el condicional reproduce el sendero impuesto y la
  media y covarianza condicionales analíticas en un DGP conocido) y **V23** (la guarda excluye un modelo explosivo
  sintético y el mínimo de miembros dispara `stop()`). CI comprueba además que los `F5_REPRO_*` siguen bit a bit.
- Una sola corrida, con `make fase6`, sobre un árbol limpio. Si se detiene, se asienta qué escribió, como en el
  protocolo de evaluación §6.
- Reproducción bit a bit en la máquina de Harold con la BLAS de referencia; fuera de Windows rige lo declarado para
  el BVAR en F1-3 de Fase 5.
- Salidas en `data/L4_experiments/F6_*/` con manifiesto, y una fila por (experimento, modelo) en
  `catalogos/07_experimentos.csv` (F4-25).

## 12. Lo que este protocolo no cubre

- Evaluar la precisión de las proyecciones: eso es la prospectiva de AP-2, que tiene su propio protocolo.
- Escenarios sin fuente publicada.
- Modelos nuevos para el PIB: las satélite modelan predictoras, no el objetivo.
