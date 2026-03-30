
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
  final UserModel? driver;
  final OriginalIds? originalIds;

  // Legacy/Flattened fields for backward compatibility and direct access
  final String? city;
  final String? airport;
  final String? terminal;
  final String? arrival; // ISO 8601 DateTime string
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
  final List<String>? trackingTimeline;
  final Map<String, dynamic>? rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // IDs (sometimes redundant with originalIds but kept for compatibility)
  final String? customerID;
  final String? driverID;
  final String? cityID;
  final String? airportID;
  final String? terminalID;
  final String? carID;
  final String? brandID;
  final String? categoryID;

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
    this.trackingTimeline,
    this.rating,
    this.createdAt,
    this.updatedAt,
  });

  String get displayBrand {
    if (carbrand != null && carbrand!.isNotEmpty) return carbrand!;
    if (carData != null && carData!.brandName != null) return carData!.brandName!;
    return 'N/A';
  }

  String get displayName {
    if (estimatedHours != null) {
      final name = carName ?? carData?.carName ?? '';
      return '$name ($estimatedHours Hours)'.trim();
    }
    if (carName != null && carName!.isNotEmpty) return carName!;
    if (carData != null && carData!.carName != null) return carData!.carName!;
    if (carbrand != null || carmodel != null) {
      return '${carbrand ?? ''} ${carmodel ?? ''}'.trim();
    }
    return 'N/A';
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    // Helper to parse nested objects
    final cityDetails = json['city'] is Map<String, dynamic> 
        ? CityDetails.fromJson(json['city']) 
        : null;
    final airportDetails = json['airport'] is Map<String, dynamic> 
        ? AirportDetails.fromJson(json['airport']) 
        : null;
    final terminalDetails = json['terminal'] is Map<String, dynamic> 
        ? TerminalDetails.fromJson(json['terminal']) 
        : null;
    final carDetails = json['car'] is Map<String, dynamic> 
        ? CarDetails.fromJson(json['car']) 
        : null;
    final customerObj = json['customer'] is Map<String, dynamic> 
        ? UserModel.fromJson(json['customer']) 
        : null;
    final driverObj = json['driver'] is Map<String, dynamic> 
        ? UserModel.fromJson(json['driver']) 
        : null;
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
      category: json['category']?.toString(),
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
      pickupAddress: json['pickupAddress']?.toString() ?? json['pickupAdddress']?.toString(),
      
      carclass: json['carclass']?.toString(),
      carName: json['carName']?.toString() ?? carDetails?.carName ??
          (json['vehicleID'] is Map
              ? json['vehicleID']['carName']?.toString()
              : null),
      charge: json['charge'] != null
          ? double.tryParse(json['charge'].toString())
          : null,
      carbrand: json['carbrand']?.toString() ?? json['brand']?.toString() ?? carDetails?.brandName ??
          (json['brandID'] is Map
              ? (json['brandID']['brandName'] ?? json['brandID']['name'])?.toString()
              : null),
      carmodel: json['carmodel']?.toString() ?? carDetails?.model,
      carimage: (json['carimage'] is Map
              ? json['carimage']['url']
              : (json['carImage'] is Map
                  ? json['carImage']['url']
                  : (json['image'] is Map ? json['image']['url'] : (json['carimage'] ?? json['carImage'] ?? json['image']))))
          ?.toString() ?? carDetails?.carImageUrl,
      
      specialRequestText: json['specialRequestText']?.toString(),
      specialRequestAudio: json['specialRequestAudio']?.toString(),
      passengerCount: json['passengerCount']?.toString() ?? carDetails?.numberOfPassengers?.toString(),
      passengerNames: json['passengerNames'],
      passengerMobile: json['passengerMobile']?.toString(),
      distance: json['distance']?.toString(),
      
      customerID: customerObj?.uid ?? originalIdsObj?.customerID ?? json['customerID']?.toString(),
      driverID: driverObj?.uid ?? originalIdsObj?.driverID ?? json['driverID']?.toString(),
      
      bookingStatus: json['bookingStatus']?.toString(),
      paymentStatus: payStatus,
      
      cityID: originalIdsObj?.cityID ?? json['cityID']?.toString(),
      airportID: originalIdsObj?.airportID ?? json['airportID']?.toString(),
      terminalID: originalIdsObj?.terminalID ?? json['terminalID']?.toString(),
      carID: originalIdsObj?.carID ?? json['carID']?.toString(),
      brandID: originalIdsObj?.brandID ?? json['brandID']?.toString(),
      categoryID: json['categoryID']?.toString(),
      
      flightNumber: json['flightNumber']?.toString(),
      serviceDuration: json['serviceDuration'] != null
          ? int.tryParse(json['serviceDuration'].toString())
          : null,
      estimatedHours: json['estimatedHours'] != null
          ? int.tryParse(json['estimatedHours'].toString())
          : (json['hours'] != null ? int.tryParse(json['hours'].toString()) : null),
      
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
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class CityDetails {
  final String id;
  final String cityName;
  final String? imageUrl;
  final bool isActive;

  CityDetails({required this.id, required this.cityName, this.imageUrl, this.isActive = true});

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

  AirportDetails({required this.id, required this.airportName, this.isActive = true, this.cityId});

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

  TerminalDetails({required this.id, required this.terminalName, this.isActive = true});

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

  CarDetails({
    required this.id,
    this.carName,
    this.model,
    this.numberOfPassengers,
    this.carImageUrl,
    this.brandName,
  });

  factory CarDetails.fromJson(Map<String, dynamic> json) {
    return CarDetails(
      id: json['_id'] ?? '',
      carName: json['carName'],
      model: json['model']?.toString(),
      numberOfPassengers: json['numberOfPassengers'] is int 
          ? json['numberOfPassengers'] 
          : int.tryParse(json['numberOfPassengers']?.toString() ?? ''),
      carImageUrl: json['carImage'] is Map ? json['carImage']['url'] : null,
      brandName: json['brandDetails'] is Map 
          ? json['brandDetails']['brandName'] 
          : (json['brandID'] is Map ? json['brandID']['brandName'] : null),
    );
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

