import '../../domain/models/civil_date.dart';

/// Effacement explicite d'une journée complète.
///
/// Opération volontairement séparée des repositories unitaires : elle doit
/// supprimer les trajets ET l'extra d'une même date de façon ATOMIQUE
/// (tout ou rien), ce qu'un enchaînement de deux repositories ne garantit
/// pas en cas d'échec partiel.
abstract interface class DayClearRepository {
  /// Supprime tous les trajets et le DayExtra de [date], atomiquement.
  /// Ne touche à rien d'autre (favoris, autres journées, réglages…).
  Future<void> clearDay(CivilDate date);
}
