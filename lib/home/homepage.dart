import 'package:premium_force_main/common_widgets/fleet_card_shimmer.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:premium_force_main/common_widgets/booking_shimmer.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/notifications/notification_screen.dart';
import 'package:premium_force_main/providers/notification_provider.dart';
import 'package:flutter_svg/svg.dart';
import 'package:premium_force_main/common_widgets/borderedcontainer.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/premuimfleetcard.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/main.dart';
import 'package:premium_force_main/ride_booking/new_booking.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_main/providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:premium_force_main/common_widgets/infinite_scroll_banner.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/common_widgets/bookingcard.dart';
import 'package:premium_force_main/utils/date_display.dart';
import 'package:premium_force_main/bookings/booking_details_page.dart';
import 'package:premium_force_main/models/v2/booking_service_type.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/models/v2/geo_models.dart';
import 'package:premium_force_main/providers/booking_provider.dart';
import 'package:premium_force_main/home/fleet_list_page.dart';
import 'package:premium_force_main/common_widgets/tracking_card.dart';
import 'package:premium_force_main/common_widgets/gold_icon.dart';
import 'package:premium_force_main/theme/app_palette.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _fleetCars = [];
  List<Map<String, dynamic>> _apiCities = [];
  List<Map<String, dynamic>> _apiAirports = [];
  List<Map<String, dynamic>> _apiTerminals = [];
  final ValueNotifier<bool> _isLoadingLocations = ValueNotifier(false);
  bool _isLoadingCars = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load from cache first for zero-latency UI
    _loadCachedFleet();
    // Fetch fresh data in the background
    _fetchLocationData();
    _fetchFleetCars();
    _fetchFleetCars();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<BookingProvider>(context, listen: false).fetchBookings();
        // Populates the unread badge in the app bar; the notification centre
        // re-reads the feed itself when opened.
        Provider.of<NotificationProvider>(context, listen: false).refresh();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isLoadingLocations.dispose();
    super.dispose();
  }

  /// Re-read the bookings when the app comes back to the foreground.
  ///
  /// A push delivered while the app was backgrounded never reaches the handler
  /// in `main` — that only runs for a message received by a live app, or one
  /// the customer taps — so the driver could have set off, and the tracking
  /// card would still not be there on return. This screen is also kept alive by
  /// [AutomaticKeepAliveClientMixin], so `initState` will not run again to do
  /// it.
  ///
  /// Silent: the customer did not ask, so the rows change under them rather
  /// than the screen dropping into a spinner.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed || !mounted) return;
    context.read<BookingProvider>().fetchBookings(silent: true);
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

  List<Map<String, dynamic>> _rearrangeFleet(
    List<Map<String, dynamic>> allCars,
  ) {
    List<Map<String, dynamic>> cars = [];
    List<Map<String, dynamic>> suvs = [];
    List<Map<String, dynamic>> buses = [];

    for (var car in allCars) {
      final name = (car['name'] ?? '').toString().toLowerCase();
      final brand = (car['brand'] ?? '').toString().toLowerCase();
      final category = (car['category'] ?? '').toString().toLowerCase();
      final passengers =
          int.tryParse(car['passengerCount']?.toString() ?? '0') ?? 0;

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
      Provider.of<BookingProvider>(context, listen: false).fetchBookings(),
    ]);
  }

  Future<void> _fetchLocationData() async {
    if (mounted) {
      _isLoadingLocations.value = true;
    }
    try {
      final api = ApiService();

      // Fetch everything in parallel for a smoother experience later
      final results =
          await Future.wait([
            api.getCities(),
            api.getAirports(),
            api.getTerminals(),
          ]).catchError((e) {
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
              return [];
            }

            // Try each possible key
            for (String key in possibleKeys) {
              if (response.containsKey(key)) {
                dynamic data = response[key];
                return rawDataToList(data);
              }
            }

            // If none of the known keys work, search for any array in the response

            for (MapEntry<String, dynamic> entry in response.entries) {
              if (entry.value is List) {
                return rawDataToList(entry.value);
              }
            }

            return [];
          }

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

          // Process Cities - only include cities that are active
          _apiCities = extractListData(results[0], ['cities', 'data', 'result'])
              .where((c) {
                final active = c['isActive'];
                return active == true ||
                    active == 1 ||
                    active.toString() == 'true';
              })
              .toList();
        });
      }
    } catch (e) {
    } finally {
      if (mounted) {
        _isLoadingLocations.value = false;
        setState(() {}); // Still call setState for other data (cities/airports)
      }
    }
  }

  List<Map<String, dynamic>> rawDataToList(dynamic rawData) {
    if (rawData == null) {
      return [];
    }

    if (rawData is List) {
      return rawData
          .map((item) {
            if (item is Map) return Map<String, dynamic>.from(item);
            return <String, dynamic>{};
          })
          .where((m) => m.isNotEmpty)
          .toList();
    }

    return [];
  }

  Future<void> _fetchFleetCars() async {
    if (mounted) setState(() => _isLoadingCars = true);
    try {
      final api = ApiService();
      final response = await api.getCars().catchError((e) {
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
                  break;
                }
              }
            }
          }

          // Take up to 20 cars from the list (for reasonable detail fetch time)
          List<String> carIds = carList.reversed
              .take(20)
              .map((car) {
                return car['_id']?.toString() ?? car['id']?.toString() ?? '';
              })
              .where((id) => id.isNotEmpty)
              .toList();

          // Fetch full details for all selected cars
          await _fetchFleetCarsDetails(carIds);
        }
      }
    } catch (e) {
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
              'category':
                  (carData['categoryID']?['categoryName'] ??
                          carData['categoryID']?['name'] ??
                          '')
                      .toString(),
              'name':
                  carData['carName']?.toString() ??
                  carData['modelName']?.toString() ??
                  'Model',
              'passengerCount': (carData['numberOfPassengers'] ?? 4).toString(),
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

      // Fetch brand logos for each car
      _fetchBrandLogos();
    } catch (e) {}
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
          continue;
        }

        final brandResponse = await api.getBrandById(brandId).catchError((e) {
          return <String, dynamic>{};
        });

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
            }
          }
        }
      }
    } catch (e) {}
  }

  // Removed local _fetchPastBookings since we use BookingProvider now

  /// Localised product name for a booking card.
  String _getBookingName(BookingV2 booking, BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return switch (booking.resolvedServiceType) {
      BookingServiceType.airportArrival => loc.airportArrival,
      BookingServiceType.airportDeparture => loc.airportDeparture,
      BookingServiceType.chauffeur => loc.chauffeurService,
      BookingServiceType.privateTransfer => loc.privateTransfer,
      null => booking.isChauffeur ? loc.chauffeurService : 'Booking',
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = AppLocalizations.of(context)!;
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.scaffold,
      body: RefreshIndicator(
        color: c.accent,
        backgroundColor: c.surface,
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAppbar(context, loc),
              SizedBox(height: 8),
              _buildBookService(context, loc),
              Consumer<BookingProvider>(
                builder: (context, bookingProvider, child) {
                  // From the moment the driver sets off until the ride ends:
                  // outside that window nothing is publishing a position, so
                  // the card and the screen behind it stay hidden.
                  final trackingBooking = bookingProvider.trackableBooking;
                  if (trackingBooking == null) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 24,
                          right: 24,
                          top: 12,
                        ),
                        child: Text(
                          loc.trackYourDriver,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      TrackingCard(booking: trackingBooking),
                    ],
                  );
                },
              ),
              _buildPremiumFleet(context, loc),

              Flexible(child: _buildRecentBookings(context, loc)),
              // Runs the recent-bookings band on past the last card, so the
              // floating nav bar sits over that band rather than over a seam.
              Container(height: 130, color: c.surfaceAlt),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentBookings(BuildContext context, AppLocalizations loc) {
    final c = context.colors;
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        return Container(
          color: c.surfaceAlt,
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
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              if (bookingProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: BookingShimmer(
                    itemCount: 3,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                  ),
                )
              else if (bookingProvider.recentBookings.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 36,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.border),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 42,
                            color: c.iconMuted,
                          ),
                          SizedBox(height: 12),
                          Text(
                            loc.noRecentBookings,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: c.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  itemCount: bookingProvider.recentBookings.length,
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final booking = bookingProvider.recentBookings[index];
                    final pickup = formatPickupDisplay(context, [
                      booking.route,
                    ]);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  BookingDetailsPage(bookingId: booking.id),
                            ),
                          );
                          if (result == true) {
                            bookingProvider.fetchBookings();
                          }
                        },
                        child: Bookingcard(
                          status: booking.status,
                          type: _getBookingName(booking, context),
                          pickup: booking.pickupAddress ?? 'N/A',
                          dropoff: booking.dropOffAddress ?? 'N/A',
                          date: pickup.date,
                          time: pickup.time,
                          ride: booking.vehicleLabel,
                          brand: booking.vehicle?.name ?? '',
                          passengers: booking.passengersCount,
                          chauffeurName: booking.driver?.name,
                          isChauffeur: booking.isChauffeur,
                          cancellationNote: booking.cancellationNote,
                          bookingNumber: booking.bookingNumber,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumFleet(BuildContext context, AppLocalizations loc) {
    final c = context.colors;
    return Container(
      height: 230,
      color: c.scaffold,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.accent,
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
                      style: TextStyle(color: c.textTertiary),
                    ),
                  )
                : ListView.builder(
                    itemCount: 5,
                    scrollDirection: Axis.horizontal,
                    cacheExtent: 1000,
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
    final c = context.colors;
    return Container(
      height: 200,
      color: c.accentSurface,
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.only(left: 24, right: 24, top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            loc.bookServices,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
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
                        const GoldIcon(asset: "assets/icons/airportservices.png", size: 44),
                        SizedBox(height: 8),
                        Text(
                          loc.airportServices,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
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
                        const GoldIcon(asset: "assets/icons/chauffeur.png", size: 44),
                        SizedBox(height: 8),
                        Text(
                          loc.privateTransfer,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
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
                        const GoldIcon(asset: "assets/icons/chauff.png", size: 44),
                        SizedBox(height: 8),
                        Text(
                          loc.chauffeurService,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
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
    // The header stays a dark photograph in both themes. It is the page's hero
    // image, not a surface — a light theme with a dark hero is the look, and
    // washing the photo out to match the page would cost the greeting and the
    // icons over it their only contrast. Everything drawn on it therefore keeps
    // the fixed white it needs against the picture.
    return Container(
      height: 301,
      padding: const EdgeInsets.only(top: 50),
      decoration: BoxDecoration(
        image: DecorationImage(
          colorFilter: ColorFilter.mode(
            const Color(0xFF1E1105).withAlpha(120),
            BlendMode.srcATop,
          ),
          image: const AssetImage('assets/images/homeappbar.jpeg'),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final auth = Provider.of<AuthProvider>(context);
                          String name =
                              auth.user?.username ??
                              (auth.status == AuthStatus.loading
                                  ? "..."
                                  : "User");
                          final style = const TextStyle(
                            fontSize: 18,
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
                // The badge tracks the server-side unread count, which is
                // what the notification centre reconciles read state against.
                Consumer<NotificationProvider>(
                  builder: (context, notificationProvider, child) {
                    final unreadCount = notificationProvider.unreadCount;
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
                                  fontSize: 12,
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
          SizedBox(height: 10),
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
    if (catcode == 0 || catcode == 1) {
      _fetchLocationData();
    }
    final c = context.colors;
    bool isEnglish = Localizations.localeOf(context).languageCode == 'en';
    int selectedCityIndex = 0; // default to Riyadh

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // The sheet has to swallow taps that land on it.
            //
            // Its background is transparent and a Container doesn't absorb
            // pointer events, so a tap that misses a city tile — the loading
            // placeholders, the gaps between tiles, the empty-state text —
            // falls through to the dismissible barrier underneath and closes
            // the sheet instead of doing nothing.
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: c.sheetGradient,
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
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: Icon(Icons.close, color: c.icon),
                            ),
                          ],
                        ),
                      ),
                      Divider(color: c.divider, thickness: 1),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: _isLoadingLocations,
                            builder: (context, isLoading, child) {
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 600),
                                switchInCurve: Curves.easeIn,
                                switchOutCurve: Curves.easeOut,
                                child: isLoading
                                    ? _buildCityGridShimmer(
                                        constraints.maxWidth,
                                        count:
                                            _getFilteredCities(catcode).length >
                                                0
                                            ? _getFilteredCities(catcode).length
                                            : 6,
                                      )
                                    : Padding(
                                        key: const ValueKey(
                                          'city_grid_content',
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 24,
                                        ),
                                        child: Builder(
                                          builder: (context) {
                                            final activeCities =
                                                _getFilteredCities(catcode);

                                            if (activeCities.isEmpty) {
                                              return Center(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 20,
                                                      ),
                                                  child: Text(
                                                    isEnglish
                                                        ? "No active cities available"
                                                        : "Ù„Ø§ ØªÙˆØ¬Ø¯ Ù…Ø¯Ù† Ù†Ø´Ø·Ø© Ù…ØªØ§Ø­Ø©",
                                                    style: TextStyle(
                                                      color: c.textSecondary,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }

                                            return Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              children: activeCities.asMap().entries.map((
                                                entry,
                                              ) {
                                                final index = entry.key;
                                                final city = entry.value;
                                                final String cityName =
                                                    city['cityName'] ??
                                                    'Unknown';
                                                final String cityNameAr =
                                                    city['cityNameAr'] ??
                                                    cityName;

                                                // API image handling - the 'image' field is a Map containing 'url'
                                                String? imageUrl;
                                                if (city['image'] != null) {
                                                  if (city['image'] is String) {
                                                    imageUrl = city['image'];
                                                  } else if (city['image']
                                                          is Map &&
                                                      city['image']['url'] !=
                                                          null) {
                                                    imageUrl =
                                                        city['image']['url'];
                                                  }
                                                }

                                                // Modernize relative paths
                                                if (imageUrl != null &&
                                                    imageUrl.isNotEmpty &&
                                                    !imageUrl.startsWith(
                                                      'http',
                                                    ) &&
                                                    !imageUrl.startsWith(
                                                      'assets/',
                                                    )) {
                                                  const String host =
                                                      'https://api.premiumforcegroup.com';
                                                  imageUrl =
                                                      imageUrl.startsWith('/')
                                                      ? '$host$imageUrl'
                                                      : '$host/$imageUrl';
                                                }

                                                final String displayImage =
                                                    imageUrl ??
                                                    'assets/images/riyadh.png';

                                                return SizedBox(
                                                  width:
                                                      (constraints.maxWidth -
                                                          48 - // Padding horizontal (24 * 2)
                                                          24) / // Spacings (12 * 2)
                                                      3, // 3 columns
                                                  child: _buildCityTile(
                                                    isEnglish: isEnglish,
                                                    isSelected:
                                                        selectedCityIndex ==
                                                        index,
                                                    nameEn: cityName,
                                                    nameAr: cityNameAr,
                                                    image: displayImage,
                                                    isApiImage:
                                                        imageUrl != null,
                                                    onTap: () => setState(
                                                      () => selectedCityIndex =
                                                          index,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            );
                                          },
                                        ),
                                      ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: PremiumButton(
                          showLoader: false,
                          borderRadius: 12,
                          text: loc.continueText,
                          onTap: () async {
                            final activeCities = _getFilteredCities(catcode);
                            if (activeCities.isEmpty) return;

                            final selectedCity =
                                activeCities[selectedCityIndex];
                            final cityId =
                                (selectedCity['_id'] ?? selectedCity['id'])
                                    ?.toString();

                            // Chauffeur pricing is no longer prefetched:
                            // v2 prices vehicles per session, so there is
                            // nothing useful to fetch before the booking
                            // draft exists.
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => NewBooking(
                                    catcode: catcode,
                                    citycode: selectedCityIndex,
                                    cityId: cityId,
                                    preloadedCities: _apiCities,
                                    preloadedAirports: _apiAirports,
                                    preloadedTerminals: _apiTerminals,
                                    // Lets the booking screen open on the first
                                    // bookable pickup time straight away.
                                    bookingBufferHours: bookingBufferHoursOf(
                                      selectedCity,
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                          fontsize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _getFilteredCities(int catcode) {
    return _apiCities.where((c) {
      // Basic active check
      final active = c['isActive'];
      final bool cityActive =
          active == true || active == 1 || active.toString() == 'true';
      if (!cityActive) return false;

      // Check 1: If Airport service, also check for at least one active airport
      if (catcode == 0 || catcode == 1) {
        final cityId = (c['_id'] ?? c['id'])?.toString();
        if (cityId == null) return false;

        return _apiAirports.any((a) {
          var aCityId = a['cityID'] ?? a['cityId'] ?? a['city_id'];
          if (aCityId is Map) {
            aCityId = aCityId['_id'] ?? aCityId['id'];
          }
          final aCityIdStr = aCityId?.toString();

          // Use robust isActive check (not explicitly false)
          final bool isAirportActive = a['isActive'] != false;

          return aCityIdStr == cityId && isAirportActive;
        });
      }

      return true;
    }).toList();
  }

  Widget _buildCityGridShimmer(double maxWidth, {int count = 6}) {
    final c = context.colors;
    return Padding(
      key: const ValueKey('city_grid_shimmer'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Shimmer.fromColors(
        baseColor: c.shimmerBase,
        highlightColor: c.shimmerHighlight,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(
            count,
            (index) => SizedBox(
              width:
                  (maxWidth -
                      48 - // Padding horizontal (24 * 2)
                      24) / // Spacings (12 * 2)
                  3, // 3 columns
              child: Container(
                height: 125,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
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
    final c = context.colors;
    // The tile is a city photograph with its name reversed out of a scrim, so
    // the caption and the scrim below stay fixed — they answer to the picture.
    // Only the selection ring and the loading placeholder follow the theme.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 125,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? c.accent : Colors.transparent,
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
                        // City tile is 125pt tall in a grid — decode small.
                        memCacheWidth: 600,
                        placeholder: (context, url) => Container(
                          color: c.skeleton,
                          child: const Center(child: PremiumLoader(size: 20)),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.image_not_supported,
                          color: c.iconMuted,
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
                      fontSize: 11,
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
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, size: 14, color: c.onAccent),
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
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Swallow taps that land on the sheet. Its background is transparent
        // and a Container doesn't absorb pointer events, so a tap that misses
        // one of the service cards would otherwise fall through to the
        // dismissible barrier underneath and close the sheet.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: c.sheetGradient,
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Icon(Icons.close, color: c.icon),
                      ),
                    ],
                  ),
                ),
                Divider(color: c.divider),

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
                            height: 130,
                            width: double.infinity,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Repainted on the light theme only: the
                                  // artwork carries white detail that reads on
                                  // the dark card and vanishes on the ivory one.
                                  const GoldIcon(
                                    asset: 'assets/icons/arrival.svg',
                                    size: 44,
                                    mirrorInRtl: true,
                                    lightModeOnly: true,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    loc.airportArrival,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: c.textPrimary,
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
                            height: 130,
                            width: MediaQuery.of(context).size.width * 0.42,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const GoldIcon(
                                    asset: 'assets/icons/departure.svg',
                                    size: 44,
                                    mirrorInRtl: true,
                                    lightModeOnly: true,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    loc.airportDeparture,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: c.textPrimary,
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
          ),
        );
      },
    );
  }
}
