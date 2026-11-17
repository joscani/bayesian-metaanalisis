## Setup común de slides/index.qmd y slides/corta.qmd.
## Se carga con source(..., local = TRUE) dentro del chunk setup.
library(tidyverse)
library(here)

source(here("R", "00_setup.R"))

# con estimacion_29n = false desaparecen las slides con encuestas o estimaciones
# del 29N. Se renderiza con: quarto render slides/index.qmd -P estimacion_29n:false
estim <- isTRUE(params$estimacion_29n)

leer_fig <- function(nombre) {
  readRDS(here("outputs", "figuras", paste0(nombre, ".rds")))
}
leer <- function(nombre) readRDS(here("outputs", paste0(nombre, ".rds")))

procedencia <- leer("procedencia")
capa_error <- leer("capa_error")
diagnosticos <- leer("diagnosticos")

comparacion <- read_csv(
  here("data", "backtest_prov_comparacion.csv"),
  show_col_types = FALSE
)
cob_prov <- function(v) {
  comparacion$cobertura[
    comparacion$variante == v & comparacion$familia == "TOTAL"
  ]
}
backtest <- read_csv(
  here("data", "backtest_escanos.csv"),
  show_col_types = FALSE
)
reglas <- read_csv(
  here("data", "coaliciones_izquierda_29N_provincias.csv"),
  col_types = cols(.default = col_character())
) |>
  count(regla)
n_regla <- function(r) reglas$n[reglas$regla == r]

corte <- format(procedencia$ultima_encuesta, "%d/%m/%Y")
peso_electopanel <- leer("peso_electopanel")
