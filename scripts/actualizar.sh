#!/usr/bin/env bash
# Actualiza las slides con encuestas nuevas, con un solo comando.
#
#   scripts/actualizar.sh                    # flujo completo, con publicación
#   scripts/actualizar.sh --sin-publicar     # no hace commit, push ni publicación
#                                            # (ni aquí ni en el blog)
#
# Con publicación, también hace commit y push en blog_quarto de los ficheros
# que cambian durante la ejecución (las encuestas descargadas), para que otro
# equipo parta del mismo estado. Lo que el blog ya tenía sin commit no se toca.
#   scripts/actualizar.sh --sin-descargar    # usa los CSV que ya hay en el blog
#   scripts/actualizar.sh --forzar           # reajusta aunque no haya cambios
#
# Condición previa: blog_quarto y este repo en la misma carpeta.
#
# Fecha de corte: LOREG art. 69.7 prohíbe publicar sondeos del 24 al 28 de
# noviembre. Los datos se congelan el domingo 22 y scripts/publicar.sh deja de
# publicar el lunes 23 por la noche. La decisión legal no la toma este script.
set -euo pipefail

FECHA_CORTE="2026-11-22"

publicar=true
descargar=true
forzar=false
for arg in "$@"; do
  case "$arg" in
    --sin-publicar) publicar=false ;;
    --sin-descargar) descargar=false ;;
    --forzar) forzar=true ;;
    *) echo "Argumento desconocido: $arg" >&2; exit 2 ;;
  esac
done

repo="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
blog="$(dirname "$repo")/blog_quarto"
[[ -d "$blog/2026/10" ]] || { echo "No encuentro $blog" >&2; exit 1; }

hoy="$(date +%F)"
if [[ "$hoy" > "$FECHA_CORTE" ]]; then
  echo "Bloqueado: los datos están congelados desde el $FECHA_CORTE." >&2
  exit 1
fi

rama="$(git -C "$repo" branch --show-current)"
if [[ "$rama" == "andalucia-2026" ]]; then
  echo "Bloqueado: estás en la rama de Andalucía." >&2
  exit 1
fi
if [[ -n "$(git -C "$repo" status --porcelain -- outputs data)" ]]; then
  echo "Bloqueado: outputs/ o data/ tienen cambios sin commit." >&2
  exit 1
fi

paso() { echo "[$(date +%H:%M:%S)] $*"; }

# ficheros del blog con cambios (modificados o nuevos), uno por línea
lista_blog() {
  {
    git -C "$blog" -c core.quotepath=off diff --name-only HEAD
    git -C "$blog" -c core.quotepath=off ls-files --others --exclude-standard
  } | sort -u
}

# confirma y sube en el blog SOLO lo que ha cambiado durante esta ejecución:
# lo que ya tenía cambios antes se queda como estaba. OJO: Netlify publica
# la web en cuanto llega a master un cambio de _site/. Aquí solo se suben las
# encuestas descargadas (nada de _site/), así que la web no cambia.
subir_blog() {
  # while read en vez de mapfile: macOS trae bash 3.2, sin mapfile
  local nuevos=() f
  while IFS= read -r f; do
    [[ -n "$f" ]] && nuevos+=("$f")
  done < <(comm -13 <(echo "$blog_antes") <(lista_blog))
  if [[ ${#nuevos[@]} -eq 0 ]]; then
    paso "Blog: sin cambios que subir"
    return
  fi
  git -C "$blog" add -- "${nuevos[@]}"
  git -C "$blog" commit --quiet -m "Encuestas actualizadas hasta $hoy (scripts/actualizar.sh de bayesian-metaanalisis)"
  git -C "$blog" push --quiet origin "$(git -C "$blog" branch --show-current)"
  paso "Blog: subidos ${#nuevos[@]} ficheros: ${nuevos[*]}"
}

blog_antes="$(lista_blog)"
if [[ -n "$blog_antes" ]]; then
  paso "Aviso: el blog ya tenía cambios sin commit; no se suben:"
  echo "$blog_antes" | sed 's/^/    /'
fi

if $descargar; then
  paso "1/5 Actualiza encuestas en el blog"
  (cd "$blog" && Rscript 2026/10/actualizar_meta.R)
else
  paso "1/5 Descarga omitida"
fi

hay_cambios=false
for f in encuestas_meta_grande_sep.csv encuestas_meta_bloque.csv; do
  cmp -s "$blog/2026/10/$f" "$repo/data/$f" || hay_cambios=true
done
if ! $hay_cambios && ! $forzar; then
  # la descarga puede haber tocado otros ficheros del blog (p. ej. el
  # scrape completo): se suben para que otro equipo parta del mismo estado
  if $publicar; then
    subir_blog
  fi
  paso "Terminado: no hay encuestas nuevas. No se reajusta ni se publica."
  exit 0
fi

previa="$(mktemp)"
cp "$repo/outputs/procedencia.rds" "$previa"

paso "2/5 Ajusta y exporta (unos 4 min)"
(cd "$blog" && SLIDES_REPO="$repo" Rscript "$repo/R/01_exportar_desde_blog.R")

paso "3/5 Construye figuras"
(cd "$repo" && Rscript R/02_figuras.R)

paso "4/5 Comprueba el resultado"
(cd "$repo" && Rscript --vanilla R/04_comprobar.R "$previa")

if ! $publicar; then
  paso "En curso: comprobaciones superadas. Revisa con: quarto preview slides/index.qmd"
  paso "Nada confirmado ni publicado. Para descartar: git restore outputs data"
  exit 0
fi

paso "5/5 Confirma y publica"
subir_blog
cd "$repo"
git add outputs data
git commit --quiet -m "Actualiza las slides con las encuestas hasta $hoy"
git push --quiet origin "$rama"
scripts/publicar.sh
paso "Terminado"
