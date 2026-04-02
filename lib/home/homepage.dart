import 'package:premium_force_main/common_widgets/fleet_card_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/notifications/notification_screen.dart';
import 'package:premium_force_main/storage/notification_storage.dart';
import 'package:premium_force_main/models/notification_model.dart';
import 'package:flutter_svg/svg.dart';
import 'package:premium_force_main/common_widgets/borderedcontainer.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/premuimfleetcard.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/main.dart';
import 'package:premium_force_main/ride_booking/new_booking.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_main/providers/auth_provider.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_main/common_widgets/infinite_scroll_banner.dart';
import 'package:premium_force_main/models/booking_model.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/common_widgets/bookingcard.dart';
import 'package:premium_force_main/bookings/booking_details_page.dart';
import 'package:premium_force_main/home/fleet_list_page.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _fleetCars = [];
  List<Map<String, dynamic>> _apiCities = [];
  List<Map<String, dynamic>> _apiAirports = [];
  List<Map<String, dynamic>> _apiTerminals = [];
  List<BookingModel> _pastBookings = [];
  bool _isLoadingLocations = false;
  bool _isLoadingCars = false;
  bool _isLoadingBookings = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Load from cache first for zero-latency UI
    _loadCachedFleet();
    // Fetch fresh data in the background
    _fetchLocationData();
    _fetchFleetCars();
    _fetchPastBookings();
  }

  void _loadCachedFleet() {
    final cached = UserLocalStorage.getFleetCars();
    if (cached != null && cached.isNotEmpty) {
      if (mounted) {
        setState(() {
          _fleetCars = _rearrangeFleet(cached);
        });
      }
    }
  }

  List<Map<String, dynamic>> _rearrangeFleet(List<Map<String, dynamic>> allCars) {
    List<Map<String, dynamic>> cars = [];
    List<Map<String, dynamic>> suvs = [];
    List<Map<String, dynamic>> buses = [];

    for (var car in allCars) {
      final name = (car['name'] ?? '').toString().toLowerCase();
      final brand = (car['brand'] ?? '').toString().toLowerCase();
      final category = (car['category'] ?? '').toString().toLowerCase();
      final passengers = int.tryParse(car['passengerCount']?.toString() ?? '0') ?? 0;

      // Logic to identify Bus/Van
      if (category.contains('bus') || 
          category.contains('van') || 
          category.contains('minibus') || 
          name.contains('sprinter') || 
          name.contains('coaster') ||
          passengers > 7) {
        if (buses.length < 2) buses.add(car);
      } 
      // Logic to identify SUV
      else if (category.contains('suv') || 
               name.contains('yukon') || 
               name.contains('escalade') || 
               name.contains('tahoe') ||
               brand.contains('gmc')) {
        if (suvs.length < 2) suvs.add(car);
      } 
      // Everything else (Sedans/Cars)
      else {
        if (cars.length < 2) cars.add(car);
      }
    }

    // Combine them 2-2-2
    List<Map<String, dynamic>> rearranged = [...cars, ...suvs, ...buses];
    
    // Fill up to 10 if we have more cars in cache to provide a good carousel
    if (rearranged.length < 10) {
      for (var car in allCars) {
        if (!rearranged.contains(car)) {
          rearranged.add(car);
          if (rearranged.length >= 10) break;
        }
      }
    }
    
    return rearranged;
  }

  Future<void> _handleRefresh() async {
    // Force reload everything
    await Future.wait([
      _fetchLocationData(),
      _fetchFleetCars(),
      _fetchPastBookings(),
    ]);
  }

  Future<void> _fetchLocationData() async {
    if (mounted) setState(() => _isLoadingLocations = true);
    try {
      final api = ApiService();

      // Fetch everything in parallel for a smoother experience later
      final results =
          await Future.wait([
            api.getCities(),
            api.getAirports(),
            api.getTerminals(),
          ]).catchError((e) {
            debugPrint('❌ Error fetching location data: $e');
            return <Map<String, dynamic>>[{}, {}, {}];
          });

      if (mounted) {
        setState(() {
          // Helper to extract list data from various response formats
          List<Map<String, dynamic>> extractListData(
            Map<String, dynamic> response,
            List<String> possibleKeys,
          ) {
            if (response['success'] != true) {
              if (kDebugMode) {
                debugPrint(
                  '🌐 API │ Response not successful: ${response['message'] ?? 'Unknown error'}',
                );
              }
              return [];
            }

            // Try each possible key
            for (String key in possibleKeys) {
              if (response.containsKey(key)) {
                dynamic data = response[key];
                if (kDebugMode) {
                  debugPrint('🌐 API │ Found data in key "$key": $data');
                }
                return rawDataToList(data);
              }
            }

            // If none of the known keys work, search for any array in the response
            if (kDebugMode) {
              debugPrint(
                '🌐 API │ No known keys found. Available keys: ${response.keys.toList()}',
              );
              debugPrint('🌐 API │ Full response: $response');
            }

            for (MapEntry<String, dynamic> entry in response.entries) {
              if (entry.value is List) {
                if (kDebugMode) {
                  debugPrint('🌐 API │ Found array in key "${entry.key}"');
                }
                return rawDataToList(entry.value);
              }
            }

            return [];
          }

          // Process Cities
          _apiCities = extractListData(results[0], [
            'cities',
            'data',
            'result',
          ]).where((c) => c['isActive'] == true).toList();

          // Process Airports
          _apiAirports = extractListData(results[1], [
            'airports',
            'data',
            'result',
          ]);

          // Process Terminals
          _apiTerminals = extractListData(results[2], [
            'terminals',
            'data',
            'result',
          ]);
        });

        if (kDebugMode) {
          debugPrint(
            '✅ 🌐 API │ Location Data Loaded - Cities: ${_apiCities.length}, Airports: ${_apiAirports.length}, Terminals: ${_apiTerminals.length}',
          );
          if (_apiCities.isNotEmpty) {
            debugPrint('🌐 API │ Sample city: ${_apiCities.first}');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ General error in _fetchLocationData: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  List<Map<String, dynamic>> rawDataToList(dynamic rawData) {
    if (rawData == null) {
      if (kDebugMode) debugPrint('🌐 API │ rawDataToList received null data');
      return [];
    }

    if (rawData is List) {
      if (kDebugMode)
        debugPrint(
          '🌐 API │ rawDataToList processing list with ${rawData.length} items',
        );
      return rawData
          .map((item) {
            if (item is Map) return Map<String, dynamic>.from(item);
            return <String, dynamic>{};
          })
          .where((m) => m.isNotEmpty)
          .toList();
    }

    if (kDebugMode)
      debugPrint(
        '🌐 API │ rawDataToList received non-list data: ${rawData.runtimeType}',
      );
    return [];
  }

  Future<void> _fetchFleetCars() async {
    if (mounted) setState(() => _isLoadingCars = true);
    try {
      final api = ApiService();
      final response = await api.getCars().catchError((e) {
        debugPrint('❌ Error fetching cars list: $e');
        return <String, dynamic>{};
      });

      if (mounted) {
        if (response['success'] == true) {
          // Extract list data from various response formats
          List<Map<String, dynamic>> carList = [];

          // Try common keys
          for (String key in ['cars', 'data', 'result']) {
            if (response.containsKey(key)) {
              final data = response[key];
              carList = rawDataToList(data);
              if (carList.isNotEmpty) break;
            }
          }

          // If still empty, search for any array in the response
          if (carList.isEmpty) {
            for (MapEntry<String, dynamic> entry in response.entries) {
              if (entry.value is List) {
                carList = rawDataToList(entry.value);
                if (carList.isNotEmpty) {
                  if (kDebugMode) {
                    debugPrint('🌐 API │ Found cars in key "${entry.key}"');
                  }
                  break;
                }
              }
            }
          }

          if (kDebugMode) {
            debugPrint(
              '✅ 🌐 API │ Cars list loaded: ${carList.length} cars total',
            );
          }

          // Take up to 20 cars from the list (for reasonable detail fetch time)
          List<String> carIds =
              carList.reversed
                  .take(20)
                  .map((car) {
                    return car['_id']?.toString() ??
                        car['id']?.toString() ??
                        '';
                  })
                  .where((id) => id.isNotEmpty)
                  .toList();

          if (kDebugMode) {
            debugPrint('🌐 API │ Selected car IDs for fleet: $carIds');
          }

          // Fetch full details for all selected cars
          await _fetchFleetCarsDetails(carIds);
        } else {
          if (kDebugMode) {
            debugPrint(
              '🌐 API │ Cars response not successful: ${response['message'] ?? 'Unknown error'}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ General error in _fetchFleetCars: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCars = false);
    }
  }

  Future<void> _fetchFleetCarsDetails(List<String> carIds) async {
    try {
      final api = ApiService();
      List<Map<String, dynamic>> detailedCars = [];

      // To improve speed, fetch details in parallel
      final detailsFutures = carIds.map(
        (id) => api.getCarById(id).catchError((e) => <String, dynamic>{}),
      );
      final detailResponses = await Future.wait(detailsFutures);

      for (int i = 0; i < detailResponses.length; i++) {
        final carResponse = detailResponses[i];
        final carId = carIds[i];

        if (carResponse['success'] == true) {
          // Extract car data from response
          Map<String, dynamic>? carData;
          if (carResponse.containsKey('data')) {
            carData = Map<String, dynamic>.from(carResponse['data']);
          } else if (carResponse.containsKey('car')) {
            carData = Map<String, dynamic>.from(carResponse['car']);
          }

          if (carData != null) {
            // Handle brand information which could be an object or a string ID
            dynamic brandDataObj =
                carData['brandID'] ?? carData['brandId'] ?? carData['brand'];
            String brandId = '';
            String brandName = 'Unknown';
            String? brandLogoUrl;

            if (brandDataObj is Map) {
              brandId =
                  brandDataObj['_id']?.toString() ??
                  brandDataObj['id']?.toString() ??
                  '';
              brandName =
                  brandDataObj['brandName']?.toString() ??
                  brandDataObj['name']?.toString() ??
                  'Unknown';

              // If the brandIcon is already there, extract the URL
              if (brandDataObj.containsKey('brandIcon')) {
                final icon = brandDataObj['brandIcon'];
                if (icon is Map && icon.containsKey('url')) {
                  brandLogoUrl = icon['url']?.toString();
                }
              }
            } else if (brandDataObj != null) {
              brandId = brandDataObj.toString();
            }

            // Extract car image URL
            String carImageUrl = '';
            if (carData['carImage'] != null && carData['carImage'] is Map) {
              carImageUrl = carData['carImage']['url']?.toString() ?? '';
            } else {
              carImageUrl =
                  carData['imagePath']?.toString() ??
                  carData['image']?.toString() ??
                  '';
            }

            detailedCars.add({
              'id': carData['_id']?.toString() ?? carId,
              'brand': brandName,
              'brandId': brandId,
              'brandLogoUrl': brandLogoUrl,
              'category': (carData['categoryID']?['categoryName'] ?? carData['categoryID']?['name'] ?? '').toString(),
              'name':
                  carData['carName']?.toString() ??
                  carData['modelName']?.toString() ??
                  'Model',
              'passengerCount':
                  (carData['numberOfPassengers'] ?? 4).toString(),
              'image': carImageUrl,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _fleetCars = _rearrangeFleet(detailedCars);
        });
        // Cache the newly fetched results (cache the whole detailed list)
        await UserLocalStorage.saveFleetCars(detailedCars);
      }

      if (kDebugMode) {
        debugPrint(
          '✅ 🌐 API │ Fleet Cars Details Loaded: ${_fleetCars.length} cars',
        );
        if (_fleetCars.isNotEmpty) {
          debugPrint('🌐 API │ Sample car: ${_fleetCars.first}');
        }
      }

      // Fetch brand logos for each car
      _fetchBrandLogos();
    } catch (e) {
      debugPrint('❌ General error in _fetchFleetCarsDetails: $e');
    }
  }

  Future<void> _fetchBrandLogos() async {
    try {
      final api = ApiService();

      for (int i = 0; i < _fleetCars.length; i++) {
        final car = _fleetCars[i];
        final brandId = car['brandId'];
        final existingLogo = car['brandLogoUrl'];

        // Skip if no brandId or if logo URL already exists (extracted from car details)
        if (brandId.isEmpty ||
            (existingLogo != null && existingLogo.isNotEmpty)) {
          if (kDebugMode) {
            debugPrint(
              '🌐 API │ Skipping car at index $i - brandId empty or logo already exists',
            );
          }
          continue;
        }

        if (kDebugMode) {
          debugPrint(
            '🌐 API │ Fetching brand logo for ${car['brand']} (ID: $brandId)',
          );
        }

        final brandResponse = await api.getBrandById(brandId).catchError((e) {
          debugPrint('❌ Error fetching brand details for $brandId: $e');
          return <String, dynamic>{};
        });

        if (kDebugMode) {
          debugPrint('🌐 API │ Brand response: $brandResponse');
        }

        if (brandResponse['success'] == true) {
          // Extract brand data - the response structure has data.brandInfo.icon.url
          Map<String, dynamic>? brandData;

          // Try to get data from various possible response formats
          if (brandResponse.containsKey('data')) {
            final data = brandResponse['data'];
            if (data is Map) {
              brandData = Map<String, dynamic>.from(data);
            }
          }

          if (brandData != null) {
            if (kDebugMode) {
              debugPrint('🌐 API │ Brand data extracted: $brandData');
            }

            // Try to extract logo URL from brandInfo.icon.url (correct structure)
            String? logoUrl;

            // Primary: data.brandInfo.icon.url
            if (brandData.containsKey('brandInfo')) {
              final brandInfo = brandData['brandInfo'];
              if (brandInfo is Map && brandInfo.containsKey('icon')) {
                final icon = brandInfo['icon'];
                if (icon is Map && icon.containsKey('url')) {
                  logoUrl = icon['url']?.toString();
                }
              }
            }

            // Fallback: Search for other possible paths
            if (logoUrl == null || logoUrl.isEmpty) {
              logoUrl =
                  brandData['logo']?.toString() ??
                  brandData['image']?.toString() ??
                  brandData['imagePath']?.toString() ??
                  brandData['icon']?.toString();
            }

            if (logoUrl != null && logoUrl.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _fleetCars[i]['brandLogoUrl'] = logoUrl;
                });
              }

              if (kDebugMode) {
                debugPrint(
                  '✅ 🌐 API │ Brand logo fetched for ${car['brand']}: $logoUrl',
                );
              }
            } else {
              if (kDebugMode) {
                debugPrint(
                  '🌐 API │ No logo URL found in brand data for ${car['brand']}',
                );
              }
            }
          } else {
            if (kDebugMode) {
              debugPrint(
                '🌐 API │ Could not extract brand data from response: $brandResponse',
              );
            }
          }
        } else {
          if (kDebugMode) {
            debugPrint(
              '🌐 API │ Brand fetch not successful for $brandId: ${brandResponse['message'] ?? 'Unknown error'}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ General error in _fetchBrandLogos: $e');
    }
  }

  /*
  List bookingItems = [
    {
      "status": "c",
      "type": "Airport Arrival",
      "pickup": "King Khalid International Airport",
      "dropoff": "City Center, Riyadh",
      "date": "13 Feb",
      "time": "12:30 PM",
      "ride": "Luxury",
      "brand": "Mercedes-Benz",
    },
    {
      "status": "p",
      "type": "Airport Departure",
      "pickup": "King Khalid International Airport",
      "dropoff": "City Center, Riyadh",
      "date": "14 Feb",
      "time": "12:30 PM",
      "ride": "Luxury",
      "brand": "BMW",
    },
    {
      "status": "x",
      "type": "Chauffeur",
      "pickup": "City Center, Riyadh",
      "dropoff": "Hotel Al Faisaliah",
      "date": "14 Feb",
      "time": "09:00 PM",
      "ride": "Luxury",
      "brand": "Audi",
    },
    {
      "status": "x",
      "type": "Chauffeur",
      "pickup": "City Center, Riyadh",
      "dropoff": "Hotel Al Faisaliah",
      "date": "14 Feb",
      "time": "09:00 PM",
      "ride": "Luxury",
      "brand": "Rolls-Royce",
    },
  ];

  List bookingItemsAr = [
    {
      "status": "c",
      "type": "وصول من المطار",
      "pickup": "مطار الملك خالد الدولي",
      "dropoff": "وسط المدينة، الرياض",
      "date": "13 فبراير",
      "time": "12:30 م",
      "ride": "فاخر",
      "brand": "مرسيدس-بنز",
    },
    {
      "status": "p",
      "type": "مغادرة إلى المطار",
      "pickup": "مطار الملك خالد الدولي",
      "dropoff": "وسط المدينة، الرياض",
      "date": "14 فبراير",
      "time": "12:30 م",
      "ride": "فاخر",
      "brand": "بي إم دبليو",
    },
    {
      "status": "x",
      "type": "سائق خاص",
      "pickup": "وسط المدينة، الرياض",
      "dropoff": "فندق الفيصلية",
      "date": "14 فبراير",
      "time": "09:00 م",
      "ride": "فاخر",
      "brand": "أودي",
    },
    {
      "status": "x",
      "type": "سائق خاص",
      "pickup": "وسط المدينة، الرياض",
      "dropoff": "فندق الفيصلية",
      "date": "14 فبراير",
      "time": "09:00 م",
      "ride": "فاخر",
      "brand": "رولز رويس",
    },
  ];
  */

  Future<void> _fetchPastBookings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    if (userId == null) return;

    if (mounted) setState(() => _isLoadingBookings = true);

    try {
      final api = ApiService();
      final token = UserLocalStorage.getToken();

      final results = await Future.wait([
        api.getBookingsByCustomerId(customerId: userId, token: token),
        api.getHourlyBookingsByCustomerId(customerId: userId, token: token),
      ]);

      List<BookingModel> userBookings = [];

      for (var result in results) {
        if (result['success'] == true) {
          final List<dynamic> bookingsJson =
              result['data'] ?? result['bookings'] ?? [];
          userBookings.addAll(
            bookingsJson.map((json) => BookingModel.fromJson(json)),
          );
        }
      }

      // Filter by status: completed or cancelled
      final pastBookings = userBookings.where((b) {
        final status = b.bookingStatus?.toLowerCase() ?? '';
        return status == 'completed' ||
            status == 'cancelled' ||
            status == 'c' ||
            status == 'x';
      }).toList();

      // Sort by date (descending)
      pastBookings.sort((a, b) {
        final dateA =
            a.createdAt ??
            (a.arrival != null ? DateTime.tryParse(a.arrival!) : null) ??
            DateTime(0);
        final dateB =
            b.createdAt ??
            (b.arrival != null ? DateTime.tryParse(b.arrival!) : null) ??
            DateTime(0);
        return dateB.compareTo(dateA); // Most recent first
      });

      if (mounted) {
        setState(() {
          _pastBookings = pastBookings.take(5).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching past bookings: $e');
    } finally {
      if (mounted) setState(() => _isLoadingBookings = false);
    }
  }

  String _getBookingName(String? category, BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (category == null) return 'Booking';
    switch (category.toLowerCase()) {
      case 'chauffeur':
        return loc.chauffeur;
      case 'airport arrival':
        return loc.airportArrival;
      case 'airport departure':
        return loc.airportDeparture;
      default:
        return 'Booking';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        color: Colors.amber,
        backgroundColor: Colors.black,
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAppbar(context, loc),
              SizedBox(height: 8),
              _buildBookService(context, loc),
              _buildPremiumFleet(context, loc),
              Flexible(child: _buildRecentBookings(context, loc)),
              Container(
                height: 130,
                color: Color(0xff292929).withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentBookings(BuildContext context, AppLocalizations loc) {
    return Container(
      color: const Color(0xff292929).withValues(alpha: 0.6),
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.only(left: 24, right: 24, top: 12),
      child: Column(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            loc.recentBookings,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (_isLoadingBookings)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: PremiumLoader(color: Color(0xFFE4A46B))),
            )
          else if (_pastBookings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 36,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(80),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withAlpha(20)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 42,
                        color: Colors.grey.withAlpha(120),
                      ),
                      SizedBox(height: 12),
                      Text(
                        loc.noRecentBookings,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              itemCount: _pastBookings.length,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 12),
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final booking = _pastBookings[index];
                final arrivalDate = booking.arrival != null
                    ? DateTime.tryParse(booking.arrival!)
                    : null;
                final dateStr = Bookingcard.formatDate(context, arrivalDate);
                final timeStr = Bookingcard.formatTime(context, arrivalDate);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              BookingDetailsPage(booking: booking),
                        ),
                      );
                      if (result == true) {
                        _fetchPastBookings();
                      }
                    },
                    child: Bookingcard(
                      status: booking.bookingStatus ?? 'Pending',
                      type: _getBookingName(booking.category, context),
                      pickup: booking.pickupAddress ?? booking.airport ?? 'N/A',
                      dropoff: booking.dropOffAddress ?? 'N/A',
                      date: dateStr,
                      time: timeStr,
                      ride: booking.displayName,
                      brand: booking.displayBrand,
                      passengers:
                          int.tryParse(booking.passengerCount ?? '1') ?? 1,
                      isChauffeur:
                          (booking.category ?? '').toLowerCase().contains(
                            'chauffeur',
                          ) ||
                          booking.estimatedHours != null,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumFleet(BuildContext context, AppLocalizations loc) {
    return Container(
      height: 230,
      color: Colors.black,
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.premiumFleet,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FleetListPage(),
                      ),
                    );
                  },
                  child: Text(
                    loc.showMore,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE4A46B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: _isLoadingCars
                ? ListView.builder(
                    itemCount: 3,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: index == 0 ? 24 : 6,
                          end: index == 2 ? 24 : 6,
                        ),
                        child: const PremuimfleetcardShimmer(),
                      );
                    },
                  )
                : _fleetCars.isEmpty
                ? Center(
                    child: Text(
                      loc.noCarsAvailable,
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: _fleetCars.length,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: index == 0 ? 24 : 6,
                          end: index == _fleetCars.length - 1 ? 24 : 6,
                        ),
                        child: Premuimfleetcard(
                          brand: _fleetCars[index]["brand"],
                          name: _fleetCars[index]["name"],
                          passengerCount: _fleetCars[index]["passengerCount"],
                          image: _fleetCars[index]["image"],
                          brandLogoUrl: _fleetCars[index]["brandLogoUrl"],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookService(BuildContext context, AppLocalizations loc) {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      height: 200,
      color: Color(0xFF401F02),
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.only(left: 24, right: 24, top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            loc.bookServices,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  _showAirportServiceSelection(context, loc);
                },
                child: PremiumContainer(
                  height: 120,
                  width: MediaQuery.of(context).size.width * 0.28,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 44,
                          width: 44,
                          child: SvgPicture.asset(
                            'assets/icons/arrival.svg',
                            fit: BoxFit.fill,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          loc.airportServices,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  showCitySelectionBottomSheet(context, loc, 3);
                },
                child: PremiumContainer(
                  height: 120,
                  width: MediaQuery.of(context).size.width * 0.28,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 44,
                          width: 44,
                          child: SvgPicture.asset(
                            'assets/icons/chauffeur.svg',
                            fit: BoxFit.fill,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          loc.privateTransfer,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  showCitySelectionBottomSheet(context, loc, 2);
                },
                child: PremiumContainer(
                  height: 120,
                  width: MediaQuery.of(context).size.width * 0.28,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 44,
                          width: 44,
                          child: Transform.scale(
                            scaleX: isArabic ? 1 : -1,
                            child: SvgPicture.asset(
                              'assets/icons/chauffeur.svg',
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          loc.chauffeurService,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppbar(BuildContext context, AppLocalizations loc) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.3,
      padding: const EdgeInsets.only(top: 50),
      decoration: BoxDecoration(
        image: DecorationImage(
          colorFilter: ColorFilter.mode(
            Color(0xFF1E1105).withAlpha(120),
            BlendMode.srcATop,
          ),
          image: AssetImage('assets/images/homeappbar.jpeg'),
          fit: BoxFit.none,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc.welcomeBack,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          String name =
                              Provider.of<AuthProvider>(
                                context,
                              ).user?.username ??
                              "User";
                          final style = const TextStyle(
                            fontSize: 35,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          );

                          String fittedName = name;
                          final textPainter = TextPainter(
                            text: TextSpan(text: fittedName, style: style),
                            maxLines: 1,
                            textDirection: Directionality.of(context),
                          )..layout(maxWidth: double.infinity);

                          if (textPainter.width > constraints.maxWidth) {
                            List<String> words = name.trim().split(
                              RegExp(r'\s+'),
                            );
                            while (words.length > 1) {
                              words.removeLast();
                              fittedName = words.join(' ');
                              textPainter.text = TextSpan(
                                text: fittedName,
                                style: style,
                              );
                              textPainter.layout(maxWidth: double.infinity);
                              if (textPainter.width <= constraints.maxWidth) {
                                break;
                              }
                            }
                          }

                          return Text(
                            fittedName,
                            style: style,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ValueListenableBuilder<List<AppNotification>>(
                  valueListenable: NotificationStorage.notificationsView,
                  builder: (context, notifications, child) {
                    final unreadCount = notifications
                        .where((n) => !n.isRead)
                        .length;
                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const NotificationScreen(),
                              ),
                            );
                          },
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  child: Material(
                    borderRadius: BorderRadius.circular(100),

                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: InkWell(
                        splashColor: Colors.grey.withAlpha(200),
                        borderRadius: BorderRadius.circular(100),
                        onTap: () {
                          bool isCurrentlyEnglish =
                              Localizations.localeOf(context).languageCode ==
                              'en';
                          MainApp.setLocale(
                            context,
                            Locale(isCurrentlyEnglish ? 'ar' : 'en'),
                          );
                        },
                        child: SvgPicture.asset(
                          Localizations.localeOf(context).languageCode == 'en'
                              ? 'assets/flags/en.svg'
                              : 'assets/flags/ar.svg',
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          const InfiniteScrollBanner(),
        ],
      ),
    );
  }

  void showCitySelectionBottomSheet(
    BuildContext context,
    AppLocalizations loc,
    int catcode,
  ) {
    bool isEnglish = Localizations.localeOf(context).languageCode == 'en';
    int selectedCityIndex = 0; // default to Riyadh

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF3E230A), Color(0xFF141313)],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 24,
                      ),
                      child: Row(
                        children: [
                          Text(
                            loc.chooseCity,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.grey, thickness: 1),
                    const SizedBox(height: 8),
                    _isLoadingLocations // Changed from _isLoadingCities
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: PremiumLoader(color: Color(0xFFE4A46B)),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 24,
                            ),
                            child: Builder(
                              builder: (context) {
                                final activeCities = _apiCities
                                    .where((c) => c['isActive'] == true)
                                    .toList();

                                if (activeCities.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      child: Text(
                                        isEnglish
                                            ? "No active cities available"
                                            : "لا توجد مدن نشطة متاحة",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: activeCities.asMap().entries.map((
                                        entry,
                                      ) {
                                        final index = entry.key;
                                        final city = entry.value;
                                        final String cityName =
                                            city['cityName'] ?? 'Unknown';

                                        // API image handling - the 'image' field is a Map containing 'url'
                                        String? imageUrl;
                                        if (city['image'] != null) {
                                          if (city['image'] is String) {
                                            imageUrl = city['image'];
                                          } else if (city['image'] is Map &&
                                              city['image']['url'] != null) {
                                            imageUrl = city['image']['url'];
                                          }
                                        }

                                        // Modernize relative paths
                                        if (imageUrl != null &&
                                            imageUrl.isNotEmpty &&
                                            !imageUrl.startsWith('http') &&
                                            !imageUrl.startsWith('assets/')) {
                                          const String host =
                                              'https://api.premiumforcegroup.com';
                                          imageUrl = imageUrl.startsWith('/')
                                              ? '$host$imageUrl'
                                              : '$host/$imageUrl';
                                        }

                                        final String displayImage =
                                            imageUrl ??
                                            'assets/images/riyadh.png';

                                        return SizedBox(
                                          width:
                                              (constraints.maxWidth - 24) /
                                              3, // 3 columns
                                          child: _buildCityTile(
                                            isEnglish: isEnglish,
                                            isSelected:
                                                selectedCityIndex == index,
                                            nameEn: cityName,
                                            nameAr: cityName,
                                            image: displayImage,
                                            isApiImage: imageUrl != null,
                                            onTap: () => setState(
                                              () => selectedCityIndex = index,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: PremiumButton(
                        showLoader: false,
                        borderRadius: 12,
                        text: loc.continueText,
                        onTap: () {
                          final activeCities = _apiCities
                              .where((c) => c['isActive'] == true)
                              .toList();
                          if (activeCities.isEmpty) return;

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => NewBooking(
                                catcode: catcode,
                                citycode: selectedCityIndex,
                                preloadedCities: activeCities,
                                preloadedAirports: _apiAirports,
                                preloadedTerminals: _apiTerminals,
                              ),
                            ),
                          );
                        },
                        fontsize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCityTile({
    required bool isEnglish,
    required bool isSelected,
    required String nameEn,
    required String nameAr,
    required String image,
    bool isApiImage = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 125,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFE4A46B) : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Image Layer
              Positioned.fill(
                child: isApiImage
                    ? CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.black26,
                          child: const Center(
                            child: PremiumLoader(
                              color: Color(0xFFE4A46B),
                              size: 20,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      )
                    : Image.asset(image, fit: BoxFit.cover),
              ),
              // Gradient Overlay for text readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(20),
                        Colors.black.withAlpha(150),
                      ],
                    ),
                  ),
                ),
              ),
              // Content Layer
              Align(
                alignment: isEnglish
                    ? Alignment.bottomLeft
                    : Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    isEnglish ? nameEn : nameAr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 6,
                  right: isEnglish ? 6 : null,
                  left: !isEnglish ? 6 : null,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE4A46B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAirportServiceSelection(
    BuildContext context,
    AppLocalizations loc,
  ) {
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3E230A), Color(0xFF141313)],
            ),
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      loc.serviceType,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Divider(),

              Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          showCitySelectionBottomSheet(context, loc, 0);
                        },
                        child: PremiumContainer(
                          height: 101,
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 44,
                                  width: 44,
                                  child: Transform.scale(
                                    scaleX: isArabic ? -1 : 1,
                                    child: SvgPicture.asset(
                                      'assets/icons/arrival.svg',
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  loc.airportArrival,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          showCitySelectionBottomSheet(context, loc, 1);
                        },
                        child: PremiumContainer(
                          height: 101,
                          width: MediaQuery.of(context).size.width * 0.42,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 44,
                                  width: 44,
                                  child: Transform.scale(
                                    scaleX: isArabic ? -1 : 1,
                                    child: SvgPicture.asset(
                                      'assets/icons/departure.svg',
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  loc.airportDeparture,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 45),
            ],
          ),
        );
      },
    );
  }
}
