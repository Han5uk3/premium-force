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

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  List cardItems = [
    {
      "brand": "Audi",
      "name": "A4",
      "passengerCount": "2",
      "image": "https://wallpapercave.com/wp/wp7401750.jpg",
    },
    {
      "brand": "Mercedes-Benz",
      "name": "C220",
      "passengerCount": "2",
      "image": "https://4kwallpapers.com/images/walls/thumbs_3t/7449.jpg",
    },
    {
      "brand": "BMW",
      "name": "735i",
      "passengerCount": "2",
      "image":
          "https://www.hdwallpapers.in/thumbs/2017/2017_bmw_7_series_black_ice_edition-t2.jpg",
    },
  ];

  List<Map<String, dynamic>> _apiCities = [];
  List<Map<String, dynamic>> _apiAirports = [];
  List<Map<String, dynamic>> _apiTerminals = [];
  bool _isLoadingLocations = false;

  @override
  void initState() {
    super.initState();
    _fetchLocationData();
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
            debugPrint('Error fetching location data: $e');
            return <Map<String, dynamic>>[{}, {}, {}];
          });

      if (mounted) {
        setState(() {
          // Process Cities
          if (results[0]['success'] == true) {
            _apiCities = rawDataToList(
              results[0]['data'] ?? results[0]['cities'],
            );
          }

          // Process Airports
          if (results[1]['success'] == true) {
            _apiAirports = rawDataToList(
              results[1]['data'] ?? results[1]['airports'],
            );
          }

          // Process Terminals
          if (results[2]['success'] == true) {
            _apiTerminals = rawDataToList(
              results[2]['data'] ?? results[2]['terminals'],
            );
          }
        });

        if (kDebugMode) {
          debugPrint(
            '🌐 API │ Location Data Loaded - Cities: ${_apiCities.length}, Airports: ${_apiAirports.length}, Terminals: ${_apiTerminals.length}',
          );
        }
      }
    } catch (e) {
      debugPrint('General error in _fetchLocationData: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  List<Map<String, dynamic>> rawDataToList(dynamic rawData) {
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAppbar(context, loc),
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
          /*
          Flexible(
            child: ListView.builder(
              itemCount: bookingItems.length,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Bookingcard(
                    status: bookingItems[index]["status"],
                    type: bookingItems[index]["type"],
                    pickup: bookingItems[index]["pickup"],
                    dropoff: bookingItems[index]["dropoff"],
                    date: bookingItems[index]["date"],
                    time: bookingItems[index]["time"],
                    ride: bookingItems[index]["ride"],
                    brand: bookingItems[index]["brand"],
                  ),
                );
              },
            ),
          ),
          */
          SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
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
            child: Text(
              loc.premiumFleet,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListView.builder(
              itemCount: cardItems.length,
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 24 : 6,
                    right: index == cardItems.length - 1 ? 24 : 6,
                  ),
                  child: Premuimfleetcard(
                    brand: cardItems[index]["brand"],
                    name: cardItems[index]["name"],
                    passengerCount: cardItems[index]["passengerCount"],
                    image: cardItems[index]["image"],
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
                  showCitySelectionBottomSheet(context, loc, 0);
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
                          height: 40,
                          width: 40,
                          child: Transform.scale(
                            scaleX: isArabic ? -1 : 1,
                            child: SvgPicture.asset(
                              'assets/icons/arrival.svg',
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          loc.airportArrival,
                          style: TextStyle(
                            fontSize: 16,
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
                  showCitySelectionBottomSheet(context, loc, 1);
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
                          height: 40,
                          width: 40,
                          child: Transform.scale(
                            scaleX: isArabic ? -1 : 1,
                            child: SvgPicture.asset(
                              'assets/icons/departure.svg',
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          loc.airportDeparture,
                          style: TextStyle(
                            fontSize: 16,
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
                          height: 40,
                          width: 40,
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
                          style: TextStyle(
                            fontSize: 16,
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
      padding: const EdgeInsets.only(left: 24, right: 24, top: 50),
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
          Row(
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
                            Provider.of<AuthProvider>(context).user?.username ??
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
                              builder: (context) => const NotificationScreen(),
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
                      child: Text(
                        loc.chooseCity,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
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
                            child: _apiCities.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      child: Text(
                                        isEnglish
                                            ? "No cities available"
                                            : "لا توجد مدن متاحة",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: _apiCities.asMap().entries.map((
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
                                  ),
                          ),
                    const SizedBox(height: 48),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: PremiumButton(
                        showLoader: false,
                        borderRadius: 12,
                        text: loc.continueText,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => NewBooking(
                                catcode: catcode,
                                citycode: selectedCityIndex,
                                preloadedCities: _apiCities,
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
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: PremiumLoader(color: Color(0xFFE4A46B)),
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
}
