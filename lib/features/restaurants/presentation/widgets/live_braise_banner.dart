// =============================================================================
// Bandeau « Live Braise ».
// -----------------------------------------------------------------------------
// Le Live Braise est l'argument différenciant de l'application : une viande ou
// un poisson braisé, en quantité limitée, pendant une fenêtre de temps courte.
// Deux composants sont fournis :
//   - `LiveBraiseStrip` : carrousel horizontal affiché sur l'accueil ;
//   - `LiveBraiseHighlight` : carte détaillée affichée dans la fiche restaurant.
// Le temps restant est TOUJOURS recalculé à partir de l'instant de référence
// fourni par le BLoC : rien n'est figé dans le widget.
// =============================================================================

// Widgets et Material.
import 'package:flutter/material.dart';

// Entité affichée.
import '../../domain/entities/live_braise_status.dart';

// Palette, espacements et formatage.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';

/// Carrousel horizontal des braises actives.
final class LiveBraiseStrip extends StatelessWidget {
  /// Construit le carrousel.
  const LiveBraiseStrip({
    required this.braises,
    required this.now,
    required this.onTap,
    super.key,
  });

  /// Braises actives (déjà filtrées par le use case).
  final List<LiveBraiseStatus> braises;

  /// Instant de référence (heure de Koudougou).
  final DateTime now;

  /// Callback d'ouverture de la fiche du restaurant concerné.
  final void Function(String restaurantId) onTap;

  /// Construit le carrousel, ou rien s'il n'y a aucune braise active.
  @override
  Widget build(BuildContext context) {
    // Aucune braise : le bandeau disparaît complètement de l'accueil.
    if (braises.isEmpty) {
      return const SizedBox.shrink();
    }

    // Thème et typographie locales.
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // En-tête de section avec icône flamme.
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.local_fire_department,
                color: theme.colorScheme.tertiary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Live Braise',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'en ce moment',
                style: textTheme.bodySmall?.copyWith(
                  color: AppPalette.of(context).mutedText,
                ),
              ),
            ],
          ),
        ),

        // Liste horizontale de cartes compactes.
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            // Padding horizontal nul : la liste est déjà encadrée par la page.
            itemCount: braises.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              // Braise courante.
              final LiveBraiseStatus braise = braises[index];

              return _LiveBraiseCard(
                braise: braise,
                now: now,
                // Ouverture de la fiche du restaurant concerné.
                onTap: () => onTap(braise.restaurantId),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Carte compacte d'une braise dans le carrousel.
final class _LiveBraiseCard extends StatelessWidget {
  /// Construit la carte.
  const _LiveBraiseCard({
    required this.braise,
    required this.now,
    required this.onTap,
  });

  /// Braise affichée.
  final LiveBraiseStatus braise;

  /// Instant de référence.
  final DateTime now;

  /// Action d'ouverture.
  final VoidCallback onTap;

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    // Thème, typographie et palette locales.
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final AppPalette palette = AppPalette.of(context);

    // Minutes restantes avant la fin de la session.
    final int remaining = braise.remainingMinutesAt(now);

    return SizedBox(
      width: 260,
      child: Card(
        // La carte est cliquable sur toute sa surface.
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Nom du restaurant.
                Text(
                  braise.restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: palette.mutedText,
                  ),
                ),

                // Plat braisé mis en avant.
                Text(
                  braise.dishName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                // Espacement.
                const SizedBox(height: AppSpacing.xs),

                // Prix d'une portion.
                Text(
                  AppFormatters.fcfa(braise.priceFcfa),
                  style: textTheme.titleSmall?.copyWith(
                    color: AppPalette.of(context).price,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                // Pousse le bas de carte vers le bas.
                const Spacer(),

                // Temps restant.
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: palette.mutedText,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      remaining > 0
                          ? '$remaining min restantes'
                          : 'Dernières portions',
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.mutedText,
                      ),
                    ),
                  ],
                ),

                // Barre de progression des portions servies.
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  child: LinearProgressIndicator(
                    value: braise.servedPercentage / 100,
                    minHeight: 6,
                    backgroundColor: palette.mutedText.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.tertiary,
                    ),
                  ),
                ),

                // Nombre de portions restantes.
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${braise.portionsRemaining} / ${braise.portionsTotal} portions',
                  style: textTheme.bodySmall?.copyWith(
                    color: palette.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte détaillée d'une braise active (fiche restaurant).
final class LiveBraiseHighlight extends StatelessWidget {
  /// Construit la carte détaillée.
  const LiveBraiseHighlight({
    required this.braise,
    required this.now,
    super.key,
  });

  /// Braise affichée.
  final LiveBraiseStatus braise;

  /// Instant de référence.
  final DateTime now;

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    // Thème, typographie et palette locales.
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final AppPalette palette = AppPalette.of(context);

    // Minutes restantes.
    final int remaining = braise.remainingMinutesAt(now);

    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Titre de section.
            Row(
              children: <Widget>[
                Icon(
                  Icons.local_fire_department,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Live Braise en cours',
                  style: textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            // Espacement.
            const SizedBox(height: AppSpacing.sm),

            // Plat braisé.
            Text(
              braise.dishName,
              style: textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),

            // Description courte.
            const SizedBox(height: AppSpacing.xxs),
            Text(
              braise.description,
              style: textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),

            // Espacement.
            const SizedBox(height: AppSpacing.sm),

            // Prix et temps restant.
            Row(
              children: <Widget>[
                // Prix d'une portion.
                Text(
                  AppFormatters.fcfa(braise.priceFcfa),
                  style: textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Temps restant.
                Text(
                  remaining > 0 ? '$remaining min' : 'Bientôt terminé',
                  style: textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),

            // Espacement.
            const SizedBox(height: AppSpacing.sm),

            // Progression des portions.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: LinearProgressIndicator(
                value: braise.servedPercentage / 100,
                minHeight: 8,
                backgroundColor: palette.mutedText.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.tertiary,
                ),
              ),
            ),

            // Espacement.
            const SizedBox(height: AppSpacing.xs),

            // Portions restantes.
            Text(
              '${braise.portionsRemaining} portion(s) restante(s) sur ${braise.portionsTotal}',
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
