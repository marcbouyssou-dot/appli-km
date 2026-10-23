import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/build_info.dart';
import '../../app/providers.dart';
import '../../domain/models/app_settings.dart';
import '../../theme/tokens.dart';
import '../../widgets/section_header.dart';
import 'accountant_screen.dart';

/// Réglages minimaux : les informations utilisées par les documents.
/// Champs AppSettings EXISTANTS (aucune extension de modèle, donc aucune
/// migration stockage/backup) ; persistance locale à la saisie.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ref.read(settingsRepositoryProvider).get();
    if (!mounted) return;
    setState(() {
      _nameController.text = settings.displayName ?? '';
      _addressController.text = settings.address ?? '';
      _cityController.text = settings.city ?? '';
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  /// Sauvegarde locale immédiate (un champ vidé redevient « non renseigné »).
  Future<void> _save() async {
    final repo = ref.read(settingsRepositoryProvider);
    final current = await repo.get();
    await repo.save(
      AppSettings(
        displayName: _nameController.text,
        address: _addressController.text,
        city: _cityController.text,
        documentRecipientName: current.documentRecipientName,
        documentRecipientAddress: current.documentRecipientAddress,
        mainVehicleId: current.mainVehicleId,
        themePreference: current.themePreference,
        accountant: current.accountant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.l),
                children: [
                  const SectionHeader(
                    'INFORMATIONS POUR LES DOCUMENTS',
                    topSpacing: 0,
                  ),
                  Text(
                    'Affichées en tête du relevé annuel. Enregistrées '
                    'uniquement sur cet appareil.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => _save(),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nom / structure',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextField(
                    controller: _addressController,
                    onChanged: (_) => _save(),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextField(
                    controller: _cityController,
                    onChanged: (_) => _save(),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Ville',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.business_outlined),
                    title: const Text('Cabinet comptable'),
                    subtitle: const Text('Coordonnées pour vos relevés PDF'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AccountantScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  // Identité de build (UX-008B) : discrète, non interactive.
                  Center(
                    child: Text(
                      versionLine(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
