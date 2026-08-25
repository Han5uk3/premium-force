import 'package:flutter/material.dart';
import 'package:premium_force_main/theme/app_palette.dart';
import 'package:shimmer/shimmer.dart';

/// Full-page skeleton for the booking details screen while its booking loads.
///
/// Replaces a centred spinner, which said only that something was happening:
/// the page it precedes is long and heavily sectioned, so the spinner sat in
/// the middle of an empty screen and then the whole layout appeared at once.
/// This mirrors that layout instead — same horizontal gutter, same card
/// chrome, same radii and the same vertical rhythm — so the shape of the
/// screen is there from the first frame and the real content lands on top of
/// it.
///
/// Three rules keep it honest:
///
/// * **Chrome outside the shimmer, content inside.** [Shimmer.fromColors]
///   masks every opaque pixel of its child, so a card background placed inside
///   it would be repainted the same grey as the bars it holds and the card
///   would dissolve into one block. Each panel therefore draws its real
///   background and border, and only the placeholder bars within it shimmer —
///   the same split `BookingShimmer` uses for the list.
/// * **Optional sections are drawn as if present.** The vehicle image, driver,
///   timeline and payment blocks are the common case; leaving them out would
///   make the skeleton shorter than nearly every real page. The genuinely
///   conditional notices — cancellation, refund, special requests — are left
///   out, since drawing those would overstate the page more often than not.
/// * **The palette is threaded, not read.** These builders are static, so they
///   have no [BuildContext] of their own; [build] resolves the palette once and
///   passes it down. Only the parts drawn *outside* a shimmer take it — inside,
///   the sweep replaces every colour anyway.
class BookingDetailsShimmer extends StatelessWidget {
  const BookingDetailsShimmer({super.key});

  /// Horizontal inset every section of the real page shares.
  static const EdgeInsets _gutter = EdgeInsets.symmetric(horizontal: 24);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      // The real page scrolls and its content runs past a phone screen; without
      // this the skeleton overflows on short devices. It does not scroll under
      // the finger, though — there is nothing yet to scroll to.
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status strip — a solid full-bleed bar, outside the gutter.
          Container(height: 30, color: c.skeleton),
          const SizedBox(height: 16),

          Padding(padding: _gutter, child: _bookingCard(c)),
          const SizedBox(height: 12),

          _vehicleImage(c),

          const SizedBox(height: 24),
          _sectionLabel(c, width: 70),
          const SizedBox(height: 12),
          Padding(padding: _gutter, child: _driverCard(c)),

          const SizedBox(height: 24),
          _sectionLabel(c, width: 84),
          const SizedBox(height: 12),
          Padding(padding: _gutter, child: _timelineCard(c)),

          const SizedBox(height: 24),
          _sectionLabel(c, width: 108),
          const SizedBox(height: 12),
          Padding(padding: _gutter, child: _paymentCard(c)),

          const SizedBox(height: 24),
          _sectionLabel(c, width: 120),
          const SizedBox(height: 12),
          Padding(padding: _gutter, child: _transactionCard(c)),

          const SizedBox(height: 24),
          Padding(padding: _gutter, child: _button(c)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Primitives
  // ---------------------------------------------------------------------------

  /// One placeholder bar. White because the shimmer gradient replaces its
  /// colour outright; only its geometry matters here.
  static Widget _bar({double? width, double height = 12, double radius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  static Widget _dot(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }

  /// Wrap a panel's contents in the sweep, leaving its chrome untouched.
  static Widget _shimmer(AppPalette c, Widget child) {
    return Shimmer.fromColors(
      baseColor: c.shimmerBase,
      highlightColor: c.shimmerHighlight,
      child: child,
    );
  }

  /// The heading above each section, which is 12pt text at the shared gutter.
  static Widget _sectionLabel(AppPalette c, {required double width}) {
    return Padding(
      padding: _gutter,
      child: _shimmer(c, _bar(width: width, height: 12)),
    );
  }

  /// The bordered panel every section below the booking card is built on.
  static Widget _cardShell(
    AppPalette c, {
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    double radius = 12,
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: c.surfaceDeep,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.border),
      ),
      child: _shimmer(c, child),
    );
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  /// Mirrors the booking card in its review form: a 1px rim around the card
  /// body, its rows spaced 10 apart.
  static Widget _bookingCard(AppPalette c) {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.divider, c.border]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.surfaceDeep,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _shimmer(
          c,
          Column(
            spacing: 10,
            children: [
              // Service and duration headings, each over its value.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _bar(width: 46, height: 12),
                      const SizedBox(height: 5),
                      _bar(width: 118, height: 14),
                      const SizedBox(height: 3),
                      _bar(width: 86, height: 11),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _bar(width: 52, height: 12),
                      const SizedBox(height: 5),
                      _bar(width: 64, height: 14),
                    ],
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 5),

              // Pickup and drop-off, with the arrow between them.
              Row(
                children: [
                  Expanded(child: _addressBlock()),
                  const SizedBox(width: 4),
                  _dot(40),
                  const SizedBox(width: 8),
                  Expanded(child: _addressBlock()),
                ],
              ),

              // The date / passengers / vehicle strip, which keeps its own fill
              // in the real card. Inside the sweep, so this is an alpha stencil
              // rather than a colour — half-strength, to read as a filled band
              // behind the bars rather than as another bar.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _iconAndLabel(),
                    Container(height: 20, width: 1, color: Colors.white24),
                    _iconAndLabel(),
                    Container(height: 20, width: 1, color: Colors.white24),
                    _iconAndLabel(),
                  ],
                ),
              ),

              // Passengers row under the closing rule.
              Column(
                children: [
                  const Divider(color: Colors.white24, height: 5),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _bar(width: 74, height: 12),
                      _bar(width: 24, height: 12),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A pickup or drop-off column: the small label chip, then the address.
  static Widget _addressBlock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(width: 58, height: 18, radius: 6),
        const SizedBox(height: 8),
        _bar(height: 12),
        const SizedBox(height: 4),
        _bar(width: 90, height: 12),
      ],
    );
  }

  static Widget _iconAndLabel() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(16),
        const SizedBox(width: 5),
        _bar(width: 38, height: 10),
      ],
    );
  }

  /// The 1.7 aspect-ratio vehicle photo, at the gutter with its 12pt lead-in.
  static Widget _vehicleImage(AppPalette c) {
    return Padding(
      padding: _gutter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _shimmer(
              c,
              AspectRatio(
                aspectRatio: 1.7,
                child: Container(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Avatar, name, rating and plate, and the round call button.
  static Widget _driverCard(AppPalette c) {
    return _cardShell(
      c,
      radius: 16,
      borderColor: c.divider,
      child: Row(
        children: [
          _dot(50),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _bar(width: 128, height: 14),
                const SizedBox(height: 6),
                _bar(width: 96, height: 12),
                const SizedBox(height: 6),
                _bar(width: 112, height: 12),
              ],
            ),
          ),
          _dot(58),
        ],
      ),
    );
  }

  /// Four progress steps, each a node and connector beside two lines of text.
  static Widget _timelineCard(AppPalette c) {
    return _cardShell(
      c,
      child: Column(
        children: [for (var i = 0; i < 4; i++) _timelineStep(isLast: i == 3)],
      ),
    );
  }

  static Widget _timelineStep({required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _dot(14),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(width: 132, height: 13),
                  const SizedBox(height: 2),
                  _bar(width: 104, height: 11),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Three charge lines, the rule, and the bolder total.
  static Widget _paymentCard(AppPalette c) {
    return _cardShell(
      c,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _amountRow(labelWidth: 64),
          const SizedBox(height: 8),
          _amountRow(labelWidth: 92),
          const SizedBox(height: 8),
          _amountRow(labelWidth: 78),
          const SizedBox(height: 8),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          _amountRow(labelWidth: 44),
        ],
      ),
    );
  }

  static Widget _amountRow({required double labelWidth}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _bar(width: labelWidth, height: 13),
        _bar(width: 62, height: 13),
      ],
    );
  }

  /// Order and transaction references, each with its copy button.
  static Widget _transactionCard(AppPalette c) {
    return _cardShell(
      c,
      child: Column(
        children: [
          _transactionRow(),
          const Divider(color: Colors.white10, height: 24),
          _transactionRow(),
        ],
      ),
    );
  }

  static Widget _transactionRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(width: 72, height: 12),
              const SizedBox(height: 4),
              _bar(width: 156, height: 12),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _bar(width: 32, height: 32, radius: 8),
      ],
    );
  }

  /// One action button, at the height the page's buttons render.
  static Widget _button(AppPalette c) {
    return _shimmer(c, _bar(height: 45, radius: 8));
  }
}
