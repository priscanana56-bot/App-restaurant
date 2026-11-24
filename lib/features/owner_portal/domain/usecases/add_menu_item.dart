// =============================================================================
// Use case : ajouter un plat au menu d'un établissement.
// -----------------------------------------------------------------------------
// Chaque écriture exige à nouveau le code gérant : même si la page est
// contournée, aucun plat ne peut être modifié sans authentification locale.
// Tous les textes repassent par `InputSanitizer` avant création de l'entité.
// =============================================================================

// Égalité des paramètres.
import 'package:equatable/equatable.dart';

// Either.
import 'package:fpdart/fpdart.dart';

// Bornes, erreurs et nettoyage.
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';

// Contrat, horloge et entités.
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../restaurants/domain/entities/menu_item.dart';
import '../../../restaurants/domain/entities/restaurant.dart';
import '../../../restaurants/domain/repositories/restaurant_repository.dart';

// Vérification du code.
import 'verify_owner_code.dart';

/// Paramètres d'ajout d'un plat.
final class AddMenuItemParams extends Equatable {
  /// Construit des paramètres typés.
  const AddMenuItemParams({
    required this.restaurantId,
    required this.code,
    required this.name,
    required this.description,
    required this.section,
    required this.priceFcfa,
    required this.portionLabel,
    required this.preparationMinutes,
    this.isAvailable = true,
    this.isSignature = false,
  });

  /// Établissement concerné.
  final String restaurantId;

  /// Code gérant, revérifié à chaque écriture.
  final String code;

  /// Nom du plat.
  final String name;

  /// Description courte.
  final String description;

  /// Section du menu.
  final MenuSection section;

  /// Prix en FCFA.
  final int priceFcfa;

  /// Libellé de portion.
  final String portionLabel;

  /// Temps de préparation en minutes.
  final int preparationMinutes;

  /// Disponibilité immédiate.
  final bool isAvailable;

  /// Mise en avant comme spécialité.
  final bool isSignature;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[
    restaurantId,
    name,
    description,
    section,
    priceFcfa,
    portionLabel,
    preparationMinutes,
    isAvailable,
    isSignature,
  ];
}

/// Ajoute un plat après vérification du code gérant.
final class AddMenuItem implements UseCase<Restaurant, AddMenuItemParams> {
  /// Injection du repository, de la vérification et de l'horloge.
  const AddMenuItem(this._repository, this._verifyCode, this._clock);

  // Dépendances uniques.
  final RestaurantRepository _repository;
  final VerifyOwnerCode _verifyCode;
  final AppClock _clock;

  /// Authentifie puis persiste le plat.
  @override
  Future<Either<Failure, Restaurant>> call(AddMenuItemParams params) async {
    // La vérification du code est asynchrone : elle est attendue avant toute
    // construction d'entité ou écriture dans le cache.
    final Either<Failure, bool> verification = await _verifyCode(
      VerifyOwnerCodeParams(
        restaurantId: params.restaurantId,
        code: params.code,
      ),
    );
    return verification.fold<Future<Either<Failure, Restaurant>>>(
      (Failure failure) async => left<Failure, Restaurant>(failure),
      (bool isValid) async {
        // Un code invalide n'est PAS une erreur de validation de saisie :
        // c'est une tentative d'accès non autorisée.
        if (!isValid) {
          return left<Failure, Restaurant>(
            const SecurityFailure(
              message: 'Code gérant incorrect. Modification refusée.',
            ),
          );
        }
        return _add(params);
      },
    );
  }

  /// Construit l'entité puis délègue l'écriture au repository.
  Future<Either<Failure, Restaurant>> _add(AddMenuItemParams params) async {
    // Nettoyage des champs libres avant toute construction d'entité.
    final String name = InputSanitizer.sanitizeShortLabel(
      params.name,
      maxLength: AppConstants.shortTextMaxLength,
    );
    final String description = InputSanitizer.sanitizePlainText(
      params.description,
      maxLength: 200,
      allowNewlines: false,
    );
    final String portionLabel = InputSanitizer.sanitizeShortLabel(
      params.portionLabel,
      maxLength: 40,
    );

    if (name.isEmpty) {
      return left(
        const ValidationFailure(
          message: 'Nom de plat invalide.',
          field: 'name',
        ),
      );
    }
    if (params.priceFcfa <= 0) {
      return left(
        const ValidationFailure(
          message: 'Le prix doit être strictement positif.',
          field: 'priceFcfa',
        ),
      );
    }
    if (params.preparationMinutes < 0 || params.preparationMinutes > 240) {
      return left(
        const ValidationFailure(
          message: 'Temps de préparation invalide.',
          field: 'preparationMinutes',
        ),
      );
    }

    // Identifiant dérivé de l'horloge injectée : stable, sûr et sans collision
    // avec les identifiants du seed (préfixe `dish_`).
    final String safeRestaurantId = InputSanitizer.sanitizeIdentifier(
      params.restaurantId,
    );
    final String id = InputSanitizer.sanitizeIdentifier(
      'dish_${safeRestaurantId}_${_clock.now().microsecondsSinceEpoch}',
    );
    if (safeRestaurantId.isEmpty || id.isEmpty) {
      return left(
        const ValidationFailure(
          message: 'Établissement ou plat invalide.',
          field: 'restaurantId',
        ),
      );
    }

    final MenuItem item = MenuItem(
      id: id,
      name: name,
      description: description,
      section: params.section,
      priceFcfa: params.priceFcfa,
      isAvailable: params.isAvailable,
      isSignature: params.isSignature,
      portionLabel: portionLabel.isEmpty ? '1 portion' : portionLabel,
      preparationMinutes: params.preparationMinutes,
      photoAsset: null,
      allergens: const <Allergen>{},
    );

    return _repository.addMenuItem(restaurantId: safeRestaurantId, item: item);
  }
}
