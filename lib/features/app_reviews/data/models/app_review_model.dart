// =============================================================================
// Modèle JSON d'un avis local.
// -----------------------------------------------------------------------------
// Le format de stockage reste le même que celui du reste de l'application :
// une chaîne JSON par objet dans une boîte Hive chiffrée. `fromJson` constitue
// la frontière de confiance : note bornée, texte nettoyé, identifiant sûr.
// =============================================================================

// Décodage JSON.
import 'dart:convert';

// Bornes métier.
import '../../../../core/constants/app_constants.dart';

// Nettoyage des entrées.
import '../../../../core/security/input_sanitizer.dart';

// Entité produite.
import '../../domain/entities/app_review.dart';

// Lecteur strict.
import '../../../restaurants/data/models/json_reader.dart';

/// Représentation de transport d'un avis.
final class AppReviewModel {
  /// Construit un modèle déjà validé.
  const AppReviewModel({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  /// Identifiant local.
  final String id;

  /// Note de 1 à 5.
  final int rating;

  /// Commentaire nettoyé.
  final String comment;

  /// Date de création.
  final DateTime createdAt;

  /// Construit le modèle depuis un objet JSON.
  factory AppReviewModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);

    final String id = InputSanitizer.sanitizeIdentifier(
      reader.requireString('id', maxLength: 64),
    );
    if (id.isEmpty) {
      throw const FormatException('Identifiant d’avis invalide.');
    }

    final int rating = reader.requireInt('rating', min: 1, max: 5);
    final String comment = InputSanitizer.sanitizePlainText(
      reader.optionalString(
        'comment',
        maxLength: AppConstants.commentMaxLength,
      ),
      maxLength: AppConstants.commentMaxLength,
    );

    return AppReviewModel(
      id: id,
      rating: rating,
      comment: comment,
      createdAt: reader.requireDateTime('createdAt'),
    );
  }

  /// Construit le modèle depuis une chaîne JSON mise en cache.
  factory AppReviewModel.fromJsonString(String raw) {
    final Object? decoded = jsonDecode(raw) as Object?;
    return AppReviewModel.fromJson(
      JsonReader.mapFrom(decoded, context: 'avis application'),
    );
  }

  /// Construit le modèle depuis une entité Domain.
  factory AppReviewModel.fromEntity(AppReview entity) => AppReviewModel(
    id: entity.id,
    rating: entity.rating,
    comment: entity.comment,
    createdAt: entity.createdAt,
  );

  /// Convertit le modèle en entité Domain.
  AppReview toEntity() =>
      AppReview(id: id, rating: rating, comment: comment, createdAt: createdAt);

  /// Sérialise le modèle pour Hive.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'rating': rating,
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Sérialise directement en chaîne pour la valeur de la boîte.
  String toJsonString() => jsonEncode(toJson());
}
