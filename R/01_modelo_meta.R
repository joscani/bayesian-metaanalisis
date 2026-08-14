## Meta-análisis bayesiano de encuestas: modelo multinomial con brms.
## Portado de ~/blog_quarto/2026/05/meta-analisis-andalucia.qmd (líneas 63-258).
## Genera:
##   - models/mod_meta_andalucia_prior.rds, models/mod_meta_andalucia.rds
##   - outputs/df_wider.rds                  (datos en formato ancho, para las slides)
##   - outputs/draws_dia_d.rds                (posterior regional en time = 0, tibble ancho)
##   - outputs/ppc_prior.rds, outputs/ppc_posterior.rds  (long, ya resumido para pintar)
##   - outputs/convergencia.rds                (tabla Rhat/ESS + nº divergencias)

library(tidyverse)
library(cmdstanr)
library(brms)
library(tidybayes)
library(here)

source(here("R", "00_setup.R"))

options(brms.backend = "cmdstanr")

dir.create(here("models"), showWarnings = FALSE)
dir.create(here("outputs"), showWarnings = FALSE)

## ---- Datos --------------------------------------------------------------

df <- read_csv(here("data", "encuestas_andalucia_2026.csv")) |>
  select(empresa, fecha, n, everything())

df_long <- df |>
  pivot_longer(c(pp, psoe, vox, por_andalucia, adelante, resto),
               names_to = "partido",
               values_to = "estim") |>
  mutate(
    votos = round(n * estim / 100),
    time  = as.numeric(fecha - fecha_elecciones)
  )

df_wider <- df_long |>
  select(-estim) |>
  pivot_wider(
    id_cols  = c(empresa, n, time),
    names_from  = partido,
    values_from = votos
  ) |>
  mutate(
    n = pp + psoe + vox + por_andalucia + adelante + resto
  )

df_wider$cell_counts <- with(
  df_wider,
  cbind(pp, psoe, vox, por_andalucia, adelante, resto)
)

saveRDS(df_long,  here("outputs", "df_long.rds"))
saveRDS(df_wider, here("outputs", "df_wider.rds"))

## ---- Fórmula y priors -----------------------------------------------------

formula <- brmsformula(
  cell_counts | trials(n) ~ time + (time | empresa)
)

priors <- get_prior(formula, df_wider, family = multinomial())

## ---- Prior predictive check ------------------------------------------------
## Los priors por defecto de brms para efectos fijos en multinomial son
## impropers (flat), lo que impide muestrear solo del prior. Sustituimos por
## priors propios, débilmente informativos en escala log-odds.

priors_ppc <- priors |>
  mutate(prior = case_when(
    prior != ""          ~ prior,
    class == "b"         ~ "normal(0, 2)",
    class == "Intercept" ~ "normal(0, 2)",
    class == "sd"        ~ "exponential(1)",
    class == "cor"       ~ "lkj(1)",
    TRUE                 ~ prior
  ))

model_prior <- brm(
  formula,
  df_wider,
  multinomial(),
  prior          = priors_ppc,
  sample_prior   = "only",
  iter           = 2000,
  warmup         = 500,
  cores          = 4,
  chains         = 2,
  seed           = 47,
  file           = here("models", "mod_meta_andalucia_prior"),
  backend        = "cmdstanr",
  refresh        = 0
)

obs_props_ppc <- df_wider |>
  mutate(across(c(pp, psoe, vox, por_andalucia, adelante, resto), \(x) x / n)) |>
  select(empresa, time, pp, psoe, vox, por_andalucia, adelante, resto) |>
  pivot_longer(pp:resto, names_to = "partido", values_to = "obs")

pred_prior <- df_wider |>
  add_epred_draws(model_prior, ndraws = 100) |>
  rename(partido = .category, pred = .epred) |>
  ungroup() |>
  mutate(pred = pred / n) |>
  select(empresa, time, partido, pred, .draw) |>
  left_join(obs_props_ppc, by = c("empresa", "time", "partido"))

saveRDS(pred_prior, here("outputs", "ppc_prior.rds"))

## ---- Modelo principal -------------------------------------------------------

model_andalucia <- brm(
  formula,
  df_wider,
  multinomial(),
  prior   = priors,
  iter    = 4000,
  warmup  = 1000,
  cores   = 4,
  chains  = 4,
  seed    = 47,
  file    = here("models", "mod_meta_andalucia"),
  backend = "cmdstanr",
  control = list(adapt_delta = 0.95),
  refresh = 0
)

## ---- Diagnósticos ------------------------------------------------------------

s <- summary(model_andalucia)

tabla_convergencia <- as.data.frame(s$fixed) |>
  tibble::rownames_to_column("param") |>
  select(param, Estimate, Est.Error, `l-95% CI`, `u-95% CI`, Rhat, Bulk_ESS, Tail_ESS) |>
  mutate(across(where(is.numeric), \(x) round(x, 3)))

n_divergentes <- nuts_params(model_andalucia) |>
  filter(Parameter == "divergent__") |>
  summarise(n_divergent = sum(Value)) |>
  pull(n_divergent)

cat(sprintf(
  "Convergencia: Rhat max = %.4f · ESS min (bulk) = %.0f · transiciones divergentes = %d\n",
  max(tabla_convergencia$Rhat), min(tabla_convergencia$Bulk_ESS), n_divergentes
))

saveRDS(
  list(tabla = tabla_convergencia, n_divergentes = n_divergentes),
  here("outputs", "convergencia.rds")
)

## ---- Posterior predictive check (a mano; no existe pp_check() para multinomial) --

obs_props <- obs_props_ppc

pred_props <- df_wider |>
  add_epred_draws(model_andalucia, ndraws = 200) |>
  rename(partido = .category, pred = .epred) |>
  ungroup() |>
  mutate(pred = pred / n) |>
  select(empresa, time, partido, pred, .draw) |>
  left_join(obs_props, by = c("empresa", "time", "partido"))

saveRDS(pred_props, here("outputs", "ppc_posterior.rds"))

## ---- Posterior para el día de las elecciones (time = 0, empresa nueva) -----------

newdata <- tibble(
  empresa = "votaciones_17mayo",
  time    = 0,
  n       = 1
)

estimaciones <- newdata |>
  add_epred_draws(model_andalucia, allow_new_levels = TRUE) |>
  mutate(partido = as_factor(.category)) |>
  select(-.category)

saveRDS(estimaciones, here("outputs", "estimaciones_dia_d.rds"))

resumen_dia_d <- estimaciones |>
  group_by(partido) |>
  summarise(
    media   = mean(.epred),
    mediana = median(.epred),
    low     = quantile(.epred, 0.05),
    high    = quantile(.epred, 0.95)
  ) |>
  mutate(across(media:high, \(x) 100 * round(x, 3)))

saveRDS(resumen_dia_d, here("outputs", "resumen_dia_d.rds"))

# Draws en formato ancho: input directo de R/02_escanos.R
draws_wide <- tibble(empresa = "votaciones_17mayo", time = 0, n = 1) |>
  add_epred_draws(model_andalucia, allow_new_levels = TRUE) |>
  ungroup() |>
  select(.draw, .category, .epred) |>
  pivot_wider(names_from = .category, values_from = .epred)

saveRDS(draws_wide, here("outputs", "draws_dia_d.rds"))

cat(sprintf("\n✓ R/01_modelo_meta.R completado. %d draws guardados en outputs/draws_dia_d.rds\n",
            nrow(draws_wide)))
