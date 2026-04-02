class CityModel {
  final String id;
  final String nameEn;
  final String nameAr;

  CityModel({
    required this.id,
    required this.nameEn,
    required this.nameAr,
  });

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: json['id'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_en': nameEn,
      'name_ar': nameAr,
    };
  }

  String getName(String locale) {
    return locale == 'ar' ? nameAr : nameEn;
  }
}
