import 'package:flutter_test/flutter_test.dart';
import 'package:premium_force_main/services/deep_link_service.dart';

void main() {
  group('bookingIdFrom', () {
    test('reads the id from a booking link on either host', () {
      expect(
        bookingIdFrom(Uri.parse('https://premiumforcegroup.com/booking/abc123')),
        'abc123',
      );
      expect(
        bookingIdFrom(
          Uri.parse('https://www.premiumforcegroup.com/booking/abc123'),
        ),
        'abc123',
      );
    });

    test('tolerates a trailing slash and deeper paths', () {
      expect(
        bookingIdFrom(Uri.parse('https://premiumforcegroup.com/booking/abc/')),
        'abc',
      );
      expect(
        bookingIdFrom(
          Uri.parse('https://premiumforcegroup.com/booking/abc/track'),
        ),
        'abc',
      );
    });

    test('keeps query strings out of the id', () {
      expect(
        bookingIdFrom(
          Uri.parse('https://premiumforcegroup.com/booking/abc?from=sms'),
        ),
        'abc',
      );
    });

    test('refuses a host the manifest never claimed', () {
      expect(
        bookingIdFrom(Uri.parse('https://evil.example.com/booking/abc')),
        isNull,
      );
      expect(
        bookingIdFrom(Uri.parse('https://cdn.premiumforce.sa/booking/abc')),
        isNull,
      );
    });

    test('refuses a non-https scheme', () {
      expect(
        bookingIdFrom(Uri.parse('http://premiumforcegroup.com/booking/abc')),
        isNull,
      );
    });

    test('refuses paths that name no booking', () {
      expect(bookingIdFrom(Uri.parse('https://premiumforcegroup.com/')), isNull);
      expect(
        bookingIdFrom(Uri.parse('https://premiumforcegroup.com/booking')),
        isNull,
      );
      expect(
        bookingIdFrom(Uri.parse('https://premiumforcegroup.com/booking/')),
        isNull,
      );
      expect(
        bookingIdFrom(Uri.parse('https://premiumforcegroup.com/about/abc')),
        isNull,
      );
    });
  });
}
