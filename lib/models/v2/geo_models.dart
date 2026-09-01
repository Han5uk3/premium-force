import 'package:premium_force_main/utils/json_utils.dart';

/// Geography models for the v2 booking flow — cities, airports, terminals, and
/// the results of the server-side `resolve-city` / `resolve-zone` lookups.
///
/// Service availability is decided by the backend: a location is bookable only
/// if it resolves to an active city, and (for private transfer) to an active
/// transfer zone. The client no longer does point-in-polygon matching locally.

/// The key aliases `bookingBufferHours` has arrived under.
const List<String> kBookingBufferHourKeys = [
  'bookingBufferHours',
  'booking_buffer_hours',
  'bufferHours',
];

/// The booking buffer carried by a raw city map, whichever key it used.
///
/// The booking screens still pass cities around as untyped maps taken straight
/// from the API, so they cannot read [CityV2.bookingBufferHours]; this keeps
/// them from each having to know the aliases. Null means the city said nothing
/// about a buffer — which is not the same as saying there is none.
int? bookingBufferHoursOf(Map<String, dynamic> city) =>
    pickInt(city, kBookingBufferHourKeys);

/// A bookable city.
///
/// `GET /cities` may or may not nest its airports/terminals; [airports] is
/// populated when they arrive nested and stays empty otherwise, in which case
/// they are fetched separately.
class CityV2 {
  const CityV2({
    required this.id,
    required this.name,
    this.nameAr,
    this.bookingBufferHours,
    this.isActive = true,
    this.lat,
    this.lng,
    this.imageUrl,
    this.sortOrder,
    this.airports = const [],
  });

  final String id;
  final String name;
  final String? nameAr;

  /// Minimum lead time, in hours, between "now" and a valid pickup time.
  ///
  /// The backend re-validates this on session init; it is surfaced here only so
  /// the date/time picker can block obviously-invalid input before a round trip.
  final int? bookingBufferHours;

  final bool isActive;
  final double? lat;
  final double? lng;
  final String? imageUrl;
  final int? sortOrder;
  final List<AirportV2> airports;

  factory CityV2.fromJson(Map<String, dynamic> json) {
    final cityId = pickId(json, const ['_id', 'id', 'cityId', 'cityID']) ?? '';
    return CityV2(
      id: cityId,
      name: pickString(json, const ['cityName', 'name', 'city']) ?? '',
      nameAr: pickString(json, const ['cityNameAr', 'nameAr', 'name_ar']),
      bookingBufferHours: bookingBufferHoursOf(json),
      isActive: pickBool(json, const ['isActive', 'active']) ?? true,
      lat: pickDouble(json, const ['lat', 'latitude']),
      lng: pickDouble(json, const ['lng', 'long', 'longitude']),
      imageUrl: pickString(json, const ['imageUrl', 'image_url', 'image']),
      sortOrder: pickInt(json, const ['sortOrder', 'sort_order', 'order']),
      airports: pickMapList(json, const [
        'airports',
      ]).map((m) => AirportV2.fromJson(m, parentCityId: cityId)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'id': id,
      'cityName': name,
      'name': name,
      if (nameAr != null) 'cityNameAr': nameAr,
      if (nameAr != null) 'nameAr': nameAr,
      if (bookingBufferHours != null) 'bookingBufferHours': bookingBufferHours,
      'isActive': isActive,
      if (lat != null) 'lat': lat,
      if (lng != null) 'long': lng,
      if (lng != null) 'lng': lng,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imageUrl != null) 'image': imageUrl,
      if (sortOrder != null) 'sortOrder': sortOrder,
      'airports': airports.map((a) => a.toJson()).toList(),
    };
  }

  /// Localised display name — falls back to English when Arabic is absent.
  String displayName(bool isArabic) =>
      isArabic ? (nameAr?.trim().isNotEmpty == true ? nameAr! : name) : name;
}

/// An airport served by the airport-transfer product.
class AirportV2 {
  const AirportV2({
    required this.id,
    required this.name,
    this.nameAr,
    this.cityId,
    this.lat,
    this.lng,
    this.isActive = true,
    this.terminals = const [],
  });

  final String id;
  final String name;
  final String? nameAr;
  final String? cityId;
  final double? lat;
  final double? lng;
  final bool isActive;
  final List<TerminalV2> terminals;

  factory AirportV2.fromJson(
    Map<String, dynamic> json, {
    String? parentCityId,
  }) {
    final airportId =
        pickId(json, const ['_id', 'id', 'airportId', 'airportID']) ?? '';
    final cityId =
        pickId(json, const ['cityID', 'cityId', 'city']) ?? parentCityId;
    return AirportV2(
      id: airportId,
      name: pickString(json, const ['airportName', 'name']) ?? '',
      nameAr: pickString(json, const ['airportNameAr', 'nameAr', 'name_ar']),
      cityId: cityId,
      lat: pickDouble(json, const ['lat', 'latitude']),
      lng: pickDouble(json, const ['lng', 'long', 'longitude']),
      isActive: pickBool(json, const ['isActive', 'active']) ?? true,
      terminals: pickMapList(json, const [
        'terminals',
      ]).map((m) => TerminalV2.fromJson(m, parentAirportId: airportId)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'id': id,
      'airportName': name,
      'name': name,
      if (nameAr != null) 'airportNameAr': nameAr,
      if (nameAr != null) 'nameAr': nameAr,
      if (cityId != null) 'cityID': cityId,
      if (cityId != null) 'cityId': cityId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'long': lng,
      if (lng != null) 'lng': lng,
      'isActive': isActive,
      'terminals': terminals.map((t) => t.toJson()).toList(),
    };
  }

  String displayName(bool isArabic) =>
      isArabic ? (nameAr?.trim().isNotEmpty == true ? nameAr! : name) : name;
}

/// A terminal within an [AirportV2].
class TerminalV2 {
  const TerminalV2({
    required this.id,
    required this.name,
    this.nameAr,
    this.airportId,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? nameAr;
  final String? airportId;
  final bool isActive;

  factory TerminalV2.fromJson(
    Map<String, dynamic> json, {
    String? parentAirportId,
  }) {
    return TerminalV2(
      id: pickId(json, const ['_id', 'id', 'terminalId', 'terminalID']) ?? '',
      name: pickString(json, const ['terminalName', 'name']) ?? '',
      nameAr: pickString(json, const ['terminalNameAr', 'nameAr', 'name_ar']),
      airportId:
          pickId(json, const ['airportID', 'airportId', 'airport']) ??
          parentAirportId,
      isActive: pickBool(json, const ['isActive', 'active']) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'id': id,
      'terminalName': name,
      'name': name,
      if (nameAr != null) 'terminalNameAr': nameAr,
      if (nameAr != null) 'nameAr': nameAr,
      if (airportId != null) 'airportID': airportId,
      if (airportId != null) 'airportId': airportId,
      'isActive': isActive,
    };
  }

  String displayName(bool isArabic) =>
      isArabic ? (nameAr?.trim().isNotEmpty == true ? nameAr! : name) : name;
}

/// Result of `POST /geo/resolve-city` — which serviced city a coordinate falls
/// in, if any.
///
/// [isServiceable] is the gate the location picker checks before letting the
/// user continue.
class ResolvedCity {
  const ResolvedCity({
    required this.isServiceable,
    this.cityId,
    this.cityName,
    this.cityNameAr,
    this.bookingBufferHours,
    this.message,
  });

  final bool isServiceable;
  final String? cityId;
  final String? cityName;
  final String? cityNameAr;
  final int? bookingBufferHours;

  /// Server-supplied explanation when the location is not serviceable.
  final String? message;

  factory ResolvedCity.fromJson(Map<String, dynamic> json) {
    // The city may come back nested under `city`/`data`, or flattened.
    final nested = pickMap(json, const ['city', 'resolvedCity']);
    final source = nested.isNotEmpty ? nested : json;

    final cityId = pickId(source, const [
      'cityId',
      'cityID',
      'cityFromId',
      '_id',
      'id',
    ]);

    return ResolvedCity(
      // A resolved id is itself proof of serviceability; an explicit flag wins
      // when the backend sends one.
      isServiceable:
          pickBool(json, const ['isServiceable', 'serviceable', 'available']) ??
          (cityId != null && cityId.isNotEmpty),
      cityId: cityId,
      cityName: pickString(source, const ['cityName', 'name', 'cityFromName']),
      cityNameAr: pickString(source, const [
        'cityNameAr',
        'nameAr',
        'cityFromNameAr',
      ]),
      bookingBufferHours: pickInt(source, const [
        'bookingBufferHours',
        'bufferHours',
      ]),
      message: pickString(json, const ['message', 'error']),
    );
  }

  String? displayName(bool isArabic) => isArabic
      ? (cityNameAr?.trim().isNotEmpty == true ? cityNameAr : cityName)
      : cityName;
}

/// Result of `POST /resolve-zone` — which active transfer zone a coordinate
/// falls in.
///
/// Private transfer requires **both** pickup and drop-off to resolve to a zone;
/// [isServiceable] false means the point is outside every configured zone.
class ResolvedZone {
  const ResolvedZone({
    required this.isServiceable,
    this.zoneId,
    this.zoneName,
    this.zoneNameAr,
    this.cityId,
    this.cityName,
    this.message,
  });

  final bool isServiceable;
  final String? zoneId;
  final String? zoneName;
  final String? zoneNameAr;
  final String? cityId;
  final String? cityName;
  final String? message;

  factory ResolvedZone.fromJson(Map<String, dynamic> json) {
    final nested = pickMap(json, const ['zone', 'resolvedZone']);
    final source = nested.isNotEmpty ? nested : json;

    final zoneId = pickId(source, const [
      'zoneId',
      'zoneID',
      'zoneFromId',
      '_id',
      'id',
    ]);

    return ResolvedZone(
      isServiceable:
          pickBool(json, const ['isServiceable', 'serviceable', 'available']) ??
          (zoneId != null && zoneId.isNotEmpty),
      zoneId: zoneId,
      zoneName: pickString(source, const ['zoneName', 'name', 'zoneFromName']),
      zoneNameAr: pickString(source, const [
        'zoneNameAr',
        'nameAr',
        'zoneFromNameAr',
      ]),
      cityId: pickId(source, const ['cityId', 'cityID', 'city']),
      cityName: pickString(source, const ['cityName']),
      message: pickString(json, const ['message', 'error']),
    );
  }

  String? displayName(bool isArabic) => isArabic
      ? (zoneNameAr?.trim().isNotEmpty == true ? zoneNameAr : zoneName)
      : zoneName;
}
