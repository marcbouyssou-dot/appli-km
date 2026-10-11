import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/km.dart';
import 'route_distance_service.dart';

/// Implémentation OpenStreetMap : géocodage Nominatim + routage OSRM.
///
/// Endpoints publics qualifiés (KM-011) : HTTPS, CORS
/// `access-control-allow-origin: *` vérifié depuis navigateur réel.
/// Politiques respectées : volume minime (2-3 requêtes par action
/// utilisateur explicite), aucun autocomplete, aucun bulk, aucun appel en
/// arrière-plan, aucun retry automatique. Le Referer du navigateur
/// identifie l'origine (le User-Agent n'est pas modifiable depuis une
/// page web).
///
/// Timeout : 8 s par étape (3 étapes max ≈ 24 s pire cas) — assez long
/// pour un réseau mobile médiocre, assez court pour ne pas bloquer un
/// formulaire dont la saisie manuelle reste toujours possible.
class OsmRouteService implements RouteDistanceService {
  OsmRouteService({
    http.Client? client,
    this.nominatimBase = 'https://nominatim.openstreetmap.org',
    this.osrmBase = 'https://router.project-osrm.org',
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String nominatimBase;
  final String osrmBase;
  final Duration timeout;

  /// Écart d'« importance » Nominatim sous lequel deux résultats sont
  /// considérés comme réellement concurrents (→ choix utilisateur).
  static const double _ambiguityImportanceGap = 0.1;

  @override
  Future<RouteDistanceResult> estimate({
    required String origin,
    required String destination,
  }) async {
    try {
      final originResult = await _geocode(origin, isOrigin: true);
      if (originResult is! _GeocodeHit) {
        return originResult as RouteDistanceResult;
      }
      final destinationResult =
          await _geocode(destination, isOrigin: false);
      if (destinationResult is! _GeocodeHit) {
        return destinationResult as RouteDistanceResult;
      }

      return await _route(originResult, destinationResult);
    } on TimeoutException {
      return const RouteTimeout();
    } on http.ClientException {
      // Navigateur : échec de fetch = hors ligne (ou réseau bloqué).
      return const RouteOffline();
    } on FormatException {
      return const RouteServiceUnavailable();
    } catch (_) {
      return const RouteServiceUnavailable();
    }
  }

  Future<Object> _geocode(String query, {required bool isOrigin}) async {
    final uri = Uri.parse('$nominatimBase/search').replace(queryParameters: {
      'format': 'jsonv2',
      'limit': '5',
      'q': query,
    });
    final response = await _client.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      return const RouteServiceUnavailable();
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) return const RouteServiceUnavailable();
    if (decoded.isEmpty) {
      return RouteAddressNotFound(isOrigin: isOrigin);
    }

    final hits = [
      for (final item in decoded)
        if (item is Map<String, Object?>) item,
    ];
    if (hits.isEmpty) return const RouteServiceUnavailable();

    double importance(Map<String, Object?> hit) =>
        (hit['importance'] as num?)?.toDouble() ?? 0;
    String label(Map<String, Object?> hit) =>
        (hit['display_name'] as String?) ?? '';
    String placeName(Map<String, Object?> hit) =>
        label(hit).split(',').first.trim().toLowerCase();
    double? coord(Map<String, Object?> hit, String key) =>
        double.tryParse('${hit[key]}');

    // Ambiguïté : plusieurs résultats d'importance proche qui désignent des
    // LIEUX réellement différents → choix utilisateur, jamais silencieux.
    // Nominatim renvoie souvent le même endroit en plusieurs objets OSM
    // (commune + arrondissement + nœud) : même nom ET < ~25 km du meilleur
    // résultat = même lieu, on garde le meilleur.
    if (hits.length > 1) {
      final top = hits.first;
      final best = importance(top);
      final topLat = coord(top, 'lat') ?? 0;
      final topLon = coord(top, 'lon') ?? 0;

      bool samePlaceAsTop(Map<String, Object?> hit) {
        if (placeName(hit) != placeName(top)) return false;
        final lat = coord(hit, 'lat') ?? 0;
        final lon = coord(hit, 'lon') ?? 0;
        // Approximation équirectangulaire, suffisante à cette échelle.
        final dLatKm = (lat - topLat).abs() * 111.0;
        final dLonKm = (lon - topLon).abs() * 78.0; // ~cos(45°) × 111
        return dLatKm < 25 && dLonKm < 25;
      }

      final rivals = <String>{label(top)};
      for (final hit in hits.skip(1)) {
        if (best - importance(hit) < _ambiguityImportanceGap &&
            !samePlaceAsTop(hit)) {
          rivals.add(label(hit));
        }
      }
      if (rivals.length > 1) {
        return RouteAddressAmbiguous(
          isOrigin: isOrigin,
          suggestions: rivals.take(5).toList(),
        );
      }
    }

    final top = hits.first;
    final lat = double.tryParse('${top['lat']}');
    final lon = double.tryParse('${top['lon']}');
    if (lat == null || lon == null) {
      return const RouteServiceUnavailable();
    }
    return _GeocodeHit(lat: lat, lon: lon, label: label(top));
  }

  Future<RouteDistanceResult> _route(
    _GeocodeHit origin,
    _GeocodeHit destination,
  ) async {
    final uri = Uri.parse(
      '$osrmBase/route/v1/driving/'
      '${origin.lon},${origin.lat};${destination.lon},${destination.lat}'
      '?overview=false',
    );
    final response = await _client.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      return const RouteServiceUnavailable();
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, Object?>) {
      return const RouteServiceUnavailable();
    }
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      return const RouteServiceUnavailable();
    }
    final first = routes.first;
    final meters =
        first is Map<String, Object?> ? first['distance'] : null;
    if (meters is! num) return const RouteServiceUnavailable();

    return RouteDistanceSuccess(
      oneWayKm: normalizeKm(meters / 1000),
      originLabel: origin.label,
      destinationLabel: destination.label,
    );
  }
}

class _GeocodeHit {
  _GeocodeHit({required this.lat, required this.lon, required this.label});

  final double lat;
  final double lon;
  final String label;
}
