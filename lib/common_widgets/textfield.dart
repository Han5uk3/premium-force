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
  final int? maxLength;
  final bool enabled;
  final VoidCallback? onTap;
  final bool readOnly;
  final int maxLines;
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
    this.maxLength,
    this.enabled = true,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: controller.text,
      validator: validator != null ? (_) => validator!(controller.text) : null,
      builder: (FormFieldState<String> fieldState) {
        final hasError = fieldState.hasError && fieldState.errorText != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [

            if (needTitle) ...[
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontsize,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // ── Styled input container ─────────────────────────
            GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0A08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasError
                        ? const Color(0xFFCF6679)
                        : const Color(0xFF1A1410),
                    width: 1,
                  ),
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
                    if (prefixIcon != null) ...[
                      prefixIcon!,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: TextFormField(
                        // Validation is handled by the outer FormField;
                        // we skip it here so no error text renders inside.
                        inputFormatters: [
                          if (maxLength != null)
                            LengthLimitingTextInputFormatter(maxLength),
                          if (needCountryCode)
                            FilteringTextInputFormatter.digitsOnly,
                        ],
                        controller: controller,
                        keyboardType: keyboardType,
                        obscureText: obscureText,
                        enabled: enabled,
                        readOnly: readOnly,
                        maxLines: maxLines,
                        onTap: onTap,
                        style: TextStyle(
                          color: enabled
                              ? Colors.white
                              : Colors.white.withAlpha(120),
                          fontSize: fontsize,
                        ),
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: TextStyle(
                            color: Colors.white.withAlpha(180),
                            fontSize: fontsize,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 18,
                          ),
                          suffixIcon: suffixIcon,
                        ),
                        cursorColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
            ),

            // ── Error text below the container ─────────────────
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  fieldState.errorText!,
                  style: const TextStyle(
                    color: Color(0xFFCF6679),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
