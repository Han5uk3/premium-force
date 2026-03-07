import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:premium_force_main/common_widgets/bookingcard.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/premiumdropdown.dart';
import 'package:premium_force_main/common_widgets/riyal_symbol.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/common_widgets/textfield.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/authentication/location_picker.dart';
import 'package:premium_force_main/ride_booking/voice_note_dialog.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:premium_force_main/models/booking_request_model.dart';
import 'package:premium_force_main/models/car_model.dart';
import 'package:country_picker/country_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NewBooking extends StatefulWidget {
  final int catcode;
  final int citycode;
  const NewBooking({super.key, required this.catcode, required this.citycode});

  @override
  State<NewBooking> createState() => _NewBookingState();
}

class _NewBookingState extends State<NewBooking> {
  late int _selectedCatCode;
  late int _selectedCityCode;

  bool _isCalculatingDistance = false;

  double _totalDistance = 50.0;

  final _tripInfoFormKey = GlobalKey<FormState>();
  final _preferencesFormKey = GlobalKey<FormState>();
  final _passengerFormKey = GlobalKey<FormState>();

  bool showPreferances = false;
  bool showTripInfo = true;
  bool showPassenger = false;
  bool showReviewAndConfirm = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedVehicleClass = "Luxury Sedan";
  String? _selectedVehicleBrand = "Mercedes";
  String? _selectedVehicleModel = "S-Class S450";
  String? _numberOfPassengers = "1";
  DateTime? _selectedPickupDate;
  TimeOfDay? _selectedPickupTime;

  String? _dropAddress;
  double? _dropLat;
  double? _dropLng;
  String? _pickupAddress;
  double? _pickupLat;
  double? _pickupLng;

  TextEditingController flightNumberController = TextEditingController();
  TextEditingController specialRequestsController = TextEditingController();
  TextEditingController _passengerNameController = TextEditingController();
  TextEditingController _mobileNumberController = TextEditingController();
  String? _specialRequestsVoiceNotePath;
  int _selectedTerminalCode = 0;
  OverlayEntry? _overlayEntry;
  String _selectedPassengerCountryCode = '966';

  double get _calculatedCharge {
    final selectedCar = availableCars.firstWhere(
      (c) =>
          c.className == _selectedVehicleClass &&
          c.brand == _selectedVehicleBrand &&
          c.modelName == _selectedVehicleModel,
      orElse: () => availableCars.first,
    );
    final distance = selectedCar.distance > 0 ? selectedCar.distance : 1;
    return (_totalDistance / distance) * selectedCar.price;
  }

  bool _isDarkLogo(String brandName) {
    final lowerBrand = brandName.toLowerCase();
    const darkLogos = [
      'audi',
      'rolls-royce',
      'mini',
      'lexus',
      'tesla',
      'maserati',
      'maybach',
      'jeep',
      'bentley',
      'aston-martin',
      'honda',
      'hyundai',
      'nissan',
      'lucid',
    ];
    return darkLogos.contains(lowerBrand);
  }

  List<String> _getTerminals(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (_selectedCityCode == 1) {
      // Dammam
      return [loc.passengerTerminal, loc.aramcoTerminal, loc.royalTerminal];
    } else if (_selectedCityCode == 2) {
      // Jeddah
      return [
        loc.terminal1,
        loc.hajjTerminal,
        loc.northTerminal,
        loc.southTerminal,
      ];
    } else {
      // Riyadh
      return [
        loc.terminal1,
        loc.terminal2,
        loc.terminal3,
        loc.terminal4,
        loc.terminal5,
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedCatCode = widget.catcode;
    _selectedCityCode = widget.citycode;
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    flightNumberController.dispose();
    specialRequestsController.dispose();
    super.dispose();
  }

  Future<void> _calculateActualDistance() async {
    String originStr = "";
    String destStr = "";

    String airportQuery;
    if (_selectedCityCode == 1) {
      airportQuery = "King Fahd International Airport, Dammam, Saudi Arabia";
    } else if (_selectedCityCode == 2) {
      airportQuery =
          "King Abdulaziz International Airport, Jeddah, Saudi Arabia";
    } else {
      airportQuery = "King Khalid International Airport, Riyadh, Saudi Arabia";
    }

    if (_selectedCatCode == 0) {
      // Airport Arrival
      originStr = airportQuery;
      destStr = "${_dropLat ?? 0},${_dropLng ?? 0}";
    } else if (_selectedCatCode == 1) {
      // Airport Departure
      originStr = "${_pickupLat ?? 0},${_pickupLng ?? 0}";
      destStr = airportQuery;
    } else {
      // Chauffeur
      originStr = "${_pickupLat ?? 0},${_pickupLng ?? 0}";
      destStr = "${_dropLat ?? 0},${_dropLng ?? 0}";
    }

    if (originStr.contains("0.0,0.0") || destStr.contains("0.0,0.0")) return;

    try {
      final dio = Dio();
      const String apiKey =
          "AIzaSyCMz7AHUHfw1BV6MTtWS2zwvLPk3XsnpGk"; // Extracted from AndroidManifest

      final String encodedOrigin = Uri.encodeComponent(originStr);
      final String encodedDest = Uri.encodeComponent(destStr);

      final url =
          "https://maps.googleapis.com/maps/api/directions/json?origin=$encodedOrigin&destination=$encodedDest&key=$apiKey";

      final response = await dio.get(url);
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final legs = data['routes'][0]['legs'];
          if (legs != null && legs.isNotEmpty) {
            final distanceMeters = legs[0]['distance']['value'];
            setState(() {
              _totalDistance = distanceMeters / 1000.0;
              print("Distance: $_totalDistance");
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Distance calculation error: \$e");
    }
  }

  void _showCustomSnackBar(String message, String type) {
    _overlayEntry?.remove();
    _overlayEntry = null;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: AnimatedSnackBar(
            message: message,
            type: type,
            onDismissed: () {
              if (mounted) {
                _overlayEntry?.remove();
                _overlayEntry = null;
              }
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  String _getServiceName(BuildContext context, int code) {
    final loc = AppLocalizations.of(context)!;
    switch (code) {
      case 1:
        return loc.airportDeparture;
      case 2:
        return loc.chauffeurService;
      case 0:
      default:
        return loc.airportArrival;
    }
  }

  String _getCityName(BuildContext context, int code) {
    final loc = AppLocalizations.of(context)!;
    switch (code) {
      case 1:
        return loc.dammam;
      case 2:
        return loc.jeddah;
      case 0:
      default:
        return loc.riyadh;
    }
  }

  int _getCatCode(BuildContext context, String name) {
    final loc = AppLocalizations.of(context)!;
    if (name == loc.airportDeparture) return 1;
    if (name == loc.chauffeurService) return 2;
    return 0;
  }

  int _getCityCode(BuildContext context, String name) {
    final loc = AppLocalizations.of(context)!;
    if (name == loc.dammam) return 1;
    if (name == loc.jeddah) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff3E230A), Color(0xff141313)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        appBar: buidAppBar(context),
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.05, 0.0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                  layoutBuilder:
                      (Widget? currentChild, List<Widget> previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                  child: showReviewAndConfirm
                      ? SizedBox(
                          key: const ValueKey('reviewAndConfirmPage'),
                          width: double.infinity,
                          child: buildReviewAndConfirmPage(context, loc),
                        )
                      : showPassenger
                      ? SizedBox(
                          key: const ValueKey('passengerForm'),
                          width: double.infinity,
                          child: buildPassengerForm(context, loc),
                        )
                      : showPreferances
                      ? SizedBox(
                          key: const ValueKey('preferencesForm'),
                          width: double.infinity,
                          child: buildPreferancesForm(context, loc),
                        )
                      : SizedBox(
                          key: const ValueKey('tripInfoForm'),
                          width: double.infinity,
                          child: buildTripInfoForm(context, loc),
                        ),
                ),
              ),
              SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PremiumButton(
                  text: showReviewAndConfirm
                      ? loc.bookService
                      : loc.continueText,
                  onTap: _isCalculatingDistance
                      ? () {}
                      : () async {
                          if (showTripInfo) {
                            if (_tripInfoFormKey.currentState?.validate() ??
                                false) {
                              if (_selectedCatCode == 1 &&
                                  _selectedDate != null &&
                                  _selectedTime != null &&
                                  _selectedPickupDate != null &&
                                  _selectedPickupTime != null) {
                                final depDateTime = DateTime(
                                  _selectedDate!.year,
                                  _selectedDate!.month,
                                  _selectedDate!.day,
                                  _selectedTime!.hour,
                                  _selectedTime!.minute,
                                );
                                final pickDateTime = DateTime(
                                  _selectedPickupDate!.year,
                                  _selectedPickupDate!.month,
                                  _selectedPickupDate!.day,
                                  _selectedPickupTime!.hour,
                                  _selectedPickupTime!.minute,
                                );

                                if (pickDateTime.isAfter(depDateTime)) {
                                  _showCustomSnackBar(
                                    loc.pickupTimeCannotBeAfterDepartureTime,
                                    'E',
                                  );
                                  return;
                                }
                              }
                              setState(() {
                                showPreferances = true;
                                showTripInfo = false;
                                showPassenger = false;
                                showReviewAndConfirm = false;
                              });
                            }
                          } else if (showPreferances) {
                            if (_preferencesFormKey.currentState?.validate() ??
                                false) {
                              setState(() {
                                showPassenger = true;
                                showTripInfo = false;
                                showPreferances = false;
                                showReviewAndConfirm = false;
                              });
                            }
                          } else if (showPassenger) {
                            if (_passengerFormKey.currentState?.validate() ??
                                false) {
                              setState(() {
                                _isCalculatingDistance = true;
                              });
                              await _calculateActualDistance();
                              setState(() {
                                showReviewAndConfirm = true;
                                showTripInfo = false;
                                showPreferances = false;
                                showPassenger = false;
                                _isCalculatingDistance = false;
                              });
                            }
                          } else if (showReviewAndConfirm) {
                            String getIsoDateTime(DateTime? d, TimeOfDay? t) {
                              if (d == null || t == null) return "";
                              return DateTime(
                                d.year,
                                d.month,
                                d.day,
                                t.hour,
                                t.minute,
                              ).toUtc().toIso8601String();
                            }

                            BookingRequestModel
                            requestModel = BookingRequestModel(
                              category: _getServiceName(
                                context,
                                _selectedCatCode,
                              ),
                              city: _getCityName(context, _selectedCityCode),
                              airport: _getTerminals(
                                context,
                              )[_selectedTerminalCode],
                              arrival: getIsoDateTime(
                                _selectedDate,
                                _selectedTime,
                              ),
                              pickupLat: _pickupLat?.toString(),
                              pickupLong: _pickupLng?.toString(),
                              dropOffLat: _dropLat?.toString(),
                              dropOffLong: _dropLng?.toString(),
                              dropOffAddress: _dropAddress ?? _pickupAddress,
                              carclass: _selectedVehicleClass,
                              carbrand: _selectedVehicleBrand,
                              carmodel: _selectedVehicleModel,
                              specialRequestText:
                                  specialRequestsController.text,
                              specialRequestAudio:
                                  _specialRequestsVoiceNotePath != null
                                  ? File(_specialRequestsVoiceNotePath!)
                                  : null,
                              passengerCount: _numberOfPassengers,
                              passengerNames: jsonEncode([
                                _passengerNameController.text,
                              ]),
                              passengerMobile:
                                  "+$_selectedPassengerCountryCode ${_mobileNumberController.text}",
                              distance:
                                  "${_totalDistance.toStringAsFixed(2)} km",
                              charge:
                                  "${(_calculatedCharge * 1.15).toStringAsFixed(2)}",
                              bookingStatus: "pending",
                              paymentStatus: "false",
                            );

                            print(
                              "=========== BOOKING REQUEST MODEL START ===========",
                            );
                            print(requestModel.toString());
                            print(
                              "=========== BOOKING REQUEST MODEL END ===========",
                            );
                          }
                        },
                  fontsize: 16,
                  showLoader: _isCalculatingDistance,
                ),
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildReviewAndConfirmPage(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            loc.reviewAndConfirm,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            loc.reviewAndConfirmYourRequest,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Builder(
            builder: (context) {
              String getDisplayDate() {
                if (_selectedCatCode == 0) {
                  return _selectedDate != null
                      ? DateFormat("yyyy-MM-dd").format(_selectedDate!)
                      : "";
                } else {
                  return _selectedPickupDate != null
                      ? DateFormat("yyyy-MM-dd").format(_selectedPickupDate!)
                      : "";
                }
              }

              String getDisplayTime() {
                if (_selectedCatCode == 0) {
                  return _selectedTime != null
                      ? _selectedTime!.format(context)
                      : "";
                } else {
                  return _selectedPickupTime != null
                      ? _selectedPickupTime!.format(context)
                      : "";
                }
              }

              String getPickup() {
                if (_selectedCatCode == 0) {
                  return _getTerminals(context)[_selectedTerminalCode];
                }
                return _pickupAddress ?? "";
              }

              String getDropoff() {
                if (_selectedCatCode == 1) {
                  return _getTerminals(context)[_selectedTerminalCode];
                }
                return _dropAddress ?? "";
              }

              return Bookingcard(
                isFromReviewAndConfirm: true,
                status: "",
                type: _getServiceName(context, _selectedCatCode),
                pickup: getPickup(),
                dropoff: getDropoff(),
                date: getDisplayDate(),
                time: getDisplayTime(),
                ride: _selectedVehicleClass ?? "",
                brand: _selectedVehicleBrand ?? "",
              );
            },
          ),
        ),
        SizedBox(height: 20),
        buildPaymentSummary(context, loc),
      ],
    );
  }

  Widget buildPaymentSummary(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            loc.paymentSummary,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      loc.totalDistance,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      "${_totalDistance.toStringAsFixed(2)} ${loc.km}",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      loc.charge,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RiyalSymbol(color: Colors.white, size: 16),
                        Text(
                          " ${_calculatedCharge.toStringAsFixed(2)}",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      loc.vat,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RiyalSymbol(color: Colors.white, size: 16),
                        Text(
                          " ${(_calculatedCharge * 0.15).toStringAsFixed(2)}",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Divider(color: Colors.grey.shade700),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      loc.total,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RiyalSymbol(color: Colors.white, size: 16),
                        Text(
                          " ${(_calculatedCharge * 1.15).toStringAsFixed(2)}",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildPassengerForm(BuildContext context, AppLocalizations loc) {
    return Form(
      key: _passengerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              loc.passenger,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              loc.providePassengerInfo,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PremiumDropDown(
              title: loc.numberOfPassengers,
              items: ["1", "2", "3", "4", "5", "6", "7"],
              value: _numberOfPassengers,
              onChanged: (value) {
                setState(() {
                  _numberOfPassengers = value;
                });
              },
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PremiumTextField(
              titleFontWeight: FontWeight.normal,
              fontsize: 14,
              needBorder: true,
              blackbg: true,
              borderRadius: 12,
              needAutoCapitalize: false,
              title: loc.passengerNameAtleastOne,
              controller: _passengerNameController,
              hintText: loc.pleaseEnterAPassengerName,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return loc.pleaseEnterAtleastOnepassengerName;
                }
                return null;
              },
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PremiumTextField(
              titleFontWeight: FontWeight.normal,
              fontsize: 14,
              needBorder: true,
              blackbg: true,
              borderRadius: 12,
              needAutoCapitalize: false,
              title: loc.mobileNumber,
              controller: _mobileNumberController,
              hintText: loc.enterMobileNumber,
              prefixIcon: GestureDetector(
                onTap: () {
                  showCountryPicker(
                    context: context,
                    showPhoneCode: true,
                    customFlagBuilder: (context) => const SizedBox.shrink(),
                    countryListTheme: CountryListThemeData(
                      backgroundColor: const Color(0xFF141313),
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      searchTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      inputDecoration: InputDecoration(
                        hintText: loc.search,
                        hintStyle: TextStyle(
                          color: Colors.white.withAlpha(180),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1A1410),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade800),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade800),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE4A46B),
                          ),
                        ),
                      ),
                      bottomSheetHeight:
                          MediaQuery.of(context).size.height * 0.75,
                    ),
                    onSelect: (Country country) {
                      setState(() {
                        _selectedPassengerCountryCode = country.phoneCode;
                      });
                    },
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+$_selectedPassengerCountryCode',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.white),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        height: 24,
                        width: 1,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return loc.pleaseEnterAMobileNumber;
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPreferancesForm(BuildContext context, AppLocalizations loc) {
    return Form(
      key: _preferencesFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              loc.preferences,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              loc.chooseYouPreferredVehicle,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          SizedBox(height: 16),
          buildVehicleClassSelector(context, loc),
          SizedBox(height: 16),
          buildVehicleBrandSelector(context, loc),
          SizedBox(height: 16),
          buildVehicleModelSelector(context, loc),
          SizedBox(height: 16),
          buildSpecialRequests(context, loc),
        ],
      ),
    );
  }

  Widget buildSpecialRequests(BuildContext context, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: PremiumTextField(
        needBorder: true,
        blackbg: true,
        borderRadius: 16,
        maxLines: 4,
        suffixIcon: GestureDetector(
          onTap: () async {
            final path = await showDialog<String>(
              context: context,
              builder: (context) => VoiceNoteDialog(
                initialAudioPath: _specialRequestsVoiceNotePath,
              ),
            );
            if (path != null) {
              setState(() {
                if (path == 'DELETED') {
                  _specialRequestsVoiceNotePath = null;
                } else {
                  _specialRequestsVoiceNotePath = path;
                }
              });
              if (path != 'DELETED') {
                _showCustomSnackBar('Voice note successfully saved.', 'S');
              }
            }
          },
          child: _specialRequestsVoiceNotePath != null
              ? Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.mic, color: Color(0xFFE4A46B)),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 10,
                          color: Colors.black, // High contrast with green
                        ),
                      ),
                    ),
                  ],
                )
              : const Icon(Icons.mic_none_outlined, color: Colors.white),
        ),
        title: loc.specialRequests,
        controller: specialRequestsController,
        hintText: loc.specialRequests,
      ),
    );
  }

  Map<String, String> _getVehicleClasses(AppLocalizations loc) {
    return {
      "Luxury Sedan": loc.luxurySedan,
      "Luxury SUV": loc.luxurySuv,
      "Luxury Coupe": loc.luxuryCoupe,
      "Luxury Sports": loc.luxurySports,
      "Luxury Convertible": loc.luxuryConvertible,
    };
  }

  Widget buildVehicleClassSelector(BuildContext context, AppLocalizations loc) {
    final classes = _getVehicleClasses(loc);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumDropDown(
            value: _selectedVehicleClass != null
                ? classes[_selectedVehicleClass]
                : null,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedVehicleClass = classes.entries
                      .firstWhere((e) => e.value == value)
                      .key;

                  final availableBrands = availableCars
                      .where((c) => c.className == _selectedVehicleClass)
                      .map((c) => c.brand)
                      .toSet()
                      .toList();

                  if (availableBrands.isNotEmpty) {
                    _selectedVehicleBrand = availableBrands.first;

                    final availableModels = availableCars
                        .where(
                          (c) =>
                              c.className == _selectedVehicleClass &&
                              c.brand == _selectedVehicleBrand,
                        )
                        .map((c) => c.modelName)
                        .toList();
                    _selectedVehicleModel = availableModels.isNotEmpty
                        ? availableModels.first
                        : null;
                  } else {
                    _selectedVehicleBrand = null;
                    _selectedVehicleModel = null;
                  }
                });
              }
            },
            title: loc.chauffeurredClass,
            items: classes.values.toList(),
          ),
        ],
      ),
    );
  }

  Widget buildVehicleBrandSelector(BuildContext context, AppLocalizations loc) {
    final List<String> brands = availableCars
        .where((c) => c.className == _selectedVehicleClass)
        .map((c) => c.brand)
        .toSet()
        .toList();

    if (brands.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.choosePreferredBrand,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: brands.length,
              itemBuilder: (context, index) {
                final brand = brands[index];
                final isSelected = _selectedVehicleBrand == brand;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedVehicleBrand = brand;

                      final availableModels = availableCars
                          .where(
                            (c) =>
                                c.className == _selectedVehicleClass &&
                                c.brand == _selectedVehicleBrand,
                          )
                          .map((c) => c.modelName)
                          .toList();
                      if (availableModels.isNotEmpty &&
                          !availableModels.contains(_selectedVehicleModel)) {
                        _selectedVehicleModel = availableModels.first;
                      }
                    });
                  },
                  child: Container(
                    margin: EdgeInsetsDirectional.only(
                      end: index != brands.length - 1 ? 8 : 0,
                    ),
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.grey.shade900 : Colors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xffE4A46B)
                            : Colors.white24,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: _isDarkLogo(brand)
                                ? Colors.white.withAlpha(200)
                                : Colors.transparent,
                          ),
                          padding: const EdgeInsets.all(12.0),
                          child: CachedNetworkImage(
                            imageUrl:
                                "https://raw.githubusercontent.com/filippofilip95/car-logos-dataset/master/logos/thumb/${brand.toLowerCase().replaceAll(' ', '-')}.png",
                            fit: BoxFit.contain,
                            errorWidget: (context, url, error) => Text(
                              brand,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _isDarkLogo(brand)
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned.directional(
                            textDirection: Directionality.of(context),
                            top: 8,
                            end: 8,
                            child: const Icon(
                              Icons.check_circle,
                              color: Color(0xffE4A46B),
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildVehicleModelSelector(BuildContext context, AppLocalizations loc) {
    final List<String> models = availableCars
        .where(
          (c) =>
              c.className == _selectedVehicleClass &&
              c.brand == _selectedVehicleBrand,
        )
        .map((c) => c.modelName)
        .toList();

    if (models.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: PremiumDropDown(
        value:
            _selectedVehicleModel != null &&
                models.contains(_selectedVehicleModel)
            ? _selectedVehicleModel
            : null,
        title: loc.preferredModel,
        items: models,
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedVehicleModel = value;
            });
          }
        },
      ),
    );
  }

  Widget buildTripInfoForm(BuildContext context, AppLocalizations loc) {
    return Form(
      key: _tripInfoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              loc.tripInfo,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              loc.tellUsAboutYourJourney,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PremiumDropDown(
              title: loc.serviceType,
              value: _getServiceName(context, _selectedCatCode),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCatCode = _getCatCode(context, val);
                  });
                }
              },
              items: [
                loc.airportArrival,
                loc.airportDeparture,
                loc.chauffeurService,
              ],
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PremiumDropDown(
              title: loc.city,
              value: _getCityName(context, _selectedCityCode),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCityCode = _getCityCode(context, val);
                    _selectedTerminalCode = 0;
                  });
                }
              },
              items: [loc.riyadh, loc.jeddah, loc.dammam],
            ),
          ),
          SizedBox(height: 16),

          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.05),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Builder(
                key: ValueKey<int>(_selectedCatCode),
                builder: (context) {
                  if (_selectedCatCode == 0)
                    return buildArrivalSection(context, loc);
                  if (_selectedCatCode == 1)
                    return buildDepartureSection(context, loc);
                  if (_selectedCatCode == 2)
                    return buildChauffeurSection(context, loc);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildArrivalSection(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildAirportName(context, loc),
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumDropDown(
            title: loc.terminal,
            value: _getTerminals(context)[_selectedTerminalCode],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedTerminalCode = _getTerminals(context).indexOf(val);
                });
              }
            },
            items: _getTerminals(context),
          ),
        ),
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumTextField(
            titleFontWeight: FontWeight.normal,
            fontsize: 14,
            title: loc.flightNumber,
            controller: flightNumberController,
            hintText: loc.enterFlightNumber,
            needBorder: true,
            blackbg: true,
            needAutoCapitalize: true,
            borderRadius: 8,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return loc.flightNumberIsRequired;
              }
              return null;
            },
          ),
        ),
        SizedBox(height: 16),
        buildDateTimePickers(context, loc, false),
        SizedBox(height: 16),
        buildDropLocation(context, loc, true),
      ],
    );
  }

  Widget buildDepartureSection(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildDropLocation(context, loc, false),
        SizedBox(height: 16),
        buildAirportName(context, loc),
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumDropDown(
            title: loc.terminal,
            value: _getTerminals(context)[_selectedTerminalCode],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedTerminalCode = _getTerminals(context).indexOf(val);
                });
              }
            },
            items: _getTerminals(context),
          ),
        ),
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumTextField(
            titleFontWeight: FontWeight.normal,
            fontsize: 14,
            title: loc.flightNumber,
            controller: flightNumberController,
            hintText: loc.enterFlightNumber,
            needBorder: true,
            blackbg: true,
            needAutoCapitalize: true,
            borderRadius: 8,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return loc.flightNumberIsRequired;
              }
              return null;
            },
          ),
        ),
        SizedBox(height: 16),
        buildDateTimePickers(context, loc, false),
        SizedBox(height: 16),
        buildDateTimePickers(context, loc, true),
      ],
    );
  }

  Widget buildChauffeurSection(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildDropLocation(context, loc, false),
        SizedBox(height: 16),
        buildDateTimePickers(context, loc, true),
        SizedBox(height: 16),
        buildDropLocation(context, loc, true),
      ],
    );
  }

  Widget buildDropLocation(
    BuildContext context,
    AppLocalizations loc,
    bool isDropLocation,
  ) {
    return FormField<bool>(
      validator: (value) {
        if (isDropLocation) {
          if (_dropLat == null || _dropLng == null) {
            return loc.dropLocationIsRequired;
          }
        } else {
          if (_pickupLat == null || _pickupLng == null) {
            return loc.pickupLocationIsRequired;
          }
        }
        return null;
      },
      builder: (state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            spacing: 8,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDropLocation ? loc.dropLocation : loc.pickupLocation,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              GestureDetector(
                onTap: () async {
                  double initLat = 24.7136; // Riyadh
                  double initLng = 46.6753; // Riyadh
                  if (_selectedCityCode == 1) {
                    // Dammam
                    initLat = 26.3927;
                    initLng = 49.9777;
                  } else if (_selectedCityCode == 2) {
                    // Jeddah
                    initLat = 21.4858;
                    initLng = 39.1925;
                  }

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationPickerPage(
                        initialLat: initLat,
                        initialLng: initLng,
                        needCurrentLocationButton: false,
                      ),
                    ),
                  );
                  if (result != null && result is Map<String, dynamic>) {
                    if (isDropLocation) {
                      setState(() {
                        _dropAddress = result['address'];
                        _dropLat = result['lat'];
                        _dropLng = result['lng'];
                      });
                    } else {
                      setState(() {
                        _pickupAddress = result['address'];
                        _pickupLat = result['lat'];
                        _pickupLng = result['lng'];
                      });
                    }
                    state.didChange(true);
                  }
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: 60),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: state.hasError
                            ? const Color(0xFFCF6679)
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            isDropLocation
                                ? _dropAddress ?? loc.tapToSelectADropLocation
                                : _pickupAddress ??
                                      loc.tapToSelectAPickupLocation,
                            style: TextStyle(
                              color: isDropLocation
                                  ? _dropAddress != null
                                        ? Colors.white
                                        : Colors.white60
                                  : _pickupAddress != null
                                  ? Colors.white
                                  : Colors.white60,
                              fontSize: 14,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 20),
                        Icon(
                          Icons.location_on_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    state.errorText!,
                    style: const TextStyle(
                      color: Color(0xFFCF6679),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget buildAirportName(BuildContext context, AppLocalizations loc) {
    String airportName = "King Khalid International Airport";
    if (_selectedCityCode == 1) {
      airportName = "King Fahd International Airport";
    } else if (_selectedCityCode == 2) {
      airportName = "King Abdulaziz International Airport";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        spacing: 5,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.airport,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      airportName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDateTimePickers(
    BuildContext context,
    AppLocalizations loc,
    bool isPickup,
  ) {
    return FormField<bool>(
      validator: (value) {
        if (isPickup) {
          if (_selectedPickupDate == null || _selectedPickupTime == null) {
            return loc.pickupDateAndTimeIsRequired;
          }
        } else {
          if (_selectedDate == null || _selectedTime == null) {
            return loc.dateAndTimeIsRequired;
          }
        }
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                isPickup
                    ? loc.pickupDateAndTime
                    : _selectedCatCode == 0
                    ? loc.arrivalDateAndTime
                    : _selectedCatCode == 1
                    ? loc.departureDateAndTime
                    : loc.pickupDateAndTime,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            SizedBox(height: 8),

            Container(
              height: 60,
              margin: EdgeInsets.symmetric(horizontal: 24),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: state.hasError
                      ? const Color(0xFFCF6679)
                      : Colors.white24,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate:
                              (isPickup
                                  ? _selectedPickupDate
                                  : _selectedDate) ??
                              DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                          confirmText: loc.done,
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: Color(0xffE4A46B),
                                  onPrimary: Colors.black,
                                  surface: Colors.grey.shade900,
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            if (isPickup) {
                              _selectedPickupDate = picked;
                            } else {
                              _selectedDate = picked;
                            }
                            if (isPickup) {
                              if (_selectedPickupTime != null) {
                                final now = DateTime.now();
                                if (picked.year == now.year &&
                                    picked.month == now.month &&
                                    picked.day == now.day) {
                                  if (_selectedPickupTime!.hour < now.hour ||
                                      (_selectedPickupTime!.hour == now.hour &&
                                          _selectedPickupTime!.minute <
                                              now.minute)) {
                                    _selectedPickupTime = null;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          loc.previouslySelectedTimeClearedAsItIsInThePast,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            } else {
                              if (_selectedTime != null) {
                                final now = DateTime.now();
                                if (picked.year == now.year &&
                                    picked.month == now.month &&
                                    picked.day == now.day) {
                                  if (_selectedTime!.hour < now.hour ||
                                      (_selectedTime!.hour == now.hour &&
                                          _selectedTime!.minute < now.minute)) {
                                    _selectedTime = null;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          loc.previouslySelectedTimeClearedAsItIsInThePast,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            }
                          });
                          state.didChange(true);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPickup
                              ? (_selectedPickupDate == null
                                    ? loc.selectDate
                                    : DateFormat(
                                        'dd MMM yyyy',
                                      ).format(_selectedPickupDate!))
                              : (_selectedDate == null
                                    ? loc.selectDate
                                    : DateFormat(
                                        'dd MMM yyyy',
                                      ).format(_selectedDate!)),
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        if (isPickup
                            ? _selectedPickupDate == null
                            : _selectedDate == null) {
                          OverlayEntry? overlayEntry;
                          overlayEntry = OverlayEntry(
                            builder: (context) => Positioned(
                              bottom:
                                  MediaQuery.of(context).viewInsets.bottom + 20,
                              left: 20,
                              right: 20,

                              child: Material(
                                color: Colors.transparent,
                                child: AnimatedSnackBar(
                                  type: "E",
                                  message: loc.pleaseSelectADateFirst,
                                  onDismissed: () {
                                    overlayEntry?.remove();
                                  },
                                ),
                              ),
                            ),
                          );
                          Overlay.of(context).insert(overlayEntry);
                          return;
                        }
                        showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            TimeOfDay tempTime =
                                (isPickup
                                    ? _selectedPickupTime
                                    : _selectedTime) ??
                                TimeOfDay.now();
                            String? errorMessage;
                            return StatefulBuilder(
                              builder: (context, setDialogState) {
                                return Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: ColorScheme.dark(
                                      surface: Colors.grey.shade900,
                                    ),
                                  ),
                                  child: AlertDialog(
                                    backgroundColor: Colors.grey.shade800,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    title: Text(
                                      loc.selectTime,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                    content: SizedBox(
                                      height: 250,
                                      child: Column(
                                        children: [
                                          if (errorMessage != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 16.0,
                                                left: 16,
                                                right: 16,
                                              ),
                                              child: Text(
                                                errorMessage!,
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 13,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          Expanded(
                                            child: CupertinoTheme(
                                              data: CupertinoThemeData(
                                                brightness: Brightness.dark,
                                                textTheme:
                                                    CupertinoTextThemeData(
                                                      dateTimePickerTextStyle:
                                                          TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                              ),
                                              child: CupertinoDatePicker(
                                                mode: CupertinoDatePickerMode
                                                    .time,
                                                use24hFormat: false,
                                                initialDateTime: DateTime(
                                                  DateTime.now().year,
                                                  DateTime.now().month,
                                                  DateTime.now().day,
                                                  tempTime.hour,
                                                  tempTime.minute,
                                                ),
                                                onDateTimeChanged:
                                                    (DateTime newDateTime) {
                                                      setDialogState(() {
                                                        errorMessage = null;
                                                        tempTime =
                                                            TimeOfDay.fromDateTime(
                                                              newDateTime,
                                                            );
                                                      });
                                                    },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          bool isToday = false;
                                          final now = DateTime.now();
                                          DateTime? dateToCheck = isPickup
                                              ? _selectedPickupDate
                                              : _selectedDate;
                                          if (dateToCheck != null) {
                                            if (dateToCheck.year == now.year &&
                                                dateToCheck.month ==
                                                    now.month &&
                                                dateToCheck.day == now.day) {
                                              isToday = true;
                                            }
                                          } else {
                                            isToday = true;
                                          }
                                          if (isToday) {
                                            if (tempTime.hour < now.hour ||
                                                (tempTime.hour == now.hour &&
                                                    tempTime.minute <
                                                        now.minute)) {
                                              setDialogState(() {
                                                errorMessage = loc
                                                    .cannotSelectPastTimeForToday;
                                              });
                                              return;
                                            }
                                          }
                                          setState(() {
                                            if (isPickup) {
                                              _selectedPickupTime = tempTime;
                                            } else {
                                              _selectedTime = tempTime;
                                            }
                                          });
                                          state.didChange(true);
                                          Navigator.of(dialogContext).pop();
                                        },
                                        child: Text(
                                          loc.done,
                                          style: TextStyle(
                                            color: Color(0xffE4A46B),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPickup
                              ? (_selectedPickupTime == null
                                    ? loc.selectTime
                                    : _selectedPickupTime!.format(context))
                              : (_selectedTime == null
                                    ? loc.selectTime
                                    : _selectedTime!.format(context)),
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(
                    color: Color(0xFFCF6679),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget buildIncompleteCheckMark(BuildContext context) {
    return Icon(Icons.circle_outlined, color: Colors.grey.shade700, size: 20);
  }

  Widget buildCompletedCheckMark(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [Color(0xff49280B), Color(0xffE4A46B), Color(0xff60350F)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Icon(Icons.check_circle, color: Colors.white, size: 20),
    );
  }

  PreferredSizeWidget buidAppBar(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight + 76),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(100), Colors.transparent],
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            loc.newBooking,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            enableFeedback: true,
            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () {
              if (showReviewAndConfirm) {
                setState(() {
                  showReviewAndConfirm = false;
                  showPassenger = true;
                  showTripInfo = false;
                  showPreferances = false;
                });
              } else if (showPassenger) {
                setState(() {
                  showReviewAndConfirm = false;
                  showPassenger = false;
                  showTripInfo = false;
                  showPreferances = true;
                });
              } else if (showPreferances) {
                setState(() {
                  showReviewAndConfirm = false;
                  showPreferances = false;
                  showTripInfo = true;
                  showPassenger = false;
                });
              } else if (showTripInfo) {
                Navigator.pop(context);
              }
            },
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(76),
            child: buildStepper(context),
          ),
        ),
      ),
    );
  }

  Widget buildStepper(BuildContext context) {
    AppLocalizations loc = AppLocalizations.of(context)!;

    bool isPrefActiveOrPassed =
        showPreferances || showPassenger || showReviewAndConfirm;
    bool isPassActiveOrPassed = showPassenger || showReviewAndConfirm;

    return Container(
      decoration: BoxDecoration(color: Colors.black.withAlpha(140)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              spacing: 5,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildCompletedCheckMark(context),
                Text(loc.tripInfo, style: TextStyle(color: Colors.white)),
              ],
            ),
            Expanded(
              child: Divider(
                color: isPrefActiveOrPassed
                    ? const Color(0xffE4A46B)
                    : Colors.grey.shade700,
                thickness: 1,
                indent: 20,
                endIndent: 20,
              ),
            ),
            Column(
              spacing: 5,
              mainAxisSize: MainAxisSize.min,
              children: [
                isPrefActiveOrPassed
                    ? buildCompletedCheckMark(context)
                    : buildIncompleteCheckMark(context),
                Text(
                  loc.preferences,
                  style: TextStyle(
                    color: isPrefActiveOrPassed
                        ? Colors.white
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Divider(
                color: isPassActiveOrPassed
                    ? const Color(0xffE4A46B)
                    : Colors.grey.shade700,
                thickness: 1,
                indent: 20,
                endIndent: 20,
              ),
            ),
            Column(
              spacing: 5,
              mainAxisSize: MainAxisSize.min,
              children: [
                isPassActiveOrPassed
                    ? buildCompletedCheckMark(context)
                    : buildIncompleteCheckMark(context),
                Text(
                  loc.passenger,
                  style: TextStyle(
                    color: isPassActiveOrPassed
                        ? Colors.white
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
