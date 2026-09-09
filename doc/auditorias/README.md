# Auditorías y verificaciones independientes

Revisiones del repositorio encargadas por Harold y ejecutadas contra el contenido real del
árbol (no contra resúmenes de sesión ni autorreportes). **No tienen autoridad decisoria:**
identifican hallazgos; lo que decide es el ADR correspondiente. Se conservan sin editar,
incluidos los hallazgos que resultaron equivocados o que se resolvieron de otro modo —
corregir una auditoría a posteriori destruiría justamente lo que la hace útil.

Su función en el repositorio es hacer resolubles las citas por código de hallazgo (`C1`, `I3`,
`M4`…) que aparecen en `CONTRIBUTING.md`, `doc/adr/README.md` y `doc/senda_metodologica.md`.

| Documento | Fecha | Commit auditado | Hallazgos | Dónde se resolvieron |
|---|---|---|---|---|
| `auditoria_fase0_SIE-el-salvador.md` | 2026-08-07 | `6631a251` | 6 C, 6 I, 4 M | Tag `v0.2.1-fase0-enmendado`; ver `doc/adr/README.md`, "Cierre de Fase 0 — revalidado" |
| `auditoria_fase1_SIE-el-salvador.md` | 2026-08-17 | `f7bae345` | I1–I3, M1–M4 | Commit `35c89aa9` |
| `verificacion_remediacion_fase1_SIE-el-salvador.md` | 2026-08-17 | `35c89aa9` / `bde69f68` | C1, I1–I2, M1–M5 | `5dc2a1af` y `6c1d559e` |
| `auditoria_fase2_SIE-el-salvador.md` | 2026-08-28 | `7858a21` | B1–B3, A1, A4, M1–M5, L1–L6 (A2 retirado por falso) | B2, B3, A4, M1–M5, L2, L5 remediados en la misma sesión (commit `e3c810e`); M1 cerrado en `5af9a98`; B1 cerrado el 2026-09-07 — ver `doc/adr/ADR-007-politica-vintages.md`, "Cierre de B1", y `doc/bitacora_verificaciones.md`, entrada 2026-09-07: los 12 archivos nunca se habían perdido, estaban en una segunda máquina de Harold; A1: el defecto de código (cobertura 3/30, `"3/3 PASS"` a mano) está remediado en `e3c810e`; la interpretación del criterio de cierre que A1 tocaba se fijó el 2026-09-09 (Opción B — ver senda §4 "Nota de cierre — lectura de \"verifica su integridad\"" y `doc/adr/README.md`, "Cierre de Fase 2 — en curso"); resta la corrida completa de `make raw` para certificar el cierre |

**Salvedad sobre la de Fase 2.** A diferencia de las tres anteriores, no es independiente: la
ejecutó el mismo agente que aplicó las correcciones, en la misma sesión y sobre el árbol de
trabajo, no sobre un clon fresco. Uno de sus hallazgos (A2) resultó falso y fue retirado tras
verificación adicional; el episodio se conserva documentado dentro del propio informe, conforme
a la regla de esta carpeta.
