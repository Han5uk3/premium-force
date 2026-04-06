import 'dart:math';
import '../models/pricing/zone_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ZoneHelper {
  /// Calculates the distance between two points in kilometers using the Haversine formula.
  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadiusKm = 6371.0;

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLng = _degreesToRadians(lng2 - lng1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) * sin(dLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Finds the best zone for a given location within a city based on priority (lower = higher priority).
  static ZoneModel? detectZone(LatLng point, List<ZoneModel> cityZones) {
    ZoneModel? bestZone;
    int? highestPriority;

    for (var zone in cityZones) {
      bool isMatch = false;
      if (zone.type == 'radius' && zone.center != null && zone.radiusKm != null) {
        double dist = calculateDistance(
          point.latitude,
          point.longitude,
          zone.center!['lat']!,
          zone.center!['lng']!,
        );
        if (dist <= zone.radiusKm!) {
          isMatch = true;
        }
      } else if (zone.type == 'polygon') {
        if (zone.containsPoint(point)) {
          isMatch = true;
        }
      }

      if (isMatch) {
        if (highestPriority == null || zone.priority < highestPriority) {
          highestPriority = zone.priority;
          bestZone = zone;
        }
      }
    }
    return bestZone;
  }
}
