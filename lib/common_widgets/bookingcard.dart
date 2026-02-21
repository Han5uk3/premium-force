import 'package:flutter/material.dart';
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
  const Bookingcard({
    super.key,
    required this.status,
    required this.type,
    required this.pickup,
    required this.dropoff,
    required this.date,
    required this.time,
    required this.ride,
    required this.brand,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF60350F), Color(0xFFE4A46B), Color(0xFF60350F)],
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
                Text(
                  type,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                buildContainerText(true, false, loc),
              ],
            ),

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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 4),
                Image.asset(
                  "assets/icons/pixel_arrow.png",
                  height: 30,
                  width: 30,
                  fit: BoxFit.contain,
                ),
                SizedBox(width: 8),
                Expanded(
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(color: Colors.white),

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
                        size: 18,
                      ),
                      SizedBox(width: 5),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 12,
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
                        size: 18,
                      ),
                      SizedBox(width: 5),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
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
                        size: 18,
                      ),
                      SizedBox(width: 5),
                      Text(
                        "$ride - $brand",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildContainerText(bool isPickup, bool isGrey, AppLocalizations loc) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isGrey ? Colors.grey : getColorByStatus(status),
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
    switch (status) {
      case "Completed":
      case "C":
      case "c":
        return loc.completed;
      case "Pending":
      case "P":
      case "p":
        return loc.pending;
      case "Cancelled":
      case "X":
      case "x":
        return loc.cancelled;
      case "q":
      case "Q":
        return loc.pickup;
      case "w":
      case "W":
        return loc.dropoff;
      default:
        return loc.unknown;
    }
  }

  Color getColorByStatus(String status) {
    switch (status) {
      case "Completed":
      case "C":
      case "c":
        return Colors.green;
      case "Pending":
      case "P":
      case "p":
        return Colors.orange;
      case "Cancelled":
      case "X":
      case "x":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
