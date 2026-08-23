import 'package:flutter/material.dart';
import 'package:premium_force_main/api/booking_api_v2.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';

/// One tab's paginated slice of `GET /bookings/my-bookings`.
class _TabState {
  List<BookingV2> bookings = [];

  /// Highest page loaded; `0` means the tab has never been fetched.
  int page = 0;
  int totalPages = 1;

  bool isLoading = false;
  bool isLoadingMore = false;

  /// Only shown when the tab has nothing to display — a failure while paging
  /// leaves the rows already on screen alone.
  String? error;

  bool get isLoaded => page > 0;
  bool get hasMore => page > 0 && page < totalPages;

  void reset() {
    bookings = [];
    page = 0;
    totalPages = 1;
    error = null;
  }
}

/// Booking history, backed by `GET /bookings/my-bookings`.
///
/// Each tab is its own paginated query, keyed by [BookingTab.wireValue], and is
/// fetched the first time it is shown. The backend decides which booking
/// belongs in which tab; nothing is bucketed on-device.
///
/// The home screen is separate: [fetchBookings] asks for every status at once
/// and keeps only what that screen needs — the recent list and the live ride.
class BookingProvider extends ChangeNotifier {
  BookingProvider({BookingApiV2? api}) : _api = api ?? BookingApiV2();

  final BookingApiV2 _api;

  /// Rows per page for the tabs. The API caps this at 50.
  static const int _tabPageSize = 10;

  /// The home screen takes one page; it only shows the three most recent.
  static const int _homePageSize = 50;

  static const String _notLoggedIn = 'User not logged in';
  static const String _loadFailed = 'Could not load your bookings.';

  final Map<BookingTab, _TabState> _tabs = {
    for (final tab in BookingTab.values) tab: _TabState(),
  };

  List<BookingV2> _bookings = [];
  List<BookingV2> _recentBookings = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ── Home screen ──────────────────────────────────────────────────────────

  List<BookingV2> get bookings => _bookings;
  List<BookingV2> get recentBookings => _recentBookings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// The booking whose driver can be watched right now, if any — drives the
  /// home tracking card.
  ///
  /// Null until the driver starts the ride: before that there is no position
  /// being published, so the card would offer a map with nothing on it.
  BookingV2? get trackableBooking {
    for (final booking in _bookings) {
      if (booking.status.isTrackable) return booking;
    }
    return null;
  }

  // ── Tabs ─────────────────────────────────────────────────────────────────

  List<BookingV2> bookingsFor(BookingTab tab) => _tabs[tab]!.bookings;
  bool isTabLoading(BookingTab tab) => _tabs[tab]!.isLoading;
  bool tabHasMore(BookingTab tab) => _tabs[tab]!.hasMore;
  String? tabError(BookingTab tab) => _tabs[tab]!.error;

  /// Load a tab's first page.
  ///
  /// Idempotent unless [force]: calling it again for a tab that is already
  /// loaded does nothing, so it is safe to call on every tab change.
  Future<void> fetchTab(BookingTab tab, {bool force = false}) async {
    final state = _tabs[tab]!;
    if (state.isLoading) return;
    if (state.isLoaded && !force) return;

    if (UserLocalStorage.getUserId() == null) {
      state.error = _notLoggedIn;
      notifyListeners();
      return;
    }

    state.isLoading = true;
    state.error = null;
    notifyListeners();

    try {
      final result = await _api.getMyBookings(
        tab: tab,
        page: 1,
        limit: _tabPageSize,
      );

      final data = result.data;
      if (data == null) {
        state.error = result.message ?? _loadFailed;
      } else {
        state.bookings = data.bookings;
        // A page of 0 would leave the tab looking unfetched forever.
        state.page = data.page > 0 ? data.page : 1;
        state.totalPages = data.totalPages;
        state.error = null;
      }
    } catch (e) {
      state.error = 'An unexpected error occurred: $e';
      debugPrint('❌ BookingProvider │ ${tab.wireValue} failed: $e');
    } finally {
      state.isLoading = false;
      notifyListeners();
    }
  }

  /// Append the next page of [tab], if there is one.
  Future<void> loadMore(BookingTab tab) async {
    final state = _tabs[tab]!;
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state.isLoadingMore = true;
    notifyListeners();

    final nextPage = state.page + 1;

    try {
      final result = await _api.getMyBookings(
        tab: tab,
        page: nextPage,
        limit: _tabPageSize,
      );

      final data = result.data;
      if (data != null) {
        // A booking added between page loads shifts rows across page
        // boundaries, so anything already held is skipped rather than repeated.
        final seen = state.bookings.map((b) => b.id).toSet();
        state.bookings = [
          ...state.bookings,
          ...data.bookings.where((b) => !seen.contains(b.id)),
        ];
        state.page = nextPage;
        state.totalPages = data.totalPages;
      }
      // On failure the page counter stays put, so scrolling on retries it
      // without disturbing the rows already shown.
    } catch (e) {
      debugPrint('❌ BookingProvider │ ${tab.wireValue} page $nextPage: $e');
    } finally {
      state.isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Re-read every list this provider holds: the home screen's recent
  /// bookings, and each tab that has already been fetched.
  ///
  /// Called when a booking is created. [fetchTab] is deliberately a no-op for
  /// a tab it has already loaded — that is what makes it safe to call on every
  /// tab change — so a newly-made booking would otherwise stay invisible until
  /// the customer pulled to refresh. Refreshing in place rather than through
  /// [invalidateTabs] keeps the rows that are already on screen: nothing is
  /// cleared, each list is simply replaced when its page arrives.
  ///
  /// Tabs never opened are skipped; they fetch on their own the first time
  /// they are shown.
  Future<void> refreshBookings() async {
    await Future.wait([
      fetchBookings(),
      for (final entry in _tabs.entries)
        if (entry.value.isLoaded) fetchTab(entry.key, force: true),
    ]);
  }

  /// Drop every tab's cache so each refetches when next shown.
  ///
  /// Used after a change that can move a booking between tabs — a cancellation
  /// leaves both the tab it left and the tab it joined out of date.
  void invalidateTabs() {
    for (final state in _tabs.values) {
      state.reset();
    }
    notifyListeners();
  }

  // ── Home screen ──────────────────────────────────────────────────────────

  /// Load the most recent bookings across every status, for the home screen.
  Future<void> fetchBookings() async {
    if (UserLocalStorage.getUserId() == null) {
      _errorMessage = _notLoggedIn;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.getMyBookings(page: 1, limit: _homePageSize);
      final data = result.data;

      if (data == null) {
        _errorMessage = result.message ?? _loadFailed;
      } else {
        // Most recent first — the home list shows only the top few.
        final collected = [...data.bookings]
          ..sort((a, b) {
            final dateA = a.createdAt ?? a.pickupDateTime ?? DateTime(0);
            final dateB = b.createdAt ?? b.pickupDateTime ?? DateTime(0);
            return dateB.compareTo(dateA);
          });

        _bookings = collected;
        _recentBookings = collected.take(3).toList();
      }
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      debugPrint('❌ BookingProvider │ Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
