# Nota metodológica: tratamiento del shock de 2020

**Decisión registrada en:** `doc/adr/ADR-004-shock-2020.md`

## Resumen

Estrategia principal: outlier aditivo/transitorio tratado en la fase de ajuste estacional (X-13ARIMA-SEATS, paquete `seasonal`), con las fechas detectadas trasplantadas como variables dicotómicas declaradas a la estimación sobre la serie oficial. Estrategia de robustez: contraste de estabilidad en dos submuestras (pre/post 2020).

## Pendiente (Fase 3, al implementar)

- [ ] Documentar las fechas exactas de outlier detectadas por `seasonal` una vez corrido el ajuste propio.
- [ ] Reportar el resultado del contraste de submuestras como parte del entregable de Fase 5.
- [ ] Cruzar referencia con `catalogos/09_rupturas.csv` para los demás quiebres candidatos (dolarización 2001, terremotos 2001, CAFTA-DR, crisis 2008-2009, bitcoin 2021).
