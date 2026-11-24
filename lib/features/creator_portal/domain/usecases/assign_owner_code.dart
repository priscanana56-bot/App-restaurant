// =============================================================================
// Use case : attribuer (ou réinitialiser) le code gérant d'une fiche existante.
// -----------------------------------------------------------------------------
// Sans ce use case, les fiches embarquées n'ont aucun code gérant et le portail
// gérant reste inutilisable. L'administrateur s'authentifie à NOUVEAU à chaque
// attribution : déverrouiller l'écran une fois ne suffit jamais à écrire un secret.
//
// Aucun code n'est renvoyé ni journalisé : seul le résultat typé est exposé.
// =============================================================================

// Égalité des paramètres.
import 'package:equatable/equatable.dart';

// Either et Unit.
import 'package:fpdart/fpdart.dart';

// Erreurs, nettoyage et contrat.
import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/security/pin_auth.dart';
import '../../../../core/usecases/usecase.dart';

// Entité et repository du catalogue.
import '../../../restaurants/domain/entities/restaurant.dart';
import '../../../restaurants/domain/repositories/restaurant_repository.dart';

// Vérification du PIN administrateur.
import 'verify_creator_pin.dart';

/// Paramètres d'attribution d'un code gérant.
final class AssignOwnerCodeParams extends Equatable {
  /// Construit des paramètres typés.
  const AssignOwnerCodeParams({
    required this.adminPin,
    required this.restaurantId,
    required this.code,
  });

  /// Code administrateur, revérifié avant écriture.
  final String adminPin;

  /// Identifiant d'une fiche déjà présente dans le catalogue.
  final String restaurantId;

  /// Nouveau code gérant (4 à 6 chiffres).
  final String code;

  // Le nouveau code est un secret : il est exclu de l'égalité et du toString
  // d'Equatable pour ne jamais apparaître dans un journal de debug.
  @override
  List<Object?> get props => <Object?>[restaurantId];
}

/// Attribue un accès gérant à une fiche existante.
final class AssignOwnerCode implements UseCase<Unit, AssignOwnerCodeParams> {
  /// Injection du repository, de la vérification PIN et du service de codes.
  const AssignOwnerCode(this._repository, this._verifyPin, this._auth);

  // Dépendances uniques.
  final RestaurantRepository _repository;
  final VerifyCreatorPin _verifyPin;
  final PinAuthService _auth;

  @override
  Future<Either<Failure, Unit>> call(AssignOwnerCodeParams params) async {
    // 1. Authentification fraîche, avant même de lire le catalogue.
    final Either<Failure, bool> verification = await _verifyPin(
      params.adminPin,
    );
    final Failure? authFailure = verification.fold(
      (Failure failure) => failure,
      (bool isValid) => isValid
          ? null
          : const SecurityFailure(
              message: 'Code administrateur incorrect. Attribution refusée.',
            ),
    );
    if (authFailure != null) {
      return left(authFailure);
    }

    // 2. L'identifiant est nettoyé : aucune clé de coffre forgée.
    final String restaurantId = InputSanitizer.sanitizeIdentifier(
      params.restaurantId,
    );
    if (restaurantId.isEmpty) {
      return left(
        const ValidationFailure(
          message: 'Établissement invalide.',
          field: 'restaurantId',
        ),
      );
    }

    // 3. La fiche doit exister réellement dans le catalogue local.
    final Either<Failure, List<Restaurant>> catalog = await _repository
        .getRestaurants(forceRefresh: false);
    final Failure? catalogFailure = catalog.fold((Failure failure) => failure, (
      List<Restaurant> restaurants,
    ) {
      for (final Restaurant restaurant in restaurants) {
        if (restaurant.id == restaurantId) {
          return null;
        }
      }
      return const NotFoundFailure(
        message: 'Cet établissement est introuvable dans le catalogue local.',
      );
    });
    if (catalogFailure != null) {
      return left(catalogFailure);
    }

    // 4. Écriture du secret dans le coffre natif (empreinte PBKDF2 seulement).
    return _auth.setOwnerCode(
      restaurantId: restaurantId,
      code: params.code.trim(),
    );
  }
}
