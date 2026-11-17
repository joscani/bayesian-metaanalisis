#!/usr/bin/env bash
# Publica las slides de generales (extensa y corta) en la subcarpeta generales/
# de la rama gh-pages.
# Solo sustituye generales/: andalucia/ y la portada no se tocan.
#
#   scripts/publicar.sh            # renderiza, copia, confirma y sube
#   scripts/publicar.sh --sin-subir  # hace lo mismo, sin git push
#   scripts/publicar.sh --sin-render # reintenta con el último render
#
# No uses `quarto publish gh-pages`: su código ejecuta `git rm -r .` en la rama.
set -euo pipefail

repo="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
subir=true
renderizar=true
for arg in "$@"; do
  case "$arg" in
    --sin-subir) subir=false ;;
    --sin-render) renderizar=false ;;
    *) echo "Argumento desconocido: $arg" >&2; exit 2 ;;
  esac
done

# sin bloqueo del 24 al 28 de noviembre: ver la cabecera de scripts/actualizar.sh
fecha_hoy="$(date +%F)"

cd "$repo"
# sin restos de renders anteriores: index_files se copia entero a la rama
if $renderizar; then
  rm -rf slides/index_files slides/corta_files
  quarto render slides/index.qmd
  quarto render slides/corta.qmd
fi

worktree="$(mktemp -d)"
trap 'git -C "$repo" worktree remove --force "$worktree"' EXIT
git fetch origin gh-pages
git worktree add --quiet --detach "$worktree" origin/gh-pages

rm -rf "$worktree/generales"
mkdir -p "$worktree/generales"
cp slides/index.html "$worktree/generales/"
cp -R slides/index_files "$worktree/generales/"
# versión corta (15 minutos): generales/corta.html
cp slides/corta.html "$worktree/generales/"
cp -R slides/corta_files "$worktree/generales/"

git -C "$worktree" add generales
if git -C "$worktree" diff --cached --quiet; then
  echo "Sin cambios en generales/."
  exit 0
fi
git -C "$worktree" commit --quiet -m "Publica las slides de generales ($fecha_hoy)"

if $subir; then
  git -C "$worktree" push origin HEAD:gh-pages
  echo "Publicado: https://joscani.github.io/bayesian-metaanalisis/generales/"
  echo "Versión corta: https://joscani.github.io/bayesian-metaanalisis/generales/corta.html"
else
  echo "Commit creado en un worktree temporal y descartado: no se ha subido nada."
fi
