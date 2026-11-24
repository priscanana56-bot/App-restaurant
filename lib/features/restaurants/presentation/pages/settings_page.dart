// =============================================================================
// Écran des paramètres.
// -----------------------------------------------------------------------------
// Regroupe les réglages non sensibles : apparence (thème), mode de données
// (local ou API distante), contacts d'urgence et informations de paiement
// mobile. Aucune donnée personnelle n'est collectée ni transmise : le thème est
// un état local, la position reste sur l'appareil et les paiements se font hors
// application.
// =============================================================================

// `unawaited` pour les appels d'urgence déclenchés par un geste.
import 'dart:async';

// Widgets et Material.
import 'package:flutter/material.dart';

// BLoC et Cubit.
import 'package:flutter_bloc/flutter_bloc.dart';

// Configuration d'environnement (mode de données).
import '../../../../core/constants/app_config.dart';

// Constantes publiques (identité, ville, pays et chemins).
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_routes.dart';

// Référentiel local (contacts d'urgence, Mobile Money).
import '../../../../core/constants/koudougou_reference.dart';

// Garde-fou d'ouverture des liens externes.
import '../../../../core/security/url_guard.dart';

// Palette et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

// Contrôleur de thème.
import '../../../../core/theme/theme_controller.dart';

// Formatage des numéros.
import '../../../../core/utils/formatters.dart';

// Retour utilisateur des liens externes.
import '../widgets/link_feedback.dart';

/// Page des paramètres de l'application.
final class SettingsPage extends StatelessWidget {
  /// Construit la page.
  const SettingsPage({required this.urlGuard, super.key});

  /// Garde-fou d'ouverture des liens (appels d'urgence).
  final UrlGuard urlGuard;

  /// Construit la page.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Barre d'application.
      appBar: AppBar(title: const Text('Paramètres')),

      // Corps défilant.
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: <Widget>[
          // ---------------------------------------------------------------
          // Apparence
          // ---------------------------------------------------------------
          const _SectionTitle(icon: Icons.palette_outlined, title: 'Apparence'),
          const SizedBox(height: AppSpacing.xs),
          const _ThemeSelector(),
          const SizedBox(height: AppSpacing.lg),

          // ---------------------------------------------------------------
          // Données et synchronisation
          // ---------------------------------------------------------------
          const _SectionTitle(icon: Icons.cloud_outlined, title: 'Données'),
          const SizedBox(height: AppSpacing.xs),
          const _DataModeCard(),
          const SizedBox(height: AppSpacing.lg),

          // ---------------------------------------------------------------
          // Espaces locaux (annuaire, avis et portails)
          // ---------------------------------------------------------------
          const _SectionTitle(icon: Icons.dashboard_outlined, title: 'Espaces'),
          const SizedBox(height: AppSpacing.xs),
          const _NavigationTile(
            icon: Icons.travel_explore_outlined,
            title: 'Annuaire de Koudougou',
            subtitle: 'Fiches sourcées, avec statut de vérification',
            route: AppRoutes.directory,
          ),
          const _NavigationTile(
            icon: Icons.rate_review_outlined,
            title: 'Avis sur l’application',
            subtitle: 'Notez et partagez votre avis, localement',
            route: AppRoutes.appReviews,
          ),
          const _NavigationTile(
            icon: Icons.manage_accounts_outlined,
            title: 'Espace gérant',
            subtitle: 'Ajouter ou retirer un plat d’un menu',
            route: AppRoutes.ownerPortal,
          ),
          const _NavigationTile(
            icon: Icons.add_business_outlined,
            title: 'Administration',
            subtitle: 'Ajouter un établissement et attribuer les codes gérants',
            route: AppRoutes.adminPortal,
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---------------------------------------------------------------
          // Contacts d'urgence
          // ---------------------------------------------------------------
          const _SectionTitle(
            icon: Icons.emergency_outlined,
            title: 'Urgences',
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final EmergencyContact contact
              in KoudougouReference.emergencyContacts)
            _EmergencyContactTile(contact: contact, urlGuard: urlGuard),
          const SizedBox(height: AppSpacing.sm),
          _SupportCallTile(urlGuard: urlGuard),
          const SizedBox(height: AppSpacing.lg),

          // ---------------------------------------------------------------
          // Paiement mobile
          // ---------------------------------------------------------------
          const _SectionTitle(
            icon: Icons.smartphone_outlined,
            title: 'Paiement mobile',
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final MobileMoneyOperator operator
              in KoudougouReference.mobileMoneyOperators)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text('${operator.name} · ${operator.ussdCode}'),
                subtitle: Text(operator.instructions),
              ),
            ),
          const _SafetyNotice(),
          const SizedBox(height: AppSpacing.lg),

          // ---------------------------------------------------------------
          // À propos
          // ---------------------------------------------------------------
          const _SectionTitle(icon: Icons.info_outline, title: 'À propos'),
          const SizedBox(height: AppSpacing.xs),
          const _AboutCard(),

          // Marge basse.
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Ligne de navigation vers un espace dédié.
/// Le chemin est envoyé au routeur central : la page n'a jamais à connaître
/// le Cubit ni les dépendances de la destination.
final class _NavigationTile extends StatelessWidget {
  /// Construit la ligne.
  const _NavigationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  /// Icône d'identification.
  final IconData icon;

  /// Libellé principal.
  final String title;

  /// Description courte.
  final String subtitle;

  /// Chemin nommé cible.
  final String route;

  /// Construit la ligne.
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pushNamed(route),
      ),
    );
  }
}

/// Titre de section avec icône, commun à tous les blocs de la page.
final class _SectionTitle extends StatelessWidget {
  /// Construit le titre.
  const _SectionTitle({required this.icon, required this.title});

  /// Icône de la section.
  final IconData icon;

  /// Libellé de la section.
  final String title;

  /// Construit le titre.
  @override
  Widget build(BuildContext context) {
    // Thème local.
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Sélecteur de thème : système, clair ou sombre.
final class _ThemeSelector extends StatelessWidget {
  /// Construit le sélecteur.
  const _ThemeSelector();

  /// Construit le sélecteur.
  @override
  Widget build(BuildContext context) {
    // Contrôleur de thème partagé (fourni à la racine de l'application).
    final ThemeController controller = context.read<ThemeController>();

    return BlocBuilder<ThemeController, ThemeMode>(
      builder: (BuildContext context, ThemeMode mode) {
        return Card(
          child: Column(
            children: <Widget>[
              // Une ligne par mode disponible.
              for (final ThemeMode option in ThemeMode.values)
                ListTile(
                  leading: Icon(_iconFor(option)),
                  title: Text(_labelFor(option)),
                  // Coche le mode actif sans ambiguïté.
                  trailing: mode == option
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : const Icon(Icons.circle_outlined),
                  onTap: () => controller.setMode(option),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Icône associée à un mode de thème.
  static IconData _iconFor(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => Icons.brightness_auto_outlined,
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
    };
  }

  /// Libellé français d'un mode de thème.
  static String _labelFor(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'Suivre le système',
      ThemeMode.light => 'Thème clair',
      ThemeMode.dark => 'Thème sombre',
    };
  }
}

/// Carte décrivant la provenance des données (local ou API distante).
final class _DataModeCard extends StatelessWidget {
  /// Construit la carte.
  const _DataModeCard();

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    // Typographie et palette locales.
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppPalette palette = AppPalette.of(context);

    // Résumé lisible du mode de fonctionnement.
    final String modeLabel = switch (AppConfig.runtimeMode) {
      'remote-sync' => 'API distante — synchronisation active',
      'remote-readonly' => 'API distante — lecture seule',
      _ => 'Données embarquées — fonctionnement hors ligne',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Mode courant.
            Row(
              children: <Widget>[
                Icon(
                  AppConfig.hasRemoteBackend
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  color: AppConfig.hasRemoteBackend
                      ? palette.success
                      : palette.mutedText,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    modeLabel,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            // Explication rassurante sur le cache local.
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Le catalogue est mis en cache sur l’appareil et reste consultable '
              'sans connexion. Les favoris sont stockés localement.',
              style: textTheme.bodySmall?.copyWith(color: palette.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne d'appel vers un contact d'urgence.
final class _EmergencyContactTile extends StatelessWidget {
  /// Construit la ligne.
  const _EmergencyContactTile({required this.contact, required this.urlGuard});

  /// Contact affiché.
  final EmergencyContact contact;

  /// Garde-fou d'ouverture du lien téléphonique.
  final UrlGuard urlGuard;

  /// Construit la ligne.
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: const Icon(Icons.call_outlined),
        title: Text('${contact.label} · ${contact.phone}'),
        subtitle: Text(contact.description),
        trailing: const Icon(Icons.chevron_right),
        // Appel du numéro court via le garde-fou de sécurité.
        onTap: () => unawaited(
          LinkFeedback.run(
            context,
            () => urlGuard.openEmergencyCall(contact.phone),
          ),
        ),
      ),
    );
  }
}

/// Ligne d'appel vers le support de l'application.
final class _SupportCallTile extends StatelessWidget {
  /// Construit la ligne.
  const _SupportCallTile({required this.urlGuard});

  /// Garde-fou d'ouverture du lien téléphonique.
  final UrlGuard urlGuard;

  /// Construit la ligne.
  @override
  Widget build(BuildContext context) {
    // Numéro de support configuré (repli public si absent).
    final String phone = AppConfig.supportPhone;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.support_agent_outlined),
        title: const Text('Support de l’application'),
        subtitle: Text(AppFormatters.phoneDisplay(phone)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => unawaited(
          LinkFeedback.run(context, () => urlGuard.openPhoneCall(phone)),
        ),
      ),
    );
  }
}

/// Avertissement de sécurité sur les paiements mobiles.
final class _SafetyNotice extends StatelessWidget {
  /// Construit l'avertissement.
  const _SafetyNotice();

  /// Construit l'avertissement.
  @override
  Widget build(BuildContext context) {
    // Typographie et palette locales.
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppPalette palette = AppPalette.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.lock_outline, size: 16, color: palette.warning),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            KoudougouReference.paymentSafetyNotice,
            style: textTheme.bodySmall?.copyWith(color: palette.mutedText),
          ),
        ),
      ],
    );
  }
}

/// Carte « À propos » : identité et périmètre de l'application.
final class _AboutCard extends StatelessWidget {
  /// Construit la carte.
  const _AboutCard();

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    // Typographie et palette locales.
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppPalette palette = AppPalette.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Identité de marque.
            Text(
              AppConstants.appName,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              AppConstants.appTagline,
              style: textTheme.bodyMedium?.copyWith(color: palette.mutedText),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Périmètre géographique et fuseau.
            Text(
              '${AppConstants.cityName}, ${AppConstants.countryName}',
              style: textTheme.bodySmall?.copyWith(color: palette.mutedText),
            ),
            Text(
              'Horaires affichés en heure de Koudougou '
              '(${AppConstants.timezoneName}).',
              style: textTheme.bodySmall?.copyWith(color: palette.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}
