import 'text.dart';

/// Catégories de véhicules reconnues en V2 (alignées sur les futures
/// familles de barèmes fiscaux).
enum VehicleCategory { car, twoWheeler }

/// Motorisation (KM-013) : distingue uniquement ce que le barème fiscal
/// distingue. [unspecified] est l'état par défaut — on ne suppose JAMAIS
/// qu'un véhicule existant est thermique.
enum Motorization { electric, other, unspecified }

/// Classe fiscale d'un deux-roues (KM-013) : le barème « moto » (> 50 cm³)
/// et le barème « cyclomoteur » (≤ 50 cm³) sont distincts — null tant que
/// l'utilisateur n'a pas précisé, et alors aucune estimation.
enum TwoWheelerFiscalClass { motorcycle, moped }

/// Un véhicule de l'utilisateur.
///
/// Le véhicule principal n'est PAS un drapeau ici : il est désigné par
/// `AppSettings.mainVehicleId`, ce qui garantit qu'il y en a au plus un.
///
/// Un véhicule s'archive ([archivedAt]) au lieu d'être supprimé, afin que les
/// trajets historiques qui le référencent restent valides.
class Vehicle {
  Vehicle({
    required this.id,
    required String name,
    required this.category,
    this.fiscalPowerCv,
    String? registration,
    this.motorization = Motorization.unspecified,
    this.twoWheelerClass,
    this.archivedAt,
  })  : name = name.trim(),
        registration = cleanText(registration) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Vehicle.id ne doit pas être vide.');
    }
    if (this.name.isEmpty) {
      throw ArgumentError('Vehicle.name ne doit pas être vide.');
    }
    final cv = fiscalPowerCv;
    if (cv != null && cv <= 0) {
      throw ArgumentError(
        'Vehicle.fiscalPowerCv doit être > 0 lorsqu’il est renseigné '
        '(reçu : $cv).',
      );
    }
  }

  final String id;
  final String name;
  final VehicleCategory category;

  /// Puissance fiscale en CV, > 0 lorsqu'elle est renseignée.
  final int? fiscalPowerCv;

  final String? registration;

  /// Motorisation fiscale. Jamais devinée : non renseignée par défaut.
  final Motorization motorization;

  /// Classe fiscale si deux-roues ; null = à compléter (pas d'estimation).
  final TwoWheelerFiscalClass? twoWheelerClass;

  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  /// Copie archivée de ce véhicule (les références historiques sont intactes).
  Vehicle archived(DateTime at) => Vehicle(
        id: id,
        name: name,
        category: category,
        fiscalPowerCv: fiscalPowerCv,
        registration: registration,
        motorization: motorization,
        twoWheelerClass: twoWheelerClass,
        archivedAt: at,
      );
}
