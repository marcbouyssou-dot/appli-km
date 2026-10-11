/// Frontière réseau du calcul d'itinéraire — indépendante de la plateforme.
///
/// PRINCIPE PRODUIT : le calcul est un CONFORT. Aucune implémentation ne
/// doit être invoquée sans action explicite de l'utilisateur, et tout le
/// reste de Mes Km fonctionne sans réseau.
library;

/// Résultat typé : jamais d'exception HTTP, de JSON brut ni de stack trace
/// vers l'UI.
sealed class RouteDistanceResult {
  const RouteDistanceResult();
}

class RouteDistanceSuccess extends RouteDistanceResult {
  const RouteDistanceSuccess({
    required this.oneWayKm,
    required this.originLabel,
    required this.destinationLabel,
  });

  /// Distance ALLER, canonisée au dixième. Le doublement A/R est une
  /// décision d'UI explicite, jamais implicite.
  final double oneWayKm;

  /// Libellés résolus par le géocodage — affichés pour que l'utilisateur
  /// VOIE ce qui a été trouvé.
  final String originLabel;
  final String destinationLabel;
}

class RouteAddressNotFound extends RouteDistanceResult {
  const RouteAddressNotFound({required this.isOrigin});

  final bool isOrigin;
}

/// Plusieurs lieux plausibles : on ne choisit pas silencieusement.
class RouteAddressAmbiguous extends RouteDistanceResult {
  const RouteAddressAmbiguous({
    required this.isOrigin,
    required this.suggestions,
  });

  final bool isOrigin;

  /// 2 à 5 libellés courts proposés à l'utilisateur.
  final List<String> suggestions;
}

class RouteOffline extends RouteDistanceResult {
  const RouteOffline();
}

class RouteTimeout extends RouteDistanceResult {
  const RouteTimeout();
}

class RouteServiceUnavailable extends RouteDistanceResult {
  const RouteServiceUnavailable();
}

abstract interface class RouteDistanceService {
  /// Calcule la distance routière ALLER entre deux adresses.
  /// Un appel = une action utilisateur explicite.
  Future<RouteDistanceResult> estimate({
    required String origin,
    required String destination,
  });
}
