import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart' show Shimmer;

import 'package:premium_force_main/api/booking_api_v2.dart';
import 'package:premium_force_main/bookings/driver_tracking_page.dart';
import 'package:premium_force_main/bookings/rate_booking_sheet.dart';
import 'package:premium_force_main/common_widgets/bookingcard.dart';
import 'package:premium_force_main/common_widgets/booking_details_shimmer.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/riyal_symbol.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/common_widgets/voice_player.dart';
import 'package:premium_force_main/common_widgets/textfield.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/models/v2/booking_service_type.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/models/v2/review_v2.dart';
import 'package:premium_force_main/services/invoice_service.dart';
import 'package:premium_force_main/theme/app_palette.dart';
import 'package:premium_force_main/utils/booking_status_display.dart';
import 'package:premium_force_main/utils/date_display.dart';
import 'package:premium_force_main/utils/screen_logger.dart';
import 'package:url_launcher/url_launcher.dart';

class _CancelBookingDialog extends StatefulWidget {
  const _CancelBookingDialog({
    required this.title,
    required this.confirmationText,
    required this.reasonTitle,
    required this.reasonHint,
    required this.cancelText,
    required this.confirmText,
    required this.onConfirm,
  });

  final String title;
  final String confirmationText;
  final String reasonTitle;
  final String reasonHint;
  final String cancelText;
  final String confirmText;
  final Future<void> Function(String reason) onConfirm;

  @override
  State<_CancelBookingDialog> createState() => _CancelBookingDialogState();
}

class _CancelBookingDialogState extends State<_CancelBookingDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border),
      ),
      scrollable: true,
      title: Text(
        widget.title,
        style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.confirmationText,
            style: TextStyle(color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          PremiumTextField(
            title: widget.reasonTitle,
            titleFontWeight: FontWeight.w500,
            fontsize: 13,
            controller: _reasonController,
            hintText: widget.reasonHint,
            maxLines: 3,
            blackbg: true,
            needBorder: true,
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            widget.cancelText,
            style: TextStyle(color: c.textSecondary),
          ),
        ),
        SizedBox(
          height: 45,
          width: 110,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _reasonController,
            builder: (context, value, child) {
              final reason = value.text.trim();
              return PremiumButton(
                text: widget.confirmText,
                enabled: reason.isNotEmpty,
                onTap: () {
                  Navigator.pop(context);
                  widget.onConfirm(reason);
                },
                fontsize: 14,
                showLoader: false,
                borderRadius: 8.0,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Detail view for a confirmed booking, backed by `GET /bookings/:id`.
///
/// The page is addressed by id and fetches its own data, so the summary shown
/// here is always current rather than whatever the list happened to hold. The
/// response arrives fully populated — driver, fleet, payment, refund and the
/// progress timeline — so no follow-up lookups are needed.
class BookingDetailsPage extends StatefulWidget {
  const BookingDetailsPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  final BookingApiV2 _api = BookingApiV2();
  final InvoiceService _invoices = InvoiceService();

  BookingV2? _booking;
  bool _isLoading = true;
  bool _isCancelling = false;
  bool _isOpeningInvoice = false;
  String? _errorMessage;

  /// The cancel endpoint's acknowledgement, which names the refund before the
  /// booking record itself reports one.
  BookingCancellation? _cancellation;

  /// The review this session submitted, kept so the page can show the rating
  /// straight away — the booking payload does not echo it back.
  ReviewV2? _review;

  /// Set once the booking is cancelled, so popping refreshes the list behind.
  bool _didChange = false;

  /// Console tag prefixing this screen's log lines.
  static const String _log = 'booking-details';

  /// Last pickup line logged, so [_buildContent] — which runs on every frame —
  /// logs the card's date and time once per load rather than once per frame.
  String? _loggedPickup;

  /// Fires the moment the cancellation window closes.
  ///
  /// The button is decided in [build], so a page left open across the
  /// four-hour mark would otherwise keep offering a cancellation the rule no
  /// longer allows until something else happened to rebuild it.
  Timer? _cancellationCutoffTimer;

  @override
  void initState() {
    super.initState();
    logScreen(_log, 'open ${widget.bookingId}');
    _loadBooking();
  }

  @override
  void dispose() {
    _cancellationCutoffTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBooking() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    logScreen(_log, 'GET booking ${widget.bookingId}');
    final startedAt = DateTime.now();
    final result = await _api.getBookingById(widget.bookingId);
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;

    if (!mounted) {
      // Worth a line: the request did come back, it just arrived after the
      // customer had left, so nothing below runs.
      logScreen(_log, 'loaded after dispose, discarded (${elapsedMs}ms)');
      return;
    }

    final booking = result.data;
    if (booking == null) {
      logScreen(
        _log,
        'load failed (${elapsedMs}ms): ${result.message ?? 'no message'}',
      );
    } else {
      logScreen(_log, 'loaded (${elapsedMs}ms) ${bookingSummary(booking)}');
      logScreenDetail(
        _log,
        'timeline=${booking.timeline.length} steps '
        'trackable=${booking.status.isTrackable} '
        'cancellable=${booking.isCancellable} '
        '(status=${booking.status.isCancellable} '
        'insideCutoff=${booking.isWithinCancellationCutoff})',
      );
      // A fresh payload may resolve the pickup differently, so the card's
      // date and time are logged again for it.
      _loggedPickup = null;
    }

    setState(() {
      _isLoading = false;
      _booking = booking;
      _errorMessage = result.hasData
          ? null
          : (result.message ?? 'Could not load this booking.');
    });

    _scheduleCancellationCutoff(booking);
  }

  /// Take the cancel button down the moment the window closes.
  ///
  /// A page opened just outside the four hours is the case worth covering: the
  /// customer reads for a few minutes, the window closes while they sit there,
  /// and without this the button is still on screen offering something the
  /// rule no longer allows. Nothing is scheduled for a booking that cannot be
  /// cancelled anyway, or for one whose window has already closed.
  void _scheduleCancellationCutoff(BookingV2? booking) {
    _cancellationCutoffTimer?.cancel();
    if (booking == null || !booking.isCancellable) return;

    final closesIn = booking.untilCancellationCloses;
    if (closesIn == null || closesIn.isNegative) return;

    logScreenDetail(_log, 'cancellation closes in ${closesIn.inMinutes} min');
    _cancellationCutoffTimer = Timer(closesIn, () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          logScreen(_log, 'close, changed=$_didChange');
          Navigator.pop(context, _didChange);
        }
      },
      child: Scaffold(
        backgroundColor: context.colors.sheet,
        appBar: buidAppBar(context),
        body: _isLoading
            ? const BookingDetailsShimmer()
            : _booking == null
            ? _buildErrorState(loc)
            : _buildContent(context, loc, _booking!),
      ),
    );
  }

  /// Log the pickup date and time the card is about to show, once per load.
  ///
  /// Called from the build path, so it compares against the last line emitted:
  /// rebuilds for anything else — a snackbar, the invoice spinner — log nothing.
  void _logPickup(BookingV2 booking, ({String date, String time}) pickup) {
    final line = '${pickup.date}|${pickup.time}';
    if (_loggedPickup == line) return;
    _loggedPickup = line;
    logPickupDisplay(_log, booking, date: pickup.date, time: pickup.time);
  }

  Widget _buildErrorState(AppLocalizations loc) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: c.iconMuted, size: 56),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? loc.somethingWentWrong,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 180,
              child: PremiumButton(
                fontsize: 12,
                text: loc.retry,
                showLoader: false,
                onTap: _loadBooking,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations loc,
    BookingV2 booking,
  ) {
    final c = context.colors;
    final pickup = formatPickupDisplay(context, [booking.route]);
    _logPickup(booking, pickup);

    // Hourly hire is the only product with a booked duration; everything else
    // leaves the slot across from the service type empty.
    final durationHours = booking.route?.durationHours ?? 0;

    return RefreshIndicator(
      onRefresh: _loadBooking,
      color: c.accent,
      backgroundColor: c.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 30,
              color: bookingStatusColor(c, booking.status),
              child: Center(
                child: Text(
                  getBookingStatusText(booking.status),
                  style: TextStyle(
                    color: onBookingStatusColor(c, booking.status),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Bookingcard(
                isFromReviewAndConfirm: true,
                status: booking.status,
                isChauffeur: booking.isChauffeur,
                type: _getBookingCategoryName(booking, context),
                pickup: booking.pickupAddress ?? 'N/A',
                dropoff: booking.dropOffAddress ?? 'N/A',
                date: pickup.date,
                time: pickup.time,
                ride: booking.vehicleLabel,
                brand: booking.vehicle?.name ?? '',
                passengers: booking.passengersCount,
                bookingNumber: booking.bookingNumber,
                durationLabel: durationHours > 0
                    ? loc.nHours(durationHours)
                    : null,
                chauffeurName: booking.driver?.name,
              ),
            ),
            const SizedBox(height: 12),

            if (booking.hasCancellationNote)
              _buildCancellationNotice(booking, loc),

            if (booking.vehicle?.image != null) _buildVehicleImage(booking),

            if (booking.driver != null) ...[
              const SizedBox(height: 24),
              _sectionLabel(loc.chauffeur),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildDriverCard(booking),
              ),
            ],

            if (booking.timeline.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildTimeline(booking, loc),
            ],

            const SizedBox(height: 20),
            _buildRideNotes(booking, loc),

            _buildPaymentSummary(context, loc, booking),

            _buildTransactionDetails(booking, loc),

            // Shown from the booking's own refund record, or straight from the
            // cancellation the customer just made.
            if (booking.refund != null || (_cancellation?.hasRefund ?? false))
              _buildRefundNotice(booking, loc),

            const SizedBox(height: 24),

            // Tracking and rating both live inside the driver card — see
            // `_buildDriverCard`. Both are about the driver, so they belong
            // with their name and photo rather than in the run of page-level
            // actions here.

            // Shown from `invoiceUrl`, which the API attaches only once the
            // booking is paid for — so its presence is the whole condition.
            if (booking.hasInvoice) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PremiumButton(
                  fontsize: 12,
                  text: loc.viewInvoice,
                  showLoader: _isOpeningInvoice,
                  onTap: _isOpeningInvoice ? () {} : _openInvoice,
                ),
              ),
            ],

            // Rating lives inside the driver card — see `_buildDriverCard`.
            // It is about the driver, so it belongs with their name and photo
            // rather than in the run of page-level actions at the bottom.
            // Status alone is not enough: cancelling closes four hours before
            // the pickup, so `BookingV2.isCancellable` is what this reads.
            if (booking.isCancellable) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PremiumButton(
                  fontsize: 12,
                  text: loc.cancelBookingButton,
                  showLoader: _isCancelling,
                  // Destructive, so it drops the gold for the error tone.
                  gradient: [c.error, c.error],
                  textColor: Colors.white,
                  onTap: _isCancelling
                      ? () {}
                      : () => _showCancelDialog(context),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        text,
        style: TextStyle(
          color: context.colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildVehicleImage(BookingV2 booking) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: c.skeleton,
              width: double.infinity,
              child: AspectRatio(
                aspectRatio: 1.7,
                child: CachedNetworkImage(
                  imageUrl: booking.vehicle!.image!,
                  fit: BoxFit.cover,
                  memCacheWidth: 1080,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: c.shimmerBase,
                    highlightColor: c.shimmerHighlight,
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.directions_car,
                    size: 50,
                    color: c.iconMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            booking.vehicleLabel,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Vertical progress stepper, rendered from the server-supplied timeline.
  ///
  /// The backend decides which steps exist and which is current, so a
  /// cancelled booking shows its own terminal step without special-casing here.
  Widget _buildTimeline(BookingV2 booking, AppLocalizations loc) {
    final c = context.colors;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final steps = booking.timeline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(loc.bookingInfo),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surfaceDeep,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  _buildTimelineStep(
                    steps[i],
                    isArabic: isArabic,
                    isLast: i == steps.length - 1,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineStep(
    BookingTimelineStep step, {
    required bool isArabic,
    required bool isLast,
  }) {
    // Completed is checked before current, and the order matters: the backend
    // marks the stage the booking has reached as both. Reading `isCurrent`
    // first painted a step that was already done — a driver who had been
    // assigned — in the in-progress gold instead of green.
    final c = context.colors;
    final Color color = step.isCancelled
        ? c.error
        : step.isCompleted
        ? c.success
        : step.isCurrent
        ? c.accent
        : c.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.isCompleted || step.isCurrent
                      ? color
                      : Colors.transparent,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: step.isCompleted ? c.success : c.divider,
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
                  Text(
                    step.displayLabel(isArabic),
                    style: TextStyle(
                      color: step.isCompleted || step.isCurrent
                          ? c.textPrimary
                          : c.textDisabled,
                      fontSize: 13,
                      fontWeight: step.isCurrent
                          ? FontWeight.bold
                          : FontWeight.w400,
                    ),
                  ),
                  if (step.timestamp != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${Bookingcard.formatDate(context, step.timestamp)} · '
                      '${Bookingcard.formatTime(context, step.timestamp)}',
                      style: TextStyle(color: c.textTertiary, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ride notes captured at booking time — the typed request, the recording
  /// the customer attached, or both.
  ///
  /// Either one alone is enough to show the section: a booking can carry a
  /// voice note with no text at all.
  Widget _buildRideNotes(BookingV2 booking, AppLocalizations loc) {
    final c = context.colors;
    final notes = booking.rideNotes?.trim();
    final hasNotes = notes != null && notes.isNotEmpty;
    if (!hasNotes && !booking.hasVoiceNote) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(loc.specialRequests),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surfaceDeep,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasNotes)
                  Text(
                    notes,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                if (hasNotes && booking.hasVoiceNote)
                  const SizedBox(height: 12),
                if (booking.hasVoiceNote)
                  VoicePlayer(audioUrl: booking.voiceNote!.trim()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Price breakdown, rendered from the amounts the backend recorded.
  ///
  /// The old page had to reverse-engineer the base fare out of the stored
  /// total; v2 stores every component, so each line is read directly.
  Widget _buildPaymentSummary(
    BuildContext context,
    AppLocalizations loc,
    BookingV2 booking,
  ) {
    final c = context.colors;
    final pricing = booking.pricing;
    final extraCharges = booking.extraCharges;
    if (pricing == null) return const SizedBox.shrink();

    final coupon = pricing.discounts.coupon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(loc.paymentSummary),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: c.surfaceDeep,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryRow(loc.charge, pricing.baseFare),
                if (pricing.discounts.totalDiscount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        coupon != null
                            ? '${loc.discount} (${coupon.code})'
                            : loc.discount,
                        style: TextStyle(
                          color: c.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        textDirection: TextDirection.ltr,
                        children: [
                          RiyalSymbol(color: c.success, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            pricing.discounts.totalDiscount.toStringAsFixed(2),
                            style: TextStyle(
                              color: c.success,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                _buildSummaryRow(
                  Bookingcard.formatPercentLabel(
                    loc.vat,
                    pricing.vat.percentage,
                  ),
                  pricing.vat.amount,
                ),
                // Extra charges section (if any)
                if (extraCharges != null && !extraCharges.isEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.extraCharges,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        textDirection: TextDirection.ltr,
                        children: [
                          RiyalSymbol(color: c.textPrimary, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            extraCharges.amount.toStringAsFixed(2),
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (extraCharges.notes?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      '• ${extraCharges.notes}',
                      style: TextStyle(
                        color: c.textTertiary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                Divider(color: c.divider),
                const SizedBox(height: 16),
                _buildSummaryRow(
                  loc.total,
                  pricing.totalAmount + (extraCharges?.amount ?? 0),
                  isBold: true,
                  color: c.accent,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionDetails(BookingV2 booking, AppLocalizations loc) {
    final c = context.colors;
    final transactionRef = booking.payment?.transactionRef;
    final bookingNumber = booking.bookingNumber;

    if (bookingNumber.isEmpty && transactionRef == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _sectionLabel(loc.transactionDetails),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surfaceDeep,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                if (bookingNumber.isNotEmpty)
                  _buildTransactionRow(loc.orderIDLabel, bookingNumber),
                if (bookingNumber.isNotEmpty && transactionRef != null)
                  Divider(color: c.divider, height: 24),
                if (transactionRef != null)
                  _buildTransactionRow(loc.transactionIDLabel, transactionRef),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The note recorded against a cancelled booking.
  ///
  /// Shown from the booking's own record — the cancel endpoint acknowledges
  /// the refund but not the note, so this only appears once the booking has
  /// been re-read.
  Widget _buildCancellationNotice(BookingV2 booking, AppLocalizations loc) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.errorSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.errorBorder, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cancel_outlined, color: c.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.cancellationNote,
                    style: TextStyle(
                      color: c.error,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.cancellationNote!.trim(),
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Refund notice, shown once a cancellation has triggered a gateway refund.
  ///
  /// Reads the booking's own refund record, falling back to the cancellation
  /// acknowledgement so the customer is told about the refund immediately
  /// rather than only after the record catches up.
  Widget _buildRefundNotice(BookingV2 booking, AppLocalizations loc) {
    final c = context.colors;
    final refund = booking.refund;
    final amount = refund?.amount ?? _cancellation?.refundAmount;
    final reference = refund?.reference ?? _cancellation?.refundNumber;

    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.successSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.successBorder, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.replay_circle_filled_outlined,
              color: c.success,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.refundProcessed,
                    style: TextStyle(
                      color: c.success,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (amount != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.ltr,
                      children: [
                        RiyalSymbol(color: c.textSecondary, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          amount.toStringAsFixed(2),
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (reference != null && reference.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${loc.refundReference}: $reference',
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    loc.refundBusinessDaysNote,
                    style: TextStyle(color: c.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionRow(String label, String value) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: c.textTertiary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                // No family, so this follows the app's — see ThemeData in
                // main.dart. It was 'monospace' to keep reference digits
                // aligned; naming the family here instead would just be a
                // second place to update the next time it changes.
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: c.accent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              AnimatedSnackBar.show(
                context,
                AppLocalizations.of(context)!.copiedToClipboard(label),
                'S',
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Icon(Icons.copy_rounded, color: c.onAccent, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isBold = false,
    Color? color,
  }) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w400,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: [
            RiyalSymbol(color: color ?? c.textPrimary, size: 13),
            const SizedBox(width: 4),
            Text(
              amount.toStringAsFixed(2),
              style: TextStyle(
                color: color ?? c.textPrimary,
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDriverCard(BookingV2 booking) {
    final loc = AppLocalizations.of(context)!;
    final c = context.colors;
    final driver = booking.driver!;
    final plate = booking.fleet?.licensePlate;

    // Once the ride is over there is nothing left to call the driver about, so
    // a finished or cancelled booking shows neither the number nor the call
    // button. Treated as "no phone at all" rather than as a separate flag, so
    // the two stay in step: the button is the only thing that dials, and it
    // reads the same value the row renders.
    final phone = booking.status.isConcluded ? null : driver.phone?.trim();
    final canCall = phone != null && phone.isNotEmpty;

    // Rating belongs to the driver, so it sits in their card rather than in
    // the run of page actions at the foot of the screen. Only once the ride is
    // done — there is nothing to rate before that.
    final canRate = booking.isCompleted;

    // Hidden until the driver sets off, which is when the driver app starts
    // publishing its position. The two are mutually exclusive — a ride is
    // either under way or finished — so the card only ever grows one action.
    final canTrack = booking.status.isTrackable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipOval(
                child: Container(
                  width: 50,
                  height: 50,
                  color: c.accentSurface,
                  child: (driver.avatar != null && driver.avatar!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: driver.avatar!,
                          fit: BoxFit.cover,
                          // 50pt avatar at 3x.
                          memCacheWidth: 150,
                          placeholder: (context, url) => Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: c.accent,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              Icon(Icons.person, color: c.accent),
                        )
                      : Icon(Icons.person, color: c.accent),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      driver.name ?? '',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (driver.rating != null) ...[
                          Icon(Icons.star, color: c.accent, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            driver.rating!.toStringAsFixed(1),
                            style: TextStyle(color: c.textSecondary, fontSize: 12),
                          ),
                        ],
                        if (driver.rating != null && plate != null)
                          Text(
                            '  ·  ',
                            style: TextStyle(color: c.textTertiary, fontSize: 12),
                          ),
                        if (plate != null)
                          Flexible(
                            child: Text(
                              plate,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    if (canCall) ...[
                      Text(
                        phone,
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (canCall)
                IconButton.filled(
                  onPressed: () => _makePhoneCall(phone),
                  icon: const Icon(Icons.phone, size: 18),
                  color: c.accent,
                  padding: const EdgeInsets.all(20),
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(c.surfaceAlt),
                    shape: const WidgetStatePropertyAll(CircleBorder()),
                  ),
                  tooltip: AppLocalizations.of(context)!.phoneNumber,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),

          if (canTrack || canRate) ...[
            const SizedBox(height: 14),
            Divider(color: c.divider, height: 1),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: canTrack
                  ? PremiumButton(
                      fontsize: 12,
                      text: loc.trackDriver,
                      showLoader: false,
                      onTap: () {
                        logScreen(
                          _log,
                          'open tracking ${bookingRef(booking)} '
                          'at ${booking.status.wireValue}',
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DriverTrackingPage(booking: booking),
                          ),
                        );
                      },
                    )
                  : _review == null
                  ? PremiumButton(
                      fontsize: 12,
                      text: loc.rateYourDriver,
                      showLoader: false,
                      onTap: _rateBooking,
                    )
                  : _buildSubmittedReview(loc, _review!),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else if (mounted) {
      AnimatedSnackBar.show(
        context,
        AppLocalizations.of(context)!.cannotMakePhoneCalls,
        'E',
      );
    }
  }

  /// Confirmation before cancelling, styled like the app's exit dialog: the
  /// dismissive action is a plain grey text button and the one that acts is a
  /// [PremiumButton], so the two never read as equal weight.
  ///
  /// The reason is required. "Yes, Cancel" stays disabled until something has
  /// been typed, which is why the button is rebuilt from the controller rather
  /// than built once with the dialog.
  void _showCancelDialog(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => _CancelBookingDialog(
        title: loc.cancelBooking,
        confirmationText: loc.cancelBookingConfirm,
        reasonTitle: loc.cancellationReason,
        reasonHint: loc.cancellationReasonHint,
        cancelText: loc.no,
        confirmText: loc.yesCancel,
        onConfirm: _cancelBooking,
      ),
    );
  }

  /// Cancel via `POST /bookings/:id/cancel`, which also triggers the automated
  /// gateway refund. The refreshed booking is re-read so the refund notice and
  /// new status appear without leaving the page.
  Future<void> _cancelBooking(String reason) async {
    setState(() => _isCancelling = true);

    // The reason itself is the customer's own words, so only its length is
    // logged — enough to confirm the dialog passed something through.
    logScreen(
      _log,
      'cancel ${widget.bookingId} (reason ${reason.length} chars)',
    );

    final result = await _api.cancelBooking(
      bookingId: widget.bookingId,
      reason: reason,
    );
    if (!mounted) return;

    setState(() => _isCancelling = false);

    if (!result.success) {
      logScreen(_log, 'cancel failed: ${result.message ?? 'no message'}');
      AnimatedSnackBar.show(
        context,
        result.message ?? AppLocalizations.of(context)!.somethingWentWrong,
        'E',
      );
      return;
    }

    _didChange = true;
    final cancellation = result.data;
    logScreen(
      _log,
      'cancelled — refund=${cancellation?.hasRefund ?? false} '
      'status=${cancellation?.refundStatus ?? '-'} '
      'amount=${cancellation?.refundAmount ?? '-'}',
    );
    AnimatedSnackBar.show(
      context,
      AppLocalizations.of(context)!.bookingCancelledSuccessfully,
      'S',
    );

    // The endpoint acknowledges the cancellation and its refund rather than
    // echoing the booking, so the page is re-read. The acknowledgement is kept
    // meanwhile: it names the refund before the booking record catches up.
    setState(() => _cancellation = result.data);
    await _loadBooking();
  }

  /// Fetch the booking's VAT invoice and hand it to the device's PDF viewer.
  ///
  /// The endpoint is authenticated, so the PDF is downloaded with the customer's
  /// token and opened from local storage rather than being handed to a browser.
  Future<void> _openInvoice() async {
    final booking = _booking;
    if (booking == null) return;

    final loc = AppLocalizations.of(context)!;
    setState(() => _isOpeningInvoice = true);
    AnimatedSnackBar.show(context, loc.preparingInvoice, 'I');

    logScreen(_log, 'open invoice ${bookingRef(booking)}');
    final outcome = await _invoices.open(booking);
    if (!mounted) return;

    setState(() => _isOpeningInvoice = false);
    if (outcome.success) {
      logScreen(_log, 'invoice handed to the device viewer');
      return;
    }

    logScreen(
      _log,
      'invoice failed — unavailable=${outcome.isUnavailable} '
      'missingViewer=${outcome.isMissingViewer} '
      'generic=${outcome.isGenericFailure} '
      'message=${outcome.message ?? '-'}',
    );

    // `message` is either one of the service's sentinels or a server string
    // worth showing verbatim (e.g. "Invoice not available for unpaid booking").
    final message = outcome.isUnavailable
        ? loc.invoiceNotAvailableYet
        : outcome.isMissingViewer
        ? loc.noPdfViewerFound
        : outcome.isGenericFailure
        ? loc.couldNotOpenInvoice
        : (outcome.message ?? loc.couldNotOpenInvoice);

    AnimatedSnackBar.show(
      context,
      message,
      outcome.isMissingViewer ? 'I' : 'E',
    );
  }

  /// Rate the completed ride via `POST /reviews`.
  Future<void> _rateBooking() async {
    final booking = _booking;
    if (booking == null) return;

    logScreen(_log, 'rate sheet opened for ${bookingRef(booking)}');
    final review = await RateBookingSheet.show(context, booking: booking);
    if (review == null || !mounted) {
      logScreen(
        _log,
        review == null
            ? 'rate sheet dismissed without a review'
            : 'review submitted but the page was gone',
      );
      return;
    }

    logScreen(_log, 'review submitted — ${review.rate}★');
    setState(() => _review = review);
    AnimatedSnackBar.show(
      context,
      AppLocalizations.of(context)!.reviewSubmittedSuccessfully,
      'S',
    );
  }

  /// The rating just submitted, shown in place of the rate button.
  ///
  /// Carries no card of its own: it renders inside the driver card, which
  /// already supplies the black panel and its border. Wrapping it in a second
  /// identical one drew a border inside a border.
  Widget _buildSubmittedReview(AppLocalizations loc, ReviewV2 review) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.yourReview,
          style: TextStyle(color: c.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final isFilled = index < review.rate;
            return Icon(
              isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: isFilled ? c.accent : c.border,
              size: 18,
            );
          }),
        ),
        if (review.reviewText?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          Text(
            review.reviewText!,
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
        ],
      ],
    );
  }

  /// Localised product name for the header.
  String _getBookingCategoryName(BookingV2 booking, BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return switch (booking.resolvedServiceType) {
      BookingServiceType.airportArrival => loc.airportArrival,
      BookingServiceType.airportDeparture => loc.airportDeparture,
      BookingServiceType.chauffeur => loc.chauffeurService,
      BookingServiceType.privateTransfer => loc.privateTransfer,
      null => booking.isChauffeur ? loc.chauffeurService : loc.unknown,
    };
  }

  PreferredSizeWidget buidAppBar(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.colors;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: c.appBarScrim,
          ),
        ),
        child: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: c.icon, size: 16),
            onPressed: () => Navigator.pop(context, _didChange),
          ),
          centerTitle: true,
          title: Text(
            loc.bookingTimeline,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: c.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
        ),
      ),
    );
  }

  /// Full-sentence wording for the banner across the top of the page.
  ///
  /// Deliberately longer than [bookingStatusLabel], which has to fit in the
  /// card's chip.
  String getBookingStatusText(BookingStatusV2 status) {
    final loc = AppLocalizations.of(context)!;
    return switch (status) {
      BookingStatusV2.completed => loc.rideCompletedStatus,
      BookingStatusV2.cancelled => loc.bookingCanceledStatus,
      BookingStatusV2.pendingPayment => loc.paymentPendingStatus,
      BookingStatusV2.confirmed => loc.pendingDriverStatus,
      BookingStatusV2.driverAssigned => loc.driverAssignedStatus,
      BookingStatusV2.driverEnRoute ||
      BookingStatusV2.driverArrived ||
      BookingStatusV2.tripStarted => loc.rideInProgressStatus,
      BookingStatusV2.unknown => bookingStatusLabel(loc, status),
    };
  }
}
