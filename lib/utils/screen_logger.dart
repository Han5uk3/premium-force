/// Debug-only console logging for the booking screens.
///
/// The API layer already logs every request and response through
/// [BookingApiLogger]; what that cannot show is what the screens did with the
/// payload — which tab was refetched and why, which booking a row resolved to,
/// and which of the several pickup fields ended up on the card. These helpers
/// cover that gap.
///
/// Two rules the call sites follow:
///
/// * **Debug only.** Every helper is a no-op in release, so booking numbers,
///   driver names and pickup addresses never reach production logs. This
///   mirrors [BookingApiLogger], which is only ever attached in debug.
/// * **Not in `build`, unguarded.** A `build` method runs on every frame and a
///   `ListView` item builder runs on every scroll, so logging from either
///   without a change check floods the console. The screens keep the last line
///   they emitted and log again only when it would differ.
library;

import 'package:flutter/foundation.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/utils/date_display.dart';

/// Emit one tagged line, e.g. `🧭 bookings │ fetch upcoming (first-show)`.
void logScreen(String tag, String message) {
  if (!kDebugMode) return;
  debugPrint('🧭 $tag │ $message');
}

/// A continuation line, indented under the [logScreen] line above it.
void logScreenDetail(String tag, String message) {
  if (!kDebugMode) return;
  debugPrint('   $tag │ $message');
}

/// How a booking is named in the log.
///
/// [BookingV2.bookingNumber] is non-nullable but comes through empty when the
/// payload omits it, so the id stands in — a line that identifies nothing is
/// worse than a long one.
String bookingRef(BookingV2 booking) =>
    booking.bookingNumber.trim().isEmpty ? booking.id : booking.bookingNumber;

/// One booking in a single line: what it is and where in its lifecycle it sits.
///
/// Deliberately carries no addresses or names — those are in the API log if
/// they are needed, and this is meant to stay short enough to scan a list of.
String bookingSummary(BookingV2 booking) {
  final ref = bookingRef(booking);
  final parts = <String>[
    ref,
    if (ref != booking.id) 'id=${booking.id}',
    'status=${booking.status.wireValue}',
    'service=${booking.resolvedServiceType?.name ?? 'unknown'}',
    if (booking.isChauffeur) 'hours=${booking.route?.durationHours ?? 0}',
    'driver=${booking.driver == null ? 'none' : 'yes'}',
    if (booking.hasCancellationNote) 'cancellationNote',
    if (booking.hasInvoice) 'invoice',
    if (booking.hasRefund) 'refund',
  ];
  return parts.join(' ');
}

/// Log the pickup date and time a card is about to show, with every field the
/// value could have come from.
///
/// [formatPickupDisplay] picks between three sources in a fixed order and each
/// one means a different clock: `pickupDate`/`pickupTime` and
/// `pickupLocalTimeFormatted` are both the pickup city's clock, while
/// `pickupUTC` can only be shifted into the device's. When a customer reports
/// the wrong time, which source won is the first thing worth knowing — a card
/// that fell through to `pickupUTC` on a phone outside the pickup city is off
/// by the gap between the two zones — so it is named here rather than left to
/// be inferred from the raw fields.
///
/// The order below mirrors [formatPickupDisplay] and has to be kept in step
/// with it: a log line naming the wrong source is worse than none.
void logPickupDisplay(
  String tag,
  BookingV2 booking, {
  required String date,
  required String time,
}) {
  if (!kDebugMode) return;

  final route = booking.route;
  final source = pickupWallClock(route) != null
      ? 'pickupDate+pickupTime (city wall clock, unshifted)'
      : (route?.pickupLocalTimeFormatted?.trim().isNotEmpty ?? false)
      ? 'pickupLocalTimeFormatted (server string, split at comma)'
      : route?.pickupDateTime != null
      ? 'pickupUTC (instant → DEVICE zone — wrong unless the device '
            'is in the pickup city)'
      : 'none — falls back to N/A';

  logScreen(
    tag,
    'pickup ${bookingRef(booking)} → '
    'date="$date" time="$time" via $source',
  );
  logScreenDetail(
    tag,
    'pickupUTC=${route?.pickupDateTime?.toIso8601String()} '
    'isUtc=${route?.pickupDateTime?.isUtc} '
    'pickupDate=${route?.pickupDate} '
    'pickupTime=${route?.pickupTime} '
    'pickupTimezone=${route?.pickupTimezone} '
    'pickupLocalTimeFormatted=${route?.pickupLocalTimeFormatted}',
  );
}
