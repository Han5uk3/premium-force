import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:premium_force_main/common_widgets/bookingcard.dart';
import 'package:premium_force_main/common_widgets/borderedcontainer.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/premuimfleetcard.dart';

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
    {
      "brand": "bmw",
      "name": "i3",
      "passengerCount": "2",
      "image":
          "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTtt985QVNzHFbPZ4cvt2tQfmVsmSa9drlimw&s",
    },
  ];
  bool isEnglish = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAppbar(context),
            _buildBookService(context),
            _buildPremiumFleet(context),
            _buildRecentBookings(context),
            Container(
              height: 80,
              color: Color(0xff292929).withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentBookings(BuildContext context) {
    return Container(
      height: 250,
      color: const Color(0xff292929).withValues(alpha: 0.6),
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.only(left: 24, right: 24, top: 12),
      child: Column(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Recent Bookings",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Bookingcard(),
        ],
      ),
    );
  }

  Widget _buildPremiumFleet(BuildContext context) {
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
              "Premium Fleet",
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

  Widget _buildBookService(BuildContext context) {
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
            "Book Services",
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
              PremiumContainer(
                height: 120,
                width: MediaQuery.of(context).size.width * 0.28,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
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
                        "Airport Arrival",
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
              PremiumContainer(
                height: 120,
                width: MediaQuery.of(context).size.width * 0.28,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
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
                        "Airport Departure",
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
              PremiumContainer(
                height: 120,
                width: MediaQuery.of(context).size.width * 0.28,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
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
                        "Chauffeur Service",
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppbar(BuildContext context) {
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
                    "Welcome Back",
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
                        setState(() {
                          isEnglish = !isEnglish;
                        });
                      },
                      child: SvgPicture.asset(
                        isEnglish
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
                    "Luxury Airport Transfers",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "in Saudi Arabia",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: 90,
                    height: 26,
                    child: PremiumButton(
                      borderRadius: 18,
                      textColor: Colors.white,
                      text: "Book Now",
                      onTap: () {},
                      fontsize: 12,
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
}
