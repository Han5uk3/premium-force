import 'package:flutter/material.dart';

import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/theme/map_style.dart';

/// How the tracking and picker maps pick their skin.
///
/// Separate from the app's own [ThemeMode] because the two answer different
/// questions. A customer reading a light app in daylight may still want the
/// night map — the dark tiles make a gold car and a route line pop — and a
/// customer on the dark app at night may want the day map because street
/// names are easier to read on it. Tying the map to the app would take that
/// choice away.
enum MapThemePreference {
  /// Follow whichever theme the app is currently painting.
  matchApp,
  light,
  dark;

  /// Round-trips through Hive. Stored as a string rather than the enum index so
  /// reordering this enum later cannot silently repoint everyone's saved
  /// preference at a different value.
  String get storageValue => name;

  static MapThemePreference fromStorage(String? value) {
    return MapThemePreference.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => MapThemePreference.light,
    );
  }
}

/// Owns the app's appearance: which [ThemeMode] it runs in, and which skin the
/// maps wear.
///
/// Both choices are read from Hive at construction, so the very first frame is
/// already in the right mode — no flash of the wrong theme while a future
/// resolves — and written straight back on every change.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider()
    : _themeMode = _readThemeMode(),
      _mapPreference = MapThemePreference.fromStorage(
        UserLocalStorage.getMapThemePreference(),
      );

  ThemeMode _themeMode;
  MapThemePreference _mapPreference;

  /// What the app is painting: light, dark, or whatever the device asks for.
  ThemeMode get themeMode => _themeMode;

  /// What the maps are painting.
  MapThemePreference get mapPreference => _mapPreference;

  /// Whether the app is currently dark, resolving [ThemeMode.system] against
  /// the platform.
  ///
  /// Takes the brightness from [MediaQuery] rather than
  /// `PlatformDispatcher.platformBrightness` so a widget calling it also
  /// *rebuilds* when the device flips modes.
  bool isDark(BuildContext context) => switch (_themeMode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark,
  };

  /// The app's resolved brightness.
  Brightness brightness(BuildContext context) =>
      isDark(context) ? Brightness.dark : Brightness.light;

  /// The app's resolved brightness, given the platform's rather than read from
  /// a [MediaQuery].
  ///
  /// For the one caller that sits *above* [MaterialApp] and so has no
  /// MediaQuery to consult. It has to supply the platform brightness itself —
  /// and to watch for it changing, since nothing here will rebuild it.
  Brightness brightnessFrom(Brightness platformBrightness) =>
      switch (_themeMode) {
        ThemeMode.dark => Brightness.dark,
        ThemeMode.light => Brightness.light,
        ThemeMode.system => platformBrightness,
      };

  /// The skin the maps should wear right now.
  ///
  /// [appBrightness] is only consulted for [MapThemePreference.matchApp]; an
  /// explicit choice wins regardless of what the app is doing.
  MapSkin mapSkin(Brightness appBrightness) => switch (_mapPreference) {
    MapThemePreference.light => MapSkin.light,
    MapThemePreference.dark => MapSkin.dark,
    MapThemePreference.matchApp => MapSkin.forBrightness(appBrightness),
  };

  /// The map skin for [context], resolving both preferences.
  MapSkin mapSkinFor(BuildContext context) => mapSkin(brightness(context));

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await UserLocalStorage.saveThemeMode(_storageValueOf(mode));
  }

  /// Flip between light and dark.
  ///
  /// Resolves [ThemeMode.system] against what is on screen first, so the toggle
  /// always moves *away* from what the customer is looking at — from system-dark
  /// it goes light, not to an explicit dark that changes nothing visible.
  Future<void> toggleThemeMode(BuildContext context) =>
      setThemeMode(isDark(context) ? ThemeMode.light : ThemeMode.dark);

  Future<void> setMapPreference(MapThemePreference preference) async {
    if (preference == _mapPreference) return;
    _mapPreference = preference;
    notifyListeners();
    await UserLocalStorage.saveMapThemePreference(preference.storageValue);
  }

  /// Flip the map between its two skins from the map screen itself.
  ///
  /// Resolves [MapThemePreference.matchApp] first for the same reason
  /// [toggleThemeMode] does, and always lands on an explicit choice — tapping
  /// the control is the customer saying they want *this* map, whatever the app
  /// does later.
  Future<void> toggleMapSkin(Brightness appBrightness) {
    final current = mapSkin(appBrightness);
    return setMapPreference(
      current.isDark ? MapThemePreference.light : MapThemePreference.dark,
    );
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  static ThemeMode _readThemeMode() {
    switch (UserLocalStorage.getThemeMode()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        // Nothing stored: the app shipped dark and every existing customer
        // knows it that way, so an upgrade keeps the app they had rather than
        // handing them a light one because their phone happens to be in light
        // mode.
        return ThemeMode.dark;
    }
  }

  static String _storageValueOf(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}
