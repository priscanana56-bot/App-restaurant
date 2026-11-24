// =============================================================================
// Configuration d'environnement — sans secret embarqué.
// -----------------------------------------------------------------------------
// Priorité de résolution d'une valeur :
//   1. `--dart-define=CLE=valeur` (recommandé en CI/CD et en production) ;
//   2. fichier `.env` local, copié depuis `.env.example` (développement) ;
//   3. valeur de repli codée dans l'application.
//
// Rappel de sécurité : tout ce qui est compilé dans l'APK/IPA est extractible.
// Une clé réellement secrète (paiement, service_role, token privé) doit rester
// côté serveur. Ici, seules des valeurs publiques sont acceptées.
// =============================================================================

// Import du chargeur de fichier `.env` (asset déclaré dans pubspec.yaml).
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Import des constantes de repli publiques.
import 'app_constants.dart';

/// Point d'accès unique à la configuration applicative.
final class AppConfig {
  // Constructeur privé : la classe est utilisée comme espace de noms statique.
  const AppConfig._();

  // Indicateur interne empêchant un double chargement du fichier `.env`.
  static bool _isLoaded = false;

  // ---------------------------------------------------------------------------
  // Chargement
  // ---------------------------------------------------------------------------

  /// Charge le fichier `.env` une seule fois, au démarrage de l'application.
  /// Une absence de fichier ne doit jamais bloquer le lancement : en production,
  /// les valeurs peuvent venir exclusivement des `--dart-define`.
  static Future<void> load() async {
    // Sortie immédiate si le chargement a déjà été effectué.
    if (_isLoaded) {
      return;
    }

    // Tentative de lecture de l'asset `.env` déclaré dans pubspec.yaml.
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Le fichier est optionnel : on ignore proprement l'erreur d'asset absent.
      // Aucun secret ni détail technique n'est journalisé ici.
    }

    // Marque le chargement comme terminé, même en cas de fichier absent.
    _isLoaded = true;
  }

  // ---------------------------------------------------------------------------
  // Lecture générique
  // ---------------------------------------------------------------------------

  /// Résout une valeur en donnant la priorité à `--dart-define`.
  /// [compileTimeValue] provient d'un `String.fromEnvironment` constant ;
  /// [envKey] est la clé correspondante dans le fichier `.env`.
  static String _resolve(String compileTimeValue, String envKey) {
    // Une valeur non vide injectée au build est prioritaire.
    final String defineValue = compileTimeValue.trim();
    if (defineValue.isNotEmpty) {
      return defineValue;
    }

    // Sans fichier chargé, aucune clé `.env` ne peut être lue.
    if (!_isLoaded || !dotenv.isInitialized) {
      return '';
    }

    // Lecture non bloquante : renvoie null si la clé est absente.
    return dotenv.maybeGet(envKey)?.trim() ?? '';
  }

  /// Convertit une chaîne en entier borné, avec repli sûr.
  static int _resolveInt(
    String raw,
    int fallback, {
    required int min,
    required int max,
  }) {
    // Analyse stricte : toute valeur non numérique déclenche le repli.
    final int? parsed = int.tryParse(raw);

    // Une valeur hors bornes est considérée comme invalide.
    if (parsed == null || parsed < min || parsed > max) {
      return fallback;
    }

    // Valeur validée.
    return parsed;
  }

  /// Interprète un drapeau textuel de façon tolérante et explicite.
  static bool _resolveBool(String raw, bool fallback) {
    // Normalisation pour accepter les variantes usuelles.
    switch (raw.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
      default:
        return fallback;
    }
  }

  // ---------------------------------------------------------------------------
  // Valeurs exposées
  // ---------------------------------------------------------------------------

  /// URL de base de l'API distante. Vide = mode local / seed embarqué.
  static String get apiBaseUrl =>
      _resolve(const String.fromEnvironment('API_BASE_URL'), 'API_BASE_URL');

  /// Indique si une API distante utilisable a été configurée.
  static bool get hasRemoteBackend {
    // Une API de production doit obligatoirement utiliser HTTPS.
    final Uri? uri = Uri.tryParse(apiBaseUrl);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  /// Délai maximal d'une requête réseau (borné entre 1 et 60 secondes).
  static Duration get apiTimeout => Duration(
    seconds: _resolveInt(
      _resolve(
        const String.fromEnvironment('API_TIMEOUT_SECONDS'),
        'API_TIMEOUT_SECONDS',
      ),
      15,
      min: 1,
      max: 60,
    ),
  );

  /// Active ou non la synchronisation distante (offline-first si false).
  static bool get isRemoteSyncEnabled => _resolveBool(
    _resolve(
      const String.fromEnvironment('ENABLE_REMOTE_SYNC'),
      'ENABLE_REMOTE_SYNC',
    ),
    false,
  );

  /// Numéro de support public de l'application, au format E.164.
  /// La valeur fictive par défaut doit être remplacée avant toute publication.
  static String get supportPhone {
    // Lecture de la valeur configurée, sans validation ici (rôle de UrlGuard).
    final String configured = _resolve(
      const String.fromEnvironment('APP_SUPPORT_PHONE'),
      'APP_SUPPORT_PHONE',
    );

    // Repli explicite si aucune valeur n'est fournie.
    return configured.isEmpty
        ? AppConstants.supportPhonePlaceholder
        : configured;
  }

  /// Version du schéma de cache local, utilisée pour migrer ou purger Hive.
  static int get cacheSchemaVersion => _resolveInt(
    _resolve(
      const String.fromEnvironment('CACHE_SCHEMA_VERSION'),
      'CACHE_SCHEMA_VERSION',
    ),
    AppConstants.cacheSchemaVersion,
    min: 1,
    max: 999,
  );

  /// Mode de fonctionnement résumé, utile pour les diagnostics non sensibles.
  static String get runtimeMode {
    // Aucune URL : l'application vit sur ses données locales.
    if (!hasRemoteBackend) {
      return 'local';
    }

    // URL présente mais synchronisation désactivée : lecture seule distante.
    if (!isRemoteSyncEnabled) {
      return 'remote-readonly';
    }

    // Configuration complète.
    return 'remote-sync';
  }
}
