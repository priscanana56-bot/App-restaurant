// =============================================================================
// Source distante HTTP.
// -----------------------------------------------------------------------------
// Sécurité :
//   - l'URL de base doit être HTTPS, sans identifiants, query ni fragment ;
//   - la taille de la réponse est bornée avant décodage ;
//   - les statuts non 200, les timeouts et les erreurs de parsing sont traduits
//     en exceptions métier stables (jamais d'exception HTTP dans le Domain).
// =============================================================================

// Timeout des requêtes.
import 'dart:async';

// Décodage UTF-8 strict.
import 'dart:convert';

// Client HTTP injectable.
import 'package:http/http.dart' as http;

// Configuration (timeout, URL de base).
import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_constants.dart';

// Exceptions stables.
import '../../../../core/error/exceptions.dart';

// Modèle de catalogue.
import '../models/restaurant_catalog_model.dart';

// Contrat implémenté.
import 'restaurant_remote_data_source.dart';

/// Implémentation HTTP de la source distante.
final class HttpRestaurantRemoteDataSource
    implements RestaurantRemoteDataSource {
  // Constructeur privé : l'URL a déjà été validée par la factory.
  HttpRestaurantRemoteDataSource._(this._endpoint, this._client, this._timeout);

  /// Construit la source après validation stricte de [baseUrl].
  factory HttpRestaurantRemoteDataSource({
    required String baseUrl,
    http.Client? client,
    Duration? timeout,
  }) {
    final String trimmed = baseUrl.trim();
    final Uri? parsed = Uri.tryParse(trimmed);

    // Une API de production ne peut être qu'en HTTPS, sans identifiants ni
    // paramètres cachés qui fausseraient la construction de l'endpoint.
    if (parsed == null ||
        parsed.scheme.toLowerCase() != 'https' ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment) {
      throw const SecurityException(
        'L’URL de l’API doit être HTTPS, sans identifiants ni paramètres.',
      );
    }

    // Suppression des slashs finaux pour éviter les doubles séparateurs.
    final String basePath = parsed.path.replaceAll(RegExp(r'/+$'), '');
    final Uri endpoint = parsed.replace(path: '$basePath/restaurants');

    return HttpRestaurantRemoteDataSource._(
      endpoint,
      client ?? http.Client(),
      timeout ?? AppConfig.apiTimeout,
    );
  }

  // Endpoint complet du catalogue.
  final Uri _endpoint;

  // Client HTTP réutilisé entre les requêtes.
  final http.Client _client;

  // Délai maximal d'une requête.
  final Duration _timeout;

  /// Télécharge le catalogue et le convertit en modèle validé.
  @override
  Future<RestaurantCatalogModel> fetchCatalog() async {
    try {
      // Requête GET sans donnée personnelle envoyée au serveur.
      final http.Response response = await _client
          .get(
            _endpoint,
            headers: const <String, String>{
              'Accept': 'application/json',
              'User-Agent': 'KoudougouGourmet/1.0',
            },
          )
          .timeout(_timeout);

      // Seul un 200 contient un catalogue exploitable.
      if (response.statusCode != 200) {
        throw ServerException(
          'Le serveur a refusé la requête.',
          statusCode: response.statusCode,
        );
      }

      // Bornage mémoire AVANT tout décodage.
      if (response.bodyBytes.length > AppConstants.maxRemotePayloadBytes) {
        throw const ServerException(
          'La réponse du serveur est trop volumineuse.',
        );
      }

      // Décodage UTF-8 strict : une réponse mal encodée est refusée.
      final String body = utf8.decode(
        response.bodyBytes,
        allowMalformed: false,
      );

      // Parsing et validation du catalogue.
      return RestaurantCatalogModel.fromJsonString(body);
    } on AppException {
      // Les erreurs déjà typées conservent leur sens métier.
      rethrow;
    } on TimeoutException {
      throw const NetworkException(
        'Le serveur met trop de temps à répondre. Réessayez.',
      );
    } on http.ClientException catch (error) {
      throw NetworkException('La connexion au serveur a échoué.', cause: error);
    } on FormatException catch (error) {
      throw ServerException(
        'La réponse du serveur est illisible.',
        cause: error,
      );
    } on Object catch (error) {
      // Filet de sécurité : aucune exception native ne traverse la Data.
      throw ServerException(
        'La synchronisation avec le serveur a échoué.',
        cause: error,
      );
    }
  }

  /// Libère le client HTTP (appelé à la destruction du conteneur).
  void close() => _client.close();
}
