# bcr_sondear_publicacion.R
# Sondeo liviano de una página vista-serie del BCR: monta el componente, confirma que
# es efectivamente vista-serie, y lee el rango completo vía /api/rangos - sin descargar
# nada ni tocar L0. Uso: inventario (Fase 1), no adquisición (Fase 2).
# Reusa .BCR_BOOT/.BCR_CMP de bcr_captura.R - no reimplementa el montaje.

source("src/adquisicion/bcr_captura.R")  # trae .BCR_BOOT, .BCR_CMP, .bcr_eval, .bcr_wait

bcr_sondear_publicacion <- function(url, timeout_s = 60) {
  b <- ChromoteSession$new()
  on.exit(try(b$close(), silent = TRUE), add = TRUE)

  b$go_to(url)

  es_vista_serie <- tryCatch({
    .bcr_wait(b, .BCR_BOOT, timeout_s = timeout_s, que = "montaje de vista-serie")
    TRUE
  }, error = function(e) FALSE)

  if (!es_vista_serie) {
    return(list(url = url, es_vista_serie = FALSE,
                nota = "No se montó un componente vista-serie en esta URL - mecanismo distinto, no sondear con este script."))
  }

  id_pub <- .bcr_eval(b, sprintf("%s.data.idPublic", .BCR_CMP))
  nombre_cuadro <- .bcr_eval(b, sprintf("%s.data.nombreCuadro", .BCR_CMP))
  unidades <- .bcr_eval(b, sprintf("%s.data.unidadesCuadro", .BCR_CMP))

  rangos <- jsonlite::fromJSON(.bcr_eval(
    b, sprintf("fetch('/api/rangos/%s',{headers:{Accept:'application/json'}}).then(r=>r.text())", id_pub),
    await = TRUE), simplifyVector = FALSE)
  anios <- vapply(rangos, function(x) as.integer(x$year), integer(1))
  primer_anio <- anios[1]; primer_simbolo <- rangos[[1]]$periodos$simbolo[[1]]
  ultimo_anio <- anios[length(anios)]
  ultimo_periodos <- rangos[[length(rangos)]]$periodos$simbolo
  ultimo_simbolo <- ultimo_periodos[[length(ultimo_periodos)]]

  list(url = url, es_vista_serie = TRUE, id_publicacion = id_pub,
       nombre_cuadro = nombre_cuadro, unidades = unidades,
       cobertura_inicio = paste(primer_anio, primer_simbolo),
       cobertura_fin = paste(ultimo_anio, ultimo_simbolo))
}
