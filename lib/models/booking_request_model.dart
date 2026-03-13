import 'dart:io';

class BookingRequestModel {
  String? category;
  String? city;
  String? airport;
  String? arrival; // ISO 8601 DateTime string
  String? pickupLat;
  String? pickupLong;
  String? dropOffLat;
  String? dropOffLong;
  String? dropOffAddress;
  String? carclass;
  String? carName;
  String? charge;
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

  BookingRequestModel({
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
  });

  Map<String, dynamic> toMap() {
    return {
      if (category != null) 'category': category,
      if (city != null) 'city': city,
      if (airport != null) 'airport': airport,
      if (arrival != null) 'arrival': arrival,
      if (pickupLat != null) 'pickupLat': pickupLat,
      if (pickupLong != null) 'pickupLong': pickupLong,
      if (dropOffLat != null) 'dropOffLat': dropOffLat,
      if (dropOffLong != null) 'dropOffLong': dropOffLong,
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
    };
  }

  @override
  String toString() {
    return 'BookingRequestModel: ${toMap()}';
  }
}
