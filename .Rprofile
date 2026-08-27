# RENV_PATHS_LIBRARY se fija aqui. Antes era la unica linea de .Renviron; .Renviron
# paso a estar gitignoreado (2026-08-27) para poder alojar credenciales personales
# -FRED_API_KEY y las que sigan de FMI/BM- sin versionarlas. renv/library es ademas
# el valor por defecto de renv: se deja explicito para no depender del default y para
# que CI lo tenga sin necesitar un .Renviron. .Renviron se lee antes que .Rprofile,
# asi que fijarlo aqui, antes de source(), llega a tiempo para el activador de renv.
Sys.setenv(RENV_PATHS_LIBRARY = "renv/library")
source("renv/activate.R")
