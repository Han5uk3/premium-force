import 'package:flutter/material.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';

import 'package:premium_force_main/models/v2/booking_service_type.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: BookingTab.values.length,
      vsync: this,
    );
    _tabController.addListener(_loadSelectedTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSelectedTab();
    });
  }

  /// Each tab is its own query, so it is fetched the first time it is shown.
  ///
  /// [BookingProvider.fetchTab] is a no-op for a tab that is already loaded,
  /// which is what makes this safe to call on every tab notification.
  void _loadSelectedTab() {
    if (!mounted) return;
    context.read<BookingProvider>().fetchTab(
      BookingTab.values[_tabController.index],
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_loadSelectedTab);
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
            body: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  dividerColor: Colors.grey.shade800,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                  ),
                  indicator: const _GradientTabIndicator(
                    gradient: _tabGradient,
                    height: 3.0,
                  ),
                  unselectedLabelColor: Colors.white38,
                  tabs: [
                    for (final tab in BookingTab.values)
                      _GradientTab(
                        text: _tabLabel(loc, tab),
                        controller: _tabController,
                        index: tab.index,
                        gradient: _tabGradient,
                      ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      for (final tab in BookingTab.values)
                        _buildBookingsList(bookingProvider, tab, loc),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingsList(
    BookingProvider bookingProvider,
    BookingTab tab,
    AppLocalizations loc,
  ) {
    final bookings = bookingProvider.bookingsFor(tab);

    if (bookings.isEmpty && bookingProvider.isTabLoading(tab)) {
      return const BookingShimmer();
    }

    final error = bookingProvider.tabError(tab);
    if (bookings.isEmpty) {
      return _buildRefreshable(
        bookingProvider,
        tab,
        child: error != null
            ? Center(
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : _buildEmptyState(
                _emptyTitle(loc, tab),
                loc.onceYouBookItWillAppearHere,
              ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => bookingProvider.fetchTab(tab, force: true),
      color: const Color(0xFFE4A46B),
      backgroundColor: Colors.black,
      child: NotificationListener<ScrollNotification>(
        // Ask for the next page slightly before the end so the list keeps
        // flowing; loadMore ignores the call unless there is more to fetch.
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 300) {
            bookingProvider.loadMore(tab);
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.only(
            top: 16,
            bottom: 100,
            left: 16,
            right: 16,
          ),
          itemCount: bookings.length + (bookingProvider.tabHasMore(tab) ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == bookings.length) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFE4A46B),
                    ),
                  ),
                ),
              );
            }

            final booking = bookings[index];
            final displayDate = booking.pickupDateTime;
            final dateStr = Bookingcard.formatDate(context, displayDate);
            final timeStr = Bookingcard.formatTime(context, displayDate);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BookingDetailsPage(bookingId: booking.id),
                    ),
                  );
                  if (result == true) {
                    // A cancellation moves the booking to another tab, so every
                    // cached tab is dropped and this one reloaded.
                    bookingProvider.invalidateTabs();
                    bookingProvider.fetchTab(tab);
                  }
                },
                child: Bookingcard(
                  isFromReviewAndConfirm: false,
                  status: booking.status.wireValue,
                  type: _getBookingCategoryName(booking, context),
                  pickup: booking.pickupAddress ?? 'N/A',
                  dropoff: booking.dropOffAddress ?? 'N/A',
                  date: dateStr,
                  time: timeStr,
                  ride: booking.vehicleLabel,
                  brand: booking.vehicle?.name ?? '',
                  passengers: booking.passengersCount,
                  isChauffeur: booking.isChauffeur,
                  chauffeurName: booking.driver?.name,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Empty and error states still need to be pullable to refresh.
  Widget _buildRefreshable(
    BookingProvider bookingProvider,
    BookingTab tab, {
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: () => bookingProvider.fetchTab(tab, force: true),
      color: const Color(0xFFE4A46B),
      backgroundColor: Colors.black,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: child,
        ),
      ),
    );
  }

  String _tabLabel(AppLocalizations loc, BookingTab tab) => switch (tab) {
    BookingTab.upcoming => loc.upcoming,
    BookingTab.ongoing => loc.ongoing,
    BookingTab.completed => loc.completed,
    BookingTab.cancelled => loc.cancelled,
  };

  String _emptyTitle(AppLocalizations loc, BookingTab tab) => switch (tab) {
    BookingTab.upcoming => loc.noUpcomingBookings,
    BookingTab.ongoing => loc.noOngoingBookings,
    BookingTab.completed => loc.noCompletedBookings,
    BookingTab.cancelled => loc.noCancelledBookings,
  };

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

  /// Localised product name for the card header.
  String _getBookingCategoryName(BookingV2 booking, BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return switch (booking.resolvedServiceType) {
      BookingServiceType.airportArrival => loc.airportArrival,
      BookingServiceType.airportDeparture => loc.airportDeparture,
      BookingServiceType.chauffeur => loc.chauffeur,
      BookingServiceType.privateTransfer => loc.privateTransfer,
      // An unrecognised serviceType still has the duration to fall back on.
      null => booking.isChauffeur ? loc.chauffeur : loc.unknown,
    };
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
