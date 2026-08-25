import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:premium_force_main/theme/app_palette.dart';

/// An icon asset painted with the theme's gold ramp.
///
/// The app's service icons are flat artwork — a PNG silhouette, or an SVG drawn
/// with the brand gold baked into it. Baked-in colour is exactly what a second
/// theme cannot use: an asset drawn to sit on black has white detail in it that
/// vanishes on ivory, and the pale middle of the gold ramp all but disappears
/// there too.
///
/// This repaints the asset through a [ShaderMask], so only its *shape* comes
/// from the file and its colour comes from [AppPalette.goldIconGradient] — the
/// ramp that is tuned for the page background in force.
class GoldIcon extends StatelessWidget {
  const GoldIcon({
    super.key,
    required this.asset,
    required this.size,
    this.mirrorInRtl = false,
    this.lightModeOnly = false,
  });

  /// Asset path. SVG and raster are both accepted; the extension picks the
  /// decoder.
  final String asset;

  /// Side length of the square the icon is drawn in.
  final double size;

  /// Flip horizontally in an RTL layout.
  ///
  /// For the directional icons — an arrival arrow pointing into a building, a
  /// departure arrow pointing out of one — whose meaning is carried by which
  /// way they point.
  final bool mirrorInRtl;

  /// Leave the asset untouched on the dark theme, and repaint only on the light
  /// one.
  ///
  /// For assets already drawn for a dark ground: recolouring them there would
  /// change a screen that is already right, while leaving them alone on ivory
  /// would strand their white detail on a near-white surface.
  final bool lightModeOnly;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    Widget art = asset.endsWith('.svg')
        ? SvgPicture.asset(asset, fit: BoxFit.contain)
        : Image.asset(asset, fit: BoxFit.contain);

    if (!(lightModeOnly && c.isDark)) {
      art = ShaderMask(
        // srcIn keeps the artwork's alpha and replaces its colour, so a stroked
        // icon stays a stroke rather than filling in.
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.goldIconGradient,
        ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
        child: art,
      );
    }

    if (mirrorInRtl && isRtl) {
      art = Transform.scale(scaleX: -1, child: art);
    }

    return SizedBox(width: size, height: size, child: art);
  }
}
