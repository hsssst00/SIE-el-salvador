# verificar_robots_ut.R
#
# Verifica, con `polite`, si robots.txt de ut.com.sv permite acceder al reporte
# de Demanda Total. `polite` consulta robots.txt directamente contra el dominio
# y por defecto SE NIEGA a continuar si la ruta está deshabilitada - hay que
# pasar force=TRUE explícitamente para saltarse esa negativa, y este script
# nunca lo hace.
#
# No descarga datos. No escribe a L0. Es solo el paso de verificación -
# el resultado decide si tiene sentido diseñar algo más, no al revés.
#
# Corrida: 2026-08-26. Resultado: robots.txt de ut.com.sv NO permite la ruta
# del reporte para este user-agent ("The path is not scrapable for this
# user-agent", tanto para el dominio base como para la ruta del reporte) --
# scrape() se niega a continuar ("No scraping allowed here!") sin force=TRUE.
# La captura de UT.DEMANDA_TOTAL_MENSUAL sigue manual.

library(polite)

url_reporte <- "https://www.ut.com.sv/reportes?p_p_id=MenuReportesEstadisticosPublicReports_WAR_PublicReports&p_p_lifecycle=1&p_p_state=normal&p_p_mode=view&_MenuReportesEstadisticosPublicReports_WAR_PublicReports_reportName=14utdemtotal"

url_base <- "https://www.ut.com.sv/"

cat("== bow() contra el dominio base ==\n")
sesion_base <- bow(url_base, user_agent = "SIE-el-salvador research bot (contacto: lm23027@ues.edu.sv)")
print(sesion_base)

cat("\n== ¿La ruta específica del reporte está permitida? ==\n")
sesion_reporte <- bow(url_reporte, user_agent = "SIE-el-salvador research bot (contacto: lm23027@ues.edu.sv)")
print(sesion_reporte)

cat("\n== Intento de scrape() (respeta el resultado de arriba automáticamente) ==\n")
resultado <- tryCatch({
  scrape(sesion_reporte)
}, error = function(e) {
  cat("scrape() se detuvo:", conditionMessage(e), "\n")
  NULL
})

if (is.null(resultado)) {
  cat("\n== CONCLUSIÓN: robots.txt no permite esta ruta. La captura sigue manual. ==\n")
} else {
  cat("\n== CONCLUSIÓN: robots.txt permite esta ruta. Contenido recibido: ==\n")
  print(resultado)
}
