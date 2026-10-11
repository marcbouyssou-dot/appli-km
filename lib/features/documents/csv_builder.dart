import 'report_data.dart';

/// CSV détaillé de l'année — compatible tableurs français :
/// séparateur `;`, décimale `,` (24,5), UTF-8.
///
/// Invariant : chaque kilomètre de l'année apparaît exactement UNE fois ;
/// la somme de la colonne Distance_km égale le total annuel du relevé.
String buildAnnualCsv(AnnualReportData report) {
  final buffer = StringBuffer();
  buffer.writeln(
    'Date;Type;Distance_km;Départ;Destination;Motif;Aller_retour;'
    'Véhicule;Immatriculation',
  );

  String escape(String value) {
    if (value.contains(';') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String km(double value) {
    final text = value == value.roundToDouble()
        ? '${value.round()}'
        : value.toStringAsFixed(1);
    return text.replaceAll('.', ',');
  }

  for (final line in report.lines) {
    buffer.writeln([
      line.date.toIso8601(),
      line.isDetailedTrip ? 'Trajet' : 'Non détaillé',
      km(line.km),
      escape(line.origin ?? ''),
      escape(line.destination ?? ''),
      escape(line.purpose ?? ''),
      line.isDetailedTrip ? (line.isRoundTrip ? 'Oui' : 'Non') : '',
      escape(line.vehicleLabel),
      escape(line.registration),
    ].join(';'));
  }

  return buffer.toString();
}
