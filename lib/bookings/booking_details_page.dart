import 'package:flutter/material.dart';
import 'package:premium_force_main/common_widgets/bookingcard.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/models/booking_model.dart';
import 'package:premium_force_main/models/user.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/bookings/driver_tracking_page.dart';

class BookingDetailsPage extends StatefulWidget {
  final BookingModel booking;

  const BookingDetailsPage({super.key, required this.booking});

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  UserModel? _driver;
  bool _isLoadingDriver = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.booking.driverID != null &&
        widget.booking.driverID != 'null' &&
        widget.booking.driverID!.isNotEmpty) {
      _fetchDriverDetails();
    }
  }

  Future<void> _fetchDriverDetails() async {
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
          _driver = driver;
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
    final arrivalDate = booking.arrival != null
        ? DateTime.tryParse(booking.arrival!)
        : null;

    final dateStr = Bookingcard.formatDate(context, arrivalDate);
    final timeStr = Bookingcard.formatTime(context, arrivalDate);

    // AI Check for Chauffeur Category
    final isChauffeur =
        (booking.category ?? '').toLowerCase().contains('chauffeur') ||
        booking.estimatedHours != null;

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
                type: _getBookingCategoryName(booking.category, context),
                pickup: booking.pickupAddress ?? booking.airport ?? 'N/A',
                dropoff: booking.dropOffAddress ?? 'N/A',
                date: dateStr,
                time: timeStr,
                ride: booking.displayName,
                brand: booking.displayBrand,
                passengers: int.tryParse(booking.passengerCount ?? '1') ?? 1,
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
                        height: 220,
                        color: Colors.black,
                        child: Image.network(
                          booking.carimage!,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFE4A46B),
                                strokeWidth: 2,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.directions_car,
                                size: 50,
                                color: Colors.white24,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      booking.estimatedHours != null
                          ? booking.displayName
                          : "${booking.displayBrand} ${booking.displayName}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

            // Payment Summary
            _buildPaymentSummary(context, loc, booking),

            // Driver Details (if assigned)
            if (widget.booking.driverID != null &&
                widget.booking.driverID != 'null' &&
                widget.booking.driverID!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  loc.chauffeur,
                  style: const TextStyle(
                    color: Color(0xFFE4A46B),
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

            // Track Driver Button
            if ((booking.bookingStatus ?? '').toLowerCase().trim() == 'starttracking')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PremiumButton(
                  fontsize: 14,
                  text: 'Track Driver',
                  showLoader: false,
                  gradient: const [Color(0xFFE4A46B), Color(0xFF49280B)],
                  textColor: Colors.black,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DriverTrackingPage(booking: booking),
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
                  text: 'Cancel Booking',
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

  Widget _buildPaymentSummary(
    BuildContext context,
    AppLocalizations loc,
    BookingModel booking,
  ) {
    // Logic from new_booking.dart back-calculated
    final total = booking.charge ?? 0.0;
    final baseCharge = total / 1.15;
    final vat = total - baseCharge;

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
                const SizedBox(height: 8),
                _buildSummaryRow(loc.vat, vat),
                const SizedBox(height: 8),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  loc.total,
                  total,
                  isBold: true,
                  color: const Color(0xFFE4A46B),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Status',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      booking.paymentStatus ?? 'Paid',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
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
          "${amount.toStringAsFixed(2)} SAR",
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
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: PremiumLoader(size: 30)),
      );
    }

    if (_driver == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline, color: Colors.white38, size: 40),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Driver Assigned',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'ID: ${widget.booking.driverID}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      );
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
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF49280B),
            backgroundImage: _driver!.profileImageUrl != null
                ? NetworkImage(_driver!.profileImageUrl!)
                : null,
            child: _driver!.profileImageUrl == null
                ? const Icon(Icons.person, color: Color(0xFFE4A46B))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _driver!.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${_driver!.countryCode} ${_driver!.phoneNumber}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {}, // TODO: Implement call
            icon: const Icon(Icons.phone_in_talk, color: Color(0xFFE4A46B)),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1105),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Booking',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this booking?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                // User will add link later
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Policy link coming soon!')),
                );
              },
              child: const Text(
                'View Cancellation & Privacy Policy',
                style: TextStyle(
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
            child: const Text('No', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
        // TODO: Backend update api for hourly/chauffeur bookings is not yet defined
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cancellation for hourly bookings is not yet implemented.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Return to previous page or refresh
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to cancel booking'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getBookingCategoryName(String? category, BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (category == null) return 'Booking';
    switch (category.toLowerCase()) {
      case 'chauffeur':
      case 'chauffeured':
        return loc.chauffeur;
      case 'airport arrival':
        return loc.airportArrival;
      case 'airport departure':
        return loc.airportDeparture;
      default:
        return category;
    }
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
    switch (status.toLowerCase()) {
      case 'completed':
        return 'completed';
      case 'cancelled':
        return 'This booking has been canceled';
      case 'pending':
        return 'A driver will be assigned to you soon!';
      case 'starttracking':
        return 'Your chauffeur is on the way.';
      case 'endtracking':
        return 'Your trip had ended!';
      default:
        return 'default';
    }
  }
}
