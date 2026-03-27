
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

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['_id'] ?? json['id'] ?? '',
      category: json['category'],
      city: json['city'],
      airport: json['airport'],
      arrival: json['arrival'],
      pickupLat: json['pickupLat'],
      pickupLong: json['pickupLong'],
      dropOffLat: json['dropOffLat'],
      dropOffLong: json['dropOffLong'],
      dropOffAddress: json['dropOffAddress'],
      carclass: json['carclass'],
      carName: json['carName'],
      charge: json['charge'] != null ? double.tryParse(json['charge'].toString()) : null,
      carbrand: json['carbrand'],
      carmodel: json['carmodel'],
      carimage: json['carimage'],
      specialRequestText: json['specialRequestText'],
      specialRequestAudio: json['specialRequestAudio'],
      passengerCount: json['passengerCount'],
      passengerNames: json['passengerNames'],
      passengerMobile: json['passengerMobile'],
      distance: json['distance'],
      customerID: json['customerID'],
      driverID: json['driverID'],
      bookingStatus: json['bookingStatus'],
      paymentStatus: json['paymentStatus'],
      cityID: json['cityID'],
      airportID: json['airportID'],
      terminalID: json['terminalID'],
      flightNumber: json['flightNumber'],
      terminal: json['terminal'],
      pickupAddress: json['pickupAddress'],
      carID: json['carID'],
      brandID: json['brandID'],
      categoryID: json['categoryID'],
      serviceDuration: json['serviceDuration'] != null ? int.tryParse(json['serviceDuration'].toString()) : null,
      estimatedHours: json['estimatedHours'] != null ? int.tryParse(json['estimatedHours'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
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
