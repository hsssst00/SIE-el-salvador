# Orquestación del pipeline. Ver CLAUDE.md antes de añadir objetivos nuevos.
# Muchos objetivos aún no tienen script real detrás — se implementan en la fase
# correspondiente de la senda metodológica (§4), no antes.

.PHONY: setup raw raw-api raw-plan raw-fisico materializar-l0 clean master explore eval eval-sintetico report validate test audit trace

setup:
	Rscript scripts/bootstrap_renv.R

# Fase 2 — verificación de integridad de L0, en dos pasos que responden preguntas distintas
# (Decisión 1b, 2026-08-25; cobertura corregida 2026-08-28, hallazgos A1 y B1 de la auditoría
# de Fase 2). Objetivo LOCAL: el segundo paso usa navegador headless y sale a la red, no corre
# en CI. La captura de un vintage nuevo es un acto deliberado vía descargar_*(), no desde aquí
# (ADR-007).
#   1. ¿Están los archivos en disco, íntegros?      -> verificar_l0_fisico.R (offline)
#   2. ¿La fuente sigue sirviendo lo mismo?         -> verificar_l0.R        (en vivo)
# El paso 1 va primero para fallar barato: si L0 está rota en disco no tiene sentido
# levantar un navegador 16 veces.
raw: raw-fisico
	Rscript scripts/verificar_l0.R

# Solo el disco. Sin red, sin navegador.
raw-fisico:
	Rscript scripts/verificar_l0_fisico.R

# Solo las fuentes de API (FMI/FRED/BM). Barato y sin navegador — útil mientras se programa,
# pero NO satisface el criterio de cierre de Fase 2, que exige la corrida completa.
raw-api: raw-fisico
	Rscript scripts/verificar_l0.R api

# No pide nada a ninguna fuente: solo lista qué se verificaría y qué está excluido.
raw-plan:
	Rscript scripts/verificar_l0.R plan

# Repuebla data/L0_raw/ desde el almacén canónico local (copia de trabajo del repo privado
# de L0), luego verifica integridad. Requiere SIE_L0_STORE apuntando a ese directorio. No
# descarga de ninguna fuente ni toca el manifiesto — ver scripts/materializar_l0.R.
materializar-l0:
	Rscript scripts/materializar_l0.R
	Rscript scripts/verificar_l0_fisico.R

# Fase 3 — L0 -> L1 -> L2 -> L3, transformaciones y series maestras.
master: validate
	Rscript src/transformacion/extraer_bcr_pib.R
	Rscript src/transformacion/ut_demanda_serie.R
	Rscript src/transformacion/extraer_bcr_ivae.R
	Rscript src/transformacion/extraer_bcr_remesas.R
	Rscript src/transformacion/extraer_onec_ipc.R
	Rscript src/transformacion/extraer_bcr_ipp.R
	Rscript src/transformacion/extraer_bcr_balanza_comercial.R
	Rscript src/transformacion/extraer_bcr_itcer.R
	Rscript src/transformacion/extraer_bcr_indices_precios_comercio_exterior.R
	Rscript src/validacion/validar_l2_pib.R
	Rscript src/validacion/validar_l2_predictores.R
	Rscript src/transformacion/l3_pib_objetivo.R
	Rscript src/transformacion/l3_predictores.R
	@echo "Pendiente: matriz de predictores mas alla de BCR.IVAE/REMESAS/IPP/EXPORT_FOB/ITCER/IPM (ADR-010) (Fase 3)"

# Fase 3 — análisis exploratorio de la base maestra (senda §4), en el orden en que se leen:
# primero descriptivos y gráficos, después las pruebas formales de estacionariedad. Depende de
# `master` porque los tres scripts leen data/L3_master/, que ese objetivo genera. Salidas:
# reporte_exploratorio_resumen.csv, reporte_estacionariedad.csv y reporte_hegy.csv en
# doc/metodologia/reportes_fase3/ -- VERSIONADOS, con columna `fecha_generacion`, porque los
# citan documentos versionados (decisión de Harold, 2026-09-23) --, y exploracion/<serie>.png
# en data/L3_master/ (capa generada, no versionada). hegy.R tarda varios minutos (5000
# réplicas de simulación por serie).
explore: master
	Rscript src/analisis/exploracion_series.R
	Rscript src/analisis/estacionariedad.R
	Rscript src/analisis/hegy.R

# Validación de esquema de catálogos (columnas/tipos) e integridad referencial entre ellos.
validate:
	Rscript src/validacion/validate_catalogs.R
	Rscript src/validacion/validar_integridad_catalogos.R

# Fase 3 — G1/G2 del checklist de cierre: trazabilidad valor -> celda contra L0, certificada
# como target y no solo a mano (senda §4, "cada valor de la base maestra puede rastrearse hasta
# la celda del archivo original"). Deliberadamente FUERA de `validate`/`master`: exige los
# .xlsx de L0 en disco, que están en .gitignore (ADR-008) y no existen en CI ni en una máquina
# recién clonada -- mismo motivo que separa `raw` de `validate`. Las filas NO_VERIFICABLE son
# informativas (salida 0), así que correrlo sin L0 completa no rompe nada, pero tampoco prueba
# nada: para cobertura real hace falta L0 materializada (`make materializar-l0`). Regla 8 de
# CLAUDE.md: cada corrida real se asienta en doc/bitacora_verificaciones.md, en el mismo commit
# que usa su resultado -- correr este target no exime de esa entrada.
trace:
	Rscript src/validacion/verificar_fuente_celda.R

# Fase 4 — verificación del motor de evaluación sobre procesos generadores conocidos
# (src/evaluacion/verificar_motor_sintetico.R). NO lee data/L3_master/, así que corre en CI: es la
# evidencia del criterio de cierre de Fase 4 ("el motor funciona y está probado antes de estimar
# cualquier modelo sofisticado", senda §4). Bloques vigentes: V1-V6 y V10; V7-V9 y V11 (pruebas de
# significancia) llegan con el paso 4 del orden de implementación.
eval-sintetico:
	Rscript src/evaluacion/verificar_motor_sintetico.R

# Fase 4/5 — motor de evaluación sobre L3. La verificación sintética es prerrequisito y corre primero
# para fallar barato. No implementar Fase 5 antes de que el motor de Fase 4 esté probado.
eval: eval-sintetico
	@echo "Pendiente: src/evaluacion/motor_backtesting.R (Fase 4, paso 5 de la especificación del motor)"

# Fase 7 — sitio de documentación.
report:
	@echo "Pendiente: src/reportes/ (Fase 7)"

test:
	Rscript -e 'testthat::test_dir("tests")'

# Factsheet de orientación pre-auditoría: conteos, integridad referencial,
# L0, ADR, auditorías, claves y licencias. No es validación — no detiene nada.
audit:
	Rscript scripts/auditoria_mecanica.R

clean:
	rm -rf data/L1_staging/* data/L2_validated/* data/L3_master/* data/L4_experiments/*
	@echo "Capas L1-L4 limpiadas. L0_raw nunca se toca desde este objetivo."
