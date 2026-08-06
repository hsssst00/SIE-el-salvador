# ADR-008: Licencias y condiciones de redistribución

**Estado:** Parcial — BCR resuelto; pendiente DIGESTYC/ONEC, ISSS y organismos internacionales (Fase 1)
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
