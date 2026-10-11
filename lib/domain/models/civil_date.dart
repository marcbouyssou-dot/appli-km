/// Date civile (année / mois / jour), sans heure ni fuseau horaire.
///
/// Les kilomètres appartiennent à une date civile : celle-ci ne doit jamais
/// glisser d'un jour à cause d'un fuseau, d'un passage heure d'été/hiver ou
/// d'une sérialisation UTC. Toute l'arithmétique interne passe par
/// `DateTime.utc`, insensible aux changements d'heure locaux.
class CivilDate implements Comparable<CivilDate> {
  CivilDate(this.year, this.month, this.day) {
    final check = DateTime.utc(year, month, day);
    if (year < 1 ||
        check.year != year ||
        check.month != month ||
        check.day != day) {
      throw ArgumentError('Date civile invalide : $year-$month-$day');
    }
  }

  /// Date civile locale d'un [DateTime] (l'heure est ignorée).
  factory CivilDate.fromDateTime(DateTime dateTime) =>
      CivilDate(dateTime.year, dateTime.month, dateTime.day);

  factory CivilDate.today() => CivilDate.fromDateTime(DateTime.now());

  /// Analyse le format stable `yyyy-MM-dd` (celui de [toIso8601]).
  factory CivilDate.parse(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      throw FormatException('Format attendu yyyy-MM-dd : "$value"');
    }
    final numbers = parts.map(int.tryParse).toList();
    if (numbers.any((n) => n == null)) {
      throw FormatException('Format attendu yyyy-MM-dd : "$value"');
    }
    return CivilDate(numbers[0]!, numbers[1]!, numbers[2]!);
  }

  final int year;
  final int month;
  final int day;

  /// Minuit local, pour les API qui exigent un [DateTime] (affichage, tri UI).
  DateTime toDateTime() => DateTime(year, month, day);

  CivilDate addDays(int days) {
    final shifted = DateTime.utc(year, month, day).add(Duration(days: days));
    return CivilDate(shifted.year, shifted.month, shifted.day);
  }

  /// Format stable pour la future persistance : `yyyy-MM-dd`.
  String toIso8601() => '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  bool isBefore(CivilDate other) => compareTo(other) < 0;

  bool isAfter(CivilDate other) => compareTo(other) > 0;

  @override
  int compareTo(CivilDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CivilDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso8601();
}
