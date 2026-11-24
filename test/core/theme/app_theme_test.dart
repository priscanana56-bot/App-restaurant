// =============================================================================
// Tests de la charte visuelle.
// -----------------------------------------------------------------------------
// Ces tests verrouillent les rôles des couleurs : vert basilic pour la
// navigation et les actions courantes, terracotta pour les prix et les boutons
// principaux, fonds crème en clair et charbon en sombre.
// =============================================================================

// Types Material (ThemeData, ButtonStyle, WidgetState) et framework de test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Palette et thèmes testés.
import 'package:koudougou_gourmet/core/theme/app_colors.dart';
import 'package:koudougou_gourmet/core/theme/app_theme.dart';

/// Point d'entrée des tests.
void main() {
  group('AppTheme', () {
    test('le vert basilic pilote la navigation en mode clair', () {
      final ThemeData theme = AppTheme.light;

      expect(theme.colorScheme.primary, AppColors.basil);
      expect(theme.colorScheme.secondary, AppColors.basil);
      expect(theme.colorScheme.primaryContainer, AppColors.basilSoft);
      expect(theme.scaffoldBackgroundColor, AppColors.cream);
    });

    test('le terracotta est réservé aux appels à l’action', () {
      final ThemeData theme = AppTheme.light;
      final ButtonStyle style = theme.filledButtonTheme.style!;

      expect(
        style.backgroundColor!.resolve(<WidgetState>{}),
        AppColors.terracotta,
      );
      expect(
        style.foregroundColor!.resolve(<WidgetState>{}),
        AppColors.anthracite,
      );
      expect(
        theme.floatingActionButtonTheme.backgroundColor,
        AppColors.terracotta,
      );
    });

    test('les montants restent lisibles dans les deux modes', () {
      // Orange foncé sur fond crème en clair, terracotta sur charbon en sombre.
      expect(AppPalette.light.price, AppColors.terracottaDeep);
      expect(AppPalette.dark.price, AppColors.terracotta);
      expect(AppPalette.light.cta, AppColors.terracotta);
      expect(AppPalette.dark.cta, AppColors.terracotta);
      expect(AppPalette.light.onCta, AppColors.anthracite);
      expect(AppPalette.dark.onCta, AppColors.anthracite);
    });

    test('le mode sombre garde des verts lumineux sur fond charbon', () {
      final ThemeData theme = AppTheme.dark;

      expect(theme.colorScheme.primary, AppColors.basilSoft);
      expect(theme.scaffoldBackgroundColor, AppColors.charcoal);
    });
  });
}
