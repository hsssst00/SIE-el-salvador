# Orquestación del pipeline. Ver CLAUDE.md antes de añadir objetivos nuevos.
# Muchos objetivos aún no tienen script real detrás — se implementan en la fase
# correspondiente de la senda metodológica (§4), no antes.

.PHONY: setup raw raw-api raw-plan raw-fisico clean master eval report validate test

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

# Fase 3 — L0 -> L1 -> L2 -> L3, transformaciones y series maestras.
master: validate
	@echo "Pendiente: src/transformacion/ (Fase 3)"

# Validación de esquema de catálogos — pointblank contra catalogos/datapackage.json.
validate:
	@echo "Pendiente: src/validacion/ (Fase 3)"

# Fase 4/5 — motor de evaluación y estimación. No implementar Fase 5 antes de que
# el motor de Fase 4 esté probado en datos sintéticos.
eval:
	@echo "Pendiente: src/evaluacion/ (Fase 4-5)"

# Fase 7 — sitio de documentación.
report:
	@echo "Pendiente: src/reportes/ (Fase 7)"

test:
	Rscript -e 'testthat::test_dir("tests")'

clean:
	rm -rf data/L1_staging/* data/L2_validated/* data/L3_master/* data/L4_experiments/*
	@echo "Capas L1-L4 limpiadas. L0_raw nunca se toca desde este objetivo."
