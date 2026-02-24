import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class RiyalSymbol extends StatelessWidget {
  const RiyalSymbol({super.key, required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/icons/saudi_riyal.svg',
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}
