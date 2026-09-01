import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:premium_force_main/storage/helpers.dart';
import 'package:premium_force_main/theme/app_palette.dart';

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

  /// Render the value left-to-right without flipping the field's layout.
  ///
  /// Only meaningful alongside [isPhoneNumber], which otherwise forces the
  /// whole field LTR and drags its icon and text to the left edge in an RTL
  /// locale.
  final bool ltrValueOnly;
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
  final FocusNode? focusNode;
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
    this.ltrValueOnly = false,
    this.validator,
    this.fontsize = 14,
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
    this.focusNode,
  });

  // Phone numbers (and their country code prefix) must always read
  // left-to-right, even inside an RTL (Arabic) locale.
  //
  // [ltrValueOnly] narrows that to the value: the field keeps the ambient
  // direction, so it stays at the start edge with its icon like every other
  // field, while the number itself is still rendered LTR.
  Widget _maybeForceLtr(Widget child) {
    if (!isPhoneNumber || ltrValueOnly) return child;
    return Directionality(textDirection: TextDirection.ltr, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // [blackbg] asks for the higher-contrast fill: black on the dark theme,
    // white on the light one. Named for what it does rather than for the
    // colour it used to be.
    final fill = blackbg ? c.fieldStrong : c.field;

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
                  color: c.textPrimary,
                  fontSize: fontsize,
                  fontWeight: titleFontWeight,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // â”€â”€ Styled input container â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _maybeForceLtr(
              GestureDetector(
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      // Without [needBorder] the outline matches the fill, so
                      // the field reads as borderless while an error still has
                      // somewhere to draw its red.
                      color: hasError
                          ? c.error
                          : needBorder
                          ? c.border
                          : fill,
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
                          padding: EdgeInsets.only(
                            top: maxLines > 1 ? 14.0 : 0,
                          ),
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
                          // The value reads LTR, but sits against the locale's
                          // start edge. TextAlign.start would resolve against
                          // the overridden LTR direction and pin it left, so
                          // the ambient direction picks the edge instead.
                          textDirection: ltrValueOnly
                              ? TextDirection.ltr
                              : null,
                          textAlign: ltrValueOnly
                              ? (Directionality.of(context) == TextDirection.rtl
                                    ? TextAlign.right
                                    : TextAlign.left)
                              : TextAlign.start,
                          textAlignVertical: maxLines > 1
                              ? TextAlignVertical.top
                              : TextAlignVertical.center,
                          keyboardType: keyboardType,
                          focusNode: focusNode,
                          obscureText: obscureText,
                          enabled: enabled,
                          readOnly: readOnly,
                          maxLines: maxLines,
                          onTap: onTap,
                          style: TextStyle(
                            color: enabled ? c.textPrimary : c.textDisabled,
                            fontSize: fontsize,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            suffix: suffix,
                            hintText: hintText,
                            hintStyle: TextStyle(
                              color: c.textTertiary,
                              fontSize: fontsize,
                            ),
                            // Every border slot is pinned to none, not just
                            // [border]: the ambient InputDecorationTheme fills
                            // in whichever of them is left null, and this field
                            // draws its own container.
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                            ),
                            suffixIcon: maxLines > 1 ? null : suffixIcon,
                          ),
                          cursorColor: c.textPrimary,
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
            ),

            // â”€â”€ Error text below the container â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  fieldState.errorText!,
                  style: TextStyle(
                    color: c.error,
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
