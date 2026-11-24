// =============================================================================
// Retour utilisateur après l'ouverture d'un lien externe.
// -----------------------------------------------------------------------------
// Ouvrir WhatsApp, le composeur téléphonique ou Google Maps est une opération
// asynchrone qui peut échouer (application absente, lien refusé par le garde-fou
// de sécurité). Ce helper centralise l'attente, la capture du `ScaffoldMessenger`
// AVANT l'appel asynchrone (pour respecter `use_build_context_synchronously`) et
// l'affichage d'un message clair.
// =============================================================================

// Widgets, Material et messagerie.
import 'package:flutter/material.dart';

// Type fonctionnel : aucun exception ne traverse la Présentation.
import 'package:fpdart/fpdart.dart';

// Erreur métier éventuelle.
import '../../../../core/error/failures.dart';

/// Utilitaires d'affichage du résultat d'un lien externe.
final class LinkFeedback {
  // Constructeur privé : classe statique uniquement.
  const LinkFeedback._();

  /// Exécute [action] puis affiche un message (erreur métier ou succès).
  ///
  /// [successMessage] peut être `null` pour ne rien afficher en cas de succès
  /// (utile quand le système affiche déjà sa propre interface, ex. l'appel).
  static Future<void> run(
    BuildContext context,
    Future<Either<Failure, Unit>> Function() action, {
    String? successMessage,
  }) async {
    // Capture du messager AVANT tout `await` : le contexte n'est plus utilisé
    // après une opération asynchrone.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    // Exécution protégée : le garde-fou renvoie toujours un `Either`.
    final Either<Failure, Unit> result = await action();

    // Affichage du résultat, jamais d'exception remontée.
    result.fold(
      (Failure failure) =>
          messenger.showSnackBar(SnackBar(content: Text(failure.message))),
      (Unit _) {
        // Message de succès facultatif.
        final String? label = successMessage;
        if (label != null && label.isNotEmpty) {
          messenger.showSnackBar(SnackBar(content: Text(label)));
        }
      },
    );
  }
}
