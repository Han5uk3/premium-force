import 'package:flutter/material.dart';

import 'package:premium_force_main/api/review_api_v2.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/models/v2/review_v2.dart';

/// Bottom sheet for rating a completed booking, backed by `POST /reviews`.
///
/// The driver is resolved server-side from the booking, so the sheet only needs
/// the booking id. A submitted review is final — the endpoint rejects a second
/// one for the same ride — which is why the sheet closes on success and returns
/// the review it created.
///
/// Usage:
/// ```dart
/// final review = await RateBookingSheet.show(context, booking: booking);
/// if (review != null) setState(() => _review = review);
/// ```
class RateBookingSheet extends StatefulWidget {
  const RateBookingSheet({super.key, required this.booking});

  final BookingV2 booking;

  /// Present the sheet, resolving to the submitted review or null if dismissed.
  static Future<ReviewV2?> show(
    BuildContext context, {
    required BookingV2 booking,
  }) {
    return showModalBottomSheet<ReviewV2>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RateBookingSheet(booking: booking),
    );
  }

  @override
  State<RateBookingSheet> createState() => _RateBookingSheetState();
}

class _RateBookingSheetState extends State<RateBookingSheet> {
  final ReviewApiV2 _api = ReviewApiV2();
  final TextEditingController _comment = TextEditingController();

  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;

    if (_rating == 0) {
      AnimatedSnackBar.show(context, loc.pleaseSelectRating, 'I');
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await _api.submitReview(
      bookingId: widget.booking.id,
      rate: _rating,
      reviewText: _comment.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!result.hasData) {
      AnimatedSnackBar.show(
        context,
        result.message ?? loc.somethingWentWrong,
        'E',
      );
      return;
    }

    Navigator.pop(context, result.data);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final driverName = widget.booking.driver?.name;

    return Padding(
      // Lift the sheet above the keyboard while the comment field has focus.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1105),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              loc.rateYourDriver,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (driverName != null && driverName.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                driverName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFE4A46B), fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),

            _buildStars(),
            const SizedBox(height: 20),

            TextField(
              controller: _comment,
              maxLines: 3,
              maxLength: 500,
              enabled: !_isSubmitting,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              cursorColor: const Color(0xFFE4A46B),
              decoration: InputDecoration(
                hintText: loc.addAnOptionalReview,
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                counterStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.black,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE4A46B)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            PremiumButton(
              fontsize: 12,
              text: loc.submit,
              showLoader: _isSubmitting,
              enabled: _rating > 0,
              textColor: Colors.black,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final star = index + 1;
        final isFilled = star <= _rating;

        return IconButton(
          onPressed: _isSubmitting ? null : () => setState(() => _rating = star),
          icon: Icon(
            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: isFilled ? const Color(0xFFE4A46B) : Colors.white24,
            size: 36,
          ),
        );
      }),
    );
  }
}
