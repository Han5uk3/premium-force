import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart' as platform;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:premium_force_main/utils/screen_logger.dart';

/// Finds the coordinate for an address that arrived without one.
///
/// Bookings regularly come back with the pickup or the drop-off written out in
/// full but positioned at `0,0` — the point never made it into the payload, or
/// was saved from a place the booking flow only had text for. `0,0` is the
/// Atlantic, so the tracking screens treat it as "no coordinate": the pin is
/// skipped, the leg has no destination, and the customer is left watching a car
/// on an empty map with no route and no ETA.
///
/// The address itself is enough to recover the point, which is what this does.
/// Results are held for the life of the process, so the same address is looked
/// up once no matter how many screens ask for it — the home card and the
/// tracking page ask for the same two points, and a leg change asks again.
class AddressGeocodingService {
  factory AddressGeocodingService() => _instance;
  AddressGeocodingService._();

  static final AddressGeocodingService _instance = AddressGeocodingService._();

  static const String _log = 'geocode';

  /// Addresses already resolved. Only successes are kept: a lookup that failed
  /// on a dead connection is worth trying again, a coordinate is not.
  final Map<String, LatLng> _cache = {};

  /// Lookups in flight, keyed the same way, so two screens asking for the same
  /// address at once share one request rather than racing.
  final Map<String, Future<LatLng?>> _inFlight = {};

  /// The coordinate for [address], or null when there is nothing usable to
  /// look up or the lookup found nothing.
  Future<LatLng?> resolve(String? address) {
    final query = address?.trim() ?? '';
    if (query.isEmpty) return Future.value(null);

    final key = query.toLowerCase();
    final cached = _cache[key];
    if (cached != null) return Future.value(cached);

    final pending = _inFlight[key];
    if (pending != null) return pending;

    final lookup = _lookup(query)
        .then((result) {
          if (result != null) _cache[key] = result;
          return result;
        })
        .whenComplete(() => _inFlight.remove(key));

    _inFlight[key] = lookup;
    return lookup;
  }

  /// Ask Google for the address, then the device.
  ///
  /// Text Search is tried first because it is the same Places API the booking
  /// flow already searches with, so it resolves the same names the customer
  /// picked their address from — including places a street geocoder does not
  /// know, such as a hotel or a terminal by name. The platform geocoder is the
  /// fallback: it costs nothing and works offline of that key, but it wants a
  /// postal-style address and returns nothing for much else.
  Future<LatLng?> _lookup(String query) async {
    final viaPlaces = await _lookupWithPlaces(query);
    if (viaPlaces != null) {
      logScreen(
        _log,
        'places resolved "$query" → '
        '${viaPlaces.latitude},${viaPlaces.longitude}',
      );
      return viaPlaces;
    }

    final viaPlatform = await _lookupWithPlatform(query);
    if (viaPlatform != null) {
      logScreen(
        _log,
        'device geocoder resolved "$query" → '
        '${viaPlatform.latitude},${viaPlatform.longitude}',
      );
      return viaPlatform;
    }

    logScreen(_log, 'no coordinate found for "$query"');
    return null;
  }

  Future<LatLng?> _lookupWithPlaces(String query) async {
    final apiKey = _apiKey;
    if (apiKey.isEmpty) return null;

    try {
      final response = await Dio().post(
        'https://places.googleapis.com/v1/places:searchText',
        data: {
          'textQuery': query,
          'maxResultCount': 1,
          // The same bias the booking flow's address search uses, so an
          // ambiguous name lands on the Saudi one rather than its namesake
          // half a world away.
          'regionCode': 'SA',
          'locationBias': {
            'rectangle': {
              'low': {'latitude': 16.38, 'longitude': 34.54},
              'high': {'latitude': 32.15, 'longitude': 55.66},
            },
          },
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            // Only the point is needed, and the field mask is what the request
            // is billed on.
            'X-Goog-FieldMask': 'places.location',
          },
          connectTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          // Read 4xx bodies rather than throwing them: a rejected key and an
          // unenabled API are only distinguishable from the response.
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200) {
        final body = response.data;
        final reason = body is Map ? (body['error']?['message'] ?? body) : body;
        logScreen(_log, 'places ${response.statusCode} for "$query" — $reason');
        return null;
      }

      final places = response.data['places'];
      if (places is! List || places.isEmpty) return null;

      final location = places.first['location'];
      if (location is! Map) return null;

      return _validated(
        (location['latitude'] as num?)?.toDouble(),
        (location['longitude'] as num?)?.toDouble(),
      );
    } catch (e) {
      logScreen(_log, 'places lookup failed for "$query" — $e');
      return null;
    }
  }

  Future<LatLng?> _lookupWithPlatform(String query) async {
    try {
      final results = await platform.locationFromAddress(query);
      if (results.isEmpty) return null;
      return _validated(results.first.latitude, results.first.longitude);
    } catch (e) {
      // Thrown for "no result" as well as for a missing platform geocoder, and
      // neither is worth more than a line.
      logScreen(_log, 'device geocoder failed for "$query" — $e');
      return null;
    }
  }

  /// A point, unless it is the null island the whole exercise exists to
  /// replace.
  static LatLng? _validated(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (lat == 0 && lng == 0) return null;
    return LatLng(lat, lng);
  }

  /// The Places key, falling back the same way the booking flow's address
  /// search does.
  static String get _apiKey {
    final places = dotenv.env['GOOGLE_PLACES_API_KEY']?.trim() ?? '';
    if (places.isNotEmpty) return places;
    final maps = dotenv.env['GOOGLE_MAPS_API_KEY']?.trim() ?? '';
    if (maps.isNotEmpty) return maps;
    return dotenv.env['MAPS_API_KEY']?.trim() ?? '';
  }
}
