import 'package:flutter_test/flutter_test.dart';
import 'package:premium_force_main/utils/pickup_window.dart';

void main() {
  group('earliestPickupInstant', () {
    test('adds the buffer within the same day', () {
      final now = DateTime(2026, 8, 25, 14, 15);
      expect(earliestPickupInstant(now, 3), DateTime(2026, 8, 25, 17, 15));
    });

    test('rolls onto the next day — 10 PM + 3h is 1 AM tomorrow', () {
      final now = DateTime(2026, 8, 25, 22, 0);
      expect(earliestPickupInstant(now, 3), DateTime(2026, 8, 26, 1, 0));
    });

    test('rolls across a month boundary', () {
      final now = DateTime(2026, 8, 31, 23, 30);
      expect(earliestPickupInstant(now, 2), DateTime(2026, 9, 1, 1, 30));
    });

    test('rolls across a year boundary', () {
      final now = DateTime(2026, 12, 31, 23, 0);
      expect(earliestPickupInstant(now, 4), DateTime(2027, 1, 1, 3, 0));
    });

    test('drops seconds so the offered minute is not rejected', () {
      final now = DateTime(2026, 8, 25, 14, 15, 59);
      expect(earliestPickupInstant(now, 0), DateTime(2026, 8, 25, 14, 15));
    });

    test('a zero or missing buffer is just now', () {
      final now = DateTime(2026, 8, 25, 14, 15);
      expect(earliestPickupInstant(now, 0), DateTime(2026, 8, 25, 14, 15));
    });
  });

  group('earliestPickupDate', () {
    test('is tomorrow once the buffer crosses midnight', () {
      final now = DateTime(2026, 8, 25, 22, 0);
      expect(earliestPickupDate(now, 3), DateTime(2026, 8, 26));
    });

    test('is today when the buffer stays inside the day', () {
      final now = DateTime(2026, 8, 25, 10, 0);
      expect(earliestPickupDate(now, 3), DateTime(2026, 8, 25));
    });
  });

  group('defaultPickupInstant', () {
    test('the reported case: 10 PM + 3h buffer defaults to 1 AM next day', () {
      final now = DateTime(2026, 8, 25, 22, 0);
      expect(defaultPickupInstant(now, 3), DateTime(2026, 8, 26, 1, 0));
    });

    test('rounds up to the next quarter hour', () {
      final now = DateTime(2026, 8, 25, 14, 16);
      expect(defaultPickupInstant(now, 0), DateTime(2026, 8, 25, 14, 30));
    });

    test('leaves an exact quarter hour alone', () {
      final now = DateTime(2026, 8, 25, 14, 30);
      expect(defaultPickupInstant(now, 0), DateTime(2026, 8, 25, 14, 30));
    });

    test('rounding alone can cross midnight', () {
      final now = DateTime(2026, 8, 25, 23, 50);
      expect(defaultPickupInstant(now, 0), DateTime(2026, 8, 26, 0, 0));
    });

    test('buffer and rounding cross midnight together', () {
      final now = DateTime(2026, 8, 25, 21, 52);
      // 21:52 + 3h = 00:52 next day, rounded up to 01:00.
      expect(defaultPickupInstant(now, 3), DateTime(2026, 8, 26, 1, 0));
    });
  });

  group('bumpedToBookable', () {
    test('leaves a candidate that already clears the buffer', () {
      final now = DateTime(2026, 8, 25, 10, 0);
      final candidate = DateTime(2026, 8, 25, 18, 0);
      expect(bumpedToBookable(candidate, now, 3), candidate);
    });

    test('moves a short candidate up to the default, keeping its day', () {
      final now = DateTime(2026, 8, 25, 10, 0);
      final candidate = DateTime(2026, 8, 25, 11, 0);
      expect(
        bumpedToBookable(candidate, now, 3),
        DateTime(2026, 8, 25, 13, 0),
      );
    });

    test('a bump that crosses midnight carries the date, not just the clock',
        () {
      final now = DateTime(2026, 8, 25, 23, 50);
      // Pairing the kept 00:00 with today would land in the past; the bump has
      // to move the day too.
      final candidate = DateTime(2026, 8, 25, 0, 0);
      expect(bumpedToBookable(candidate, now, 0), DateTime(2026, 8, 26, 0, 0));
    });
  });
}
