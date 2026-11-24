// =============================================================================
// Tests du panier local (CartCubit).
// -----------------------------------------------------------------------------
// Le panier ne stocke que des quantités : ces tests vérifient l'ajout, le
// retrait, le vidage, le bornage des quantités et la taille du groupe.
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Bornes métier.
import 'package:koudougou_gourmet/core/constants/app_constants.dart';

// Cubit testé.
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/cart_cubit.dart';

/// Point d'entrée des tests.
void main() {
  group('CartCubit', () {
    test('démarre vide avec deux convives', () {
      final CartCubit cubit = CartCubit();
      addTearDown(cubit.close);

      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.itemCount, 0);
      expect(cubit.state.partySize, 2);
    });

    test('increment ajoute une unité puis decrement la retire', () {
      final CartCubit cubit = CartCubit();
      addTearDown(cubit.close);

      cubit.increment('dish-1');
      cubit.increment('dish-1');
      expect(cubit.state.quantityOf('dish-1'), 2);
      expect(cubit.state.itemCount, 2);
      expect(cubit.state.isEmpty, isFalse);

      cubit.decrement('dish-1');
      expect(cubit.state.quantityOf('dish-1'), 1);

      // Retour à zéro : la ligne disparaît complètement.
      cubit.decrement('dish-1');
      expect(cubit.state.quantityOf('dish-1'), 0);
      expect(cubit.state.quantities.containsKey('dish-1'), isFalse);
    });

    test('decrement sous zéro est sans effet', () {
      final CartCubit cubit = CartCubit();
      addTearDown(cubit.close);

      cubit.decrement('inconnu');
      expect(cubit.state.isEmpty, isTrue);
    });

    test('clear vide le panier mais conserve les convives', () {
      final CartCubit cubit = CartCubit();
      addTearDown(cubit.close);

      cubit.increment('dish-1');
      cubit.setPartySize(5);
      cubit.clear();

      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.partySize, 5);
    });

    test('increment est plafonné à la quantité maximale', () {
      final CartCubit cubit = CartCubit();
      addTearDown(cubit.close);

      // On dépasse volontairement la borne.
      for (var i = 0; i < AppConstants.maxItemQuantity + 5; i++) {
        cubit.increment('dish-1');
      }

      expect(cubit.state.quantityOf('dish-1'), AppConstants.maxItemQuantity);
    });

    test('setPartySize borne la valeur entre 1 et le maximum', () {
      final CartCubit cubit = CartCubit();
      addTearDown(cubit.close);

      cubit.setPartySize(0);
      expect(cubit.state.partySize, 1);

      cubit.setPartySize(1000);
      expect(cubit.state.partySize, AppConstants.maxPartySize);

      cubit.setPartySize(4);
      expect(cubit.state.partySize, 4);
    });
  });
}
