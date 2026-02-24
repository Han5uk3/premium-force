import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:premium_force_main/storage/helpers.dart';

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
  final bool isPhoneNumber;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final VoidCallback? onTap;
  final bool readOnly;
  final int maxLines;
  final bool needBorder;
  final double borderRadius;
  final bool blackbg;
  final bool needAutoCapitalize;
  final FontWeight titleFontWeight;
  final Widget? suffix;
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
    this.isPhoneNumber = false,
    this.validator,
    this.fontsize = 16,
    this.enabled = true,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.borderRadius = 12,
    this.needBorder = false,
    this.blackbg = false,
    this.needAutoCapitalize = false,
    this.titleFontWeight = FontWeight.w400,
    this.suffix,
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
                  fontWeight: titleFontWeight,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // ── Styled input container ─────────────────────────
            GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: blackbg ? Colors.black : const Color(0xFF1A1410),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: hasError
                        ? const Color(0xFFCF6679)
                        : needBorder
                        ? Colors.grey.shade800
                        : const Color(0xFF1A1410),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: maxLines > 1
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 20),

                    if (prefixIcon != null) ...[
                      Padding(
                        padding: EdgeInsets.only(top: maxLines > 1 ? 14.0 : 0),
                        child: prefixIcon!,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: TextFormField(
                        textCapitalization: needAutoCapitalize
                            ? TextCapitalization.characters
                            : TextCapitalization.none,
                        // Validation is handled by the outer FormField;
                        // we skip it here so no error text renders inside.
                        inputFormatters: [
                          if (needAutoCapitalize) UpperCaseTextFormatter(),
                     
                          if (isPhoneNumber)
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
                          suffix: suffix,
                          hintText: hintText,
                          hintStyle: TextStyle(
                            color: Colors.white.withAlpha(180),
                            fontSize: fontsize,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 18,
                          ),
                          suffixIcon: maxLines > 1 ? null : suffixIcon,
                        ),
                        cursorColor: Colors.white,
                      ),
                    ),
                    if (maxLines > 1 && suffixIcon != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: suffixIcon!,
                      ),
                      const SizedBox(width: 16),
                    ] else ...[
                      const SizedBox(width: 20),
                    ],
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
