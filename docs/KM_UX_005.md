# KM-UX-005 — choix de fonctionnement et recette

Les six évolutions conservent le stockage local et le packaging PWA existants.
La recette est limitée à `https://staging.meskm.fr`. Les domaines racine, www,
Netlify et l'infrastructure MobSanté restent hors du périmètre des modifications.

## Données et compatibilité

La base est Sembast, avec IndexedDB sur le Web. Son schéma reste en v1 :
`settings.accountant` est un objet optionnel. Son absence signifie aucun cabinet.
Aucune donnée existante n'est réécrite ou déduite à l'ouverture. Les autres champs
du profil et le véhicule principal sont conservés lors des modifications.

Le format `.kmbackup` passe en v4. Les migrations pures v1/v2/v3 vers v4
conservent les données et laissent le cabinet absent s'il n'existe pas. Le codec
valide les coordonnées avant restauration ; la restauration existante reste
transactionnelle. Une ancienne application refuse une sauvegarde v4 plutôt que
de la restaurer partiellement en perdant le cabinet.

## Favoris sur plusieurs jours

Le tap rapide sur un favori ajoute toujours un trajet au jour consulté. Il
continue à autoriser deux trajets identiques le même jour. Le parcours distinct
`Plus → Trajets favoris → Ajouter à des jours…` applique un favori à une sélection
explicite de jours passés ou du jour courant. Aucune récurrence future n'est créée.

L'aperçu n'écrit rien. La confirmation indique les dates ajoutées, les congés
exclus et les doublons probables exclus. Un doublon correspond à la date, au
véhicule, à la distance, à la métadonnée aller-retour et aux départ/arrivée/motif
(texte comparé sans différence de casse ou d'espacement). Cette comparaison
couvre aussi les anciens trajets sans identifiant de favori d'origine.

L'application ne possède pas l'historique des changements de véhicule principal.
Elle ne peut donc pas inventer celui d'une date passée. Le véhicule explicite du
favori est proposé, sinon le principal actuel, mais l'utilisateur doit confirmer
le véhicule réellement utilisé pour les jours passés. Il peut sélectionner un
ancien véhicule archivé pour des dates antérieures à son archivage, ou choisir
explicitement « Sans véhicule renseigné ». Un véhicule archivé ne peut pas être
appliqué à une date à partir de son archivage. Des groupes de dates correspondant
à des véhicules différents s'ajoutent par opérations distinctes.

La confirmation relit et revérifie l'aperçu dans la même transaction que toutes
les créations. Si les données pertinentes ont changé, elle exige une nouvelle
vérification. Une erreur annule le lot entier. Trips et DayExtra existants,
favoris, véhicules et périodes de congés ne sont jamais modifiés par ce parcours.
Le total journalier reste dérivé, et les vues Riverpod sont rafraîchies après succès.

## Présentation et documents

Le compteur conserve son vrai champ éditable et l'action sur toute sa surface.
Le chiffre et « km » sont sur la même ligne, avec réduction proportionnelle
pour les valeurs longues ; le libellé inférieur est « aujourd’hui » ou « ce jour ».

Le splash HTML est unique : Flutter démarre immédiatement derrière lui. Le logo
existant est conservé, avec filigrane et apparitions douces de MesKm.fr. Le
minimum de présentation est de 2,1 s ; il n'ajoute aucun délai si la première
frame arrive plus tard. Avec reduced motion, l'animation et ce minimum sont retirés.
Le filigrane route garde sa composition, à 0,07 en clair et 0,05 en sombre.

Le PDF A4 possède un design imprimable indépendant du thème de l'application,
avec logo et polices Inter locaux, coordonnées du cabinet si présentes, synthèse,
répartition mensuelle et par véhicule, congés, détail des trajets et DayExtra,
en-têtes répétés et pagination. Les très longs textes ont des continuations sans
perte ; chaque distance apparaît une fois dans le détail. L'estimation existante
est incluse uniquement si le barème officiel de l'année est disponible et les
informations du véhicule suffisantes, avec mention indicative et caractère
partiel explicites. Aucun barème d'une autre année n'est appliqué implicitement.
Le CSV conserve son format et son builder.

## Vérifications et publication

Les tests couvrent transactions/rollback, doublons, congés, attribution passée,
annulation, coordonnées, persistance, sauvegardes anciennes et actuelles,
petits écrans et compteur. Les PDF avec 0, 4 et 90 trajets sont générés et rendus
pour vérifier les caractères français, les marges et toutes les pages.

Utiliser `tool/build_web.sh <identifiant-unique>` : CanvasKit local et `sw.js`
versionné restent indispensables. Chaque release staging utilise un identifiant
de contenu distinct et un nouveau répertoire sous `/srv/apps/meskm/releases/`.
Seul `meskm-web` est recréé. Les configurations et conteneurs MobSanté sont
comparés avant/après, ainsi que leurs endpoints et certificats publics.

La mise à jour PWA suit l'activation normale du service worker après fermeture
des anciennes fenêtres. La recette conserve un profil de test avec des données
synthétiques créé sur la version précédente, détecte le worker en attente,
ferme l'ancien client puis vérifie l'activation du nouveau cache et la conservation
des kilomètres. Une recette séparée bloque le réseau pour vérifier le cold start.
Les preuves et exemples locaux sont sous `build/ux005-qa/`, hors Git.
