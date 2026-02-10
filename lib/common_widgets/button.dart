import 'package:flutter/material.dart';

class PremiumButton extends StatelessWidget {
  const PremiumButton({
    super.key,
    required this.text,
    required this.onTap,
    required this.fontsize,
    this.borderRadius,
    this.textColor,
    this.gradient,
  });

  final String text;
  final VoidCallback onTap;
  final double fontsize;
  final double? borderRadius;
  final Color? textColor;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors:
              gradient ??
              [Color(0xFF49280B), Color(0xFFE4A46B), Color(0xFF60350F)],
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius ?? 12),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: textColor ?? Colors.black,
                fontSize: fontsize,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
