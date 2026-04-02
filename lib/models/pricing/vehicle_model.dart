class PricingVehicleModel {
  final String id;
  final String nameEn;
  final bool active;

  PricingVehicleModel({
    required this.id,
    required this.nameEn,
    this.active = true,
  });

  factory PricingVehicleModel.fromJson(Map<String, dynamic> json) {
    return PricingVehicleModel(
      id: json['id'] as String,
      nameEn: json['name_en'] as String,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_en': nameEn,
      'active': active,
    };
  }
}
