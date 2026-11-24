// =============================================================================
// Écran « page introuvable ».
// -----------------------------------------------------------------------------
// Le routeur redirige ici TOUTE destination non reconnue :
//   - une URL profonde forgée (`/restaurants/../../etc`) ;
//   - une route du portail gérant pas encore livrée (`/owner`, `/owner/login`) ;
//   - un lien obsolète partagé par un ancien utilisateur.
// L'écran ne consomme aucun BLoC et ne lit aucune donnée : il rassure
// l'utilisateur et lui propose un retour sûr vers l'accueil, sans jamais
// exposer de détail technique (ni chemin, ni code d'erreur).
// =============================================================================

// Widgets et Material.
import 'package:flutter/material.dart';

// Route de repli vers l'accueil.
import '../../../../core/constants/app_routes.dart';

// Vue « état vide » réutilisée pour rester cohérent avec le reste de l'app.
import '../widgets/async_state_views.dart';

/// Page affichée lorsqu'aucune route ne correspond à la destination demandée.
final class NotFoundPage extends StatelessWidget {
  /// Construit la page.
  const NotFoundPage({super.key});

  /// Construit la page.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Barre d'application minimale, sans action.
      appBar: AppBar(title: const Text('Page introuvable')),

      // Corps centré : icône, explication et retour à l'accueil.
      body: AppEmptyView(
        icon: Icons.explore_off_outlined,
        title: 'Cette page n’existe pas',
        message:
            'Le lien est peut-être incomplet ou obsolète. Revenez à l’accueil '
            'pour retrouver les restaurants de Koudougou.',
        action: FilledButton.tonalIcon(
          // Remplace TOUTE la pile : l'utilisateur repart d'un état propre,
          // même si la page introuvable était la première route (lien profond).
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.home,
            (Route<dynamic> route) => false,
          ),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Retour à l’accueil'),
        ),
      ),
    );
  }
}
