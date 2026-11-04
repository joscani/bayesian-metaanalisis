# Comprobaciones antes de publicar. Sale con error si alguna falla, y entonces
# scripts/actualizar.sh no confirma ni publica nada.
#
#   Rscript --vanilla R/04_comprobar.R <procedencia.rds anterior>

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1)
previa <- readRDS(args[1])

leer <- function(x) readRDS(file.path("outputs", paste0(x, ".rds")))
proc <- leer("procedencia")
diag <- leer("diagnosticos")
draws <- leer("escanos_draws")
prob <- leer("prob_mayorias")

fallos <- character()
exige <- function(condicion, texto) {
  cat(sprintf("%s %s\n", if (isTRUE(condicion)) "OK   " else "FALLO", texto))
  if (!isTRUE(condicion)) fallos <<- c(fallos, texto)
}

for (m in c("grande", "bloque")) {
  d <- diag[[m]]
  exige(d$rhat_max < 1.01, sprintf("%s: Rhat máximo %.3f < 1,01", m, d$rhat_max))
  exige(d$ess_min > 400, sprintf("%s: ESS mínimo %.0f > 400", m, d$ess_min))
  exige(d$n_divergentes == 0, sprintf("%s: %d divergencias", m, d$n_divergentes))
}

exige(
  all(rowSums(draws[, setdiff(names(draws), ".draw")]) == 350),
  "todos los draws suman 350 escaños"
)
exige(abs(sum(prob$prob) - 1) < 1e-8, "las probabilidades de mayoría suman 1")
exige(
  proc$n_encuestas_m1 >= previa$n_encuestas_m1,
  sprintf("modelo 1: de %d a %d encuestas", previa$n_encuestas_m1, proc$n_encuestas_m1)
)
exige(
  proc$n_encuestas_m2 >= previa$n_encuestas_m2,
  sprintf("modelo 2: de %d a %d encuestas", previa$n_encuestas_m2, proc$n_encuestas_m2)
)
exige(
  proc$ultima_encuesta <= Sys.Date(),
  sprintf("última encuesta %s, no posterior a hoy", format(proc$ultima_encuesta))
)
exige(
  proc$ultima_encuesta >= previa$ultima_encuesta,
  sprintf("última encuesta: de %s a %s", format(previa$ultima_encuesta), format(proc$ultima_encuesta))
)

# figuras reconstruidas después de la exportación
figuras <- list.files("outputs/figuras", pattern = "\\.rds$", full.names = TRUE)
figuras <- setdiff(figuras, "outputs/figuras/fig_heatmap_andalucia.rds")
exige(
  all(file.mtime(figuras) >= file.mtime("outputs/procedencia.rds")),
  "las figuras son posteriores a la exportación"
)

if (length(fallos) > 0) {
  cat(sprintf("\n%d comprobaciones fallidas. No se publica.\n", length(fallos)))
  quit(save = "no", status = 1)
}
cat("\nComprobaciones superadas.\n")
