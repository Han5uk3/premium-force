import 'package:flutter/material.dart';
import '../../models/pricing/city_model.dart';
import '../../models/pricing/zone_model.dart';
import '../../services/firebase_pricing_service.dart';
import '../../common_widgets/button.dart';
import '../../common_widgets/textfield.dart';
import '../../common_widgets/snackbar.dart';

class AddZonePage extends StatefulWidget {
  const AddZonePage({super.key});

  @override
  State<AddZonePage> createState() => _AddZonePageState();
}

class _AddZonePageState extends State<AddZonePage> {
  final _idController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _nameArController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController();
  final _priorityController = TextEditingController(text: "10");
  final _service = FirebasePricingService();

  List<CityModel> _cities = [];
  CityModel? _selectedCity;
  bool _loading = false;
  bool _fetching = true;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    final cities = await _service.fetchCities();
    if (mounted) {
      setState(() {
        _cities = cities;
        _fetching = false;
      });
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameEnController.dispose();
    _nameArController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_idController.text.isEmpty || _nameEnController.text.isEmpty || _nameArController.text.isEmpty || _selectedCity == null) {
      AnimatedSnackBar.show(context, "Please fill all fields", "E");
      return;
    }

    setState(() => _loading = true);
    try {
      final zone = ZoneModel(
        id: _idController.text.trim().toLowerCase(),
        cityId: _selectedCity!.id,
        nameEn: _nameEnController.text.trim(),
        nameAr: _nameArController.text.trim(),
        type: "radius",
        center: {
          "lat": double.parse(_latController.text),
          "lng": double.parse(_lngController.text),
        },
        radiusKm: double.parse(_radiusController.text),
        priority: int.parse(_priorityController.text),
      );
      await _service.addZone(zone);
      if (mounted) {
        AnimatedSnackBar.show(context, "Zone added successfully!", "S");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AnimatedSnackBar.show(context, "Error adding zone: $e", "E");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1105),
      appBar: AppBar(
        title: const Text("Add New Zone", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _fetching
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE4A46B)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withAlpha(20)),
                    ),
                    child: DropdownButton<CityModel>(
                      dropdownColor: const Color(0xFF1E1105),
                      value: _selectedCity,
                      hint: const Text("Select City", style: TextStyle(color: Colors.grey)),
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _cities.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.nameEn, style: const TextStyle(color: Colors.white)),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedCity = v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PremiumTextField(
                    title: "Zone ID",
                    controller: _idController,
                    hintText: "Zone ID (unique per city)",
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 16),
                  PremiumTextField(
                    title: "Name (EN)",
                    controller: _nameEnController,
                    hintText: "Zone Name (English)",
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 16),
                  PremiumTextField(
                    title: "Name (AR)",
                    controller: _nameArController,
                    hintText: "Zone Name (Arabic)",
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: PremiumTextField(
                          title: "Latitude",
                          controller: _latController,
                          hintText: "Lat (e.g., 24.1234)",
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: PremiumTextField(
                          title: "Longitude",
                          controller: _lngController,
                          hintText: "Lng (e.g., 46.1234)",
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PremiumTextField(
                    title: "Radius (KM)",
                    controller: _radiusController,
                    hintText: "Radius in KM (e.g., 5.0)",
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  PremiumTextField(
                    title: "Priority",
                    controller: _priorityController,
                    hintText: "Priority (Lower = Higher Rank)",
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 32),
                  PremiumButton(
                    onTap: _save,
                    text: "Save Zone",
                    fontsize: 16,
                    showLoader: _loading,
                  ),
                ],
              ),
            ),
    );
  }
}
