// =============================================================================
// Validation des chemins d'assets locaux.
// -----------------------------------------------------------------------------
// Un chemin d'image vient du seed ou de l'API : il ne doit jamais permettre de
// sortir du dossier `assets/images/` (pas de `..`, pas d'URL, pas de schéma).
// Un chemin invalide est ignoré (photo absente) plutôt que de faire planter
// l'interface.
// =============================================================================

/// Validateur centralisé des chemins d'images embarquées.
final class AssetPathValidator {
  // Constructeur privé : espace de noms statique.
  const AssetPathValidator._();

  // Motif strict : dossier connu, minuscules, chiffres, tirets, underscores.
  static final RegExp _pattern = RegExp(
    r'^assets/images/[a-z0-9][a-z0-9/_-]*\.(jpg|jpeg|png|webp)$',
  );

  /// Retourne le chemin sûr, ou `null` si la valeur est absente/invalide.
  static String? sanitize(String? raw) {
    // Normalisation minimale.
    final String value = (raw ?? '').trim();

    // Absence de photo : cas normal, pas une erreur.
    if (value.isEmpty || value.length > 200) {
      return null;
    }

    // Refus des traversées de répertoire et des extensions inattendues.
    if (value.contains('..') || !_pattern.hasMatch(value)) {
      return null;
    }

    // Chemin conforme.
    return value;
  }
}
