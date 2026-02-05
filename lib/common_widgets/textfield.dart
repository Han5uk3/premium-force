import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool needTitle;
  final String title;
  final String hintText;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final double fontsize;
  final bool needCountryCode;
  final FormFieldValidator<String>? validator;
  const PremiumTextField({
    super.key,
    this.needTitle = true,
    required this.title,
    required this.controller,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.needCountryCode = false,
    this.validator,
    this.fontsize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        needTitle
            ? Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontsize,
                  fontWeight: FontWeight.w400,
                ),
              )
            : const SizedBox.shrink(),
        needTitle ? const SizedBox(height: 8) : const SizedBox.shrink(),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0A08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1A1410), width: 1),
          ),
          child: Row(
            children: [
              const SizedBox(width: 20),
              if (needCountryCode)
                const Text(
                  '(+966)   ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              Expanded(
                child: TextFormField(
                  validator: validator,
                  inputFormatters: [LengthLimitingTextInputFormatter(9)],
                  controller: controller,
                  keyboardType: keyboardType,
                  style: TextStyle(color: Colors.white, fontSize: fontsize),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: Colors.white.withAlpha(180),
                      fontSize: fontsize,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 18),
                  ),
                  cursorColor: Colors.white,
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ],
    );
  }
}
