import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/services/driver_location_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Displays a live map of the driver's location for a given booking.
class DriverTrackingPage extends StatefulWidget {
  final BookingV2 booking;

  const DriverTrackingPage({super.key, required this.booking});

  @override
  State<DriverTrackingPage> createState() => _DriverTrackingPageState();
}

class _DriverTrackingPageState extends State<DriverTrackingPage> {
  final Completer<GoogleMapController> _controller = Completer();
  StreamSubscription? _locationSubscription;
  StreamSubscription? _sessionSubscription;

  LatLng? _driverLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _driverIcon;

  // Chauffeur timer
  bool _isChauffeur = false;
  DateTime? _chauffeurStartTime;
  Timer? _chauffeurTimer;
  Duration _elapsed = Duration.zero;
  bool _tripEnded = false;

  // Location permissions
  bool _locationPermissionGranted = false;

  // Distance & ETA
  LatLng? _lastFetchLocation;
  String _currentEta = 'Calculating...';
  String _currentDistance = 'Calculating...';

  bool _mapLayoutReady = false;
  bool _hasFittedDriverInitialLocation = false;
  int _fetchDirectionsSeq = 0;

  static const String _mapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#212121"}]
  },
  {
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#757575"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#212121"}]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [{"color": "#757575"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [{"color": "#2c2c2c"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#3c3c3c"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#000000"}]
  }
]
''';

  @override
  void initState() {
    super.initState();
    _isChauffeur = _detectChauffeur();
    _loadDriverIcon();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkLocationPermission();
        _initStaticMarkersAndPolylines();
        _listenToDriverLocation();
        _listenToSessionForChauffeur();
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _sessionSubscription?.cancel();
    _chauffeurTimer?.cancel();
    super.dispose();
  }

  bool _detectChauffeur() => widget.booking.isChauffeur;

  /// The assigned car and its plate, e.g. `"GMC Yukon XL 2025 · 5432-RSA"`.
  ///
  /// Both come from the booking payload — the vehicle the customer booked and
  /// the fleet car actually dispatched — and either may be absent until a
  /// vehicle is assigned.
  String get _vehicleLine {
    final plate = widget.booking.fleet?.licensePlate;
    return [
      widget.booking.vehicleLabel,
      if (plate != null && plate.trim().isNotEmpty) plate,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
  }

  // --- Permissions ---

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) _showPermissionDialog();
      return;
    }

    if (mounted) {
      setState(() => _locationPermissionGranted = true);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.locationPermissionDenied),
        content: Text(
          AppLocalizations.of(context)!.locationPermissionsPermanentlyDenied,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Geolocator.openAppSettings();
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.settings),
          ),
        ],
      ),
    );
  }

  // --- Markers & Polylines ---

  void _initStaticMarkersAndPolylines() {
    final booking = widget.booking;
    // Direction determines which endpoint carries the airport marker.
    final isArrival = booking.isAirportArrival;
    final isDeparture = booking.isAirportDeparture;

    final pickupLat = booking.pickupLat ?? 0;
    final pickupLng = booking.pickupLng ?? 0;
    final dropoffLat = booking.dropOffLat ?? 0;
    final dropoffLng = booking.dropOffLng ?? 0;

    if (pickupLat == 0 || pickupLng == 0) return;

    final pickupLatLng = LatLng(pickupLat, pickupLng);

    if (_isChauffeur) {
      _addMarkerWithCustomIcon(
        id: 'pickup',
        position: pickupLatLng,
        title: AppLocalizations.of(context)!.pickupPointLabel,
        isGrayPin: true,
      );
    } else {
      _addMarkerWithCustomIcon(
        id: 'pickup',
        position: pickupLatLng,
        title: isArrival
            ? AppLocalizations.of(context)!.pickupPointLabel
            : AppLocalizations.of(context)!.airportPickupLabel,
        isGrayPin: true,
      );
      if (dropoffLat != 0 && dropoffLng != 0) {
        _addMarkerWithCustomIcon(
          id: 'dropoff',
          position: LatLng(dropoffLat, dropoffLng),
          title: isDeparture
              ? AppLocalizations.of(context)!.dropoffPointLabel
              : AppLocalizations.of(context)!.airportDropoffLabel,
          isGrayPin: true,
        );
      }
    }
    _updateDriverMarker();
    // Only fetch directions if driver location is already available.
    // Otherwise, the Firebase listener will trigger _fetchDirections()
    // once the driver location arrives, avoiding a race condition where
    // a stale (no-driver) response could overwrite the correct route.
    if (_driverLocation != null) {
      _fetchDirections();
    }
  }

  Future<void> _addMarkerWithCustomIcon({
    required String id,
    required LatLng position,
    required String title,
    bool isGrayPin = false,
  }) async {
    BitmapDescriptor icon;
    if (isGrayPin) {
      icon = await _getGrayPinIcon();
    } else {
      icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }

    if (mounted) {
      setState(() {
        _markers = Set<Marker>.from(_markers)
          ..add(
            Marker(
              markerId: MarkerId(id),
              position: position,
              infoWindow: InfoWindow(title: title),
              icon: icon,
            ),
          );
      });
    }
  }

  Future<BitmapDescriptor> _getGrayPinIcon() async {
    const double size = 70.0;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final ui.Paint paint = ui.Paint()..color = const Color(0xFF2C2C2C);

    // Modern pin shape matching the reference image
    final ui.Path path = ui.Path();
    path.moveTo(size / 2, size);
    path.quadraticBezierTo(size * 0.1, size * 0.6, size * 0.1, size * 0.4);
    path.arcToPoint(
      Offset(size * 0.9, size * 0.4),
      radius: const Radius.circular(size * 0.4),
      clockwise: true,
    );
    path.quadraticBezierTo(size * 0.9, size * 0.6, size / 2, size);
    canvas.drawPath(path, paint);

    // Inner white circle
    canvas.drawCircle(
      Offset(size / 2, size * 0.4),
      size * 0.15,
      ui.Paint()..color = Colors.white,
    );

    // Inner gray center dot for the "modern target" look
    canvas.drawCircle(
      Offset(size / 2, size * 0.4),
      size * 0.05,
      ui.Paint()..color = const Color(0xFF2C2C2C),
    );

    final ui.Image image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    // Drawn at the exact pixel size wanted, so no further scaling.
    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      imagePixelRatio: 1,
    );
  }

  void _addRoutePolyline(List<LatLng> points) {
    final newPolylines = Set<Polyline>.from(_polylines);

    // 1. Core solid line
    newPolylines.add(
      Polyline(
        polylineId: const PolylineId('route_core'),
        points: points,
        color: Colors.white,
        width: 3,
      ),
    );

    // 2. High intensity inner bloom
    newPolylines.add(
      Polyline(
        polylineId: const PolylineId('route_inner_glow'),
        points: points,
        color: Colors.white.withAlpha(150),
        width: 7,
      ),
    );

    // 3. Diffuse soft glow
    newPolylines.add(
      Polyline(
        polylineId: const PolylineId('route_outer_glow'),
        points: points,
        color: Colors.white.withAlpha(60),
        width: 12,
      ),
    );

    // 4. Ambient aura (replicates the bloom from the user's reference image)
    newPolylines.add(
      Polyline(
        polylineId: const PolylineId('route_ambient'),
        points: points,
        color: Colors.white.withAlpha(25),
        width: 22,
      ),
    );

    _polylines = newPolylines;
  }

  // --- RTDB Listeners ---

  void _listenToDriverLocation() {
    _locationSubscription = DriverLocationService()
        .watchLocation(widget.booking.id)
        .listen((position) {
          if (!mounted) return;

          setState(() {
            _driverLocation = position;
            _updateDriverMarker();
          });
          _moveCameraToDriver();

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

  void _listenToSessionForChauffeur() {
    if (!_isChauffeur) return;

    _sessionSubscription = DriverLocationService()
        .watchChauffeurSession(widget.booking.id)
        .listen((session) {
          if (!mounted) return;

          if (session.startedAt != null && _chauffeurStartTime == null) {
            _chauffeurStartTime = session.startedAt;
            _startChauffeurTimer();
          }
          if (!session.isActive && !_tripEnded) {
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

  Future<void> _loadDriverIcon() async {
    if (_driverIcon != null) return;
    try {
      debugPrint(
        '🚗 Loading driver pin custom asset: assets/images/car_image_generated.png',
      );
      final ByteData data = await rootBundle.load(
        'assets/images/car_image_generated.png',
      );
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 140, // Increased size for better visibility on the map
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ByteData? byteData = await fi.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      // Already scaled to 140px above, so it is passed at 1:1.
      _driverIcon = BitmapDescriptor.bytes(
        byteData!.buffer.asUint8List(),
        imagePixelRatio: 1,
      );
      debugPrint('🚗 Driver pin custom asset loaded successfully!');
    } catch (e) {
      debugPrint('⚠️ Error loading driver pin: $e');
      _driverIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueOrange,
      );
    }
    if (mounted && _driverLocation != null) {
      setState(() {
        _updateDriverMarker();
      });
    }
  }

  void _updateDriverMarker() {
    if (_driverLocation == null) return;
    if (!mounted) return;

    final markerTitle = AppLocalizations.of(context)!.driverMarkerTitle;

    final newMarkers = Set<Marker>.from(_markers);
    newMarkers.removeWhere((m) => m.markerId.value == 'driver');
    newMarkers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: _driverLocation!,
        icon:
            _driverIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(title: markerTitle),
      ),
    );
    _markers = newMarkers;
  }

  Future<void> _moveCameraToDriver() async {
    if (!_mapLayoutReady || _driverLocation == null) return;

    if (!_hasFittedDriverInitialLocation) {
      _hasFittedDriverInitialLocation = true;
      _zoomToFitAllPins();
      return;
    }

    final controller = await _controller.future;
    try {
      await controller.animateCamera(CameraUpdate.newLatLng(_driverLocation!));
    } catch (e) {
      debugPrint('⚠️ Error moving camera to driver: $e');
    }
  }

  Future<void> _zoomToFitAllPins() async {
    if (!mounted || !_mapLayoutReady || _markers.isEmpty) return;
    final controller = await _controller.future;
    double minLat = _markers.first.position.latitude,
        maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude,
        maxLng = _markers.first.position.longitude;
    for (final m in _markers) {
      if (m.position.latitude < minLat) minLat = m.position.latitude;
      if (m.position.latitude > maxLat) maxLat = m.position.latitude;
      if (m.position.longitude < minLng) minLng = m.position.longitude;
      if (m.position.longitude > maxLng) maxLng = m.position.longitude;
    }

    try {
      if (minLat == maxLat && minLng == maxLng) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14),
        );
      } else {
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            ),
            75,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error fitting camera bounds: $e');
    }
  }

  // --- Directions API ---

  Future<void> _fetchDirections() async {
    final seq = ++_fetchDirectionsSeq;
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

          final List<LatLng> polyPoints = [];
          for (final leg in legs) {
            for (final step in (leg['steps'] as List)) {
              polyPoints.addAll(_decodePolyline(step['polyline']['points']));
            }
          }

          if (mounted && seq == _fetchDirectionsSeq) {
            setState(() {
              _polylines = {};
              _addRoutePolyline(polyPoints);
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

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0, len = encoded.length, lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
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

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot make phone calls on this device.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.trackYourDriver,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.booking.route?.pickupLocation?.lat ?? 24.7136,
                widget.booking.route?.pickupLocation?.lng ?? 46.6753,
              ),
              zoom: 14,
            ),
            style: _mapStyle,
            onMapCreated: (c) {
              _controller.complete(c);
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  setState(() {
                    _mapLayoutReady = true;
                  });
                  _zoomToFitAllPins();
                }
              });
            },

            markers: _markers,
            polylines: _polylines,
            // Shows the customer's own position alongside the driver's, once
            // they have granted permission.
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(150),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: Row(
                children: [
                  // Driver Profile Pic or First Letter
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFE4A46B),
                    child:
                        widget.booking.driver?.avatar != null &&
                            widget.booking.driver!.avatar!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: CachedNetworkImage(
                              imageUrl: widget.booking.driver!.avatar!,
                              fit: BoxFit.cover,
                              width: 52,
                              height: 52,
                              errorWidget: (c, u, e) => Text(
                                (widget.booking.driver?.name ?? "D")[0]
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            (widget.booking.driver?.name ?? "D")[0]
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  // Driver Info and ETA
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.booking.driver?.name ?? "Driver",
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (widget.booking.driver?.rating != null) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFE4A46B),
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                widget.booking.driver!.rating!.toStringAsFixed(
                                  1,
                                ),
                                style: const TextStyle(
                                  color: Color(0xFFE4A46B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        // The car and its plate — what the customer actually
                        // looks for when it pulls up.
                        if (_vehicleLine.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _vehicleLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  color: Colors.white.withAlpha(150),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _isChauffeur
                                        ? (_tripEnded
                                              ? loc.tripEnded
                                              : (_chauffeurStartTime == null
                                                    ? "00:00:00"
                                                    : _formatElapsed(_elapsed)))
                                        : "$_currentEta (approx)",
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(150),
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.white.withAlpha(150),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _currentDistance,
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(150),
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Call Button
                  Material(
                    color: const Color(0xFFE4A46B),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => _makePhoneCall(widget.booking.driver?.phone),
                      borderRadius: BorderRadius.circular(25),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.phone, color: Colors.black, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
