// =============================================================================
// Barre de recherche, de filtres et de tri.
// -----------------------------------------------------------------------------
// Composant d'entrée : il traduit les gestes de l'utilisateur en callbacks
// typés, sans connaître le BLoC. La recherche est LOCALE (aucun appel réseau) :
// chaque frappe déclenche un simple recalcul de la liste visible.
// =============================================================================

// Widgets et Material.
import 'package:flutter/material.dart';

// Critères et tri.
import '../../domain/entities/restaurant_category.dart';
import '../../domain/entities/restaurant_filter.dart';

// Palette et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Barre complète : recherche, catégories, filtres rapides et tri.
final class RestaurantFilterBar extends StatefulWidget {
  /// Construit la barre.
  const RestaurantFilterBar({
    required this.filter,
    required this.onSearchChanged,
    required this.onCategoryToggled,
    required this.onSortChanged,
    required this.onOpenNowToggled,
    required this.onVerifiedToggled,
    required this.onClear,
    super.key,
  });

  /// Filtre courant (source de vérité pour l'état des puces).
  final RestaurantFilter filter;

  /// Notification d'une nouvelle saisie de recherche.
  final ValueChanged<String> onSearchChanged;

  /// Notification du tap sur une catégorie.
  final ValueChanged<RestaurantCategory> onCategoryToggled;

  /// Notification d'un nouveau tri.
  final ValueChanged<RestaurantSort> onSortChanged;

  /// Bascule du filtre « ouvert maintenant ».
  final VoidCallback onOpenNowToggled;

  /// Bascule du filtre « vérifié sur place ».
  final VoidCallback onVerifiedToggled;

  /// Réinitialisation de tous les critères.
  final VoidCallback onClear;

  /// Crée l'état qui possède le contrôleur de saisie.
  @override
  State<RestaurantFilterBar> createState() => _RestaurantFilterBarState();
}

/// État de la barre de filtres.
class _RestaurantFilterBarState extends State<RestaurantFilterBar> {
  // Contrôleur du champ de recherche, possédé par l'état pour survivre aux
  // reconstructions provoquées par les changements de filtre.
  late final TextEditingController _controller;

  /// Initialise le contrôleur avec la requête courante.
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.filter.query);
  }

  /// Libère le contrôleur (obligatoire pour éviter une fuite mémoire).
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Construit la barre.
  @override
  Widget build(BuildContext context) {
    // Thème, typographie et palette locales.
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final AppPalette palette = AppPalette.of(context);

    // Filtre courant.
    final RestaurantFilter filter = widget.filter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Champ de recherche.
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          // La saisie remonte immédiatement au BLoC (filtrage local instantané).
          onChanged: widget.onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Rechercher un maquis, un plat, un secteur...',
            prefixIcon: const Icon(Icons.search),
            // Bouton d'effacement visible uniquement quand un texte est saisi.
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer la recherche',
                    onPressed: () {
                      // Vide le champ puis notifie le BLoC.
                      _controller.clear();
                      widget.onSearchChanged('');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),

        // Espacement.
        const SizedBox(height: AppSpacing.sm),

        // Catégories, en défilement horizontal.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final RestaurantCategory category
                  in RestaurantCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: ChoiceChip(
                    selected: filter.category == category,
                    onSelected: (_) => widget.onCategoryToggled(category),
                    label: Text(category.label),
                  ),
                ),
            ],
          ),
        ),

        // Espacement.
        const SizedBox(height: AppSpacing.xs),

        // Filtres rapides et tri, sur une ligne défilante.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              // Filtre « ouvert maintenant ».
              FilterChip(
                selected: filter.onlyOpenNow,
                onSelected: (_) => widget.onOpenNowToggled(),
                avatar: const Icon(Icons.schedule_outlined, size: 16),
                label: const Text('Ouvert'),
              ),
              const SizedBox(width: AppSpacing.xs),

              // Filtre « vérifié sur place ».
              FilterChip(
                selected: filter.onlyVerified,
                onSelected: (_) => widget.onVerifiedToggled(),
                avatar: const Icon(Icons.verified_outlined, size: 16),
                label: const Text('Vérifié'),
              ),
              const SizedBox(width: AppSpacing.xs),

              // Menu de tri.
              PopupMenuButton<RestaurantSort>(
                tooltip: 'Trier',
                initialValue: filter.sort,
                onSelected: widget.onSortChanged,
                itemBuilder: (BuildContext context) {
                  return <PopupMenuEntry<RestaurantSort>>[
                    for (final RestaurantSort sort in RestaurantSort.values)
                      PopupMenuItem<RestaurantSort>(
                        value: sort,
                        child: Row(
                          children: <Widget>[
                            // Coche la valeur active.
                            Icon(
                              filter.sort == sort
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: filter.sort == sort
                                  ? theme.colorScheme.primary
                                  : palette.mutedText,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(sort.label),
                          ],
                        ),
                      ),
                  ];
                },
                child: Chip(
                  avatar: const Icon(Icons.sort, size: 16),
                  label: Text('Tri : ${filter.sort.label}'),
                ),
              ),

              // Bouton de réinitialisation, affiché seulement si un critère est actif.
              if (filter.hasActiveCriteria) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                TextButton.icon(
                  onPressed: () {
                    // Vide aussi la recherche pour rester cohérent avec l'état.
                    _controller.clear();
                    widget.onClear();
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Réinitialiser'),
                ),
              ],
            ],
          ),
        ),

        // Résumé du nombre de critères actifs (feedback discret).
        if (filter.hasActiveCriteria)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              'Filtres actifs',
              style: textTheme.labelSmall?.copyWith(color: palette.mutedText),
            ),
          ),
      ],
    );
  }
}
