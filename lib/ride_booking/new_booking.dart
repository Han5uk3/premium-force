import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:premium_force_main/common_widgets/bookingcard.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/premiumdropdown.dart';
import 'package:premium_force_main/common_widgets/riyal_symbol.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/common_widgets/textfield.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/authentication/location_picker.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/ride_booking/voice_note_dialog.dart';
import 'dart:io';
import 'package:premium_force_main/models/car_model.dart';
import 'package:country_picker/country_picker.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/models/payment_model.dart';
import 'package:premium_force_main/ride_booking/success_page.dart';
import 'package:premium_force_main/ride_booking/payment_rejected_page.dart';
import 'package:premium_force_main/ride_booking/payment_cancelled_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:premium_force_main/models/pricing/zone_model.dart';
import 'package:premium_force_main/api/booking_api_v2.dart';
import 'package:premium_force_main/models/v2/available_vehicle.dart';
import 'package:premium_force_main/models/v2/booking_service_type.dart';
import 'package:premium_force_main/models/v2/chauffeur_options.dart';
import 'package:premium_force_main/models/v2/checkout_models.dart';
import 'package:premium_force_main/models/v2/geo_models.dart';
import 'package:premium_force_main/models/v2/session_models.dart';
import 'package:premium_force_main/providers/booking_session_provider.dart';
import 'package:premium_force_main/services/service_availability_service.dart';
import 'package:premium_force_main/services/session_payment_service.dart';

class NewBooking extends StatefulWidget {
  final int catcode;
  final int citycode;
  final List<Map<String, dynamic>>? preloadedCities;
  final List<Map<String, dynamic>>? preloadedAirports;
  final List<Map<String, dynamic>>? preloadedTerminals;

  const NewBooking({
    super.key,
    required this.catcode,
    required this.citycode,
    this.cityId, // New optional field
    this.preloadedCities,
    this.preloadedAirports,
    this.preloadedTerminals,
  });

  final String? cityId;

  @override
  State<NewBooking> createState() => _NewBookingState();
}

class _NewBookingState extends State<NewBooking> {
  late int _selectedCatCode;
  late int _selectedCityCode;

  bool _isCalculatingDistance = false;
  bool _isBooking = false;

  double _totalDistance = 50.0;

  // Fetched car data from the backend
  List<CarModel> _cars = [];
  List<Map<String, dynamic>> _apiCategories = [];
  List<Map<String, dynamic>> _apiCities = [];
  List<Map<String, dynamic>> _apiAirports = [];
  List<Map<String, dynamic>> _apiTerminals = [];
  Map<String, String> _brandIcons = {}; // Added this
  bool _isCheckingRoute = false;
  List<ZoneModel> _allZones = []; // New field: List of all fetched API zones

  bool _isFilteringCars = false;

  final _tripInfoFormKey = GlobalKey<FormState>();
  final _preferencesFormKey = GlobalKey<FormState>();
  final _passengerFormKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  bool showPreferances = false;
  bool showTripInfo = true;
  bool showPassenger = false;
  bool showReviewAndConfirm = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedVehicleClass;
  String? _selectedVehicleBrand = "Mercedes";
  String? _selectedVehicleModel = "S-Class S450";
  String? _numberOfPassengers = "1";
  DateTime? _selectedPickupDate;
  TimeOfDay? _selectedPickupTime;

  String? _dropAddress;
  double? _dropLat;
  double? _dropLng;
  String? _pickupAddress;
  double? _pickupLat;
  double? _pickupLng;

  TextEditingController flightNumberController = TextEditingController();
  TextEditingController specialRequestsController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();

  /// Rejection reason for the last coupon attempt, shown under the field.
  String? _couponError;
  TextEditingController _passengerNameController = TextEditingController();
  TextEditingController _mobileNumberController = TextEditingController();
  String? _specialRequestsVoiceNotePath;
  int _selectedTerminalCode = 0;
  int _selectedAirportCode = 0;
  String _selectedPassengerCountryCode = '966';

  // Promo Code variables
  double _discountPercentage = 0.0;

  int _selectedEstimatedHours = 0; // 0 means not selected yet
  double _vatPercentage = 15.0;

  bool _isLoadingHourlyPrices = false;

  /// What the chauffeur product offers, from `GET /chauffeur/options`.
  ///
  /// `null` while that call is in flight, so the picker offers nothing until the
  /// backend has said what is bookable. The backend still validates the choice
  /// on session init, so this only decides what is offered.
  ChauffeurOptions? _chauffeurOptions;

  /// Which chauffeur product the user picked; `null` until they choose.
  ///
  /// Decides both what the duration pickers show and which duration field
  /// session init sends.
  ChauffeurType? _selectedChauffeurType;

  /// Used only when the options call fails, so a network blip cannot leave the
  /// chauffeur flow with an empty picker. Packages only: the hourly bounds are
  /// not ours to guess.
  static const ChauffeurOptions _fallbackChauffeurOptions = ChauffeurOptions(
    hourly: HourlyChauffeurOption(available: false),
    packages: [4, 6, 8, 12],
  );

  // ---------------------------------------------------------------------------
  // v2 backend-driven session
  //
  // The booking draft lives on the server (Redis, 1-hour TTL). Each step posts
  // to the session API and the response replaces local state, so availability,
  // fares, VAT, discounts and the payable total are all decided server-side.
  // Nothing below computes a price.
  // ---------------------------------------------------------------------------

  /// Scoped to this screen: one draft per booking attempt.
  final BookingSessionProvider _session = BookingSessionProvider();
  final ServiceAvailabilityService _availability = ServiceAvailabilityService();
  final BookingApiV2 _apiV2 = BookingApiV2();

  /// Cities from the v2 API, reshaped for the existing dropdowns.
  ///
  /// The trip-info form reads untyped maps keyed by the legacy field names, so
  /// the typed model is flattened back to that shape rather than rewriting the
  /// form. Inactive cities are dropped — they are not bookable.
  Future<Map<String, dynamic>> _fetchCitiesV2() async {
    final result = await _apiV2.getCities();
    final cities = result.data;
    if (cities == null) {
      return {'success': false, 'message': result.message};
    }

    return {
      'success': true,
      'data': [
        for (final city in cities.where((c) => c.isActive))
          {
            '_id': city.id,
            'cityName': city.name,
            'cityNameAr': city.nameAr,
            'bookingBufferHours': city.bookingBufferHours,
            'isActive': city.isActive,
            'lat': city.lat,
            'long': city.lng,
          },
      ],
      // Kept so airports/terminals can be read from the nested payload when the
      // backend returns them that way.
      'cities': cities,
    };
  }

  /// Airports for the dropdowns, preferring any nested in the cities payload.
  ///
  /// Falls back to the standalone v2 endpoint, then to v1, because whether
  /// `GET /cities` nests them is not yet settled.
  Future<Map<String, dynamic>> _fetchAirportsV2(
    List<CityV2> citiesFromV2,
  ) async {
    final nested = [
      for (final city in citiesFromV2)
        for (final airport in city.airports)
          if (airport.isActive)
            {
              '_id': airport.id,
              'airportName': airport.name,
              'airportNameAr': airport.nameAr,
              'cityID': airport.cityId ?? city.id,
              'lat': airport.lat,
              'long': airport.lng,
              'isActive': airport.isActive,
            },
    ];
    if (nested.isNotEmpty) return {'success': true, 'data': nested};

    final result = await _apiV2.getAirports();
    final airports = result.data;
    if (airports != null && airports.isNotEmpty) {
      return {
        'success': true,
        'data': [
          for (final airport in airports.where((a) => a.isActive))
            {
              '_id': airport.id,
              'airportName': airport.name,
              'airportNameAr': airport.nameAr,
              'cityID': airport.cityId,
              'lat': airport.lat,
              'long': airport.lng,
              'isActive': airport.isActive,
            },
        ],
      };
    }

    return ApiService().getAirports();
  }

  /// Terminals for the dropdowns, with the same nested-then-fallback strategy.
  Future<Map<String, dynamic>> _fetchTerminalsV2(
    List<CityV2> citiesFromV2,
  ) async {
    final nested = [
      for (final city in citiesFromV2)
        for (final airport in city.airports)
          for (final terminal in airport.terminals)
            if (terminal.isActive)
              {
                '_id': terminal.id,
                'terminalName': terminal.name,
                'terminalNameAr': terminal.nameAr,
                'airportID': terminal.airportId ?? airport.id,
                'isActive': terminal.isActive,
              },
    ];
    if (nested.isNotEmpty) return {'success': true, 'data': nested};

    final result = await _apiV2.getTerminals();
    final terminals = result.data;
    if (terminals != null && terminals.isNotEmpty) {
      return {
        'success': true,
        'data': [
          for (final terminal in terminals.where((t) => t.isActive))
            {
              '_id': terminal.id,
              'terminalName': terminal.name,
              'terminalNameAr': terminal.nameAr,
              'airportID': terminal.airportId,
              'isActive': terminal.isActive,
            },
        ],
      };
    }

    return ApiService().getTerminals();
  }

  /// The product being booked, derived from the legacy `catcode`.
  BookingServiceType get _serviceType =>
      BookingServiceType.fromCatCode(_selectedCatCode);

  /// The pickup instant the user chose.
  ///
  /// Airport departure and chauffeur capture pickup in their own date/time
  /// fields; arrival and private transfer use the primary pair.
  DateTime? get _pickupInstant {
    final usesPickupFields = _selectedCatCode == 1 || _selectedCatCode == 2;
    final date = usesPickupFields ? _selectedPickupDate : _selectedDate;
    final time = usesPickupFields ? _selectedPickupTime : _selectedTime;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// Step 1 → 2: create the server draft, then load the vehicles it prices.
  ///
  /// The backend re-resolves cities/zones and re-checks the booking buffer here,
  /// so a rejection at this point is authoritative and its message is shown
  /// verbatim.
  Future<bool> _startSessionAndLoadVehicles(AppLocalizations loc) async {
    final pickupAt = _pickupInstant;
    if (pickupAt == null) {
      _showCustomSnackBar(loc.somethingWentWrong, 'E');
      return false;
    }

    bool started = false;

    switch (_serviceType) {
      case BookingServiceType.airportArrival:
      case BookingServiceType.airportDeparture:
        final airportId = _getSelectedAirportId();
        final terminalId = _getSelectedTerminalId();
        if (airportId == null ||
            airportId.isEmpty ||
            terminalId == null ||
            terminalId.isEmpty) {
          _showCustomSnackBar(loc.somethingWentWrong, 'E');
          return false;
        }

        // The customer-side endpoint is the drop-off on arrival and the pickup
        // on departure; the other end is always the airport terminal.
        final isArrival = _serviceType == BookingServiceType.airportArrival;
        final lat = isArrival ? _dropLat : _pickupLat;
        final lng = isArrival ? _dropLng : _pickupLng;
        final address = isArrival ? _dropAddress : _pickupAddress;

        if (lat == null || lng == null || address == null || address.isEmpty) {
          _showCustomSnackBar(loc.pickupLocationIsRequired, 'E');
          return false;
        }

        started = await _session.startAirportSession(
          serviceType: _serviceType,
          airportId: airportId,
          terminalId: terminalId,
          customerLat: lat,
          customerLng: lng,
          customerAddress: address,
          pickupDateTime: pickupAt,
          flightNumber: flightNumberController.text,
        );

      case BookingServiceType.chauffeur:
        if (_pickupLat == null ||
            _pickupLng == null ||
            _pickupAddress == null) {
          _showCustomSnackBar(loc.pickupLocationIsRequired, 'E');
          return false;
        }
        // Hourly hire is only fully chosen once the second picker has an hour
        // on it, so both halves are re-checked before the draft is created.
        final chauffeurType = _selectedChauffeurType;
        if (chauffeurType == null || _selectedEstimatedHours == 0) {
          _showCustomSnackBar(loc.selectDuration, 'E');
          return false;
        }
        started = await _session.startChauffeurSession(
          pickupLat: _pickupLat!,
          pickupLng: _pickupLng!,
          pickupAddress: _pickupAddress!,
          hours: _selectedEstimatedHours,
          chauffeurType: chauffeurType,
          pickupDateTime: pickupAt,
        );

      case BookingServiceType.privateTransfer:
        if (_pickupLat == null ||
            _pickupLng == null ||
            _pickupAddress == null ||
            _dropLat == null ||
            _dropLng == null ||
            _dropAddress == null) {
          _showCustomSnackBar(loc.pickupLocationIsRequired, 'E');
          return false;
        }
        started = await _session.startPrivateTransferSession(
          pickupLat: _pickupLat!,
          pickupLng: _pickupLng!,
          pickupAddress: _pickupAddress!,
          dropOffLat: _dropLat!,
          dropOffLng: _dropLng!,
          dropOffAddress: _dropAddress!,
          pickupDateTime: pickupAt,
        );
    }

    if (!started) {
      _showNoServiceAlert(
        message: _session.errorMessage ?? loc.somethingWentWrong,
      );
      return false;
    }

    if (!await _session.loadVehicles()) {
      _showNoServiceAlert(
        message: _session.errorMessage ?? loc.somethingWentWrong,
      );
      return false;
    }

    _adoptSessionVehicles();

    if (_cars.isEmpty) {
      _showNoServiceAlert(message: loc.somethingWentWrong);
      return false;
    }
    return true;
  }

  /// Feed the server-priced vehicles into the existing selection UI.
  ///
  /// Mapping them onto [CarModel] keeps the class/brand/model pickers and the
  /// fleet cards unchanged, while the ids they carry become v2 vehicle ids.
  void _adoptSessionVehicles() {
    final response = _session.vehicles;
    if (response == null) return;

    final bookable = response.vehicles.where((v) => v.isAvailable).toList();
    if (!mounted) return;

    setState(() {
      _cars = bookable.map(_toCarModel).toList();

      // Classes, brands and logos ship with the vehicle list, so the pickers
      // can never offer an option this route does not actually support.
      _apiCategories = [
        for (final category in response.categories)
          {
            '_id': category.id,
            'name': category.name,
            'nameAr': category.nameAr,
          },
      ];
      _brandIcons = {
        for (final brand in response.brands)
          if (brand.icon != null && brand.icon!.isNotEmpty)
            brand.name: brand.icon!,
      };
    });

    _selectInitialVehicleClass();
    _syncSelectionToSupportedCars();
  }

  /// Pick a sensible default class the first time vehicles arrive.
  ///
  /// Runs here rather than at screen load because the class list is now scoped
  /// to the resolved route, and only exists once the session has been created.
  void _selectInitialVehicleClass() {
    if (_apiCategories.isEmpty) return;

    final names = _apiCategories
        .map((c) => (c['name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) return;

    // Keep an existing choice when it survived into the new list.
    if (_selectedVehicleClass != null &&
        names.contains(_selectedVehicleClass)) {
      return;
    }

    final preferred = _selectedCatCode == 2 ? 'chauffeur' : 'sedan';
    _selectedVehicleClass = names.firstWhere(
      (name) => name.toLowerCase().contains(preferred),
      orElse: () => names.first,
    );
  }

  /// Bridge a server-priced vehicle into the legacy view model.
  CarModel _toCarModel(AvailableVehicle vehicle) {
    return CarModel(
      id: vehicle.vehicleId,
      className: vehicle.category?.name ?? '',
      brand: vehicle.brand?.name ?? '',
      modelName: vehicle.displayName.isNotEmpty
          ? vehicle.displayName
          : vehicle.name,
      imagePath: vehicle.image ?? '',
      // Price and distance are vestigial on this view model — the backend owns
      // pricing, and nothing on screen reads either field.
      price: 0,
      distance: 0,
      maxPassengers: vehicle.maxPassengers ?? 4,
      brandId: vehicle.brand?.id,
      categoryId: vehicle.category?.id,
    );
  }

  /// Step 2 → 3: attach the chosen vehicle and ride notes to the draft.
  Future<bool> _submitVehicleSelection(AppLocalizations loc) async {
    final vehicleId = _getSelectedCarId();
    if (vehicleId == null || vehicleId.isEmpty) {
      _showCustomSnackBar(loc.somethingWentWrong, 'E');
      return false;
    }

    final saved = await _session.selectVehicle(
      vehicleId: vehicleId,
      rideNotes: specialRequestsController.text,
      voiceNotePath: _specialRequestsVoiceNotePath,
    );

    if (!saved) {
      _showCustomSnackBar(_session.errorMessage ?? loc.somethingWentWrong, 'E');
      return false;
    }

    _clampPassengerCount();
    return true;
  }

  /// Trim the passenger count to the chosen vehicle's capacity.
  ///
  /// A count picked for a roomier vehicle survives a change of vehicle, and
  /// step 3 rejects anything above `selectedVehicle.maxPassengers`. Left alone
  /// it also leaves the passenger dropdown blank, since the stale count is no
  /// longer one of its options.
  void _clampPassengerCount() {
    final options = _getPassengerOptions();
    if (options.isEmpty || options.contains(_numberOfPassengers)) return;

    // Options run 1..capacity, so the last is the most the vehicle can take.
    setState(() => _numberOfPassengers = options.last);
  }

  /// Step 3 → 4: save passengers, then pull the authoritative price breakdown.
  Future<bool> _submitPassengerAndLoadCheckout(AppLocalizations loc) async {
    final names = _passengerNameController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(', ');

    final saved = await _session.savePassengerDetails(
      passengersCount: int.tryParse(_numberOfPassengers ?? '1') ?? 1,
      passengerNames: names,
      passengerPhone:
          '+$_selectedPassengerCountryCode'
          '${_mobileNumberController.text.replaceAll(' ', '')}',
    );

    if (!saved) {
      _showCustomSnackBar(_session.errorMessage ?? loc.somethingWentWrong, 'E');
      return false;
    }

    if (!await _session.loadCheckout()) {
      _showCustomSnackBar(_session.errorMessage ?? loc.somethingWentWrong, 'E');
      return false;
    }

    _adoptCheckoutPricing();
    return true;
  }

  /// Mirror the parts of the server breakdown the summary shows as labels.
  ///
  /// Amounts are read straight from [_serverPricing]; only the VAT and discount
  /// *percentages* are kept here, because the summary labels them as percentages
  /// while the API reports the discount as an absolute amount.
  void _adoptCheckoutPricing() {
    final pricing = _session.pricing;
    if (pricing == null || !mounted) return;

    setState(() {
      _vatPercentage = pricing.vat.percentage;
      _discountPercentage = pricing.baseFare > 0
          ? (pricing.discounts.totalDiscount / pricing.baseFare) * 100
          : 0;
      _totalDistance = _session.route?.distanceKm ?? _totalDistance;
    });
  }

  // ── Review screen ────────────────────────────────────────────────────────
  //
  // The review step renders the draft as the backend holds it, not the local
  // form state, so the customer confirms what will actually be booked.
  //
  // Three server sources, in order of preference, because the checkout summary
  // is a *subset* of the session draft — it carries the locations and the
  // vehicle, but not necessarily the pickup date/time or the booked duration:
  //
  //   1. `GET /session/checkout` → `summary`  (freshest, post-vehicle)
  //   2. the step-1 session draft             (always has the full route)
  //   3. the step-2 vehicle list              (class/make/image by id)
  //
  // Local form state is the last resort, reached only before checkout lands.

  BookingSession? get _checkoutSummary => _session.checkout?.summary;
  SessionRoute? get _checkoutRoute => _checkoutSummary?.route;
  SessionRoute? get _draftRoute => _session.route;

  /// First of [candidates] that has actual content.
  static String? _firstNonEmpty(Iterable<String?> candidates) {
    for (final value in candidates) {
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  /// The product being booked, as the backend classified it.
  BookingServiceType get _reviewServiceType =>
      _checkoutSummary?.resolvedServiceType ??
      _session.session?.resolvedServiceType ??
      _serviceType;

  /// Hours of chauffeur hire, as recorded on the draft.
  int get _reviewDurationHours =>
      _checkoutRoute?.durationHours ??
      _draftRoute?.durationHours ??
      _selectedEstimatedHours;

  /// The pickup instant the backend stored.
  ///
  /// `pickupDate`/`pickupTime` are the plain local strings it holds, so they are
  /// recombined rather than read from `pickupDateTime`, which is UTC and would
  /// render in the device's timezone instead of the pickup city's.
  DateTime? get _reviewPickupInstant =>
      _instantOf(_checkoutRoute) ?? _instantOf(_draftRoute) ?? _pickupInstant;

  static DateTime? _instantOf(SessionRoute? route) {
    final date = route?.pickupDate;
    final time = route?.pickupTime;
    if (date == null || time == null) return null;
    return DateTime.tryParse('${date}T$time');
  }

  /// Pickup date and time as the card renders them.
  ///
  /// Falls back to the server's own `pickupLocalTimeFormatted`
  /// (`"10 Aug 2026, 06:00 PM"`) when no date/time pair is available, splitting
  /// it at the comma — already in the city's timezone, just not localised.
  ({String date, String time}) _reviewPickupDisplay(BuildContext context) {
    final instant = _reviewPickupInstant;
    if (instant != null) {
      return (
        date: Bookingcard.formatDate(context, instant),
        time: Bookingcard.formatTime(context, instant),
      );
    }

    final formatted = _firstNonEmpty([
      _checkoutRoute?.pickupLocalTimeFormatted,
      _draftRoute?.pickupLocalTimeFormatted,
    ]);
    if (formatted == null) return (date: '', time: '');

    final separator = formatted.lastIndexOf(',');
    if (separator <= 0) return (date: formatted, time: '');
    return (
      date: formatted.substring(0, separator).trim(),
      time: formatted.substring(separator + 1).trim(),
    );
  }

  /// Localised product label, with the booked duration for chauffeur hire.
  String _reviewServiceLabel(BuildContext context, AppLocalizations loc) {
    final type = _reviewServiceType;
    if (type.isChauffeur) {
      return '${loc.chauffeur} - '
          '${_getServiceDurationLabel(loc, _reviewDurationHours)}';
    }
    return _getServiceName(context, type.catCode);
  }

  /// One end of the route, with the terminal appended on the airport side.
  ///
  /// The terminal is named in two different places: nested under the location
  /// in the checkout summary, and on `route.airport` in the session draft. The
  /// airport end is also the one with no coordinates, which is what identifies
  /// it when the payload omits `airportId`.
  String? _routeEndLabel(
    SessionRoute? route, {
    required bool isPickup,
    required bool isArabic,
  }) {
    if (route == null) return null;

    final location = isPickup ? route.pickupLocation : route.dropOffLocation;
    final address = location?.address;
    if (address == null || address.trim().isEmpty) return null;

    final isAirportSide =
        location?.airportId != null ||
        (route.airport != null && location?.hasCoordinates != true);

    final terminal =
        location?.displayTerminal(isArabic) ??
        (isAirportSide ? route.airport?.displayTerminal(isArabic) : null);

    if (terminal == null || terminal.trim().isEmpty) return address;
    return '$address - $terminal';
  }

  String _reviewPickupLabel(BuildContext context, bool isArabic) {
    return _firstNonEmpty([
          _routeEndLabel(_checkoutRoute, isPickup: true, isArabic: isArabic),
          _routeEndLabel(_draftRoute, isPickup: true, isArabic: isArabic),
          // Arrivals are picked up at a terminal, which local state holds only
          // as two separate selections.
          if (_reviewServiceType == BookingServiceType.airportArrival)
            _localAirportLabel(context),
          _pickupAddress,
        ]) ??
        '';
  }

  String _reviewDropOffLabel(BuildContext context, bool isArabic) {
    // Chauffeur hire has no drop-off at all.
    if (_reviewServiceType.isChauffeur) return '';

    return _firstNonEmpty([
          _routeEndLabel(_checkoutRoute, isPickup: false, isArabic: isArabic),
          _routeEndLabel(_draftRoute, isPickup: false, isArabic: isArabic),
          if (_reviewServiceType == BookingServiceType.airportDeparture)
            _localAirportLabel(context),
          _dropAddress,
        ]) ??
        '';
  }

  /// `"Airport - Terminal"` from the local pickers, for the window before the
  /// backend's own resolution is available.
  String _localAirportLabel(BuildContext context) {
    final airport = _getSelectedAirportName(context) ?? '';
    final terminal = _getSelectedTerminalName(context) ?? '';
    return terminal.isNotEmpty ? '$airport - $terminal' : airport;
  }

  /// The vehicle stub echoed back on the draft.
  SelectedVehicle? get _reviewVehicle =>
      _checkoutSummary?.selectedVehicle ?? _session.session?.selectedVehicle;

  /// The same vehicle as step 2 listed it, matched by id.
  ///
  /// The session echoes only a thin stub — often just id, name and capacity —
  /// so the class and make come from the list the backend returned for this
  /// route rather than from the local pickers.
  AvailableVehicle? get _reviewListedVehicle {
    final id = _reviewVehicle?.vehicleId;
    if (id == null || id.isEmpty) return null;

    for (final vehicle in _session.vehicles?.vehicles ?? const []) {
      if (vehicle.vehicleId == id) return vehicle;
    }
    return null;
  }

  String _reviewVehicleClass(bool isArabic) =>
      _firstNonEmpty([
        _reviewVehicle?.category?.displayName(isArabic),
        _reviewListedVehicle?.category?.displayName(isArabic),
        _selectedVehicleClass,
      ]) ??
      '';

  String _reviewVehicleBrand(bool isArabic) =>
      _firstNonEmpty([
        _reviewVehicle?.brand?.displayName(isArabic),
        _reviewListedVehicle?.brand?.displayName(isArabic),
        _selectedVehicleBrand,
      ]) ??
      '';

  int get _reviewPassengers =>
      _checkoutSummary?.passengerDetails?.passengersCount ??
      _session.session?.passengerDetails?.passengersCount ??
      int.tryParse(_numberOfPassengers ?? '1') ??
      1;

  String? get _reviewVehicleImage => _firstNonEmpty([
    _reviewVehicle?.image,
    _reviewListedVehicle?.image,
    _getSelectedCar()?.imagePath,
  ]);

  // ── Coupons ──────────────────────────────────────────────────────────────

  /// The server's price breakdown, once checkout has been loaded.
  ///
  /// The summary renders these amounts directly rather than recomputing them,
  /// so what the user sees is exactly what the gateway will charge.
  CheckoutPricing? get _serverPricing => _session.pricing;

  // Zero until checkout has been fetched; the review step is only reachable
  // after it succeeds, so these never render a client-derived figure.
  double get _summaryBaseFare => _serverPricing?.baseFare ?? 0;

  double get _summaryDiscount => _serverPricing?.discounts.totalDiscount ?? 0;

  double get _summaryVatAmount => _serverPricing?.vat.amount ?? 0;

  double get _summaryTotal => _serverPricing?.totalAmount ?? 0;

  /// The coupon currently applied to the draft, if any.
  AppliedCoupon? get _appliedCoupon => _serverPricing?.discounts.coupon;

  bool get _isCouponBusy => _session.busy == SessionBusy.applyingCoupon;

  /// Send the entered code to the backend, which recalculates the whole
  /// checkout and returns it.
  Future<void> _applyCouponCode(AppLocalizations loc) async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      setState(() => _couponError = loc.pleaseEnterYourPromoCode);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _couponError = null);

    if (!await _session.applyCoupon(code)) {
      setState(
        () => _couponError = _session.errorMessage ?? loc.invalidPromoCode,
      );
      return;
    }

    _adoptCheckoutPricing();
    _couponController.clear();
    _showCustomSnackBar(loc.promoCodeAppliedSuccessfully, 'S');
  }

  /// Drop the applied coupon and re-read the restored pricing.
  Future<void> _removeCouponCode(AppLocalizations loc) async {
    FocusScope.of(context).unfocus();

    if (!await _session.removeCoupon()) {
      _showCustomSnackBar(_session.errorMessage ?? loc.somethingWentWrong, 'E');
      return;
    }

    _adoptCheckoutPricing();
    setState(() => _couponError = null);
    _showCustomSnackBar(loc.promoCodeRemoved, 'S');
  }

  /// Step 4: confirm the draft, pay if required, and let the backend settle it.
  ///
  /// Order matters — the booking row is created by `confirm` *before* the SDK
  /// opens, so a charge can never exist without a booking attached to it.
  Future<void> _confirmAndPay(AppLocalizations loc) async {
    if (_isBooking) return;
    setState(() => _isBooking = true);

    try {
      final confirmation = await _session.confirm();
      if (confirmation == null) {
        _showCustomSnackBar(_session.errorMessage ?? loc.bookingFailed, 'E');
        return;
      }

      // A fully-discounted booking is already confirmed; no gateway involved.
      if (!confirmation.paymentRequired) {
        _goToSuccess(loc);
        return;
      }

      final config = confirmation.paytabsConfig!;
      final method = await _choosePaymentMethod(loc);
      if (method == null) return;

      final userData = UserLocalStorage.getUserData();
      final customerName =
          userData?['name'] ?? userData?['username'] ?? 'Customer';
      final customerEmail = userData?['email'] ?? '';
      final customerPhone =
          userData?['phone'] ?? userData?['phoneNumber'] ?? '';

      final service = SessionPaymentService();
      final paymentResult = method == 'apple_pay'
          ? await service.startApplePayPayment(
              config: config,
              customerName: customerName,
              customerEmail: customerEmail,
              customerPhone: customerPhone,
            )
          : await service.startCardPayment(
              config: config,
              customerName: customerName,
              customerEmail: customerEmail,
              customerPhone: customerPhone,
            );

      debugPrint(
        '💳 Session payment │ success=${paymentResult.success} '
        'ref=${paymentResult.transactionReference} '
        'msg=${paymentResult.responseMessage}',
      );

      if (!paymentResult.success) {
        _goToPaymentFailure(paymentResult);
        return;
      }

      // The SDK reporting success is not proof — the backend settles it. While
      // the gateway is still clearing (3-D Secure, bank authorisation) the
      // read-only verify endpoint is polled rather than read once.
      final verification = await _session.awaitPaymentSettled();

      switch (verification?.outcome) {
        case PaymentVerificationOutcome.confirmed:
          _goToSuccess(loc);

        case PaymentVerificationOutcome.failed:
          // The SDK said it went through but the backend disagrees, so the
          // server's reason is what the user is shown.
          _goToPaymentFailure(paymentResult, message: verification?.message);

        case PaymentVerificationOutcome.pending:
          // Still with the gateway after polling. The booking exists as
          // `pending_payment`, so neither outcome can be claimed.
          _showCustomSnackBar(
            verification?.message ?? loc.paymentPendingStatus,
            'E',
          );

        case null:
          _showCustomSnackBar(
            _session.errorMessage ?? loc.somethingWentWrong,
            'E',
          );
      }
    } catch (e) {
      debugPrint('❌ Booking error: $e');
      _showCustomSnackBar(loc.somethingWentWrong, 'E');
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  /// Ask iOS users for a payment method; Android always pays by card.
  ///
  /// Returns `null` when the sheet is dismissed without choosing.
  Future<String?> _choosePaymentMethod(AppLocalizations loc) async {
    if (!Platform.isIOS) return 'card';

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1105),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              loc.selectPaymentMethod,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.apple, color: Colors.white, size: 30),
              title: Text(
                loc.applePay,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, 'apple_pay'),
            ),
            ListTile(
              leading: const Icon(
                Icons.credit_card,
                color: Colors.white,
                size: 30,
              ),
              title: Text(
                loc.creditDebitCard,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, 'card'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _goToSuccess(AppLocalizations loc) {
    if (!mounted) return;
    _showCustomSnackBar(loc.bookingConfirmedSuccessfully, 'S');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SuccessPage()),
      (route) => false,
    );
  }

  /// Show the cancelled or declined screen for a payment that did not go
  /// through.
  ///
  /// [message] overrides the SDK's own reason — used when the SDK reported
  /// success but the backend's verification says the charge failed.
  void _goToPaymentFailure(PaymentResult result, {String? message}) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isUserCancellation(result)
            ? const PaymentCancelledPage()
            : PaymentRejectedPage(
                errorMessage: message ?? result.responseMessage,
              ),
      ),
    );
  }

  /// Helper to trigger price re-fetch

  /// Get the current selected CarModel
  CarModel? _getSelectedCar() {
    final carsList = _cars.isNotEmpty ? _cars : availableCars;
    try {
      return carsList.firstWhere(
        (c) =>
            c.className == _selectedVehicleClass &&
            c.brand == _selectedVehicleBrand &&
            c.modelName == _selectedVehicleModel,
      );
    } catch (_) {
      try {
        return carsList.firstWhere((c) => c.className == _selectedVehicleClass);
      } catch (_) {
        return carsList.isNotEmpty ? carsList.first : null;
      }
    }
  }

  /// Gets the city ID for the selected airport

  /// Detects which city a location (lat/lng) belongs to using zones

  /// Check route availability and optionally fetch price

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: PremiumLoader());
      },
    );
  }

  void _showNoServiceAlert({String? message}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF141313),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFFE4A46B),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)!.serviceNotAvailable,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                message ??
                    AppLocalizations.of(context)!.serviceNotAvailableMessage,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE4A46B),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  AppLocalizations.of(context)!.ok,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedCatCode = widget.catcode;
    _selectedCityCode = widget.citycode;

    // Use preloaded data from widget if available.
    //
    // This has to happen before the cityId sync below, which reads _apiCities.
    _apiCities = widget.preloadedCities ?? [];
    _apiAirports = widget.preloadedAirports ?? [];
    _apiTerminals = widget.preloadedTerminals ?? [];

    _syncCityIndexFromId();

    // Set initial class based on catcode
    if (_selectedCatCode == 2) {
      _selectedVehicleClass = "Luxury Sedan";
    } else {
      _selectedVehicleClass = "Luxury Sedan";
    }

    // Autofill passenger details using customer data
    final userDataMap = UserLocalStorage.getUserData();
    if (userDataMap != null) {
      _passengerNameController.text =
          (userDataMap['username'] ?? userDataMap['name'] ?? '').toString();
    }

    final savedPhoneNumber = UserLocalStorage.getPhoneNumber();
    if (savedPhoneNumber != null && savedPhoneNumber.isNotEmpty) {
      _mobileNumberController.text = savedPhoneNumber;
    }

    final savedCCode = UserLocalStorage.getCountryCode();
    if (savedCCode != null && savedCCode.isNotEmpty) {
      _selectedPassengerCountryCode = savedCCode.replaceAll('+', '').trim();
    }

    _loadCarData();
    _loadVat();
    // Only the chauffeur product has a duration picker, and the category cannot
    // change once this screen is open.
    if (_serviceType.isChauffeur) _loadChauffeurOptions();
  }

  /// Populate the chauffeur duration pickers from the backend.
  Future<void> _loadChauffeurOptions() async {
    final result = await _apiV2.getChauffeurOptions();
    if (!mounted) return;

    final options = result.data;
    if (options == null || !options.hasBookableDurations) {
      debugPrint('⏱️ Chauffeur │ No durations returned — using defaults');
    }

    setState(() {
      _chauffeurOptions = (options != null && options.hasBookableDurations)
          ? options
          : _fallbackChauffeurOptions;
      // Nothing can have been picked yet, but the pickers read both of these,
      // so neither is left pointing at a duration that is no longer offered.
      _selectedChauffeurType = null;
      _selectedEstimatedHours = 0;
    });
  }

  Future<void> _loadVat() async {
    try {
      final res = await ApiService().getVat(token: UserLocalStorage.getToken());
      if (res['success'] == true && res['data'] != null) {
        if (mounted) {
          setState(() {
            _vatPercentage = _parseDouble(res['data']['vat'] ?? 15);
          });
        }
      }
    } catch (e) {
      debugPrint('❌ VAT Fetch Error: $e');
    }
  }

  /// Load car data (categories, brands, cars) from the backend API.
  /// Load the reference data the trip-info form needs.
  ///
  /// Vehicles, classes and brands are deliberately absent here: they arrive
  /// with the session's `GET /bookings/session/vehicles` response, already
  /// priced and scoped to the resolved route, so there is no longer a
  /// catalogue-wide fetch when the screen opens.
  Future<void> _loadCarData() async {
    try {
      final citiesResponse = _apiCities.isEmpty
          ? await _fetchCitiesV2()
          : <String, dynamic>{'success': true, 'data': _apiCities};

      final citiesFromV2 =
          (citiesResponse['cities'] as List<CityV2>?) ?? const <CityV2>[];

      final results =
          await Future.wait<Map<String, dynamic>>([
            _apiAirports.isEmpty
                ? _fetchAirportsV2(citiesFromV2)
                : Future.value({'success': true, 'data': _apiAirports}),
            _apiTerminals.isEmpty
                ? _fetchTerminalsV2(citiesFromV2)
                : Future.value({'success': true, 'data': _apiTerminals}),
            ApiService().getZones(token: UserLocalStorage.getToken()),
          ]).catchError((e) {
            debugPrint('Error loading location data: $e');
            return <Map<String, dynamic>>[{}, {}, {}];
          });

      if (!mounted) return;

      final airportsResult = results[0];
      final terminalsResult = results[1];
      final zonesResult = results[2];

      setState(() {
        if (citiesResponse['success'] == true) {
          final citiesData = citiesResponse['data'];
          if (citiesData is List) {
            _apiCities = rawDataToList(citiesData);
            // Nothing was preloaded, so initState had no list to resolve
            // widget.cityId against.
            _syncCityIndexFromId();
          }
        }

        if (airportsResult['success'] == true) {
          final airportsData =
              airportsResult['data'] ?? airportsResult['airports'];
          if (airportsData is List) _apiAirports = rawDataToList(airportsData);
        }

        if (terminalsResult['success'] == true) {
          final terminalsData =
              terminalsResult['data'] ?? terminalsResult['terminals'];
          if (terminalsData is List) {
            _apiTerminals = rawDataToList(terminalsData);
          }
        }

        if (zonesResult['success'] == true) {
          final zonesData = zonesResult['data'] ?? zonesResult['zones'];
          if (zonesData is List) {
            _allZones = zonesData.map((z) => ZoneModel.fromJson(z)).toList();
          }
        }

        // Private transfer only lists cities covered by an active zone, so a
        // preselected city outside that set has to be corrected.
        if (_selectedCatCode == 3) _resetCityIfUnzoned();
      });
    } catch (e) {
      debugPrint('Error loading location data: $e');
    }
  }

  /// Point [_selectedCityCode] at [NewBooking.cityId] within [_apiCities].
  ///
  /// [NewBooking.citycode] indexes the *filtered* list the caller displayed
  /// (airport services hide cities with no airport, private transfer hides
  /// cities with no zone), while everything on this screen indexes the full
  /// [_apiCities]. The two only line up when nothing was filtered out, so
  /// without this the screen resolves a different city than the user picked and
  /// reads its airports.
  ///
  /// Called again once cities load, for the case where none were preloaded.
  void _syncCityIndexFromId() {
    final cityId = widget.cityId;
    if (cityId == null || _apiCities.isEmpty) return;

    final index = _apiCities.indexWhere(
      (c) => (c['_id'] ?? c['id'])?.toString() == cityId,
    );
    if (index != -1) _selectedCityCode = index;
  }

  /// Move the selection to the first zone-covered city when the current one
  /// would be hidden from the picker.
  void _resetCityIfUnzoned() {
    final currentCityId =
        (_apiCities.isNotEmpty && _selectedCityCode < _apiCities.length)
        ? (_apiCities[_selectedCityCode]['_id'] ??
                  _apiCities[_selectedCityCode]['id'] ??
                  '')
              .toString()
        : '';

    final isVisible = _allZones.any(
      (z) => z.cityId == currentCityId && z.isActive,
    );
    if (isVisible) return;

    final visibleNames = _getAvailableCityNames(context);
    if (visibleNames.isEmpty) return;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final index = _apiCities.indexWhere((c) {
      final name =
          (isArabic ? (c['cityNameAr'] ?? c['cityName']) : c['cityName'])
              .toString();
      return name == visibleNames.first;
    });
    if (index != -1) _selectedCityCode = index;
  }

  /// Helper to parse double values from API responses
  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  bool _isNearAirport(double lat, double lng, String address) {
    if (address.toLowerCase().contains('airport') || address.contains('مطار')) {
      return true;
    }

    if (lat == 0 && lng == 0) return false;
    for (var airport in _apiAirports) {
      final aLat = _parseDouble(airport['lat']);
      final aLng = _parseDouble(airport['long']);
      if (aLat != 0 && aLng != 0) {
        final distance = Geolocator.distanceBetween(lat, lng, aLat, aLng);
        if (distance < 3000) return true; // 3km radius
      }
    }
    return false;
  }

  /// Brands available within a vehicle class.
  ///
  /// Derived straight from the fetched vehicles: the endpoint already returns
  /// only what this route supports, so presence in [_cars] is the whole test.
  List<String> _getAvailableBrands(String? className) {
    if (className == null) return const [];
    final target = className.toLowerCase().trim();

    return _cars
        .where((c) => c.className.toLowerCase().trim() == target)
        .map((c) => c.brand.trim())
        .where((b) => b.isNotEmpty && b.toLowerCase() != 'unknown')
        .toSet()
        .toList();
  }

  /// Models available for a class and brand.
  List<String> _getAvailableModels(String? className, String? brand) {
    if (className == null || brand == null) return const [];
    final targetClass = className.toLowerCase().trim();
    final targetBrand = brand.toLowerCase().trim();

    return _cars
        .where(
          (c) =>
              c.className.toLowerCase().trim() == targetClass &&
              c.brand.toLowerCase().trim() == targetBrand,
        )
        .map((c) => c.modelName.trim())
        .where((m) => m.isNotEmpty && m.toLowerCase() != 'unknown')
        .toSet()
        .toList();
  }

  /// Get passenger options based on selected car's max passengers
  List<String> _getPassengerOptions() {
    // Find the selected car
    final carsList = _cars.isNotEmpty ? _cars : availableCars;
    final selectedCar = carsList.firstWhere(
      (c) =>
          c.className == _selectedVehicleClass &&
          c.brand == _selectedVehicleBrand &&
          c.modelName == _selectedVehicleModel,
      orElse: () => carsList.firstWhere(
        (c) => c.className == _selectedVehicleClass,
        orElse: () => carsList.first,
      ),
    );

    final maxPassengers = selectedCar.maxPassengers > 0
        ? selectedCar.maxPassengers
        : 7;
    return List.generate(maxPassengers, (index) => (index + 1).toString());
  }

  @override
  void dispose() {
    AnimatedSnackBar.dismiss();
    flightNumberController.dispose();
    specialRequestsController.dispose();
    _couponController.dispose();
    _scrollController.dispose();
    _session.dispose();
    super.dispose();
  }

  void _showCustomSnackBar(String message, String type) {
    AnimatedSnackBar.show(context, message, type);
  }

  /// Cascade the class → brand → model selection onto what the route offers.
  ///
  /// Run whenever the vehicle list changes, so a choice carried over from a
  /// previous route cannot survive into one that does not support it.
  void _syncSelectionToSupportedCars() {
    if (_cars.isEmpty) return;

    final availableClasses = _getAvailableVehicleClasses();
    if (availableClasses.isEmpty) return;

    // If current class is not available, switch to first available
    if (_selectedVehicleClass == null ||
        !availableClasses.contains(_selectedVehicleClass)) {
      _selectedVehicleClass = availableClasses.first;
    }

    // Cascade: Pick first supported brand in this class
    final availableBrands = _getAvailableBrands(_selectedVehicleClass);
    if (availableBrands.isEmpty) {
      _selectedVehicleBrand = null;
      _selectedVehicleModel = null;
      return;
    }
    if (_selectedVehicleBrand == null ||
        !availableBrands.contains(_selectedVehicleBrand)) {
      _selectedVehicleBrand = availableBrands.first;
    }

    // Cascade: Pick first supported model for this class+brand
    final availableModels = _getAvailableModels(
      _selectedVehicleClass,
      _selectedVehicleBrand,
    );
    if (availableModels.isEmpty) {
      _selectedVehicleModel = null;
      return;
    }
    if (_selectedVehicleModel == null ||
        !availableModels.contains(_selectedVehicleModel)) {
      _selectedVehicleModel = availableModels.first;
    }
  }

  String _getServiceName(BuildContext context, int code) {
    final loc = AppLocalizations.of(context)!;
    switch (code) {
      case 1:
        return loc.airportDeparture;
      case 2:
        return loc.chauffeurService;
      case 3:
        return loc.privateTransfer;
      case 0:
      default:
        return loc.airportArrival;
    }
  }

  String _getCityName(BuildContext context, int code) {
    if (_apiCities.isNotEmpty && code < _apiCities.length) {
      final city = _apiCities[code];
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      return (isArabic
              ? (city['cityNameAr'] ?? city['cityName'])
              : city['cityName'])
          .toString();
    }
    final loc = AppLocalizations.of(context)!;
    switch (code) {
      case 1:
        return loc.dammam;
      case 2:
        return loc.jeddah;
      case 0:
      default:
        return loc.riyadh;
    }
  }

  void _handleBackAction() {
    if (_isBooking) return;
    if (showReviewAndConfirm) {
      // Editing an earlier step drops any applied coupon server-side, so the
      // entry field starts clean when the customer comes back to checkout. The
      // applied coupon itself is read from the server's pricing, so it clears
      // itself on the next checkout load.
      _couponController.clear();
      setState(() {
        showReviewAndConfirm = false;
        showPassenger = true;
        showTripInfo = false;
        showPreferances = false;
        _couponError = null;
      });
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    } else if (showPassenger) {
      setState(() {
        showReviewAndConfirm = false;
        showPassenger = false;
        showTripInfo = false;
        showPreferances = true;
      });
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    } else if (showPreferances) {
      setState(() {
        showReviewAndConfirm = false;
        showPreferances = false;
        showTripInfo = true;
        showPassenger = false;
      });
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    } else if (showTripInfo) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return PopScope(
      canPop: showTripInfo && !_isBooking,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBackAction();
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff3E230A), Color(0xff141313)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: AbsorbPointer(
          absorbing: _isBooking,
          child: Scaffold(
            appBar: buidAppBar(context),
            backgroundColor: Colors.transparent,
            body: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.05, 0.0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                      layoutBuilder:
                          (
                            Widget? currentChild,
                            List<Widget> previousChildren,
                          ) {
                            return Stack(
                              alignment: Alignment.topCenter,
                              children: <Widget>[
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                      child: showReviewAndConfirm
                          ? SizedBox(
                              key: const ValueKey('reviewAndConfirmPage'),
                              width: double.infinity,
                              child: buildReviewAndConfirmPage(context, loc),
                            )
                          : showPassenger
                          ? SizedBox(
                              key: const ValueKey('passengerForm'),
                              width: double.infinity,
                              child: buildPassengerForm(context, loc),
                            )
                          : showPreferances
                          ? SizedBox(
                              key: const ValueKey('preferencesForm'),
                              width: double.infinity,
                              child: buildPreferancesForm(context, loc),
                            )
                          : SizedBox(
                              key: const ValueKey('tripInfoForm'),
                              width: double.infinity,
                              child: buildTripInfoForm(context, loc),
                            ),
                    ),
                  ),
                  SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: PremiumButton(
                      text:
                          (_isCalculatingDistance ||
                              _isCheckingRoute ||
                              _isFilteringCars ||
                              _isLoadingHourlyPrices)
                          ? loc.processing
                          : showReviewAndConfirm
                          ? loc.bookService
                          : loc.continueText,
                      onTap:
                          _isCalculatingDistance ||
                              _isCheckingRoute ||
                              _isFilteringCars ||
                              _isLoadingHourlyPrices
                          ? () {}
                          : () async {
                              if (showTripInfo) {
                                if (_selectedCatCode == 2 &&
                                    _selectedEstimatedHours == 0) {
                                  _showCustomSnackBar(loc.selectDuration, 'E');
                                  return;
                                }

                                if (_tripInfoFormKey.currentState?.validate() ??
                                    false) {
                                  // Check booking buffer hours for all categories
                                  int bufferHours = 0;
                                  if (_apiCities.isNotEmpty &&
                                      _selectedCityCode < _apiCities.length) {
                                    final city = _apiCities[_selectedCityCode];
                                    bufferHours =
                                        int.tryParse(
                                          city['bookingBufferHours']
                                                  ?.toString() ??
                                              '0',
                                        ) ??
                                        0;
                                  }

                                  if (bufferHours > 0) {
                                    DateTime? actualPickupDateTime;
                                    if (_selectedCatCode == 1 ||
                                        _selectedCatCode == 2) {
                                      if (_selectedPickupDate != null &&
                                          _selectedPickupTime != null) {
                                        actualPickupDateTime = DateTime(
                                          _selectedPickupDate!.year,
                                          _selectedPickupDate!.month,
                                          _selectedPickupDate!.day,
                                          _selectedPickupTime!.hour,
                                          _selectedPickupTime!.minute,
                                        );
                                      }
                                    } else {
                                      if (_selectedDate != null &&
                                          _selectedTime != null) {
                                        actualPickupDateTime = DateTime(
                                          _selectedDate!.year,
                                          _selectedDate!.month,
                                          _selectedDate!.day,
                                          _selectedTime!.hour,
                                          _selectedTime!.minute,
                                        );
                                      }
                                    }

                                    if (actualPickupDateTime != null) {
                                      if (actualPickupDateTime.isBefore(
                                        DateTime.now().add(
                                          Duration(hours: bufferHours),
                                        ),
                                      )) {
                                        final isArabic =
                                            Localizations.localeOf(
                                              context,
                                            ).languageCode ==
                                            'ar';

                                        String errorMsgEn =
                                            'Bookings must be made at least $bufferHours hour${bufferHours == 1 ? '' : 's'} in advance.';
                                        String errorMsgAr = '';
                                        if (bufferHours == 1) {
                                          errorMsgAr =
                                              'يجب أن يتم الحجز قبل ساعة واحدة على الأقل';
                                        } else if (bufferHours == 2) {
                                          errorMsgAr =
                                              'يجب أن يتم الحجز قبل ساعتين على الأقل';
                                        } else if (bufferHours >= 3 &&
                                            bufferHours <= 10) {
                                          errorMsgAr =
                                              'يجب أن يتم الحجز قبل $bufferHours ساعات على الأقل';
                                        } else {
                                          errorMsgAr =
                                              'يجب أن يتم الحجز قبل $bufferHours ساعة على الأقل';
                                        }

                                        _showCustomSnackBar(
                                          isArabic ? errorMsgAr : errorMsgEn,
                                          'E',
                                        );
                                        return;
                                      }
                                    }
                                  }

                                  if (_selectedCatCode == 1 &&
                                      _selectedDate != null &&
                                      _selectedTime != null &&
                                      _selectedPickupDate != null &&
                                      _selectedPickupTime != null) {
                                    final depDateTime = DateTime(
                                      _selectedDate!.year,
                                      _selectedDate!.month,
                                      _selectedDate!.day,
                                      _selectedTime!.hour,
                                      _selectedTime!.minute,
                                    );
                                    final pickDateTime = DateTime(
                                      _selectedPickupDate!.year,
                                      _selectedPickupDate!.month,
                                      _selectedPickupDate!.day,
                                      _selectedPickupTime!.hour,
                                      _selectedPickupTime!.minute,
                                    );

                                    if (pickDateTime.isAfter(
                                      depDateTime.subtract(
                                        const Duration(hours: 4),
                                      ),
                                    )) {
                                      _showCustomSnackBar(
                                        loc.pickupTimeAtLeast4HoursBeforeDeparture,
                                        'E',
                                      );
                                      return;
                                    }
                                  }

                                  if (_selectedCatCode == 2 &&
                                      _selectedPickupDate != null &&
                                      _selectedPickupTime != null) {
                                    final pickDateTime = DateTime(
                                      _selectedPickupDate!.year,
                                      _selectedPickupDate!.month,
                                      _selectedPickupDate!.day,
                                      _selectedPickupTime!.hour,
                                      _selectedPickupTime!.minute,
                                    );

                                    if (pickDateTime.isBefore(
                                      DateTime.now().add(
                                        const Duration(hours: 1),
                                      ),
                                    )) {
                                      _showCustomSnackBar(
                                        loc.pickupTimeAtLeast1HourFromNow,
                                        'E',
                                      );
                                      return;
                                    }
                                  }

                                  // Create the server draft, which resolves the
                                  // route and returns the vehicles it prices.
                                  setState(() => _isCheckingRoute = true);
                                  final started =
                                      await _startSessionAndLoadVehicles(loc);
                                  if (mounted) {
                                    setState(() => _isCheckingRoute = false);
                                  }
                                  if (!started) return;

                                  setState(() {
                                    showPreferances = true;
                                    showTripInfo = false;
                                    showPassenger = false;
                                    showReviewAndConfirm = false;
                                  });
                                  if (_scrollController.hasClients) {
                                    _scrollController.jumpTo(0);
                                  }
                                }
                              } else if (showPreferances) {
                                if (_preferencesFormKey.currentState
                                        ?.validate() ??
                                    false) {
                                  setState(() {
                                    _isCheckingRoute = true;
                                  });

                                  // Attach the vehicle to the draft; its fare
                                  // was already quoted by the server.
                                  final vehicleSaved =
                                      await _submitVehicleSelection(loc);

                                  if (mounted) {
                                    setState(() {
                                      _isCheckingRoute = false;
                                    });
                                  }

                                  if (!vehicleSaved) return;

                                  setState(() {
                                    showPassenger = true;
                                    showTripInfo = false;
                                    showPreferances = false;
                                    showReviewAndConfirm = false;
                                  });
                                  if (_scrollController.hasClients) {
                                    _scrollController.jumpTo(0);
                                  }
                                }
                              } else if (showPassenger) {
                                if (_passengerFormKey.currentState
                                        ?.validate() ??
                                    false) {
                                  setState(() {
                                    _isCalculatingDistance = true;
                                  });

                                  // Save passengers, then pull the server's
                                  // authoritative price breakdown.
                                  final ready =
                                      await _submitPassengerAndLoadCheckout(
                                        loc,
                                      );

                                  if (mounted) {
                                    setState(() {
                                      _isCalculatingDistance = false;
                                    });
                                  }

                                  if (!ready) return;

                                  setState(() {
                                    showReviewAndConfirm = true;
                                    showTripInfo = false;
                                    showPreferances = false;
                                    showPassenger = false;
                                  });
                                  if (_scrollController.hasClients) {
                                    _scrollController.jumpTo(0);
                                  }
                                }
                              } else if (showReviewAndConfirm) {
                                // Confirm creates the booking server-side
                                // before any money moves, then pays with the
                                // gateway parameters it issued and lets the
                                // backend settle the result.
                                await _confirmAndPay(loc);
                              }
                            },
                      fontsize: 14,
                      showLoader:
                          _isCalculatingDistance ||
                          _isBooking ||
                          _isCheckingRoute,
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildReviewAndConfirmPage(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            loc.reviewAndConfirm,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            loc.reviewAndConfirmYourRequest,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Builder(
            builder: (context) {
              // Rendered from the checkout summary — the draft as the backend
              // holds it — so the customer confirms what will actually be
              // booked, not what the local form happens to still contain.
              final isArabic =
                  Localizations.localeOf(context).languageCode == 'ar';
              final pickupAt = _reviewPickupDisplay(context);

              return Bookingcard(
                isFromReviewAndConfirm: true,
                status: "",
                isChauffeur: _reviewServiceType.isChauffeur,
                type: _reviewServiceLabel(context, loc),
                pickup: _reviewPickupLabel(context, isArabic),
                dropoff: _reviewDropOffLabel(context, isArabic),
                date: pickupAt.date,
                time: pickupAt.time,
                ride: _reviewVehicleClass(isArabic),
                brand: _reviewVehicleBrand(isArabic),
                passengers: _reviewPassengers,
              );
            },
          ),
        ),
        SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Builder(
            builder: (context) {
              // The image the backend attached to the vehicle it recorded.
              final carImageUrl = _reviewVehicleImage;

              if (carImageUrl == null || carImageUrl.isEmpty)
                return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.black,
                      width: double.infinity,
                      child: AspectRatio(
                        aspectRatio: 1.7,
                        child: CachedNetworkImage(
                          imageUrl: carImageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, error, stackTrace) =>
                              const Icon(
                                Icons.directions_car,
                                size: 50,
                                color: Colors.white24,
                              ),
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.white.withAlpha(5),
                            highlightColor: Colors.white.withAlpha(15),
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${_selectedVehicleBrand ?? ""} ${_selectedVehicleModel ?? ""}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
        buildCouponSection(context, loc),
        buildPaymentSummary(context, loc),
        if (_selectedCatCode == 2)
          Padding(
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 0,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFFE4A46B),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      loc.extraHoursInfo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Coupon entry for the review step.
  ///
  /// Applying or removing a code is a server round-trip that returns the whole
  /// recalculated checkout, so the price summary below updates from the same
  /// response — the client never adjusts the total itself.
  Widget buildCouponSection(BuildContext context, AppLocalizations loc) {
    final applied = _appliedCoupon;

    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.promoCode,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (applied != null)
            _buildAppliedCouponRow(loc, applied)
          else
            _buildCouponInputRow(loc),
          if (_couponError != null) ...[
            const SizedBox(height: 8),
            Text(
              _couponError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  /// The applied-coupon state: code, the amount it took off, and a remove action.
  Widget _buildAppliedCouponRow(AppLocalizations loc, AppliedCoupon applied) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade700),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_outlined, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  applied.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.ltr,
                  children: [
                    const Text(
                      "-",
                      style: TextStyle(color: Colors.green, fontSize: 13),
                    ),
                    const RiyalSymbol(color: Colors.green, size: 13),
                    Text(
                      " ${applied.amount.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _isCouponBusy
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: PremiumLoader(size: 16, color: Color(0xFFE4A46B)),
                )
              : TextButton(
                  onPressed: () => _removeCouponCode(loc),
                  child: Text(
                    loc.remove,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  /// The empty state: a code field with an apply action.
  Widget _buildCouponInputRow(AppLocalizations loc) {
    return PremiumTextField(
      controller: _couponController,
      needTitle: false,
      title: loc.promoCode,
      hintText: loc.enterYourPromoCode,
      needBorder: true,
      blackbg: true,
      borderRadius: 12,
      enabled: !_isCouponBusy,
      needAutoCapitalize: true,
      suffixIcon: _isCouponBusy
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: PremiumLoader(size: 16, color: Color(0xFFE4A46B)),
            )
          : TextButton(
              onPressed: () => _applyCouponCode(loc),
              child: Text(
                loc.apply,
                style: const TextStyle(
                  color: Color(0xFFE4A46B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Widget buildPaymentSummary(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            loc.paymentSummary,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /*
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      loc.totalDistance,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      "${_totalDistance.toStringAsFixed(2)} ${loc.km}",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                */
                /*
                const SizedBox(height: 16),
                PremiumTextField(
                  controller: _promoController,
                  title: "Promo Code",
                  hintText: "Enter promo code",
                  readOnly: _isPromoValid,
                  enabled: !_isPromoValid,
                  needBorder: true,
                  blackbg: true,
                  borderRadius: 12,
                  suffixIcon: _isCheckingPromo
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFE4A46B),
                              ),
                            ),
                          ),
                        )
                      : TextButton(
                          onPressed: _isPromoValid ? _removePromoCode : _verifyPromoCode,
                          child: Text(
                            _isPromoValid ? "Remove" : "Apply",
                            style: TextStyle(
                              color: _isPromoValid ? Colors.red : const Color(0xFFE4A46B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                */
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    Expanded(
                      child: Text(
                        maxLines: 2,
                        getBaseChargeText(loc),
                        style: const TextStyle(
                          overflow: TextOverflow.ellipsis,
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.ltr,
                      children: [
                        const RiyalSymbol(color: Colors.white, size: 16),
                        _isCheckingRoute && _selectedCatCode == 3
                            ? const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: PremiumLoader(
                                  size: 16,
                                  color: Color(0xFFE4A46B),
                                ),
                              )
                            : Text(
                                " ${_summaryBaseFare.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
                if (_summaryDiscount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        Bookingcard.formatPercentLabel(
                          loc.discount,
                          _discountPercentage,
                        ),
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        textDirection: TextDirection.ltr,
                        children: [
                          const Text(
                            "-",
                            style: TextStyle(color: Colors.green, fontSize: 16),
                          ),
                          const RiyalSymbol(color: Colors.green, size: 16),
                          _isCheckingRoute && _selectedCatCode == 3
                              ? const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: PremiumLoader(
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                )
                              : Text(
                                  " ${_summaryDiscount.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      Bookingcard.formatPercentLabel(loc.vat, _vatPercentage),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.ltr,
                      children: [
                        const RiyalSymbol(color: Colors.white, size: 16),
                        _isCheckingRoute && _selectedCatCode == 3
                            ? const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: PremiumLoader(
                                  size: 16,
                                  color: Color(0xFFE4A46B),
                                ),
                              )
                            : Text(
                                " ${_summaryVatAmount.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Divider(color: Colors.grey.shade700),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      loc.total,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.ltr,
                      children: [
                        const RiyalSymbol(color: Colors.white, size: 16),
                        _isCheckingRoute && _selectedCatCode == 3
                            ? const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: PremiumLoader(
                                  size: 16,
                                  color: Color(0xFFE4A46B),
                                ),
                              )
                            : Text(
                                " ${_summaryTotal.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String getBaseChargeText(AppLocalizations loc) {
    if (_selectedCatCode == 2) {
      return "${loc.charge} (${_getServiceDurationLabel(loc, _selectedEstimatedHours)})";
    }
    return loc.charge;
  }

  Widget buildPassengerForm(BuildContext context, AppLocalizations loc) {
    return Form(
      key: _passengerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              loc.passenger,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              loc.providePassengerInfo,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PremiumDropDown(
              title: loc.numberOfPassengers,
              items: _getPassengerOptions(),
              value: _numberOfPassengers,
              onChanged: (value) {
                setState(() {
                  _numberOfPassengers = value;
                });
              },
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PremiumTextField(
              titleFontWeight: FontWeight.normal,
              fontsize: 14,
              needBorder: true,
              blackbg: true,
              borderRadius: 12,
              needAutoCapitalize: false,
              title: loc.passengerNameAtleastOne,
              controller: _passengerNameController,
              hintText: loc.pleaseEnterAPassengerName,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return loc.pleaseEnterAtleastOnepassengerName;
                }
                return null;
              },
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PremiumTextField(
              isPhoneNumber: true,
              titleFontWeight: FontWeight.normal,
              fontsize: 14,
              needBorder: true,
              blackbg: true,
              borderRadius: 12,
              needAutoCapitalize: false,
              title: loc.mobileNumber,
              controller: _mobileNumberController,
              hintText: loc.enterMobileNumber,
              prefixIcon: GestureDetector(
                onTap: () {
                  showCountryPicker(
                    context: context,
                    showPhoneCode: true,
                    customFlagBuilder: (context) => const SizedBox.shrink(),
                    countryListTheme: CountryListThemeData(
                      backgroundColor: const Color(0xFF141313),
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      searchTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      inputDecoration: InputDecoration(
                        hintText: loc.search,
                        hintStyle: TextStyle(
                          color: Colors.white.withAlpha(180),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1A1410),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade800),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade800),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE4A46B),
                          ),
                        ),
                      ),
                      bottomSheetHeight:
                          MediaQuery.of(context).size.height * 0.75,
                    ),
                    onSelect: (Country country) {
                      setState(() {
                        _selectedPassengerCountryCode = country.phoneCode;
                      });
                      // Pricing is quoted by the backend when the session is created.
                    },
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+$_selectedPassengerCountryCode',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.white),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        height: 24,
                        width: 1,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return loc.pleaseEnterAMobileNumber;
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPreferancesForm(BuildContext context, AppLocalizations loc) {
    return Form(
      key: _preferencesFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              loc.preferences,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              loc.chooseYouPreferredVehicle,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          SizedBox(height: 16),
          buildVehicleClassSelector(context, loc),
          SizedBox(height: 16),
          buildVehicleBrandSelector(context, loc),
          buildVehicleModelSelector(context, loc),
          buildSimilarVehicleCheckbox(context, loc),
          SizedBox(height: 16),
          buildCarImageDisplay(context, loc),
          SizedBox(height: 16),
          buildSpecialRequests(context, loc),
        ],
      ),
    );
  }

  Widget buildSpecialRequests(BuildContext context, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: PremiumTextField(
        needBorder: true,
        blackbg: true,
        borderRadius: 16,
        maxLines: 4,
        suffixIcon: GestureDetector(
          onTap: () async {
            FocusScope.of(context).requestFocus(FocusNode());
            final path = await showDialog<String>(
              context: context,
              builder: (context) => VoiceNoteDialog(
                initialAudioPath: _specialRequestsVoiceNotePath,
              ),
            );
            if (path != null) {
              FocusScope.of(context).requestFocus(FocusNode());
              setState(() {
                if (path == 'DELETED') {
                  _specialRequestsVoiceNotePath = null;
                } else {
                  _specialRequestsVoiceNotePath = path;
                }
              });
              if (path != 'DELETED') {
                _showCustomSnackBar(loc.voiceNoteSaved, 'S');
              }
            }
          },
          child: _specialRequestsVoiceNotePath != null
              ? Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.mic, color: Color(0xFFE4A46B)),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 10,
                          color: Colors.black, // High contrast with green
                        ),
                      ),
                    ),
                  ],
                )
              : const Icon(Icons.mic_none_outlined, color: Colors.white),
        ),
        title: loc.specialRequests,
        controller: specialRequestsController,
        hintText: loc.specialRequests,
      ),
    );
  }

  Map<String, String> _getVehicleClasses(AppLocalizations loc) {
    return {
      "Luxury Sedan": loc.luxurySedan,
      "Luxury SUV": loc.luxurySuv,
      "Luxury Coupe": loc.luxuryCoupe,
      "Luxury Sports": loc.luxurySports,
      "Luxury Convertible": loc.luxuryConvertible,
    };
  }

  /// Vehicle classes offered for the current route.
  ///
  /// Keeps the order the backend listed its categories in, narrowed to those
  /// that actually have a vehicle in the response.
  List<String> _getAvailableVehicleClasses() {
    if (_cars.isEmpty) {
      // Only reachable before a session exists, where the picker is not shown.
      return _getVehicleClasses(AppLocalizations.of(context)!).keys.toList();
    }

    final withVehicles = _cars
        .map((c) => c.className.trim())
        .where((name) => name.isNotEmpty && name.toLowerCase() != 'unknown')
        .toSet();

    final ordered = _apiCategories
        .map((cat) => (cat['name'] ?? '').toString().trim())
        .where(withVehicles.contains)
        .toList();

    // Fall back to the vehicles' own classes if the category list is absent.
    return ordered.isNotEmpty ? ordered : withVehicles.toList();
  }

  Widget buildVehicleClassSelector(BuildContext context, AppLocalizations loc) {
    // Get available classes from API or fallback to hardcoded
    final availableClasses = _getAvailableVehicleClasses();

    // Ensure the selected value is in the available classes, otherwise update state
    if (_selectedVehicleClass != null &&
        !availableClasses.contains(_selectedVehicleClass)) {
      // Schedule a post-frame state sync so we don't setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedVehicleClass = availableClasses.isNotEmpty
              ? availableClasses.first
              : null;
          // Cascade brand & model
          final brands = _getAvailableBrands(_selectedVehicleClass);
          _selectedVehicleBrand = brands.isNotEmpty ? brands.first : null;
          final models = _getAvailableModels(
            _selectedVehicleClass,
            _selectedVehicleBrand,
          );
          _selectedVehicleModel = models.isNotEmpty ? models.first : null;
        });
      });
    }

    final displayClass =
        (_selectedVehicleClass != null &&
            availableClasses.contains(_selectedVehicleClass))
        ? _selectedVehicleClass
        : (availableClasses.isNotEmpty ? availableClasses.first : null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumDropDown(
            value: displayClass,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedVehicleClass = value;

                  // Cascaded Reset: Update brand and model to first available in new class
                  final availableBrands = _getAvailableBrands(
                    _selectedVehicleClass,
                  );
                  if (availableBrands.isNotEmpty) {
                    _selectedVehicleBrand = availableBrands.first;
                    final availableModels = _getAvailableModels(
                      _selectedVehicleClass,
                      _selectedVehicleBrand,
                    );
                    if (availableModels.isNotEmpty) {
                      _selectedVehicleModel = availableModels.first;
                    } else {
                      _selectedVehicleModel = null;
                    }
                  } else {
                    _selectedVehicleBrand = null;
                    _selectedVehicleModel = null;
                  }
                  // Pricing is quoted by the backend when the session is created.
                });
              }
            },
            title: loc.chauffeurredClass,
            items: availableClasses,
          ),
        ],
      ),
    );
  }

  Widget buildVehicleBrandSelector(BuildContext context, AppLocalizations loc) {
    final List<String> brands = _getAvailableBrands(_selectedVehicleClass);

    if (brands.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Text(
          'No brands available',
          style: TextStyle(color: Colors.white.withAlpha(128)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.choosePreferredBrand,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: brands.length,
            itemBuilder: (context, index) {
              final brand = brands[index];
              final isSelected = _selectedVehicleBrand == brand;
              final iconUrl = _brandIcons[brand];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedVehicleBrand = brand;
                    final availableModels = _getAvailableModels(
                      _selectedVehicleClass,
                      _selectedVehicleBrand,
                    );
                    if (availableModels.isNotEmpty) {
                      _selectedVehicleModel = availableModels.first;
                    } else {
                      _selectedVehicleModel = null;
                    }
                    // Pricing is quoted by the backend when the session is created.
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.green : Colors.black,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: iconUrl != null && iconUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: CachedNetworkImage(
                                  imageUrl: iconUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) =>
                                      const PremiumLoader(
                                        size: 20,
                                        color: Colors.white24,
                                      ),
                                  errorWidget: (context, url, e) => const Icon(
                                    Icons.directions_car,
                                    color: Colors.white24,
                                    size: 24,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.directions_car,
                                color: Colors.white24,
                                size: 24,
                              ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.green : Colors.white24,
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.green,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildVehicleModelSelector(BuildContext context, AppLocalizations loc) {
    final List<String> models = _getAvailableModels(
      _selectedVehicleClass,
      _selectedVehicleBrand,
    );

    if (models.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: PremiumDropDown(
        value:
            _selectedVehicleModel != null &&
                models.contains(_selectedVehicleModel)
            ? _selectedVehicleModel
            : null,
        title: loc.preferredModel,
        items: models,
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedVehicleModel = value;
            });
            // Pricing is quoted by the backend when the session is created.
          }
        },
      ),
    );
  }

  Widget buildSimilarVehicleCheckbox(
    BuildContext context,
    AppLocalizations loc,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
            child: Text(
              loc.similarVehicleNote,
              style: TextStyle(
                color: Colors.white.withAlpha(179),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCarImageDisplay(BuildContext context, AppLocalizations loc) {
    final carsList = _cars.isNotEmpty ? _cars : availableCars;

    // Find the selected car
    CarModel? selectedCar;
    try {
      selectedCar = carsList.firstWhere(
        (c) =>
            c.className == _selectedVehicleClass &&
            c.brand == _selectedVehicleBrand &&
            c.modelName == _selectedVehicleModel,
      );
    } catch (e) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Car Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: AspectRatio(
                aspectRatio: 1.7,
                child: CachedNetworkImage(
                  imageUrl: selectedCar.imagePath,
                  fit: BoxFit.cover,
                  placeholder: (context, url) {
                    return Shimmer.fromColors(
                      baseColor: Colors.white.withAlpha(5),
                      highlightColor: Colors.white.withAlpha(15),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  errorWidget: (context, url, error) => const Icon(
                    Icons.directions_car,
                    size: 50,
                    color: Colors.white24,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          // Car Model Name
          Text(
            _selectedVehicleModel ?? '',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.start,
          ),
        ],
      ),
    );
  }

  Widget buildTripInfoForm(BuildContext context, AppLocalizations loc) {
    return Form(
      key: _tripInfoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              loc.tripInfo,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              loc.tellUsAboutYourJourney,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PremiumTextField(
              title: loc.serviceType,
              controller: TextEditingController(
                text: _getServiceName(context, _selectedCatCode),
              ),
              readOnly: true,
              needBorder: true,
              blackbg: true,
              borderRadius: 12,
              fontsize: 14,
              hintText: "",
            ),
          ),
          // City selector hidden
          SizedBox.shrink(),
          SizedBox(height: 16),

          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.05),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Builder(
                key: ValueKey<int>(_selectedCatCode),
                builder: (context) {
                  if (_selectedCatCode == 0)
                    return buildArrivalSection(context, loc);
                  if (_selectedCatCode == 1)
                    return buildDepartureSection(context, loc);
                  if (_selectedCatCode == 2)
                    return buildChauffeurSection(context, loc);
                  if (_selectedCatCode == 3)
                    return buildPrivateTransferSection(context, loc);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildArrivalSection(BuildContext context, AppLocalizations loc) {
    final terminals = _getAvailableTerminals(context);
    final airports = _getAvailableAirports(context);
    final bool showTerminals = airports.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildAirportName(context, loc),
        if (showTerminals) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PremiumDropDown(
              title: loc.terminal,
              value: terminals.isNotEmpty
                  ? (_selectedTerminalCode < terminals.length
                        ? terminals[_selectedTerminalCode]
                        : terminals.first)
                  : "",
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedTerminalCode = terminals.indexOf(val);
                  });
                }
              },
              items: terminals,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumTextField(
            titleFontWeight: FontWeight.normal,
            fontsize: 14,
            title: loc.flightNumberMandatory,
            controller: flightNumberController,
            hintText: loc.enterFlightNumber,
            needBorder: true,
            blackbg: true,
            needAutoCapitalize: true,
            borderRadius: 8,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return loc.flightNumberIsRequired;
              }
              return null;
            },
          ),
        ),
        SizedBox(height: 16),
        buildDateTimePickers(context, loc, false),
        SizedBox(height: 16),
        buildDropLocation(context, loc, true),
      ],
    );
  }

  Widget buildDepartureSection(BuildContext context, AppLocalizations loc) {
    final terminals = _getAvailableTerminals(context);
    final airports = _getAvailableAirports(context);
    final bool showTerminals = airports.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildDropLocation(context, loc, false),
        const SizedBox(height: 16),
        buildAirportName(context, loc),
        if (showTerminals) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PremiumDropDown(
              title: loc.terminal,
              value: terminals.isNotEmpty
                  ? (_selectedTerminalCode < terminals.length
                        ? terminals[_selectedTerminalCode]
                        : terminals.first)
                  : "",
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedTerminalCode = terminals.indexOf(val);
                  });
                }
              },
              items: terminals,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumTextField(
            titleFontWeight: FontWeight.normal,
            fontsize: 14,
            title: loc.flightNumber,
            controller: flightNumberController,
            hintText: loc.enterFlightNumber,
            needBorder: true,
            blackbg: true,
            needAutoCapitalize: true,
            borderRadius: 8,
          ),
        ),
        SizedBox(height: 16),
        buildDateTimePickers(context, loc, false),
        SizedBox(height: 16),
      ],
    );
  }

  Widget buildPrivateTransferSection(
    BuildContext context,
    AppLocalizations loc,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildDropLocation(context, loc, false), // Pickup
        SizedBox(height: 16),
        buildDropLocation(context, loc, true), // Dropoff
        SizedBox(height: 16),
        buildDateTimePickers(context, loc, false),
        SizedBox(height: 16),
      ],
    );
  }

  Widget buildChauffeurSection(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildDropLocation(context, loc, false),

        SizedBox(height: 16),
        buildHoursDataSelectors(context, loc),
        SizedBox(height: 16),
        buildDateTimePickers(context, loc, true),
      ],
    );
  }

  /// The chauffeur duration pickers.
  ///
  /// The first chooses the product — hourly hire, when the backend has it
  /// enabled, followed by each fixed package. A package carries its own
  /// duration, so only hourly reveals the second picker.
  Widget buildHoursDataSelectors(BuildContext context, AppLocalizations loc) {
    // Null until the options call lands, so the placeholder is all that is
    // offered while it is in flight.
    final options = _chauffeurOptions;
    final hourlyAvailable = options?.hourly.available ?? false;

    // The labels are localised — and in Arabic not always numeric — so the hour
    // behind the chosen label is looked up rather than parsed back out of it.
    final packagesByLabel = {
      for (final h in options?.packages ?? const <int>[])
        _getServiceDurationLabel(loc, h): h,
    };

    final items = [
      if (hourlyAvailable) loc.hourly,
      ...packagesByLabel.keys,
    ];

    // A package shows its own duration; hourly stays on its label whatever hour
    // the second picker is on. Null leaves the field on its placeholder, which
    // is a hint rather than a row the user could pick.
    final currentLabel = switch (_selectedChauffeurType) {
      ChauffeurType.hourly => loc.hourly,
      ChauffeurType.package => _getServiceDurationLabel(
        loc,
        _selectedEstimatedHours,
      ),
      null => null,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumDropDown(
            title: loc.serviceDuration,
            hint: loc.selectDuration,
            value: currentLabel,
            items: items,
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                final packageHours = packagesByLabel[val];
                if (packageHours != null) {
                  _selectedChauffeurType = ChauffeurType.package;
                  _selectedEstimatedHours = packageHours;
                } else if (hourlyAvailable && val == loc.hourly) {
                  // Hours come from the second picker, which starts unset.
                  _selectedChauffeurType = ChauffeurType.hourly;
                  _selectedEstimatedHours = 0;
                }
              });
            },
          ),
        ),
        if (options != null &&
            _selectedChauffeurType == ChauffeurType.hourly) ...[
          SizedBox(height: 16),
          buildHourlyHoursSelector(context, loc, options.hourly),
        ],
      ],
    );
  }

  /// Hour picker for hourly hire, listing every hour the backend allows.
  Widget buildHourlyHoursSelector(
    BuildContext context,
    AppLocalizations loc,
    HourlyChauffeurOption hourly,
  ) {
    final hoursByLabel = {
      for (final h in hourly.range) _getServiceDurationLabel(loc, h): h,
    };

    final items = hoursByLabel.keys.toList();

    // Null until an hour is picked, which shows the placeholder as a hint.
    final currentLabel = _selectedEstimatedHours == 0
        ? null
        : _getServiceDurationLabel(loc, _selectedEstimatedHours);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: PremiumDropDown(
        title: loc.duration,
        hint: loc.selectDuration,
        value: currentLabel,
        items: items,
        onChanged: (val) {
          if (val == null) return;
          setState(() => _selectedEstimatedHours = hoursByLabel[val] ?? 0);
        },
      ),
    );
  }

  String _getServiceDurationLabel(AppLocalizations loc, int value) {
    return loc.nHours(value);
  }

  Widget buildDropLocation(
    BuildContext context,
    AppLocalizations loc,
    bool isDropLocation,
  ) {
    return FormField<bool>(
      validator: (value) {
        if (isDropLocation) {
          if (_dropLat == null || _dropLng == null) {
            return loc.dropLocationIsRequired;
          }
        } else {
          if (_pickupLat == null || _pickupLng == null) {
            return loc.pickupLocationIsRequired;
          }
        }
        return null;
      },
      builder: (state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            // spacing: 8, // This is not a valid property for Column
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDropLocation ? loc.dropLocation : loc.pickupLocation,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              SizedBox(height: 8), // Added SizedBox for spacing
              GestureDetector(
                onTap: () async {
                  double initLat = 24.7136; // Default: Riyadh
                  double initLng = 46.6753;

                  if (_apiCities.isNotEmpty) {
                    final cityName = _getCityName(context, _selectedCityCode);
                    // Find actual city data by name to avoid index mismatch
                    final cityData = _apiCities.firstWhere((c) {
                      final isArabic =
                          Localizations.localeOf(context).languageCode == 'ar';
                      final name =
                          (isArabic
                                  ? (c['cityNameAr'] ?? c['cityName'])
                                  : c['cityName'])
                              .toString();
                      return name == cityName;
                    }, orElse: () => _apiCities.first);

                    final latVal = cityData['lat'] ?? cityData['latitude'];
                    final lngVal =
                        cityData['long'] ??
                        cityData['lng'] ??
                        cityData['longitude'];

                    if (latVal != null &&
                        lngVal != null &&
                        double.tryParse(latVal.toString()) != 0) {
                      initLat = double.tryParse(latVal.toString()) ?? 24.7136;
                      initLng = double.tryParse(lngVal.toString()) ?? 46.6753;
                    } else {
                      // Extended fallback name-based lookup
                      String nameKey = (cityData['cityName'] ?? "")
                          .toString()
                          .toLowerCase();
                      if (nameKey.contains("dammam")) {
                        initLat = 26.3927;
                        initLng = 49.9777;
                      } else if (nameKey.contains("jeddah")) {
                        initLat = 21.4858;
                        initLng = 39.1925;
                      } else if (nameKey.contains("mecca") ||
                          nameKey.contains("makkah")) {
                        initLat = 21.3891;
                        initLng = 39.8579;
                      } else if (nameKey.contains("medina") ||
                          nameKey.contains("madinah")) {
                        initLat = 24.4673;
                        initLng = 39.6107;
                      } else if (nameKey.contains("khobar")) {
                        initLat = 26.2172;
                        initLng = 50.1971;
                      } else if (nameKey.contains("abha")) {
                        initLat = 18.2164;
                        initLng = 42.5053;
                      } else if (nameKey.contains("tabuk")) {
                        initLat = 28.3835;
                        initLng = 36.5662;
                      } else if (nameKey.contains("taif")) {
                        initLat = 21.2854;
                        initLng = 40.4258;
                      } else if (nameKey.contains("riyadh")) {
                        initLat = 24.7136;
                        initLng = 46.6753;
                      }
                    }
                  }

                  FocusScope.of(context).requestFocus(FocusNode());
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationPickerPage(
                        initialLat: initLat,
                        initialLng: initLng,
                        needCurrentLocationButton: !isDropLocation,
                      ),
                    ),
                  );
                  if (result != null && result is Map<String, dynamic>) {
                    FocusScope.of(context).requestFocus(FocusNode());
                    final double newLat = result['lat'] ?? 0;
                    final double newLng = result['lng'] ?? 0;
                    final String newAddress = (result['address'] ?? '')
                        .toString();

                    if (_selectedCatCode == 3) {
                      debugPrint(
                        '📍 PREM-FORCE │ Private Transfer Location Selection:',
                      );
                      debugPrint('   → Latitude: $newLat');
                      debugPrint('   → Longitude: $newLng');
                      debugPrint('   → Full Address: $newAddress');
                      debugPrint('   → City Name: ${result['city'] ?? ''}');
                    }

                    if (_selectedCatCode == 3 &&
                        _isNearAirport(newLat, newLng, newAddress)) {
                      _showCustomSnackBar(loc.useAirportServicesWarning, 'E');
                      if (isDropLocation) {
                        setState(() {
                          _dropAddress = null;
                          _dropLat = null;
                          _dropLng = null;
                        });
                      } else {
                        setState(() {
                          _pickupAddress = null;
                          _pickupLat = null;
                          _pickupLng = null;
                        });
                      }
                      state.didChange(true);
                      return; // Do not update state/location with new airport location
                    }

                    // Every picked location must resolve to a serviced city.
                    // Private transfer additionally requires the point to fall
                    // inside an active transfer zone, so the backend decides
                    // both before the address is accepted.
                    _showLoadingDialog();
                    final availability = await _availability.checkLocation(
                      lat: newLat,
                      lng: newLng,
                      serviceType: _serviceType,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                    }

                    if (!availability.isAvailable) {
                      _showCustomSnackBar(
                        availability.message ??
                            'We do not currently operate in this area.',
                        'E',
                      );
                      if (isDropLocation) {
                        setState(() {
                          _dropAddress = null;
                          _dropLat = null;
                          _dropLng = null;
                        });
                      } else {
                        setState(() {
                          _pickupAddress = null;
                          _pickupLat = null;
                          _pickupLng = null;
                        });
                      }
                      state.didChange(true);
                      return;
                    }

                    if (isDropLocation) {
                      setState(() {
                        _dropAddress = newAddress;
                        _dropLat = newLat;
                        _dropLng = newLng;
                      });
                    } else {
                      setState(() {
                        _pickupAddress = newAddress;
                        _pickupLat = newLat;
                        _pickupLng = newLng;
                      });
                    }
                    state.didChange(true);
                    // Pricing is quoted by the backend when the session is created.
                  }
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: 60),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: state.hasError
                            ? const Color(0xFFCF6679)
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            isDropLocation
                                ? _dropAddress ?? loc.tapToSelectADropLocation
                                : _pickupAddress ??
                                      loc.tapToSelectAPickupLocation,
                            style: TextStyle(
                              color: isDropLocation
                                  ? _dropAddress != null
                                        ? Colors.white
                                        : Colors.white60
                                  : _pickupAddress != null
                                  ? Colors.white
                                  : Colors.white60,
                              fontSize: 14,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 20),
                        Icon(
                          Icons.location_on_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    state.errorText!,
                    style: const TextStyle(
                      color: Color(0xFFCF6679),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget buildAirportName(BuildContext context, AppLocalizations loc) {
    final airports = _getAvailableAirports(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: PremiumDropDown(
        title: loc.airport,
        // With no airports the field has nothing to select, so it renders the
        // hint and stays inert.
        hint: loc.noAirportsAvailable,
        value: airports.isNotEmpty
            ? (_selectedAirportCode < airports.length
                  ? airports[_selectedAirportCode]
                  : airports.first)
            : null,
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _selectedAirportCode = airports.indexOf(val);
              _selectedTerminalCode = 0;
            });
          }
        },
        items: airports,
      ),
    );
  }

  Widget buildDateTimePickers(
    BuildContext context,
    AppLocalizations loc,
    bool isPickup,
  ) {
    return FormField<bool>(
      validator: (value) {
        if (isPickup) {
          if (_selectedPickupDate == null || _selectedPickupTime == null) {
            return loc.pickupDateAndTimeIsRequired;
          }
        } else {
          if (_selectedDate == null || _selectedTime == null) {
            return loc.dateAndTimeIsRequired;
          }
        }
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                loc.pickupDateAndTime,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            SizedBox(height: 8),

            Container(
              height: 60,
              margin: EdgeInsets.symmetric(horizontal: 24),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: state.hasError
                      ? const Color(0xFFCF6679)
                      : Colors.white24,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        FocusScope.of(context).requestFocus(FocusNode());
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate:
                              (isPickup
                                  ? _selectedPickupDate
                                  : _selectedDate) ??
                              DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                          confirmText: loc.done,
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: Color(0xffE4A46B),
                                  onPrimary: Colors.black,
                                  surface: Colors.grey.shade900,
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          FocusScope.of(context).requestFocus(FocusNode());
                          setState(() {
                            if (isPickup) {
                              _selectedPickupDate = picked;
                            } else {
                              _selectedDate = picked;
                            }
                            if (isPickup) {
                              if (_selectedPickupTime != null) {
                                final now = DateTime.now();
                                if (picked.year == now.year &&
                                    picked.month == now.month &&
                                    picked.day == now.day) {
                                  if (_selectedPickupTime!.hour < now.hour ||
                                      (_selectedPickupTime!.hour == now.hour &&
                                          _selectedPickupTime!.minute <
                                              now.minute)) {
                                    _selectedPickupTime = null;
                                    AnimatedSnackBar.show(
                                      context,
                                      loc.previouslySelectedTimeClearedAsItIsInThePast,
                                      'I',
                                    );
                                  }
                                }
                              }
                            } else {
                              if (_selectedTime != null) {
                                final now = DateTime.now();
                                if (picked.year == now.year &&
                                    picked.month == now.month &&
                                    picked.day == now.day) {
                                  if (_selectedTime!.hour < now.hour ||
                                      (_selectedTime!.hour == now.hour &&
                                          _selectedTime!.minute < now.minute)) {
                                    _selectedTime = null;
                                    AnimatedSnackBar.show(
                                      context,
                                      loc.previouslySelectedTimeClearedAsItIsInThePast,
                                      'I',
                                    );
                                  }
                                }
                              }
                            }
                          });
                          state.didChange(true);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPickup
                              ? (_selectedPickupDate == null
                                    ? loc.selectDate
                                    : Bookingcard.formatDate(
                                        context,
                                        _selectedPickupDate,
                                      ))
                              : (_selectedDate == null
                                    ? loc.selectDate
                                    : Bookingcard.formatDate(
                                        context,
                                        _selectedDate,
                                      )),
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        FocusScope.of(context).requestFocus(FocusNode());
                        if (isPickup
                            ? _selectedPickupDate == null
                            : _selectedDate == null) {
                          OverlayEntry? overlayEntry;
                          overlayEntry = OverlayEntry(
                            builder: (context) => Positioned(
                              bottom:
                                  MediaQuery.of(context).viewInsets.bottom + 20,
                              left: 20,
                              right: 20,

                              child: Material(
                                color: Colors.transparent,
                                child: AnimatedSnackBar(
                                  type: "E",
                                  message: loc.pleaseSelectADateFirst,
                                  onDismissed: () {
                                    overlayEntry?.remove();
                                  },
                                ),
                              ),
                            ),
                          );
                          Overlay.of(context).insert(overlayEntry);
                          return;
                        }
                        await showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            TimeOfDay tempTime =
                                (isPickup
                                    ? _selectedPickupTime
                                    : _selectedTime) ??
                                TimeOfDay.now();
                            String? errorMessage;
                            return StatefulBuilder(
                              builder: (context, setDialogState) {
                                return Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: ColorScheme.dark(
                                      surface: Colors.grey.shade900,
                                    ),
                                  ),
                                  child: AlertDialog(
                                    backgroundColor: Colors.grey.shade800,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    title: Text(
                                      loc.selectTime,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                    content: SizedBox(
                                      height: 250,
                                      child: Column(
                                        children: [
                                          if (errorMessage != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 16.0,
                                                left: 16,
                                                right: 16,
                                              ),
                                              child: Text(
                                                errorMessage!,
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 13,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          Expanded(
                                            child: CupertinoTheme(
                                              data: CupertinoThemeData(
                                                brightness: Brightness.dark,
                                                textTheme:
                                                    CupertinoTextThemeData(
                                                      dateTimePickerTextStyle:
                                                          TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                              ),
                                              child: CupertinoDatePicker(
                                                mode: CupertinoDatePickerMode
                                                    .time,
                                                use24hFormat: false,
                                                initialDateTime: DateTime(
                                                  DateTime.now().year,
                                                  DateTime.now().month,
                                                  DateTime.now().day,
                                                  tempTime.hour,
                                                  tempTime.minute,
                                                ),
                                                onDateTimeChanged:
                                                    (DateTime newDateTime) {
                                                      setDialogState(() {
                                                        errorMessage = null;
                                                        tempTime =
                                                            TimeOfDay.fromDateTime(
                                                              newDateTime,
                                                            );
                                                      });
                                                    },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          bool isToday = false;
                                          final now = DateTime.now();
                                          DateTime? dateToCheck = isPickup
                                              ? _selectedPickupDate
                                              : _selectedDate;
                                          if (dateToCheck != null) {
                                            if (dateToCheck.year == now.year &&
                                                dateToCheck.month ==
                                                    now.month &&
                                                dateToCheck.day == now.day) {
                                              isToday = true;
                                            }
                                          } else {
                                            isToday = true;
                                          }
                                          if (isToday) {
                                            if (tempTime.hour < now.hour ||
                                                (tempTime.hour == now.hour &&
                                                    tempTime.minute <
                                                        now.minute)) {
                                              setDialogState(() {
                                                errorMessage = loc
                                                    .cannotSelectPastTimeForToday;
                                              });
                                              return;
                                            }
                                          }
                                          setState(() {
                                            if (isPickup) {
                                              _selectedPickupTime = tempTime;
                                            } else {
                                              _selectedTime = tempTime;
                                            }
                                          });
                                          state.didChange(true);
                                          Navigator.of(dialogContext).pop();
                                        },
                                        child: Text(
                                          loc.done,
                                          style: TextStyle(
                                            color: Color(0xffE4A46B),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                        FocusScope.of(context).requestFocus(FocusNode());
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPickup
                              ? (_selectedPickupTime == null
                                    ? loc.selectTime
                                    : _selectedPickupTime!.format(context))
                              : (_selectedTime == null
                                    ? loc.selectTime
                                    : _selectedTime!.format(context)),
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(
                    color: Color(0xFFCF6679),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget buildIncompleteCheckMark(BuildContext context) {
    return Icon(Icons.circle_outlined, color: Colors.grey.shade700, size: 20);
  }

  Widget buildCompletedCheckMark(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [Color(0xff49280B), Color(0xffE4A46B), Color(0xff60350F)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Icon(Icons.check_circle, color: Colors.white, size: 20),
    );
  }

  PreferredSizeWidget buidAppBar(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight + 76),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(100), Colors.transparent],
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            loc.newBooking,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            enableFeedback: true,
            icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
            onPressed: _handleBackAction,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(76),
            child: buildStepper(context),
          ),
        ),
      ),
    );
  }

  Widget buildStepper(BuildContext context) {
    AppLocalizations loc = AppLocalizations.of(context)!;

    bool isPrefActiveOrPassed =
        showPreferances || showPassenger || showReviewAndConfirm;
    bool isPassActiveOrPassed = showPassenger || showReviewAndConfirm;

    return Container(
      decoration: BoxDecoration(color: Colors.black.withAlpha(140)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              spacing: 5,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildCompletedCheckMark(context),
                Text(
                  loc.tripInfo,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
            Expanded(
              child: Divider(
                color: isPrefActiveOrPassed
                    ? const Color(0xffE4A46B)
                    : Colors.grey.shade700,
                thickness: 1,
                indent: 20,
                endIndent: 20,
              ),
            ),
            Column(
              spacing: 5,
              mainAxisSize: MainAxisSize.min,
              children: [
                isPrefActiveOrPassed
                    ? buildCompletedCheckMark(context)
                    : buildIncompleteCheckMark(context),
                Text(
                  loc.preferences,
                  style: TextStyle(
                    fontSize: 12,
                    color: isPrefActiveOrPassed
                        ? Colors.white
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Divider(
                color: isPassActiveOrPassed
                    ? const Color(0xffE4A46B)
                    : Colors.grey.shade700,
                thickness: 1,
                indent: 20,
                endIndent: 20,
              ),
            ),
            Column(
              spacing: 5,
              mainAxisSize: MainAxisSize.min,
              children: [
                isPassActiveOrPassed
                    ? buildCompletedCheckMark(context)
                    : buildIncompleteCheckMark(context),
                Text(
                  loc.passenger,
                  style: TextStyle(
                    fontSize: 12,
                    color: isPassActiveOrPassed
                        ? Colors.white
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Get simplified list of city names for dropdowns
  List<String> _getAvailableCityNames(BuildContext context) {
    if (_apiCities.isNotEmpty) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';

      return _apiCities
          .where((c) {
            // Check 1: City must be active
            final bool cityActive = c['isActive'] == true;
            if (!cityActive) return false;

            // Check 2: If airport service, city must have at least one active airport
            if (_selectedCatCode == 0 || _selectedCatCode == 1) {
              final cityId = (c['_id'] ?? c['id'])?.toString();
              final hasActiveAirport = _apiAirports.any((a) {
                var aCityId = a['cityID'] ?? a['cityId'] ?? a['city_id'];
                if (aCityId is Map) aCityId = aCityId['_id'] ?? aCityId['id'];
                final aCityIdStr = aCityId?.toString();

                // Explicitly check for false; if missing, we could assume true or false.
                // Usually, if not specified, it's active unless deactivated.
                final bool airportActive = a['isActive'] != false;
                return aCityIdStr == cityId && airportActive;
              });
              if (!hasActiveAirport) return false;
            }

            // Check 3: For private transfer, ONLY show cities that HAVE zone pricing
            // (as requested: show only cities where private transfer is available)
            // Only apply this filter after zones have loaded to avoid blank dropdown
            if (_selectedCatCode == 3 && _allZones.isNotEmpty) {
              final cityId = (c['_id'] ?? c['id'])?.toString();
              final hasActiveZone = _allZones.any(
                (z) => z.cityId == cityId && z.isActive,
              );
              if (!hasActiveZone) return false;
            }

            return true;
          })
          .map(
            (c) =>
                (isArabic ? (c['cityNameAr'] ?? c['cityName']) : c['cityName'])
                    .toString(),
          )
          .toSet()
          .toList();
    }
    return [];
  }

  /// Get airports based on selected city (using cityID from _apiCities).
  ///
  /// Empty means the city has none; callers surface that rather than showing it
  /// as a selectable airport.
  List<String> _getAvailableAirports(BuildContext context) {
    if (_apiCities.isNotEmpty && _apiAirports.isNotEmpty) {
      try {
        if (_selectedCityCode < _apiCities.length) {
          final city = _apiCities[_selectedCityCode];
          final cityId = (city['_id'] ?? city['id'])?.toString();

          final filtered = _apiAirports
              .where((a) {
                var aCityId = a['cityID'] ?? a['cityId'] ?? a['city_id'];
                if (aCityId is Map) {
                  aCityId = aCityId['_id'] ?? aCityId['id'];
                }
                final aCityIdStr = aCityId?.toString();

                // If isActive is NOT explicitly false, we consider it active
                // (or if it's missing, we assume active unless user says otherwise)
                // But let's follow the 'set as false' rule.
                final bool isActive = a['isActive'] != false;

                return aCityIdStr != null && aCityIdStr == cityId && isActive;
              })
              .map((a) => a['airportName'].toString())
              .toSet()
              .toList();

          return filtered;
        }
      } catch (e) {
        debugPrint('Error filtering airports: $e');
      }
    }
    return const [];
  }

  /// Get terminals based on selected airport
  List<String> _getAvailableTerminals(BuildContext context) {
    if (_apiAirports.isNotEmpty && _apiTerminals.isNotEmpty) {
      try {
        final airportNames = _getAvailableAirports(context);
        if (airportNames.isNotEmpty) {
          // Find the selected airport object to get its ID
          final selectedAirportName =
              airportNames[_selectedAirportCode < airportNames.length
                  ? _selectedAirportCode
                  : 0];

          final airport = _apiAirports.firstWhere(
            (a) => a['airportName']?.toString() == selectedAirportName,
            orElse: () => {},
          );

          if (airport.isNotEmpty) {
            final airportId = (airport['_id'] ?? airport['id'])?.toString();

            final filtered = _apiTerminals
                .where((t) {
                  var tAirportId =
                      t['airportID'] ?? t['airportId'] ?? t['airport_id'];
                  if (tAirportId is Map) {
                    tAirportId = tAirportId['_id'] ?? tAirportId['id'];
                  }
                  final tAirportIdStr = tAirportId?.toString();
                  // Active unless explicitly set false — same rule the airport
                  // filter uses, and the default TerminalV2 itself applies. A
                  // stricter test would drop every terminal from a payload that
                  // omits the flag, and session init requires a terminalId.
                  final bool isActive = t['isActive'] != false;
                  return tAirportIdStr != null &&
                      tAirportIdStr == airportId &&
                      isActive;
                })
                .map((t) => t['terminalName'].toString())
                .toSet()
                .toList();

            if (filtered.isNotEmpty) return filtered;
          }
        }
      } catch (e) {
        debugPrint('Error filtering terminals: $e');
      }
    }
    return ["no terminals"];
  }

  String? _getSelectedTerminalName(BuildContext context) {
    final terminals = _getAvailableTerminals(context);
    if (terminals.isNotEmpty) {
      return terminals[_selectedTerminalCode < terminals.length
          ? _selectedTerminalCode
          : 0];
    }
    return "";
  }

  String? _getSelectedAirportName(BuildContext context) {
    final airports = _getAvailableAirports(context);
    if (airports.isNotEmpty) {
      return airports[_selectedAirportCode < airports.length
          ? _selectedAirportCode
          : 0];
    }
    return "";
  }

  String? _getSelectedAirportId() {
    if (_apiAirports.isNotEmpty) {
      final airportNames = _getAvailableAirports(context);
      if (airportNames.isNotEmpty) {
        final selectedAirportName =
            airportNames[_selectedAirportCode < airportNames.length
                ? _selectedAirportCode
                : 0];
        try {
          final airport = _apiAirports.firstWhere(
            (a) => a['airportName']?.toString() == selectedAirportName,
            orElse: () => {},
          );
          return (airport['_id'] ?? airport['id'])?.toString();
        } catch (e) {
          return null;
        }
      }
    }
    return null;
  }

  String? _getSelectedTerminalId() {
    if (_apiTerminals.isNotEmpty) {
      final terminalNames = _getAvailableTerminals(context);
      if (terminalNames.isNotEmpty) {
        final selectedTerminalName =
            terminalNames[_selectedTerminalCode < terminalNames.length
                ? _selectedTerminalCode
                : 0];
        try {
          final terminal = _apiTerminals.firstWhere(
            (t) => t['terminalName']?.toString() == selectedTerminalName,
            orElse: () => {},
          );
          return (terminal['_id'] ?? terminal['id'])?.toString();
        } catch (e) {
          return null;
        }
      }
    }
    return null;
  }

  String? _getSelectedCarId() {
    if (_cars.isNotEmpty) {
      try {
        final selectedCar = _cars.firstWhere(
          (c) =>
              c.className == _selectedVehicleClass &&
              c.brand == _selectedVehicleBrand &&
              c.modelName == _selectedVehicleModel,
          orElse: () => CarModel(
            id: '',
            className: '',
            brand: '',
            modelName: '',
            imagePath: '',
            price: 0,
            distance: 0,
            maxPassengers: 0,
          ),
        );
        return selectedCar.id.isNotEmpty ? selectedCar.id : null;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Helper to safely convert dynamic raw data from API to a list of maps
  List<Map<String, dynamic>> rawDataToList(dynamic rawData) {
    if (rawData is List) {
      return rawData
          .map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          })
          .where((m) => m.isNotEmpty)
          .toList();
    }
    return [];
  }
}
