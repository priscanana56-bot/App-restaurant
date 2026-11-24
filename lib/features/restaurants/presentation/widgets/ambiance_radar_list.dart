// =============================================================================
// Radar d'ambiance — liste des événements.
// -----------------------------------------------------------------------------
// Le radar met en avant les concerts, matchs et soirées des maquis de
// Koudougou. Le filtrage temporel (événements passés masqués, en cours d'abord)
// est réalisé par le use case `GetEventRadar` ; ce widget ne fait que présenter
// les événements reçus et signaler ceux qui sont « en direct ».
// =============================================================================

// Widgets et Material.
import 'package:flutter/material.dart';

// Entité affichée.
import '../../domain/entities/event_radar.dart';

// Palette, espacements et formatage.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';

// Badges réutilisables.
import 'status_badges.dart';

/// Section complète du radar : en-tête, bascule « en direct » et liste.
final class AmbianceRadarSection extends StatelessWidget {
  /// Construit la section.
  const AmbianceRadarSection({
    required this.events,
    required this.now,
    required this.onEventTap,
    required this.onlyLive,
    required this.onToggleOnlyLive,
    super.key,
  });

  /// Événements à afficher (déjà filtrés et triés).
  final List<EventRadar> events;

  /// Instant de référence (heure de Koudougou).
  final DateTime now;

  /// Callback d'ouverture de la fiche du restaurant organisateur.
  final void Function(String restaurantId) onEventTap;

  /// Indique si le filtre « uniquement en direct » est actif.
  final bool onlyLive;

  /// Action de bascule du filtre « uniquement en direct ».
  final VoidCallback onToggleOnlyLive;

  /// Construit la section.
  @override
  Widget build(BuildContext context) {
    // Thème, typographie et palette locales.
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final AppPalette palette = AppPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // En-tête : titre et bascule de filtre.
        Row(
          children: <Widget>[
            // Icône radar.
            Icon(
              Icons.radar_outlined,
              color: theme.colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.xs),

            // Titre de la section.
            Expanded(
              child: Text(
                'Radar d’ambiance',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            // Bascule « en direct » sous forme de puce sélectionnable.
            FilterChip(
              selected: onlyLive,
              onSelected: (_) => onToggleOnlyLive(),
              avatar: Icon(
                Icons.sensors,
                size: 16,
                color: onlyLive ? palette.onDanger : palette.mutedText,
              ),
              label: const Text('En direct'),
            ),
          ],
        ),

        // Espacement avant la liste.
        const SizedBox(height: AppSpacing.xs),

        // Aucun événement : message discret.
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              onlyLive
                  ? 'Aucun événement en direct pour le moment.'
                  : 'Aucun événement programmé prochainement.',
              style: textTheme.bodyMedium?.copyWith(color: palette.mutedText),
            ),
          ),

        // Liste verticale des événements.
        if (events.isNotEmpty)
          Column(
            children: <Widget>[
              for (final EventRadar event in events)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: EventRadarTile(
                    event: event,
                    now: now,
                    // Ouverture de la fiche du restaurant organisateur.
                    onTap: () => onEventTap(event.restaurantId),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Tuile d'un événement du radar.
final class EventRadarTile extends StatelessWidget {
  /// Construit la tuile.
  const EventRadarTile({
    required this.event,
    required this.now,
    required this.onTap,
    super.key,
  });

  /// Événement affiché.
  final EventRadar event;

  /// Instant de référence.
  final DateTime now;

  /// Action d'ouverture de la fiche du restaurant.
  final VoidCallback onTap;

  /// Construit la tuile.
  @override
  Widget build(BuildContext context) {
    // Thème, typographie et palette locales.
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final AppPalette palette = AppPalette.of(context);

    // L'événement est-il en cours à l'instant de référence ?
    final bool isLive = event.isLiveAt(now);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Badges : type et éventuel « en direct ».
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  EventTypeBadge(type: event.type),
                  if (isLive) const LiveBadge(),
                ],
              ),

              // Espacement.
              const SizedBox(height: AppSpacing.xs),

              // Titre de l'événement.
              Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              // Restaurant organisateur.
              Text(
                event.restaurantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: palette.mutedText),
              ),

              // Espacement.
              const SizedBox(height: AppSpacing.xs),

              // Horaire, tarif et affluence.
              Row(
                children: <Widget>[
                  // Icône calendrier.
                  Icon(
                    Icons.schedule_outlined,
                    size: 15,
                    color: palette.mutedText,
                  ),
                  const SizedBox(width: AppSpacing.xxs),

                  // Jour + plage horaire.
                  Expanded(
                    child: Text(
                      '${_dayLabel(event.startsAt, now)} · '
                      '${AppFormatters.timeFr(event.startsAt)}'
                      ' - ${AppFormatters.timeFr(event.endsAt)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.mutedText,
                      ),
                    ),
                  ),

                  // Tarif : « Gratuit » ou montant en FCFA.
                  Text(
                    event.isFree
                        ? 'Gratuit'
                        : AppFormatters.fcfaCompact(event.entryPriceFcfa),
                    style: textTheme.labelMedium?.copyWith(
                      color: AppPalette.of(context).price,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Libellé de jour relatif à l'instant de référence.
  static String _dayLabel(DateTime startsAt, DateTime now) {
    // Comparaison sur la date seule (heure murale de Koudougou, en UTC).
    final DateTime startDay = DateTime.utc(
      startsAt.toUtc().year,
      startsAt.toUtc().month,
      startsAt.toUtc().day,
    );
    final DateTime today = DateTime.utc(
      now.toUtc().year,
      now.toUtc().month,
      now.toUtc().day,
    );

    // Écart en jours entiers.
    final int days = startDay.difference(today).inDays;

    // Correspondances lisibles.
    if (days <= 0) {
      return 'Aujourd’hui';
    }
    if (days == 1) {
      return 'Demain';
    }
    if (days < 7) {
      return AppFormatters.weekdayFr(startsAt);
    }

    // Au-delà d'une semaine : date courte.
    return AppFormatters.shortDateFr(startsAt);
  }
}
