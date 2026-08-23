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

import 'package:flutter/material.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';

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

/// Colour for a status chip or banner.
///
/// Three outcomes read at a glance — finished, cancelled, waiting on payment —
/// and everything still in flight shares one colour, because the label already
/// says which stage it is at.
Color bookingStatusColor(BookingStatusV2 status) {
  return switch (status) {
    BookingStatusV2.completed => Colors.green,
    BookingStatusV2.cancelled => Colors.red,
    BookingStatusV2.pendingPayment => Colors.orange,
    BookingStatusV2.unknown => Colors.grey,
    _ => Colors.blue,
  };
}
