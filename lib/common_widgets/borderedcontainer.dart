import 'package:flutter/material.dart';
import 'package:premium_force_main/theme/app_palette.dart';

class PremiumContainer extends StatelessWidget {
  const PremiumContainer({
    super.key,
    required this.height,
    required this.width,
    required this.child,
  });

  final double height;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: c.goldGradient),
        borderRadius: BorderRadius.circular(12),
      ),
      // The 1px margin is what turns the gradient behind it into a hairline
      // frame; the fill has to be opaque or the gold shows through the middle.
      child: Container(
        margin: EdgeInsets.all(1),
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: c.surfaceDeep,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}
