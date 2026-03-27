import 'package:flutter/material.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/models/booking_model.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:intl/intl.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  
  List<BookingModel> _upcomingBookings = [];
  List<BookingModel> _ongoingBookings = [];
  List<BookingModel> _completedBookings = [];
  List<BookingModel> _canceledBookings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUserId = UserLocalStorage.getUserId();
      if (currentUserId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "User not logged in";
        });
        return;
      }

      final token = UserLocalStorage.getToken();
      final response = await _apiService.getAllBookings(token: token);

      if (response['success'] == true) {
        final List<dynamic> allBookingsJson = response['data'] ?? response['bookings'] ?? [];
        
        // Filter by customerID and convert to models
        final List<BookingModel> userBookings = allBookingsJson
            .map((json) => BookingModel.fromJson(json))
            .where((booking) => booking.customerID == currentUserId)
            .toList();

        // Sort by most recent (createdAt or arrival)
        userBookings.sort((a, b) {
          final dateA = a.createdAt ?? (a.arrival != null ? DateTime.tryParse(a.arrival!) : null) ?? DateTime(0);
          final dateB = b.createdAt ?? (b.arrival != null ? DateTime.tryParse(b.arrival!) : null) ?? DateTime(0);
          return dateB.compareTo(dateA); // Most recent first
        });

        // Categorize bookings
        _upcomingBookings = [];
        _ongoingBookings = [];
        _completedBookings = [];
        _canceledBookings = [];

        for (final booking in userBookings) {
          final status = booking.bookingStatus?.toLowerCase() ?? 'pending';
          
          if (status == 'pending') {
            _upcomingBookings.add(booking);
          } else if (status == 'completed') {
            _completedBookings.add(booking);
          } else if (status == 'cancelled') {
            _canceledBookings.add(booking);
          } else {
            // Ongoing is anything that is not pending, completed, or cancelled
            _ongoingBookings.add(booking);
          }
        }
      } else {
        _errorMessage = response['message'] ?? "Failed to fetch bookings";
      }
    } catch (e) {
      _errorMessage = "An unexpected error occurred: $e";
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E1105),
            Color(0xFF1E1105),
            Color.fromARGB(255, 26, 23, 23),
            Color.fromARGB(255, 26, 23, 23),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buidAppBar(context),
        body: Column(
          children: [
            TabBar(
              controller: _tabController,
              dividerColor: Colors.grey.shade800,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              indicator: const _GradientTabIndicator(
                gradient: _tabGradient,
                height: 3.0,
              ),
              unselectedLabelColor: Colors.white38,
              tabs: [
                _GradientTab(
                  text: loc.upcoming,
                  controller: _tabController,
                  index: 0,
                  gradient: _tabGradient,
                ),
                _GradientTab(
                  text: loc.ongoing,
                  controller: _tabController,
                  index: 1,
                  gradient: _tabGradient,
                ),
                _GradientTab(
                  text: loc.completed,
                  controller: _tabController,
                  index: 2,
                  gradient: _tabGradient,
                ),
                _GradientTab(
                  text: loc.cancelled,
                  controller: _tabController,
                  index: 3,
                  gradient: _tabGradient,
                ),
              ],
            ),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE4A46B)))
                : _errorMessage != null
                  ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBookingsList(
                          _upcomingBookings,
                          loc.noUpcomingBookings,
                          loc.onceYouBookItWillAppearHere,
                        ),
                        _buildBookingsList(
                          _ongoingBookings,
                          loc.noOngoingBookings,
                          loc.onceYouBookItWillAppearHere,
                        ),
                        _buildBookingsList(
                          _completedBookings,
                          loc.noCompletedBookings,
                          loc.onceYouBookItWillAppearHere,
                        ),
                        _buildBookingsList(
                          _canceledBookings,
                          loc.noCancelledBookings,
                          loc.onceYouBookItWillAppearHere,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsList(List<BookingModel> bookings, String emptyTitle, String emptySubtitle) {
    if (bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchBookings,
        color: const Color(0xFFE4A46B),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildEmptyState(emptyTitle, emptySubtitle),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBookings,
      color: const Color(0xFFE4A46B),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          return _BookingCard(booking: bookings[index]);
        },
      ),
    );
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
          centerTitle: true,
          title: Text(
            loc.bookings,
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

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF49280B),
                  Color(0xFFE4A46B),
                  Color(0xFF60350F),
                ],
              ).createShader(bounds);
            },
            child: const Icon(
              Icons.calendar_month_outlined,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final arrivalDate = booking.arrival != null ? DateTime.tryParse(booking.arrival!) : null;
    final formattedDate = arrivalDate != null ? DateFormat('dd MMM yyyy, hh:mm a').format(arrivalDate) : 'N/A';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C1F14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.carName ?? 'Car Booking',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(booking.bookingStatus).withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(booking.bookingStatus).withAlpha(100)),
                  ),
                  child: Text(
                    (booking.bookingStatus ?? 'Pending').toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(booking.bookingStatus),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.black26, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildLocationRow(
                  Icons.location_on_outlined,
                  booking.pickupAddress ?? booking.airport ?? 'Pickup Location',
                ),
                const SizedBox(height: 12),
                _buildLocationRow(
                  Icons.flag_outlined,
                  booking.dropOffAddress ?? 'Destination',
                ),
              ],
            ),
          ),
          if (booking.charge != null) ...[
            const Divider(color: Colors.black26, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    'SAR ${booking.charge!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFE4A46B),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String address) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFE4A46B)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    status = status?.toLowerCase();
    switch (status) {
      case 'completed':
      case 'finished':
      case 'payment_completed':
        return Colors.green;
      case 'ongoing':
      case 'started':
      case 'arrived':
      case 'picked_up':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

const Gradient _tabGradient = LinearGradient(
  colors: [Color(0xFF49280B), Color(0xFFE4A46B), Color(0xFF60350F)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class _GradientTabIndicator extends Decoration {
  final double height;
  final Gradient gradient;

  const _GradientTabIndicator({this.height = 3.0, required this.gradient});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _GradientPainter(this, onChanged);
  }
}

class _GradientPainter extends BoxPainter {
  final _GradientTabIndicator decoration;

  _GradientPainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect =
        Offset(
          offset.dx,
          (configuration.size?.height ?? 0) - decoration.height,
        ) &
        Size(configuration.size?.width ?? 0, decoration.height);
    final Paint paint = Paint()
      ..shader = decoration.gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }
}

class _GradientTab extends AnimatedWidget implements PreferredSizeWidget {
  final String text;
  final TabController controller;
  final int index;
  final Gradient gradient;

  _GradientTab({
    required this.text,
    required this.controller,
    required this.index,
    required this.gradient,
  }) : super(listenable: controller.animation!);

  @override
  Widget build(BuildContext context) {
    double animationValue = controller.animation?.value ?? index.toDouble();
    double isSelectedValue =
        1.0 - (animationValue - index).abs().clamp(0.0, 1.0);

    return Tab(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 1.0 - isSelectedValue,
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white38,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          Opacity(
            opacity: isSelectedValue,
            child: ShaderMask(
              shaderCallback: (bounds) => gradient.createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              ),
              blendMode: BlendMode.srcIn,
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(46.0);
}
