// =============================================================================
// Tests de la source distante HTTP.
// -----------------------------------------------------------------------------
// Aucun appel réseau réel : un `MockClient` (fourni par le paquet `http`)
// intercepte la requête. On vérifie à la fois la sécurité de l'URL, la
// construction de l'endpoint et la traduction de chaque échec en exception
// métier stable (jamais d'exception HTTP brute).
// =============================================================================

// Client HTTP et exception de transport.
import 'package:http/http.dart' as http;

// Client de test sans socket.
import 'package:http/testing.dart';

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Exceptions attendues.
import 'package:koudougou_gourmet/core/error/exceptions.dart';

// Source testée.
import 'package:koudougou_gourmet/features/restaurants/data/datasources/http_restaurant_remote_data_source.dart';

// Fixtures (catalogue JSON).
import '../support/fixtures.dart';

/// Construit une réponse 200 encodée en UTF-8 (accents inclus).
http.Response _jsonResponse(String body) => http.Response(
  body,
  200,
  headers: const <String, String>{
    'content-type': 'application/json; charset=utf-8',
  },
);

/// Point d'entrée des tests.
void main() {
  group('Validation de l’URL', () {
    test('refuse un schéma non HTTPS', () {
      // Une API en clair exposerait le trafic : refus immédiat.
      expect(
        () => HttpRestaurantRemoteDataSource(baseUrl: 'http://api.example.com'),
        throwsA(isA<SecurityException>()),
      );
    });

    test('refuse identifiants, query et fragment', () {
      // Ces éléments peuvent masquer une redirection ou une fuite de données.
      expect(
        () => HttpRestaurantRemoteDataSource(
          baseUrl: 'https://user:pass@api.example.com',
        ),
        throwsA(isA<SecurityException>()),
      );
      expect(
        () => HttpRestaurantRemoteDataSource(
          baseUrl: 'https://api.example.com?token=abc',
        ),
        throwsA(isA<SecurityException>()),
      );
      expect(
        () => HttpRestaurantRemoteDataSource(
          baseUrl: 'https://api.example.com#section',
        ),
        throwsA(isA<SecurityException>()),
      );
    });

    test('construit l’endpoint /restaurants sans double slash', () async {
      // Une URL avec slash final ne doit pas produire `//restaurants`.
      late Uri observed;
      final MockClient client = MockClient((http.Request request) async {
        observed = request.url;
        return _jsonResponse(sampleCatalogJson);
      });

      final HttpRestaurantRemoteDataSource source =
          HttpRestaurantRemoteDataSource(
            baseUrl: 'https://api.example.com/',
            client: client,
          );
      await source.fetchCatalog();

      expect(observed.scheme, 'https');
      expect(observed.host, 'api.example.com');
      expect(observed.path, '/restaurants');
      expect(observed.hasQuery, isFalse);
    });

    test('conserve un préfixe de version dans le chemin', () async {
      // Un déploiement versionné (`/v1`) doit rester intact.
      late Uri observed;
      final MockClient client = MockClient((http.Request request) async {
        observed = request.url;
        return _jsonResponse(sampleCatalogJson);
      });

      final HttpRestaurantRemoteDataSource source =
          HttpRestaurantRemoteDataSource(
            baseUrl: 'https://api.example.com/v1',
            client: client,
          );
      await source.fetchCatalog();

      expect(observed.path, '/v1/restaurants');
    });
  });

  group('fetchCatalog', () {
    test('envoie un GET et parse une réponse 200', () async {
      // La requête porte les en-têtes attendus et aucun corps.
      late http.Request captured;
      final MockClient client = MockClient((http.Request request) async {
        captured = request;
        return _jsonResponse(sampleCatalogJson);
      });

      final HttpRestaurantRemoteDataSource source =
          HttpRestaurantRemoteDataSource(
            baseUrl: 'https://api.example.com',
            client: client,
          );
      final catalog = await source.fetchCatalog();

      expect(captured.method, 'GET');
      expect(captured.headers['Accept'], 'application/json');
      expect(catalog.restaurants, hasLength(2));
    });

    test('traduit un statut non 200 en ServerException avec code', () async {
      // Un 503 doit conserver le statut pour adapter l'interface.
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('indisponible', 503),
      );
      final HttpRestaurantRemoteDataSource source =
          HttpRestaurantRemoteDataSource(
            baseUrl: 'https://api.example.com',
            client: client,
          );

      await expectLater(
        source.fetchCatalog(),
        throwsA(
          isA<ServerException>().having(
            (ServerException error) => error.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
    });

    test('traduit un JSON invalide en ServerException', () async {
      // Une réponse 200 mais illisible reste une erreur serveur.
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('{ pas du JSON', 200),
      );
      final HttpRestaurantRemoteDataSource source =
          HttpRestaurantRemoteDataSource(
            baseUrl: 'https://api.example.com',
            client: client,
          );

      await expectLater(source.fetchCatalog(), throwsA(isA<ServerException>()));
    });

    test('refuse une réponse trop volumineuse', () async {
      // Le bornage mémoire protège le téléphone avant tout décodage.
      final String huge = 'x' * (2 * 1024 * 1024 + 64);
      final MockClient client = MockClient(
        (http.Request request) async => http.Response(huge, 200),
      );
      final HttpRestaurantRemoteDataSource source =
          HttpRestaurantRemoteDataSource(
            baseUrl: 'https://api.example.com',
            client: client,
          );

      await expectLater(source.fetchCatalog(), throwsA(isA<ServerException>()));
    });

    test('traduit une erreur de transport en NetworkException', () async {
      // Une coupure réseau n'est pas une erreur serveur.
      final MockClient client = MockClient(
        (http.Request request) async => throw http.ClientException('coupure'),
      );
      final HttpRestaurantRemoteDataSource source =
          HttpRestaurantRemoteDataSource(
            baseUrl: 'https://api.example.com',
            client: client,
          );

      await expectLater(
        source.fetchCatalog(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('traduit un timeout en NetworkException', () async {
      // Un serveur trop lent doit être abandonné proprement.
      final MockClient client = MockClient((http.Request request) {
        // Réponse volontairement plus lente que le timeout.
        return Future<http.Response>.delayed(
          const Duration(seconds: 2),
          () => _jsonResponse(sampleCatalogJson),
        );
      });
      final HttpRestaurantRemoteDataSource source =
          HttpRestaurantRemoteDataSource(
            baseUrl: 'https://api.example.com',
            client: client,
            timeout: const Duration(milliseconds: 30),
          );

      await expectLater(
        source.fetchCatalog(),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
