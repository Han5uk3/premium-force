import 'package:flutter/material.dart';
import 'package:premium_force_main/theme/app_palette.dart';
import 'package:shimmer/shimmer.dart';

class PremuimfleetcardShimmer extends StatelessWidget {
  const PremuimfleetcardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Shimmer masks its child with `BlendMode.srcIn`, so only the child's
    // *alpha* survives — its colours are replaced by the sweep. That is why the
    // blocks below are left as translucent whites: they are opacity stencils,
    // and the two colours here are the only ones that reach the screen.
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Shimmer.fromColors(
        baseColor: c.shimmerBase,
        highlightColor: c.shimmerHighlight,
        child: Container(
          height: 160,
          width: 240,
          decoration: BoxDecoration(
            color: c.skeleton,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Bottom info overlay shimmer
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 55,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 80,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Brand badge shimmer
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  height: 50,
                  width: 50,
                  decoration: const BoxDecoration(
                    color: Colors.white12,
                    shape: BoxShape.circle,
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
