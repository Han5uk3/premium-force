class ZoneModel {
  final String id;
  final String cityId;
  final String nameEn;
  final String nameAr;
  final String type; // "radius"
  final Map<String, double> center; // {"lat": ..., "lng": ...}
  final double radiusKm;
  final int priority;

  ZoneModel({
    required this.id,
    required this.cityId,
    required this.nameEn,
    required this.nameAr,
    required this.type,
    required this.center,
    required this.radiusKm,
    required this.priority,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    // Robustly extract center coordinates
    final rawCenter = json['center'] as Map<String, dynamic>;
    final centerMap = {
      'lat': (rawCenter['lat'] as num).toDouble(),
      'lng': (rawCenter['lng'] as num).toDouble(),
    };

    return ZoneModel(
      id: (json['id'] ?? '').toString(),
      cityId: (json['city_id'] ?? json['cityId'] ?? '').toString(),
      nameEn: (json['name_en'] ?? json['nameEn'] ?? '').toString(),
      nameAr: (json['name_ar'] ?? json['nameAr'] ?? '').toString(),
      type: (json['type'] ?? 'radius').toString(),
      center: centerMap,
      radiusKm: (json['radius_km'] as num? ?? 0.0).toDouble(),
      priority: (json['priority'] as num? ?? 0).toInt(),
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
    };
  }

  String getName(String locale) {
    return locale == 'ar' ? nameAr : nameEn;
  }
}
