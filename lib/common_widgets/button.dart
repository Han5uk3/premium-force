import 'package:flutter/material.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';

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

  /// Muted stand-in for the gold gradient while [enabled] is false.
  static const _disabledGradient = [
    Color(0xFF332B22),
    Color(0xFF4E4335),
    Color(0xFF332B22),
  ];

  @override
  Widget build(BuildContext context) {
    // A button mid-save is still "enabled" — it just isn't tappable yet.
    final canTap = enabled && !showLoader;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: enabled
              ? (gradient ??
                    [Color(0xFF49280B), Color(0xFFE4A46B), Color(0xFF60350F)])
              : _disabledGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            spreadRadius: 3,
          ),
        ],
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
                ? PremiumLoader(size: 28, color: Colors.black)
                : Text(
                    text,
                    style: TextStyle(
                      color: enabled
                          ? (textColor ?? Colors.black)
                          : Colors.white38,
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
