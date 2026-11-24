# Koudougou Gourmet

Application mobile Flutter pour les restaurants, maquis et cafés de
**Koudougou (Burkina Faso)** : menus en FCFA, contacts WhatsApp/téléphone,
géolocalisation, **devis de livraison selon la distance**, récapitulatif de
commande WhatsApp, Live Braise, radar d'ambiance, partage d'addition, annuaire
sourcé, espaces gérant/administration et avis sur l'application.

> **État actuel : application complète.** Socle `core/` (thème, sécurité,
> horloge), Domain pur, Data offline-first (**5 boîtes Hive chiffrées** + seed),
> couche **Presentation** (BLoC/Cubit + widgets + navigation), injection **GetIt**
> (`injection_container.dart`) et bootstrap définitif (`main.dart`). Les espaces
> `/annuaire`, `/avis`, `/owner` et `/admin` (`/createur` reste supporté) sont
> opérationnels.
> `flutter analyze` est propre et **287 tests** passent.

---

## Démarrage

```bash
# 1. Configuration locale (le fichier .env n'est pas versionné)
cp .env.example .env

# 2. Dépendances
flutter pub get

# 3. Analyse stricte + tests
flutter analyze
flutter test

# 4. Lancement
flutter run
```

Prérequis : **Flutter >= 3.47** / **Dart >= 3.13**. Version utilisée et validée :
**Flutter 3.50.1 / Dart 3.14.0**.

> **VS Code.** Le fichier `.vscode/settings.json` force `dart.flutterSdkPath`
> vers le SDK utilisé par le projet. Si vous aviez un réglage global pointant
> vers un ancien Flutter (par exemple 3.39 / Dart 3.10), les erreurs affichées
> dans l’éditeur sont fausses : lancez **Dart: Restart Analysis Server** ou
> **Developer: Reload Window** après ouverture du dossier du projet.

### Configuration et secrets

La configuration est résolue dans cet ordre :

1. `--dart-define=CLE=valeur` (recommandé en CI/CD) ;
2. fichier `.env` local ;
3. valeur de repli publique dans le code.

```bash
flutter run --dart-define=API_BASE_URL=https://api.exemple.bf
```

> ⚠️ Tout ce qui est compilé dans l'APK/IPA est extractible. Le fichier `.env`
> embarqué ne doit contenir **aucune clé privée** (paiement, `service_role`,
> token). Ces secrets restent côté serveur. Voir `.env.example`.

---

## Architecture

```text
lib/
├── core/
│   ├── constants/     # Constantes, configuration, routes, référentiel Koudougou
│   ├── error/         # Exceptions techniques, Failures métier, ErrorMapper
│   ├── location/      # Contrat LocationService + objet-valeur GeoPoint
│   ├── network/       # NetworkInfo (connectivité, offline-first)
│   ├── router/        # AppRouter : routes nommées, deep links, providers par route
│   ├── security/      # Sanitizer, validateurs, UrlGuard, coffre-fort AES
│   ├── theme/         # Couleurs, palette sémantique, typographie, ThemeController
│   ├── usecases/      # Contrats UseCase / StreamUseCase / NoParams
│   └── utils/         # Horloge injectable, formateurs FCFA/dates
├── features/
│   ├── restaurants/       # Catalogue : Domain / Data / Presentation
│   │   ├── domain/        # Entités, filtres/tri, contrats, use cases (pur)
│   │   ├── data/          # Modèles JSON, Hive / HTTPS / seed, repository
│   │   └── presentation/  # BLoC/Cubit, pages, widgets
│   ├── owner_portal/      # Ajout/retrait de plats (code gérant revérifié)
│   │   └── domain/ + presentation/
│   ├── creator_portal/    # PIN local + création d'établissement non vérifié
│   │   └── domain/ + presentation/
│   └── app_reviews/       # Avis locaux 1–5 étoiles + partage
│       ├── domain/        # Entité, contrats, use cases
│       ├── data/          # Modèle Hive + service de partage `share_plus`
│       └── presentation/  # `AppReviewsCubit`, page, formulaire
├── injection_container.dart  # GetIt : câblage de toutes les dépendances
└── main.dart          # Bootstrap définitif (Hive, GetIt, MaterialApp, routeur)
```

Règle de dépendance : `Presentation -> Domain <- Data`, avec `core/` partagé.
Le Domain ne dépend ni de Flutter, ni de HTTP, ni de Hive.

---

## Couche Presentation

Chaque écran observe un état immuable et délègue toute intention à un événement :
aucune logique métier dans les widgets.

| Composant | Rôle |
|---|---|
| `RestaurantListBloc` | Catalogue de l'accueil : chargement offline-first, recherche/filtres/tri **100 % locaux**, favoris, bandeau Live Braise. Le compteur de résultats propose un raccourci « Consulter l'annuaire ». Fourni une seule fois par `MainShell` (partagé entre Accueil et Favoris). |
| `RestaurantDetailBloc` | Fiche détaillée d'un restaurant (chargement par identifiant, favori). Créé par route. |
| `AmbianceRadarBloc` | Événements du radar (concerts, matchs, soirées), filtre « en direct ». |
| `CartCubit` | Panier : quantités + nombre de convives + option `deliveryRequested`. Les prix des plats restent dans l'entité `Restaurant`. Singleton applicatif. |
| `DeliveryCubit` | Devis de livraison : position locale, tarif calculé par le Domain, fast-foods proches proposés au-delà de 5 km. Cible passée en paramètre (aucun état caché). |
| `LocationCubit` | Position GPS via le contrat `LocationService` (jamais `geolocator` directement) : sert au tri par proximité, au devis et à l'affichage des distances. |
| `ThemeController` | `Cubit<ThemeMode>` : thème clair / sombre / système, persisté et exposé dans `MaterialApp`. |
| `DirectoryCubit` | Annuaire sourcé de Koudougou : statut de vérification et URL source affichés, jamais présenté comme une certification d'ouverture. |
| `OwnerPortalCubit` | Sélection d'un établissement (présélection possible depuis sa fiche), déverrouillage par code, ajout/retrait de plats, verrouillage automatique en arrière-plan. Le code est revérifié dans **chaque** use case d'écriture. |
| `CreatorPortalCubit` | Espace Administration : création du PIN, connexion, création d'une fiche locale avec code gérant associé, attribution/réinitialisation du code gérant d'une fiche existante (PIN ressaisi à chaque fois). |
| `AppReviewsCubit` | Note 1–5, commentaire, moyenne, liste des avis et partage explicite. |

### Navigation

`core/router/app_router.dart` utilise `onGenerateRoute` avec des chemins
construits par `AppRoutes` (`/restaurants/:id`, `/restaurants/:id/order`,
`/restaurants/:id/split-bill`, `/annuaire/:id`...). Le routeur :

- enveloppe chaque page profonde dans les `BlocProvider` nécessaires (via GetIt) ;
- injecte `UrlGuard` (sécurité des liens) et l'instant `now` (horloge) pour que
  les badges « Ouvert » / « Live Braise » restent testables ;
- crée un Cubit **neuf** pour `/annuaire`, `/avis`, `/owner` et `/admin` :
  aucun code saisi ne survit à la fermeture d'un espace ;
- transmet l'identifiant de la fiche à `/owner` : le bouton **Gérer le menu**
  ouvre directement le bon établissement, sans donner d'accès implicite ;
- résout `/annuaire/:id` depuis la fiche typée transmise par la carte, ou via
  `GetKoudougouDirectory` pour un lien profond, puis fournit le panier partagé et
  un `DeliveryCubit` neuf à la fiche commandable ;
- envoie toute route inconnue vers `NotFoundPage`.

Les tuiles « Espaces » des Paramètres ouvrent ces routes sans jamais
référencer directement un BLoC.

### Espaces gérant et administration

- **Gérant** : depuis Paramètres → « Espace gérant », ou depuis le bouton
  **Gérer le menu** d'une fiche. Choisir l'établissement, saisir son code
  gérant, puis ajouter ou retirer des plats. Chaque écriture **revérifie le
  code** ; le champ est effacé après chaque tentative et l'accès se verrouille
  à changement d'établissement, au bouton **Verrouiller** ou au passage en
  arrière-plan. Si la fiche n'a pas de code, un encart l'indique et propose
  d'ouvrir l'administration.
- **Administration** : depuis Paramètres → « Administration » (`/admin`, alias
  `/createur`). Premier lancement : créer le PIN. Ensuite : ajouter un
  établissement local **non vérifié**, ou attribuer/réinitialiser le code
  gérant d'une fiche déjà présente. L'attribution exige de **ressaisir le PIN
  administrateur** et de confirmer que la fiche existe dans le catalogue.
- Les codes gérants des fiches embarquées ne sont pas fournis : ils doivent être
  attribués localement via l'administration. Aucun établissement réel n'est
  certifié ouvert par ces espaces.

`MainShell` (4 onglets : Découvrir / Carte / Favoris / Paramètres, via
`IndexedStack` + `NavigationBar`) conserve l'état de chaque onglet et accepte un
`initialIndex` pour les deep links (`/map`, `/favorites`, `/settings`).

> **Carte sans SDK natif.** L'onglet Carte trie les restaurants par distance
> (Haversine) et ouvre Google Maps via `UrlGuard` : aucun plugin de carte lourd,
> aucune clé API à embarquer.

### Livraison, devis et récapitulatif WhatsApp

- Chaque fiche porte un champ explicite `deliveryAvailable`, affiché par un badge
  « Livraison disponible / indisponible ». Le repli sur l'équipement historique
  `RestaurantAmenity.delivery` est conservé pour les anciennes fiches.
- Le devis est calculé **localement** par `QuoteDelivery` (Haversine) :
  `500 FCFA + 200 FCFA/km`, supplément arrondi au FCFA supérieur, rayon maximal
  **5 km**. Au-delà, `FindNearbyFastFoods` propose les fast-foods **déjà présents
  dans l'annuaire**, triés par distance, sans fabriquer la moindre adresse.
- La fiche **Snack Time** est une seule entrée sourcée de l'annuaire
  (`snack-time-bcb`, `12.2469375 / -2.3885625`, « Face à la BCB »). Son devis est
  une simulation : ouverture et service de livraison restent à confirmer.
- La page de commande affiche un **récapitulatif fixe** en bas d'écran :
  **Modifier** ramène au panier, **Confirmer** ouvre `wa.me` avec un message
  pré-rempli (lignes, sous-total, frais de livraison, total, horodatage). Le
  message ne contient aucune coordonnée GPS et aucun paiement n'est capté.

### Fiche commandable de l'annuaire (`/annuaire/:id`)

Un appui sur une carte de l'annuaire (par exemple **Vivalto Café**) ouvre une
fiche détaillée qui affiche :

- les informations **sourcées** : quartier, horaires, numéro, niveau de
  vérification, source HTTPS consultable ;
- le téléphone et l'**itinéraire** (uniquement si la source publie des
  coordonnées : `position` ou paire `(lat ; lng)` dans `area`, jamais devinées) ;
- un **menu d'exemple signalé « démonstration – à confirmer »** : les plats et
  prix sont fictifs et ne prétendent pas être la carte réelle de l'établissement ;
- le même récapitulatif fixe que la commande classique : **Modifier** ramène au
  menu, **Confirmer** envoie le récap via `wa.me` au numéro sourcé.

`DirectoryOrderCatalog` (Domaine) convertit la fiche sourcée en `Restaurant`
commandable : identifiants des plats préfixés `demo/<id>/<slug>` pour ne jamais
mélanger deux fiches dans le panier singleton, champs non sourcés neutres et
`isVerified: false`. Le devis n'apparaît que si `deliveryAvailable` est vrai ET
si des coordonnées publiées existent.

---

## Injection de dépendances

`injection_container.dart` centralise le câblage **GetIt** :

- le cache Hive **déjà ouvert** par `main.dart` : 5 boîtes (restaurants, favoris,
  panier, radar, avis). La source d'avis est transmise explicitement à
  `configureDependencies(appReviewDataSource: cache.reviewDataSource)` ;
- `RestaurantRemoteDataSource` **uniquement** si `API_SYNC_ENABLED=true` et une URL HTTPS valide ;
- `RestaurantRepositoryImpl` (repository offline-first), `AppReviewRepositoryImpl`
  et `ReviewShareService` (`share_plus`) ;
- horloge (`SystemClock`), `LocationService`, `NetworkInfo`, `UrlGuard`,
  `PinAuthService` et coffre natif `SecureKeyStore` ;
- use cases du catalogue, de l'annuaire (`GetKoudougouDirectory`), de la
  livraison (`QuoteDelivery`, `FindNearbyFastFoods`), des deux portails et des
  avis ;
- **factory** pour tous les BLoC/Cubit de page, **singleton** pour `CartCubit` et
  `ThemeController`.

`configureDependencies()` est appelé une seule fois dans `main.dart`, après
l'ouverture du cache Hive. Le reste de l'application ne connaît que l'interface
`sl` (service locator) : aucune instanciation manuelle dans les widgets.

---

## Sécurité implémentée

- **Entrées** : `InputSanitizer` nettoie recherche, textes, téléphones, prix,
  e-mails, identifiants et URLs (balises, contrôles, caractères bidi/invisibles).
- **Liens externes** : schémas limités à `https`, `tel`, `geo` ; hôtes HTTPS en
  liste blanche exacte (`wa.me`, Google Maps...) ; `canLaunchUrl` avant
  `launchUrl` ; timeouts et erreurs converties en `Failure`.
- **Téléphone** : normalisation E.164 `+226XXXXXXXX`, refus des saisies polluées.
- **Cache** : clé AES-256 générée par `Random.secure` et conservée dans le
  Keychain iOS / Keystore Android (aucune clé dans le code).
- **Codes locaux** : PIN administrateur et codes gérant dérivés avec
  **PBKDF2-HMAC-SHA256, 210 000 itérations**, sel aléatoire de 16 octets généré
  par `Random.secure`. Seule l'empreinte est conservée dans le coffre natif ;
  les anciennes empreintes SHA-256 sont migrées automatiquement après une
  première vérification réussie. Comparaison à temps constant.
- **Force brute** : après **5 échecs** sur une même portée (administrateur ou
  établissement), l'accès est verrouillé **30 s**, puis 1 min, 2 min… plafonné à
  **15 min**. Le compteur et l'échéance sont persistés dans le coffre natif :
  redémarrer l'application ne les efface pas. Une réussite remet le compteur à
  zéro. Un changement de code l'efface aussi.
- **Sessions** : aucun secret dans les états BLoC/Cubit, champs obscurcis,
  effacés après tentative, à chaque changement d'établissement, au
  verrouillage manuel et au passage en arrière-plan.
- **Limites** : ce sont des barrières d'interface **locales**, hors ligne. Elles
  ne remplacent pas une authentification serveur, ne protègent pas contre un
  appareil compromis (clavier logiciel, attachement de débogueur, extraction du
  coffre par une racine) et ne vérifient aucune identité réelle. Une sécurité
  « ultra » exigerait un backend, HTTPS, des comptes serveur, des droits
  centralisés, de la journalisation et une rotation des codes — hors du
  périmètre de cette application offline-first.
- **Réseau** : `usesCleartextTraffic="false"` sur Android, API distante HTTPS.
- **Android 11+ / iOS** : déclarations `<queries>` et `LSApplicationQueriesSchemes`
  pour que la détection des applications de téléphone/carte fonctionne.
- **Typage** : `strict-casts`, `strict-inference`, `strict-raw-types`, aucun
  `dynamic`, `Either<Failure, T>` dans les contrats métier.

---

## Identité visuelle

| Rôle | Couleur |
|---|---|
| Primaire — basilic (navigation, actions courantes) | `#2D6A4F` |
| Appels à l'action — braise | `#E85D04` |
| Prix (mode clair, contraste renforcé) | `#C24A00` |
| Prix (mode sombre) | `#E85D04` |
| Accent — safran | `#FFB703` |
| Fond clair | `#FFFDF9` |
| Cartes claires | `#FFFFFF` |
| Fond sombre | `#121212` |
| Cartes sombres | `#1E1E1E` |
| Ouvert / Live Braise | `#2D6A4F` |
| Fermé / épuisé | `#D00000` |
| Vérifié sur place | `#0077B6` |

> **Confort visuel.** Le vert basilic remplace l'orange en grand aplat : il est
> utilisé pour la navigation, les filtres, les liens et les actions secondaires.
> Le terracotta est réservé aux prix et aux boutons principaux, avec un texte
> anthracite (meilleur contraste que du blanc sur orange). Les dégradés
> décoratifs passent en vert, et le mode sombre emploie `#74C69D` sur charbon.

---

## Données à vérifier avant production

- Numéros d'urgence (`17`, `18`, `112`) et codes USSD Mobile Money.
- Découpage des secteurs et repères de Koudougou.
- Numéro de support (`APP_SUPPORT_PHONE`), actuellement fictif.
- **10 établissements du seed** (`assets/seed/restaurants_koudougou.json`) :
  fiches **fictives de démonstration**, jamais présentées comme des commerces réels.
- **Annuaire sourcé** (`assets/seed/koudougou_directory.json`, 52 fiches) :
  chaque entrée affiche sa source et son statut de vérification. Aucune source
  ne certifie une ouverture actuelle : « Ouverture à confirmer avant déplacement ».
  Les menus proposés depuis ces fiches sont des **exemples de démonstration**,
  pas des cartes réelles : à confirmer par téléphone avant de commander.
- **18 fiches reprises du cahier de projet** : restaurants, maquis, fast-foods,
  bars et cafés/pâtisseries ajoutés avec leur repère, téléphone, horaires et prix
  publiés. Elles n'ont **ni coordonnées GPS ni URL source** et portent toutes le
  statut « À confirmer » : aucune ouverture n'est certifiée.
- **Fiches créées depuis l'application** : `isVerified: false`, note à 0, aucun
  horaire inventé et coordonnées par défaut au centre de Koudougou avec avertissement.

> ⚠️ **Téléphones de démonstration.** Les numéros du seed
> (`+22670000001` à `+22670000011`) sont **fictifs**. Ils respectent le format
> E.164 burkinabè mais ne joignent personne : chaque numéro doit être **vérifié
> sur le terrain** et remplacé avant toute publication en production. Il en va
> de même pour les noms, adresses, menus et prix.

---

## Stratégie offline-first

Le repository tente les sources dans cet ordre et retombe toujours sur une
valeur utilisable :

1. **Cache frais** (Hive, < 24 h) → réponse immédiate, sans réseau.
2. **API HTTPS** si `API_SYNC_ENABLED=true` et connexion disponible → mise à
   jour du cache.
3. **Cache périmé** si l'API échoue → mode dégradé.
4. **Seed embarqué** si aucun cache → premier lancement hors ligne fonctionnel.
5. **Failure** seulement si aucune source n'aboutit.

Une montée de `CACHE_SCHEMA_VERSION` (actuellement **2**) purge le catalogue et
les événements en cache au prochain lancement, tout en conservant les favoris :
c'est ainsi que les modifications du seed atteignent les installations déjà
ouvertes. Les fichiers JSON étant embarqués au build, un changement d'asset
nécessite aussi une reconstruction complète (un simple hot reload ne suffit pas).

Aucune exception ne franchit la frontière Domain : tout est converti en
`Failure` via `ErrorMapper`.

Les écritures des portails et des avis suivent le même principe : elles ne
modifient que le cache local chiffré. Un avis n'est **jamais envoyé** à un
serveur ; le bouton « Partager » ouvre la feuille de partage du système uniquement
après action explicite de l'utilisateur.

### Limite de chiffrement sur le Web

Le cache Hive est chiffré en **AES-256** sur mobile (clé dans le Keychain iOS /
Keystore Android). **Hive ne prend pas en charge AES sur le Web** : `main.dart`
appelle donc `HiveRestaurantCache.open(encrypt: !kIsWeb)`. Sur le Web, le cache
local n'est **pas** chiffré (stockage assumé, aucune donnée sensible n'y transite)
tandis que mobile et desktop conservent le chiffrement.
