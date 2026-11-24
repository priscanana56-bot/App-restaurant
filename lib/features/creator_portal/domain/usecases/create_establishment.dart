// =============================================================================
// Use case : créer un établissement depuis le portail créatrice.
// -----------------------------------------------------------------------------
// Sécurité : le code créateur est revérifié à chaque création, puis un code
// gérant propre à la nouvelle fiche est immédiatement enregistré (empreinte
// salée seulement). Les champs sont nettoyés par `InputSanitizer`.
//
// La fiche créée n'est PAS certifiée ouverte : `isVerified` reste à `false`,
// la note démarre à 0 et les horaires sont vides. L'UI l'indique explicitement.
// =============================================================================

// Égalité des paramètres.
import 'package:equatable/equatable.dart';

// Either.
import 'package:fpdart/fpdart.dart';

// Constantes, erreurs et nettoyage.
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/koudougou_reference.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/security/pin_auth.dart';

// Contrat et horloge.
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/app_clock.dart';

// Entités et repository du catalogue.
import '../../../restaurants/domain/entities/menu_item.dart';
import '../../../restaurants/domain/entities/opening_hours.dart';
import '../../../restaurants/domain/entities/restaurant.dart';
import '../../../restaurants/domain/entities/restaurant_category.dart';
import '../../../restaurants/domain/repositories/restaurant_repository.dart';

// Vérification du PIN.
import 'verify_creator_pin.dart';

/// Paramètres de création d'un établissement.
final class CreateEstablishmentParams extends Equatable {
  /// Construit des paramètres typés.
  const CreateEstablishmentParams({
    required this.creatorPin,
    required this.name,
    required this.category,
    required this.sector,
    required this.landmark,
    required this.phone,
    required this.address,
    required this.ownerCode,
  });

  /// Code créateur, revérifié avant écriture.
  final String creatorPin;

  /// Nom commercial.
  final String name;

  /// Catégorie d'établissement.
  final RestaurantCategory category;

  /// Secteur administratif de Koudougou.
  final String sector;

  /// Repère de proximité.
  final String landmark;

  /// Téléphone au format burkinabè.
  final String phone;

  /// Adresse descriptive.
  final String address;

  /// Code qui sera attribué au gérant de cette fiche.
  final String ownerCode;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[
    name,
    category,
    sector,
    landmark,
    phone,
    address,
  ];
}

/// Crée une fiche locale et son accès gérant.
final class CreateEstablishment
    implements UseCase<Restaurant, CreateEstablishmentParams> {
  /// Injection du repository, du PIN, du coffre et de l'horloge.
  const CreateEstablishment(
    this._repository,
    this._verifyPin,
    this._auth,
    this._clock,
  );

  // Dépendances uniques.
  final RestaurantRepository _repository;
  final VerifyCreatorPin _verifyPin;
  final PinAuthService _auth;
  final AppClock _clock;

  /// Authentifie, valide, enregistre le code gérant puis la fiche.
  @override
  Future<Either<Failure, Restaurant>> call(
    CreateEstablishmentParams params,
  ) async {
    // Le PIN est vérifié de façon asynchrone : on attend l'Either avant de
    // décider si la création est autorisée.
    final Either<Failure, bool> verification = await _verifyPin(
      params.creatorPin,
    );
    return verification.fold<Future<Either<Failure, Restaurant>>>(
      (Failure failure) async => left<Failure, Restaurant>(failure),
      (bool isValid) async {
        // Un code incorrect est une tentative d'accès, pas une simple erreur
        // de saisie : on renvoie une Failure de sécurité explicite.
        if (!isValid) {
          return left<Failure, Restaurant>(
            const SecurityFailure(
              message: 'Code créateur incorrect. Création refusée.',
            ),
          );
        }
        return _create(params);
      },
    );
  }

  /// Valide les champs puis construit l'entité.
  Future<Either<Failure, Restaurant>> _create(
    CreateEstablishmentParams params,
  ) async {
    final String name = InputSanitizer.sanitizeShortLabel(
      params.name,
      maxLength: AppConstants.shortTextMaxLength,
    );
    final String sector = InputSanitizer.sanitizeShortLabel(
      params.sector,
      maxLength: 40,
    );
    final String landmark = InputSanitizer.sanitizeShortLabel(
      params.landmark,
      maxLength: 80,
    );
    final String address = InputSanitizer.sanitizeShortLabel(
      params.address,
      maxLength: 200,
    );
    final String? phone = InputSanitizer.sanitizePhoneNumber(params.phone);

    if (name.isEmpty) {
      return left(
        const ValidationFailure(message: 'Nom invalide.', field: 'name'),
      );
    }
    if (!KoudougouReference.sectors.contains(sector)) {
      return left(
        const ValidationFailure(
          message: 'Choisissez un secteur de Koudougou.',
          field: 'sector',
        ),
      );
    }
    if (landmark.isEmpty) {
      return left(
        const ValidationFailure(message: 'Repère invalide.', field: 'landmark'),
      );
    }
    if (phone == null) {
      return left(
        const ValidationFailure(
          message: 'Numéro burkinabè invalide.',
          field: 'phone',
        ),
      );
    }

    final DateTime now = _clock.now();
    final String id = InputSanitizer.sanitizeIdentifier(
      'local_${now.microsecondsSinceEpoch}',
    );
    if (id.isEmpty) {
      return left(
        const ValidationFailure(message: 'Identifiant invalide.', field: 'id'),
      );
    }

    // Le code gérant est enregistré AVANT la fiche : ainsi, si l'écriture du
    // catalogue échoue, il n'existe aucun établissement sans accès gérant.
    final Either<Failure, Unit> codeResult = await _auth.setOwnerCode(
      restaurantId: id,
      code: params.ownerCode.trim(),
    );
    final Failure? codeFailure = codeResult.fold(
      (Failure failure) => failure,
      (Unit _) => null,
    );
    if (codeFailure != null) {
      return left(codeFailure);
    }

    final Restaurant restaurant = Restaurant(
      id: id,
      name: name,
      tagline: 'Fiche ajoutée localement',
      description:
          'Établissement ajouté depuis l’espace administration. '
          'Informations à confirmer sur place avant toute visite.',
      category: params.category,
      sector: sector,
      landmark: landmark,
      address: address,
      // Coordonnées au centre-ville : l'application ne fabrique PAS de GPS
      // précis. Un repère textuel est fourni pour compenser cette limite.
      latitude: AppConstants.cityLatitude,
      longitude: AppConstants.cityLongitude,
      phone: phone,
      whatsappPhone: phone,
      rating: 0,
      reviewCount: 0,
      priceRange: PriceRange.fromAveragePrice(0),
      averagePriceFcfa: 0,
      ambiance: const AmbianceInfo(score: 0, musicGenre: '', note: ''),
      openingHours: OpeningHours(
        weekly: <int, DaySchedule?>{
          for (var weekday = 1; weekday <= 7; weekday++) weekday: null,
        },
      ),
      menu: const <MenuItem>[],
      isVerified: false,
      verifiedAt: null,
      updatedAt: now,
      paymentMethods: const <PaymentMethod>{PaymentMethod.cash},
      amenities: const <RestaurantAmenity>{},
      photoAsset: null,
      liveBraise: null,
    );

    return _repository.addRestaurant(restaurant);
  }
}
