#!/usr/bin/env bash
# Actualiza las slides con encuestas nuevas, con un solo comando.
#
#   scripts/actualizar.sh                    # flujo completo, con publicación
#   scripts/actualizar.sh --sin-publicar     # no hace commit, push ni publicación
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
cd "$repo"
git add outputs data
git commit --quiet -m "Actualiza las slides con las encuestas hasta $hoy"
git push --quiet origin "$rama"
scripts/publicar.sh
paso "Terminado"
