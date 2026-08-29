import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/theme/app_palette.dart';

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
    final loc = AppLocalizations.of(context)!;
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(left: 18, right: 18, bottom: 22),
      // The bar floats over the page rather than sitting on it, so it is lifted
      // by a shadow. On the dark theme that shadow all but vanishes against
      // black — which is fine, the frost already separates it. On the light one
      // it is what stops a white bar dissolving into a near-white page.
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: c.shadow, blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
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
              // Already translucent — the blur behind it is doing the frosting,
              // so this must not be opaque.
              color: c.navBar,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(color: c.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              spacing: 8,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MenuIcon(
                  icon: Icons.home_outlined,
                  label: loc.home,
                  isSelected: selectedIndex == 0,
                  onTap: () => onIndexChanged(0),
                ),
                MenuIcon(
                  icon: Icons.calendar_today_outlined,
                  label: loc.bookings,
                  isSelected: selectedIndex == 1,
                  onTap: () => onIndexChanged(1),
                ),
                MenuIcon(
                  icon: Icons.account_circle_outlined,
                  label: loc.account,
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
    final c = context.colors;
    // The selected pill is a gold wash that starts dark and settles: one deep
    // stop, then the accent held across the rest of the width so the label sits
    // on flat gold rather than on a ramp.
    final selectedFill = LinearGradient(
      colors: [
        c.goldGradient[1],
        c.goldGradient[1],
        c.goldGradient[1],
        c.goldGradient[1],
        c.goldGradient[1],
        c.goldGradient[1],
      ],
    );

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
                  ? selectedFill
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
                    // Selected sits on gold and takes the on-gold ink;
                    // unselected sits on the frosted bar and takes the page's.
                    color: widget.isSelected ? c.onGold : c.textPrimary,
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
                                  style: TextStyle(
                                    color: c.onGold,
                                    fontSize: 12,
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

