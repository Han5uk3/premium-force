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
          nameEn: (data['name_en'] ?? data['nameEn'] ?? data['name'] ?? '').toString(),
          nameAr: (data['name_ar'] ?? data['nameAr'] ?? '').toString(),
        );
      }).toList();
      return _cachedCities!;
    } catch (e) {
      print("FirebasePricingService error: fetchCities: $e");
      return [];
    }
  }

  /// Fetches zones for a specific city.
  Future<List<ZoneModel>> fetchZones(String cityId) async {
    if (_cachedZonesByCity.containsKey(cityId)) return _cachedZonesByCity[cityId]!;

    try {
      final snapshot = await _firestore
          .collection('zones')
          .where('city_id', isEqualTo: cityId)
          .get();
      final zones = snapshot.docs.map((doc) => ZoneModel.fromJson(doc.data())).toList();
      _cachedZonesByCity[cityId] = zones;
      return zones;
    } catch (e) {
      print("FirebasePricingService error: fetchZones: $e");
      return [];
    }
  }

  /// Fetches routes for a specific vehicle and city combination.
  /// Modified to handle bidirectional fetching if needed or called by getPrice.
  Future<List<RouteModel>> fetchRoutes(String vehicleId, String fromCityId, String toCityId) async {
    String queryKey = "${vehicleId}_${fromCityId}_${toCityId}";
    if (_cachedRoutesByQuery.containsKey(queryKey)) return _cachedRoutesByQuery[queryKey]!;

    try {
      final snapshot = await _firestore
          .collection('routes')
          .where('active', isEqualTo: true)
          .where('vehicle_id', isEqualTo: vehicleId)
          .where('from_city_id', isEqualTo: fromCityId)
          .where('to_city_id', isEqualTo: toCityId)
          .get();
      final routes = snapshot.docs.map((doc) => RouteModel.fromJson(doc.data())).toList();
      _cachedRoutesByQuery[queryKey] = routes;
      return routes;
    } catch (e) {
      print("FirebasePricingService error: fetchRoutes: $e");
      return [];
    }
  }

  /// Maps a reverse-geocoded city name to its Firestore city object.
  Future<CityModel?> findCityByName(String geocodedCityName) async {
    final cities = await fetchCities();
    String normGeocoded = _normalizeForComparison(geocodedCityName);
    
    print("🌍 FirebasePricingService: Attempting to match city '$geocodedCityName' (Normalized: '$normGeocoded')");
    print("   🏙️ Cities available in cache: ${cities.length}");

    // PRIORITY 1: Exact Match
    for (var city in cities) {
      String dbEn = _normalizeForComparison(city.nameEn);
      String dbAr = _normalizeForComparison(city.nameAr);
      
      if (dbEn == normGeocoded || dbAr == normGeocoded) {
        print("✅ FirebasePricingService: Match found [Exact] -> ${city.nameEn}");
        return city;
      }
    }

    // PRIORITY 2: Geocoded name contains DB name
    for (var city in cities) {
      String dbEn = _normalizeForComparison(city.nameEn);
      String dbAr = _normalizeForComparison(city.nameAr);

      if (dbEn.isNotEmpty && normGeocoded.contains(dbEn)) {
        print("✅ FirebasePricingService: Match found [Sub-Geocode] -> ${city.nameEn} (Matches DB EN: '$dbEn')");
        return city;
      }
      if (dbAr.isNotEmpty && normGeocoded.contains(dbAr)) {
        print("✅ FirebasePricingService: Match found [Sub-Geocode] -> ${city.nameEn} (Matches DB AR: '$dbAr')");
        return city;
      }
    }

    // PRIORITY 3: DB name contains Geocoded name
    for (var city in cities) {
      String dbEn = _normalizeForComparison(city.nameEn);
      String dbAr = _normalizeForComparison(city.nameAr);

      if (normGeocoded.isNotEmpty && dbEn.contains(normGeocoded)) {
        print("✅ FirebasePricingService: Match found [Sub-DB] -> ${city.nameEn} (DB EN: '$dbEn' contains '$normGeocoded')");
        return city;
      }
      if (normGeocoded.isNotEmpty && dbAr.contains(normGeocoded)) {
        print("✅ FirebasePricingService: Match found [Sub-DB] -> ${city.nameEn} (DB AR: '$dbAr' contains '$normGeocoded')");
        return city;
      }
    }

    // PRIORITY 4: Space-insensitive Match (Ignore all spaces in both names)
    String superNormGeocoded = _normalizeForComparison(geocodedCityName, stripAllSpaces: true);
    if (superNormGeocoded.isNotEmpty) {
      for (var city in cities) {
        if (_normalizeForComparison(city.nameEn, stripAllSpaces: true) == superNormGeocoded ||
            _normalizeForComparison(city.nameAr, stripAllSpaces: true) == superNormGeocoded) {
          print("✅ FirebasePricingService: Match found [Space-Insensitive] -> ${city.nameEn}");
          return city;
        }
      }
    }

    print("⚠️ FirebasePricingService: No match found for '$geocodedCityName' among ${cities.length} cities.");
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
    CityModel? pickupCity = await findCityByName(pickupCityName);
    CityModel? dropCity = await findCityByName(dropCityName);

    if (pickupCity == null || dropCity == null) {
      print("❌ FirebasePricingService: City not matched in Firestore. (Pickup: '$pickupCityName', Drop: '$dropCityName')");
      return null;
    }

    print("🔍 FirebasePricingService: [CAT 3] Matched Cities -> P: ${pickupCity.id}, D: ${dropCity.id}");

    // 2. Detect Pickup & Drop Zones
    List<ZoneModel> pickupZones = await fetchZones(pickupCity.id);
    List<ZoneModel> dropZones = await fetchZones(dropCity.id);

    ZoneModel? pZone = ZoneHelper.detectZone(pickup, pickupZones);
    ZoneModel? dZone = ZoneHelper.detectZone(drop, dropZones);

    String? pZoneId = pZone?.id;
    String? dZoneId = dZone?.id;

    print("📍 FirebasePricingService: Detected Zones -> P: ${pZoneId ?? 'None (City Level)'}, D: ${dZoneId ?? 'None (City Level)'}");

    // 3. Fetch routes for both directions (Bidirectional Support)
    // We want all routes between these two cities for this vehicle
    print("📡 FirebasePricingService: Querying routes for Vehicle: $vehicleId between ${pickupCity.id} and ${dropCity.id}");
    
    List<RouteModel> availableRoutes = [];
    availableRoutes.addAll(await fetchRoutes(vehicleId, pickupCity.id, dropCity.id));
    
    // Only fetch reverse if cities are different to avoid duplicate fetching for same-city zones
    if (pickupCity.id != dropCity.id) {
       final reverseRoutes = await fetchRoutes(vehicleId, dropCity.id, pickupCity.id);
       availableRoutes.addAll(reverseRoutes);
    }

    if (availableRoutes.isEmpty) {
      print("⚠️ FirebasePricingService: No active routes found for this vehicle/city combination in Firestore.");
      return null;
    }

    print("✅ FirebasePricingService: Found ${availableRoutes.length} potential routes. Applying matching logic...");

    // 4. Match using Matching Logic priorities (Bidirectional)
    
    // PRIORITY 1: Exact Match (Direct: P->D)
    final directExact = availableRoutes.cast<RouteModel?>().firstWhere(
      (r) => r!.fromCityId == pickupCity.id && r.toCityId == dropCity.id &&
             r.fromZoneId == pZoneId && r.toZoneId == dZoneId,
      orElse: () => null,
    );
    if (directExact != null) {
      print("💎 FirebasePricingService: Match Found! [Exact Direct] Price: ${directExact.price}");
      return directExact.price;
    }

    // PRIORITY 1b: Exact Match (Reversed: D->P)
    final reversedExact = availableRoutes.cast<RouteModel?>().firstWhere(
      (r) => r!.fromCityId == dropCity.id && r.toCityId == pickupCity.id && 
             r.fromZoneId == dZoneId && r.toZoneId == pZoneId,
      orElse: () => null,
    );
    if (reversedExact != null) {
      print("💎 FirebasePricingService: Match Found! [Exact Reversed] Price: ${reversedExact.price}");
      return reversedExact.price;
    }

    // PRIORITY 2: Fallback Match (Direct: City P -> City D)
    final directFallback = availableRoutes.cast<RouteModel?>().firstWhere(
      (r) => r!.fromCityId == pickupCity.id && r.toCityId == dropCity.id && 
             r.fromZoneId == null && r.toZoneId == null,
      orElse: () => null,
    );
    if (directFallback != null) {
      print("💎 FirebasePricingService: Match Found! [City Fallback Direct] Price: ${directFallback.price}");
      return directFallback.price;
    }

    // PRIORITY 2b: Fallback Match (Reversed: City D -> City P)
    final reversedFallback = availableRoutes.cast<RouteModel?>().firstWhere(
      (r) => r!.fromCityId == dropCity.id && r.toCityId == pickupCity.id && 
             r.fromZoneId == null && r.toZoneId == null,
      orElse: () => null,
    );
    if (reversedFallback != null) {
      print("💎 FirebasePricingService: Match Found! [City Fallback Reversed] Price: ${reversedFallback.price}");
      return reversedFallback.price;
    }

    print("❌ FirebasePricingService: No match found among available routes.");
    return null;
  }

  // Admin CRUD operations (Simplified for use in the Flutter Admin pages)
  Future<void> addCity(CityModel city) => _firestore.collection('cities').doc(city.id).set(city.toJson());
  Future<void> addZone(ZoneModel zone) => _firestore.collection('zones').doc(zone.id).set(zone.toJson());
  Future<void> addVehicle(PricingVehicleModel vehicle) => _firestore.collection('vehicles').doc(vehicle.id).set(vehicle.toJson());
  Future<void> addRoute(RouteModel route) {
    // Unique ID for route (deterministic for simplicity if possible, or auto-id)
    return _firestore.collection('routes').add(route.toJson());
  }

  Future<List<PricingVehicleModel>> fetchVehicles() async {
    final snapshot = await _firestore.collection('vehicles').get();
    return snapshot.docs.map((doc) => PricingVehicleModel.fromJson(doc.data())).toList();
  }

  void clearCache() {
    _cachedCities = null;
    _cachedZonesByCity.clear();
    _cachedRoutesByQuery.clear();
  }
}
