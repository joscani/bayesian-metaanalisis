## Constantes y helpers compartidos por R/02_figuras.R y slides/index.qmd.
## Paleta y referencias de blog_quarto/2026/10 (posts de generales y escenario mapa).

library(here)

fecha_elecciones <- as.Date("2026-11-29")
mayoria_absoluta <- 176

# nombre de cada familia en las slides. En el escenario mapa, la familia SUMAR
# es el Frente Amplio
nombres_partido <- c(
  PP = "PP",
  PSOE = "PSOE",
  VOX = "VOX",
  SUMAR = "Frente Amplio",
  PODEMOS = "Podemos",
  AA = "Adelante A.",
  SALF = "SALF",
  ERC = "ERC",
  Junts = "Junts",
  `EH Bildu` = "EH Bildu",
  PNV = "PNV",
  BNG = "BNG",
  CC = "CC",
  UPN = "UPN"
)

colores_esc <- c(
  "PP" = "#005999",
  "PSOE" = "#FF0126",
  "VOX" = "#51962A",
  "Frente Amplio" = "#A00B85",
  "Podemos" = "#6F2C91",
  "Adelante A." = "#8C66F1",
  "SALF" = "#00C3B6",
  "ERC" = "#F5A21D",
  "Junts" = "#00C2B4",
  "EH Bildu" = "#00A56D",
  "PNV" = "#008141",
  "BNG" = "#7F9CC4",
  "CC" = "#D44A20",
  "UPN" = "#1B4A9B",
  "Bloque" = "grey50"
)

# escaños oficiales del 23J (blog: meta-analisis-generales-escanos-jlcr.qmd:744).
# Sumar incluía a Podemos. Adelante A., Podemos y SALF no tienen referencia
escanos_23j <- c(
  "PP" = 137,
  "PSOE" = 121,
  "VOX" = 33,
  "Frente Amplio" = 31,
  "ERC" = 7,
  "Junts" = 7,
  "EH Bildu" = 6,
  "PNV" = 5,
  "BNG" = 1,
  "CC" = 1,
  "UPN" = 1
)

col_mayoria <- c(
  "Investidura" = "#cc3333",
  "Sin mayoría" = "#aaaaaa",
  "PP + VOX" = "#7ab8d9",
  "PP solo" = "#005999"
)

# Tema ggplot para proyección: los posts del blog usan base_size 11-12,
# ilegible en pantalla de proyector.
theme_slides <- function(base_size = 18) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = ggplot2::rel(1.05)),
      plot.subtitle = ggplot2::element_text(color = "grey45", size = ggplot2::rel(0.75)),
      panel.grid.minor = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank()
    )
}

# media de escaños por partido, redondeada por resto mayor para que sume 350
# (misma regla que escanos_resto_mayor() de simular_escanos.R)
medias_resto_mayor <- function(draws) {
  m <- as.matrix(draws[, setdiff(names(draws), ".draw")])
  medias <- colMeans(m)
  base <- floor(medias)
  faltan <- round(sum(medias)) - sum(base)
  extra <- rank(-(medias - base), ties.method = "first") <= faltan
  tibble::tibble(
    familia = names(medias),
    media = unname(medias),
    etiqueta = unname(base + extra)
  )
}

num_es <- function(x, d = 1) {
  format(round(x, d), decimal.mark = ",", big.mark = ".", nsmall = d, trim = TRUE)
}
pct_es <- function(p, d = 1) paste0(num_es(100 * p, d), " %")

# tabla interactiva de encuestas para las slides. La columna Encuesta ya trae
# el enlace en HTML, por eso escape = FALSE
tabla_encuestas <- function(d) {
  DT::datatable(
    d,
    escape = FALSE,
    rownames = FALSE,
    class = "compact stripe",
    options = list(
      pageLength = 6,
      lengthChange = FALSE,
      scrollX = TRUE,
      language = list(
        search = "Buscar:",
        info = "_START_-_END_ de _TOTAL_",
        infoFiltered = "(de _MAX_)",
        zeroRecords = "Sin resultados",
        paginate = list(previous = "Anterior", `next` = "Siguiente")
      )
    )
  )
}
