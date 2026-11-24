// =============================================================================
// Vues d'état asynchrone : chargement, erreur, liste vide.
// -----------------------------------------------------------------------------
// Trois écrans génériques et sans logique métier, partagés par toutes les pages.
// Ils garantissent un rendu homogène et rassurant : l'utilisateur comprend
// toujours ce qui se passe (chargement, échec avec réessai, absence de résultat).
// =============================================================================

// Widgets et Material.
import 'package:flutter/material.dart';

// Erreur métier déjà prête à afficher (message en français).
import '../../../../core/error/failures.dart';

// Palette sémantique et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Indicateur de chargement centré, avec message optionnel.
final class AppLoadingView extends StatelessWidget {
  /// Construit la vue de chargement.
  const AppLoadingView({this.message, super.key});

  /// Texte affiché sous l'indicateur (ex. « Chargement des maquis... »).
  final String? message;

  /// Construit la vue.
  @override
  Widget build(BuildContext context) {
    // Typographie locale.
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Message éventuel.
    final String? label = message;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Indicateur circulaire aux couleurs de la marque.
            const CircularProgressIndicator(),

            // Espacement conditionnel : rien si aucun message.
            if (label != null) const SizedBox(height: AppSpacing.md),

            // Message d'accompagnement.
            if (label != null)
              Text(
                label,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}

/// Vue d'erreur avec bouton « Réessayer ».
final class AppErrorView extends StatelessWidget {
  /// Construit la vue d'erreur.
  const AppErrorView({
    required this.failure,
    required this.onRetry,
    this.compact = false,
    super.key,
  });

  /// Erreur métier à afficher (message déjà sûr).
  final Failure failure;

  /// Action déclenchée par le bouton « Réessayer ».
  final VoidCallback onRetry;

  /// Réduit les marges lorsque la vue est insérée dans une liste.
  final bool compact;

  /// Construit la vue.
  @override
  Widget build(BuildContext context) {
    // Typographie et palette locales.
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppPalette palette = AppPalette.of(context);

    // Contenu commun, réutilisé dans les deux mises en page.
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Icône d'alerte colorée.
        Icon(Icons.wifi_off_outlined, size: 44, color: palette.danger),

        // Espacement.
        const SizedBox(height: AppSpacing.md),

        // Message métier (jamais de détail technique).
        Text(
          failure.message,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge,
        ),

        // Espacement.
        const SizedBox(height: AppSpacing.lg),

        // Bouton de réessai, action explicite et rassurante.
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
        ),
      ],
    );

    // Variante compacte : marges réduites pour insertion dans une liste.
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: content,
      );
    }

    // Variante pleine page : contenu centré.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: content,
      ),
    );
  }
}

/// Vue « liste vide » avec icône, titre, explication et action facultative.
final class AppEmptyView extends StatelessWidget {
  /// Construit la vue vide.
  const AppEmptyView({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
    super.key,
  });

  /// Icône illustrative.
  final IconData icon;

  /// Titre court (ex. « Aucun favori »).
  final String title;

  /// Explication complémentaire facultative.
  final String? message;

  /// Action facultative (bouton).
  final Widget? action;

  /// Réduit les marges pour une insertion dans une liste.
  final bool compact;

  /// Construit la vue.
  @override
  Widget build(BuildContext context) {
    // Typographie et palette locales.
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppPalette palette = AppPalette.of(context);

    // Message et action éventuels.
    final String? details = message;
    final Widget? trailingAction = action;

    // Contenu commun.
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Icône discrète (couleur secondaire).
        Icon(icon, size: 48, color: palette.mutedText),

        // Espacement.
        const SizedBox(height: AppSpacing.md),

        // Titre.
        Text(title, textAlign: TextAlign.center, style: textTheme.titleMedium),

        // Explication facultative.
        if (details != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            details,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: palette.mutedText),
          ),
        ],

        // Action facultative.
        if (trailingAction != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          trailingAction,
        ],
      ],
    );

    // Variante compacte.
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: content,
      );
    }

    // Variante pleine page.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: content,
      ),
    );
  }
}
