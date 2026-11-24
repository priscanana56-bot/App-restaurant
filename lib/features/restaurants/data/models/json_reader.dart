// =============================================================================
// Lecteur JSON strict, sans `dynamic`.
// -----------------------------------------------------------------------------
// `jsonDecode` renvoie un type dynamique : on le convertit UNE SEULE FOIS en
// `Map<String, Object?>` ici, puis tous les champs sont lus avec des méthodes
// typées qui valident le type, la longueur et les bornes. Toute anomalie lève
// une `FormatException` décrite par la clé concernée — jamais par la valeur,
// afin de ne pas journaliser de donnée personnelle.
// =============================================================================

/// Enveloppe typée autour d'un objet JSON.
final class JsonReader {
  /// Construit un lecteur à partir d'une map déjà convertie.
  const JsonReader(this._values);

  // Valeurs brutes de l'objet JSON.
  final Map<String, Object?> _values;

  /// Convertit une valeur JSON inconnue en map à clés textuelles.
  static Map<String, Object?> mapFrom(
    Object? value, {
    required String context,
  }) {
    // Cas nominal : `jsonDecode` produit une Map<String, dynamic>, compatible
    // avec Map<String, Object?>.
    if (value is Map<String, Object?>) {
      return value;
    }

    // Cas défensif : map à clés non typées (construction manuelle, test).
    if (value is Map<Object?, Object?>) {
      final Map<String, Object?> converted = <String, Object?>{};
      for (final MapEntry<Object?, Object?> entry in value.entries) {
        final Object? key = entry.key;
        if (key is! String) {
          throw FormatException('$context : clé JSON non textuelle.');
        }
        converted[key] = entry.value;
      }
      return converted;
    }

    // Tout autre type est refusé.
    throw FormatException('$context : objet JSON attendu.');
  }

  /// Vérifie la présence d'une clé non nulle.
  bool has(String key) => _values[key] != null;

  /// Lit une chaîne obligatoire, non vide et bornée.
  String requireString(String key, {int maxLength = 4000}) {
    final Object? value = _values[key];
    if (value is! String) {
      throw FormatException('Champ « $key » manquant ou non textuel.');
    }

    // Les espaces de bord ne portent aucune information métier.
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw FormatException('Champ « $key » vide.');
    }
    if (trimmed.length > maxLength) {
      throw FormatException('Champ « $key » trop long.');
    }
    return trimmed;
  }

  /// Lit une chaîne optionnelle ; une clé absente renvoie une chaîne vide.
  String optionalString(String key, {int maxLength = 4000}) {
    final Object? value = _values[key];
    if (value == null) {
      return '';
    }
    if (value is! String) {
      throw FormatException('Champ « $key » non textuel.');
    }

    final String trimmed = value.trim();
    if (trimmed.length > maxLength) {
      throw FormatException('Champ « $key » trop long.');
    }
    return trimmed;
  }

  /// Lit une chaîne nullable (null si absente ou vide).
  String? nullableString(String key, {int maxLength = 4000}) {
    final String value = optionalString(key, maxLength: maxLength);
    return value.isEmpty ? null : value;
  }

  /// Lit un entier obligatoire, avec bornes optionnelles.
  int requireInt(String key, {int? min, int? max}) {
    return _readInt(_values[key], key: key, min: min, max: max);
  }

  /// Lit un entier optionnel.
  int? optionalInt(String key, {int? min, int? max}) {
    final Object? value = _values[key];
    if (value == null) {
      return null;
    }
    return _readInt(value, key: key, min: min, max: max);
  }

  /// Lit un nombre décimal obligatoire.
  double requireDouble(String key, {double? min, double? max}) {
    return _readDouble(_values[key], key: key, min: min, max: max);
  }

  /// Lit un nombre décimal optionnel.
  double? optionalDouble(String key, {double? min, double? max}) {
    final Object? value = _values[key];
    if (value == null) {
      return null;
    }
    return _readDouble(value, key: key, min: min, max: max);
  }

  /// Lit un booléen optionnel avec valeur de repli.
  bool optionalBool(String key, {bool defaultValue = false}) {
    final Object? value = _values[key];
    if (value == null) {
      return defaultValue;
    }
    if (value is! bool) {
      throw FormatException('Champ « $key » : booléen attendu.');
    }
    return value;
  }

  /// Lit une liste obligatoire.
  List<Object?> requireList(String key, {int maxLength = 5000}) {
    final Object? value = _values[key];
    if (value is! List<Object?>) {
      throw FormatException('Champ « $key » : liste attendue.');
    }
    if (value.length > maxLength) {
      throw FormatException('Champ « $key » : liste trop longue.');
    }
    return value;
  }

  /// Lit une liste optionnelle (liste vide si absente).
  List<Object?> optionalList(String key, {int maxLength = 5000}) {
    final Object? value = _values[key];
    if (value == null) {
      return const <Object?>[];
    }
    if (value is! List<Object?>) {
      throw FormatException('Champ « $key » : liste attendue.');
    }
    if (value.length > maxLength) {
      throw FormatException('Champ « $key » : liste trop longue.');
    }
    return value;
  }

  /// Lit un objet obligatoire.
  Map<String, Object?> requireObject(String key) {
    final Object? value = _values[key];
    if (value == null) {
      throw FormatException('Champ « $key » manquant.');
    }
    return JsonReader.mapFrom(value, context: 'champ « $key »');
  }

  /// Lit un objet optionnel.
  Map<String, Object?>? optionalObject(String key) {
    final Object? value = _values[key];
    if (value == null) {
      return null;
    }
    return JsonReader.mapFrom(value, context: 'champ « $key »');
  }

  /// Lit une liste de chaînes, en ignorant les éléments non textuels.
  List<String> stringList(
    String key, {
    int maxItems = 100,
    int maxLength = 200,
  }) {
    final List<Object?> values = optionalList(key, maxLength: maxItems);
    final List<String> result = <String>[];
    for (final Object? value in values) {
      if (value is! String) {
        throw FormatException('Champ « $key » : texte attendu dans la liste.');
      }
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (trimmed.length > maxLength) {
        throw FormatException('Champ « $key » : élément trop long.');
      }
      result.add(trimmed);
    }
    return List<String>.unmodifiable(result);
  }

  /// Lit une liste d'entiers, avec bornes optionnelles.
  List<int> intList(String key, {int? min, int? max, int maxItems = 100}) {
    final List<Object?> values = optionalList(key, maxLength: maxItems);
    final List<int> result = <int>[];
    for (final Object? value in values) {
      result.add(_readInt(value, key: key, min: min, max: max));
    }
    return List<int>.unmodifiable(result);
  }

  /// Lit une date ISO-8601 obligatoire, convertie en UTC.
  DateTime requireDateTime(String key) {
    final String value = requireString(key, maxLength: 40);
    return _parseDate(value, key: key);
  }

  /// Lit une date ISO-8601 optionnelle, convertie en UTC.
  DateTime? optionalDateTime(String key) {
    final String value = optionalString(key, maxLength: 40);
    if (value.isEmpty) {
      return null;
    }
    return _parseDate(value, key: key);
  }

  // ---------------------------------------------------------------------------
  // Helpers privés
  // ---------------------------------------------------------------------------

  /// Valide et convertit un entier JSON.
  int _readInt(Object? value, {required String key, int? min, int? max}) {
    // Les entiers JSON sont désérialisés en `int`, mais un serveur peut envoyer
    // un double entier (ex. 1500.0) : on l'accepte sans perte.
    final int? parsed = switch (value) {
      final int intValue => intValue,
      final double doubleValue
          when doubleValue == doubleValue.roundToDouble() =>
        doubleValue.toInt(),
      _ => null,
    };

    if (parsed == null) {
      throw FormatException('Champ « $key » : entier attendu.');
    }
    if (min != null && parsed < min) {
      throw FormatException('Champ « $key » : valeur trop petite.');
    }
    if (max != null && parsed > max) {
      throw FormatException('Champ « $key » : valeur trop grande.');
    }
    return parsed;
  }

  /// Valide et convertit un nombre JSON.
  double _readDouble(
    Object? value, {
    required String key,
    double? min,
    double? max,
  }) {
    if (value is! num) {
      throw FormatException('Champ « $key » : nombre attendu.');
    }
    final double parsed = value.toDouble();
    if (parsed.isNaN || parsed.isInfinite) {
      throw FormatException('Champ « $key » : nombre non fini.');
    }
    if (min != null && parsed < min) {
      throw FormatException('Champ « $key » : valeur trop petite.');
    }
    if (max != null && parsed > max) {
      throw FormatException('Champ « $key » : valeur trop grande.');
    }
    return parsed;
  }

  /// Valide une date ISO-8601 et la ramène en UTC.
  DateTime _parseDate(String value, {required String key}) {
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('Champ « $key » : date invalide.');
    }

    final DateTime utc = parsed.toUtc();

    // Une date aberrante (horloge corrompue, saisie manuelle) est refusée.
    if (utc.year < 2020 || utc.year > 2100) {
      throw FormatException('Champ « $key » : date hors plage.');
    }
    return utc;
  }
}
