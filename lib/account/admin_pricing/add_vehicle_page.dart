import 'package:flutter/material.dart';
import '../../models/pricing/vehicle_model.dart';
import '../../services/firebase_pricing_service.dart';
import '../../common_widgets/button.dart';
import '../../common_widgets/textfield.dart';
import '../../common_widgets/snackbar.dart';

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _idController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _service = FirebasePricingService();
  bool _active = true;
  bool _loading = false;

  @override
  void dispose() {
    _idController.dispose();
    _nameEnController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_idController.text.isEmpty || _nameEnController.text.isEmpty) {
      AnimatedSnackBar.show(context, "Please fill all fields", "E");
      return;
    }

    setState(() => _loading = true);
    try {
      final vehicle = PricingVehicleModel(
        id: _idController.text.trim(),
        nameEn: _nameEnController.text.trim(),
        active: _active,
      );
      await _service.addVehicle(vehicle);
      if (mounted) {
        AnimatedSnackBar.show(context, "Vehicle added successfully!", "S");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AnimatedSnackBar.show(context, "Error adding vehicle: $e", "E");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1105),
      appBar: AppBar(
        title: const Text("Add New Vehicle", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            PremiumTextField(
              title: "Vehicle ID",
              controller: _idController,
              hintText: "Vehicle ID (Must match Backend ID exactly)",
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
            PremiumTextField(
              title: "Vehicle Name",
              controller: _nameEnController,
              hintText: "Vehicle Name (English display for admin)",
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text("Active Status", style: TextStyle(color: Colors.white, fontSize: 16)),
                const Spacer(),
                Switch(value: _active, onChanged: (v) => setState(() => _active = v)),
              ],
            ),
            const SizedBox(height: 32),
            PremiumButton(
              onTap: _save,
              text: "Save Vehicle",
              fontsize: 16,
              showLoader: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
