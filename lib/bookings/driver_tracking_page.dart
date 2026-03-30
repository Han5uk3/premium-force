import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:premium_force_main/models/booking_model.dart';

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

  LatLng? _driverLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

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
    _initMarkers();
    _initPolylines();
    _listenToDriverLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _initMarkers() {
    final pickup = LatLng(
      widget.booking.pickupLat ?? 0,
      widget.booking.pickupLong ?? 0,
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        infoWindow: const InfoWindow(title: 'Pickup Point'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );

    final isChauffeur = (widget.booking.category ?? '').toLowerCase().contains(
      'chauffeur',
    );
    if (!isChauffeur && widget.booking.dropOffLat != null) {
      final dropoff = LatLng(
        widget.booking.dropOffLat ?? 0,
        widget.booking.dropOffLong ?? 0,
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          infoWindow: const InfoWindow(title: 'Dropoff Point'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        ),
      );
    }
  }

  void _initPolylines() {
    final pickup = LatLng(
      widget.booking.pickupLat ?? 0,
      widget.booking.pickupLong ?? 0,
    );
    final dropoff = LatLng(
      widget.booking.dropOffLat ?? 0,
      widget.booking.dropOffLong ?? 0,
    );

    final isChauffeur = (widget.booking.category ?? '').toLowerCase().contains(
      'chauffeur',
    );

    if (!isChauffeur && pickup.latitude != 0 && dropoff.latitude != 0) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [pickup, dropoff],
          color: Colors.white.withOpacity(0.8),
          width: 5,
        ),
      );
      // Glow effect
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_glow'),
          points: [pickup, dropoff],
          color: Colors.white.withOpacity(0.2),
          width: 12,
        ),
      );
    }
  }

  void _listenToDriverLocation() {
    _locationSubscription = _database
        .ref('bookings/${widget.booking.id}/driver_location')
        .onValue
        .listen((event) {
          final data = event.snapshot.value as Map?;
          if (data != null) {
            final lat = data['lat'] as double?;
            final lng = data['lng'] as double?;
            if (lat != null && lng != null) {
              setState(() {
                _driverLocation = LatLng(lat, lng);
                _updateDriverMarker();
              });
            }
          }
        });
  }

  void _updateDriverMarker() async {
    if (_driverLocation == null) return;

    final icon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/car_black.png',
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'driver');
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon: icon,
          rotation: 0,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(
      widget.booking.pickupLat ?? 0,
      widget.booking.pickupLong ?? 0,
    );

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
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
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
    );
  }
}
