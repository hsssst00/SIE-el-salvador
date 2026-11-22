# Checklist de Fase 7 — Documentación, publicación y sostenibilidad

**Fecha de apertura:** 2026-11-20 · **Fase 6 cerrada:** tags `v0.9.0-fase6` (`04dbc3c`) y `v0.9.1-fase6` (`0634301`)
**Criterio de cierre (senda §4):** *un investigador externo puede actualizar el sistema con la publicación del
trimestre siguiente siguiendo únicamente el manual.*
**Entregables (senda §4):** repositorio público completo; manual de usuario; sitio de documentación; DOI.

Convención de este tablero, igual que en Fases 3 a 6: una actividad se marca `[x]` solo cuando su evidencia está
asentada (corrida de CI, archivo de evidencia textual o entrada en `doc/bitacora_verificaciones.md`), y la evidencia
se cita en la propia línea. Las decisiones viven en `doc/metodologia/decisiones_fase7.md`. Una actividad que depende
de una ficha todavía no decidida lo dice y no se marca.

---

## A. Compuerta de entrada

- [x] **A1** Fase 6 cerrada y su auditoría remediada. — `v0.9.0-fase6` (`04dbc3c`) y `v0.9.1-fase6` (`0634301`, merge
  del PR #106); CI run 44804099609 en verde.

## B. Decisiones

- [x] **B1 · F7-02, F7-03** Lecturas del trimestre siguiente y del alcance de la actualización. — Harold, 2026-11-20.
- [x] **B2 · F7-05 a F7-12** Forma de los entregables y proceso. — Harold, 2026-11-20.
- [ ] **B3 · F7-01** Quién es el investigador externo. Abierta: depende de conseguir a la persona.
- [ ] **B4 · F7-04** Cómo obtiene L0. Abierta: depende de B3 y de la lectura de ADR-008 que haga Harold.

## C. Ensayo con el 2026-T2 (F7-02, primer tiempo)

- [x] **C1** Borrador de `doc/manual_actualizacion.md` con las secciones del esqueleto de apertura. — este commit; no
  congelado (el congelamiento es G1).
- [ ] **C2** Llevar la L3 vigente de 2026-Q1 a 2026-Q2 siguiendo solo el borrador (`make validate`, `make master`,
  `make trace` con su entrada en la bitácora, pruebas). Lo corre Harold en su PC, con L0 materializada.
- [ ] **C3** Referencia versionada del sha256 de cada archivo de `data/L3_master/` vigente, para que la sección 4 del
  manual pueda comparar contra algo (hueco del esqueleto).
- [x] **C5 · F7-13** Captura fuera de ventana asistida: `planear_d3()` y `capturar_d3()` (antes `captura_d3()`), sus pruebas y las
  notas de ADR-007. — este
  commit; `tests/test-captura-d3.R` (9 pruebas) en verde. Incluye el mapeo del PIB NSA y
  nominal a la fila del SA en el calendario.
- [x] **C6 · F7-14** `make sincronizar-l0`: L0 y almacén en las dos direcciones, con commit y push. — este commit;
  `tests/test-sincronizacion-l0.R`.
- [ ] **C4** Corregir el manual con lo que falló en C2, y dejar la bitácora del ensayo en
  `doc/evidencia_ensayo_fase7.txt`.

## D. Documentación (F7-05)

- [ ] **D1** `doc/manual_usuario.md`.
- [ ] **D2** Puerta de entrada técnica: arquitectura del código (`src/` → `Makefile` → capas).
- [ ] **D3** `doc/diccionario_datos.md` (previsto en §7 de la senda): columnas de L1, L3 y L4.
- [ ] **D4** `manual_usuario.md` en el árbol de §7 de la senda.

## E. Sitio y *vignettes* (F7-06, F7-07)

- [ ] **E1** `_quarto.yml` y `src/reportes/`; `make report` deja de ser un aviso.
- [ ] **E2** *Workflow* de publicación en GitHub Pages, con la versión de Quarto fijada, y nota de seguimiento en
  ADR-009 en el mismo PR.
- [ ] **E3** *Vignette* 1 (catálogos y trazabilidad), que corre en CI.
- [ ] **E4** *Vignette* 2 (consulta bitemporal), con `freeze` sobre L3.
- [ ] **E5** *Vignette* 3 (resultados de Fases 5 y 6 desde las tablas versionadas), que corre en CI.

## F. DOI y versión (F7-08, F7-09)

- [x] **F1** Harold conecta Zenodo con su cuenta de GitHub y activa el repo. — 2026-11-20: *webhook* de `zenodo.org`
  activo para `release` (API de GitHub).
- [x] **F2** `CITATION.cff` con `abstract` y `keywords` (y ORCID y afiliación si Harold los da). — este commit: ORCID,
  `abstract`, `keywords` y `type`, validado contra el esquema de CFF 1.2.0; sin afiliación (Harold no la dio).

## G. Prueba del criterio (F7-01, F7-02, F7-04)

- [ ] **G1** Congelar el manual: tag `manual-v1`. Requiere C4, B3 y B4.
- [ ] **G2** La persona externa actualiza el sistema con el primer PIB trimestral publicado después de G1, siguiendo
  solo el manual. Su bitácora, sin editar, va a `doc/evidencia_cierre_fase7.txt`.

## H. Cierre (F7-09, F7-11)

- [ ] **H1** Nota de cierre de Fase 7 en la senda §4, con las lecturas de F7-01 a F7-04.
- [ ] **H2** «Cierre de Fase 7» en `doc/adr/README.md`; `CITATION.cff` y `DESCRIPTION` en 1.0.0 en el mismo commit.
- [ ] **H3** Tag `v1.0.0-fase7` con CI en verde, y *GitHub Release* (Zenodo mintea el DOI).
- [ ] **H4** DOI de concepto en el `README.md` y en `CITATION.cff`.
- [ ] **H5** Revisión independiente en `doc/auditorias/` (la deposita Harold).

## Fuera de esta fase

- **AP-2** (F7-10): sigue su propio protocolo y su plazo, en PR aparte. El manual la menciona cuando exista
  `prospectiva-v1`.
