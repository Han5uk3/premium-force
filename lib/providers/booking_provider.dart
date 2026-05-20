import 'package:flutter/material.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/models/booking_model.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';

class BookingProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<BookingModel> _bookings = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<BookingModel> _upcomingBookings = [];
  List<BookingModel> _ongoingBookings = [];
  List<BookingModel> _completedBookings = [];
  List<BookingModel> _canceledBookings = [];
  List<BookingModel> _recentBookings = [];

  List<BookingModel> get bookings => _bookings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<BookingModel> get upcomingBookings => _upcomingBookings;
  List<BookingModel> get ongoingBookings => _ongoingBookings;
  List<BookingModel> get completedBookings => _completedBookings;
  List<BookingModel> get canceledBookings => _canceledBookings;
  List<BookingModel> get recentBookings => _recentBookings;

  Future<void> fetchBookings() async {
    final currentUserId = UserLocalStorage.getUserId();
    if (currentUserId == null) {
      _errorMessage = "User not logged in";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
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
          hourlyBookingsJson.map((json) {
            final model = BookingModel.fromJson(json);
            if (model.bookingType == null || model.bookingType!.isEmpty) {
              return model.copyWith(bookingType: 'hourly');
            }
            return model;
          }),
        );
      }

      // Sort by most recent first
      userBookings.sort((a, b) {
        final dateA = _getBookingDate(a);
        final dateB = _getBookingDate(b);
        return dateB.compareTo(dateA);
      });

      _bookings = userBookings;
      _recentBookings = userBookings.take(3).toList();
      _categorizeBookings(userBookings);
      
    } catch (e) {
      _errorMessage = "An unexpected error occurred: $e";
      debugPrint('❌ BookingProvider │ Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DateTime _getBookingDate(BookingModel booking) {
    return booking.createdAt ??
        (booking.pickupdatetime != null
            ? DateTime.tryParse(booking.pickupdatetime!)
            : null) ??
        DateTime(0);
  }

  void _categorizeBookings(List<BookingModel> userBookings) {
    _upcomingBookings = [];
    _ongoingBookings = [];
    _completedBookings = [];
    _canceledBookings = [];

    for (final booking in userBookings) {
      final status = (booking.bookingStatus ?? '').toLowerCase().trim();

      if (status == 'pending' ||
          status == 'assigned' ||
          status == 'p' ||
          status == 'a') {
        _upcomingBookings.add(booking);
      } else if (status == 'completed' ||
          status == 'reviewed' ||
          status == 'c') {
        _completedBookings.add(booking);
      } else if (status == 'cancelled' ||
          status == 'canceled' ||
          status == 'x') {
        _canceledBookings.add(booking);
      } else {
        _ongoingBookings.add(booking);
      }
    }
  }

  /// Silently update the bookings (e.g. after a status change)
  void updateBookingsLocally(List<BookingModel> updatedList) {
    _bookings = updatedList;
    _recentBookings = updatedList.take(3).toList();
    _categorizeBookings(updatedList);
    notifyListeners();
  }
}
