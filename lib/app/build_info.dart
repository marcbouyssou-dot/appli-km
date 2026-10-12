/// Identité de build (UX-008B) — support/traçabilité V1.
///
/// Le SHA court est injecté à la compilation par le script de déploiement
/// (`--dart-define=MESKM_GIT_SHA=<sha>`). En build local sans define, le
/// repli est propre : la ligne de version s'affiche sans SHA.
library;

const String appVersion = '1.0.0';

const String buildSha =
    String.fromEnvironment('MESKM_GIT_SHA', defaultValue: 'dev');

/// Ligne discrète affichée en pied de Réglages :
/// « Mes Km 1.0.0 · abc1234 » (SHA omis proprement en build local).
String versionLine([String sha = buildSha]) =>
    sha == 'dev' || sha.isEmpty ? 'Mes Km $appVersion' : 'Mes Km $appVersion · $sha';
