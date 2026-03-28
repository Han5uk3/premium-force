import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A premium waveform / equalizer-style loader.
///
/// Renders [barCount] vertical bars that oscillate with staggered phases,
/// creating a smooth, fluid wave effect. Each bar has rounded caps and can
/// use the app's gold gradient or a solid [color].
///
/// ```dart
/// // Page-level (gold, default)
/// const PremiumLoader(size: 40)
///
/// // Inside a button
/// const PremiumLoader(size: 24, color: Colors.black)
/// ```
class PremiumLoader extends StatefulWidget {
  /// Overall height of the loader. Width scales automatically.
  final double size;

  /// Bar colour. Defaults to the app's gold accent.
  final Color color;

  /// Number of bars in the waveform.
  final int barCount;

  /// Duration of one full wave cycle.
  final Duration duration;

  const PremiumLoader({
    super.key,
    this.size = 20,
    this.color = const Color(0xFFD4A574),
    this.barCount = 5,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<PremiumLoader> createState() => _PremiumLoaderState();
}

class _PremiumLoaderState extends State<PremiumLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Width = enough room for all bars + gaps
    final barWidth = widget.size * 0.12;
    final gap = barWidth * 0.75;
    final totalWidth =
        (barWidth * widget.barCount) + (gap * (widget.barCount - 1));

    return SizedBox(
      width: totalWidth,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _WaveformPainter(
              progress: _controller.value,
              color: widget.color,
              barCount: widget.barCount,
              barWidth: barWidth,
              gap: gap,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _WaveformPainter extends CustomPainter {
  final double progress; // 0 → 1
  final Color color;
  final int barCount;
  final double barWidth;
  final double gap;

  _WaveformPainter({
    required this.progress,
    required this.color,
    required this.barCount,
    required this.barWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxBarHeight = size.height;
    final minBarHeight = maxBarHeight * 0.15;
    final radius = Radius.circular(barWidth / 2);

    for (int i = 0; i < barCount; i++) {
      // Stagger phase across bars for the wave effect
      final phase = (i / barCount) * 2 * math.pi;
      final wave = math.sin(progress * 2 * math.pi - phase);

      // Map sine (-1..1) → height (minBarHeight..maxBarHeight)
      final barHeight =
          minBarHeight + ((wave + 1) / 2) * (maxBarHeight - minBarHeight);

      // Opacity: bars at their lowest are slightly faded
      final opacity = 0.45 + 0.55 * ((wave + 1) / 2);

      final left = i * (barWidth + gap);
      final top = (size.height - barHeight) / 2; // vertically centred

      final paint = Paint()
        ..color = color.withAlpha((opacity * 255).round())
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        radius,
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ---------------------------------------------------------------------------
// Convenience: full-page loader overlay
// ---------------------------------------------------------------------------

/// A centred full-screen overlay with a semi-transparent background and the
/// [PremiumLoader]. Useful with a [Stack] or in a dialog.
class PremiumLoaderOverlay extends StatelessWidget {
  final double loaderSize;
  final Color? loaderColor;

  const PremiumLoaderOverlay({
    super.key,
    this.loaderSize = 52,
    this.loaderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(140),
      child: Center(
        child: PremiumLoader(
          size: loaderSize,
          color: loaderColor ?? const Color(0xFFD4A574),
        ),
      ),
    );
  }
}
