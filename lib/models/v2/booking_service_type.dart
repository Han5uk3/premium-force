/// The four bookable products, and their mapping onto the v2 API vocabulary.
///
/// The UI still identifies a product by the legacy `catcode` integer that
/// `NewBooking` is constructed with, so [fromCatCode] is the bridge between the
/// existing screens and the new endpoints.
enum BookingServiceType {
  airportArrival,
  airportDeparture,
  chauffeur,
  privateTransfer;

  /// Map the legacy `catcode` used throughout the booking UI.
  ///
  /// 0 = airport arrival, 1 = airport departure, 2 = chauffeur (hourly),
  /// 3 = private transfer.
  static BookingServiceType fromCatCode(int catCode) => switch (catCode) {
    0 => airportArrival,
    1 => airportDeparture,
    2 => chauffeur,
    _ => privateTransfer,
  };

  /// The legacy `catcode` for this product.
  int get catCode => switch (this) {
    airportArrival => 0,
    airportDeparture => 1,
    chauffeur => 2,
    privateTransfer => 3,
  };

  /// `serviceType` as reported in the session payload.
  String get serviceType => switch (this) {
    airportArrival || airportDeparture => 'airport_transfer',
    chauffeur => 'hourly',
    privateTransfer => 'private_transfer',
  };

  /// `transferSubType` request field — airport products only.
  String? get transferSubType => switch (this) {
    airportArrival => 'airport_arrival',
    airportDeparture => 'airport_departure',
    _ => null,
  };

  /// Session-initiation endpoint (relative to the v2 base URL).
  String get sessionInitPath => switch (this) {
    airportArrival || airportDeparture => 'bookings/session/airport-transfer',
    chauffeur => 'bookings/session/chauffeur',
    privateTransfer => 'bookings/session/private-transfer',
  };

  bool get isAirport => this == airportArrival || this == airportDeparture;
  bool get isChauffeur => this == chauffeur;
  bool get isPrivateTransfer => this == privateTransfer;

  /// Whether this product requires both endpoints to fall inside an active
  /// transfer zone. Only private transfer is zone-gated.
  bool get requiresZoneResolution => this == privateTransfer;

  /// Reconstruct from a session payload, using [transferSubType] to
  /// disambiguate the two airport directions.
  static BookingServiceType? fromResponse(
    String? serviceType,
    String? subType,
  ) {
    final normalisedSub = subType?.toLowerCase().replaceAll('-', '_');
    if (normalisedSub == 'airport_arrival') return airportArrival;
    if (normalisedSub == 'airport_departure') return airportDeparture;

    return switch (serviceType?.toLowerCase().replaceAll('-', '_')) {
      'airport_transfer' => airportArrival,
      // A chauffeur booking reports its `chauffeurType` as the service type, so
      // both hourly hire and the fixed packages land here.
      'hourly' || 'chauffeur' || 'package' => chauffeur,
      'private_transfer' => privateTransfer,
      _ => null,
    };
  }
}
