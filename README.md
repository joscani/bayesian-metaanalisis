# De la encuesta al escaño

Slides de la comunicación **"De la encuesta al escaño: Un flujo de trabajo
bayesiano en R para la agregación electoral e incertidumbre provincial"**, en
las Jornadas de R de Canarias, el 25 de noviembre de 2026.

Dos modelos multinomiales con `brms` agregan las encuestas de las generales del
29 de noviembre de 2026. La simulación traduce el posterior a escaños, provincia
a provincia. Propaga el error histórico de las encuestas, el cambio del reparto
provincial y las candidaturas registradas en cada provincia.

## Ver las slides

- Portada: <https://joscani.github.io/bayesian-metaanalisis/>
- Generales del 29N: <https://joscani.github.io/bayesian-metaanalisis/generales/>
- Andaluzas de mayo: <https://joscani.github.io/bayesian-metaanalisis/andalucia/>

El código de la versión de Andalucía está en la rama y la etiqueta `andalucia-2026`.

## Estructura

```
data/       CSV copiados del blog: encuestas, backtests y candidaturas
R/          scripts de cómputo y figuras
models/     fits de brms, no versionados
outputs/    resultados y figuras ya construidos
slides/     documento Quarto revealjs, partes opcionales (_*.qmd) y tema
scripts/    publicación en GitHub Pages
```

Las slides no computan nada: solo hacen `readRDS()` y pintan. El modelo no se
copia aquí: `R/01_exportar_desde_blog.R` llama al código de
[`blog_quarto/2026/10`](https://github.com/joscani/blog_quarto/tree/master/2026/10).
`outputs/procedencia.rds` guarda el commit del blog y la fecha de la última encuesta.

Los tau del reparto provincial también vienen del blog. Antes de simular,
`R/01_exportar_desde_blog.R` ejecuta `2026/10/ajustar_tau_shock.R` y se para si
no reproduce los 5 ficheros de tau desde los datos electorales.
`procedencia.rds` guarda el md5 de esos ficheros.

**Dos diferencias con `simular_escanos.R` del blog:**

- **Predicción:** el blog usa `re_formula = NA`. Aquí se usa `re_formula = NULL`,
  con un epred por casa y la media entre casas. El motivo está en
  `2026/11/mrp-multiencuesta/GUIA.md`, sección "Lección de brms".
- **Correlación PP-VOX de la capa de error:** el blog usa +0,5, a partir de las 3
  generales con VOX. Aquí se usa la mediana de `Omega` del post full bayesian
  (`2026/10/full-bayesian/conjunto_parametros.csv`), estimada con 44 elecciones.

## Actualizar con encuestas nuevas

Condición previa: tener `blog_quarto` y este repo en la misma carpeta.

Ejecuta, desde la raíz de este repo:

```bash
scripts/actualizar.sh
```

El script descarga encuestas y sale si no hay nuevas. Si las hay, reajusta y
comprueba convergencia con `R/04_comprobar.R`. Solo publica si todo pasa.
También hace commit y push en `blog_quarto` de los ficheros que cambian durante
la ejecución, como las encuestas descargadas. Lo que el blog ya tenía sin commit
no se toca.
Con `--sin-publicar` no confirma ni publica nada. Los datos se congelan el
22 de noviembre.

Los pasos, por separado:

1. Actualiza los CSV, desde la raíz del blog:

   ```bash
   Rscript 2026/10/actualizar_meta.R
   ```

2. Ajusta y exporta, también desde la raíz del blog para activar su `renv`:

   ```bash
   Rscript ../bayesian-metaanalisis/R/01_exportar_desde_blog.R
   ```

3. Construye las figuras, desde la raíz de este repo:

   ```bash
   Rscript R/02_figuras.R
   ```

4. Publica, desde la raíz de este repo:

   ```bash
   scripts/publicar.sh
   ```

## Publicar en GitHub Pages

Pages sirve la rama `gh-pages`, con una subcarpeta por charla.
`scripts/publicar.sh` solo sustituye `generales/`.

No uses `quarto publish gh-pages`: su código ejecuta `git rm -r .` en esa rama.

## Periodo del 24 al 28 de noviembre

El art. 69.7 de la LOREG prohíbe publicar, difundir o reproducir sondeos
electorales en los cinco días anteriores a la votación. `scripts/publicar.sh` se
niega a publicar en esas fechas.

Esta versión oculta las slides con encuestas o estimaciones del 29N:

```bash
quarto render slides/index.qmd -P estimacion_29n:false
```

## Copia offline

Ejecútalo desde `slides/`. Con otra ruta, las imágenes no se embeben.

```bash
cd slides
quarto render index.qmd --to revealjs -M embed-resources:true -o index-offline.html
```

Genera `slides/index-offline.html`, un único HTML de unos 5,7 MB que funciona sin red. No se versiona.
