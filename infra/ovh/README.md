# Mes Km sur OVH — KM-OVH-001

Frontend Flutter statique uniquement. Aucun backend, compte, base, secret ou
volume MobSanté n'est utilisé. Netlify reste disponible sur
`https://meskm.netlify.app` et son script `tool/deploy.sh` reste indépendant.

## Architecture et état de la qualification

```text
Internet :80/:443 → Traefik existant → réseau interne meskm-ingress
                                      └─ meskm-web:8080 (nginx)
```

Le VPS audité est Debian 12 / amd64, Docker 29.9 et Compose 5.6. Traefik 3.7.7
lit `/srv/apps/mobsante/staging/runtime/public/dynamic.yml`. Il n'utilise pas le
provider Docker. Son resolver `public` utilise Let's Encrypt HTTP-01, et sa
configuration TLS impose TLS 1.2 minimum et SNI strict.

Le réseau **dédié, internal:true** contient uniquement nginx et Traefik. Ne pas
raccorder nginx aux réseaux `mobsante-staging_edge`, `application`, `mail`,
`idp-database` ou `public`. Le firewall existant bloque les nouvelles connexions
vers le bridge public ; le réseau edge donne accès à des services privés.
Aucune modification du firewall n'est nécessaire avec le réseau dédié.

Traefik est raccordé à chaud, avec `--gw-priority -1`. Sa passerelle publique
existante reste prioritaire (`1`). Aucun conteneur MobSanté n'est recréé.
Les nouveaux noms Traefik sont `meskm-http`, `meskm-https`, `meskm-static`.
Les règles correspondent seulement à `staging.meskm.fr`.

Le domaine final souhaité reste `meskm.fr` (éventuellement `www.meskm.fr`). Au
22 octobre 2026, ces deux noms pointent sur un autre hébergement OVH Apache :
A `51.91.236.255`, AAAA `2001:41d0:301::29`. Aucun DNS n'a été modifié. Le
sous-domaine staging permet la recette sans basculer ces noms ni Netlify.

**Avant action DNS :** les routes peuvent être qualifiées via un Host Mes Km
avec un SNI MobSanté existant. Le tunnel SSH direct vers l'IP nginx est refusé
par le `PermitOpen` existant (loopback uniquement) : conserver cette restriction.
La recette Chrome du build hébergé utilise un proxy HTTP local de test qui
transmet ce Host via HTTPS, puis est arrêté pour tester le hors ligne.
Cela ne prouve pas un
certificat ni une installation PWA pour `staging.meskm.fr`. Le router HTTPS
initial a `tls: {}` : aucune émission ACME prématurée n'est demandée.
La qualification publique complète reste en attente du DNS, de l'émission du
certificat, puis de la recette navigateur/iPhone sur cette origine.

Qualification réalisée le 22 octobre 2026 : analyse et build release PASS,
429 tests Flutter et 12 tests Chrome PASS (dont CORS/calcul réel Nominatim et
OSRM). Les 43 ressources testées via Traefik correspondent au build local par
SHA-256 ; le refresh SPA, les 404 d'assets et le cache HTTP sont vérifiés.
Le build hébergé démarre dans Chrome via le proxy de test, précache son shell,
puis démarre à froid deux fois après arrêt du proxy. L'installation iPhone et
le HTTPS natif de staging restent à qualifier après le DNS.

Les neuf conteneurs MobSanté sont healthy avant/après, avec mêmes identifiants,
heures de démarrage, compteurs de restart, images, montages, ports et configs.
Seul le raccordement réseau additionnel de Traefik est attendu. HTTPS,
certificats, redirections, frontend, healthchecks gateway, discovery OIDC et
refus des accès privés sont préservés : `MOBSANTE_REGRESSION = NO`.
Le build applicatif déployé est celui de `4ef8c39599da` ; ce lot ne modifie aucun
fichier `lib/` ou `web/`. Le seul ajustement de test attend l'initialisation du
contrôleur, comme le fait l'interface, avant les mutations synthétiques.

## Build et contrôles

Depuis la racine du dépôt :

```sh
flutter pub get
flutter analyze
flutter test --exclude-tags network
tool/build_web.sh "$(git rev-parse --short=12 HEAD)"
node tool/offline_gate.mjs
```

`tool/build_web.sh` réalise le build release Flutter, conserve CanvasKit local
et génère `sw.js` avec le SHA et la liste complète de précache. Un simple
`flutter build web` ne suffit pas à reproduire ce packaging hors ligne.
Ne pas lancer `tool/deploy.sh` pour OVH : il publie sur Netlify.

Le build doit contenir index, bootstrap, main.dart.js, manifest, favicon,
icônes, polices, assets, CanvasKit et sw.js. Les tests `test/web/` s'exécutent
séparément avec `flutter test --platform chrome --exclude-tags network test/web`.
La qualification réseau réelle OSM est volontairement explicite et rare :
`flutter test --platform chrome --tags network test/web/route_network_qualification_test.dart`.

## Implantation et lancement

Racine Mes Km sur VPS : `/srv/apps/meskm`, extérieure au volume MobSanté.

```text
/srv/apps/meskm/
  compose.yml, nginx.conf, traefik_routes.py
  .env                         # MESKM_RELEASE seulement, aucun secret
  releases/<identifiant>/web/   # builds immuables, anciens builds conservés
  audit/<date>/                # sauvegarde, candidat, preuves
```

Transférer un build vérifié dans un **nouveau** répertoire de release, ainsi que
compose.yml et nginx.conf. Ne jamais écraser une release existante. Le conteneur
monte uniquement ces fichiers Mes Km en lecture seule, tourne UID 101, sans
capabilities, sans port publié, avec 128 Mio / 0,25 CPU / 64 processus maximum.
Ses fichiers temporaires vont dans un tmpfs de 32 Mio ; logs bornés. L'image
officielle nginx amd64 est épinglée par digest dans compose.yml.

Après vérification de l'absence de collision des noms et de l'état MobSanté,
sur le VPS (commandes opérateur, droits Docker nécessaires) :

```sh
docker network create --internal --label app=meskm meskm-ingress
docker network connect --gw-priority -1 meskm-ingress mobsante-staging-ingress-1
cd /srv/apps/meskm
# .env contient MESKM_RELEASE=<identifiant du répertoire existant>
docker compose config --quiet
docker compose run --no-deps --name meskm-nginx-config-check web -t -c /etc/meskm/nginx.conf
docker compose up -d --no-deps web
docker inspect meskm-web --format '{{.State.Health.Status}}'
```

La création/raccordement n'est nécessaire qu'une fois ; inspecter l'état avant
de les répéter. Les conteneurs de validation arrêtés sont conservés ; aucun
nettoyage automatique. Ne jamais exécuter un `compose down` global ni de prune.

## Ajout Traefik sans redémarrage

Avant toute application, sauvegarder le fichier courant **sur le Mac, avec une
date**, puis sur le VPS. Ne jamais sauvegarder ACME, clés privées, secrets ou
contenus d'environnement MobSanté dans le dépôt. Les preuves locales de ce lot
se trouvent dans `build/ovh-audit/20261022/` (ignoré par Git).

`traefik_routes.py` utilise PyYAML déjà installé sur le VPS. Il produit un
candidat distinct, vérifie le SHA du baseline, refuse les collisions et prouve
que tous les nœuds MobSanté restent identiques. Les lignes d'origine restent
intactes. Il ne touche jamais au fichier actif.

```sh
python3 traefik_routes.py audit/<date>/dynamic.before.yml \
  audit/<date>/dynamic.candidate.yml --expected-sha256 <sha256-baseline>
```

Valider le candidat dans une instance Traefik isolée (même image, pas de ports
publiés, ACME désactivé vers Internet), vérifier ses routers/services et nginx.
Puis vérifier encore que le fichier actif possède le SHA attendu. Installer le
candidat par remplacement atomique, avec UID/GID et mode du fichier original,
dans le répertoire monté `/public`. Le file provider recharge dynamiquement :
aucun redémarrage de Traefik. Contrôler immédiatement la référence MobSanté
avant/après, dont les identifiants, démarrages, santé, ports, montages,
configurations, routes, HTTPS et certificats.

## Action DNS minimale et activation HTTPS

Créer uniquement `staging.meskm.fr A 178.33.206.185`. Ne pas créer d'AAAA pour ce
sous-domaine : le VPS n'expose pas l'ingress HTTP/HTTPS IPv6. Conserver les DNS
de meskm.fr/www et Netlify. Après propagation, le script vérifie les A/AAAA via
Cloudflare et Google en DNS-over-HTTPS avant de permettre ACME, sans installer
de logiciel sur le VPS :

```sh
# Utiliser le baseline ORIGINAL sans les nœuds Mes Km et un nouveau candidat.
python3 traefik_routes.py audit/<date>/dynamic.before.yml \
  audit/<nouvelle-date>/dynamic.acme.yml \
  --expected-sha256 <sha256-baseline-original> --enable-acme
```

Avant application, vérifier que le candidat conserve **aussi** tout changement
MobSanté intervenu depuis ce baseline. Si le baseline est devenu ancien,
réauditer le fichier courant et préparer un nouveau baseline sans modifier ses
nœuds MobSanté. Pour cette activation, seule la différence
`http.routers.meskm-https.tls.certResolver: public` est attendue par rapport au
fichier actif. Sauvegarder localement ce fichier actif, valider, vérifier le
diff, puis appliquer atomiquement. Ne pas relancer de tentative ACME tant que
les DNS ne sont pas corrects et les ports 80/443 accessibles.

Tester ensuite HTTP→HTTPS, chaîne TLS, frontend, assets, manifest, service
worker, route rechargée, installation PWA, démarrage à froid hors ligne, et
fonctions locales avec un profil neuf et des données synthétiques. Vérifier
Nominatim et OSRM en CORS depuis la nouvelle origine, et refaire la référence
MobSanté. Ne pas déclarer le lot entièrement qualifié avant ces contrôles.

## PWA et données locales

nginx utilise un fallback `/index.html` pour la navigation et des 404 pour les
assets manquants. `Cache-Control: no-cache` permet la revalidation des noms
stables Flutter, y compris index, bootstrap, main.dart.js et sw.js. Le service
worker existant conserve son cache versionné : mise à jour après fermeture
des anciennes fenêtres puis réouverture, sans `skipWaiting` imposé.

Les données IndexedDB sont liées à **l'origine navigateur**. Netlify et staging
Mes Km n'ont donc pas la même base locale. Sauvegarder depuis l'ancienne origine
et restaurer explicitement dans la nouvelle ; vérifier les totaux et exports
avant toute bascule. Ne pas prétendre à une migration automatique des données.
La page légale existante mentionne encore Netlify : son adaptation à OVH reste
à traiter avant la bascule finale, sans changement applicatif dans ce lot.

## Mise à jour et rollback

Reprendre les contrôles, créer une nouvelle release, sauvegarder `.env`, mettre
à jour uniquement `MESKM_RELEASE`, puis `docker compose up -d --no-deps web`
depuis `/srv/apps/meskm`. Vérifier nginx et MobSanté avant/après. Un nouveau
build applicatif doit utiliser un nouvel identifiant SW. Garder les anciennes
releases, images, preuves et sauvegardes ; aucun prune ni suppression.

Rollback applicatif : remettre l'identifiant de la release précédente dans
`.env`, puis recréer uniquement `web`. Fermer/réouvrir la PWA pour que le service
worker de cette release s'active. IndexedDB ne doit pas être supprimé.

Rollback ingress : repartir du fichier courant, retirer **uniquement** les deux
routers et le service Mes Km, prouver l'identité de tous les nœuds MobSanté,
sauvegarder et recharger atomiquement. Ne pas restaurer aveuglément une ancienne
copie qui effacerait des évolutions MobSanté ultérieures. Laisser les fichiers,
réseaux et certificats en place. Netlify reste le recours indépendant conservé.

## Reboot et reproduction

Docker est activé au démarrage. `unless-stopped`, les bind mounts persistants et
le réseau Docker assurent la reprise nginx après reboot ; aucun reboot de test
n'est effectué. Le raccordement réseau de Traefik survit au redémarrage de ce
conteneur existant. **Une recréation de Traefik par le compose MobSanté, qui ne
déclare pas ce réseau, exige de rejouer `docker network connect --gw-priority -1`
vers le nouveau conteneur.** C'est une étape de la procédure d'exploitation,
pas une modification du compose MobSanté. Après toute recréation, vérifier la
passerelle publique prioritaire et les deux applications. Aucun composant Mes Km
ne monte le volume LUKS MobSanté ou son stockage ACME.

Références : [réseaux et priorités Docker](https://docs.docker.com/engine/network/),
[file provider Traefik](https://doc.traefik.io/traefik/reference/install-configuration/providers/others/file/).
