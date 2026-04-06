import 'package:google_maps_flutter/google_maps_flutter.dart';

class ZoneModel {
  final String id;
  final String cityId;
  final String nameEn;
  final String nameAr;
  final String type; // "radius" or "polygon"
  final Map<String, double>? center; // {"lat": ..., "lng": ...}
  final double? radiusKm;
  final List<LatLng>? coordinates;
  final int priority;
  final bool isActive;

  ZoneModel({
    required this.id,
    required this.cityId,
    required this.nameEn,
    required this.nameAr,
    required this.type,
    this.center,
    this.radiusKm,
    this.coordinates,
    required this.priority,
    this.isActive = true,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    List<LatLng>? coords;
    if (json['coordinates'] is List) {
      coords = (json['coordinates'] as List).map((c) {
        return LatLng(
          (c['lat'] as num).toDouble(),
          (c['lng'] as num).toDouble(),
        );
      }).toList();
    }

    Map<String, double>? centerMap;
    if (json['center'] is Map) {
      final rawCenter = json['center'] as Map<String, dynamic>;
      centerMap = {
        'lat': (rawCenter['lat'] as num).toDouble(),
        'lng': (rawCenter['lng'] as num).toDouble(),
      };
    }

    dynamic cityData = json['city_id'] ?? json['cityID'] ?? json['cityId'] ?? '';
    String cId = '';
    if (cityData is Map) {
      cId = (cityData['_id'] ?? cityData['id'] ?? '').toString();
    } else {
      cId = cityData.toString();
    }

    return ZoneModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      cityId: cId,

      nameEn: (json['name'] ?? json['nameEn'] ?? json['name_en'] ?? '').toString(),
      nameAr: (json['nameAr'] ?? json['name_ar'] ?? '').toString(),
      type: (json['type'] ?? (coords != null ? 'polygon' : 'radius')).toString(),
      center: centerMap,
      radiusKm: (json['radius_km'] ?? json['radiusKm'] as num? ?? 0.0).toDouble(),
      priority: (json['priority'] as num? ?? 0).toInt(),
      coordinates: coords,
      isActive: json['isActive'] ?? json['active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'city_id': cityId,
      'name_en': nameEn,
      'name_ar': nameAr,
      'type': type,
      'center': center,
      'radius_km': radiusKm,
      'priority': priority,
      'isActive': isActive,
      'coordinates': coordinates?.map((c) => {'lat': c.latitude, 'lng': c.longitude}).toList(),
    };
  }

  String getName(String locale) {
    return locale == 'ar' ? nameAr : nameEn;
  }

  bool containsPoint(LatLng point) {
    if (type == 'radius') {
      if (center == null || radiusKm == null) return false;
      // Distance check will be handled by ZoneHelper for radius
      return false; 
    } else if (type == 'polygon' && coordinates != null && coordinates!.isNotEmpty) {
      return _isPointInPolygon(point, coordinates!);
    }
    return false;
  }

  static bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int i, j = polygon.length - 1;
    bool oddNodes = false;
    double x = point.longitude;
    double y = point.latitude;

    for (i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude < y && polygon[j].latitude >= y ||
          polygon[j].latitude < y && polygon[i].latitude >= y) &&
          (polygon[i].longitude +
              (y - polygon[i].latitude) /
                  (polygon[j].latitude - polygon[i].latitude) *
                  (polygon[j].longitude - polygon[i].longitude) <
              x)) {
        oddNodes = !oddNodes;
      }
      j = i;
    }
    return oddNodes;
  }
}
