import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';

class LocationPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final bool needCurrentLocationButton;
  const LocationPickerPage({
    super.key,
    this.initialLat,
    this.initialLng,
    this.needCurrentLocationButton = true,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late LatLng _selectedLocation;
  String _selectedAddress = '';
  String _selectedCity = '';
  bool _isLoading = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(
      widget.initialLat ?? 24.7136,
      widget.initialLng ?? 46.6753,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      // Force English for address results
      await setLocaleIdentifier('en');
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _selectedAddress = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.country,
          ].where((e) => e != null && e.isNotEmpty).join(', ');
          _selectedCity = place.locality ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        debugPrint('âš ï¸ Missing Google Maps API Key in .env');
        setState(() => _isSearching = false);
        return;
      }

      // NO-COST Autocomplete call (New API)
      final Dio dio = Dio();
      const String url = 'https://places.googleapis.com/v1/places:autocomplete';

      final response = await dio.post(
        url,
        data: {
          'input': query,
          'includedRegionCodes': ['sa'],
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
          },
        ),
      );

      if (response.statusCode == 200) {
        final List suggestions = response.data['suggestions'] ?? [];
        final List<Map<String, dynamic>> results = [];

        for (var sug in suggestions) {
          final pred = sug['placePrediction'];
          if (pred == null) continue;

          results.add({
            'address': pred['text']?['text'] ?? '',
            'main_text': pred['structuredFormat']?['mainText']?['text'] ?? '',
            'secondary_text':
                pred['structuredFormat']?['secondaryText']?['text'] ?? '',
            'place_id': pred['placeId'],
          });
        }

        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      } else {
        debugPrint('âŒ Google Places (New) API Error: ${response.statusCode}');
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('âŒ Search failed: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _selectSearchResult(Map<String, dynamic> result) async {
    final String placeId = result['place_id'];
    final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

    setState(() => _isLoading = true);
    _searchFocusNode.unfocus();

    try {
      // Get Place details (New API)
      final Dio dio = Dio();
      final String url = 'https://places.googleapis.com/v1/places/$placeId';

      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            // Only request the fields we need to save costs
            'X-Goog-FieldMask':
                'id,location,formattedAddress,addressComponents',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final double lat = data['location']['latitude'];
        final double lng = data['location']['longitude'];
        final String formattedAddress =
            data['formattedAddress'] ?? result['address'];

        // Extract city (locality)
        String city = '';
        final List components = data['addressComponents'] ?? [];
        for (var comp in components) {
          final List types = comp['types'] ?? [];
          if (types.contains('locality') ||
              types.contains('administrative_area_level_2')) {
            city = comp['longText'] ?? '';
            break;
          }
        }

        LatLng position = LatLng(lat, lng);
        setState(() {
          _selectedLocation = position;
          _selectedAddress = formattedAddress;
          _selectedCity = city;
          _searchResults = [];
          _searchController.clear();
        });

        final controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(position, 16));
      }
    } catch (e) {
      debugPrint('âŒ Failed to resolve place details: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          AnimatedSnackBar.show(
            context,
            AppLocalizations.of(context)!.locationServicesAreDisabled,
            'E',
            actionText: AppLocalizations.of(context)!.settings,
            onAction: () => Geolocator.openLocationSettings(),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            AnimatedSnackBar.show(
              context,
              AppLocalizations.of(context)!.locationPermissionDenied,
              'E',
              actionText: AppLocalizations.of(context)!.settings,
              onAction: () => Geolocator.openAppSettings(),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AnimatedSnackBar.show(
            context,
            AppLocalizations.of(context)!.locationPermissionsPermanentlyDenied,
            'E',
            actionText: AppLocalizations.of(context)!.settings,
            onAction: () => Geolocator.openAppSettings(),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = currentLatLng;
      });

      await _getAddressFromLatLng(currentLatLng);

      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(currentLatLng, 16));
    } catch (e) {
      debugPrint('Error getting current location: $e');
      if (mounted) {
        AnimatedSnackBar.show(
          context,
          '${AppLocalizations.of(context)!.errorGettingLocation}$e',
          'E',
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E1105),
            Color(0xFF1E1105),
            Color.fromARGB(255, 26, 23, 23),
            Color.fromARGB(255, 26, 23, 23),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            // Map
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLocation,
                zoom: 11,
              ),
              onMapCreated: (controller) {
                _mapController.complete(controller);
              },
              onTap: (latLng) async {
                setState(() {
                  _selectedLocation = latLng;
                });
                await _getAddressFromLatLng(latLng);
              },
              markers: {
                Marker(
                  markerId: const MarkerId('selected'),
                  position: _selectedLocation,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange,
                  ),
                ),
              },
              mapType: MapType.normal,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              style: _mapDarkStyle,
            ),

            // Search bar overlay at top
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0A08).withAlpha(240),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF49280B),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(100),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              colors: [
                                Color(0xFF49280B),
                                Color(0xFFE4A46B),
                                Color(0xFF60350F),
                              ],
                            ).createShader(bounds);
                          },
                          child: const Icon(
                            Icons.search,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(
                                context,
                              )!.searchForALocation,
                              hintStyle: TextStyle(
                                color: Colors.white.withAlpha(120),
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                            cursorColor: const Color(0xFFE4A46B),
                            onChanged: (value) {
                              _debounceTimer?.cancel();
                              _debounceTimer = Timer(
                                const Duration(milliseconds: 600),
                                () => _searchLocation(value),
                              );
                            },
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Icons.close,
                                color: Colors.white.withAlpha(150),
                                size: 20,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),

                  // Search results dropdown
                  if (_isSearching)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0A08).withAlpha(240),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF49280B),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: PremiumLoader(
                          size: 20,
                          color: Color(0xFFE4A46B),
                        ),
                      ),
                    ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0A08).withAlpha(240),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF49280B),
                          width: 1,
                        ),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => Divider(
                          color: Colors.grey.shade800.withAlpha(100),
                          height: 1,
                          indent: 48,
                        ),
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            leading: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return const LinearGradient(
                                  colors: [
                                    Color(0xFF49280B),
                                    Color(0xFFE4A46B),
                                    Color(0xFF60350F),
                                  ],
                                ).createShader(bounds);
                              },
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              _searchResults[index]['main_text'].isNotEmpty
                                  ? _searchResults[index]['main_text']
                                  : _searchResults[index]['address'],
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle:
                                _searchResults[index]['secondary_text'] !=
                                        null &&
                                    _searchResults[index]['secondary_text']
                                        .isNotEmpty
                                ? Text(
                                    _searchResults[index]['secondary_text'],
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(150),
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () =>
                                _selectSearchResult(_searchResults[index]),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Bottom panel with address + buttons
            AnimatedPositioned(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutQuart,
              bottom: (_selectedAddress.isNotEmpty || widget.needCurrentLocationButton) ? 0 : -300,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: (_selectedAddress.isNotEmpty || widget.needCurrentLocationButton) ? 1 : 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF3E230A), Color(0xFF141313)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(150),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Animated Switcher for Address display
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.2),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: _selectedAddress.isNotEmpty
                                  ? Column(
                                      key: const ValueKey('address_display'),
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            ShaderMask(
                                              shaderCallback: (Rect bounds) {
                                                return const LinearGradient(
                                                  colors: [
                                                    Color(0xFF49280B),
                                                    Color(0xFFE4A46B),
                                                    Color(0xFF60350F),
                                                  ],
                                                ).createShader(bounds);
                                              },
                                              child: const Icon(
                                                Icons.location_on,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.selectedLocationDisplay,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _selectedAddress,
                                          style: TextStyle(
                                            color: Colors.white.withAlpha(180),
                                            fontSize: 11,
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                    )
                                  : const SizedBox.shrink(key: ValueKey('empty_address')),
                            ),

                          if (widget.needCurrentLocationButton) ...[
                            // Use current location button (condensed in selected state)
                            GestureDetector(
                              onTap: _isLoading ? null : _useCurrentLocation,
                              child: Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D0A08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF49280B),
                                    width: 1,
                                  ),
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Row(
                                    key: ValueKey(_isLoading),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isLoading)
                                        const PremiumLoader(
                                          size: 24,
                                          color: Color(0xFFE4A46B),
                                        )
                                      else
                                        ShaderMask(
                                          shaderCallback: (Rect bounds) {
                                            return const LinearGradient(
                                              colors: [
                                                Color(0xFF49280B),
                                                Color(0xFFE4A46B),
                                                Color(0xFF60350F),
                                              ],
                                            ).createShader(bounds);
                                          },
                                          child: const Icon(
                                            Icons.my_location,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _isLoading
                                            ? AppLocalizations.of(
                                                context,
                                              )!.gettingLocation
                                            : AppLocalizations.of(
                                                context,
                                              )!.useCurrentLocation,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Confirm button
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutBack,
                                    ),
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: _selectedAddress.isNotEmpty
                                ? GestureDetector(
                                    key: const ValueKey('confirm_button'),
                                    onTap: () {
                                      Navigator.pop(context, {
                                        'address': _selectedAddress,
                                        'city': _selectedCity,
                                        'lat': _selectedLocation.latitude,
                                        'lng': _selectedLocation.longitude,
                                      });
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Color(0xFF49280B),
                                            Color(0xFFE4A46B),
                                            Color(0xFF60350F),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(10),
                                            blurRadius: 8,
                                            spreadRadius: 3,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          AppLocalizations.of(context)!.confirmLocation,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(key: ValueKey('empty_confirm')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(150), Colors.transparent],
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            AppLocalizations.of(context)!.selectLocation,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}

// Dark map style JSON for premium look
const String _mapDarkStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
  {"featureType": "administrative.country", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#181818"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "poi.park", "elementType": "labels.text.stroke", "stylers": [{"color": "#1b1b1b"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#373737"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
  {"featureType": "road.highway.controlled_access", "elementType": "geometry", "stylers": [{"color": "#4e4e4e"}]},
  {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "transit", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]}
]
''';

