import 'package:flutter/material.dart';
import 'package:premium_force_main/common_widgets/bottomnavbar.dart';
import 'package:premium_force_main/home/homepage.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;

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
    _pageController.jumpToPage(
      index,
      // duration: const Duration(milliseconds: 300),
      // curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [Homepage(), Placeholder(), Placeholder()],
      ),
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onIndexChanged: _onNavTapped,
      ),
    );
  }
}
