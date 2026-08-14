## De porcentajes regionales a escaños provinciales, con incertidumbre.
## Portado de ~/blog_quarto/2026/05/escanos_a_lo_bayesiano.qmd (líneas 101-512).
## Requiere outputs/draws_dia_d.rds (generado por R/01_modelo_meta.R).
##
## Tres fuentes de incertidumbre encadenadas:
##   [1] el posterior del modelo bayesiano de encuestas (ya viene en draws_dia_d.rds)
##   [2] error histórico de las encuestas (normal multivariante sobre el posterior)
##   [3] reparto provincial (Dirichlet centrada en la referencia de 2022)
## y D'Hondt con barrera del 3% aplicado provincia a provincia.
##
## Genera:
##   - outputs/resultados_escanos.rds   (12000 draws x escaños por partido)
##   - outputs/resumen_mayorias.rds     (tabla de probabilidades de mayoría)
##   - outputs/top_joint.rds            (distribución conjunta de escaños)
##   - outputs/p_aa_gana.rds            (P(Adelante > Por Andalucía) en escaños)

library(tidyverse)
library(gtools)
library(furrr)
library(here)

source(here("R", "00_setup.R"))

draws_wide <- readRDS(here("outputs", "draws_dia_d.rds"))

partidos <- c("pp", "psoe", "vox", "por_andalucia", "adelante", "resto")

n_draws   <- nrow(draws_wide)
draws_mat <- as.matrix(draws_wide[, partidos])

cat(sprintf("Draws disponibles: %d\n", n_draws))

## ---- [2] Error histórico ----------------------------------------------------
## σ y matriz de correlación fijadas a criterio experto (ver justificación en
## el post original); no se re-estiman aquí porque solo hay 2 elecciones con
## datos completos (2022 y 2018), insuficiente para ajustar nada con rigor.

sigma_pp <- c(
  pp            = 3.0,
  psoe          = 2.8,
  vox           = 3.0,
  por_andalucia = 1.8,
  adelante      = 1.5,
  resto         = 2.0
)

R_corr <- matrix(c(
#  pp    psoe   vox   pora    aa   resto
  1.0, -0.3, -0.5, -0.1, -0.1,  0.0,
 -0.3,  1.0, -0.2,  0.5,  0.4,  0.0,
 -0.5, -0.2,  1.0, -0.1, -0.1,  0.0,
 -0.1,  0.5, -0.1,  1.0,  0.6,  0.0,
 -0.1,  0.4, -0.1,  0.6,  1.0,  0.0,
  0.0,  0.0,  0.0,  0.0,  0.0,  1.0
), nrow = 6, ncol = 6, byrow = TRUE,
dimnames = list(partidos, partidos))

D_sigma      <- diag(sigma_pp)
Sigma_struct <- D_sigma %*% R_corr %*% D_sigma
Sigma_prop   <- Sigma_struct / 1e4

set.seed(2847)
error_draws <- MASS::mvrnorm(n_draws, mu = rep(0, 6), Sigma = Sigma_prop)

stopifnot(dim(draws_mat) == dim(error_draws))

draw_adj <- pmax(draws_mat + error_draws, 0)
draw_adj <- draw_adj / rowSums(draw_adj)

## ---- [3] Reparto provincial (Dirichlet) -------------------------------------

ref_2022 <- read_csv(here("data", "ref_provincial_2022.csv"))

n_total <- 500  # concentración igual para todas las provincias

set.seed(1234)
dirichlet_mats <- lapply(seq_len(nrow(ref_2022)), function(i) {
  alpha <- as.numeric(ref_2022[i, partidos]) / 100 * n_total
  mat   <- gtools::rdirichlet(n_draws, alpha)
  colnames(mat) <- partidos
  mat
})
names(dirichlet_mats) <- ref_2022$provincia

## ---- D'Hondt por provincia, agregado a nivel autonómico ---------------------
## dhondt() viene de R/00_setup.R.

sim_escanos_draw <- function(k, draw_vec) {
  escanos_totales <- integer(length(partidos))
  names(escanos_totales) <- partidos
  for (i in seq_len(nrow(ref_2022))) {
    prov_vec        <- dirichlet_mats[[i]][k, ]
    ratio           <- prov_vec / (regional_2022[partidos] / 100)
    raw             <- draw_vec * ratio
    norm            <- raw / sum(raw)
    # "resto" agrupa partidos que no compiten individualmente por escaños
    norm["resto"]   <- 0
    norm            <- norm / sum(norm)
    escanos_totales <- escanos_totales + dhondt(norm, ref_2022$escanos[i])
  }
  escanos_totales
}

plan(multisession, workers = max(1, parallel::detectCores() - 1))

escanos_list <- future_map(
  seq_len(n_draws),
  \(k) sim_escanos_draw(k, draw_adj[k, ]),
  .options = furrr_options(seed = NULL)
)

plan(sequential)

## ---- Resultados --------------------------------------------------------------

resultados_escanos <- draws_wide |>
  mutate(
    pp_esc            = map_int(escanos_list, "pp"),
    psoe_esc          = map_int(escanos_list, "psoe"),
    vox_esc           = map_int(escanos_list, "vox"),
    por_andalucia_esc = map_int(escanos_list, "por_andalucia"),
    adelante_esc      = map_int(escanos_list, "adelante"),
    resto_esc         = map_int(escanos_list, "resto")
  )

n_mal <- resultados_escanos |>
  transmute(total = pp_esc + psoe_esc + vox_esc + por_andalucia_esc + adelante_esc + resto_esc) |>
  filter(total != 109) |>
  nrow()

if (n_mal > 0) {
  stop(sprintf("¡Error en D'Hondt! %d draws no suman 109 escaños.", n_mal))
} else {
  message(sprintf("✓ Los %d draws suman exactamente 109 escaños.", nrow(resultados_escanos)))
}

saveRDS(resultados_escanos, here("outputs", "resultados_escanos.rds"))
saveRDS(draw_adj,          here("outputs", "draw_adj.rds"))
saveRDS(dirichlet_mats,    here("outputs", "dirichlet_mats.rds"))

## ---- Tablas resumen para las slides -------------------------------------------

resumen_mayorias <- resultados_escanos |>
  mutate(
    pp_vox  = pp_esc + vox_esc,
    pp_solo = pp_esc >= 55
  ) |>
  summarise(
    pp_mediana_esc   = median(pp_esc),
    p_pp_mayoria_abs = mean(pp_solo),
    p_ppvox_mayoria  = mean(!pp_solo & pp_vox >= 55),
    p_ppvox_menor55  = mean(pp_vox < 55)
  )

saveRDS(resumen_mayorias, here("outputs", "resumen_mayorias.rds"))

p_aa_gana <- mean(resultados_escanos$adelante_esc > resultados_escanos$por_andalucia_esc)
saveRDS(p_aa_gana, here("outputs", "p_aa_gana.rds"))

top_joint <- resultados_escanos |>
  count(pp_esc, psoe_esc, vox_esc, por_andalucia_esc, adelante_esc, resto_esc, sort = TRUE) |>
  mutate(
    prob      = n / sum(n),
    prob_acum = cumsum(prob)
  )

saveRDS(top_joint, here("outputs", "top_joint.rds"))

cat(sprintf(
  "\n✓ R/02_escanos.R completado. P(PP mayoría abs.) = %.1f%% · P(Adelante > Por Andalucía) = %.1f%%\n",
  100 * resumen_mayorias$p_pp_mayoria_abs, 100 * p_aa_gana
))
