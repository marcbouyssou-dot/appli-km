# KM-UX-005A — recette humaine, seconde passe

Les modifications KM-UX-005 restent conservées dans le worktree. Aucun commit/push. Le précontrôle a retrouvé exactement la signature source `ux005-bcf60d2e68b3`, HEAD et origin/main `efbf3b834cdfd4d4850ad75c8c7d89f1fa257d97`. Une copie de travail et le diff initial sont gardés dans les preuves ignorées sous `build/ux005a-qa/precheck`.

## Splash conservé

Aucun changement de `web/index.html` dans 005A. Le minimum est **2 100 ms**, mesuré depuis le script inline. Le cycle CSS MesKm.fr dure **2,1 s**, avec trois positions successives. Flutter démarre immédiatement : le retrait se produit à `max(2 100 ms, première frame Flutter)`, sans délai ajouté si cette frame arrive après le minimum. Ce n'est donc pas un délai maximal de chargement : un premier démarrage lent peut durer davantage. En reduced motion : animation désactivée, filigrane sans rotation, minimum **0 ms**, retrait à la première frame. Les invariants numériques sont vérifiés par les tests d'empaquetage.

## Fond et favoris

Même paysage et mêmes opacités de route (7 % clair, 5 % sombre). Feuillages légèrement teintés d'un vert désaturé (6 % / 4,5 %) et une seule petite borne rouge pâle (5,5 % / 4 %). Décor inerte, exclu des annonces, sans animation ni travail au scroll.

Chaque favori présente son nom et sa distance au-dessus des actions. Ajouter immédiatement, calendrier multi-jours, Modifier ont des cibles distinctes. Le calendrier porte « Ajouter à des jours », mesure au moins 48 px, et ouvre directement **FavoriteDaysScreen** avec le même favori. Aucune nouvelle logique de duplication, véhicule, congés, validation ou écriture : le service transactionnel 005 reste partagé. Le titre conserve son tap d'ajout historique ; l'action +km reste explicite. Tests 320 px, échelle 1,5, plusieurs favoris, distance longue, pas d'overflow ; anciens tests Modifier et ajout conservés.

## PDF : choix, aperçu, partage

Documents → Exporter le PDF → choix (Synthèse uniquement par défaut, Synthèse + détail) → Voir le PDF → Aperçu PDF → Partager. Annuler ou Retour n'écrit aucun fichier et n'ouvre aucun partage. Le partage réutilise **BackupFileGateway.saveFile**, avec détection Web Share puis téléchargement de repli. Il est appelé directement depuis le geste sur l'aperçu, sans génération asynchrone préalable pouvant perdre l'activation utilisateur Safari. Les **mêmes octets** sont gardés en mémoire entre aperçu et partage ; les données ne sont pas relues.

La synthèse utilise une seule **pw.Page A4**, sans pagination automatique. Corps 9 pt, notes 8 pt. Les champs de coordonnées sont bornés à 44 caractères Unicode avec ellipse visible ; les libellés de véhicules à 40. Jusqu'à 6 véhicules sont affichés, sinon les 5 premiers et une ligne « Autres véhicules (N) » avec leur somme exacte et une note explicative. Aucun kilomètre n'est écarté. Les 12 mois, total, jours actifs et moyenne proviennent du même relevé dans les deux modes. Le footer est Page 1/1 en synthèse. Les coordonnées complètes restent dans les Réglages. Les tests couvrent 0/1/6/7/25 véhicules, cabinet absent/présent, textes très longs et caractères larges.

Le format complet commence par la même synthèse A4. Les éventuels congés et estimations indicatives disposent d'une section complémentaire paginée, puis vient le détail intégral des trajets. Le détail conserve toutes les colonnes, textes longs en continuations, totaux, headers et footers répétés. CSV, schéma DB et sauvegardes ne changent pas dans 005A.

## Lecteur local et compatibilité

Le projet avait le générateur `pdf` et le partage, sans moteur de rendu PDF. Un iframe PDF natif est insuffisant comme garantie de parcours multipage sur iPhone/PWA. Le lecteur intégré utilise uniquement la couche display + worker **PDF.js 6.4.299 legacy**, ~1,85 Mo avant compression, avec licence Apache-2.0 et intégrité npm SHA-512 vérifiée. Aucun package Flutter supplémentaire, aucun CDN, aucun upload, aucun serveur PDF. Références : [architecture PDF.js](https://mozilla.github.io/pdf.js/getting_started/), [support navigateurs](https://github.com/mozilla/pdf.js/wiki/Frequently-Asked-Questions#faq-support) (legacy Safari 18+, support principalement annoncé, sans test automatisé Safari par Mozilla).

Le lecteur possède précédent/suivant, numéro de page, zoom, défilement et boutons 44 px. Un seul canvas est réutilisé, résolution plafonnée à 8 millions de pixels et DPR 2. Le partage est activé après le premier rendu. Les messages sont filtrés par origine ET fenêtre source, le listener est retiré à la fermeture. Le document reste local. CSP du lecteur restrictive et évaluation JS PDF désactivée.

Tous les fichiers du lecteur entrent dans le précache intégral existant. Le fallback de navigation du worker consulte d'abord la page explicitement précachée avant `/`, afin de charger aussi le lecteur hors ligne. Le fallback Flutter pour les routes applicatives reste présent. Nginx Mes Km déclare le MIME JavaScript de `.mjs` et permet SAMEORIGIN **uniquement** sur `/pdf_preview/index.html`, avec `frame-ancestors 'self'`. Les autres pages conservent DENY. Ces deux adaptations n'affectent aucun composant MobSanté ni Traefik.

La validation Chrome sur dimensions iPhone ne remplace pas une recette physique Safari/PWA iPhone. À confirmer lors de la seconde recette : lecture/zoom, passage à la page 2, Retour, partage système Mail/Fichiers/AirDrop, puis reprise hors ligne.

## Qualification finale

- Release active : **ux005a-84a583c87811**, uniquement https://staging.meskm.fr ; `meskm-web` HEALTHY. Sauvegardes nginx et `.env` dans `/srv/apps/meskm/audit/ux005a-84a583c87811`, ancienne release conservée. Nginx validé avant activation dans un conteneur éphémère sans réseau.
- `flutter analyze` : aucune anomalie. Suite Flutter complète : **470 PASS** (457 avant ce lot), dont sauvegardes/restaurations. Chrome : **10 PASS + 2 réseau PASS**. Build du pipeline existant : PASS, 48 entrées précachées.
- Lecteur réel : synthèse 1 page, détail 2 pages dans le profil public synthétique, précédent/suivant, zoom, annulation sans partage, partage depuis aperçu, ouverture après relance hors ligne : PASS. La suite PDF couvre aussi 180 trajets multipages et l'égalité des totaux des deux formats. Les rendus PDF A4 ont été contrôlés avec Poppler, y compris champs longs et larges, 6/25 véhicules ; marges respectées et footer 1/1.
- Public : HTTP 308 vers HTTPS, chaîne TLS validée, certificat Let's Encrypt YE2 pour staging.meskm.fr jusqu'au 20/01/2027, 52 contrôles de ressources et routes : PASS. En-têtes iframe/MIME, assets, manifest installable, worker, navigation des quatre onglets et refresh : PASS. Aucune erreur réseau en ligne dans les profils de qualification.
- Mise à jour : **ux005-bcf60d2e68b3 → ux005a-84a583c87811**, worker en attente puis activation après fermeture/réouverture, ancien cache retiré, **42 km conservés** dans IndexedDB. Deux démarrages Flutter hors ligne avec cache HTTP vidé et sonde réseau réellement bloquée : PASS. Aperçu PDF également disponible hors ligne. Les échecs réseau explicitement simulés hors ligne ne sont pas des erreurs applicatives.
- Splash public inchangé : minimum 2 100 ms, animation 2,1 s. Durant la qualification à froid : première frame/retrait **3 149,4 / 3 149,6 ms** en clair et **3 673,0 / 3 673,2 ms** en sombre ; aucun délai artificiel ajouté à la frame tardive. Reduced motion : **611,1 / 611,2 ms**, animation none, minimum 0. Ces temps réels dépendent du chargement et de la machine ; ils ne changent pas la durée nominale.
- MobSanté avant/après/après recette : **9/9 HEALTHY**. Identité complète des snapshots de ses neuf conteneurs (IDs, StartedAt, RestartCount, image, Config/HostConfig, ports, montages, réseaux) et des empreintes de ses configurations Compose/Traefik. Frontend, gateway, auth, HTTP/HTTPS et certificats publics identiques à la référence. **MOBSANTE_REGRESSION = NO**.
- DNS staging A 178.33.206.185, aucun AAAA. Apex et www toujours A 51.91.236.255 / AAAA 2001:41d0:301::29. Netlify toujours HTTP 200, aucune action Netlify ni DNS effectuée.
- HEAD et origin/main restent `efbf3b834cdfd4d4850ad75c8c7d89f1fa257d97`. Worktree volontairement DIRTY, diff contrôlé, aucun secret ni artefact QA suivi ; CSV inchangé. **COMMIT NONE, PUSH NONE**.

Preuves reproductibles conservées hors Git dans `build/ux005a-qa/` : snapshots OVH avant/après/final, manifestes SHA-256, journaux de build/recette, contrôles publics, PDF et captures. Logs Flutter/Chrome dans `/private/tmp/meskm-ux005a-*`. Le serveur local de qualification a été arrêté. Les essais navigateur sont réalisés avec des profils Chrome synthétiques et dimensions iPhone/desktop ; **aucune recette sur iPhone physique n'est revendiquée**.

**Verdict : READY_FOR_SECOND_HUMAN_RECIPE**. Pour récupérer le nouveau worker dans une PWA déjà ouverte : fermer complètement Mes Km puis rouvrir. Recette iPhone attendue : fond, raccourci multi-jours, choix du format, aperçu/zoom/page 2, Retour et partage système.
