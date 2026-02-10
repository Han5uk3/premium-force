import 'package:flutter/material.dart';
import 'package:premium_force_main/common_widgets/borderedcontainer.dart';

class Bookingcard extends StatelessWidget {
  const Bookingcard({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumContainer(
      height: 180,
      width: MediaQuery.of(context).size.width,
      child: Column(
        spacing: 8,
        children: [
          Row(
            children: [
              Text(
                "No Bookings Yet",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
