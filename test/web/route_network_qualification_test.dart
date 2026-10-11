@TestOn('browser')
@Tags(['network'])
library;

// QUALIFICATION RÉSEAU RÉELLE (CORS/HTTPS) depuis un vrai navigateur,
// exigence critique KM-011 : un endpoint utilisable en curl n'est pas
// automatiquement utilisable depuis une PWA.
//
// Exécution EXPLICITE et rare (respect des services publics OSM) :
//   flutter test --platform chrome --tags network \
//     test/web/route_network_qualification_test.dart
// Les runs normaux doivent utiliser --exclude-tags network.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mes_km/data/network/osm_route_service.dart';
import 'package:mes_km/data/network/route_distance_service.dart';

void main() {
  test('CORS navigateur : Nominatim et OSRM répondent à notre origine',
      () async {
    // Un fetch réussi PROUVE que CORS est passé (sinon le navigateur
    // bloque la réponse).
    final nominatim = await http.get(Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&q=Seilhac'));
    expect(nominatim.statusCode, 200);
    expect(nominatim.body, startsWith('['));

    final osrm = await http.get(Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '1.7126,45.3672;1.7686,45.2674?overview=false'));
    expect(osrm.statusCode, 200);
    expect(osrm.body, contains('"routes"'));
  });

  test('un VRAI calcul de bout en bout depuis le navigateur', () async {
    final service = OsmRouteService();
    var origin = 'Seilhac, France';
    var destination = 'Tulle, France';
    RouteDistanceResult result = const RouteServiceUnavailable();

    // Même flux que l'UI : une ambiguïté réelle (plusieurs lieux
    // plausibles) se résout en choisissant une proposition puis en
    // relançant — au plus 3 itérations.
    for (var attempt = 0; attempt < 3; attempt++) {
      result = await service.estimate(
          origin: origin, destination: destination);
      if (result is! RouteAddressAmbiguous) break;
      if (result.isOrigin) {
        origin = result.suggestions.first;
      } else {
        destination = result.suggestions.first;
      }
    }

    // Seilhac-Tulle ≈ 15 km par la route : on vérifie un ordre de
    // grandeur plausible, pas une valeur figée (les routes évoluent).
    result as RouteDistanceSuccess;
    expect(result.oneWayKm, greaterThan(5));
    expect(result.oneWayKm, lessThan(40));
    expect(result.originLabel.toLowerCase(), contains('seilhac'));
  });
}
