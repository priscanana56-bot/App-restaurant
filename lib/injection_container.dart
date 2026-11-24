// =============================================================================
// Conteneur d'injection de dépendances (GetIt).
// -----------------------------------------------------------------------------
// Point UNIQUE de câblage de l'application. Les couches restent ignorantes les
// unes des autres : elles déclarent seulement des contrats (interfaces), et ce
// fichier décide quelle implémentation concrète est fournie.
//
// Règles de cycle de vie appliquées ici :
//   - `registerLazySingleton` : une seule instance, créée au premier accès.
//     Réservé aux objets SANS état d'écran (clients, services, use cases) et
//     aux états réellement partagés (`CartCubit`, `ThemeController`) ;
//   - `registerFactory` : une instance NEUVE par demande. Réservé aux BLoC de
//     page : deux fiches ouvertes ne doivent jamais partager leur état.
//
// Ce fichier est le SEUL (avec `MainShell`) à importer GetIt dans la
// Présentation, ce qui garde les widgets testables sans conteneur global.
// =============================================================================

// Conteneur de services.
import 'package:get_it/get_it.dart';

// Configuration d'environnement (mode local ou API distante).
import 'core/constants/app_config.dart';

// Horloge injectable (heure de Koudougou).
import 'core/utils/app_clock.dart';

// Traduction Exceptions -> Failures.
import 'core/error/error_mapper.dart';

// Détection de connectivité.
import 'core/network/network_info.dart';

// Service de localisation GPS.
import 'core/location/location_service.dart';

// Coffre-fort de la clé AES du cache Hive et service PIN local.
import 'core/security/pin_auth.dart';
import 'core/security/secure_key_store.dart';

// Garde-fou d'ouverture des liens externes.
import 'core/security/url_guard.dart';

// Contrôleur du thème clair/sombre.
import 'core/theme/theme_controller.dart';

// Avis sur l'application : Data, Domain et Présentation.
import 'features/app_reviews/data/datasources/app_review_local_data_source.dart';
import 'features/app_reviews/data/repositories/app_review_repository_impl.dart';
import 'features/app_reviews/data/services/share_plus_review_share_service.dart';
import 'features/app_reviews/domain/repositories/app_review_repository.dart';
import 'features/app_reviews/domain/services/review_share_service.dart';
import 'features/app_reviews/domain/usecases/get_app_reviews.dart';
import 'features/app_reviews/domain/usecases/share_app_review.dart';
import 'features/app_reviews/domain/usecases/submit_app_review.dart';
import 'features/app_reviews/presentation/bloc/app_reviews_cubit.dart';

// Portail gérant : use cases et Cubit.
import 'features/owner_portal/domain/usecases/add_menu_item.dart';
import 'features/owner_portal/domain/usecases/get_owner_restaurants.dart';
import 'features/owner_portal/domain/usecases/has_owner_code.dart';
import 'features/owner_portal/domain/usecases/remove_menu_item.dart';
import 'features/owner_portal/domain/usecases/verify_owner_code.dart';
import 'features/owner_portal/presentation/bloc/owner_portal_cubit.dart';

// Espace administration : use cases et Cubit.
import 'features/creator_portal/domain/usecases/assign_owner_code.dart';
import 'features/creator_portal/domain/usecases/create_establishment.dart';
import 'features/creator_portal/domain/usecases/has_creator_pin.dart';
import 'features/creator_portal/domain/usecases/set_creator_pin.dart';
import 'features/creator_portal/domain/usecases/verify_creator_pin.dart';
import 'features/creator_portal/presentation/bloc/creator_portal_cubit.dart';

// Contrats et implémentations de la couche Data.
import 'features/restaurants/data/datasources/http_restaurant_remote_data_source.dart';
import 'features/restaurants/data/datasources/koudougou_directory_data_source.dart';
import 'features/restaurants/data/datasources/restaurant_local_data_source.dart';
import 'features/restaurants/data/datasources/restaurant_remote_data_source.dart';
import 'features/restaurants/data/datasources/restaurant_seed_data_source.dart';
import 'features/restaurants/data/repositories/koudougou_directory_repository_impl.dart';
import 'features/restaurants/data/repositories/restaurant_repository_impl.dart';

// Contrats du Domain.
import 'features/restaurants/domain/repositories/koudougou_directory_repository.dart';
import 'features/restaurants/domain/repositories/restaurant_repository.dart';

// Use cases du catalogue.
import 'features/restaurants/domain/usecases/filter_restaurants.dart';
import 'features/restaurants/domain/usecases/find_nearby_fast_foods.dart';
import 'features/restaurants/domain/usecases/quote_delivery.dart';
import 'features/restaurants/domain/usecases/get_event_radar.dart';
import 'features/restaurants/domain/usecases/get_koudougou_directory.dart';
import 'features/restaurants/domain/usecases/get_favorite_ids.dart';
import 'features/restaurants/domain/usecases/get_live_braise.dart';
import 'features/restaurants/domain/usecases/get_restaurant_by_id.dart';
import 'features/restaurants/domain/usecases/get_restaurants.dart';
import 'features/restaurants/domain/usecases/toggle_favorite.dart';

// BLoC et Cubits de la Présentation.
import 'features/restaurants/presentation/bloc/ambiance_radar_bloc.dart';
import 'features/restaurants/presentation/bloc/cart_cubit.dart';
import 'features/restaurants/presentation/bloc/delivery_cubit.dart';
import 'features/restaurants/presentation/bloc/directory_cubit.dart';
import 'features/restaurants/presentation/bloc/location_cubit.dart';
import 'features/restaurants/presentation/bloc/restaurant_detail_bloc.dart';
import 'features/restaurants/presentation/bloc/restaurant_list_bloc.dart';

/// Instance globale du conteneur, accessible via `sl<Type>()`.
/// Le nom court `sl` (service locator) évite de répéter `GetIt.instance` partout.
final GetIt sl = GetIt.instance;

/// Câble toutes les dépendances de l'application.
///
/// [localDataSource] est FOURNI par l'appelant : le cache Hive doit d'abord être
/// ouvert (opération asynchrone et potentiellement chiffrée) dans `main.dart`.
/// Cette séparation garde `configureDependencies` synchrone et testable.
void configureDependencies({
  required RestaurantLocalDataSource localDataSource,
  required AppReviewLocalDataSource appReviewDataSource,
}) {
  // ---------------------------------------------------------------------------
  // 1. Services « socle » (sans état métier)
  // ---------------------------------------------------------------------------

  // Coffre-fort natif : génère et conserve la clé AES-256 du cache Hive.
  sl.registerLazySingleton<SecureKeyStore>(FlutterSecureKeyStore.new);

  // Connectivité réseau : utilisée par le repository pour décider d'un appel HTTP.
  sl.registerLazySingleton<NetworkInfo>(ConnectivityNetworkInfo.new);

  // Horloge de Koudougou (GMT+0) : injectée partout pour des tests déterministes.
  sl.registerLazySingleton<AppClock>(() => const SystemClock());

  // Traducteur d'erreurs techniques vers des `Failure` affichables.
  sl.registerLazySingleton<ErrorMapper>(() => const ErrorMapper());

  // Garde-fou unique des liens externes (WhatsApp, téléphone, Google Maps).
  sl.registerLazySingleton<UrlGuard>(UrlGuard.new);

  // Service GPS : la Présentation ne parle jamais directement à `geolocator`.
  sl.registerLazySingleton<LocationService>(
    () => const GeolocatorLocationService(),
  );

  // Service d'authentification locale : codes hachés dans le coffre natif.
  sl.registerLazySingleton<PinAuthService>(
    // L'horloge injectée rend le verrouillage testable et cohérent avec le
    // reste de l'application (heure de Koudougou).
    () => PinAuthService(sl<SecureKeyStore>(), clock: sl<AppClock>()),
  );

  // ---------------------------------------------------------------------------
  // 2. États partagés (singletons réactifs)
  // ---------------------------------------------------------------------------

  // Thème : modifié depuis les Paramètres, lu par `MaterialApp`.
  sl.registerLazySingleton<ThemeController>(ThemeController.new);

  // Panier : partagé entre la fiche, la commande et le partage d'addition.
  // Un seul panier par session utilisateur, volontairement NON fermé par les
  // routes qui le consomment.
  sl.registerLazySingleton<CartCubit>(CartCubit.new);

  // ---------------------------------------------------------------------------
  // 3. Sources de données
  // ---------------------------------------------------------------------------

  // Catalogue embarqué de secours (asset JSON), toujours disponible hors ligne.
  sl.registerLazySingleton<RestaurantSeedDataSource>(
    AssetRestaurantSeedDataSource.new,
  );

  // Annuaire réel sourcé : asset distinct du catalogue de démonstration.
  sl.registerLazySingleton<KoudougouDirectoryDataSource>(
    AssetKoudougouDirectoryDataSource.new,
  );

  // Cache local déjà ouvert par `main.dart` : on enregistre l'instance fournie.
  sl.registerLazySingleton<RestaurantLocalDataSource>(() => localDataSource);

  // Stockage des avis : même chiffrement AES, boîte Hive séparée.
  sl.registerLazySingleton<AppReviewLocalDataSource>(() => appReviewDataSource);

  // Source distante HTTP : enregistrée UNIQUEMENT si une API HTTPS valide est
  // configurée. Sinon, aucune instance n'existe et le repository reste local.
  if (AppConfig.hasRemoteBackend) {
    sl.registerLazySingleton<RestaurantRemoteDataSource>(
      () => HttpRestaurantRemoteDataSource(baseUrl: AppConfig.apiBaseUrl),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Repository (implémentation du contrat du Domain)
  // ---------------------------------------------------------------------------

  sl.registerLazySingleton<RestaurantRepository>(
    () => RestaurantRepositoryImpl(
      // Cache chiffré, seed embarqué et état réseau.
      localDataSource: sl<RestaurantLocalDataSource>(),
      seedDataSource: sl<RestaurantSeedDataSource>(),
      networkInfo: sl<NetworkInfo>(),
      clock: sl<AppClock>(),
      errorMapper: sl<ErrorMapper>(),

      // Source distante optionnelle : `null` en mode 100 % local.
      remoteDataSource: AppConfig.hasRemoteBackend
          ? sl<RestaurantRemoteDataSource>()
          : null,
    ),
  );

  // Annuaire sourcé : repository dédié, sans écriture possible depuis l'app.
  sl.registerLazySingleton<KoudougouDirectoryRepository>(
    () => KoudougouDirectoryRepositoryImpl(sl()),
  );

  // Avis locaux : repository + partage natif injectable.
  sl.registerLazySingleton<AppReviewRepository>(
    () => AppReviewRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton<ReviewShareService>(
    SharePlusReviewShareService.create,
  );

  // ---------------------------------------------------------------------------
  // 5. Use cases (sans état, donc singletons paresseux)
  // ---------------------------------------------------------------------------

  // Annuaire sourcé de Koudougou.
  sl.registerLazySingleton<GetKoudougouDirectory>(
    () => GetKoudougouDirectory(sl()),
  );

  // Avis sur l'application.
  sl.registerLazySingleton<GetAppReviews>(() => GetAppReviews(sl()));
  sl.registerLazySingleton<SubmitAppReview>(() => SubmitAppReview(sl(), sl()));
  sl.registerLazySingleton<ShareAppReview>(() => ShareAppReview(sl()));

  // Catalogue complet (stratégie offline-first gérée par la Data).
  sl.registerLazySingleton<GetRestaurants>(() => GetRestaurants(sl()));

  // Fiche précise, identifiant revalidé côté Domain.
  sl.registerLazySingleton<GetRestaurantById>(() => GetRestaurantById(sl()));

  // Favoris locaux.
  sl.registerLazySingleton<GetFavoriteIds>(() => GetFavoriteIds(sl()));
  sl.registerLazySingleton<ToggleFavorite>(() => ToggleFavorite(sl()));

  // Filtrage/tri local (pur, dépend seulement de l'horloge).
  sl.registerLazySingleton<FilterRestaurants>(() => FilterRestaurants(sl()));

  // Livraison : tarif et redirection, deux calculs purs sans état.
  sl.registerLazySingleton<QuoteDelivery>(() => const QuoteDelivery());
  sl.registerLazySingleton<FindNearbyFastFoods>(
    () => const FindNearbyFastFoods(),
  );

  // Live Braise et radar : le repository + l'horloge suffisent.
  sl.registerLazySingleton<GetLiveBraise>(() => GetLiveBraise(sl(), sl()));
  sl.registerLazySingleton<GetEventRadar>(() => GetEventRadar(sl(), sl()));

  // Portail gérant : le code est revérifié dans chaque use case d'écriture.
  sl.registerLazySingleton<GetOwnerRestaurants>(
    () => GetOwnerRestaurants(sl()),
  );
  sl.registerLazySingleton<HasOwnerCode>(() => HasOwnerCode(sl()));
  sl.registerLazySingleton<VerifyOwnerCode>(() => VerifyOwnerCode(sl()));
  sl.registerLazySingleton<AddMenuItem>(() => AddMenuItem(sl(), sl(), sl()));
  sl.registerLazySingleton<RemoveMenuItem>(() => RemoveMenuItem(sl(), sl()));

  // Administration : PIN local, création non vérifiée et attribution des codes.
  sl.registerLazySingleton<HasCreatorPin>(() => HasCreatorPin(sl(), sl()));
  sl.registerLazySingleton<SetCreatorPin>(() => SetCreatorPin(sl()));
  sl.registerLazySingleton<VerifyCreatorPin>(() => VerifyCreatorPin(sl()));
  sl.registerLazySingleton<CreateEstablishment>(
    () => CreateEstablishment(sl(), sl(), sl(), sl()),
  );
  sl.registerLazySingleton<AssignOwnerCode>(
    () => AssignOwnerCode(sl(), sl(), sl()),
  );

  // ---------------------------------------------------------------------------
  // 6. BLoC et Cubits de page (une instance NEUVE par écran)
  // ---------------------------------------------------------------------------

  // Catalogue + favoris : partagé par les onglets via `MainShell`, mais créé
  // comme une fabrique pour qu'un futur écran isolé puisse en avoir un autre.
  sl.registerFactory<RestaurantListBloc>(
    () => RestaurantListBloc(
      getRestaurants: sl(),
      filterRestaurants: sl(),
      getLiveBraise: sl(),
      getFavoriteIds: sl(),
      toggleFavorite: sl(),
      clock: sl(),
    ),
  );

  // Fiche détaillée : une instance par route ouverte.
  sl.registerFactory<RestaurantDetailBloc>(
    () => RestaurantDetailBloc(
      getRestaurantById: sl(),
      getFavoriteIds: sl(),
      toggleFavorite: sl(),
    ),
  );

  // Radar d'ambiance : une instance par coquille.
  sl.registerFactory<AmbianceRadarBloc>(
    () => AmbianceRadarBloc(getEventRadar: sl(), clock: sl()),
  );

  // Localisation : une instance par onglet carte.
  sl.registerFactory<LocationCubit>(() => LocationCubit(sl()));

  // Devis de livraison : une instance par fiche / page de commande.
  sl.registerFactory<DeliveryCubit>(
    () => DeliveryCubit(sl(), sl(), sl(), sl()),
  );

  // Annuaire sourcé : une instance par coquille / page dédiée.
  sl.registerFactory<DirectoryCubit>(() => DirectoryCubit(sl()));

  // Avis : une instance par ouverture de l'écran.
  sl.registerFactory<AppReviewsCubit>(() => AppReviewsCubit(sl(), sl(), sl()));

  // Portails : une instance par ouverture, jamais partagée entre écrans.
  // Le code saisi reste dans la page et n'est pas conservé dans le Cubit.
  sl.registerFactory<OwnerPortalCubit>(
    () => OwnerPortalCubit(sl(), sl(), sl(), sl(), sl()),
  );
  sl.registerFactory<CreatorPortalCubit>(
    () => CreatorPortalCubit(sl(), sl(), sl(), sl(), sl(), sl()),
  );
}
