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
                    // Decode at ~3x the 240pt display width, not full source res.
                    memCacheWidth: 720,
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
              height: 40,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Blurred background with top fade
                    ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withAlpha(0), Colors.black],
                          stops: [0.0, 0.4],
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          imageProvider.isNotEmpty
                              ? Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: widget.height,
                                  child: ImageFiltered(
                                    imageFilter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: CachedNetworkImage(
                                      imageUrl: imageProvider,
                                      fit: BoxFit.cover,
                                      width: widget.width,
                                      height: widget.height,
                                      // Blurred backdrop: detail is destroyed
                                      // by the filter, so decode small.
                                      memCacheWidth: 300,
                                    ),
                                  ),
                                )
                              : Container(color: Colors.grey[800]),
                          // Subtle dark tint for better legibility
                          Container(color: Colors.black.withAlpha(40)),
                        ],
                      ),
                    ),
                    // Text content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "${widget.brand} ${widget.name}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.group_outlined,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${loc.passenger}: ${widget.passengerCount}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
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
              top: 0,
              right: Directionality.of(context) == TextDirection.ltr
                  ? 15
                  : null,
              left: Directionality.of(context) == TextDirection.rtl ? 15 : null,
              child: ClipPath(
                clipper: _CardClipper(),
                child: SizedBox(
                  height: 30,
                  width: 30,
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
                                  // Blurred at sigma 20 — decode very small.
                                  memCacheWidth: 240,
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
                                memCacheWidth: 160,
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

class _CardClipper extends CustomClipper<Path> {
  const _CardClipper();

  @override
  Path getClip(Size size) {
    Path path = Path();
    // Start way above the top to achieve "no clipping on top"
    path.moveTo(0, -999);
    path.lineTo(size.width, -999);
    path.lineTo(size.width, size.height - 10);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - 10,
      size.height,
    );
    path.lineTo(10, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - 10);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
