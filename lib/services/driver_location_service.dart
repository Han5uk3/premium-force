import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Which leg of the journey the map should be drawing.
///
/// The driver app publishes this and switches it as the ride progresses, so the
/// map changes legs the moment the driver does rather than waiting for a
/// booking refresh to report the new status.
enum TrackingPhase {
  /// Driver → pickup: the car coming to fetch the customer.
  toPickup('to_pickup'),

  /// Driver → drop-off: the car carrying them.
  toDropOff('to_dropoff'),

  /// Under way with nowhere to route to — hourly chauffeur hire, which has no
  /// drop-off point because the customer directs the car themselves. The
  /// driver's position is still live; there is simply no route to draw.
  inProgress('in_progress');

  const TrackingPhase(this.wireValue);

  final String wireValue;

  static TrackingPhase fromWire(String? value) {
    final normalised = value?.trim().toLowerCase().replaceAll('-', '_');
    for (final phase in values) {
      if (phase.wireValue == normalised) return phase;
    }
    // Sessions opened by a driver build older than the two-leg split carry no
    // phase; they behaved as the approach leg, so that is what they become.
    return toPickup;
  }

  /// Whether this leg has a destination the map can route to.
  bool get hasDestination => this != inProgress;
}

/// The live tracking session for a booking, as the driver app reports it.
class TrackingSession {
  const TrackingSession({
    required this.isActive,
    this.phase = TrackingPhase.toPickup,
    this.startedAt,
  });

  /// False once the driver ends the ride. The map stops and the tracking card
  /// takes itself away on this alone — it arrives in realtime, whereas the
  /// booking's own status only changes on the next refresh.
  final bool isActive;

  /// The leg being driven.
  final TrackingPhase phase;

  /// When the hire meter started; `null` until the driver starts the trip.
  ///
  /// Not the same as when tracking opened. The driver app begins publishing its
  /// position at `driver_en_route`, while the passenger is still waiting, and
  /// records that separately as `sharingStartTime`. Reading that one here would
  /// run the customer's hire clock through the driver's journey to the pickup.
  final DateTime? startedAt;
}

/// Live driver position for a booking.
///
/// The driver app currently publishes to Firebase Realtime Database, under
/// `bookings/<bookingId>/driver_location`, and the customer app subscribes.
/// **This is the only place that knows that.** When the backend exposes its own
/// tracking stream, [watchLocation] and [watchSession] are the two methods to
/// reimplement — callers already work in terms of [LatLng] and
/// [TrackingSession] and never touch Firebase.
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
  FirebaseDatabase get _database => FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseUrl,
  );

  /// Positions for [bookingId], skipping anything unreadable.
  ///
  /// Errors are logged and swallowed rather than closing the stream, so a
  /// transient database fault does not permanently kill tracking on the screen.
  Stream<LatLng> watchLocation(String bookingId) {
    final path = 'bookings/$bookingId/driver_location';

    return _database
        .ref(path)
        .onValue
        .handleError((Object error) {})
        .map((event) => parsePosition(event.snapshot.value))
        .where((position) => position != null)
        .cast<LatLng>();
  }

  /// The live session for [bookingId] — which leg is being driven, whether it
  /// is still running, and the hire meter.
  Stream<TrackingSession> watchSession(String bookingId) {
    final path = 'bookings/$bookingId/tracking_session';

    return _database
        .ref(path)
        .onValue
        .handleError((Object error) {})
        .map((event) {
          final data = event.snapshot.value;
          if (data is! Map) return null;

          return TrackingSession(
            // Absent means running: the node only exists once the driver has
            // set off.
            isActive: data['isActive'] as bool? ?? true,
            phase: TrackingPhase.fromWire(data['phase']?.toString()),
            startedAt: DateTime.tryParse(data['startTime']?.toString() ?? ''),
          );
        })
        .where((session) => session != null)
        .cast<TrackingSession>();
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
        } catch (error) {}
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
