// =============================================================================
// Garde-fou d'ouverture de liens externes.
// -----------------------------------------------------------------------------
// Aucun lien issu des données (restaurant, gérant, partage) n'est ouvert
// directement. Il passe par :
//   1. une liste blanche de schémas (`https`, `tel`, `geo`) ;
//   2. une liste blanche d'hôtes HTTPS (WhatsApp, Google Maps...) ;
//   3. une validation stricte du numéro ou des coordonnées ;
//   4. `canLaunchUrl` avant `launchUrl`.
// Cela bloque `javascript:`, `data:`, `intent:`, `file:` et les domaines typosquattés.
// =============================================================================

// Type fonctionnel `Either` pour ne jamais laisser fuiter d'exception.
import 'package:fpdart/fpdart.dart';

// Constantes (timeout, schémas autorisés).
import '../constants/app_constants.dart';

// Mapper d'erreurs techniques vers des erreurs métier.
import '../error/error_mapper.dart';
import '../error/failures.dart';

// Nettoyage des numéros, URLs et coordonnées.
import 'input_sanitizer.dart';

// Abstraction du plugin d'ouverture de liens.
import 'url_launcher_gateway.dart';

/// Service unique d'ouverture de liens, injectable via GetIt.
final class UrlGuard {
  /// Construit le garde-fou avec des dépendances optionnelles (tests/fakes).
  UrlGuard({
    UrlLauncherGateway? gateway,
    Set<String>? allowedHttpsHosts,
    ErrorMapper? errorMapper,
    Duration? timeout,
  }) : _gateway = gateway ?? const PluginUrlLauncherGateway(),
       _allowedHttpsHosts = allowedHttpsHosts ?? defaultHttpsHosts,
       _errorMapper = errorMapper ?? const ErrorMapper(),
       _timeout = timeout ?? AppConstants.externalLinkTimeout;

  // Passerelle native, remplaçable en test.
  final UrlLauncherGateway _gateway;

  // Hôtes HTTPS autorisés, sous forme de correspondance exacte (pas de suffixe).
  final Set<String> _allowedHttpsHosts;

  // Traducteur d'exceptions.
  final ErrorMapper _errorMapper;

  // Délai maximal avant de considérer qu'un lancement a échoué.
  final Duration _timeout;

  /// Liste blanche par défaut : uniquement les services réellement utilisés.
  /// Une correspondance exacte empêche `wa.me.attaquant.com` de passer.
  static const Set<String> defaultHttpsHosts = <String>{
    'wa.me',
    'api.whatsapp.com',
    'www.google.com',
    'maps.google.com',
    'maps.app.goo.gl',
    'goo.gl',
    'play.google.com',
    'apps.apple.com',
    // Sources publiques de l'annuaire de Koudougou (consultation seule).
    'mnadiiye.com',
    'www.mnadiiye.com',
    'www.petitfute.com',
    'petitfute.co.uk',
    'www.petitfute.co.uk',
    'www.goafricaonline.com',
    'goafricaonline.com',
    'exa.ai',
    'www.courrierinternational.com',
  };

  // ---------------------------------------------------------------------------
  // API générique
  // ---------------------------------------------------------------------------

  /// Valide une chaîne d'URL puis l'ouvre si elle est autorisée.
  Future<Either<Failure, Unit>> openRaw(String? rawUrl) async {
    // Analyse et nettoyage via la liste blanche globale.
    final Uri? uri = InputSanitizer.sanitizeUrl(
      rawUrl,
      allowedSchemes: AppConstants.allowedExternalSchemes,
    );

    // Une URL refusée ne doit jamais atteindre le plugin natif.
    if (uri == null) {
      return left(
        const SecurityFailure(
          message: 'Ce lien est invalide ou n’est pas autorisé.',
        ),
      );
    }

    // Délégation au traitement spécialisé par schéma.
    return openUri(uri);
  }

  /// Ouvre une URI déjà construite par l'application.
  /// L'URI est revalidée : on ne fait jamais confiance à l'appelant.
  Future<Either<Failure, Unit>> openUri(Uri? uri) {
    // Absence d'URI : erreur de validation, pas de crash.
    if (uri == null) {
      return Future<Either<Failure, Unit>>.value(
        left(const ValidationFailure(message: 'Lien manquant.', field: 'url')),
      );
    }

    // Dispatch strict par schéma normalisé.
    switch (uri.scheme.toLowerCase()) {
      case 'https':
        return _openHttps(uri);
      case 'tel':
        return _openTelephone(uri.path, allowShortNumber: true);
      case 'geo':
        return _openGeo(uri);
      default:
        // Tout autre schéma est considéré comme une tentative d'attaque.
        return Future<Either<Failure, Unit>>.value(
          left(const SecurityFailure(message: 'Type de lien non autorisé.')),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Liens métier
  // ---------------------------------------------------------------------------

  /// Ouvre une conversation WhatsApp avec un message pré-rempli.
  Future<Either<Failure, Unit>> openWhatsApp({
    required String phone,
    required String message,
  }) {
    // Validation du numéro et conversion au format attendu par wa.me.
    final String? digits = InputSanitizer.whatsAppNumber(phone);
    if (digits == null) {
      return Future<Either<Failure, Unit>>.value(
        left(
          const ValidationFailure(
            message: 'Le numéro WhatsApp du restaurant est invalide.',
            field: 'phone',
          ),
        ),
      );
    }

    // Nettoyage du message : balises, contrôles et longueur abusive retirés.
    final String safeMessage = InputSanitizer.sanitizePlainText(
      message,
      maxLength: 1200,
    );

    // Construction d'une URL HTTPS (pas de deep link `whatsapp:` non maîtrisé).
    final Uri uri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '/$digits',
      queryParameters: safeMessage.isEmpty
          ? null
          : <String, String>{'text': safeMessage},
    );

    // Passe par le validateur HTTPS et la liste blanche d'hôtes.
    // `allowTextBreaks` concerne UNIQUEMENT cette URI construite ici : le
    // message a déjà été nettoyé par `sanitizePlainText`. Une URL saisie par
    // l'utilisateur reste soumise au refus strict des contrôles encodés.
    return _openHttps(uri, allowTextBreaks: true);
  }

  /// Lance un appel vers un numéro mobile/fixe validé.
  Future<Either<Failure, Unit>> openPhoneCall(String rawPhone) {
    // Un numéro court d'urgence n'est pas accepté ici.
    return _openTelephone(rawPhone, allowShortNumber: false);
  }

  /// Lance un appel vers un service d'urgence (2 à 4 chiffres).
  Future<Either<Failure, Unit>> openEmergencyCall(String shortNumber) {
    // Validation spécifique pour ne pas confondre avec un numéro complet.
    return _openTelephone(
      shortNumber,
      allowShortNumber: true,
      requireShort: true,
    );
  }

  /// Ouvre Google Maps sur un point précis, avec un libellé optionnel.
  Future<Either<Failure, Unit>> openMaps({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    // Contrôle géographique avant toute construction d'URL.
    if (!InputSanitizer.isValidCoordinate(latitude, longitude)) {
      return Future<Either<Failure, Unit>>.value(
        left(
          const ValidationFailure(
            message: 'Coordonnées GPS invalides.',
            field: 'location',
          ),
        ),
      );
    }

    // Nettoyage du libellé affiché sur la carte.
    final String safeLabel = InputSanitizer.sanitizeShortLabel(
      label,
      maxLength: 80,
    );

    // Requête textuelle lisible par l'application Google Maps.
    final String query = safeLabel.isEmpty
        ? '$latitude,$longitude'
        : '$latitude,$longitude ($safeLabel)';

    // URL universelle : fonctionne avec l'app Maps ou le navigateur.
    final Uri uri = Uri(
      scheme: 'https',
      host: 'www.google.com',
      path: '/maps/search/',
      queryParameters: <String, String>{'api': '1', 'query': query},
    );

    // Validation finale puis lancement.
    return _openHttps(uri);
  }

  /// Ouvre un itinéraire Google Maps vers un restaurant.
  Future<Either<Failure, Unit>> openDirections({
    required double latitude,
    required double longitude,
  }) {
    // Garde-fou sur les coordonnées.
    if (!InputSanitizer.isValidCoordinate(latitude, longitude)) {
      return Future<Either<Failure, Unit>>.value(
        left(
          const ValidationFailure(
            message: 'Coordonnées GPS invalides.',
            field: 'location',
          ),
        ),
      );
    }

    // Construction de l'URL d'itinéraire.
    final Uri uri = Uri(
      scheme: 'https',
      host: 'www.google.com',
      path: '/maps/dir/',
      queryParameters: <String, String>{
        'api': '1',
        'destination': '$latitude,$longitude',
      },
    );

    // Validation finale puis lancement.
    return _openHttps(uri);
  }

  // ---------------------------------------------------------------------------
  // Implémentations privées
  // ---------------------------------------------------------------------------

  /// Ouvre un lien HTTPS après double validation (format + hôte autorisé).
  ///
  /// [allowTextBreaks] ne doit être utilisé que pour une URI générée par
  /// l'application à partir d'un texte déjà nettoyé (message WhatsApp).
  Future<Either<Failure, Unit>> _openHttps(
    Uri uri, {
    bool allowTextBreaks = false,
  }) {
    // Revalidation complète de l'URI sérialisée.
    final Uri? sanitized = InputSanitizer.sanitizeUrl(
      uri.toString(),
      allowedSchemes: const <String>{'https'},
      allowTextBreaks: allowTextBreaks,
    );

    // Format invalide : aucune ouverture.
    if (sanitized == null) {
      return Future<Either<Failure, Unit>>.value(
        left(const SecurityFailure(message: 'Lien HTTPS invalide.')),
      );
    }

    // Liste blanche stricte des domaines : pas de wildcard, pas de suffixe.
    final String host = sanitized.host.toLowerCase();
    if (!_allowedHttpsHosts.contains(host)) {
      return Future<Either<Failure, Unit>>.value(
        left(
          const SecurityFailure(
            message: 'Ce site n’est pas autorisé par l’application.',
          ),
        ),
      );
    }

    // Lancement effectif.
    return _launch(sanitized);
  }

  /// Ouvre le composeur téléphonique avec un numéro normalisé.
  Future<Either<Failure, Unit>> _openTelephone(
    String raw, {
    required bool allowShortNumber,
    bool requireShort = false,
  }) {
    // Validation d'un numéro complet (mobile/fixe).
    final String? fullNumber = requireShort
        ? null
        : InputSanitizer.sanitizePhoneNumber(raw);

    // Validation d'un numéro court d'urgence si autorisé par l'appelant.
    final String? shortNumber = allowShortNumber
        ? InputSanitizer.sanitizeShortNumber(raw)
        : null;

    // Sélection du numéro utilisable : complet prioritaire, sauf mode urgence.
    final String? number = requireShort
        ? shortNumber
        : (fullNumber ?? shortNumber);

    // Aucun numéro sûr : erreur de validation.
    if (number == null) {
      return Future<Either<Failure, Unit>>.value(
        left(
          const ValidationFailure(
            message: 'Numéro de téléphone invalide.',
            field: 'phone',
          ),
        ),
      );
    }

    // Reconstruction de l'URI `tel:` à partir de la valeur validée.
    final Uri uri = Uri(scheme: 'tel', path: number);

    // Lancement effectif.
    return _launch(uri);
  }

  /// Ouvre une URI `geo:` après validation stricte du couple lat/lng.
  Future<Either<Failure, Unit>> _openGeo(Uri uri) {
    // Revalidation complète via la même routine que les autres schémas.
    final Uri? sanitized = InputSanitizer.sanitizeUrl(
      uri.toString(),
      allowedSchemes: const <String>{'geo'},
    );

    // URI geo invalide : refus.
    if (sanitized == null) {
      return Future<Either<Failure, Unit>>.value(
        left(
          const ValidationFailure(
            message: 'Coordonnées GPS invalides.',
            field: 'location',
          ),
        ),
      );
    }

    // Lancement de l'application de cartographie.
    return _launch(sanitized);
  }

  /// Exécute `canLaunch` puis `launch` avec timeout et capture d'erreurs.
  Future<Either<Failure, Unit>> _launch(Uri uri) async {
    // Bloc de capture : aucune exception native ne doit remonter jusqu'au BLoC.
    try {
      // Vérification préalable, bornée dans le temps.
      final bool canOpen = await _gateway
          .canLaunch(uri)
          .timeout(_timeout, onTimeout: () => false);

      // Aucune application capable d'ouvrir ce type de lien.
      if (!canOpen) {
        return left(
          const ExternalLinkFailure(
            message: 'Aucune application compatible n’est installée sur cet appareil.',
          ),
        );
      }

      // Ouverture réelle, elle aussi bornée.
      final bool opened = await _gateway
          .launch(uri)
          .timeout(_timeout, onTimeout: () => false);

      // Le plugin peut renvoyer `false` sans lever d'exception.
      if (!opened) {
        return left(const ExternalLinkFailure());
      }

      // Succès métier : `unit` matérialise un résultat vide.
      return right(unit);
    } on Object catch (error) {
      // Toute erreur native/plugin est traduite en Failure stable.
      // Le détail technique reste dans le mapper, jamais dans le message utilisateur.
      return left(
        ExternalLinkFailure(
          message: _errorMapper.map(error) is SecurityFailure
              ? 'Ce lien n’est pas autorisé par l’application.'
              : 'L’ouverture du lien a échoué. Réessayez.',
        ),
      );
    }
  }
}
