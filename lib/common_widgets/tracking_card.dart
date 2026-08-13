import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/bookings/driver_tracking_page.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
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
  LatLng? _driverLocation;
  LatLng? _lastFetchLocation;
  String _currentEta = '';
  String _currentDistance = '';
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://premium-force-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
  bool _isChauffeur = false;

  @override
  void initState() {
    super.initState();
    _isChauffeur = widget.booking.isChauffeur;
    _listenToDriverLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _listenToDriverLocation() {
    final path = 'bookings/${widget.booking.id}/driver_location';
    debugPrint(
      '📡 [TrackingCard] Listening to driver location at Firebase path: $path',
    );

    _locationSubscription = _database
        .ref(path)
        .onValue
        .listen(
          (event) {
            final data = event.snapshot.value;
            debugPrint(
              '📡 [TrackingCard] Received Firebase location update: $data (Type: ${data.runtimeType})',
            );

            if (data == null) {
              debugPrint('📡 [TrackingCard] Location update is null');
              return;
            }

            double? lat;
            double? lng;

            if (data is Map) {
              final rawLat =
                  data['lat'] ?? data['latitude'] ?? data['Latitude'];
              final rawLng =
                  data['lng'] ??
                  data['longitude'] ??
                  data['Longitude'] ??
                  data['long'] ??
                  data['Long'];

              if (rawLat is num) lat = rawLat.toDouble();
              if (rawLng is num) lng = rawLng.toDouble();
            } else if (data is String) {
              final trimmed = data.trim();
              if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
                try {
                  final Map<String, dynamic> parsed = Map<String, dynamic>.from(
                    json.decode(trimmed) as Map,
                  );
                  final rawLat =
                      parsed['lat'] ?? parsed['latitude'] ?? parsed['Latitude'];
                  final rawLng =
                      parsed['lng'] ??
                      parsed['longitude'] ??
                      parsed['Longitude'] ??
                      parsed['long'] ??
                      parsed['Long'];

                  if (rawLat is num) lat = rawLat.toDouble();
                  if (rawLng is num) lng = rawLng.toDouble();
                } catch (e) {
                  debugPrint(
                    '⚠️ [TrackingCard] Error decoding JSON location string: $e',
                  );
                }
              } else if (trimmed.contains(',')) {
                final parts = trimmed.split(',');
                if (parts.length >= 2) {
                  lat = double.tryParse(parts[0].trim());
                  lng = double.tryParse(parts[1].trim());
                }
              }
            }

            if (lat != null && lng != null) {
              final double nonNullLat = lat;
              final double nonNullLng = lng;
              debugPrint(
                '📡 [TrackingCard] Parsed coordinates successfully: ($nonNullLat, $nonNullLng)',
              );

              if (mounted) {
                setState(() {
                  _driverLocation = LatLng(nonNullLat, nonNullLng);
                });
              }
              if (_lastFetchLocation == null ||
                  Geolocator.distanceBetween(
                        _lastFetchLocation!.latitude,
                        _lastFetchLocation!.longitude,
                        nonNullLat,
                        nonNullLng,
                      ) >
                      100) {
                _lastFetchLocation = _driverLocation;
                _fetchDirections();
              }
            } else {
              debugPrint(
                '⚠️ [TrackingCard] Failed to parse coordinates from: $data',
              );
            }
          },
          onError: (error) {
            debugPrint(
              '❌ [TrackingCard] Firebase location stream error at path "$path": $error',
            );
          },
        );
  }

  Future<void> _fetchDirections() async {
    final booking = widget.booking;
    final pickupLat = booking.pickupLat ?? 0;
    final pickupLng = booking.pickupLng ?? 0;
    final dropoffLat = booking.dropOffLat ?? 0;
    final dropoffLng = booking.dropOffLng ?? 0;
    final hasDropoff = dropoffLat != 0 && dropoffLng != 0;

    String origin, destination, waypoints = '';
    if (_driverLocation == null) {
      if (!hasDropoff) return;
      origin = '$pickupLat,$pickupLng';
      destination = '$dropoffLat,$dropoffLng';
    } else {
      origin = '${_driverLocation!.latitude},${_driverLocation!.longitude}';
      if (_isChauffeur || !hasDropoff) {
        destination = '$pickupLat,$pickupLng';
      } else {
        destination = '$dropoffLat,$dropoffLng';
        waypoints = '&waypoints=$pickupLat,$pickupLng';
      }
    }

    final apiKey =
        dotenv.env['GOOGLE_MAPS_API_KEY'] ?? dotenv.env['MAPS_API_KEY'] ?? '';
    if (apiKey.isEmpty) return;

    try {
      final url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination$waypoints&key=$apiKey';
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
          final legs = routes.first['legs'] as List;
          int dist = 0, dur = 0;
          if (_driverLocation == null || legs.length < 2) {
            for (final leg in legs) {
              dist += (leg['distance']['value'] as num).toInt();
              dur += (leg['duration']['value'] as num).toInt();
            }
          } else {
            dist = (legs[0]['distance']['value'] as num).toInt();
            dur = (legs[0]['duration']['value'] as num).toInt();
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final booking = widget.booking;

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
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4A46B).withAlpha(20),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE4A46B).withAlpha(40),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.local_taxi_rounded,
                      color: Color(0xFFE4A46B),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.ongoing.toUpperCase(),
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
                    color: Colors.blue.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        loc.tracking.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.blue,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (booking.dropOffAddress != null &&
                    booking.dropOffAddress!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white24,
                    size: 16,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
