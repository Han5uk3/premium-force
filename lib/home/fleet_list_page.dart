import 'package:flutter/material.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/common_widgets/fleet_list_card.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';

class FleetListPage extends StatefulWidget {
  const FleetListPage({super.key});

  @override
  State<FleetListPage> createState() => _FleetListPageState();
}

class _FleetListPageState extends State<FleetListPage> {
  List<Map<String, dynamic>> _allFleetCars = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCachedFleet();
    _fetchAllCars();
  }

  void _loadCachedFleet() {
    final cached = UserLocalStorage.getFleetCars();
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _allFleetCars = cached;
      });
    }
  }

  Future<void> _fetchAllCars() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final api = ApiService();
      final response = await api.getCars().catchError((e) {
        debugPrint('❌ Error fetching cars list: $e');
        return <String, dynamic>{};
      });

      if (response['success'] == true) {
        List<Map<String, dynamic>> carList = [];
        for (String key in ['cars', 'data', 'result']) {
          if (response.containsKey(key)) {
            final data = response[key];
            if (data is List) {
              carList = data.map((e) => Map<String, dynamic>.from(e)).toList();
              if (carList.isNotEmpty) break;
            }
          }
        }

        // Search for any array if not found
        if (carList.isEmpty) {
          for (var entry in response.entries) {
            if (entry.value is List) {
              carList = (entry.value as List)
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
              break;
            }
          }
        }

        // Reverse the order (newest first)
        final reversedCarList = carList.reversed.toList();

        List<String> carIds = reversedCarList
            .map((car) => car['_id']?.toString() ?? car['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();

        await _fetchDetailedCars(carIds);
      }
    } catch (e) {
      debugPrint('❌ Error in _fetchAllCars: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDetailedCars(List<String> carIds) async {
    final api = ApiService();
    List<Map<String, dynamic>> detailedCars = [];

    // To improve speed, we could fetch these in chunks or parallel,
    // but the homepage does it sequentially. Let's do it in parallel for better performance here.
    final detailsFutures = carIds.map(
      (id) => api.getCarById(id).catchError((e) => <String, dynamic>{}),
    );
    final detailResponses = await Future.wait(detailsFutures);

    for (int i = 0; i < detailResponses.length; i++) {
      final carResponse = detailResponses[i];
      final carId = carIds[i];

      if (carResponse['success'] == true) {
        Map<String, dynamic>? carData;
        if (carResponse.containsKey('data')) {
          carData = Map<String, dynamic>.from(carResponse['data']);
        } else if (carResponse.containsKey('car')) {
          carData = Map<String, dynamic>.from(carResponse['car']);
        }

        if (carData != null) {
          dynamic brandDataObj =
              carData['brandID'] ?? carData['brandId'] ?? carData['brand'];
          String brandId = '';
          String brandName = 'Unknown';
          String? brandLogoUrl;

          if (brandDataObj is Map) {
            brandId =
                brandDataObj['_id']?.toString() ??
                brandDataObj['id']?.toString() ??
                '';
            brandName =
                brandDataObj['brandName']?.toString() ??
                brandDataObj['name']?.toString() ??
                'Unknown';

            if (brandDataObj.containsKey('brandIcon')) {
              final icon = brandDataObj['brandIcon'];
              if (icon is Map && icon.containsKey('url')) {
                brandLogoUrl = icon['url']?.toString();
              }
            }
          } else if (brandDataObj != null) {
            brandId = brandDataObj.toString();
          }

          String carImageUrl = '';
          if (carData['carImage'] != null && carData['carImage'] is Map) {
            carImageUrl = carData['carImage']['url']?.toString() ?? '';
          } else {
            carImageUrl =
                carData['imagePath']?.toString() ??
                carData['image']?.toString() ??
                '';
          }

          detailedCars.add({
            'id': carData['_id']?.toString() ?? carId,
            'brand': brandName,
            'brandId': brandId,
            'brandLogoUrl': brandLogoUrl,
            'name':
                carData['carName']?.toString() ??
                carData['modelName']?.toString() ??
                'Model',
            'passengerCount': (carData['numberOfPassengers'] ?? 4).toString(),
            'image': carImageUrl,
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _allFleetCars = detailedCars;
      });
      // Update global cache with full detailed results
      UserLocalStorage.saveFleetCars(detailedCars);
      // Fetch brand logos for those that don't have it yet
      _fetchBrandLogos();
    }
  }

  Future<void> _fetchBrandLogos() async {
    final api = ApiService();
    for (int i = 0; i < _allFleetCars.length; i++) {
      final car = _allFleetCars[i];
      if (car['brandId'].isEmpty || car['brandLogoUrl'] != null) continue;

      final brandRes = await api
          .getBrandById(car['brandId'])
          .catchError((e) => <String, dynamic>{});
      if (brandRes['success'] == true) {
        final brandData = brandRes['data'];
        if (brandData is Map) {
          String? logoUrl;
          if (brandData.containsKey('brandInfo')) {
            final info = brandData['brandInfo'];
            if (info is Map && info['icon'] is Map) {
              logoUrl = info['icon']['url']?.toString();
            }
          }
          if (logoUrl == null) {
            logoUrl =
                brandData['logo']?.toString() ?? brandData['icon']?.toString();
          }

          if (logoUrl != null && mounted) {
            setState(() {
              _allFleetCars[i]['brandLogoUrl'] = logoUrl;
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
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
        appBar: buildAppBar(context),
        body: _isLoading && _allFleetCars.isEmpty
            ? _buildLoadingGrid()
            : _allFleetCars.isEmpty
            ? Center(
                child: Text(
                  loc.noCarsAvailable,
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                cacheExtent: 1000,
                itemCount: _allFleetCars.length,
                itemBuilder: (context, index) {
                  final car = _allFleetCars[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FleetListCard(
                      brand: car['brand'],
                      name: car['name'],
                      passengerCount: car['passengerCount'],
                      image: car['image'],
                      brandLogoUrl: car['brandLogoUrl'],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 6,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AspectRatio(
          aspectRatio: 2.2,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: PremiumLoader(size: 32, color: Color(0xFFE4A46B)),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
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
            loc.premiumFleet,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
