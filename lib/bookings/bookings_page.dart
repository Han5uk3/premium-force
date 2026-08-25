import 'package:flutter/material.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';

import 'package:premium_force_main/models/v2/booking_service_type.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';

import 'package:premium_force_main/common_widgets/bookingcard.dart';
import 'package:premium_force_main/common_widgets/booking_shimmer.dart';
import 'package:premium_force_main/bookings/booking_details_page.dart';
import 'package:premium_force_main/providers/booking_provider.dart';
import 'package:premium_force_main/theme/app_palette.dart';
import 'package:premium_force_main/utils/date_display.dart';
import 'package:premium_force_main/utils/screen_logger.dart';
import 'package:provider/provider.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key, this.isVisible = true});

  /// Whether this page is the one the shell is currently showing.
  ///
  /// [Home] keeps all three tabs alive in a `PageView`, so this page is not
  /// rebuilt from scratch when the customer comes back to it — without being
  /// told, it would go on showing whatever it last fetched.
  final bool isVisible;

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Console tag prefixing this screen's log lines.
  static const String _log = 'bookings';

  /// Last state line logged per tab, so [_buildBookingsList] — which runs on
  /// every frame — logs only when what it is showing actually changed.
  final Map<BookingTab, String> _loggedTabState = {};

  /// Pickup lines already logged, keyed by booking and resolved value. The item
  /// builder re-runs on every scroll, so without this each row would log again
  /// every time it came back into view. Cleared on a refetch, so a pickup that
  /// changed is logged afresh.
  final Set<String> _loggedPickups = {};

  /// Row count at which a paging request was last logged, per tab — see
  /// [_logLoadMore].
  final Map<BookingTab, int> _loggedLoadMoreAt = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: BookingTab.values.length,
      vsync: this,
    );
    _tabController.addListener(_loadSelectedTab);

    // Built alongside the other shell tabs, so the first fetch waits until this
    // one is actually on screen — otherwise every launch pays for a list the
    // customer may never open. `didUpdateWidget` picks it up from there.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isVisible) _loadSelectedTab(trigger: 'first-show');
    });
  }

  /// Re-read the selected tab from the server.
  ///
  /// Forced every time rather than left to [BookingProvider.fetchTab]'s own
  /// "already loaded" shortcut: a booking's status changes outside the app —
  /// a driver is assigned, a ride completes — so a cached tab is stale the
  /// moment it leaves the screen. The rows already shown stay up while the
  /// refresh is in flight, so this reads as an update rather than a reload.
  ///
  /// [trigger] only names the cause in the log — the fetch itself is the same
  /// whichever entry point called it.
  void _loadSelectedTab({String trigger = 'tab-change'}) {
    if (!mounted) return;

    // The controller notifies twice for one change: once as the animation
    // starts and again when it settles. Only the settled index is fetched.
    if (_tabController.indexIsChanging) return;

    final tab = BookingTab.values[_tabController.index];
    logScreen(_log, 'fetch ${tab.name} (force, $trigger)');

    _resetRowLogs(tab);
    context.read<BookingProvider>().fetchTab(tab, force: true);
  }

  @override
  void didUpdateWidget(BookingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Brought back on screen from another shell tab.
    if (!oldWidget.isVisible && widget.isVisible) {
      _loadSelectedTab(trigger: 'became-visible');
    }
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
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: c.pageGradient,
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
                  dividerColor: c.divider,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                  ),
                  indicator: _GradientTabIndicator(
                    gradient: _tabGradient(c),
                    height: 3.0,
                  ),
                  unselectedLabelColor: c.textTertiary,
                  tabs: [
                    for (final tab in BookingTab.values)
                      _GradientTab(
                        text: _tabLabel(loc, tab),
                        controller: _tabController,
                        index: tab.index,
                        gradient: _tabGradient(c),
                        unselectedColor: c.textTertiary,
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
    final c = context.colors;
    final bookings = bookingProvider.bookingsFor(tab);
    _logTabState(bookingProvider, tab, bookings);

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
                  style: TextStyle(color: c.textPrimary),
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
      color: c.accent,
      backgroundColor: c.surface,
      child: NotificationListener<ScrollNotification>(
        // Ask for the next page slightly before the end so the list keeps
        // flowing; loadMore ignores the call unless there is more to fetch.
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 300) {
            _logLoadMore(bookingProvider, tab, bookings.length);
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
              return Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.accent,
                    ),
                  ),
                ),
              );
            }

            final booking = bookings[index];
            final pickup = formatPickupDisplay(context, [booking.route]);
            _logRow(tab, index, booking, pickup);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () async {
                  logScreen(
                    _log,
                    'open details ${bookingRef(booking)} from ${tab.name}',
                  );
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BookingDetailsPage(bookingId: booking.id),
                    ),
                  );
                  if (!context.mounted) return;

                  logScreen(
                    _log,
                    'back from details, changed=${result == true} — '
                    'refetching ${tab.name}',
                  );

                  // A cancellation moves the booking to another tab, so the
                  // others are dropped as well and refetch when next shown.
                  if (result == true) bookingProvider.invalidateTabs();

                  // The booking may have changed even without a cancellation,
                  // so this tab is re-read either way.
                  _resetRowLogs(tab);
                  bookingProvider.fetchTab(tab, force: true);
                },
                child: Bookingcard(
                  isFromReviewAndConfirm: false,
                  status: booking.status,
                  type: _getBookingCategoryName(booking, context),
                  pickup: booking.pickupAddress ?? 'N/A',
                  dropoff: booking.dropOffAddress ?? 'N/A',
                  date: pickup.date,
                  time: pickup.time,
                  ride: booking.vehicleLabel,
                  brand: booking.vehicle?.name ?? '',
                  passengers: booking.passengersCount,
                  isChauffeur: booking.isChauffeur,
                  chauffeurName: booking.driver?.name,
                  cancellationNote: booking.cancellationNote,
                  bookingNumber: booking.bookingNumber,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Forget what has been logged for one tab's rows, so a refetch logs them
  /// again — the same booking may come back with a different status or pickup,
  /// and that is exactly what a refetch is being watched for.
  void _resetRowLogs(BookingTab tab) {
    _loggedPickups.removeWhere((key) => key.startsWith('${tab.name}|'));
    _loggedLoadMoreAt.remove(tab);
  }

  /// Log a paging request, once per page rather than once per scroll frame.
  ///
  /// The scroll handler calls [BookingProvider.loadMore] on every notification
  /// near the end of the list and lets the provider drop the ones it cannot
  /// serve, so the row count at the time of the call is what makes a request
  /// distinct: it changes only when a page actually arrived.
  void _logLoadMore(
    BookingProvider bookingProvider,
    BookingTab tab,
    int rows,
  ) {
    if (!bookingProvider.tabHasMore(tab)) return;
    if (_loggedLoadMoreAt[tab] == rows) return;
    _loggedLoadMoreAt[tab] = rows;
    logScreen(_log, 'load more ${tab.name} after $rows rows');
  }

  /// Log one row of the list: the booking itself, and the pickup date and time
  /// the card will show with the field they came from.
  ///
  /// Called from the item builder, so it is keyed on booking and resolved
  /// value: a row scrolling back into view logs nothing, but a row whose
  /// pickup resolved differently after a refetch logs again.
  void _logRow(
    BookingTab tab,
    int index,
    BookingV2 booking,
    ({String date, String time}) pickup,
  ) {
    final key = '${tab.name}|${booking.id}|${pickup.date}|${pickup.time}';
    if (!_loggedPickups.add(key)) return;

    logScreen(_log, '${tab.name}[$index] ${bookingSummary(booking)}');
    logPickupDisplay(_log, booking, date: pickup.date, time: pickup.time);
  }

  /// Log which of the four states a tab is rendering, once per change.
  ///
  /// Called from the build path, so it compares against the last line emitted
  /// for this tab — a tab that is simply on screen and idle logs nothing, while
  /// the shimmer → rows → error transitions each show up exactly once.
  void _logTabState(
    BookingProvider bookingProvider,
    BookingTab tab,
    List<BookingV2> bookings,
  ) {
    final error = bookingProvider.tabError(tab);
    final state =
        'rows=${bookings.length} '
        'loading=${bookingProvider.isTabLoading(tab)} '
        'hasMore=${bookingProvider.tabHasMore(tab)} '
        'error=${error ?? '-'}';

    if (_loggedTabState[tab] == state) return;
    _loggedTabState[tab] = state;
    logScreen(_log, '${tab.name}: $state');
  }

  /// Empty and error states still need to be pullable to refresh.
  Widget _buildRefreshable(
    BookingProvider bookingProvider,
    BookingTab tab, {
    required Widget child,
  }) {
    final c = context.colors;
    return RefreshIndicator(
      onRefresh: () => bookingProvider.fetchTab(tab, force: true),
      color: c.accent,
      backgroundColor: c.surface,
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
    final c = context.colors;
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: c.appBarScrim,
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            loc.bookings,
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

  Widget _buildEmptyState(String title, String subtitle) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: c.goldIconGradient,
              ).createShader(bounds);
            },
            // White because [ShaderMask] defaults to `BlendMode.modulate`,
            // which multiplies the child by the shader — white lets the ramp
            // through untouched.
            child: const Icon(
              Icons.calendar_month_outlined,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
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
      BookingServiceType.chauffeur => loc.chauffeurService,
      BookingServiceType.privateTransfer => loc.privateTransfer,
      // An unrecognised serviceType still has the duration to fall back on.
      null => booking.isChauffeur ? loc.chauffeurService : loc.unknown,
    };
  }
}

/// The gold the selected tab's label and its underline are painted with.
///
/// A function of the palette rather than a constant: the ramp that reads on
/// black is not the one that reads on ivory.
Gradient _tabGradient(AppPalette c) => LinearGradient(
  colors: c.goldIconGradient,
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

  /// The label colour while this tab is not the selected one.
  final Color unselectedColor;

  _GradientTab({
    required this.text,
    required this.controller,
    required this.index,
    required this.gradient,
    required this.unselectedColor,
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
              style: TextStyle(
                fontSize: 11,
                color: unselectedColor,
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
              // srcIn here, so the label's own colour is discarded entirely
              // and replaced by the gradient — only its alpha survives.
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
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
