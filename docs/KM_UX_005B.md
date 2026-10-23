# KM-UX-005B — trajets sur plusieurs jours

## Baseline et périmètre

Branche main, HEAD et origin/main `efbf3b834cdfd4d4850ad75c8c7d89f1fa257d97`. Worktree volontairement DIRTY : les sources correspondent exactement à la release qualifiée **ux005a-84a583c87811**, et le diff suivi est identique au diff final 005A conservé. Copie préalable de tous les fichiers modifiés/non suivis et empreintes dans `build/ux005b-qa/precheck/` (ignoré par Git). Aucun reset, stash, checkout, commit ou push.

Le stockage réel est **Sembast**, fourni sur le Web par **IndexedDB / sembast_web**, et non SQLite. Schéma DB v1 et sauvegarde v4 conservés. Aucun nouveau champ de persistance ni migration.

## Nouveau trajet

Aujourd’hui ou une journée du calendrier → Ajouter un trajet → saisie habituelle → **Enregistrer sur plusieurs jours…**. L’ajout simple **Ajouter** conserve sa fonction sur le jour consulté. L’action multi-jours est un bouton texte secondaire de 48 px, épinglé sous l’action principale, utilisable clavier ouvert. Sur petit écran, itinéraire/détails restent accessibles par défilement au-dessus du pied.

La saisie n’est pas fermée pendant la sélection des dates. Retour retrouve distance, aller-retour, départ, destination, motif et véhicule. Annuler le formulaire, revenir du calendrier ou annuler le récapitulatif ne crée aucun trajet. Le jour consulté est présélectionné de façon visible ; il peut être désélectionné, et ne recevra alors rien. Aucune écriture sur le jour initial avant la confirmation multi-jours, aucun favori temporaire créé.

Le congé du jour consulté n’est plus retiré à l’ouverture du formulaire. La confirmation de retrait intervient seulement après validation d’un ajout simple sur ce jour. Pour un lot multi-jours, les congés sont exclus et conservés tels quels, y compris le congé du jour initial.

## Trajet historique

Dans Trajets détaillés, le menu **Actions du trajet** (…) donne **Reporter sur d’autres jours…**. Supprimer reste un bouton direct distinct, sans passage supplémentaire par le menu. Toucher la ligne continue d’ouvrir son édition habituelle. Le même DayView rend ce parcours disponible sur Aujourd’hui et dans le calendrier.

Le calendrier s’ouvre sur le mois du trajet source, sans date présélectionnée. La date source peut être sélectionnée pour constater son exclusion explicite : elle est toujours considérée comme déjà présente, même après choix d’un autre véhicule. Le trajet source reste intact. Chaque copie possède son propre UUID, sa propre CivilDate et une date de création calculée lors de l’application. Modifier/supprimer une copie n’affecte ni la source ni les autres copies. Le modèle Trip n’a pas de note séparée : le champ métier `purpose` (Motif), départ, destination, distance, aller-retour et attribution véhicule sont repris, sans inventer de champs.

## Composants communs

- `TripTemplate` : valeurs métier immuables, sans identité/date ni métadonnées techniques. La distance est déjà le total comptabilisé ; aucun doublement pour l’aller-retour.
- `TripBatchSource` : référence d’un favori, référence d’un trajet enregistré, ou saisie immuable en mémoire.
- **`TripBatchService`** : moteur unique de prévisualisation, détection, revérification et écriture transactionnelle pour les trois parcours. `FavoriteBatchService` est désormais un adaptateur léger vers ce moteur ; il ne contient aucune règle distincte.
- **`TripDaysScreen`** : calendrier, sélection, liste des dates choisies, choix/confirmation véhicule, récapitulatif et application partagés. `FavoriteDaysScreen` reste une entrée de compatibilité qui fournit le favori au même écran.
- Providers et invalidation `dayControllerProvider(date)` / `dayDataVersionProvider` existants : rechargement immédiat des journées, calendrier, statistiques et documents après application.

Les favoris multi-jours restent accessibles depuis Aujourd’hui et Plus → Trajets favoris. L’ajout favori rapide conserve ses règles existantes, y compris deux trajets identiques légitimes sur une même journée.

## Dates, doublons et congés

Sélection multiple sur plusieurs mois, désélection, liste des dates choisies, Retour, annulation et récapitulatif. Seuls aujourd’hui et les jours passés sont autorisés dans l’interface et dans le moteur. Aucune récurrence, planification future, notification, synchronisation ni écriture automatique.

Un doublon probable compare date, véhicule, distance canonisée, aller-retour, départ, destination et motif. Textes comparés après nettoyage de casse/espaces ; IDs et dates techniques ne servent pas à cette comparaison. La date source est exclue même si le véhicule de copie diffère. Les doublons sont signalés et exclus par défaut, sans copie supplémentaire silencieuse. Les congés sont signalés et exclus, sans modification de leurs périodes. Le parcours simple reste disponible lorsqu’un deuxième déplacement identique est légitime.

Le récapitulatif présente les caractéristiques du trajet, véhicule, dates demandées, dates à ajouter, doublons, congés et nombre exact d’ajouts. Il explique l’addition aux données existantes. S’il n’y a aucun ajout possible, le message « Aucun nouveau trajet à ajouter » apparaît, sans action de confirmation. L’annulation conserve la sélection pour la revoir.

## Véhicule et historique

Une saisie multi-jours reprend exactement le véhicule choisi dans le formulaire, y compris aucun véhicule. Une copie propose le véhicule du trajet source, sans le remplacer par le principal actuel. Les jours passés nécessitent une confirmation explicite du véhicule réellement utilisé. Il reste possible de choisir « Sans véhicule renseigné » ; le véhicule n’est jamais rendu obligatoire.

Un véhicule archivé est autorisé uniquement pour les dates antérieures à sa date d’archivage, conformément à la règle 005. Le sélecteur commun propose aussi les véhicules archivés. Si le véhicule source a disparu, un avertissement et une confirmation explicite imposent un choix disponible ou l’absence de véhicule ; le principal actuel n’est pas substitué. Les favoris conservent leur proposition historique : véhicule explicite du favori, sinon principal actuel, avec confirmation pour le passé.

Mes Km ne possède pas l’historique des changements de principal : ce lot ne le déduit pas. Des dates ayant utilisé des véhicules différents doivent être appliquées en lots distincts après choix explicite.

## Transaction, totaux et sauvegarde

La prévisualisation ne fait que lire. Au moment de confirmer, le moteur relit source persistée, véhicule, congés et trajets concernés **dans la même transaction Sembast que toutes les insertions**. Une empreinte du plan est comparée avec le plan approuvé. Changement pertinent, suppression de la source, doublon concurrent ou échec d’écriture : arrêt et rollback complet, puis nouvelle vérification requise. Collision d’UUID détectée avant écrasement d’un trajet ; double confirmation d’un même plan refusée si le lot a déjà été appliqué.

Seul le store `trips` reçoit de nouveaux enregistrements. Source, favoris, véhicules, paramètres, congés et `day_extras` ne sont jamais modifiés. **Total du jour = somme des trajets + extraKm**. Ajouter 70 km à une journée contenant 12 km de trajets et 33 km non détaillés produit 115 km, sans recalculer les 33 km ni perdre note/attribution. Aucun total manuel n’est réinterprété ou écrasé.

Les copies sont des Trip ordinaires pour CSV, PDF, backup et restore. Le test dédié vérifie l’export/restauration complet des IDs, dates et valeurs copiées ; la suite existante couvre aussi les anciennes sauvegardes. Schémas inchangés (DB v1, backup v4).

## Tests et recette restante

Tests ajoutés : 20 cas métier du moteur et 12 cas UI de saisie/report. Ils couvrent annulation/Retour, sélection inter-mois, futur refusé, date initiale désélectionnée, aucun ajout avant confirmation, copie source inchangée, indépendance après édition/suppression, source déjà présente, véhicule historique/absent/disparu, véhicule choisi dans le formulaire, doublons partiels/totaux/concurrents, congés, échec à la seconde insertion, DayExtra et total additif, sauvegarde/restauration. Matrice 320×568 et 430×932, texte agrandi, clavier simulé, défilement et cibles tactiles.

La recette physique Safari/PWA iPhone reste à effectuer : saisie puis Retour, choix des dates et du véhicule historique, confirmation, menu de report, suppression directe d’une copie, refresh et reprise hors ligne. Les profils automatisés sont synthétiques et isolés ; aucune donnée réelle utilisateur n’est supprimée pour mettre à jour la PWA.

## Résultats de qualification et déploiement

- **Analyse : PASS**, aucune anomalie. **502 tests Flutter PASS** (470 + 32 nouveaux), puis vérification ciblée finale des formulaires/congés : 14 PASS. **12 tests Chrome PASS** (10 sans réseau + 2 CORS/calcul réel). PDF synthèse/complet, aperçu, cabinet, splash, favoris, calendrier, statistiques et backup/restore inclus dans les régressions.
- **Build : PASS**, via `tool/build_web.sh ux005b-7800c05616b0`, CanvasKit local, même manifest et même mécanisme de précache (48 entrées). Signature du contenu source et manifeste SHA-256 vérifiés avant transfert et en fin de lot.
- **Release active : ux005b-7800c05616b0**, uniquement **https://staging.meskm.fr**. `meskm-web` HEALTHY, bind de release en lecture seule vérifié, aucun port hôte publié. Ancienne release conservée ; `.env` précédent sauvegardé dans `/srv/apps/meskm/audit/ux005b-7800c05616b0/env.before`. Activation limitée à `docker compose up -d --no-deps --no-build --pull never web`. **Nginx, Compose, réseaux et Traefik inchangés dans 005B** ; seule la release Mes Km sélectionnée est remplacée.
- **Qualification publique : PASS**. 52 vérifications des octets des ressources et des routes, assets, MIME, cache, manifest installable, worker actif, navigation des quatre onglets, refresh et stockage. HTTP permanent vers la même URL HTTPS (GET 301 et HEAD 308 observés), suivi vers HTTPS 200 avec validation TLS. Certificat Let's Encrypt YE2 / staging.meskm.fr, valide jusqu’au 20/01/2027, empreinte identique à 005A.
- **Nouveaux parcours sur HTTPS public : PASS**. Saisie 70 km A/R avec départ/destination/motif, annulation du résumé, Retour au formulaire avec champs conservés, validation uniquement sur 5 et 12 octobre après désélection du jour initial. Depuis le trajet du 5 : sélection 5/12/19 → deux déjà présents exclus → un ajout. Suppression directe de la copie du 19 → source et copie du 12 toujours à 70 km, mois à 140 km après refresh.
- **Hors ligne : PASS**. Cache HTTP vidé, réseau bloqué aussi pour le worker, sonde non cachée réellement en échec. Saisie multi-jours puis report depuis un trajet existant effectués hors ligne, copies et source retrouvées après relance à froid. Porte publique générale : deux démarrages Flutter hors ligne PASS. Les erreurs réseau volontairement provoquées par ces sondes sont distinguées des erreurs applicatives ; aucune erreur réseau en ligne ni exception applicative dans les recettes de validation.
- **PWA update : PASS**. Profil isolé déjà contrôlé par **ux005a-84a583c87811**, 42 km persistés avant activation, nouveau worker en attente, fermeture/réouverture, activation de **ux005b-7800c05616b0**, ancien cache retiré et **42 km conservés**. Aucune suppression IndexedDB ni nettoyage de données réelles.
- **Régressions publiques 005A : PASS**. Favori multi-jours, synthèse PDF exactement 1 page, PDF complet avec navigation page 2, zoom, annulation de l’aperçu sans partage, partage du PDF depuis l’aperçu et aperçu après relance hors ligne. Le mécanisme Web Share est simulé dans le profil de test ; la feuille système iOS reste à la recette physique.
- **MOBSANTE_BEFORE = 9/9 HEALTHY ; MOBSANTE_AFTER = 9/9 HEALTHY**. Les snapshots avant/après/final ont les mêmes IDs, images, StartedAt, RestartCount, Config/HostConfig, ports, montages et réseaux pour les neuf conteneurs. Empreintes des configurations Compose et Traefik identiques. Frontend, gateway, auth, redirections et certificats publics comparés à la référence : inchangés. **MOBSANTE_REGRESSION = NO**.
- **Netlify inchangé**, toujours HTTP 200, aucune action Netlify. Domaines racine et www toujours A 51.91.236.255 / AAAA 2001:41d0:301::29 ; staging toujours A 178.33.206.185 sans AAAA. Aucune action DNS.
- **Git : aucun commit, aucun push**. HEAD et origin/main toujours `efbf3b834cdfd4d4850ad75c8c7d89f1fa257d97`. Worktree DIRTY conservant 005, 005A et 005B ; fichiers 005/005A hors refactorings explicitement nécessaires inchangés bit à bit. Diff vérifié, aucun secret ni artefact QA suivi. Le serveur local de qualification est arrêté.

Preuves ignorées par Git : `build/ux005b-qa/` (précontrôle, diff, manifestes, captures, snapshots OVH, recettes UI locales/publiques, mise à jour, hors ligne et non-régression PDF). Logs Flutter/Chrome : `/private/tmp/meskm-ux005b-*`.

**Verdict : READY_FOR_FINAL_HUMAN_RECIPE**. Recette physique iPhone restante : fermer complètement l’ancienne PWA puis rouvrir, vérifier les trois parcours, le Retour au formulaire, les dates/vehicules historiques, une copie supprimée sans effet sur la source et une relance hors ligne. Aucun essai sur iPhone physique n’est revendiqué par cette qualification automatisée.
