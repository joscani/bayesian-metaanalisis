#!/usr/bin/env bash
# Publica las slides de generales en la subcarpeta generales/ de la rama gh-pages.
# Solo sustituye generales/: andalucia/ y la portada no se tocan.
#
#   scripts/publicar.sh            # renderiza, copia, confirma y sube
#   scripts/publicar.sh --sin-subir  # hace lo mismo, sin git push
#
# No uses `quarto publish gh-pages`: su código ejecuta `git rm -r .` en la rama.
set -euo pipefail

repo="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
subir=true
[[ "${1:-}" == "--sin-subir" ]] && subir=false

fecha_hoy="$(date +%F)"
if [[ "$fecha_hoy" > "2026-11-23" && "$fecha_hoy" < "2026-11-29" ]]; then
  echo "Bloqueado: del 24 al 28 de noviembre Pages no se toca (LOREG art. 69.7)." >&2
  exit 1
fi

cd "$repo"
# sin restos de renders anteriores: index_files se copia entero a la rama
rm -rf slides/index_files
quarto render slides/index.qmd

worktree="$(mktemp -d)"
trap 'git -C "$repo" worktree remove --force "$worktree"' EXIT
git fetch origin gh-pages
git worktree add --quiet --detach "$worktree" origin/gh-pages

rm -rf "$worktree/generales"
mkdir -p "$worktree/generales"
cp slides/index.html "$worktree/generales/"
cp -R slides/index_files "$worktree/generales/"

git -C "$worktree" add generales
if git -C "$worktree" diff --cached --quiet; then
  echo "Sin cambios en generales/."
  exit 0
fi
git -C "$worktree" commit --quiet -m "Publica las slides de generales ($fecha_hoy)"

if $subir; then
  git -C "$worktree" push origin HEAD:gh-pages
  echo "Publicado: https://joscani.github.io/bayesian-metaanalisis/generales/"
else
  echo "Commit creado en un worktree temporal y descartado: no se ha subido nada."
fi
