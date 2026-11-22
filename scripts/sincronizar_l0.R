# scripts/sincronizar_l0.R
# `make sincronizar-l0`: deja data/L0_raw/ y el almacen privado de L0 (SIE_L0_STORE) con los mismos
# archivos del manifiesto, en las dos direcciones, y sube lo nuevo al almacen con commit y push.
# Ficha F7-14 de doc/metodologia/decisiones_fase7.md. Correr despues de cada captura y antes del PR
# que registra el manifiesto. `make materializar-l0` sigue siendo la via para una maquina nueva.

source("src/adquisicion/sincronizacion_l0_lib.R")
sincronizar_l0()
