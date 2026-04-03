import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';

class FleetListCard extends StatefulWidget {
  const FleetListCard({
    super.key,
    required this.image,
    required this.name,
    required this.passengerCount,
    required this.brand,
    this.brandLogoUrl,
  });

  final String image;
  final String name;
  final String passengerCount;
  final String brand;
  final String? brandLogoUrl;

  @override
  State<FleetListCard> createState() => _FleetListCardState();
}

class _FleetListCardState extends State<FleetListCard>
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1.3, // Wider as it takes one per row
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Base image
            widget.image.isEmpty
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
                    imageUrl: widget.image,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: PremiumLoader(
                          size: 24,
                          color: Colors.grey[600]!,
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

            // Vertical Side Band (Frosted overlay)
            // Positioned according to text direction
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.92,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Tinted gradient overlay (Fade from start to end)

                    // Content: Brand Icon + Info
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Brand Badge
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 44,
                              width: 44,
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
                                          size: 16,
                                          color: Color(0xFFE4A46B),
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.directions_car,
                                      color: Colors.grey,
                                      size: 24,
                                    ),
                            ),
                          ),
                          const Spacer(),
                          // Car Info
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${widget.brand} ${widget.name}",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.group_outlined,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${loc.passenger}: ${widget.passengerCount}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }
}
