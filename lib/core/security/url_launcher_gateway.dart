// =============================================================================
// Passerelle d'ouverture de liens externes.
// -----------------------------------------------------------------------------
// Cette abstraction isole `url_launcher` pour deux raisons :
//   1. testabilité : un fake permet de vérifier les URI sans lancer d'app ;
//   2. maîtrise : `UrlGuard` décide, la passerelle exécute, rien d'autre.
// =============================================================================

// Plugin officiel d'ouverture d'URL, téléphone, carte, etc.
import 'package:url_launcher/url_launcher.dart';

/// Contrat minimal utilisé par `UrlGuard`.
abstract interface class UrlLauncherGateway {
  /// Vérifie qu'une application peut traiter l'URI sur cet appareil.
  Future<bool> canLaunch(Uri uri);

  /// Lance l'URI dans l'application externe appropriée.
  Future<bool> launch(Uri uri);
}

/// Implémentation réelle basée sur `url_launcher`.
final class PluginUrlLauncherGateway implements UrlLauncherGateway {
  /// Constructeur constant : aucun état à conserver.
  const PluginUrlLauncherGateway();

  /// Délègue la vérification au plugin natif.
  @override
  Future<bool> canLaunch(Uri uri) {
    // `canLaunchUrl` ne déclenche aucune navigation.
    return canLaunchUrl(uri);
  }

  /// Ouvre le lien dans l'application externe (jamais dans un WebView intégré).
  /// `externalApplication` évite qu'un navigateur embarqué ne masque l'URL réelle.
  @override
  Future<bool> launch(Uri uri) {
    // Le mode externe permet aussi la main levée vers WhatsApp / Téléphone / Maps.
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
