import 'package:flutter/material.dart';
import 'package:premium_force_main/api/booking_api_v2.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';

/// Booking history, backed by `GET /bookings/my-bookings`.
///
/// The v2 endpoint returns one unified, paginated collection — airport,
/// private-transfer and chauffeur bookings all arrive together, so the old
/// two-call merge of regular + hourly endpoints is gone.
///
/// Bookings are fetched once with `status=all` and bucketed on-device via
/// [BookingStatusV2.listBucket]. That keeps all four tabs populated from a
/// single round trip and preserves pull-to-refresh behaviour.
class BookingProvider extends ChangeNotifier {
  BookingProvider({BookingApiV2? api}) : _api = api ?? BookingApiV2();

  final BookingApiV2 _api;

  /// Page size to request; the API caps this at 50.
  static const int _pageSize = 50;

  /// Safety valve so a bad `totalPages` cannot spin forever.
  static const int _maxPages = 10;

  List<BookingV2> _bookings = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<BookingV2> _upcomingBookings = [];
  List<BookingV2> _ongoingBookings = [];
  List<BookingV2> _completedBookings = [];
  List<BookingV2> _canceledBookings = [];
  List<BookingV2> _recentBookings = [];

  List<BookingV2> get bookings => _bookings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<BookingV2> get upcomingBookings => _upcomingBookings;
  List<BookingV2> get ongoingBookings => _ongoingBookings;
  List<BookingV2> get completedBookings => _completedBookings;
  List<BookingV2> get canceledBookings => _canceledBookings;
  List<BookingV2> get recentBookings => _recentBookings;

  /// The booking currently being driven, if any — drives the home tracking card.
  BookingV2? get liveBooking {
    for (final booking in _bookings) {
      if (booking.status.isLive) return booking;
    }
    return null;
  }

  /// Load every booking for the signed-in customer.
  Future<void> fetchBookings() async {
    if (UserLocalStorage.getUserId() == null) {
      _errorMessage = 'User not logged in';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final collected = <BookingV2>[];
      var page = 1;

      while (page <= _maxPages) {
        final result = await _api.getMyBookings(
          status: 'all',
          page: page,
          limit: _pageSize,
        );

        final data = result.data;
        if (data == null) {
          // Fail only if nothing at all was retrieved; a mid-way failure still
          // shows the pages that did load.
          if (collected.isEmpty) {
            _errorMessage = result.message ?? 'Could not load your bookings.';
          }
          break;
        }

        collected.addAll(data.bookings);
        if (!data.hasMore) break;
        page++;
      }

      // Most recent first.
      collected.sort((a, b) {
        final dateA = a.createdAt ?? a.pickupDateTime ?? DateTime(0);
        final dateB = b.createdAt ?? b.pickupDateTime ?? DateTime(0);
        return dateB.compareTo(dateA);
      });

      _bookings = collected;
      _recentBookings = collected.take(3).toList();
      _categorizeBookings(collected);
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      debugPrint('❌ BookingProvider │ Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Split bookings into the four tabs using the status enum's own mapping.
  ///
  /// `pending_payment` drafts are intentionally excluded — they represent a
  /// checkout that never completed and are not shown to the customer.
  void _categorizeBookings(List<BookingV2> source) {
    _upcomingBookings = [];
    _ongoingBookings = [];
    _completedBookings = [];
    _canceledBookings = [];

    for (final booking in source) {
      switch (booking.status.listBucket) {
        case 'upcoming':
          _upcomingBookings.add(booking);
        case 'ongoing':
          _ongoingBookings.add(booking);
        case 'completed':
          _completedBookings.add(booking);
        case 'cancelled':
          _canceledBookings.add(booking);
      }
    }
  }

  /// Replace one booking in place after a detail refresh or a cancellation,
  /// avoiding a full refetch.
  void replaceBooking(BookingV2 updated) {
    final index = _bookings.indexWhere((b) => b.id == updated.id);
    if (index == -1) return;

    _bookings[index] = updated;
    _recentBookings = _bookings.take(3).toList();
    _categorizeBookings(_bookings);
    notifyListeners();
  }
}
