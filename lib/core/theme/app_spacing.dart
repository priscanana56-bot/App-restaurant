// =============================================================================
// Espacements, rayons et ombres.
// -----------------------------------------------------------------------------
// Une échelle unique (multiples de 4) garantit un rythme visuel régulier entre
// toutes les pages. Les ombres restent douces pour ne pas « salir » les photos.
// =============================================================================

// Material fournit `BoxShadow`, `Offset`, `BorderRadius`.
import 'package:flutter/material.dart';

/// Échelle d'espacement et de rayons.
final class AppSpacing {
  // Constructeur privé : constantes uniquement.
  const AppSpacing._();

  // ---------------------------------------------------------------------------
  // Espacements (multiples de 4)
  // ---------------------------------------------------------------------------

  /// Espacement minimal (4 px).
  static const double xxs = 4;

  /// Petit espacement (8 px).
  static const double xs = 8;

  /// Espacement compact (12 px).
  static const double sm = 12;

  /// Espacement standard (16 px), marge horizontale des écrans.
  static const double md = 16;

  /// Espacement large (24 px), séparation de sections.
  static const double lg = 24;

  /// Très large (32 px).
  static const double xl = 32;

  /// Espacement majeur (48 px), écrans vides ou héro.
  static const double xxl = 48;

  /// Marge horizontale par défaut d'une page.
  static const double pagePadding = 16;

  /// Hauteur minimale d'une cible tactile (accessibilité).
  static const double minTouchTarget = 48;

  /// Hauteur standard d'un bouton principal.
  static const double buttonHeight = 52;

  // ---------------------------------------------------------------------------
  // Rayons
  // ---------------------------------------------------------------------------

  /// Rayon des petits éléments (badges, puces).
  static const double radiusXs = 8;

  /// Rayon des champs de saisie et boutons compacts.
  static const double radiusSm = 12;

  /// Rayon standard des cartes.
  static const double radiusMd = 18;

  /// Rayon des feuilles modales et grandes surfaces.
  static const double radiusLg = 26;

  /// Rayon « pilule » pour un conteneur entièrement arrondi.
  static const double radiusPill = 999;

  /// `BorderRadius` prêt à l'emploi pour les cartes.
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(radiusMd),
  );

  /// `BorderRadius` prêt à l'emploi pour les feuilles modales.
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(radiusLg),
  );

  // ---------------------------------------------------------------------------
  // Durées d'animation
  // ---------------------------------------------------------------------------

  /// Transition rapide (états de bouton, badges).
  static const Duration fast = Duration(milliseconds: 150);

  /// Transition standard (apparition de carte, changement de filtre).
  static const Duration normal = Duration(milliseconds: 250);

  /// Transition lente (ouverture de feuille, changement de thème).
  static const Duration slow = Duration(milliseconds: 400);
}

/// Ombres douces réutilisables.
final class AppShadows {
  // Constructeur privé : constantes uniquement.
  const AppShadows._();

  /// Ombre légère des cartes en mode clair.
  static const List<BoxShadow> softLight = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -6,
    ),
  ];

  /// Ombre un peu plus marquée pour les éléments flottants (FAB, feuilles).
  static const List<BoxShadow> elevatedLight = <BoxShadow>[
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 32,
      offset: Offset(0, 12),
      spreadRadius: -8,
    ),
  ];

  /// Ombre des cartes en mode sombre : la profondeur vient du contraste.
  static const List<BoxShadow> softDark = <BoxShadow>[
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 20,
      offset: Offset(0, 8),
      spreadRadius: -6,
    ),
  ];
}
