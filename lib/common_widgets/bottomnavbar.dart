import 'dart:ui';

import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.only(
              top: 12,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            width: MediaQuery.of(context).size.width,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xff292929).withValues(alpha: 0.7),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              spacing: 8,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MenuIcon(
                  icon: Icons.home_outlined,
                  label: "Home",
                  isSelected: selectedIndex == 0,
                  onTap: () => onIndexChanged(0),
                ),
                MenuIcon(
                  icon: Icons.calendar_today_outlined,
                  label: "Bookings",
                  isSelected: selectedIndex == 1,
                  onTap: () => onIndexChanged(1),
                ),
                MenuIcon(
                  icon: Icons.account_circle_outlined,
                  label: "Profile",
                  isSelected: selectedIndex == 2,
                  onTap: () => onIndexChanged(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MenuIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const MenuIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<MenuIcon> createState() => _MenuIconState();
}

class _MenuIconState extends State<MenuIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.isSelected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant MenuIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: widget.isSelected
                  ? const LinearGradient(
                      colors: [
                        Color(0xff60350F),
                        Color(0xffE4A46B),
                        Color(0xffE4A46B),
                        Color(0xffE4A46B),
                        Color(0xffE4A46B),
                        Color(0xffE4A46B),
                      ],
                    )
                  : const LinearGradient(
                      colors: [Colors.transparent, Colors.transparent],
                    ),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            height: 50,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    widget.icon,
                    key: ValueKey(widget.isSelected),
                    color: widget.isSelected ? Colors.black : Colors.white,
                    size: 20,
                  ),
                ),
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: Alignment.centerLeft,
                    child: widget.isSelected
                        ? SlideTransition(
                            position: _slideAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 3),
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(width: 0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
