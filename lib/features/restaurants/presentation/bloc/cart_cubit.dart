// =============================================================================
// Panier local (commande WhatsApp et partage d'addition).
// -----------------------------------------------------------------------------
// Le panier ne contient QUE des quantités indexées par identifiant de plat :
// les `MenuItem` restent dans l'entité `Restaurant`, seule source de vérité des
// prix. Cela évite toute duplication et tout risque d'incohérence de prix.
// =============================================================================

// Equatable pour comparer deux états de panier.
import 'package:equatable/equatable.dart';

// Cubit : état réactif minimal.
import 'package:flutter_bloc/flutter_bloc.dart';

// Bornes métier (quantité max, taille de groupe max).
import '../../../../core/constants/app_constants.dart';

/// État du panier : quantités + nombre de convives.
final class CartState extends Equatable {
  /// Construit un panier vide avec deux convives par défaut.
  const CartState({
    this.quantities = const <String, int>{},
    this.partySize = 2,
    this.deliveryRequested = false,
  });

  /// Quantités par identifiant de plat (jamais de quantité nulle stockée).
  final Map<String, int> quantities;

  /// Nombre de convives pour le partage d'addition.
  final int partySize;

  /// `true` si l'utilisateur souhaite être livré (devis affiché séparément).
  final bool deliveryRequested;

  /// Nombre total d'articles.
  int get itemCount =>
      quantities.values.fold(0, (int sum, int qty) => sum + qty);

  /// `true` si aucun article n'est sélectionné.
  bool get isEmpty => quantities.isEmpty;

  /// Quantité d'un plat donné (0 s'il est absent).
  int quantityOf(String itemId) => quantities[itemId] ?? 0;

  /// Copie modifiée de l'état.
  CartState copyWith({
    Map<String, int>? quantities,
    int? partySize,
    bool? deliveryRequested,
  }) {
    return CartState(
      quantities: quantities ?? this.quantities,
      partySize: partySize ?? this.partySize,
      deliveryRequested: deliveryRequested ?? this.deliveryRequested,
    );
  }

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[
    quantities,
    partySize,
    deliveryRequested,
  ];
}

/// Cubit du panier.
final class CartCubit extends Cubit<CartState> {
  /// Démarre avec un panier vide.
  CartCubit() : super(const CartState());

  /// Ajoute une unité du plat [itemId] (dans la limite autorisée).
  void increment(String itemId) {
    // Quantité courante et garde-fou anti-abus.
    final int current = state.quantityOf(itemId);
    if (current >= AppConstants.maxItemQuantity) {
      return;
    }

    // Copie mutable pour ne jamais modifier la map de l'état précédent.
    final Map<String, int> next = Map<String, int>.of(state.quantities)
      ..[itemId] = current + 1;

    // Publication du nouvel état.
    emit(state.copyWith(quantities: next));
  }

  /// Retire une unité du plat [itemId] (le retire à zéro).
  void decrement(String itemId) {
    // Rien à retirer si le plat n'est pas dans le panier.
    final int current = state.quantityOf(itemId);
    if (current <= 0) {
      return;
    }

    // Copie mutable puis mise à jour ou suppression de la ligne.
    final Map<String, int> next = Map<String, int>.of(state.quantities);
    if (current == 1) {
      next.remove(itemId);
    } else {
      next[itemId] = current - 1;
    }

    // Publication du nouvel état.
    emit(state.copyWith(quantities: next));
  }

  /// Vide le panier (les convives sont conservés).
  void clear() => emit(state.copyWith(quantities: const <String, int>{}));

  /// Fixe le nombre de convives, borné entre 1 et [AppConstants.maxPartySize].
  void setPartySize(int value) {
    // Bornage explicite (évite un `num` issu de `clamp`).
    final int bounded = value < 1
        ? 1
        : (value > AppConstants.maxPartySize
              ? AppConstants.maxPartySize
              : value);

    // Publication.
    emit(state.copyWith(partySize: bounded));
  }

  /// Active ou désactive la livraison pour la commande en cours.
  void setDeliveryRequested(bool value) {
    if (state.deliveryRequested == value) {
      return;
    }
    emit(state.copyWith(deliveryRequested: value));
  }
}
