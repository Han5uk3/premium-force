import 'package:flutter/material.dart';
import '../../models/pricing/city_model.dart';
import '../../models/pricing/zone_model.dart';
import '../../models/pricing/vehicle_model.dart';
import '../../models/pricing/route_model.dart';
import '../../services/firebase_pricing_service.dart';
import '../../common_widgets/button.dart';
import '../../common_widgets/textfield.dart';
import '../../common_widgets/snackbar.dart';

class AddRoutePage extends StatefulWidget {
  const AddRoutePage({super.key});

  @override
  State<AddRoutePage> createState() => _AddRoutePageState();
}

class _AddRoutePageState extends State<AddRoutePage> {
  final _priceController = TextEditingController();
  final _service = FirebasePricingService();

  List<CityModel> _cities = [];
  List<PricingVehicleModel> _vehicles = [];
  List<ZoneModel> _fromZones = [];
  List<ZoneModel> _toZones = [];

  PricingVehicleModel? _selectedVehicle;
  CityModel? _selectedFromCity;
  ZoneModel? _selectedFromZone;
  CityModel? _selectedToCity;
  ZoneModel? _selectedToZone;

  bool _active = true;
  bool _loading = false;
  bool _fetching = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final cities = await _service.fetchCities();
    final vehicles = await _service.fetchVehicles();
    if (mounted) {
      setState(() {
        _cities = cities;
        _vehicles = vehicles;
        _fetching = false;
      });
    }
  }

  Future<void> _loadFromZones(String cityId) async {
    final zones = await _service.fetchZones(cityId);
    setState(() {
      _fromZones = zones;
      _selectedFromZone = null;
    });
  }

  Future<void> _loadToZones(String cityId) async {
    final zones = await _service.fetchZones(cityId);
    setState(() {
      _toZones = zones;
      _selectedToZone = null;
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedVehicle == null || _selectedFromCity == null || _selectedToCity == null || _priceController.text.isEmpty) {
      AnimatedSnackBar.show(context, "Please fill required fields", "E");
      return;
    }

    setState(() => _loading = true);
    try {
      final route = RouteModel(
        vehicleId: _selectedVehicle!.id,
        fromCityId: _selectedFromCity!.id,
        fromZoneId: _selectedFromZone?.id,
        toCityId: _selectedToCity!.id,
        toZoneId: _selectedToZone?.id,
        price: double.parse(_priceController.text),
        active: _active,
      );
      await _service.addRoute(route);
      if (mounted) {
        AnimatedSnackBar.show(context, "Route added successfully!", "S");
        Navigator.pop(context);
        _service.clearCache();
      }
    } catch (e) {
      if (mounted) AnimatedSnackBar.show(context, "Error adding route: $e", "E");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1105),
      appBar: AppBar(
        title: const Text("Add New Route", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _fetching
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE4A46B)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Vehicle *", style: TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(height: 8),
                  _buildDropdown<PricingVehicleModel>(
                    value: _selectedVehicle,
                    hint: "Select Vehicle",
                    items: _vehicles.map((v) => DropdownMenuItem(value: v, child: Text(v.nameEn, style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) => setState(() => _selectedVehicle = v),
                  ),
                  const SizedBox(height: 24),
                  const Text("FROM *", style: TextStyle(color: Color(0xFFE4A46B), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildDropdown<CityModel>(
                    value: _selectedFromCity,
                    hint: "Select City",
                    items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c.nameEn, style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedFromCity = v);
                      if (v != null) _loadFromZones(v.id);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDropdown<ZoneModel>(
                    value: _selectedFromZone,
                    hint: "Select Zone (Optional)",
                    items: _fromZones.map((z) => DropdownMenuItem(value: z, child: Text(z.nameEn, style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) => setState(() => _selectedFromZone = v),
                  ),
                  const SizedBox(height: 24),
                  const Text("TO *", style: TextStyle(color: Color(0xFFE4A46B), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildDropdown<CityModel>(
                    value: _selectedToCity,
                    hint: "Select City",
                    items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c.nameEn, style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedToCity = v);
                      if (v != null) _loadToZones(v.id);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDropdown<ZoneModel>(
                    value: _selectedToZone,
                    hint: "Select Zone (Optional)",
                    items: _toZones.map((z) => DropdownMenuItem(value: z, child: Text(z.nameEn, style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) => setState(() => _selectedToZone = v),
                  ),
                  const SizedBox(height: 24),
                  PremiumTextField(
                    title: "Route Price",
                    controller: _priceController,
                    hintText: "Price (e.g., 250.00)",
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("Active Status", style: TextStyle(color: Colors.white, fontSize: 14)),
                      const Spacer(),
                      Switch(value: _active, onChanged: (v) => setState(() => _active = v)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  PremiumButton(
                    onTap: _save,
                    text: "Save Route",
                    fontsize: 14,
                    showLoader: _loading,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDropdown<T>({T? value, required String hint, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: DropdownButton<T>(
        dropdownColor: const Color(0xFF1E1105),
        value: value,
        hint: Text(hint, style: const TextStyle(color: Colors.grey)),
        isExpanded: true,
        underline: const SizedBox(),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

