# KM-UX-005B1 — simplification des actions multi-jours

## Baseline et périmètre

Branche `main`, HEAD et origin/main `efbf3b834cdfd4d4850ad75c8c7d89f1fa257d97`, worktree volontairement DIRTY. Avant intervention, empreinte des sources identique à `ux005b-7800c05616b0` et diff suivi identique au diff final 005B. Copie préalable et empreintes des fichiers modifiés/non suivis dans `build/ux005b1-qa/precheck/` (ignoré). Les lots 005, 005A et 005B sont conservés. Aucun reset, stash, commit ou push.

Ce lot ne modifie que la présentation des actions multi-jours et les tests associés. TripBatchService, son adaptateur favoris, les modèles, providers et règles de stockage restent identiques à 005B. La persistance réelle est Sembast/IndexedDB, pas SQLite : DB v1 et sauvegarde v4 inchangées, aucune migration. Splash, paysage, cabinet comptable, PDF/CSV et sauvegarde/restauration ne sont pas modifiés.

## Nouveau trajet

Dans le formulaire, **Quand effectuer ce trajet ?** précède l'unique action principale **Enregistrer le trajet**. Deux choix de 48 px minimum :

- **Aujourd’hui**, sélectionné par défaut depuis Aujourd’hui ; depuis le calendrier, la date consultée complète est affichée (jour, mois et année).
- **Choisir plusieurs jours…**, qui sélectionne le mode sans écrire ni ouvrir immédiatement le calendrier.

Le bouton principal en mode jour unique conserve l'ajout direct sur la date consultée, sans étape supplémentaire. En mode plusieurs jours, ce même bouton ouvre le calendrier partagé et son récapitulatif de confirmation. Aucune écriture avant confirmation, aucune bascule implicite vers le jour unique lorsqu'aucune date n'est choisie.

Le mode et les champs (distance, A/R, itinéraire, motif, véhicule) restent dans le formulaire pendant la navigation. Retour et annulation ne perdent pas la saisie. L'édition d'un trajet conserve son bouton Enregistrer et son fonctionnement antérieur.

## Placement et petits écrans

FormSheetScaffold conserve son corps défilant et son bouton principal épinglé au-dessus du clavier et de la zone sûre. Le nouveau slot `beforePrimary` place le choix juste avant le bouton, hors de la section facultative Itinéraire et détails. Lorsque la hauteur disponible avec clavier est inférieure à 400 px, le choix défile à la suite des champs pour éviter tout débordement ; le bouton reste épinglé. Les cibles ne sont pas réduites.

## Trajet existant et favoris

Chaque trajet détaillé conserve une ligne principale compacte (distance, A/R, détails, suppression directe), puis **Reporter sur d’autres jours** avec une icône calendrier et un séparateur discret. Le menu à trois points a été supprimé. L'action capture explicitement le trajet de sa ligne ; toucher la ligne principale ouvre toujours son édition.

Dans Aujourd’hui et les journées du calendrier, les favoris proposent **+km**, **Autres jours** avec une icône calendrier, et **Modifier**. Un Wrap permet aux actions de passer sur plusieurs lignes lorsque la largeur ou la taille du texte l'impose. Aucun libellé n'est caché derrière une icône seule. La gestion des favoris et le calendrier partagé reprennent le libellé Autres jours.

## Composants et règles conservés

Les trois parcours réutilisent TripDaysScreen et l'unique TripBatchService : transaction, rollback, anti-doublons, congés exclus, véhicule historique, confirmation des dates passées, extraKm et totaux additifs, indépendance des trajets copiés. Aucun second moteur, aucun champ persistant ajouté, aucune donnée réelle utilisateur modifiée par la recette.

## Vérification et recette humaine

Les tests couvrent le défaut jour unique, la date passée exacte, l'action principale unique, le choix multi-jours sans écriture, l'interdiction de zéro date, le mode et les champs conservés au retour. Les listes de 1, 2, 5 et 10 trajets vérifient chaque source de report et la suppression directe. Matrice 320, 375, 390, 430 px, clavier, défilement, zone sûre et texte agrandi ; favoris avec libellés longs et ajout rapide.

La recette physique Safari/PWA sur iPhone reste à effectuer : visibilité immédiate des choix et du report, clavier/barre Safari, annulation sans perte, sélection de plusieurs dates, favoris, suppression, actualisation et reprise hors ligne. Chrome automatisé ne remplace pas cette validation humaine.

## Qualification réalisée

Release **ux005b1-34e946a09ae6**, déployée uniquement sur **https://staging.meskm.fr/**. Archive SHA-256 `6e66c84623fba626eb1c57fbd242b2f9c3c8d49209c75f6bd116ffe9b896aaab`. Pipeline `tool/build_web.sh` existant, 48 ressources précachées, 50 fichiers de build vérifiés avant activation.

- `flutter analyze` : PASS, aucune anomalie.
- `flutter test` : **512 PASS** (baseline 502 + 10 cas supplémentaires). Les 35 tests ciblés des formulaires, reports et favoris passent également.
- Tests Chrome existants : **12 PASS** (10 sans réseau + 2 avec Nominatim/OSRM).
- Build : PASS. Recettes Chrome locales et publiques : choix explicite, saisie conservée, absence d'écriture avant confirmation, dates initiales désélectionnées, report visible, doublons exclus et suppression indépendante : PASS.
- Responsive : captures examinées, quatre largeurs demandées et modes clair/sombre ; tests clavier, défilement, zone sûre et texte agrandi : PASS.
- HTTPS/TLS : PASS, certificat Let's Encrypt YE2 valide pour staging, inchangé (22 octobre 2026 – 20 janvier 2027). HTTP redirige vers HTTPS (GET 301, HEAD 308).
- **52 contrôles publics** : fichiers de release identiques, MIME, cache, manifest, service worker, viewer PDF local, refresh SPA et ressources absentes : PASS.
- Mise à jour depuis **ux005b-7800c05616b0** : nouveau worker activé, ancien cache retiré, **42 km synthétiques conservés après actualisation**, aucune suppression des données IndexedDB.
- PWA : service worker contrôlant, précache complet, aucune erreur d'installabilité Chrome. Navigation et refresh : PASS. Aucune requête échouée ni exception critique en ligne.
- Hors ligne : réseau réellement bloqué dans la page et le worker, cache HTTP neutralisé, sonde non précachée en échec ; création multi-jours et report confirmés, données persistées après reprise, **deux démarrages à froid Flutter hors ligne** : PASS.
- Régression favoris : ajout rapide et Autres jours, annulation/récapitulatif/confirmation, doublons : PASS. Régression PDF public : synthèse 1 page et complet 2 pages, navigation/zoom, partage des octets PDF préparés et aperçu après redémarrage hors ligne : PASS. CSV, statistiques, congés, véhicules et sauvegarde/restauration couverts par la suite existante.

## Protection de l'exploitation

Seul **meskm-web** a été recréé, puis confirmé **HEALTHY**, sans port hôte publié, avec montage en lecture seule de la nouvelle release. Configuration nginx **inchangée** (`122fcfb2b4c3950c23981ee4e97b727fae9e8cff76271fab1526b26d3083f4ad`). Anciennes releases conservées. Aucun redémarrage global, aucun changement Traefik.

**MobSanté : 9/9 healthy avant et après.** Comparaison exacte des neuf conteneurs : IDs, images, démarrages, compteurs de redémarrage, empreintes Config/HostConfig, ports, montages et réseaux identiques ; configurations Compose/Traefik identiques. Frontend, gateway et auth publics conservent statuts, routes, TLS/certificats et empreintes stables. **MOBSANTE_REGRESSION = NO**.

DNS staging : A `178.33.206.185`, aucun AAAA. Apex et www : A `51.91.236.255`, AAAA `2001:41d0:301::29`, inchangés. Netlify, meskm.fr et www.meskm.fr répondent en HTTPS ; aucune modification ni bascule de domaine, aucun appel de modification Netlify.

Sources métier et lots antérieurs hors périmètre vérifiés identiques à la copie préalable. Diff final contrôlé, recherche de secrets claire. HEAD et origin/main restent `efbf3b834cdfd4d4850ad75c8c7d89f1fa257d97`, worktree DIRTY attendu. **COMMIT: NONE ; PUSH: NONE.**

**VERDICT : READY_FOR_FINAL_HUMAN_RECIPE** — validation physique iPhone Safari/PWA encore attendue.

## Clôture humaine — KM-UX-005-FINAL

Après cette qualification, la recette humaine sur iPhone a confirmé l'affichage kilométrique, le nouveau formulaire, le choix un jour/plusieurs jours, la sélection multiple et l'ajout aux dates choisies avec conservation des kilomètres existants, le calendrier, le report d'un trajet existant et l'ergonomie des actions multi-jours. L'attente de recette indiquée ci-dessus décrit donc l'état à la livraison 005B1 ; cette validation humaine autorise désormais le gel des quatre lots dans un unique commit et son push. Elle ne vaut pas bascule de domaine ni autorisation de redéploiement.
