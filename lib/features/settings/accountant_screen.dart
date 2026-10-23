import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/accountant_contact.dart';
import '../../theme/tokens.dart';

class AccountantScreen extends ConsumerStatefulWidget {
  const AccountantScreen({super.key});
  @override
  ConsumerState<AccountantScreen> createState() => _AccountantScreenState();
}

class _AccountantScreenState extends ConsumerState<AccountantScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = List.generate(8, (_) => TextEditingController());
  bool _loaded = false, _saving = false, _exists = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = (await ref.read(settingsRepositoryProvider).get()).accountant;
      if (!mounted) return;
      final values = [
        a?.name,
        a?.contact,
        a?.address,
        a?.addressExtra,
        a?.postalCode,
        a?.city,
        a?.phone,
        a?.email,
      ];
      for (var i = 0; i < values.length; i++) {
        _fields[i].text = values[i] ?? '';
      }
      setState(() {
        _loaded = true;
        _exists = a != null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Impossible de lire les coordonnées. Réessayez.',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _save({bool clear = false}) async {
    if (_saving) return;
    final empty = _fields.every((f) => f.text.trim().isEmpty);
    if (!clear && !empty && !_form.currentState!.validate()) return;
    if (clear && !await _confirmClear()) return;
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final current = await repo.get();
      final a = clear || empty
          ? null
          : AccountantContact(
              name: _fields[0].text,
              contact: _fields[1].text,
              address: _fields[2].text,
              addressExtra: _fields[3].text,
              postalCode: _fields[4].text,
              city: _fields[5].text,
              phone: _fields[6].text,
              email: _fields[7].text,
            );
      await repo.save(
        current.copyWith(accountant: a, clearAccountant: a == null),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            a == null
                ? 'Coordonnées du cabinet effacées.'
                : 'Cabinet comptable enregistré.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Enregistrement impossible. Vos coordonnées restent affichées pour réessayer.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmClear() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Effacer les coordonnées ?'),
          content: const Text(
            'Les relevés et sauvegardes déjà exportés ne seront pas modifiés.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Effacer'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Cabinet comptable')),
      body: SafeArea(
        child: !_loaded
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : TextButton(onPressed: _load, child: Text(_error!)),
              )
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  children: [
                    Text(
                      'Pour vos relevés PDF. Ces informations restent sur votre appareil et sont incluses dans vos sauvegardes.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    for (var i = 0; i < _fields.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.m),
                        child: TextFormField(
                          key: Key('accountant-$i'),
                          controller: _fields[i],
                          enabled: !_saving,
                          textCapitalization: i < 6
                              ? TextCapitalization.sentences
                              : TextCapitalization.none,
                          keyboardType: i == 7
                              ? TextInputType.emailAddress
                              : i == 6
                              ? TextInputType.phone
                              : TextInputType.text,
                          textInputAction: i == 7
                              ? TextInputAction.done
                              : TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: const [
                              'Nom du cabinet *',
                              'Interlocuteur',
                              'Adresse',
                              'Complément d’adresse',
                              'Code postal',
                              'Ville',
                              'Téléphone',
                              'Email',
                            ][i],
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (i == 0 && (value ?? '').trim().isEmpty) {
                              return 'Renseignez le nom du cabinet.';
                            }
                            if (i == 7 &&
                                (value ?? '').trim().isNotEmpty &&
                                !AccountantContact.validEmail(value!)) {
                              return 'Vérifiez l’adresse email.';
                            }
                            return null;
                          },
                        ),
                      ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(),
                      icon: const Icon(Icons.check),
                      label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
                    ),
                    if (_exists)
                      TextButton(
                        onPressed: _saving ? null : () => _save(clear: true),
                        child: const Text('Effacer les coordonnées'),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
      ),
    ),
  );
}
