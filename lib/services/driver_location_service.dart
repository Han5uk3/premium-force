import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The chauffeur meter, as the driver app reports it.
class ChauffeurTrackingSession {
  const ChauffeurTrackingSession({required this.isActive, this.startedAt});

  /// False once the driver ends the hire.
  final bool isActive;

  /// When the meter started; `null` until the driver starts the trip.
  final DateTime? startedAt;
}

/// Live driver position for a booking.
///
/// The driver app currently publishes to Firebase Realtime Database, under
/// `bookings/<bookingId>/driver_location`, and the customer app subscribes.
/// **This is the only place that knows that.** When the backend exposes its own
/// tracking stream, [watchLocation] and [watchChauffeurSession] are the two
/// methods to reimplement — callers already work in terms of [LatLng] and
/// [ChauffeurTrackingSession] and never touch Firebase.
///
/// [bookingId] is the booking's Mongo `_id` from the v2 API, so the driver app
/// must key its writes by the same id.
///
/// Usage:
/// ```dart
/// _subscription = DriverLocationService()
///     .watchLocation(booking.id)
///     .listen((position) => setState(() => _driverLocation = position));
/// ```
class DriverLocationService {
  static final DriverLocationService _instance =
      DriverLocationService._internal();
  factory DriverLocationService() => _instance;
  DriverLocationService._internal();

  static const String _databaseUrl =
      'https://premium-force-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Resolved lazily: Firebase has to be initialised before this is touched.
  FirebaseDatabase get _database =>
      FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _databaseUrl);

  /// Positions for [bookingId], skipping anything unreadable.
  ///
  /// Errors are logged and swallowed rather than closing the stream, so a
  /// transient database fault does not permanently kill tracking on the screen.
  Stream<LatLng> watchLocation(String bookingId) {
    final path = 'bookings/$bookingId/driver_location';
    debugPrint('📡 Driver location │ listening at $path');

    return _database
        .ref(path)
        .onValue
        .handleError((Object error) {
          debugPrint('❌ Driver location │ stream error at $path: $error');
        })
        .map((event) => parsePosition(event.snapshot.value))
        .where((position) => position != null)
        .cast<LatLng>();
  }

  /// The chauffeur meter for [bookingId].
  Stream<ChauffeurTrackingSession> watchChauffeurSession(String bookingId) {
    final path = 'bookings/$bookingId/tracking_session';

    return _database
        .ref(path)
        .onValue
        .handleError((Object error) {
          debugPrint('❌ Driver location │ session error at $path: $error');
        })
        .map((event) {
          final data = event.snapshot.value;
          if (data is! Map) return null;

          return ChauffeurTrackingSession(
            // Absent means running: the node only exists once the trip started.
            isActive: data['isActive'] as bool? ?? true,
            startedAt: DateTime.tryParse(
              data['startTime']?.toString() ?? '',
            ),
          );
        })
        .where((session) => session != null)
        .cast<ChauffeurTrackingSession>();
  }

  /// Read a position from whatever the driver app wrote.
  ///
  /// Three shapes have been seen in the wild — a map, a JSON string, and a bare
  /// `"lat,lng"` pair — and the key spellings vary, so all are accepted.
  @visibleForTesting
  static LatLng? parsePosition(dynamic data) {
    if (data == null) return null;

    if (data is Map) return _fromMap(data);

    if (data is String) {
      final trimmed = data.trim();

      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = json.decode(trimmed);
          if (decoded is Map) return _fromMap(decoded);
        } catch (error) {
          debugPrint('⚠️ Driver location │ bad JSON payload: $error');
        }
        return null;
      }

      if (trimmed.contains(',')) {
        final parts = trimmed.split(',');
        if (parts.length >= 2) {
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());
          if (lat != null && lng != null) return LatLng(lat, lng);
        }
      }
    }

    debugPrint('⚠️ Driver location │ unreadable payload: $data');
    return null;
  }

  static LatLng? _fromMap(Map<dynamic, dynamic> data) {
    final lat = _toDouble(data['lat'] ?? data['latitude'] ?? data['Latitude']);
    final lng = _toDouble(
      data['lng'] ??
          data['longitude'] ??
          data['Longitude'] ??
          data['long'] ??
          data['Long'],
    );

    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }
}
