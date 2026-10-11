import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mes_km/data/network/osm_route_service.dart';
import 'package:mes_km/data/network/route_distance_service.dart';

void main() {
  http.Response geocodeResponse(List<Map<String, Object?>> hits) =>
      http.Response(jsonEncode(hits), 200,
          headers: {'content-type': 'application/json'});

  http.Response routeResponse(double meters) => http.Response(
      jsonEncode({
        'routes': [
          {'distance': meters}
        ]
      }),
      200,
      headers: {'content-type': 'application/json'});

  Map<String, Object?> hit(String name,
          {double importance = 0.8, String lat = '45.0', String lon = '1.7'}) =>
      {
        'display_name': name,
        'importance': importance,
        'lat': lat,
        'lon': lon,
      };

  OsmRouteService service(
          Future<http.Response> Function(http.Request) handler) =>
      OsmRouteService(
        client: MockClient(handler),
        timeout: const Duration(milliseconds: 500),
      );

  Future<RouteDistanceResult> estimate(OsmRouteService s) =>
      s.estimate(origin: 'Maison, Seilhac', destination: 'EHPAD, Seilhac');

  test('succès : géocodage x2 + routage, distance aller canonisée', () async {
    final s = service((request) async {
      if (request.url.host.contains('nominatim')) {
        final q = request.url.queryParameters['q']!;
        return geocodeResponse(
            [hit(q.contains('Maison') ? 'Maison, Seilhac' : 'EHPAD, Seilhac')]);
      }
      return routeResponse(6437); // 6,437 km -> 6,4
    });

    final result = await estimate(s);
    result as RouteDistanceSuccess;
    expect(result.oneWayKm, 6.4);
    expect(result.originLabel, 'Maison, Seilhac');
    expect(result.destinationLabel, 'EHPAD, Seilhac');
  });

  test('adresse introuvable (départ puis destination)', () async {
    final s = service((request) async => geocodeResponse(const []));
    final result = await estimate(s);
    result as RouteAddressNotFound;
    expect(result.isOrigin, isTrue);

    final s2 = service((request) async {
      final q = request.url.queryParameters['q']!;
      return geocodeResponse(q.contains('Maison') ? [hit('Maison')] : const []);
    });
    final result2 = await estimate(s2);
    result2 as RouteAddressNotFound;
    expect(result2.isOrigin, isFalse);
  });

  test('ambiguïté : importances proches ET lieux distincts => 2-5 '
      'propositions, pas de choix silencieux', () async {
    final s = service((request) async => geocodeResponse([
          hit('Seilhac, Corrèze', importance: 0.80, lat: '45.36'),
          hit('Seilhac, Dordogne', importance: 0.75, lat: '44.90'),
        ]));

    final result = await estimate(s);
    result as RouteAddressAmbiguous;
    expect(result.isOrigin, isTrue);
    expect(result.suggestions,
        ['Seilhac, Corrèze', 'Seilhac, Dordogne']);
  });

  test('doublons administratifs (même nom, < 25 km) => PAS d\u2019ambiguïté, '
      'meilleur résultat utilisé', () async {
    final s = service((request) async {
      if (request.url.host.contains('nominatim')) {
        return geocodeResponse([
          hit('Tulle, Corrèze, 19000', importance: 0.59, lat: '45.2678'),
          hit('Tulle, Corrèze', importance: 0.528, lat: '45.3388'),
        ]);
      }
      return routeResponse(15200);
    });

    final result = await estimate(s);
    expect(result, isA<RouteDistanceSuccess>());
    expect((result as RouteDistanceSuccess).oneWayKm, 15.2);
  });

  test('meilleur résultat net (importance dominante) => utilisé', () async {
    final s = service((request) async {
      if (request.url.host.contains('nominatim')) {
        return geocodeResponse([
          hit('Seilhac, Corrèze', importance: 0.9),
          hit('Lieu-dit mineur', importance: 0.3),
        ]);
      }
      return routeResponse(12400);
    });

    final result = await estimate(s);
    expect(result, isA<RouteDistanceSuccess>());
    expect((result as RouteDistanceSuccess).oneWayKm, 12.4);
  });

  test('timeout => RouteTimeout', () async {
    final s = service((request) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      return geocodeResponse([hit('x')]);
    });
    expect(await estimate(s), isA<RouteTimeout>());
  });

  test('erreur réseau (fetch) => RouteOffline', () async {
    final s = service(
        (request) async => throw http.ClientException('Failed to fetch'));
    expect(await estimate(s), isA<RouteOffline>());
  });

  test('réponse malformée => RouteServiceUnavailable', () async {
    final s = service((request) async =>
        http.Response('<html>maintenance</html>', 200));
    expect(await estimate(s), isA<RouteServiceUnavailable>());
  });

  test('statuts 429/500 => RouteServiceUnavailable', () async {
    for (final code in [429, 500, 503]) {
      final s = service((request) async => http.Response('err', code));
      expect(await estimate(s), isA<RouteServiceUnavailable>(),
          reason: 'statut $code');
    }
  });

  test('routage sans itinéraire => RouteServiceUnavailable', () async {
    final s = service((request) async {
      if (request.url.host.contains('nominatim')) {
        return geocodeResponse([hit('a')]);
      }
      return http.Response(jsonEncode({'routes': []}), 200);
    });
    expect(await estimate(s), isA<RouteServiceUnavailable>());
  });
}
