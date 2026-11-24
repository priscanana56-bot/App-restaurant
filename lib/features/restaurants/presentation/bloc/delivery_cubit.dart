// =============================================================================
// Cubit de devis de livraison.
// -----------------------------------------------------------------------------
// Il orchestre trois opérations simples : demander la position de l'utilisateur
// (service local), calculer le devis (use case pur) et proposer les fast-foods
// les plus proches quand la distance dépasse 5 km. Aucune position n'est
// envoyée à un serveur et aucun montant n'est débité : le devis est affiché,
// puis repris dans le message WhatsApp.
//
// La fiche ciblée est passée en paramètre de `requestLocation` : le Cubit n'a
// aucun état caché à synchroniser avec le widget (pas d'effet de bord dans
// `initState`, donc pas de rebuild pendant la phase de construction).
// =============================================================================

// Equatable pour comparer deux états et Either pour les retours typés.
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

// Cubit réactif.
import 'package:flutter_bloc/flutter_bloc.dart';

// Erreur métier affichable.
import '../../../../core/error/failures.dart';

// Position et service GPS injectés.
import '../../../../core/location/geo_point.dart';
import '../../../../core/location/location_service.dart';

// Entités du devis et des suggestions.
import '../../domain/entities/delivery_quote.dart';
import '../../domain/entities/nearby_restaurant.dart';
import '../../domain/entities/restaurant.dart';

// Use cases purs.
import '../../domain/usecases/find_nearby_fast_foods.dart';
import '../../domain/usecases/get_restaurants.dart';
import '../../domain/usecases/quote_delivery.dart';

/// Cycle de vie d'une demande de devis.
enum DeliveryStatus {
  /// Aucune demande effectuée.
  initial,

  /// Position en cours d'acquisition.
  requesting,

  /// Devis calculé (disponible ou refusé avec raison).
  ready,

  /// La position n'a pas pu être obtenue.
  failure,
}

/// État immuable du panneau de livraison.
final class DeliveryState extends Equatable {
  /// Construit un état.
  const DeliveryState({
    this.status = DeliveryStatus.initial,
    this.targetId = '',
    this.targetLabel = '',
    this.destination,
    this.deliveryAvailable = false,
    this.quote,
    this.nearbyFastFoods = const <NearbyRestaurant>[],
    this.failure,
  });

  /// Étape courante.
  final DeliveryStatus status;

  /// Identifiant de la fiche ciblée (exclu des suggestions).
  final String targetId;

  /// Libellé de la fiche ciblée.
  final String targetLabel;

  /// Point GPS de la fiche ciblée.
  final GeoPoint? destination;

  /// Indique si la fiche ciblée propose la livraison.
  final bool deliveryAvailable;

  /// Devis calculé, ou `null` avant la demande.
  final DeliveryQuote? quote;

  /// Fast-foods proches proposés en cas de distance supérieure à 5 km.
  final List<NearbyRestaurant> nearbyFastFoods;

  /// Erreur de localisation éventuelle.
  final Failure? failure;

  /// `true` dès qu'un devis exploitable a été calculé.
  bool get hasQuote => status == DeliveryStatus.ready && quote != null;

  /// Vérifie que l'état correspond encore à la fiche affichée.
  bool matchesTarget({
    required String id,
    required GeoPoint destinationPoint,
    required bool available,
  }) {
    return targetId == id &&
        destination == destinationPoint &&
        deliveryAvailable == available;
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    targetId,
    targetLabel,
    destination,
    deliveryAvailable,
    quote,
    nearbyFastFoods,
    failure,
  ];
}

/// Cubit du panneau de livraison, créé par écran.
final class DeliveryCubit extends Cubit<DeliveryState> {
  /// Injecte le GPS, les calculs métier et le catalogue local.
  DeliveryCubit(
    this._locationService,
    this._quoteDelivery,
    this._findNearbyFastFoods,
    this._getRestaurants,
  ) : super(const DeliveryState());

  /// Service de localisation locale.
  final LocationService _locationService;

  /// Calcul du tarif.
  final QuoteDelivery _quoteDelivery;

  /// Sélection des fast-foods proches.
  final FindNearbyFastFoods _findNearbyFastFoods;

  /// Catalogue local (donne les fast-foods de l'annuaire).
  final GetRestaurants _getRestaurants;

  /// Demande la position puis calcule le devis et les suggestions pour [id].
  ///
  /// Tous les paramètres sont explicites : le widget reste une simple vue et
  /// deux fiches différentes ne peuvent pas partager un devis périmé.
  Future<void> requestLocation({
    required String id,
    required String label,
    required GeoPoint destination,
    required bool deliveryAvailable,
  }) async {
    emit(
      DeliveryState(
        status: DeliveryStatus.requesting,
        targetId: id,
        targetLabel: label,
        destination: destination,
        deliveryAvailable: deliveryAvailable,
      ),
    );

    // 1. Position locale (jamais transmise à un serveur).
    final Either<Failure, GeoPoint> result = await _locationService
        .currentPosition();
    await result.fold(
      (Failure failure) async {
        emit(
          DeliveryState(
            status: DeliveryStatus.failure,
            targetId: id,
            targetLabel: label,
            destination: destination,
            deliveryAvailable: deliveryAvailable,
            failure: failure,
          ),
        );
      },
      (GeoPoint origin) async {
        // 2. Devis métier (500 FCFA + 200 FCFA/km, max 5 km).
        final DeliveryQuote quote =
            _quoteDelivery(
              origin: origin,
              destination: destination,
              deliveryAvailable: deliveryAvailable,
            ).getOrElse(
              (Failure _) => const DeliveryQuote.unavailable(
                distanceKm: 0,
                reason: 'Position GPS invalide.',
              ),
            );

        // 3. Catalogue local : en cas d'échec, on affiche quand même le devis.
        final List<Restaurant> restaurants =
            await _getRestaurants(const GetRestaurantsParams()).then(
              (Either<Failure, List<Restaurant>> result) =>
                  result.getOrElse((Failure _) => const <Restaurant>[]),
            );

        // 4. Hors zone : fast-foods proches triés par distance croissante.
        final List<NearbyRestaurant> nearby =
            quote.isAvailable || !deliveryAvailable
            ? const <NearbyRestaurant>[]
            : _findNearbyFastFoods(
                origin: origin,
                restaurants: restaurants,
                excludeId: id,
              );

        emit(
          DeliveryState(
            status: DeliveryStatus.ready,
            targetId: id,
            targetLabel: label,
            destination: destination,
            deliveryAvailable: deliveryAvailable,
            quote: quote,
            nearbyFastFoods: nearby,
          ),
        );
      },
    );
  }
}
