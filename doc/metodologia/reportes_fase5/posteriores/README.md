# Análisis posteriores de Fase 5 (AP-1 a AP-4): informe consolidado

**Análisis posteriores a los resultados.** Los pidió Harold el 2026-10-15, después de `v0.8.1-fase5` y antes de Fase
6 (registro en `doc/metodologia/decisiones_fase5.md`, «Análisis posteriores»). Ninguno cambia un modelo, un YAML, un
experimento, la tabla de resultados ni el MCS de Fase 5, y ninguno mueve un tag. Ninguno elige un modelo para Fase
6: lo que sigue entra a las fichas de Fase 6 como evidencia.

Todo se corrió en R (ADR-009) sobre la L4 de la corrida citada (`e1722fa`) y el corte `corte_fase5.csv`, en la
máquina de Harold (R 4.6.1, BLAS/LAPACK de referencia). Antes de usar los errores, cada script comprueba que
reproducen la L4 o sus métricas.

| Código | Informe | Script | Hallazgo principal |
|---|---|---|---|
| AP-1 | `ap1_explosivos.md` | `src/analisis_posterior/ap1_explosivos.R` | Los dos pronósticos explosivos reproducen la L4 (dif. ~1e-15): **no hay error de implementación**. El ENET (G3, 2021-Q1) es de especificación y selección: el choque de 2020 queda en la fila del origen a 33 desviaciones de la ventana, y la validación anidada, con un ECM casi plano, elige el extremo menos penalizado. El BVAR (G3, 2020-Q2) es de especificación del pronóstico puntual: la media de la predictiva la dominan extracciones explosivas (mediana +5,3 pp, media −126 pp). Todo lo que pasa el doble del máximo histórico tiene el choque de 2020 en el origen |
| AP-2 (descriptivo) | `ap2_estabilidad_puente.md` | `src/analisis_posterior/ap2_estabilidad_puente.R` | Con h = 1, la ventaja de `MIX.PUENTE` es sobre todo de 2020-2021: en 2022-2026 cae a los puestos 22/23, 14/22 y 13/21. Con h = 4 es más estable; con h = 8 no es primero en ninguna ventana. No es independiente |
| AP-2 (prospectiva) | `../../protocolo_prospectiva_ap2.md` | pendiente (§6 del protocolo) | Reglas preregistradas antes del primer target (2026-Q3); lectura primaria con 20 targets |
| AP-3 | `ap3_tamano.md` | `src/analisis_posterior/ap3_tamano.R` | GW y el contraste de estabilidad tienen tamaño correcto con h = 1, y sobre-rechazan con h ≥ 2: hasta 0,72 al 5 % (GW, G3, h = 8). Ficha AP3-1 pendiente; se recomienda restringir su uso a h = 1 |
| AP-4 | `ap4_familias.md` | `src/analisis_posterior/ap4_familias.R` | Con h ≤ 4, MIX tiene el menor RMSE y CRPS de familia, pero sin los targets de 2020-2021 su ventaja en h = 1 desaparece. Con h = 8 las familias quedan juntas. El MCS de los 7 representantes (fijados antes de calcularlo) los conserva a todos en las 12 celdas (p mínimo 0,121) |

## Lo que queda abierto

- **Ficha AP3-1** (uso de GW y del contraste de estabilidad con h ≥ 2): la decide Harold.
- **Implementación de la prospectiva** y tag `prospectiva-v1`, antes de que se publique el PIB de 2026-T3.
- **La verificación sintética V12-V21 no se corrió en la sesión de estos análisis.** El X-13 falla con rutas
  temporales largas en el sandbox; con un TMPDIR corto funciona. V1-V11 dieron las líneas de la evidencia de Fase 4
  byte a byte, y CI corre V1-V21 en cada PR.

## Lo que estos análisis no permiten concluir

- Que una familia o un modelo sea mejor: ni el MCS de Fase 5 ni el de representantes distinguen, y el ordenamiento
  descriptivo cambia al sacar 2020-2021.
- Que otra especificación del ENET o del BVAR habría ganado en Fase 5: no se corrió ninguna alternativa.
- Que la ventaja del puente se mantenga fuera de la muestra: eso lo dirá la lectura primaria de la prospectiva.
