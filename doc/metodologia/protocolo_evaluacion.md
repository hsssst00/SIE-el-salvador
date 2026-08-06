# Nota metodológica: protocolo de evaluación predictiva

**Decisión registrada en:** `doc/adr/ADR-002-horizonte-y-diseno.md`

## Resumen

- Horizontes: h = 1, 2, 4, 8 trimestres, reportados por separado.
- Ventana de estimación inicial: 1990-T1 a 2012-T4 (92 observaciones).
- Evaluación pseudo-fuera-de-muestra: desde 2013-T1, ventana expansiva con reestimación en cada origen.
- Número de reestimaciones: 52.
- Orígenes evaluables por horizonte: h=1 → 52; h=2 → 51; h=4 → 49; h=8 → 45.

## Pendiente (Fase 4, al implementar el motor de backtesting)

- [ ] Verificar el motor de evaluación contra datos sintéticos antes de correr cualquier modelo real (criterio de cierre de Fase 4 — no negociable).
- [ ] Documentar la grilla de búsqueda de hiperparámetros y el criterio de selección para la validación anidada (§5.2 de la senda metodológica).
