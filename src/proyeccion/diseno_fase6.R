# diseno_fase6.R
#
# Diseño de la proyección condicional (Ejercicio B; checklist de Fase 6, D1). Es un diseño aparte de DISENO_FASE4,
# que no cambia (F6-06): el Ejercicio A sigue con h = 1..8 y sus orígenes de evaluación, y Fase 6 proyecta una sola
# vez, desde el origen del corte, con h = 1..20 (F6-04). Cada campo cita la ficha de
# doc/metodologia/decisiones_fase6.md que lo fija; aquí no se decide nada.
#
# El origen no es un campo: es el último trimestre del objetivo en la L3 del corte (F6-04, F6-04-a) y se lee de
# ahí al correr, con origen_fase6().

source(here::here("src", "evaluacion", "eval_lib.R"))   # DISENO_FASE4, GRUPOS_FASE4, q_a_ind(), ind_a_q()

DISENO_FASE6 <- list(
  h_max        = 20L,                                  # F6-04, F6-06: h = 1 a 20
  h_calibrado  = DISENO_FASE4$h_max,                   # F6-07: con h > 8, la banda lleva la marca «sin calibrar»
  niveles      = c(0.80, 0.95),                        # F6-07: bandas del 80 y del 95 %
  min_miembros = 3L,                                   # F6-02: menos de 3 miembros en un grupo y escenario, stop()
  grupos       = names(GRUPOS_FASE4),                  # F6-01: G1, G2 y G3 de F4-05
  escenarios   = c("BASE", "ADVERSO", "FAVORABLE")     # F6-05, F6-14: base, escenario C y escenario A del recuadro 1.2
)

# Predictoras externas (F6-03, F6-15): la predictora trimestral de L3 y su satélite. Son las únicas que reciben un
# sendero de escenario; IVAE y UT son internas y las proyecta el propio modelo. Un modelo es condicionable si al
# menos una de sus predictoras está aquí (F6-01-b); el puente usa la versión mensual (.M) del mismo concepto.
SATELITES_FASE6 <- c(
  "BCR.REMESAS.NOM.NSA.Q"    = "SAT.REMESAS_NOM",
  "BCR.REMESAS.REAL.NSA.Q"   = "SAT.REMESAS_REAL",
  "BCR.EXPORT_FOB.NOM.NSA.Q" = "SAT.EXPORT_FOB",
  "BCR.ITCER.IDX.NSA.Q"      = "SAT.ITCER",
  "BCR.IPM.IDX.NSA.Q"        = "SAT.IPM",
  "BCR.IPP.IDX.NSA.Q"        = "SAT.IPP"
)

#' Origen de Fase 6 (F6-04): último trimestre del objetivo observado (data.frame con `periodo`). Falla visible si
#' el objetivo viene vacío o desordenado.
origen_fase6 <- function(objetivo) {
  if (!nrow(objetivo)) stop("origen_fase6: el objetivo no trae filas")
  i <- q_a_ind(objetivo$periodo)
  if (is.unsorted(i, strictly = TRUE)) stop("origen_fase6: el objetivo no está ordenado por período sin repetir")
  i[length(i)]
}

#' Trimestres proyectados desde el origen `o` (índice trimestral): o + 1 .. o + h_max, en formato AAAA-Qn.
periodos_fase6 <- function(o, h_max = DISENO_FASE6$h_max) ind_a_q(as.integer(o) + seq_len(h_max))
