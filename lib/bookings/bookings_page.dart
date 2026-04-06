import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
// removed unused api import

import 'package:premium_force_main/models/booking_model.dart';

// removed unused UserLocalStorage import

import 'package:premium_force_main/common_widgets/bookingcard.dart';
import 'package:premium_force_main/common_widgets/booking_shimmer.dart';
import 'package:premium_force_main/bookings/booking_details_page.dart';
import 'package:premium_force_main/providers/booking_provider.dart';
import 'package:provider/provider.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // removed unused _apiService


  // removed local booking lists


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<BookingProvider>(context, listen: false).fetchBookings();
      }
    });
  }

  // Removed local _fetchBookings. Using BookingProvider now.


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
      child: Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: buidAppBar(context),
          body: RefreshIndicator(
            onRefresh: bookingProvider.fetchBookings,
            color: const Color(0xFFE4A46B),
            backgroundColor: Colors.black,
            child: Column(
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
                  child: bookingProvider.isLoading
                      ? const BookingShimmer()
                      : bookingProvider.errorMessage != null
                          ? Center(
                              child: Text(
                                bookingProvider.errorMessage!,
                                style: const TextStyle(color: Colors.white),
                              ),
                            )
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildBookingsList(
                                  bookingProvider,
                                  bookingProvider.upcomingBookings,
                                  loc.noUpcomingBookings,
                                  loc.onceYouBookItWillAppearHere,
                                ),
                                _buildBookingsList(
                                  bookingProvider,
                                  bookingProvider.ongoingBookings,
                                  loc.noOngoingBookings,
                                  loc.onceYouBookItWillAppearHere,
                                ),
                                _buildBookingsList(
                                  bookingProvider,
                                  bookingProvider.completedBookings,
                                  loc.noCompletedBookings,
                                  loc.onceYouBookItWillAppearHere,
                                ),
                                _buildBookingsList(
                                  bookingProvider,
                                  bookingProvider.canceledBookings,
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
      },
    ),
    );
  }

  Widget _buildBookingsList(
    BookingProvider bookingProvider,
    List<BookingModel> bookings,
    String emptyTitle,
    String emptySubtitle,
  ) {
    if (bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: bookingProvider.fetchBookings,
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
      onRefresh: bookingProvider.fetchBookings,
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
          final displayDate =
              (booking.pickupdatetime != null &&
                  booking.pickupdatetime!.isNotEmpty)
              ? DateTime.tryParse(booking.pickupdatetime!)
              : (booking.arrival != null
                    ? DateTime.tryParse(booking.arrival!)
                    : null);
          final dateStr = Bookingcard.formatDate(context, displayDate);
          final timeStr = Bookingcard.formatTime(context, displayDate);
          final isChauffeur = booking is HourlyBookingModel;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () async {
                debugPrint('🚗 carData │ ${booking.carData?.toJson()}');
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingDetailsPage(booking: booking),
                  ),
                );
                if (result == true) {
                  bookingProvider.fetchBookings();
                }
              },
              child: Bookingcard(
                isFromReviewAndConfirm: false,
                status: booking.bookingStatus ?? 'Pending',
                type: _getBookingCategoryName(booking, context),
                pickup: booking.pickupAddress ?? booking.airport ?? 'N/A',
                dropoff: booking.dropOffAddress ?? 'N/A',
                date: dateStr,
                time: timeStr,
                ride: booking.displayCategory,
                brand: booking.displayBrand,
                passengers: int.tryParse(booking.passengerCount ?? '1') ?? 1,
                isChauffeur: isChauffeur,
                chauffeurName: booking.displayDriverName,
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
              fontSize: 18,
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
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  String _getBookingCategoryName(BookingModel booking, BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    log(booking.category.toString());
    if (booking is HourlyBookingModel) {
      return loc.chauffeur;
    }

    // Fallback for types if model is not HourlyBookingModel but has category name
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
                fontSize: 11,
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
                  fontSize: 11,
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
