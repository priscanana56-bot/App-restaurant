// =============================================================================
// Coquille principale de l'application (navigation par onglets).
// -----------------------------------------------------------------------------
// Elle fournit les BLoC partagés par plusieurs onglets :
//   - `RestaurantListBloc` : catalogue + favoris, utilisé par l'accueil et les
//     favoris (une seule source de vérité, donc pas de désynchronisation) ;
//   - `AmbianceRadarBloc` : événements du radar, affichés sur l'accueil ;
//   - `LocationCubit` : position GPS, utilisé par l'onglet carte.
// L'`IndexedStack` conserve l'état de chaque onglet (position de défilement,
// champ de recherche) lors des changements d'onglet.
// =============================================================================

// Widgets et Material.
import 'package:flutter/material.dart';

// BLoC et Cubit.
import 'package:flutter_bloc/flutter_bloc.dart';

// Injection de dépendances.
import '../../../../injection_container.dart';

// Sécurité des liens externes (paramètres).
import '../../../../core/security/url_guard.dart';

// BLoC et Cubits utilisés.
import '../bloc/ambiance_radar_bloc.dart';
import '../bloc/ambiance_radar_event.dart';
import '../bloc/directory_cubit.dart';
import '../bloc/location_cubit.dart';
import '../bloc/restaurant_list_bloc.dart';
import '../bloc/restaurant_list_event.dart';

// Onglets.
import 'favorites_page.dart';
import 'home_page.dart';
import 'map_page.dart';
import 'settings_page.dart';

/// Coquille avec barre de navigation inférieure à quatre onglets.
final class MainShell extends StatefulWidget {
  /// Construit la coquille.
  ///
  /// [initialIndex] permet au routeur d'ouvrir directement un onglet précis
  /// (lien profond `/map`, `/favorites` ou `/settings`).
  const MainShell({required this.urlGuard, this.initialIndex = 0, super.key})
    : assert(
        initialIndex >= 0 && initialIndex < 4,
        'L’onglet initial doit être compris entre 0 et 3.',
      );

  /// Garde-fou d'ouverture de liens (transmis à l'onglet Paramètres).
  final UrlGuard urlGuard;

  /// Onglet affiché à l'ouverture (0 = accueil).
  final int initialIndex;

  /// Crée l'état qui mémorise l'onglet actif.
  @override
  State<MainShell> createState() => _MainShellState();
}

/// État de la coquille.
class _MainShellState extends State<MainShell> {
  // Index de l'onglet affiché (initialisé depuis `widget.initialIndex`).
  late int _index;

  /// Initialise l'onglet actif depuis le paramètre du widget.
  @override
  void initState() {
    super.initState();
    // La valeur est déjà bornée par l'assertion du constructeur.
    _index = widget.initialIndex;
  }

  /// Construit la coquille et ses fournisseurs de BLoC.
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Catalogue partagé : démarré immédiatement (chargement offline-first).
        BlocProvider<RestaurantListBloc>(
          create: (_) =>
              sl<RestaurantListBloc>()..add(const RestaurantListStarted()),
        ),

        // Radar d'ambiance : chargé au démarrage de la coquille.
        BlocProvider<AmbianceRadarBloc>(
          create: (_) =>
              sl<AmbianceRadarBloc>()..add(const AmbianceRadarStarted()),
        ),

        // Position GPS : créée au repos, la demande est déclenchée par l'utilisateur.
        BlocProvider<LocationCubit>(create: (_) => sl<LocationCubit>()),

        // Annuaire sourcé : chargé immédiatement pour l'accueil.
        BlocProvider<DirectoryCubit>(
          create: (_) => sl<DirectoryCubit>()..load(),
        ),
      ],
      child: Scaffold(
        // Les quatre onglets sont conservés en mémoire.
        body: IndexedStack(
          index: _index,
          children: <Widget>[
            // Onglet 1 : catalogue, recherche, braise et radar.
            const HomePage(),

            // Onglet 2 : proximité et itinéraires.
            MapPage(urlGuard: widget.urlGuard),

            // Onglet 3 : restaurants mis en favori.
            const FavoritesPage(),

            // Onglet 4 : réglages, thème, contacts d'urgence.
            SettingsPage(urlGuard: widget.urlGuard),
          ],
        ),

        // Barre de navigation inférieure, conforme à la charte Material 3.
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (int index) {
            // Changement d'onglet purement local.
            setState(() {
              _index = index;
            });
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Découvrir',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Carte',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'Favoris',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Paramètres',
            ),
          ],
        ),
      ),
    );
  }
}
