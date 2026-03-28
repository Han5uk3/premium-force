
class BookingModel {
  final String id;
  final String? category;
  final String? city;
  final String? airport;
  final String? arrival; // ISO 8601 DateTime string
  final String? pickupLat;
  final String? pickupLong;
  final String? dropOffLat;
  final String? dropOffLong;
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
  final String? customerID;
  final String? driverID;
  final String? bookingStatus;
  final String? paymentStatus;
  final String? cityID;
  final String? airportID;
  final String? terminalID;
  final String? flightNumber;
  final String? terminal;
  final String? pickupAddress;
  final String? carID;
  final String? brandID;
  final String? categoryID;
  final int? serviceDuration;
  final int? estimatedHours;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BookingModel({
    required this.id,
    this.category,
    this.city,
    this.airport,
    this.arrival,
    this.pickupLat,
    this.pickupLong,
    this.dropOffLat,
    this.dropOffLong,
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
    this.terminal,
    this.pickupAddress,
    this.carID,
    this.brandID,
    this.categoryID,
    this.serviceDuration,
    this.estimatedHours,
    this.createdAt,
    this.updatedAt,
  });

  String get displayBrand {
    if (carbrand != null && carbrand!.isNotEmpty) return carbrand!;
    return 'N/A';
  }

  String get displayName {
    if (estimatedHours != null) {
      return '${carName ?? ''} ($estimatedHours Hours)'.trim();
    }
    if (carName != null && carName!.isNotEmpty) return carName!;
    if (carbrand != null || carmodel != null) {
      return '${carbrand ?? ''} ${carmodel ?? ''}'.trim();
    }
    return 'N/A';
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['_id'] ?? json['id'] ?? '',
      category: json['category']?.toString(),
      city: json['city']?.toString(),
      airport: json['airport']?.toString(),
      arrival: json['arrival']?.toString(),
      pickupLat: json['pickupLat']?.toString() ?? json['pickuplat']?.toString(),
      pickupLong:
          json['pickupLong']?.toString() ?? json['pickuplong']?.toString(),
      dropOffLat: json['dropOffLat']?.toString(),
      dropOffLong: json['dropOffLong']?.toString(),
      dropOffAddress: json['dropOffAddress']?.toString(),
      carclass: json['carclass']?.toString(),
      carName: json['carName']?.toString() ??
          (json['vehicleID'] is Map
              ? json['vehicleID']['carName']?.toString()
              : null) ??
          (json['carID'] is Map
              ? (json['carID']['carName'] ?? json['carID']['name'])?.toString()
              : null),
      charge: json['charge'] != null
          ? double.tryParse(json['charge'].toString())
          : null,
      carbrand: json['carbrand']?.toString() ??
          json['brand']?.toString() ??
          (json['brandID'] is Map
              ? (json['brandID']['brandName'] ?? json['brandID']['name'])
                  ?.toString()
              : null) ??
          (json['vehicleID'] is Map
              ? (json['vehicleID']['brandName'] ??
                      json['vehicleID']['carbrand'] ??
                      json['vehicleID']['brand'])
                  ?.toString()
              : null) ??
          (json['carID'] is Map
              ? (json['carID']['brandName'] ??
                      json['carID']['carbrand'] ??
                      json['carID']['brand'])
                  ?.toString()
              : null),
      carmodel: json['carmodel']?.toString() ??
          (json['vehicleID'] is Map
              ? (json['vehicleID']['model'] ?? json['vehicleID']['carmodel'])
                  ?.toString()
              : null) ??
          (json['carID'] is Map
              ? (json['carID']['model'] ?? json['carID']['carmodel'])
                  ?.toString()
              : null),
      carimage: (json['carimage'] is Map
              ? json['carimage']['url']
              : (json['carImage'] is Map
                  ? json['carImage']['url']
                  : (json['image'] is Map ? json['image']['url'] : (json['carimage'] ?? json['carImage'] ?? json['image']))))
          ?.toString() ??
          (json['vehicleID'] is Map
              ? (json['vehicleID']['carimage'] ??
                      json['vehicleID']['image'] ??
                      json['vehicleID']['url'])
                  ?.toString()
              : null) ??
          (json['carID'] is Map
              ? (json['carID']['carimage'] ??
                      json['carID']['image'] ??
                      json['carID']['url'])
                  ?.toString()
              : null),
      specialRequestText: json['specialRequestText']?.toString(),
      specialRequestAudio: json['specialRequestAudio']?.toString(),
      passengerCount: json['passengerCount']?.toString(),
      passengerNames: json['passengerNames'],
      passengerMobile: json['passengerMobile']?.toString(),
      distance: json['distance']?.toString(),
      customerID: json['customerID'] is Map
          ? json['customerID']['_id']?.toString()
          : json['customerID']?.toString(),
      driverID: json['driverID'] is Map
          ? json['driverID']['_id']?.toString()
          : json['driverID']?.toString(),
      bookingStatus: json['bookingStatus']?.toString(),
      paymentStatus: json['paymentStatus']?.toString(),
      cityID: json['cityID']?.toString(),
      airportID: json['airportID']?.toString(),
      terminalID: json['terminalID']?.toString(),
      flightNumber: json['flightNumber']?.toString(),
      terminal: json['terminal']?.toString(),
      pickupAddress: json['pickupAddress']?.toString() ??
          json['pickupAdddress']?.toString(),
      carID: json['carID'] is Map
          ? json['carID']['_id']?.toString()
          : json['carID']?.toString(),
      brandID: json['brandID'] is Map
          ? json['brandID']['_id']?.toString()
          : json['brandID']?.toString(),
      categoryID: json['categoryID']?.toString(),
      serviceDuration: json['serviceDuration'] != null
          ? int.tryParse(json['serviceDuration'].toString())
          : null,
      estimatedHours: json['estimatedHours'] != null
          ? int.tryParse(json['estimatedHours'].toString())
          : (json['hours'] != null
              ? int.tryParse(json['hours'].toString())
              : null),
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
      'terminal': terminal,
      'pickupAddress': pickupAddress,
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
