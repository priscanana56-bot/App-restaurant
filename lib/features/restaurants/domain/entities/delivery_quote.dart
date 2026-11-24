// =============================================================================
// Devis de livraison : objet-valeur pur du Domain.
// -----------------------------------------------------------------------------
// Un devis n'est PAS une commande : il décrit seulement ce qui serait facturé
// pour une distance donnée. Les deux cas (zone autorisée / hors zone) sont
// représentés par la même classe afin que l'interface puisse afficher un
// message explicite sans lever d'exception pour une règle métier attendue.
// =============================================================================

// Égalité de valeur.
import 'package:equatable/equatable.dart';

/// Résultat du calcul de livraison entre l'utilisateur et un établissement.
final class DeliveryQuote extends Equatable {
  /// Construit un devis déjà validé par le use case.
  const DeliveryQuote({
    required this.distanceKm,
    required this.feeFcfa,
    this.isAvailable = true,
    this.reason = '',
  });

  /// Construit un devis refusé, avec la raison affichée à l'utilisateur.
  const DeliveryQuote.unavailable({
    required this.distanceKm,
    required this.reason,
  }) : feeFcfa = 0,
       isAvailable = false;

  /// Distance haversine entre l'utilisateur et l'établissement, en km.
  final double distanceKm;

  /// Frais de livraison en FCFA. Zéro si le devis n'est pas disponible.
  final int feeFcfa;

  /// `true` seulement si l'établissement livre et si la distance est ≤ 5 km.
  final bool isAvailable;

  /// Raison du refus (chaîne vide quand le devis est disponible).
  final String reason;

  @override
  List<Object?> get props => <Object?>[
    distanceKm,
    feeFcfa,
    isAvailable,
    reason,
  ];
}
