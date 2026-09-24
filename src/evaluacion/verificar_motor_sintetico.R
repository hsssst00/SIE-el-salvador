# src/evaluacion/verificar_motor_sintetico.R
#
# Verificación del motor de evaluación sobre procesos generadores conocidos: la evidencia del
# criterio de cierre de Fase 4 ("el motor funciona y está probado antes de estimar cualquier modelo
# sofisticado", senda §4). No lee data/L3_master/ ni ningún dato del proyecto, así que corre en CI.
# Cada bloque falla con stop() (regla 7 de CLAUDE.md); si todos pasan, sale 0.
#
# Bloques implementados en esta versión (paso 3 del orden de implementación de la especificación §9):
#   V1   aritmética de orígenes sobre las fechas reales del objetivo: 52/51/49/45 pares
#   V2   el sendero de un AR(1) con coeficientes verdaderos coincide con la fórmula cerrada
#   V3   RMSE simulado dentro de ±3 errores de Monte Carlo del teórico (AR(1) en Δy y paseo aleatorio)
#   V4   ordenamiento correcto: AR(p)-BIC bate al paseo aleatorio si el DGP es AR, y no si es paseo
#   V5   canario de filtración: un modelo que busca el futuro en su insumo hace fallar al motor
#   V6   canario de mutación: un modelo que modifica su insumo no altera el estado maestro
#   V10  reproducibilidad: dos corridas con la misma semilla dan salidas idénticas bit a bit
# Bloques del paso 4 (pruebas de significancia; F4-12, F4-15..F4-18):
#   V7   tamaño de DM/HLN en las 12 celdas grupo×h: estricto en h=1,2 (cota binomial 99%);
#        en h=4,8 se reporta el tamaño empírico (distorsión documentada, F4-18)
#   V8   potencia de DM/HLN ante una pérdida 20% menor (solo reporte)
#   V9   MCS T_max α=0,10: el modelo dominante queda dentro (estricto); con modelos equivalentes
#        el MCS completo se exige en h=1 y se reporta en h=8
#   V11  MCS propio contra MCS::MCSprocedure (Suggests; SKIP si el paquete no está instalado)
#
# Uso: Rscript src/evaluacion/verificar_motor_sintetico.R   (make eval-sintetico)

source(here::here("src", "evaluacion", "eval_lib.R"))
source(here::here("src", "evaluacion", "modelos_referencia.R"))

SEMILLA_RAIZ <- 20260924L
PERIODOS_OBJ <- ind_a_q(q_a_ind("1990-Q1") + 0:144)          # 145 obs, 1990-Q1 a 2026-Q1, como el objetivo
stopifnot(length(PERIODOS_OBJ) == 145L, utils::tail(PERIODOS_OBJ, 1) == "2026-Q1")

#' Simula y = log-nivel con Δy AR(1): Δy_t = c + φ Δy_{t-1} + ε, ε ~ N(0, σ²).
simular_objetivo <- function(n, phi, sigma, c0 = 0, y0 = log(100), inicio = "1990-Q1") {
  dy <- numeric(n); e <- stats::rnorm(n, 0, sigma)
  for (t in 2:n) dy[t] <- c0 + phi * dy[t - 1] + e[t]
  data.frame(periodo = ind_a_q(q_a_ind(inicio) + 0:(n - 1)), y = y0 + cumsum(dy), stringsAsFactors = FALSE)
}

#' Modelo de prueba con coeficientes verdaderos: no estima nada.
modelo_ar1_verdadero <- function(c0, phi) list(
  modelo_id = "PRUEBA.AR1_VERDADERO", requiere = "objetivo",
  ajustar  = function(datos, spec) { y <- datos$objetivo$y; list(dy = diff(y), y_o = utils::tail(y, 1)) },
  predecir = function(aj, h) .recursion_ar(c0, phi, aj$dy, aj$y_o, h)
)

#' Varianza teórica del error de pronóstico del LOG-NIVEL a h pasos cuando Δy es AR(1) y el
#' predictor usa los coeficientes verdaderos: σ² Σ_{k=0}^{h-1} ((1 - φ^{k+1}) / (1 - φ))².
#' (Con φ = 0 se reduce a σ² h, la del paseo aleatorio.)
var_error_teorica <- function(h, phi, sigma) {
  psi <- if (phi == 0) rep(1, h) else (1 - phi^(seq_len(h))) / (1 - phi)
  sigma^2 * sum(psi^2)
}

ok <- function(bloque, detalle) cat(sprintf("%-4s OK  %s\n", bloque, detalle))

# --- V1 · aritmética de orígenes -------------------------------------------------------------
set.seed(SEMILLA_RAIZ)
obj <- simular_objetivo(145L, 0.3, 0.01)
stopifnot(identical(obj$periodo, PERIODOS_OBJ))
ors <- origenes_diseno()
pron <- correr_backtest(list(objetivo = obj), list(modelo_rw_sin_deriva()), ors, exp_id = "V1")
err  <- calcular_errores(pron, obj)
cnt  <- conteo_por_horizonte(err[err$unidad == "yoy_pp", ])
esperado <- c(`1` = 52L, `2` = 51L, `4` = 49L, `8` = 45L)
if (!identical(cnt, esperado)) stop("V1: pares por horizonte ", paste(cnt, collapse = "/"), ", se esperaba 52/51/49/45")
n_primera <- nrow(recortar_a_origen(obj, ors[1]))
if (n_primera != 93L) stop("V1: la muestra del primer origen tiene ", n_primera, " obs, se esperaban 93 (convención A)")
ok("V1", sprintf("52 orígenes 2013-Q1..2025-Q4; pares h=1/2/4/8 = %s; primera muestra %d obs", paste(cnt, collapse = "/"), n_primera))

# --- V2 · sendero del modelo verdadero ---------------------------------------------------------
phi <- 0.6
set.seed(SEMILLA_RAIZ + 2L)
obj <- simular_objetivo(145L, phi, 0.01)
o <- q_a_ind("2026-Q1")
s_motor <- correr_backtest(list(objetivo = obj), list(modelo_ar1_verdadero(0, phi)), o, exp_id = "V2")$log_nivel_pronosticado
dy_o <- utils::tail(diff(obj$y), 1); y_o <- utils::tail(obj$y, 1)
s_cerrada <- y_o + cumsum(phi^(1:8) * dy_o)
if (max(abs(s_motor - s_cerrada)) > 1e-10) stop("V2: el sendero difiere de la fórmula cerrada en ", max(abs(s_motor - s_cerrada)))
ok("V2", sprintf("AR(1) φ=%.1f: |motor - fórmula cerrada| máx = %.1e en h=1..8", phi, max(abs(s_motor - s_cerrada))))

# --- V3 · RMSE teórico -------------------------------------------------------------------------
R3 <- 2000L; sigma <- 0.01; hs <- c(1L, 2L, 4L, 8L)
for (caso in list(list(nombre = "AR(1) φ=0,6", phi = 0.6, modelo = modelo_ar1_verdadero(0, 0.6)),
                  list(nombre = "paseo aleatorio", phi = 0, modelo = modelo_rw_sin_deriva()))) {
  set.seed(SEMILLA_RAIZ + 3L)
  e2 <- matrix(NA_real_, R3, length(hs))
  for (r in seq_len(R3)) {
    sim <- simular_objetivo(153L, caso$phi, sigma)                      # 145 + 8 para observar hasta h=8
    p <- correr_backtest(list(objetivo = sim), list(caso$modelo), q_a_ind("2026-Q1"), exp_id = "V3")
    e <- calcular_errores(p, sim, horizontes = hs)
    e <- e[e$unidad == "log_nivel", ]
    e2[r, ] <- e$error[match(hs, e$h)]^2
  }
  for (j in seq_along(hs)) {
    rmse_sim <- sqrt(mean(e2[, j])); rmse_teo <- sqrt(var_error_teorica(hs[j], caso$phi, sigma))
    ee <- stats::sd(e2[, j]) / sqrt(R3) / (2 * rmse_sim)                # método delta
    if (abs(rmse_sim - rmse_teo) > 3 * ee) {
      stop(sprintf("V3 %s h=%d: RMSE simulado %.5f vs teórico %.5f (3 EE = %.5f)", caso$nombre, hs[j], rmse_sim, rmse_teo, 3 * ee))
    }
  }
  ok("V3", sprintf("%s: RMSE simulado dentro de ±3 EE de Monte Carlo del teórico en h=1/2/4/8 (%d réplicas)", caso$nombre, R3))
}

# --- V4 · ordenamiento correcto --------------------------------------------------------------
R4 <- 50L
razon_h1 <- function(phi) {
  vapply(seq_len(R4), function(r) {
    sim <- simular_objetivo(145L, phi, 0.01)
    p <- correr_backtest(list(objetivo = sim), list(modelo_rw_sin_deriva(), modelo_arp_bic()), ors, exp_id = "V4")
    m <- metricas_por_horizonte(calcular_errores(p, sim, horizontes = 1L))
    m <- m[m$unidad == "log_nivel", ]
    m$rmse[m$modelo_id == "BENCH.ARP_BIC"] / m$rmse[m$modelo_id == "BENCH.RW_SIN_DERIVA"]
  }, numeric(1))
}
set.seed(SEMILLA_RAIZ + 4L)
rz_ar <- razon_h1(0.6)
if (mean(rz_ar < 1) < 0.9) stop(sprintf("V4: con DGP AR(1) φ=0,6 el AR(p)-BIC bate al paseo aleatorio solo en %.0f%% de las réplicas", 100 * mean(rz_ar < 1)))
set.seed(SEMILLA_RAIZ + 5L)
rz_rw <- razon_h1(0)
if (mean(rz_rw) < 1) stop(sprintf("V4: con DGP paseo aleatorio el AR(p)-BIC tiene RMSE relativo medio %.4f < 1", mean(rz_rw)))
ok("V4", sprintf("DGP AR(1): AR(p)-BIC gana en %.0f%% de %d réplicas (RMSE relativo medio %.3f); DGP paseo: RMSE relativo medio %.4f",
                 100 * mean(rz_ar < 1), R4, mean(rz_ar), mean(rz_rw)))

# --- V5 · canario de filtración -----------------------------------------------------------------
# Busca en su insumo los períodos o+1..o+h. Con un recorte correcto no los encuentra, devuelve NA y
# G-3 detiene el motor. Si alguna vez los encontrara, lograría RMSE = 0: esa es la señal de un motor roto.
canario_futuro <- list(
  modelo_id = "PRUEBA.CANARIO_FUTURO", requiere = "objetivo",
  ajustar  = function(datos, spec) datos$objetivo,
  predecir = function(aj, h) {
    o <- max(q_a_ind(aj$periodo))
    aj$y[match(ind_a_q(o + seq_len(h)), aj$periodo)]
  }
)
set.seed(SEMILLA_RAIZ + 6L)
obj <- simular_objetivo(145L, 0.3, 0.01)
r5 <- tryCatch({ correr_backtest(list(objetivo = obj), list(canario_futuro), ors, exp_id = "V5"); "sin error" },
               error = function(e) conditionMessage(e))
if (!grepl("^G-3", r5)) stop("V5: el canario de filtración no detuvo al motor con G-3 (resultado: ", r5, ")")
r5b <- tryCatch({ guarda_recorte(obj, q_a_ind("2013-Q1"), nombre = "objetivo_sin_recortar"); "sin error" },
                error = function(e) conditionMessage(e))
if (!grepl("^G-1", r5b)) stop("V5: G-1 no detectó una serie sin recortar (resultado: ", r5b, ")")
ok("V5", "el canario que busca el futuro no lo encuentra y G-3 detiene el motor; G-1 rechaza una serie sin recortar")

# --- V6 · canario de mutación --------------------------------------------------------------------
# En R un data.frame se copia al modificarse, así que un modelo no puede alterar el insumo del motor
# modificando su argumento: el bloque certifica esa inmunidad (y que G-2 la vigila), en vez de esperar
# que el motor falle.
canario_mutante <- list(
  modelo_id = "PRUEBA.CANARIO_MUTANTE", requiere = "objetivo",
  ajustar  = function(datos, spec) { datos$objetivo$y[] <- 0; list(y_o = 0) },
  predecir = function(aj, h) rep(aj$y_o, h)
)
series6 <- list(objetivo = obj); huella <- digest::digest(series6)
p6 <- correr_backtest(series6, list(canario_mutante, modelo_rw_sin_deriva()), ors, exp_id = "V6")
if (!identical(digest::digest(series6), huella)) stop("V6: el estado maestro cambió después de la corrida")
rw6 <- p6[p6$modelo_id == "BENCH.RW_SIN_DERIVA", ]
if (!isTRUE(all.equal(rw6$log_nivel_pronosticado, obj$y[match(ind_a_q(rw6$origen), obj$periodo)]))) {
  stop("V6: el modelo que corrió después del canario vio un insumo alterado")
}
ok("V6", "un modelo que modifica su insumo no altera el estado maestro ni lo que ven los modelos siguientes")

# --- V10 · reproducibilidad ----------------------------------------------------------------------
canario_estocastico <- list(
  modelo_id = "PRUEBA.ESTOCASTICO", requiere = "objetivo",
  ajustar  = function(datos, spec) list(y_o = utils::tail(datos$objetivo$y, 1), ruido = stats::rnorm(8, 0, 0.01)),
  predecir = function(aj, h) aj$y_o + aj$ruido[seq_len(h)]
)
set.seed(SEMILLA_RAIZ + 10L)
obj <- simular_objetivo(145L, 0.3, 0.01)
corrida <- function(exp_id) {
  set.seed(1L)   # la semilla global previa no debe importar: el motor la fija por (exp, modelo, origen)
  p <- correr_backtest(list(objetivo = obj), c(modelos_referencia(), list(canario_estocastico)), ors, exp_id = exp_id)
  digest::digest(p, algo = "sha256")
}
h_a <- corrida("V10"); h_b <- corrida("V10")
if (!identical(h_a, h_b)) stop("V10: dos corridas con el mismo exp_id no son idénticas")
h_c <- corrida("V10_otro")
if (identical(h_a, h_c)) stop("V10: cambiar exp_id no cambió la semilla del modelo estocástico")
ok("V10", sprintf("dos corridas con los 6 benchmarks + un modelo estocástico: sha256 idéntico (%s…); otro exp_id cambia la semilla", substr(h_a, 1, 12)))

# --- Pruebas de significancia (paso 4; F4-12, F4-15..F4-18) -------------------------------------
# DGP común: error de pronóstico h pasos = suma de h innovaciones N(0,1) → MA(h-1), como el error
# óptimo de un paseo aleatorio. Pérdida cuadrática; los pares de las celdas son los de G1/G2/G3.
ma_err <- function(n, h, sd = 1) {
  u <- stats::rnorm(n + h - 1L, 0, sd)
  as.numeric(stats::filter(u, rep(1, h), sides = 1))[h:(n + h - 1L)]
}
CELDAS <- data.frame(grupo = rep(c("G1", "G2", "G3"), each = 4), h = rep(c(1L, 2L, 4L, 8L), 3),
                     n = c(52L, 51L, 49L, 45L, 45L, 44L, 42L, 38L, 25L, 24L, 22L, 18L))

# --- V7 · tamaño de DM/HLN (F4-18: estricto en h=1,2; reportado en h=4,8) ------------------------
R7 <- 2000L
cota7 <- stats::qbinom(0.995, R7, 0.05) / R7                     # cota superior 99% bajo tamaño 5%
set.seed(SEMILLA_RAIZ + 7L)
v7 <- do.call(rbind, lapply(seq_len(nrow(CELDAS)), function(i) {
  n <- CELDAS$n[i]; h <- CELDAS$h[i]
  s <- replicate(R7, { r <- prueba_dm_hln(ma_err(n, h), ma_err(n, h), h)
                       c(rech = r$p_valor < 0.05, resp = r$varianza != "rectangular") })
  cbind(CELDAS[i, ], tamano = mean(s["rech", ]), respaldo = mean(s["resp", ]))
}))
print(v7, row.names = FALSE, digits = 3)
malas7 <- v7[v7$h <= 2L & v7$tamano > cota7, ]
if (nrow(malas7) > 0) stop(sprintf("V7: DM/HLN sobre-rechaza en h<=2 (%s)", paste(malas7$grupo, malas7$h, collapse = ", ")))
ok("V7", sprintf("tamaño DM/HLN <= %.4f en h=1,2; h=4,8 reportado (máx %.3f): distorsión documentada", cota7, max(v7$tamano[v7$h >= 4L])))

# --- V8 · potencia de DM/HLN (solo reporte) -------------------------------------------------------
R8 <- 1000L
set.seed(SEMILLA_RAIZ + 8L)
v8 <- vapply(seq_len(nrow(CELDAS)), function(i) {
  n <- CELDAS$n[i]; h <- CELDAS$h[i]
  mean(replicate(R8, prueba_dm_hln(ma_err(n, h), ma_err(n, h, sqrt(0.8)), h)$p_valor < 0.05))
}, numeric(1))
ok("V8", sprintf("potencia ante pérdida 20%% menor, rango %.3f-%.3f (solo reporte)", min(v8), max(v8)))

# --- V9 · cobertura del MCS (α=0,10; F4-15, F4-18) ------------------------------------------------
perdidas_sim <- function(n, h, escala) {
  L <- sapply(escala, function(s) ma_err(n, h, sqrt(s))^2)
  colnames(L) <- paste0("M", seq_along(escala)); L
}
R9 <- 200L; B9 <- 500L; m9 <- 6L
set.seed(SEMILLA_RAIZ + 9L)
for (cfg in list(c(n = 52L, h = 1L), c(n = 45L, h = 8L), c(n = 18L, h = 8L))) {
  n <- cfg[["n"]]; h <- cfg[["h"]]
  eq  <- replicate(R9, all(mcs_tmax(perdidas_sim(n, h, rep(1, m9)), h, B = B9, semilla = sample.int(1e8, 1))$en_mcs))
  dom <- replicate(R9, mcs_tmax(perdidas_sim(n, h, c(0.8, rep(1, m9 - 1))), h, B = B9, semilla = sample.int(1e8, 1))$en_mcs[1])
  piso <- 0.90 - 2 * sqrt(0.09 / R9)                              # 1-α menos 2 errores de Monte Carlo
  if (mean(dom) < piso) stop(sprintf("V9: el modelo dominante queda fuera del MCS (n=%d h=%d: %.3f)", n, h, mean(dom)))
  if (h == 1L && mean(eq) < piso) stop(sprintf("V9: el MCS descarta modelos equivalentes en h=1 (%.3f)", mean(eq)))
  ok("V9", sprintf("n=%d h=%d: P(dominante en MCS)=%.3f; P(MCS completo | equivalentes)=%.3f%s",
                   n, h, mean(dom), mean(eq), if (h == 1L) "" else " (reportado)"))
}

# --- V11 · oráculo contra el paquete MCS (Suggests) -----------------------------------------------
if (requireNamespace("MCS", quietly = TRUE)) {
  set.seed(SEMILLA_RAIZ + 11L)
  L11 <- perdidas_sim(52L, 1L, c(0.5, 0.55, 1, 1, 1.5, 2))
  propio <- mcs_tmax(L11, 1L, B = 5000L, semilla = 11L)
  oraculo <- MCS::MCSprocedure(L11, alpha = 0.10, B = 5000, statistic = "Tmax", k = bloque_mcs(52L, 1L), verbose = FALSE)
  sup_o <- sort(rownames(oraculo@show)); sup_p <- sort(propio$modelo_id[propio$en_mcs])
  if (!identical(sup_o, sup_p)) stop(sprintf("V11: MCS propio {%s} distinto del oráculo {%s}", toString(sup_p), toString(sup_o)))
  ok("V11", sprintf("MCS propio coincide con MCS::MCSprocedure: {%s}", toString(sup_p)))
} else {
  cat("V11 SKIP  paquete MCS no instalado (Suggests)\n")
}

cat("verificación sintética: bloques OK (V1-V11)\n")
