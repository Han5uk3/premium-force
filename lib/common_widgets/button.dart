import 'package:flutter/material.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/theme/app_palette.dart';

class PremiumButton extends StatelessWidget {
  const PremiumButton({
    super.key,
    required this.text,
    required this.onTap,
    required this.fontsize,
    required this.showLoader,
    this.borderRadius,
    this.textColor,
    this.gradient,
    this.enabled = true,
  });

  final String text;
  final VoidCallback onTap;
  final double fontsize;
  final double? borderRadius;
  final Color? textColor;
  final bool showLoader;
  final List<Color>? gradient;

  /// When false the button greys out and ignores taps — use it for "nothing to
  /// submit yet" states.
  ///
  /// Distinct from [showLoader], which keeps the normal styling (so the black
  /// loader stays legible on the gold) while also blocking taps.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = c.brightness == Brightness.dark;
    final premiumColors = isDark
        ? const [
            Color(0xFF6E3E12), // Deep warm bronze at top-end
            Color(0xFFB57D3E), // Muted luxury gold
            Color(0xFFDDA663), // Soft satin gold highlight (subdued, elegant)
            Color(0xFFB57D3E), // Muted luxury gold
            Color(0xFF5A300A), // Deep contour at bottom-start
          ]
        : const [
            Color(0xFFB06F27), // Deep luxury gold/bronze at top-end
            Color(0xFFE4A46B), // Signature warm brand gold
            Color(
              0xFFF7D990,
            ), // Warm reflective gold sheen (centered, reduced whiteness)
            Color(0xFFE4A46B), // Signature warm brand gold
            Color(0xFF9E5C1A), // Deep warm contour at bottom-start
          ];

    // Multi-stop metallic gold gradient:
    // runs diagonally from topEnd to bottomStart with a warm, non-white
    // golden reflective sheen centered across the button.
    // In dark mode, uses deeper satin bronze/gold tones to prevent harsh brightness.
    final selectedFill = LinearGradient(
      begin: AlignmentDirectional.topEnd,
      end: AlignmentDirectional.bottomStart,
      colors: premiumColors,
      stops: const [0.0, 0.28, 0.50, 0.72, 1.0],
    );

    // A button mid-save is still "enabled" — it just isn't tappable yet.
    final canTap = enabled && !showLoader;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          // The gold itself is the same in both modes — a filled gold chip is
          // the brand's signature and reads on black or on ivory alike. Only
          // the disabled stand-in has to change, since a dark grey that says
          // "off" on black says "on" on ivory.
          colors: enabled
              ? (gradient ?? premiumColors)
              : c.goldDisabledGradient,
        ),
       
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          splashColor: Colors.black.withAlpha(50),
          highlightColor: Colors.black.withAlpha(50),
          // Null here also suppresses the ink splash, so a disabled button
          // gives no touch feedback at all.
          onTap: canTap ? onTap : null,
          borderRadius: BorderRadius.circular(borderRadius ?? 12),
          child: Center(
            child: showLoader
                // Black, not the accent: the loader spins on the gold fill, so
                // it takes the same colour the label would.
                ? const PremiumLoader(size: 23, color: Colors.black)
                : Text(
                    text,
                    style: TextStyle(
                      color: enabled
                          ? (textColor ?? c.onGold)
                          : c.textDisabled,
                      fontSize: fontsize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
