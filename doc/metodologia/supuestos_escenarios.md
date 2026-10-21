# Nota metodológica: supuestos de escenarios exógenos (Ejercicio B)

**Decisión registrada en:** `doc/adr/ADR-002-horizonte-y-diseno.md`

**Estado (2026-10-21): borrador en curso; lo completa F1 del `doc/checklist_fase6.md`.** El «Resumen» y el
«Pendiente» de abajo son el texto original de ADR-002 y se conservan como registro. Lo vigente está en las notas
fechadas que siguen, en este orden: la del 2026-10-19 (F6-14 a F6-18) corrige a la del 2026-10-17 (F6-03 y F6-05), y
esta corrige al «Resumen» en dos puntos: la Fed no se usa, y la CBO quedó capturada pero sin uso en Fase 6 (F6-05-a,
F6-15).

## Resumen

Fuente híbrida: FMI WEO para variables globales/regionales; proyecciones de la Reserva Federal / BEA / CBO para variables relacionadas con Estados Unidos (actividad económica, insumo del supuesto de remesas).

**Nota de coherencia obligatoria:** no se garantiza consistencia interna perfecta entre las dos fuentes combinadas — debe declararse explícitamente en el documento final de supuestos (Fase 6).

## Pendiente (Fase 6, al implementar)

- [x] Fijar las publicaciones específicas de WEO y Fed/BEA/CBO a usar como fuente para cada escenario. — F6-05 y
  F6-15; capturadas en L0 con sha256 por C2 y C2b (checklist de Fase 6, 2026-10-19).
- [x] Definir 2-3 escenarios explícitos con supuestos citados. — base, adverso (C) y favorable (A), F6-05 y F6-14.
  Los supuestos citados con vintage y sha256 los reúne F1.
- [ ] Análisis de sensibilidad a los supuestos. — F6-09, aún sin implementar (D6).

## Nota (2026-10-17, F6-03 y F6-05)

Las publicaciones quedan fijadas en `doc/metodologia/decisiones_fase6.md` (F6-05, con el detalle F6-05-a delegado al
agente). Las casillas de arriba no se marcan hasta que los supuestos estén capturados en L0 con su sha256.

- **Base:** FMI, *World Economic Outlook* de octubre de 2026 (publicado el 2026-10-12), para las variables globales y
  el PIB de EE. UU.; CBO, proyecciones económicas vigentes al congelar, para el empleo de EE. UU. El SEP de la Fed no
  se usa.
- **Adverso:** un escenario de riesgo del capítulo 1 del mismo WEO, si publica magnitudes cuantitativas utilizables
  (ficha F6-14, abierta).
- **Favorable:** solo si aparece una fuente que lo publique.
- **Sensibilidad:** F6-09.
- **Cómo llegan los supuestos a los modelos:** por ecuaciones satélite, una por predictora externa (remesas, FOB,
  IPM e IPP, ITCER; F6-03). IVAE y UT no se condicionan. Las satélite son modelos nuevos que el Ejercicio A no evaluó,
  y este documento debe declararlo junto con la nota de coherencia de arriba.

El método completo está en `doc/metodologia/protocolo_proyeccion.md`.

## Nota (2026-10-19, F6-14 a F6-18)

Las fichas F6-14 a F6-18 de `doc/metodologia/decisiones_fase6.md` completan lo que la nota anterior dejaba abierto.

- **Base:** WEO de octubre de 2026 para el PIB de EE. UU., la inflación de EE. UU. y el precio del petróleo. La CBO
  quedó capturada y sin uso; el empleo de EE. UU. y el comercio mundial no se usan (F6-15).
- **Adverso:** escenario C («Market Correction») del recuadro 1.2 del capítulo 1, con sus desvíos anuales del PIB y
  de la inflación de EE. UU. El petróleo queda en la base (F6-14).
- **Favorable:** escenario A («Strong Payoffs») del mismo recuadro, con la misma traducción (F6-05, nota del
  2026-10-19).
- **De anual a trimestral:** Denton-Cholette con los trimestres observados fijos (F6-16).
- **Inconsistencias que se declaran:** el adverso y el favorable vienen de un modelo del FMI (GIMF) distinto del que
  arma la base; con C y con A el petróleo no se mueve; y las remesas nominales y reales tienen satélites separadas
  (F6-15-b).
