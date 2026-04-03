import 'user.dart';

class BookingModel {
  final String id;
  final String? category;

  // Nested Objects from newer API response
  final CityDetails? cityData;
  final AirportDetails? airportData;
  final TerminalDetails? terminalData;
  final CarDetails? carData;
  final UserModel? customer;
  final DriverDetails? driver;
  final OriginalIds? originalIds;

  // Legacy/Flattened fields for backward compatibility and direct access
  final String? city;
  final String? airport;
  final String? terminal;
  final String? arrival; // ISO 8601 DateTime string
  final String? pickupdatetime; // ISO 8601 DateTime string
  final double? pickupLat;
  final double? pickupLong;
  final double? dropOffLat;
  final double? dropOffLong;
  final String? pickupAddress;
  final String? dropOffAddress;
  final String? carclass;
  final String? carName;
  final double? charge;
  final String? carbrand;
  final String? carmodel;
  final String? carimage; // Now a String (URL) from response
  final String? specialRequestText;
  final String? specialRequestAudio; // Now a String (URL) from response
  final String? passengerCount;
  final dynamic passengerNames; // Can be String or List
  final String? passengerMobile;
  final String? distance;
  final String? bookingStatus;
  final String? paymentStatus; // Handled as String for UI display
  final String? flightNumber;
  final int? serviceDuration;
  final int? estimatedHours;
  final int? extraHours; // > 0 when driver ran over booked hours
  final List<String>? trackingTimeline;
  final Map<String, dynamic>? rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? discountPercentage;
  final String? orderID;
  final String? transactionID;

  // IDs (sometimes redundant with originalIds but kept for compatibility)
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
    this.city,
    this.airport,
    this.terminal,
    this.cityData,
    this.airportData,
    this.terminalData,
    this.carData,
    this.customer,
    this.driver,
    this.originalIds,
    this.arrival,
    this.pickupdatetime,
    this.pickupLat,
    this.pickupLong,
    this.dropOffLat,
    this.dropOffLong,
    this.pickupAddress,
    this.dropOffAddress,
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
    this.distance,
    this.customerID,
    this.driverID,
    this.bookingStatus,
    this.paymentStatus,
    this.cityID,
    this.airportID,
    this.terminalID,
    this.flightNumber,
    this.carID,
    this.brandID,
    this.categoryID,
    this.serviceDuration,
    this.estimatedHours,
    this.extraHours,
    this.trackingTimeline,
    this.rating,
    this.createdAt,
    this.updatedAt,
    this.discountPercentage,
    this.orderID,
    this.transactionID,
    this.bookingType,
    this.bookingNumber,
  });

  String get displayBrand {
    if (carData != null && carData!.brandName != null)
      return carData!.brandName!;
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
    if (carData != null && carData!.categoryName != null)
      return carData!.categoryName!;
    return 'N/A';
  }

  String? get displayDriverName {
    if (driver != null &&
        driver!.driverName != null &&
        driver!.driverName!.isNotEmpty) {
      return driver!.driverName!;
    }
    return null;
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    // Helper to parse nested objects
    final cityDetails = (json['city'] ?? json['cityID']) is Map<String, dynamic>
        ? CityDetails.fromJson(json['city'] ?? json['cityID'])
        : null;
    final airportDetails =
        (json['airport'] ?? json['airportID']) is Map<String, dynamic>
        ? AirportDetails.fromJson(json['airport'] ?? json['airportID'])
        : null;
    final terminalDetails =
        (json['terminal'] ?? json['terminalID']) is Map<String, dynamic>
        ? TerminalDetails.fromJson(json['terminal'] ?? json['terminalID'])
        : null;

    // Hourly bookings use 'carID' as the vehicle object; normal bookings use 'car'
    final carMap = json['car'] ?? json['carID'];
    final carDetails = carMap is Map<String, dynamic>
        ? CarDetails.fromJson({
            ...carMap,
            // Merge root level fields that hourly booking provides
            'carImage': json['carImage'] ?? carMap['carImage'],
            'model': json['model'] ?? carMap['model'],
            'brand': json['brandID'] ?? carMap['brand'],
            'category': json['categoryID'] ?? carMap['category'],
            'numberOfPassengers':
                json['passsenrgersCount'] ??
                json['passengerCount'] ??
                carMap['numberOfPassengers'],
            'carName': json['model'] ?? json['carClass'] ?? carMap['carName'],
          })
        : null;

    final customerObj = json['customer'] is Map<String, dynamic>
        ? UserModel.fromJson(json['customer'])
        : (json['customerID'] is Map<String, dynamic>
              ? UserModel.fromJson(json['customerID'])
              : null);
    final driverObj = json['driver'] is Map<String, dynamic>
        ? DriverDetails.fromJson(json['driver'])
        : (json['driverID'] is Map<String, dynamic>
              ? DriverDetails.fromJson(json['driverID'])
              : null);
    final originalIdsObj = json['originalIds'] is Map<String, dynamic>
        ? OriginalIds.fromJson(json['originalIds'])
        : null;

    // Handle payment status which could be bool or String
    String? payStatus;
    if (json['paymentStatus'] is bool) {
      payStatus = (json['paymentStatus'] as bool) ? 'Paid' : 'Unpaid';
    } else {
      payStatus = json['paymentStatus']?.toString();
    }

    return BookingModel(
      id: json['_id'] ?? json['id'] ?? '',
      category:
          (json['category'] is Map
                  ? (json['category']['name'] ??
                        json['category']['categoryName'] ??
                        json['category']['displayName'])
                  : (json['categoryID'] is Map
                        ? (json['categoryID']['name'] ??
                              json['categoryID']['categoryName'] ??
                              json['categoryID']['displayName'])
                        : json['category']))
              ?.toString() ??
          carDetails?.categoryName,
      bookingType:
          json['bookingType']?.toString() ?? json['booking_type']?.toString(),
      bookingNumber:
          json['bookingNumber']?.toString() ?? json['bookingID']?.toString(),
      cityData: cityDetails,
      airportData: airportDetails,
      terminalData: terminalDetails,
      carData: carDetails,
      customer: customerObj,
      driver: driverObj,
      originalIds: originalIdsObj,

      // Fallback to extraction from nested objects if flat fields are missing/null
      city: cityDetails?.cityName ?? json['city']?.toString(),
      airport: airportDetails?.airportName ?? json['airport']?.toString(),
      terminal: terminalDetails?.terminalName ?? json['terminal']?.toString(),

      arrival: json['arrival']?.toString(),
      pickupdatetime:
          json['pickupdatetime']?.toString() ??
          json['pickupDateTime']?.toString() ??
          json['startedAt']?.toString(),
      pickupLat: (json['pickupLat'] ?? json['pickuplat']) != null
          ? double.tryParse(json['pickupLat'].toString())
          : null,
      pickupLong: (json['pickupLong'] ?? json['pickuplong']) != null
          ? double.tryParse(json['pickupLong'].toString())
          : null,
      dropOffLat: json['dropOffLat'] != null
          ? double.tryParse(json['dropOffLat'].toString())
          : null,
      dropOffLong: json['dropOffLong'] != null
          ? double.tryParse(json['dropOffLong'].toString())
          : null,
      dropOffAddress: json['dropOffAddress']?.toString(),
      pickupAddress:
          json['pickupAddress']?.toString() ??
          json['pickupAdddress']?.toString(),

      carclass: json['carclass']?.toString() ?? carDetails?.categoryName,
      carName:
          json['model']?.toString() ??
          json['carName']?.toString() ??
          carDetails?.carName ??
          (json['vehicleID'] is Map
              ? json['vehicleID']['carName']?.toString()
              : null),
      charge: json['charge'] != null
          ? double.tryParse(json['charge'].toString())
          : null,
      carbrand:
          json['carbrand']?.toString() ??
          (json['brandID'] is Map
              ? (json['brandID']['brandName'] ?? json['brandID']['name'])
                    ?.toString()
              : (json['brand'] is Map
                    ? (json['brand']['brandName'] ?? json['brand']['name'])
                          ?.toString()
                    : json['brand']?.toString())) ??
          carDetails?.brandName,
      carmodel:
          json['model']?.toString() ??
          json['carmodel']?.toString() ??
          carDetails?.model,
      carimage:
          json['carImage']?.toString() ??
          (json['carimage'] is Map
                  ? json['carimage']['url']
                  : (json['carImage'] is Map
                        ? json['carImage']['url']
                        : (json['image'] is Map
                              ? json['image']['url']
                              : (json['carimage'] ??
                                    json['carImage'] ??
                                    json['image']))))
              ?.toString() ??
          carDetails?.carImageUrl,

      specialRequestText: json['specialRequestText']?.toString(),
      specialRequestAudio: json['specialRequestAudio']?.toString(),
      passengerCount:
          json['passsenrgersCount']?.toString() ??
          json['passengerCount']?.toString() ??
          carDetails?.numberOfPassengers?.toString(),
      passengerNames: json['passengerNames'],
      passengerMobile: json['passengerMobile']?.toString(),
      distance: json['distance']?.toString(),

      customerID:
          customerObj?.uid ??
          originalIdsObj?.customerID ??
          (json['customerID'] is Map
              ? (json['customerID']['_id'] ?? json['customerID']['id'] ?? '')
                    .toString()
              : json['customerID']?.toString()),
      driverID:
          originalIdsObj?.driverID ??
          (json['driverID'] is Map
              ? (json['driverID']['_id'] ?? json['driverID']['id'] ?? '')
                    .toString()
              : json['driverID']?.toString()),

      bookingStatus:
          json['bookingStatus']?.toString() ?? json['status']?.toString(),
      paymentStatus: payStatus,

      cityID: originalIdsObj?.cityID ?? json['cityID']?.toString(),
      airportID: originalIdsObj?.airportID ?? json['airportID']?.toString(),
      terminalID: originalIdsObj?.terminalID ?? json['terminalID']?.toString(),
      carID: originalIdsObj?.carID ?? json['carID']?.toString(),
      brandID:
          originalIdsObj?.brandID ??
          json['brandID']?.toString() ??
          carDetails?.brandID,
      categoryID: json['categoryID']?.toString() ?? carDetails?.categoryID,

      flightNumber: json['flightNumber']?.toString(),
      serviceDuration: json['serviceDuration'] != null
          ? int.tryParse(json['serviceDuration'].toString())
          : null,
      estimatedHours: json['estimatedHours'] != null
          ? int.tryParse(json['estimatedHours'].toString())
          : (json['hours'] != null
                ? int.tryParse(json['hours'].toString())
                : null),
      extraHours: json['extraHours'] != null
          ? int.tryParse(json['extraHours'].toString())
          : null,

      trackingTimeline: json['TrackingTimeLine'] != null
          ? List<String>.from(json['TrackingTimeLine'])
          : null,
      rating: json['rating'] is Map<String, dynamic> ? json['rating'] : null,

      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      discountPercentage: json['discountPercentage'] != null
          ? double.tryParse(json['discountPercentage'].toString())
          : null,
      orderID: json['orderID']?.toString(),
      transactionID: json['transactionID']?.toString(),
    );
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
    String? arrival,
    String? pickupdatetime,
    double? pickupLat,
    double? pickupLong,
    double? dropOffLat,
    double? dropOffLong,
    String? pickupAddress,
    String? dropOffAddress,
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
    String? distance,
    String? bookingStatus,
    String? paymentStatus,
    String? flightNumber,
    int? serviceDuration,
    int? estimatedHours,
    int? extraHours,
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
  }) {
    return BookingModel(
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
      arrival: arrival ?? this.arrival,
      pickupdatetime: pickupdatetime ?? this.pickupdatetime,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLong: pickupLong ?? this.pickupLong,
      dropOffLat: dropOffLat ?? this.dropOffLat,
      dropOffLong: dropOffLong ?? this.dropOffLong,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropOffAddress: dropOffAddress ?? this.dropOffAddress,
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
      distance: distance ?? this.distance,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      flightNumber: flightNumber ?? this.flightNumber,
      serviceDuration: serviceDuration ?? this.serviceDuration,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      extraHours: extraHours ?? this.extraHours,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'city': city,
      'airport': airport,
      'terminal': terminal,
      'arrival': arrival,
      'pickupLat': pickupLat,
      'pickupLong': pickupLong,
      'dropOffLat': dropOffLat,
      'dropOffLong': dropOffLong,
      'dropOffAddress': dropOffAddress,
      'carclass': carclass,
      'carName': carName,
      'charge': charge,
      'carbrand': carbrand,
      'carmodel': carmodel,
      'carimage': carimage,
      'specialRequestText': specialRequestText,
      'specialRequestAudio': specialRequestAudio,
      'passengerCount': passengerCount,
      'passengerNames': passengerNames,
      'passengerMobile': passengerMobile,
      'distance': distance,
      'customerID': customerID,
      'driverID': driverID,
      'bookingStatus': bookingStatus,
      'paymentStatus': paymentStatus,
      'cityID': cityID,
      'airportID': airportID,
      'terminalID': terminalID,
      'flightNumber': flightNumber,
      'carID': carID,
      'brandID': brandID,
      'categoryID': categoryID,
      'serviceDuration': serviceDuration,
      'estimatedHours': estimatedHours,
      'extraHours': extraHours,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'pickupdatetime': pickupdatetime,
      'discountPercentage': discountPercentage,
      'orderID': orderID,
      'transactionID': transactionID,
      'bookingType': bookingType,
      'bookingNumber': bookingNumber,
    };
  }
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
      cityId: json['cityID'] is Map
          ? json['cityID']['_id']
          : (json['cityID']?.toString()),
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
    // Handle nested brand
    String? bName;
    String? bID;
    if (json['brand'] is Map) {
      bName = json['brand']['brandName'] ?? json['brand']['name'];
      bID = (json['brand']['_id'] ?? json['brand']['id'])?.toString();
    } else if (json['brandDetails'] is Map) {
      bName = json['brandDetails']['brandName'];
      bID = (json['brandDetails']['_id'] ?? json['brandDetails']['id'])
          ?.toString();
    } else if (json['brandID'] is Map) {
      bName = json['brandID']['brandName'];
      bID = (json['brandID']['_id'] ?? json['brandID']['id'])?.toString();
    }

    // Handle nested category
    String? cName;
    String? cID;
    if (json['category'] is Map) {
      cName =
          json['category']['categoryName'] ??
          json['category']['name'] ??
          json['category']['displayName'];
      cID = (json['category']['_id'] ?? json['category']['id'])?.toString();
    } else if (json['categoryDetails'] is Map) {
      cName =
          json['categoryDetails']['categoryName'] ??
          json['categoryDetails']['name'] ??
          json['categoryDetails']['displayName'];
      cID =
          (json['categoryDetails']['_id'] ?? json['categoryDetails']['id'])
              ?.toString();
    } else if (json['categoryID'] is Map) {
      cName =
          json['categoryID']['categoryName'] ??
          json['categoryID']['name'] ??
          json['categoryID']['displayName'];
      cID = (json['categoryID']['_id'] ?? json['categoryID']['id'])?.toString();
    }

    return CarDetails(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      carName: json['carName']?.toString(),
      model: json['model']?.toString(),
      numberOfPassengers: json['numberOfPassengers'] is int
          ? json['numberOfPassengers']
          : int.tryParse(json['numberOfPassengers']?.toString() ?? ''),
      carImageUrl:
          (json['carImage'] is Map
                  ? json['carImage']['url']
                  : (json['image'] is Map
                        ? json['image']['url']
                        : (json['carimage'] ??
                              json['carImage'] ??
                              json['image'])))
              ?.toString(),
      brandName: bName?.toString(),
      brandID: bID,
      categoryName: cName?.toString(),
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
      driverName: (json['driverName'] ?? json['name'] ?? json['username'])
          ?.toString(),
      phoneNumber: (json['phoneNumber'] ?? json['phone'])?.toString(),
      countryCode: json['countryCode']?.toString(),
      licenseNumber: (json['licenseNumber'] ?? json['specialId'])?.toString(),
      profileImageUrl: json['profileImage'] is Map<String, dynamic>
          ? json['profileImage']['url']?.toString()
          : (json['profileImage']?.toString()),
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString())
          : null,
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
