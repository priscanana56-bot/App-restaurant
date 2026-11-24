// =============================================================================
// Portail gérant — modification locale du menu.
// -----------------------------------------------------------------------------
// La page ne contient aucune règle métier : elle collecte des champs, les confie
// au Cubit et affiche son état. Le code gérant reste dans un contrôleur local,
// obscurci à l'écran et jamais écrit dans un état ou un journal.
// =============================================================================

// `unawaited` pour la soumission déclenchée par un bouton.
import 'dart:async';

// Widgets et Material.
import 'package:flutter/material.dart';

// BLoC.
import 'package:flutter_bloc/flutter_bloc.dart';

// Routes nommées (accès à l'administration pour attribuer un code).
import '../../../../core/constants/app_routes.dart';

// Nettoyage du prix saisi.
import '../../../../core/security/input_sanitizer.dart';

// Palette et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

// Entité du menu.
import '../../../restaurants/domain/entities/menu_item.dart';
import '../../../restaurants/domain/entities/restaurant.dart';

// Cubit et état.
import '../bloc/owner_portal_cubit.dart';
import '../bloc/owner_portal_state.dart';

/// Écran du portail gérant.
final class OwnerPortalPage extends StatefulWidget {
  /// Construit la page (le Cubit est fourni par la route).
  const OwnerPortalPage({super.key});

  @override
  State<OwnerPortalPage> createState() => _OwnerPortalPageState();
}

/// État de la page, propriétaire des contrôleurs de saisie.
final class _OwnerPortalPageState extends State<OwnerPortalPage>
    with WidgetsBindingObserver {
  /// Code gérant (jamais persisté).
  final TextEditingController _codeController = TextEditingController();

  /// Champs du nouveau plat.
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _portionController = TextEditingController();
  final TextEditingController _preparationController = TextEditingController();

  /// Section choisie pour le nouveau plat.
  MenuSection _section = MenuSection.mainDishes;

  /// Erreur de saisie locale (avant appel au Cubit).
  String? _formError;

  /// Charge le catalogue à l'ouverture.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<OwnerPortalCubit>().load();
  }

  /// Libère les contrôleurs et l'observateur de cycle de vie.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _portionController.dispose();
    _preparationController.dispose();
    super.dispose();
  }

  /// Reverrouille l'accès en arrière-plan sans laisser le code à l'écran.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _lockNow();
    }
  }

  /// Verrouille et efface immédiatement le code saisi.
  void _lockNow() {
    _codeController.clear();
    context.read<OwnerPortalCubit>().lock();
  }

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portail gérant')),
      body: SafeArea(
        child: BlocBuilder<OwnerPortalCubit, OwnerPortalState>(
          builder: (BuildContext context, OwnerPortalState state) {
            if (state.status == OwnerPortalStatus.loading &&
                state.restaurants.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _NoticeCard(),
                  const SizedBox(height: AppSpacing.md),
                  _EstablishmentSelector(state: state),
                  if (state.selectedHasCode == false) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    const _MissingCodeCard(),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _AccessCard(
                    state: state,
                    codeController: _codeController,
                    onLock: _lockNow,
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
                  if (_formError != null)
                    Text(
                      _formError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (state.isUnlocked) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    _MenuEditor(state: state, codeController: _codeController),
                    const SizedBox(height: AppSpacing.md),
                    _AddDishForm(
                      state: state,
                      nameController: _nameController,
                      descriptionController: _descriptionController,
                      priceController: _priceController,
                      portionController: _portionController,
                      preparationController: _preparationController,
                      section: _section,
                      onSectionChanged: (MenuSection section) =>
                          setState(() => _section = section),
                      onSubmitted: _submitDishFromForm,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Adaptateur `VoidCallback` : le formulaire n'a pas besoin de connaître
  /// l'état, seule la page lit le Cubit au moment de la soumission.
  void _submitDishFromForm() => unawaited(_submitDish());

  /// Valide la saisie puis délègue l'ajout au Cubit.
  Future<void> _submitDish() async {
    setState(() => _formError = null);

    final int? price = InputSanitizer.sanitizePriceFcfa(_priceController.text);
    final int? preparation = int.tryParse(_preparationController.text.trim());
    if (price == null || price <= 0) {
      setState(() => _formError = 'Indiquez un prix en FCFA valide.');
      return;
    }
    if (preparation == null || preparation < 0 || preparation > 240) {
      setState(
        () => _formError = 'Temps de préparation invalide (0 à 240 min).',
      );
      return;
    }

    final OwnerPortalCubit cubit = context.read<OwnerPortalCubit>();
    await cubit.addDish(
      code: _codeController.text,
      name: _nameController.text,
      description: _descriptionController.text,
      section: _section,
      priceFcfa: price,
      portionLabel: _portionController.text,
      preparationMinutes: preparation,
    );
    // Le code est effacé après chaque tentative, réussie ou non.
    _codeController.clear();
    if (!mounted) {
      return;
    }
    if (cubit.state.failure == null) {
      _nameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _portionController.clear();
      _preparationController.clear();
    }
  }
}

/// Rappel de la nature locale des données du portail.
final class _NoticeCard extends StatelessWidget {
  /// Construit la carte.
  const _NoticeCard();

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    return const Card(
      color: AppColors.saffronSoft,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Text(
          'Espace de démonstration hors ligne. Les fiches issues du catalogue '
          'embarqué sont fictives et ne certifient aucun établissement réel. '
          'Les modifications restent sur cet appareil.',
        ),
      ),
    );
  }
}

/// Sélecteur d'établissement.
final class _EstablishmentSelector extends StatelessWidget {
  /// Construit le sélecteur.
  const _EstablishmentSelector({required this.state});

  /// État courant.
  final OwnerPortalState state;

  /// Construit le sélecteur.
  @override
  Widget build(BuildContext context) {
    final String? selected = state.selectedRestaurantId;
    final bool selectedExists = state.restaurants.any(
      (Restaurant restaurant) => restaurant.id == selected,
    );

    return DropdownButtonFormField<String>(
      // Une valeur absente du catalogue est ignorée : pas de crash de dropdown.
      value: selectedExists ? selected : null,
      decoration: const InputDecoration(
        labelText: 'Établissement à gérer',
        border: OutlineInputBorder(),
      ),
      items: state.restaurants
          .map(
            (Restaurant restaurant) => DropdownMenuItem<String>(
              value: restaurant.id,
              child: Text(restaurant.name),
            ),
          )
          .toList(growable: false),
      onChanged: (String? value) {
        if (value == null) {
          return;
        }
        context.read<OwnerPortalCubit>().selectRestaurant(value);
      },
    );
  }
}

/// Aide quand la fiche sélectionnée n'a pas encore de code gérant.
final class _MissingCodeCard extends StatelessWidget {
  /// Construit la carte.
  const _MissingCodeCard();

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.saffronSoft,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Aucun code gérant n’est défini pour cet établissement.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Les fiches du catalogue embarqué n’ont pas toutes un accès '
              'gérant. Un administrateur doit d’abord attribuer un code à '
              'cette fiche depuis l’espace Administration.',
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.creatorPortal),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Ouvrir l’administration'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte de saisie du code gérant.
final class _AccessCard extends StatelessWidget {
  /// Construit la carte.
  const _AccessCard({
    required this.state,
    required this.codeController,
    required this.onLock,
  });

  /// État courant.
  final OwnerPortalState state;

  /// Contrôleur du code (non conservé dans l'état).
  final TextEditingController codeController;

  /// Callback de verrouillage explicite.
  final VoidCallback onLock;

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    final OwnerPortalCubit cubit = context.read<OwnerPortalCubit>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              state.isUnlocked ? 'Accès gérant vérifié' : 'Code gérant',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: codeController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Code à 4 ou 6 chiffres',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton.icon(
              onPressed: state.isBusy || state.selectedRestaurantId == null
                  ? null
                  : () => unawaited(() async {
                      await cubit.unlock(codeController.text);
                      codeController.clear();
                    }()),
              icon: const Icon(Icons.lock_outline),
              label: Text(
                state.isUnlocked ? 'Revérifier le code' : 'Déverrouiller',
              ),
            ),
            if (state.isUnlocked)
              OutlinedButton.icon(
                onPressed: onLock,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Verrouiller'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Liste des plats avec suppression individuelle.
final class _MenuEditor extends StatelessWidget {
  /// Construit la liste.
  const _MenuEditor({required this.state, required this.codeController});

  /// État courant.
  final OwnerPortalState state;

  /// Contrôleur du code.
  final TextEditingController codeController;

  /// Construit la liste.
  @override
  Widget build(BuildContext context) {
    final Restaurant? restaurant = state.selectedRestaurant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Menu · ${restaurant?.name ?? ''}',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (restaurant == null || restaurant.menu.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('Aucun plat dans le menu de cette fiche.'),
            ),
          )
        else
          for (final MenuItem item in restaurant.menu)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                title: Text(item.name),
                subtitle: Text(
                  '${item.section.label} · ${item.priceFcfa} FCFA',
                ),
                trailing: IconButton(
                  tooltip: 'Retirer ce plat',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: state.isBusy
                      ? null
                      : () => unawaited(() async {
                          await context.read<OwnerPortalCubit>().removeDish(
                            code: codeController.text,
                            itemId: item.id,
                          );
                          codeController.clear();
                        }()),
                ),
              ),
            ),
      ],
    );
  }
}

/// Formulaire d'ajout d'un plat.
final class _AddDishForm extends StatelessWidget {
  /// Construit le formulaire.
  const _AddDishForm({
    required this.state,
    required this.nameController,
    required this.descriptionController,
    required this.priceController,
    required this.portionController,
    required this.preparationController,
    required this.section,
    required this.onSectionChanged,
    required this.onSubmitted,
  });

  /// État courant.
  final OwnerPortalState state;

  /// Contrôleurs des champs du plat.
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final TextEditingController portionController;
  final TextEditingController preparationController;

  /// Section sélectionnée.
  final MenuSection section;

  /// Callback de changement de section.
  final ValueChanged<MenuSection> onSectionChanged;

  /// Callback de soumission.
  final VoidCallback onSubmitted;

  /// Construit le formulaire.
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Ajouter un plat',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du plat',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (facultative)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<MenuSection>(
              value: section,
              decoration: const InputDecoration(
                labelText: 'Section',
                border: OutlineInputBorder(),
              ),
              items: MenuSection.values
                  .map(
                    (MenuSection value) => DropdownMenuItem<MenuSection>(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (MenuSection? value) {
                if (value != null) {
                  onSectionChanged(value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Prix FCFA',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextField(
                    controller: preparationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Préparation (min)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: portionController,
              decoration: const InputDecoration(
                labelText: 'Portion (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: state.isBusy ? null : onSubmitted,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter au menu'),
            ),
          ],
        ),
      ),
    );
  }
}
