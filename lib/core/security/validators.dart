// =============================================================================
// Validateurs de formulaires (couche Présentation).
// -----------------------------------------------------------------------------
// Chaque méthode retourne `null` si la valeur est valide, ou un message français
// prêt à afficher sous un champ. Elles s'appuient TOUJOURS sur `InputSanitizer`.
// =============================================================================

// Sanitizer : unique porte d'entrée des données saisies.
import 'input_sanitizer.dart';

/// Collection de validateurs réutilisables par les formulaires Flutter.
final class AppValidators {
  // Constructeur privé : utilitaires statiques uniquement.
  const AppValidators._();

  /// Valide une requête de recherche.
  static String? search(String? value) {
    // Nettoyage : la valeur brute n'est jamais utilisée directement.
    final String clean = InputSanitizer.sanitizeSearchQuery(value);

    // Une recherche vide est autorisée (elle réinitialise le filtre).
    if (clean.isEmpty) {
      return null;
    }

    // Une recherche d'un seul caractère est peu utile mais non dangereuse.
    // On exige toutefois au moins deux caractères pour lancer une requête réseau.
    if (clean.length < 2) {
      return 'Saisissez au moins 2 caractères.';
    }

    // Aucun message : champ valide.
    return null;
  }

  /// Valide un numéro de téléphone burkinabè et exige le format international.
  static String? phone(String? value) {
    // Tentative de normalisation stricte.
    final String? normalized = InputSanitizer.sanitizePhoneNumber(value);

    // `null` signifie numéro absent ou mal formé.
    if (normalized == null) {
      return 'Numéro invalide. Exemple : +226 70 00 00 00.';
    }

    // Numéro valide.
    return null;
  }

  /// Valide un e-mail professionnel (portail gérant).
  static String? email(String? value) {
    // Normalisation et contrôle de format.
    if (InputSanitizer.sanitizeEmail(value) == null) {
      return 'Adresse e-mail invalide.';
    }

    // Aucun message : champ valide.
    return null;
  }

  /// Valide un prix en FCFA.
  static String? priceFcfa(String? value) {
    // Un prix doit être un entier positif plausible.
    if (InputSanitizer.sanitizePriceFcfa(value) == null) {
      return 'Indiquez un prix entier valide en FCFA.';
    }

    // Prix accepté.
    return null;
  }

  /// Valide une quantité d'article.
  static String? quantity(String? value) {
    // La quantité doit être comprise entre 1 et la borne globale.
    if (InputSanitizer.sanitizeQuantity(value) == null) {
      return 'Quantité invalide.';
    }

    // Quantité acceptée.
    return null;
  }

  /// Valide un texte obligatoire (nom de plat, description...).
  static String? requiredText(String? value, {int maxLength = 120}) {
    // Nettoyage puis contrôle de présence.
    final String clean = InputSanitizer.sanitizeShortLabel(
      value,
      maxLength: maxLength,
    );
    if (clean.isEmpty) {
      return 'Ce champ est obligatoire.';
    }

    // Contrôle de longueur après nettoyage (les balises ont pu être retirées).
    if (clean.length < 3) {
      return 'Saisissez au moins 3 caractères.';
    }

    // Aucun message : champ valide.
    return null;
  }

  /// Valide une adresse e-mail ou un téléphone selon le mode choisi.
  static String? contact(String? value) {
    // Un numéro de téléphone valide suffit.
    if (InputSanitizer.sanitizePhoneNumber(value) != null) {
      return null;
    }

    // Sinon, on tente l'e-mail.
    if (InputSanitizer.sanitizeEmail(value) != null) {
      return null;
    }

    // Ni l'un ni l'autre : message commun.
    return 'Indiquez un téléphone ou un e-mail valide.';
  }
}
