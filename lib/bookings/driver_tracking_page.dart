import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/services/address_geocoding_service.dart';
import 'package:premium_force_main/services/driver_location_service.dart';
import 'package:premium_force_main/utils/screen_logger.dart';
import 'package:shimmer/shimmer.dart';
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

class _DriverTrackingPageState extends State<DriverTrackingPage>
    with SingleTickerProviderStateMixin {
  /// Completes on the first `onMapCreated`, so callers can wait for a map that
  /// does not exist yet.
  final Completer<GoogleMapController> _controller = Completer();

  /// The controller most recently handed over, which is not necessarily the one
  /// [_controller] completed with.
  ///
  /// A platform view can be torn down and rebuilt — a `Stack` child list that
  /// changes shape is enough — and the controller from the previous one then
  /// belongs to a map that is gone: it accepts `animateCamera` and nothing
  /// happens, which is a camera that has silently stopped following.
  GoogleMapController? _liveController;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _sessionSubscription;

  /// Console tag prefixing this screen's log lines.
  static const String _log = 'tracking';

  /// Redraws the route and ETA on a clock as well as on movement, so a car
  /// stopped in traffic still counts down.
  Timer? _routeRefreshTimer;

  /// Re-checks how long ago the driver app last published, for the stale
  /// banner. Cheap — it only reads a timestamp already in hand.
  Timer? _freshnessTimer;

  /// The position last published, which is where the marker is animating *to*.
  LatLng? _driverLocation;
  Set<Marker> _markers = {};

  /// The markers the map is actually drawing.
  ///
  /// Separate from [_markers] so the car can be moved without a [setState].
  /// The marker is rebuilt on every animation frame, and a `setState` there
  /// rebuilt this whole page sixty times a second — the app bar, the driver
  /// card and its network image, the controls — which is what made each
  /// position update look like the map reloading. Only the [GoogleMap] listens
  /// to this, so only the map rebuilds.
  final ValueNotifier<Set<Marker>> _mapMarkers = ValueNotifier({});

  Set<Polyline> _polylines = {};
  BitmapDescriptor? _driverIcon;

  /// The pin drawn at the pickup and drop-off points.
  ///
  /// Held once and reused: the markers are rebuilt every time the leg changes,
  /// and decoding a 1.4 MB asset again each time would be real work for an
  /// identical result.
  BitmapDescriptor? _pinIcon;

  /// The leg being driven, as the driver app publishes it.
  ///
  /// Drives everything the map shows: which marker is the destination, where
  /// the route runs, and what the ETA counts down to. Starts on the approach,
  /// because that is the only leg a session can open on.
  TrackingPhase _phase = TrackingPhase.toPickup;

  /// Ends of the journey recovered from their address text, for a booking that
  /// arrived with `0,0` where the coordinate should have been.
  ///
  /// Null until a lookup succeeds, and never used in preference to a real
  /// coordinate from the payload — see [_pickupPoint] and [_dropOffPoint].
  LatLng? _geocodedPickup;
  LatLng? _geocodedDropOff;

  /// Whether a lookup is already running, so a leg change does not start a
  /// second pass over the same two addresses.
  bool _resolvingEndpoints = false;

  // Chauffeur timer
  bool _isChauffeur = false;
  DateTime? _chauffeurStartTime;
  Timer? _chauffeurTimer;
  Duration _elapsed = Duration.zero;
  bool _tripEnded = false;

  // Location permissions
  bool _locationPermissionGranted = false;

  /// Whether a fix for the customer's own position is being waited on, so the
  /// button can show it is working rather than looking dead for a few seconds.
  bool _isLocatingCustomer = false;

  // --- Marker animation ---

  /// Drives the slide from [_animFrom] to [_animTo]. The driver app publishes
  /// only every 50m, so without this the car would jump between fixes; with it
  /// the marker walks the gap and reads as a moving vehicle.
  late final AnimationController _markerController;

  LatLng? _animFrom;
  LatLng? _animTo;

  // --- Route following ---

  /// The drawn route, and the distance in metres from its start to each of its
  /// points. Together these turn "how far along the route" into a position and
  /// a heading, which is what lets the car track the line instead of cutting
  /// across it.
  List<LatLng> _routePoints = const [];
  List<double> _routeCumulative = const [];

  /// How far along the route the car is drawn, and the span the current
  /// animation is covering. Null whenever there is no usable route, in which
  /// case the marker falls back to a straight line between fixes.
  double? _renderedAlong;
  double? _animFromAlong;
  double? _animToAlong;

  /// Segment [_pointAlong] last landed on, so the next frame resumes there
  /// instead of searching the route from the beginning. Reset with the route.
  int _segmentHint = 0;

  /// How far off the route a fix may be and still be treated as on it.
  ///
  /// Covers GPS scatter and the width of a carriageway. Beyond it the driver
  /// has genuinely left the drawn route — a wrong turn, or a road the route
  /// did not take — and snapping would slide the car sideways onto a line it
  /// is not on, so the raw position is used until the next route arrives.
  static const double _maxSnapMeters = 45;

  /// The shortest move that is allowed to change the car's heading when there
  /// is no route to take it from. Below this the displacement is GPS noise.
  static const double _minBearingMeters = 5;

  /// Metres in a degree of latitude — near enough constant everywhere, unlike
  /// longitude, which narrows towards the poles.
  static const double _metresPerLat = 111132.0;

  /// Where the marker is drawn right now — between the last two fixes while the
  /// animation runs, and exactly on the newest one once it settles.
  LatLng? _renderedDriverLocation;

  /// Heading in degrees the car icon is rotated to, so it points the way it is
  /// travelling instead of always facing north.
  double _driverBearing = 0;

  /// How long the marker takes to walk from one fix to the next.
  ///
  /// Deliberately shorter than the gap between fixes at city speeds: finishing
  /// early and waiting reads as a car pausing, which is honest, whereas running
  /// long would have the marker still crossing ground the driver has left.
  static const Duration _markerAnimation = Duration(milliseconds: 900);

  // --- Camera ---

  /// Whether the map still follows the car.
  ///
  /// Cleared the moment the customer pans or zooms: re-centring under their
  /// finger every time a fix arrives made the map impossible to read ahead on.
  /// The recentre button puts it back — and so does letting go of the map, see
  /// [_resumeFollowAfter].
  bool _followDriver = true;

  /// Whether following was dropped by the customer's own hand on the map,
  /// rather than by a button asking for a particular view.
  ///
  /// Only a gesture arms the auto-resume below. Someone who tapped "show full
  /// route" is reading the whole journey, and pulling the camera back onto the
  /// car five seconds later would take it away mid-look; someone who nudged the
  /// map is glancing, and expects it to settle back on the car by itself.
  bool _followSuspendedByGesture = false;

  /// The pending return to the car. Restarted while the map is still moving, so
  /// it measures the quiet *after* the pan rather than the time since it began.
  Timer? _followResumeTimer;

  /// How long the map must sit untouched before it goes back to following the
  /// car of its own accord.
  static const Duration _resumeFollowAfter = Duration(seconds: 5);

  /// Last line [_logCamera] emitted, so a decision repeated on every position
  /// fix is said once.
  String? _lastCameraLog;

  /// Zoom the two locate buttons settle on — close enough to read the street
  /// the car is on, which is the question either of them is asked.
  static const double _driverFocusZoom = 17;
  static const double _customerFocusZoom = 16;

  /// Width of a circular map control — 20pt icon inside 12pt of padding.
  ///
  /// Used as its own size and as the width of the empty slot balancing it on
  /// the other side of the row, which is what puts the recentre pill on the
  /// screen's centre line.
  static const double _mapControlSize = 44;

  /// The points currently drawn — the route from the car forward, kept so the
  /// line can be rebuilt at a new width without re-deriving it.
  List<LatLng> _drawnPoints = const [];

  /// Current line width in screen pixels. See [_routeWidthFor].
  int _routeWidth = 6;

  // --- Distance & ETA ---

  LatLng? _lastFetchLocation;
  DateTime? _lastFetchAt;

  /// Null until the first successful Directions response — rendered as
  /// "Calculating…", which cannot be built here because it needs a context.
  String? _currentEta;
  String? _currentDistance;

  /// Consecutive Directions failures, for the backoff in [_scheduleRouteRetry].
  int _directionsFailures = 0;
  Timer? _directionsRetryTimer;

  /// When the driver app last published, and whether that is long enough ago to
  /// tell the customer the feed has stopped.
  DateTime? _lastPingAt;
  bool _feedIsStale = false;

  bool _mapLayoutReady = false;
  bool _hasCentredOnDriver = false;

  // --- Opening the map ---

  /// Where the map is created looking, and at what zoom.
  ///
  /// The map is not built at all until this is known, so it opens *on* the car
  /// rather than flying to it. It used to be created at the booking's pickup
  /// coordinate, which on an airport booking arrives as `0,0` — the middle of
  /// the Atlantic — so the screen opened on blank ocean and then panned across
  /// the world once the first fix landed.
  LatLng? _mapOpenTarget;
  double _mapOpenZoom = _driverFocusZoom;

  /// Set once the map has faded in, after which the skeleton beneath it is no
  /// longer built.
  bool _mapRevealed = false;

  /// How long to wait for a driver fix before opening the map anyway.
  ///
  /// A feed that never arrives — the driver's app killed, or no signal — must
  /// not leave the customer watching a placeholder indefinitely. After this the
  /// map opens on the booking instead, pulled back a little since the car could
  /// be anywhere.
  static const Duration _openWithoutDriverAfter = Duration(seconds: 10);
  Timer? _openFallbackTimer;
  int _fetchDirectionsSeq = 0;

  /// How far the car must move before the route is redrawn.
  ///
  /// The driver publishes every 50m, so this re-routes about every other fix.
  static const double _rerouteDistanceMeters = 120;

  /// The route is also refreshed on this clock, so an ETA held up in traffic
  /// keeps falling while the car is barely moving.
  static const Duration _routeRefreshInterval = Duration(seconds: 45);

  /// No publish for this long means the driver's feed has stopped rather than
  /// the car having stopped — the driver app heartbeats once a minute purely so
  /// this is decidable.
  static const Duration _staleAfter = Duration(seconds: 150);

  @override
  void initState() {
    super.initState();
    _isChauffeur = _detectChauffeur();

    _markerController =
        AnimationController(vsync: this, duration: _markerAnimation)
          ..addListener(_onMarkerTick);

    _loadDriverIcon();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkLocationPermission();
        _initStaticMarkersAndPolylines();
        _listenToDriverLocation();
        _listenToSession();
        _startRouteRefreshTimer();
        _startFreshnessTimer();
        _startOpenFallbackTimer();
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _sessionSubscription?.cancel();
    _chauffeurTimer?.cancel();
    _routeRefreshTimer?.cancel();
    _freshnessTimer?.cancel();
    _directionsRetryTimer?.cancel();
    _openFallbackTimer?.cancel();
    _followResumeTimer?.cancel();
    _markerController.dispose();
    _mapMarkers.dispose();
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

  /// Artwork for the pickup and drop-off pins.
  static const String _pinAsset = 'assets/images/locationpin.png';

  /// Artwork for the driver's car — top-down, nose north.
  static const String _carAsset = 'assets/images/carTopDown.png';

  /// Width in device pixels the car is decoded at. Height follows the asset's
  /// own aspect ratio, which is roughly 1:1.7, so this draws a car about 28pt
  /// wide and 47pt long at [BitmapDescriptor.bytes]'s 2x ratio.
  static const int _carTargetWidth = 56;

  /// Width in device pixels the pin is decoded at. Height follows the asset's
  /// own aspect ratio, which a pin needs — it is taller than it is wide.
  static const int _pinTargetWidth = 60;

  /// Trimmed text, or null when there is nothing worth showing.
  ///
  /// An [InfoWindow] renders an empty string as a blank line, so anything that
  /// might be absent has to come through here.
  static String? _cleaned(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
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

  // --- Journey endpoints ---

  /// Where the pickup is, or null while it is still unknown.
  ///
  /// The payload's coordinate wins; `0,0` — which is what a booking saved
  /// without a point comes back as — is not a place, so it falls through to
  /// whatever [_resolveMissingEndpoints] recovered from the address text.
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

  /// A point for the log line, or why there isn't one.
  static String _describe(LatLng? point) =>
      point == null ? 'none' : '${point.latitude},${point.longitude}';

  /// Recover the ends of the journey the payload positioned at `0,0`.
  ///
  /// Bookings arrive fairly often with the address written out in full but no
  /// coordinate behind it, and until now that cost the customer the pin, the
  /// route and the ETA — a car crawling across an empty map. The address is
  /// enough to find the point, so it is looked up and used exactly as a payload
  /// coordinate would be.
  ///
  /// Both ends are resolved in one pass rather than only the leg being driven,
  /// so the drop-off is already in hand when the driver starts the ride and the
  /// map does not have to wait on a lookup at the moment the leg changes.
  Future<void> _resolveMissingEndpoints() async {
    if (_resolvingEndpoints) return;

    final booking = widget.booking;
    final needsPickup = _pickupPoint == null;
    final needsDropOff =
        _dropOffPoint == null &&
        (booking.dropOffAddress?.trim().isNotEmpty ?? false);
    if (!needsPickup && !needsDropOff) return;

    _resolvingEndpoints = true;
    try {
      final geocoder = AddressGeocodingService();

      if (needsPickup) {
        final resolved = await geocoder.resolve(booking.pickupAddress);
        if (!mounted) return;
        if (resolved != null) {
          setState(() => _geocodedPickup = resolved);
          logScreen(
            _log,
            'pickup recovered from address → ${_describe(resolved)}',
          );
          _onEndpointResolved(resolved);
        }
      }

      if (needsDropOff) {
        final resolved = await geocoder.resolve(booking.dropOffAddress);
        if (!mounted) return;
        if (resolved != null) {
          setState(() => _geocodedDropOff = resolved);
          logScreen(
            _log,
            'drop-off recovered from address → ${_describe(resolved)}',
          );
          _onEndpointResolved(resolved);
        }
      }
    } finally {
      _resolvingEndpoints = false;
    }
  }

  /// Put up the pin and draw the route now that there is somewhere to put them.
  ///
  /// Only the end the current leg is driving to acts on this. Recovering the
  /// drop-off while the car is still on its way to the pickup changes nothing
  /// on screen — the point is simply held until that leg comes round, rather
  /// than spending a Directions request redrawing the leg already drawn.
  void _onEndpointResolved(LatLng resolved) {
    final destination = _phase == TrackingPhase.toDropOff
        ? _dropOffPoint
        : _pickupPoint;
    if (destination != resolved) return;

    _addLegDestinationMarker();
    if (_driverLocation != null) _fetchDirections();
  }

  // --- Markers & Polylines ---

  /// Pin only what the current leg is about.
  ///
  /// On the approach that is the pickup; once the trip starts it is the
  /// drop-off, and the pickup comes down — it is behind the car by then, and
  /// leaving it up made the map read as though the driver were still going
  /// there. Hourly hire pins the pickup throughout, having nowhere else to go.
  void _initStaticMarkersAndPolylines() {
    final booking = widget.booking;

    final pickup = _pickupPoint;
    final dropoff = _dropOffPoint;

    // A missing coordinate silently costs both the destination pin and the
    // route — the pin is skipped here and `_legDestination` returns null, so
    // the map shows a lone car and no line. Logged with the raw sources so it
    // is obvious whether the payload lacked the point or the model missed it.
    logScreen(
      _log,
      'markers for ${_phase.wireValue}: '
      'pickup=${_describe(pickup)} dropoff=${_describe(dropoff)}',
    );
    logScreenDetail(
      _log,
      'sources — pickupLocation=${booking.route?.pickupLocation?.lat},'
      '${booking.route?.pickupLocation?.lng} '
      'dropOffLocation=${booking.route?.dropOffLocation?.lat},'
      '${booking.route?.dropOffLocation?.lng} '
      'airport=${booking.route?.airport?.name} '
      '${booking.route?.airport?.lat},${booking.route?.airport?.lng} '
      'service=${booking.resolvedServiceType?.name}',
    );

    _addLegDestinationMarker();
    _updateDriverMarker();
    // An end of the journey the payload left at `0,0` is looked up from its
    // address, and the pin and the route go in when it lands.
    _resolveMissingEndpoints();
    // Only fetch directions if driver location is already available.
    // Otherwise, the Firebase listener will trigger _fetchDirections()
    // once the driver location arrives, avoiding a race condition where
    // a stale (no-driver) response could overwrite the correct route.
    if (_driverLocation != null) {
      _fetchDirections();
    }
  }

  /// The pin for the end of the journey the current leg is driving to.
  ///
  /// The pin says which end of the journey it is and, underneath, the address
  /// itself. Naming it after the *product* — "Airport (Pickup)" — told the
  /// customer something they already knew and left out the one thing they tap
  /// a pin to find out: where it actually is.
  void _addLegDestinationMarker() {
    final booking = widget.booking;
    final loc = AppLocalizations.of(context)!;

    final dropoff = _dropOffPoint;
    if (_phase == TrackingPhase.toDropOff && dropoff != null) {
      _addMarkerWithCustomIcon(
        id: 'dropoff',
        position: dropoff,
        title: loc.dropLocation,
        snippet: booking.dropOffAddress,
      );
      return;
    }

    final pickup = _pickupPoint;
    if (_phase != TrackingPhase.toDropOff && pickup != null) {
      _addMarkerWithCustomIcon(
        id: 'pickup',
        position: pickup,
        title: loc.pickupLocation,
        snippet: booking.pickupAddress,
      );
    }
  }

  Future<void> _addMarkerWithCustomIcon({
    required String id,
    required LatLng position,
    required String title,
    String? snippet,
  }) async {
    final icon = await _getPinIcon();

    if (mounted) {
      setState(() {
        _markers = Set<Marker>.from(_markers)
          ..add(
            Marker(
              markerId: MarkerId(id),
              position: position,
              infoWindow: InfoWindow(
                title: title,
                // Google Maps drops an empty snippet rather than reserving a
                // blank second line, so an address it does not have simply
                // leaves the window one line tall.
                snippet: _cleaned(snippet),
              ),
              icon: icon,
            ),
          );
        _publishMarkers();
      });

    }
  }

  /// The pin marking the pickup and the drop-off.
  ///
  /// Replaces a pin this screen used to draw onto a canvas by hand, so the
  /// artwork now lives with the rest of the app's images rather than in forty
  /// lines of bezier curves.
  Future<BitmapDescriptor> _getPinIcon() async {
    final cached = _pinIcon;
    if (cached != null) return cached;

    try {
      final ByteData data = await rootBundle.load(_pinAsset);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: _pinTargetWidth,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? bytes = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      // Decoded at twice the width it is drawn at, so it stays sharp on a 2x
      // screen while taking up the same room on the map as the pin it replaces.
      _pinIcon = BitmapDescriptor.bytes(
        bytes!.buffer.asUint8List(),
        imagePixelRatio: 2,
      );
    } catch (e) {
      // A missing asset is a build problem, not a runtime one — fall back to
      // something visible rather than dropping the marker altogether.
      _pinIcon = BitmapDescriptor.defaultMarker;
    }

    return _pinIcon!;
  }

  /// The route: one black line.
  ///
  /// Replaces four stacked translucent polylines that faked a glow for the old
  /// dark map. On the default light map a plain dark line is both what reads
  /// best and a quarter of the geometry to push across the platform channel
  /// every time the route is redrawn.
  void _addRoutePolyline(List<LatLng> points) {
    _drawnPoints = points;
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: Colors.black,
        width: _routeWidth,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  /// Line width, in screen pixels, for the current zoom.
  ///
  /// [Polyline.width] is a *screen* measurement and does not scale with the
  /// map, so a width chosen to sit nicely over a street at zoom 17 stays that
  /// many pixels wide at zoom 10 — by which point the roads beneath it have
  /// shrunk to hairlines and the route reads as a fat black smear across the
  /// city. Thinning it as the map pulls back keeps it proportional to what it
  /// is drawn over.
  static int _routeWidthFor(double zoom) {
    if (zoom >= 16) return 6;
    if (zoom >= 14) return 4;
    if (zoom >= 11) return 3;
    return 2;
  }

  /// Re-draw the route if this zoom calls for a different width.
  ///
  /// Called from `onCameraMove`, which fires every frame of a pinch — so the
  /// width is bucketed and the polyline is rebuilt only when the bucket
  /// actually changes, not sixty times a second.
  void _applyZoom(double zoom) {
    final width = _routeWidthFor(zoom);
    if (width == _routeWidth) return;

    setState(() {
      _routeWidth = width;
      if (_drawnPoints.isNotEmpty) _addRoutePolyline(_drawnPoints);
    });
  }

  // --- RTDB Listeners ---

  void _listenToDriverLocation() {
    _locationSubscription = DriverLocationService()
        .watchPing(widget.booking.id)
        .listen((ping) {
          if (!mounted) return;

          final position = ping.position;
          final previous = _driverLocation;

          // A heartbeat republishes the same spot to prove the feed is alive.
          // It refreshes the clock but must not restart the animation, which
          // would jiggle a parked car.
          final moved =
              previous == null ||
              Geolocator.distanceBetween(
                    previous.latitude,
                    previous.longitude,
                    position.latitude,
                    position.longitude,
                  ) >
                  1;

          setState(() {
            _lastPingAt = ping.timestamp ?? DateTime.now();
            _feedIsStale = false;
            _driverLocation = position;
            // First fix: this is where the map gets built, already looking at
            // the car. Anything later leaves it alone — the camera follows by
            // animation from here, not by re-creating the map.
            if (_mapOpenTarget == null) {
              _mapOpenTarget = position;
              _mapOpenZoom = _driverFocusZoom;
              _hasCentredOnDriver = true;
              _openFallbackTimer?.cancel();
            }
          });

          if (moved) {
            _animateMarkerTo(position, from: previous);
          } else if (_renderedDriverLocation == null) {
            // First fix of the session, with nothing to animate from.
            _renderedDriverLocation = position;
            _updateDriverMarker();
          }

          _moveCameraToDriver();

          if (_shouldRefetchRoute(position)) _fetchDirections();
        });
  }

  /// Whether the route is worth re-requesting for this fix.
  ///
  /// Two triggers, because either alone leaves a case wrong: distance catches a
  /// car making progress, and the clock catches one sitting in traffic whose
  /// ETA is still rising while it barely moves.
  bool _shouldRefetchRoute(LatLng position) {
    final last = _lastFetchLocation;
    if (last == null) return true;

    final moved = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      position.latitude,
      position.longitude,
    );
    if (moved >= _rerouteDistanceMeters) return true;

    final at = _lastFetchAt;
    return at == null ||
        DateTime.now().difference(at) >= _routeRefreshInterval;
  }

  /// Redraw the route on a clock as well as on movement.
  void _startRouteRefreshTimer() {
    _routeRefreshTimer?.cancel();
    _routeRefreshTimer = Timer.periodic(_routeRefreshInterval, (_) {
      if (!mounted || _tripEnded || _driverLocation == null) return;
      _fetchDirections();
    });
  }

  /// Open the map on the booking if no driver fix turns up in time.
  ///
  /// The pickup is read through [_pickupPoint], which falls back to the
  /// airport's own position and then to the address lookup, and is used only
  /// when it is a real coordinate — a `0,0` from the payload is the Atlantic,
  /// not a location, and is exactly what used to open this screen on blank
  /// water.
  void _startOpenFallbackTimer() {
    _openFallbackTimer?.cancel();
    _openFallbackTimer = Timer(_openWithoutDriverAfter, () {
      if (!mounted || _mapOpenTarget != null) return;

      final pickup = _pickupPoint;

      logScreen(
        _log,
        'no driver fix in ${_openWithoutDriverAfter.inSeconds}s — opening on '
        '${pickup != null ? 'the pickup' : 'the default city'}',
      );

      setState(() {
        _mapOpenTarget =
            pickup ??
            // Riyadh, so the map opens on the country it serves rather than
            // on nothing at all.
            const LatLng(24.7136, 46.6753);
        _mapOpenZoom = 13;
      });
    });
  }

  /// Watch the gap since the last publish, so a feed that stops is called out
  /// rather than leaving a car frozen on the map with no explanation.
  void _startFreshnessTimer() {
    _freshnessTimer?.cancel();
    _freshnessTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || _tripEnded) return;

      final at = _lastPingAt;
      final stale = at != null && DateTime.now().difference(at) > _staleAfter;
      if (stale != _feedIsStale) setState(() => _feedIsStale = stale);
    });
  }

  // --- Marker animation ---

  /// Move the marker to [to], following the drawn route where it can.
  ///
  /// Two modes. With a usable route the car travels *along the line* — the
  /// animation interpolates distance-along rather than latitude and longitude,
  /// so it takes the bends instead of cutting the corner, and its heading comes
  /// from whichever segment it is on at that instant. That is what makes it
  /// turn with the road. Without a route — hourly hire, or before the first
  /// Directions response — it falls back to a straight line between fixes.
  void _animateMarkerTo(LatLng to, {LatLng? from}) {
    final origin = from ?? _renderedDriverLocation;
    final toAlong = _alongRoute(to);

    if (toAlong != null) {
      final fromAlong =
          _renderedAlong ?? (origin == null ? null : _alongRoute(origin)) ?? 0;

      _animFromAlong = fromAlong;
      _animToAlong = toAlong;
      _animFrom = null;
      _animTo = null;

      // The line is *not* re-trimmed here. It was, to drop the length already
      // driven — but that copied the whole route and pushed every point across
      // the platform channel on each fix, and a cross-city route is tens of
      // thousands of points. That rebuild was the second half of the stutter.
      // The route is re-requested from the driver's own position every 120m
      // anyway, so the untrimmed tail behind the car is short-lived and costs
      // nothing to leave.
      _markerController
        ..reset()
        ..forward();
      return;
    }

    // Off-route, or no route at all.
    _animFromAlong = null;
    _animToAlong = null;

    if (origin == null) {
      _renderedDriverLocation = to;
      _updateDriverMarker();
      return;
    }

    _animFrom = origin;
    _animTo = to;

    // Only re-aim on a move big enough to mean something. Two fixes a couple of
    // metres apart are GPS scatter, not a direction, and taking a heading from
    // them spins the car to an arbitrary angle while it sits still — which is
    // how it ended up pointing north-ish on a north-east road.
    final gap = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      to.latitude,
      to.longitude,
    );
    if (gap >= _minBearingMeters) {
      _driverBearing = _compassBearing(origin, to);
    }

    _markerController
      ..reset()
      ..forward();
  }

  /// One frame of the car's movement.
  ///
  /// Runs sixty times a second, so it does **no** [setState]: it writes the
  /// fields and calls [_updateDriverMarker], which pushes the new marker into
  /// [_mapMarkers]. Only the map is subscribed to that, so a frame costs one
  /// small widget rebuild instead of rebuilding the whole screen.
  void _onMarkerTick() {
    if (!mounted) return;

    final fromAlong = _animFromAlong;
    final toAlong = _animToAlong;
    final t = _markerController.value;

    // Route mode: interpolate the distance travelled, then read the position
    // and heading off the line at that distance.
    if (fromAlong != null && toAlong != null) {
      final along = fromAlong + (toAlong - fromAlong) * t;
      final at = _pointAlong(along);
      if (at == null) return;

      _renderedAlong = along;
      _renderedDriverLocation = at.position;
      _driverBearing = at.bearing;
      _updateDriverMarker();
      return;
    }

    final from = _animFrom;
    final to = _animTo;
    if (from == null || to == null) return;

    _renderedDriverLocation = LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
    _updateDriverMarker();
  }

  // --- Route geometry ---

  /// Adopt [points] as the route and measure it.
  ///
  /// The cumulative table is built once here rather than per frame, since the
  /// animation reads it sixty times a second.
  void _setRoute(List<LatLng> points) {
    _routePoints = _thin(points);
    // The old hint indexes a line that no longer exists.
    _segmentHint = 0;

    final cumulative = List<double>.filled(_routePoints.length, 0);
    for (var i = 1; i < _routePoints.length; i++) {
      cumulative[i] =
          cumulative[i - 1] +
          Geolocator.distanceBetween(
            _routePoints[i - 1].latitude,
            _routePoints[i - 1].longitude,
            _routePoints[i].latitude,
            _routePoints[i].longitude,
          );
    }
    _routeCumulative = cumulative;

    // Every route is requested from the driver's own position, so the car is at
    // the start of the new line — but it may still be animating towards the fix
    // that line was built from, so its actual offset is measured rather than
    // assumed to be zero.
    final at = _renderedDriverLocation ?? _driverLocation;
    _renderedAlong = at == null ? 0 : (_alongRoute(at) ?? 0);

    // Point the car down the new road straight away. Waiting for the next
    // animation tick means waiting for the next published fix — up to 50m of
    // driving — during which the car sits at whatever heading it last had, or
    // at due north if this is the first route of the session.
    final at0 = _pointAlong(_renderedAlong ?? 0);
    if (at0 != null) {
      _renderedDriverLocation = at0.position;
      _driverBearing = at0.bearing;
      // A Marker is immutable, so moving the heading is not enough — the one
      // already in `_markers` keeps whatever rotation it was built with. Every
      // other place that changes the bearing rebuilds it; this one has to as
      // well, or the car keeps the north it was created pointing at until the
      // next published fix happens to redraw it.
      _updateDriverMarker();
    }
  }

  /// Drop points closer together than a metre.
  ///
  /// Two reasons, and the first is the one that was turning the car the wrong
  /// way. The route is assembled from each step's own polyline, and every step
  /// begins on the point the previous one ended on — so the joined line carries
  /// a duplicated vertex at every turn. A duplicated vertex is a zero-length
  /// segment, a zero-length segment has no direction, and asking
  /// [Geolocator.bearingBetween] for one returns 0 — due north. The car
  /// therefore snapped north at exactly the moments a turn made it most
  /// visible. Sub-metre segments are noise for the same reason: their heading
  /// is dominated by rounding rather than by the road.
  ///
  /// The second reason is cheaper: fewer points to measure, search and draw.
  static List<LatLng> _thin(List<LatLng> points) {
    if (points.length < 2) return points;

    final thinned = <LatLng>[points.first];
    for (final point in points.skip(1)) {
      final last = thinned.last;
      final gap = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        point.latitude,
        point.longitude,
      );
      if (gap >= 1) thinned.add(point);
    }

    // Keep the true end even if it sat within a metre of the point before it,
    // so the line still reaches the destination.
    if (thinned.last != points.last) thinned.add(points.last);
    return thinned;
  }

  /// How far along the route the point nearest [p] lies, or null when [p] is
  /// further from the line than [_maxSnapMeters].
  double? _alongRoute(LatLng p) {
    if (_routePoints.length < 2) return null;

    var bestDistance = double.infinity;
    var bestAlong = 0.0;

    for (var i = 0; i < _routePoints.length - 1; i++) {
      final a = _routePoints[i];
      final b = _routePoints[i + 1];
      final t = _projectionFactor(a, b, p);

      final projected = LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
      final distance = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        projected.latitude,
        projected.longitude,
      );

      if (distance < bestDistance) {
        bestDistance = distance;
        bestAlong =
            _routeCumulative[i] +
            (_routeCumulative[i + 1] - _routeCumulative[i]) * t;
      }
    }

    return bestDistance <= _maxSnapMeters ? bestAlong : null;
  }

  /// Where [p] falls on the segment `a`–`b`, as a fraction clamped to it.
  ///
  /// Degrees are converted to metres first — a degree of longitude is a good
  /// deal shorter than one of latitude at Saudi latitudes, and projecting in
  /// raw degrees would bias every result eastward.
  static double _projectionFactor(LatLng a, LatLng b, LatLng p) {
    final metresPerLng =
        111320.0 * math.cos((a.latitude + b.latitude) / 2 * math.pi / 180);

    final bx = (b.longitude - a.longitude) * metresPerLng;
    final by = (b.latitude - a.latitude) * _metresPerLat;
    final px = (p.longitude - a.longitude) * metresPerLng;
    final py = (p.latitude - a.latitude) * _metresPerLat;

    final lengthSquared = bx * bx + by * by;
    // A zero-length segment: the polyline repeats a point where two steps meet.
    if (lengthSquared == 0) return 0;

    return ((px * bx + py * by) / lengthSquared).clamp(0.0, 1.0);
  }

  /// The position and heading at [along] metres into the route.
  ({LatLng position, double bearing})? _pointAlong(double along) {
    if (_routePoints.length < 2) return null;

    final total = _routeCumulative.last;
    final target = along.clamp(0.0, total);

    // Resume the search from the segment last used rather than from the start.
    // The car only ever moves forward along the route, so this is one or two
    // steps per frame instead of a scan of the whole line — which on a
    // cross-city route is tens of thousands of points, sixty times a second.
    var i = _segmentHint;
    if (i >= _routeCumulative.length - 1 || _routeCumulative[i] > target) i = 0;
    while (i < _routeCumulative.length - 2 && _routeCumulative[i + 1] < target) {
      i++;
    }
    _segmentHint = i;

    final segmentStart = _routeCumulative[i];
    final segmentEnd = _routeCumulative[i + 1];
    final span = segmentEnd - segmentStart;
    final t = span > 0 ? (target - segmentStart) / span : 0.0;

    final a = _routePoints[i];
    final b = _routePoints[i + 1];

    return (
      position: LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      ),
      // The heading of the segment being driven, which is what turns the car
      // through a bend as it reaches it.
      bearing: _compassBearing(a, b),
    );
  }

  /// Heading from [a] to [b] as degrees clockwise from north, 0–360.
  ///
  /// [Geolocator.bearingBetween] answers in −180…180, which is the same angle
  /// but is not what [Marker.rotation] documents itself as taking.
  static double _compassBearing(LatLng a, LatLng b) {
    final bearing = Geolocator.bearingBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    return (bearing + 360) % 360;
  }

  /// The route from [along] onwards, headed by the exact point at that
  /// distance so the line starts under the car rather than at the next vertex.
  List<LatLng> _routeFrom(double along) {
    if (_routePoints.length < 2) return _routePoints;

    final head = _pointAlong(along);
    if (head == null) return _routePoints;

    return [
      head.position,
      for (var i = 0; i < _routePoints.length; i++)
        if (_routeCumulative[i] > along) _routePoints[i],
    ];
  }

  /// Follow the session for both of the things it decides: which leg is being
  /// driven, and whether the ride is still running.
  ///
  /// Subscribed to for every booking, not only chauffeur hire — the leg change
  /// when the driver starts the trip is what moves the map from the pickup to
  /// the drop-off, and every ride has one.
  void _listenToSession() {
    _sessionSubscription = DriverLocationService()
        .watchSession(widget.booking.id)
        .listen((session) {
          if (!mounted) return;

          if (session.phase != _phase) {
            // The destination moved, so the drawn route and the destination pin
            // are both now the wrong ones. `_initStaticMarkersAndPolylines`
            // re-requests the route itself once the markers are back, so it is
            // not called again here — doing both fired two identical Directions
            // requests for every leg change.
            setState(() {
              _phase = session.phase;
              _restaleRoute();
            });
            _initStaticMarkersAndPolylines();
            // Re-fit, because the leg the customer is watching just changed and
            // the new destination is very likely off screen.
            _hasCentredOnDriver = false;
            _followDriver = true;
            // The leg change has overridden whatever the customer had done to
            // the camera, so the pan that turned following off is spent. Left
            // set, it would keep claiming a gesture is outstanding long after
            // the view it applied to was replaced.
            _followSuspendedByGesture = false;
            _cancelFollowResume();
            _logCamera('leg changed — following again');
          }

          if (_isChauffeur &&
              session.startedAt != null &&
              _chauffeurStartTime == null) {
            _chauffeurStartTime = session.startedAt;
            _startChauffeurTimer();
          }

          if (!session.isActive && !_tripEnded) {
            _endTracking();
          }
        });
  }

  /// The ride is over: stop following the driver and clear the route.
  ///
  /// The map is left on screen showing where things ended rather than being
  /// popped out from under the customer, but nothing on it is live any more.
  void _endTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _chauffeurTimer?.cancel();
    _routeRefreshTimer?.cancel();
    _freshnessTimer?.cancel();
    _directionsRetryTimer?.cancel();
    // A pan in the last few seconds of the ride leaves this armed; there is no
    // longer a moving car to go back to.
    _cancelFollowResume();
    // Otherwise the marker keeps sliding towards a fix that is now final.
    _markerController.stop();

    setState(() {
      _tripEnded = true;
      _polylines = {};
      _currentEta = null;
      _currentDistance = null;
      // The feed is meant to have stopped now, so the stale banner would be
      // telling the customer something is wrong when nothing is.
      _feedIsStale = false;
    });
  }

  /// Forget the route drawn for the previous leg, so the next fix redraws
  /// rather than waiting out the movement threshold.
  ///
  /// Callers hold the [setState]; this only writes the fields.
  void _restaleRoute() {
    _lastFetchLocation = null;
    _lastFetchAt = null;
    _directionsFailures = 0;
    _directionsRetryTimer?.cancel();
    _polylines = {};
    _markers = {};
    _publishMarkers();
    _currentEta = null;
    _currentDistance = null;
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

  /// The car drawn at the driver's position.
  ///
  /// A top-down car, whose nose points north in the artwork — which is what
  /// makes [Marker.rotation] usable directly: a bearing of 0 leaves it facing
  /// up, and every other bearing turns it to match.
  Future<void> _loadDriverIcon() async {
    if (_driverIcon != null) return;
    try {
      final ByteData data = await rootBundle.load(_carAsset);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: _carTargetWidth,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ByteData? byteData = await fi.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      // Decoded at twice the width it is drawn at, so it stays sharp on a 2x
      // screen — the source art is far larger than a marker needs.
      _driverIcon = BitmapDescriptor.bytes(
        byteData!.buffer.asUint8List(),
        imagePixelRatio: 2,
      );
    } catch (e) {
      _driverIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueOrange,
      );
    }
    if (mounted && _driverLocation != null) {
      _updateDriverMarker();
    }
  }

  void _updateDriverMarker() {
    final drawAt = _renderedDriverLocation ?? _driverLocation;
    if (drawAt == null) return;
    if (!mounted) return;

    // The driver by name, so tapping the car answers "who is coming for me".
    // Falls back to the generic word while the booking has no driver populated.
    final markerTitle =
        _cleaned(widget.booking.driver?.name) ??
        AppLocalizations.of(context)!.driverMarkerTitle;

    final newMarkers = Set<Marker>.from(_markers);
    newMarkers.removeWhere((m) => m.markerId.value == 'driver');
    newMarkers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: drawAt,
        icon:
            _driverIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        anchor: const Offset(0.5, 0.5),
        // Point the car the way it is going. Flat keeps the rotation in the
        // map's plane, so it reads as a vehicle heading somewhere rather than
        // a pin tipped over.
        rotation: _driverBearing,
        flat: true,
        infoWindow: InfoWindow(
          title: markerTitle,
          snippet: _cleaned(_vehicleLine),
        ),
      ),
    );
    _markers = newMarkers;
    _publishMarkers();
  }

  /// Hand the current markers to the map.
  ///
  /// Call after every change to [_markers]; it is what makes the change
  /// visible, and it is deliberately not a [setState] — see [_mapMarkers].
  void _publishMarkers() => _mapMarkers.value = _markers;

  /// Keep the camera on the car as it moves.
  ///
  /// Never changes the zoom except once, on the first fix of a leg, to settle
  /// on a street-level view. Every later fix is a plain re-centre, so whatever
  /// the customer has pinched to is preserved.
  ///
  /// This used to fit the driver and the destination into view instead. On a
  /// cross-city booking those are hundreds of kilometres apart, so "fit both"
  /// meant zooming out to country scale — which is what looked like the map
  /// throwing itself away every time a position arrived.
  /// The controller to drive the camera with.
  ///
  /// Waits for the map to exist, then hands back the *current* controller
  /// rather than the one that first arrived — see [_liveController].
  Future<GoogleMapController> _camera() async {
    await _controller.future;
    return _liveController ?? await _controller.future;
  }

  Future<void> _moveCameraToDriver() async {
    if (!_mapLayoutReady || _driverLocation == null) {
      _logCamera(
        'waiting — layout=${_mapLayoutReady ? 'ready' : 'pending'} '
        'fix=${_driverLocation == null ? 'none' : 'have'}',
      );
      return;
    }

    // The customer has taken the map over; leave it where they put it. Without
    // this, every fix dragged the view back to the car and made it impossible
    // to look ahead at the route or the drop-off.
    if (!_followDriver) {
      _logCamera(
        'held — following off '
        '(gesture=$_followSuspendedByGesture, '
        'resume=${_followResumeTimer == null ? 'unarmed' : 'armed'})',
      );
      return;
    }

    final isFirst = !_hasCentredOnDriver;
    _hasCentredOnDriver = true;

    final controller = await _camera();
    try {
      await controller.animateCamera(
        isFirst
            ? CameraUpdate.newLatLngZoom(_driverLocation!, _driverFocusZoom)
            : CameraUpdate.newLatLng(_driverLocation!),
      );
      _logCamera(isFirst ? 'following (first fix, zoom in)' : 'following');
    } catch (e) {
      // Was silently swallowed, which made a camera that never moved
      // indistinguishable from one that was never asked to.
      _logCamera('animateCamera failed — $e');
    }
  }

  /// Drop any pending auto-resume.
  ///
  /// Called wherever the customer has just said what they want the camera to
  /// do — the recentre button, the route button, the locate button — so a timer
  /// armed by an earlier pan cannot fire on top of that a moment later.
  void _cancelFollowResume() {
    // Only worth a line when something was actually pending. This is called
    // from `onCameraMove` too, which runs every frame of a pan.
    if (_followResumeTimer != null) _logCamera('resume cancelled');
    _followResumeTimer?.cancel();
    _followResumeTimer = null;
  }

  /// One deduplicated line about what the camera is doing and why.
  ///
  /// Deduplicated because the interesting calls sit on the position feed, which
  /// publishes every 50m: "following" said once and then nothing is the shape
  /// of a camera that is working, and any change of mind shows up as the next
  /// line. Repeating it every fix would bury exactly that.
  void _logCamera(String state) {
    if (state == _lastCameraLog) return;
    _lastCameraLog = state;
    logScreenDetail(_log, 'camera │ $state');
  }

  /// Arm the return to the car.
  ///
  /// Driven by [GoogleMap.onCameraIdle], which the map fires once the camera
  /// has stopped, no animation is pending *and* the customer has taken their
  /// hands off it. That is the whole of "the pan is over" in one callback — the
  /// finger lifting and the fling coasting to a halt included — so the five
  /// seconds is measured from the map genuinely coming to rest.
  ///
  /// This deliberately does not count pointers on a [Listener] instead. The map
  /// is a platform view: it consumes the touches it handles, so a pointer-up
  /// need not surface on the Flutter side, and a lift missed that way would
  /// leave the resume permanently unarmed. The map's own account of what it is
  /// doing cannot go missing like that.
  void _scheduleFollowResume() {
    _followResumeTimer?.cancel();
    _followResumeTimer = null;

    // Already following, or the camera was put here by a button rather than by
    // hand — neither is something to undo.
    if (_followDriver || !_followSuspendedByGesture) return;
    // Nothing left to go back to.
    if (_tripEnded || _driverLocation == null) {
      _logCamera(
        'idle, nothing to resume to '
        '(ended=$_tripEnded, fix=${_driverLocation == null ? 'none' : 'have'})',
      );
      return;
    }

    _logCamera('map at rest — resuming in ${_resumeFollowAfter.inSeconds}s');
    _followResumeTimer = Timer(_resumeFollowAfter, () {
      if (!mounted) return;
      if (_followDriver || !_followSuspendedByGesture) return;
      if (_tripEnded || _driverLocation == null) return;
      _logCamera('resume firing');
      _recentreOnDriver();
    });
  }

  /// Resume following, and bring the camera back onto the car.
  ///
  /// Zooms in as well as re-centring: the customer reaches for this after
  /// panning or pinching out to see the whole route, so restoring the position
  /// without the zoom would leave them looking at a car three streets wide.
  ///
  /// Also where the map lands on its own once it has been left alone for
  /// [_resumeFollowAfter], so a hands-off return is the same view as a tapped
  /// one rather than a second, subtly different one.
  Future<void> _recentreOnDriver() async {
    _cancelFollowResume();
    _followSuspendedByGesture = false;
    _logCamera('recentring on the car');
    setState(() => _followDriver = true);

    final target = _renderedDriverLocation ?? _driverLocation;
    if (target == null || !_mapLayoutReady) return;

    final controller = await _camera();
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(target, _driverFocusZoom),
      );
    } catch (e) {}
  }

  /// Frame the whole journey — the route, the car and the destination pin.
  ///
  /// The only thing on this screen that zooms out, and it does so only when
  /// asked. Fitting on its own used to run off every position update, which on
  /// a cross-city booking threw the map out to province scale each time a fix
  /// arrived; as a button it is the same view, offered rather than imposed.
  ///
  /// Bounds come from the route's own points as well as the markers, so a road
  /// that bows well outside the straight line between the two ends is still
  /// framed whole.
  Future<void> _showFullRoute() async {
    if (!_mapLayoutReady) return;

    final points = <LatLng>[
      ..._routePoints,
      for (final marker in _markers) marker.position,
    ];
    if (points.isEmpty) return;

    // Same reasoning as the locate button: this is the customer choosing a
    // view, so the next fix must not drag the camera off it — and neither must
    // the auto-resume, which is why this is not marked as a gesture.
    _cancelFollowResume();
    _followSuspendedByGesture = false;
    _logCamera('showing the full route');
    setState(() => _followDriver = false);

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final controller = await _camera();
    try {
      // Degenerate bounds — everything on one spot — is not something
      // `newLatLngBounds` can frame, so it gets a plain zoom instead.
      if (minLat == maxLat && minLng == maxLng) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, _driverFocusZoom),
        );
      } else {
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            ),
            60,
          ),
        );
      }
    } catch (e) {}
  }

  /// Move the camera to the customer's own position.
  ///
  /// Stops following the driver, because this is the customer taking the
  /// camera somewhere of their own — exactly what a pan is. The button sits
  /// above the map in the stack, so its tap never reaches the [Listener] that
  /// normally notices that; saying so here is what makes the recentre button
  /// appear to undo this, and what stops the next driver fix from dragging the
  /// camera straight back off the customer's own position.
  Future<void> _goToCustomerLocation() async {
    if (_isLocatingCustomer) return;
    _cancelFollowResume();
    _followSuspendedByGesture = false;
    _logCamera('going to the customer');
    setState(() {
      _isLocatingCustomer = true;
      _followDriver = false;
    });

    try {
      // `myLocationEnabled` draws the blue dot but hands us no coordinate, so
      // the fix is read directly. Bounded, because a cold GPS start under a
      // roof can otherwise hang for a long time.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;

      final controller = await _camera();
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          _customerFocusZoom,
        ),
      );
    } catch (e) {
      if (mounted) {
        AnimatedSnackBar.show(
          context,
          AppLocalizations.of(context)!.somethingWentWrong,
          'E',
        );
      }
    } finally {
      if (mounted) setState(() => _isLocatingCustomer = false);
    }
  }


  // --- Directions API ---

  /// Where the current leg is headed, as a `lat,lng` pair, or null when there
  /// is nowhere to route to.
  String? _legDestination() {
    final point = _phase == TrackingPhase.toDropOff
        ? _dropOffPoint
        : (_phase.hasDestination ? _pickupPoint : null);

    return point == null ? null : '${point.latitude},${point.longitude}';
  }

  /// Route the leg being driven: the car to the pickup, or the car to the
  /// drop-off.
  ///
  /// One leg, never both. Routing driver → pickup → drop-off in a single
  /// request, as this used to, drew the whole journey at once and left the
  /// customer reading a line through a place the car had already been.
  Future<void> _fetchDirections() async {
    if (_tripEnded) return;

    final destination = _legDestination();
    // Hourly hire once under way has nowhere to route to; the car is still
    // live on the map, there is simply no line to draw. The other two reasons
    // are faults, so all three are named rather than returning in silence.
    if (destination == null || _driverLocation == null) {
      logScreen(
        _log,
        'no route: ${destination == null ? 'no destination for ${_phase.wireValue}' : 'no driver fix yet'}',
      );
      return;
    }

    final seq = ++_fetchDirectionsSeq;
    final origin = '${_driverLocation!.latitude},${_driverLocation!.longitude}';

    final apiKey =
        dotenv.env['GOOGLE_MAPS_API_KEY'] ?? dotenv.env['MAPS_API_KEY'] ?? '';
    if (apiKey.isEmpty) return;

    _lastFetchLocation = _driverLocation;
    _lastFetchAt = DateTime.now();

    try {
      final url =
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$origin&destination=$destination'
          // Asks for a live estimate rather than a free-flow one. With no
          // departure_time the API returns the drive as if the roads were
          // empty, which on a Riyadh evening understates the arrival badly;
          // with it, each leg also carries duration_in_traffic.
          '&departure_time=now&traffic_model=best_guess&mode=driving'
          '&key=$apiKey';
      final response = await Dio().get(
        url,
        options: Options(
          connectTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      final status = response.data['status'];
      if (response.statusCode != 200 || status != 'OK') {
        logScreen(
          _log,
          'directions ${response.statusCode} $status — '
          '${response.data['error_message'] ?? 'no error_message'}',
        );
        // ZERO_RESULTS is an answer, not a fault: there is no drivable route,
        // and retrying will not invent one.
        _onDirectionsFailure(retryable: status != 'ZERO_RESULTS');
        return;
      }

      final routes = response.data['routes'] as List;
      if (routes.isEmpty) {
        _onDirectionsFailure(retryable: false);
        return;
      }

      // One leg is requested, so one leg is summed — the distance and ETA are
      // for where the car is going now, not for the whole journey.
      final legs = routes.first['legs'] as List;
      int dist = 0, dur = 0;
      for (final leg in legs) {
        dist += (leg['distance']['value'] as num).toInt();
        // duration_in_traffic is only returned when the key is enabled for it
        // and the request asked for a departure time; fall back to the
        // free-flow duration rather than showing nothing.
        final traffic = leg['duration_in_traffic']?['value'] as num?;
        dur += (traffic ?? leg['duration']['value'] as num).toInt();
      }

      final List<LatLng> polyPoints = [];
      for (final leg in legs) {
        for (final step in (leg['steps'] as List)) {
          polyPoints.addAll(_decodePolyline(step['polyline']['points']));
        }
      }

      logScreen(
        _log,
        'route ${_phase.wireValue}: ${polyPoints.length} points, '
        '${(dist / 1000).toStringAsFixed(1)} km, ${(dur / 60).ceil()} min',
      );

      if (mounted && seq == _fetchDirectionsSeq) {
        _directionsFailures = 0;
        _directionsRetryTimer?.cancel();
        setState(() {
          _setRoute(polyPoints);
          _polylines = {};
          _addRoutePolyline(_routeFrom(_renderedAlong ?? 0));
          _currentDistance = (dist / 1000).toStringAsFixed(1);
          _currentEta = _formatEta(dur);
        });
      }
    } catch (_) {
      _onDirectionsFailure(retryable: true);
    }
  }

  /// Render a duration in seconds as the ETA text, in the app's language.
  String _formatEta(int seconds) {
    final loc = AppLocalizations.of(context)!;
    // Rounded up: a route 30 seconds out reads better as "1 min" than as "0".
    final mins = (seconds / 60).ceil();
    if (mins < 60) return loc.etaMinutes(mins);
    return loc.etaHoursMinutes(mins ~/ 60, mins % 60);
  }

  /// A Directions request came back unusable.
  ///
  /// The previous route and ETA are deliberately left on screen: a stale line
  /// is closer to the truth than an empty map, and the car is still live
  /// regardless. [retryable] failures back off — 4s, 8s, 16s, capped — so a
  /// blocked key or a flapping connection cannot spin the quota.
  void _onDirectionsFailure({required bool retryable}) {
    if (!mounted || !retryable) return;

    _directionsFailures++;
    // Movement or the refresh timer will ask again on its own by now.
    if (_directionsFailures > 4) return;

    final backoff = Duration(seconds: 2 << _directionsFailures);
    _directionsRetryTimer?.cancel();
    _directionsRetryTimer = Timer(backoff, () {
      if (!mounted || _tripEnded) return;
      // Force the next attempt past the movement gate.
      _lastFetchAt = null;
      _fetchDirections();
    });
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
        AnimatedSnackBar.show(
          context,
          AppLocalizations.of(context)!.cannotMakePhoneCalls,
          'E',
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
        // Dark on light, since the bar floats over the map and the map is now
        // Google's light one — the white these used to be is invisible on it.
        // The status-bar icons have to flip with them for the same reason.
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.trackYourDriver,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          // A touch on the map is the one unambiguous signal that the customer
          // wants to drive the camera themselves. `onCameraMoveStarted` cannot
          // be used for this: it fires for our own `animateCamera` calls too,
          // so following would switch itself off on the first fix.
          // Under the map until it has faded in, then dropped.
          if (!_mapRevealed) const Positioned.fill(child: _MapSkeleton()),

          if (_mapOpenTarget != null)
          Listener(
            onPointerDown: (_) {
              _cancelFollowResume();
              // Marked as a gesture even when following is already off, so a
              // pan made after the route or locate button still earns the
              // hands-off return that those buttons deliberately do not.
              _followSuspendedByGesture = true;
              if (_followDriver) {
                _logCamera('customer took the map');
                setState(() => _followDriver = false);
              }
            },
            // Only this subtree rebuilds when the car moves. The map keeps its
            // own texture and camera across a rebuild — the plugin diffs the
            // marker set and sends just what changed — so the car slides while
            // everything else on screen stays untouched.
            // Fades up over the skeleton once the platform view has laid out,
            // so the map appears already settled on the car instead of
            // snapping in mid-render.
            child: AnimatedOpacity(
              opacity: _mapLayoutReady ? 1 : 0,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
              onEnd: () {
                if (mounted && _mapLayoutReady && !_mapRevealed) {
                  setState(() => _mapRevealed = true);
                }
              },
              child: ValueListenableBuilder<Set<Marker>>(
              valueListenable: _mapMarkers,
              builder: (context, markers, _) => GoogleMap(
                // Built only once there is somewhere to look, so this is the
                // car's own position — the map opens on it rather than
                // travelling there.
                initialCameraPosition: CameraPosition(
                  target: _mapOpenTarget!,
                  zoom: _mapOpenZoom,
                ),
                // No `style`: Google's default light map. The dark style this
                // used to carry buried the route and the pins in a near-black
                // ground.
                onMapCreated: (c) {
                  _liveController = c;
                  // `complete` throws if called twice, which a rebuilt platform
                  // view would do — and the throw happens inside a plugin
                  // callback, where it takes the rest of this handler with it.
                  if (!_controller.isCompleted) {
                    _controller.complete(c);
                  } else {
                    logScreen(_log, 'map view rebuilt — controller replaced');
                  }
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      setState(() {
                        _mapLayoutReady = true;
                      });
                      // No fit here either — the map opens on the pickup at
                      // the zoom above and stays there until the first driver
                      // fix centres it. Fitting would have pulled straight
                      // back out to take in a destination that may be a
                      // province away.
                      _moveCameraToDriver();
                    }
                  });
                },
                onCameraMove: (position) {
                  _applyZoom(position.zoom);
                  // Moving again — whatever was armed was armed for a map that
                  // has since been picked back up.
                  _cancelFollowResume();
                },
                // The map has come to rest with nobody touching it. Everything
                // that decides whether that should return the camera to the car
                // lives in [_scheduleFollowResume]; this also fires at the end
                // of the page's own animations, which those guards ignore.
                onCameraIdle: _scheduleFollowResume,
                markers: markers,
                polylines: _polylines,
                // Shows the customer's own position alongside the driver's,
                // once they have granted permission.
                myLocationEnabled: _locationPermissionGranted,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
              ),
            ),
          ),

          // Map controls, stacked above the driver card on the trailing edge.
          // Directional, so they sit on the left in Arabic without a second
          // layout — and clear of the card below either way.
          PositionedDirectional(
            start: 20,
            end: 20,
            bottom: 190,
            child: Row(
              children: [
                // The two icon buttons are equal-width slots on either side, so
                // the recentre pill between them lands on the screen's centre
                // line rather than the middle of whatever is left over.
                SizedBox(
                  width: _mapControlSize,
                  child: _routePoints.isEmpty
                      ? null
                      : _MapControl(
                          icon: Icons.route,
                          tooltip: loc.showFullRoute,
                          onTap: _showFullRoute,
                        ),
                ),
                Expanded(
                  child: Center(
                    // Offered only once the customer has taken the map over, so
                    // it does not sit there implying the view has drifted when
                    // it has not.
                    child:
                        (!_followDriver &&
                            !_tripEnded &&
                            _driverLocation != null)
                        ? _MapControl(
                            label: loc.recenterMap,
                            icon: Icons.navigation_rounded,
                            onTap: _recentreOnDriver,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                SizedBox(
                  width: _mapControlSize,
                  child: _locationPermissionGranted
                      ? _MapControl(
                          icon: Icons.my_location,
                          tooltip: loc.myLocation,
                          isBusy: _isLocatingCustomer,
                          onTap: _goToCustomerLocation,
                        )
                      : null,
                ),
              ],
            ),
          ),

          // The driver app heartbeats once a minute, so silence past
          // [_staleAfter] means the feed stopped rather than the car. Said
          // plainly, because a frozen marker otherwise reads as a car that has
          // parked and the customer keeps waiting on it.
          if (_feedIsStale && !_tripEnded)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withAlpha(120)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        loc.liveLocationPaused,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                              // 52pt avatar at 3x.
                              memCacheWidth: 160,
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
                                    _tripEnded
                                        ? loc.tripEnded
                                        : _isChauffeur
                                        ? (_chauffeurStartTime == null
                                              ? "00:00:00"
                                              : _formatElapsed(_elapsed))
                                        : _currentEta == null
                                        ? loc.calculatingEta
                                        : loc.etaApprox(_currentEta!),
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
                                    _tripEnded
                                        ? ''
                                        : _currentDistance == null
                                        ? loc.calculatingEta
                                        : loc.distanceKm(_currentDistance!),
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
                      onTap: () =>
                          _makePhoneCall(widget.booking.driver?.fullPhone),
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

/// One floating control on the map.
///
/// Renders as a labelled pill when given a [label] and as a round icon button
/// when not, so the two controls on this screen — a named action and a bare
/// locate button — share one shape language without a second widget.
class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
    this.isBusy = false,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Shown beside the icon. Null makes this a circular icon-only button.
  final String? label;

  /// Accessibility name, and the long-press tooltip. Falls back to [label].
  final String? tooltip;

  /// Swaps the icon for a spinner and refuses taps, for a control whose work
  /// takes long enough to notice — waiting on a GPS fix, mostly.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final hasLabel = label != null;
    final shape = hasLabel
        ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))
        : const CircleBorder();

    final glyph = isBusy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withAlpha(220),
            ),
          )
        : Icon(icon, color: Colors.white.withAlpha(220), size: 20);

    return Tooltip(
      message: tooltip ?? label ?? '',
      child: Material(
        color: const Color(0xFF1E1E1E),
        shape: shape,
        elevation: 4,
        shadowColor: Colors.black54,
        child: InkWell(
          onTap: isBusy ? null : onTap,
          customBorder: shape,
          child: Padding(
            padding: hasLabel
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                : const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                glyph,
                if (hasLabel) ...[
                  const SizedBox(width: 8),
                  Text(
                    label!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder shown while the map waits for the driver's first position.
///
/// Deliberately map-shaped rather than a spinner: it holds the same ground the
/// map is about to occupy, in the same light tone, with a few abstract streets
/// running through it — so the real map resolving over it reads as the screen
/// arriving rather than one thing being swapped for another.
class _MapSkeleton extends StatelessWidget {
  const _MapSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      // The light map's own ground colour, so the fade has nothing to travel.
      color: const Color(0xFFE8EAED),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE8EAED),
        highlightColor: const Color(0xFFF6F7F9),
        child: CustomPaint(
          painter: _StreetsPainter(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// A handful of streets and a block or two — enough to read as a map without
/// pretending to be one anywhere in particular.
class _StreetsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final minor = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    // Two arterials crossing at a shallow angle, the way most city grids read
    // when the map is turned slightly off north.
    canvas.drawLine(
      Offset(-40, size.height * 0.34),
      Offset(size.width + 40, size.height * 0.52),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.68, -40),
      Offset(size.width * 0.32, size.height + 40),
      road,
    );

    // Side streets running off them.
    canvas.drawLine(
      Offset(-20, size.height * 0.72),
      Offset(size.width * 0.62, size.height * 0.86),
      minor,
    );
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.12),
      Offset(size.width * 0.30, size.height * 0.62),
      minor,
    );

    // A couple of blocks between them.
    final block = Paint()..color = Colors.white.withAlpha(140);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.56, 90, 62),
        const Radius.circular(6),
      ),
      block,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.18, 110, 74),
        const Radius.circular(6),
      ),
      block,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
