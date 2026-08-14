# Slides "De la encuesta al escaño" — Jornadas R Canarias 2026

## Context

Hay que preparar una comunicación de **15 minutos** (con material extra por si son 20)
para las Jornadas de R de Canarias 2026, titulada **"De la encuesta al escaño: Un flujo
de trabajo bayesiano en R para la agregación electoral e incertidumbre provincial"**.

El contenido ya existe repartido en dos posts del blog:

- `~/blog_quarto/2026/05/meta-analisis-andalucia.qmd` — meta-análisis multinomial con `brms`
  (23 encuestas, empresa como efecto aleatorio, tendencia temporal).
- `~/blog_quarto/2026/05/escanos_a_lo_bayesiano.qmd` — traducción del posterior a escaños:
  error histórico multivariante + reparto provincial Dirichlet + D'Hondt por circunscripción.
- (apoyo) `~/blog_quarto/2026/05/como-funciona-sim-escanos.qmd` — desglose didáctico de
  `sim_escanos_draw()` con ejemplo de juguete de 2 provincias / 2 partidos. Muy útil para
  la slide explicativa del reparto provincial.

El repo `~/Proyectos/2026/bayesian-metaanalisis` está prácticamente vacío (solo `README.md`),
así que hay que montarlo desde cero.

**Resultado esperado**: un repo autocontenido y reproducible con las slides en Quarto revealjs,
que rendericen en segundos el día de la charla (sin depender de que Stan compile en el hotel).

### Decisiones tomadas con el usuario

| Decisión | Elección |
|---|---|
| Duración | 15 min de núcleo + slides opcionales marcadas para estirar a 20 |
| Cómputo | **Precomputar** en scripts R → objetos ligeros en `outputs/`; las slides solo cargan y pintan |
| Publicación | Las slides acabarán en **GitHub Pages** (ver Fase 5) |
| Modelo `.rds` | Al `.gitignore` **de momento**; decisión aplazada al final del proyecto (ver "El modelo en git") |
| Cierre | **Sí** incluir validación post-electoral (resultado real 17-M: PP 53, Vox 15) |
| Estilo | Quarto **revealjs + SCSS propio** sobrio, sin extensiones de terceros |
| Código | **Snippets clave** (3-5 bloques cortos); los gráficos son los protagonistas |

---

## Estructura del repo a crear

```
bayesian-metaanalisis/
├── _quarto.yml                # project: default, render solo slides/
├── README.md                  # (ampliar) qué es, cómo reproducir
├── .gitignore                 # models/*.rds grandes, _freeze, .Rproj.user
├── data/
│   ├── encuestas_andalucia_2026.csv     # copiar del blog
│   ├── ref_provincial_2022.csv          # copiar del blog
│   └── resultado_real_2026.csv          # NUEVO (ver "Datos que faltan")
├── R/
│   ├── 00_setup.R             # partidos, paleta, tema ggplot de las slides, helpers
│   ├── 01_modelo_meta.R       # ajuste brms → models/mod_meta_andalucia.rds
│   ├── 02_escanos.R           # error hist + Dirichlet + D'Hondt → outputs/*.rds
│   └── 03_figuras.R           # construye TODAS las figuras → outputs/figuras/*.rds (objetos ggplot)
├── models/                    # .rds de brms (gitignored si pesan)
├── outputs/
│   ├── draws_dia_d.rds        # posterior regional time=0 (tibble ligero)
│   ├── resultados_escanos.rds # 12000 × 6 escaños por partido
│   ├── resumen_*.rds          # tablas ya agregadas para las slides
│   └── figuras/*.rds          # objetos ggplot serializados
└── slides/
    ├── index.qmd              # las slides
    ├── theme-jrc.scss         # tema propio
    └── img/                   # logo jornadas, foto, QR al repo
```

**Regla clave**: `slides/index.qmd` **no ajusta modelos ni simula**. Solo hace
`readRDS()` de `outputs/` y muestra código con `#| eval: false` cuando toca enseñar
la sintaxis. Así el render es de segundos y la charla no depende de cmdstanr.

### El modelo en git

`models/mod_meta_andalucia.rds` pesa ~15 MB. **Decisión: al `.gitignore` durante el
desarrollo, y se revisa al final.** Los argumentos para cuando toque decidir:

- 15 MB **sí cabe** en GitHub (el límite duro es 100 MB por fichero; el aviso, a 50 MB).
  No es un problema técnico, solo hace el clon más pesado y queda para siempre en el
  historial (git no olvida un binario aunque lo borres después).
- **No hace falta para renderizar las slides ni para Pages**: gracias a la regla de arriba,
  el `.qmd` solo lee los objetos ligeros de `outputs/`. Esos **sí** conviene commitearlos
  (son unos pocos MB en total) — son los que hacen que el repo sea "clonar y renderizar".
- Sí hace falta para **regenerar** los `outputs/` desde cero sin re-muestrear, o para la
  slide opcional **O4** (efectos aleatorios por empresa vía `ranef()`), que necesita el
  objeto brms. Si se hace O4, guardar el `ranef()` ya extraído en `outputs/` y así el
  modelo sigue sin ser necesario.
- Si al final se quiere subir: mejor como **release asset** o con **git-lfs** que como
  blob normal en el historial.

Mientras tanto, `.gitignore` con `models/*.rds` y una nota en el README explicando cómo
regenerarlo (`Rscript R/01_modelo_meta.R`, ~pocos minutos con cmdstanr).

---

## Fase 1 — Andamiaje y datos

1. Crear la estructura de directorios y `.gitignore`.
2. Copiar `encuestas_andalucia_2026.csv` y `ref_provincial_2022.csv` del blog a `data/`.
3. `_quarto.yml` mínimo (`project: type: default`, `output-dir: _site` o render directo).
4. `R/00_setup.R` con lo que hoy está duplicado entre los dos posts:
   - `partidos <- c("pp","psoe","vox","por_andalucia","adelante","resto")`
   - `colores` y `colores_esc` (copiar tal cual de los posts: PP `#005999`, PSOE `#FF0126`,
     Vox `#51962A`, Por Andalucía `#E51C55`, Adelante `#8C66F1`, resto gris)
   - `nombres_partido`, `orden_partidos`
   - `regional_2022`, `escanos_prov`, `fecha_elecciones <- ymd("2026-05-17")`
   - `theme_slides()`: `theme_minimal(base_size = 16)` + títulos bold + sin grid menor.
     Base grande porque en proyección el `base_size = 11/12` de los posts es ilegible.

### Datos que faltan

`data/resultado_real_2026.csv` con el resultado real del 17-M por partido (voto % y escaños).
De los posts solo consta **PP 53 / Vox 15**. Hay que completar PSOE-A, Por Andalucía,
Adelante Andalucía y el % de voto de cada uno. **Asunción a validar**: si no se localiza el
dato, la slide de validación se limita al heatmap PP-Vox, que ya funciona por sí sola
(es exactamente la figura final de `escanos_a_lo_bayesiano.qmd`).

## Fase 2 — Scripts de cómputo

### `R/01_modelo_meta.R`
Portar tal cual de `meta-analisis-andalucia.qmd` (líneas 63-258):
lectura del csv → `df_long` con `votos` y `time` → `df_wider` con `cell_counts` →
`brmsformula(cell_counts | trials(n) ~ time + (time | empresa))` con `family = multinomial()`.
- Ajustar el modelo del prior predictive check (`priors_ppc`, `sample_prior = "only"`) y el
  modelo principal (`iter = 4000`, `adapt_delta = 0.95`, `seed = 47`).
- Guardar en `models/`. Alternativa más rápida: copiar `mod_meta_andalucia.rds` y
  `mod_meta_andalucia_prior.rds` del blog, pero **el script debe existir igualmente** para
  que el repo sea reproducible y para poder citarlo en la charla.
- Persistir en `outputs/`: `draws_dia_d.rds` (draws para `time = 0`, empresa nueva),
  `df_long.rds`, `df_wider.rds`, y los datos ya resumidos del PPC (prior y posterior)
  para no arrastrar el objeto brms de 15 MB a las slides.

### `R/02_escanos.R`
Portar de `escanos_a_lo_bayesiano.qmd` (líneas 101-512):
- `error_hist`, `sigma_pp`, `R_corr` → `Sigma_prop`; `MASS::mvrnorm(12000, ...)`, `set.seed(2847)`.
- `draw_adj <- pmax(draws_mat + error_draws, 0)` normalizado por filas.
- `dirichlet_mats` (8 matrices `n_draws × 6`, `n_total = 500`, `set.seed(1234)`).
- Funciones `dhondt(votos, escanos, threshold = 0.03)` y `sim_escanos_draw(k, draw_vec)`
  copiadas literalmente (son el corazón de la charla, no tocarlas).
- `furrr::future_map` sobre los 12000 draws → `outputs/resultados_escanos.rds`.
- Mantener la validación `stopifnot`/`stop()` de que todos los draws suman 109 escaños.
- Guardar tablas agregadas: `P(PP mayoría abs.)`, `P(PP+Vox ≥ 55)`, `P(sin mayoría)`,
  `p_aa_gana`, y `top_joint` (distribución conjunta).

**Nota a incluir como slide de honestidad**: el callout de Virgilio Gómez Rubio del post
(sumar el error en escala logit en vez de aditivamente en proporciones, o meterlo todo en
un único modelo bayesiano). Es una limitación reconocida, no un fallo a ocultar.

### `R/03_figuras.R`
Genera los objetos ggplot y los serializa a `outputs/figuras/*.rds`, todos con
`theme_slides()` y tamaños de fuente para proyección:

| Objeto | Origen | Ajustes para proyección |
|---|---|---|
| `fig_encuestas_tiempo` | meta-análisis L102-112 | puntos más grandes, leyenda abajo |
| `fig_ppc_posterior` | meta-análisis L318-331 | facetas 2×3, sin leyenda |
| `fig_posterior_dia_d` | meta-análisis L369-378 | densidades, etiquetas de % directas |
| `fig_dirichlet_box` | escaños L352-372 | quizá reducir a 3 partidos si va apretado |
| `fig_ridges_escanos` | escaños L614-666 | **la figura estrella**, ya viene etiquetada |
| `fig_mayorias_hist` | escaños L749-776 | histograma coloreado por escenario |
| `fig_heatmap_ppvox` | escaños L969-1014 | con el punto del resultado real |
| `fig_conjunta_bloques` | escaños L865-880 | *opcional* |

Reutilizar el código de anotaciones que ya existe (`ann()`, `xann()`, `resumen_ridge`):
está muy trabajado y no merece reescribirse.

## Fase 3 — Las slides

`slides/index.qmd`, formato `revealjs` con `theme: [default, theme-jrc.scss]`,
`slide-number: c/t`, `incremental: false`, `code-line-numbers` para los snippets,
`echo: false` global (el código que se enseña va con `#| eval: false, echo: true`).

### Guion — núcleo 15 min (~18 slides, ~45 s por slide)

| # | Slide | Contenido |
|---|---|---|
| 1 | Portada | Título, autor, jornadas, QR al repo |
| 2 | El problema | "Las encuestas dan %, el Parlamento reparte escaños". 109 escaños, 8 circunscripciones, D'Hondt |
| 3 | Por qué no basta un número | Un titular de prensa ("el PP rozará la absoluta") vs una distribución |
| 4 | El flujo en una imagen | Diagrama: encuestas → posterior regional → +error histórico → +reparto provincial → D'Hondt → distribución de escaños |
| 5 | Los datos | 23 encuestas, Wikipedia EN, `n` publicado, columna `resto` |
| 6 | Evolución temporal | `fig_encuestas_tiempo` |
| 7 | El modelo | **Snippet 1**: `brmsformula(cell_counts \| trials(n) ~ time + (time \| empresa))` + `multinomial()`. Explicar: multinomial por composición, empresa como efecto aleatorio (= "casa encuestadora"), `time` = tendencia |
| 8 | ¿Funciona? | `fig_ppc_posterior`. Mencionar que `pp_check()` no existe para multinomial y se hace a mano |
| 9 | Posterior día D | `fig_posterior_dia_d` + tabla con IC 90 % |
| 10 | Aquí acaba la mayoría de agregadores | Transición: "…y aquí empieza lo interesante" |
| 11 | Tres fuentes de incertidumbre | [1] modelo, [2] error histórico de las encuestas, [3] reparto provincial |
| 12 | [2] El error histórico | Matriz de correlación: ρ(PP,Vox) = −0.5, ρ(PSOE,PorA) = +0.5. Explicar el trasvase de voto útil |
| 13 | [2] En código | **Snippet 2**: `MASS::mvrnorm(12000, mu = 0, Sigma)` + `pmax(...,0)` + normalización |
| 14 | [3] El reparto provincial | Ratio provincial 2022 + Dirichlet. Ejemplo Almería (Vox saca el doble de su media regional) |
| 15 | [3] Dirichlet en acción | `fig_dirichlet_box` (referencia 2022 en rojo, caja = incertidumbre) |
| 16 | D'Hondt | **Snippet 3**: la función `dhondt()` (10 líneas, con barrera del 3 %) |
| 17 | Resultado: escaños | `fig_ridges_escanos` — **la slide clave**, dejarla respirar |
| 18 | ¿Qué mayoría? | `fig_mayorias_hist` + tabla de probabilidades |
| 19 | Validación 17-M | `fig_heatmap_ppvox` con el punto del resultado real. "No acerté el número; acerté la región de plausibilidad" |
| 20 | Limitaciones + cierre | Callout de Virgilio, hipótesis frágiles, repo/QR, gracias |

(20 slides contando portada y cierre; el ritmo real de las de transición es de ~20 s.)

### Slides opcionales (para estirar a 20 min)

Marcarlas en el `.qmd` con un comentario `<!-- OPCIONAL -->` y `visibility: hidden` si
se decide saltarlas, o simplemente colocarlas como **sub-slides verticales** de revealjs
(bajar solo si sobra tiempo — es la opción más elegante y la recomendada):

- **O1** — Prior predictive check: por qué los priors por defecto de brms en multinomial son
  impropers y hay que sustituirlos por `Normal(0,2)` / `Exponential(1)`.
- **O2** — Diagnósticos: Rhat, ESS, transiciones divergentes = 0.
- **O3** — `sim_escanos_draw()` paso a paso con el ejemplo de juguete de
  `como-funciona-sim-escanos.qmd` (2 provincias, 2 partidos).
- **O4** — Efectos aleatorios por empresa: qué casa encuestadora se desvía y hacia dónde
  (figura nueva a partir de `ranef(model_andalucia)`).
- **O5** — "¿Puede Adelante adelantar a Por Andalucía?": `p_aa_gana` + tabla de combinaciones.
  Buen ejemplo de pregunta que solo se puede responder con la distribución conjunta.
- **O6** — Distribución conjunta por bloques (`fig_conjunta_bloques`).
- **O7** — Coste computacional: `furrr` para 12000 × 8 provincias, cuánto tarda.

### `slides/theme-jrc.scss`

Sobrio y legible en proyector:
- `$body-bg: #fdfdfd`, `$body-color: #1a1a1a`, `$link-color: #005999`.
- `$presentation-font-size-root: 34px` (los `.qmd` de blog usan tamaños muy pequeños).
- Clases de utilidad: `.small-code` (código a 0.7em), `.partido-pp/-psoe/...` con la paleta,
  `.footer` con nombre + jornadas.
- Nada de web fonts externas: usar la pila del sistema para que no falle sin conexión.

## Fase 4 — README

Ampliar `README.md`: de qué va la charla, enlace a los dos posts originales, cómo reproducir
(`Rscript R/01_...` → `02` → `03` → `quarto render slides/index.qmd`), y las dependencias
(`tidyverse`, `brms`, `cmdstanr`, `tidybayes`, `gtools`, `ggridges`, `furrr`, `MASS`).
Todas están ya instaladas en el sistema (verificado); solo faltan `ggtern` y `patchwork`,
que **no** son necesarias con este guion (se descarta el gráfico ternario).

## Fase 5 — Publicación en GitHub Pages

Objetivo: que las slides sean una URL pública (`https://<usuario>.github.io/bayesian-metaanalisis/`)
que se pueda enlazar desde el QR de la portada y desde el blog.

**Enfoque recomendado: `quarto publish gh-pages`** (render local → push a la rama `gh-pages`).

```bash
quarto publish gh-pages
```

Por qué este y no GitHub Actions: el render en CI exigiría instalar R, `brms`, `cmdstanr` y
compilar Stan en el runner, o commitear todos los `outputs/`. Renderizando en local, el CI
sobra por completo y no hay nada que se pueda romper la semana de la charla. Como el `.qmd`
no computa nada, re-publicar tras un cambio de texto son segundos.

Detalles a resolver en esta fase:

1. **Activar Pages apuntando a la rama `gh-pages`**. El remoto ya existe
   (`https://github.com/joscani/bayesian-metaanalisis.git`), así que `quarto publish gh-pages`
   debería funcionar directamente; conviene confirmar en Settings → Pages que la rama y la
   carpeta (`/ (root)`) quedan bien. URL resultante: `https://joscani.github.io/bayesian-metaanalisis/`.
2. **Rutas relativas**: las imágenes de `slides/img/` y cualquier `readRDS("../outputs/...")`
   deben resolverse respecto al `.qmd`. Usar `here::here()` en los chunks para no depender
   del directorio de trabajo del render.
3. **El QR de la portada es circular**: apunta a una URL que aún no existe. Generarlo
   (paquete `qrcode`, ya que estamos en R) **después** del primer publish, o apuntarlo
   directamente al repo de GitHub en vez de a las slides.
4. **Copia offline de respaldo**: además del HTML de Pages, renderizar una versión con
   `embed-resources: true` a un único fichero `.html` autocontenido y llevarlo en el portátil.
   El wifi de las jornadas no es de fiar y con esto las slides funcionan sin red.
   Se puede definir como un segundo formato o un perfil de Quarto para no duplicar el `.qmd`.
5. **`.gitignore`**: ignorar `_site/` y `.quarto/` (el publish gestiona su propia rama);
   ignorar `slides/index_files/` si el render deja artefactos en el árbol de trabajo.

**Orden sugerido**: dejar esta fase para el final, cuando el contenido esté cerrado. Publicar
slides a medias solo genera enlaces rotos y confusión.

---

## Verificación

1. `Rscript R/01_modelo_meta.R` — comprobar que converge: Rhat < 1.01, ESS > 400,
   0 transiciones divergentes (el script debe imprimirlo).
2. `Rscript R/02_escanos.R` — debe imprimir "✓ Los 12000 draws suman exactamente 109 escaños"
   y no lanzar el `stop()`.
3. `Rscript R/03_figuras.R` — comprobar que se crean los 7-8 `.rds` en `outputs/figuras/`.
4. `quarto render slides/index.qmd` — debe tardar **segundos**, no minutos. Si tarda minutos,
   es que hay cómputo colado en el `.qmd`.
5. Abrir el HTML y revisar a tamaño de proyección (zoom del navegador al 150 %) que ningún
   texto de eje o leyenda quede ilegible. Este es el fallo más probable al portar figuras
   pensadas para el blog.
6. Cronometrar un pase en voz alta: si el núcleo pasa de 15 min, mover slides al bloque
   vertical opcional.
7. Tras el publish: abrir la URL de Pages en el móvil (red distinta a la del portátil) y
   comprobar que cargan las imágenes y el tema SCSS, no solo el HTML pelado.
8. Probar la copia `embed-resources` **con el wifi apagado**. Es la única forma de saber
   que no queda ninguna dependencia externa colada.
