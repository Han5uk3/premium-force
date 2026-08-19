import 'package:premium_force_main/utils/json_utils.dart';

/// In-app notification models for the v2 notification centre
/// (`GET /notifications`).
///
/// Every notification is stored bilingually by the backend, so the payload
/// carries both an English and an Arabic copy of the title and body; the app
/// picks one at render time via [NotificationV2.displayTitle] rather than
/// asking the server to localise.

/// What a notification is about, which decides its icon and tap target.
enum NotificationTypeV2 {
  bookingStatus('booking_status'),
  tripAssignment('trip_assignment'),
  payment('payment'),
  promotion('promotion'),
  general('general');

  const NotificationTypeV2(this.wireValue);

  /// The exact string the API uses.
  final String wireValue;

  static NotificationTypeV2 fromWire(String? value) {
    final normalised = value?.trim().toLowerCase().replaceAll('-', '_');
    if (normalised == null || normalised.isEmpty) return general;
    for (final type in values) {
      if (type.wireValue == normalised) return type;
    }
    // Tolerate the spellings the backend uses interchangeably.
    return switch (normalised) {
      'booking' || 'booking_update' || 'status' => bookingStatus,
      'trip' || 'ride_assignment' || 'assignment' => tripAssignment,
      'refund' || 'invoice' || 'payment_status' => payment,
      'offer' || 'promo' || 'marketing' => promotion,
      _ => general,
    };
  }
}

/// A single entry in the notification centre.
class NotificationV2 {
  const NotificationV2({
    required this.id,
    required this.title,
    required this.body,
    this.titleAr,
    this.bodyAr,
    this.type = NotificationTypeV2.general,
    this.data = const {},
    this.bookingId,
    this.isRead = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String? titleAr;
  final String? bodyAr;
  final NotificationTypeV2 type;

  /// Free-form payload mirrored from the push message — booking number, pickup
  /// time, and whatever else the sender attached.
  final Map<String, dynamic> data;

  /// The booking this notification refers to, when it refers to one.
  final String? bookingId;

  final bool isRead;
  final DateTime? createdAt;

  factory NotificationV2.fromJson(Map<String, dynamic> json) {
    final data = pickMap(json, const ['data']);

    return NotificationV2(
      id: pickId(json, const ['_id', 'id']) ?? '',
      title: pickString(json, const ['title']) ?? '',
      body: pickString(json, const ['body', 'message']) ?? '',
      titleAr: pickString(json, const ['titleAr']),
      bodyAr: pickString(json, const ['bodyAr', 'messageAr']),
      type: NotificationTypeV2.fromWire(
        pickString(json, const ['type']) ?? pickString(data, const ['type']),
      ),
      data: data,
      // The id sits at the top level on most notifications and inside `data` on
      // those mirrored straight from a push payload.
      bookingId:
          pickId(json, const ['bookingID', 'bookingId', 'booking']) ??
          pickId(data, const ['bookingId', 'bookingID']),
      isRead: pickBool(json, const ['isRead', 'read']) ?? false,
      createdAt: pickDateTime(json, const ['createdAt', 'timestamp']),
    );
  }

  /// The booking number carried alongside the ids, for display.
  String? get bookingNumber => pickString(data, const ['bookingNumber']);

  String displayTitle(bool isArabic) => isArabic
      ? (titleAr?.trim().isNotEmpty == true ? titleAr! : title)
      : title;

  String displayBody(bool isArabic) =>
      isArabic ? (bodyAr?.trim().isNotEmpty == true ? bodyAr! : body) : body;

  NotificationV2 copyWith({bool? isRead}) {
    return NotificationV2(
      id: id,
      title: title,
      body: body,
      titleAr: titleAr,
      bodyAr: bodyAr,
      type: type,
      data: data,
      bookingId: bookingId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

/// One page of the notification centre, plus the account-wide unread count.
///
/// The count spans every notification rather than just this page, so it is what
/// the badge should show.
class NotificationFeedPage {
  const NotificationFeedPage({
    required this.notifications,
    this.unreadCount = 0,
    this.page = 1,
    this.limit = 10,
    this.total = 0,
    this.totalPages = 1,
  });

  final List<NotificationV2> notifications;
  final int unreadCount;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory NotificationFeedPage.fromJson(Map<String, dynamic> json) {
    final meta = pickMap(json, const ['meta', 'pagination']);
    final source = meta.isNotEmpty ? meta : json;

    final page = pickInt(source, const ['page', 'currentPage']) ?? 1;
    final limit = pickInt(source, const ['limit', 'pageSize', 'perPage']) ?? 10;
    final total =
        pickInt(source, const ['totalItems', 'total', 'totalCount']) ?? 0;

    return NotificationFeedPage(
      notifications: pickMapList(json, const [
        'notifications',
        'data',
        'items',
      ]).map(NotificationV2.fromJson).toList(),
      unreadCount: pickInt(json, const ['unreadCount']) ?? 0,
      page: page,
      limit: limit,
      total: total,
      // Derived when the API reports only a total, so paging still advances.
      totalPages:
          pickInt(source, const ['totalPages', 'pages']) ??
          (total > 0 && limit > 0 ? (total + limit - 1) ~/ limit : 1),
    );
  }

  bool get hasMore => page < totalPages;
}
