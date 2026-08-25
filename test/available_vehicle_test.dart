import 'package:flutter_test/flutter_test.dart';
import 'package:premium_force_main/models/v2/available_vehicle.dart';

/// The payload shape currently on the wire: top-level `categories` with no
/// Arabic name, and a nested `category` of just `{id, name}`.
Map<String, dynamic> _payload({String? categoryNameAr}) => {
  'categories': [
    {
      'id': '69c92b3955994025b73aaa71',
      'name': 'Luxury Van',
      'image': null,
      if (categoryNameAr != null) 'name_ar': categoryNameAr,
    },
  ],
  'brands': [
    {
      'id': '69ce34a2e51a0e460209ef56',
      'name': 'Toyota',
      'icon': 'https://example.com/toyota.jpg',
    },
  ],
  'vehicles': [
    {
      'vehicleId': '69ce3502e51a0e460209ef6a',
      'name': 'Hiace',
      'maxPassengers': 10,
      'category': {'id': '69c92b3955994025b73aaa71', 'name': 'Luxury Van'},
      'brand': {'id': '69ce34a2e51a0e460209ef56', 'name': 'Toyota'},
      'image': 'https://example.com/hiace.png',
    },
  ],
};

void main() {
  group('AvailableVehiclesResponse', () {
    test('parses the payload shape currently on the wire', () {
      final response = AvailableVehiclesResponse.fromJson(_payload());

      expect(response.vehicles, hasLength(1));
      expect(response.categories.single.name, 'Luxury Van');
      expect(response.vehicles.single.category?.name, 'Luxury Van');
      // No Arabic anywhere yet, so display falls back to the English name.
      expect(response.vehicles.single.category?.displayName(true), 'Luxury Van');
    });

    test('joins name_ar from the top-level categories onto each vehicle', () {
      final response = AvailableVehiclesResponse.fromJson(
        _payload(categoryNameAr: 'فان فاخرة'),
      );

      final category = response.vehicles.single.category;
      expect(category?.nameAr, 'فان فاخرة');
      expect(category?.displayName(true), 'فان فاخرة');
      // English is untouched — it stays the filter/identity key.
      expect(category?.name, 'Luxury Van');
      expect(category?.displayName(false), 'Luxury Van');
    });

    test('joins the brand icon onto the vehicle the same way', () {
      final response = AvailableVehiclesResponse.fromJson(_payload());
      expect(
        response.vehicles.single.brand?.icon,
        'https://example.com/toyota.jpg',
      );
    });

    test('a nested name_ar wins over the top-level one', () {
      final payload = _payload(categoryNameAr: 'from top level');
      (payload['vehicles'] as List).first['category'] = {
        'id': '69c92b3955994025b73aaa71',
        'name': 'Luxury Van',
        'name_ar': 'from nested',
      };

      final response = AvailableVehiclesResponse.fromJson(payload);
      expect(response.vehicles.single.category?.nameAr, 'from nested');
    });

    test('leaves vehicles alone when no top-level taxonomies are sent', () {
      final payload = _payload()..remove('categories')..remove('brands');
      final response = AvailableVehiclesResponse.fromJson(payload);

      expect(response.vehicles.single.category?.name, 'Luxury Van');
      expect(response.vehicles.single.category?.nameAr, isNull);
      // Categories are still derived from the vehicles themselves.
      expect(response.categories.single.name, 'Luxury Van');
    });

    test('an unmatched category id is left as it arrived', () {
      final payload = _payload(categoryNameAr: 'فان فاخرة');
      (payload['vehicles'] as List).first['category'] = {
        'id': 'some-other-id',
        'name': 'Luxury Bus',
      };

      final response = AvailableVehiclesResponse.fromJson(payload);
      expect(response.vehicles.single.category?.name, 'Luxury Bus');
      expect(response.vehicles.single.category?.nameAr, isNull);
    });
  });
}
