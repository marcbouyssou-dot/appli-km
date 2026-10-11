import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/models/fiscal_reference.dart';

/// Référentiels fiscaux embarqués (assets/fiscal/) — KM-013.
///
/// Chargement LOCAL uniquement (aucun téléchargement), validation à la
/// construction des modèles. Un asset invalide est rejeté : l'app affiche
/// alors « barème non disponible » plutôt qu'une estimation douteuse.
class FiscalReferenceStore {
  FiscalReferenceStore(this.references);

  final List<FiscalReference> references;

  /// Barème officiel de l'année de REVENUS [year] ; null si aucun.
  FiscalReference? forIncomeYear(int year) {
    for (final reference in references) {
      if (reference.incomeYear == year) return reference;
    }
    return null;
  }

  /// Dernier barème officiel connu (pour simulation PROVISOIRE explicite).
  FiscalReference? get latest {
    FiscalReference? best;
    for (final reference in references) {
      if (best == null || reference.incomeYear > best.incomeYear) {
        best = reference;
      }
    }
    return best;
  }
}

const _assetPaths = ['assets/fiscal/bareme-revenus-2025.json'];

/// Charge et valide les référentiels embarqués. Un référentiel illisible
/// n'est jamais remplacé par des valeurs devinées : il est simplement absent.
Future<FiscalReferenceStore> loadFiscalReferenceStore() async {
  final references = <FiscalReference>[];
  for (final path in _assetPaths) {
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Référentiel invalide : racine illisible.');
      }
      references.add(FiscalReference.fromJson(decoded));
    } catch (error) {
      if (kDebugMode) debugPrint('[fiscal] référentiel rejeté ($path): $error');
    }
  }
  return FiscalReferenceStore(references);
}
