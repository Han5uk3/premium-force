import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';

class Premuimfleetcard extends StatefulWidget {
  const Premuimfleetcard({
    super.key,
    required this.image,
    required this.name,
    required this.passengerCount,
    required this.brand,
    this.brandLogoUrl,
    this.width = 240,
    this.height = 160,
  });

  final String image;
  final String name;
  final String passengerCount;
  final String brand;
  final String? brandLogoUrl;
  final double width;
  final double height;

  @override
  State<Premuimfleetcard> createState() => _PremuimfleetcardState();
}

class _PremuimfleetcardState extends State<Premuimfleetcard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
    ];
    return darkLogos.contains(lowerBrand);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = AppLocalizations.of(context)!;
    final imageProvider = widget.image;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        width: widget.width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Base image
            imageProvider.isEmpty
                ? Container(
                    color: Colors.grey[800],
                    child: Center(
                      child: Icon(
                        Icons.directions_car,
                        color: Colors.grey[600],
                        size: 60,
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: imageProvider,
                    fit: BoxFit.cover,
                    width: 240,
                    height: 160,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: PremiumLoader(
                          size: 24,
                          color: Color(0xFFE4A46B),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[600],
                          size: 40,
                        ),
                      ),
                    ),
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
                    imageProvider.isNotEmpty
                        ? Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 160,
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: 5,
                                sigmaY: 5,
                              ),
                              child: CachedNetworkImage(
                                imageUrl: imageProvider,
                                fit: BoxFit.cover,
                                width: 240,
                                height: 160,
                              ),
                            ),
                          )
                        : Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 160,
                            child: Container(color: Colors.grey[800]),
                          ),
                    // Tinted overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color.fromARGB(255, 213, 132, 61).withAlpha(130),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
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
                            "${widget.brand} ${widget.name}",
                            style: TextStyle(fontSize: 13, color: Colors.white),
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
                                "${loc.passenger}: ${widget.passengerCount}",
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

            // Brand badge (top-right) â€” uses ImageFiltered instead of
            // BackdropFilter so it is scroll-safe.
            Positioned(
              top: 5,
              right: Directionality.of(context) == TextDirection.ltr ? 5 : null,
              left: Directionality.of(context) == TextDirection.rtl ? 5 : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 50,
                  width: 50,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Blurred image slice behind the badge
                      imageProvider.isNotEmpty
                          ? Positioned(
                              top: -5,
                              right:
                                  Directionality.of(context) ==
                                      TextDirection.rtl
                                  ? -5
                                  : null,
                              left:
                                  Directionality.of(context) ==
                                      TextDirection.ltr
                                  ? -5
                                  : null,
                              width: 240,
                              height: 160,
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 20,
                                  sigmaY: 20,
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: imageProvider,
                                  fit: BoxFit.cover,
                                  width: 240,
                                  height: 160,
                                ),
                              ),
                            )
                          : Positioned(
                              top: -5,
                              right:
                                  Directionality.of(context) ==
                                      TextDirection.rtl
                                  ? -5
                                  : null,
                              left:
                                  Directionality.of(context) ==
                                      TextDirection.ltr
                                  ? -5
                                  : null,
                              width: 240,
                              height: 160,
                              child: Container(color: Colors.grey[800]),
                            ),
                      Container(
                        decoration: BoxDecoration(
                          color: _isDarkLogo(widget.brand)
                              ? Colors.white.withAlpha(128)
                              : Colors.black.withAlpha(128),
                        ),

                        child: widget.brandLogoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: widget.brandLogoUrl!,
                                fit: BoxFit.fill,
                                placeholder: (context, url) => Center(
                                  child: PremiumLoader(
                                    size: 12,
                                    color: Color(0xFFE4A46B),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Center(
                                  child: Icon(
                                    Icons.directions_car,
                                    color: Colors.grey,
                                    size: 24,
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.directions_car,
                                  color: Colors.grey,
                                  size: 24,
                                ),
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
