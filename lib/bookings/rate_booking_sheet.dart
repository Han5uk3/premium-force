import 'package:flutter/material.dart';

import 'package:premium_force_main/api/review_api_v2.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/theme/app_palette.dart';
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
    final c = context.colors;

    return Padding(
      // Lift the sheet above the keyboard while the comment field has focus.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Same header the logout and delete-account sheets use: the title
            // ranged left at 18pt with a close control opposite it, over a
            // full-bleed rule. The drag handle that used to sit here is gone
            // with it — those sheets are dismissed by the X, and two ways out
            // in one corner is one more than the pattern has.
            Padding(
              padding: const EdgeInsets.only(
                top: 24,
                bottom: 12,
                left: 24,
                right: 24,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      loc.rateYourDriver,
                      style: TextStyle(color: c.textPrimary, fontSize: 18),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: c.icon, size: 24),
                  ),
                ],
              ),
            ),
            Divider(color: c.divider, thickness: 1),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                 

                  _buildStars(c),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _comment,
                    maxLines: 3,
                    maxLength: 500,
                    enabled: !_isSubmitting,
                    style: TextStyle(color: c.textPrimary, fontSize: 13),
                    // The one field in the app with a gold cursor, which is why
                    // it is set here rather than left to the theme.
                    cursorColor: c.accent,
                    decoration: InputDecoration(
                      hintText: loc.addAnOptionalReview,
                      hintStyle: TextStyle(
                        color: c.textTertiary,
                        fontSize: 13,
                      ),
                      counterStyle: TextStyle(color: c.textTertiary),
                      filled: true,
                      fillColor: c.field,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  PremiumButton(
                    fontsize: 12,
                    text: loc.submit,
                    showLoader: _isSubmitting,
                    enabled: _rating > 0,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStars(AppPalette c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final star = index + 1;
        final isFilled = star <= _rating;

        return IconButton(
          onPressed: _isSubmitting
              ? null
              : () => setState(() => _rating = star),
          icon: Icon(
            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: isFilled ? c.accent : c.border,
            size: 40,
          ),
        );
      }),
    );
  }
}
