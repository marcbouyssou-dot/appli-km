#!/usr/bin/env bash
# Mes Km — build web + génération du service worker de précache (UX-008C).
# Usage : tool/build_web.sh [sha_court]   (défaut : dev)
set -euo pipefail
cd "$(dirname "$0")/.."
SHA="${1:-dev}"

flutter build web --no-web-resources-cdn --dart-define=MESKM_GIT_SHA="$SHA"

python3 - "$SHA" <<'PY'
import json, os, sys
sha = sys.argv[1]
root = 'build/web'
entries = ['/']
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if not d.startswith('.')]
    for f in sorted(filenames):
        if f.startswith('.'):
            continue
        rel = os.path.relpath(os.path.join(dirpath, f), root).replace(os.sep, '/')
        if rel in ('sw.js', 'flutter_service_worker.js'):
            continue
        entries.append('/' + rel)
tmpl = open('tool/sw_template.js').read()
out = (tmpl.replace('__BUILD_ID__', sha)
           .replace('__PRECACHE__',
                    json.dumps(sorted(set(entries)), indent=2)))
open(os.path.join(root, 'sw.js'), 'w').write(out)
print(f'sw.js : {len(set(entries))} ressources précachées (build {sha})')
PY
