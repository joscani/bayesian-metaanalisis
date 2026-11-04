# Backtest de 5 generales con ρ(PP, VOX) = +0,5 y con la mediana de Omega del
# post full bayesian. Solo cambia esa correlación: misma semilla por elección.
#
# Se ejecuta desde la RAÍZ DE blog_quarto, para que se active su renv:
#
#   cd ~/proyectos/blog_quarto
#   Rscript ../bayesian-metaanalisis/R/03_backtest_correlacion.R
#
# No modifica el blog. backtest_pipeline.R no tiene la correlación como
# argumento, y su backtest_guardar() sobrescribe los CSV congelados. Por eso se
# carga una copia temporal con dos cambios y se escribe en data/ de este repo:
#   1. La correlación pasa a ser la variable global cor_pp_vox.
#   2. backtest_eleccion() devuelve también los escaños por draw.
#
# Límite: Omega se estimó con 44 elecciones que incluyen estas 5, así que el
# resultado no está fuera de muestra respecto a la correlación.

suppressPackageStartupMessages({
  library(purrr)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(readr)
})

dir_repo <- normalizePath(Sys.getenv("SLIDES_REPO", "../bayesian-metaanalisis"))
f_bt <- here::here("2026/10/backtest_pipeline.R")
stopifnot(file.exists(f_bt), dir.exists(file.path(dir_repo, "data")))

log_paso <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", sep = "")

parchear <- function(lineas, buscado, nuevo) {
  i <- which(lineas == buscado)
  stopifnot(length(i) == 1)
  lineas[i] <- nuevo
  lineas
}
codigo <- readLines(f_bt, encoding = "UTF-8")
codigo <- parchear(
  codigo,
  '      R["PP", "VOX"] <- R["VOX", "PP"] <- 0.5',
  '      R["PP", "VOX"] <- R["VOX", "PP"] <- cor_pp_vox'
)
codigo <- parchear(
  codigo,
  "    sigma = sg",
  "    sigma = sg,\n    esc_draws = esc"
)
f_temp <- tempfile(fileext = ".R")
writeLines(codigo, f_temp)
source(f_temp)

omega <- read_csv(
  here::here("2026/10/full-bayesian/conjunto_parametros.csv"),
  show_col_types = FALSE
) |>
  filter(parametro == "Omega", partido == "VOX-PP")
stopifnot(nrow(omega) == 1)

log_paso("Prepara elecciones")
preps <- preparar_preps()
b <- 2000
tau <- extraer_tau_draws(readRDS(here::here("2026/10/mod_tau_shock.rds")), b = b)
mapa <- mapa_ccaa_congreso()

correr_variante <- function(valor, nombre) {
  cor_pp_vox <<- valor
  map(elecciones, \(e) {
    log_paso(nombre, " · ", e$id)
    correr_bt(
      preps,
      e,
      d_ref = preps[[prev_de[[e$id]]]],
      b = b,
      kappa = 0.5,
      modo = "shock",
      tau = tau,
      mapa = mapa
    )
  })
}

variantes <- list(`+0,5` = 0.5, `Omega` = omega$mediana)
res <- imap(variantes, correr_variante)

tablas <- function(campo) {
  imap_dfr(res, \(r, v) map_dfr(r, campo) |> mutate(variante = v, .before = 1))
}
escanos <- tablas("escanos")
votos <- tablas("votos")

# PP + VOX, solo en las elecciones donde VOX está entre las familias seguidas
suma <- imap_dfr(res, \(r, v) {
  map_dfr(r, \(x) {
    if (!"VOX" %in% x$familias) {
      return(NULL)
    }
    d <- x$esc_draws$PP + x$esc_draws$VOX
    tibble(
      variante = v,
      eleccion = x$id,
      real = x$real_derecha,
      mediana = median(d),
      q05 = unname(quantile(d, 0.05)),
      q95 = unname(quantile(d, 0.95)),
      dentro = real >= q05 & real <= q95
    )
  })
})

write_csv(escanos, file.path(dir_repo, "data", "backtest_escanos_correlacion.csv"))
write_csv(votos, file.path(dir_repo, "data", "backtest_votos_correlacion.csv"))
write_csv(suma, file.path(dir_repo, "data", "backtest_suma_correlacion.csv"))

# control: la variante +0,5 debe reproducir los CSV congelados del blog
control <- function(tabla, f, nombre) {
  congelado <- read_csv(here::here("2026/10", f), show_col_types = FALSE)
  cruce <- tabla |>
    filter(variante == "+0,5") |>
    inner_join(congelado, by = c("eleccion", "familia"), suffix = c("", "_csv"))
  stopifnot(nrow(cruce) == nrow(congelado))
  cat(sprintf(
    "Control %s: dif. máx. mediana %.3f, q05 %.3f, q95 %.3f; celdas con `dentro` distinto: %d\n",
    nombre,
    max(abs(cruce$mediana - cruce$mediana_csv)),
    max(abs(cruce$q05 - cruce$q05_csv)),
    max(abs(cruce$q95 - cruce$q95_csv)),
    sum(cruce$dentro != cruce$dentro_csv)
  ))
}
control(escanos, "backtest_escanos.csv", "escaños")
control(votos, "backtest_votos.csv", "voto")

resumen <- function(d) {
  d |>
    group_by(variante) |>
    summarise(
      celdas = n(),
      dentro = sum(dentro),
      ancho_medio = mean(q95 - q05),
      error_mediano = median(abs(mediana - real)),
      .groups = "drop"
    )
}
cat("\n== Escaños, por partido ==\n")
print(resumen(escanos))
cat("\n== Voto, por partido ==\n")
print(resumen(votos))
cat("\n== Escaños, solo PP y VOX en las elecciones con VOX ==\n")
print(resumen(escanos |> filter(familia %in% c("PP", "VOX"), eleccion %in% c("28a", "10n", "23j"))))
cat("\n== PP + VOX ==\n")
print(suma |> arrange(eleccion, variante), n = Inf)
log_paso("Terminado")
