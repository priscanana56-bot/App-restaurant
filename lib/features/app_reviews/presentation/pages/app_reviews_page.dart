// =============================================================================
// Écran des avis sur l'application.
// -----------------------------------------------------------------------------
// Cet espace est local : la note et le commentaire restent sur l'appareil.
// Le bouton « Partager » ouvre uniquement la feuille native choisie par
// l'utilisateur ; aucune donnée n'est envoyée automatiquement.
// =============================================================================

// Widgets et Material.
import 'package:flutter/material.dart';

// BLoC.
import 'package:flutter_bloc/flutter_bloc.dart';

// Bornes métier.
import '../../../../core/constants/app_constants.dart';

// Palette et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

// Cubit et état.
import '../bloc/app_reviews_cubit.dart';
import '../bloc/app_reviews_state.dart';

// Entité affichée.
import '../../domain/entities/app_review.dart';

/// Page de notation de l'application.
final class AppReviewsPage extends StatefulWidget {
  /// Construit la page (le Cubit est fourni par la route).
  const AppReviewsPage({super.key});

  @override
  State<AppReviewsPage> createState() => _AppReviewsPageState();
}

/// État de la page, propriétaire du contrôleur de texte.
final class _AppReviewsPageState extends State<AppReviewsPage> {
  /// Saisie du commentaire.
  final TextEditingController _commentController = TextEditingController();

  /// Charge les avis dès l'ouverture.
  @override
  void initState() {
    super.initState();
    context.read<AppReviewsCubit>().load();
  }

  /// Libère le contrôleur.
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Votre avis sur l’application')),
      body: SafeArea(
        child: BlocBuilder<AppReviewsCubit, AppReviewsState>(
          builder: (BuildContext context, AppReviewsState state) {
            if (state.status == AppReviewsStatus.loading &&
                state.reviews.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _SummaryCard(state: state),
                  const SizedBox(height: AppSpacing.lg),
                  _RatingPicker(
                    rating: state.rating,
                    onChanged: context.read<AppReviewsCubit>().ratingChanged,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _commentController,
                    onChanged: context.read<AppReviewsCubit>().commentChanged,
                    maxLines: 4,
                    maxLength: AppConstants.commentMaxLength,
                    decoration: const InputDecoration(
                      labelText: 'Votre commentaire (facultatif)',
                      hintText:
                          'Qu’est-ce qui vous a plu ? Que faut-il améliorer ?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: state.isBusy ? null : () => _submit(context),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Enregistrer mon avis'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (state.failure != null)
                    Text(
                      state.failure!.message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (state.infoMessage != null)
                    Text(
                      state.infoMessage!,
                      style: TextStyle(color: AppPalette.of(context).success),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionTitle(
                    title: 'Avis enregistrés sur cet appareil',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (state.reviews.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Aucun avis pour le moment. Votre retour reste privé '
                          'et n’est partagé que si vous le décidez.',
                        ),
                      ),
                    )
                  else
                    for (final AppReview review in state.reviews)
                      _ReviewCard(
                        review: review,
                        isBusy: state.isBusy,
                        onShare: () =>
                            context.read<AppReviewsCubit>().share(review),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Enregistre puis vide le champ si l'écriture a réussi.
  Future<void> _submit(BuildContext context) async {
    final AppReviewsCubit cubit = context.read<AppReviewsCubit>();
    await cubit.submit();
    if (!mounted) {
      return;
    }
    if (cubit.state.comment.isEmpty) {
      _commentController.clear();
    }
  }
}

/// Carte de synthèse (moyenne et nombre d'avis).
final class _SummaryCard extends StatelessWidget {
  /// Construit la carte.
  const _SummaryCard({required this.state});

  /// État courant.
  final AppReviewsState state;

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      color: AppColors.saffronSoft,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: <Widget>[
            const Icon(Icons.star_rounded, color: AppColors.saffron, size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    state.averageRating.toStringAsFixed(1),
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${state.reviews.length} avis local${state.reviews.length > 1 ? 's' : ''}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sélecteur de note de 1 à 5 étoiles.
final class _RatingPicker extends StatelessWidget {
  /// Construit le sélecteur.
  const _RatingPicker({required this.rating, required this.onChanged});

  /// Note courante.
  final int rating;

  /// Callback de changement.
  final ValueChanged<int> onChanged;

  /// Construit le sélecteur.
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Votre note',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var value = 1; value <= 5; value++)
                  IconButton(
                    // Un libellé explicite rend le widget accessible.
                    tooltip: '$value étoile${value > 1 ? 's' : ''}',
                    icon: Icon(
                      value <= rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: value <= rating
                          ? AppColors.saffron
                          : AppColors.textMuted,
                      size: 34,
                    ),
                    onPressed: () => onChanged(value),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Titre de la liste des avis.
final class _SectionTitle extends StatelessWidget {
  /// Construit le titre.
  const _SectionTitle({required this.title});

  /// Libellé affiché.
  final String title;

  /// Construit le titre.
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

/// Carte d'un avis et de son bouton de partage.
final class _ReviewCard extends StatelessWidget {
  /// Construit la carte.
  const _ReviewCard({
    required this.review,
    required this.isBusy,
    required this.onShare,
  });

  /// Avis affiché.
  final AppReview review;

  /// Désactive le partage pendant une opération.
  final bool isBusy;

  /// Callback de partage.
  final VoidCallback onShare;

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String date = review.createdAt.toLocal().toIso8601String().substring(
      0,
      10,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '${'★' * review.rating}${'☆' * (5 - review.rating)}',
                  style: const TextStyle(
                    color: AppColors.saffron,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                Text(date, style: textTheme.bodySmall),
              ],
            ),
            if (review.comment.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(review.comment),
            ],
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: isBusy ? null : onShare,
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Partager'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
