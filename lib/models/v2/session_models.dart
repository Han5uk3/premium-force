import 'package:premium_force_main/models/v2/available_vehicle.dart';
import 'package:premium_force_main/models/v2/booking_service_type.dart';
import 'package:premium_force_main/utils/json_utils.dart';

/// Models for the server-held booking draft (`booking_session:<userId>` in
/// Redis, 1-hour TTL).
///
/// Every session endpoint — init, vehicle, passenger — returns the same
/// envelope, progressively filled in, so [BookingSession] is the single source
/// of truth for what the backend currently believes about the in-progress
/// booking. The client mirrors it rather than accumulating its own copy.

/// A pickup or drop-off point.
///
/// Airport-side locations carry [airportId]/[terminalId] and no coordinates;
/// customer-side locations carry lat/lng.
class SessionLocation {
  const SessionLocation({
    this.address,
    this.lat,
    this.lng,
    this.airportId,
    this.terminalId,
    this.terminalName,
    this.terminalNameAr,
  });

  final String? address;
  final double? lat;
  final double? lng;
  final String? airportId;
  final String? terminalId;

  /// Terminal name, when the checkout summary nests one under the location.
  final String? terminalName;
  final String? terminalNameAr;

  factory SessionLocation.fromJson(Map<String, dynamic> json) {
    // The checkout summary nests the terminal here as `terminal: {name}`,
    // where the session payload hangs it off `route.airport`.
    final terminal = pickMap(json, const ['terminal']);

    return SessionLocation(
      address: pickString(json, const ['address', 'formattedAddress', 'name']),
      lat: pickDouble(json, const ['lat', 'latitude']),
      lng: pickDouble(json, const ['lng', 'long', 'longitude']),
      airportId: pickId(json, const ['airportId', 'airportID']),
      terminalId:
          pickId(json, const ['terminalId', 'terminalID']) ??
          pickId(terminal, const ['id', '_id']),
      terminalName: pickString(terminal, const ['name', 'terminalName']),
      terminalNameAr: pickString(terminal, const ['nameAr', 'terminalNameAr']),
    );
  }

  bool get hasCoordinates => lat != null && lng != null;

  /// The terminal nested on this location, localised, or `null` when the
  /// payload names it elsewhere.
  String? displayTerminal(bool isArabic) => isArabic
      ? (terminalNameAr?.trim().isNotEmpty == true
            ? terminalNameAr
            : terminalName)
      : terminalName;

  /// Address for display, with the terminal appended when there is one.
  String? displayAddress(bool isArabic) {
    final terminal = displayTerminal(isArabic);

    if (address == null || address!.trim().isEmpty) return terminal;
    if (terminal == null || terminal.trim().isEmpty) return address;
    return '$address - $terminal';
  }
}

/// The airport block on an airport-transfer session, with its selected terminal
/// nested inside.
class SessionAirport {
  const SessionAirport({
    this.id,
    this.name,
    this.nameAr,
    this.terminalId,
    this.terminalName,
    this.terminalNameAr,
    this.lat,
    this.lng,
  });

  final String? id;
  final String? name;
  final String? nameAr;
  final String? terminalId;
  final String? terminalName;
  final String? terminalNameAr;

  /// Where the terminal is, when the record carries it.
  ///
  /// On an airport booking one end of the journey *is* the airport, and the
  /// payload gives no [SessionLocation] for that end — so without these the
  /// map has no coordinate to pin or route to. Not every airport in the
  /// database has them filled in, which is why they stay nullable and callers
  /// have to cope with their absence.
  final double? lat;
  final double? lng;

  factory SessionAirport.fromJson(Map<String, dynamic> json) {
    // `terminal` is nested on session payloads but a sibling key on booking
    // detail payloads, so both placements are accepted.
    final terminal = pickMap(json, const ['terminal']);
    return SessionAirport(
      id: pickId(json, const ['id', '_id', 'airportId']),
      name: pickString(json, const ['name', 'airportName']),
      nameAr: pickString(json, const ['nameAr', 'airportNameAr']),
      terminalId: pickId(terminal, const ['id', '_id', 'terminalId']),
      terminalName: pickString(terminal, const ['name', 'terminalName']),
      terminalNameAr: pickString(terminal, const ['nameAr', 'terminalNameAr']),
      // `long` is what the airports endpoint calls it; the others are accepted
      // in case the booking payload spells it differently.
      lat: pickDouble(json, const ['lat', 'latitude']),
      lng: pickDouble(json, const ['lng', 'long', 'longitude']),
    );
  }

  String? displayName(bool isArabic) =>
      isArabic ? (nameAr?.trim().isNotEmpty == true ? nameAr : name) : name;

  String? displayTerminal(bool isArabic) => isArabic
      ? (terminalNameAr?.trim().isNotEmpty == true
            ? terminalNameAr
            : terminalName)
      : terminalName;
}

/// The resolved route for the session: which cities/zones the backend matched,
/// the two endpoints, and the pickup timestamp in every form the UI needs.
class SessionRoute {
  const SessionRoute({
    this.cityFromId,
    this.cityFromName,
    this.cityFromNameAr,
    this.cityToId,
    this.cityToName,
    this.cityToNameAr,
    this.zoneFromId,
    this.zoneFromName,
    this.zoneFromNameAr,
    this.zoneToId,
    this.zoneToName,
    this.zoneToNameAr,
    this.airport,
    this.pickupLocation,
    this.dropOffLocation,
    this.flightNumber,
    this.durationHours,
    this.distanceKm,
    this.pickupDate,
    this.pickupTime,
    this.pickupDateTime,
    this.pickupTimezone,
    this.pickupLocalTimeFormatted,
  });

  final String? cityFromId;
  final String? cityFromName;
  final String? cityFromNameAr;
  final String? cityToId;
  final String? cityToName;
  final String? cityToNameAr;

  /// Zone fields are populated for private transfer only.
  final String? zoneFromId;
  final String? zoneFromName;
  final String? zoneFromNameAr;
  final String? zoneToId;
  final String? zoneToName;
  final String? zoneToNameAr;

  /// Populated for airport transfer only.
  final SessionAirport? airport;

  final SessionLocation? pickupLocation;
  final SessionLocation? dropOffLocation;
  final String? flightNumber;

  /// Populated for chauffeur (hourly) only.
  final int? durationHours;

  final double? distanceKm;

  /// Pickup as the user entered it: `YYYY-MM-DD` and `HH:mm`.
  final String? pickupDate;
  final String? pickupTime;

  /// Authoritative pickup instant (UTC) computed by the backend from the local
  /// date/time plus [pickupTimezone]. Read from `pickupUTC`.
  ///
  /// Not what the cards display: shifting it lands in the *device's* zone, not
  /// the pickup city's, so [pickupDate]/[pickupTime] are shown instead and this
  /// is only a last resort. See [formatPickupDisplay].
  final DateTime? pickupDateTime;
  final String? pickupTimezone;

  /// Server-rendered display string, e.g. `"Aug 12, 2026, 06:00 PM"`.
  final String? pickupLocalTimeFormatted;

  factory SessionRoute.fromJson(Map<String, dynamic> json) {
    // Booking-detail payloads nest cities as objects (`cityFrom: {...}`) while
    // session payloads flatten them (`cityFromName`), so both are read.
    final cityFrom = pickMap(json, const ['cityFrom']);
    final cityTo = pickMap(json, const ['cityTo']);
    final airportJson = pickMap(json, const ['airport']);
    final terminalJson = pickMap(json, const ['terminal']);

    return SessionRoute(
      cityFromId:
          pickId(json, const ['cityFromId', 'cityFromID']) ??
          pickId(cityFrom, const ['_id', 'id']),
      cityFromName:
          pickString(json, const ['cityFromName']) ??
          pickString(cityFrom, const ['cityName', 'name']),
      cityFromNameAr:
          pickString(json, const ['cityFromNameAr']) ??
          pickString(cityFrom, const ['cityNameAr', 'nameAr']),
      cityToId:
          pickId(json, const ['cityToId', 'cityToID']) ??
          pickId(cityTo, const ['_id', 'id']),
      cityToName:
          pickString(json, const ['cityToName']) ??
          pickString(cityTo, const ['cityName', 'name']),
      cityToNameAr:
          pickString(json, const ['cityToNameAr']) ??
          pickString(cityTo, const ['cityNameAr', 'nameAr']),
      zoneFromId: pickId(json, const ['zoneFromId', 'zoneFromID']),
      zoneFromName: pickString(json, const ['zoneFromName']),
      zoneFromNameAr: pickString(json, const ['zoneFromNameAr']),
      zoneToId: pickId(json, const ['zoneToId', 'zoneToID']),
      zoneToName: pickString(json, const ['zoneToName']),
      zoneToNameAr: pickString(json, const ['zoneToNameAr']),
      airport: airportJson.isEmpty
          ? null
          // Merge a sibling `terminal` into the airport block so both response
          // shapes produce an equivalent SessionAirport.
          : SessionAirport.fromJson({
              ...airportJson,
              if (terminalJson.isNotEmpty && airportJson['terminal'] == null)
                'terminal': terminalJson,
            }),
      pickupLocation: json['pickupLocation'] == null
          ? null
          : SessionLocation.fromJson(pickMap(json, const ['pickupLocation'])),
      dropOffLocation: json['dropOffLocation'] == null
          ? null
          : SessionLocation.fromJson(pickMap(json, const ['dropOffLocation'])),
      flightNumber: pickString(json, const ['flightNumber']),
      durationHours: pickInt(json, const [
        'durationHours',
        'hours',
        'estimatedHours',
      ]),
      distanceKm: pickDouble(json, const ['distanceKm', 'distance']),
      pickupDate: pickString(json, const ['pickupDate']),
      pickupTime: pickString(json, const ['pickupTime']),
      // `pickupUTC` is read first: it is the key the backend documents as the
      // authoritative instant, and it is what the cards display. The other two
      // spellings are the same value under names older payloads use.
      pickupDateTime: pickDateTime(json, const [
        'pickupUTC',
        'pickupDateTime',
        'pickupdatetime',
      ]),
      pickupTimezone: pickString(json, const ['pickupTimezone']),
      pickupLocalTimeFormatted: pickString(json, const [
        'pickupLocalTimeFormatted',
      ]),
    );
  }

  /// The pickup as a wall clock, or null when the payload holds no date/time
  /// strings.
  ///
  /// [pickupDate] and [pickupTime] name a time in the pickup city, not an
  /// instant, so they are parsed without a zone: the result carries exactly
  /// the digits the backend sent, which is what makes it safe to format
  /// without shifting. `formatPickupDisplay` reads this to print the card.
  DateTime? get pickupWallClock {
    final date = pickupDate;
    final time = pickupTime;
    if (date == null || time == null) return null;
    return DateTime.tryParse('${date}T$time');
  }

  String? cityFromDisplay(bool isArabic) => isArabic
      ? (cityFromNameAr?.trim().isNotEmpty == true
            ? cityFromNameAr
            : cityFromName)
      : cityFromName;

  String? cityToDisplay(bool isArabic) => isArabic
      ? (cityToNameAr?.trim().isNotEmpty == true ? cityToNameAr : cityToName)
      : cityToName;
}

/// The vehicle chosen in step 2, as echoed back by the session.
class SelectedVehicle {
  const SelectedVehicle({
    required this.vehicleId,
    this.name,
    this.model,
    this.maxPassengers,
    this.maxLuggage,
    this.image,
    this.category,
    this.brand,
  });

  final String vehicleId;
  final String? name;
  final String? model;
  final int? maxPassengers;
  final int? maxLuggage;
  final String? image;

  /// Class and make, as the checkout summary echoes them back. The review
  /// screen labels the vehicle from these rather than from the local pickers.
  final VehicleTaxonomy? category;
  final VehicleTaxonomy? brand;

  factory SelectedVehicle.fromJson(Map<String, dynamic> json) {
    final category = pickMap(json, const ['category']);
    final brand = pickMap(json, const ['brand']);

    return SelectedVehicle(
      vehicleId: pickId(json, const ['vehicleId', '_id', 'id']) ?? '',
      name: pickString(json, const ['name', 'carName', 'vehicleName']),
      model: pickString(json, const ['model', 'modelName', 'year']),
      maxPassengers: pickInt(json, const ['maxPassengers', 'passengers']),
      maxLuggage: pickInt(json, const ['maxLuggage', 'luggage']),
      image: pickString(json, const ['image', 'imageUrl', 'carImage']),
      category: category.isEmpty ? null : VehicleTaxonomy.fromJson(category),
      brand: brand.isEmpty ? null : VehicleTaxonomy.fromJson(brand),
    );
  }

  /// Label for the vehicle, e.g. `"S450 2024"`.
  String get displayName =>
      [name, model].where((p) => p?.trim().isNotEmpty == true).join(' ').trim();
}

/// Passenger details captured in step 3.
class PassengerDetails {
  const PassengerDetails({
    required this.passengersCount,
    required this.passengerNames,
    required this.passengerPhone,
  });

  final int passengersCount;

  /// Comma-separated list, matching the existing multi-passenger UI.
  final String passengerNames;

  /// E.164, including country code.
  final String passengerPhone;

  factory PassengerDetails.fromJson(Map<String, dynamic> json) {
    return PassengerDetails(
      passengersCount: pickInt(json, const ['passengersCount', 'count']) ?? 1,
      passengerNames:
          pickString(json, const ['passengerNames', 'names', 'name']) ?? '',
      passengerPhone:
          pickString(json, const ['passengerPhone', 'phone', 'mobile']) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'passengersCount': passengersCount,
    'passengerNames': passengerNames,
    'passengerPhone': passengerPhone,
  };
}

/// The full server-held draft, as returned by every session endpoint.
class BookingSession {
  const BookingSession({
    required this.step,
    this.userId,
    this.serviceType,
    this.transferSubType,
    this.route,
    this.selectedVehicle,
    this.passengerDetails,
    this.rideNotes,
    this.voiceNote,
    this.updatedAt,
  });

  /// How far the draft has progressed server-side: 1 = trip info, 2 = vehicle
  /// chosen, 3 = passenger details saved.
  final int step;

  final String? userId;
  final String? serviceType;
  final String? transferSubType;
  final SessionRoute? route;
  final SelectedVehicle? selectedVehicle;
  final PassengerDetails? passengerDetails;
  final String? rideNotes;

  /// S3 URL of the uploaded recording, once one has been attached in step 2.
  final String? voiceNote;

  final DateTime? updatedAt;

  factory BookingSession.fromJson(Map<String, dynamic> json) {
    return BookingSession(
      step: pickInt(json, const ['step']) ?? 1,
      userId: pickId(json, const ['userId', 'userID']),
      serviceType: pickString(json, const ['serviceType']),
      transferSubType: pickString(json, const ['transferSubType']),
      route: json['route'] == null
          ? null
          : SessionRoute.fromJson(pickMap(json, const ['route'])),
      selectedVehicle: json['selectedVehicle'] == null
          ? null
          : SelectedVehicle.fromJson(pickMap(json, const ['selectedVehicle'])),
      passengerDetails: json['passengerDetails'] == null
          ? null
          : PassengerDetails.fromJson(
              pickMap(json, const ['passengerDetails']),
            ),
      rideNotes: pickString(json, const ['rideNotes', 'specialRequest']),
      voiceNote: pickString(json, const [
        'voiceNote',
        'voiceNoteUrl',
        'specialRequestAudio',
      ]),
      updatedAt: pickDateTime(json, const ['updatedAt']),
    );
  }

  /// The product this draft is for, or `null` if the payload was unrecognisable.
  BookingServiceType? get resolvedServiceType =>
      BookingServiceType.fromResponse(serviceType, transferSubType);
}
