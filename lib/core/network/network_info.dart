// =============================================================================
// Surveillance de la connectivité réseau.
// -----------------------------------------------------------------------------
// L'application est « offline-first » : elle doit pouvoir répondre uniquement
// avec le cache. Ce service indique si une tentative réseau a une chance
// d'aboutir ; il ne prouve PAS l'accès réel à Internet (portail captif, DNS).
// =============================================================================

// Plugin officiel de détection des interfaces réseau.
import 'package:connectivity_plus/connectivity_plus.dart';

/// Contrat consommé par les repositories et les BLoC.
/// L'abstraction permet de remplacer le plugin par un fake dans les tests.
abstract interface class NetworkInfo {
  /// Vérifie l'état courant des interfaces réseau.
  Future<bool> get isConnected;

  /// Flux d'états : `true` dès qu'une interface utilisable apparaît.
  Stream<bool> get onConnectivityChanged;
}

/// Implémentation réelle basée sur `connectivity_plus`.
final class ConnectivityNetworkInfo implements NetworkInfo {
  /// Injection optionnelle du plugin pour faciliter les tests et le mock.
  ConnectivityNetworkInfo({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  // Instance du plugin, jamais exposée à l'extérieur.
  final Connectivity _connectivity;

  /// Convertit la liste renvoyée par le plugin en booléen métier.
  /// Une liste peut contenir plusieurs interfaces (Wi-Fi + mobile) ou `none`.
  bool _hasUsableInterface(List<ConnectivityResult> results) {
    // `any` suffit : une seule interface non nulle rend le réseau potentiellement
    // disponible. On exclut explicitement `none` et les listes vides.
    return results.any(
      (ConnectivityResult result) => result != ConnectivityResult.none,
    );
  }

  /// Interrogation ponctuelle de la connectivité.
  @override
  Future<bool> get isConnected async {
    // `checkConnectivity` renvoie désormais toujours une liste.
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();

    // Application de la règle métier commune.
    return _hasUsableInterface(results);
  }

  /// Diffusion des changements, filtrée pour éviter les doublons.
  @override
  Stream<bool> get onConnectivityChanged {
    // `distinct` évite de reconstruire l'UI pour un état identique.
    return _connectivity.onConnectivityChanged
        .map(_hasUsableInterface)
        .distinct();
  }
}
