// =============================================================================
// Palette de couleurs — psychologie de la restauration.
// -----------------------------------------------------------------------------
// Terracotta = chaleur de la braise et appétit.
// Vert basilic = fraîcheur, produits locaux, confiance.
// Safran = étoiles, promotions, signalétique positive.
// Les surfaces claires sont chaudes pour ne pas éblouir et valoriser les plats.
// =============================================================================

// Material fournit `Color`, `ThemeExtension` et `Brightness`.
import 'package:flutter/material.dart';

/// Couleurs brutes de la marque, indépendantes du thème clair/sombre.
final class AppColors {
  // Constructeur privé : espace de noms statique.
  const AppColors._();

  // ---------------------------------------------------------------------------
  // Couleurs de marque
  // ---------------------------------------------------------------------------

  /// Orange braise / terracotta : couleur primaire, actions et identité.
  static const Color terracotta = Color(0xFFE85D04);

  /// Variante plus sombre du terracotta (état pressé, texte sur fond clair).
  static const Color terracottaDeep = Color(0xFFC24A00);

  /// Variante claire du terracotta (conteneurs, badges discrets).
  static const Color terracottaSoft = Color(0xFFFFE6D3);

  /// Vert basilic : fraîcheur, produits locaux, couleur principale des actions
  /// et de la navigation (plus douce pour les yeux que l'orange en aplat).
  static const Color basil = Color(0xFF2D6A4F);

  /// Variante claire du basilic (fonds de badges, succès, mode sombre).
  static const Color basilSoft = Color(0xFFD8F3DC);

  /// Variante profonde du basilic (dégradés discrets, hiérarchie secondaire).
  static const Color basilDeep = Color(0xFF1B4332);

  /// Jaune safran : notes, promotions, mise en avant.
  static const Color saffron = Color(0xFFFFB703);

  /// Variante claire du safran (conteneurs d'avertissement doux).
  static const Color saffronSoft = Color(0xFFFFF3CD);

  // ---------------------------------------------------------------------------
  // Fonds et surfaces
  // ---------------------------------------------------------------------------

  /// Blanc crème chaud du mode clair : moins agressif qu'un blanc pur.
  static const Color cream = Color(0xFFFFFDF9);

  /// Blanc pur réservé aux cartes et feuilles du mode clair.
  static const Color pureWhite = Color(0xFFFFFFFF);

  /// Noir charbon du fond en mode sombre (sorties nocturnes en maquis).
  static const Color charcoal = Color(0xFF121212);

  /// Surface des cartes en mode sombre, légèrement plus claire que le fond.
  static const Color charcoalSurface = Color(0xFF1E1E1E);

  /// Anthracite du texte principal en mode clair.
  static const Color anthracite = Color(0xFF1B1B1B);

  /// Blanc cassé du texte principal en mode sombre.
  static const Color offWhite = Color(0xFFF5F5F5);

  // ---------------------------------------------------------------------------
  // Badges de statut (valeurs imposées par la charte produit)
  // ---------------------------------------------------------------------------

  /// Statut « Ouvert » et « Live Braise prêt ».
  static const Color statusOpen = Color(0xFF2D6A4F);

  /// Statut « Fermé » et « Épuisé ».
  static const Color statusClosed = Color(0xFFD00000);

  /// Badge « Vérifié sur place ».
  static const Color statusVerified = Color(0xFF0077B6);

  /// Version claire du rouge fermé, pour les conteneurs.
  static const Color statusClosedSoft = Color(0xFFFFE0E0);

  /// Version claire du bleu vérifié, pour les conteneurs.
  static const Color statusVerifiedSoft = Color(0xFFD9EEFF);

  // ---------------------------------------------------------------------------
  // Neutres fonctionnels
  // ---------------------------------------------------------------------------

  /// Texte secondaire gris chaud en mode clair.
  static const Color textMuted = Color(0xFF6B6B6B);

  /// Texte secondaire en mode sombre.
  static const Color textMutedDark = Color(0xFFB0B0B0);

  /// Bordure douce en mode clair.
  static const Color outlineLight = Color(0xFFE8E0D6);

  /// Bordure discrète en mode sombre.
  static const Color outlineDark = Color(0xFF383838);

  /// Ombre douce des cartes claires (noir à 10 % d'opacité).
  static const Color shadowLight = Color(0x1A000000);

  /// Ombre plus dense en mode sombre (le relief doit rester perceptible).
  static const Color shadowDark = Color(0x66000000);

  /// Voile sombre affiché derrière les feuilles modales.
  static const Color scrim = Color(0x99000000);
}

/// Couleurs sémantiques dépendantes du thème (clair ou sombre).
/// Un `ThemeExtension` permet d'y accéder partout sans condition sur `Brightness`.
@immutable
final class AppPalette extends ThemeExtension<AppPalette> {
  /// Constructeur complet : chaque couleur sémantique doit être fournie.
  const AppPalette({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.verified,
    required this.onVerified,
    required this.verifiedContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.price,
    required this.cta,
    required this.onCta,
    required this.mutedText,
    required this.cardShadow,
  });

  /// Vert de succès / ouverture.
  final Color success;

  /// Contenu lisible sur [success].
  final Color onSuccess;

  /// Fond clair associé au succès.
  final Color successContainer;

  /// Rouge d'erreur / fermeture / épuisement.
  final Color danger;

  /// Contenu lisible sur [danger].
  final Color onDanger;

  /// Fond clair associé au danger.
  final Color dangerContainer;

  /// Bleu du badge « Vérifié sur place ».
  final Color verified;

  /// Contenu lisible sur [verified].
  final Color onVerified;

  /// Fond clair associé à la vérification.
  final Color verifiedContainer;

  /// Jaune d'avertissement / promotion.
  final Color warning;

  /// Contenu lisible sur [warning].
  final Color onWarning;

  /// Fond clair associé à l'avertissement.
  final Color warningContainer;

  /// Couleur des montants FCFA : orange foncé en mode clair pour rester lisible
  /// sur fond crème, terracotta en mode sombre.
  final Color price;

  /// Fond des boutons principaux (appels à l'action) : terracotta de la marque.
  final Color cta;

  /// Texte lisible sur [cta] (anthracite, meilleur contraste que du blanc).
  final Color onCta;

  /// Texte secondaire adapté au thème.
  final Color mutedText;

  /// Couleur d'ombre des cartes, adaptée à la luminosité.
  final Color cardShadow;

  /// Palette du mode clair.
  static const AppPalette light = AppPalette(
    success: AppColors.statusOpen,
    onSuccess: AppColors.pureWhite,
    successContainer: AppColors.basilSoft,
    danger: AppColors.statusClosed,
    onDanger: AppColors.pureWhite,
    dangerContainer: AppColors.statusClosedSoft,
    verified: AppColors.statusVerified,
    onVerified: AppColors.pureWhite,
    verifiedContainer: AppColors.statusVerifiedSoft,
    warning: AppColors.saffron,
    onWarning: AppColors.anthracite,
    warningContainer: AppColors.saffronSoft,
    price: AppColors.terracottaDeep,
    cta: AppColors.terracotta,
    onCta: AppColors.anthracite,
    mutedText: AppColors.textMuted,
    cardShadow: AppColors.shadowLight,
  );

  /// Palette du mode sombre, avec des teintes plus lumineuses pour le contraste.
  static const AppPalette dark = AppPalette(
    success: Color(0xFF74C69D),
    onSuccess: Color(0xFF06281A),
    successContainer: Color(0xFF1B4332),
    danger: Color(0xFFFF6B6B),
    onDanger: Color(0xFF2A0000),
    dangerContainer: Color(0xFF4A1010),
    verified: Color(0xFF4DA3D9),
    onVerified: Color(0xFF001E2E),
    verifiedContainer: Color(0xFF003049),
    warning: Color(0xFFFFC94D),
    onWarning: Color(0xFF2A1E00),
    warningContainer: Color(0xFF4A3600),
    price: AppColors.terracotta,
    cta: AppColors.terracotta,
    onCta: AppColors.anthracite,
    mutedText: AppColors.textMutedDark,
    cardShadow: AppColors.shadowDark,
  );

  /// Accès rapide à la palette depuis un `BuildContext`.
  /// Si l'extension est absente (widget isolé dans un test), on retombe sur le clair.
  static AppPalette of(BuildContext context) {
    // Lecture de l'extension ajoutée par `AppTheme`.
    final AppPalette? palette = Theme.of(context).extension<AppPalette>();

    // Repli sûr : jamais de `null` renvoyé à l'UI.
    return palette ?? AppPalette.light;
  }

  /// Copie avec surcharge partielle, pratique pour les variantes locales.
  @override
  AppPalette copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? verified,
    Color? onVerified,
    Color? verifiedContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? price,
    Color? cta,
    Color? onCta,
    Color? mutedText,
    Color? cardShadow,
  }) {
    // Chaque champ absent conserve sa valeur actuelle.
    return AppPalette(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      verified: verified ?? this.verified,
      onVerified: onVerified ?? this.onVerified,
      verifiedContainer: verifiedContainer ?? this.verifiedContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      price: price ?? this.price,
      cta: cta ?? this.cta,
      onCta: onCta ?? this.onCta,
      mutedText: mutedText ?? this.mutedText,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  /// Interpolation utilisée par Flutter lors d'une transition de thème.
  @override
  AppPalette lerp(covariant ThemeExtension<AppPalette>? other, double t) {
    // Si l'autre palette n'est pas du bon type, aucune interpolation possible.
    if (other is! AppPalette) {
      return this;
    }

    // Interpolation canal par canal, avec repli sur la valeur courante.
    return AppPalette(
      success: Color.lerp(success, other.success, t) ?? success,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t) ?? onSuccess,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t) ??
          successContainer,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      onDanger: Color.lerp(onDanger, other.onDanger, t) ?? onDanger,
      dangerContainer:
          Color.lerp(dangerContainer, other.dangerContainer, t) ??
          dangerContainer,
      verified: Color.lerp(verified, other.verified, t) ?? verified,
      onVerified: Color.lerp(onVerified, other.onVerified, t) ?? onVerified,
      verifiedContainer:
          Color.lerp(verifiedContainer, other.verifiedContainer, t) ??
          verifiedContainer,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      onWarning: Color.lerp(onWarning, other.onWarning, t) ?? onWarning,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t) ??
          warningContainer,
      price: Color.lerp(price, other.price, t) ?? price,
      cta: Color.lerp(cta, other.cta, t) ?? cta,
      onCta: Color.lerp(onCta, other.onCta, t) ?? onCta,
      mutedText: Color.lerp(mutedText, other.mutedText, t) ?? mutedText,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t) ?? cardShadow,
    );
  }
}
