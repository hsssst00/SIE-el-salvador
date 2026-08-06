# ADR-007: Política de versiones de publicación (vintages)

**Estado:** Cerrado
**Fecha:** 2026-08-06
**Relacionado con:** ADR-001 (vintage de referencia), ADR-003 (alcance de reconstrucción retrospectiva)

## Contexto

El PIB trimestral se revisa. Si los modelos se evalúan contra la serie revisada más reciente, se les entrega información que no existía en el momento en que el pronóstico habría sido emitido — el resultado deja de ser replicable en operación real y sobreestima la precisión alcanzable. Identificada como el aporte más original y publicable del proyecto: no existe para El Salvador un registro de este tipo en la literatura local.

## Alternativas consideradas

- **(a) Vintages solo prospectivos:** el sistema captura y archiva cada nueva publicación desde el inicio del proyecto. Factible con certeza, pero deja fuera toda la historia de revisiones previa al proyecto.
- **(b) Reconstrucción retrospectiva exhaustiva:** rescate de publicaciones históricas (boletines, revistas trimestrales, Wayback Machine, publicaciones de SECMCA/FMI). Alto costo, resultado incierto y probablemente incompleto — coincide con el riesgo de mayor probabilidad e impacto identificado en la gestión de riesgos del proyecto (alcance excesivo para un primer proyecto académico).
- **(c) Híbrido:** (a) como compromiso firme, (b) como esfuerzo de mejor empeño con cobertura documentada explícitamente.

## Decisión

- **Estrategia: híbrida (c).** Captura prospectiva firme desde ya. Reconstrucción retrospectiva de mejor empeño, con la cobertura efectivamente lograda documentada sin importar cuán parcial resulte.
- **Alcance acotado de la reconstrucción retrospectiva:** limitada a la vigencia del SCN 2008. No se persigue reconstruir vintages publicados bajo metodologías de cuentas nacionales anteriores al empalme (ver ADR-003). Esto alinea el esfuerzo de reconstrucción con la variante de robustez de estimación sobre el tramo homogéneo, y acota explícitamente el riesgo de alcance excesivo.
- **Diseño de base:** bitemporal desde el primer día (cada observación indexada por período de referencia y por fecha de publicación), con independencia de cuánto se logre reconstruir retrospectivamente. Añadir esta dimensión después obligaría a rehacer el modelo de datos completo.
- **Granularidad del registro:** cada evento de publicación se archiva en L0 y recibe un `vintage_id` en el catálogo `08_vintages`. No se requiere una regla adicional de deduplicación: el campo `alcance_revision`, combinado con la comparación de checksum contra el manifiesto de L0 (§3.1), determina si hubo cambio real de contenido respecto del vintage anterior.

## Consecuencias

- Habilita la evaluación en tiempo real (§5.5 de la senda metodológica) y la cuantificación de la magnitud y el sesgo de las revisiones del PIB salvadoreño como resultado publicable independiente.
- Resuelve por extensión el sub-punto "vintage de referencia" de ADR-001: evaluación contra el vintage disponible en cada origen de pronóstico como criterio primario.
- Cada publicación del BCR no archivada desde hoy es información irrecuperable — la captura prospectiva debe iniciar de inmediato, incluso antes de que exista automatización (Fase 2). Hasta entonces, la captura es manual.
