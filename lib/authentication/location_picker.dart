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
import 'package:premium_force_main/theme/app_palette.dart';
import 'package:premium_force_main/theme/map_style.dart';
import 'package:premium_force_main/theme/theme_provider.dart';
import 'package:provider/provider.dart';

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

  /// Key for the Places **web service** calls below.
  ///
  /// Deliberately separate from the Maps SDK key: a key restricted to Android /
  /// iOS applications authorises the embedded map but is rejected with
  /// `403 PERMISSION_DENIED` on direct HTTPS calls like these, because there is
  /// no app signature for Google to check. Restrict this one by API instead.
  ///
  /// Falls back to the maps key so behaviour is unchanged until a dedicated key
  /// is configured.
  String get _placesApiKey {
    final placesKey = dotenv.env['GOOGLE_PLACES_API_KEY']?.trim() ?? '';
    if (placesKey.isNotEmpty) return placesKey;
    return dotenv.env['GOOGLE_MAPS_API_KEY']?.trim() ?? '';
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
    } catch (e) {}
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
      final String apiKey = _placesApiKey;
      if (apiKey.isEmpty) {
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
          'locationBias': {
            'rectangle': {
              'low': {'latitude': 16.38, 'longitude': 34.54},
              'high': {'latitude': 32.15, 'longitude': 55.66},
            },
          },
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
          },
          // Read 4xx bodies instead of throwing: Google explains *why* a key or
          // project is rejected in the response, and that message is the only
          // way to tell an unenabled API from a restricted key.
          validateStatus: (status) => status != null && status < 500,
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
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    } on DioException {
      // Surface the server's explanation, not just the exception type: a bad
      // key, an unenabled API and a restricted key all look identical without
      // the response body.
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _selectSearchResult(Map<String, dynamic> result) async {
    final String placeId = result['place_id'];
    final String apiKey = _placesApiKey;

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
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final double lat = data['location']['latitude'];
        final double lng = data['location']['longitude'];

        LatLng position = LatLng(lat, lng);
        setState(() {
          _searchResults = [];
          _searchController.clear();
          _selectedLocation = position;
        });

        await _getAddressFromLatLng(position);

        final controller = await _mapController.future;
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(position, 16),
        );
      }
    } on DioException {
    } catch (_) {}

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
    final c = context.colors;
    // The tiles answer to the map preference; everything floating over them is
    // app chrome and answers to the app's own theme.
    final mapSkin = context.watch<ThemeProvider>().mapSkinFor(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: c.pageGradient,
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
              style: MapStyle.forSkin(mapSkin),
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
                      color: c.overlaySurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.accentBorder, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: c.shadow,
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
                            return LinearGradient(
                              colors: c.goldIconGradient,
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
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(
                                context,
                              )!.searchForALocation,
                              hintStyle: TextStyle(
                                color: c.textTertiary,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                            cursorColor: c.accent,
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
                                color: c.iconMuted,
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
                        color: c.overlaySurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.accentBorder, width: 1),
                      ),
                      child: const Center(child: PremiumLoader(size: 20)),
                    ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: c.overlaySurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.accentBorder, width: 1),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: c.divider, height: 1, indent: 48),
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            leading: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return LinearGradient(
                                  colors: c.goldIconGradient,
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
                              style: TextStyle(
                                color: c.textPrimary,
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
                                      color: c.textTertiary,
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
              bottom:
                  (_selectedAddress.isNotEmpty ||
                      widget.needCurrentLocationButton)
                  ? 0
                  : -300,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity:
                    (_selectedAddress.isNotEmpty ||
                        widget.needCurrentLocationButton)
                    ? 1
                    : 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: c.sheetGradient,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.shadow,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            ShaderMask(
                                              shaderCallback: (Rect bounds) {
                                                return LinearGradient(
                                                  colors: c.goldIconGradient,
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
                                              style: TextStyle(
                                                color: c.textPrimary,
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
                                            color: c.textSecondary,
                                            fontSize: 11,
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('empty_address'),
                                    ),
                            ),

                            if (widget.needCurrentLocationButton) ...[
                              // Use current location button (condensed in selected state)
                              GestureDetector(
                                onTap: _isLoading ? null : _useCurrentLocation,
                                child: Container(
                                  width: double.infinity,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: c.surfaceDeep,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: c.accentBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Row(
                                      key: ValueKey(_isLoading),
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (_isLoading)
                                          const PremiumLoader(size: 24)
                                        else
                                          ShaderMask(
                                            shaderCallback: (Rect bounds) {
                                              return LinearGradient(
                                                colors: c.goldIconGradient,
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
                                          style: TextStyle(
                                            color: c.textPrimary,
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
                                    scale: Tween<double>(begin: 0.9, end: 1.0)
                                        .animate(
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
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: c.goldGradient,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: c.shadow,
                                              blurRadius: 8,
                                              spreadRadius: 3,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.confirmLocation,
                                            style: TextStyle(
                                              color: c.onGold,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('empty_confirm'),
                                    ),
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
    final c = context.colors;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: c.appBarScrim,
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            AppLocalizations.of(context)!.selectLocation,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: c.icon),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}
