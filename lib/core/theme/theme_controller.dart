// =============================================================================
// Contrôleur du thème clair / sombre.
// -----------------------------------------------------------------------------
// Un `Cubit<ThemeMode>` minuscule remplace un `setState` dans la racine : le
// mode est un état réactif partagé, modifiable depuis l'écran Paramètres et lu
// par `MaterialApp` sans reconstruire toute l'application à la main.
// =============================================================================

// `ThemeMode` provient de Material.
import 'package:flutter/material.dart';

// Cubit : état réactif minimal, sans événements.
import 'package:flutter_bloc/flutter_bloc.dart';

/// Gère le mode de thème courant.
final class ThemeController extends Cubit<ThemeMode> {
  /// Démarre en mode système : l'application suit le réglage du téléphone.
  ThemeController() : super(ThemeMode.system);

  /// Applique un mode explicite (clair, sombre ou système).
  void setMode(ThemeMode mode) => emit(mode);

  /// Bascule entre clair et sombre (le mode système est traité comme clair).
  void toggleDark() =>
      emit(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}
