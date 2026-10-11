import 'package:uuid/uuid.dart';

/// Génération d'identifiants pour les entités du domaine.
///
/// Les modèles reçoivent leurs ids et ne les génèrent jamais eux-mêmes.
/// UUID v4 : portable (pur Dart, identique Web/iOS), sans dépendance au
/// navigateur, et sans coordination nécessaire — adapté à une app locale.
class IdGenerator {
  const IdGenerator();

  static const _uuid = Uuid();

  String newId() => _uuid.v4();
}
