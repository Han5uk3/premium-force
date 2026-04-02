import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:premium_force_main/bookings/bookings_page.dart';
import 'package:premium_force_main/common_widgets/bottomnavbar.dart';
import 'package:premium_force_main/account/account.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/home/homepage.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';

class Home extends StatefulWidget {
  const Home({super.key, this.isfromSuccessPage = false});
  final bool isfromSuccessPage;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final PageController _pageController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.isfromSuccessPage ? 1 : 0;
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onNavTapped(int index) {
    _pageController.jumpToPage(index);
  }

  Future<bool?> _showExitDialog(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1a1a1a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Color(0xff1a1a1a)),
        ),
        title: Text(
          loc.exitApp,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          loc.exitAppConfirm,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          SizedBox(
            height: 45,
            width: 80,
            child: PremiumButton(
              text: loc.exit,
              onTap: () => Navigator.pop(context, true),
              fontsize: 14,
              showLoader: false,
              borderRadius: 8.0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (_selectedIndex != 0) {
          _onNavTapped(0);
        } else {
          final shouldExit = await _showExitDialog(context);
          if (shouldExit == true) {
            if (Platform.isAndroid) {
              SystemNavigator.pop();
            } else {
              exit(0);
            }
          }
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: _onPageChanged,
          children: [Homepage(), BookingsPage(), AccountPage()],
        ),
        resizeToAvoidBottomInset: true,
        bottomNavigationBar: BottomNavBar(
          selectedIndex: _selectedIndex,
          onIndexChanged: _onNavTapped,
        ),
      ),
    );
  }
}

