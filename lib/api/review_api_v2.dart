import 'package:premium_force_main/api/api_result.dart';
import 'package:premium_force_main/api/v2_client.dart';
import 'package:premium_force_main/models/v2/review_v2.dart';
import 'package:premium_force_main/utils/json_utils.dart';

/// Client for customer reviews and driver ratings (`/api/v2/reviews`).
///
/// A review belongs to a completed booking. The driver is resolved server-side
/// from the booking, so the app never has to send a driver id, and a second
/// review for the same booking is rejected with a displayable message rather
/// than silently overwriting the first.
///
/// Usage:
/// ```dart
/// final result = await ReviewApiV2().submitReview(
///   bookingId: booking.id,
///   rate: 5,
///   reviewText: 'Great driver!',
/// );
/// ```
class ReviewApiV2 extends V2ApiClient {
  static final ReviewApiV2 _instance = ReviewApiV2._internal();
  factory ReviewApiV2() => _instance;

  ReviewApiV2._internal();

  /// Rate a completed booking from 1 to 5 stars, with an optional comment.
  ///
  /// [rate] is clamped to the range the endpoint accepts so a UI bug cannot
  /// turn into a 400. An empty [reviewText] is omitted rather than sent blank.
  Future<ApiResult<ReviewV2>> submitReview({
    required String bookingId,
    required int rate,
    String? reviewText,
  }) {
    final comment = reviewText?.trim();

    return request(
      () => dio.post(
        'reviews',
        data: {
          'bookingID': bookingId,
          'rate': rate.clamp(1, 5),
          if (comment != null && comment.isNotEmpty) 'reviewText': comment,
        },
      ),
      parse: (payload) => ReviewV2.fromJson(asMap(payload)),
    );
  }

  /// Paginated reviews for a driver, with their average rating and review count.
  Future<ApiResult<DriverReviewsPage>> getDriverReviews({
    required String driverId,
    int page = 1,
    int limit = 10,
  }) {
    return request(
      () => dio.get(
        'reviews/driver/$driverId',
        queryParameters: {'page': page, 'limit': limit},
      ),
      parse: (payload) => DriverReviewsPage.fromJson(asMap(payload)),
    );
  }
}
