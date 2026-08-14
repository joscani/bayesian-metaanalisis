## Constantes y helpers compartidos por los scripts de R/ y por slides/index.qmd
## Consolida lo que en los posts originales del blog estaba duplicado entre
## meta-analisis-andalucia.qmd y escanos_a_lo_bayesiano.qmd.

library(here)

partidos <- c("pp", "psoe", "vox", "por_andalucia", "adelante", "resto")

nombres_partido <- c(
  pp_esc            = "PP",
  psoe_esc          = "PSOE-A",
  vox_esc           = "Vox",
  por_andalucia_esc = "Por Andalucía",
  adelante_esc      = "Adelante A.",
  resto_esc         = "Otros"
)

orden_partidos <- c("PP", "PSOE-A", "Vox", "Por Andalucía", "Adelante A.", "Otros")
niveles_ridge  <- rev(orden_partidos)

colores <- c(
  "pp"            = "#005999",
  "psoe"          = "#FF0126",
  "vox"           = "#51962A",
  "por_andalucia" = "#E51C55",
  "adelante"      = "#8C66F1",
  "resto"         = "grey"
)

colores_esc <- c(
  "PP"             = "#005999",
  "PSOE-A"         = "#FF0126",
  "Vox"            = "#51962A",
  "Por Andalucía"  = "#E51C55",
  "Adelante A."    = "#8C66F1",
  "Otros"          = "#aaaaaa"
)

col_mayoria <- c(
  "Izquierda"   = "#cc3333",
  "Sin mayoría" = "#aaaaaa",
  "PP + Vox"    = "#7ab8d9",
  "PP solo"     = "#005999"
)

fecha_elecciones <- lubridate::ymd("2026-05-17")

escanos_prov <- tibble::tibble(
  provincia = c("Sevilla", "Málaga", "Cádiz", "Granada",
                "Almería", "Córdoba", "Huelva", "Jaén"),
  escanos   = c(18, 17, 15, 13, 12, 12, 11, 11)
)

# Media regional 2022 (denominador del ratio provincial en el reparto Dirichlet)
regional_2022 <- c(
  pp            = 43.10,
  psoe          = 24.10,
  vox           = 13.46,
  por_andalucia =  7.68,
  adelante      =  4.58,
  resto         =  7.08
)

# Tema ggplot para proyección: los posts del blog usan base_size 11-12,
# ilegible en pantalla de proyector.
theme_slides <- function(base_size = 18) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title         = ggplot2::element_text(face = "bold", size = ggplot2::rel(1.05)),
      plot.subtitle      = ggplot2::element_text(color = "grey45", size = ggplot2::rel(0.75)),
      panel.grid.minor   = ggplot2::element_blank(),
      axis.ticks         = ggplot2::element_blank()
    )
}

# D'Hondt con barrera del 3%. Corazón del reparto provincial (escanos_a_lo_bayesiano.qmd L400-437).
dhondt <- function(votos, escanos, threshold = 0.03) {
  if (is.null(names(votos))) {
    stop("El vector 'votos' debe tener nombres de partidos.")
  }

  votos <- pmax(votos, 0)
  total_validos <- sum(votos)

  if (total_validos <= 0) {
    return(setNames(rep(0L, length(votos)), names(votos)))
  }

  pasan_umbral <- votos / total_validos >= threshold
  votos_filtrados <- votos
  votos_filtrados[!pasan_umbral] <- 0

  if (sum(votos_filtrados) <= 0) {
    return(setNames(rep(0L, length(votos)), names(votos)))
  }

  resultado <- setNames(integer(length(votos_filtrados)), names(votos_filtrados))

  for (i in seq_len(escanos)) {
    cocientes <- votos_filtrados / (resultado + 1)
    ganador <- which.max(cocientes)
    resultado[ganador] <- resultado[ganador] + 1L
  }

  resultado
}
