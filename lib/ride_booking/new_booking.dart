import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_main/services/payment_service.dart';
import 'package:premium_force_main/models/payment_model.dart';
import 'package:premium_force_main/utils/paytabs_config.dart';

class NewBooking extends StatefulWidget {
  final int catcode;
  final int citycode;
  final List<Map<String, dynamic>>? preloadedCities;
  final List<Map<String, dynamic>>? preloadedAirports;
  final List<Map<String, dynamic>>? preloadedTerminals;

  const NewBooking({
    super.key,
    required this.catcode,
    required this.citycode,
    this.preloadedCities,
    this.preloadedAirports,
    this.preloadedTerminals,
  });

  @override
  State<NewBooking> createState() => _NewBookingState();
}

class _NewBookingState extends State<NewBooking> {
  late int _selectedCatCode;
  late int _selectedCityCode;

  bool _isCalculatingDistance = false;
  bool _isBooking = false;

  double _totalDistance = 50.0;

  // Fetched car data from the backend
  List<Map<String, dynamic>> _brands = [];
  List<CarModel> _cars = [];
  List<Map<String, dynamic>> _apiCategories = [];
  List<Map<String, dynamic>> _apiCities = [];
  List<Map<String, dynamic>> _apiAirports = [];
  List<Map<String, dynamic>> _apiTerminals = [];
  Map<String, String> _brandIcons = {}; // Added this
  double? _routePrice;
  bool _isCheckingRoute = false;

  final _tripInfoFormKey = GlobalKey<FormState>();
  final _preferencesFormKey = GlobalKey<FormState>();
  final _passengerFormKey = GlobalKey<FormState>();
  final _chauffeurTripInfoFormKey = GlobalKey<FormState>();

  bool showPreferances = false;
  bool showTripInfo = true;
  bool showPassenger = false;
  bool showReviewAndConfirm = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedVehicleClass;
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
  int _selectedAirportCode = 0;
  OverlayEntry? _overlayEntry;
  String _selectedPassengerCountryCode = '966';
  int _selectedServiceDuration =
      0; // 0 for hourly, 1 for 8 hours, 2 for 12 hours
  int _selectedEstimatedHours = 1; // 1 to 12

  double get _calculatedCharge {
    return 1.0; // BYPASS FOR TESTING: Fixed 1.0 Riyal
  }

  /// Get the current selected CarModel
  CarModel? _getSelectedCar() {
    final carsList = _cars.isNotEmpty ? _cars : availableCars;
    try {
      return carsList.firstWhere(
        (c) =>
            c.className == _selectedVehicleClass &&
            c.brand == _selectedVehicleBrand &&
            c.modelName == _selectedVehicleModel,
      );
    } catch (_) {
      try {
        return carsList.firstWhere((c) => c.className == _selectedVehicleClass);
      } catch (_) {
        return carsList.isNotEmpty ? carsList.first : null;
      }
    }
  }

  /*
  /// Extracts the city ID from an address string by matching with _apiCities
  String? _getCityIdFromAddress(String? address) {
    if (address == null || address.isEmpty || _apiCities.isEmpty) return null;

    for (var city in _apiCities) {
      final cityName = (city['cityName'] ?? city['name'] ?? '').toString();
      if (cityName.isNotEmpty &&
          address.toLowerCase().contains(cityName.toLowerCase())) {
        return (city['_id'] ?? city['id']).toString();
      }
    }
    return null;
  }
  */

  /*
  /// Gets the city ID for the selected airport
  String? _getAirportCityId() {
    if (_apiAirports.isEmpty) return null;

    final availableAirports = _getAvailableAirports(context);
    if (availableAirports.isEmpty) return null;

    final selectedAirportName =
        availableAirports[_selectedAirportCode < availableAirports.length
            ? _selectedAirportCode
            : 0];

    try {
      final airport = _apiAirports.firstWhere(
        (a) => a['airportName'] == selectedAirportName,
      );
      return (airport['cityID'] ??
              airport['cityId'] ??
              airport['city_id'] ??
              airport['city'])
          ?.toString();
    } catch (_) {
      return null;
    }
  }
  */

  /// Check route availability and optionally fetch price
  /* 
  /// Check route availability and optionally fetch price
  Future<Map<String, dynamic>> _fetchRouteDetails({bool withVehicle = false}) async {
    // BYPASS: Always return success with a custom price for testing
    debugPrint('🚧 BYPASS │ Returning custom price (5.0) for testing');
    return {
      'success': true,
      'data': {'charge': 5.0},
      'payload': {'charge': 5.0},
    };
  }
  */

  /*
  void _showNoServiceAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Service Not Available"),
        content: Text(
          "Service not available in this city. Please try another location.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }
  */

  @override
  void initState() {
    super.initState();
    _selectedCatCode = widget.catcode;
    _selectedCityCode = widget.citycode;

    // Set initial class based on catcode
    if (_selectedCatCode == 2) {
      _selectedVehicleClass =
          "Luxury Sedan"; // Will be updated to "Chauffeured Class" once API loads
    } else {
      _selectedVehicleClass = "Luxury Sedan";
    }

    // Use preloaded data from widget if available
    _apiCities = widget.preloadedCities ?? [];
    _apiAirports = widget.preloadedAirports ?? [];
    _apiTerminals = widget.preloadedTerminals ?? [];

    _loadCarData();
  }

  /// Load car data (categories, brands, cars) from the backend API.
  Future<void> _loadCarData() async {
    try {
      final api = ApiService();
      final token = UserLocalStorage.getToken();

      final List<Future<Map<String, dynamic>>> futures = [
        api.getCategories(token: token),
        api.getBrands(token: token),
        api.getCars(token: token),
      ];

      if (_apiCities.isEmpty) {
        futures.add(api.getCities());
      } else {
        futures.add(Future.value({'success': true, 'data': _apiCities}));
      }

      if (_apiAirports.isEmpty) {
        futures.add(api.getAirports());
      } else {
        futures.add(Future.value({'success': true, 'data': _apiAirports}));
      }

      if (_apiTerminals.isEmpty) {
        futures.add(api.getTerminals());
      } else {
        futures.add(Future.value({'success': true, 'data': _apiTerminals}));
      }

      final results = await Future.wait(futures).catchError((e) {
        debugPrint('Error in Future.wait: $e');
        return <Map<String, dynamic>>[{}, {}, {}, {}, {}, {}];
      });

      final categoriesResult = results[0];
      final brandsResult = results[1];
      final carsResult = results[2];
      final citiesResult = results[3];
      final airportsResult = results[4];
      final terminalsResult = results[5];

      if (mounted) {
        setState(() {
          Map<String, String> categoryIdToName = {};
          if (categoriesResult['success'] == true) {
            final categoriesData =
                categoriesResult['data'] ??
                categoriesResult['categories'] ??
                categoriesResult['payload'];
            _apiCategories = rawDataToList(categoriesData);

            if (categoriesData != null) {
              final List categoriesList = categoriesData is List
                  ? categoriesData
                  : [categoriesData];
              for (var category in categoriesList) {
                if (category is Map) {
                  final id = (category['_id'] ?? category['id'] ?? '')
                      .toString();
                  final name =
                      (category['name'] ??
                              category['categoryName'] ??
                              category['category_name'] ??
                              category['title'] ??
                              'Unknown')
                          .toString()
                          .trim();
                  if (id.isNotEmpty && name != 'Unknown') {
                    categoryIdToName[id] = name;
                  }
                }
              }
            }
          }

          // Robust Brand data extraction
          Map<String, String> brandIdToName = {};
          if (brandsResult['success'] == true) {
            dynamic brandsRaw =
                brandsResult['data'] ??
                brandsResult['brands'] ??
                brandsResult['payload'];

            // Handle if data is an object containing a brands list
            if (brandsRaw is Map && brandsRaw.containsKey('brands')) {
              brandsRaw = brandsRaw['brands'];
            }

            if (brandsRaw is List) {
              _brands = rawDataToList(brandsRaw);
              _brandIcons = {};
              brandIdToName = {};

              for (var brandObj in _brands) {
                // Support both flat and nested brandInfo structure
                final info = brandObj['brandInfo'] is Map
                    ? brandObj['brandInfo']
                    : brandObj;
                final name =
                    (info['name'] ??
                            info['brandName'] ??
                            info['brand'] ??
                            'Unknown')
                        .toString()
                        .trim();
                final id = (info['_id'] ?? info['id'] ?? info['brandID'] ?? '')
                    .toString();

                if (id.isNotEmpty && name != 'Unknown') {
                  brandIdToName[id] = name;
                  debugPrint('🌐 API │ Brand Mapping: $id -> $name');

                  // Resolve Icon URL
                  dynamic iconData =
                      info['brandIcon'] ??
                      info['icon'] ??
                      info['brandimage'] ??
                      info['image'];
                  String iconUrl = '';
                  if (iconData is Map) {
                    iconUrl = iconData['url']?.toString() ?? '';
                  } else if (iconData != null) {
                    iconUrl = iconData.toString();
                  }
                  if (iconUrl.isNotEmpty) {
                    _brandIcons[name] = iconUrl;
                  }
                }
              }
              debugPrint('🌐 API │ Brands Normalized: ${_brands.length}');
            }
          }

          if (carsResult['success'] == true) {
            dynamic carsRaw =
                carsResult['data'] ??
                carsResult['cars'] ??
                carsResult['payload'];

            // Handle if data is an object containing a cars list
            if (carsRaw is Map && carsRaw.containsKey('cars')) {
              carsRaw = carsRaw['cars'];
            }

            if (carsRaw is List) {
              _cars = carsRaw
                  .map((car) {
                    if (car is CarModel) return car;
                    if (car is Map) {
                      final map = Map<String, dynamic>.from(car);

                      String apiCategory = '';
                      // Handle if categoryID is an object or a flat string
                      dynamic cidRaw =
                          map['categoryID'] ??
                          map['categoryId'] ??
                          map['category'];
                      String cid =
                          (cidRaw is Map
                                  ? (cidRaw['_id'] ?? cidRaw['id'])
                                  : cidRaw)
                              ?.toString() ??
                          '';

                      if (cid.isNotEmpty)
                        apiCategory = categoryIdToName[cid] ?? '';

                      if (apiCategory.isEmpty ||
                          apiCategory.toLowerCase() == 'unknown') {
                        final catData = cidRaw is Map
                            ? cidRaw['name']
                            : (map['categoryName'] ?? map['className']);
                        if (catData is String)
                          apiCategory = catData;
                        else if (catData is Map)
                          apiCategory = catData['name'] ?? '';
                      }
                      apiCategory = apiCategory.isEmpty
                          ? 'Unknown'
                          : apiCategory;

                      String apiBrand = '';
                      // Handle if brandID is an object or a flat string
                      dynamic bidRaw =
                          map['brandID'] ?? map['brandId'] ?? map['brand'];
                      String bid =
                          (bidRaw is Map
                                  ? (bidRaw['_id'] ??
                                        bidRaw['id'] ??
                                        bidRaw['brandID'])
                                  : bidRaw)
                              ?.toString() ??
                          '';

                      if (bid.isNotEmpty) apiBrand = brandIdToName[bid] ?? '';

                      if (apiBrand.isEmpty ||
                          apiBrand.toLowerCase() == 'unknown') {
                        final brandData = bidRaw is Map
                            ? (bidRaw['brandName'] ?? bidRaw['name'])
                            : (map['brandName'] ?? map['brand']);
                        if (brandData is String)
                          apiBrand = brandData;
                        else if (brandData is Map)
                          apiBrand = brandData['name'] ?? '';
                      }
                      apiBrand = apiBrand.isEmpty ? 'Unknown' : apiBrand;

                      String? carImage;
                      final rawImage = map['carImage'] ?? map['image'];
                      if (rawImage is String)
                        carImage = rawImage;
                      else if (rawImage is Map)
                        carImage = rawImage['url'];

                      if (carImage != null &&
                          !carImage.startsWith('http') &&
                          !carImage.startsWith('assets/')) {
                        const host =
                            'http://ec2-54-252-191-113.ap-southeast-2.compute.amazonaws.com:5000';
                        carImage = carImage.startsWith('/')
                            ? '$host$carImage'
                            : '$host/$carImage';
                      }
                      final carNameStr = (map['carName'] ?? '')
                          .toString()
                          .trim();
                      final modelStr = (map['model'] ?? '').toString().trim();
                      String modelLabel = "$modelStr $carNameStr".trim();
                      if (modelLabel.isEmpty) modelLabel = 'Unknown';

                      debugPrint(
                        '🌐 API │ Car parsed: $apiBrand $modelLabel (Category: $apiCategory)',
                      );

                      return CarModel(
                        id: map['_id']?.toString() ?? '',
                        className: apiCategory,
                        brand: apiBrand,
                        brandId: bid,
                        categoryId: cid,
                        modelName: modelLabel,
                        imagePath: carImage ?? 'assets/images/bmwdummy.jpg',
                        price: _parseDouble(
                          map['minCharge'] ?? map['price'] ?? 0,
                        ),
                        distance: _parseDouble(
                          map['minimumChargeDistance'] ?? map['distance'] ?? 10,
                        ),
                        maxPassengers: _parseInt(
                          map['numberOfPassengers'] ?? 4,
                        ),
                      );
                    }
                    return null;
                  })
                  .whereType<CarModel>()
                  .toList();
            }
          }

          if (citiesResult['success'] == true) {
            final citiesData = citiesResult['data'] ?? citiesResult['cities'];
            if (citiesData is List) _apiCities = rawDataToList(citiesData);
          }
          if (airportsResult['success'] == true) {
            final airportsData =
                airportsResult['data'] ?? airportsResult['airports'];
            if (airportsData is List)
              _apiAirports = rawDataToList(airportsData);
          }
          if (terminalsResult['success'] == true) {
            final terminalsData =
                terminalsResult['data'] ?? terminalsResult['terminals'];
            if (terminalsData is List)
              _apiTerminals = rawDataToList(terminalsData);
          }

          if (_apiCategories.isNotEmpty) {
            String initialClass =
                (_apiCategories.first['name'] ??
                        _apiCategories.first['categoryName'] ??
                        'Unknown')
                    .toString()
                    .trim();
            if (_selectedCatCode == 2) {
              for (var cat in _apiCategories) {
                final name = (cat['name'] ?? cat['categoryName'] ?? '')
                    .toString()
                    .trim();
                if (name.toLowerCase().contains('chauffeur')) {
                  initialClass = name;
                  break;
                }
              }
            } else {
              for (var cat in _apiCategories) {
                final name = (cat['name'] ?? cat['categoryName'] ?? '')
                    .toString()
                    .trim();
                if (name.toLowerCase().contains('sedan')) {
                  initialClass = name;
                  break;
                }
              }
            }
            if (initialClass.toLowerCase() == 'unknown') {
              for (var cat in _apiCategories) {
                final name = (cat['name'] ?? cat['categoryName'] ?? 'Unknown')
                    .toString()
                    .trim();
                if (name.toLowerCase() != 'unknown') {
                  initialClass = name;
                  break;
                }
              }
            }
            _selectedVehicleClass = initialClass;
            final brandsInClass = _getAvailableBrands(_selectedVehicleClass);
            if (brandsInClass.isNotEmpty) {
              _selectedVehicleBrand = brandsInClass.first;
              final modelsInBrand = _getAvailableModels(
                _selectedVehicleClass,
                _selectedVehicleBrand,
              );
              _selectedVehicleModel = modelsInBrand.isNotEmpty
                  ? modelsInBrand.first
                  : null;
            } else {
              _selectedVehicleBrand = null;
              _selectedVehicleModel = null;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading car data: $e');
    }
  }

  /// Helper to parse double values from API responses
  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Helper to parse int values from API responses
  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  /// Get the list of cars to use (fetched or fallback to hardcoded)
  List<CarModel> get _carsList => _cars.isNotEmpty ? _cars : availableCars;

  /// Get available brands for a given car class (category)
  List<String> _getAvailableBrands(String? className) {
    if (className == null) return [];
    final categoryId = _getSelectedCategoryId();
    debugPrint(
      '🔍 Filter │ Getting brands for Class: $className (ID: $categoryId)',
    );

    if (_brands.isNotEmpty) {
      final filteredBrands = _brands
          .where((brand) {
            // Primary Check: Match by categoryId if available
            final categories =
                brand['categories'] ??
                brand['categoryID'] ??
                brand['categoryId'] ??
                brand['category'];

            if (categories is List) {
              return categories.any((c) {
                String cid = (c is Map
                    ? (c['id'] ?? c['_id'] ?? '').toString()
                    : c.toString());
                String cname =
                    (c is Map
                            ? (c['name'] ?? c['categoryName'] ?? '')
                                  .toString()
                                  .trim()
                            : '')
                        .toLowerCase();
                return (categoryId != null && cid == categoryId) ||
                    cname == className.toLowerCase().trim();
              });
            } else if (categories != null) {
              String cid = (categories is Map
                  ? (categories['id'] ?? categories['_id'] ?? '').toString()
                  : categories.toString());
              String cname =
                  (categories is Map
                          ? (categories['name'] ??
                                    categories['categoryName'] ??
                                    '')
                                .toString()
                                .trim()
                          : '')
                      .toLowerCase();
              return (categoryId != null && cid == categoryId) ||
                  cname == className.toLowerCase().trim();
            }
            return false;
          })
          .map((brand) {
            final info = brand['brandInfo'] is Map ? brand['brandInfo'] : brand;
            return (info['name'] ?? info['brandName'] ?? 'Unknown')
                .toString()
                .trim();
          })
          .where((name) => name != 'Unknown')
          .toSet()
          .toList();

      debugPrint('🔍 Filter │ Filtered Brands result: $filteredBrands');
      if (filteredBrands.isNotEmpty) return filteredBrands;
    }

    // Fallback: Match brands by ID from cars in this class
    final brandsFromCars = _carsList
        .where(
          (c) =>
              (categoryId != null && c.categoryId == categoryId) ||
              c.className.toLowerCase().trim() ==
                  className.toLowerCase().trim(),
        )
        .map((c) => c.brand)
        .where((b) => b != 'Unknown')
        .toSet()
        .toList();

    debugPrint('🔍 Filter │ Brands from cars fallback: $brandsFromCars');
    return brandsFromCars;
  }

  /// Get available models for a given class and brand
  List<String> _getAvailableModels(String? className, String? brand) {
    if (className == null ||
        brand == null ||
        className == 'Unknown' ||
        brand == 'Unknown')
      return [];

    final categoryId = _getSelectedCategoryId();
    final brandId = _getSelectedBrandId();
    debugPrint(
      '🔍 Filter │ Getting models for ClassID: $categoryId ($className), BrandID: $brandId ($brand)',
    );

    final lowerClass = className.toLowerCase().trim();
    final lowerBrand = brand.toLowerCase().trim();

    final results = _carsList
        .where((c) {
          // ID-based matching is more reliable than name-based strings
          if (categoryId != null && brandId != null) {
            return c.categoryId == categoryId && c.brandId == brandId;
          }
          // Name-based fallback if IDs not resolved
          return c.className.toLowerCase().trim() == lowerClass &&
              c.brand.toLowerCase().trim() == lowerBrand;
        })
        .map((c) => c.modelName.trim())
        .where((m) => m.isNotEmpty && m.toLowerCase() != 'unknown')
        .toSet() // Ensure uniqueness
        .toList();

    debugPrint('🔍 Filter │ Filtered Models result: $results');
    return results;
  }

  /// Get passenger options based on selected car's max passengers
  List<String> _getPassengerOptions() {
    // Find the selected car
    final carsList = _cars.isNotEmpty ? _cars : availableCars;
    final selectedCar = carsList.firstWhere(
      (c) =>
          c.className == _selectedVehicleClass &&
          c.brand == _selectedVehicleBrand &&
          c.modelName == _selectedVehicleModel,
      orElse: () => carsList.firstWhere(
        (c) => c.className == _selectedVehicleClass,
        orElse: () => carsList.first,
      ),
    );

    final maxPassengers = selectedCar.maxPassengers > 0
        ? selectedCar.maxPassengers
        : 7;
    return List.generate(maxPassengers, (index) => (index + 1).toString());
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

  String _getCategoryForApi(int code) {
    switch (code) {
      case 1:
        return 'airport departure';
      case 2:
        return 'chauffeured';
      case 0:
      default:
        return 'airport arrival';
    }
  }

  String _getCityName(BuildContext context, int code) {
    if (_apiCities.isNotEmpty && code < _apiCities.length) {
      return _apiCities[code]['cityName'].toString();
    }
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

  Map<String, double> _getAirportCoordinates() {
    // Try to find the airport from API data first
    if (_apiAirports.isNotEmpty) {
      final availableAirports = _getAvailableAirports(context);
      if (availableAirports.isNotEmpty) {
        final selectedAirportName =
            availableAirports[_selectedAirportCode < availableAirports.length
                ? _selectedAirportCode
                : 0];
        try {
          final airport = _apiAirports.firstWhere(
            (a) => a['airportName'] == selectedAirportName,
            orElse: () => _apiAirports.first,
          );
          if (airport.containsKey('lat') && airport.containsKey('long')) {
            final latitude = _parseDouble(airport['lat']);
            final longitude = _parseDouble(airport['long']);
            if (latitude != 0 && longitude != 0) {
              return {'lat': latitude, 'lng': longitude};
            }
          }
        } catch (e) {
          debugPrint('Error getting airport coordinates from API: $e');
        }
      }
    }

    // Fallback Returns airport coordinates based on selected city code
    switch (_selectedCityCode) {
      case 1:
        // Dammam - King Fahd International Airport
        return {'lat': 26.1604, 'lng': 50.1508};
      case 2:
        // Jeddah - King Abdulaziz International Airport
        return {'lat': 21.5433, 'lng': 39.1564};
      case 0:
      default:
        // Riyadh - King Khalid International Airport
        return {'lat': 24.9575, 'lng': 46.6982};
    }
  }

  void _handleBackAction() {
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
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return PopScope(
      canPop: showTripInfo,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBackAction();
      },
      child: Container(
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
                    text: (_isCalculatingDistance || _isCheckingRoute)
                        ? "Processing..."
                        : showReviewAndConfirm
                        ? loc.bookService
                        : loc.continueText,
                    onTap: _isCalculatingDistance || _isCheckingRoute
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

                                  if (pickDateTime.isAfter(
                                    depDateTime.subtract(
                                      const Duration(hours: 4),
                                    ),
                                  )) {
                                    _showCustomSnackBar(
                                      loc.pickupTimeAtLeast4HoursBeforeDeparture,
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
                              if (_preferencesFormKey.currentState
                                      ?.validate() ??
                                  false) {
                                // ── Route & Vehicle Availability Check (Bypassed) ─────
                                /*
                                setState(() {
                                  _isCheckingRoute = true;
                                });

                                final routeResult = await _fetchRouteDetails(
                                  withVehicle: true,
                                );

                                setState(() {
                                  _isCheckingRoute = false;
                                });

                                if (routeResult['success'] == true) {
                                  final data =
                                      routeResult['data'] ??
                                      routeResult['payload'] ??
                                      routeResult;
                                  final fetchedCharge = _parseDouble(
                                    data is Map ? data['charge'] : 0,
                                  );
                                  if (fetchedCharge > 0) {
                                    setState(() {
                                      _routePrice = fetchedCharge;
                                    });
                                  } else {
                                    _showNoServiceAlert();
                                    return;
                                  }
                                } else {
                                  // No price found for this route/vehicle
                                  _showNoServiceAlert();
                                  return;
                                }
                                */

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
                              if (_isBooking) return;

                              setState(() {
                                _isBooking = true;
                              });

                              try {
                                // 1. Prepare Request Data
                                final userData = UserLocalStorage.getUserData();
                                final userId = UserLocalStorage.getUserId();
                                final userEmail = userData?['email'] ?? "";
                                final userName =
                                    userData?['name'] ?? "Customer";
                                final userPhone =
                                    userData?['phoneNumber'] ??
                                    UserLocalStorage.getPhoneNumber() ??
                                    "";

                                final totalWithVat =
                                    1.0; // BYPASS FOR TESTING: Fixed 1.0 Riyal
                                final orderId =
                                    "BOOK_${DateTime.now().millisecondsSinceEpoch}";

                                // 2. Process Payment
                                final paymentRequest = PaymentRequest(
                                  amount: totalWithVat,
                                  currency: PaytabsConfig.defaultCurrency,
                                  merchantCountryCode:
                                      PaytabsConfig.merchantCountryCode,
                                  orderId: orderId,
                                  customerEmail: userEmail,
                                  customerName: userName,
                                  customerPhone: userPhone,
                                  cartId: orderId,
                                  cartDescription:
                                      "Ride Booking for $_selectedVehicleClass",
                                );

                                final paymentResult = await PaymentService()
                                    .startPayment(request: paymentRequest);

                                if (paymentResult.success) {
                                  // 3. If Payment Successful, Create Booking Record
                                  String getIsoDateTime(
                                    DateTime? d,
                                    TimeOfDay? t,
                                  ) {
                                    if (d == null || t == null) return "";
                                    return DateTime(
                                              d.year,
                                              d.month,
                                              d.day,
                                              t.hour,
                                              t.minute,
                                            )
                                            .toUtc()
                                            .toIso8601String()
                                            .split('.')
                                            .first +
                                        "Z";
                                  }

                                  final airportCoords =
                                      _getAirportCoordinates();
                                  double? finalPickupLat;
                                  double? finalPickupLng;
                                  double? finalDropOffLat;
                                  double? finalDropOffLng;
                                  String? finalPickupAddress;
                                  String? finalDropOffAddress;

                                  if (_selectedCatCode == 0) {
                                    finalPickupLat = airportCoords['lat'];
                                    finalPickupLng = airportCoords['lng'];
                                    finalDropOffLat = _dropLat;
                                    finalDropOffLng = _dropLng;

                                    final String airport =
                                        _getSelectedAirportName(context) ?? "";
                                    final String terminal =
                                        _getSelectedTerminalName(context) ?? "";
                                    finalPickupAddress = terminal.isNotEmpty
                                        ? "$airport - $terminal"
                                        : airport;
                                    finalDropOffAddress = _dropAddress;
                                  } else if (_selectedCatCode == 1) {
                                    finalPickupLat = _pickupLat;
                                    finalPickupLng = _pickupLng;
                                    finalDropOffLat = airportCoords['lat'];
                                    finalDropOffLng = airportCoords['lng'];

                                    final String airport =
                                        _getSelectedAirportName(context) ?? "";
                                    final String terminal =
                                        _getSelectedTerminalName(context) ?? "";
                                    finalDropOffAddress = terminal.isNotEmpty
                                        ? "$airport - $terminal"
                                        : airport;
                                    finalPickupAddress = _pickupAddress;
                                  } else {
                                    finalPickupLat = _pickupLat;
                                    finalPickupLng = _pickupLng;
                                    finalDropOffLat = _dropLat;
                                    finalDropOffLng = _dropLng;
                                    finalPickupAddress = _pickupAddress;
                                    finalDropOffAddress = _dropAddress;
                                  }

                                  // Logging raw items removed to focus on exact API data

                                  final BookingRequestModel
                                  requestModel = BookingRequestModel(
                                    category: _getCategoryForApi(
                                      _selectedCatCode,
                                    ),
                                    city: _getCityName(
                                      context,
                                      _selectedCityCode,
                                    ),
                                    airport:
                                        _getSelectedAirportName(context) ?? "",
                                    flightNumber: flightNumberController.text,
                                    cityID: _getSelectedCityId(),
                                    airportID: _getSelectedAirportId(),
                                    terminalID: _getSelectedTerminalId(),
                                    terminal:
                                        _getSelectedTerminalName(context) ?? "",
                                    arrival: getIsoDateTime(
                                      _selectedDate,
                                      _selectedTime,
                                    ),
                                    pickupLat: finalPickupLat
                                        ?.toString()
                                        .trim(),
                                    pickupLong: finalPickupLng
                                        ?.toString()
                                        .trim(),
                                    dropOffLat: finalDropOffLat
                                        ?.toString()
                                        .trim(),
                                    dropOffLong: finalDropOffLng
                                        ?.toString()
                                        .trim(),
                                    dropOffAddress: finalDropOffAddress,
                                    pickupAddress: finalPickupAddress,
                                    specialRequestText:
                                        specialRequestsController.text,
                                    specialRequestAudio:
                                        _specialRequestsVoiceNotePath != null
                                        ? File(_specialRequestsVoiceNotePath!)
                                        : null,
                                    passengerCount: _numberOfPassengers
                                        .toString(),
                                    passengerNames: jsonEncode(
                                      _passengerNameController.text
                                          .split(',')
                                          .map((e) => e.trim())
                                          .where((e) => e.isNotEmpty)
                                          .toList(),
                                    ),
                                    passengerMobile:
                                        "+$_selectedPassengerCountryCode${_mobileNumberController.text.replaceAll(' ', '')}",
                                    distance:
                                        "${_totalDistance.toStringAsFixed(2)} km",
                                    charge: double.parse(
                                      totalWithVat.toStringAsFixed(2),
                                    ),
                                    bookingStatus: "pending",
                                    customerID: userId,
                                    driverID: "null",
                                    carID: _getSelectedCarId(),
                                    brandID: _getSelectedBrandId(),
                                    categoryID: _getSelectedCategoryId(),
                                    carclass: _selectedVehicleClass,
                                    carName: _selectedVehicleModel,
                                    carbrand: _selectedVehicleBrand,
                                    carmodel: _selectedVehicleModel,
                                    serviceDuration: _selectedCatCode == 2
                                        ? _selectedServiceDuration
                                        : null,
                                    estimatedHours: _selectedCatCode == 2
                                        ? _selectedServiceDuration == 0
                                              ? _selectedEstimatedHours
                                              : null
                                        : null,
                                  );

                                  if (kDebugMode) {
                                    final finalDataMap = requestModel.toMap();
                                    debugPrint(
                                      '🚀 🌐 API │ EXACT DATA FOR BOOKING:',
                                    );
                                    final prettyJson = JsonEncoder.withIndent(
                                      '  ',
                                    ).convert(finalDataMap);
                                    debugPrint(prettyJson);
                                  }

                                  final apiResponse = await ApiService()
                                      .createBooking(
                                        booking: requestModel,
                                        token: UserLocalStorage.getToken(),
                                      );

                                  if (kDebugMode) {
                                    debugPrint(
                                      "✅ 🌐 API │ BOOKING RESPONSE RECEIVED",
                                    );
                                    debugPrint(
                                      "✅ 🌐 API │ Status: ${apiResponse['success']}",
                                    );
                                    debugPrint(
                                      "✅ 🌐 API │ Full Response: $apiResponse",
                                    );
                                  }

                                  if (apiResponse['success'] == true) {
                                    _showCustomSnackBar(
                                      // Use direct string fallback if localization not yet generated
                                      "Booking confirmed successfully!",
                                      'S',
                                    );
                                    Navigator.of(context).pop();
                                  } else {
                                    _showCustomSnackBar(
                                      apiResponse['message'] ??
                                          "Booking failed. Please try again.",
                                      'E',
                                    );
                                  }
                                } else {
                                  _showCustomSnackBar(
                                    paymentResult.responseMessage,
                                    'E',
                                  );
                                }
                              } catch (e) {
                                debugPrint('❌ Booking error: $e');
                                _showCustomSnackBar(
                                  "Something went wrong. Please try again.",
                                  'E',
                                );
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isBooking = false;
                                  });
                                }
                              }
                            }
                          },
                    fontsize: 16,
                    showLoader: _isCalculatingDistance || _isBooking,
                  ),
                ),
                SizedBox(height: 32),
              ],
            ),
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
                  final airport = _getSelectedAirportName(context) ?? "";
                  final terminal = _getSelectedTerminalName(context) ?? "";
                  return terminal.isNotEmpty ? "$airport - $terminal" : airport;
                }
                return _pickupAddress ?? "";
              }

              String getDropoff() {
                if (_selectedCatCode == 1) {
                  final airport = _getSelectedAirportName(context) ?? "";
                  final terminal = _getSelectedTerminalName(context) ?? "";
                  return terminal.isNotEmpty ? "$airport - $terminal" : airport;
                }
                return _dropAddress ?? "";
              }

              return Bookingcard(
                isFromReviewAndConfirm: true,
                status: "",
                isChauffeur: _selectedCatCode == 2,
                type: _selectedCatCode == 2
                    ? "${loc.chauffeur} - ${_getServiceDurationLabel(_selectedServiceDuration)}"
                    : _getServiceName(context, _selectedCatCode),
                pickup: getPickup(),
                dropoff: getDropoff(),
                date: getDisplayDate(),
                time: getDisplayTime(),
                ride: _selectedVehicleClass ?? "",
                brand: _selectedVehicleBrand ?? "",
                passengers: int.tryParse(_numberOfPassengers ?? "1") ?? 1,
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
                /*
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
                */
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      getBaseChargeText(loc),

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
                          " 1.00",
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
                          " 1.00",
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

  String getBaseChargeText(AppLocalizations loc) {
    if (_selectedCatCode == 2) {
      switch (_selectedServiceDuration) {
        case 0:
          return loc.baseChauffeurChargeHourly;
        case 1:
          return loc.baseChauffeurCharge8Hours;
        case 2:
          return loc.baseChauffeurCharge12Hours;
      }
    }
    return loc.charge;
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
              items: _getPassengerOptions(),
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
              isPhoneNumber: true,
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
          buildCarImageDisplay(context, loc),
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
            FocusScope.of(context).requestFocus(FocusNode());
            final path = await showDialog<String>(
              context: context,
              builder: (context) => VoiceNoteDialog(
                initialAudioPath: _specialRequestsVoiceNotePath,
              ),
            );
            if (path != null) {
              FocusScope.of(context).requestFocus(FocusNode());
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

  List<String> _getAvailableVehicleClasses() {
    // Approach requested: Fetch all categories from backend
    if (_apiCategories.isNotEmpty) {
      final names =
          _apiCategories
              .map(
                (cat) => (cat['name'] ?? cat['categoryName'] ?? 'Unknown')
                    .toString()
                    .trim(),
              )
              .where((name) => name != 'Unknown')
              .toSet()
              .toList()
            ..sort();

      if (names.isNotEmpty) return names;
    }

    // Fallback: If no categories loaded, get categories from cars
    if (_cars.isNotEmpty) {
      final classes = _cars.map((c) => c.className).toSet().toList()..sort();

      if (classes.length > 1) {
        classes.removeWhere((c) => c.toLowerCase() == 'unknown');
      }

      return classes;
    }
    // Deep Fallback: Hardcoded classes
    return _getVehicleClasses(AppLocalizations.of(context)!).keys.toList();
  }

  Widget buildVehicleClassSelector(BuildContext context, AppLocalizations loc) {
    // Get available classes from API or fallback to hardcoded
    final availableClasses = _getAvailableVehicleClasses();

    // Ensure the selected value is in the available classes, otherwise use first
    String? validSelectedClass = _selectedVehicleClass;
    if (validSelectedClass != null &&
        !availableClasses.contains(validSelectedClass)) {
      validSelectedClass = availableClasses.isNotEmpty
          ? availableClasses.first
          : null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumDropDown(
            value: validSelectedClass,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedVehicleClass = value;

                  // Cascaded Reset: Update brand and model to first available in new class
                  final availableBrands = _getAvailableBrands(
                    _selectedVehicleClass,
                  );
                  if (availableBrands.isNotEmpty) {
                    _selectedVehicleBrand = availableBrands.first;
                    final availableModels = _getAvailableModels(
                      _selectedVehicleClass,
                      _selectedVehicleBrand,
                    );
                    if (availableModels.isNotEmpty) {
                      _selectedVehicleModel = availableModels.first;
                    } else {
                      _selectedVehicleModel = null;
                    }
                  } else {
                    _selectedVehicleBrand = null;
                    _selectedVehicleModel = null;
                  }
                });
              }
            },
            title: loc.chauffeurredClass,
            items: availableClasses,
          ),
        ],
      ),
    );
  }

  Widget buildVehicleBrandSelector(BuildContext context, AppLocalizations loc) {
    final List<String> brands = _getAvailableBrands(_selectedVehicleClass);

    if (brands.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: PremiumDropDown(
        title: loc.choosePreferredBrand,
        items: brands,
        value:
            _selectedVehicleBrand != null &&
                brands.contains(_selectedVehicleBrand)
            ? _selectedVehicleBrand
            : null,
        itemImages: _brandIcons,
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedVehicleBrand = value;

              final availableModels = _getAvailableModels(
                _selectedVehicleClass,
                _selectedVehicleBrand,
              );
              if (availableModels.isNotEmpty) {
                _selectedVehicleModel = availableModels.first;
              } else {
                _selectedVehicleModel = null;
              }
            });
          }
        },
      ),
    );
  }

  Widget buildVehicleModelSelector(BuildContext context, AppLocalizations loc) {
    final List<String> models = _getAvailableModels(
      _selectedVehicleClass,
      _selectedVehicleBrand,
    );

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

  Widget buildCarImageDisplay(BuildContext context, AppLocalizations loc) {
    final carsList = _cars.isNotEmpty ? _cars : availableCars;

    // Find the selected car
    CarModel? selectedCar;
    try {
      selectedCar = carsList.firstWhere(
        (c) =>
            c.className == _selectedVehicleClass &&
            c.brand == _selectedVehicleBrand &&
            c.modelName == _selectedVehicleModel,
      );
    } catch (e) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Car Image
          Container(
            width: double.infinity,
            height: 259,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey.shade800,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: selectedCar.imagePath.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: selectedCar.imagePath,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.amber),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Icon(
                          Icons.car_rental,
                          color: Colors.grey.shade600,
                          size: 64,
                        ),
                      ),
                    )
                  : Image.asset(
                      selectedCar.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.car_rental,
                            color: Colors.grey.shade600,
                            size: 64,
                          ),
                        );
                      },
                    ),
            ),
          ),
          SizedBox(height: 16),
          // Car Model Name
          Text(
            _selectedVehicleModel ?? '',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.start,
          ),
        ],
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
                    _selectedCityCode = _getAvailableCityNames(
                      context,
                    ).indexOf(val);
                    _selectedAirportCode = 0;
                    _selectedTerminalCode = 0;
                  });
                }
              },
              items: _getAvailableCityNames(context),
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
    final terminals = _getAvailableTerminals(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildAirportName(context, loc),
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumDropDown(
            title: loc.terminal,
            value: terminals.isNotEmpty
                ? (_selectedTerminalCode < terminals.length
                      ? terminals[_selectedTerminalCode]
                      : terminals.first)
                : "",
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedTerminalCode = terminals.indexOf(val);
                });
              }
            },
            items: terminals,
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
    final terminals = _getAvailableTerminals(context);
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
            value: terminals.isNotEmpty
                ? (_selectedTerminalCode < terminals.length
                      ? terminals[_selectedTerminalCode]
                      : terminals.first)
                : "",
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedTerminalCode = terminals.indexOf(val);
                });
              }
            },
            items: terminals,
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
      ],
    );
  }

  Widget buildChauffeurSection(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildDropLocation(context, loc, false),

        SizedBox(height: 16),
        buildHoursDataSelectors(context, loc),
        SizedBox(height: 16),
        buildDateTimePickers(context, loc, true),
      ],
    );
  }

  Widget buildHoursDataSelectors(BuildContext context, AppLocalizations loc) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumDropDown(
            title: loc.serviceDuration,
            value: _getServiceDurationLabel(_selectedServiceDuration),
            items: ["Hourly", "8 Hours", "12 Hours"],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  if (val == "Hourly") {
                    _selectedServiceDuration = 0;
                    _selectedEstimatedHours = 1;
                  } else if (val == "8 Hours") {
                    _selectedServiceDuration = 1;
                    _selectedEstimatedHours = 8;
                  } else if (val == "12 Hours") {
                    _selectedServiceDuration = 2;
                    _selectedEstimatedHours = 12;
                  }
                });
              }
            },
          ),
        ),
        if (_selectedServiceDuration == 0) ...[
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PremiumDropDown(
              title: "Estimated hours",
              value: _selectedEstimatedHours.toString(),
              items: List.generate(12, (index) => (index + 1).toString()),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedEstimatedHours = int.tryParse(val) ?? 1;
                  });
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  String _getServiceDurationLabel(int value) {
    switch (value) {
      case 0:
        return "Hourly";
      case 1:
        return "8 Hours";
      case 2:
        return "12 Hours";
      default:
        return "Hourly";
    }
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
            // spacing: 8, // This is not a valid property for Column
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDropLocation ? loc.dropLocation : loc.pickupLocation,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              SizedBox(height: 8), // Added SizedBox for spacing
              GestureDetector(
                onTap: () async {
                  double initLat = 24.7136; // Default: Riyadh
                  double initLng = 46.6753;

                  if (_apiCities.isNotEmpty &&
                      _selectedCityCode < _apiCities.length) {
                    final cityData = _apiCities[_selectedCityCode];
                    final latVal = cityData['lat'] ?? cityData['latitude'];
                    final lngVal =
                        cityData['long'] ??
                        cityData['lng'] ??
                        cityData['longitude'];

                    if (latVal != null && lngVal != null) {
                      initLat = double.tryParse(latVal.toString()) ?? 24.7136;
                      initLng = double.tryParse(lngVal.toString()) ?? 46.6753;
                    } else {
                      // Fallback name-based lookup
                      String selectedCity = _getCityName(
                        context,
                        _selectedCityCode,
                      );
                      if (selectedCity.toLowerCase().contains("dammam")) {
                        initLat = 26.3927;
                        initLng = 49.9777;
                      } else if (selectedCity.toLowerCase().contains(
                        "jeddah",
                      )) {
                        initLat = 21.4858;
                        initLng = 39.1925;
                      }
                    }
                  }

                  FocusScope.of(context).requestFocus(FocusNode());
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
                    FocusScope.of(context).requestFocus(FocusNode());
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
    final airports = _getAvailableAirports(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: PremiumDropDown(
        title: loc.airport,
        value: airports.isNotEmpty
            ? (_selectedAirportCode < airports.length
                  ? airports[_selectedAirportCode]
                  : airports.first)
            : "",
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _selectedAirportCode = airports.indexOf(val);
              _selectedTerminalCode = 0;
            });
          }
        },
        items: airports,
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
                        FocusScope.of(context).requestFocus(FocusNode());
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
                          FocusScope.of(context).requestFocus(FocusNode());
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
                        FocusScope.of(context).requestFocus(FocusNode());
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
                        await showDialog(
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
                        FocusScope.of(context).requestFocus(FocusNode());
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
            onPressed: _handleBackAction,
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

  /// Get simplified list of city names for dropdowns
  List<String> _getAvailableCityNames(BuildContext context) {
    if (_apiCities.isNotEmpty) {
      return _apiCities.map((c) => c['cityName'].toString()).toSet().toList();
    }
    return [];
  }

  /// Get airports based on selected city (using cityID from _apiCities)
  List<String> _getAvailableAirports(BuildContext context) {
    if (_apiCities.isNotEmpty && _apiAirports.isNotEmpty) {
      try {
        if (_selectedCityCode < _apiCities.length) {
          final city = _apiCities[_selectedCityCode];
          final cityId = (city['_id'] ?? city['id'])?.toString();

          final filtered = _apiAirports
              .where((a) {
                var aCityId = a['cityID'] ?? a['cityId'] ?? a['city_id'];
                if (aCityId is Map) {
                  aCityId = aCityId['_id'] ?? aCityId['id'];
                }
                final aCityIdStr = aCityId?.toString();
                return aCityIdStr != null && aCityIdStr == cityId;
              })
              .map((a) => a['airportName'].toString())
              .toSet()
              .toList();

          if (filtered.isNotEmpty) return filtered;
        }
      } catch (e) {
        debugPrint('Error filtering airports: $e');
      }
    }
    return [];
  }

  /// Get terminals based on selected airport
  List<String> _getAvailableTerminals(BuildContext context) {
    if (_apiAirports.isNotEmpty && _apiTerminals.isNotEmpty) {
      try {
        final airportNames = _getAvailableAirports(context);
        if (airportNames.isNotEmpty) {
          // Find the selected airport object to get its ID
          final selectedAirportName =
              airportNames[_selectedAirportCode < airportNames.length
                  ? _selectedAirportCode
                  : 0];

          final airport = _apiAirports.firstWhere(
            (a) => a['airportName']?.toString() == selectedAirportName,
            orElse: () => _apiAirports.firstWhere(
              (a) => true, // Just to have a fallback if names don't match
              orElse: () => {},
            ),
          );

          if (airport.isNotEmpty) {
            final airportId = (airport['_id'] ?? airport['id'])?.toString();

            final filtered = _apiTerminals
                .where((t) {
                  var tAirportId =
                      t['airportID'] ?? t['airportId'] ?? t['airport_id'];
                  if (tAirportId is Map) {
                    tAirportId = tAirportId['_id'] ?? tAirportId['id'];
                  }
                  final tAirportIdStr = tAirportId?.toString();
                  return tAirportIdStr != null && tAirportIdStr == airportId;
                })
                .map((t) => t['terminalName'].toString())
                .toSet()
                .toList();

            if (filtered.isNotEmpty) return filtered;
          }
        }
      } catch (e) {
        debugPrint('Error filtering terminals: $e');
      }
    }
    return [];
  }

  String? _getSelectedTerminalName(BuildContext context) {
    final terminals = _getAvailableTerminals(context);
    if (terminals.isNotEmpty) {
      return terminals[_selectedTerminalCode < terminals.length
          ? _selectedTerminalCode
          : 0];
    }
    return "";
  }

  String? _getSelectedAirportName(BuildContext context) {
    final airports = _getAvailableAirports(context);
    if (airports.isNotEmpty) {
      return airports[_selectedAirportCode < airports.length
          ? _selectedAirportCode
          : 0];
    }
    return "";
  }

  String? _getSelectedCityId() {
    if (_apiCities.isNotEmpty && _selectedCityCode < _apiCities.length) {
      final city = _apiCities[_selectedCityCode];
      return (city['_id'] ?? city['id'])?.toString();
    }
    return null;
  }

  String? _getSelectedAirportId() {
    if (_apiAirports.isNotEmpty) {
      final airportNames = _getAvailableAirports(context);
      if (airportNames.isNotEmpty) {
        final selectedAirportName =
            airportNames[_selectedAirportCode < airportNames.length
                ? _selectedAirportCode
                : 0];
        try {
          final airport = _apiAirports.firstWhere(
            (a) => a['airportName']?.toString() == selectedAirportName,
            orElse: () => {},
          );
          return (airport['_id'] ?? airport['id'])?.toString();
        } catch (e) {
          return null;
        }
      }
    }
    return null;
  }

  String? _getSelectedTerminalId() {
    if (_apiTerminals.isNotEmpty) {
      final terminalNames = _getAvailableTerminals(context);
      if (terminalNames.isNotEmpty) {
        final selectedTerminalName =
            terminalNames[_selectedTerminalCode < terminalNames.length
                ? _selectedTerminalCode
                : 0];
        try {
          final terminal = _apiTerminals.firstWhere(
            (t) => t['terminalName']?.toString() == selectedTerminalName,
            orElse: () => {},
          );
          return (terminal['_id'] ?? terminal['id'])?.toString();
        } catch (e) {
          return null;
        }
      }
    }
    return null;
  }

  String? _getSelectedCarId() {
    if (_cars.isNotEmpty) {
      try {
        final selectedCar = _cars.firstWhere(
          (c) =>
              c.className == _selectedVehicleClass &&
              c.brand == _selectedVehicleBrand &&
              c.modelName == _selectedVehicleModel,
          orElse: () => CarModel(
            id: '',
            className: '',
            brand: '',
            modelName: '',
            imagePath: '',
            price: 0,
            distance: 0,
            maxPassengers: 0,
          ),
        );
        return selectedCar.id.isNotEmpty ? selectedCar.id : null;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  String? _getSelectedBrandId() {
    // 1. Try to find from the selected car in _cars list (most reliable if car was loaded via API)
    if (_cars.isNotEmpty) {
      try {
        final selectedCar = _cars.firstWhere(
          (c) =>
              c.className == _selectedVehicleClass &&
              c.brand == _selectedVehicleBrand &&
              c.modelName == _selectedVehicleModel,
          orElse: () => CarModel(
            id: '',
            className: '',
            brand: '',
            modelName: '',
            imagePath: '',
            price: 0,
            distance: 0,
            maxPassengers: 0,
          ),
        );
        if (selectedCar.brandId != null && selectedCar.brandId!.isNotEmpty) {
          return selectedCar.brandId;
        }
      } catch (_) {}
    }

    // 2. Fallback to searching the _brands list
    if (_brands.isNotEmpty && _selectedVehicleBrand != null) {
      try {
        final brand = _brands.firstWhere(
          (b) =>
              (b['brandName']?.toString() == _selectedVehicleBrand ||
              b['name']?.toString() == _selectedVehicleBrand ||
              b['brand']?.toString() == _selectedVehicleBrand),
          orElse: () => {},
        );
        return (brand['_id'] ?? brand['id'] ?? brand['brandID'])?.toString();
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  String? _getSelectedCategoryId() {
    // 1. Try to find from the selected car in _cars list
    if (_cars.isNotEmpty) {
      try {
        final selectedCar = _cars.firstWhere(
          (c) =>
              c.className == _selectedVehicleClass &&
              c.brand == _selectedVehicleBrand &&
              c.modelName == _selectedVehicleModel,
          orElse: () => CarModel(
            id: '',
            className: '',
            brand: '',
            modelName: '',
            imagePath: '',
            price: 0,
            distance: 0,
            maxPassengers: 0,
          ),
        );
        if (selectedCar.categoryId != null &&
            selectedCar.categoryId!.isNotEmpty) {
          return selectedCar.categoryId;
        }
      } catch (_) {}
    }

    // 2. Fallback to searching the _apiCategories list
    if (_apiCategories.isNotEmpty && _selectedVehicleClass != null) {
      try {
        final category = _apiCategories.firstWhere(
          (c) =>
              (c['name']?.toString() == _selectedVehicleClass ||
              c['categoryName']?.toString() == _selectedVehicleClass ||
              c['category_name']?.toString() == _selectedVehicleClass),
          orElse: () => {},
        );
        return (category['_id'] ?? category['id'])?.toString();
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Helper to safely convert dynamic raw data from API to a list of maps
  List<Map<String, dynamic>> rawDataToList(dynamic rawData) {
    if (rawData is List) {
      return rawData
          .map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          })
          .where((m) => m.isNotEmpty)
          .toList();
    }
    return [];
  }
}
