import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:premium_force_main/common_widgets/bookingcard.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/models/booking_model.dart';
import 'package:premium_force_main/models/payment_model.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/bookings/driver_tracking_page.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';

class BookingDetailsPage extends StatefulWidget {
  final BookingModel booking;

  const BookingDetailsPage({super.key, required this.booking});

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  DriverDetails? _driver;
  bool _isLoadingDriver = false;
  bool _isPayingExtraHours = false;
  bool _extraHoursPaid = false;
  Map<String, dynamic>? _currentRating;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _currentRating = widget.booking.rating;
    if (widget.booking.driver != null &&
        widget.booking.driver!.driverName != null &&
        widget.booking.driver!.driverName!.isNotEmpty) {
      _driver = widget.booking.driver;
    } else if (widget.booking.driverID != null &&
        widget.booking.driverID != 'null' &&
        widget.booking.driverID!.isNotEmpty) {
      // Name is missing or driver object is null - fetch full details
      _fetchDriverDetails();
    }
  }

  Future<void> _fetchDriverDetails() async {
    // If we already have the driver from the model, no need to fetch
    if (_driver != null) return;

    setState(() {
      _isLoadingDriver = true;
    });

    try {
      final token = UserLocalStorage.getToken();
      final driver = await _apiService.getUserById(
        id: widget.booking.driverID!,
        token: token,
      );
      if (mounted) {
        setState(() {
          if (driver != null) {
            _driver = DriverDetails(
              driverName: driver.username,
              phoneNumber: driver.phoneNumber,
              countryCode: driver.countryCode,
              licenseNumber: driver.specialId,
              profileImageUrl: driver.profileImageUrl,
            );
          }
          _isLoadingDriver = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching driver details: $e');
      if (mounted) {
        setState(() {
          _isLoadingDriver = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final booking = widget.booking;
    final displayDate =
        (booking.pickupdatetime != null && booking.pickupdatetime!.isNotEmpty)
        ? DateTime.tryParse(booking.pickupdatetime!)
        : (booking.arrival != null
              ? DateTime.tryParse(booking.arrival!)
              : null);

    final dateStr = Bookingcard.formatDate(context, displayDate);
    final timeStr = Bookingcard.formatTime(context, displayDate);

    // AI Check for Chauffeur Category
    final isChauffeur =
        (booking.category ?? '').toLowerCase().contains('chauffeur') ||
        booking.estimatedHours != null ||
        booking.bookingType == 'hourly';

    return Scaffold(
      backgroundColor: const Color(0xFF1E1105),
      appBar: buidAppBar(context),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 30,
              color: getStatusLabelColor(booking.bookingStatus ?? ""),
              child: Center(
                child: Text(
                  getBookingStatusText(booking.bookingStatus ?? ""),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            // Booking Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Bookingcard(
                isFromReviewAndConfirm: true,
                status: booking.bookingStatus ?? 'Pending',
                isChauffeur: isChauffeur,
                type: _getBookingCategoryName(booking, context),
                pickup: booking.pickupAddress ?? booking.airport ?? 'N/A',
                dropoff: booking.dropOffAddress ?? 'N/A',
                date: dateStr,
                time: timeStr,
                ride: booking.displayBrand,
                brand: booking.displayBrand,
                passengers: int.tryParse(booking.passengerCount ?? '1') ?? 1,
                chauffeurName: _driver?.driverName ?? booking.displayDriverName,
              ),
            ),
            const SizedBox(height: 12),

            // Car Image and Name (same as review step)
            if (booking.carimage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,

                        child: CachedNetworkImage(
                          imageUrl: booking.carimage!,
                          fit: BoxFit.contain,
                          placeholder: (context, url) {
                            return const Center(child: PremiumLoader(size: 20));
                          },
                          errorWidget: (context, url, error) => const Icon(
                            Icons.directions_car,
                            size: 50,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      booking.displayBrand + " " + booking.displayName,

                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            if ((widget.booking.driverID != null &&
                    widget.booking.driverID != 'null' &&
                    widget.booking.driverID!.isNotEmpty) &&
                (_driver != null || _isLoadingDriver)) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  loc.chauffeur,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildDriverCard(),
              ),
            ],
            const SizedBox(height: 20),
            // Payment Summary
            _buildPaymentSummary(context, loc, booking),

            // Transaction Details (New Section)
            _buildTransactionDetails(booking),

            // Driver Details (if assigned)

            // Review Section (if completed)
            _buildReviewSection(),

            SizedBox(height: 24),

            // ------------------------------------------------------------------
            // Extra Hours charge banner (chauffeur overtime)
            // ------------------------------------------------------------------
            if (_shouldShowExtraHoursSection(booking))
              _buildExtraHoursBanner(booking),

            // Track Driver Button
            if ((booking.bookingStatus ?? '').toLowerCase().trim() ==
                'starttracking')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PremiumButton(
                  fontsize: 14,
                  text: loc.trackDriver,
                  showLoader: false,
                  gradient: const [Color(0xFFE4A46B), Color(0xFF49280B)],
                  textColor: Colors.black,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DriverTrackingPage(booking: booking),
                      ),
                    );
                  },
                ),
              ),

            // Cancel Booking Button
            if ((booking.bookingStatus ?? '').toLowerCase().trim() ==
                    'pending' ||
                (booking.bookingStatus ?? '').toLowerCase().trim() ==
                    'assigned')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PremiumButton(
                  fontsize: 14,
                  text: loc.cancelBookingButton,
                  showLoader: false,
                  gradient: [Colors.red, Colors.red.shade900],
                  textColor: Colors.white,
                  onTap: () {
                    debugPrint('Cancel button tapped');
                    _showCancelDialog(context);
                  },
                ),
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection() {
    final loc = AppLocalizations.of(context)!;
    final status = (widget.booking.bookingStatus ?? '').toLowerCase().trim();
    if (status != 'completed') return const SizedBox.shrink();

    if (_currentRating != null) {
      // Show entered review
      final rate = _currentRating!['rate'] ?? 5;
      final text = _currentRating!['reviewText'] ?? '';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(13),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    loc.yourReview,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rate ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 18,
                      );
                    }),
                  ),
                ],
              ),
              if (text.toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  text.toString(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      // Show "Leave a Review" button
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: PremiumButton(
          fontsize: 14,
          text: loc.leaveAReview,
          showLoader: false,
          textColor: Colors.white,
          onTap: () => _showReviewDialog(context),
        ),
      );
    }
  }

  void _showReviewDialog(BuildContext context) {
    int selectedStars = 5;
    final reviewController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.rateYourDriver,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < selectedStars
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              selectedStars = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reviewController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(
                          context,
                        )!.addAnOptionalReview,
                        hintStyle: TextStyle(
                          color: Colors.white.withAlpha(128),
                        ),
                        filled: true,
                        fillColor: Colors.white.withAlpha(13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.pop(ctx),
                          child: Text(
                            AppLocalizations.of(context)!.cancel,
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE4A46B),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setDialogState(() => isSubmitting = true);
                                  final token = UserLocalStorage.getToken();
                                  final driverID = widget.booking.driverID;

                                  if (driverID == null ||
                                      driverID.isEmpty ||
                                      driverID == 'null') {
                                    AnimatedSnackBar.show(
                                      context,
                                      AppLocalizations.of(
                                        context,
                                      )!.cannotReviewWithoutValidDriver,
                                      'E',
                                    );
                                    setDialogState(() => isSubmitting = false);
                                    Navigator.pop(ctx);
                                    return;
                                  }

                                  final result = await _apiService.addReview(
                                    bookingID: widget.booking.id,
                                    driverID: driverID,
                                    rate: selectedStars,
                                    reviewText: reviewController.text,
                                    token: token,
                                  );

                                  if (mounted) {
                                    if (result['success'] == true) {
                                      setState(() {
                                        _currentRating = {
                                          'rate': selectedStars,
                                          'reviewText': reviewController.text,
                                        };
                                      });
                                      AnimatedSnackBar.show(
                                        context,
                                        AppLocalizations.of(
                                          context,
                                        )!.reviewSubmittedSuccessfully,
                                        'S',
                                      );
                                      Navigator.pop(ctx);
                                    } else {
                                      setDialogState(
                                        () => isSubmitting = false,
                                      );
                                      AnimatedSnackBar.show(
                                        context,
                                        result['message'] ??
                                            'Failed to submit review',
                                        'E',
                                      );
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(AppLocalizations.of(context)!.submit),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentSummary(
    BuildContext context,
    AppLocalizations loc,
    BookingModel booking,
  ) {
    // booking.charge is the total the customer paid (after discount + 15% VAT)
    final total = booking.charge ?? 0.0;
    final discount = booking.discountPercentage ?? 0.0;

    // Reverse-engineer: total = base * (1 - discount%) * 1.15
    // So: base = total / ((1 - discount%) * 1.15)
    final discountFactor = 1.0 - (discount / 100.0);
    final baseCharge = (discountFactor > 0)
        ? total / (discountFactor * 1.15)
        : total / 1.15;
    final discountSaving = baseCharge * (discount / 100.0);
    final discountedBase = baseCharge - discountSaving;
    final vat = discountedBase * 0.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            loc.paymentSummary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryRow(loc.charge, baseCharge),
                if (discount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${loc.discount} (${discount.toStringAsFixed(0)}%)',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        '- ${discountSaving.toStringAsFixed(2)} SAR',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                _buildSummaryRow(loc.vat, vat),
                const SizedBox(height: 8),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  loc.total,
                  total,
                  isBold: true,
                  color: const Color(0xFFE4A46B),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionDetails(BookingModel booking) {
    if (booking.orderID == null && booking.transactionID == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            AppLocalizations.of(context)!.transactionDetails,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: Column(
              children: [
                if (booking.orderID != null)
                  _buildTransactionRow(
                    AppLocalizations.of(context)!.orderIDLabel,
                    booking.orderID!,
                  ),
                if (booking.orderID != null && booking.transactionID != null)
                  const Divider(color: Colors.white10, height: 24),
                if (booking.transactionID != null)
                  _buildTransactionRow(
                    AppLocalizations.of(context)!.transactionIDLabel,
                    booking.transactionID!,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withAlpha(128),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: const Color(0xFFE4A46B),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              AnimatedSnackBar.show(
                context,
                AppLocalizations.of(context)!.copiedToClipboard(label),
                "S",
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(10.0),
              child: Icon(Icons.copy_rounded, color: Colors.black, size: 20),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w400,
          ),
        ),
        Text(
          "${amount.toStringAsFixed(2)} ${AppLocalizations.of(context)!.riyal}",
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverCard() {
    if (_isLoadingDriver) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: PremiumLoader(size: 30)),
      );
    }

    if (_driver == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          ClipOval(
            child: Container(
              width: 50,
              height: 50,
              color: const Color(0xFF49280B),
              child:
                  (_driver?.profileImageUrl != null &&
                      _driver!.profileImageUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: _driver!.profileImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Color(0xFFE4A46B),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.person, color: Color(0xFFE4A46B)),
                    )
                  : const Icon(Icons.person, color: Color(0xFFE4A46B)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.driverAssigned,
                  style: TextStyle(
                    color: Colors.white.withAlpha(153),
                    fontSize: 12,
                  ),
                ),
                Text(
                  _driver!.driverName ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_driver!.licenseNumber != null &&
                    _driver!.licenseNumber!.isNotEmpty)
                  Text(
                    '${AppLocalizations.of(context)!.licenseNumber}: ${_driver!.licenseNumber}',
                    style: TextStyle(
                      color: Colors.white.withAlpha(153),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Simple key–value row used inside the extra-hours banner.
  Widget _extraInfoRow(
    String label,
    String value,
    Color valueColor, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Extra Hours helpers
  // ---------------------------------------------------------------------------

  /// Show the extra hours section when:
  /// - booking is chauffeur (estimatedHours != null)
  /// - extraHours > 0 (driver ran over)
  /// - trip has ended (status is 'endtracking' or completed-but-unpaid)
  /// - customer has not already paid for extra hours in this session.
  bool _shouldShowExtraHoursSection(BookingModel booking) {
    if (_extraHoursPaid) return false;
    final extraHours = booking.extraHours ?? 0;
    if (extraHours <= 0) return false;
    final isChauffeur =
        (booking.category ?? '').toLowerCase().contains('chauffeur') ||
        booking.estimatedHours != null;
    if (!isChauffeur) return false;
    final status = (booking.bookingStatus ?? '').toLowerCase().trim();
    // Show when driver set paymentpending
    return status == 'paymentpending';
  }

  Widget _buildExtraHoursBanner(BookingModel booking) {
    final extraHours = booking.extraHours ?? 0;
    // Use the base per-hour rate from the original charge
    // charge / estimatedHours gives hourly rate; fallback to 0 if unknown
    final bookedHours = booking.estimatedHours ?? 1;
    final originalCharge = booking.charge ?? 0.0;
    final hourlyRate = bookedHours > 0 ? (originalCharge / bookedHours) : 0.0;
    final extraCharge = hourlyRate * extraHours;
    final extraVat = extraCharge * 0.15;
    final extraTotal = extraCharge + extraVat;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withAlpha(64),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade700, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.timer_off,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.extraHoursCharge,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _extraInfoRow(
                  AppLocalizations.of(context)!.extraHoursLabel,
                  '$extraHours ${AppLocalizations.of(context)!.hrs}',
                  Colors.white70,
                ),
                const SizedBox(height: 4),
                _extraInfoRow(
                  AppLocalizations.of(context)!.charge,
                  '${AppLocalizations.of(context)!.riyal} ${extraCharge.toStringAsFixed(2)}',
                  Colors.white70,
                ),
                const SizedBox(height: 4),
                _extraInfoRow(
                  '${AppLocalizations.of(context)!.vat} (15%)',
                  '${AppLocalizations.of(context)!.riyal} ${extraVat.toStringAsFixed(2)}',
                  Colors.white70,
                ),
                const Divider(color: Colors.white24, height: 16),
                _extraInfoRow(
                  AppLocalizations.of(context)!.totalExtraDue,
                  '${AppLocalizations.of(context)!.riyal} ${extraTotal.toStringAsFixed(2)}',
                  Colors.redAccent,
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PremiumButton(
            fontsize: 14,
            text: AppLocalizations.of(context)!.completePayment,
            showLoader: _isPayingExtraHours,
            onTap: _isPayingExtraHours
                ? () {}
                : () =>
                      _payExtraHours(booking: booking, extraTotal: extraTotal),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _payExtraHours({
    required BookingModel booking,
    required double extraTotal,
  }) async {
    if (_isPayingExtraHours) return;
    setState(() => _isPayingExtraHours = true);

    try {
      final userData = UserLocalStorage.getUserData();
      final userEmail = userData?['email'] as String? ?? '';

      final orderId =
          'EXTRA_${booking.id}_${DateTime.now().millisecondsSinceEpoch}';

      // ── BYPASS (same as main booking flow) ──────────────────────────────
      final paymentResult = PaymentResult(
        success: true,
        transactionReference: 'BYPASS_EXTRA_$orderId',
        invoiceId: orderId,
        responseCode: '000',
        responseMessage: 'Success',
        customerEmail: userEmail,
        amount: extraTotal,
        orderID: orderId,
        transactionID: 'BYPASS_EXTRA_$orderId',
      );
      // ── Uncomment below to enable live Paytabs payment ───────────────────
      // final userData2 = UserLocalStorage.getUserData();
      // final paymentResult = await PaymentService().startPayment(
      //   request: PaymentRequest(
      //     amount: double.parse(extraTotal.toStringAsFixed(2)),
      //     currency: PaytabsConfig.defaultCurrency,
      //     merchantCountryCode: PaytabsConfig.merchantCountryCode,
      //     orderId: orderId,
      //     customerEmail: userData2?['email'] ?? '',
      //     customerName: userData2?['name'] ?? 'Customer',
      //     customerPhone: userData2?['phoneNumber'] ?? UserLocalStorage.getPhoneNumber() ?? '',
      //     cartId: orderId,
      //     cartDescription:
      //         'Extra ${booking.extraHours} hour(s) — Chauffeur booking ${booking.id}',
      //   ),
      // );

      if (paymentResult.success) {
        // Mark booking as completed
        final token = UserLocalStorage.getToken();
        final result = await _apiService.updateHourlyBookingStatus(
          bookingId: booking.id,
          status: 'completed',
          transactionReference: paymentResult.transactionReference,
          token: token,
        );

        if (mounted) {
          if (result['success'] == true) {
            setState(() => _extraHoursPaid = true);
            AnimatedSnackBar.show(
              context,
              AppLocalizations.of(context)!.paymentSuccessfulBookingCompleted,
              'S',
            );
            // Pop back so the parent refreshes
            Navigator.pop(context, true);
          } else {
            AnimatedSnackBar.show(
              context,
              result['message'] ?? 'Payment ok, but failed to update booking.',
              'E',
            );
          }
        }
      } else {
        if (mounted) {
          AnimatedSnackBar.show(context, paymentResult.responseMessage, 'E');
        }
      }
    } catch (e) {
      if (mounted) {
        AnimatedSnackBar.show(
          context,
          '${AppLocalizations.of(context)!.paymentError}$e',
          'E',
        );
      }
    } finally {
      if (mounted) setState(() => _isPayingExtraHours = false);
    }
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1105),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.of(context)!.cancelBooking,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.cancelBookingConfirm,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                // User will add link later
                AnimatedSnackBar.show(
                  context,
                  AppLocalizations.of(context)!.policyLinkComingSoon,
                  'I',
                );
              },
              child: Text(
                AppLocalizations.of(context)!.viewCancellationPolicy,
                style: const TextStyle(
                  color: Color(0xFFE4A46B),
                  decoration: TextDecoration.underline,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(
              AppLocalizations.of(context)!.no,
              style: const TextStyle(color: Colors.white54),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(
              AppLocalizations.of(context)!.yesCancel,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _cancelBooking();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking() async {
    setState(() {
      // We can use the existing _isLoadingDriver or a new one
      // but let's just show a simple loader overlay if needed
      // or just handle the API call.
    });

    try {
      final token = UserLocalStorage.getToken();
      final isHourly =
          (widget.booking.category ?? '').toLowerCase().contains('chauffeur') ||
          widget.booking.estimatedHours != null;

      if (isHourly) {
        final result = await _apiService.updateHourlyBookingStatus(
          bookingId: widget.booking.id,
          status: 'cancelled',
          token: token,
        );

        if (mounted) {
          if (result['success'] == true) {
            AnimatedSnackBar.show(
              context,
              AppLocalizations.of(context)!.bookingCancelledSuccessfully,
              'S',
            );
            Navigator.pop(context, true);
          } else {
            AnimatedSnackBar.show(
              context,
              result['message'] ?? 'Failed to cancel booking',
              'E',
            );
          }
        }
        return;
      }

      final result = await _apiService.updateBookingStatus(
        bookingId: widget.booking.id,
        status: 'cancelled',
        token: token,
      );

      if (result['success'] == true) {
        if (mounted) {
          AnimatedSnackBar.show(
            context,
            AppLocalizations.of(context)!.bookingCancelledSuccessfully,
            'S',
          );
          // Return to previous page or refresh
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          AnimatedSnackBar.show(
            context,
            result['message'] ?? 'Failed to cancel booking',
            'E',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AnimatedSnackBar.show(
          context,
          '${AppLocalizations.of(context)!.error}$e',
          'E',
        );
      }
    }
  }

  String _getBookingCategoryName(BookingModel booking, BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // Check booking type first
    final bType = (booking.bookingType ?? '').toLowerCase().trim();
    if (bType == 'hourly') return loc.chauffeur;

    // Check category string
    String category = (booking.category ?? "").toLowerCase().trim();

    if (category == "airport arrival" || category == "arrival") {
      return loc.airportArrival;
    } else if (category == "airport departure" || category == "departure") {
      return loc.airportDeparture;
    } else if (category == "chauffeur" ||
        category == "chauffeur service" ||
        category.contains("chauffeur") ||
        booking.estimatedHours != null) {
      return loc.chauffeur;
    } else if (category == "private transfer" || category.contains("private")) {
      return loc.privateTransfer;
    }

    // Final fallback for hourly if not caught above
    if (booking.estimatedHours != null && booking.estimatedHours! > 0) {
      return loc.chauffeur;
    }

    return category.isNotEmpty
        ? category[0].toUpperCase() + category.substring(1)
        : loc.unknown;
  }

  PreferredSizeWidget buidAppBar(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(100), Colors.transparent],
          ),
        ),
        child: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            loc.bookingInfo,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
        ),
      ),
    );
  }

  Color getStatusLabelColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String getBookingStatusText(String status) {
    final loc = AppLocalizations.of(context)!;
    switch (status.toLowerCase()) {
      case 'completed':
        return loc.tripCompletedStatus;
      case 'cancelled':
        return loc.bookingCanceledStatus;
      case 'pending':
        return loc.pendingDriverStatus;
      case 'assigned':
        return loc.driverAssignedStatus;
      case 'starttracking':
        return loc.rideInProgressStatus;
      case 'paymentpending':
        return loc.paymentPendingStatus;
      case 'reviewed':
        return loc.tripReviewedStatus;
      default:
        return status;
    }
  }
}
