import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/pricing/city_model.dart';
import '../models/pricing/zone_model.dart';
import '../models/pricing/vehicle_model.dart';
import '../models/pricing/route_model.dart';
import '../utils/zone_helper.dart';

class FirebasePricingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Caching mechanism
  static List<CityModel>? _cachedCities;
  static final Map<String, List<ZoneModel>> _cachedZonesByCity = {};
  static final Map<String, List<RouteModel>> _cachedRoutesByQuery = {};

  /// Fetches all cities from the `cities` collection.
  Future<List<CityModel>> fetchCities() async {
    if (_cachedCities != null) return _cachedCities!;

    try {
      final snapshot = await _firestore.collection('cities').get();
      _cachedCities = snapshot.docs.map((doc) {
        final data = doc.data();
        return CityModel(
          id: (data['id'] ?? data['_id'] ?? doc.id).toString(),
          nameEn: (data['name_en'] ?? data['nameEn'] ?? data['name'] ?? '')
              .toString(),
          nameAr: (data['name_ar'] ?? data['nameAr'] ?? '').toString(),
        );
      }).toList();
      return _cachedCities!;
    } catch (e) {
      return [];
    }
  }

  /// Fetches zones for a specific city.
  Future<List<ZoneModel>> fetchZones(String cityId) async {
    if (_cachedZonesByCity.containsKey(cityId))
      return _cachedZonesByCity[cityId]!;

    try {
      final snapshot = await _firestore
          .collection('zones')
          .where('city_id', isEqualTo: cityId)
          .get();
      final zones = snapshot.docs.map((doc) {
        final data = doc.data();
        if (data['id'] == null) data['id'] = doc.id;
        return ZoneModel.fromJson(data);
      }).toList();
      _cachedZonesByCity[cityId] = zones;
      return zones;
    } catch (e) {
      return [];
    }
  }

  /// Fetches routes for a specific vehicle and city combination.
  /// Modified to handle bidirectional fetching if needed or called by getPrice.
  Future<List<RouteModel>> fetchRoutes(
    String vehicleId,
    String fromCityId,
    String toCityId,
  ) async {
    String queryKey = "${vehicleId}_${fromCityId}_${toCityId}";
    if (_cachedRoutesByQuery.containsKey(queryKey))
      return _cachedRoutesByQuery[queryKey]!;

    try {
      final snapshot = await _firestore
          .collection('routes')
          .where('active', isEqualTo: true)
          .where('vehicle_id', isEqualTo: vehicleId)
          .where('from_city_id', isEqualTo: fromCityId)
          .where('to_city_id', isEqualTo: toCityId)
          .get();
      final routes = snapshot.docs.map((doc) {
        final data = doc.data();
        if (data['id'] == null) data['id'] = doc.id;
        return RouteModel.fromJson(data);
      }).toList();
      _cachedRoutesByQuery[queryKey] = routes;
      return routes;
    } catch (e) {
      return [];
    }
  }

  /// Maps a reverse-geocoded city name to its Firestore city object.
  Future<CityModel?> findCityByName(String geocodedCityName) async {
    if (geocodedCityName.isEmpty) return null;

    final cities = await fetchCities();
    final normGeocoded = _normalizeForComparison(geocodedCityName);

    // Common Saudi city variants (lowercase normalized)
    final Map<String, List<String>> cityVariants = {
      'madinah': [
        'medina',
        'madinah',
        'al madinah',
        'al madinah al munawwarah',
        'madina',
      ],
      'makkah': ['mecca', 'makkah', 'al makkah', 'al makkah al mukarramah'],
      'jeddah': ['jeddah', 'jiddah'],
      'riyadh': ['riyadh', 'ar riyadh'],
      'dammam': ['dammam', 'ad dammam'],
      'khobar': ['khobar', 'al khobar'],
    };

    // Priority 0: Exact Document ID Match
    for (var city in cities) {
      if (city.id.toLowerCase().trim() == normGeocoded) {
        return city;
      }
    }

    // Priority 1: Exact Name Match (Normalized)
    for (var city in cities) {
      String dbEn = _normalizeForComparison(city.nameEn);
      String dbAr = _normalizeForComparison(city.nameAr);

      if (dbEn == normGeocoded || dbAr == normGeocoded) {
        return city;
      }
    }

    // Priority 2: Variant Match (Check if normGeocoded or parts of it match known variants)
    for (var cityEntry in cityVariants.entries) {
      final canonical = cityEntry.key;
      final aliases = cityEntry.value;

      bool isVariantMatch = aliases.any(
        (alias) =>
            normGeocoded == alias ||
            normGeocoded.contains(alias) ||
            alias.contains(normGeocoded),
      );

      if (isVariantMatch) {
        // Find the city in DB that matches the canonical name or has a matching ID
        for (var city in cities) {
          if (city.id.toLowerCase() == canonical ||
              _normalizeForComparison(city.nameEn) == canonical) {
            return city;
          }
        }
      }
    }

    // Priority 3: Contains Match (Fallback)
    for (var city in cities) {
      String dbEn = _normalizeForComparison(city.nameEn);
      String dbAr = _normalizeForComparison(city.nameAr);

      if (dbEn.isNotEmpty && normGeocoded.contains(dbEn)) {
        return city;
      }
      if (dbAr.isNotEmpty && normGeocoded.contains(dbAr)) {
        return city;
      }
    }

    return null;
  }

  /// Normalizes strings for resilient comparison, especially for Arabic characters.
  String _normalizeForComparison(String text, {bool stripAllSpaces = false}) {
    String normalized = text.toLowerCase().trim();

    // Arabic Character Normalization (e.g., Alef variations, Teh Marbuta)
    normalized = normalized.replaceAll(RegExp('[أإآ]'), 'ا');
    normalized = normalized.replaceAll('ة', 'ه');
    normalized = normalized.replaceAll('ى', 'ي');

    // Improved "Al-" (ال) prefix removal
    // We remove "ال" if it's at the start of the string OR preceded by a space
    normalized = normalized.replaceAll(RegExp('(^|\\s)ال'), '');

    // Remove punctuation
    normalized = normalized.replaceAll(RegExp('[^\\u0621-\\u064A\\s\\w]'), ' ');

    // Handle spaces
    if (stripAllSpaces) {
      normalized = normalized.replaceAll(RegExp('\\s+'), '');
    } else {
      normalized = normalized.replaceAll(RegExp('\\s+'), ' ');
    }

    return normalized.trim();
  }

  /// Pricing Engine Implementation
  /// Orchestrates city/zone detection and route matching with bidirectional support.
  Future<double?> getPrice({
    required LatLng pickup,
    required LatLng drop,
    required String pickupCityName,
    required String dropCityName,
    required String vehicleId,
  }) async {
    // 1. Detect Pickup & Drop Cities
    final pickupCity = await findCityByName(pickupCityName);
    final dropCity = await findCityByName(dropCityName);

    if (pickupCity == null || dropCity == null) {
      return null;
    }

    // 2. Detect Pickup & Drop Zones
    List<ZoneModel> pickupZones = await fetchZones(pickupCity.id);
    List<ZoneModel> dropZones = await fetchZones(dropCity.id);

    ZoneModel? pZone = ZoneHelper.detectZone(pickup, pickupZones);
    ZoneModel? dZone = ZoneHelper.detectZone(drop, dropZones);

    String? pZoneId = pZone?.id;
    String? dZoneId = dZone?.id;

    // 3. Fetch routes for both directions (Bidirectional Support)
    // We want all routes between these two cities for this vehicle

    List<RouteModel> availableRoutes = [];
    availableRoutes.addAll(
      await fetchRoutes(vehicleId, pickupCity.id, dropCity.id),
    );

    // Only fetch reverse if cities are different to avoid duplicate fetching for same-city zones
    if (pickupCity.id != dropCity.id) {
      final reverseRoutes = await fetchRoutes(
        vehicleId,
        dropCity.id,
        pickupCity.id,
      );
      availableRoutes.addAll(reverseRoutes);
    }

    if (availableRoutes.isEmpty) {
      return null;
    }

    // 4. Match using Matching Logic priorities (Bidirectional)

    // 5. Ranking Match Priorities (Direct & Reversed)
    // Level 1: Exact Zone-to-Zone Match
    // Level 2: City-Level Match (No Zones in Route Document)
    // Level 3: Broad Intra-City Fallback (If same city, and ANY route exists for that city)

    // Priority 1: Exact Match
    RouteModel? match = availableRoutes.cast<RouteModel?>().firstWhere(
      (r) =>
          ((r!.fromCityId == pickupCity.id &&
              r.toCityId == dropCity.id &&
              r.fromZoneId == pZoneId &&
              r.toZoneId == dZoneId) ||
          (r.fromCityId == dropCity.id &&
              r.toCityId == pickupCity.id &&
              r.fromZoneId == dZoneId &&
              r.toZoneId == pZoneId)),
      orElse: () => null,
    );

    // Priority 2: City-Level Fallback (No zones defined in document)
    if (match == null) {
      match = availableRoutes.cast<RouteModel?>().firstWhere(
        (r) =>
            ((r!.fromCityId == pickupCity.id &&
                r.toCityId == dropCity.id &&
                (r.fromZoneId == null || r.fromZoneId!.isEmpty) &&
                (r.toZoneId == null || r.toZoneId!.isEmpty)) ||
            (r.fromCityId == dropCity.id &&
                r.toCityId == pickupCity.id &&
                (r.fromZoneId == null || r.fromZoneId!.isEmpty) &&
                (r.toZoneId == null || r.toZoneId!.isEmpty))),
        orElse: () => null,
      );
    }

    // Priority 3: Broad Intra-City Fallback (Same city, any available internal route)
    if (match == null && pickupCity.id == dropCity.id) {
      match = availableRoutes.cast<RouteModel?>().firstWhere(
        (r) => (r!.fromCityId == pickupCity.id && r.toCityId == pickupCity.id),
        orElse: () => null,
      );
    }

    if (match == null) {
      return null;
    }

    return match.price;
  }

  // Admin CRUD operations (Simplified for use in the Flutter Admin pages)
  Future<void> addCity(CityModel city) =>
      _firestore.collection('cities').doc(city.id).set(city.toJson());
  Future<void> addZone(ZoneModel zone) =>
      _firestore.collection('zones').doc(zone.id).set(zone.toJson());
  Future<void> addVehicle(PricingVehicleModel vehicle) =>
      _firestore.collection('vehicles').doc(vehicle.id).set(vehicle.toJson());
  Future<void> addRoute(RouteModel route) {
    // Unique ID for route (deterministic for simplicity if possible, or auto-id)
    return _firestore.collection('routes').add(route.toJson());
  }

  Future<List<PricingVehicleModel>> fetchVehicles() async {
    final snapshot = await _firestore.collection('vehicles').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      if (data['id'] == null) data['id'] = doc.id;
      return PricingVehicleModel.fromJson(data);
    }).toList();
  }

  void clearCache() {
    _cachedCities = null;
    _cachedZonesByCity.clear();
    _cachedRoutesByQuery.clear();
  }
}
