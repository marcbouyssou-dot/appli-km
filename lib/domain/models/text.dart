/// Nettoyage commun des champs texte facultatifs du domaine :
/// espaces superflus retirés, chaîne vide ramenée à `null`.
String? cleanText(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
