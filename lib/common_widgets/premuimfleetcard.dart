import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';

class Premuimfleetcard extends StatelessWidget {
  const Premuimfleetcard({
    super.key,
    required this.image,
    required this.name,
    required this.passengerCount,
    required this.brand,
  });

  final String image;
  final String name;
  final String passengerCount;
  final String brand;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final imageProvider = "assets/images/bmwdummy.jpg";

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 160,
        width: 240,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Base image
            Image(
              image: AssetImage(imageProvider),
              fit: BoxFit.cover,
              width: 240,
              height: 160,
            ),

            // Bottom frosted-glass info overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 55,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Blurred copy of the same image, aligned to match the
                    // position it would occupy behind this region.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 160,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Image(
                          image: AssetImage(imageProvider),
                          fit: BoxFit.cover,
                          width: 240,
                          height: 160,
                        ),
                      ),
                    ),
                    // Tinted overlay
                    Container(
                      color: Color.fromARGB(255, 213, 132, 61).withAlpha(80),
                    ),
                    // Text content
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 2,
                        left: 8,
                        right: 8,
                        bottom: 8,
                      ),
                      child: Column(
                        spacing: 3,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$brand $name",
                            style: TextStyle(fontSize: 15, color: Colors.white),
                          ),
                          Row(
                            spacing: 5,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.group_outlined,
                                color: Colors.white54,
                                size: 16,
                              ),
                              Text(
                                "${loc.passenger}: $passengerCount",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Brand badge (top-right) — uses ImageFiltered instead of
            // BackdropFilter so it is scroll-safe.
            Positioned(
              top: 5,
              right: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 50,
                  width: 50,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Blurred image slice behind the badge
                      Positioned(
                        top: -5,
                        right: -5,
                        width: 240,
                        height: 160,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Image(
                            image: AssetImage(imageProvider),
                            fit: BoxFit.cover,
                            width: 240,
                            height: 160,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(20),
                        ),
                        padding: const EdgeInsets.all(4.0),
                        child: CachedNetworkImage(
                          imageUrl:
                              "https://raw.githubusercontent.com/filippofilip95/car-logos-dataset/master/logos/thumb/${brand.toLowerCase()}.png",
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
