// =============================================================================
// Cubit de l'espace administration (ex-portail créatrice).
// -----------------------------------------------------------------------------
// Le code PIN n'est jamais stocké dans l'état : il est saisi dans la page,
// transmis aux use cases, puis remplacé par un booléen « accès autorisé ».
// L'attribution d'un code gérant à une fiche existante exige elle aussi une
// ressaisie du PIN administrateur, même si l'écran est déjà déverrouillé.
// =============================================================================

// Cubit et Either.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

// Erreurs métier.
import '../../../../core/error/failures.dart';

// Entité et chargement du catalogue.
import '../../../restaurants/domain/entities/restaurant.dart';
import '../../../restaurants/domain/entities/restaurant_category.dart';
import '../../../restaurants/domain/usecases/get_restaurants.dart';

// Use cases.
import '../../domain/usecases/assign_owner_code.dart';
import '../../domain/usecases/create_establishment.dart';
import '../../domain/usecases/has_creator_pin.dart';
import '../../domain/usecases/set_creator_pin.dart';
import '../../domain/usecases/verify_creator_pin.dart';

// État.
import 'creator_portal_state.dart';

/// Pilote l'espace administration.
final class CreatorPortalCubit extends Cubit<CreatorPortalState> {
  /// Injection des six dépendances de l'espace.
  CreatorPortalCubit(
    this._hasPin,
    this._setPin,
    this._verifyPin,
    this._create,
    this._assignCode,
    this._getRestaurants,
  ) : super(const CreatorPortalState());

  // Dépendances uniques.
  final HasCreatorPin _hasPin;
  final SetCreatorPin _setPin;
  final VerifyCreatorPin _verifyPin;
  final CreateEstablishment _create;
  final AssignOwnerCode _assignCode;
  final GetRestaurants _getRestaurants;

  /// Détermine l'écran à afficher et charge les fiches attribuables.
  Future<void> load() async {
    emit(
      state.copyWith(
        isBusy: true,
        failure: null,
        infoMessage: null,
        phase: CreatorPortalPhase.initial,
      ),
    );

    final Either<Failure, bool> pinResult = await _hasPin();

    // Le catalogue est utile pour l'attribution mais n'est pas une condition
    // d'accès : une panne du cache ne doit pas bloquer la création d'un PIN.
    final Either<Failure, List<Restaurant>> catalogResult =
        await _getRestaurants(const GetRestaurantsParams());
    final List<Restaurant> restaurants = catalogResult.fold(
      (Failure _) => const <Restaurant>[],
      (List<Restaurant> value) => value,
    );

    pinResult.fold(
      (failure) => emit(state.copyWith(isBusy: false, failure: failure)),
      (hasPin) => emit(
        state.copyWith(
          isBusy: false,
          phase: hasPin
              ? CreatorPortalPhase.login
              : CreatorPortalPhase.setupPin,
          restaurants: restaurants,
          selectedRestaurantId: restaurants.isEmpty
              ? null
              : restaurants.first.id,
        ),
      ),
    );
  }

  /// Enregistre un nouveau PIN après confirmation.
  Future<void> setPin({
    required String pin,
    required String confirmation,
  }) async {
    // La confirmation est vérifiée côté Présentation : c'est une ergonomie,
    // pas une règle de sécurité (le service valide la forme du code).
    if (pin != confirmation) {
      emit(
        state.copyWith(
          failure: const ValidationFailure(
            message: 'Les deux codes ne correspondent pas.',
            field: 'confirmation',
          ),
        ),
      );
      return;
    }
    emit(state.copyWith(isBusy: true, failure: null, infoMessage: null));

    final result = await _setPin(pin);
    result.fold(
      (failure) => emit(state.copyWith(isBusy: false, failure: failure)),
      (_) => emit(
        state.copyWith(
          isBusy: false,
          phase: CreatorPortalPhase.login,
          infoMessage: 'Code administrateur enregistré. Connectez-vous.',
        ),
      ),
    );
  }

  /// Vérifie le PIN et ouvre le formulaire de création.
  Future<void> login(String pin) async {
    emit(state.copyWith(isBusy: true, failure: null, infoMessage: null));
    final result = await _verifyPin(pin);
    result.fold(
      (failure) => emit(state.copyWith(isBusy: false, failure: failure)),
      (isValid) => emit(
        isValid
            ? state.copyWith(
                isBusy: false,
                phase: CreatorPortalPhase.unlocked,
                infoMessage: 'Espace administration déverrouillé.',
              )
            : state.copyWith(
                isBusy: false,
                failure: const SecurityFailure(
                  message: 'Code administrateur incorrect.',
                ),
              ),
      ),
    );
  }

  /// Reverrouille l'espace après une interruption ou un geste explicite.
  void lock() {
    if (state.phase != CreatorPortalPhase.unlocked) {
      return;
    }
    emit(
      state.copyWith(
        phase: CreatorPortalPhase.login,
        isBusy: false,
        failure: null,
        infoMessage: 'Espace administration verrouillé.',
      ),
    );
  }

  /// Sélectionne la fiche dont on veut attribuer le code gérant.
  void selectRestaurant(String restaurantId) {
    emit(state.copyWith(selectedRestaurantId: restaurantId, failure: null));
  }

  /// Crée un établissement avec son code gérant.
  Future<void> create({
    required String creatorPin,
    required String name,
    required RestaurantCategory category,
    required String sector,
    required String landmark,
    required String phone,
    required String address,
    required String ownerCode,
  }) async {
    if (state.phase != CreatorPortalPhase.unlocked || state.isBusy) {
      return;
    }
    emit(state.copyWith(isBusy: true, failure: null, infoMessage: null));

    final result = await _create(
      CreateEstablishmentParams(
        creatorPin: creatorPin,
        name: name,
        category: category,
        sector: sector,
        landmark: landmark,
        phone: phone,
        address: address,
        ownerCode: ownerCode,
      ),
    );
    result.fold(
      (failure) => emit(state.copyWith(isBusy: false, failure: failure)),
      (restaurant) => emit(
        state.copyWith(
          isBusy: false,
          createdRestaurant: restaurant,
          infoMessage: 'Établissement ajouté. Transmettez le code gérant au responsable.',
        ),
      ),
    );
  }

  /// Attribue ou réinitialise le code gérant d'une fiche existante.
  Future<void> assignCode({
    required String adminPin,
    required String restaurantId,
    required String code,
  }) async {
    if (state.phase != CreatorPortalPhase.unlocked || state.isBusy) {
      return;
    }
    emit(state.copyWith(isBusy: true, failure: null, infoMessage: null));

    final result = await _assignCode(
      AssignOwnerCodeParams(
        adminPin: adminPin,
        restaurantId: restaurantId,
        code: code,
      ),
    );
    result.fold(
      (failure) => emit(state.copyWith(isBusy: false, failure: failure)),
      (_) {
        // Recherche purement descriptive : aucun secret n'est affiché.
        String label = restaurantId;
        for (final Restaurant restaurant in state.restaurants) {
          if (restaurant.id == restaurantId) {
            label = restaurant.name;
            break;
          }
        }
        emit(
          state.copyWith(
            isBusy: false,
            infoMessage: 'Code gérant attribué à « $label ».',
          ),
        );
      },
    );
  }
}
