import 'package:flutter/material.dart';
import 'add_city_page.dart';
import 'add_zone_page.dart';
import 'add_vehicle_page.dart';
import 'add_route_page.dart';

class AdminPricingDashboard extends StatelessWidget {
  const AdminPricingDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1105),
      appBar: AppBar(
        title: const Text("Pricing Admin", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _AdminTile(
            title: "Manage Cities",
            subtitle: "Add/Edit Firestore cities",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCityPage())),
          ),
          const SizedBox(height: 16),
          _AdminTile(
            title: "Manage Zones",
            subtitle: "Add/Edit radius-based zones for cities",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddZonePage())),
          ),
          const SizedBox(height: 16),
          _AdminTile(
            title: "Manage Vehicles",
            subtitle: "Add/Edit vehicle IDs for pricing",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddVehiclePage())),
          ),
          const SizedBox(height: 16),
          _AdminTile(
            title: "Manage Routes",
            subtitle: "Define pricing between cities and zones",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddRoutePage())),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminTile({required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(40)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFFE4A46B), size: 16),
          ],
        ),
      ),
    );
  }
}

