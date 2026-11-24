// =============================================================================
// Nettoyage et validation de TOUTES les entrées utilisateur.
// -----------------------------------------------------------------------------
// Règle d'or : aucune donnée externe (recherche, commentaire, téléphone, URL,
// prix, portail gérant) n'atteint le Domain, le réseau ou un plugin sans passer
// par cette classe. La validation est volontairement stricte et sans `dynamic`.
// =============================================================================

// Constantes de bornes (longueurs, prix maximal...).
import '../constants/app_constants.dart';

/// Bibliothèque statique de sanitization.
/// Chaque méthode est pure : mêmes entrées -> mêmes sorties, sans effet de bord.
final class InputSanitizer {
  // Constructeur privé : aucune instance n'est nécessaire.
  const InputSanitizer._();

  // ---------------------------------------------------------------------------
  // Expressions régulières précompilées (coût évité à chaque appel)
  // ---------------------------------------------------------------------------

  /// Caractères de contrôle interdits, sauf tabulation (\t) et saut de ligne (\n).
  /// La plage 007F-009F couvre aussi les contrôles ASCII étendus.
  static final RegExp _controlCharacters = RegExp(
    r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]',
  );

  /// Caractères invisibles utilisés pour usurper l'affichage (zero-width, bidi).
  /// Ils permettent des attaques dites « Trojan Source » ou du camouflage de nom.
  static final RegExp _invisibleCharacters = RegExp(
    r'[\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF]',
  );

  /// Balises de type HTML/XML, retirées avant tout stockage ou affichage.
  static final RegExp _htmlTags = RegExp(r'<[^>]*>', caseSensitive: false);

  /// Caractères à risque de rupture de contexte (HTML, JSON, requête, shell).
  /// Les apostrophes et traits d'union sont conservés : ils sont fréquents dans
  /// les noms locaux (« Chez l'Ami », « Maquis-go »).
  static final RegExp _unsafeSearchCharacters = RegExp(
    r'''[<>"`;{}\[\]\\|^~$%&=?]''',
  );

  /// Espaces multiples (espaces, tabulations, sauts de ligne).
  static final RegExp _anyWhitespace = RegExp(r'\s+');

  /// Séquences de contrôles encodés en pourcentage (%00 à %1F, %7F).
  static final RegExp _encodedControlCharacters = RegExp(
    r'%(?:0[0-9a-f]|1[0-9a-f]|7f)',
    caseSensitive: false,
  );

  /// Variante utilisée uniquement pour les URI construites par l'application
  /// (message WhatsApp) : %09, %0A et %0D restent autorisés car ce sont des
  /// retours à la ligne/tabulations déjà nettoyés par [sanitizePlainText].
  /// Tous les autres contrôles encodés restent refusés.
  static final RegExp _encodedControlCharactersExceptTextBreaks = RegExp(
    r'%(?:0[0-8b-ce-f]|1[0-9a-f]|7f)',
    caseSensitive: false,
  );

  /// Nom de domaine valide : labels alphanumériques, TLD alphabétique >= 2.
  static final RegExp _domainPattern = RegExp(
    r'^(?=.{1,253}$)([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$',
  );

  /// Identifiant technique sûr : lettres, chiffres, underscore et tiret.
  static final RegExp _identifierPattern = RegExp(r'^[a-zA-Z0-9_-]+$');

  /// Adresse e-mail volontairement simple (la validation définitive est serveur).
  static final RegExp _emailPattern = RegExp(
    r'''^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$''',
  );

  // ---------------------------------------------------------------------------
  // Recherche et textes libres
  // ---------------------------------------------------------------------------

  /// Nettoie une requête de recherche avant filtrage ou appel réseau.
  /// - supprime les balises et caractères de contrôle ;
  /// - neutralise les caractères de rupture de contexte ;
  /// - compacte les espaces et borne la longueur.
  static String sanitizeSearchQuery(
    String? raw, {
    int maxLength = AppConstants.searchMaxLength,
  }) {
    // Une longueur non positive rendrait `substring` invalide : on refuse.
    if (raw == null || raw.isEmpty || maxLength < 1) {
      return '';
    }

    // Retrait des balises AVANT les chevrons, pour ne pas laisser leur contenu.
    var value = raw.replaceAll(_htmlTags, ' ');

    // Remplacement des contrôles par une espace (pas de concaténation de mots).
    value = value.replaceAll(_controlCharacters, ' ');

    // Suppression des caractères invisibles d'usurpation.
    value = value.replaceAll(_invisibleCharacters, '');

    // Neutralisation des opérateurs et délimiteurs dangereux.
    value = value.replaceAll(_unsafeSearchCharacters, ' ');

    // Compactage des espaces et retrait des espaces de bord.
    value = value.replaceAll(_anyWhitespace, ' ').trim();

    // Troncature finale sans dépasser la limite.
    return _truncate(value, maxLength).trim();
  }

  /// Nettoie un texte libre (commentaire, description, message WhatsApp).
  /// Les sauts de ligne sont conservés par défaut pour préserver la lisibilité.
  static String sanitizePlainText(
    String? raw, {
    int maxLength = AppConstants.commentMaxLength,
    bool allowNewlines = true,
  }) {
    // Refus des entrées absentes ou des limites incohérentes.
    if (raw == null || raw.isEmpty || maxLength < 1) {
      return '';
    }

    // Uniformisation des fins de ligne Windows/Mac vers \n.
    var value = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Retrait des balises HTML éventuelles.
    value = value.replaceAll(_htmlTags, ' ');

    // Retrait des contrôles (tabulation et \n sont hors de la plage interdite).
    value = value.replaceAll(_controlCharacters, '');

    // Retrait des caractères invisibles/bidi.
    value = value.replaceAll(_invisibleCharacters, '');

    // Neutralisation des chevrons résiduels (défense en profondeur).
    value = value.replaceAll('<', '').replaceAll('>', '');

    // Si les retours à la ligne ne sont pas autorisés, ils deviennent des espaces.
    if (!allowNewlines) {
      value = value.replaceAll('\n', ' ');
    }

    // Compactage : jamais plus de deux sauts de ligne consécutifs.
    value = value.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Compactage des espaces/tabulations répétés.
    value = value.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

    // Troncature et nettoyage des bords.
    return _truncate(value.trim(), maxLength);
  }

  /// Variante pour les noms courts (plat, restaurant, gérant) sans retour ligne.
  static String sanitizeShortLabel(
    String? raw, {
    int maxLength = AppConstants.shortTextMaxLength,
  }) {
    // Délègue au nettoyage générique en interdisant les sauts de ligne.
    return sanitizePlainText(raw, maxLength: maxLength, allowNewlines: false);
  }

  // ---------------------------------------------------------------------------
  // Téléphone
  // ---------------------------------------------------------------------------

  /// Valide et normalise un numéro burkinabè au format international E.164.
  /// Retourne `null` si le numéro est invalide : l'appelant décide du message.
  static String? sanitizePhoneNumber(String? raw) {
    // Un numéro absent ne peut pas être validé.
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    // Refus des caractères non téléphoniques (lettres, balises, ponctuation
    // exotique). On ne se contente pas de les supprimer : une saisie polluée
    // doit être signalée, pas silencieusement réinterprétée.
    if (RegExp(r'[^0-9\s()+\-.]').hasMatch(raw)) {
      return null;
    }

    // Conservation des chiffres uniquement (retire espaces, tirets, parenthèses).
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

    // Gestion du préfixe international composé « 00 ».
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    // Retrait de l'indicatif pays +226 s'il est présent.
    if (digits.startsWith('226')) {
      digits = digits.substring(3);
    }

    // Un numéro national burkinabè comporte exactement 8 chiffres.
    if (digits.length != 8) {
      return null;
    }

    // Les préfixes valides commencent par 2 (fixe), 5, 6 ou 7 (mobile).
    if (!RegExp(r'^[2567]').hasMatch(digits)) {
      return null;
    }

    // Format canonique utilisé pour `tel:` et WhatsApp.
    return '+226$digits';
  }

  /// Formate un numéro pour les liens WhatsApp (chiffres uniquement, sans `+`).
  static String? whatsAppNumber(String? raw) {
    // On s'appuie sur la validation stricte du numéro.
    final String? normalized = sanitizePhoneNumber(raw);

    // `substring(1)` retire le « + » initial : wa.me attend 226XXXXXXXX.
    return normalized?.substring(1);
  }

  /// Valide un numéro court d'urgence (2 à 4 chiffres).
  /// Ces numéros ne doivent jamais être acceptés comme numéros WhatsApp.
  static String? sanitizeShortNumber(String? raw) {
    // Refus de tout caractère autre que chiffre ou espace.
    if (raw == null || RegExp(r'[^0-9\s]').hasMatch(raw)) {
      return null;
    }

    // Nettoyage minimal : chiffres uniquement.
    final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

    // Longueur autorisée pour les services d'urgence locaux.
    if (digits.length < 2 || digits.length > 4) {
      return null;
    }

    // Valeur sûre à réinjecter dans un URI `tel:`.
    return digits;
  }

  // ---------------------------------------------------------------------------
  // Prix, quantités, identifiants
  // ---------------------------------------------------------------------------

  /// Convertit un prix saisi en FCFA vers un entier sûr.
  /// Accepte « 1 500 », « 1500 FCFA » ; refuse décimales et caractères parasites.
  static int? sanitizePriceFcfa(String? raw) {
    // Entrée absente : invalide.
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    // Normalisation de la casse pour retirer le suffixe monétaire.
    var value = raw.trim().toLowerCase().replaceAll('fcfa', '');

    // Retrait de tous les séparateurs d'espaces, y compris insécables.
    value = value.replaceAll(RegExp(r'[\s\u00A0\u202F]'), '');

    // Seuls des chiffres (1 à 8) sont acceptés : pas de décimale, pas de signe.
    if (!RegExp(r'^\d{1,8}$').hasMatch(value)) {
      return null;
    }

    // Conversion sûre après validation du format.
    final int? parsed = int.tryParse(value);
    if (parsed == null || parsed < 0 || parsed > AppConstants.maxPriceFcfa) {
      return null;
    }

    // Prix métier valide.
    return parsed;
  }

  /// Valide une quantité d'article comprise entre 1 et [max].
  static int? sanitizeQuantity(
    String? raw, {
    int max = AppConstants.maxItemQuantity,
  }) {
    // Conversion stricte : pas d'espaces ni de signe.
    final int? parsed = int.tryParse((raw ?? '').trim());

    // Bornage métier : une quantité nulle ou négative n'a pas de sens.
    if (parsed == null || parsed < 1 || parsed > max) {
      return null;
    }

    // Quantité valide.
    return parsed;
  }

  /// Nettoie un identifiant technique (restaurant, plat, gérant).
  /// Retourne une chaîne vide si l'identifiant est absent ou non conforme.
  static String sanitizeIdentifier(String? raw, {int maxLength = 64}) {
    // Normalisation minimale : suppression des espaces de bord.
    final String value = (raw ?? '').trim();

    // Refus des valeurs vides, trop longues ou hors motif autorisé.
    if (value.isEmpty ||
        value.length > maxLength ||
        !_identifierPattern.hasMatch(value)) {
      return '';
    }

    // Identifiant utilisable dans une route ou une clé de stockage.
    return value;
  }

  // ---------------------------------------------------------------------------
  // E-mail (portail gérant)
  // ---------------------------------------------------------------------------

  /// Valide et normalise une adresse e-mail. Retourne `null` si invalide.
  static String? sanitizeEmail(String? raw) {
    // Normalisation : minuscules, sans espaces de bord.
    final String value = (raw ?? '').trim().toLowerCase();

    // Longueur maximale standard d'une adresse e-mail.
    if (value.isEmpty || value.length > 254) {
      return null;
    }

    // Contrôle du format ; la validation d'existence reste côté serveur.
    if (!_emailPattern.hasMatch(value)) {
      return null;
    }

    // Adresse normalisée.
    return value;
  }

  // ---------------------------------------------------------------------------
  // URL et coordonnées
  // ---------------------------------------------------------------------------

  /// Valide une URL avant tout lancement externe.
  /// [allowedSchemes] doit rester une liste blanche stricte.
  static Uri? sanitizeUrl(
    String? raw, {
    Set<String> allowedSchemes = const <String>{'https'},
    int maxLength = AppConstants.urlMaxLength,
    bool allowTextBreaks = false,
  }) {
    // Nettoyage des bords et refus des valeurs vides/trop longues.
    final String trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty || trimmed.length > maxLength) {
      return null;
    }

    // Refus des espaces, contrôles et barres obliques inverses déguisées.
    if (trimmed.contains(RegExp(r'[\u0000-\u0020\u007F]')) ||
        trimmed.contains(r'\')) {
      return null;
    }

    // Refus des contrôles encodés (%0A, %0D...) qui peuvent tromper un parseur.
    // Seules les URI internes déjà nettoyées (message WhatsApp) tolèrent les
    // retours à la ligne encodés ; une URL saisie reste strictement refusée.
    final RegExp encodedControls = allowTextBreaks
        ? _encodedControlCharactersExceptTextBreaks
        : _encodedControlCharacters;
    if (encodedControls.hasMatch(trimmed)) {
      return null;
    }

    // Analyse non destructive : aucun lancement n'est effectué ici.
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return null;
    }

    // Le schéma est normalisé en minuscules avant comparaison à la liste blanche.
    final String scheme = uri.scheme.toLowerCase();
    if (!allowedSchemes.contains(scheme)) {
      return null;
    }

    // Un URI ne doit jamais embarquer d'identifiants (https://user:pass@host).
    if (uri.userInfo.isNotEmpty) {
      return null;
    }

    // Règles spécifiques au HTTPS : domaine public et port standard.
    if (scheme == 'https') {
      if (uri.host.isEmpty ||
          !_domainPattern.hasMatch(uri.host.toLowerCase())) {
        return null;
      }
      if (uri.hasPort && uri.port != 443) {
        return null;
      }
    }

    // Règles du schéma téléphonique : numéro mobile/fixe ou numéro d'urgence.
    if (scheme == 'tel') {
      if (sanitizePhoneNumber(uri.path) == null &&
          sanitizeShortNumber(uri.path) == null) {
        return null;
      }
    }

    // Règles du schéma geo : latitude et longitude numériques et bornées.
    if (scheme == 'geo') {
      final List<String> parts = uri.path.split(',');
      if (parts.length != 2) {
        return null;
      }
      final double? latitude = double.tryParse(parts[0]);
      final double? longitude = double.tryParse(parts[1]);
      if (!isValidCoordinate(latitude, longitude)) {
        return null;
      }
    }

    // URL conforme : l'appelant peut la soumettre à `UrlGuard`.
    return uri;
  }

  /// Vérifie qu'un couple latitude/longitude est réellement sur Terre.
  static bool isValidCoordinate(double? latitude, double? longitude) {
    // Une coordonnée absente est invalide.
    if (latitude == null || longitude == null) {
      return false;
    }

    // Bornes géographiques standard.
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  // ---------------------------------------------------------------------------
  // Normalisation pour la recherche locale
  // ---------------------------------------------------------------------------

  /// Table de translittération des caractères accentués français.
  /// Évite de dépendre d'une bibliothèque ICU pour la recherche offline.
  static const Map<String, String> _diacritics = <String, String>{
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'œ': 'oe',
    'æ': 'ae',
    'À': 'A',
    'Á': 'A',
    'Â': 'A',
    'Ä': 'A',
    'Ã': 'A',
    'Å': 'A',
    'Ç': 'C',
    'È': 'E',
    'É': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'Ì': 'I',
    'Í': 'I',
    'Î': 'I',
    'Ï': 'I',
    'Ñ': 'N',
    'Ò': 'O',
    'Ó': 'O',
    'Ô': 'O',
    'Ö': 'O',
    'Õ': 'O',
    'Ù': 'U',
    'Ú': 'U',
    'Û': 'U',
    'Ü': 'U',
    'Ý': 'Y',
    'Œ': 'OE',
    'Æ': 'AE',
  };

  /// Supprime les diacritiques d'une chaîne, caractère par caractère.
  static String stripDiacritics(String input) {
    // Tampon efficace pour une construction linéaire.
    final StringBuffer buffer = StringBuffer();

    // Parcours par rune pour ne pas casser les caractères multi-octets.
    for (final int rune in input.runes) {
      final String character = String.fromCharCode(rune);
      buffer.write(_diacritics[character] ?? character);
    }

    // Chaîne translittérée.
    return buffer.toString();
  }

  /// Produit une clé de recherche normalisée (minuscules, sans accents/ponctuation).
  /// Utilisée par le filtrage local : « Tô » et « to » doivent se rencontrer.
  static String normalizeForSearch(String input) {
    // Translittération puis minuscules.
    final String lowered = stripDiacritics(input).toLowerCase();

    // Remplacement de toute ponctuation par une espace.
    final String cleaned = lowered.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');

    // Compactage et nettoyage final.
    return cleaned.replaceAll(_anyWhitespace, ' ').trim();
  }

  // ---------------------------------------------------------------------------
  // Helpers privés
  // ---------------------------------------------------------------------------

  /// Tronque proprement une chaîne sans dépasser [maxLength].
  static String _truncate(String value, int maxLength) {
    // Pas de troncature si la valeur tient déjà.
    if (value.length <= maxLength) {
      return value;
    }

    // Découpage strict puis retrait des espaces résiduels.
    return value.substring(0, maxLength).trim();
  }
}
