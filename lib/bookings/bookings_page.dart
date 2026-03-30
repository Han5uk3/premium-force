import 'package:flutter/material.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/models/booking_model.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/common_widgets/bookingcard.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/bookings/booking_details_page.dart';

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

      // Fetch regular bookings and hourly bookings in parallel
      final results = await Future.wait([
        _apiService.getBookingsByCustomerId(
          customerId: currentUserId,
          token: token,
        ),
        _apiService.getHourlyBookingsByCustomerId(
          customerId: currentUserId,
          token: token,
        ),
      ]);

      final regularResponse = results[0];
      final hourlyResponse = results[1];

      List<BookingModel> userBookings = [];

      if (regularResponse['success'] == true) {
        final List<dynamic> bookingsJson =
            regularResponse['data'] ?? regularResponse['bookings'] ?? [];
        userBookings.addAll(
          bookingsJson.map((json) => BookingModel.fromJson(json)),
        );
      }

      if (hourlyResponse['success'] == true) {
        final List<dynamic> hourlyBookingsJson =
            hourlyResponse['data'] ?? hourlyResponse['bookings'] ?? [];
        userBookings.addAll(
          hourlyBookingsJson.map((json) => BookingModel.fromJson(json)),
        );
      }

      if (userBookings.isEmpty &&
          regularResponse['success'] != true &&
          hourlyResponse['success'] != true) {
        _errorMessage =
            regularResponse['message'] ??
            hourlyResponse['message'] ??
            "Failed to fetch bookings";
      }

      // Sort by most recent (createdAt or arrival)
      userBookings.sort((a, b) {
        final dateA =
            a.createdAt ??
            (a.pickupdatetime != null ? DateTime.tryParse(a.pickupdatetime!) : null) ??
            (a.arrival != null ? DateTime.tryParse(a.arrival!) : null) ??
            DateTime(0);
        final dateB =
            b.createdAt ??
            (b.pickupdatetime != null ? DateTime.tryParse(b.pickupdatetime!) : null) ??
            (b.arrival != null ? DateTime.tryParse(b.arrival!) : null) ??
            DateTime(0);
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
                  ? const Center(child: PremiumLoader(color: Color(0xFFE4A46B)))
                  : _errorMessage != null
                  ? Center(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
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

  Widget _buildBookingsList(
    List<BookingModel> bookings,
    String emptyTitle,
    String emptySubtitle,
  ) {
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
        padding: const EdgeInsets.only(
          top: 16,
          bottom: 100,
          left: 16,
          right: 16,
        ),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          final displayDate = (booking.pickupdatetime != null && booking.pickupdatetime!.isNotEmpty)
              ? DateTime.tryParse(booking.pickupdatetime!)
              : (booking.arrival != null ? DateTime.tryParse(booking.arrival!) : null);
          final dateStr = Bookingcard.formatDate(context, displayDate);
          final timeStr = Bookingcard.formatTime(context, displayDate);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingDetailsPage(booking: booking),
                  ),
                );
                if (result == true) {
                  _fetchBookings();
                }
              },
              child: Bookingcard(
                isFromReviewAndConfirm: false,
                status: booking.bookingStatus ?? 'Pending',
                type: _getBookingName(booking.category, context),
                pickup: booking.pickupAddress ?? booking.airport ?? 'N/A',
                dropoff: booking.dropOffAddress ?? 'N/A',
                date: dateStr,
                time: timeStr,
                ride: booking.displayName,
                brand: booking.displayBrand,
                passengers: int.tryParse(booking.passengerCount ?? '1') ?? 1,
                isChauffeur:
                    (booking.category ?? '').toLowerCase().contains(
                      'chauffeur',
                    ) ||
                    booking.estimatedHours != null,
              ),
            ),
          );
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

  String _getBookingName(String? category, BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (category == null) return 'Booking';
    switch (category.toLowerCase()) {
      case 'chauffeur':
        return loc.chauffeur;
      case 'airport arrival':
        return loc.airportArrival;
      case 'airport departure':
        return loc.airportDeparture;

      default:
        return 'invalid';
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
