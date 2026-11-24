// =============================================================================
// Message WhatsApp d'une commande (fonction pure, facile à tester).
// -----------------------------------------------------------------------------
// Le message est pré-rempli puis confié à `UrlGuard.openWhatsApp` : l'envoi
// effectif se fait dans WhatsApp, jamais depuis l'application. Le texte ne
// contient aucune coordonnée GPS : seules la distance et la tranche tarifaire
// sont partagées avec le gérant.
// =============================================================================

// Formatage localisé (FCFA, dates, distances).
import '../../../../core/utils/formatters.dart';

// Entité du devis.
import '../../domain/entities/delivery_quote.dart';

// Entité affichée.
import '../../domain/entities/restaurant.dart';

// Récapitulatif calculé à partir du panier.
import 'cart_summary.dart';

/// Construit le message envoyé au gérant via WhatsApp.
///
/// [quote] est fourni uniquement si l'utilisateur a demandé la livraison et si
/// le devis est disponible. Les montants restent des entiers en FCFA.
String buildOrderMessage({
  required Restaurant restaurant,
  required CartSummary summary,
  required DateTime now,
  DeliveryQuote? quote,
}) {
  final StringBuffer buffer = StringBuffer()
    ..writeln('Bonjour ${restaurant.name},')
    ..writeln('Je souhaite passer une commande :');

  // Détail de chaque ligne commandée.
  for (final CartLine line in summary.lines) {
    buffer.writeln(
      '• ${line.quantity} × ${line.item.name} '
      '(${AppFormatters.fcfa(line.subtotalFcfa)})',
    );
  }

  // Frais de livraison et total, sans coordonnées personnelles.
  final DeliveryQuote? delivery = quote != null && quote.isAvailable
      ? quote
      : null;
  final int deliveryFeeFcfa = delivery?.feeFcfa ?? 0;
  final int totalFcfa = summary.totalFcfa + deliveryFeeFcfa;

  buffer.writeln('');
  if (delivery != null) {
    buffer
      ..writeln(
        'Livraison demandée : ${AppFormatters.distanceKm(delivery.distanceKm)}',
      )
      ..writeln('Frais de livraison : ${AppFormatters.fcfa(deliveryFeeFcfa)}')
      ..writeln('Sous-total : ${AppFormatters.fcfa(summary.totalFcfa)}');
  }
  buffer
    ..writeln('Total : ${AppFormatters.fcfa(totalFcfa)}')
    ..writeln('Envoyé le ${AppFormatters.dateTimeFr(now)}')
    ..write('Merci de confirmer la disponibilité.');

  return buffer.toString();
}
