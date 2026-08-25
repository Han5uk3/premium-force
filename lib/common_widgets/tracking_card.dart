import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/bookings/driver_tracking_page.dart';
import 'package:premium_force_main/services/address_geocoding_service.dart';
import 'package:premium_force_main/services/driver_location_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TrackingCard extends StatefulWidget {
  final BookingV2 booking;

  const TrackingCard({super.key, required this.booking});

  @override
  State<TrackingCard> createState() => _TrackingCardState();
}

class _TrackingCardState extends State<TrackingCard> {
  StreamSubscription? _locationSubscription;
  StreamSubscription? _sessionSubscription;
  LatLng? _driverLocation;
  LatLng? _lastFetchLocation;
  String _currentEta = '';
  String _currentDistance = '';

  /// The leg being driven, which decides what the ETA counts down to.
  TrackingPhase _phase = TrackingPhase.toPickup;

  /// Set when the driver ends the ride, at which point the card takes itself
  /// away.
  ///
  /// The booking's own status says the same thing, but only after the next
  /// refresh; this arrives the moment the driver taps complete, so the card
  /// does not sit on the home screen offering to track a finished ride.
  bool _tripEnded = false;

  /// Ends of the journey recovered from their address text, for a booking that
  /// arrived with `0,0` where the coordinate should have been. Without them
  /// the card has nothing to route to and shows no ETA at all.
  LatLng? _geocodedPickup;
  LatLng? _geocodedDropOff;

  @override
  void initState() {
    super.initState();
    _listenToDriverLocation();
    _listenToSession();
    _resolveMissingEndpoints();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }

  void _listenToSession() {
    _sessionSubscription = DriverLocationService()
        .watchSession(widget.booking.id)
        .listen((session) {
          if (!mounted) return;

          if (session.phase != _phase) {
            setState(() => _phase = session.phase);
            // The destination moved; re-route without waiting for the car to
            // travel another 100m.
            _lastFetchLocation = null;
            _fetchDirections();
          }

          if (!session.isActive && !_tripEnded) {
            _locationSubscription?.cancel();
            _locationSubscription = null;
            setState(() => _tripEnded = true);
          }
        });
  }

  void _listenToDriverLocation() {
    _locationSubscription = DriverLocationService()
        .watchLocation(widget.booking.id)
        .listen((position) {
          if (mounted) setState(() => _driverLocation = position);

          // Re-route only after real movement, so a stationary driver does not
          // burn Directions quota on every heartbeat.
          if (_lastFetchLocation == null ||
              Geolocator.distanceBetween(
                    _lastFetchLocation!.latitude,
                    _lastFetchLocation!.longitude,
                    position.latitude,
                    position.longitude,
                  ) >
                  100) {
            _lastFetchLocation = position;
            _fetchDirections();
          }
        });
  }

  /// Distance and ETA for the leg being driven — the car to the pickup, or the
  /// car to the drop-off, never both at once.
  Future<void> _fetchDirections() async {
    final destination = _legDestination();
    // Hourly hire once under way has nowhere to route to.
    if (destination == null || _driverLocation == null || _tripEnded) return;

    final origin =
        '${_driverLocation!.latitude},${_driverLocation!.longitude}';

    final apiKey =
        dotenv.env['GOOGLE_MAPS_API_KEY'] ?? dotenv.env['MAPS_API_KEY'] ?? '';
    if (apiKey.isEmpty) return;

    try {
      final url =
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$origin&destination=$destination&key=$apiKey';
      final response = await Dio().get(
        url,
        options: Options(
          connectTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final routes = response.data['routes'] as List;
        if (routes.isNotEmpty) {
          // One leg requested, one leg summed.
          final legs = routes.first['legs'] as List;
          int dist = 0, dur = 0;
          for (final leg in legs) {
            dist += (leg['distance']['value'] as num).toInt();
            dur += (leg['duration']['value'] as num).toInt();
          }

          if (mounted) {
            setState(() {
              _currentDistance = '${(dist / 1000).toStringAsFixed(1)} km';
              final int mins = (dur / 60).round();
              _currentEta = mins > 60
                  ? '${mins ~/ 60} hr ${mins % 60} min'
                  : '$mins min';
            });
          }
        }
      }
    } catch (_) {}
  }

  /// Where the current leg is headed, or null when there is nowhere to route
  /// to.
  String? _legDestination() {
    final point = _phase == TrackingPhase.toDropOff
        ? _dropOffPoint
        : (_phase.hasDestination ? _pickupPoint : null);

    return point == null ? null : '${point.latitude},${point.longitude}';
  }

  /// Where the pickup is, or null while it is still unknown. The payload's
  /// coordinate wins; `0,0` is not a place, so it falls through to whatever
  /// [_resolveMissingEndpoints] recovered from the address text.
  LatLng? get _pickupPoint =>
      _usable(widget.booking.pickupLat, widget.booking.pickupLng) ??
      _geocodedPickup;

  /// Where the drop-off is, or null while it is still unknown. Always null for
  /// hourly hire, which has no drop-off to know.
  LatLng? get _dropOffPoint =>
      _usable(widget.booking.dropOffLat, widget.booking.dropOffLng) ??
      _geocodedDropOff;

  /// A coordinate pair as a point, unless it is absent or `0,0`.
  static LatLng? _usable(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }

  /// Recover the ends of the journey the payload positioned at `0,0`, from the
  /// addresses it did carry, and put the ETA back on the card once one lands.
  ///
  /// The lookups are shared with the tracking map through
  /// [AddressGeocodingService]'s cache, so opening the map from this card
  /// costs nothing again.
  Future<void> _resolveMissingEndpoints() async {
    final booking = widget.booking;
    final geocoder = AddressGeocodingService();

    if (_pickupPoint == null) {
      final resolved = await geocoder.resolve(booking.pickupAddress);
      if (!mounted) return;
      if (resolved != null) {
        setState(() => _geocodedPickup = resolved);
        // Only the leg being driven has an ETA to put back; the other end is
        // held until its leg comes round.
        if (_phase != TrackingPhase.toDropOff) _fetchDirections();
      }
    }

    if (_dropOffPoint == null) {
      final resolved = await geocoder.resolve(booking.dropOffAddress);
      if (!mounted) return;
      if (resolved != null) {
        setState(() => _geocodedDropOff = resolved);
        if (_phase == TrackingPhase.toDropOff) _fetchDirections();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final booking = widget.booking;

    // The ride is over: nothing left to track, so nothing left to show.
    if (_tripEnded) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE4A46B), Color(0xFF60350F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE4A46B).withAlpha(40),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // The booking's own reference, in place of a status
                        // word: the card only ever appears for a ride under
                        // way, so "ongoing" told the customer what its
                        // presence already had. Forced left-to-right — it is
                        // Latin text and digits, and inherits the Arabic
                        // direction of the layout otherwise, which reverses it.
                        booking.bookingNumber.trim().isEmpty
                            ? loc.ongoing.toUpperCase()
                            : Bidi.enforceLtrInText(
                                booking.bookingNumber.trim(),
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE4A46B),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.vehicleLabel.isNotEmpty
                            ? booking.vehicleLabel
                            : "Premium Ride",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_currentEta.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              color: Colors.white70,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _currentEta,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.location_on_outlined,
                              color: Colors.white70,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _currentDistance,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        loc.tracking.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: Colors.white10, height: 1),
            ),
            Row(
              // Top-aligned, so the PICKUP and DROPOFF labels stay level when
              // one address wraps to two lines and the other does not.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.pickup.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withAlpha(100),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.pickupAddress ?? "Pickup Point",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (booking.dropOffAddress != null &&
                    booking.dropOffAddress!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  // Nudged down past the label row, so it sits against the
                  // addresses it points between rather than the headings.
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.dropoff.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withAlpha(100),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          booking.dropOffAddress!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverTrackingPage(booking: booking),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE4A46B),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                loc.trackYourDriver,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
