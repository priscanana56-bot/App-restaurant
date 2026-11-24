// =============================================================================
// AppTheme — construction des thèmes clair et sombre.
// -----------------------------------------------------------------------------
// Un seul point de vérité pour les couleurs, typographies, formes et états des
// composants. Les widgets n'utilisent que `Theme.of(context)` et `AppPalette`,
// jamais une couleur codée en dur.
// =============================================================================

// Material : ThemeData et tous les sous-thèmes.
import 'package:flutter/material.dart';

// Contrôle de la barre d'état (icônes claires/sombres).
import 'package:flutter/services.dart';

// Palette brute + extension sémantique.
import 'app_colors.dart';

// Échelle d'espacement, rayons et ombres.
import 'app_spacing.dart';

// Échelle typographique.
import 'app_typography.dart';

/// Fabrique des thèmes de l'application.
final class AppTheme {
  // Constructeur privé : accès uniquement via `AppTheme.light` / `AppTheme.dark`.
  const AppTheme._();

  // ---------------------------------------------------------------------------
  // API publique
  // ---------------------------------------------------------------------------

  /// Thème clair : fond crème chaud et cartes blanches.
  static ThemeData get light => _build(brightness: Brightness.light);

  /// Thème sombre : charbon et cartes #1E1E1E, pensé pour les maquis du soir.
  static ThemeData get dark => _build(brightness: Brightness.dark);

  /// Palette sémantique à utiliser dans les widgets :
  /// `AppPalette.of(context).danger`, etc.
  static AppPalette paletteOf(BuildContext context) => AppPalette.of(context);

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  /// Construit un thème complet pour la luminosité demandée.
  static ThemeData _build({required Brightness brightness}) {
    // Raccourci booléen utilisé pour toutes les variantes.
    final bool isDark = brightness == Brightness.dark;

    // Schéma Material 3 : couleurs de base et de surfaces.
    final ColorScheme scheme = isDark ? _darkScheme : _lightScheme;

    // Extension de couleurs métier (statuts, ombres, texte secondaire).
    final AppPalette palette = isDark ? AppPalette.dark : AppPalette.light;

    // Application des couleurs de texte au thème typographique commun.
    final TextTheme textTheme = AppTypography.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    // Couleur de fond de l'échafaudage, distincte de la surface des cartes.
    final Color scaffoldColor = isDark ? AppColors.charcoal : AppColors.cream;

    // Couleur des champs de saisie, légèrement teintée pour se détacher.
    final Color fieldFill = isDark
        ? const Color(0xFF242424)
        : const Color(0xFFFFF8F0);

    // Thème complet construit en une passe.
    return ThemeData(
      // Material 3 est le langage de design de référence.
      useMaterial3: true,

      // Luminosité explicite (pilote les composants natifs).
      brightness: brightness,

      // Schéma de couleurs complet.
      colorScheme: scheme,

      // Fond de page : crème en clair, charbon en sombre.
      scaffoldBackgroundColor: scaffoldColor,

      // Typographie appliquée à toute l'application.
      textTheme: textTheme,

      // Densité standard : cibles tactiles accessibles.
      visualDensity: VisualDensity.standard,

      // Hauteur minimale des zones tactiles conforme aux recommandations.
      materialTapTargetSize: MaterialTapTargetSize.padded,

      // Extension métier accessible via `AppPalette.of(context)`.
      extensions: <ThemeExtension<AppPalette>>[palette],

      // -----------------------------------------------------------------------
      // Barre d'application
      // -----------------------------------------------------------------------
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: palette.cardShadow,
        centerTitle: false,
        titleSpacing: AppSpacing.md,
        toolbarHeight: 60,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),

      // -----------------------------------------------------------------------
      // Cartes
      // -----------------------------------------------------------------------
      cardTheme: CardThemeData(
        color: isDark ? AppColors.charcoalSurface : AppColors.pureWhite,
        surfaceTintColor: Colors.transparent,
        shadowColor: palette.cardShadow,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.cardRadius,
        ),
      ),

      // -----------------------------------------------------------------------
      // Champs de saisie
      // -----------------------------------------------------------------------
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.mutedText),
        labelStyle: textTheme.bodyMedium?.copyWith(color: palette.mutedText),
        floatingLabelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.primary,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: palette.danger),
        prefixIconColor: palette.mutedText,
        suffixIconColor: palette.mutedText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: palette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: palette.danger, width: 1.6),
        ),
      ),

      // -----------------------------------------------------------------------
      // Boutons
      // -----------------------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Appel à l'action : terracotta de la marque, texte anthracite pour
          // un contraste confortable (le blanc sur orange était trop agressif).
          backgroundColor: palette.cta,
          foregroundColor: palette.onCta,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.10),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Bouton secondaire : contour vert basilic, fond transparent.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.secondary,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          side: BorderSide(color: scheme.secondary.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Bouton texte : actions discrètes (annuler, voir plus).
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Bouton flottant : même appel à l'action que le bouton principal.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.cta,
        foregroundColor: palette.onCta,
        elevation: 3,
        focusElevation: 4,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),

      // -----------------------------------------------------------------------
      // Puces / filtres
      // -----------------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        secondarySelectedColor: scheme.secondaryContainer,
        disabledColor: scheme.surfaceContainerHighest,
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        showCheckmark: false,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
      ),

      // -----------------------------------------------------------------------
      // Navigation
      // -----------------------------------------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (Set<WidgetState> states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : palette.mutedText,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (Set<WidgetState> states) => textTheme.labelSmall!.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : palette.mutedText,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: palette.mutedText,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),

      // -----------------------------------------------------------------------
      // Surfaces modales
      // -----------------------------------------------------------------------
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.sheetRadius,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        textStyle: textTheme.bodyMedium,
      ),

      // -----------------------------------------------------------------------
      // Composants divers
      // -----------------------------------------------------------------------
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        minLeadingWidth: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outlineVariant,
        circularTrackColor: scheme.outlineVariant,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? scheme.surfaceContainerHighest
            : AppColors.anthracite,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? scheme.onSurface : AppColors.offWhite,
        ),
        actionTextColor: isDark ? AppColors.saffron : AppColors.saffron,
        elevation: 4,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        ),
        textStyle: textTheme.labelSmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
        preferBelow: false,
      ),

      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.22),
        selectionHandleColor: scheme.primary,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Schémas de couleurs
  // ---------------------------------------------------------------------------

  /// Schéma Material 3 du mode clair.
  ///
  /// Le vert basilic pilote la navigation et les actions courantes : c'est une
  /// teinte plus douce que l'orange en grand aplat. Le terracotta reste réservé
  /// aux prix et aux boutons principaux via `AppPalette.cta`.
  static const ColorScheme _lightScheme = ColorScheme.light(
    primary: AppColors.basil,
    onPrimary: AppColors.pureWhite,
    primaryContainer: AppColors.basilSoft,
    onPrimaryContainer: Color(0xFF0B2E1F),
    secondary: AppColors.basil,
    onSecondary: AppColors.pureWhite,
    secondaryContainer: AppColors.basilSoft,
    onSecondaryContainer: Color(0xFF0B2E1F),
    tertiary: AppColors.saffron,
    onTertiary: AppColors.anthracite,
    tertiaryContainer: AppColors.saffronSoft,
    onTertiaryContainer: Color(0xFF3D2B00),
    error: AppColors.statusClosed,
    onError: AppColors.pureWhite,
    errorContainer: AppColors.statusClosedSoft,
    onErrorContainer: Color(0xFF410000),
    surface: AppColors.pureWhite,
    onSurface: AppColors.anthracite,
    surfaceDim: Color(0xFFF2EBE2),
    surfaceBright: AppColors.pureWhite,
    surfaceContainerLowest: AppColors.pureWhite,
    surfaceContainerLow: Color(0xFFFFFAF3),
    surfaceContainer: Color(0xFFFFF7ED),
    surfaceContainerHigh: Color(0xFFF8F1E7),
    surfaceContainerHighest: Color(0xFFF0E8DC),
    onSurfaceVariant: AppColors.textMuted,
    outline: AppColors.outlineLight,
    outlineVariant: Color(0xFFF0E8DD),
    shadow: AppColors.shadowLight,
    scrim: AppColors.scrim,
    inverseSurface: AppColors.anthracite,
    onInverseSurface: AppColors.offWhite,
    inversePrimary: AppColors.basilSoft,
  );

  /// Schéma Material 3 du mode sombre : mêmes rôles qu'en mode clair, avec des
  /// verts plus lumineux pour rester lisibles sur le charbon.
  static const ColorScheme _darkScheme = ColorScheme.dark(
    primary: AppColors.basilSoft,
    onPrimary: Color(0xFF06281A),
    primaryContainer: AppColors.basilDeep,
    onPrimaryContainer: AppColors.basilSoft,
    secondary: AppColors.basilSoft,
    onSecondary: Color(0xFF06281A),
    secondaryContainer: AppColors.basilDeep,
    onSecondaryContainer: AppColors.basilSoft,
    tertiary: Color(0xFFFFC94D),
    onTertiary: Color(0xFF2A1E00),
    tertiaryContainer: Color(0xFF5C4300),
    onTertiaryContainer: Color(0xFFFFE7A3),
    error: Color(0xFFFF6B6B),
    onError: Color(0xFF2A0000),
    errorContainer: Color(0xFF5C1010),
    onErrorContainer: Color(0xFFFFD9D9),
    surface: AppColors.charcoalSurface,
    onSurface: AppColors.offWhite,
    surfaceDim: Color(0xFF0D0D0D),
    surfaceBright: Color(0xFF2A2A2A),
    surfaceContainerLowest: Color(0xFF0D0D0D),
    surfaceContainerLow: Color(0xFF161616),
    surfaceContainer: AppColors.charcoalSurface,
    surfaceContainerHigh: Color(0xFF242424),
    surfaceContainerHighest: Color(0xFF2A2A2A),
    onSurfaceVariant: AppColors.textMutedDark,
    outline: AppColors.outlineDark,
    outlineVariant: Color(0xFF2C2C2C),
    shadow: Color(0xFF000000),
    scrim: AppColors.scrim,
    inverseSurface: AppColors.offWhite,
    onInverseSurface: AppColors.anthracite,
    inversePrimary: AppColors.basil,
  );
}
