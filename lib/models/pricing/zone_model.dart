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
    return ZoneModel(
      id: json['id'] as String,
      cityId: json['city_id'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String,
      type: json['type'] as String,
      center: Map<String, double>.from(json['center']),
      radiusKm: (json['radius_km'] as num).toDouble(),
      priority: json['priority'] as int,
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
