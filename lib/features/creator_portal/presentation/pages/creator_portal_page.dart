// =============================================================================
// Espace administration — ajout d'établissements et attribution des codes.
// -----------------------------------------------------------------------------
// Premier lancement : création d'un PIN. Ensuite : connexion, puis deux outils
// distincts, chacun avec une authentification fraîche :
//   - ajouter un établissement local (non vérifié) ;
//   - attribuer/réinitialiser le code gérant d'une fiche déjà présente.
// Aucun secret n'est écrit dans le code, ni conservé dans l'état du Cubit :
// les codes restent dans des contrôleurs obscurcis, en mémoire le temps de la
// session, et sont effacés en cas de passage en arrière-plan.
// =============================================================================

// Widgets et Material.
import 'package:flutter/material.dart';

// BLoC.
import 'package:flutter_bloc/flutter_bloc.dart';

// Constantes de référence.
import '../../../../core/constants/koudougou_reference.dart';

// Palette et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

// Entités du catalogue.
import '../../../restaurants/domain/entities/restaurant.dart';
import '../../../restaurants/domain/entities/restaurant_category.dart';

// Cubit et état.
import '../bloc/creator_portal_cubit.dart';
import '../bloc/creator_portal_state.dart';

/// Écran de l'espace administration.
final class CreatorPortalPage extends StatefulWidget {
  /// Construit la page (le Cubit est fourni par la route).
  const CreatorPortalPage({super.key});

  @override
  State<CreatorPortalPage> createState() => _CreatorPortalPageState();
}

/// État de la page, propriétaire des contrôleurs de saisie.
final class _CreatorPortalPageState extends State<CreatorPortalPage>
    with WidgetsBindingObserver {
  /// Code administrateur, conservé en mémoire pour les créations successives.
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  /// Champs de la nouvelle fiche.
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _ownerCodeController = TextEditingController();

  /// Champs de l'attribution d'un code à une fiche existante.
  final TextEditingController _adminPinController = TextEditingController();
  final TextEditingController _newOwnerCodeController = TextEditingController();

  /// Catégorie et secteur choisis.
  RestaurantCategory _category = RestaurantCategory.maquis;
  String _sector = KoudougouReference.sectors.first;

  /// S'enregistre pour pouvoir reverrouiller en arrière-plan.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<CreatorPortalCubit>().load();
  }

  /// Libère les contrôleurs et l'observateur de cycle de vie.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    _confirmController.dispose();
    _nameController.dispose();
    _landmarkController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _ownerCodeController.dispose();
    _adminPinController.dispose();
    _newOwnerCodeController.dispose();
    super.dispose();
  }

  /// Reverrouille l'espace dès que l'application passe en arrière-plan :
  /// aucun code saisi ne doit survivre à une interruption.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _clearSecrets();
      context.read<CreatorPortalCubit>().lock();
    }
  }

  /// Efface tous les champs sensibles de la page.
  void _clearSecrets() {
    _pinController.clear();
    _confirmController.clear();
    _ownerCodeController.clear();
    _adminPinController.clear();
    _newOwnerCodeController.clear();
  }

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administration')),
      body: SafeArea(
        child: BlocBuilder<CreatorPortalCubit, CreatorPortalState>(
          builder: (BuildContext context, CreatorPortalState state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  switch (state.phase) {
                    CreatorPortalPhase.initial => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    CreatorPortalPhase.setupPin => _PinSetupCard(
                      state: state,
                      pinController: _pinController,
                      confirmController: _confirmController,
                    ),
                    CreatorPortalPhase.login => _PinLoginCard(
                      state: state,
                      pinController: _pinController,
                    ),
                    CreatorPortalPhase.unlocked => _UnlockedView(
                      state: state,
                      nameController: _nameController,
                      landmarkController: _landmarkController,
                      phoneController: _phoneController,
                      addressController: _addressController,
                      ownerCodeController: _ownerCodeController,
                      adminPinController: _adminPinController,
                      newOwnerCodeController: _newOwnerCodeController,
                      category: _category,
                      sector: _sector,
                      onCategoryChanged: (RestaurantCategory category) =>
                          setState(() => _category = category),
                      onSectorChanged: (String sector) =>
                          setState(() => _sector = sector),
                      onSubmit: _submit,
                      onAssignCode: _assignCode,
                      onLock: () {
                        _clearSecrets();
                        context.read<CreatorPortalCubit>().lock();
                      },
                    ),
                  },
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
                  if (state.createdRestaurant != null)
                    _CreatedCard(restaurant: state.createdRestaurant!),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Transmet le formulaire au Cubit avec le PIN déjà saisi.
  Future<void> _submit() async {
    final CreatorPortalCubit cubit = context.read<CreatorPortalCubit>();
    await cubit.create(
      creatorPin: _pinController.text,
      name: _nameController.text,
      category: _category,
      sector: _sector,
      landmark: _landmarkController.text,
      phone: _phoneController.text,
      address: _addressController.text,
      ownerCode: _ownerCodeController.text,
    );
    if (!mounted) {
      return;
    }
    if (cubit.state.failure == null) {
      // Le PIN n'est plus nécessaire après une création réussie.
      _pinController.clear();
      _nameController.clear();
      _landmarkController.clear();
      _phoneController.clear();
      _addressController.clear();
      _ownerCodeController.clear();
    }
  }

  /// Attribue un code gérant à la fiche sélectionnée.
  Future<void> _assignCode() async {
    final CreatorPortalCubit cubit = context.read<CreatorPortalCubit>();
    final String? restaurantId = cubit.state.selectedRestaurantId;
    if (restaurantId == null) {
      return;
    }
    await cubit.assignCode(
      adminPin: _adminPinController.text,
      restaurantId: restaurantId,
      code: _newOwnerCodeController.text,
    );
    if (!mounted) {
      return;
    }
    // Les secrets saisis ne restent pas à l'écran, même en cas d'échec.
    _adminPinController.clear();
    _newOwnerCodeController.clear();
  }
}

/// Premier réglage du code administrateur.
final class _PinSetupCard extends StatelessWidget {
  /// Construit la carte.
  const _PinSetupCard({
    required this.state,
    required this.pinController,
    required this.confirmController,
  });

  /// État courant.
  final CreatorPortalState state;

  /// Contrôleurs des codes.
  final TextEditingController pinController;
  final TextEditingController confirmController;

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Créer le code administrateur',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Ce code de 4 à 6 chiffres protège l’ajout d’établissements et '
              'l’attribution des codes gérants sur cet appareil. Seule une '
              'empreinte PBKDF2 est conservée dans le coffre natif.',
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Code administrateur',
                border: OutlineInputBorder(),
              ),
            ),
            TextField(
              controller: confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Confirmer le code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: state.isBusy
                  ? null
                  : () => context.read<CreatorPortalCubit>().setPin(
                      pin: pinController.text,
                      confirmation: confirmController.text,
                    ),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Enregistrer le code'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Connexion avec un PIN déjà créé.
final class _PinLoginCard extends StatelessWidget {
  /// Construit la carte.
  const _PinLoginCard({required this.state, required this.pinController});

  /// État courant.
  final CreatorPortalState state;

  /// Contrôleur du code.
  final TextEditingController pinController;

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Accès administration',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Code administrateur',
                border: OutlineInputBorder(),
              ),
            ),
            FilledButton.icon(
              onPressed: state.isBusy
                  ? null
                  : () => context.read<CreatorPortalCubit>().login(
                      pinController.text,
                    ),
              icon: const Icon(Icons.login),
              label: const Text('Déverrouiller'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Outils disponibles après authentification.
final class _UnlockedView extends StatelessWidget {
  /// Construit la vue.
  const _UnlockedView({
    required this.state,
    required this.nameController,
    required this.landmarkController,
    required this.phoneController,
    required this.addressController,
    required this.ownerCodeController,
    required this.adminPinController,
    required this.newOwnerCodeController,
    required this.category,
    required this.sector,
    required this.onCategoryChanged,
    required this.onSectorChanged,
    required this.onSubmit,
    required this.onAssignCode,
    required this.onLock,
  });

  /// État courant.
  final CreatorPortalState state;

  /// Contrôleurs du formulaire de création.
  final TextEditingController nameController;
  final TextEditingController landmarkController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController ownerCodeController;

  /// Contrôleurs de l'attribution d'un code.
  final TextEditingController adminPinController;
  final TextEditingController newOwnerCodeController;

  /// Catégorie et secteur sélectionnés.
  final RestaurantCategory category;
  final String sector;

  /// Callbacks de sélection.
  final ValueChanged<RestaurantCategory> onCategoryChanged;
  final ValueChanged<String> onSectorChanged;

  /// Callbacks d'action.
  final VoidCallback onSubmit;
  final VoidCallback onAssignCode;
  final VoidCallback onLock;

  /// Construit la vue.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: state.isBusy ? null : onLock,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Verrouiller'),
          ),
        ),
        _CodeAssignmentCard(
          state: state,
          adminPinController: adminPinController,
          newOwnerCodeController: newOwnerCodeController,
          onSubmit: onAssignCode,
        ),
        const SizedBox(height: AppSpacing.md),
        _CreationForm(
          state: state,
          nameController: nameController,
          landmarkController: landmarkController,
          phoneController: phoneController,
          addressController: addressController,
          ownerCodeController: ownerCodeController,
          category: category,
          sector: sector,
          onCategoryChanged: onCategoryChanged,
          onSectorChanged: onSectorChanged,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

/// Attribution d'un code gérant à une fiche du catalogue.
final class _CodeAssignmentCard extends StatelessWidget {
  /// Construit la carte.
  const _CodeAssignmentCard({
    required this.state,
    required this.adminPinController,
    required this.newOwnerCodeController,
    required this.onSubmit,
  });

  /// État courant.
  final CreatorPortalState state;

  /// Contrôleurs des codes saisis.
  final TextEditingController adminPinController;
  final TextEditingController newOwnerCodeController;

  /// Callback de soumission.
  final VoidCallback onSubmit;

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    final String? selected = state.selectedRestaurantId;
    final bool selectedExists = state.restaurants.any(
      (Restaurant restaurant) => restaurant.id == selected,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Attribuer un code gérant',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Les fiches déjà présentes n’ont pas toutes un code gérant. '
              'Choisissez une fiche, ressaisissez le code administrateur puis '
              'définissez le code à transmettre au responsable. Seule son '
              'empreinte PBKDF2 sera enregistrée.',
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              value: selectedExists ? selected : null,
              decoration: const InputDecoration(
                labelText: 'Établissement concerné',
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
              onChanged: state.isBusy
                  ? null
                  : (String? value) {
                      if (value != null) {
                        context.read<CreatorPortalCubit>().selectRestaurant(
                          value,
                        );
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: adminPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Code administrateur (à ressaisir)',
                border: OutlineInputBorder(),
              ),
            ),
            TextField(
              controller: newOwnerCodeController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Nouveau code gérant (4 à 6 chiffres)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonalIcon(
              onPressed: state.isBusy || selected == null ? null : onSubmit,
              icon: const Icon(Icons.key_outlined),
              label: const Text('Attribuer le code gérant'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulaire de création d'un établissement.
final class _CreationForm extends StatelessWidget {
  /// Construit le formulaire.
  const _CreationForm({
    required this.state,
    required this.nameController,
    required this.landmarkController,
    required this.phoneController,
    required this.addressController,
    required this.ownerCodeController,
    required this.category,
    required this.sector,
    required this.onCategoryChanged,
    required this.onSectorChanged,
    required this.onSubmit,
  });

  /// État courant.
  final CreatorPortalState state;

  /// Contrôleurs des champs.
  final TextEditingController nameController;
  final TextEditingController landmarkController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController ownerCodeController;

  /// Catégorie et secteur sélectionnés.
  final RestaurantCategory category;
  final String sector;

  /// Callbacks de sélection.
  final ValueChanged<RestaurantCategory> onCategoryChanged;
  final ValueChanged<String> onSectorChanged;

  /// Callback de soumission.
  final VoidCallback onSubmit;

  /// Construit le formulaire.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Card(
          color: AppColors.saffronSoft,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text(
              'La fiche créée reste NON vérifiée : aucun horaire ni GPS précis '
              'n’est inventé. Le point est placé au centre de Koudougou et le '
              'repère textuel sert de référence. Un code gérant sera associé '
              'à cette fiche.',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Nouvel établissement',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de l’établissement',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<RestaurantCategory>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(),
                  ),
                  items: RestaurantCategory.values
                      .map(
                        (RestaurantCategory value) =>
                            DropdownMenuItem<RestaurantCategory>(
                              value: value,
                              child: Text(value.label),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: (RestaurantCategory? value) {
                    if (value != null) {
                      onCategoryChanged(value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  value: sector,
                  decoration: const InputDecoration(
                    labelText: 'Secteur',
                    border: OutlineInputBorder(),
                  ),
                  items: KoudougouReference.sectors
                      .map(
                        (String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    if (value != null) {
                      onSectorChanged(value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: landmarkController,
                  decoration: const InputDecoration(
                    labelText: 'Repère (ex. Grand marché)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone burkinabè',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse ou description (facultatif)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: ownerCodeController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Code gérant à associer (4 ou 6 chiffres)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: state.isBusy ? null : onSubmit,
                  icon: const Icon(Icons.add_business_outlined),
                  label: const Text('Ajouter l’établissement'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Confirmation affichée après une création réussie.
final class _CreatedCard extends StatelessWidget {
  /// Construit la carte.
  const _CreatedCard({required this.restaurant});

  /// Fiche créée.
  final Restaurant restaurant;

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.basilSoft,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          '« ${restaurant.name} » a été ajouté localement dans '
          '${restaurant.sector}. Statut : non vérifié.',
        ),
      ),
    );
  }
}
