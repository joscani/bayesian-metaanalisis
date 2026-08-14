# De la encuesta al escaño

Slides de la comunicación **"De la encuesta al escaño: Un flujo de trabajo
bayesiano en R para la agregación electoral e incertidumbre provincial"**,
presentada en las Jornadas de R de Canarias 2026.

Aplica un modelo multinomial bayesiano (`brms`) para agregar 23 encuestas de
las elecciones al Parlamento de Andalucía de mayo de 2026, y traduce el
posterior regional a una distribución de escaños por provincia con D'Hondt,
propagando tres fuentes de incertidumbre: el modelo de encuestas, el error
histórico de las encuestadoras y el reparto territorial del voto.

Basado en dos posts del blog [Muestrear no es
pecado](https://muestrear-no-es-pecado.es/):

- [Meta-análisis. Agregando encuestas III. Elecciones andaluzas 2026](https://muestrear-no-es-pecado.es/2026/05/meta-analisis-andalucia)
- [¿Mayoría absoluta? Escaños, Bayesian way. Andalucía 2026](https://muestrear-no-es-pecado.es/2026/05/escanos_a_lo_bayesiano)

## Ver las slides

👉 **https://joscani.github.io/bayesian-metaanalisis/**

## Estructura del repo

```
data/       csv de entrada: encuestas, referencia provincial 2022, resultado real 2026
R/          scripts de cómputo (ver abajo)
models/     objetos brms ajustados (no versionados, ver más abajo)
outputs/    resultados intermedios y figuras ya construidas, listos para las slides
slides/     el documento Quarto revealjs y su tema
```

El principio de diseño: **las slides no computan nada**. Los tres scripts de
`R/` generan todos los objetos pesados una sola vez y los guardan en
`outputs/`; `slides/index.qmd` solo hace `readRDS()` y pinta. Por eso el
render de las slides tarda segundos, no minutos, y no depende de tener
`cmdstanr`/Stan instalado el día de la charla.

## Reproducir desde cero

```r
# Dependencias (todas en CRAN salvo cmdstanr):
# tidyverse, brms, cmdstanr, tidybayes, gtools, ggridges, furrr, MASS, here, ggridges

Rscript R/01_modelo_meta.R   # ajusta el meta-análisis brms (~3 min con cmdstanr)
Rscript R/02_escanos.R       # error histórico + Dirichlet + D'Hondt (~1 min)
Rscript R/03_figuras.R       # construye las figuras de las slides (segundos)
```

```bash
quarto render slides/index.qmd   # o: quarto preview slides/index.qmd
```

## Sobre `models/*.rds`

El modelo brms ajustado (`models/mod_meta_andalucia.rds`, ~15 MB) **no está
versionado** en este repo — decisión tomada por simplicidad durante el
desarrollo, no por límite técnico (15 MB cabe de sobra en GitHub). No hace
falta para renderizar las slides ni para publicarlas en Pages, porque todo lo
que necesitan ya está precomputado en `outputs/`. Solo hace falta si quieres
regenerar `outputs/` desde cero: `Rscript R/01_modelo_meta.R`.

## Publicar en GitHub Pages

```bash
quarto publish gh-pages
```

Render local, push a la rama `gh-pages`. No hay build en CI: como las slides
no computan nada, republicar tras un cambio de texto tarda segundos.

## Copia offline (por si falla el wifi)

```bash
cd slides
quarto render index.qmd --to revealjs -M embed-resources:true -o index-offline.html
```

Genera un único HTML autocontenido (~5 MB, todo embebido: imágenes, fuentes,
JS de reveal.js) que funciona abriéndolo directamente en el navegador, sin
red. No se versiona (ver `.gitignore`); regenerar antes de la charla.
