// =============================================================================
// Routeur central de l'application.
// -----------------------------------------------------------------------------
// Un seul point de décision : `onGenerateRoute` transforme un chemin
// (navigation interne ou lien profond) en une `Route` Flutter. Les pages ne
// connaissent donc jamais GetIt : elles reçoivent leurs dépendances (BLoC,
// `UrlGuard`, horloge) au moment de la construction de la route.
//
// Choix de conception :
//   - `onGenerateRoute` plutôt qu'une table `routes:` : les chemins paramétrés
//     (`/restaurants/:id`) et le repli « page introuvable » sont explicites ;
//   - les identifiants capturés sont DÉCODÉS puis revalidés par le Domain :
//     un lien forgé ne peut jamais atteindre le stockage ;
//   - les espaces gérant/administration et les avis sont des routes à part, hors
//     coquille, chacune avec son Cubit neuf ;
//   - toute route inconnue renvoie vers `NotFoundPage` plutôt que de provoquer
//     un écran rouge.
// =============================================================================

// Widgets, Material et `Route`.
import 'package:flutter/material.dart';

// Fournisseurs de BLoC et de Cubit pour les routes paramétrées.
import 'package:flutter_bloc/flutter_bloc.dart';

// Erreur métier du chargement de l'annuaire.
import '../error/failures.dart';

// Conteneur d'injection : seul le routeur (avec `MainShell`) y accède.
import '../../injection_container.dart';

// BLoC et Cubit des espaces avancés.
import '../../features/app_reviews/presentation/bloc/app_reviews_cubit.dart';
import '../../features/creator_portal/presentation/bloc/creator_portal_cubit.dart';
import '../../features/owner_portal/presentation/bloc/owner_portal_cubit.dart';

// Entité de l'annuaire et use case de résolution pour les liens profonds.
import '../../features/restaurants/domain/entities/koudougou_listing.dart';
import '../../features/restaurants/domain/usecases/get_koudougou_directory.dart';

// Paramètres vides du use case.
import '../usecases/usecase.dart';

// BLoC et Cubit de la fiche détaillée et de l'annuaire.
import '../../features/restaurants/presentation/bloc/cart_cubit.dart';
import '../../features/restaurants/presentation/bloc/delivery_cubit.dart';
import '../../features/restaurants/presentation/bloc/directory_cubit.dart';
import '../../features/restaurants/presentation/bloc/restaurant_detail_bloc.dart';
import '../../features/restaurants/presentation/bloc/restaurant_detail_event.dart';

// Pages cibles.
import '../../features/app_reviews/presentation/pages/app_reviews_page.dart';
import '../../features/creator_portal/presentation/pages/creator_portal_page.dart';
import '../../features/owner_portal/presentation/pages/owner_portal_page.dart';
import '../../features/restaurants/presentation/pages/directory_listing_page.dart';
import '../../features/restaurants/presentation/pages/directory_page.dart';
import '../../features/restaurants/presentation/pages/main_shell.dart';
import '../../features/restaurants/presentation/pages/not_found_page.dart';
import '../../features/restaurants/presentation/pages/order_page.dart';
import '../../features/restaurants/presentation/pages/restaurant_detail_page.dart';
import '../../features/restaurants/presentation/pages/split_bill_page.dart';

// Chemins nommés.
import '../constants/app_routes.dart';

// Garde-fou des liens externes (transmis aux pages).
import '../security/url_guard.dart';

// Horloge injectée (badges « ouvert » et « Live Braise » déterministes).
import '../utils/app_clock.dart';

/// Fabrique de routes de l'application.
final class AppRouter {
  // Constructeur privé : espace de noms statique uniquement.
  const AppRouter._();

  // ---------------------------------------------------------------------------
  // Motifs de chemins paramétrés
  // ---------------------------------------------------------------------------
  // Un identifiant est un segment sans « / » : la classe `[^/]+` empêche toute
  // tentative de traversée de répertoire dans le chemin.

  /// `/restaurants/:id` — fiche détaillée.
  static final RegExp _detailPattern = RegExp(r'^/restaurants/([^/]+)$');

  /// `/restaurants/:id/order` — commande WhatsApp.
  static final RegExp _orderPattern = RegExp(r'^/restaurants/([^/]+)/order$');

  /// `/restaurants/:id/split-bill` — partage d'addition.
  static final RegExp _splitBillPattern = RegExp(
    r'^/restaurants/([^/]+)/split-bill$',
  );

  /// `/annuaire/:id` — fiche commandable d'une entrée sourcée.
  static final RegExp _directoryListingPattern = RegExp(r'^/annuaire/([^/]+)$');

  // ---------------------------------------------------------------------------
  // Point d'entrée du routeur
  // ---------------------------------------------------------------------------

  /// Construit la route correspondant à [settings].
  /// Ne renvoie jamais `null` : toute destination inconnue est redirigée vers
  /// la page « introuvable », ce qui évite un crash de navigation.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    // Chemin brut fourni par la navigation ou le lien profond.
    final String raw = settings.name ?? AppRoutes.home;

    // Suppression de la requête et du fragment : seuls le chemin nous intéresse.
    final String path = _stripQueryAndFragment(raw);

    // 1. Routes paramétrées (ordre important : la fiche est testée en dernier).
    final String? orderId = _captureId(_orderPattern, path);
    if (orderId != null) {
      return _orderRoute(orderId);
    }

    final String? splitId = _captureId(_splitBillPattern, path);
    if (splitId != null) {
      return _splitBillRoute(splitId);
    }

    final String? detailId = _captureId(_detailPattern, path);
    if (detailId != null) {
      return _detailRoute(detailId);
    }

    // Fiche de l'annuaire : les arguments typés sont utilisés quand ils sont
    // présents (appui sur une carte) ; sinon la fiche est résolue par identifiant
    // pour que les liens profonds fonctionnent aussi.
    final String? directoryListingId = _captureId(
      _directoryListingPattern,
      path,
    );
    if (directoryListingId != null) {
      return _directoryListingRoute(directoryListingId, settings.arguments);
    }

    // 2. Routes racines : un seul `MainShell`, positionné sur le bon onglet.
    switch (path) {
      case AppRoutes.home:
      case '':
        return _shellRoute(initialIndex: 0);
      case AppRoutes.map:
        return _shellRoute(initialIndex: 1);
      case AppRoutes.favorites:
        return _shellRoute(initialIndex: 2);
      case AppRoutes.settings:
        return _shellRoute(initialIndex: 3);
    }

    // 3. Pages hors coquille (annuaire, portails, avis).
    if (path == AppRoutes.directory) {
      return _directoryRoute();
    }
    if (path == AppRoutes.ownerPortal || path == AppRoutes.ownerLogin) {
      return _ownerPortalRoute(settings.arguments);
    }
    // `/createur` reste supporté pour les liens existants ; `/admin` est le
    // nouveau libellé affiché dans les réglages.
    if (path == AppRoutes.creatorPortal || path == AppRoutes.adminPortal) {
      return _creatorPortalRoute();
    }
    if (path == AppRoutes.appReviews) {
      return _appReviewsRoute();
    }

    // 4. Repli : toute route inconnue.
    return _notFoundRoute();
  }

  // ---------------------------------------------------------------------------
  // Construction des routes
  // ---------------------------------------------------------------------------

  /// Route de la coquille principale, ouverte sur [initialIndex].
  static Route<dynamic> _shellRoute({required int initialIndex}) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => MainShell(
        // `UrlGuard` vient de GetIt : la coquille le transmet aux onglets.
        urlGuard: sl<UrlGuard>(),
        initialIndex: initialIndex,
      ),
    );
  }

  /// Route de la fiche détaillée d'un restaurant.
  static Route<dynamic> _detailRoute(String restaurantId) {
    // L'horloge est lue UNE fois : tous les badges de la page partagent le même
    // instant de référence, ce qui garantit une cohérence visuelle parfaite.
    final DateTime now = sl<AppClock>().now();

    return MaterialPageRoute<void>(
      settings: RouteSettings(name: AppRoutes.restaurantDetail(restaurantId)),
      builder: (BuildContext context) => _provideRestaurantContext(
        restaurantId: restaurantId,
        // La page lit `RestaurantDetailBloc` et `CartCubit` depuis le contexte.
        child: RestaurantDetailPage(
          restaurantId: restaurantId,
          urlGuard: sl<UrlGuard>(),
          now: now,
        ),
      ),
    );
  }

  /// Route de la commande WhatsApp d'un restaurant.
  static Route<dynamic> _orderRoute(String restaurantId) {
    // Même instant de référence que la fiche, pour un enchaînement cohérent.
    final DateTime now = sl<AppClock>().now();

    return MaterialPageRoute<void>(
      settings: RouteSettings(name: AppRoutes.order(restaurantId)),
      builder: (BuildContext context) => _provideRestaurantContext(
        restaurantId: restaurantId,
        child: OrderPage(
          restaurantId: restaurantId,
          urlGuard: sl<UrlGuard>(),
          now: now,
        ),
      ),
    );
  }

  /// Route du partage d'addition d'un restaurant.
  static Route<dynamic> _splitBillRoute(String restaurantId) {
    // Instant de référence utilisé pour l'horodatage du message partagé.
    final DateTime now = sl<AppClock>().now();

    return MaterialPageRoute<void>(
      settings: RouteSettings(name: AppRoutes.splitBill(restaurantId)),
      builder: (BuildContext context) => _provideRestaurantContext(
        restaurantId: restaurantId,
        child: SplitBillPage(
          restaurantId: restaurantId,
          urlGuard: sl<UrlGuard>(),
          now: now,
        ),
      ),
    );
  }

  /// Route de l'annuaire réel sourcé de Koudougou.
  static Route<dynamic> _directoryRoute() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.directory),
      builder: (BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider<DirectoryCubit>(
            create: (_) => sl<DirectoryCubit>()..load(),
          ),
          // Devis de livraison de la fiche Snack Time sourcée.
          BlocProvider<DeliveryCubit>(create: (_) => sl<DeliveryCubit>()),
        ],
        child: DirectoryPage(urlGuard: sl<UrlGuard>()),
      ),
    );
  }

  /// Route de la fiche commandable d'une entrée de l'annuaire.
  static Route<dynamic> _directoryListingRoute(
    String listingId,
    Object? arguments,
  ) {
    // L'instant de référence est figé à l'ouverture de la route.
    final DateTime now = sl<AppClock>().now();
    final UrlGuard urlGuard = sl<UrlGuard>();

    // Appui sur une carte : l'objet typé est transmis directement, sans recharger
    // l'annuaire. Lien profond : le résolveur interroge le use case dédié.
    final KoudougouListing? passed = arguments is KoudougouListing
        ? arguments
        : null;

    return MaterialPageRoute<void>(
      settings: RouteSettings(name: AppRoutes.directoryListing(listingId)),
      builder: (BuildContext context) => _DirectoryListingResolver(
        listingId: listingId,
        listing: passed,
        urlGuard: urlGuard,
        now: now,
      ),
    );
  }

  /// Fournit le panier partagé et un devis neuf à la fiche d'annuaire.
  static Widget _provideDirectoryListingContext({
    required KoudougouListing listing,
    required Widget child,
  }) {
    return MultiBlocProvider(
      providers: [
        // Panier applicatif : jamais recréé, la commande doit le partager.
        BlocProvider<CartCubit>.value(value: sl<CartCubit>()),
        // Devis neuf par fiche ouverte (une seule fiche Snack Time sourcée).
        BlocProvider<DeliveryCubit>(
          create: (BuildContext context) => sl<DeliveryCubit>(),
        ),
      ],
      child: child,
    );
  }

  /// Route du portail gérant (modification locale du menu).
  ///
  /// [arguments] peut contenir l'identifiant d'une fiche : la page l'ouvre
  /// directement quand le bouton « Gérer le menu » est utilisé.
  static Route<dynamic> _ownerPortalRoute(Object? arguments) {
    final String initialId = AppRoutes.restaurantIdFromArguments(arguments);
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.ownerPortal),
      builder: (BuildContext context) => BlocProvider<OwnerPortalCubit>(
        // Le Cubit est neuf à chaque visite : aucun code ne survit à la fermeture.
        create: (_) =>
            sl<OwnerPortalCubit>()
              ..load(initialRestaurantId: initialId.isEmpty ? null : initialId),
        child: const OwnerPortalPage(),
      ),
    );
  }

  /// Route de l'administration (PIN local, établissements et codes gérants).
  static Route<dynamic> _creatorPortalRoute() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.creatorPortal),
      builder: (BuildContext context) => BlocProvider<CreatorPortalCubit>(
        create: (_) => sl<CreatorPortalCubit>()..load(),
        child: const CreatorPortalPage(),
      ),
    );
  }

  /// Route de l'espace d'avis sur l'application.
  static Route<dynamic> _appReviewsRoute() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.appReviews),
      builder: (BuildContext context) => BlocProvider<AppReviewsCubit>(
        create: (_) => sl<AppReviewsCubit>()..load(),
        child: const AppReviewsPage(),
      ),
    );
  }

  /// Route de repli « page introuvable ».
  static Route<dynamic> _notFoundRoute() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/introuvable'),
      builder: (BuildContext context) => const NotFoundPage(),
    );
  }

  // ---------------------------------------------------------------------------
  // Fourniture des dépendances
  // ---------------------------------------------------------------------------

  /// Enveloppe [child] avec les dépendances propres aux routes restaurant.
  ///
  /// - `RestaurantDetailBloc` est une instance FRAÎCHE par route : deux fiches
  ///   ouvertes en parallèle ne se marchent pas dessus ;
  /// - `CartCubit` est le singleton applicatif (`.value`) : il n'est jamais
  ///   fermé par le routeur, car la commande et le partage doivent le partager ;
  /// - `DeliveryCubit` est neuf par route : chaque fiche calcule son propre
  ///   devis sans réutiliser la position d'un autre écran.
  static Widget _provideRestaurantContext({
    required String restaurantId,
    required Widget child,
  }) {
    return MultiBlocProvider(
      providers: [
        // BLoC de la fiche : démarré immédiatement avec l'identifiant de route.
        BlocProvider<RestaurantDetailBloc>(
          create: (BuildContext context) =>
              sl<RestaurantDetailBloc>()
                ..add(RestaurantDetailRequested(restaurantId)),
        ),

        // Panier partagé : fourni par référence, jamais recréé ni fermé ici.
        BlocProvider<CartCubit>.value(value: sl<CartCubit>()),

        // Devis de livraison : une instance par fiche ouverte.
        BlocProvider<DeliveryCubit>(
          create: (BuildContext context) => sl<DeliveryCubit>(),
        ),
      ],
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // Utilitaires de chemin
  // ---------------------------------------------------------------------------

  /// Retire la requête (`?`) et le fragment (`#`) d'un chemin brut.
  /// Volontairement sans `Uri.parse` : aucune exception possible sur une entrée
  /// malformée provenant d'un lien externe.
  static String _stripQueryAndFragment(String raw) {
    final String withoutFragment = raw.split('#').first;
    return withoutFragment.split('?').first;
  }

  /// Capture et décode le premier groupe de [pattern] appliqué à [path].
  /// Retourne `null` si le chemin ne correspond pas, si le décodage échoue ou
  /// si l'identifiant obtenu est vide.
  static String? _captureId(RegExp pattern, String path) {
    // Recherche du motif.
    final RegExpMatch? match = pattern.firstMatch(path);
    if (match == null) {
      return null;
    }

    // Segment encodé (les identifiants sont encodés par `AppRoutes`).
    final String encoded = match.group(1) ?? '';
    if (encoded.isEmpty) {
      return null;
    }

    // Décodage protégé : un pourcentage malformé ne doit pas lever d'exception.
    try {
      final String decoded = Uri.decodeComponent(encoded);

      // Un identifiant vide après décodage est traité comme une route inconnue.
      return decoded.isEmpty ? null : decoded;
    } on FormatException {
      return null;
    }
  }
}

/// Résout la fiche d'annuaire d'un lien profond, puis installe les providers.
///
/// Quand la navigation vient d'une carte, la fiche est déjà disponible et
/// aucune lecture n'est effectuée. Sinon, le use case de l'annuaire est appelé
/// une seule fois ; une fiche introuvable renvoie vers la page « introuvable ».
final class _DirectoryListingResolver extends StatelessWidget {
  /// Construit le résolveur.
  const _DirectoryListingResolver({
    required this.listingId,
    required this.listing,
    required this.urlGuard,
    required this.now,
  });

  /// Identifiant capturé dans le chemin.
  final String listingId;

  /// Fiche transmise par la carte, ou `null` pour un lien profond.
  final KoudougouListing? listing;

  /// Garde-fou transmis à la page.
  final UrlGuard urlGuard;

  /// Instant de référence transmis à la page.
  final DateTime now;

  /// Charge la fiche uniquement si elle n'a pas été fournie.
  Future<KoudougouListing?> _resolve() async {
    final KoudougouListing? existing = listing;
    if (existing != null) {
      return existing;
    }

    final result = await sl<GetKoudougouDirectory>()(const NoParams());
    // `fold` garde le typage : aucun `dynamic`, aucune exception ne remonte.
    return result.fold((Failure failure) => null, (
      List<KoudougouListing> listings,
    ) {
      for (final KoudougouListing candidate in listings) {
        if (candidate.id == listingId) {
          return candidate;
        }
      }
      return null;
    });
  }

  /// Construit la page cible ou le repli « introuvable ».
  @override
  Widget build(BuildContext context) {
    final KoudougouListing? existing = listing;
    if (existing != null) {
      return AppRouter._provideDirectoryListingContext(
        listing: existing,
        child: DirectoryListingPage(
          listing: existing,
          urlGuard: urlGuard,
          now: now,
        ),
      );
    }

    return FutureBuilder<KoudougouListing?>(
      future: _resolve(),
      builder:
          (BuildContext context, AsyncSnapshot<KoudougouListing?> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final KoudougouListing? found = snapshot.data;
            if (found == null) {
              return const NotFoundPage();
            }
            return AppRouter._provideDirectoryListingContext(
              listing: found,
              child: DirectoryListingPage(
                listing: found,
                urlGuard: urlGuard,
                now: now,
              ),
            );
          },
    );
  }
}
