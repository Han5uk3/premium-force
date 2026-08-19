import 'package:premium_force_main/utils/json_utils.dart';

/// Review models for `POST /reviews` and `GET /reviews/driver/:driverId`.
///
/// A review is one star rating (1–5) plus an optional comment, tied to a
/// completed booking. The backend recalculates the driver's average on submit
/// and rejects a second review for the same booking, so the app treats a
/// successful submit as final.

/// A submitted review.
class ReviewV2 {
  const ReviewV2({
    required this.id,
    required this.rate,
    this.bookingId,
    this.driverId,
    this.customerId,
    this.reviewText,
    this.customerName,
    this.bookingNumber,
    this.createdAt,
  });

  final String id;

  /// Star rating, 1–5.
  final int rate;

  final String? bookingId;
  final String? driverId;
  final String? customerId;
  final String? reviewText;

  /// Present on the driver-reviews listing, absent on the submit response.
  final String? customerName;
  final String? bookingNumber;

  final DateTime? createdAt;

  factory ReviewV2.fromJson(Map<String, dynamic> json) {
    return ReviewV2(
      id: pickId(json, const ['_id', 'id']) ?? '',
      rate: pickInt(json, const ['rate', 'rating']) ?? 0,
      bookingId: pickId(json, const ['bookingID', 'bookingId']),
      driverId: pickId(json, const ['driverID', 'driverId']),
      customerId: pickId(json, const ['customerID', 'customerId']),
      reviewText: pickString(json, const ['reviewText', 'review', 'comment']),
      customerName: pickString(json, const ['customerName']),
      bookingNumber: pickString(json, const ['bookingNumber']),
      createdAt: pickDateTime(json, const ['createdAt']),
    );
  }
}

/// The driver's aggregate rating, recalculated server-side on every submit.
class DriverRatingSummary {
  const DriverRatingSummary({this.averageRating = 0, this.totalReviews = 0});

  final double averageRating;
  final int totalReviews;

  factory DriverRatingSummary.fromJson(Map<String, dynamic> json) {
    return DriverRatingSummary(
      averageRating: pickDouble(json, const ['averageRating', 'average']) ?? 0,
      totalReviews: pickInt(json, const ['totalReviews', 'count']) ?? 0,
    );
  }
}

/// One page of a driver's reviews, alongside their rating summary.
class DriverReviewsPage {
  const DriverReviewsPage({
    required this.reviews,
    this.summary = const DriverRatingSummary(),
    this.page = 1,
    this.limit = 10,
    this.total = 0,
    this.totalPages = 1,
  });

  final List<ReviewV2> reviews;
  final DriverRatingSummary summary;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory DriverReviewsPage.fromJson(Map<String, dynamic> json) {
    final meta = pickMap(json, const ['meta', 'pagination']);
    final source = meta.isNotEmpty ? meta : json;

    final page = pickInt(source, const ['page', 'currentPage']) ?? 1;
    final limit = pickInt(source, const ['limit', 'pageSize', 'perPage']) ?? 10;
    final total =
        pickInt(source, const ['totalItems', 'total', 'totalCount']) ?? 0;

    return DriverReviewsPage(
      reviews: pickMapList(json, const [
        'reviews',
        'data',
        'items',
      ]).map(ReviewV2.fromJson).toList(),
      summary: DriverRatingSummary.fromJson(pickMap(json, const ['summary'])),
      page: page,
      limit: limit,
      total: total,
      totalPages:
          pickInt(source, const ['totalPages', 'pages']) ??
          (total > 0 && limit > 0 ? (total + limit - 1) ~/ limit : 1),
    );
  }

  bool get hasMore => page < totalPages;
}
