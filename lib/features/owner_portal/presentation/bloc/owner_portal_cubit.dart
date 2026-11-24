// =============================================================================
// Cubit du portail gérant.
// -----------------------------------------------------------------------------
// Le code gérant n'est PAS conservé dans l'état : il reste dans le contrôleur
// de la page et est transmis explicitement à chaque opération. Il n'apparaît
// donc ni dans les comparaisons d'état, ni dans les journaux de debug.
// Le déverrouillage est volontairement volatile : passer en arrière-plan ou
// changer d'établissement le fait expirer immédiatement.
// =============================================================================

// `unawaited` pour la vérification d'existence du code.
import 'dart:async';

// Cubit et Either.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

// Erreurs métier.
import '../../../../core/error/failures.dart';

// Entités.
import '../../../restaurants/domain/entities/menu_item.dart';
import '../../../restaurants/domain/entities/restaurant.dart';

// Use cases.
import '../../domain/usecases/add_menu_item.dart';
import '../../domain/usecases/get_owner_restaurants.dart';
import '../../domain/usecases/has_owner_code.dart';
import '../../domain/usecases/remove_menu_item.dart';
import '../../domain/usecases/verify_owner_code.dart';

// État.
import 'owner_portal_state.dart';

/// Pilote le portail gérant.
final class OwnerPortalCubit extends Cubit<OwnerPortalState> {
  /// Injection des cinq use cases du portail.
  OwnerPortalCubit(
    this._getRestaurants,
    this._verifyCode,
    this._addItem,
    this._removeItem,
    this._hasCode,
  ) : super(const OwnerPortalState());

  // Dépendances uniques.
  final GetOwnerRestaurants _getRestaurants;
  final VerifyOwnerCode _verifyCode;
  final AddMenuItem _addItem;
  final RemoveMenuItem _removeItem;
  final HasOwnerCode _hasCode;

  /// Charge le catalogue local.
  ///
  /// [initialRestaurantId] permet à la fiche détaillée d'ouvrir directement le
  /// bon établissement via `/owner`, sans laisser l'utilisateur le rechercher.
  Future<void> load({String? initialRestaurantId}) async {
    if (state.status == OwnerPortalStatus.loading) {
      return;
    }
    emit(state.copyWith(status: OwnerPortalStatus.loading, failure: null));

    final result = await _getRestaurants();
    result.fold(
      (failure) => emit(
        state.copyWith(status: OwnerPortalStatus.failure, failure: failure),
      ),
      (restaurants) {
        // La fiche demandée est prioritaire ; à défaut, la première du catalogue.
        String? selected;
        if (initialRestaurantId != null &&
            restaurants.any(
              (Restaurant restaurant) => restaurant.id == initialRestaurantId,
            )) {
          selected = initialRestaurantId;
        } else {
          selected = restaurants.isEmpty ? null : restaurants.first.id;
        }
        emit(
          state.copyWith(
            status: OwnerPortalStatus.ready,
            restaurants: restaurants,
            selectedRestaurantId: selected,
            selectedHasCode: null,
          ),
        );
        if (selected != null) {
          unawaited(_refreshCodeStatus(selected));
        }
      },
    );
  }

  /// Sélectionne un établissement et verrouille à nouveau l'accès.
  void selectRestaurant(String restaurantId) {
    emit(
      state.copyWith(
        selectedRestaurantId: restaurantId,
        selectedHasCode: null,
        isUnlocked: false,
        failure: null,
        infoMessage: null,
      ),
    );
    unawaited(_refreshCodeStatus(restaurantId));
  }

  /// Verrouille immédiatement l'accès (bouton explicite ou arrière-plan).
  void lock() {
    if (!state.isUnlocked) {
      return;
    }
    emit(
      state.copyWith(
        isUnlocked: false,
        isBusy: false,
        failure: null,
        infoMessage: 'Accès gérant verrouillé.',
      ),
    );
  }

  /// Vérifie si la fiche sélectionnée possède déjà un code gérant.
  Future<void> _refreshCodeStatus(String restaurantId) async {
    final Either<Failure, bool> result = await _hasCode(restaurantId);
    // Évite d'afficher le statut d'une fiche abandonnée entre-temps.
    if (isClosed || state.selectedRestaurantId != restaurantId) {
      return;
    }
    result.fold(
      (Failure _) => emit(state.copyWith(selectedHasCode: null)),
      (bool hasCode) => emit(state.copyWith(selectedHasCode: hasCode)),
    );
  }

  /// Vérifie le code de l'établissement sélectionné.
  Future<void> unlock(String code) async {
    final String? id = state.selectedRestaurantId;
    if (id == null) {
      emit(
        state.copyWith(
          failure: const ValidationFailure(
            message: 'Sélectionnez d’abord un établissement.',
            field: 'restaurantId',
          ),
        ),
      );
      return;
    }
    if (state.isBusy) {
      return;
    }
    emit(state.copyWith(isBusy: true, failure: null, infoMessage: null));

    final result = await _verifyCode(
      VerifyOwnerCodeParams(restaurantId: id, code: code),
    );
    result.fold(
      (failure) => emit(state.copyWith(isBusy: false, failure: failure)),
      (isValid) => emit(
        isValid
            ? state.copyWith(
                isBusy: false,
                isUnlocked: true,
                selectedHasCode: true,
                infoMessage: 'Accès gérant autorisé.',
              )
            : state.copyWith(
                isBusy: false,
                isUnlocked: false,
                failure: const SecurityFailure(
                  message: 'Code gérant incorrect.',
                ),
              ),
      ),
    );
  }

  /// Ajoute un plat après nouvelle vérification du code.
  Future<void> addDish({
    required String code,
    required String name,
    required String description,
    required MenuSection section,
    required int priceFcfa,
    required String portionLabel,
    required int preparationMinutes,
    bool isAvailable = true,
    bool isSignature = false,
  }) async {
    final String? id = state.selectedRestaurantId;
    if (id == null || !state.isUnlocked || state.isBusy) {
      return;
    }
    emit(state.copyWith(isBusy: true, failure: null, infoMessage: null));

    final result = await _addItem(
      AddMenuItemParams(
        restaurantId: id,
        code: code,
        name: name,
        description: description,
        section: section,
        priceFcfa: priceFcfa,
        portionLabel: portionLabel,
        preparationMinutes: preparationMinutes,
        isAvailable: isAvailable,
        isSignature: isSignature,
      ),
    );
    _applyWriteResult(result, 'Plat ajouté au menu.');
  }

  /// Retire un plat après nouvelle vérification du code.
  Future<void> removeDish({
    required String code,
    required String itemId,
  }) async {
    final String? id = state.selectedRestaurantId;
    if (id == null || !state.isUnlocked || state.isBusy) {
      return;
    }
    emit(state.copyWith(isBusy: true, failure: null, infoMessage: null));

    final result = await _removeItem(
      RemoveMenuItemParams(restaurantId: id, code: code, itemId: itemId),
    );
    _applyWriteResult(result, 'Plat retiré du menu.');
  }

  /// Remplace la fiche modifiée dans la liste et lève le busy.
  void _applyWriteResult(
    Either<Failure, Restaurant> result,
    String successMessage,
  ) {
    result.fold(
      (failure) => emit(state.copyWith(isBusy: false, failure: failure)),
      (updated) {
        final List<Restaurant> next = state.restaurants
            .map(
              (Restaurant restaurant) =>
                  restaurant.id == updated.id ? updated : restaurant,
            )
            .toList(growable: false);
        emit(
          state.copyWith(
            isBusy: false,
            restaurants: next,
            infoMessage: successMessage,
          ),
        );
      },
    );
  }
}
