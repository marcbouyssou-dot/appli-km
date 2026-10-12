#!/usr/bin/env bash
# Mes Km — déploiement de PRODUCTION gardé (UX-008B).
#
# Garde-fous AVANT tout build/deploy :
#   1. branche = main ;
#   2. worktree suivi propre ;
#   3. HEAD = origin/main (après fetch).
# Puis : build Flutter web avec le SHA court injecté
# (--dart-define=MESKM_GIT_SHA) et deploy manuel sur le site Netlify
# EXISTANT `meskm`. Aucun commit, aucun push, aucune config Netlify.
set -euo pipefail

SITE_ID="8dbc5da7-73c2-405e-8fd7-0051538a4ab8"  # meskm.netlify.app
cd "$(dirname "$0")/.."

branch="$(git branch --show-current)"
if [[ "$branch" != "main" ]]; then
  echo "REFUS : branche courante '$branch' (main requis)." >&2
  exit 1
fi

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "REFUS : worktree suivi non propre — committez ou remisez d'abord." >&2
  git status --short --untracked-files=no >&2
  exit 1
fi

git fetch origin main --quiet
head_sha="$(git rev-parse HEAD)"
origin_sha="$(git rev-parse origin/main)"
if [[ "$head_sha" != "$origin_sha" ]]; then
  echo "REFUS : HEAD ($head_sha) != origin/main ($origin_sha) — poussez/rebasez d'abord." >&2
  exit 1
fi

short_sha="$(git rev-parse --short HEAD)"
echo "== Mes Km deploy : main@$short_sha =="

flutter pub get
tool/build_web.sh "$short_sha"

# Porte de régression HORS LIGNE (UX-008D) : le build qui part en
# production doit démarrer sans réseau dans un vrai navigateur.
node tool/offline_gate.mjs

netlify deploy --prod --dir build/web --site "$SITE_ID" \
  --message "main@$short_sha"

echo "== Déployé : main@$short_sha → https://meskm.netlify.app =="
