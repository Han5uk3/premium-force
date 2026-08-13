import 'package:premium_force_main/utils/json_utils.dart';

/// Models for `GET /bookings/session/vehicles`.
///
/// The endpoint returns only the vehicles the session's route supports, along
/// with the classes and brands needed to drive the pickers. It carries no
/// prices: the fare is decided at checkout, so nothing here is a fare and the
/// client never derives one.
///
/// Parsing accepts both a bare array and an object wrapper, and tolerates
/// category/brand arriving either as populated sub-documents or as flat
/// id/name pairs.

/// A simple `{id, name, nameAr}` reference, used for categories and brands.
class VehicleTaxonomy {
  const VehicleTaxonomy({
    required this.id,
    required this.name,
    this.nameAr,
    this.icon,
  });

  final String id;
  final String name;
  final String? nameAr;

  /// Logo URL. Brands carry one; categories generally send `null`.
  final String? icon;

  factory VehicleTaxonomy.fromJson(Map<String, dynamic> json) {
    return VehicleTaxonomy(
      id:
          pickId(json, const [
            '_id',
            'id',
            'categoryId',
            'brandId',
            'categoryID',
            'brandID',
          ]) ??
          '',
      name:
          pickString(json, const [
            'name',
            'categoryName',
            'brandName',
            'className',
            'title',
          ]) ??
          '',
      nameAr: pickString(json, const [
        'nameAr',
        'categoryNameAr',
        'brandNameAr',
        'name_ar',
      ]),
      icon: pickString(json, const ['icon', 'image', 'logo', 'iconUrl']),
    );
  }

  String displayName(bool isArabic) =>
      isArabic ? (nameAr?.trim().isNotEmpty == true ? nameAr! : name) : name;

  @override
  bool operator ==(Object other) =>
      other is VehicleTaxonomy && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// A bookable vehicle with its fare for the current session's route.
class AvailableVehicle {
  const AvailableVehicle({
    required this.vehicleId,
    required this.name,
    this.model,
    this.image,
    this.maxPassengers,
    this.maxLuggage,
    this.category,
    this.brand,
    this.isAvailable = true,
  });

  final String vehicleId;
  final String name;
  final String? model;
  final String? image;

  // No fare here by design: the backend prices the booking at checkout, so a
  // vehicle carries no price of its own.

  final int? maxPassengers;
  final int? maxLuggage;

  /// Vehicle class (Sedan / SUV / …) — drives the class filter.
  final VehicleTaxonomy? category;

  final VehicleTaxonomy? brand;
  final bool isAvailable;

  factory AvailableVehicle.fromJson(Map<String, dynamic> json) {
    // Category/brand may be populated objects or flat id + name fields.
    final categoryJson = pickMap(json, const ['category', 'categoryId']);
    final brandJson = pickMap(json, const ['brand', 'brandId']);

    final category = categoryJson.isNotEmpty
        ? VehicleTaxonomy.fromJson(categoryJson)
        : _flatTaxonomy(
            json,
            idKeys: const ['categoryId', 'categoryID'],
            nameKeys: const ['categoryName', 'className', 'carclass'],
            nameArKeys: const ['categoryNameAr', 'classNameAr'],
          );

    final brand = brandJson.isNotEmpty
        ? VehicleTaxonomy.fromJson(brandJson)
        : _flatTaxonomy(
            json,
            idKeys: const ['brandId', 'brandID'],
            nameKeys: const ['brandName', 'brand'],
            nameArKeys: const ['brandNameAr'],
          );

    return AvailableVehicle(
      vehicleId:
          pickId(json, const ['vehicleId', 'vehicleID', '_id', 'id']) ?? '',
      name:
          pickString(json, const ['name', 'carName', 'vehicleName', 'title']) ??
          '',
      model: pickString(json, const ['model', 'modelName', 'year']),
      image: pickString(json, const [
        'image',
        'imageUrl',
        'carImage',
        'imagePath',
      ]),
      maxPassengers: pickInt(json, const [
        'maxPassengers',
        'passengers',
        'seats',
      ]),
      maxLuggage: pickInt(json, const ['maxLuggage', 'luggage', 'bags']),
      category: category,
      brand: brand,
      // The endpoint only returns vehicles the route supports, so absence of an
      // explicit flag means available.
      isAvailable: pickBool(json, const ['isAvailable', 'available']) ?? true,
    );
  }

  /// Build a taxonomy from sibling id/name fields, returning `null` when neither
  /// is present.
  static VehicleTaxonomy? _flatTaxonomy(
    Map<String, dynamic> json, {
    required List<String> idKeys,
    required List<String> nameKeys,
    required List<String> nameArKeys,
  }) {
    final id = pickId(json, idKeys);
    final name = pickString(json, nameKeys);
    if (id == null && name == null) return null;
    return VehicleTaxonomy(
      id: id ?? name!,
      name: name ?? '',
      nameAr: pickString(json, nameArKeys),
    );
  }

  /// Label for the vehicle, e.g. `"S450 2023"`.
  String get displayName =>
      [name, model].where((p) => p?.trim().isNotEmpty == true).join(' ').trim();
}

/// The vehicle list plus the taxonomies needed for the class/brand filters.
///
/// When the backend does not send explicit `categories`/`brands` arrays they are
/// derived from the vehicles themselves, so the filter chips populate either way.
class AvailableVehiclesResponse {
  const AvailableVehiclesResponse({
    required this.vehicles,
    required this.categories,
    required this.brands,
  });

  final List<AvailableVehicle> vehicles;
  final List<VehicleTaxonomy> categories;
  final List<VehicleTaxonomy> brands;

  factory AvailableVehiclesResponse.fromJson(dynamic payload) {
    // Accepts a bare array, or an object wrapping the list under any of the
    // usual keys.
    final List<Map<String, dynamic>> vehicleJson;
    Map<String, dynamic> root = const {};

    if (payload is List) {
      vehicleJson = asMapList(payload);
    } else {
      root = asMap(payload);
      final nested = pickRaw(root, const [
        'vehicles',
        'cars',
        'data',
        'items',
        'results',
      ]);
      vehicleJson = nested is List
          ? asMapList(nested)
          // One more level of nesting: {data: {vehicles: [...]}}.
          : asMapList(
              pickRaw(asMap(nested), const ['vehicles', 'cars', 'items']),
            );
    }

    final vehicles = vehicleJson
        .map(AvailableVehicle.fromJson)
        .where((v) => v.vehicleId.isNotEmpty)
        .toList();

    final explicitCategories = pickMapList(root, const [
      'categories',
    ]).map(VehicleTaxonomy.fromJson).where((t) => t.name.isNotEmpty).toList();
    final explicitBrands = pickMapList(root, const [
      'brands',
    ]).map(VehicleTaxonomy.fromJson).where((t) => t.name.isNotEmpty).toList();

    return AvailableVehiclesResponse(
      vehicles: vehicles,
      categories: explicitCategories.isNotEmpty
          ? explicitCategories
          : _distinct(vehicles.map((v) => v.category)),
      brands: explicitBrands.isNotEmpty
          ? explicitBrands
          : _distinct(vehicles.map((v) => v.brand)),
    );
  }

  /// Collapse nullable taxonomies into a distinct, order-preserving list.
  static List<VehicleTaxonomy> _distinct(Iterable<VehicleTaxonomy?> source) {
    final seen = <String>{};
    final result = <VehicleTaxonomy>[];
    for (final item in source) {
      if (item == null || item.name.isEmpty) continue;
      if (seen.add(item.id.isNotEmpty ? item.id : item.name)) {
        result.add(item);
      }
    }
    return result;
  }

  bool get isEmpty => vehicles.isEmpty;
}
