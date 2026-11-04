# Plan: slides de las generales del 29N en `bayesian-metaanalisis`

## Contexto

La charla de las Jornadas de R de Canarias es el **25 de noviembre de 2026**, cuatro días antes de las generales.
Las slides actuales tratan de las andaluzas de mayo. Las nuevas aplican el mismo flujo a las generales, con brms.
Las slides de Andalucía se conservan y siguen publicadas.

Decisiones tomadas:

- **Candidaturas:** escenario `mapa`, las coaliciones reales de cada provincia (tu respuesta).
- **Modelos:** `ajustar_grande_sep()` (7 categorías) y `ajustar_bloque()` (8 subceldas), ambos con brms.
- **Estilo del gráfico de escaños:** el ridge de `fig_ridges_escanos` de las slides actuales. Es una suposición mía; corrígela si te referías al `stat_halfeye` del post.
- **Duración:** 15 min de núcleo y slides verticales opcionales, como en el `PLAN.md` actual. También es una suposición.

## Riesgo legal que debes resolver tú

La charla cae dentro del periodo de 24 a 28 de noviembre.
El art. 69.7 de la LOREG prohíbe en esos cinco días publicar, difundir o reproducir sondeos electorales por cualquier medio de comunicación (comprobado en el texto consolidado del BOE).
No sé si una charla técnica o una URL pública entran en esa prohibición. Pregúntalo a la organización o a la Junta Electoral.

Para no depender de esa respuesta, el plan incluye:

- **Último corte de encuestas:** 22 nov, con publicación como tarde el 23 nov. Pages no se toca del 24 al 28 nov.
- **Versión sin estimación:** un parámetro de Quarto (`estimacion_29n: false`) oculta las slides con cifras del 29N. El método y el backtest se mantienen.

## 1. Conservar lo actual

Una rama basta, y el código de Andalucía no cambia.

1. Crea la etiqueta y la rama `andalucia-2026` en `866d2fb`.
2. Sube las dos a `origin`.
3. Trabaja las slides nuevas en una rama `generales-2026`, que se fusiona en `main` al final.

Mover el código a `old/` rompería las rutas `here()` y duplicaría 20 MB de `outputs/` en `main`.

## 2. GitHub Pages con las dos charlas

Pages sirve una sola rama por repo (comprobado: `gh-pages`, carpeta raíz). Por eso dos ramas de código no se pueden publicar por separado, pero dos carpetas dentro de `gh-pages` sí.

```
gh-pages/
├── index.html      # portada con enlaces a las dos charlas
├── andalucia/      # el HTML actual, movido sin renderizar de nuevo
└── generales/      # las slides nuevas
```

| URL | Contenido |
|---|---|
| `joscani.github.io/bayesian-metaanalisis/` | Portada con los dos enlaces |
| `.../andalucia/` | Slides de Andalucía |
| `.../generales/` | Slides de las generales |

- **Rutas:** el HTML publicado no tiene rutas absolutas (comprobado), así que debe funcionar en la subcarpeta.
- **Publicación:** creo `scripts/publicar.sh`, que usa un `git worktree` de `gh-pages` y solo sustituye `generales/`.
- **No uses `quarto publish gh-pages`:** su código ejecuta `git rm -r --quiet .` (`quarto.js:169306`), y deduzco que borraría `andalucia/`. No lo he ejecutado.

## 3. Cómputo

Las slides siguen sin computar nada: solo hacen `readRDS()` y pintan.

El blog sigue siendo la única fuente del modelo. `simular_escanos.R` tiene más de 1.000 líneas, y copiarlo crearía dos versiones justo cuando entran encuestas nuevas. El coste es que el repo de slides depende del blog para regenerar `outputs/`; `outputs/procedencia.rds` registra qué versión del blog se usó.

| Script | Dónde se ejecuta | Qué hace |
|---|---|---|
| `R/01_exportar_desde_blog.R` (nuevo) | Raíz de `blog_quarto`, con su `renv` | Ajusta, simula y exporta a `outputs/` y `data/` |
| `R/02_figuras.R` (adapta `R/03_figuras.R`) | Raíz del repo de slides | Construye `outputs/figuras/*.rds` |
| `R/00_setup.R` (adapta el actual) | Lo carga `R/02_figuras.R` | Paleta de 15 partidos, 176 escaños, `theme_slides()` |

Motivos comprobados:

- `cmdstanr` y `tidybayes` solo están en el `renv` del blog, no en la librería del sistema.
- Las dos librerías tienen `ggplot2` 4.0.3, y la del sistema tiene `ggdist` y `ggridges`.
- Los fits actuales son del 28 oct y los CSV de encuestas, del 3 nov. Hay que reajustar.
- Los `mod_meta_*.rds` del blog están versionados. El script no debe escribir sobre ellos.

`R/01_exportar_desde_blog.R` hace esto:

1. Carga `2026/10/simular_escanos.R`.
2. Redirige `f_mod_g_sep` y `f_mod_b` a `models/` del repo de slides, que está en `.gitignore`.
3. Ejecuta `ajustar_grande_sep(refit = TRUE)` y `ajustar_bloque(refit = TRUE)`.
4. Sustituye en el entorno global la llamada `add_epred_draws(mod_g, re_formula = NA)` de `simular_escanos.R:409` por `re_formula = NULL` con media entre casas (lección de `2026/11/mrp-multiencuesta/GUIA.md:343`). El blog no cambia.
   - Ejecuta `set.seed(2911); simular(n_draws = 6000, listas = "mapa", provincial = TRUE)`, igual que `escenarios_mapa_29N.R`.
5. Exporta los objetos ligeros:
   - escaños por draw y voto nacional por draw, ponderado como en `escenarios_mapa_29N.R:252-261`;
   - resúmenes de mayorías, diagnósticos, PPC por encuesta y efectos casa;
   - `procedencia.rds`: commit del blog, fecha de la última encuesta y número de encuestas.
6. Copia a `data/` los CSV que usan las slides: encuestas, `backtest_escanos.csv`, `backtest_prov_comparacion.csv` y `coaliciones_izquierda_29N_provincias.csv`.

Para actualizar con encuestas nuevas:

1. Ejecuta `Rscript 2026/10/actualizar_meta.R` desde la raíz del blog.
2. Ejecuta `R/01_exportar_desde_blog.R`.
3. Ejecuta `R/02_figuras.R`.
4. Ejecuta `scripts/publicar.sh`.

## 4. Figuras

**Escaños, en dos slides con el estilo actual.** Un solo eje de 0 a 145 aplastaría a los partidos pequeños y solaparía sus etiquetas.

- **Slide A:** PP, PSOE, VOX y Frente Amplio.
- **Slide B:** ERC, EH Bildu, Junts, PNV, AA, BNG, CC, Podemos, UPN y SALF.

Se mantienen las crestas de color, la línea blanca en la media, las cifras de los extremos y la discontinua del 23J. Hay cuatro cambios:

- **Intervalo:** IC 90 % en lugar de IC 80 %, para usar el mismo en toda la charla.
- **Etiqueta:** media redondeada con `escanos_resto_mayor()`, para que la suma dé 350.
- **Referencia 23J:** PP 137, PSOE 121, VOX 33, Sumar 31, ERC 7, Junts 7, EH Bildu 6, PNV 5, BNG 1, CC 1, UPN 1. Sumar incluía a Podemos, y el gráfico debe indicarlo. AA, Podemos y SALF no llevan línea.
- **Datos discretos:** compruebo si `bandwidth = 0.8` crea picos artificiales en los partidos pequeños. Si los crea, uso histograma por entero en la slide B.

**Otras figuras:**

| Figura | Cambio respecto a Andalucía |
|---|---|
| Encuestas en el tiempo | Eje en fecha; línea del día E |
| PPC | Cuantiles ya calculados, sin `tidybayes` |
| Posterior del día E | 7 categorías; `re_formula = NULL` con un epred por casa y media entre casas |
| Mayorías | PP solo, PP + VOX, bloque de investidura y sin mayoría; umbral de 176 |
| Reparto provincial | Sustituye la Dirichlet por el shock con `τ_c` y `τ_p` |
| Backtest (nueva) | Mediana, IC 90 % y resultado real en 5 generales |

## 5. Guion de `slides/index.qmd`

Título y tema se mantienen; una idea por slide. Los textos de Andalucía se reescriben con los datos de generales.

| # | Slide | Contenido |
|---|---|---|
| 1 | Portada | Título, autor, 25 nov 2026, fecha de corte de encuestas |
| 2 | El problema | 350 escaños, 52 circunscripciones, D'Hondt, umbral del 3 % |
| 3 | Por qué no basta un número | Un titular frente a una distribución |
| 4 | El flujo | Encuestas, cascada, error, provincia, mapa, D'Hondt |
| 5 | Los datos | ciento76 y objetivo176; sin CIS ni ElectoPanel en el modelo 1 |
| 6 | Cascada | Muchas encuestas omiten los regionales: dos modelos |
| 7 | Modelo 1 | `cell_counts \| trials(n) ~ time + (1 \| encuestadora)` |
| 8 | Modelo 2 y encaje | Ejemplo de juguete del post, con `BLOQUE × composición` |
| 9 | ¿Funciona? | PPC hecho a mano |
| 10 | Posterior del día E | Densidades y tabla con IC 90 % |
| 11 | Transición | "Aquí acaba la mayoría de agregadores…" |
| 12 | Fuentes de incertidumbre | Modelo, error histórico, provincia, candidaturas |
| 13 | Error histórico | PSOE +0,7 pp; PP–VOX +0,5, frente al −0,5 fijado en Andalucía |
| 14 | Provincia: el fallo | La Dirichlet promete 90 % y cubre 66 % |
| 15 | Provincia: la solución | Efectos de comunidad y provincia con brms; cobertura nueva |
| 16 | Mapa de candidaturas | 33 separadas, 8 con AA, 6 unidas, 4 sin Podemos, 1 sin FA |
| 17 | D'Hondt | Función, umbral y Ceuta y Melilla |
| 18 | Resultado A | Ridge de los cuatro grandes |
| 19 | Resultado B | Ridge del resto |
| 20 | ¿Qué mayoría? | Probabilidad de cada escenario |
| 21 | Backtest | Cobertura en 5 generales |
| 22 | Limitaciones y cierre | Ver abajo |

Las slides 10, 18, 19 y 20 se ocultan con `estimacion_29n: false`. La 13 no lleva estimación, y la 21 es histórica.

**Slide 22:** el modelo estima la media de las encuestadoras, no calibra por casa, usa solo 5 elecciones para el error histórico y hereda el reparto provincial del 23J. AA y la transferencia de Podemos en Cataluña son priors, no encuestas. El aviso de Virgilio Gómez Rubio se mantiene y enlaza al post `full-bayesian`.

**Opcionales verticales:** priors, diagnósticos, efectos casa, descomposición de la incertidumbre, `mapa` frente a `unidas`, heatmap PP–VOX y validación del 17-M, reutilizada de `andalucia-2026`.

## 6. Ficheros

- **Se reescriben:** `slides/index.qmd`, `R/00_setup.R`, `README.md`, `PLAN.md`.
- **Se sustituyen:** `R/03_figuras.R` pasa a `R/02_figuras.R`.
- **Se eliminan de `main`:** `R/01_modelo_meta.R`, `R/02_escanos.R`, los datos y `outputs/` de Andalucía. Quedan en `andalucia-2026`.
- **Se conservan:** `slides/theme-jrc.scss`, `_quarto.yml`, `.gitignore`.
- **Se crean:** `R/01_exportar_desde_blog.R`, `scripts/publicar.sh`, `index.html` de portada.
- **No se modifica nada en** `blog_quarto`, salvo los CSV de encuestas cuando ejecutes su actualización habitual.

## 7. Verificación

1. **Conservación:** `git diff 866d2fb andalucia-2026` queda vacío.
2. **Modelos:** Rhat < 1,01, ESS > 400 y divergencias registradas.
3. **Blog intacto:** `git status -- 2026/10` en el blog no muestra cambios en `mod_meta_*.rds`.
4. **Simulación:** cada draw suma 350 escaños. Los resultados se comparan con `escenarios_29N_*.csv`, y cualquier diferencia debe explicarse por las encuestas nuevas.
5. **Render:** `quarto render slides/index.qmd` tarda segundos y funciona también con `estimacion_29n: false`.
6. **Lectura:** reviso las figuras a tamaño de proyección, sobre todo las etiquetas de la slide 19.
7. **Pages:** tras publicar, abro las tres URL y compruebo imágenes y tema.
8. **Copia offline:** genero el HTML con `embed-resources` y lo pruebo sin wifi.

Tú debes cronometrar un pase en voz alta. Si pasa de 15 min, las slides 14 y 16 son las primeras candidatas a pasar a opcionales.

## 8. Calendario

| Fecha | Hito |
|---|---|
| Esta semana | Ramas, Pages, exportación y figuras con datos actuales |
| Antes del 15 nov | Guion completo y primer pase |
| 22 nov | Último corte de encuestas y reajuste |
| 23 nov | Última publicación y copia offline |
| 24–28 nov | Pages sin cambios |
| 25 nov | Charla |
