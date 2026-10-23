import 'package:flutter/material.dart';
import '../../data/local/trip_batch_service.dart';
import '../../domain/models/favorite_trip.dart';
import '../../domain/models/trip_template.dart';
import '../day/trip_days_screen.dart';

/// Entrée Favori conservée ; calendrier et moteur partagés avec saisie/historique.
class FavoriteDaysScreen extends StatelessWidget {
  const FavoriteDaysScreen({super.key, required this.favorite});
  final FavoriteTrip favorite;
  @override
  Widget build(BuildContext context) => TripDaysScreen(
    source: TripBatchSource.favorite(favorite.id),
    template: TripTemplate.fromFavorite(favorite),
    label: favorite.label,
  );
}
