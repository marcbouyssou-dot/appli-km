import 'package:flutter/material.dart';

import '../../app/build_info.dart';
import '../../theme/tokens.dart';
import '../../widgets/section_header.dart';

/// Informations légales (LEGAL-001B/C) — page STATIQUE unique, compilée dans
/// l'application (donc disponible hors ligne par construction), quatre
/// sections. Contact opérationnel : contact@meskm.fr (vérifié humainement,
/// LEGAL-001C). Édition « à titre non professionnel » : régime de
/// l'article 1-1, II de la LCEN (loi 2004-575 modifiée) — ni téléphone ni
/// immatriculation exigés ; l'identité affichée va au-delà du minimum légal.
///
/// RÈGLES CRITIQUES : seule adresse e-mail autorisée : contact@meskm.fr ;
/// jamais de « marque déposée » ni de symbole (R) ; aucune coordonnée
/// inventée (SIRET, téléphone…).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.l,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            text,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        );

    Widget para(String text) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s),
          child: Text(text, style: theme.textTheme.bodyMedium),
        );

    Widget hairline() => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
          child:
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Informations légales')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          children: [
            // ----------------------------------------------------------
            const SectionHeader('MENTIONS LÉGALES', topSpacing: AppSpacing.s),
            heading('Éditeur'),
            para('L’application « Mes Km » est éditée à titre non '
                'professionnel par Marc Bouyssou, personne physique.'),
            para('Adresse :\n'
                'Rue Combe Maurette\n'
                '19700 Seilhac\n'
                'France'),
            para('Directeur de la publication : Marc Bouyssou.'),
            heading('Contact'),
            para('contact@meskm.fr'),
            heading('Hébergement'),
            para('Le site et l’application Mes Km sont actuellement '
                'hébergés par Netlify, Inc., 101 2nd Street, '
                'San Francisco, CA 94105-2239, États-Unis.'),
            para('Site de l’hébergeur : netlify.com'),
            heading('Statut'),
            para('Mes Km est actuellement en phase pilote et mise à '
                'disposition gratuitement.'),
            hairline(),

            // ----------------------------------------------------------
            const SectionHeader('CONFIDENTIALITÉ', topSpacing: 0),
            para('Mes Km est conçu selon un principe « local d’abord ».'),
            heading('Données enregistrées localement'),
            para('Les informations saisies dans l’application sont '
                'enregistrées sur l’appareil de l’utilisateur, dans le '
                'stockage local du navigateur.'),
            para('Cela peut notamment comprendre :\n'
                '• kilomètres et trajets ;\n'
                '• lieux et motifs saisis librement ;\n'
                '• trajets favoris ;\n'
                '• véhicules et leurs caractéristiques ;\n'
                '• périodes de congés ;\n'
                '• informations renseignées dans Réglages pour les '
                'documents.'),
            para('Mes Km ne nécessite aucun compte utilisateur.'),
            para('L’application n’utilise actuellement ni outil de mesure '
                'd’audience ni cookie publicitaire.'),
            heading('Calcul d’itinéraire'),
            para('Le calcul d’itinéraire est facultatif.'),
            para('Uniquement lorsque l’utilisateur demande explicitement '
                '« Calculer la distance », les adresses de départ et de '
                'destination saisies sont transmises aux services '
                'nécessaires au géocodage et au calcul routier, notamment '
                'Nominatim/OpenStreetMap et OSRM.'),
            para('Ces adresses peuvent constituer des données '
                'personnelles.'),
            para('Si l’utilisateur ne souhaite pas transmettre une adresse '
                'à ces services, il peut saisir directement la distance : '
                'le reste de Mes Km demeure utilisable.'),
            heading('Exports et sauvegardes'),
            para('Les fichiers PDF, CSV et .kmbackup sont générés '
                'localement.'),
            para('Ils ne sont transmis à une autre destination que lorsque '
                'l’utilisateur choisit lui-même de les partager ou de les '
                'enregistrer.'),
            heading('Hébergement'),
            para('Le chargement de l’application depuis meskm.netlify.app '
                'implique le traitement par l’hébergeur Netlify de données '
                'techniques nécessaires à la fourniture du service, '
                'notamment l’adresse IP et des journaux techniques.'),
            para('Netlify, Inc. est établie aux États-Unis.'),
            heading('Conservation'),
            para('Les données métier enregistrées par Mes Km restent sur '
                'l’appareil jusqu’à leur modification ou leur suppression '
                'par l’utilisateur, ou jusqu’à la suppression des données '
                'locales du site ou de l’application.'),
            para('Les données techniques éventuellement conservées par les '
                'prestataires tiers relèvent de leurs propres politiques '
                'et durées de conservation.'),
            heading('Maîtrise et suppression'),
            para('L’utilisateur peut modifier ou supprimer ses '
                'informations directement dans Mes Km.'),
            para('La suppression de l’application ou des données de site '
                'peut supprimer les données locales de manière '
                'définitive.'),
            para('Il est recommandé de conserver régulièrement une '
                'sauvegarde récente.'),
            heading('Droits et contact'),
            para('Pour toute question concernant la confidentialité ou '
                'l’exercice de droits applicables : contact@meskm.fr'),
            hairline(),

            // ----------------------------------------------------------
            const SectionHeader('CONDITIONS D’UTILISATION — PHASE PILOTE',
                topSpacing: 0),
            heading('Objet'),
            para('Mes Km est un outil permettant de relever des kilomètres '
                'professionnels, d’organiser les trajets associés et de '
                'produire des documents récapitulatifs.'),
            heading('Phase pilote'),
            para('Mes Km est actuellement proposée gratuitement dans le '
                'cadre d’une phase pilote.'),
            heading('Estimation kilométrique'),
            para('La fonction « Estimation kilométrique » constitue une '
                'simulation indicative fondée sur les références intégrées '
                'dans l’application.'),
            para('Elle ne constitue ni un calcul d’impôt, ni un conseil '
                'fiscal, ni une garantie de déduction.'),
            para('L’utilisateur reste responsable de la vérification de '
                'ses relevés et des informations utilisées pour ses '
                'déclarations.'),
            para('En cas de doute, il lui appartient de consulter '
                'l’administration compétente ou un professionnel.'),
            heading('Données et sauvegardes'),
            para('Les données sont principalement conservées localement '
                'sur l’appareil de l’utilisateur.'),
            para('Il appartient à l’utilisateur de conserver régulièrement '
                'une sauvegarde, notamment avant toute suppression de '
                'l’application ou de ses données.'),
            heading('Disponibilité'),
            para('Pendant la phase pilote, Mes Km peut être corrigée, '
                'modifiée ou interrompue.'),
            para('L’application est fournie en l’état, sous réserve des '
                'garanties et responsabilités qui ne peuvent être exclues '
                'par la loi.'),
            heading('Usage'),
            para('Mes Km doit être utilisée conformément à sa '
                'destination.'),
            para('Toute utilisation abusive des services techniques tiers, '
                'notamment des services d’itinéraire, est interdite.'),
            heading('Responsabilité'),
            para('L’utilisateur demeure responsable des informations qu’il '
                'saisit, des documents qu’il produit et de leur '
                'utilisation.'),
            para('Dans les limites permises par la loi, l’éditeur ne '
                'saurait être tenu responsable des conséquences '
                'd’informations erronées saisies par l’utilisateur ou '
                'd’une perte de données locales qui n’aurait pas fait '
                'l’objet d’une sauvegarde.'),
            heading('Évolution'),
            para('Les présentes conditions peuvent évoluer.'),
            para('La version applicable est celle mise à disposition dans '
                'l’application.'),
            hairline(),

            // ----------------------------------------------------------
            const SectionHeader('PROPRIÉTÉ INTELLECTUELLE', topSpacing: 0),
            para('© 2026 MB — Marc Bouyssou.'),
            para('Les éléments originaux de Mes Km, notamment son '
                'interface, ses textes, son identité visuelle et les '
                'créations graphiques propres à l’application, sont '
                'utilisés sous la responsabilité de leur éditeur et '
                'peuvent être protégés par les droits de propriété '
                'intellectuelle applicables.'),
            para('Aucun dépôt de marque « Mes Km » n’est revendiqué à ce '
                'stade.'),
            para('Mes Km utilise également des composants, bibliothèques, '
                'polices, données et services tiers qui demeurent soumis à '
                'leurs licences et conditions respectives.'),
            para('La police Inter est distribuée sous licence SIL Open '
                'Font License.'),
            para('Le calcul d’itinéraire optionnel s’appuie notamment sur '
                'les services et données de l’écosystème OpenStreetMap et '
                'OSRM.'),
            para('Les données OpenStreetMap sont © les contributeurs '
                'OpenStreetMap et mises à disposition selon la licence '
                'ODbL.'),
            const SizedBox(height: AppSpacing.s),
            // Inventaire standard des licences embarquées (LicenseRegistry
            // Flutter) : aucune base maison à maintenir.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('legal-licenses-button'),
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Mes Km',
                  applicationVersion: versionLine(),
                  applicationLegalese: '© 2026 MB — Marc Bouyssou',
                ),
                child: const Text('Licences des composants'),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
