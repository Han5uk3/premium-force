class RouteModel {
  final String vehicleId;
  final String fromCityId;
  final String? fromZoneId;
  final String toCityId;
  final String? toZoneId;
  final double price;
  final bool active;

  RouteModel({
    required this.vehicleId,
    required this.fromCityId,
    this.fromZoneId,
    required this.toCityId,
    this.toZoneId,
    required this.price,
    this.active = true,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      vehicleId: json['vehicle_id'] as String,
      fromCityId: json['from_city_id'] as String,
      fromZoneId: json['from_zone_id'] as String?,
      toCityId: json['to_city_id'] as String,
      toZoneId: json['to_zone_id'] as String?,
      price: (json['price'] as num).toDouble(),
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle_id': vehicleId,
      'from_city_id': fromCityId,
      'from_zone_id': fromZoneId,
      'to_city_id': toCityId,
      'to_zone_id': toZoneId,
      'price': price,
      'active': active,
    };
  }

  /// Calculates a priority score for the match.
  /// 4 = Exact match (both zones match)
  /// 2 = One zone matches (from or to) - though the requirements didn't specify this fallback, it's good to consider.
  /// 1 = Fallback match (both zones null)
  int getMatchPriority(String? pZoneId, String? dZoneId) {
    int score = 0;
    if (fromZoneId == pZoneId && toZoneId == dZoneId) {
      score = 4;
    } else if (fromZoneId == null && toZoneId == null) {
      score = 1;
    }
    return score;
  }
}
