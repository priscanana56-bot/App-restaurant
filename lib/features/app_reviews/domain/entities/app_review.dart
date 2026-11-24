// =============================================================================
// Avis local sur la qualité de l'application.
// -----------------------------------------------------------------------------
// Cette entité ne décrit PAS un restaurant : elle permet à l'utilisateur de
// noter l'application elle-même (ergonomie, prix affichés, fiabilité du guide)
// et de partager son avis. Elle est immuable, comparable et sans dépendance
// Flutter, comme le reste du Domain.
// =============================================================================

// Égalité de valeur.
import 'package:equatable/equatable.dart';

/// Avis écrit localement par l'utilisateur.
final class AppReview extends Equatable {
  /// Construit un avis dont la note est comprise entre 1 et 5 étoiles.
  const AppReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
  }) : assert(
         rating >= 1 && rating <= 5,
         'La note doit être comprise entre 1 et 5 étoiles.',
       );

  /// Identifiant local stable (clé Hive).
  final String id;

  /// Note de 1 à 5 étoiles.
  final int rating;

  /// Commentaire déjà nettoyé par `InputSanitizer`.
  final String comment;

  /// Date de création de l'avis.
  final DateTime createdAt;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[id, rating, comment, createdAt];
}
