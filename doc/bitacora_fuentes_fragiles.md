# Bitácora de fuentes frágiles

Registro de comportamientos anómalos o de bloqueo encontrados al automatizar la
adquisición de cada fuente. Entregable de Fase 2 (senda §4).

## BCR — portal Livewire/Alpine.js, detección de bots confirmada

- **2026-08-18** (Claude, chat): `web_fetch` simple sin headers de navegador contra
  `estadisticas.bcr.gob.sv/serie/...` fue bloqueado ("Site blocked the request (bot
  detection)").
- **2026-08-19** (Claude Code): `httr2` con headers de navegador (User-Agent, Accept,
  Accept-Language, Referer) contra la misma URL también fue bloqueado. La respuesta llegó
  con `codigo_http = 200` pero `Content-Type: text/html` — es decir, el bloqueo no se
  manifiesta como un error HTTP sino como una página normal en lugar del `.xlsx`. La
  verificación de forma (`verificacion_xlsx`, firma ZIP "PK") habría fallado también; el
  chequeo de `Content-Type` detuvo la ejecución primero. No se guardó ningún archivo ni se
  escribió ninguna fila en el manifiesto — falló de forma visible conforme a la regla 6 de
  CLAUDE.md.
- **Hipótesis pendiente de investigar:** la URL en el manifiesto es la página del
  portal, no necesariamente el endpoint real de descarga del `.xlsx` — el archivo real
  puede requerir una acción de Livewire (POST a un endpoint de exportación, con
  token/sesión) que un `GET` simple no dispara. No confirmado todavía.
- **Conclusión de este intento:** headers de navegador por sí solos no son suficientes.
  Ver `diseno_src_adquisicion.md` para el criterio de qué probar después (ej. Cowork con
  navegador real, o investigar el endpoint real de exportación de Livewire) — no decidido
  todavía, pendiente de que Harold defina el siguiente paso.
