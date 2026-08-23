import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/utils/booking_status_display.dart';
import 'package:premium_force_main/utils/date_display.dart';

class Bookingcard extends StatelessWidget {
  /// The booking's stage, or null on the review card — there is no booking
  /// yet, and that card renders no status chip.
  final BookingStatusV2? status;
  /// The service, already localised by the caller — the card renders it as
  /// given rather than deriving a label again from the text.
  final String type;
  final String pickup;
  final String dropoff;
  final String date;
  final String time;
  final String ride;
  final String brand;
  final int passengers;
  final bool isFromReviewAndConfirm;
  final bool isChauffeur;
  final String? chauffeurName;

  /// Hours of chauffeur hire, already formatted and localised, e.g.
  /// `"6 Hours"`.
  ///
  /// Shown across from the service type, in the place the status chip takes
  /// on the list cards — so only the detail card, which carries no chip, has
  /// the room for it. Null for anything that is not hourly hire.
  final String? durationLabel;

  /// The booking's reference, e.g. `"PF-APT-2608-7795"`, shown under the
  /// service type.
  ///
  /// Absent on the review screen, which renders the card before a booking
  /// exists to number.
  final String? bookingNumber;

  /// The note the operator left when the booking was cancelled, shown on the
  /// card so a cancelled ride explains itself without being opened.
  final String? cancellationNote;

  const Bookingcard({
    super.key,
    this.passengers = 1,
    this.isFromReviewAndConfirm = false,
    this.isChauffeur = false,
    this.chauffeurName,
    this.bookingNumber,
    this.durationLabel,
    this.cancellationNote,
    this.status,
    required this.type,
    required this.pickup,
    required this.dropoff,
    required this.date,
    required this.time,
    required this.ride,
    required this.brand,
  });

  /// Kept as the card's own entry points into [formatDisplayTime] and
  /// [formatDisplayDate], which convert a UTC instant into device time.
  static String formatTime(BuildContext context, DateTime? dateTime) =>
      formatDisplayTime(context, dateTime);

  static String formatDate(BuildContext context, DateTime? dateTime) =>
      formatDisplayDate(context, dateTime);

  /// Labels a price-summary row with its rate, e.g. "VAT (15%)".
  ///
  /// The bracketed rate is forced left-to-right. In an RTL layout the digits
  /// otherwise inherit Arabic-number direction from the Arabic label in front
  /// of them, which strands the '%' and mirrors the brackets, so "(15%)" comes
  /// out as "(%15)".
  static String formatPercentLabel(String label, double percentage) {
    final rate = '(${percentage.toStringAsFixed(0)}%)';
    return '$label ${Bidi.enforceLtrInText(rate)}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFromReviewAndConfirm
              ? [Colors.grey.shade800, Colors.grey.shade700]
              : [Color(0xFF60350F), Color(0xFFE4A46B), Color(0xFF60350F)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        width: MediaQuery.of(context).size.width,
        child: Column(
          spacing: 10,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFromReviewAndConfirm) ...[
                        Text(
                          loc.service,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 5),
                      ],
                      Text(
                        type,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (bookingNumber?.trim().isNotEmpty ?? false) ...[
                        SizedBox(height: 3),
                        Text(
                          // The reference is latin text and digits: without
                          // this it inherits the Arabic direction of the label
                          // above it and comes out reversed in an RTL layout.
                          Bidi.enforceLtrInText(bookingNumber!.trim()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withAlpha(150),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isFromReviewAndConfirm) ...[
                  SizedBox(width: 8),
                  buildContainerText(true, false, loc),
                ] else if (durationLabel?.trim().isNotEmpty ?? false) ...[
                  SizedBox(width: 8),
                  // Mirrors the service block opposite it, so the two headings
                  // and the two values sit on the same lines.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc.duration,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        durationLabel!.trim(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            isFromReviewAndConfirm
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [Divider(color: Colors.grey.shade700, height: 5)],
                  )
                : SizedBox.shrink(),

            Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildContainerText(true, true, loc),
                      SizedBox(height: 8),
                      Text(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        pickup,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                isChauffeur ? SizedBox.shrink() : SizedBox(width: 4),
                isChauffeur
                    ? SizedBox.shrink()
                    : CircleAvatar(
                        backgroundColor: Colors.grey.shade900.withValues(
                          alpha: 0.6,
                        ),
                        child: Icon(Icons.arrow_forward, color: Colors.white),
                      ),
                isChauffeur ? SizedBox.shrink() : SizedBox(width: 8),
                isChauffeur
                    ? SizedBox.shrink()
                    : Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildContainerText(false, true, loc),
                            SizedBox(height: 8),
                            Text(
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              dropoff,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
            ),

            !isFromReviewAndConfirm ? Divider(color: Colors.white) : SizedBox(),

            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Color(0xFF332627),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 5),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(height: 20, width: 1, color: Colors.white),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 5),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(height: 20, width: 1, color: Colors.white),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.drive_eta_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 5),
                      Text(
                        "$ride",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_hasCancellationNote) _buildCancellationNote(loc),

            Column(
              children: [
                Divider(color: Colors.grey.shade700, height: 5),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      isFromReviewAndConfirm ? loc.passengers : loc.chauffeur,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      isFromReviewAndConfirm
                          ? "$passengers"
                          : _getChauffeurDisplay(loc),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Whether there is a note to show, which is only ever the case on a
  /// cancelled booking.
  bool get _hasCancellationNote =>
      cancellationNote?.trim().isNotEmpty ?? false;

  /// The cancellation note the API attached to a cancelled booking.
  Widget _buildCancellationNote(AppLocalizations loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.red.withValues(alpha: 0.12),
        border: Border.all(color: Colors.red.shade900),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.red.shade300, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.cancellationNote,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade300,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cancellationNote!.trim(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getChauffeurDisplay(AppLocalizations loc) {
    if (chauffeurName != null &&
        chauffeurName!.isNotEmpty &&
        chauffeurName != 'Not Assigned' &&
        chauffeurName != 'Driver Assigned') {
      return chauffeurName!;
    }

    // The name usually arrives with the assignment; this covers the gap
    // between the ride being assigned and the driver record being populated.
    if (status?.hasDriver ?? false) return loc.driverAssigned;
    return loc.notAssigned;
  }

  Widget buildContainerText(bool isPickup, bool isGrey, AppLocalizations loc) {
    final stage = status ?? BookingStatusV2.unknown;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isGrey ? Colors.grey.shade800 : bookingStatusColor(stage),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isGrey
            ? isPickup
                  ? loc.pickup
                  : loc.dropoff
            : bookingStatusLabel(loc, stage),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
