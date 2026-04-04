import 'user.dart';

abstract class BookingModel {
  final String id;
  final String? category;

  // Nested Objects
  final CityDetails? cityData;
  final AirportDetails? airportData;
  final TerminalDetails? terminalData;
  final CarDetails? carData;
  final UserModel? customer;
  final DriverDetails? driver;
  final OriginalIds? originalIds;

  // Common extracted fields
  final String? city;
  final String? airport;
  final String? terminal;
  final double? pickupLat;
  final double? pickupLong;
  final String? pickupAddress;
  final String? carclass;
  final String? carName;
  final double? charge;
  final String? carbrand;
  final String? carmodel;
  final String? carimage;
  final String? specialRequestText;
  final String? specialRequestAudio;
  final String? passengerCount;
  final dynamic passengerNames;
  final String? passengerMobile;
  final String? bookingStatus;
  final String? paymentStatus;
  final List<String>? trackingTimeline;
  final Map<String, dynamic>? rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? discountPercentage;
  final String? orderID;
  final String? transactionID;

  // Common IDs
  final String? customerID;
  final String? driverID;
  final String? cityID;
  final String? airportID;
  final String? terminalID;
  final String? carID;
  final String? brandID;
  final String? categoryID;
  final String? bookingType;
  final String? bookingNumber;

  BookingModel({
    required this.id,
    this.category,
    this.cityData,
    this.airportData,
    this.terminalData,
    this.carData,
    this.customer,
    this.driver,
    this.originalIds,
    this.city,
    this.airport,
    this.terminal,
    this.pickupLat,
    this.pickupLong,
    this.pickupAddress,
    this.carclass,
    this.carName,
    this.charge,
    this.carbrand,
    this.carmodel,
    this.carimage,
    this.specialRequestText,
    this.specialRequestAudio,
    this.passengerCount,
    this.passengerNames,
    this.passengerMobile,
    this.bookingStatus,
    this.paymentStatus,
    this.trackingTimeline,
    this.rating,
    this.createdAt,
    this.updatedAt,
    this.discountPercentage,
    this.orderID,
    this.transactionID,
    this.customerID,
    this.driverID,
    this.cityID,
    this.airportID,
    this.terminalID,
    this.carID,
    this.brandID,
    this.categoryID,
    this.bookingType,
    this.bookingNumber,
  });

  // Getters for common derived properties
  String get displayBrand {
    if (carData != null && carData!.brandName != null) return carData!.brandName!;
    return 'N/A';
  }

  String get displayName {
    if (carData != null && carData!.carName != null) return carData!.carName!;
    return 'N/A';
  }

  String get displayBookingCategory {
    if (category != null && category!.isNotEmpty) return category!;
    return 'N/A';
  }

  String get displayCategory {
    if (carData != null && carData!.categoryName != null) return carData!.categoryName!;
    return 'N/A';
  }

  String? get displayDriverName {
    if (driver != null && driver!.driverName != null && driver!.driverName!.isNotEmpty) {
      return driver!.driverName!;
    }
    return null;
  }

  // Virtual fields (nullable in base, overridden in specific models)
  String? get arrival => null;
  String? get dropOffAddress => null;
  double? get dropOffLat => null;
  double? get dropOffLong => null;
  String? get distance => null;
  String? get flightNumber => null;

  String? get startedAt => null;
  String? get stoppedAt => null;

  String? get pickupdatetime => null;
  int? get estimatedHours => null;
  int? get extraHours => null;
  String? get extraOrderID => null;
  String? get extraTransactionID => null;
  double? get extraPayment => null;
  double? get extraDiscount => null;
  String? get extraPaymentCompleted => null;

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    // Determine type
    final type = (json['bookingType'] ?? json['booking_type'])?.toString().toLowerCase();
    final category = json['category']?.toString().toLowerCase() ?? '';
    final isHourly = type == 'hourly' ||
        category.contains('chauffeur') ||
        json['estimatedHours'] != null ||
        json['hours'] != null;

    if (isHourly) {
      return HourlyBookingModel.fromMap(json);
    } else {
      return NormalBookingModel.fromMap(json);
    }
  }

  BookingModel copyWith({
    String? id,
    String? category,
    CityDetails? cityData,
    AirportDetails? airportData,
    TerminalDetails? terminalData,
    CarDetails? carData,
    UserModel? customer,
    DriverDetails? driver,
    OriginalIds? originalIds,
    String? city,
    String? airport,
    String? terminal,
    double? pickupLat,
    double? pickupLong,
    String? pickupAddress,
    String? carclass,
    String? carName,
    double? charge,
    String? carbrand,
    String? carmodel,
    String? carimage,
    String? specialRequestText,
    String? specialRequestAudio,
    String? passengerCount,
    dynamic passengerNames,
    String? passengerMobile,
    String? bookingStatus,
    String? paymentStatus,
    List<String>? trackingTimeline,
    Map<String, dynamic>? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? discountPercentage,
    String? orderID,
    String? transactionID,
    String? customerID,
    String? driverID,
    String? cityID,
    String? airportID,
    String? terminalID,
    String? carID,
    String? brandID,
    String? categoryID,
    String? bookingType,
    String? bookingNumber,
  });

  Map<String, dynamic> toJson();
}

class NormalBookingModel extends BookingModel {
  @override
  final String? arrival;
  @override
  final String? dropOffAddress;
  @override
  final double? dropOffLat;
  @override
  final double? dropOffLong;
  @override
  final String? distance;
  @override
  final String? flightNumber;

  NormalBookingModel({
    required super.id,
    super.category,
    super.cityData,
    super.airportData,
    super.terminalData,
    super.carData,
    super.customer,
    super.driver,
    super.originalIds,
    super.city,
    super.airport,
    super.terminal,
    super.pickupLat,
    super.pickupLong,
    super.pickupAddress,
    super.carclass,
    super.carName,
    super.charge,
    super.carbrand,
    super.carmodel,
    super.carimage,
    super.specialRequestText,
    super.specialRequestAudio,
    super.passengerCount,
    super.passengerNames,
    super.passengerMobile,
    super.bookingStatus,
    super.paymentStatus,
    super.trackingTimeline,
    super.rating,
    super.createdAt,
    super.updatedAt,
    super.discountPercentage,
    super.orderID,
    super.transactionID,
    super.customerID,
    super.driverID,
    super.cityID,
    super.airportID,
    super.terminalID,
    super.carID,
    super.brandID,
    super.categoryID,
    super.bookingType,
    super.bookingNumber,
    this.arrival,
    this.dropOffAddress,
    this.dropOffLat,
    this.dropOffLong,
    this.distance,
    this.flightNumber,
  });

  factory NormalBookingModel.fromMap(Map<String, dynamic> json) {
    final common = _parseCommon(json);
    return NormalBookingModel(
      id: common.id,
      category: common.category,
      cityData: common.cityData,
      airportData: common.airportData,
      terminalData: common.terminalData,
      carData: common.carData,
      customer: common.customer,
      driver: common.driver,
      originalIds: common.originalIds,
      city: common.city,
      airport: common.airport,
      terminal: common.terminal,
      pickupLat: common.pickupLat,
      pickupLong: common.pickupLong,
      pickupAddress: common.pickupAddress,
      carclass: common.carclass,
      carName: common.carName,
      charge: common.charge,
      carbrand: common.carbrand,
      carmodel: common.carmodel,
      carimage: common.carimage,
      specialRequestText: common.specialRequestText,
      specialRequestAudio: common.specialRequestAudio,
      passengerCount: common.passengerCount,
      passengerNames: common.passengerNames,
      passengerMobile: common.passengerMobile,
      bookingStatus: common.bookingStatus,
      paymentStatus: common.paymentStatus,
      trackingTimeline: common.trackingTimeline,
      rating: common.rating,
      createdAt: common.createdAt,
      updatedAt: common.updatedAt,
      discountPercentage: common.discountPercentage,
      orderID: common.orderID,
      transactionID: common.transactionID,
      customerID: common.customerID,
      driverID: common.driverID,
      cityID: common.cityID,
      airportID: common.airportID,
      terminalID: common.terminalID,
      carID: common.carID,
      brandID: common.brandID,
      categoryID: common.categoryID,
      bookingType: common.bookingType,
      bookingNumber: common.bookingNumber,
      // Normal specific
      arrival: json['arrival']?.toString(),
      dropOffAddress: json['dropOffAddress']?.toString(),
      dropOffLat: _toDouble(json['dropOffLat']),
      dropOffLong: _toDouble(json['dropOffLong']),
      distance: json['distance']?.toString(),
      flightNumber: json['flightNumber']?.toString(),
    );
  }

  @override
  NormalBookingModel copyWith({
    String? id,
    String? category,
    CityDetails? cityData,
    AirportDetails? airportData,
    TerminalDetails? terminalData,
    CarDetails? carData,
    UserModel? customer,
    DriverDetails? driver,
    OriginalIds? originalIds,
    String? city,
    String? airport,
    String? terminal,
    double? pickupLat,
    double? pickupLong,
    String? pickupAddress,
    String? carclass,
    String? carName,
    double? charge,
    String? carbrand,
    String? carmodel,
    String? carimage,
    String? specialRequestText,
    String? specialRequestAudio,
    String? passengerCount,
    dynamic passengerNames,
    String? passengerMobile,
    String? bookingStatus,
    String? paymentStatus,
    List<String>? trackingTimeline,
    Map<String, dynamic>? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? discountPercentage,
    String? orderID,
    String? transactionID,
    String? customerID,
    String? driverID,
    String? cityID,
    String? airportID,
    String? terminalID,
    String? carID,
    String? brandID,
    String? categoryID,
    String? bookingType,
    String? bookingNumber,
    String? arrival,
    String? dropOffAddress,
    double? dropOffLat,
    double? dropOffLong,
    String? distance,
    String? flightNumber,
  }) {
    return NormalBookingModel(
      id: id ?? this.id,
      category: category ?? this.category,
      cityData: cityData ?? this.cityData,
      airportData: airportData ?? this.airportData,
      terminalData: terminalData ?? this.terminalData,
      carData: carData ?? this.carData,
      customer: customer ?? this.customer,
      driver: driver ?? this.driver,
      originalIds: originalIds ?? this.originalIds,
      city: city ?? this.city,
      airport: airport ?? this.airport,
      terminal: terminal ?? this.terminal,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLong: pickupLong ?? this.pickupLong,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      carclass: carclass ?? this.carclass,
      carName: carName ?? this.carName,
      charge: charge ?? this.charge,
      carbrand: carbrand ?? this.carbrand,
      carmodel: carmodel ?? this.carmodel,
      carimage: carimage ?? this.carimage,
      specialRequestText: specialRequestText ?? this.specialRequestText,
      specialRequestAudio: specialRequestAudio ?? this.specialRequestAudio,
      passengerCount: passengerCount ?? this.passengerCount,
      passengerNames: passengerNames ?? this.passengerNames,
      passengerMobile: passengerMobile ?? this.passengerMobile,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      trackingTimeline: trackingTimeline ?? this.trackingTimeline,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      orderID: orderID ?? this.orderID,
      transactionID: transactionID ?? this.transactionID,
      customerID: customerID ?? this.customerID,
      driverID: driverID ?? this.driverID,
      cityID: cityID ?? this.cityID,
      airportID: airportID ?? this.airportID,
      terminalID: terminalID ?? this.terminalID,
      carID: carID ?? this.carID,
      brandID: brandID ?? this.brandID,
      categoryID: categoryID ?? this.categoryID,
      bookingType: bookingType ?? this.bookingType,
      bookingNumber: bookingNumber ?? this.bookingNumber,
      arrival: arrival ?? this.arrival,
      dropOffAddress: dropOffAddress ?? this.dropOffAddress,
      dropOffLat: dropOffLat ?? this.dropOffLat,
      dropOffLong: dropOffLong ?? this.dropOffLong,
      distance: distance ?? this.distance,
      flightNumber: flightNumber ?? this.flightNumber,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'arrival': arrival,
      'dropOffAddress': dropOffAddress,
      'bookingStatus': bookingStatus,
      // ... common fields could be added but usually serialization is handled at higher level or explicitly
    };
  }
}

class HourlyBookingModel extends BookingModel {
  @override
  final String? pickupdatetime;
  @override
  final int? estimatedHours;
  @override
  final int? extraHours;
  @override
  final String? extraOrderID;
  @override
  final String? extraTransactionID;
  @override
  final double? extraPayment;
  @override
  final double? extraDiscount;
  @override
  final String? extraPaymentCompleted;

  @override
  final String? startedAt;
  @override
  final String? stoppedAt;

  HourlyBookingModel({
    required super.id,
    super.category,
    super.cityData,
    super.airportData,
    super.terminalData,
    super.carData,
    super.customer,
    super.driver,
    super.originalIds,
    super.city,
    super.airport,
    super.terminal,
    super.pickupLat,
    super.pickupLong,
    super.pickupAddress,
    super.carclass,
    super.carName,
    super.charge,
    super.carbrand,
    super.carmodel,
    super.carimage,
    super.specialRequestText,
    super.specialRequestAudio,
    super.passengerCount,
    super.passengerNames,
    super.passengerMobile,
    super.bookingStatus,
    super.paymentStatus,
    super.trackingTimeline,
    super.rating,
    super.createdAt,
    super.updatedAt,
    super.discountPercentage,
    super.orderID,
    super.transactionID,
    super.customerID,
    super.driverID,
    super.cityID,
    super.airportID,
    super.terminalID,
    super.carID,
    super.brandID,
    super.categoryID,
    super.bookingType,
    super.bookingNumber,
    this.startedAt,
    this.stoppedAt,
    this.pickupdatetime,
    this.estimatedHours,
    this.extraHours,
    this.extraOrderID,
    this.extraTransactionID,
    this.extraPayment,
    this.extraDiscount,
    this.extraPaymentCompleted,
  });

  factory HourlyBookingModel.fromMap(Map<String, dynamic> json) {
    final common = _parseCommon(json);
    return HourlyBookingModel(
      id: common.id,
      category: common.category,
      cityData: common.cityData,
      airportData: common.airportData,
      terminalData: common.terminalData,
      carData: common.carData,
      customer: common.customer,
      driver: common.driver,
      originalIds: common.originalIds,
      city: common.city,
      airport: common.airport,
      terminal: common.terminal,
      pickupLat: common.pickupLat,
      pickupLong: common.pickupLong,
      pickupAddress: common.pickupAddress,
      carclass: common.carclass,
      carName: common.carName,
      charge: common.charge,
      carbrand: common.carbrand,
      carmodel: common.carmodel,
      carimage: common.carimage,
      specialRequestText: common.specialRequestText,
      specialRequestAudio: common.specialRequestAudio,
      passengerCount: common.passengerCount,
      passengerNames: common.passengerNames,
      passengerMobile: common.passengerMobile,
      bookingStatus: common.bookingStatus,
      paymentStatus: common.paymentStatus,
      trackingTimeline: common.trackingTimeline,
      rating: common.rating,
      createdAt: common.createdAt,
      updatedAt: common.updatedAt,
      discountPercentage: common.discountPercentage,
      orderID: common.orderID,
      transactionID: common.transactionID,
      customerID: common.customerID,
      driverID: common.driverID,
      cityID: common.cityID,
      airportID: common.airportID,
      terminalID: common.terminalID,
      carID: common.carID,
      brandID: common.brandID,
      categoryID: common.categoryID,
      bookingType: common.bookingType,
      bookingNumber: common.bookingNumber?.toString() ?? json['bookingID']?.toString(),
      // Specialized fields
      startedAt: json['startedAt']?.toString(),
      stoppedAt: json['stoppedAt']?.toString(),
      pickupdatetime: json['pickupdatetime']?.toString() ?? json['pickupDateTime']?.toString() ?? json['startedAt']?.toString(),
      estimatedHours: _toInt(json['estimatedHours'] ?? json['hours']),
      extraHours: _toInt(json['extraHours']),
      extraOrderID: json['extraOrderID']?.toString(),
      extraTransactionID: json['extraTransactionID']?.toString(),
      extraPayment: _toDouble(json['extraPayment']),
      extraDiscount: _toDouble(json['extraDiscount']),
      extraPaymentCompleted: json['extraPaymentCompleted']?.toString(),
    );
  }

  @override
  HourlyBookingModel copyWith({
    String? id,
    String? category,
    CityDetails? cityData,
    AirportDetails? airportData,
    TerminalDetails? terminalData,
    CarDetails? carData,
    UserModel? customer,
    DriverDetails? driver,
    OriginalIds? originalIds,
    String? city,
    String? airport,
    String? terminal,
    double? pickupLat,
    double? pickupLong,
    String? pickupAddress,
    String? carclass,
    String? carName,
    double? charge,
    String? carbrand,
    String? carmodel,
    String? carimage,
    String? specialRequestText,
    String? specialRequestAudio,
    String? passengerCount,
    dynamic passengerNames,
    String? passengerMobile,
    String? bookingStatus,
    String? paymentStatus,
    List<String>? trackingTimeline,
    Map<String, dynamic>? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? discountPercentage,
    String? orderID,
    String? transactionID,
    String? customerID,
    String? driverID,
    String? cityID,
    String? airportID,
    String? terminalID,
    String? carID,
    String? brandID,
    String? categoryID,
    String? bookingType,
    String? bookingNumber,
    String? startedAt,
    String? stoppedAt,
    String? pickupdatetime,
    int? estimatedHours,
    int? extraHours,
    String? extraOrderID,
    String? extraTransactionID,
    double? extraPayment,
    double? extraDiscount,
    String? extraPaymentCompleted,
  }) {
    return HourlyBookingModel(
      id: id ?? this.id,
      category: category ?? this.category,
      cityData: cityData ?? this.cityData,
      airportData: airportData ?? this.airportData,
      terminalData: terminalData ?? this.terminalData,
      carData: carData ?? this.carData,
      customer: customer ?? this.customer,
      driver: driver ?? this.driver,
      originalIds: originalIds ?? this.originalIds,
      city: city ?? this.city,
      airport: airport ?? this.airport,
      terminal: terminal ?? this.terminal,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLong: pickupLong ?? this.pickupLong,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      carclass: carclass ?? this.carclass,
      carName: carName ?? this.carName,
      charge: charge ?? this.charge,
      carbrand: carbrand ?? this.carbrand,
      carmodel: carmodel ?? this.carmodel,
      carimage: carimage ?? this.carimage,
      specialRequestText: specialRequestText ?? this.specialRequestText,
      specialRequestAudio: specialRequestAudio ?? this.specialRequestAudio,
      passengerCount: passengerCount ?? this.passengerCount,
      passengerNames: passengerNames ?? this.passengerNames,
      passengerMobile: passengerMobile ?? this.passengerMobile,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      trackingTimeline: trackingTimeline ?? this.trackingTimeline,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      orderID: orderID ?? this.orderID,
      transactionID: transactionID ?? this.transactionID,
      customerID: customerID ?? this.customerID,
      driverID: driverID ?? this.driverID,
      cityID: cityID ?? this.cityID,
      airportID: airportID ?? this.airportID,
      terminalID: terminalID ?? this.terminalID,
      carID: carID ?? this.carID,
      brandID: brandID ?? this.brandID,
      categoryID: categoryID ?? this.categoryID,
      bookingType: bookingType ?? this.bookingType,
      bookingNumber: bookingNumber ?? this.bookingNumber,
      startedAt: startedAt ?? this.startedAt,
      stoppedAt: stoppedAt ?? this.stoppedAt,
      pickupdatetime: pickupdatetime ?? this.pickupdatetime,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      extraHours: extraHours ?? this.extraHours,
      extraOrderID: extraOrderID ?? this.extraOrderID,
      extraTransactionID: extraTransactionID ?? this.extraTransactionID,
      extraPayment: extraPayment ?? this.extraPayment,
      extraDiscount: extraDiscount ?? this.extraDiscount,
      extraPaymentCompleted: extraPaymentCompleted ?? this.extraPaymentCompleted,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingNumber': bookingNumber,
      'startedAt': startedAt,
      'stoppedAt': stoppedAt,
      'pickupdatetime': pickupdatetime,
      'estimatedHours': estimatedHours,
      'bookingStatus': bookingStatus,
    };
  }
}

// ── Shared Helper Logic ───────────────────────────────────────────────────────

class _CommonBookingFields {
  final String id;
  final String? category;
  final CityDetails? cityData;
  final AirportDetails? airportData;
  final TerminalDetails? terminalData;
  final CarDetails? carData;
  final UserModel? customer;
  final DriverDetails? driver;
  final OriginalIds? originalIds;
  final String? city;
  final String? airport;
  final String? terminal;
  final double? pickupLat;
  final double? pickupLong;
  final String? pickupAddress;
  final String? carclass;
  final String? carName;
  final double? charge;
  final String? carbrand;
  final String? carmodel;
  final String? carimage;
  final String? specialRequestText;
  final String? specialRequestAudio;
  final String? passengerCount;
  final dynamic passengerNames;
  final String? passengerMobile;
  final String? bookingStatus;
  final String? paymentStatus;
  final List<String>? trackingTimeline;
  final Map<String, dynamic>? rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? discountPercentage;
  final String? orderID;
  final String? transactionID;
  final String? customerID;
  final String? driverID;
  final String? cityID;
  final String? airportID;
  final String? terminalID;
  final String? carID;
  final String? brandID;
  final String? categoryID;
  final String? bookingType;
  final String? bookingNumber;

  _CommonBookingFields({
    required this.id,
    this.category,
    this.cityData,
    this.airportData,
    this.terminalData,
    this.carData,
    this.customer,
    this.driver,
    this.originalIds,
    this.city,
    this.airport,
    this.terminal,
    this.pickupLat,
    this.pickupLong,
    this.pickupAddress,
    this.carclass,
    this.carName,
    this.charge,
    this.carbrand,
    this.carmodel,
    this.carimage,
    this.specialRequestText,
    this.specialRequestAudio,
    this.passengerCount,
    this.passengerNames,
    this.passengerMobile,
    this.bookingStatus,
    this.paymentStatus,
    this.trackingTimeline,
    this.rating,
    this.createdAt,
    this.updatedAt,
    this.discountPercentage,
    this.orderID,
    this.transactionID,
    this.customerID,
    this.driverID,
    this.cityID,
    this.airportID,
    this.terminalID,
    this.carID,
    this.brandID,
    this.categoryID,
    this.bookingType,
    this.bookingNumber,
  });
}

_CommonBookingFields _parseCommon(Map<String, dynamic> json) {
  // Shared parsing logic for common nested objects
  final cityDetails = (json['city'] ?? json['cityID']) is Map<String, dynamic>
      ? CityDetails.fromJson(json['city'] ?? json['cityID'])
      : null;
  final airportDetails = (json['airport'] ?? json['airportID']) is Map<String, dynamic>
      ? AirportDetails.fromJson(json['airport'] ?? json['airportID'])
      : null;
  final terminalDetails = (json['terminal'] ?? json['terminalID']) is Map<String, dynamic>
      ? TerminalDetails.fromJson(json['terminal'] ?? json['terminalID'])
      : null;

  final carMap = json['car'] ?? json['carID'];
  final carDetails = carMap is Map<String, dynamic>
      ? CarDetails.fromJson({
          ...carMap,
          'carImage': json['carImage'] ?? carMap['carImage'],
          'model': json['model'] ?? carMap['model'],
          'brand': json['brandID'] ?? carMap['brand'],
          'category': json['categoryID'] ?? carMap['category'],
          'numberOfPassengers': json['passsenrgersCount'] ?? json['passengerCount'] ?? carMap['numberOfPassengers'],
          'carName': json['model'] ?? json['carClass'] ?? carMap['carName'],
        })
      : null;

  final customerObj = json['customer'] is Map<String, dynamic>
      ? UserModel.fromJson(json['customer'])
      : (json['customerID'] is Map<String, dynamic> ? UserModel.fromJson(json['customerID']) : null);
  final driverObj = json['driver'] is Map<String, dynamic>
      ? DriverDetails.fromJson(json['driver'])
      : (json['driverID'] is Map<String, dynamic> ? DriverDetails.fromJson(json['driverID']) : null);
  final originalIdsObj = json['originalIds'] is Map<String, dynamic> ? OriginalIds.fromJson(json['originalIds']) : null;

  String? payStatus;
  if (json['paymentStatus'] is bool) {
    payStatus = (json['paymentStatus'] as bool) ? 'Paid' : 'Unpaid';
  } else {
    payStatus = json['paymentStatus']?.toString();
  }

  final bool isHourlyDetected = (json['bookingType'] ?? json['booking_type'])?.toString().toLowerCase() == 'hourly' || json['hours'] != null || json['estimatedHours'] != null;
  final String? baseCategory = isHourlyDetected 
      ? (json['bookingType'] ?? json['booking_type'])?.toString() 
      : (json['category'] is Map 
          ? (json['category']['name'] ?? json['category']['categoryName'] ?? json['category']['displayName']) 
          : (json['categoryID'] is Map 
              ? (json['categoryID']['name'] ?? json['categoryID']['categoryName'] ?? json['categoryID']['displayName']) 
              : json['category']))?.toString();

  return _CommonBookingFields(
    id: json['_id'] ?? json['id'] ?? '',
    category: baseCategory ?? carDetails?.categoryName,
    cityData: cityDetails,
    airportData: airportDetails,
    terminalData: terminalDetails,
    carData: carDetails,
    customer: customerObj,
    driver: driverObj,
    originalIds: originalIdsObj,
    city: cityDetails?.cityName ?? json['city']?.toString(),
    airport: airportDetails?.airportName ?? json['airport']?.toString(),
    terminal: terminalDetails?.terminalName ?? json['terminal']?.toString(),
    pickupLat: _toDouble(json['pickupLat'] ?? json['pickuplat']),
    pickupLong: _toDouble(json['pickupLong'] ?? json['pickuplong']),
    pickupAddress: json['pickupAddress']?.toString() ?? json['pickupAdddress']?.toString(),
    carclass: json['carclass']?.toString() ?? carDetails?.categoryName,
    carName: json['model']?.toString() ?? json['carName']?.toString() ?? carDetails?.carName ?? (json['vehicleID'] is Map ? json['vehicleID']['carName']?.toString() : null),
    charge: _toDouble(json['charge']),
    carbrand: json['carbrand']?.toString() ?? (json['brandID'] is Map ? (json['brandID']['brandName'] ?? json['brandID']['name'])?.toString() : (json['brand'] is Map ? (json['brand']['brandName'] ?? json['brand']['name'])?.toString() : json['brand']?.toString())) ?? carDetails?.brandName,
    carmodel: json['model']?.toString() ?? json['carmodel']?.toString() ?? carDetails?.model,
    carimage: (json['carimage'] is Map ? json['carimage']['url'] : (json['carImage'] is Map ? json['carImage']['url'] : (json['image'] is Map ? json['image']['url'] : (json['carimage'] ?? json['carImage'] ?? json['image']))))?.toString(),
    specialRequestText: json['specialRequestText']?.toString(),
    specialRequestAudio: json['specialRequestAudio']?.toString(),
    passengerCount: json['passsenrgersCount']?.toString() ?? json['passengerCount']?.toString() ?? carDetails?.numberOfPassengers?.toString(),
    passengerNames: json['passengerNames'],
    passengerMobile: json['passengerMobile']?.toString(),
    bookingStatus: json['bookingStatus']?.toString() ?? json['status']?.toString(),
    paymentStatus: payStatus,
    trackingTimeline: json['TrackingTimeLine'] != null ? List<String>.from(json['TrackingTimeLine']) : null,
    rating: (json['rating'] is Map<String, dynamic> && (json['rating']['rate'] != null && json['rating']['rate'] != 0)) ? json['rating'] : null,
    createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    discountPercentage: _toDouble(json['discountPercentage']),
    orderID: json['orderID']?.toString(),
    transactionID: json['transactionID']?.toString(),
    customerID: customerObj?.uid ?? originalIdsObj?.customerID ?? (json['customerID'] is Map ? (json['customerID']['_id'] ?? json['customerID']['id'] ?? '').toString() : json['customerID']?.toString()),
    driverID: originalIdsObj?.driverID ?? (json['driverID'] is Map ? (json['driverID']['_id'] ?? json['driverID']['id'] ?? '').toString() : json['driverID']?.toString()),
    cityID: originalIdsObj?.cityID ?? json['cityID']?.toString(),
    airportID: originalIdsObj?.airportID ?? json['airportID']?.toString(),
    terminalID: originalIdsObj?.terminalID ?? json['terminalID']?.toString(),
    carID: originalIdsObj?.carID ?? json['carID']?.toString(),
    brandID: originalIdsObj?.brandID ?? json['brandID']?.toString() ?? carDetails?.brandID,
    categoryID: json['categoryID']?.toString() ?? carDetails?.categoryID,
    bookingType: json['bookingType']?.toString() ?? json['booking_type']?.toString(),
    bookingNumber: json['bookingNumber']?.toString() ?? json['bookingID']?.toString(),
  );
}

double? _toDouble(dynamic val) {
  if (val == null) return null;
  return double.tryParse(val.toString());
}

int? _toInt(dynamic val) {
  if (val == null) return null;
  return int.tryParse(val.toString());
}

class CityDetails {
  final String id;
  final String cityName;
  final String? imageUrl;
  final bool isActive;

  CityDetails({
    required this.id,
    required this.cityName,
    this.imageUrl,
    this.isActive = true,
  });

  factory CityDetails.fromJson(Map<String, dynamic> json) {
    return CityDetails(
      id: json['_id'] ?? '',
      cityName: json['cityName'] ?? '',
      imageUrl: json['image'] is Map ? json['image']['url'] : null,
      isActive: json['isActive'] ?? true,
    );
  }
}

class AirportDetails {
  final String id;
  final String airportName;
  final bool isActive;
  final String? cityId;

  AirportDetails({
    required this.id,
    required this.airportName,
    this.isActive = true,
    this.cityId,
  });

  factory AirportDetails.fromJson(Map<String, dynamic> json) {
    return AirportDetails(
      id: json['_id'] ?? '',
      airportName: json['airportName'] ?? '',
      isActive: json['isActive'] ?? true,
      cityId: json['cityID'] is Map ? json['cityID']['_id'] : (json['cityID']?.toString()),
    );
  }
}

class TerminalDetails {
  final String id;
  final String terminalName;
  final bool isActive;

  TerminalDetails({
    required this.id,
    required this.terminalName,
    this.isActive = true,
  });

  factory TerminalDetails.fromJson(Map<String, dynamic> json) {
    return TerminalDetails(
      id: json['_id'] ?? '',
      terminalName: json['terminalName'] ?? '',
      isActive: json['isActive'] ?? true,
    );
  }
}

class CarDetails {
  final String id;
  final String? carName;
  final String? model;
  final int? numberOfPassengers;
  final String? carImageUrl;
  final String? brandName;
  final String? brandID;
  final String? categoryName;
  final String? categoryID;

  CarDetails({
    required this.id,
    this.carName,
    this.model,
    this.numberOfPassengers,
    this.carImageUrl,
    this.brandName,
    this.brandID,
    this.categoryName,
    this.categoryID,
  });

  factory CarDetails.fromJson(Map<String, dynamic> json) {
    String? bName;
    String? bID;
    if (json['brand'] is Map) {
      bName = json['brand']['brandName'] ?? json['brand']['name'];
      bID = (json['brand']['_id'] ?? json['brand']['id'])?.toString();
    } else if (json['brandDetails'] is Map) {
      bName = json['brandDetails']['brandName'];
      bID = (json['brandDetails']['_id'] ?? json['brandDetails']['id'])?.toString();
    } else if (json['brandID'] is Map) {
      bName = json['brandID']['brandName'];
      bID = (json['brandID']['_id'] ?? json['brandID']['id'])?.toString();
    }

    String? cName;
    String? cID;
    if (json['category'] is Map) {
      cName = json['category']['categoryName'] ?? json['category']['name'] ?? json['category']['displayName'];
      cID = (json['category']['_id'] ?? json['category']['id'])?.toString();
    } else if (json['categoryDetails'] is Map) {
      cName = json['categoryDetails']['categoryName'] ?? json['categoryDetails']['name'] ?? json['categoryDetails']['displayName'];
      cID = (json['categoryDetails']['_id'] ?? json['categoryDetails']['id'])?.toString();
    } else if (json['categoryID'] is Map) {
      cName = json['categoryID']['categoryName'] ?? json['categoryID']['name'] ?? json['categoryID']['displayName'];
      cID = (json['categoryID']['_id'] ?? json['categoryID']['id'])?.toString();
    }

    return CarDetails(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      carName: json['carName']?.toString(),
      model: json['model']?.toString(),
      numberOfPassengers: json['numberOfPassengers'] is int ? json['numberOfPassengers'] : int.tryParse(json['numberOfPassengers']?.toString() ?? ''),
      carImageUrl: (json['carImage'] is Map ? json['carImage']['url'] : (json['image'] is Map ? json['image']['url'] : (json['carimage'] ?? json['carImage'] ?? json['image'])))?.toString(),
      brandName: bName?.toString(),
      brandID: bID,
      categoryName: cName?.toString() ?? json['carCategory']?.toString() ?? json['carClass']?.toString(),
      categoryID: cID,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'carName': carName,
      'model': model,
      'numberOfPassengers': numberOfPassengers,
      'carImageUrl': carImageUrl,
      'brandName': brandName,
      'brandID': brandID,
      'categoryName': categoryName,
      'categoryID': categoryID,
    };
  }
}

class OriginalIds {
  final String? cityID;
  final String? airportID;
  final String? terminalID;
  final String? carID;
  final String? customerID;
  final String? driverID;
  final String? brandID;

  OriginalIds({
    this.cityID,
    this.airportID,
    this.terminalID,
    this.carID,
    this.customerID,
    this.driverID,
    this.brandID,
  });

  factory OriginalIds.fromJson(Map<String, dynamic> json) {
    return OriginalIds(
      cityID: json['cityID']?.toString(),
      airportID: json['airportID']?.toString(),
      terminalID: json['terminalID']?.toString(),
      carID: json['carID']?.toString(),
      customerID: json['customerID']?.toString(),
      driverID: json['driverID']?.toString(),
      brandID: json['brandID']?.toString(),
    );
  }
}

class DriverDetails {
  final String? driverName;
  final String? phoneNumber;
  final String? countryCode;
  final String? licenseNumber;
  final String? profileImageUrl;
  final double? rating;

  DriverDetails({
    this.driverName,
    this.phoneNumber,
    this.countryCode,
    this.licenseNumber,
    this.profileImageUrl,
    this.rating,
  });

  factory DriverDetails.fromJson(Map<String, dynamic> json) {
    return DriverDetails(
      driverName: (json['driverName'] ?? json['name'] ?? json['username'])?.toString(),
      phoneNumber: (json['phoneNumber'] ?? json['phone'])?.toString(),
      countryCode: json['countryCode']?.toString(),
      licenseNumber: (json['licenseNumber'] ?? json['specialId'])?.toString(),
      profileImageUrl: json['profileImage'] is Map<String, dynamic> ? json['profileImage']['url']?.toString() : (json['profileImage']?.toString()),
      rating: json['rating'] != null ? double.tryParse(json['rating'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driverName': driverName,
      'phoneNumber': phoneNumber,
      'countryCode': countryCode,
      'licenseNumber': licenseNumber,
      'profileImageUrl': profileImageUrl,
      'rating': rating,
    };
  }
}
