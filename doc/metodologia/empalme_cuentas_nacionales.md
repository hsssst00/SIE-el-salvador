# Nota metodológica: empalme de cuentas nacionales

**Decisión registrada en:** `doc/adr/ADR-003-empalme-cuentas-nacionales.md`

## Resumen

La serie de PIB trimestral utilizada cubre 1990-T1 a 2026-T1 (145 observaciones), combinando:

- Serie retropolada oficial del BCR: 1990-T1 a 2005-T4 (64 obs), declarada por el BCR como "serie homogénea, retropolada".
- Compilación nativa bajo SCN 2008: 2005-T1 a 2026-T1 (85 obs).
- Superposición de 4 trimestres (2005-T1 a 2005-T4) entre ambas.

No se realizó empalme propio — la retropolación oficial del BCR se adopta tal cual.

## Pendiente (Fase 1, no bloqueante)

- [ ] Localizar y citar la nota metodológica específica del BCR que documenta el método de retropolación utilizado.
- [ ] Confirmar si la superposición de 4 trimestres corresponde a un período de calibración/validación documentado por el BCR, o si es una coincidencia de publicación.
- [ ] Registrar el número de observaciones al momento de cada actualización trimestral (crece con el tiempo).
