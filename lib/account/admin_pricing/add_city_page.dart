import 'package:flutter/material.dart';
import '../../models/pricing/city_model.dart';
import '../../services/firebase_pricing_service.dart';
import '../../common_widgets/button.dart';
import '../../common_widgets/textfield.dart';
import '../../common_widgets/snackbar.dart';

class AddCityPage extends StatefulWidget {
  const AddCityPage({super.key});

  @override
  State<AddCityPage> createState() => _AddCityPageState();
}

class _AddCityPageState extends State<AddCityPage> {
  final _idController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _nameArController = TextEditingController();
  final _service = FirebasePricingService();
  bool _loading = false;

  @override
  void dispose() {
    _idController.dispose();
    _nameEnController.dispose();
    _nameArController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_idController.text.isEmpty || _nameEnController.text.isEmpty || _nameArController.text.isEmpty) {
      AnimatedSnackBar.show(context, "Please fill all fields", "E");
      return;
    }

    setState(() => _loading = true);
    try {
      final city = CityModel(
        id: _idController.text.trim().toLowerCase(),
        nameEn: _nameEnController.text.trim(),
        nameAr: _nameArController.text.trim(),
      );
      await _service.addCity(city);
      if (mounted) {
        AnimatedSnackBar.show(context, "City added successfully!", "S");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AnimatedSnackBar.show(context, "Error adding city", "E");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1105),
      appBar: AppBar(
        title: const Text("Add New City", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            PremiumTextField(
              title: "City ID",
              controller: _idController,
              hintText: "City ID (e.g., riyadh)",
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
            PremiumTextField(
              title: "Name (EN)",
              controller: _nameEnController,
              hintText: "City Name (English)",
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
            PremiumTextField(
              title: "Name (AR)",
              controller: _nameArController,
              hintText: "City Name (Arabic)",
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 32),
            PremiumButton(
              onTap: _save,
              text: "Save City",
              fontsize: 16,
              showLoader: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
