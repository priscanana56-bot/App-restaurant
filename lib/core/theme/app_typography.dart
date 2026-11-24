// =============================================================================
// Typographie de l'application.
// -----------------------------------------------------------------------------
// Échelle volontairement courte et lisible sur petits écrans, avec des hauteurs
// de ligne généreuses : les noms de plats et les prix doivent rester lisibles
// en plein soleil comme dans un maquis sombre.
//
// Pour une identité encore plus forte, ajouter la police Poppins en asset :
//   assets/fonts/Poppins-Regular.ttf, Poppins-SemiBold.ttf, Poppins-Bold.ttf
// puis déclarer `fontFamily: 'Poppins'` dans ce fichier et dans pubspec.yaml.
// =============================================================================

// Material fournit `TextStyle`, `TextTheme` et `FontWeight`.
import 'package:flutter/material.dart';

/// Échelle typographique Material 3 personnalisée.
final class AppTypography {
  // Constructeur privé : la classe expose uniquement une échelle statique.
  const AppTypography._();

  /// Familles de repli si la police de marque n'est pas disponible.
  /// Flutter utilise la première police installée sur l'appareil.
  static const List<String> fontFallback = <String>[
    'Poppins',
    'Roboto',
    'Segoe UI',
    'Helvetica Neue',
  ];

  /// Construit un style cohérent avec les paramètres de la marque.
  static TextStyle _style({
    required double size,
    required FontWeight weight,
    required double height,
    double letterSpacing = 0,
  }) {
    // Aucun `fontFamily` en dur : le thème système reste la référence,
    // avec la liste de repli ci-dessus pour une future police embarquée.
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      fontFamilyFallback: fontFallback,
    );
  }

  /// Échelle complète utilisée par `AppTheme`.
  static final TextTheme textTheme = TextTheme(
    // ---------------------------------------------------------------------
    // Titres d'écran
    // ---------------------------------------------------------------------
    displayLarge: _style(
      size: 40,
      weight: FontWeight.w700,
      height: 1.12,
      letterSpacing: -0.8,
    ),
    displayMedium: _style(
      size: 34,
      weight: FontWeight.w700,
      height: 1.14,
      letterSpacing: -0.6,
    ),
    displaySmall: _style(
      size: 30,
      weight: FontWeight.w700,
      height: 1.16,
      letterSpacing: -0.4,
    ),

    // ---------------------------------------------------------------------
    // En-têtes de sections
    // ---------------------------------------------------------------------
    headlineLarge: _style(
      size: 28,
      weight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -0.3,
    ),
    headlineMedium: _style(
      size: 24,
      weight: FontWeight.w700,
      height: 1.22,
      letterSpacing: -0.2,
    ),
    headlineSmall: _style(size: 21, weight: FontWeight.w700, height: 1.25),

    // ---------------------------------------------------------------------
    // Titres de cartes et de listes
    // ---------------------------------------------------------------------
    titleLarge: _style(size: 19, weight: FontWeight.w700, height: 1.3),
    titleMedium: _style(size: 16, weight: FontWeight.w600, height: 1.35),
    titleSmall: _style(size: 14, weight: FontWeight.w600, height: 1.35),

    // ---------------------------------------------------------------------
    // Corps de texte
    // ---------------------------------------------------------------------
    bodyLarge: _style(size: 16, weight: FontWeight.w400, height: 1.45),
    bodyMedium: _style(size: 14, weight: FontWeight.w400, height: 1.42),
    bodySmall: _style(size: 12, weight: FontWeight.w400, height: 1.38),

    // ---------------------------------------------------------------------
    // Libellés, boutons et badges
    // ---------------------------------------------------------------------
    labelLarge: _style(
      size: 14,
      weight: FontWeight.w600,
      height: 1.3,
      letterSpacing: 0.1,
    ),
    labelMedium: _style(
      size: 12,
      weight: FontWeight.w600,
      height: 1.3,
      letterSpacing: 0.3,
    ),
    labelSmall: _style(
      size: 11,
      weight: FontWeight.w700,
      height: 1.3,
      letterSpacing: 0.7,
    ),
  );
}
