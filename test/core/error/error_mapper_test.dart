// =============================================================================
// Tests du traducteur Exceptions -> Failures.
// -----------------------------------------------------------------------------
// Vérifie qu'aucun message technique brut ne fuite vers l'utilisateur.
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Exceptions techniques.
import 'package:koudougou_gourmet/core/error/exceptions.dart';

// Failures métier.
import 'package:koudougou_gourmet/core/error/failures.dart';

// Traducteur testé.
import 'package:koudougou_gourmet/core/error/error_mapper.dart';

/// Point d'entrée des tests.
void main() {
  // Instance sans état.
  const ErrorMapper mapper = ErrorMapper();

  group('ErrorMapper', () {
    test('convertit une erreur serveur sans fuiter le message technique', () {
      // Statut 500 et message interne sensible.
      final Failure failure = mapper.map(
        const ServerException('SQLSTATE 42P01', statusCode: 500),
      );

      // Type et message utilisateur attendus.
      expect(failure, isA<ServerFailure>());
      expect(failure.message, isNot(contains('SQLSTATE')));
      expect((failure as ServerFailure).statusCode, 500);
    });

    test('conserve le champ et le message d’une erreur de validation', () {
      // Message rédigé par l'application, donc sûr à afficher.
      final Failure failure = mapper.map(
        const ValidationException('Numéro invalide.', field: 'phone'),
      );

      // La Failure conserve les deux informations.
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Numéro invalide.');
      expect((failure as ValidationFailure).field, 'phone');
    });

    test('conserve le caractère définitif d’un refus de permission', () {
      // Refus définitif de la localisation.
      final Failure failure = mapper.map(
        const PermissionException(
          'Localisation refusée.',
          isPermanentlyDenied: true,
        ),
      );

      // L'UI pourra afficher « Ouvrir les réglages ».
      expect(failure, isA<PermissionFailure>());
      expect((failure as PermissionFailure).isPermanentlyDenied, isTrue);
    });

    test('traduit une erreur inconnue en UnknownFailure', () {
      // Erreur non applicative (bug, plugin tiers).
      final Failure failure = mapper.map(StateError('boom'));

      // Repli générique.
      expect(failure, isA<UnknownFailure>());
    });

    test('les Failures sont comparables par valeur', () {
      // Deux erreurs identiques doivent être égales pour Equatable/BLoC.
      expect(const UnknownFailure(), const UnknownFailure());
      expect(const UnknownFailure(), isNot(const NetworkFailure()));
    });
  });
}
