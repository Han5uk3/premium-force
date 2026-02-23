import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:premium_force_main/common_widgets/bookingcard.dart';
import 'package:premium_force_main/common_widgets/borderedcontainer.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/premuimfleetcard.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/main.dart';
import 'package:premium_force_main/ride_booking/new_booking.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  List cardItems = [
    {
      "brand": "bmw",
      "name": "735",
      "passengerCount": "2",
      "image":
          "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTtt985QVNzHFbPZ4cvt2tQfmVsmSa9drlimw&s",
    },
    {
      "brand": "Audi",
      "name": "A4",
      "passengerCount": "2",
      "image":
          "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTtt985QVNzHFbPZ4cvt2tQfmVsmSa9drlimw&s",
    },
    {
      "brand": "mercedes-benz",
      "name": "c220",
      "passengerCount": "2",
      "image":
          "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTtt985QVNzHFbPZ4cvt2tQfmVsmSa9drlimw&s",
    },
  ];
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
              height: 80,
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
                          child: SvgPicture.asset(
                            'assets/icons/arrival.svg',
                            fit: BoxFit.fill,
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
                          child: SvgPicture.asset(
                            'assets/icons/departure.svg',
                            fit: BoxFit.fill,
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
                          child: SvgPicture.asset(
                            'assets/icons/chauffeur.svg',
                            fit: BoxFit.fill,
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
              Column(
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
                  Text(
                    "Ahamed",
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
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
          Container(
            height: 140,
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              color: Colors.black,
              image: DecorationImage(
                image: AssetImage('assets/images/banner.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              height: 140,
              width: MediaQuery.of(context).size.width,
              padding: EdgeInsets.only(left: 16, right: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF49280B).withAlpha(200),
                    const Color(0xFF49280B).withAlpha(180),
                    const Color(0xFF49280B).withAlpha(150),

                    Colors.transparent,
                    Colors.transparent,
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    loc.luxuryAirportTransfers,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    loc.inSaudiArabia,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  IgnorePointer(
                    ignoring: true,
                    child: SizedBox(
                      width: 90,
                      height: 26,
                      child: PremiumButton(
                        showLoader: false,
                        borderRadius: 18,
                        textColor: Colors.white,
                        text: loc.bookNow,
                        onTap: () {},
                        fontsize: 12,
                      ),
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
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 24,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCityTile(
                            isEnglish: isEnglish,
                            isSelected: selectedCityIndex == 0,
                            nameEn: "Riyadh",
                            nameAr: "الرياض",
                            image: "assets/images/riyadh.png",
                            onTap: () => setState(() => selectedCityIndex = 0),
                          ),
                          const SizedBox(width: 8),
                          _buildCityTile(
                            isEnglish: isEnglish,
                            isSelected: selectedCityIndex == 1,
                            nameEn: "Dammam",
                            nameAr: "الدمام",
                            image: "assets/images/dammam.png",
                            onTap: () => setState(() => selectedCityIndex = 1),
                          ),
                          const SizedBox(width: 8),
                          _buildCityTile(
                            isEnglish: isEnglish,
                            isSelected: selectedCityIndex == 2,
                            nameEn: "Jeddah",
                            nameAr: "جدة",
                            image: "assets/images/jeddah.png",
                            onTap: () => setState(() => selectedCityIndex = 2),
                          ),
                        ],
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
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 125,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFE4A46B) : Colors.transparent,
              width: 2,
            ),
            image: DecorationImage(image: AssetImage(image), fit: BoxFit.cover),
          ),
          child: Stack(
            children: [
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
