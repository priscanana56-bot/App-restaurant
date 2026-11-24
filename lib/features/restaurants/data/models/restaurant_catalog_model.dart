// =============================================================================
// Modèle du catalogue complet (restaurants + radar).
// -----------------------------------------------------------------------------
// C'est l'unité de synchronisation : l'API et le seed renvoient le même
// enveloppement versionné. Une version inconnue est refusée, les identifiants
// dupliqués aussi, et un événement orphelin est ignoré pour ne jamais produire
// de lien mort dans l'interface.
// =============================================================================

// Décodage JSON unique et typé.
import 'dart:convert';

// Version de schéma supportée.
import '../../../../core/constants/app_constants.dart';

// Entités Domain produites.
import '../../domain/entities/event_radar.dart';
import '../../domain/entities/restaurant.dart';

// Modèles imbriqués.
import 'event_radar_model.dart';
import 'json_reader.dart';
import 'restaurant_model.dart';

/// Enveloppe versionnée du catalogue.
final class RestaurantCatalogModel {
  /// Construit un catalogue déjà validé.
  const RestaurantCatalogModel({
    required this.schemaVersion,
    required this.restaurants,
    required this.events,
  });

  /// Version du schéma JSON (doit valoir [AppConstants.catalogSchemaVersion]).
  final int schemaVersion;

  /// Restaurants du catalogue.
  final List<RestaurantModel> restaurants;

  /// Événements du radar, tous rattachés à un restaurant connu.
  final List<EventRadarModel> events;

  /// Décode une chaîne JSON (asset ou réponse HTTP).
  factory RestaurantCatalogModel.fromJsonString(String raw) {
    // Conversion dynamique -> Object? immédiatement maîtrisée.
    final Object? decoded = jsonDecode(raw) as Object?;
    return RestaurantCatalogModel.fromJson(
      JsonReader.mapFrom(decoded, context: 'catalogue'),
    );
  }

  /// Valide et convertit l'enveloppe JSON.
  factory RestaurantCatalogModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);

    // Version obligatoire et strictement supportée.
    final int schemaVersion = reader.requireInt(
      'schemaVersion',
      min: 1,
      max: 999,
    );
    if (schemaVersion != AppConstants.catalogSchemaVersion) {
      throw const FormatException(
        'Version de catalogue non supportée par cette application.',
      );
    }

    // -------------------------------------------------------------------------
    // Restaurants
    // -------------------------------------------------------------------------
    final List<RestaurantModel> restaurants = <RestaurantModel>[];
    final Set<String> restaurantIds = <String>{};
    for (final Object? item in reader.requireList(
      'restaurants',
      maxLength: 500,
    )) {
      final RestaurantModel restaurant = RestaurantModel.fromJson(
        JsonReader.mapFrom(item, context: 'restaurant'),
      );

      // Un identifiant dupliqué rendrait le cache ambigu.
      if (!restaurantIds.add(restaurant.id)) {
        throw FormatException(
          'Restaurant en double dans le catalogue : « ${restaurant.id} ».',
        );
      }
      restaurants.add(restaurant);
    }

    // -------------------------------------------------------------------------
    // Événements du radar
    // -------------------------------------------------------------------------
    final List<EventRadarModel> events = <EventRadarModel>[];
    final Set<String> eventIds = <String>{};
    for (final Object? item in reader.optionalList('events', maxLength: 500)) {
      final EventRadarModel event = EventRadarModel.fromJson(
        JsonReader.mapFrom(item, context: 'événement'),
      );

      // Identifiant d'événement unique.
      if (!eventIds.add(event.id)) {
        throw FormatException(
          'Événement en double dans le catalogue : « ${event.id} ».',
        );
      }

      // Un événement orphelin ne peut pas ouvrir la fiche du restaurant.
      if (!restaurantIds.contains(event.restaurantId)) {
        continue;
      }
      events.add(event);
    }

    // Immuabilité des collections exposées.
    return RestaurantCatalogModel(
      schemaVersion: schemaVersion,
      restaurants: List<RestaurantModel>.unmodifiable(restaurants),
      events: List<EventRadarModel>.unmodifiable(events),
    );
  }

  /// Convertit les restaurants en entités pour l'instant [now].
  List<Restaurant> toEntities(DateTime now) => restaurants
      .map((RestaurantModel model) => model.toEntity(now))
      .toList(growable: false);

  /// Convertit les événements en entités pour l'instant [now].
  List<EventRadar> toEventEntities(DateTime now) => events
      .map((EventRadarModel model) => model.toEntity(now))
      .toList(growable: false);

  /// Sérialise le catalogue (utile aux tests de round-trip et au cache).
  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'restaurants': restaurants
        .map((RestaurantModel model) => model.toJson())
        .toList(growable: false),
    'events': events
        .map((EventRadarModel model) => model.toJson())
        .toList(growable: false),
  };
}
