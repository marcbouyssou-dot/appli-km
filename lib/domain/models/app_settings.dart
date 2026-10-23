import 'text.dart';
import 'accountant_contact.dart';

/// Préférence de thème de l'application.
enum ThemePreference { system, light, dark }

/// Réglages et profil utilisateur (singleton logique, modèle volontairement
/// léger : uniquement ce que les documents et l'app utilisent déjà).
class AppSettings {
  AppSettings({
    String? displayName,
    String? address,
    String? city,
    String? documentRecipientName,
    String? documentRecipientAddress,
    String? mainVehicleId,
    this.accountant,
    this.themePreference = ThemePreference.system,
  }) : displayName = cleanText(displayName),
       address = cleanText(address),
       city = cleanText(city),
       documentRecipientName = cleanText(documentRecipientName),
       documentRecipientAddress = cleanText(documentRecipientAddress),
       mainVehicleId = cleanText(mainVehicleId);

  /// Nom ou société, tel qu'il apparaîtra sur les documents.
  final String? displayName;
  final String? address;
  final String? city;

  /// Destinataire des documents (cabinet comptable / centre des impôts).
  final String? documentRecipientName;
  final String? documentRecipientAddress;

  /// Véhicule principal désigné (au plus un, par construction).
  final String? mainVehicleId;

  final ThemePreference themePreference;
  final AccountantContact? accountant;

  AppSettings copyWith({
    String? displayName,
    String? address,
    String? city,
    String? documentRecipientName,
    String? documentRecipientAddress,
    String? mainVehicleId,
    ThemePreference? themePreference,
    AccountantContact? accountant,
    bool clearAccountant = false,
  }) {
    return AppSettings(
      displayName: displayName ?? this.displayName,
      address: address ?? this.address,
      city: city ?? this.city,
      documentRecipientName:
          documentRecipientName ?? this.documentRecipientName,
      documentRecipientAddress:
          documentRecipientAddress ?? this.documentRecipientAddress,
      mainVehicleId: mainVehicleId ?? this.mainVehicleId,
      themePreference: themePreference ?? this.themePreference,
      accountant: clearAccountant ? null : accountant ?? this.accountant,
    );
  }
}
