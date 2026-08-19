# lib_adquisicion.R
#
# Funcion compartida para todos los scripts de src/adquisicion/. Implementa el
# contrato descrito en diseno_src_adquisicion.md (aprobado 2026-08-18): descargar,
# calcular checksum, comparar contra el manifiesto, registrar si cambio, nunca
# sobrescribir (senda S3.1; reglas 1 y 6 de CLAUDE.md).
#
# Esta funcion NO decide como se pide el dato (eso lo hace cada script por
# institucion) - solo que hacer con la respuesta una vez obtenida.

library(digest)

ruta_manifiesto <- "data/L0_raw/manifiesto.csv"
ruta_vintages <- "catalogos/08_vintages.csv"
dir_l0 <- "data/L0_raw"

leer_manifiesto <- function() {
  if (!file.exists(ruta_manifiesto)) {
    stop("No se encuentra ", ruta_manifiesto, " - no correr este script fuera de la raiz del repo.")
  }
  read.csv(ruta_manifiesto, stringsAsFactors = FALSE, colClasses = "character")
}

calcular_sha256_raw <- function(contenido_crudo) {
  digest::digest(contenido_crudo, algo = "sha256", serialize = FALSE)
}

# fuente: "BCR", "FMI", "FRED", "BM" - coincide con institucion_id
# publicacion_id: debe existir en 01_publicaciones/*.yaml
# url: URL exacta consultada
# descripcion_archivo: snake_case, sin fuente ni fecha
# extension: "xlsx", "json", etc.
# contenido_crudo: bytes crudos ya obtenidos (raw vector)
# codigo_http: codigo de estado HTTP de la respuesta
# verificacion_forma: funcion opcional, recibe contenido_crudo, devuelve TRUE/FALSE
registrar_descarga <- function(fuente, publicacion_id, url, descripcion_archivo, extension,
                                contenido_crudo, codigo_http, fecha_publicacion = "",
                                periodo_referencia_max = "", verificacion_forma = NULL) {

  # Paso 1: fallar de forma visible ante cualquier senal de que la fuente no
  # devolvio lo esperado (regla 6 de CLAUDE.md). Sin advertencias silenciosas.
  if (codigo_http != 200) {
    stop("FALLO VISIBLE [", publicacion_id, "]: codigo HTTP ", codigo_http,
         " (se esperaba 200). URL: ", url)
  }
  if (!is.null(verificacion_forma)) {
    forma_ok <- verificacion_forma(contenido_crudo)
    if (!isTRUE(forma_ok)) {
      stop("FALLO VISIBLE [", publicacion_id, "]: la respuesta no paso la ",
           "verificacion de forma esperada. URL: ", url,
           ". Esto probablemente significa que la fuente devolvio algo distinto ",
           "del archivo esperado (pagina de error, bloqueo, estructura cambiada) - ",
           "no se guarda nada.")
    }
  }

  # Paso 2: checksum
  sha256_nuevo <- calcular_sha256_raw(contenido_crudo)
  tamano_bytes <- length(contenido_crudo)
  fecha_descarga <- as.character(Sys.Date())

  # Paso 3: comparar contra el manifiesto existente para este publicacion_id
  manifiesto <- leer_manifiesto()
  filas_previas <- manifiesto[manifiesto$publicacion_id == publicacion_id, ]

  if (nrow(filas_previas) == 0) {
    alcance_revision <- "primera captura - sin vintage previo con el cual comparar"
  } else {
    sha256_previo <- filas_previas$sha256[nrow(filas_previas)]
    if (identical(sha256_previo, sha256_nuevo)) {
      fecha_previa <- filas_previas$fecha_descarga[nrow(filas_previas)]
      message("Sin cambios respecto de la ultima captura (", fecha_previa,
              ") para ", publicacion_id, ". No se registra archivo ni vintage nuevo. ",
              "sha256 coincide: ", sha256_nuevo)
      return(invisible(list(
        vintage_nuevo = FALSE,
        sha256 = sha256_nuevo,
        mensaje = paste0("verificado, sin cambios desde ", fecha_previa)
      )))
    }
    alcance_revision <- paste0("vintage nuevo - sha256 distinto del capturado el ",
                                 filas_previas$fecha_descarga[nrow(filas_previas)])
  }

  # Paso 4: escribir el archivo (nunca sobrescribe)
  nombre_archivo <- paste0(fuente, "_", descripcion_archivo, "_", fecha_descarga, ".", extension)
  ruta_archivo <- file.path(dir_l0, nombre_archivo)
  if (file.exists(ruta_archivo)) {
    stop("FALLO VISIBLE [", publicacion_id, "]: ", ruta_archivo, " ya existe. ",
         "No se sobrescribe (regla 1 de CLAUDE.md). Si esto no es una corrida ",
         "duplicada del mismo dia, algo esta mal.")
  }
  writeBin(contenido_crudo, ruta_archivo)

  # Paso 5: vintage_id y registro en manifiesto + 08_vintages.csv
  vintage_id <- paste0(publicacion_id, ".v", format(Sys.Date(), "%Y-%m"))

  fila_manifiesto <- data.frame(
    archivo = nombre_archivo, fuente = fuente, url = url,
    fecha_descarga = fecha_descarga, sha256 = sha256_nuevo,
    tamano_bytes = as.character(tamano_bytes), codigo_http = as.character(codigo_http),
    vintage_id = vintage_id, publicacion_id = publicacion_id,
    stringsAsFactors = FALSE
  )
  write.table(fila_manifiesto, ruta_manifiesto, sep = ",", append = TRUE,
              row.names = FALSE, col.names = FALSE, qmethod = "double")

  fila_vintage <- data.frame(
    vintage_id = vintage_id, publicacion_id = publicacion_id,
    fecha_publicacion = fecha_publicacion, periodo_referencia_max = periodo_referencia_max,
    documento_fuente = url, archivo_raw = nombre_archivo, sha256 = sha256_nuevo,
    alcance_revision = alcance_revision, notas = "",
    stringsAsFactors = FALSE
  )
  write.table(fila_vintage, ruta_vintages, sep = ",", append = TRUE,
              row.names = FALSE, col.names = FALSE, qmethod = "double")

  message("Registrado: ", nombre_archivo, " (", publicacion_id, "), sha256=", sha256_nuevo)

  invisible(list(vintage_nuevo = TRUE, sha256 = sha256_nuevo, archivo = nombre_archivo,
                  vintage_id = vintage_id))
}
