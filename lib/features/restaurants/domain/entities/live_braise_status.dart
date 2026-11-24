// =============================================================================
// Live Braise — statut d'une braise en cours.
// -----------------------------------------------------------------------------
// Le Live Braise est une session limitée dans le temps : une viande ou un
// poisson braisé, un stock de portions et une heure de fin. Le statut est
// TOUJOURS recalculé à partir de l'horloge injectée, jamais figé dans l'UI.
// =============================================================================

// Equatable pour comparer deux statuts.
import 'package:equatable/equatable.dart';

/// Braise en cours ou à venir dans un restaurant.
final class LiveBraiseStatus extends Equatable {
  /// Construit un statut cohérent.
  const LiveBraiseStatus({
    required this.restaurantId,
    required this.restaurantName,
    required this.dishName,
    required this.description,
    required this.priceFcfa,
    required this.portionsTotal,
    required this.portionsRemaining,
    required this.startedAt,
    required this.endsAt,
  }) : assert(priceFcfa >= 0, 'Le prix d’une braise ne peut pas être négatif.'),
       assert(portionsTotal > 0, 'Une braise doit avoir au moins une portion.'),
       assert(
         portionsRemaining >= 0 && portionsRemaining <= portionsTotal,
         'Les portions restantes doivent être comprises entre 0 et le total.',
       );

  /// Identifiant du restaurant qui propose la braise.
  final String restaurantId;

  /// Nom du restaurant, dénormalisé pour l'affichage rapide du bandeau.
  final String restaurantName;

  /// Nom du plat braisé (ex. « Mouton braisé »).
  final String dishName;

  /// Description courte (morceaux, accompagnement, épices).
  final String description;

  /// Prix d'une portion en FCFA.
  final int priceFcfa;

  /// Nombre de portions prévues au départ.
  final int portionsTotal;

  /// Nombre de portions encore disponibles.
  final int portionsRemaining;

  /// Début de la session de braise (heure de Koudougou, encodée en UTC).
  final DateTime startedAt;

  /// Fin prévue de la session.
  final DateTime endsAt;

  /// Indique si la braise est active à l'instant [now].
  bool isActiveAt(DateTime now) {
    // Un stock épuisé termine immédiatement la braise.
    if (portionsRemaining <= 0) {
      return false;
    }

    // Fenêtre semi-ouverte [début, fin).
    return !now.isBefore(startedAt) && now.isBefore(endsAt);
  }

  /// Indique si toutes les portions ont été vendues.
  bool get isSoldOut => portionsRemaining <= 0;

  /// Pourcentage de portions déjà servies, borné entre 0 et 100.
  int get servedPercentage {
    // Le total est garanti strictement positif par le constructeur.
    final double ratio = 1 - (portionsRemaining / portionsTotal);
    return (ratio * 100).round().clamp(0, 100);
  }

  /// Minutes restantes avant la fin, bornées à zéro.
  int remainingMinutesAt(DateTime now) {
    // Une session déjà terminée renvoie zéro, jamais un nombre négatif.
    final int minutes = endsAt.difference(now).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[
    restaurantId,
    restaurantName,
    dishName,
    description,
    priceFcfa,
    portionsTotal,
    portionsRemaining,
    startedAt,
    endsAt,
  ];
}
