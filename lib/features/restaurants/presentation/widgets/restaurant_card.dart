// =============================================================================
// Carte d'un restaurant dans la liste.
// -----------------------------------------------------------------------------
// Composant purement présentationnel : il reçoit une entité déjà chargée et des
// callbacks, sans jamais appeler de use case. Cela le rend trivial à tester et à
// réutiliser (accueil, favoris, résultats de recherche).
// =============================================================================

// Widgets et Material.
import 'package:flutter/material.dart';

// Entité affichée.
import '../../domain/entities/live_braise_status.dart';
import '../../domain/entities/restaurant.dart';

// Palette, espacements et formatage.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';

// Badges réutilisables.
import 'status_badges.dart';

/// Carte compacte présentant un restaurant et ses indicateurs clés.
final class RestaurantCard extends StatelessWidget {
  /// Construit la carte.
  const RestaurantCard({
    required this.restaurant,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
    this.now,
    this.liveBraise,
    this.distanceKm,
    super.key,
  });

  /// Restaurant affiché.
  final Restaurant restaurant;

  /// Indique si le restaurant est déjà en favori (cœur plein ou vide).
  final bool isFavorite;

  /// Action d'ouverture de la fiche détaillée.
  final VoidCallback onTap;

  /// Action de bascule du favori.
  final VoidCallback onFavoriteToggle;

  /// Instant de référence pour le badge « Ouvert » (`null` = badge masqué).
  final DateTime? now;

  /// Braise active pour ce restaurant, si elle existe.
  final LiveBraiseStatus? liveBraise;

  /// Distance depuis la position de l'utilisateur, si connue.
  final double? distanceKm;

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    // Thème, typographie et palette locales.
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final AppPalette palette = AppPalette.of(context);

    // Instant de référence éventuel.
    final DateTime? reference = now;

    // Braise éventuelle.
    final LiveBraiseStatus? braise = liveBraise;

    // Distance éventuelle.
    final double? distance = distanceKm;

    return Card(
      child: InkWell(
        // Toute la surface de la carte ouvre la fiche.
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Vignette de gauche (photo ou repli coloré).
              _RestaurantThumb(restaurant: restaurant),

              // Espacement entre la vignette et le contenu.
              const SizedBox(width: AppSpacing.sm),

              // Colonne de contenu, extensible pour absorber les textes longs.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Ligne du nom et du bouton favori.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Nom du restaurant, sur deux lignes maximum.
                        Expanded(
                          child: Text(
                            restaurant.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        // Bouton favori compact, cible tactile respectée.
                        IconButton(
                          onPressed: onFavoriteToggle,
                          tooltip: isFavorite
                              ? 'Retirer des favoris'
                              : 'Ajouter aux favoris',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite
                                ? palette.danger
                                : palette.mutedText,
                          ),
                        ),
                      ],
                    ),

                    // Accroche courte, une ligne.
                    Text(
                      restaurant.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.mutedText,
                      ),
                    ),

                    // Espacement avant les badges.
                    const SizedBox(height: AppSpacing.xs),

                    // Badges de statut, sur plusieurs lignes si nécessaire.
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        // Statut d'ouverture : seulement si l'heure est connue.
                        if (reference != null)
                          OpenStatusBadge(
                            isOpen: restaurant.isOpenAt(reference),
                          ),

                        // Braise active : mise en avant prioritaire.
                        if (braise != null && reference != null)
                          LiveBraiseBadge(braise: braise, now: reference),

                        // Vérification sur place.
                        if (restaurant.isVerified) const VerifiedBadge(),

                        // Catégorie.
                        CategoryBadge(category: restaurant.category),

                        // Livraison : état explicite, disponible ou non.
                        DeliveryBadge(available: restaurant.deliveryAvailable),
                      ],
                    ),

                    // Espacement avant la ligne d'informations chiffrées.
                    const SizedBox(height: AppSpacing.xs),

                    // Note, prix moyen et distance éventuelle.
                    Row(
                      children: <Widget>[
                        // Note avec icône étoile.
                        Icon(
                          Icons.star_rate_rounded,
                          size: 16,
                          color: theme.colorScheme.tertiary,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          restaurant.rating
                              .toStringAsFixed(1)
                              .replaceAll('.', ','),
                          style: textTheme.labelMedium,
                        ),

                        // Séparateur.
                        _dot(palette),

                        // Prix moyen d'un repas.
                        Text(
                          AppFormatters.fcfa(restaurant.averagePriceFcfa),
                          style: textTheme.labelMedium?.copyWith(
                            color: palette.mutedText,
                          ),
                        ),

                        // Distance : uniquement si la position est connue.
                        if (distance != null) ...<Widget>[
                          _dot(palette),
                          Icon(
                            Icons.near_me_outlined,
                            size: 14,
                            color: palette.mutedText,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            AppFormatters.distanceKm(distance),
                            style: textTheme.labelMedium?.copyWith(
                              color: palette.mutedText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Petit séparateur point entre deux informations.
  Widget _dot(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Text('·', style: TextStyle(color: palette.mutedText)),
    );
  }
}

/// Vignette carrée : photo si disponible, sinon repli dégradé aux couleurs de
/// la marque. Le repli garantit qu'aucune carte ne « casse » sans image.
final class _RestaurantThumb extends StatelessWidget {
  /// Construit la vignette.
  const _RestaurantThumb({required this.restaurant});

  /// Restaurant dont la photo éventuelle est affichée.
  final Restaurant restaurant;

  /// Construit la vignette.
  @override
  Widget build(BuildContext context) {
    // Chemin d'asset éventuel.
    final String? asset = restaurant.photoAsset;

    // Repli coloré : dégradé de basilic apaisant et icône de couverts.
    const Widget fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[AppColors.basilDeep, AppColors.basil],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.restaurant, color: AppColors.pureWhite, size: 30),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: SizedBox(
        width: 84,
        height: 84,
        // Photo locale si elle existe, avec repli automatique en cas d'erreur.
        child: asset == null
            ? fallback
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                // Une image manquante ne doit jamais casser la liste.
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
