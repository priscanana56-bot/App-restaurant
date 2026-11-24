// =============================================================================
// Panneau de livraison réutilisable (fiche restaurant et annuaire sourcé).
// -----------------------------------------------------------------------------
// Il affiche l'indicateur « livraison disponible / indisponible », demande la
// position à l'utilisateur, puis montre le devis calculé par le Domain. Au-delà
// de 5 km, il propose les fast-foods déjà présents dans l'annuaire, triés par
// distance. Aucune adresse n'est inventée et aucun lien n'est ouvert en dehors
// de `UrlGuard`.
//
// Le panneau est sans état : la cible est fournie à chaque demande de devis.
// Ainsi, aucun `emit` ne survient pendant la construction du widget et un devis
// périmé ne peut jamais être affiché pour une autre fiche.
// =============================================================================

// Appels asynchrones non attendus depuis un geste.
import 'dart:async';

// Widgets et Material.
import 'package:flutter/material.dart';

// BLoC.
import 'package:flutter_bloc/flutter_bloc.dart';

// Garde-fou des liens externes.
import '../../../../core/security/url_guard.dart';

// Palette et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

// Formatage des distances et des montants.
import '../../../../core/utils/formatters.dart';

// Coordonnées de la fiche ciblée.
import '../../../../core/location/geo_point.dart';

// Entités du devis et des suggestions.
import '../../domain/entities/delivery_quote.dart';
import '../../domain/entities/nearby_restaurant.dart';

// État du devis.
import '../bloc/delivery_cubit.dart';

// Retour utilisateur des liens externes.
import 'link_feedback.dart';

// Badge d'indicateur.
import 'status_badges.dart';

/// Panneau autonome de devis de livraison.
final class DeliveryPanel extends StatelessWidget {
  /// Construit le panneau pour une fiche donnée.
  const DeliveryPanel({
    required this.targetId,
    required this.targetLabel,
    required this.destination,
    required this.deliveryAvailable,
    required this.urlGuard,
    super.key,
  });

  /// Identifiant de la fiche (exclu des suggestions de redirection).
  final String targetId;

  /// Nom affiché de la fiche.
  final String targetLabel;

  /// Point GPS publié par la source.
  final GeoPoint destination;

  /// Champ pilote de l'entité : la livraison est-elle proposée ?
  final bool deliveryAvailable;

  /// Garde-fou des liens (itinéraires des fast-foods suggérés).
  final UrlGuard urlGuard;

  /// Lance une demande de devis pour CETTE fiche uniquement.
  void _request(DeliveryCubit cubit) {
    unawaited(
      cubit.requestLocation(
        id: targetId,
        label: targetLabel,
        destination: destination,
        deliveryAvailable: deliveryAvailable,
      ),
    );
  }

  /// Construit le panneau réactif.
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Titre et indicateur explicite.
            Row(
              children: <Widget>[
                Icon(Icons.delivery_dining, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Livraison',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DeliveryBadge(available: deliveryAvailable),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Règle tarifaire, toujours visible (transparence du devis).
            Text(
              'Tarif : 500 FCFA + 200 FCFA/km, jusqu’à 5 km.',
              style: textTheme.bodySmall?.copyWith(
                color: AppPalette.of(context).mutedText,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Service non proposé : aucun devis n'est calculé.
            if (!deliveryAvailable)
              Text(
                'Cet établissement ne propose pas la livraison. '
                'Le devis n’est donc pas disponible.',
                style: textTheme.bodyMedium,
              ),

            // Service proposé : le devis dépend de la position de l'utilisateur.
            if (deliveryAvailable)
              BlocBuilder<DeliveryCubit, DeliveryState>(
                builder: (BuildContext context, DeliveryState state) {
                  // Un état périmé (autre fiche) est traité comme « initial ».
                  final bool isCurrent = state.matchesTarget(
                    id: targetId,
                    destinationPoint: destination,
                    available: deliveryAvailable,
                  );
                  final DeliveryCubit cubit = context.read<DeliveryCubit>();

                  if (state.status == DeliveryStatus.initial || !isCurrent) {
                    return _AskLocationButton(
                      label: 'Calculer ma livraison',
                      onPressed: () => _request(cubit),
                    );
                  }

                  if (state.status == DeliveryStatus.requesting) {
                    return const Row(
                      children: <Widget>[
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text('Localisation en cours...')),
                      ],
                    );
                  }

                  if (state.status == DeliveryStatus.failure) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          state.failure?.message ?? 'Position indisponible.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppPalette.of(context).danger,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _AskLocationButton(
                          label: 'Réessayer',
                          onPressed: () => _request(cubit),
                        ),
                      ],
                    );
                  }

                  final DeliveryQuote? quote = state.quote;
                  if (quote == null) {
                    return const SizedBox.shrink();
                  }

                  if (quote.isAvailable) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Distance : ${AppFormatters.distanceKm(quote.distanceKm)}',
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Frais de livraison : '
                          '${AppFormatters.fcfa(quote.feeFcfa)}',
                          style: textTheme.titleSmall?.copyWith(
                            color: AppPalette.of(context).price,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _AskLocationButton(
                          label: 'Actualiser ma position',
                          onPressed: () => _request(cubit),
                        ),
                      ],
                    );
                  }

                  // Refus métier : raison + éventuelles alternatives proches.
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        quote.reason,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppPalette.of(context).danger,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (state.nearbyFastFoods.isNotEmpty) ...<Widget>[
                        Text(
                          'Fast-foods proches dans l’annuaire :',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        for (final NearbyRestaurant nearby
                            in state.nearbyFastFoods)
                          _NearbyFastFoodTile(
                            nearby: nearby,
                            urlGuard: urlGuard,
                          ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      _AskLocationButton(
                        label: 'Actualiser ma position',
                        onPressed: () => _request(cubit),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Bouton de demande de position, unique point de déclenchement du GPS.
final class _AskLocationButton extends StatelessWidget {
  /// Construit le bouton.
  const _AskLocationButton({required this.label, required this.onPressed});

  /// Libellé du bouton.
  final String label;

  /// Action de localisation.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: const Icon(Icons.gps_fixed),
      label: Text(label),
    );
  }
}

/// Ligne d'un fast-food suggéré, avec distance et itinéraire sécurisé.
final class _NearbyFastFoodTile extends StatelessWidget {
  /// Construit la ligne.
  const _NearbyFastFoodTile({required this.nearby, required this.urlGuard});

  /// Fiche et distance calculée.
  final NearbyRestaurant nearby;

  /// Garde-fou des liens externes.
  final UrlGuard urlGuard;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.fastfood_outlined),
      title: Text(nearby.restaurant.name),
      subtitle: Text(
        '${nearby.restaurant.locationLabel} · '
        '${AppFormatters.distanceKm(nearby.distanceKm)}',
      ),
      trailing: TextButton(
        onPressed: () => unawaited(
          LinkFeedback.run(
            context,
            () => urlGuard.openDirections(
              latitude: nearby.restaurant.latitude,
              longitude: nearby.restaurant.longitude,
            ),
            successMessage: 'Ouverture de l’itinéraire...',
          ),
        ),
        child: Text('Itinéraire', style: textTheme.labelMedium),
      ),
    );
  }
}
