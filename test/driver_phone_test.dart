import 'package:flutter_test/flutter_test.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';

DriverV2 driver({String? countryCode, String? phone}) =>
    DriverV2(id: 'd1', countryCode: countryCode, phone: phone);

void main() {
  group('DriverV2.fullPhone', () {
    test('joins the prefix onto the number', () {
      expect(
        driver(countryCode: '+91', phone: '9847801552').fullPhone,
        '+919847801552',
      );
    });

    test('adds the missing plus when the payload omits it', () {
      expect(
        driver(countryCode: '91', phone: '9847801552').fullPhone,
        '+919847801552',
      );
    });

    test('leaves an already qualified number alone', () {
      expect(
        driver(countryCode: '+91', phone: '+919847801552').fullPhone,
        '+919847801552',
      );
    });

    test('does not repeat a prefix the number already carries', () {
      expect(
        driver(countryCode: '+91', phone: '919847801552').fullPhone,
        '+919847801552',
      );
    });

    test('falls back to the bare number when there is no prefix', () {
      expect(driver(phone: '9847801552').fullPhone, '9847801552');
      expect(driver(countryCode: '  ', phone: '9847801552').fullPhone,
          '9847801552');
    });

    test('is null when there is no number to call', () {
      expect(driver(countryCode: '+91').fullPhone, isNull);
      expect(driver(countryCode: '+91', phone: '   ').fullPhone, isNull);
    });

    test('reads countryCode off the payload', () {
      final parsed = DriverV2.fromJson(const {
        '_id': '6a43a5bdf65ad45abff851e4',
        'name': 'Test Driver',
        'countryCode': '+91',
        'phone': '9847801552',
        'rating': 4,
      });
      expect(parsed.countryCode, '+91');
      expect(parsed.phone, '9847801552');
      expect(parsed.fullPhone, '+919847801552');
    });
  });
}
