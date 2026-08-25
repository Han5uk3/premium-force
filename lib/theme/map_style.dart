import 'package:flutter/material.dart';

/// Which of the two map skins the tracking map is wearing.
///
/// Deliberately its own type rather than a reuse of [Brightness]: the map's
/// brightness is a separate, separately-persisted choice from the app's, and
/// keeping the types apart stops the two being passed to each other by
/// accident.
enum MapSkin {
  light,
  dark;

  bool get isDark => this == MapSkin.dark;

  /// The skin matching an app [Brightness] — what "match the app" resolves to.
  static MapSkin forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? MapSkin.dark : MapSkin.light;
}

/// The two Google Maps styles the tracking and picker maps run on, plus the
/// few colours that have to be drawn *over* them.
///
/// A map is not part of the widget tree we colour, so it cannot read
/// [AppPalette] — Google styles it from a JSON string handed to
/// [GoogleMap.style]. These are those strings, tuned for the one job the map
/// does here: carrying a route line, two pins and a car, legibly.
///
/// Both styles drop business POIs and transit. On a screen whose whole purpose
/// is "where is my driver", a field of restaurant pins is noise competing with
/// the one marker that matters.
abstract final class MapStyle {
  /// Warm, low-noise daylight map.
  ///
  /// Roads are pure white against an ivory ground — the same ivory the light
  /// app is built on — so the dark route line reads as the strongest thing on
  /// screen. Highways carry the brand's bronze in their labels.
  static const String light = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#f6f3ee"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#6b645c"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#fbf9f6"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#dcd5cb"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#3f3a34"}]},
  {"featureType": "administrative.neighborhood", "stylers": [{"visibility": "off"}]},
  {"featureType": "landscape.man_made", "elementType": "geometry", "stylers": [{"color": "#efeae2"}]},
  {"featureType": "poi", "elementType": "labels.text", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.business", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#e3ecdd"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#e6dfd5"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8b837a"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#fdf2e0"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#ecd8b6"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#8c5a1e"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#d7e4ec"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#8095a5"}]}
]
''';

  /// Warm charcoal night map.
  ///
  /// Deliberately *not* the near-black night style this screen once carried,
  /// which buried the route and the pins in an unreadable ground. The land sits
  /// at 0xFF1D1B19 and every road class is stepped up from there, so a pale
  /// route line, a gold pin and the car all stay separable from the map they
  /// are drawn on.
  static const String dark = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1d1b19"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#a29b93"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#131211"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#3b3630"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#d5cec6"}]},
  {"featureType": "administrative.neighborhood", "stylers": [{"visibility": "off"}]},
  {"featureType": "landscape.man_made", "elementType": "geometry", "stylers": [{"color": "#232120"}]},
  {"featureType": "poi", "elementType": "labels.text", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.business", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#1b2419"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#33302c"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#413d38"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9b948c"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#3d3934"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#4c443b"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#5e5348"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#d3b78c"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#101820"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#55626e"}]}
]
''';

  /// The style string for [skin].
  static String forSkin(MapSkin skin) => skin.isDark ? dark : light;

  // ---------------------------------------------------------------------------
  // What gets drawn on top of the map
  // ---------------------------------------------------------------------------

  /// The route line.
  ///
  /// It is drawn over Google's tiles, not over an app surface, so it takes its
  /// colour from the *map's* skin rather than the app's palette. Near-black on
  /// the day map, near-white on the night one: on both it is the highest
  /// contrast thing on screen, which is what a route should be.
  static Color routeLine(MapSkin skin) =>
      skin.isDark ? const Color(0xFFF2E7D8) : const Color(0xFF101010);

  /// The route line's casing, drawn underneath and slightly wider so the line
  /// keeps its edge where it crosses a road of similar tone.
  static Color routeLineCasing(MapSkin skin) =>
      skin.isDark ? const Color(0xB3000000) : const Color(0x66FFFFFF);

  /// Fill for a control floating on the map — the recentre pill, the locate
  /// button, the day/night switch.
  ///
  /// Set against the *map*, not the app: a control has to be readable on the
  /// tiles it sits on, so it inverts with the skin rather than with the theme.
  static Color controlSurface(MapSkin skin) =>
      skin.isDark ? const Color(0xFFF7F5F2) : const Color(0xFF1E1E1E);

  /// Ink for whatever is drawn on [controlSurface] — icons, labels, and the app
  /// bar's title and back arrow, which sit straight on the tiles.
  static Color onControlSurface(MapSkin skin) =>
      skin.isDark ? const Color(0xFF1B1917) : const Color(0xFFFFFFFF);

  /// The tiles' own ground colour, used by the skeleton that stands in for the
  /// map before it loads, so the real map fading in has nothing to travel.
  static Color ground(MapSkin skin) =>
      skin.isDark ? const Color(0xFF1D1B19) : const Color(0xFFE8EAED);

  /// The skeleton's shimmer highlight, a step up from [ground].
  static Color groundHighlight(MapSkin skin) =>
      skin.isDark ? const Color(0xFF2A2724) : const Color(0xFFF6F7F9);

  /// The colour the skeleton draws its stand-in streets in — the same relation
  /// to [ground] that a real road has to the land around it.
  static Color skeletonStreet(MapSkin skin) =>
      skin.isDark ? const Color(0xFF3A3733) : const Color(0xFFFFFFFF);
}
