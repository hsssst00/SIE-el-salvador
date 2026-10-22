# scripts/armar_preregistro_fase6.R
#
# Escribe doc/metodologia/preregistro_fase6.yaml (F6-12, ítem E1 del checklist de Fase 6): las constantes de la regla
# (F6-02), la guarda calculada sobre el objetivo de la L3 del corte (F6-08, F6-08-a), los intervalos (F6-07), la
# sensibilidad (F6-09) y la lista de coherencia (F6-10). Se corre UNA vez, al congelar, sobre la L3 que armó
# `make master` con corte_fase6.csv; el archivo se commitea en el PR de congelamiento y no se edita a mano. La
# corrida (`make fase6`) lo exige y recalcula la guarda: si difiere, se detiene.
#
# No proyecta ni lee senderos: solo el objetivo observado.
#
# Uso: make preregistro-fase6   (exporta CONJUNTO=doc/metodologia/corte_fase6.csv SALIDA=data/conjuntos/corte_f6)

source(here::here("src", "proyeccion", "correr_fase6.R"))

conjunto <- exigir_conjunto(conjunto_activo())
ident <- identidad_conjunto(Sys.getenv("SIE_CONJUNTO"))
if (basename(ident$ruta) != CORTE_FASE6) stop("F6-04: el preregistro se arma sobre ", CORTE_FASE6, " y se pidió ", ident$ruta)
if (file.exists(PREREGISTRO_FASE6)) stop("F6-12: ", ruta_relativa(PREREGISTRO_FASE6), " ya existe; un preregistro congelado no se reescribe")
objetivo <- leer_objetivo("PIB_SA_PROPIO_Q.csv", "revision_vigente", leer_vintages(), conjunto)
o <- origen_fase6(objetivo)
p <- armar_preregistro_fase6(objetivo[c("periodo", "y")], o, ident$sha256)
escribir_preregistro_fase6(p)
cat(sprintf("OK %s: origen %s, guarda [%.4f, %.4f] pp (mín %.4f, máx %.4f, X %.4f, n %d); corte %s\n",
            ruta_relativa(PREREGISTRO_FASE6), p$origen, p$guarda$inferior, p$guarda$superior, p$guarda$minimo,
            p$guarda$maximo, p$guarda$X, p$guarda$n, ident$etiqueta))
