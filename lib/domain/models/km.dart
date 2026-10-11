/// Représentation des kilomètres du domaine.
///
/// Stratégie retenue : `double` exprimé en kilomètres, **canonisé au dixième
/// de kilomètre** à l'entrée de chaque modèle et à la sortie de chaque somme.
/// Les erreurs binaires d'addition (de l'ordre de 1e-13) restent très en deçà
/// du seuil d'arrondi de 0,05 km : arrondir après sommation les élimine, et
/// deux valeurs canonisées égales sont strictement égales (`==` fiable).
/// Une représentation entière (mètres) aurait imposé des conversions partout
/// sans gain pour une précision utilisateur au dixième de km.
library;

/// Canonise une valeur en kilomètres au dixième le plus proche.
double normalizeKm(double km) => (km * 10).roundToDouble() / 10;

/// Somme canonisée d'une collection de kilomètres.
double sumKm(Iterable<double> values) =>
    normalizeKm(values.fold(0.0, (total, value) => total + value));
