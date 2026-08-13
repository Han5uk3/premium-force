import 'package:flutter_test/flutter_test.dart';
import 'package:premium_force_main/api/api_logger.dart';

/// The confirm response carries live PayTabs credentials, so these assertions
/// guard the one logging bug that would have real consequences.
void main() {
  final logger = BookingApiLogger();

  group('credential masking', () {
    test('masks the gateway keys returned by confirm', () {
      final rendered = logger.renderForTest({
        'paymentRequired': true,
        'bookingNumber': 'PF-APT-2608-9842',
        'paytabsConfig': {
          'profileId': '109432',
          'serverKey': 'SJKNKD82SECRETVALUE',
          'clientKey': 'CKJND83SECRETVALUE',
          'cartId': 'PF-APT-2608-9842',
          'amount': 232.88,
        },
      });

      expect(rendered, isNot(contains('SJKNKD82SECRETVALUE')));
      expect(rendered, isNot(contains('CKJND83SECRETVALUE')));
      expect(rendered, isNot(contains('109432')));

      // Non-sensitive fields must survive, or the log loses its value.
      expect(rendered, contains('PF-APT-2608-9842'));
      expect(rendered, contains('232.88'));
    });

    test('masks credentials nested inside lists', () {
      final rendered = logger.renderForTest({
        'items': [
          {'serverKey': 'NESTEDSECRET'},
        ],
      });

      expect(rendered, isNot(contains('NESTEDSECRET')));
    });

    test('masks regardless of key casing or underscores', () {
      final rendered = logger.renderForTest({
        'server_key': 'SNAKECASESECRET',
        'ServerKey': 'PASCALCASESECRET',
      });

      expect(rendered, isNot(contains('SNAKECASESECRET')));
      expect(rendered, isNot(contains('PASCALCASESECRET')));
    });

    test('masks credentials inside a JSON string body', () {
      final rendered = logger.renderForTest(
        '{"serverKey":"STRINGBODYSECRET","cartId":"PF-1"}',
      );

      expect(rendered, isNot(contains('STRINGBODYSECRET')));
      expect(rendered, contains('PF-1'));
    });
  });

  group('rendering', () {
    test('keeps ordinary session payloads readable', () {
      final rendered = logger.renderForTest({
        'serviceType': 'private_transfer',
        'route': {'cityFromName': 'Riyadh'},
      });

      expect(rendered, contains('private_transfer'));
      expect(rendered, contains('Riyadh'));
    });

    test('truncates oversized bodies instead of flooding the log', () {
      final logger = BookingApiLogger(maxBodyChars: 80);
      final rendered = logger.renderForTest({
        'vehicles': List.generate(50, (i) => {'name': 'Vehicle $i'}),
      });

      expect(rendered, contains('truncated'));
      expect(rendered.length, lessThan(200));
    });

    test('does not throw on values it cannot encode', () {
      expect(() => logger.renderForTest(Object()), returnsNormally);
      expect(() => logger.renderForTest(null), returnsNormally);
    });
  });
}
