## Construye las figuras de las slides a partir de outputs/ y las serializa como
## objetos ggplot en outputs/figuras/*.rds. slides/index.qmd solo hace readRDS().
##
## Se ejecuta desde la raíz de este repo, con la librería del sistema:
##   Rscript R/02_figuras.R

library(tidyverse)
library(ggridges)
library(here)

source(here("R", "00_setup.R"))

dir.create(here("outputs", "figuras"), showWarnings = FALSE)

guardar_fig <- function(fig, nombre) {
  saveRDS(fig, here("outputs", "figuras", paste0(nombre, ".rds")))
  cat(sprintf("  ✓ %s\n", nombre))
}

a_nombre <- function(x) unname(nombres_partido[x])

escanos_draws <- readRDS(here("outputs", "escanos_draws.rds"))
voto_draws <- readRDS(here("outputs", "voto_draws.rds"))
procedencia <- readRDS(here("outputs", "procedencia.rds"))

corte <- format(procedencia$ultima_encuesta, "%d/%m/%Y")

## ---- 1. Encuestas en el tiempo ---------------------------------------------------

colores_voto <- c(colores_esc, "SUMAR" = "#A00B85")

encuestas <- readRDS(here("outputs", "encuestas_modelo.rds")) |>
  filter(partido %in% c("PP", "PSOE", "VOX", "SUMAR", "PODEMOS", "SALF")) |>
  mutate(partido = factor(a_nombre(partido), levels = a_nombre(c("PP", "PSOE", "VOX", "SUMAR", "PODEMOS", "SALF"))))

fig_encuestas_tiempo <- encuestas |>
  ggplot(aes(x = fecha, y = pct, color = partido)) +
  geom_vline(xintercept = fecha_elecciones, linetype = "dashed", color = "grey40") +
  annotate(
    "text",
    x = fecha_elecciones, y = 36, label = "29-N", hjust = 1.15,
    color = "grey30", size = 5
  ) +
  geom_point(size = 2.4, alpha = 0.75) +
  geom_smooth(se = FALSE, linewidth = 1.1, method = "loess", span = 1) +
  scale_color_manual(values = colores_esc, name = NULL) +
  scale_x_date(
    limits = c(min(encuestas$fecha), fecha_elecciones),
    date_breaks = "1 month",
    date_labels = "%b"
  ) +
  labs(
    title = sprintf(
      "%d encuestas de %d casas, modelo 1",
      procedencia$n_encuestas_m1, procedencia$n_casas_m1
    ),
    subtitle = sprintf("Última encuesta: %s", corte),
    x = NULL,
    y = "Estimación publicada (%)"
  ) +
  theme_slides() +
  theme(legend.position = "bottom")

guardar_fig(fig_encuestas_tiempo, "fig_encuestas_tiempo")

## ---- 2. Posterior predictive check -----------------------------------------------

ppc <- readRDS(here("outputs", "ppc.rds")) |>
  filter(partido %in% c("PP", "PSOE", "VOX", "SUMAR", "PODEMOS", "SALF")) |>
  mutate(partido = factor(a_nombre(partido), levels = a_nombre(c("PP", "PSOE", "VOX", "SUMAR", "PODEMOS", "SALF"))))

cobertura_ppc <- mean(ppc$obs >= ppc$q05 & ppc$obs <= ppc$q95)
saveRDS(cobertura_ppc, here("outputs", "cobertura_ppc.rds"))

fig_ppc_posterior <- ppc |>
  ggplot(aes(x = fecha, color = partido)) +
  geom_linerange(aes(ymin = q05, ymax = q95), linewidth = 0.9, alpha = 0.45) +
  geom_point(aes(y = obs), size = 1.9) +
  facet_wrap(~partido, scales = "free_y") +
  scale_color_manual(values = colores_esc, guide = "none") +
  scale_x_date(date_breaks = "2 months", date_labels = "%b") +
  labs(
    title = "Posterior predictive check",
    subtitle = "Barra: IC 90 % predicho para cada encuesta · Punto: valor publicado",
    x = NULL,
    y = "Voto (%)"
  ) +
  theme_slides(base_size = 15)

guardar_fig(fig_ppc_posterior, "fig_ppc_posterior")

## ---- 3. Posterior del día E ------------------------------------------------------

epred_e <- readRDS(here("outputs", "epred_dia_e.rds"))

resumen_dia_e <- epred_e |>
  pivot_longer(everything(), names_to = "partido", values_to = "voto") |>
  group_by(partido) |>
  summarise(
    mediana = median(voto),
    low = quantile(voto, 0.05),
    high = quantile(voto, 0.95),
    .groups = "drop"
  ) |>
  arrange(desc(mediana)) |>
  mutate(partido = if_else(partido == "BLOQUE", "Bloque", a_nombre(partido)))
saveRDS(resumen_dia_e, here("outputs", "resumen_dia_e.rds"))

fig_posterior_dia_e <- epred_e |>
  select(-BLOQUE) |>
  pivot_longer(everything(), names_to = "partido", values_to = "voto") |>
  mutate(partido = factor(a_nombre(partido), levels = a_nombre(c("PP", "PSOE", "VOX", "SUMAR", "PODEMOS", "SALF")))) |>
  ggplot(aes(x = voto, fill = partido)) +
  geom_density(alpha = 0.65, color = NA) +
  scale_fill_manual(values = colores_esc, name = NULL) +
  labs(x = "Voto estimado (%)", y = "Densidad") +
  theme_slides() +
  theme(legend.position = "bottom")

guardar_fig(fig_posterior_dia_e, "fig_posterior_dia_e")

## ---- 4. Reparto provincial -------------------------------------------------------

provincias_ej <- c("Madrid", "Barcelona", "Sevilla", "Bizkaia", "Almería", "Soria")

prov_resumen <- readRDS(here("outputs", "prov_resumen.rds")) |>
  filter(provincia %in% provincias_ej) |>
  mutate(
    partido = factor(a_nombre(partido), levels = a_nombre(c("PP", "PSOE", "VOX", "SUMAR"))),
    provincia = factor(provincia, levels = rev(provincias_ej))
  )
stopifnot(n_distinct(prov_resumen$provincia) == length(provincias_ej))

fig_provincial <- prov_resumen |>
  ggplot(aes(y = provincia, color = partido)) +
  geom_linerange(aes(xmin = q05, xmax = q95), linewidth = 1, alpha = 0.5) +
  geom_linerange(aes(xmin = q25, xmax = q75), linewidth = 3) +
  geom_point(aes(x = pct_23j), color = "grey10", shape = 18, size = 3.5) +
  facet_wrap(~partido, nrow = 1, scales = "free_x") +
  scale_color_manual(values = colores_esc, guide = "none") +
  labs(
    title = "Voto provincial simulado",
    subtitle = "Barra fina: IC 90 % · Barra gruesa: IC 50 % · Rombo: resultado del 23J (Sumar con Podemos)",
    x = "Voto (%)",
    y = NULL
  ) +
  theme_slides(base_size = 15)

guardar_fig(fig_provincial, "fig_provincial")

## ---- 5. Distribución de escaños (ridgeline) --------------------------------------

medias <- medias_resto_mayor(escanos_draws) |>
  filter(familia %in% names(nombres_partido)) |>
  mutate(partido = a_nombre(familia))

largo_escanos <- escanos_draws |>
  select(.draw, all_of(medias$familia)) |>
  pivot_longer(-.draw, names_to = "familia", values_to = "escanos") |>
  mutate(partido = a_nombre(familia))

resumen_ridge <- largo_escanos |>
  group_by(partido) |>
  summarise(
    media = mean(escanos),
    lo90 = quantile(escanos, 0.05),
    hi90 = quantile(escanos, 0.95),
    .groups = "drop"
  ) |>
  left_join(select(medias, partido, etiqueta), by = "partido")
saveRDS(resumen_ridge, here("outputs", "resumen_escanos.rds"))

# altura de cada cresta en la escala de geom_density_ridges(scale = 0.9): se usa
# para que la línea de la media y la etiqueta sigan a la curva de cada partido
ridge_escanos <- function(partidos, bw, titulo, paso_x, escala = 0.9) {
  niveles <- resumen_ridge |>
    filter(partido %in% partidos) |>
    arrange(media) |>
    pull(partido)
  d <- largo_escanos |>
    filter(partido %in% partidos) |>
    mutate(partido = factor(partido, levels = niveles))
  picos <- d |>
    group_by(partido) |>
    summarise(pico = max(density(escanos, bw = bw)$y), .groups = "drop") |>
    mutate(alto = escala * pico / max(pico))
  r <- resumen_ridge |>
    filter(partido %in% partidos) |>
    mutate(partido = factor(partido, levels = niveles)) |>
    left_join(picos, by = "partido")
  ref <- tibble(partido = names(escanos_23j), escanos = unname(escanos_23j)) |>
    filter(partido %in% partidos) |>
    mutate(partido = factor(partido, levels = niveles))

  ggplot(d, aes(x = escanos, y = partido, fill = partido)) +
    geom_density_ridges(scale = escala, bandwidth = bw, alpha = 0.85, color = NA) +
    geom_segment(
      data = r,
      aes(x = media, xend = media, y = as.numeric(partido), yend = as.numeric(partido) + alto),
      color = "white", linewidth = 0.9
    ) +
    geom_segment(
      data = ref,
      aes(x = escanos, xend = escanos, y = as.numeric(partido), yend = as.numeric(partido) + 0.8),
      color = "grey20", linewidth = 0.6, linetype = "dashed"
    ) +
    geom_text(
      data = r,
      aes(x = media, y = as.numeric(partido) + alto + 0.1, label = etiqueta),
      fontface = "bold", size = 5.5, color = "grey15"
    ) +
    geom_text(
      data = r,
      aes(x = lo90, y = as.numeric(partido) + 0.14, label = round(lo90)),
      hjust = 1, nudge_x = -1, size = 4.2, fontface = "bold", color = "grey35"
    ) +
    geom_text(
      data = r,
      aes(x = hi90, y = as.numeric(partido) + 0.14, label = round(hi90)),
      hjust = 0, nudge_x = 1, size = 4.2, fontface = "bold", color = "grey35"
    ) +
    scale_fill_manual(values = colores_esc, guide = "none") +
    scale_x_continuous(breaks = scales::breaks_width(paso_x), expand = expansion(mult = 0.05)) +
    labs(
      title = titulo,
      subtitle = "Blanco y cifra: media · Laterales: IC 90 % · Discontinua: 23J (Sumar con Podemos)",
      x = "Escaños",
      y = NULL
    ) +
    theme_slides(base_size = 18) +
    theme(panel.grid.major.y = element_blank())
}

# candidaturas pequeñas: pocos valores enteros. Una barra por entero, cada fila
# a su propia escala y las cifras en una columna a la derecha, sin solapes
barras_escanos <- function(partidos, titulo) {
  niveles <- resumen_ridge |>
    filter(partido %in% partidos) |>
    arrange(media, hi90) |>
    pull(partido)
  fila <- setNames(seq_along(niveles), niveles)
  barras <- largo_escanos |>
    filter(partido %in% partidos) |>
    count(partido, escanos) |>
    group_by(partido) |>
    mutate(alto = 0.85 * n / max(n)) |>
    ungroup() |>
    mutate(y = fila[partido])
  r <- resumen_ridge |>
    filter(partido %in% partidos) |>
    mutate(y = fila[partido], texto = sprintf("%d  (%d – %d)", etiqueta, round(lo90), round(hi90)))
  ref <- tibble(partido = names(escanos_23j), escanos = unname(escanos_23j)) |>
    filter(partido %in% partidos) |>
    mutate(y = fila[partido])
  x_texto <- max(barras$escanos) + 1.5

  ggplot() +
    geom_rect(
      data = barras,
      aes(xmin = escanos - 0.48, xmax = escanos + 0.48, ymin = y, ymax = y + alto, fill = partido),
      alpha = 0.85
    ) +
    geom_segment(
      data = r,
      aes(x = media, xend = media, y = y, yend = y + 0.85),
      color = "white", linewidth = 1
    ) +
    geom_segment(
      data = ref,
      aes(x = escanos, xend = escanos, y = y, yend = y + 0.92),
      color = "grey20", linewidth = 0.6, linetype = "dashed"
    ) +
    geom_text(
      data = r,
      aes(x = x_texto, y = y + 0.35, label = texto),
      hjust = 0, size = 4.8, fontface = "bold", color = "grey25"
    ) +
    annotate(
      "text",
      x = x_texto, y = length(niveles) + 1.05,
      label = "media (IC 90 %)", hjust = 0, size = 4, color = "grey45"
    ) +
    scale_fill_manual(values = colores_esc, guide = "none") +
    scale_y_continuous(
      breaks = fila + 0.35, labels = names(fila),
      expand = expansion(mult = c(0.01, 0.03))
    ) +
    scale_x_continuous(
      breaks = seq(0, 16, 2),
      limits = c(-0.6, x_texto + 3.6),
      expand = expansion(mult = 0.01)
    ) +
    labs(
      title = titulo,
      subtitle = "Barra: frecuencia de cada entero · Blanco: media · Discontinua: 23J",
      x = "Escaños",
      y = NULL
    ) +
    theme_slides(base_size = 16) +
    theme(panel.grid.major.y = element_blank())
}

guardar_fig(
  ridge_escanos(c("PP", "PSOE", "VOX", "Frente Amplio"), 1.5, "Escaños: las cuatro candidaturas mayores", 20),
  "fig_ridges_grandes"
)
guardar_fig(
  barras_escanos(
    c("ERC", "EH Bildu", "Junts", "PNV", "Adelante A.", "BNG", "CC", "Podemos", "UPN", "SALF"),
    "Escaños: el resto de candidaturas"
  ),
  "fig_ridges_resto"
)

## ---- 6. Probabilidad de cada mayoría -------------------------------------------

de_investidura <- c("PSOE", "SUMAR", "PODEMOS", "AA", "ERC", "Junts", "EH Bildu", "PNV", "BNG", "CC")

clasificado <- escanos_draws |>
  mutate(
    derecha = PP + VOX,
    investidura = rowSums(across(all_of(de_investidura))),
    scenario = case_when(
      PP >= mayoria_absoluta ~ "PP solo",
      derecha >= mayoria_absoluta ~ "PP + VOX",
      investidura >= mayoria_absoluta ~ "Investidura",
      TRUE ~ "Sin mayoría"
    ),
    scenario = factor(scenario, levels = names(col_mayoria))
  ) |>
  select(.draw, derecha, investidura, PP, VOX, scenario) |>
  left_join(
    voto_draws |>
      transmute(
        .draw,
        ventaja_voto = (PP + VOX) - rowSums(across(all_of(de_investidura)))
      ),
    by = ".draw"
  )

prob_escenario <- clasificado |>
  count(scenario, .drop = FALSE) |>
  mutate(prob = n / sum(n))
saveRDS(prob_escenario, here("outputs", "prob_mayorias.rds"))
saveRDS(
  list(
    mediana_derecha = median(clasificado$derecha),
    mediana_investidura = median(clasificado$investidura),
    mediana_pp = median(clasificado$PP)
  ),
  here("outputs", "resumen_bloques.rds")
)

fig_mayorias_hist <- clasificado |>
  ggplot(aes(x = ventaja_voto, fill = scenario)) +
  geom_histogram(binwidth = 0.5, color = "white", linewidth = 0.08) +
  scale_fill_manual(
    values = col_mayoria,
    # etiquetas ya calculadas: una función que use objetos de este script no
    # sobrevive al saveRDS() de la figura
    labels = setNames(
      sprintf("%s: %s", prob_escenario$scenario, pct_es(prob_escenario$prob)),
      as.character(prob_escenario$scenario)
    ),
    name = NULL,
    drop = FALSE
  ) +
  scale_y_continuous(labels = scales::label_number(big.mark = ".", decimal.mark = ",")) +
  labs(
    title = "¿Qué probabilidad tiene cada mayoría?",
    subtitle = "Cada simulación se colorea según la mayoría de escaños que produce",
    x = "Ventaja de voto: PP + VOX menos el bloque de investidura (puntos)",
    y = "Simulaciones"
  ) +
  theme_slides() +
  theme(
    legend.position = "bottom",
    panel.grid.major.x = element_blank()
  )

guardar_fig(fig_mayorias_hist, "fig_mayorias_hist")

## ---- 7. Backtest -------------------------------------------------------------------

etiquetas_eleccion <- c(`20d` = "20D-2015", `26j` = "26J-2016", `28a` = "28A-2019", `10n` = "10N-2019", `23j` = "23J-2023")
nombre_backtest <- c(PP = "PP", PSOE = "PSOE", VOX = "VOX", SUMAR = "Podemos / Sumar")
colores_backtest <- c("PP" = "#005999", "PSOE" = "#FF0126", "VOX" = "#51962A", "Podemos / Sumar" = "#A00B85")

backtest <- read_csv(here("data", "backtest_escanos.csv"), show_col_types = FALSE) |>
  mutate(
    eleccion = factor(etiquetas_eleccion[eleccion], levels = etiquetas_eleccion),
    partido = factor(nombre_backtest[familia], levels = rev(nombre_backtest))
  )

fig_backtest <- backtest |>
  ggplot(aes(y = partido, color = partido)) +
  geom_linerange(aes(xmin = q05, xmax = q95), linewidth = 2.2, alpha = 0.45) +
  geom_point(aes(x = mediana), size = 3) +
  geom_point(aes(x = real), color = "grey10", shape = 18, size = 4.5) +
  facet_wrap(~eleccion, nrow = 1) +
  scale_color_manual(values = colores_backtest, guide = "none") +
  labs(
    title = sprintf(
      "%d de %d resultados dentro del IC 90 %%",
      sum(backtest$dentro), nrow(backtest)
    ),
    subtitle = "Barra: IC 90 % · Punto: mediana · Rombo: escaños reales",
    x = "Escaños",
    y = NULL
  ) +
  theme_slides(base_size = 15) +
  theme(axis.text.x = element_text(size = 11))

guardar_fig(fig_backtest, "fig_backtest")

## ---- 8. [opcional] Mapa de calor PP frente a VOX -----------------------------------

fig_heatmap_ppvox <- clasificado |>
  count(PP, VOX) |>
  ggplot(aes(x = PP, y = VOX, fill = n)) +
  geom_tile(color = "white", linewidth = 0.15) +
  geom_abline(intercept = mayoria_absoluta, slope = -1, linetype = "dashed", linewidth = 0.7) +
  annotate(
    "text",
    x = 101, y = 50, label = "Por debajo de la línea:\nPP + VOX < 176",
    fontface = "bold", size = 4.5
  ) +
  scale_fill_viridis_c(name = "Simulaciones") +
  labs(
    title = "Mapa de calor posterior: PP y VOX",
    subtitle = "Cada celda cuenta las simulaciones con esa combinación de escaños",
    x = "Escaños PP",
    y = "Escaños VOX"
  ) +
  theme_slides() +
  theme(legend.position = "bottom")

guardar_fig(fig_heatmap_ppvox, "fig_heatmap_ppvox")

## ---- 9. [opcional] Efectos casa ---------------------------------------------------

efectos_vox <- readRDS(here("outputs", "efectos_casa.rds")) |>
  filter(param == "muVOX_Intercept") |>
  arrange(Estimate) |>
  mutate(encuestadora = factor(encuestadora, levels = encuestadora))

fig_ranef_vox <- efectos_vox |>
  ggplot(aes(x = Estimate, y = encuestadora)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_pointrange(aes(xmin = Q2.5, xmax = Q97.5), color = "#51962A", linewidth = 0.9) +
  labs(
    title = "¿Qué casa se desvía en VOX?",
    subtitle = "Efecto casa sobre el log-odds de VOX frente al PP, con IC 95 %",
    x = "Desviación (log-odds)",
    y = NULL
  ) +
  theme_slides(base_size = 16)

guardar_fig(fig_ranef_vox, "fig_ranef_vox")

cat(sprintf(
  "\n✓ R/02_figuras.R completado. %d figuras en outputs/figuras/\n",
  length(list.files(here("outputs", "figuras"), pattern = "\\.rds$"))
))
