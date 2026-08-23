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
/// first. The sources are preferred in this order:
///
/// 1. `pickupDate` + `pickupTime` — the plain local strings the backend stores.
///    They carry no zone, so they are read as a wall clock and formatted
///    without being shifted.
/// 2. `pickupDateTime`/`pickupUTC` — an instant, converted to device time.
/// 3. `pickupLocalTimeFormatted` — the server's own rendering
///    (`"10 Aug 2026, 05:00 PM (AST)"`), split at the comma and shown verbatim.
///    Last because it is already in the pickup city's timezone but is not
///    localised.
///
/// [fallbackInstant] covers the case where no route has come back yet — the
/// pickup the customer chose on the device, which is local already. With no
/// source at all both halves come back as `N/A`, matching
/// [formatDisplayDate] on a null instant.
({String date, String time}) formatPickupDisplay(
  BuildContext context,
  Iterable<SessionRoute?> routes, {
  DateTime? fallbackInstant,
}) {
  final present = routes.whereType<SessionRoute>().toList();

  DateTime? instant;
  for (final route in present) {
    instant = pickupWallClock(route);
    if (instant != null) break;
  }
  if (instant == null) {
    for (final route in present) {
      instant = route.pickupDateTime;
      if (instant != null) break;
    }
  }
  instant ??= fallbackInstant;

  if (instant != null) {
    return (
      date: formatDisplayDate(context, instant),
      time: formatDisplayTime(context, instant),
    );
  }

  for (final route in present) {
    final formatted = route.pickupLocalTimeFormatted;
    if (formatted == null || formatted.trim().isEmpty) continue;

    final separator = formatted.lastIndexOf(',');
    if (separator <= 0) return (date: formatted.trim(), time: '');
    return (
      date: formatted.substring(0, separator).trim(),
      time: formatted.substring(separator + 1).trim(),
    );
  }

  return (date: 'N/A', time: 'N/A');
}

/// The route's pickup as a wall clock, or `null` when it holds no date/time
/// strings.
///
/// `pickupDate` and `pickupTime` name a time in the pickup city, not an
/// instant, so they are parsed without a zone: the result is a local
/// `DateTime` carrying exactly the digits the backend sent, which formatting
/// then leaves alone.
DateTime? pickupWallClock(SessionRoute? route) {
  final date = route?.pickupDate;
  final time = route?.pickupTime;
  if (date == null || time == null) return null;
  return DateTime.tryParse('${date}T$time');
}
