import 'package:flutter/material.dart';

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
    return GestureDetector(
      onTap: ontap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 20,
        height: 20,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: isAgreed ? const Color(0xFFD4A574) : Colors.transparent,
          border: Border.all(color: const Color(0xFFD4A574), width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: isAgreed
              ? const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                  key: ValueKey('check'),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ),
    );
  }
}
