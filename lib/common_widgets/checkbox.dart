import 'package:flutter/material.dart';
import 'package:premium_force_main/theme/app_palette.dart';

class PremiumCheckbox extends StatelessWidget {
  final VoidCallback ontap;
  final bool isAgreed;
  const PremiumCheckbox({
    super.key,
    required this.ontap,
    required this.isAgreed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: ontap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 20,
        height: 20,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: isAgreed ? c.accentSoft : Colors.transparent,
          border: Border.all(color: c.accentSoft, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: isAgreed
              // The tick sits on the gold fill, so it takes the same colour a
              // label on a gold button would rather than the page's ink.
              ? Icon(
                  Icons.check,
                  size: 14,
                  color: c.onGold,
                  key: const ValueKey('check'),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ),
    );
  }
}
