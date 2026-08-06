# Orquestación del pipeline. Ver CLAUDE.md antes de añadir objetivos nuevos.
# Muchos objetivos aún no tienen script real detrás — se implementan en la fase
# correspondiente de la senda metodológica (§4), no antes.

.PHONY: setup raw clean master eval report validate test

setup:
	Rscript scripts/bootstrap_renv.R

# Fase 2 — reconstruye o verifica la integridad de la capa L0 desde cero, sin pasos manuales.
raw:
	@echo "Pendiente: src/adquisicion/ (Fase 2)"

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
