/// How a booking's status is presented — one mapping, shared by every screen
/// that shows it.
///
/// The label and the colour used to be written out again at each call site,
/// keyed by status *string*. That is what let the two drift: the v2 API moved
/// to wire values like `driver_assigned` and `trip_started`, and the card's
/// string switch — still written for the old `assigned`/`starttracking`
/// spellings — matched none of them, so it fell through to capitalising the
/// raw wire value. Untranslated, underscored, and grey. Keying off
/// [BookingStatusV2] instead means a status added to the enum has to be given
/// a label here or the switch will not compile.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/theme/app_palette.dart';

/// Short label for a status chip, e.g. `"Driver Assigned"`.
///
/// Kept to one or two words: this is rendered in the pill on the booking card,
/// not as a sentence. The details screen has its own fuller wording for the
/// banner across the top.
String bookingStatusLabel(AppLocalizations loc, BookingStatusV2 status) {
  return switch (status) {
    BookingStatusV2.pendingPayment => loc.paymentPending,
    BookingStatusV2.confirmed => loc.confirmed,
    BookingStatusV2.driverAssigned => loc.driverAssigned,
    BookingStatusV2.driverEnRoute => loc.onTheWay,
    BookingStatusV2.driverArrived => loc.arrived,
    BookingStatusV2.tripStarted => loc.ongoing,
    BookingStatusV2.completed => loc.completed,
    BookingStatusV2.cancelled => loc.cancelled,
    BookingStatusV2.unknown => loc.unknown,
  };
}

/// Colour for a status chip or banner, drawn from the palette in force.
///
/// Three outcomes read at a glance — finished, cancelled, waiting on payment —
/// and everything still in flight shares one colour, because the label already
/// says which stage it is at.
///
/// Takes the palette rather than raw Material colours so the chips deepen in
/// the light theme, where a saturated green or orange would glare against
/// ivory, and so white chip text keeps its contrast in both modes.
Color bookingStatusColor(AppPalette c, BookingStatusV2 status) {
  return switch (status) {
    BookingStatusV2.completed => c.success,
    BookingStatusV2.cancelled => c.error,
    BookingStatusV2.pendingPayment => c.warning,
    BookingStatusV2.unknown => c.textTertiary,
    _ => c.info,
  };
}

/// The ink that reads on a [bookingStatusColor] fill.
///
/// Measured rather than listed: the chip colours differ between the two
/// palettes — the dark theme's amber is pale enough that white on it falls to
/// about 2:1, while the light theme's is deep enough that white is the only
/// readable choice — and a hand-written table of exceptions would go stale the
/// first time one of them is retuned. Comparing luminance decides it correctly
/// for whatever the palette holds.
Color onBookingStatusColor(AppPalette c, BookingStatusV2 status) {
  return _readableInkOn(bookingStatusColor(c, status));
}

/// Black or white, whichever contrasts more with [fill].
Color _readableInkOn(Color fill) {
  // The sRGB relative luminance from WCAG 2.1, which is what a contrast ratio
  // is computed from — a plain average of the channels would call a saturated
  // green and a saturated blue equally bright, and they are not.
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

  final luminance =
      0.2126 * channel(fill.r) +
      0.7152 * channel(fill.g) +
      0.0722 * channel(fill.b);

  final onWhite = 1.05 / (luminance + 0.05);
  final onBlack = (luminance + 0.05) / 0.05;
  return onBlack > onWhite ? Colors.black : Colors.white;
}
