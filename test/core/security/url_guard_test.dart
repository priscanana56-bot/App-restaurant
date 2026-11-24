// =============================================================================
// Tests du garde-fou d'ouverture de liens.
// -----------------------------------------------------------------------------
// Aucun plugin natif n'est appelé : une passerelle factice enregistre les URI
// réellement transmises, ce qui permet de vérifier la politique de sécurité.
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// `Either` pour lire le résultat fonctionnel.
import 'package:fpdart/fpdart.dart';

// Failures attendues.
import 'package:koudougou_gourmet/core/error/failures.dart';

// Contrat de la passerelle.
import 'package:koudougou_gourmet/core/security/url_launcher_gateway.dart';

// Service testé.
import 'package:koudougou_gourmet/core/security/url_guard.dart';

/// Passerelle factice : aucune application n'est ouverte pendant les tests.
final class _FakeUrlLauncherGateway implements UrlLauncherGateway {
  // Configure la réponse de `canLaunch`.
  _FakeUrlLauncherGateway({
    this.canLaunchResult = true,
    this.launchResult = true,
    this.throwOnLaunch = false,
  });

  // Valeur renvoyée par `canLaunch`.
  final bool canLaunchResult;

  // Valeur renvoyée par `launch`.
  final bool launchResult;

  // Simule une erreur native.
  final bool throwOnLaunch;

  // URIs effectivement transmises au plugin.
  final List<Uri> launchedUris = <Uri>[];

  /// Renvoie la valeur configurée.
  @override
  Future<bool> canLaunch(Uri uri) async {
    // Simulation optionnelle d'un crash plugin.
    if (throwOnLaunch) {
      throw StateError('plugin indisponible');
    }
    return canLaunchResult;
  }

  /// Enregistre l'URI et renvoie la valeur configurée.
  @override
  Future<bool> launch(Uri uri) async {
    // Simulation d'une erreur native au moment de l'ouverture.
    if (throwOnLaunch) {
      throw StateError('ouverture impossible');
    }
    launchedUris.add(uri);
    return launchResult;
  }
}

/// Extrait la Failure d'un résultat, ou `null` en cas de succès.
Failure? _failureOf(Either<Failure, Unit> result) {
  // `match` force un retour typé : aucun `dynamic` dans les tests.
  return result.match<Failure?>((Failure failure) => failure, (_) => null);
}

/// Point d'entrée des tests.
void main() {
  // ---------------------------------------------------------------------------
  // WhatsApp
  // ---------------------------------------------------------------------------
  group('UrlGuard.openWhatsApp', () {
    test(
      'construit une URL wa.me avec message nettoyé et numéro validé',
      () async {
        // Passerelle qui accepte tout.
        final _FakeUrlLauncherGateway gateway = _FakeUrlLauncherGateway();
        final UrlGuard guard = UrlGuard(gateway: gateway);

        // Message contenant des balises et un numéro local.
        final Either<Failure, Unit> result = await guard.openWhatsApp(
          phone: '70 12 34 56',
          message: '<b>Bonjour</b> depuis Koudougou',
        );

        // Succès métier.
        expect(result.isRight(), isTrue);

        // Une seule ouverture, vers le bon hôte.
        final Uri launched = gateway.launchedUris.single;
        expect(launched.scheme, 'https');
        expect(launched.host, 'wa.me');
        expect(launched.path, '/22670123456');

        // Le texte est décodé proprement et les balises ont disparu.
        expect(launched.queryParameters['text'], contains('Bonjour'));
        expect(launched.queryParameters['text'], isNot(contains('<b>')));
      },
    );

    test(
      'accepte un message WhatsApp multi-lignes (récapitulatif de commande)',
      () async {
        // Régression : le message du récapitulatif contient des sauts de ligne,
        // encodés `%0A` dans l'URL. Le garde-fou ne doit plus les rejeter.
        final _FakeUrlLauncherGateway gateway = _FakeUrlLauncherGateway();
        final UrlGuard guard = UrlGuard(gateway: gateway);
        const String message =
            'Bonjour Snack Time,\n'
            'Je souhaite passer une commande :\n'
            '• 2 × Sandwich (1 400 FCFA)\n'
            '\n'
            'Total : 1 400 FCFA\n'
            'Merci de confirmer la disponibilité.';

        final Either<Failure, Unit> result = await guard.openWhatsApp(
          phone: '+226 73 46 12 47',
          message: message,
        );

        expect(result.isRight(), isTrue);
        final Uri launched = gateway.launchedUris.single;
        expect(launched.queryParameters['text'], contains('\n'));
        expect(launched.queryParameters['text'], contains('2 × Sandwich'));
      },
    );

    test('refuse un numéro invalide sans appeler le plugin', () async {
      // Numéro trop court.
      final _FakeUrlLauncherGateway gateway = _FakeUrlLauncherGateway();
      final UrlGuard guard = UrlGuard(gateway: gateway);

      // Appel avec un numéro invalide.
      final Either<Failure, Unit> result = await guard.openWhatsApp(
        phone: '123',
        message: 'Bonjour',
      );

      // Failure de validation et aucune tentative d'ouverture.
      expect(_failureOf(result), isA<ValidationFailure>());
      expect(gateway.launchedUris, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Liste blanche d'hôtes
  // ---------------------------------------------------------------------------
  group('UrlGuard.openRaw', () {
    test(
      'refuse encore une URL saisie avec un contrôle encodé (%0A)',
      () async {
        // L'assouplissement ne s'applique qu'aux URI internes déjà nettoyées :
        // une URL externe contenant `%0A` reste rejetée avant tout lancement.
        final _FakeUrlLauncherGateway gateway = _FakeUrlLauncherGateway();
        final UrlGuard guard = UrlGuard(gateway: gateway);

        final Either<Failure, Unit> result = await guard.openRaw(
          'https://wa.me/22670123456?text=Bonjour%0AAdmin',
        );

        expect(_failureOf(result), isA<SecurityFailure>());
        expect(gateway.launchedUris, isEmpty);
      },
    );

    test('refuse un domaine non autorisé', () async {
      // Hôte valide techniquement mais absent de la liste blanche.
      final _FakeUrlLauncherGateway gateway = _FakeUrlLauncherGateway();
      final UrlGuard guard = UrlGuard(gateway: gateway);

      // Tentative de hameçonnage.
      final Either<Failure, Unit> result = await guard.openRaw(
        'https://evil.example/phish',
      );

      // Blocage de sécurité, aucune ouverture.
      expect(_failureOf(result), isA<SecurityFailure>());
      expect(gateway.launchedUris, isEmpty);
    });

    test('refuse les schémas non autorisés', () async {
      // `javascript:` ne doit jamais atteindre le plugin.
      final _FakeUrlLauncherGateway gateway = _FakeUrlLauncherGateway();
      final UrlGuard guard = UrlGuard(gateway: gateway);

      // Injection de script.
      final Either<Failure, Unit> result = await guard.openRaw(
        'javascript:alert(1)',
      );

      // Rejet immédiat.
      expect(_failureOf(result), isA<SecurityFailure>());
      expect(gateway.launchedUris, isEmpty);
    });

    test('accepte une URL Google Maps valide', () async {
      // Hôte autorisé et coordonnées correctes.
      final _FakeUrlLauncherGateway gateway = _FakeUrlLauncherGateway();
      final UrlGuard guard = UrlGuard(gateway: gateway);

      // Recherche cartographique.
      final Either<Failure, Unit> result = await guard.openMaps(
        latitude: 12.2528,
        longitude: -2.3669,
        label: 'Maquis Le Baobab',
      );

      // Succès et hôte attendu.
      expect(result.isRight(), isTrue);
      expect(gateway.launchedUris.single.host, 'www.google.com');
    });
  });

  // ---------------------------------------------------------------------------
  // Téléphone
  // ---------------------------------------------------------------------------
  group('UrlGuard appels', () {
    test('normalise le numéro dans une URI tel:', () async {
      // Numéro local.
      final _FakeUrlLauncherGateway gateway = _FakeUrlLauncherGateway();
      final UrlGuard guard = UrlGuard(gateway: gateway);

      // Appel.
      final Either<Failure, Unit> result = await guard.openPhoneCall(
        '70 12 34 56',
      );

      // URI composée à partir du numéro normalisé.
      expect(result.isRight(), isTrue);
      expect(gateway.launchedUris.single.scheme, 'tel');
      expect(gateway.launchedUris.single.path, '+22670123456');
    });

    test('refuse un numéro invalide', () async {
      // Numéro incomplet.
      final _FakeUrlLauncherGateway gateway = _FakeUrlLauncherGateway();
      final UrlGuard guard = UrlGuard(gateway: gateway);

      // Aucun lancement attendu.
      final Either<Failure, Unit> result = await guard.openPhoneCall('12');
      expect(_failureOf(result), isA<ValidationFailure>());
      expect(gateway.launchedUris, isEmpty);
    });

    test('accepte un numéro d’urgence court', () async {
      // Service de police.
      final _FakeUrlLauncherGateway gateway = _FakeUrlLauncherGateway();
      final UrlGuard guard = UrlGuard(gateway: gateway);

      // Appel d'urgence.
      final Either<Failure, Unit> result = await guard.openEmergencyCall('17');
      expect(result.isRight(), isTrue);
      expect(gateway.launchedUris.single.path, '17');
    });
  });

  // ---------------------------------------------------------------------------
  // Robustesse
  // ---------------------------------------------------------------------------
  group('UrlGuard robustesse', () {
    test(
      'renvoie une Failure si aucune application ne peut ouvrir le lien',
      () async {
        // `canLaunch` faux.
        final _FakeUrlLauncherGateway gateway = _FakeUrlLauncherGateway(
          canLaunchResult: false,
        );
        final UrlGuard guard = UrlGuard(gateway: gateway);

        // Résultat attendu : erreur de lien externe.
        final Either<Failure, Unit> result = await guard.openPhoneCall(
          '70 12 34 56',
        );
        expect(_failureOf(result), isA<ExternalLinkFailure>());
      },
    );

    test('renvoie une Failure si le plugin refuse l’ouverture', () async {
      // `launch` renvoie false sans lever d'exception.
      final _FakeUrlLauncherGateway gateway = _FakeUrlLauncherGateway(
        launchResult: false,
      );
      final UrlGuard guard = UrlGuard(gateway: gateway);

      // Résultat attendu : erreur de lien externe.
      final Either<Failure, Unit> result = await guard.openPhoneCall(
        '70 12 34 56',
      );
      expect(_failureOf(result), isA<ExternalLinkFailure>());
    });

    test('capture les erreurs natives du plugin', () async {
      // Plugin qui lève une exception.
      final _FakeUrlLauncherGateway gateway = _FakeUrlLauncherGateway(
        throwOnLaunch: true,
      );
      final UrlGuard guard = UrlGuard(gateway: gateway);

      // L'exception ne doit pas remonter : elle devient une Failure.
      final Either<Failure, Unit> result = await guard.openPhoneCall(
        '70 12 34 56',
      );
      expect(_failureOf(result), isA<ExternalLinkFailure>());
    });

    test('refuse des coordonnées hors bornes', () async {
      // Latitude impossible.
      final _FakeUrlLauncherGateway gateway = _FakeUrlLauncherGateway();
      final UrlGuard guard = UrlGuard(gateway: gateway);

      // Validation avant toute construction d'URL.
      final Either<Failure, Unit> result = await guard.openMaps(
        latitude: 120,
        longitude: 0,
      );
      expect(_failureOf(result), isA<ValidationFailure>());
      expect(gateway.launchedUris, isEmpty);
    });
  });
}
