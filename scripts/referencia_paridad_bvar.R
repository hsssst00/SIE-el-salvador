# scripts/referencia_paridad_bvar.R
#
# Regenera src/evaluacion/referencias/paridad_bvar.csv, la referencia de V17 (paridad Windows/Linux del BVAR;
# checklist F1, decisiones F1-1, F1-2 y F1-3). Se corre solo en Windows, la máquina de la corrida única (E2), y solo
# cuando cambia el código o la configuración del BVAR: la referencia nueva va en el mismo PR que el cambio, con una
# nota fechada en doc/metodologia/decisiones_fase5.md. No es parte de make eval ni del CI. Tarda lo que cuatro
# ajustes de producción del BVAR: G1 y G3 para los momentos y otra vez para su error de Monte Carlo (F1-3).
#
# Uso: Rscript scripts/referencia_paridad_bvar.R

if (.Platform$OS.type != "windows") stop("la referencia de paridad del BVAR se genera en Windows (decisión F1-1)")
source(here::here("src", "evaluacion", "eval_lib.R"))
source(here::here("src", "evaluacion", "modelos_referencia.R"))
source(here::here("src", "evaluacion", "modelos_univariados.R"))
source(here::here("src", "evaluacion", "modelos_multivariados.R"))
source(here::here("src", "evaluacion", "paridad_bvar.R"))

actual <- momentos_paridad_bvar()
mcse <- mcse_paridad_bvar(actual)                                            # otro ajuste por grupo (F1-3)
ruta <- escribir_referencia_paridad_bvar(actual, mcse)
num <- actual$campo != CAMPO_ENTRADAS_PARIDAD_BVAR
cat(sprintf("referencia de paridad del BVAR: %s, %d valores; sha256 de los momentos %s; %s, %s\n", ruta, sum(num),
            sha256_doubles(actual$valor[num]), R.version.string, utils::sessionInfo()$running))
