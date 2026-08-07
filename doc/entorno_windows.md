# Nota de entorno: `make test` falla con Segmentation fault en Windows

## Síntoma

En Windows (R 4.5.1, UCRT, GNU Make de Rtools45), `make test` termina así,
incluso con todos los tests en verde:

```
══ Results ═══════════════════════════════════════════════════════════════
[ FAIL 0 | WARN 1 | SKIP 0 | PASS 7 ]
Warning message:
package 'testthat' was built under R version 4.5.3
make: *** [Makefile:32: test] Segmentation fault
```

El fallo ocurre *después* de que `testthat` reporta los resultados — es un
crash del proceso de R durante el cierre/salida, no un fallo de ninguna
prueba. Reproducido dos veces consecutivas (`make clean` + `make test`),
mismo resultado ambas veces.

Ejecutar la misma suite directamente, sin pasar por `make`, **no** produce el
crash:

```
$ Rscript -e 'testthat::test_dir("tests")'
[ FAIL 0 | WARN 1 | SKIP 0 | PASS 7 ]
$ echo $?
0
```

## Causa

Categoría de bug conocida en el paquete `cli` en Windows — no una versión
específica, ya que el conjunto de issues relacionados ha cambiado de forma
con distintas versiones del paquete. Ver r-lib/cli issues [#494](https://github.com/r-lib/cli/issues/494)
y [#375](https://github.com/r-lib/cli/issues/375). El patrón encaja: R
segfaultea al salir cuando cli (cargado transitivamente por `testthat` u
otras dependencias) intenta consultar el estado de la consola en un proceso
sin una consola Windows real adjunta — el caso de un hijo lanzado por
`make.exe`.

**Se descartó que fuera cuestión de versión.** Se corrió
`update.packages(oldPkgs = "cli", repos = "https://cloud.r-project.org")`
antes de documentar esto: `cli` ya estaba en la 3.6.6, que es también la
versión más reciente publicada en CRAN para R 4.5 en Windows (verificado
independientemente contra `PACKAGES` del repositorio CRAN). No hubo
actualización que aplicar ni cambio en `renv.lock`.

## Señal de verdad

**CI (Ubuntu) es la señal de verdad para saber si los tests pasan.** Este
crash es específico de Windows y del mecanismo de invocación
(`make` → proceso hijo sin consola). No bloquea Fase 0 ni indica un problema
real en el código o las pruebas.

## Workaround local confiable

En Windows, correr la suite directo, sin pasar por `make`:

```
Rscript -e 'testthat::test_dir("tests")'
```

No se modificó el `Makefile` para trabajar alrededor de esto — ver
`CLAUDE.md` sobre no introducir cambios no solicitados fuera del alcance de
la fase actual.
