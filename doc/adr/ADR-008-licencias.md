# ADR-008: Licencias y condiciones de redistribución

**Estado:** Parcial — BCR (corte 2026-10-12), FMI y FRED resueltos; ISSS resuelto por decisión de no perseguir esclarecimiento; Banco Mundial aplazado a la resolución del BCR; CEPAL en gestión (corte 2026-10-16); pendiente DIGESTYC/ONEC (Fase 1)
**Fecha:** 2026-08-06
**Relacionado con:** ADR-005 (principio de reproducibilidad), ADR-003 (fuente verificada)

## Contexto

Debe resolverse antes de publicar el repositorio: licencia del código, licencia de la documentación, y qué hacer con datos que las fuentes no permiten redistribuir.

## Alternativas consideradas

- **Licencia del código — MIT vs. GPL-3.0.** MIT es permisiva: cualquiera, incluido el propio BCR, puede reutilizar el código con fricción mínima. GPL-3.0 es copyleft: garantiza que los trabajos derivados permanezcan abiertos, pero algunas instituciones evitan por política dependencias con copyleft, lo que introduce fricción justo donde más interesa la adopción institucional.

## Decisión

- **Licencia del código:** MIT. Se prioriza la adopción institucional —incluida la posible adopción por el propio BCR, identificada como parte del valor del sistema— sobre la garantía de apertura propagada de un copyleft.
- **Licencia de la documentación:** CC-BY-4.0.
- **Política de datos no redistribuibles:** cuando una fuente no permite redistribución, el repositorio publica el *script* de descarga y el *checksum* (SHA-256), nunca el archivo. Es la única opción coherente con el principio de reproducibilidad ya adoptado en ADR-005.
- **Pendiente:** condiciones específicas de uso y redistribución de cada fuente (BCR, DIGESTYC/ONEC, ISSS, organismos internacionales). Se determinan durante el relevamiento de Fase 1, en paralelo a la verificación de ADR-003.

## Consecuencias

- Este ADR se enmienda en cuanto se complete el relevamiento de condiciones por fuente; no bloquea el inicio de Fase 0 ni Fase 1.
- El catálogo `01_publicaciones` debe incluir un campo de condiciones de uso por publicación, poblado durante ese relevamiento.

## Enmienda — condiciones de la fuente BCR (2026-08-06)

**Hallazgo:** la Base de Datos Económica y Financiera del BCR está catalogada como portal de divulgación estadística oficial de libre consulta. No opera bajo licencias abiertas comerciales (tipo Creative Commons); opera bajo un marco de información pública de libre acceso.

**Decisión aplicada:** "libre consulta" no equivale a una licencia explícita de redistribución. Se aplica el default conservador ya fijado en la sección de Decisión: el repositorio publica el *script* de descarga y el *checksum* (SHA-256) de los archivos de esta fuente; los archivos crudos de L0 provenientes del BCR no se comprometen directamente al repositorio público de Git.

**Seguimiento no bloqueante:** localizar en el sitio del BCR una página específica de términos de uso o aviso legal (posible referencia a la Ley de Acceso a la Información Pública de El Salvador) para tener una cita exacta en `01_publicaciones`.

**Pendiente sin cambios:** condiciones de DIGESTYC/ONEC, ISSS y organismos internacionales.

## Enmienda — nota preliminar sobre el estándar probatorio de estas enmiendas (2026-08-12)

Las tres enmiendas que siguen se apoyan en un relevamiento externo hecho por Claude vía búsqueda y lectura web, sin verificación directa de Harold contra las páginas de términos de uso de cada fuente. El proyecto marca ese tipo de hallazgo como "pendiente verificación directa de Harold" en los catálogos, y la misma cautela corresponde acá.

La distinción que permite cerrar de todos modos dos de los tres tramos es la siguiente:

- **Mantener el default conservador** (script + checksum, sin comprometer los archivos) es una conducta robusta al error del relevamiento. Si el hallazgo sobre la licencia de una fuente resultara equivocado en cualquiera de las dos direcciones, aplicar el default no incumple nada. La decisión puede cerrarse aunque la cita que la justifica quede pendiente de verificación.
- **Relajar el default** —comprometer archivos crudos al repositorio público amparándose en una licencia abierta— NO es robusto al error. Si el hallazgo sobre esa licencia fuera incorrecto, el proyecto estaría redistribuyendo sin autorización. Esa decisión exige verificación directa previa, sin excepción.

En consecuencia: los tramos FMI y FRED se cierran; el tramo Banco Mundial no.

## Enmienda — condiciones de la fuente FMI (2026-08-12)

**Hallazgo (relevamiento de Claude vía web, pendiente verificación directa de Harold).** El Fondo Monetario Internacional publica su contenido bajo régimen de derechos reservados salvo indicación en contrario, con una política separada de reuso libre no comercial de datos sujeto a cita de fuente obligatoria. No es una licencia abierta de tipo Creative Commons y no autoriza redistribución comercial. Página de referencia: `https://www.imf.org/en/_site_imf/about/copyright-and-terms`.

**Decisión aplicada.** Se aplica el default conservador de este ADR: el repositorio publica el *script* de descarga y el *checksum* (SHA-256); los archivos crudos de L0 provenientes del FMI no se comprometen al repositorio público. Tramo cerrado.

**Consecuencia operativa.** La API SDMX 3.0 del FMI no requiere autenticación, de modo que el *script* de descarga es ejecutable por cualquier tercero sin trámite previo. Este tramo no introduce fricción al criterio de reproducibilidad de la senda metodológica §10.1.

**Seguimiento no bloqueante.** Verificación directa de Harold contra la página de términos citada, para poder referenciarla con precisión en `01_publicaciones`.

## Enmienda — condiciones de la fuente FRED (2026-08-12)

**Hallazgo (relevamiento de Claude vía web, pendiente verificación directa de Harold).** Los Términos de Uso de la API de FRED (Federal Reserve Bank of St. Louis) imponen tres condiciones que exceden el default conservador y que este ADR no había contemplado para ninguna fuente anterior:

1. **Clave por usuario.** Se requiere una clave de API gratuita y cada usuario debe emplear la suya. La clave no puede comprometerse al repositorio bajo ninguna circunstancia.
2. **Aviso de no-aval obligatorio.** Debe colocarse de forma prominente en la aplicación la declaración de que el producto usa la API de FRED pero no está avalado ni certificado por el Federal Reserve Bank of St. Louis. Está prohibido afirmar o sugerir respaldo institucional, así como usar marcas o logotipos de la institución.
3. **Copyright de terceros.** FRED redistribuye series de decenas de fuentes y algunas son de propiedad privada. Las series con derechos reservados llevan la marca correspondiente en su campo de notas. FRED declara explícitamente que no puede otorgar permiso sobre esas series en nombre de sus titulares.

**Decisión aplicada.** Se aplica el default conservador (script + *checksum*), que en este caso además es la única conducta posible: la clave por usuario impide cualquier otra. Tramo cerrado en cuanto a política de L0.

**Consecuencias que se activan al escribir el primer *script* de `src/adquisicion/` que consuma FRED, no antes:**

- La clave se lee de variable de entorno, nunca de archivo versionado. El *script* debe fallar de forma visible si la variable no está definida, conforme a la regla 6 de `CLAUDE.md`.
- El aviso de no-aval debe incorporarse al `README.md` del repositorio con el texto exacto que exijan los Términos de Uso vigentes en ese momento. No se añade todavía porque no existe aún aplicación alguna que consuma la API, y anticiparlo introduciría en el `README.md` una declaración sobre una dependencia inexistente.
- Antes de incorporar cualquier serie concreta de FRED a `03_series`, debe verificarse serie por serie si su campo de notas contiene la marca de derechos reservados. Una serie con esa marca no entra al proyecto sin resolver antes su condición.

**Tensión documentada, no resuelta.** El criterio de cierre de Fase 0 (senda metodológica §4) exige que un tercero pueda clonar el repositorio y reproducir el entorno sin intervención del autor. Un tercero que quiera reproducir la capa L0 completa deberá registrarse en `fredaccount.stlouisfed.org` y obtener su propia clave. Eso es un trámite gratuito e instantáneo, pero es intervención del tercero, no del autor, y no invalida el criterio. Queda registrado para que el manual de actualización (Fase 7) lo declare como requisito previo explícito.

## Enmienda — condiciones de la fuente Banco Mundial: DECISIÓN APLAZADA (2026-08-12)

**Hallazgo (relevamiento de Claude vía web, pendiente verificación directa de Harold).** El Banco Mundial licencia por defecto los conjuntos de datos producidos por él mismo y distribuidos como datos abiertos bajo Creative Commons Attribution 4.0 International (CC-BY 4.0), que permite copiar, modificar y distribuir en cualquier formato y para cualquier fin, incluido el comercial, con la sola obligación de dar crédito e indicar si se hicieron cambios. Aplican tres condiciones adicionales: una cláusula obligatoria de mediación no vinculante para disputas; un formato de atribución solicitado; y la salvedad de que algunos conjuntos de datos e indicadores provienen de terceros y no pueden redistribuirse sin consentimiento del proveedor original, condición que aparece en los metadatos del indicador. Referencias: `https://datacatalog.worldbank.org/public-licenses` y `https://data.worldbank.org/summary-terms-of-use`.

**Por qué esto no se decide hoy.** El hallazgo plantea, por primera vez en el proyecto, la posibilidad de comprometer archivos crudos de L0 al repositorio público. Pero la pregunta que abre no es sobre el Banco Mundial: es sobre si el proyecto adopta **una** política de L0 o una política **por fuente**.

Esa pregunta no puede contestarse sin conocer el régimen de la fuente que aporta la variable objetivo. Si el BCR resultara tener licencia abierta explícita, no habría ramificación que introducir —el *pipeline* seguiría siendo uniforme, solo que uniforme del otro lado—. Decidir la arquitectura de L0 a partir del caso periférico, cuando el caso central sigue sin resolverse, sería fijar el diseño desde la excepción.

**Estado.** Información relevada, decisión aplazada. El default conservador de este ADR sigue vigente para el Banco Mundial mientras tanto. El aplazamiento no tiene costo: no existe todavía ningún archivo de L0 proveniente de esta fuente, ni lo habrá antes de Fase 2.

**Disparador.** Se resuelve al ocurrir lo primero de: (i) respuesta del BCR a la consulta registrada en la enmienda siguiente, o (ii) la fecha de corte fijada en esa misma enmienda. En cualquiera de los dos casos, la resolución exige además verificación directa de Harold de los términos del Banco Mundial, por la razón expuesta en la nota preliminar sobre estándar probatorio.

## Enmienda — consulta formal al BCR sobre régimen de redistribución (2026-08-12)

Esta enmienda actualiza y sustituye el punto "Seguimiento no bloqueante" de la enmienda del 2026-08-06 sobre la fuente BCR. Aquel punto planteaba localizar en el sitio del BCR una página de términos de uso. La gestión escaló de la búsqueda documental a la consulta directa a la institución.

**Registro de la gestión:**

| Fecha | Acto |
|---|---|
| 2026-08-07 (viernes) | Harold remite consulta al Banco Central de Reserva, dirección `normas@bcr.gob.sv`, sobre el régimen de redistribución y licenciamiento de la información difundida por la Base de Datos Económica y Financiera. |
| 2026-08-12 (miércoles) | El BCR responde solicitando ampliación de la descripción de los usos previstos. Harold remite la ampliación el mismo día, detallando naturaleza del proyecto, objeto, cuatro actos concretos sobre la información (descarga y conservación local con registro de procedencia; transformación estadística documentada; publicación de resultados agregados; redistribución de los archivos originales en repositorio público), restricciones autoimpuestas, y solicitud de pronunciamiento específico sobre el cuarto acto. |

**Naturaleza de la gestión.** Consulta ordinaria por correo institucional, no solicitud formal bajo la Ley de Acceso a la Información Pública. En consecuencia **no existe plazo legal de respuesta**, y el pendiente quedaría abierto de forma indefinida si no se le fija término.

**Fecha de corte: 2026-10-12** (aproximadamente sesenta días desde la ampliación de usos). Si a esa fecha no hay pronunciamiento del BCR:

- se mantiene el default conservador de este ADR para la fuente BCR, sin cambio;
- se resuelve la decisión de política de L0 pendiente en la enmienda anterior sobre el Banco Mundial;
- se documenta en este mismo ADR la ausencia de pronunciamiento, con las fechas de la gestión, de modo que la aplicación del default quede sostenida por un hecho registrado y no por omisión.

**Por qué importa el registro de fechas.** Si el BCR nunca responde, el proyecto debe decidir igual. La posición documentalmente defendible en ese escenario es "se consultó a la fuente en tal fecha, se amplió la descripción de usos en tal otra a solicitud de la propia institución, no hubo pronunciamiento, se aplicó el default conservador". Sin las fechas asentadas esa posición no se sostiene, y la decisión quedaría indistinguible de no haber consultado nunca.

**Conservación de evidencia.** El hilo completo de correspondencia —consulta original, solicitud de ampliación del BCR y ampliación remitida— se conserva como respaldo de esta enmienda.

**Pendiente sin cambios:** condiciones de DIGESTYC/ONEC. ISSS: ver enmienda separada abajo (2026-08-17) — queda resuelto por decisión de no perseguir esclarecimiento, no por relevamiento pendiente.

## Enmienda — condiciones de la fuente CEPAL: consulta enviada, corte pendiente (2026-08-17)

**Hallazgo.** Los Términos y condiciones del sitio de CEPAL (`https://www.cepal.org/es/terminos-condiciones-uso-sitio-web-la-cepal-usuario`, punto 4) autorizan a los Usuarios a descargar y copiar los Materiales del sitio únicamente para uso personal, sin fines comerciales, y sin derecho a revender, redistribuir ni crear otros trabajos a partir de ellos. Es una licencia más restrictiva que la del Banco Mundial y comparable en severidad a la del FMI — no es un régimen de datos abiertos.

**Estándar probatorio de este hallazgo (más sólido que las enmiendas anteriores de este ADR).** Claude verificó directamente por *fetch* (no snippet de buscador) la versión en inglés de este documento (`https://www.cepal.org/en/website-usage-agreement-between-eclac-and-user`) y confirmó el texto de la cláusula 4 palabra por palabra contra lo que Harold cita en su propia consulta a CEPAL (ver registro de la gestión) — coinciden. La URL en español específica que Harold cita no se re-verificó por *fetch* directo en esta sesión (restricción de la herramienta de navegación de Claude, no del hallazgo en sí), pero el mismo texto de la cláusula 4, en español, aparece de forma idéntica en múltiples subdominios oficiales de `cepal.org` consultados de forma independiente. Se trata como confiable, sin la salvedad de "pendiente verificación directa de Harold" que llevan los hallazgos de FMI y FRED — Harold ya verificó él mismo el contenido de la cláusula al citarla textualmente en su propia consulta.

**Decisión aplicada.** Se aplica el default conservador de este ADR: el repositorio publica el *script* de descarga y el *checksum* (SHA-256) de los archivos provenientes de CEPALSTAT; los archivos crudos de L0 de esta fuente no se comprometen al repositorio público.

**Matiz que excede el default de este ADR — pendiente, no resuelto por esta enmienda.** El default conservador fue diseñado para el archivo crudo de L0 ("no comprometer el archivo, sí el script"). La cláusula 4 de CEPAL prohíbe además crear obras derivadas — no solo redistribuir el archivo original. El proyecto sí transforma las series de CEPALSTAT (ajuste estacional, deflactación, empalmes, combinación con otras fuentes) y publica el resultado (series master, hallazgos) en el repositorio abierto. No está resuelto si esa actividad cae dentro de "obra derivada" en el sentido de la cláusula 4, ni si el uso académico sin fines comerciales la exceptúa implícitamente. Harold ya elevó esta pregunta exacta a CEPAL (ver registro de la gestión). Queda señalado como riesgo abierto explícito, no resuelto por interpretación propia mientras la fuente no se pronuncie — misma lógica que ya rige el resto de este ADR: relajar un default exige verificación previa, nunca inferencia propia.

**Registro de la gestión:**

| Fecha | Acto |
|---|---|
| 2026-08-17 (lunes) | Harold remite consulta a `cepalstat@cepal.org`. Se presenta como estudiante de economía de la Universidad de El Salvador, describe el SIE (catálogo trazable, repositorio abierto en GitHub, caso de uso: comparación de modelos de proyección del PIB trimestral), cita textualmente la cláusula 4 de los Términos y condiciones del sitio, y pregunta explícitamente si (a) el uso descrito —investigación académica sin fines comerciales que transforma las series y publica el resultado (código MIT, documentación CC-BY-4.0) en un repositorio público— está cubierto por los términos generales del sitio, o (b) CEPALSTAT tiene una política de datos abiertos específica (tipo Creative Commons) separada del aviso legal general, análoga a la de Banco Mundial y BID. |

**Naturaleza de la gestión.** Consulta ordinaria por correo institucional, no solicitud formal bajo un régimen de acceso a la información. No existe plazo legal de respuesta.

**Fecha de corte: 2026-10-16** (60 días desde el envío, mismo criterio que la enmienda del BCR). Si a esa fecha no hay pronunciamiento de CEPAL:

- se mantiene el default conservador de este ADR para la fuente CEPAL, sin cambio para el archivo crudo de L0;
- el matiz sobre obras derivadas señalado arriba **no** se cierra por el solo vencimiento del plazo — a diferencia del caso BCR, acá el default conservador (script + checksum del archivo crudo) probablemente no cubre por sí solo la actividad real que el proyecto ya realiza sobre esta fuente (transformar y publicar derivados). El vencimiento sin respuesta deja ese riesgo documentado como abierto, no resuelto por omisión;
- se documenta en este mismo ADR la ausencia de pronunciamiento, con las fechas de la gestión.

**Conservación de evidencia.** El correo enviado se conserva en la bandeja de salida de Harold como respaldo de esta enmienda; no se reproduce íntegro en este documento, mismo criterio ya establecido para la enmienda del BCR.

**Diferencia con el caso del Banco Mundial.** A diferencia de BM (licencia CC-BY-4.0 declarada, con matices que motivaron aplazar la decisión de arquitectura de L0), acá el hallazgo apunta en la dirección contraria: términos más restrictivos que el propio default de este ADR, no más permisivos. La pregunta de arquitectura de L0 que dejó aplazada la enmienda de Banco Mundial (¿una política uniforme de L0 o una política por fuente?) no se resuelve ni se activa por este caso.

## Enmienda — condiciones de la fuente ISSS: resuelto por decisión, no por relevamiento (2026-08-17)

**Decisión de Harold:** no se persigue esclarecimiento adicional de condiciones de uso con el ISSS. El portal opera bajo LAIP (no datos abiertos; reproducción de documentos $0.04/página vía solicitud formal), y el contexto de discontinuación de publicaciones desde may-2023 e invocación de reserva de información ya está verificado directamente por Harold contra el portal — ver `09_rupturas.csv`, `R014_ISSS_ESTADISTICAS_RESERVA`, y la fila ISSS de `00_instituciones.csv` para el detalle completo. Escribir para confirmar términos formales de uso no aporta información adicional relevante: el ISSS sirve solo como tramo histórico hasta may-2023, no como predictor en tiempo real del proyecto. Se aplica el default conservador de este ADR sin cambios. Puede revisitarse si el ISSS retoma publicaciones o si estas series se vuelven candidatas concretas a insumo de modelación.

**Pendiente sin cambios:** condiciones de DIGESTYC/ONEC. Este ADR permanece en estado **Parcial**.
