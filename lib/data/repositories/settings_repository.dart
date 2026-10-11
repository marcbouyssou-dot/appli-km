import '../../domain/models/app_settings.dart';

/// Accès aux réglages/profil (singleton logique).
abstract interface class SettingsRepository {
  /// Les réglages courants, ou les valeurs par défaut si rien n'est stocké.
  Future<AppSettings> get();

  Future<void> save(AppSettings settings);
}
