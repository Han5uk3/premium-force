/// How API-supplied dates and times are rendered.
///
/// The backend hands timestamps over in three different shapes, and each one
/// has to be treated differently:
///
/// * **UTC instants** — `pickupUTC`, `createdAt`, and the timeline
///   `timestamp`s. They are parsed as UTC, so they are converted to the
///   device's timezone before formatting; rendering them untouched puts a UTC
///   clock in front of the customer.
/// * **Values that are already local** — a `DateTime` the app built from its
///   own pickers, or one the backend already shifted. [DateTime.toLocal] is a
///   no-op on these, so the same helpers are safe for both.
/// * **Plain strings** — `pickupDate`/`pickupTime` (wall clock in the pickup
///   city's timezone) and `pickupLocalTimeFormatted` (already rendered for
///   display). These are never re-interpreted as an instant to shift; they are
///   shown as they arrived.
library;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:premium_force_main/models/v2/session_models.dart';

/// Format an instant as `dd MMM yyyy` in the device's timezone.
///
/// A UTC value is converted; one that is already local is left where it is.
String formatDisplayDate(BuildContext context, DateTime? dateTime) {
  if (dateTime == null) return 'N/A';
  final locale = Localizations.localeOf(context).languageCode;
  return DateFormat('dd MMM yyyy', locale).format(dateTime.toLocal());
}

/// Format an instant as `h:mm AM/PM` in the device's timezone.
String formatDisplayTime(BuildContext context, DateTime? dateTime) {
  if (dateTime == null) return 'N/A';
  final locale = Localizations.localeOf(context).languageCode;
  final local = dateTime.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = DateFormat('a', locale).format(local);
  return '$hour:$minute $period';
}

/// The pickup date and time of a route, as the cards render them.
///
/// [routes] are tried in order, so a caller holding both the checkout summary
/// and the session draft can pass both and get whichever names the pickup
/// first.
///
/// The pickup shown is the one the **pickup city's** clock reads — the hour the
/// driver will actually arrive, and the hour the customer chose. It is not
/// converted to the device's timezone, so the same booking reads the same on a
/// phone in any country.
///
/// That constraint is what fixes the source order, because only some of the
/// fields can honour it:
///
/// 1. `pickupDate` + `pickupTime` — the pickup city's wall clock, stored as the
///    customer entered it. Carries no zone, so it is read as a wall clock and
///    formatted without being shifted. Preferred: it is exact on every device,
///    and it is the only source that is also localised.
/// 2. `pickupLocalTimeFormatted` — the server's own rendering
///    (`"10 Aug 2026, 05:00 PM (AST)"`), split at the comma and shown verbatim.
///    Also in the city's zone, so it is accurate, but it arrives pre-rendered
///    in English — which is why it sits behind the wall clock rather than
///    ahead of it.
/// 3. [fallbackInstant] — the pickup the customer just chose on the device,
///    for the review screen before any route has come back. Already local, and
///    by definition the value they are looking at.
/// 4. `pickupUTC` — the backend's authoritative instant, converted to device
///    time. **Last resort.** Dart can only shift an instant into the device's
///    zone, and the project carries no IANA timezone database to shift it into
///    the pickup city's instead, so this reads correctly only when the two
///    zones agree. Booking 5:15 PM in Riyadh from a phone on IST renders as
///    7:45 PM here — the +2:30 between the zones. It is kept because a payload
///    that carries nothing else still has to show something.
///
/// With no source at all both halves come back as `N/A`, matching
/// [formatDisplayDate] on a null instant.
({String date, String time}) formatPickupDisplay(
  BuildContext context,
  Iterable<SessionRoute?> routes, {
  DateTime? fallbackInstant,
}) {
  final present = routes.whereType<SessionRoute>().toList();

  for (final route in present) {
    final wallClock = pickupWallClock(route);
    if (wallClock != null) {
      return (
        date: formatDisplayDate(context, wallClock),
        time: formatDisplayTime(context, wallClock),
      );
    }
  }

  for (final route in present) {
    final split = _splitFormattedPickup(route.pickupLocalTimeFormatted);
    if (split != null) return split;
  }

  if (fallbackInstant != null) {
    return (
      date: formatDisplayDate(context, fallbackInstant),
      time: formatDisplayTime(context, fallbackInstant),
    );
  }

  for (final route in present) {
    final instant = route.pickupDateTime;
    if (instant != null) {
      return (
        date: formatDisplayDate(context, instant),
        time: formatDisplayTime(context, instant),
      );
    }
  }

  return (date: 'N/A', time: 'N/A');
}

/// Split `"10 Aug 2026, 05:00 PM (AST)"` into its date and time halves.
///
/// The last comma is the separator, since the date half may contain one of its
/// own (`"Aug 12, 2026, 06:00 PM"`). A string with no comma is all date.
({String date, String time})? _splitFormattedPickup(String? formatted) {
  if (formatted == null || formatted.trim().isEmpty) return null;

  final separator = formatted.lastIndexOf(',');
  if (separator <= 0) return (date: formatted.trim(), time: '');
  return (
    date: formatted.substring(0, separator).trim(),
    time: formatted.substring(separator + 1).trim(),
  );
}

/// The route's pickup as a wall clock, or `null` when it holds no date/time
/// strings.
///
/// `pickupDate` and `pickupTime` name a time in the pickup city, not an
/// instant, so they are parsed without a zone: the result is a local
/// `DateTime` carrying exactly the digits the backend sent, which formatting
/// then leaves alone.
///
/// The parsing itself lives on [SessionRoute.pickupWallClock], so the booking
/// model can read the same value without reaching into this Flutter-facing
/// library; this stays as the null-tolerant form the formatters call.
DateTime? pickupWallClock(SessionRoute? route) => route?.pickupWallClock;
