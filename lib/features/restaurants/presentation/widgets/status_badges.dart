// =============================================================================
// Badges de statut réutilisables.
// -----------------------------------------------------------------------------
// Petits composants purement visuels, sans logique métier : ils traduisent un
// fait déjà calculé (ouvert/fermé, braise active, note, tranche de prix) en une
// pastille lisible. Les couleurs proviennent TOUJOURS de la palette sémantique
// (`AppPalette`) et jamais d'une valeur codée en dur, afin que les modes clair
// et sombre restent cohérents.
// =============================================================================

// Widgets, Material et couleurs.
import 'package:flutter/material.dart';

// Palette sémantique (statuts adaptés au thème).
import '../../../../core/theme/app_colors.dart';

// Échelle d'espacements et de rayons.
import '../../../../core/theme/app_spacing.dart';

// Formatage des montants et pourcentages.
import '../../../../core/utils/formatters.dart';

// Objets-valeurs affichés.
import '../../domain/entities/event_radar.dart';
import '../../domain/entities/live_braise_status.dart';
import '../../domain/entities/restaurant_category.dart';

/// Pastille générique : un libellé court, une icône optionnelle et deux
/// couleurs (texte + fond). Elle sert de brique commune à tous les badges.
final class StatusPill extends StatelessWidget {
  /// Construit une pastille neutre.
  const StatusPill({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
    super.key,
  });

  /// Texte affiché (déjà en français et de longueur maîtrisée).
  final String label;

  /// Couleur du texte et de l'icône.
  final Color foreground;

  /// Couleur de fond de la pastille.
  final Color background;

  /// Icône facultative affichée avant le texte.
  final IconData? icon;

  /// Construit la pastille.
  @override
  Widget build(BuildContext context) {
    // Typographie locale : le badge reste discret face au titre du restaurant.
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Icône éventuelle : on évite une ligne vide si aucune icône n'est fournie.
    final IconData? iconData = icon;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Icône conditionnelle suivie d'un petit espacement.
            if (iconData != null) ...<Widget>[
              Icon(iconData, size: 14, color: foreground),
              const SizedBox(width: AppSpacing.xxs),
            ],

            // Libellé du badge.
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge « Ouvert » / « Fermé ».
final class OpenStatusBadge extends StatelessWidget {
  /// Construit le badge à partir de l'état calculé par le BLoC.
  const OpenStatusBadge({required this.isOpen, super.key});

  /// `true` si l'établissement est ouvert à l'instant de référence.
  final bool isOpen;

  /// Construit le badge coloré.
  @override
  Widget build(BuildContext context) {
    // Palette dépendante du thème.
    final AppPalette palette = AppPalette.of(context);

    return StatusPill(
      label: isOpen ? 'Ouvert' : 'Fermé',
      icon: isOpen ? Icons.check_circle_outline : Icons.cancel_outlined,
      foreground: isOpen ? palette.success : palette.danger,
      background: isOpen ? palette.successContainer : palette.dangerContainer,
    );
  }
}

/// Badge « Live Braise » signalant une braise active.
final class LiveBraiseBadge extends StatelessWidget {
  /// Construit le badge à partir de la braise active et de l'heure de référence.
  const LiveBraiseBadge({required this.braise, required this.now, super.key});

  /// Braise en cours (jamais `null` : l'appelant vérifie l'activité en amont).
  final LiveBraiseStatus braise;

  /// Instant de référence (heure de Koudougou) pour calculer le temps restant.
  final DateTime now;

  /// Construit le badge.
  @override
  Widget build(BuildContext context) {
    // Palette dépendante du thème : la braise utilise la couleur d'avertissement.
    final AppPalette palette = AppPalette.of(context);

    // Minutes restantes, bornées à zéro par l'entité.
    final int remaining = braise.remainingMinutesAt(now);

    return StatusPill(
      label: remaining > 0 ? 'Braise · $remaining min' : 'Braise en cours',
      icon: Icons.local_fire_department_outlined,
      foreground: palette.onWarning,
      background: palette.warning,
    );
  }
}

/// Badge « Vérifié sur place ».
final class VerifiedBadge extends StatelessWidget {
  /// Construit le badge sans paramètre : sa simple présence signifie « vérifié ».
  const VerifiedBadge({super.key});

  /// Construit le badge.
  @override
  Widget build(BuildContext context) {
    // Palette dépendante du thème : bleu de confiance.
    final AppPalette palette = AppPalette.of(context);

    return StatusPill(
      label: 'Vérifié',
      icon: Icons.verified_outlined,
      foreground: palette.onVerified,
      background: palette.verifiedContainer,
    );
  }
}

/// Badge explicite de disponibilité de la livraison.
final class DeliveryBadge extends StatelessWidget {
  /// Construit le badge à partir du champ pilote de l'entité.
  const DeliveryBadge({required this.available, super.key});

  /// `true` si l'établissement propose la livraison.
  final bool available;

  /// Construit le badge.
  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return StatusPill(
      label: available ? 'Livraison disponible' : 'Livraison indisponible',
      icon: available ? Icons.delivery_dining : Icons.remove_shopping_cart,
      foreground: available ? palette.success : palette.mutedText,
      background: available
          ? palette.successContainer
          : palette.mutedText.withValues(alpha: 0.12),
    );
  }
}

/// Badge de tranche de prix (`Économique`, `Modéré`, `Premium`).
final class PriceRangeBadge extends StatelessWidget {
  /// Construit le badge à partir de la tranche calculée par le Domain.
  const PriceRangeBadge({required this.range, super.key});

  /// Tranche de prix affichée.
  final PriceRange range;

  /// Construit le badge.
  @override
  Widget build(BuildContext context) {
    // Couleurs du thème courant.
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = AppPalette.of(context);

    return StatusPill(
      label: range.label,
      icon: Icons.payments_outlined,
      foreground: theme.colorScheme.onSurface,
      background: palette.mutedText.withValues(alpha: 0.12),
    );
  }
}

/// Badge de catégorie (`Maquis`, `Restaurant`, `Fast-food`...).
final class CategoryBadge extends StatelessWidget {
  /// Construit le badge à partir de la catégorie de l'établissement.
  const CategoryBadge({required this.category, super.key});

  /// Catégorie affichée.
  final RestaurantCategory category;

  /// Construit le badge.
  @override
  Widget build(BuildContext context) {
    // Couleurs du thème courant.
    final ThemeData theme = Theme.of(context);

    return StatusPill(
      label: category.label,
      icon: Icons.storefront_outlined,
      foreground: theme.colorScheme.onSecondaryContainer,
      background: theme.colorScheme.secondaryContainer,
    );
  }
}

/// Badge d'affluence (`Animé`, `Calme`) avec le pourcentage.
final class AmbianceBadge extends StatelessWidget {
  /// Construit le badge à partir du score d'ambiance (0-100).
  const AmbianceBadge({required this.score, super.key});

  /// Score d'affluence calculé par la Data.
  final int score;

  /// Construit le badge.
  @override
  Widget build(BuildContext context) {
    // Palette dépendante du thème.
    final AppPalette palette = AppPalette.of(context);

    // Un score élevé signale un maquis animé (couleur d'avertissement).
    final bool isLively = score >= 70;

    return StatusPill(
      label: isLively ? 'Animé · ${AppFormatters.percentage(score)}' : 'Calme',
      icon: isLively ? Icons.graphic_eq : Icons.nightlight_outlined,
      foreground: isLively ? palette.onWarning : palette.mutedText,
      background: isLively
          ? palette.warningContainer
          : palette.mutedText.withValues(alpha: 0.12),
    );
  }
}

/// Badge de note (`4,6 ★ · 148 avis`).
final class RatingBadge extends StatelessWidget {
  /// Construit le badge à partir de la note et du nombre d'avis.
  const RatingBadge({
    required this.rating,
    required this.reviewCount,
    super.key,
  });

  /// Note moyenne de 0 à 5.
  final double rating;

  /// Nombre d'avis ayant servi au calcul.
  final int reviewCount;

  /// Construit le badge.
  @override
  Widget build(BuildContext context) {
    // Couleurs du thème courant.
    final ThemeData theme = Theme.of(context);

    // Note avec une décimale, virgule française.
    final String formattedRating = rating
        .toStringAsFixed(1)
        .replaceAll('.', ',');

    return StatusPill(
      label: '$formattedRating ★ · $reviewCount avis',
      icon: Icons.star_outline,
      foreground: theme.colorScheme.onTertiaryContainer,
      background: theme.colorScheme.tertiaryContainer,
    );
  }
}

/// Badge du type d'événement du radar (`Concert`, `Football`, `Soirée DJ`...).
final class EventTypeBadge extends StatelessWidget {
  /// Construit le badge à partir du type d'événement.
  const EventTypeBadge({required this.type, super.key});

  /// Type de l'événement affiché.
  final RadarEventType type;

  /// Construit le badge.
  @override
  Widget build(BuildContext context) {
    // Couleurs du thème courant.
    final ThemeData theme = Theme.of(context);

    return StatusPill(
      label: type.label,
      icon: _iconFor(type),
      foreground: theme.colorScheme.onPrimaryContainer,
      background: theme.colorScheme.primaryContainer,
    );
  }

  /// Associe une icône lisible à chaque type d'événement.
  static IconData _iconFor(RadarEventType type) {
    return switch (type) {
      RadarEventType.concert => Icons.music_note_outlined,
      RadarEventType.football => Icons.sports_soccer_outlined,
      RadarEventType.djSet => Icons.headphones_outlined,
      RadarEventType.cultural => Icons.theater_comedy_outlined,
      RadarEventType.market => Icons.storefront_outlined,
      RadarEventType.specialMenu => Icons.restaurant_menu_outlined,
      RadarEventType.other => Icons.celebration_outlined,
    };
  }
}

/// Badge « En direct » utilisé par le radar et la braise.
final class LiveBadge extends StatelessWidget {
  /// Construit le badge sans paramètre.
  const LiveBadge({super.key});

  /// Construit le badge.
  @override
  Widget build(BuildContext context) {
    // Palette dépendante du thème : rouge « en direct ».
    final AppPalette palette = AppPalette.of(context);

    return StatusPill(
      label: 'En direct',
      icon: Icons.circle,
      foreground: palette.onDanger,
      background: palette.danger,
    );
  }
}
