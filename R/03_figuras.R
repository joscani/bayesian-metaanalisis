## Construye todas las figuras de las slides a partir de los outputs de
## R/01_modelo_meta.R y R/02_escanos.R, y las serializa como objetos ggplot
## en outputs/figuras/*.rds. slides/index.qmd solo hace readRDS() de estos
## objetos: no computa nada.
##
## Portado de meta-analisis-andalucia.qmd y escanos_a_lo_bayesiano.qmd,
## ajustando tamaños de fuente y grosor de trazo para proyección (theme_slides()).

library(tidyverse)
library(ggridges)
library(here)

source(here("R", "00_setup.R"))

dir.create(here("outputs", "figuras"), showWarnings = FALSE)

guardar_fig <- function(fig, nombre) {
  saveRDS(fig, here("outputs", "figuras", paste0(nombre, ".rds")))
  cat(sprintf("  ✓ %s\n", nombre))
}

cat("Generando figuras...\n")

## ---- 1. Evolución temporal de las encuestas -----------------------------------

df_long <- readRDS(here("outputs", "df_long.rds"))

fig_encuestas_tiempo <- df_long |>
  ggplot(aes(x = time, y = estim, color = partido)) +
  geom_point(size = 2.2, alpha = 0.8) +
  scale_color_manual(values = colores, guide = "none") +
  geom_smooth(se = FALSE, linewidth = 1.1) +
  labs(
    title = "23 encuestas, elecciones andaluzas 2026",
    x = "Días hasta las elecciones (0 = 17 mayo)",
    y = "Estimación (%)"
  ) +
  theme_slides()

guardar_fig(fig_encuestas_tiempo, "fig_encuestas_tiempo")

## ---- 2. Posterior predictive check ---------------------------------------------

ppc_posterior <- readRDS(here("outputs", "ppc_posterior.rds"))

fig_ppc_posterior <- ppc_posterior |>
  ggplot(aes(x = time, color = partido)) +
  tidybayes::stat_lineribbon(aes(y = pred), .width = c(0.50, 0.90), alpha = 0.25) +
  geom_point(aes(y = obs), size = 1.8) +
  facet_wrap(~partido, scales = "free_y") +
  scale_color_manual(values = colores, guide = "none") +
  scale_fill_grey(start = 0.6, end = 0.85, guide = "none") +
  labs(
    title    = "Posterior predictive check",
    subtitle = "Bandas: IC 50% y 90% del posterior · Puntos: proporción observada",
    x = "Días hasta las elecciones", y = "Proporción"
  ) +
  theme_slides(base_size = 14)

guardar_fig(fig_ppc_posterior, "fig_ppc_posterior")

## ---- 3. Posterior día de las elecciones -----------------------------------------

estimaciones_dia_d <- readRDS(here("outputs", "estimaciones_dia_d.rds"))

fig_posterior_dia_d <- estimaciones_dia_d |>
  ggplot(aes(x = .epred, fill = partido)) +
  geom_density(alpha = 0.6) +
  scale_x_continuous(labels = scales::percent, limits = c(0, 0.6)) +
  scale_fill_manual(values = colores) +
  labs(
    title = "Estimación día de las elecciones",
    x     = "Porcentaje estimado",
    y     = "Densidad",
    fill  = NULL
  ) +
  theme_slides() +
  theme(legend.position = "bottom")

guardar_fig(fig_posterior_dia_d, "fig_posterior_dia_d")

## ---- 4. Reparto provincial: Dirichlet -------------------------------------------

dirichlet_mats <- readRDS(here("outputs", "dirichlet_mats.rds"))
ref_2022 <- read_csv(here("data", "ref_provincial_2022.csv"), show_col_types = FALSE)

fig_dirichlet_box <- map_dfr(names(dirichlet_mats), function(prov) {
  as_tibble(dirichlet_mats[[prov]] * 100) |>
    mutate(provincia = prov)
}) |>
  pivot_longer(-provincia, names_to = "partido", values_to = "pct") |>
  left_join(
    ref_2022 |> pivot_longer(all_of(partidos), names_to = "partido", values_to = "ref"),
    by = c("provincia", "partido")
  ) |>
  mutate(partido = factor(partido, levels = partidos)) |>
  ggplot(aes(x = pct, y = provincia)) +
  geom_boxplot(outlier.size = 0.4, fill = "steelblue", alpha = 0.4) +
  geom_point(aes(x = ref), color = "firebrick", size = 2, shape = 18) +
  facet_wrap(~partido, scales = "free_x") +
  labs(
    title    = "Dirichlet: distribución provincial del voto",
    subtitle = "Caja: incertidumbre Dirichlet · Punto rojo: referencia 2022",
    x = "%", y = NULL
  ) +
  theme_slides(base_size = 14)

guardar_fig(fig_dirichlet_box, "fig_dirichlet_box")

## ---- 5. Distribución de escaños (ridgeline) -- la figura estrella --------------

resultados_escanos <- readRDS(here("outputs", "resultados_escanos.rds"))

resumen_ridge <- resultados_escanos |>
  select(all_of(names(nombres_partido))) |>
  summarise(across(
    everything(),
    list(
      media = mean,
      lo80  = \(x) quantile(x, 0.10),
      hi80  = \(x) quantile(x, 0.90)
    )
  )) |>
  pivot_longer(
    everything(),
    names_to  = c("partido", ".value"),
    names_sep = "_(?=[^_]+$)"
  ) |>
  mutate(
    partido = nombres_partido[partido],
    partido = factor(partido, levels = niveles_ridge),
    media   = round(media, 1)
  )

ref2022_ridge <- tibble(
  partido      = factor(c("PP", "PSOE-A", "Vox", "Por Andalucía", "Adelante A."),
                        levels = niveles_ridge),
  escanos_2022 = c(58, 30, 14, 5, 2)
)

fig_ridges_escanos <- resultados_escanos |>
  select(.draw, all_of(names(nombres_partido))) |>
  pivot_longer(-.draw, names_to = "partido", values_to = "escanos") |>
  mutate(
    partido = nombres_partido[partido],
    partido = factor(partido, levels = niveles_ridge)
  ) |>
  ggplot(aes(x = escanos, y = partido, fill = partido)) +
  geom_density_ridges(scale = 0.9, bandwidth = 0.8, alpha = 0.85, color = NA) +
  geom_segment(
    data = resumen_ridge,
    aes(x = media, xend = media,
        y = as.numeric(partido), yend = as.numeric(partido) + 0.9),
    color = "white", linewidth = 0.9
  ) +
  geom_segment(
    data = ref2022_ridge,
    aes(x = escanos_2022, xend = escanos_2022,
        y = as.numeric(partido), yend = as.numeric(partido) + 0.9),
    color = "grey20", linewidth = 0.6, linetype = "dashed"
  ) +
  geom_text(
    data = resumen_ridge,
    aes(x = media, y = partido, label = media),
    nudge_y = 0.60, fontface = "bold", size = 4.5, color = "grey20"
  ) +
  geom_text(
    data = resumen_ridge,
    aes(x = lo80, y = partido, label = lo80),
    nudge_y = 0.45, hjust = 1, nudge_x = -0.5,
    size = 3.8, fontface = "bold", color = "grey30"
  ) +
  geom_text(
    data = resumen_ridge,
    aes(x = hi80, y = partido, label = hi80),
    nudge_y = 0.45, hjust = 0, nudge_x = 0.5,
    size = 3.8, fontface = "bold", color = "grey30"
  ) +
  scale_fill_manual(values = colores_esc, guide = "none") +
  scale_x_continuous(breaks = seq(0, 65, 5)) +
  labs(
    title    = "Distribución posterior de escaños",
    subtitle = "Blanco: media · Pequeño: IC 80% · Discontinua: resultado 2022",
    x = "Escaños", y = NULL
  ) +
  theme_slides(base_size = 18) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    axis.ticks         = element_blank()
  )

guardar_fig(fig_ridges_escanos, "fig_ridges_escanos")

## ---- 6. Probabilidad de cada mayoría --------------------------------------------

draws_wide <- readRDS(here("outputs", "draws_dia_d.rds"))

mayoria_df <- draws_wide |>
  mutate(ventaja_voto = 100 * ((pp + vox) - (psoe + por_andalucia + adelante))) |>
  select(.draw, ventaja_voto) |>
  left_join(
    resultados_escanos |>
      mutate(
        pp_vox = pp_esc + vox_esc,
        izq    = psoe_esc + por_andalucia_esc + adelante_esc,
        scenario = case_when(
          pp_esc >= 55 ~ "PP solo",
          pp_vox >= 55 ~ "PP + Vox",
          izq    >= 55 ~ "Izquierda",
          TRUE         ~ "Sin mayoría"
        ),
        scenario = factor(scenario, levels = names(col_mayoria))
      ) |>
      select(.draw, scenario, pp_esc, pp_vox),
    by = ".draw"
  )

pct_df <- mayoria_df |> count(scenario) |> mutate(pct = n / sum(n))
pct    <- setNames(pct_df$pct, as.character(pct_df$scenario))

xann <- function(scen, q = 0.5) {
  v <- mayoria_df$ventaja_voto[mayoria_df$scenario == scen]
  if (length(v) == 0) NA_real_ else quantile(v, q)
}
xann_ppsolo <- xann("PP solo",  q = 0.97)
xann_ppvox  <- xann("PP + Vox", q = 0.03)
xann_izq    <- min(mayoria_df$ventaja_voto) - 0.5

max_n <- mayoria_df |>
  mutate(bin = round(ventaja_voto / 0.5) * 0.5) |>
  count(bin) |> pull(n) |> max()

ann <- function(p, x, y_pct, col, label_name,
                pct_size = 6.5, name_size = 4.2, gap = 0.13,
                offset = 0.7, hjust = 0) {
  if (is.na(x) || is.na(p)) return(list())
  acc <- ifelse(p < 0.01, 0.1, 1)
  list(
    annotate("point", x = x,          y = y_pct,               color = col, size = 3.5, shape = 15),
    annotate("text",  x = x + offset, y = y_pct,               hjust = hjust, vjust = 0.4,
             label = scales::percent(p, accuracy = acc),
             color = col, fontface = "bold", size = pct_size),
    annotate("text",  x = x + offset, y = y_pct - max_n * gap, hjust = hjust, vjust = 0.4,
             label = label_name, color = col, size = name_size)
  )
}

fig_mayorias_hist <- ggplot(mayoria_df, aes(x = ventaja_voto, fill = scenario)) +
  geom_histogram(binwidth = 0.5, color = "white", linewidth = 0.08) +
  ann(pct["PP solo"],   xann_ppsolo,  max_n * 1.38, "#005999", "PP solo",
      offset = -0.7, hjust = 1) +
  ann(pct["PP + Vox"],  xann_ppvox,   max_n * 1.38, "#4a9cc4", "PP + Vox") +
  ann(pct["Izquierda"], xann_izq,     max_n * 0.20, "#cc3333", "Izquierda",
      pct_size = 4.6, name_size = 3.5) +
  scale_fill_manual(values = col_mayoria, guide = "none") +
  scale_x_continuous(breaks = seq(-20, 60, 10)) +
  scale_y_continuous(
    expand = expansion(mult = c(0, 0.55)),
    labels = scales::label_comma()
  ) +
  labs(
    title    = "¿Qué probabilidad tiene cada mayoría?",
    subtitle = "El área de cada color representa la probabilidad de cada escenario",
    x = "← Izquierda · Ventaja voto (PP+Vox − PSOE+PorA+AA), pp · Derecha →",
    y = "Número de simulaciones"
  ) +
  theme_slides() +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor   = element_blank(),
    panel.grid.major.y = element_line(color = "grey92")
  )

guardar_fig(fig_mayorias_hist, "fig_mayorias_hist")

## ---- 7. Heatmap PP vs Vox, con el resultado real -----------------------------

resultado_real <- read_csv(here("data", "resultado_real_2026.csv"), show_col_types = FALSE)

resultado_real_pp_vox <- tibble(
  pp_esc  = resultado_real$escanos[resultado_real$partido == "pp"],
  vox_esc = resultado_real$escanos[resultado_real$partido == "vox"]
)

fig_heatmap_ppvox <- resultados_escanos |>
  count(pp_esc, vox_esc) |>
  ggplot(aes(x = pp_esc, y = vox_esc, fill = n)) +
  geom_tile(color = "white", linewidth = 0.15) +
  geom_vline(xintercept = 55, linetype = "dashed", linewidth = 0.7) +
  geom_abline(intercept = 55, slope = -1, linetype = "dashed", linewidth = 0.7) +
  geom_point(
    data = resultado_real_pp_vox,
    aes(x = pp_esc, y = vox_esc),
    inherit.aes = FALSE,
    shape = 21, size = 5.5, stroke = 1.4, fill = "white", color = "black"
  ) +
  geom_text(
    data = resultado_real_pp_vox,
    aes(x = pp_esc, y = vox_esc,
        label = sprintf("Resultado real\nPP %d · Vox %d", pp_esc, vox_esc)),
    inherit.aes = FALSE, nudge_y = 4.5, size = 4.2, fontface = "bold"
  ) +
  scale_fill_viridis_c() +
  labs(
    title = "Mapa de calor posterior: PP vs Vox",
    subtitle = "Cada celda cuenta cuántos draws posteriores dan esa combinación de escaños",
    x = "Escaños PP", y = "Escaños Vox", fill = "Frecuencia"
  ) +
  theme_slides() +
  theme(legend.position = "bottom")

guardar_fig(fig_heatmap_ppvox, "fig_heatmap_ppvox")

## ---- 8. [opcional] Distribución conjunta por bloques ----------------------------

fig_conjunta_bloques <- resultados_escanos |>
  mutate(
    derecha   = pp_esc + vox_esc,
    izquierda = psoe_esc + por_andalucia_esc + adelante_esc
  ) |>
  count(derecha, izquierda) |>
  ggplot(aes(x = derecha, y = izquierda, fill = n)) +
  geom_tile(color = "white", linewidth = 0.15) +
  scale_fill_viridis_c() +
  labs(
    title = "Distribución conjunta por bloques",
    x = "Escaños derecha (PP + Vox)",
    y = "Escaños izquierda (PSOE + PorA + AA)",
    fill = "Frecuencia"
  ) +
  theme_slides() +
  theme(legend.position = "bottom")

guardar_fig(fig_conjunta_bloques, "fig_conjunta_bloques")

## ---- 9. [opcional, O4] Efectos aleatorios por empresa (house effects) -----------
## Requiere el objeto brms (no está en outputs/ por su peso); se omite si no está.

model_path <- here("models", "mod_meta_andalucia.rds")
if (file.exists(model_path)) {
  library(brms)
  model_andalucia <- readRDS(model_path)

  ranef_vox <- ranef(model_andalucia)$empresa[, , "muvox_Intercept"] |>
    as.data.frame() |>
    tibble::rownames_to_column("empresa") |>
    arrange(Estimate)

  fig_ranef_vox <- ranef_vox |>
    mutate(empresa = factor(empresa, levels = empresa)) |>
    ggplot(aes(x = Estimate, y = empresa)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
    geom_pointrange(aes(xmin = Q2.5, xmax = Q97.5), color = "#51962A", linewidth = 0.9) +
    labs(
      title    = "¿Qué casa encuestadora se desvía en Vox?",
      subtitle = "Efecto aleatorio de empresa sobre el intercepto de Vox (escala log-odds)",
      x = "Desviación respecto a la media (log-odds)", y = NULL
    ) +
    theme_slides(base_size = 16)

  guardar_fig(fig_ranef_vox, "fig_ranef_vox")
} else {
  cat("  (modelo no encontrado en models/, se omite fig_ranef_vox — slide opcional O4)\n")
}

cat(sprintf("\n✓ R/03_figuras.R completado. %d figuras en outputs/figuras/\n",
            length(list.files(here("outputs", "figuras"), pattern = "\\.rds$"))))
