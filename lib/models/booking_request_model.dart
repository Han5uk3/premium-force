import 'dart:io';

class BookingRequestModel {
  String? category;
  String? city;
  String? airport;
  String? arrival; // ISO 8601 DateTime string
  String? pickupLat;
  String? pickupLng;
  String? dropOffLat;
  String? dropOffLng;
  String? dropOffAddress;
  String? carclass;
  String? carName;
  double? charge;
  String? carbrand;
  String? carmodel;
  File? carimage;
  String? specialRequestText;
  File? specialRequestAudio;
  String? passengerCount;
  String?
  passengerNames; // JSON Object format, e.g., '["John Doe", "Jane Smith"]'
  String? passengerMobile;
  String? distance;
  String? customerID;
  String? driverID;
  String? bookingStatus;
  String? paymentStatus;
  String? cityID;
  String? airportID;
  String? terminalID;
  String? flightNumber;
  String? terminal;
  String? pickupAddress;
  String? carID;
  String? brandID;
  String? categoryID;

  BookingRequestModel({
    this.category,
    this.city,
    this.airport,
    this.arrival,
    this.pickupLat,
    this.pickupLng,
    this.dropOffLat,
    this.dropOffLng,
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
  });

  Map<String, dynamic> toMap() {
    return {
      if (category != null) 'category': category,
      if (city != null) 'city': city,
      if (airport != null) 'airport': airport,
      if (arrival != null) 'arrival': arrival,
      if (pickupLat != null) 'pickupLat': pickupLat,
      if (pickupLng != null) 'pickupLng': pickupLng,
      if (dropOffLat != null) 'dropOffLat': dropOffLat,
      if (dropOffLng != null) 'dropOffLng': dropOffLng,
      if (dropOffAddress != null) 'dropOffAddress': dropOffAddress,
      if (carclass != null) 'carclass': carclass,
      if (carName != null) 'carName': carName,
      if (charge != null) 'charge': charge,
      if (carbrand != null) 'carbrand': carbrand,
      if (carmodel != null) 'carmodel': carmodel,
      if (carimage != null) 'carimage': carimage!.path, // Displaying path
      if (specialRequestText != null) 'specialRequestText': specialRequestText,
      if (specialRequestAudio != null)
        'specialRequestAudio': specialRequestAudio!.path,
      if (passengerCount != null) 'passengerCount': passengerCount,
      if (passengerNames != null) 'passengerNames': passengerNames,
      if (passengerMobile != null) 'passengerMobile': passengerMobile,
      if (distance != null) 'distance': distance,
      if (customerID != null) 'customerID': customerID,
      if (driverID != null) 'driverID': driverID,
      if (bookingStatus != null) 'bookingStatus': bookingStatus,
      if (paymentStatus != null) 'paymentStatus': paymentStatus,
      if (cityID != null) 'cityID': cityID,
      if (airportID != null) 'airportID': airportID,
      if (terminalID != null) 'terminalID': terminalID,
      if (flightNumber != null) 'flightNumber': flightNumber,
      if (terminal != null) 'terminal': terminal,
      if (pickupAddress != null) 'pickupAddress': pickupAddress,
      if (carID != null) 'carID': carID,
      if (brandID != null) 'brandID': brandID,
      if (categoryID != null) 'categoryID': categoryID,
    };
  }

  @override
  String toString() {
    return 'BookingRequestModel: ${toMap()}';
  }
}
