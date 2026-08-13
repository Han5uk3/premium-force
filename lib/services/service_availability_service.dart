import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/booking_api_v2.dart';
import 'package:premium_force_main/models/v2/booking_service_type.dart';
import 'package:premium_force_main/models/v2/geo_models.dart';

/// Verdict for a single picked location.
class LocationAvailability {
  const LocationAvailability({
    required this.isAvailable,
    this.message,
    this.city,
    this.zone,
  });

  /// Whether the location may be used for the requested service.
  final bool isAvailable;

  /// Reason to show the user when [isAvailable] is false.
  final String? message;

  final ResolvedCity? city;

  /// Only populated for zone-gated services (private transfer).
  final ResolvedZone? zone;

  String? get cityId => city?.cityId;
  String? get zoneId => zone?.zoneId;
}

/// Verdict for a private-transfer route, where both endpoints must qualify.
class RouteAvailability {
  const RouteAvailability({
    required this.isAvailable,
    required this.pickup,
    required this.dropOff,
    this.message,
  });

  final bool isAvailable;
  final LocationAvailability pickup;
  final LocationAvailability dropOff;
  final String? message;
}

/// Checks whether a picked coordinate is inside the serviced area.
///
/// Two independent gates, both decided by the backend:
///
/// * **City** — every selected location, for every service, must resolve to a
///   serviced city via `POST /geo/resolve-city`.
/// * **Zone** — private transfer additionally requires the point to fall inside
///   an active transfer zone configured in the admin panel, via
///   `POST /resolve-zone`.
///
/// Running these at pick time means an unsupported address is rejected while the
/// user is still on the map, instead of failing later on session init. The
/// backend re-validates on init regardless; this is a UX fast-path, not the
/// authority.
///
/// Usage:
/// ```dart
/// final result = await ServiceAvailabilityService().checkLocation(
///   lat: lat, lng: lng, serviceType: BookingServiceType.privateTransfer,
/// );
/// if (!result.isAvailable) showError(result.message);
/// ```
class ServiceAvailabilityService {
  static final ServiceAvailabilityService _instance =
      ServiceAvailabilityService._internal();
  factory ServiceAvailabilityService() => _instance;
  ServiceAvailabilityService._internal();

  final BookingApiV2 _api = BookingApiV2();

  /// Resolution results keyed by rounded coordinate.
  ///
  /// The location picker re-checks the same point as the user pans and
  /// confirms, so results are memoised for the life of the session.
  final Map<String, ResolvedCity> _cityCache = {};
  final Map<String, ResolvedZone> _zoneCache = {};

  static const String _defaultCityFailure =
      'We do not currently operate in this area. Please choose another location.';
  static const String _defaultZoneFailure =
      'This location is outside our supported transfer zones. Please choose another location.';

  /// Cache key at ~11 m precision — finer than any zone boundary matters.
  String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

  /// Check one location for [serviceType].
  ///
  /// Resolves the city always, and the zone as well when the service is
  /// zone-gated. Both must succeed for [LocationAvailability.isAvailable].
  Future<LocationAvailability> checkLocation({
    required double lat,
    required double lng,
    required BookingServiceType serviceType,
  }) async {
    final needsZone = serviceType.requiresZoneResolution;

    // Both lookups are independent, so run them together rather than in series.
    final results = await Future.wait([
      _resolveCity(lat, lng),
      if (needsZone) _resolveZone(lat, lng),
    ]);

    final city = results[0] as ResolvedCity?;
    final zone = needsZone && results.length > 1
        ? results[1] as ResolvedZone?
        : null;

    // A null result means the lookup itself failed (offline, server error).
    // Let it through: the backend re-validates on session init, and blocking
    // the user on a transient network fault would be worse than a late error.
    if (city == null) {
      debugPrint('📍 Availability │ City lookup unavailable — allowing');
      return const LocationAvailability(isAvailable: true);
    }

    if (!city.isServiceable) {
      debugPrint(
        '📍 Availability │ ($lat, $lng) rejected: outside serviced cities',
      );
      return LocationAvailability(
        isAvailable: false,
        message: city.message ?? _defaultCityFailure,
        city: city,
      );
    }

    if (needsZone) {
      if (zone == null) {
        debugPrint('📍 Availability │ Zone lookup unavailable — allowing');
        return LocationAvailability(isAvailable: true, city: city);
      }
      if (!zone.isServiceable) {
        debugPrint(
          '📍 Availability │ ($lat, $lng) rejected: outside transfer zones',
        );
        return LocationAvailability(
          isAvailable: false,
          message: zone.message ?? _defaultZoneFailure,
          city: city,
          zone: zone,
        );
      }
    }

    debugPrint(
      '📍 Availability │ ($lat, $lng) accepted: city=${city.cityName}'
      '${zone == null ? '' : ' zone=${zone.zoneName}'}',
    );
    return LocationAvailability(isAvailable: true, city: city, zone: zone);
  }

  /// Check both ends of a private transfer.
  ///
  /// Both endpoints must resolve to a serviced city *and* an active zone; the
  /// returned [RouteAvailability.message] names whichever end failed.
  Future<RouteAvailability> checkPrivateTransferRoute({
    required double pickupLat,
    required double pickupLng,
    required double dropOffLat,
    required double dropOffLng,
  }) async {
    const serviceType = BookingServiceType.privateTransfer;

    final checks = await Future.wait([
      checkLocation(lat: pickupLat, lng: pickupLng, serviceType: serviceType),
      checkLocation(lat: dropOffLat, lng: dropOffLng, serviceType: serviceType),
    ]);

    final pickup = checks[0];
    final dropOff = checks[1];

    String? message;
    if (!pickup.isAvailable) {
      message = 'Pickup: ${pickup.message ?? _defaultZoneFailure}';
    } else if (!dropOff.isAvailable) {
      message = 'Drop-off: ${dropOff.message ?? _defaultZoneFailure}';
    }

    return RouteAvailability(
      isAvailable: pickup.isAvailable && dropOff.isAvailable,
      pickup: pickup,
      dropOff: dropOff,
      message: message,
    );
  }

  /// Resolve a city, returning `null` when the lookup could not be performed.
  Future<ResolvedCity?> _resolveCity(double lat, double lng) async {
    final key = _key(lat, lng);
    final cached = _cityCache[key];
    if (cached != null) return cached;

    final result = await _api.resolveCity(lat: lat, lng: lng);
    final city = result.data;
    if (city != null) _cityCache[key] = city;
    return city;
  }

  /// Resolve a zone, returning `null` when the lookup could not be performed.
  Future<ResolvedZone?> _resolveZone(double lat, double lng) async {
    final key = _key(lat, lng);
    final cached = _zoneCache[key];
    if (cached != null) return cached;

    final result = await _api.resolveZone(lat: lat, lng: lng);
    final zone = result.data;
    if (zone != null) _zoneCache[key] = zone;
    return zone;
  }

  /// Drop memoised results — call when the serviced areas may have changed.
  void clearCache() {
    _cityCache.clear();
    _zoneCache.clear();
  }
}
