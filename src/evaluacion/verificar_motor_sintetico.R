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
#   V11  MCS propio contra MCS::MCSprocedure (Suggests; SKIP si el paquete no está instalado, salvo
#        en CI, donde su ausencia detiene la corrida con stop())
# Bloque de la remediación de la auditoría independiente de Fase 4 (hallazgo I3):
#   V12  orquestación de motor_backtesting.R (correr_experimento(), X-13 por origen de F4-09b) sobre
#        insumos sintéticos en memoria: G2 principal con R3/R4, y R1, R2, R5 y R6 de G3; más dos
#        canarios (outlier LS no contemplado y NSA más allá del origen con el recorte saboteado)
# Bloque de la compuerta de Fase 5 (remediación de la auditoría independiente de Fase 4, hallazgo I2a;
# F4-33, decidida el 2026-09-29):
#   V13  densidad gaussiana: cobertura al 80/95 % dentro de ±3 ee de MC con el modelo verdadero, CRPS
#        del verdadero < paseo aleatorio, y CRPS propio contra scoringRules::crps_norm (Suggests)
#   V5   (extensión F4-34, al final del archivo) canario de predictora anual: UT solo con años cerrados
# Bloque de los univariados de Fase 5 (B1b; F5-06, F5-12):
#   V14  ARIMAX sobre un DGP con predictora adelantada: bate al AR(p)-BIC en h = 1, 2 (estricto), su densidad
#        del sistema conjunto cubre al nominal en h = 1, 2, 4 (±3 ee de MC más 0,03 de sesgo plug-in) y, con
#        una predictora placebo, no empeora al AR(p)-BIC en más de 10 % en h = 1
# Bloque de los multivariados de Fase 5 (B2a; F5-07, F5-12):
#   V15  VAR_DIF sobre un DGP VAR: bate al AR(p)-BIC en h = 1, 2 y su densidad cubre al nominal; VECM sobre un DGP
#        cointegrado: la traza elige r = 1, bate al VAR_DIF en h = 2, 4 y cubre; sin cointegración elige r = 0
#   V16  (B2b) BVAR sobre el DGP VAR de V15 más una NSA placebo: bate al AR(p)-BIC en h = 1, 2, su predictiva
#        posterior (B2-10) cubre al nominal en h = 1, 2, 4 y reejecutar reproduce bit a bit (F5-15)
# Bloque de la paridad Windows/Linux del BVAR (checklist F1; F5-15, decisiones F1-1, F1-2 y F1-3 reabierta):
#   V17  un BVAR fijo con la configuración de producción (primer origen de G1 y G3) reproduce byte a byte, en Windows,
#        la media y la covarianza de su predictiva y sus diagnósticos contra la referencia generada en Windows; en
#        otro sistema informa las diferencias en unidades del error de Monte Carlo, sin detenerse
# Bloque de los regularizados de Fase 5 (B3; F5-09, F5-11, F5-12, B3-1 a B3-7):
#   V18  elastic net sobre un DGP con una predictora adelantada entre ruidos (una NSA) y PCR sobre un DGP de factor: baten
#        al AR(p)-BIC en h = 1, 2; la densidad de errores internos cubre dentro de una holgura declarada (subcobertura
#        de hasta 0,10 además de 3 ee de MC); con un placebo el elastic net no empeora al AR(p)-BIC en más de 10 % en
#        h = 1; reejecutar reproduce bit a bit (F5-15)
# Bloque de la frecuencia mixta de Fase 5 (B3b; F5-08, F5-04, F5-12, B3b-1 a B3b-6):
#   V19  U-MIDAS y puente sobre un DGP con una predictora mensual cuyo promedio trimestral mueve al PIB y 2 meses de o+1
#        en el borde: baten al AR(p)-BIC en h = 1; la densidad del puente (sistema conjunto) cubre como V14 a V16 y la del
#        U-MIDAS con la holgura de V18; con un placebo no empeoran al AR(p)-BIC en más de 10 %; reejecutar reproduce bit a bit
# Bloque de los árboles de Fase 5 (B4; F5-10, F5-11, F5-12, F5-15, B4-1 a B4-6):
#   V20  random forest sobre un DGP no lineal (el PIB responde al valor absoluto de una predictora adelantada): bate al
#        AR(p)-BIC en h = 1; la densidad de errores internos cubre dentro de la holgura declarada de V18; con un placebo
#        no empeora al AR(p)-BIC en más de 10 % en h = 1; reejecutar reproduce bit a bit el RF y el LightGBM (F5-15)
# Bloque de la doble corrida de Fase 5 (C6; F5-15, F5-13):
#   V21  el registro de Fase 5 de G2 con la configuración de producción (con la variante Q1 de F5-11), los benchmarks y
#        las cuatro combinaciones sobre insumos sintéticos con los inicios de L3, en un Q1 y el origen siguiente: dos
#        corridas con el mismo exp_id dan sha256 idéntico; otro exp_id cambia la semilla del BVAR y del RF
#
# Uso: Rscript src/evaluacion/verificar_motor_sintetico.R   (make eval-sintetico)

source(here::here("src", "evaluacion", "eval_lib.R"))
source(here::here("src", "evaluacion", "modelos_referencia.R"))
source(here::here("src", "evaluacion", "modelos_univariados.R"))   # V14 (B1b)
source(here::here("src", "evaluacion", "modelos_multivariados.R")) # V15 (B2a) y V16 (B2b)
source(here::here("src", "evaluacion", "paridad_bvar.R"))          # V17 (F1)
source(here::here("src", "evaluacion", "forma_directa.R"))          # V18 (B3)
source(here::here("src", "evaluacion", "modelos_regularizados.R"))  # V18 (B3)
source(here::here("src", "evaluacion", "modelos_frecuencia_mixta.R")) # V19 (B3b)
source(here::here("src", "evaluacion", "modelos_arboles.R"))        # V20 (B4)

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
  # El paquete remuestrea con bloques móviles fijos y el motor con bootstrap estacionario (F4-15), así
  # que la comparación se hace con las MISMAS remuestras: se reconstruyen los índices del paquete con
  # su semilla y se pasan al motor. Lo que se contrasta es el estadístico T_max y la eliminación.
  k11 <- bloque_mcs(52L, 1L); B11 <- 2000L; s11 <- 11L
  for (esc in list(c(0.5, 0.55, 1, 1, 1.5, 2), c(1, 1.1, 1.2, 1.3))) {
    L11 <- perdidas_sim(52L, 1L, esc)
    oraculo <- MCS::MCSprocedure(L11, alpha = 0.10, B = B11, statistic = "Tmax", k = k11, verbose = FALSE, seed = s11)@show
    set.seed(s11); idx11 <- t(MCS:::GetIndices(52L, k11, B11))
    propio <- mcs_tmax(L11, 1L, semilla = s11, indices = idx11)
    dif <- max(abs(propio$p_mcs[match(rownames(oraculo), propio$modelo_id)] - oraculo[, "MCS p-Value"]))
    if (dif > 1e-12) stop(sprintf("V11: p-valores MCS propios difieren del oráculo (máx %.3g)", dif))
    ok("V11", sprintf("%d modelos: p-valores MCS idénticos a MCS::MCSprocedure con las mismas remuestras (máx |dif| %.1g)",
                      length(esc), dif))
  }
} else {
  # En CI el oráculo es obligatorio: MCS está fijado en renv.lock (Suggests, 8c4dec7), así que su
  # ausencia es un lockfile roto, no una máquina sin el paquete (hallazgo M6, remediación de la
  # auditoría independiente de Fase 4).
  if (identical(Sys.getenv("CI"), "true"))
    stop("V11: paquete MCS no instalado en CI; renv.lock lo fija como oráculo (Suggests)")
  cat("V11 SKIP  paquete MCS no instalado (Suggests)\n")
  V11_SKIP <- TRUE
}

# --- V12 · orquestación con X-13 por origen sobre insumos sintéticos ------------------------------
# Hallazgo I3 de la auditoría independiente de Fase 4: el bucle de motor_backtesting.R (ajuste X-13
# por origen de F4-09b, caché por tramo, R1-R6, submuestras de R3/R4, bases del origen y token) no
# se ejercía en CI. Este bloque corre correr_experimento() sobre un objetivo sintético con la misma
# grilla de fechas que el real y dos AO declarados en 2020-Q2/Q3. No lee data/ ni escribe nada: no
# llama a escribir_experimento() ni a registrar_experimentos(), y main() no corre al hacer source().
source(here::here("src", "evaluacion", "motor_backtesting.R"))
set.seed(SEMILLA_RAIZ + 12L)
per12   <- PERIODOS_OBJ
n12     <- length(per12)
estac12 <- rep(c(-0.03, 0.01, 0.00, 0.02), length.out = n12)                # estacionalidad conocida
# Δy AR(1) con φ = 0,5: con un paseo con deriva puro, AR(p)-BIC elige p = 0 y replica al paseo con
# deriva, y el MCS se detiene por varianza bootstrap nula (pérdidas idénticas).
ly12    <- simular_objetivo(n12, phi = 0.5, sigma = 0.008, c0 = 0.003, y0 = 4.6)$y
i20     <- match(c("2020-Q2", "2020-Q3"), per12); ly12[i20] <- ly12[i20] + c(-0.20, -0.08)   # los dos AO
i05     <- q_a_ind(per12) >= q_a_ind(INICIO_HOMOGENEO)
insumos12 <- list(
  objetivos = list(
    PIB_SA_PROPIO_Q  = data.frame(periodo = per12, y = ly12, vintage_id = "SINT.v1", stringsAsFactors = FALSE),
    PIB_SA_OFICIAL_Q = data.frame(periodo = per12[i05], y = ly12[i05] + 0.001, vintage_id = "SINT.v1", stringsAsFactors = FALSE)),
  nsa      = data.frame(periodo = per12, valor = exp(ly12 + estac12), vintage_id = "SINT.v1", stringsAsFactors = FALSE),
  outliers = data.frame(periodo = c("2020-Q2", "2020-Q3"), tipo = "AO", stringsAsFactors = FALSE))
cache12 <- new.env()
exps12  <- c("F4_BENCH_G2", "F4_BENCH_G3_R1", "F4_BENCH_G3_R2", "F4_BENCH_G3_R5", "F4_BENCH_G3_R6")
PARES12 <- list(G2 = c(45L, 44L, 42L, 38L), G3 = c(25L, 24L, 22L, 18L))
INICIO12 <- c(F4_BENCH_G3_R1 = "1997-Q1", F4_BENCH_G3_R2 = "2005-Q1", F4_BENCH_G3_R5 = "2005-Q1")
for (id12 in exps12) {
  ex12 <- EXPERIMENTOS[EXPERIMENTOS$exp_id == id12, ]
  if (nrow(ex12) != 1L) stop("V12: el experimento ", id12, " no está declarado en EXPERIMENTOS")
  r12 <- correr_experimento(ex12, insumos12, cache12)
  # 1. pares por horizonte del grupo
  np <- tapply(r12$metricas$n_pares, r12$metricas$h, unique)
  if (!identical(as.integer(unlist(np)), PARES12[[ex12$grupo]]))
    stop(sprintf("V12 %s: pares por horizonte %s, se esperan %s", id12, paste(unlist(np), collapse = "/"),
                 paste(PARES12[[ex12$grupo]], collapse = "/")))
  # 2. ajuste por origen: AO que entran solo desde el origen que los alcanza, transform=log
  if (ex12$sa == "reestimado_en_origen") {
    aj <- r12$ajuste_estacional
    if (is.null(aj) || nrow(aj) != length(origenes_grupo(ex12$grupo))) stop("V12 ", id12, ": falta una fila de ajuste por origen")
    oi <- q_a_ind(aj$origen)
    esp <- ifelse(oi < q_a_ind("2020-Q2"), "", ifelse(oi < q_a_ind("2020-Q3"), "2020-Q2", "2020-Q2 2020-Q3"))
    if (!identical(aj$ao_declarados, esp)) stop("V12 ", id12, ": AO declarados por origen distintos de F4-09b")
    reg <- tolower(aj$regresores)
    if (any(grepl("ao20", reg[oi < q_a_ind("2020-Q2")])) ||
        !all(grepl("ao2020.2", reg[oi >= q_a_ind("2020-Q2")], fixed = TRUE)) ||
        any(grepl("ao2020.3", reg[oi < q_a_ind("2020-Q3")], fixed = TRUE)) ||
        !all(grepl("ao2020.3", reg[oi >= q_a_ind("2020-Q3")], fixed = TRUE)))
      stop("V12 ", id12, ": regresores AO del modelo X-13 fuera de su origen")
    if (!all(trimws(aj$transform) == "log")) stop("V12 ", id12, ": algún origen no usó transform=log")
  } else if (!is.null(r12$ajuste_estacional)) {
    stop("V12 ", id12, ": sa=l3_unico no debe registrar ajuste por origen")
  }
  # 3. paseo aleatorio sin deriva: sendero plano y yoy exactamente 0 en h = 4 (su nivel es la base)
  rw <- r12$pronosticos[r12$pronosticos$modelo_id == BENCHMARK, ]
  if (!nrow(rw) || any(rw$yoy_pp_pronosticado[rw$h == 4L] != 0))
    stop("V12 ", id12, ": el yoy del paseo sin deriva en h = 4 no es exactamente 0")
  if (any(tapply(rw$log_nivel_pronosticado, rw$origen, function(x) length(unique(x))) != 1L))
    stop("V12 ", id12, ": el sendero del paseo sin deriva no es plano")
  # 4. submuestras de R3/R4 y contraste de estabilidad (solo la principal de G2)
  if (id12 == "F4_BENCH_G2") {
    if (is.null(r12$sub) || !setequal(unique(r12$sub$metricas$muestra_eval), c("pre2020", "post2020", "sin_2020", "sin_2020_2021")))
      stop("V12 F4_BENCH_G2: faltan submuestras de R3/R4")
    if (is.null(r12$estabilidad) || nrow(r12$estabilidad) != 20L) stop("V12 F4_BENCH_G2: estabilidad no trae 20 filas")
  }
  # 5. inicio de la muestra de estimación de R1, R2 y R5
  if (id12 %in% names(INICIO12) && !identical(r12$muestra_inicio, INICIO12[[id12]]))
    stop(sprintf("V12 %s: muestra_inicio %s, se espera %s", id12, r12$muestra_inicio, INICIO12[[id12]]))
  # 6. token
  validar_token(r12$token)
  ok("V12", sprintf("%-15s pares %s; %s; token válido", id12, paste(unlist(np), collapse = "/"),
                    if (is.null(r12$ajuste_estacional)) "sa=l3_unico" else sprintf("%d ajustes X-13 por origen", nrow(r12$ajuste_estacional))))
}
# Canarios negativos (C3), con tryCatch y grepl sobre el mensaje como V5.
o12 <- q_a_ind("2021-Q1")
c12a <- tryCatch({ ajustar_en_origen(insumos12$nsa, data.frame(periodo = "2020-Q2", tipo = "LS", stringsAsFactors = FALSE), o12); "sin error" },
                 error = function(e) conditionMessage(e))
if (!grepl("tipo de outlier declarado no contemplado por F4-09b", c12a, fixed = TRUE))
  stop("V12: un outlier LS declarado no detuvo el ajuste por origen (resultado: ", c12a, ")")
# NSA más allá del origen con el recorte saboteado: la guarda G-1 (segundo cerrojo) debe detenerlo.
ajustar_sin_recorte <- ajustar_en_origen
environment(ajustar_sin_recorte) <- list2env(list(recortar_a_origen = function(d, o, ...) d), parent = globalenv())
c12b <- tryCatch({ ajustar_sin_recorte(insumos12$nsa, insumos12$outliers, o12); "sin error" },
                 error = function(e) conditionMessage(e))
if (!grepl("^G-1", c12b)) stop("V12: una NSA más allá del origen no detuvo el ajuste con G-1 (resultado: ", c12b, ")")
ok("V12", sprintf("canarios: LS 2020-Q2 detiene el ajuste (F4-09b) y una NSA más allá del origen lo detiene con G-1; %d ajustes X-13 en caché",
                  length(ls(cache12))))

# --- V13 · densidad: cobertura y CRPS sobre un DGP conocido (F4-33) --------------------------------
# Remediación del hallazgo I2(a) de la auditoría independiente de Fase 4. Con un AR(1) gaussiano en Δy
# y la densidad del modelo verdadero (coeficientes y σ conocidos), la cobertura empírica al 80 % y al
# 95 % de la tasa interanual debe quedar dentro de ±3 errores de Monte Carlo del nominal en cada h, y
# el CRPS medio del modelo verdadero debe ser menor que el del paseo aleatorio sin deriva. El error de
# Monte Carlo sale de la dispersión entre réplicas independientes, así que tolera la superposición de
# los pares dentro de cada réplica en h > 1.
modelo_ar1_verdadero_dens <- function(c0, phi, sigma) {
  m <- modelo_ar1_verdadero(c0, phi)
  m$predecir_densidad <- function(aj, h) list(media = .recursion_ar(c0, phi, aj$dy, aj$y_o, h),
                                              cov = cov_desde_pesos(pesos_ar_dy(phi, h), sigma^2))
  m
}
set.seed(SEMILLA_RAIZ + 13L)
R13 <- 150L; c13 <- 0.003; phi13 <- 0.5; s13 <- 0.01
mods13 <- list(modelo_ar1_verdadero_dens(c13, phi13, s13), modelo_rw_sin_deriva())
rep13 <- lapply(seq_len(R13), function(r) {
  sim <- simular_objetivo(145L, phi13, s13, c0 = c13)
  p <- correr_backtest(list(objetivo = sim), mods13, ors, exp_id = "V13", densidad = TRUE)
  m <- metricas_por_horizonte(calcular_errores(p, sim))
  m[m$unidad == "yoy_pp", c("modelo_id", "h", "cobertura_80", "cobertura_95", "crps")]
})
t13 <- do.call(rbind, rep13)
for (h in DISENO_FASE4$horizontes) {
  v <- t13[t13$modelo_id == "PRUEBA.AR1_VERDADERO" & t13$h == h, ]
  rw <- t13[t13$modelo_id == "BENCH.RW_SIN_DERIVA" & t13$h == h, ]
  for (nv in c(80, 95)) {
    x <- v[[paste0("cobertura_", nv)]]; ee <- stats::sd(x) / sqrt(R13)
    if (abs(mean(x) - nv / 100) > 3 * ee)
      stop(sprintf("V13: cobertura al %d%% en h=%d fuera de ±3 errores de Monte Carlo (%.3f, ee %.4f)", nv, h, mean(x), ee))
  }
  if (!(mean(v$crps) < mean(rw$crps))) stop(sprintf("V13: en h=%d el CRPS del modelo verdadero (%.3f) no es menor que el del paseo (%.3f)", h, mean(v$crps), mean(rw$crps)))
  ok("V13", sprintf("h=%d: cobertura 80%% %.3f y 95%% %.3f (±3 ee de MC); CRPS verdadero %.3f < paseo %.3f",
                    h, mean(v$cobertura_80), mean(v$cobertura_95), mean(v$crps), mean(rw$crps)))
}
# Oráculo del CRPS (Suggests; F4-33): scoringRules::crps_norm con los mismos argumentos.
if (requireNamespace("scoringRules", quietly = TRUE)) {
  set.seed(SEMILLA_RAIZ + 131L)
  y13 <- stats::rnorm(500, 0, 3); mu13 <- stats::rnorm(500); sg13 <- stats::rexp(500) + 0.05
  dif13 <- max(abs(crps_normal(y13, mu13, sg13) - scoringRules::crps_norm(y13, mean = mu13, sd = sg13)))
  if (dif13 > 1e-10) stop(sprintf("V13: CRPS propio difiere de scoringRules::crps_norm (máx %.3g)", dif13))
  ok("V13", sprintf("CRPS gaussiano propio idéntico a scoringRules::crps_norm en 500 casos (máx |dif| %.1g)", dif13))
} else {
  if (identical(Sys.getenv("CI"), "true"))
    stop("V13: paquete scoringRules no instalado en CI; renv.lock lo fija como oráculo (Suggests)")
  cat("V13 SKIP  oráculo scoringRules no instalado (Suggests)\n")
}

# --- V5 (extensión F4-34) · canario de predictora anual -------------------------------------------
# Remediación del hallazgo I2(b), E4. Mecanismo retenido: una predictora de grano anual entra solo con
# años cerrados, el año `a` desde el origen (a+1)-Q1. UT dejó de usarlo (F5-04, 2026-10-05: rezago de
# 30 días, cubierto en tests/test-evaluacion.R §13), pero la rama sigue siendo parte del motor y se
# prueba aquí. El canario busca en su insumo el año del propio origen; con el
# recorte correcto no lo encuentra, devuelve NA y G-3 detiene el motor. Va al final del archivo, y no
# junto a V5, para que la salida de V1-V11 siga idéntica byte a byte a doc/evidencia_cierre_fase4.txt.
canario_anual <- list(
  modelo_id = "PRUEBA.CANARIO_ANUAL", requiere = c("objetivo", "ut"),
  ajustar  = function(datos, spec) list(o = max(q_a_ind(datos$objetivo$periodo)), ut = datos$ut, y_o = utils::tail(datos$objetivo$y, 1)),
  predecir = function(aj, h) {
    en_curso <- aj$ut$valor[anio_de_periodo(aj$ut$periodo) == aj$o %/% 4L]
    if (length(en_curso)) rep(aj$y_o + mean(en_curso) * 0, h) else rep(NA_real_, h)
  }
)
set.seed(SEMILLA_RAIZ + 55L)
obj5b <- simular_objetivo(145L, 0.3, 0.01)
im5b <- m_a_ind("2002-M01"):m_a_ind("2025-M12")
ut5b <- data.frame(periodo = sprintf("%d-M%02d", im5b %/% 12L, im5b %% 12L + 1L), valor = stats::rnorm(length(im5b), 500, 20),
                   stringsAsFactors = FALSE)
r5c <- tryCatch({ correr_backtest(list(objetivo = obj5b, ut = ut5b), list(canario_anual), ors, exp_id = "V5b",
                                  rezagos = list(ut = REZAGO_ANUAL_CERRADO)); "sin error" },
                error = function(e) conditionMessage(e))
if (!grepl("^G-3", r5c)) stop("V5: el canario anual no detuvo al motor con G-3 (resultado: ", r5c, ")")
r5d <- tryCatch({ guarda_recorte(ut5b, q_a_ind("2019-Q3"), REZAGO_ANUAL_CERRADO, nombre = "ut_sin_recortar"); "sin error" },
                error = function(e) conditionMessage(e))
if (!grepl("^G-1", r5d)) stop("V5: G-1 no detectó una predictora anual con el año en curso (resultado: ", r5d, ")")
ok("V5", "canario anual (F4-34, rama retenida): la predictora anual no trae el año del origen y G-3 detiene el motor; G-1 rechaza el año en curso")

# --- V14 · ARIMAX con predictora adelantada (B1b; F5-06, F5-12) -----------------------------------
# DGP: x_t = 0,6 x_{t-1} + u_t (Δlog de una predictora SA), Δy_t = 0,004 + β x_{t-1} + e_t, con σ_u = 0,02 y
# σ_e = 0,006. Con β = 0,4 la predictora adelanta al objetivo: en h = 1 el ARIMAX conoce x_o y su error es e, mientras
# el AR(p)-BIC sobre Δy solo recupera x_o a medias. La predictora trimestral entra hasta el origen (rezago de 30 días,
# F5-04) y se proyecta con su AR(p)-BIC (F5-05); la densidad es la del sistema conjunto (F5-12, B1-5). La cobertura
# se exige con una holgura de 0,03 además de ±3 ee de MC: la densidad es plug-in en los parámetros estimados con
# unas 90 observaciones, así que algo de subcobertura en h = 4 es esperable y se declara. Con β = 0 (placebo) el
# ARIMAX no debe empeorar al AR(p)-BIC en más de 10 % en h = 1.
sim_v14 <- function(beta, n = 145L, phx = 0.6, sx = 0.02, se = 0.006) {
  x <- numeric(n); dy <- numeric(n); u <- stats::rnorm(n, 0, sx); e <- stats::rnorm(n, 0, se)
  for (t in 2:n) { x[t] <- phx * x[t - 1] + u[t]; dy[t] <- 0.004 + beta * x[t - 1] + e[t] }
  list(objetivo = data.frame(periodo = PERIODOS_OBJ, y = 4 + cumsum(dy), stringsAsFactors = FALSE),
       PRUEBA.X.SA.Q = data.frame(periodo = PERIODOS_OBJ, valor = 100 * exp(cumsum(x)), stringsAsFactors = FALSE))
}
mods14 <- list(modelo_arimax("PRUEBA.ARIMAX", "PRUEBA.X.SA.Q", rezagos_x = 0:1, p_max = 1L, q_max = 1L), modelo_arp_bic())
corrida14 <- function(beta, R, semilla) {
  set.seed(semilla)
  do.call(rbind, lapply(seq_len(R), function(r) {
    s <- sim_v14(beta)
    p <- correr_backtest(s, mods14, ors, rezagos = list(PRUEBA.X.SA.Q = 30L), exp_id = "V14", densidad = TRUE)
    m <- metricas_por_horizonte(calcular_errores(p, s$objetivo))
    m[m$unidad == "yoy_pp", c("modelo_id", "h", "rmse", "cobertura_80", "cobertura_95")]
  }))
}
R14 <- 20L
t14 <- corrida14(0.4, R14, SEMILLA_RAIZ + 14L)
for (h in c(1L, 2L, 4L)) {
  ax <- t14[t14$modelo_id == "PRUEBA.ARIMAX" & t14$h == h, ]; ar <- t14[t14$modelo_id == "BENCH.ARP_BIC" & t14$h == h, ]
  razon <- mean(ax$rmse) / mean(ar$rmse)
  if (h <= 2L && !(razon < 0.8)) stop(sprintf("V14: en h=%d el ARIMAX no bate al AR(p)-BIC con la predictora adelantada (razón de RMSE %.3f)", h, razon))
  for (nv in c(80, 95)) {
    x <- ax[[paste0("cobertura_", nv)]]; ee <- stats::sd(x) / sqrt(R14)
    if (abs(mean(x) - nv / 100) > 3 * ee + 0.03)
      stop(sprintf("V14: cobertura del ARIMAX al %d%% en h=%d fuera de ±(3 ee + 0,03) del nominal (%.3f, ee %.4f)", nv, h, mean(x), ee))
  }
  ok("V14", sprintf("h=%d: RMSE ARIMAX / AR(p)-BIC %.3f%s; cobertura 80%% %.3f y 95%% %.3f", h, razon,
                    if (h <= 2L) " (< 0,8)" else "", mean(ax$cobertura_80), mean(ax$cobertura_95)))
}
t14b <- corrida14(0, 10L, SEMILLA_RAIZ + 141L)
razon_b <- mean(t14b$rmse[t14b$modelo_id == "PRUEBA.ARIMAX" & t14b$h == 1L]) / mean(t14b$rmse[t14b$modelo_id == "BENCH.ARP_BIC" & t14b$h == 1L])
if (!(razon_b < 1.10)) stop(sprintf("V14: con una predictora placebo el ARIMAX empeora al AR(p)-BIC en h=1 (razón %.3f)", razon_b))
ok("V14", sprintf("placebo (β = 0): RMSE ARIMAX / AR(p)-BIC en h=1 %.3f (< 1,10)", razon_b))

# --- V15 · VAR y VECM (B2a; F5-07, F5-12) ---------------------------------------------------------
# Tres DGP de dos series (PIB y una predictora SA, sin dummies):
#   "var"    el de V14 (x_t = 0,6 x_{t-1} + u_t, Δy_t = 0,004 + 0,4 x_{t-1} + e_t): un VAR(1) en diferencias. El
#            VAR_DIF debe batir al AR(p)-BIC en h = 1, 2 (razón de RMSE < 0,8) y su densidad (pesos MA, F5-12) cubrir
#            al nominal en h = 1, 2, 4 dentro de ±3 ee de MC más 0,03 de holgura plug-in, como V14.
#   "coint"  x paseo con deriva y Δy_t = 0,004 − 0,25 (y_{t-1} − x_{t-1} − 0,5) + e_t: una relación de cointegración
#            con corrección en el PIB. La traza de Johansen al 5 % (B2-3) debe encontrar r = 1 en al menos el 80 % de
#            los orígenes, el VECM debe batir al VAR_DIF en h = 2, 4 (razón de RMSE < 0,9) y su densidad cubrir como
#            arriba. En h = 8 la pérdida interanual compara o+8 con o+4, dos puntos que la corrección ya alcanzó, y
#            la ventaja casi desaparece (razón ≈ 0,97 en la calibración): no se exige.
#   "indep"  dos paseos independientes: r = 0, y el VECM es el VAR en diferencias anidado (B2-4), en al menos el 80 %
#            de los orígenes.
sim_v15 <- function(tipo, n = 145L, sx = 0.01, se = 0.006) {
  x <- numeric(n); y <- numeric(n); u <- stats::rnorm(n, 0, sx); e <- stats::rnorm(n, 0, se)
  if (tipo == "var") {
    dx <- numeric(n); dy <- numeric(n); u <- 2 * u
    for (t in 2:n) { dx[t] <- 0.6 * dx[t - 1] + u[t]; dy[t] <- 0.004 + 0.4 * dx[t - 1] + e[t] }
    x <- cumsum(dx); y <- 4 + cumsum(dy)
  } else {
    x[1] <- 3.5; y[1] <- 4
    for (t in 2:n) {
      x[t] <- x[t - 1] + 0.004 + u[t]
      y[t] <- y[t - 1] + 0.004 + (if (tipo == "coint") -0.25 * (y[t - 1] - x[t - 1] - 0.5) else 0) + e[t]
    }
  }
  list(objetivo = data.frame(periodo = PERIODOS_OBJ, y = y, stringsAsFactors = FALSE),
       PRUEBA.X.SA.Q = data.frame(periodo = PERIODOS_OBJ, valor = 100 * exp(x), stringsAsFactors = FALSE))
}
mods15 <- list(modelo_var("PRUEBA.VAR_DIF", "PRUEBA.X.SA.Q", 2L, "dif"), modelo_vecm("PRUEBA.VECM", "PRUEBA.X.SA.Q"), modelo_arp_bic())
corrida15 <- function(tipo, R, semilla) {
  set.seed(semilla)
  res <- lapply(seq_len(R), function(r) {
    s <- sim_v15(tipo)
    p <- correr_backtest(s, mods15, ors, rezagos = list(PRUEBA.X.SA.Q = 30L), exp_id = "V15", densidad = TRUE)
    m <- metricas_por_horizonte(calcular_errores(p, s$objetivo))
    d <- attr(p, "diagnosticos")
    list(m = m[m$unidad == "yoy_pp", c("modelo_id", "h", "rmse", "cobertura_80", "cobertura_95")],
         r = d$valor[d$modelo_id == "PRUEBA.VECM" & d$clave == "r"])
  })
  list(m = do.call(rbind, lapply(res, `[[`, "m")), r = unlist(lapply(res, `[[`, "r")))
}
cobertura15 <- function(tab, id, etiqueta) for (h in c(1L, 2L, 4L)) for (nv in c(80, 95)) {
  x <- tab[tab$modelo_id == id & tab$h == h, ][[paste0("cobertura_", nv)]]; ee <- stats::sd(x) / sqrt(length(x))
  if (abs(mean(x) - nv / 100) > 3 * ee + 0.03)
    stop(sprintf("V15: cobertura de %s al %d%% en h=%d fuera de ±(3 ee + 0,03) del nominal (%.3f, ee %.4f; DGP %s)", id, nv, h, mean(x), ee, etiqueta))
}
razon15 <- function(tab, a, b, h) mean(tab$rmse[tab$modelo_id == a & tab$h == h]) / mean(tab$rmse[tab$modelo_id == b & tab$h == h])
t15 <- corrida15("var", 20L, SEMILLA_RAIZ + 15L)
for (h in c(1L, 2L)) {
  rz <- razon15(t15$m, "PRUEBA.VAR_DIF", "BENCH.ARP_BIC", h)
  if (!(rz < 0.8)) stop(sprintf("V15: en h=%d el VAR_DIF no bate al AR(p)-BIC en un DGP VAR (razón de RMSE %.3f)", h, rz))
  ok("V15", sprintf("DGP VAR, h=%d: RMSE VAR_DIF / AR(p)-BIC %.3f (< 0,8)", h, rz))
}
cobertura15(t15$m, "PRUEBA.VAR_DIF", "VAR")
ok("V15", sprintf("DGP VAR: cobertura del VAR_DIF 80%% %s y 95%% %s en h = 1, 2, 4",
                  paste(sprintf("%.3f", sapply(c(1L, 2L, 4L), function(h) mean(t15$m$cobertura_80[t15$m$modelo_id == "PRUEBA.VAR_DIF" & t15$m$h == h]))), collapse = "/"),
                  paste(sprintf("%.3f", sapply(c(1L, 2L, 4L), function(h) mean(t15$m$cobertura_95[t15$m$modelo_id == "PRUEBA.VAR_DIF" & t15$m$h == h]))), collapse = "/")))
t15c <- corrida15("coint", 10L, SEMILLA_RAIZ + 151L)
fr1 <- mean(t15c$r == 1)
if (!(fr1 >= 0.8)) stop(sprintf("V15: con una relación de cointegración la traza elige r = 1 solo en %.0f%% de los orígenes", 100 * fr1))
for (h in c(2L, 4L)) {
  rz <- razon15(t15c$m, "PRUEBA.VECM", "PRUEBA.VAR_DIF", h)
  if (!(rz < 0.9)) stop(sprintf("V15: en h=%d el VECM no bate al VAR_DIF en un DGP cointegrado (razón de RMSE %.3f)", h, rz))
}
cobertura15(t15c$m, "PRUEBA.VECM", "cointegrado")
ok("V15", sprintf("DGP cointegrado: r = 1 en %.0f%% de los orígenes; RMSE VECM / VAR_DIF %.3f (h=2) y %.3f (h=4) (< 0,9); cobertura del VECM en h = 1, 2, 4 dentro de tolerancia",
                  100 * fr1, razon15(t15c$m, "PRUEBA.VECM", "PRUEBA.VAR_DIF", 2L), razon15(t15c$m, "PRUEBA.VECM", "PRUEBA.VAR_DIF", 4L)))
t15i <- corrida15("indep", 10L, SEMILLA_RAIZ + 152L)
fr0 <- mean(t15i$r == 0)
if (!(fr0 >= 0.8)) stop(sprintf("V15: con dos paseos independientes la traza elige r = 0 solo en %.0f%% de los orígenes", 100 * fr0))
ok("V15", sprintf("DGP sin cointegración: r = 0 (VECM anidado en diferencias, B2-4) en %.0f%% de los orígenes", 100 * fr0))

# --- V16 · BVAR (B2b; F5-07, F5-12, B2-5, B2-10 a B2-16) -------------------------------------------
# DGP "var" de V15 (PIB y una predictora SA: un VAR(1) en diferencias) más una tercera serie NSA sin relación con el
# PIB: un paseo con deriva de 0,01 por trimestre y un estacional determinista de amplitud 0,04, que el BVAR recibe
# desestacionalizada dentro del origen (B2-5, B2-14). El BVAR (p = 4; priors, ψ y MH de producción: B2-7, B2-11, B2-12,
# B2-15, B2-16) corre con 2 000 extracciones y 1 000 de quemado para acotar el costo del canario (la configuración de
# producción se prueba en tests/test-modelo-bvar.R), en uno de cada cuatro orígenes del diseño y con 6 réplicas (unos
# 4 minutos). Se exige: razón de RMSE contra el AR(p)-BIC < 0,85 en h = 1, 2; cobertura de la predictiva posterior
# (B2-10) en h = 1, 2, 4 dentro de ±3 ee de MC más 0,03, como V14 y V15 (con ψ = σ en lugar de σ², B2-16, la cobertura
# al 80 % en h = 1 sale cerca de 0,99 y el bloque falla); y que reejecutar dos orígenes reproduzca bit a bit sendero
# y densidad (F5-15).
sim_v16 <- function() {
  s <- sim_v15("var"); n <- length(PERIODOS_OBJ)
  z <- 3 + cumsum(0.01 + stats::rnorm(n, 0, 0.015)) + c(0.04, -0.01, -0.04, 0.01)[q_a_ind(PERIODOS_OBJ) %% 4L + 1L]
  s$PRUEBA.Z.NSA.Q <- data.frame(periodo = PERIODOS_OBJ, valor = 100 * exp(z), stringsAsFactors = FALSE)
  s
}
ors16 <- ors[seq(1L, length(ors), by = 4L)]
mods16 <- list(modelo_bvar("PRUEBA.BVAR", c("PRUEBA.X.SA.Q", "PRUEBA.Z.NSA.Q"), n_draw = 2000L, n_burn = 1000L), modelo_arp_bic())
corrida16 <- function(R, semilla) {
  set.seed(semilla)
  res <- lapply(seq_len(R), function(r) {
    s <- sim_v16()
    p <- correr_backtest(s, mods16, ors16, rezagos = list(PRUEBA.X.SA.Q = 30L, PRUEBA.Z.NSA.Q = 30L), exp_id = "V16", densidad = TRUE)
    m <- metricas_por_horizonte(calcular_errores(p, s$objetivo))
    list(m = m[m$unidad == "yoy_pp", c("modelo_id", "h", "rmse", "cobertura_80", "cobertura_95")], p = p, s = s)
  })
  list(m = do.call(rbind, lapply(res, `[[`, "m")), p = lapply(res, `[[`, "p"), s = lapply(res, `[[`, "s"))
}
t16 <- corrida16(6L, SEMILLA_RAIZ + 16L)
for (h in c(1L, 2L)) {
  rz <- razon15(t16$m, "PRUEBA.BVAR", "BENCH.ARP_BIC", h)
  if (!(rz < 0.85)) stop(sprintf("V16: en h=%d el BVAR no bate al AR(p)-BIC en un DGP VAR (razón de RMSE %.3f)", h, rz))
  ok("V16", sprintf("DGP VAR + NSA placebo, h=%d: RMSE BVAR / AR(p)-BIC %.3f (< 0,85)", h, rz))
}
for (h in c(1L, 2L, 4L)) for (nv in c(80, 95)) {
  x <- t16$m[t16$m$modelo_id == "PRUEBA.BVAR" & t16$m$h == h, ][[paste0("cobertura_", nv)]]; ee <- stats::sd(x) / sqrt(length(x))
  if (abs(mean(x) - nv / 100) > 3 * ee + 0.03)
    stop(sprintf("V16: cobertura del BVAR al %d%% en h=%d fuera de ±(3 ee + 0,03) del nominal (%.3f, ee %.4f)", nv, h, mean(x), ee))
}
ok("V16", sprintf("cobertura de la predictiva posterior del BVAR 80%% %s y 95%% %s en h = 1, 2, 4",
                  paste(sprintf("%.3f", sapply(c(1L, 2L, 4L), function(h) mean(t16$m$cobertura_80[t16$m$modelo_id == "PRUEBA.BVAR" & t16$m$h == h]))), collapse = "/"),
                  paste(sprintf("%.3f", sapply(c(1L, 2L, 4L), function(h) mean(t16$m$cobertura_95[t16$m$modelo_id == "PRUEBA.BVAR" & t16$m$h == h]))), collapse = "/")))
p16b <- correr_backtest(t16$s[[1]], mods16[1], ors16[1:2], rezagos = list(PRUEBA.X.SA.Q = 30L, PRUEBA.Z.NSA.Q = 30L), exp_id = "V16", densidad = TRUE)
p16a <- t16$p[[1]]; p16a <- p16a[p16a$modelo_id == "PRUEBA.BVAR" & p16a$origen %in% ors16[1:2], ]; rownames(p16a) <- NULL
attr(p16a, "diagnosticos") <- NULL; attr(p16b, "diagnosticos") <- NULL   # se comparan los pronósticos
if (!identical(p16a, p16b)) stop("V16: reejecutar el BVAR con la misma semilla del motor no reproduce bit a bit sus pronósticos (F5-15)")
ok("V16", "reejecutar dos orígenes reproduce bit a bit sendero y densidad del BVAR (semilla del motor, F5-15)")

# --- V17 · Paridad Windows/Linux del BVAR (checklist F1; F5-15, decisiones F1-1, F1-2 y F1-3 reabierta) ---------------
# Un BVAR fijo (src/evaluacion/paridad_bvar.R): configuración de producción (p = 4, 10 000/5 000; B2-7) en el primer
# origen de G1 (3 series) y G3 (9 series), con los datos sintéticos de la prueba de producción y la siembra del motor.
# Se comparan los bytes de la media y la covarianza de su predictiva en h = 1..8 y de sus diagnósticos con
# src/evaluacion/referencias/paridad_bvar.csv, generada en Windows, la máquina de la corrida única. En Windows deben
# ser idénticos (F5-15: en una misma máquina, bit a bit), así que también detecta un cambio del BVAR sin regenerar la
# referencia (F1-1); si no, stop(). En otro sistema (el CI, Ubuntu) V17 solo informa (F1-3, reabierta): con OpenBLAS,
# según la CPU, un redondeo distinto cambia decisiones del MH y las cadenas se separan hasta la escala del error de
# Monte Carlo. Informa las decisiones del MH distintas, |dif| / MCSE por campo (MCSE de la referencia) y la plataforma.
# En Windows la línea OK no lleva datos de la plataforma; fuera de Windows la salida de la verificación difiere solo
# en esta línea.
c17 <- comparar_paridad_bvar(momentos_paridad_bvar(), leer_referencia_paridad_bvar())
plataforma17 <- sprintf("%s; %s; BLAS %s; LAPACK %s %s", R.version.string, utils::sessionInfo()$running,
                        basename(extSoftVersion()[["BLAS"]]), basename(La_library()), La_version())
maximos17 <- paste(sprintf("%s %.2g", names(c17$maximos), c17$maximos), collapse = ", ")
if (.Platform$OS.type == "windows") {
  if (c17$n_distintos > 0L) {
    stop(sprintf(paste0("V17: en Windows el BVAR fijo debe reproducir byte a byte la referencia (F5-15, F1-1) y difieren %d de %d ",
                        "valores; entradas %s; máximos por campo (media absoluta en log-nivel, demás relativos): %s; aceptación ",
                        "%.3g; sha256 %s; %s. Si cambió el código o la configuración del BVAR, la referencia se regenera con ",
                        "scripts/referencia_paridad_bvar.R en el mismo PR, con una nota fechada"),
                 c17$n_distintos, c17$n, if (c17$entradas_iguales) "idénticas" else "DISTINTAS", maximos17, c17$dif_aceptacion,
                 c17$sha256, plataforma17))
  }
  ok("V17", sprintf("paridad del BVAR (G1 y G3, producción, primer origen): %d valores idénticos byte a byte a la referencia de Windows (sha256 %s…)",
                    c17$n - 1L, substr(c17$sha256, 1, 12)))
} else {
  ok("V17", sprintf(paste0("paridad del BVAR entre sistemas, informativa (F1-3): %d de %d valores distintos de la referencia de ",
                           "Windows; entradas %s; decisiones del MH distintas de %d: %s; máx |dif| / MCSE: %s; máximos por campo ",
                           "(media absoluta en log-nivel, demás relativos): %s; sha256 %s…; %s"),
                    c17$n_distintos, c17$n - 1L, if (c17$entradas_iguales) "idénticas" else "DISTINTAS", N_DRAW_BVAR - N_BURN_BVAR,
                    paste(sprintf("%s %d", names(c17$decisiones_distintas), c17$decisiones_distintas), collapse = ", "),
                    paste(sprintf("%s %.2g", names(c17$en_mcse), c17$en_mcse), collapse = ", "), maximos17,
                    substr(c17$sha256, 1, 12), plataforma17))
}

# --- V18 · Regularizados (B3; F5-09, F5-11, F5-12, B3-1 a B3-7) ------------------------------------------------------
# Dos DGP con predictoras trimestrales desde 1990 (unas 90 filas en el primer origen del diseño):
#   "dispersa"  la predictora X adelanta al PIB como en V14 (x_t = 0,6 x_{t-1} + u_t, Δy_t = 0,004 + 0,4 x_{t-1} + e_t),
#               junto a una SA de ruido y una NSA de ruido con estacional determinista de amplitud 0,04, que ejercita la
#               ventana de B3-2. El elastic net (4 series con rezagos 0..3: 16 columnas) debe batir al AR(p)-BIC con razón
#               de RMSE < 0,8 en h = 1, 2 (con estas semillas, 0,60 y 0,75).
#   "factor"    tres SA cargan un factor f (f_t = 0,6 f_{t-1} + u_t, ruido idiosincrático de 0,01) que adelanta al PIB
#               (Δy_t = 0,004 + 0,4 f_{t-1} + e_t), más la NSA de ruido. El PCR debe batir al AR(p)-BIC con razón < 0,9 en
#               h = 1, 2 (con estas semillas, 0,65 y 0,79).
# Densidad de errores internos (F5-12, B3-5, B3-6): la cobertura en h = 1, 2, 4 no puede pasar del nominal más 3 ee de
# MC más 0,03 ni quedar por debajo del nominal menos 3 ee menos 0,10. La holgura inferior es mayor que la de V14 a V16 y
# se declara (decisiones_fase5.md, PR 2 de B3): con K = 12 errores internos del candidato de menor ECM interno, la
# densidad subcubre; con estas semillas, 0,64 a 0,81 al 80 % y 0,86 a 0,96 al 95 % en h = 1, 2, 4. Placebo (β = 0 en
# "dispersa"): el elastic net no empeora al AR(p)-BIC en más de 10 % en h = 1 (1,04). Reejecutar dos orígenes reproduce
# bit a bit sendero y densidad (F5-15). Uno de cada cuatro orígenes del diseño; 6, 6 y 4 réplicas.
ESTAC_V18 <- c(0.04, -0.01, -0.04, 0.01)[q_a_ind(PERIODOS_OBJ) %% 4L + 1L]
sim_v18 <- function(tipo, beta, n = length(PERIODOS_OBJ)) {
  e <- stats::rnorm(n, 0, 0.006); u <- stats::rnorm(n, 0, 0.02); a <- numeric(n); dy <- numeric(n)
  for (t in 2:n) { a[t] <- 0.6 * a[t - 1] + u[t]; dy[t] <- 0.004 + beta * a[t - 1] + e[t] }
  xs <- if (tipo == "dispersa") {
    list(PRUEBA.X.SA.Q = a, PRUEBA.N.SA.Q = stats::rnorm(n, 0, 0.02), PRUEBA.Z.NSA.Q = stats::rnorm(n, 0.01, 0.015))
  } else {
    list(PRUEBA.F1.SA.Q = a + stats::rnorm(n, 0, 0.01), PRUEBA.F2.SA.Q = a + stats::rnorm(n, 0, 0.01),
         PRUEBA.F3.SA.Q = a + stats::rnorm(n, 0, 0.01), PRUEBA.Z.NSA.Q = stats::rnorm(n, 0.01, 0.015))
  }
  s <- list(objetivo = data.frame(periodo = PERIODOS_OBJ, y = 4 + cumsum(dy), stringsAsFactors = FALSE))
  for (id in names(xs)) {
    lv <- cumsum(xs[[id]]) + if (grepl(".NSA.", id, fixed = TRUE)) ESTAC_V18 else 0
    s[[id]] <- data.frame(periodo = PERIODOS_OBJ, valor = 100 * exp(lv), stringsAsFactors = FALSE)
  }
  s
}
ors18 <- ors[seq(1L, length(ors), by = 4L)]
rezagos18 <- function(s) { ids <- setdiff(names(s), "objetivo"); stats::setNames(as.list(rep(30L, length(ids))), ids) }
mods18d <- list(modelo_directo("PRUEBA.ENET", c("PRUEBA.X.SA.Q", "PRUEBA.N.SA.Q", "PRUEBA.Z.NSA.Q"), especificacion_enet()), modelo_arp_bic())
mods18f <- list(modelo_directo("PRUEBA.PCR", c("PRUEBA.F1.SA.Q", "PRUEBA.F2.SA.Q", "PRUEBA.F3.SA.Q", "PRUEBA.Z.NSA.Q"), especificacion_pcr()), modelo_arp_bic())
corrida18 <- function(tipo, beta, R, semilla, mods) {
  set.seed(semilla)
  res <- lapply(seq_len(R), function(r) {
    s <- sim_v18(tipo, beta)
    p <- correr_backtest(s, mods, ors18, rezagos = rezagos18(s), exp_id = "V18", densidad = TRUE)
    m <- metricas_por_horizonte(calcular_errores(p, s$objetivo))
    list(m = m[m$unidad == "yoy_pp", c("modelo_id", "h", "rmse", "cobertura_80", "cobertura_95")], p = p, s = s)
  })
  list(m = do.call(rbind, lapply(res, `[[`, "m")), p = res[[1]]$p, s = res[[1]]$s)
}
cobertura18 <- function(tab, id, etiqueta) {
  cs <- list()
  for (nv in c(80, 95)) for (h in c(1L, 2L, 4L)) {
    x <- tab[tab$modelo_id == id & tab$h == h, ][[paste0("cobertura_", nv)]]; ee <- stats::sd(x) / sqrt(length(x))
    if (mean(x) > nv / 100 + 3 * ee + 0.03 || mean(x) < nv / 100 - 3 * ee - 0.10)
      stop(sprintf("V18: cobertura de %s al %d%% en h=%d fuera de [nominal − (3 ee + 0,10), nominal + 3 ee + 0,03] (%.3f, ee %.4f; DGP %s)",
                   id, nv, h, mean(x), ee, etiqueta))
    cs[[as.character(nv)]] <- c(cs[[as.character(nv)]], mean(x))
  }
  ok("V18", sprintf("DGP %s: cobertura de la densidad de errores internos de %s 80%% %s y 95%% %s en h = 1, 2, 4", etiqueta, id,
                    paste(sprintf("%.3f", cs[["80"]]), collapse = "/"), paste(sprintf("%.3f", cs[["95"]]), collapse = "/")))
}
t18d <- corrida18("dispersa", 0.4, 6L, SEMILLA_RAIZ + 18L, mods18d)
for (h in c(1L, 2L)) {
  rz <- razon15(t18d$m, "PRUEBA.ENET", "BENCH.ARP_BIC", h)
  if (!(rz < 0.8)) stop(sprintf("V18: en h=%d el elastic net no bate al AR(p)-BIC con una predictora adelantada entre ruidos (razón de RMSE %.3f)", h, rz))
  ok("V18", sprintf("DGP disperso, h=%d: RMSE elastic net / AR(p)-BIC %.3f (< 0,8)", h, rz))
}
cobertura18(t18d$m, "PRUEBA.ENET", "disperso")
t18f <- corrida18("factor", 0.4, 6L, SEMILLA_RAIZ + 181L, mods18f)
for (h in c(1L, 2L)) {
  rz <- razon15(t18f$m, "PRUEBA.PCR", "BENCH.ARP_BIC", h)
  if (!(rz < 0.9)) stop(sprintf("V18: en h=%d el PCR no bate al AR(p)-BIC en un DGP de factor (razón de RMSE %.3f)", h, rz))
  ok("V18", sprintf("DGP de factor, h=%d: RMSE PCR / AR(p)-BIC %.3f (< 0,9)", h, rz))
}
cobertura18(t18f$m, "PRUEBA.PCR", "de factor")
t18p <- corrida18("dispersa", 0, 4L, SEMILLA_RAIZ + 182L, mods18d)
rz18p <- razon15(t18p$m, "PRUEBA.ENET", "BENCH.ARP_BIC", 1L)
if (!(rz18p < 1.10)) stop(sprintf("V18: con predictoras placebo el elastic net empeora al AR(p)-BIC en h=1 (razón %.3f)", rz18p))
ok("V18", sprintf("placebo (β = 0): RMSE elastic net / AR(p)-BIC en h=1 %.3f (< 1,10)", rz18p))
p18b <- correr_backtest(t18d$s, mods18d[1], ors18[1:2], rezagos = rezagos18(t18d$s), exp_id = "V18", densidad = TRUE)
p18a <- t18d$p[t18d$p$modelo_id == "PRUEBA.ENET" & t18d$p$origen %in% ors18[1:2], ]; rownames(p18a) <- NULL
d18a <- attr(t18d$p, "diagnosticos"); d18a <- d18a[d18a$modelo_id == "PRUEBA.ENET" & d18a$origen %in% ors18[1:2], ]; rownames(d18a) <- NULL
d18b <- attr(p18b, "diagnosticos"); rownames(d18b) <- NULL
attr(p18a, "diagnosticos") <- NULL; attr(p18b, "diagnosticos") <- NULL
if (!identical(p18a, p18b) || !identical(d18a, d18b)) stop("V18: reejecutar el elastic net no reproduce bit a bit sus pronósticos y diagnósticos (F5-15)")
ok("V18", "reejecutar dos orígenes reproduce bit a bit sendero, densidad y diagnósticos del elastic net (F5-15)")

# --- V19 · Frecuencia mixta (B3b; F5-08, F5-04, F5-12, B3b-1 a B3b-6) -----------------------------------------------
# DGP: una predictora mensual SA x_m = 0,5 x_{m-1} + u_m (σ_u = 0,01) y una NSA de ruido con estacional mensual
# determinista; el PIB trimestral sigue Δy_t = 0,004 + β · (promedio de x en los meses de t) + e_t (σ_e = 0,003). Las
# dos mensuales traen 2 meses de o+1 en el origen (rezago de 24 días, como las remesas; F5-04), así que el borde
# irregular contiene dos tercios del trimestre o+1. Con β = 1, el U-MIDAS (meses m(t)+2..m(t)−5, la forma de G1) y el
# puente deben batir al AR(p)-BIC con razón de RMSE < 0,7 en h = 1. Cobertura en h = 1, 2, 4: el puente (densidad del
# sistema conjunto, plug-in) dentro de ±(3 ee + 0,03) del nominal, como V14 a V16; el U-MIDAS (errores internos, una sola
# especificación) con la holgura inferior de V18 (0,10). Con β = 0 (placebo), ninguno empeora al AR(p)-BIC en más de
# 10 % en h = 1. Reejecutar dos orígenes reproduce bit a bit. Uno de cada dos orígenes del diseño; 8 y 4 réplicas (unos
# 2 minutos). Con estas semillas: razones 0,55 (U-MIDAS) y 0,60 (puente) en h = 1; cobertura del puente 0,77 a 0,84 al
# 80 % y 0,94 a 0,98 al 95 %; del U-MIDAS 0,77 a 0,78 y 0,91 a 0,94. Sin los términos cruzados de B3b-6 el puente
# subcubría (0,68 a 0,79 al 80 %), porque su innovación correlaciona con la de los meses del trimestre.
MESES_V19 <- (q_a_ind("1990-Q1") %/% 4L * 12L):(ultimo_mes_trimestre(q_a_ind("2026-Q2")))
.ind_a_m19 <- function(i) sprintf("%d-M%02d", i %/% 12L, i %% 12L + 1L)
sim_v19 <- function(beta) {
  nm <- length(MESES_V19); u <- stats::rnorm(nm, 0, 0.01); x <- numeric(nm)
  for (m in 2:nm) x[m] <- 0.5 * x[m - 1] + u[m]
  z <- stats::rnorm(nm, 0.001, 0.01)
  q_m <- MESES_V19 %/% 3L
  xq <- tapply(x, q_m, mean)[as.character(q_a_ind(PERIODOS_OBJ))]
  dy <- 0.004 + beta * unname(xq) + stats::rnorm(length(PERIODOS_OBJ), 0, 0.003); dy[1] <- 0
  est <- 0.03 * sin(2 * pi * (MESES_V19 %% 12L) / 12)
  list(objetivo = data.frame(periodo = PERIODOS_OBJ, y = 4 + cumsum(dy), stringsAsFactors = FALSE),
       PRUEBA.X.SA.M = data.frame(periodo = .ind_a_m19(MESES_V19), valor = 100 * exp(cumsum(x)), stringsAsFactors = FALSE),
       PRUEBA.Z.NSA.M = data.frame(periodo = .ind_a_m19(MESES_V19), valor = 100 * exp(cumsum(z) + est), stringsAsFactors = FALSE))
}
pred19 <- c("PRUEBA.X.SA.M", "PRUEBA.Z.NSA.M")
rez19 <- list(PRUEBA.X.SA.M = 24L, PRUEBA.Z.NSA.M = 24L)
ors19 <- ors[seq(1L, length(ors), by = 2L)]
mods19 <- list(modelo_directo("PRUEBA.UMIDAS", pred19, especificacion_umidas(), construir = function(datos) matriz_umidas(datos, pred19, "PRUEBA.UMIDAS", 0:5)),
               modelo_puente("PRUEBA.PUENTE", pred19), modelo_arp_bic())
corrida19 <- function(beta, R, semilla) {
  set.seed(semilla)
  res <- lapply(seq_len(R), function(r) {
    s <- sim_v19(beta)
    p <- correr_backtest(s, mods19, ors19, rezagos = rez19, exp_id = "V19", densidad = TRUE)
    m <- metricas_por_horizonte(calcular_errores(p, s$objetivo))
    list(m = m[m$unidad == "yoy_pp", c("modelo_id", "h", "rmse", "cobertura_80", "cobertura_95")], p = p, s = s)
  })
  list(m = do.call(rbind, lapply(res, `[[`, "m")), p = res[[1]]$p, s = res[[1]]$s)
}
cobertura19 <- function(tab, id, holgura_inf) {
  cs <- list()
  for (nv in c(80, 95)) for (h in c(1L, 2L, 4L)) {
    x <- tab[tab$modelo_id == id & tab$h == h, ][[paste0("cobertura_", nv)]]; ee <- stats::sd(x) / sqrt(length(x))
    if (mean(x) > nv / 100 + 3 * ee + 0.03 || mean(x) < nv / 100 - 3 * ee - holgura_inf)
      stop(sprintf("V19: cobertura de %s al %d%% en h=%d fuera de [nominal − (3 ee + %.2f), nominal + 3 ee + 0,03] (%.3f, ee %.4f)", id, nv, h, holgura_inf, mean(x), ee))
    cs[[as.character(nv)]] <- c(cs[[as.character(nv)]], mean(x))
  }
  ok("V19", sprintf("cobertura de %s 80%% %s y 95%% %s en h = 1, 2, 4", id, paste(sprintf("%.3f", cs[["80"]]), collapse = "/"), paste(sprintf("%.3f", cs[["95"]]), collapse = "/")))
}
t19 <- corrida19(1, 8L, SEMILLA_RAIZ + 19L)
for (id in c("PRUEBA.UMIDAS", "PRUEBA.PUENTE")) {
  rz <- razon15(t19$m, id, "BENCH.ARP_BIC", 1L)
  if (!(rz < 0.7)) stop(sprintf("V19: en h=1 %s no bate al AR(p)-BIC con el borde irregular (razón de RMSE %.3f)", id, rz))
  ok("V19", sprintf("borde irregular, h=1: RMSE %s / AR(p)-BIC %.3f (< 0,7); h=2 %.3f", id, rz, razon15(t19$m, id, "BENCH.ARP_BIC", 2L)))
}
cobertura19(t19$m, "PRUEBA.PUENTE", 0.03)
cobertura19(t19$m, "PRUEBA.UMIDAS", 0.10)
t19p <- corrida19(0, 4L, SEMILLA_RAIZ + 191L)
for (id in c("PRUEBA.UMIDAS", "PRUEBA.PUENTE")) {
  rz <- razon15(t19p$m, id, "BENCH.ARP_BIC", 1L)
  if (!(rz < 1.10)) stop(sprintf("V19: con predictoras placebo %s empeora al AR(p)-BIC en h=1 (razón %.3f)", id, rz))
  ok("V19", sprintf("placebo (β = 0): RMSE %s / AR(p)-BIC en h=1 %.3f (< 1,10)", id, rz))
}
p19b <- correr_backtest(t19$s, mods19[1:2], ors19[1:2], rezagos = rez19, exp_id = "V19", densidad = TRUE)
p19a <- t19$p[t19$p$modelo_id %in% c("PRUEBA.UMIDAS", "PRUEBA.PUENTE") & t19$p$origen %in% ors19[1:2], ]; rownames(p19a) <- NULL
attr(p19a, "diagnosticos") <- NULL; attr(p19b, "diagnosticos") <- NULL
if (!identical(p19a, p19b)) stop("V19: reejecutar U-MIDAS y puente no reproduce bit a bit sus pronósticos (F5-15)")
ok("V19", "reejecutar dos orígenes reproduce bit a bit sendero y densidad del U-MIDAS y del puente (F5-15)")

# --- V20 · Árboles (B4; F5-10, F5-11, F5-12, F5-15, B4-1 a B4-6) ----------------------------------------------------
# DGP no lineal con predictoras trimestrales desde 1990 (unas 90 filas en el primer origen del diseño): la predictora X
# (x_t = 0,6 x_{t-1} + u_t, sd(u) = 0,02) adelanta al PIB por su valor absoluto, Δy_t = 0,004 + β (|x_{t-1}| − E|x|) + e_t
# con β = 0,8 y sd(e) = 0,006, junto a una SA de ruido. Δy no tiene correlación lineal con x_{t-1}, así que un modelo
# lineal no aprovecha a X. El RF (3 series con rezagos 0..3: 12 columnas, mtry = 4 y min.node.size ∈ {5, 3}) debe batir
# al AR(p)-BIC con razón de RMSE < 0,8 en h = 1. Densidad de errores internos (B4-2) con la holgura declarada de V18: la
# cobertura en h = 1, 2, 4 no puede pasar del nominal más 3 ee de MC más 0,03 ni quedar por debajo del nominal menos 3 ee
# menos 0,10. Placebo (β = 0): el RF no empeora al AR(p)-BIC en más de 10 % en h = 1. Reejecutar dos orígenes reproduce
# bit a bit sendero, densidad y diagnósticos del RF, y un origen los del LightGBM (semilla del motor, F5-15). Para acotar
# el costo (unos 4 minutos), el RF corre con 50 árboles en lugar de 500 y el LightGBM con 20 rondas como máximo en lugar
# de 500; la configuración de producción se prueba en tests/test-modelos-arboles.R. Uno de cada cuatro orígenes del
# diseño; 2 réplicas y 2 de placebo. El LightGBM no entra a las comparaciones de RMSE ni de cobertura: aun con 50 rondas
# cuesta unos 19 s por origen en el sandbox (decisiones_fase5.md, «Implementación del bloque B4»).
MEDIA_ABS_V20 <- 0.025 * sqrt(2 / pi)   # E|x| con x AR(1) estacionario de desviación 0,02 / sqrt(1 − 0,6²)
sim_v20 <- function(beta, n = length(PERIODOS_OBJ)) {
  e <- stats::rnorm(n, 0, 0.006); u <- stats::rnorm(n, 0, 0.02); a <- numeric(n); dy <- numeric(n)
  for (t in 2:n) { a[t] <- 0.6 * a[t - 1] + u[t]; dy[t] <- 0.004 + beta * (abs(a[t - 1]) - MEDIA_ABS_V20) + e[t] }
  xs <- list(PRUEBA.X.SA.Q = a, PRUEBA.N.SA.Q = stats::rnorm(n, 0, 0.02))
  s <- list(objetivo = data.frame(periodo = PERIODOS_OBJ, y = 4 + cumsum(dy), stringsAsFactors = FALSE))
  for (id in names(xs)) s[[id]] <- data.frame(periodo = PERIODOS_OBJ, valor = 100 * exp(cumsum(xs[[id]])), stringsAsFactors = FALSE)
  s
}
ors20 <- ors[seq(1L, length(ors), by = 4L)]
ids20 <- c("PRUEBA.X.SA.Q", "PRUEBA.N.SA.Q")
rezagos20 <- stats::setNames(as.list(rep(30L, length(ids20))), ids20)
mods20 <- list(modelo_directo("PRUEBA.RF", ids20, especificacion_rf(num_arboles = 50L)), modelo_arp_bic())
corrida20 <- function(beta, R, semilla) {
  set.seed(semilla)
  res <- lapply(seq_len(R), function(r) {
    s <- sim_v20(beta)
    p <- correr_backtest(s, mods20, ors20, rezagos = rezagos20, exp_id = "V20", densidad = TRUE)
    m <- metricas_por_horizonte(calcular_errores(p, s$objetivo))
    list(m = m[m$unidad == "yoy_pp", c("modelo_id", "h", "n_pares", "rmse", "cobertura_80", "cobertura_95")], p = p, s = s)
  })
  list(m = do.call(rbind, lapply(res, `[[`, "m")), p = res[[1]]$p, s = res[[1]]$s)
}
t20 <- corrida20(0.8, 2L, SEMILLA_RAIZ + 20L)
rz20 <- razon15(t20$m, "PRUEBA.RF", "BENCH.ARP_BIC", 1L)
if (!(rz20 < 0.8)) stop(sprintf("V20: en h=1 el RF no bate al AR(p)-BIC en un DGP no lineal (razón de RMSE %.3f)", rz20))
ok("V20", sprintf("DGP no lineal (|x|), h=1: RMSE RF / AR(p)-BIC %.3f (< 0,8); h=2 %.3f y h=4 %.3f, informativas", rz20,
                  razon15(t20$m, "PRUEBA.RF", "BENCH.ARP_BIC", 2L), razon15(t20$m, "PRUEBA.RF", "BENCH.ARP_BIC", 4L)))
cs20 <- list(); ee20 <- numeric(0)
for (nv in c(80, 95)) for (h in c(1L, 2L, 4L)) {
  t <- t20$m[t20$m$modelo_id == "PRUEBA.RF" & t20$m$h == h, ]; x <- t[[paste0("cobertura_", nv)]]
  # con 2 réplicas la desviación entre réplicas no estima el error de MC (puede dar 0): piso binomial con los pares de
  # las réplicas, que todavía lo subestima porque los errores a h > 1 se traslapan (B4-6, nota del 2026-10-08)
  ee <- max(stats::sd(x) / sqrt(length(x)), sqrt(nv / 100 * (1 - nv / 100) / sum(t$n_pares)))
  if (mean(x) > nv / 100 + 3 * ee + 0.03 || mean(x) < nv / 100 - 3 * ee - 0.10)
    stop(sprintf("V20: cobertura del RF al %d%% en h=%d fuera de [nominal − (3 ee + 0,10), nominal + 3 ee + 0,03] (%.3f, ee %.4f)",
                 nv, h, mean(x), ee))
  cs20[[as.character(nv)]] <- c(cs20[[as.character(nv)]], mean(x)); ee20 <- c(ee20, ee)
}
ok("V20", sprintf("cobertura de la densidad de errores internos del RF 80%% %s y 95%% %s en h = 1, 2, 4 (ee de MC de %.3f a %.3f)",
                  paste(sprintf("%.3f", cs20[["80"]]), collapse = "/"), paste(sprintf("%.3f", cs20[["95"]]), collapse = "/"), min(ee20), max(ee20)))
t20p <- corrida20(0, 2L, SEMILLA_RAIZ + 201L)
rz20p <- razon15(t20p$m, "PRUEBA.RF", "BENCH.ARP_BIC", 1L)
if (!(rz20p < 1.10)) stop(sprintf("V20: con predictoras placebo el RF empeora al AR(p)-BIC en h=1 (razón %.3f)", rz20p))
ok("V20", sprintf("placebo (β = 0): RMSE RF / AR(p)-BIC en h=1 %.3f (< 1,10)", rz20p))
sin_attr20 <- function(p) { d <- attr(p, "diagnosticos"); rownames(d) <- NULL; attr(p, "diagnosticos") <- NULL; rownames(p) <- NULL; list(p = p, d = d) }
p20b <- sin_attr20(correr_backtest(t20$s, mods20[1], ors20[1:2], rezagos = rezagos20, exp_id = "V20", densidad = TRUE))
p20a <- t20$p[t20$p$modelo_id == "PRUEBA.RF" & t20$p$origen %in% ors20[1:2], ]
d20a <- attr(t20$p, "diagnosticos"); d20a <- d20a[d20a$modelo_id == "PRUEBA.RF" & d20a$origen %in% ors20[1:2], ]; rownames(d20a) <- NULL
attr(p20a, "diagnosticos") <- NULL; rownames(p20a) <- NULL
if (!identical(p20a, p20b$p) || !identical(d20a, p20b$d)) stop("V20: reejecutar el RF no reproduce bit a bit sus pronósticos y diagnósticos (F5-15)")
lg20 <- list(modelo_directo("PRUEBA.LGBM", ids20, especificacion_lgbm(rondas_max = 20L)))
l20a <- sin_attr20(correr_backtest(t20$s, lg20, ors20[1], rezagos = rezagos20, exp_id = "V20", densidad = TRUE))
l20b <- sin_attr20(correr_backtest(t20$s, lg20, ors20[1], rezagos = rezagos20, exp_id = "V20", densidad = TRUE))
if (!identical(l20a, l20b) || !all(is.finite(l20a$p$sd_log_nivel))) stop("V20: reejecutar el LightGBM no reproduce bit a bit sus pronósticos y diagnósticos (F5-15)")
ok("V20", "reejecutar reproduce bit a bit sendero, densidad y diagnósticos del RF (dos orígenes) y del LightGBM (uno) (F5-15)")

# --- V21 · doble corrida con los modelos de Fase 5 y sus combinaciones (C6; F5-15) ----------------
# Insumos sintéticos de G2 con los inicios de L3 (mensuales y trimestrales), el registro real de G2 (los 12 modelos de
# Fase 5, con la configuración de producción) más los benchmarks en dos orígenes consecutivos de G2, 2015-Q1 y 2015-Q2,
# para que la variante Q1 de F5-11 reoptimice en el primero y reutilice la elección en el segundo, y las cuatro
# combinaciones (F5-13). Dos corridas con el mismo exp_id y distinta semilla global dan sha256 idéntico en pronósticos,
# densidades y diagnósticos; con otro exp_id, el BVAR y el RF (los que usan el generador) cambian. Dos orígenes acotan
# el costo (unos 8 minutos en el sandbox: el LightGBM de producción cuesta unos 75 s en un origen Q1 de G2).
INICIO_M21 <- c(BCR.REMESAS.NOM.NSA = "1991-M01", BCR.EXPORT_FOB.NOM.NSA = "1994-M01", BCR.ITCER.IDX.NSA = "2000-M01",
                UT.DEMANDA_ELEC.GWH.NSA = "2002-M01", BCR.IVAE.VOL.SA = "2005-M01", BCR.IPM.IDX.NSA = "2005-M01")
set.seed(SEMILLA_RAIZ + 21L)
obj21 <- simular_objetivo(145L, 0.3, 0.01)
pred21_todas <- list()
for (b in names(INICIO_M21)) {
  im <- m_a_ind(INICIO_M21[[b]]):m_a_ind("2026-M06")
  est <- if (grepl(".NSA", b, fixed = TRUE)) 0.03 * sin(pi * (im %% 12L) / 6) else 0
  x <- 100 * exp(cumsum(0.0015 + stats::rnorm(length(im), 0, 0.01)) + est)
  pred21_todas[[paste0(b, ".M")]] <- data.frame(periodo = sprintf("%d-M%02d", im %/% 12L, im %% 12L + 1L), valor = x, stringsAsFactors = FALSE)
  iq <- im %/% 3L; qs <- as.integer(names(which(table(iq) == 3L)))
  pred21_todas[[paste0(b, ".Q")]] <- data.frame(periodo = ind_a_q(qs), valor = as.numeric(tapply(x, iq, mean)[as.character(qs)]), stringsAsFactors = FALSE)
}
mods21 <- modelos_fase5("G2")
ids21  <- vapply(mods21, `[[`, character(1), "modelo_id")
pred21 <- setdiff(unique(unlist(lapply(mods21, `[[`, "requiere"))), "objetivo")
if (length(setdiff(pred21, names(pred21_todas)))) stop("V21: faltan predictoras sintéticas: ", paste(setdiff(pred21, names(pred21_todas)), collapse = ", "))
rez21 <- rezagos_predictoras(pred21)
ors21 <- q_a_ind(c("2015-Q1", "2015-Q2"))                       # Q1 y el siguiente (F5-11, variante Q1)
y21 <- stats::setNames(lapply(ors21, function(o) { s <- obj21[q_a_ind(obj21$periodo) <= o, ]; stats::setNames(s$y, q_a_ind(s$periodo)) }), ors21)
corrida21 <- function(exp_id, semilla_global, modelos = c(modelos_referencia(), mods21)) {
  set.seed(semilla_global)   # la semilla global previa no debe importar: el motor la fija por (exp, modelo, origen)
  p <- correr_backtest(c(list(objetivo = obj21), pred21_todas[pred21]), modelos, ors21,
                       rezagos = rez21, exp_id = exp_id, densidad = TRUE)
  cmb <- if (length(modelos) > length(modelos_referencia())) combinar_pronosticos(p, ids21, "G2", y21) else NULL
  list(p = p, cmb = cmb, sha = digest::digest(list(p, cmb), algo = "sha256"))
}
c21a <- corrida21("V21", 1L); c21b <- corrida21("V21", 2L)
d21 <- attr(c21a$p, "diagnosticos")
r21 <- d21[d21$clave == "reoptimizado" & d21$origen == ors21[2], ]
if (nrow(r21) != 4L || any(r21$valor != 0)) stop("V21: en 2015-Q2 ENET, PCR, RF y LightGBM debían reutilizar la elección de 2015-Q1 (F5-11, variante Q1)")
sin_attr21 <- function(cr) {
  d <- rbind(attr(cr$p, "diagnosticos"), attr(cr$cmb, "diagnosticos")); rownames(d) <- NULL
  p <- rbind(cr$p, cr$cmb); attr(p, "diagnosticos") <- NULL; rownames(p) <- NULL
  list(p = p, d = d)
}
if (!identical(c21a$sha, c21b$sha)) {
  a <- sin_attr21(c21a); b <- sin_attr21(c21b)
  dif <- unique(c(a$p$modelo_id[!vapply(seq_len(nrow(a$p)), function(i) identical(unlist(a$p[i, ]), unlist(b$p[i, ])), logical(1))],
                  if (!identical(a$d, b$d)) "diagnósticos"))
  stop("V21: dos corridas con el mismo exp_id no son idénticas (F5-15); difieren: ", paste(dif, collapse = ", "))
}
estoc21 <- Filter(function(m) startsWith(m$modelo_id, "MULT.BVAR.") || startsWith(m$modelo_id, "ML.RF."), mods21)
c21c <- corrida21("V21_otro", 1L, estoc21)
for (m in estoc21) {
  a <- c21a$p[c21a$p$modelo_id == m$modelo_id, ]; b <- c21c$p[c21c$p$modelo_id == m$modelo_id, ]
  attr(a, "diagnosticos") <- NULL; attr(b, "diagnosticos") <- NULL; rownames(a) <- NULL; rownames(b) <- NULL
  if (identical(a, b)) stop("V21: cambiar exp_id no cambió la semilla de ", m$modelo_id)
}
ok("V21", sprintf("dos corridas de los %d modelos de Fase 5 de G2 + 6 benchmarks + 4 combinaciones en 2015-Q1 y 2015-Q2 (Q1 reutilizado): sha256 idéntico (%s…); otro exp_id cambia %s",
                  length(ids21), substr(c21a$sha, 1, 12), paste(vapply(estoc21, `[[`, character(1), "modelo_id"), collapse = " y ")))

cat(if (exists("V11_SKIP")) "verificación sintética: bloques OK V1-V10 y V12-V21 (V11 SKIP)\n"
    else "verificación sintética: bloques OK (V1-V21)\n")
