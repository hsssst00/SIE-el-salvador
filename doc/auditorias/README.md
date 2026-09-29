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
| `auditoria_fase2_SIE-el-salvador.md` | 2026-08-28 | `7858a21` | B1–B3, A1, A4, M1–M5, L1–L6 (A2 retirado por falso) | B2, B3, A4, M1–M5, L2, L5 remediados en la misma sesión (commit `e3c810e`); M1 cerrado en `5af9a98`; B1 cerrado el 2026-09-07 — ver `doc/adr/ADR-007-politica-vintages.md`, "Cierre de B1", y `doc/bitacora_verificaciones.md`, entrada 2026-09-07: los 12 archivos nunca se habían perdido, estaban en una segunda máquina de Harold; A1 cerrado el 2026-09-09: el defecto de código está remediado en `e3c810e`; la interpretación del criterio de cierre (Opción B) se fijó en senda §4 y la corrida completa de `make raw` que la certifica está en `doc/evidencia_cierre_fase2.txt` (54/54 offline, 13 PASS / 15 CAMBIO / 0 ERROR, salida 0). Ver `doc/adr/README.md`, "Cierre de Fase 2" |
| `auditoria_independiente_fase2_SIE-el-salvador.md` | 2026-09-15 | `23c1064` (`v0.5.0-fase2`) | C1, I1–I2, M1–M2 | Todos remediados el mismo día — ver la nota de remediación al final del propio informe |
| `revision_independiente_fase3_SIE-el-salvador.md` | 2026-09-17 | `e8116f1` (Fase 3 en curso) | C1, I1–I4, M1–M5 | Todos remediados en dos sesiones (`a6ec10e`, `82d06a0`); un desvío de CI en el proceso corregido en `543722b` — ver la nota de remediación al final del propio informe |
| `auditoria_independiente_fase4_SIE-el-salvador.md` | 2026-09-29 | `a67bde9` (`v0.7.0-fase4`) | I1–I4, M1–M5 (M6 apareció al preparar la remediación) | Remediados el 2026-09-29 (`81eb337`, `2c1865f`, `8c0435e`, `2da3d3b`, `b9b793e`, `7c5faa8`, `87a5e84`) — ver `doc/adr/README.md`, "Remediación de la auditoría independiente de Fase 4" |

**Salvedad sobre la interna de Fase 2.** A diferencia de las otras tres, no fue independiente: la
ejecutó el mismo agente que aplicó las correcciones, en la misma sesión y sobre el árbol de
trabajo, no sobre un clon fresco. Uno de sus hallazgos (A2) resultó falso y fue retirado tras
verificación adicional; el episodio se conserva documentado dentro del propio informe, conforme
a la regla de esta carpeta. La auditoría independiente de Fase 2 (2026-09-15) es la primera
revisión de ese cierre contra un clon fresco por un tercero, y cierra esa brecha (I2).

**Salvedad sobre el cierre de Fase 3.** La revisión independiente de Fase 3 (2026-09-17) auditó `e8116f1`,
con la fase en curso. El cierre (`906fb56`, `v0.6.0-fase3`, 2026-09-22/23), con la enmienda de UT a la matriz
y la extensión de `make trace` a los CSV anuales, no tuvo revisión de un tercero. La auditoría independiente de
Fase 4 cubrió de ese cierre solo lo que Fase 4 consume (L0 cruzada 56/56, integridad referencial, batería
completa) y no re-derivó `make trace` 106 PASS (hallazgo M5).
