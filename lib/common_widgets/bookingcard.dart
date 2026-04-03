import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:premium_force_main/l10n/app_localizations.dart';

class Bookingcard extends StatelessWidget {
  final String status;
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

  const Bookingcard({
    super.key,
    this.passengers = 1,
    this.isFromReviewAndConfirm = false,
    this.isChauffeur = false,
    this.chauffeurName,
    required this.status,
    required this.type,
    required this.pickup,
    required this.dropoff,
    required this.date,
    required this.time,
    required this.ride,
    required this.brand,
  });

  static String formatTime(BuildContext context, DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final locale = Localizations.localeOf(context).languageCode;
    return '${DateFormat('hh:mm', 'en').format(dateTime)} ${DateFormat('a', locale).format(dateTime)}';
  }

  static String formatDate(BuildContext context, DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat('dd MMM yyyy', locale).format(dateTime);
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
                isFromReviewAndConfirm
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.service,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            getServiceType(type, loc),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        type,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                !isFromReviewAndConfirm
                    ? buildContainerText(true, false, loc)
                    : SizedBox.shrink(),
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

  String _getChauffeurDisplay(AppLocalizations loc) {
    if (chauffeurName != null &&
        chauffeurName!.isNotEmpty &&
        chauffeurName != 'Not Assigned' &&
        chauffeurName != 'Driver Assigned') {
      return chauffeurName!;
    }

    final lowerStatus = status.toLowerCase().trim();
    if (lowerStatus == 'assigned' ||
        lowerStatus == 'starttracking' ||
        lowerStatus == 'ongoing') {
      return loc.driverAssigned;
    }
    return loc.notAssigned;
  }

  Widget buildContainerText(bool isPickup, bool isGrey, AppLocalizations loc) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isGrey ? Colors.grey.shade800 : getColorByStatus(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isGrey
            ? isPickup
                  ? loc.pickup
                  : loc.dropoff
            : getStatusText(status, loc),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  String getStatusText(String status, AppLocalizations loc) {
    status = status.toLowerCase();
    if (status == "completed" || status == "c") {
      return loc.completed;
    } else if (status == "reviewed") {
      return loc.reviewed;
    } else if (status == "pending" || status == "p") {
      return loc.pending;
    } else if (status == "cancelled" || status == "x") {
      return loc.cancelled;
    } else if (status == "starttracking") {
      return loc.tracking;
    } else if (status == "stoptracking") {
      return loc.trackingStopped;
    } else if (status == "assigned") {
      return loc.assigned;
    } else if (status == "paymentpending" || status == "payment pending") {
      return loc.paymentPending;
    }
    return status.isNotEmpty
        ? status[0].toUpperCase() + status.substring(1)
        : loc.unknown;
  }

  Color getColorByStatus(String status) {
    status = status.toLowerCase();
    if (status == "completed" || status == "c" || status == "reviewed") {
      return Colors.green;
    } else if (status == "pending" || status == "p") {
      return Colors.orange;
    } else if (status == "confirmed" ||
        status == "ongoing" ||
        status == "assigned" ||
        status == "starttracking" ||
        status == "stoptracking" ||
        status == "paymentpending" ||
        status == "payment pending") {
      return Colors.blue;
    } else if (status == "cancelled" || status == "x") {
      return Colors.red;
    }
    return Colors.grey;
  }

  String getServiceType(String type, AppLocalizations loc) {
    type = type.toLowerCase();
    if (type == "airport arrival" || type == "arrival") {
      return loc.airportArrival;
    } else if (type == "airport departure" || type == "departure") {
      return loc.airportDeparture;
    } else if (type == "chauffeur" ||
        type == "chauffeur service" ||
        type.contains("chauffeur") ||
        type == "hourly") {
      return loc.chauffeur;
    } else if (type == "private transfer") {
      return loc.privateTransfer;
    }
    return type.isNotEmpty
        ? type[0].toUpperCase() + type.substring(1)
        : loc.unknown;
  }
}
