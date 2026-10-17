# Nota metodológica: supuestos de escenarios exógenos (Ejercicio B)

**Decisión registrada en:** `doc/adr/ADR-002-horizonte-y-diseno.md`

## Resumen

Fuente híbrida: FMI WEO para variables globales/regionales; proyecciones de la Reserva Federal / BEA / CBO para variables relacionadas con Estados Unidos (actividad económica, insumo del supuesto de remesas).

**Nota de coherencia obligatoria:** no se garantiza consistencia interna perfecta entre las dos fuentes combinadas — debe declararse explícitamente en el documento final de supuestos (Fase 6).

## Pendiente (Fase 6, al implementar)

- [ ] Fijar las publicaciones específicas de WEO y Fed/BEA/CBO a usar como fuente para cada escenario.
- [ ] Definir 2-3 escenarios explícitos con supuestos citados.
- [ ] Análisis de sensibilidad a los supuestos.

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
