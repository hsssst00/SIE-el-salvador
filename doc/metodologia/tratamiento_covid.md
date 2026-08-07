# Nota metodológica: tratamiento del shock de 2020

**Decisión registrada en:** `doc/adr/ADR-004-shock-2020.md` (mecanismo enmendado el 2026-08-07 tras enmienda de `doc/adr/ADR-001-variable-objetivo.md`)

## Resumen

Estrategia principal: outlier aditivo/transitorio tratado en la fase de ajuste estacional (X-13ARIMA-SEATS, paquete `seasonal`), aplicada directamente sobre la serie que constituye la variable objetivo primaria — el ajuste propio sobre la concatenación de las series NSA (retropolado 1990–2005 + compilación nativa 2005–2026), conforme a la enmienda de ADR-001 (2026-08-07). Las fechas de outlier detectadas quedan declaradas como variables dicotómicas dentro de esa misma fase, sin trasplante a una serie distinta. La serie oficial SA del BCR (2005–2026), en su rol de verificación de robustez, se contrasta contra la serie ya tratada en el tramo de superposición; no recibe tratamiento de outlier propio de este proyecto. Estrategia de robustez: contraste de estabilidad en dos submuestras (pre/post 2020).

## Pendiente (Fase 3, al implementar)

- [ ] Documentar las fechas exactas de outlier detectadas por `seasonal` una vez corrido el ajuste propio.
- [ ] Reportar el resultado del contraste de submuestras como parte del entregable de Fase 5.
- [ ] Cruzar referencia con `catalogos/09_rupturas.csv` para los demás quiebres candidatos (dolarización 2001, terremotos 2001, CAFTA-DR, crisis 2008-2009, bitcoin 2021).
