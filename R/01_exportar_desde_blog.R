# Ajusta los modelos del 29N y exporta a este repo lo que necesitan las slides.
#
# El modelo vive en el blog (blog_quarto/2026/10): este script lo llama, no lo
# copia. Se ejecuta desde la RAÍZ DE blog_quarto, para que se active su renv
# (brms, cmdstanr y tidybayes solo están ahí):
#
#   cd ~/proyectos/blog_quarto
#   Rscript ../bayesian-metaanalisis/R/01_exportar_desde_blog.R
#   Rscript ../bayesian-metaanalisis/R/01_exportar_desde_blog.R --sin-refit
#   Rscript ../bayesian-metaanalisis/R/01_exportar_desde_blog.R --sin-comprobar-tau
#
# --sin-comprobar-tau salta el paso 0, que descarga resultados de Interior.
# Úsalo solo si esa descarga falla (p. ej. HTTP 403, 9 nov 2026). Queda
# anotado en el log y en procedencia.rds.
#
# Los fits se guardan en models/ de este repo. No se escribe nada en el blog.
#
# Diferencia deliberada con el blog: simular_escanos.R:409 predice con
# re_formula = NA. Aquí se usa re_formula = NULL con un epred por casa y media
# entre casas. Ver blog_quarto/2026/11/mrp-multiencuesta/GUIA.md, sección
# "Lección de brms". La sustitución se hace enmascarando add_epred_draws().
#
# Segunda diferencia deliberada: la capa de error histórico. simular_escanos.R
# suma un error normal en puntos, con sigma de 5 generales y una correlación
# PP-VOX de +0,5. Aquí se usa el error de una elección nueva del full bayesian
# (err_new, escala logit, 44 elecciones): draws conjuntos de mu, sigma y Omega.
# La sustitución se hace enmascarando extraer_shares13() (sección 2b).

suppressPackageStartupMessages({
  library(purrr)
  library(dplyr)
  library(tidyr)
  library(tibble)
})

args <- commandArgs(trailingOnly = TRUE)
sin_refit <- "--sin-refit" %in% args
sin_comprobar_tau <- "--sin-comprobar-tau" %in% args
dir_repo <- normalizePath(Sys.getenv("SLIDES_REPO", "../bayesian-metaanalisis"))
stopifnot(
  file.exists(here::here("2026/10/simular_escanos.R")),
  file.exists(file.path(dir_repo, "slides/index.qmd"))
)

ruta_out <- function(...) file.path(dir_repo, "outputs", ...)
ruta_data <- function(...) file.path(dir_repo, "data", ...)
dir.create(file.path(dir_repo, "models"), showWarnings = FALSE)
dir.create(ruta_out(), showWarnings = FALSE)
dir.create(ruta_data(), showWarnings = FALSE)

log_paso <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", sep = "")

source(here::here("2026/10/simular_escanos.R"))

# ---- 0. tau del shock geográfico ----------------------------------------------
# simular() lee tau_shock_draws.csv y tau_regionales.csv del blog. Antes de
# usarlos, compruebo que ajustar_tau_shock.R los reproduce desde los datos
# electorales. Ese script no escribe nada si los ficheros existen y coinciden;
# si alguno falta o difiere, aquí se para.

if (sin_comprobar_tau) {
  log_paso("0. AVISO: --sin-comprobar-tau, uso los tau del blog sin comprobarlos")
} else {
  log_paso("0. ajustar_tau_shock.R: compruebo que los tau del blog se reproducen")
  salida_tau <- suppressWarnings(system2(
    "Rscript",
    here::here("2026/10/ajustar_tau_shock.R"),
    stdout = TRUE,
    stderr = TRUE
  ))
  if (!is.null(attr(salida_tau, "status")) ||
    sum(grepl("^reproducido", salida_tau)) != 5) {
    cat(salida_tau, sep = "\n")
    stop("los tau del blog no se reproducen: revisa 2026/10/ajustar_tau_shock.R")
  }
}

# ---- 1. modelos, en models/ de este repo --------------------------------------

f_mod_g_sep <- file.path(dir_repo, "models", "mod_meta_grande_sep")
f_mod_b <- file.path(dir_repo, "models", "mod_meta_bloque")

cats7 <- c("PP", "PSOE", "VOX", "SUMAR", "PODEMOS", "SALF", "BLOQUE")
if (sin_refit) {
  log_paso("1. refit saltado: uso los fits de models/")
} else {
  log_paso("1a. ajustar_grande_sep(refit = TRUE)")
  invisible(ajustar_grande_sep(refit = TRUE))
  log_paso("1b. ajustar_bloque(refit = TRUE)")
  invisible(ajustar_bloque(refit = TRUE))
}
mod_g <- ajustar_grande_sep()
mod_b <- ajustar_bloque()

# ---- 2. predicción con todos los efectos aleatorios ---------------------------

# re_formula = NULL exige una casa en newdata: una fila por casa observada y
# media entre casas, draw a draw (como mrp-multiencuesta/07_post_celdas.R).
# Devuelve draws × 1 × categorías, la misma forma que con una sola fila.
epred_casa_media <- function(modelo, time_obj, ids) {
  casas <- unique(as.character(modelo$data$encuestadora))
  ep <- posterior_epred(
    modelo,
    newdata = tibble(time = time_obj, n = 1, encuestadora = casas),
    draw_ids = ids
  )
  m <- apply(ep, c(1, 3), mean)
  array(m, c(dim(m)[1], 1, dim(m)[2]), list(NULL, NULL, dimnames(ep)[[3]]))
}

add_epred_original <- tidybayes::add_epred_draws
n_sustituciones <- 0L
add_epred_draws <- function(newdata, object, ndraws = NULL, re_formula = NULL, ...) {
  if (is.null(re_formula) || !"encuestadora" %in% names(object$data)) {
    return(add_epred_original(newdata, object, ndraws = ndraws, re_formula = re_formula, ...))
  }
  n_sustituciones <<- n_sustituciones + 1L
  ids <- sample(brms::ndraws(object), ndraws)
  epred_casa_media(object, newdata$time[1], ids)[, 1, ] |>
    as_tibble() |>
    mutate(.draw = row_number()) |>
    pivot_longer(-.draw, names_to = ".category", values_to = ".epred")
}

# ---- 2b. capa de error del full bayesian ----------------------------------------

# err_new = logit(resultado) - logit(voto latente) de una elección nueva, para
# PP, PSOE, VOX y SUMAR + PODEMOS (grupos_error de full-bayesian/11_datos_conjunto.R).
# Cada draw trae su mu, su sigma y su Omega. El fit no va a git: sus draws se
# copian a data/ para poder repetir la exportación en otro equipo.
f_fit_fb <- here::here("2026/10/full-bayesian/vivo/fit_conjunto.rds")
f_err_fb <- ruta_data("err_new_full_bayesian.csv")
grupos_error_fb <- c("PP", "PSOE", "VOX", "SUMAR")
if (file.exists(f_fit_fb)) {
  err_fb <- posterior::as_draws_matrix(readRDS(f_fit_fb)$draws("err_new"))
  err_fb <- matrix(unclass(err_fb), nrow(err_fb), dimnames = list(NULL, grupos_error_fb))
  readr::write_csv(as_tibble(err_fb), f_err_fb)
  fecha_fit_fb <- file.mtime(f_fit_fb)
} else {
  log_paso("2b. AVISO: no está ", f_fit_fb, "; uso ", f_err_fb)
  err_fb <- as.matrix(readr::read_csv(f_err_fb, show_col_types = FALSE))
  fecha_fit_fb <- NA
}
stopifnot(identical(colnames(err_fb), grupos_error_fb), nrow(err_fb) >= 1000)

# error de la versión del blog, para comparar en las notas
error_pipeline <- list(mu = error_mu, sigma = error_sigma, cor_pp_vox = R_error["PP", "VOX"])

# Misma secuencia que la capa de error de extraer_shares13() (error, shock del
# BLOQUE, reescalado a 100), pero con el error en logit. Se aplica a la salida
# sin error: SUMAR y PODEMOS reciben el error de su suma en proporción a su
# peso, y las 8 subceldas del BLOQUE, el shock del BLOQUE en proporción a su
# peso. Es lo mismo que hace extraer_shares13() antes de repartir.
extraer_shares13_original <- extraer_shares13
n_sustituciones_error <- 0L
extraer_shares13 <- function(n_draws, time_obj, con_error, sigma_bloque,
                             cor_bloque, t_sigma_df, f_antelacion, listas) {
  out <- extraer_shares13_original(
    n_draws, time_obj, FALSE, sigma_bloque, cor_bloque, t_sigma_df,
    f_antelacion, listas
  )
  if (!con_error) {
    return(out)
  }
  stopifnot(listas == "separadas", is.null(t_sigma_df), f_antelacion == 1, cor_bloque == 0)
  n_sustituciones_error <<- n_sustituciones_error + 1L
  e <- err_fb[sample.int(nrow(err_fb), n_draws, replace = TRUE), ]
  g <- cbind(out[, c("PP", "PSOE", "VOX")], SUMAR = out[, "SUMAR"] + out[, "PODEMOS"])
  g_new <- 100 * plogis(qlogis(g / 100) + e)
  b <- rowSums(out[, fams_bloque])
  b_new <- pmax(b + sigma_bloque * rnorm(n_draws), 0)
  res <- out
  res[, c("PP", "PSOE", "VOX")] <- g_new[, c("PP", "PSOE", "VOX")]
  res[, c("SUMAR", "PODEMOS")] <- out[, c("SUMAR", "PODEMOS")] * (g_new[, "SUMAR"] / g[, "SUMAR"])
  res[, fams_bloque] <- out[, fams_bloque] * (b_new / b)
  100 * res / rowSums(res)
}

omega_pp_vox <- readr::read_csv(
  here::here("2026/10/full-bayesian/conjunto_parametros.csv"),
  show_col_types = FALSE
) |>
  filter(parametro == "Omega", partido == "VOX-PP")
stopifnot(nrow(omega_pp_vox) == 1)
log_paso(
  "2b. capa de error: err_new del full bayesian, ", nrow(err_fb), " draws",
  " (fit del ", format(fecha_fit_fb, "%Y-%m-%d %H:%M"), ")"
)

# ---- 3. simulación principal ----------------------------------------------------

log_paso("3. simular(listas = 'mapa')")
set.seed(2911)
sim <- simular(n_draws = 6000, listas = "mapa", provincial = TRUE)
stopifnot(
  n_sustituciones >= 1L,
  n_sustituciones_error >= 1L,
  all(rowSums(sim$draws[, setdiff(names(sim$draws), ".draw")]) == 350)
)
log_paso("   sustituciones del epred: ", n_sustituciones, "; todos los draws suman 350")

saveRDS(sim$draws, ruta_out("escanos_draws.rds"))

# voto nacional por draw, con todas las capas (escenarios_mapa_29N.R:252-261)
validos_p <- ref13 |>
  group_by(codigo_provincia) |>
  summarise(v = sum(votos), .groups = "drop") |>
  slice(match(sim$prov_ref$codigo_provincia, codigo_provincia)) |>
  pull(v)
wv_p <- validos_p / sum(validos_p)
fams <- dimnames(sim$prov_voto)[[3]]
voto_draws <- as_tibble(sapply(fams, \(f) 100 * as.numeric(sim$prov_voto[, , f] %*% wv_p))) |>
  mutate(.draw = row_number(), .before = 1)
saveRDS(voto_draws, ruta_out("voto_draws.rds"))

# voto provincial resumido, con el valor del 23J como referencia
fams_prov <- c("PP", "PSOE", "VOX", "SUMAR", "CC")
prov_resumen <- map_dfr(fams_prov, \(f) {
  m <- sim$prov_voto[, , f] * 100
  tibble(
    partido = f,
    provincia = sim$prov_ref$provincia,
    q05 = apply(m, 2, quantile, 0.05),
    q25 = apply(m, 2, quantile, 0.25),
    q50 = apply(m, 2, quantile, 0.50),
    q75 = apply(m, 2, quantile, 0.75),
    q95 = apply(m, 2, quantile, 0.95)
  )
}) |>
  left_join(
    ref13 |> transmute(provincia, partido, pct_23j = pct_prov),
    by = c("provincia", "partido")
  )
saveRDS(prov_resumen, ruta_out("prov_resumen.rds"))

# escaños por draw en las dos provincias canarias
i_canarias <- match(c("Las Palmas", "Santa Cruz de Tenerife"), sim$prov_ref$provincia)
stopifnot(!anyNA(i_canarias))
escanos_canarias <- map_dfr(i_canarias, \(i) {
  m <- sim$prov_escanos[, i, ]
  as_tibble(m) |>
    mutate(.draw = row_number(), provincia = sim$prov_ref$provincia[i], .before = 1)
})
saveRDS(escanos_canarias, ruta_out("escanos_canarias.rds"))

# ---- 4. posterior del día E, sin capas ------------------------------------------

log_paso("4. posterior del día E y PPC")
ids <- sort(sample(brms::ndraws(mod_g), 4000))
epred_e <- epred_casa_media(mod_g, time_eleccion, ids)[, 1, ] * 100
saveRDS(as_tibble(epred_e), ruta_out("epred_dia_e.rds"))

# ---- 5. encuestas usadas y PPC --------------------------------------------------

dat_g <- prep_grande(f_grande_sep, cats7)
dat_b <- prep_bloque()
stopifnot(nrow(dat_g) == nrow(mod_g$data))

encuestas <- dat_g |>
  transmute(encuestadora, fecha, muestra, n, as_tibble(cell_counts)) |>
  pivot_longer(all_of(cats7), names_to = "partido", values_to = "votos") |>
  mutate(pct = 100 * votos / n)
saveRDS(encuestas, ruta_out("encuestas_modelo.rds"))

pp <- posterior_predict(mod_g, draw_ids = ids[seq(1, length(ids), by = 4)])
ppc <- map_dfr(dimnames(pp)[[3]], \(k) {
  prop <- sweep(pp[, , k, drop = FALSE], 2, dat_g$n, "/")[, , 1]
  tibble(
    partido = k,
    encuestadora = dat_g$encuestadora,
    fecha = dat_g$fecha,
    obs = 100 * dat_g$cell_counts[, k] / dat_g$n,
    q05 = 100 * apply(prop, 2, quantile, 0.05),
    q50 = 100 * apply(prop, 2, quantile, 0.50),
    q95 = 100 * apply(prop, 2, quantile, 0.95)
  )
})
saveRDS(ppc, ruta_out("ppc.rds"))

# ---- 6. diagnósticos y efectos casa ---------------------------------------------

diag_modelo <- function(m) {
  s <- summary(m)
  tabla <- as.data.frame(s$fixed)
  if (!is.null(s$random$encuestadora)) {
    tabla <- rbind(tabla, as.data.frame(s$random$encuestadora))
  }
  np <- nuts_params(m)
  list(
    tabla = tabla |> rownames_to_column("param") |> as_tibble(),
    rhat_max = max(tabla$Rhat),
    ess_min = min(tabla$Bulk_ESS, tabla$Tail_ESS),
    n_divergentes = sum(np$Value[np$Parameter == "divergent__"]),
    n_transiciones = brms::ndraws(m)
  )
}
diagnostico_modelos <- list(grande = diag_modelo(mod_g), bloque = diag_modelo(mod_b))
saveRDS(diagnostico_modelos, ruta_out("diagnosticos.rds"))
log_paso(
  "   modelo 1: Rhat máx ", round(diagnostico_modelos$grande$rhat_max, 3),
  ", ESS mín ", round(diagnostico_modelos$grande$ess_min),
  ", divergentes ", diagnostico_modelos$grande$n_divergentes
)
log_paso(
  "   modelo 2: Rhat máx ", round(diagnostico_modelos$bloque$rhat_max, 3),
  ", ESS mín ", round(diagnostico_modelos$bloque$ess_min),
  ", divergentes ", diagnostico_modelos$bloque$n_divergentes
)

re <- ranef(mod_g)$encuestadora
efectos_casa <- map_dfr(dimnames(re)[[3]], \(p) {
  as.data.frame(re[, , p]) |>
    rownames_to_column("encuestadora") |>
    mutate(param = p)
}) |>
  as_tibble()
saveRDS(efectos_casa, ruta_out("efectos_casa.rds"))

# ---- 7. capas: descomposición de la incertidumbre y candidaturas ----------------

log_paso("7a. descomposición de la incertidumbre")
resumen_derecha <- function(s, nombre) {
  d <- s$draws$PP + s$draws$VOX
  tibble(
    escenario = nombre,
    mediana = median(d),
    ic90_ancho = unname(quantile(d, 0.95) - quantile(d, 0.05)),
    p_mayoria = mean(d >= 176)
  )
}
set.seed(4177)
descomposicion <- bind_rows(
  resumen_derecha(simular(n_draws = 4000, listas = "mapa", con_ruido = FALSE, con_error = FALSE), "Solo posterior"),
  resumen_derecha(simular(n_draws = 4000, listas = "mapa", con_ruido = FALSE, con_error = TRUE), "+ error histórico"),
  resumen_derecha(simular(n_draws = 4000, listas = "mapa", con_ruido = TRUE, con_error = FALSE), "+ shock provincial"),
  resumen_derecha(simular(n_draws = 4000, listas = "mapa", con_ruido = TRUE, con_error = TRUE), "Todas las capas")
)
saveRDS(descomposicion, ruta_out("descomposicion.rds"))

log_paso("7b. candidaturas unidas frente a mapa, con la misma semilla")
mapa_reglas <- readr::read_csv(
  f_mapa_listas,
  col_types = readr::cols(.default = readr::col_character())
)
f_unidas <- tempfile(fileext = ".csv")
readr::write_csv(
  tibble(codigo_provincia = mapa_reglas$codigo_provincia, regla = "unida"),
  f_unidas
)
set.seed(2911)
sim_unidas <- simular(n_draws = 6000, listas = "mapa", f_mapa = f_unidas)
resumen_lista <- function(s, nombre) {
  resumen_escanos(s, width = 0.9) |>
    transmute(escenario = nombre, partido, mediana = escanos, q05 = .lower, q95 = .upper)
}
candidaturas <- list(
  escanos = bind_rows(resumen_lista(sim_unidas, "unidas"), resumen_lista(sim, "mapa")),
  mayorias = bind_rows(
    prob_mayorias(sim_unidas) |> mutate(lista = "unidas"),
    prob_mayorias(sim) |> mutate(lista = "mapa")
  )
)
saveRDS(candidaturas, ruta_out("candidaturas.rds"))

# ---- 8. constantes, datos y procedencia -----------------------------------------

# error en puntos que da err_new aplicado a la mediana del voto del día E
# (sin capas): solo para describirlo en las slides
p_e <- apply(epred_e, 2, median)
p_e <- c(p_e[c("PP", "PSOE", "VOX")], SUMAR = sum(p_e[c("SUMAR", "PODEMOS")])) / 100
err_pp <- 100 * (plogis(sweep(err_fb, 2, qlogis(p_e), "+")) - matrix(p_e, nrow(err_fb), 4, byrow = TRUE))
saveRDS(
  list(
    fuente = "err_new del full bayesian",
    n_draws = nrow(err_fb),
    fecha_fit = fecha_fit_fb,
    mu_pp = colMeans(err_pp),
    sigma_pp = apply(err_pp, 2, sd),
    cor_pp_vox_draws = cor(err_fb[, "PP"], err_fb[, "VOX"]),
    cor_pp_vox = omega_pp_vox$mediana,
    cor_pp_vox_q05 = omega_pp_vox$q05,
    cor_pp_vox_q95 = omega_pp_vox$q95,
    pipeline = error_pipeline,
    sigma_bloque = 1.5
  ),
  ruta_out("capa_error.rds")
)

file.copy(
  here::here(
    "2026/10",
    c(
      "backtest_escanos.csv",
      "backtest_votos.csv",
      "backtest_prov_comparacion.csv",
      "tau_shock_brms.csv",
      "coaliciones_izquierda_29N_provincias.csv",
      "encuestas_meta_grande_sep.csv",
      "encuestas_meta_bloque.csv"
    )
  ),
  ruta_data(),
  overwrite = TRUE
)

# entregas de trackings que quitar_tracking_solapado() deja fuera (ajustar_meta.R).
# 02_figuras.R las quita de las tablas de encuestas, y 04_comprobar.R las suma
# al contar encuestas, para que la regla no parezca una pérdida de datos
tracking_fuera <- function(f, modelo) {
  d <- readr::read_csv(f, show_col_types = FALSE) |>
    distinct(encuestadora, campo, enlace, fecha)
  invisible(capture.output(r <- quitar_tracking_solapado(d)))
  anti_join(d, r, by = c("encuestadora", "campo", "enlace")) |>
    mutate(modelo = modelo, .before = 1)
}
fuera_tracking <- bind_rows(
  tracking_fuera(f_grande_sep, "m1"),
  tracking_fuera(f_bloque, "m2")
)
saveRDS(fuera_tracking, ruta_out("tracking_fuera.rds"))

git_blog <- function(...) system2("git", c("-C", here::here(), ...), stdout = TRUE)
procedencia <- list(
  blog_commit = git_blog("rev-parse", "--short", "HEAD"),
  blog_cambios_2026_10 = git_blog("status", "--short", "--", "2026/10"),
  tau_comprobado = !sin_comprobar_tau,
  tau_md5 = tools::md5sum(here::here(
    "2026/10",
    c("mod_tau_shock.rds", "tau_shock_draws.csv", "tau_regionales.csv")
  )),
  fecha_ejecucion = Sys.time(),
  ultima_encuesta = max(dat_g$fecha),
  primera_encuesta = min(dat_g$fecha),
  n_encuestas_m1 = nrow(dat_g),
  n_casas_m1 = n_distinct(dat_g$encuestadora),
  n_encuestas_m2 = nrow(dat_b),
  n_casas_m2 = n_distinct(dat_b$encuestadora),
  n_tracking_fuera_m1 = sum(fuera_tracking$modelo == "m1"),
  n_tracking_fuera_m2 = sum(fuera_tracking$modelo == "m2"),
  brms = as.character(packageVersion("brms")),
  cmdstan = as.character(cmdstanr::cmdstan_version())
)
saveRDS(procedencia, ruta_out("procedencia.rds"))
log_paso(
  "8. modelo 1: ", procedencia$n_encuestas_m1, " encuestas de ", procedencia$n_casas_m1,
  " casas, última ", format(procedencia$ultima_encuesta), " · blog ", procedencia$blog_commit
)

print(
  resumen_escanos(sim, width = 0.9) |>
    select(partido, escanos, .lower, .upper),
  n = Inf
)
print(prob_mayorias(sim))
log_paso("Terminado")
