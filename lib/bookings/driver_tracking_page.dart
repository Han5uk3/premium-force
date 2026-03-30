import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:premium_force_main/models/booking_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

/// Displays a live map of the driver's location for a given booking.
///
/// Route behaviour per booking type:
/// - **Airport Arrival**  : driver → pickup location → airport (dropoff).
/// - **Airport Departure**: driver → airport (pickup) → dropoff location.
/// - **Chauffeur**        : driver → pickup location. Timer visible on screen.
///                          No fixed dropoff. Trip ends when driver stops tracking.
class DriverTrackingPage extends StatefulWidget {
  final BookingModel booking;

  const DriverTrackingPage({super.key, required this.booking});

  @override
  State<DriverTrackingPage> createState() => _DriverTrackingPageState();
}

class _DriverTrackingPageState extends State<DriverTrackingPage> {
  final Completer<GoogleMapController> _controller = Completer();
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _sessionSubscription;

  LatLng? _driverLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Chauffeur timer
  bool _isChauffeur = false;
  DateTime? _chauffeurStartTime;
  Timer? _chauffeurTimer;
  Duration _elapsed = Duration.zero;
  bool _tripEnded = false;
  // Distance & ETA
  LatLng? _lastFetchLocation;
  String _currentEta = 'Calculating...';
  String _currentDistance = 'Calculating...';

  static const String _mapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {"color": "#212121"}
    ]
  },
  {
    "elementType": "labels.icon",
    "stylers": [
      {"visibility": "off"}
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {"color": "#757575"}
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {"color": "#212121"}
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      {"color": "#757575"}
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [
      {"color": "#2c2c2c"}
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {"color": "#3c3c3c"}
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {"color": "#000000"}
    ]
  }
]
''';

  @override
  void initState() {
    super.initState();
    _isChauffeur = _detectChauffeur();
    _initStaticMarkersAndPolylines();
    _listenToDriverLocation();
    _listenToSessionForChauffeur();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _sessionSubscription?.cancel();
    _chauffeurTimer?.cancel();
    super.dispose();
  }

  bool _detectChauffeur() {
    final cat = (widget.booking.category ?? '').toLowerCase();
    return cat.contains('chauffeur') || widget.booking.estimatedHours != null;
  }

  // ---------------------------------------------------------------------------
  // Markers & Polylines
  // ---------------------------------------------------------------------------

  /// Determine booking type and set up the static pickup/dropoff markers and
  /// any polyline connecting them.
  void _initStaticMarkersAndPolylines() {
    final booking = widget.booking;
    final cat = (booking.category ?? '').toLowerCase();
    final isArrival = cat.contains('arrival');
    final isDeparture = cat.contains('departure');

    final pickupLat = booking.pickupLat ?? 0;
    final pickupLng = booking.pickupLong ?? 0;
    final dropoffLat = booking.dropOffLat ?? 0;
    final dropoffLng = booking.dropOffLong ?? 0;

    final hasPickup = pickupLat != 0 && pickupLng != 0;
    final hasDropoff = dropoffLat != 0 && dropoffLng != 0;

    if (!hasPickup) return;

    final pickupLatLng = LatLng(pickupLat, pickupLng);

    if (_isChauffeur) {
      // Chauffeur: only show the pickup marker (no fixed dropoff route)
      _markers.add(_buildMarker(
        id: 'pickup',
        position: pickupLatLng,
        title: 'Pickup Point',
        hue: BitmapDescriptor.hueAzure,
      ));
      return;
    }

    if (isArrival) {
      // Airport Arrival: driver picks up customer at a location → drops off at airport.
      // pickup = customer location, dropoff = airport
      _markers.add(_buildMarker(
        id: 'pickup',
        position: pickupLatLng,
        title: 'Pickup Point',
        hue: BitmapDescriptor.hueAzure,
      ));
      if (hasDropoff) {
        final dropoffLatLng = LatLng(dropoffLat, dropoffLng);
        _markers.add(_buildMarker(
          id: 'dropoff',
          position: dropoffLatLng,
          title: 'Airport (Dropoff)',
          hue: BitmapDescriptor.hueRose,
        ));
        _addRoutePolyline([pickupLatLng, dropoffLatLng]);
      }
      return;
    }

    if (isDeparture) {
      // Airport Departure: driver picks up customer from airport → drops off at destination.
      // pickup = airport, dropoff = customer destination
      _markers.add(_buildMarker(
        id: 'pickup',
        position: pickupLatLng,
        title: 'Airport (Pickup)',
        hue: BitmapDescriptor.hueAzure,
      ));
      if (hasDropoff) {
        final dropoffLatLng = LatLng(dropoffLat, dropoffLng);
        _markers.add(_buildMarker(
          id: 'dropoff',
          position: dropoffLatLng,
          title: 'Dropoff Point',
          hue: BitmapDescriptor.hueRose,
        ));
        _addRoutePolyline([pickupLatLng, dropoffLatLng]);
      }
      return;
    }

    // Standard / unknown: show pickup → dropoff if both available
    _markers.add(_buildMarker(
      id: 'pickup',
      position: pickupLatLng,
      title: 'Pickup Point',
      hue: BitmapDescriptor.hueAzure,
    ));
    if (hasDropoff) {
      final dropoffLatLng = LatLng(dropoffLat, dropoffLng);
      _markers.add(_buildMarker(
        id: 'dropoff',
        position: dropoffLatLng,
        title: 'Dropoff Point',
        hue: BitmapDescriptor.hueRose,
      ));
      _addRoutePolyline([pickupLatLng, dropoffLatLng]);
    }
  }

  Marker _buildMarker({
    required String id,
    required LatLng position,
    required String title,
    required double hue,
  }) {
    return Marker(
      markerId: MarkerId(id),
      position: position,
      infoWindow: InfoWindow(title: title),
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
    );
  }

  void _addRoutePolyline(List<LatLng> points) {
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: Colors.white.withOpacity(0.8),
        width: 5,
      ),
    );
    // Glow effect
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route_glow'),
        points: points,
        color: Colors.white.withOpacity(0.2),
        width: 12,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RTDB Listeners
  // ---------------------------------------------------------------------------

  void _listenToDriverLocation() {
    _locationSubscription = _database
        .ref('bookings/${widget.booking.id}/driver_location')
        .onValue
        .listen((event) {
          final data = event.snapshot.value as Map?;
          if (data != null) {
            final lat = (data['lat'] as num?)?.toDouble();
            final lng = (data['lng'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              setState(() {
                _driverLocation = LatLng(lat, lng);
                _updateDriverMarker();
              });
              _moveCameraToDriver();
              
              if (_lastFetchLocation == null ||
                  Geolocator.distanceBetween(
                        _lastFetchLocation!.latitude,
                        _lastFetchLocation!.longitude,
                        lat,
                        lng,
                      ) >
                      100) {
                _lastFetchLocation = _driverLocation;
                _fetchDirections();
              }
            }
          }
        });
  }

  /// Listen to the tracking_session node. For chauffeur bookings:
  /// - On start: read startTime and begin the elapsed timer.
  /// - On stop (isActive = false): stop the timer and show "Trip Ended".
  void _listenToSessionForChauffeur() {
    if (!_isChauffeur) return;

    _sessionSubscription = _database
        .ref('bookings/${widget.booking.id}/tracking_session')
        .onValue
        .listen((event) {
          final data = event.snapshot.value as Map?;
          if (data == null) return;

          final isActive = data['isActive'] as bool? ?? true;
          final startTimeStr = data['startTime'] as String?;

          if (startTimeStr != null && _chauffeurStartTime == null) {
            _chauffeurStartTime = DateTime.tryParse(startTimeStr);
            _startChauffeurTimer();
          }

          if (!isActive && !_tripEnded) {
            setState(() => _tripEnded = true);
            _chauffeurTimer?.cancel();
          }
        });
  }

  void _startChauffeurTimer() {
    _chauffeurTimer?.cancel();
    _chauffeurTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_chauffeurStartTime != null && !_tripEnded) {
        setState(() {
          _elapsed = DateTime.now().difference(_chauffeurStartTime!);
        });
      }
    });
  }

  void _updateDriverMarker() async {
    if (_driverLocation == null) return;

    BitmapDescriptor icon;
    try {
      icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/icons/car_black.png',
      );
    } catch (_) {
      icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }

    if (mounted) {
      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'driver');
        _markers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: _driverLocation!,
            icon: icon,
            rotation: 0,
            anchor: const Offset(0.5, 0.5),
            infoWindow: const InfoWindow(title: 'Driver'),
          ),
        );
      });
    }
  }

  Future<void> _moveCameraToDriver() async {
    if (_driverLocation == null) return;
    try {
      final controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newLatLng(_driverLocation!),
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _fetchDirections() async {
    if (_driverLocation == null) return;

    final booking = widget.booking;
    final pickupLat = booking.pickupLat ?? 0;
    final pickupLng = booking.pickupLong ?? 0;
    if (pickupLat == 0 || pickupLng == 0) return;

    final dropoffLat = booking.dropOffLat ?? 0;
    final dropoffLng = booking.dropOffLong ?? 0;
    final hasDropoff = dropoffLat != 0 && dropoffLng != 0;

    String origin = '${_driverLocation!.latitude},${_driverLocation!.longitude}';
    String destination;
    String waypoints = '';

    if (_isChauffeur || !hasDropoff) {
      destination = '$pickupLat,$pickupLng';
    } else {
      destination = '$dropoffLat,$dropoffLng';
      waypoints = '&waypoints=$pickupLat,$pickupLng';
    }

    final apiKey =
        dotenv.env['GOOGLE_MAPS_API_KEY'] ?? dotenv.env['MAPS_API_KEY'] ?? '';
    if (apiKey.isEmpty) return;

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination$waypoints&key=$apiKey';

    try {
      final response = await Dio().get(url);
      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final routes = response.data['routes'] as List;
        if (routes.isNotEmpty) {
          final legs = routes.first['legs'] as List;
          int totalDistance = 0;
          int totalDuration = 0;
          for (var leg in legs) {
            totalDistance += (leg['distance']['value'] as num).toInt();
            totalDuration += (leg['duration']['value'] as num).toInt();
          }

          final polylineStr = routes.first['overview_polyline']['points'] as String;
          final polyPoints = _decodePolyline(polylineStr);

          if (mounted) {
            setState(() {
              _polylines.clear(); 
              _addRoutePolyline(polyPoints);

              _currentDistance = '${(totalDistance / 1000).toStringAsFixed(1)} km';
              
              int mins = (totalDuration / 60).round();
              _currentEta = mins > 60 
                  ? '${mins ~/ 60} hr ${mins % 60} min' 
                  : '$mins min';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching directions: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 100000.0, lng / 100000.0));
    }
    return poly;
  }

  String _formatElapsed(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mins:$secs' : '$mins:$secs';
  }

  String _buildSubtitle() {
    final cat = (widget.booking.category ?? '').toLowerCase();
    if (cat.contains('arrival')) return 'Airport Arrival — Driver en route to you';
    if (cat.contains('departure')) return 'Airport Departure — Driver coming to pick up';
    if (_isChauffeur) return 'Chauffeur Service — Driver en route to pickup';
    return 'Driver is on the way';
  }

  LatLng get _initialCameraTarget {
    final lat = widget.booking.pickupLat ?? 0;
    final lng = widget.booking.pickupLong ?? 0;
    if (lat != 0 && lng != 0) return LatLng(lat, lng);
    return _driverLocation ?? const LatLng(24.7136, 46.6753); // Riyadh fallback
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Track Your Driver',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialCameraTarget,
              zoom: 14,
            ),
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              controller.setMapStyle(_mapStyle);
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Info banner at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subtitle / booking type label
                  Text(
                    _buildSubtitle(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Chauffeur timer or status line
                  if (_isChauffeur) ...[
                    _tripEnded
                        ? const Text(
                            'Trip Ended',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : Row(
                            children: [
                              const Icon(
                                Icons.timer,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _chauffeurStartTime == null
                                    ? 'Waiting for driver...'
                                    : _formatElapsed(_elapsed),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                  ] else ...[
                    Text(
                      _driverLocation != null
                          ? 'ETA: $_currentEta • $_currentDistance'
                          : 'Waiting for driver location...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
