// =============================================================================
// Point d'entrée définitif de l'application.
// -----------------------------------------------------------------------------
// Le démarrage suit un ordre STRICT, imposé par les dépendances natives :
//   1. `WidgetsFlutterBinding` : initialise les canaux natifs (plugins) ;
//   2. configuration `.env` / `--dart-define` : aucune valeur n'est lue avant ;
//   3. données de locale française pour `intl` (mois, jours) ;
//   4. ouverture du cache Hive (clé AES lue dans le Keychain/Keystore) ;
//   5. câblage de GetIt avec la source locale réellement ouverte ;
//   6. verrouillage de l'orientation puis `runApp`.
// Toute erreur d'étape 4 est déjà convertie en exception métier par la Data :
// l'application ne démarre jamais avec un cache à moitié initialisé.
// =============================================================================

// Widgets, Material et `Locale`.
import 'package:flutter/material.dart';

// `kIsWeb` : Hive ne chiffre pas sur le web (AES indisponible).
import 'package:flutter/foundation.dart';

// Verrouillage de l'orientation.
import 'package:flutter/services.dart';

// BLoC et Cubit à la racine (thème).
import 'package:flutter_bloc/flutter_bloc.dart';

// Localisations officielles Material / Widgets / Cupertino (français).
import 'package:flutter_localizations/flutter_localizations.dart';

// Données de locale française pour `intl` (noms de mois et de jours).
import 'package:intl/date_symbol_data_local.dart';

// Configuration d'environnement (chargée depuis `.env` ou `--dart-define`).
import 'core/constants/app_config.dart';

// Constantes publiques (nom, locale, fuseau).
import 'core/constants/app_constants.dart';

// Routes nommées (route initiale).
import 'core/constants/app_routes.dart';

// Routeur central : transforme un chemin en `Route` Flutter.
import 'core/router/app_router.dart';

// Coffre-fort de la clé AES-256 du cache.
import 'core/security/secure_key_store.dart';

// Thèmes clair et sombre.
import 'core/theme/app_theme.dart';

// Contrôleur réactif du mode de thème.
import 'core/theme/theme_controller.dart';

// Conteneur d'injection de dépendances.
import 'injection_container.dart';

// Bootstrap du cache Hive (ouverture des boîtes, chiffrement optionnel).
import 'features/restaurants/data/datasources/hive_restaurant_cache.dart';

/// Démarrage de l'application.
Future<void> main() async {
  // Initialise les canaux natifs AVANT tout appel à un plugin
  // (dotenv, secure storage, Hive, geolocator...).
  WidgetsFlutterBinding.ensureInitialized();

  // Charge `.env` une seule fois. Une absence de fichier n'est jamais bloquante :
  // les valeurs de production viennent des `--dart-define`.
  await AppConfig.load();

  // Charge les symboles de date français utilisés par `AppFormatters`.
  await initializeDateFormatting(AppConstants.defaultLocale);

  // Coffre-fort natif : génère la clé AES-256 au premier lancement, puis la relit.
  final SecureKeyStore keyStore = FlutterSecureKeyStore();

  // Ouvre les cinq boîtes Hive : catalogue et avis sur l'application.
  // Sur le web, le chiffrement AES n'existe pas : `encrypt` est désactivé.
  final HiveRestaurantCache cache = await HiveRestaurantCache.open(
    keyStore: keyStore,
    encrypt: !kIsWeb,
  );

  // Câble GetIt avec la source locale réellement ouverte.
  configureDependencies(
    localDataSource: cache.dataSource,
    appReviewDataSource: cache.reviewDataSource,
  );

  // Verrouille l'orientation portrait : l'expérience FoodTech est pensée pour
  // une prise en main à une main.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Lance l'interface.
  runApp(const KoudougouGourmetApp());
}

/// Racine de l'application.
final class KoudougouGourmetApp extends StatelessWidget {
  /// Construit la racine : aucun paramètre, toutes les dépendances viennent de
  /// GetIt (déjà câblé dans `main`).
  const KoudougouGourmetApp({super.key});

  /// Construit l'application et réagit aux changements de thème.
  @override
  Widget build(BuildContext context) {
    // Le contrôleur de thème est un singleton applicatif : fourni par référence,
    // il n'est jamais fermé par la racine.
    return BlocProvider<ThemeController>.value(
      value: sl<ThemeController>(),
      child: BlocBuilder<ThemeController, ThemeMode>(
        builder: (BuildContext context, ThemeMode themeMode) {
          return MaterialApp(
            // Masque le bandeau « DEBUG » en haut à droite.
            debugShowCheckedModeBanner: false,

            // Nom utilisé par les outils système et les aperçus de tâche.
            title: AppConstants.appName,

            // Thème clair complet (couleurs, typographie, composants).
            theme: AppTheme.light,

            // Thème sombre complet, confortable pour les sorties nocturnes.
            darkTheme: AppTheme.dark,

            // Mode courant : système, clair ou sombre.
            themeMode: themeMode,

            // Locale forcée en français du Burkina Faso.
            locale: const Locale('fr', 'FR'),

            // Seule locale supportée par cette première version.
            supportedLocales: const <Locale>[Locale('fr', 'FR')],

            // Traductions officielles des widgets Material, Widgets et Cupertino.
            localizationsDelegates: const <LocalizationsDelegate<Object>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // Premier écran : la coquille principale (onglet « Découvrir »).
            initialRoute: AppRoutes.home,

            // Toutes les routes (y compris les liens profonds) passent ici.
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
