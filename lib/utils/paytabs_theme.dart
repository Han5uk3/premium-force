import 'package:flutter/material.dart';
import 'package:flutter_paytabs_bridge/IOSThemeConfiguration.dart';
import 'package:premium_force_main/theme/app_palette.dart';

/// The PayTabs SDK theme used by every payment screen in the app.
///
/// The checkout sheet is drawn by the native SDK, not by Flutter, so it cannot
/// read [AppPalette] the way the rest of the app does — it takes a set of
/// six-digit hex strings and paints itself. This converts one palette into
/// those strings, so the gateway screen arrives in the same theme the customer
/// left the app in rather than always in the dark one.
///
/// Extracted so the legacy `PaymentService` and the session-driven
/// `SessionPaymentService` present an identical checkout.
IOSThemeConfigurations buildPremiumForceTheme(AppPalette palette) {
  final theme = IOSThemeConfigurations();
  theme.logoImage = 'assets/applogo/premiumforcelogo.png';

  // The SDK's own light/dark pair is set to the *same* value on purpose. It
  // switches on the device's appearance setting, which is not what the customer
  // chose here — the app has its own control, and honouring the OS instead
  // would hand a customer running the app light a dark checkout.
  void both(void Function(String) light, void Function(String) dark, Color c) {
    final value = _hex(c);
    light(value);
    dark(value);
  }

  // Screen background.
  both(
    (v) => theme.backgroundColor = v,
    (v) => theme.backgroundColorDark = v,
    palette.scaffold,
  );

  // Primary accent — the brand gold.
  both(
    (v) => theme.primaryColor = v,
    (v) => theme.primaryColorDark = v,
    palette.accent,
  );

  // Card container background.
  both(
    (v) => theme.secondaryColor = v,
    (v) => theme.secondaryColorDark = v,
    palette.surfaceElevated,
  );

  // Text inside the fields.
  both(
    (v) => theme.primaryFontColor = v,
    (v) => theme.primaryFontColorDark = v,
    palette.textPrimary,
  );

  // Labels and helper text.
  both(
    (v) => theme.secondaryFontColor = v,
    (v) => theme.secondaryFontColorDark = v,
    palette.textSecondary,
  );

  // The pay button, and the ink that reads on it.
  both(
    (v) => theme.buttonColor = v,
    (v) => theme.buttonColorDark = v,
    palette.accent,
  );
  both(
    (v) => theme.buttonFontColor = v,
    (v) => theme.buttonFontColorDark = v,
    palette.onAccent,
  );

  // Navigation title.
  both(
    (v) => theme.titleFontColor = v,
    (v) => theme.titleFontColorDark = v,
    palette.textPrimary,
  );

  // Borders.
  both(
    (v) => theme.strokeColor = v,
    (v) => theme.strokeColorDark = v,
    palette.border,
  );
  theme.strokeThinckness = 1;

  // Field placeholders and their fill.
  both(
    (v) => theme.placeholderColor = v,
    (v) => theme.placeholderColorDark = v,
    palette.textTertiary,
  );
  both(
    (v) => theme.inputFieldBackgroundColor = v,
    (v) => theme.inputFieldBackgroundColorDark = v,
    palette.field,
  );

  return theme;
}

/// A colour as the six hex digits the SDK expects — no leading `#`, no alpha.
String _hex(Color color) {
  String channel(double value) =>
      (value * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '${channel(color.r)}${channel(color.g)}${channel(color.b)}'
      .toUpperCase();
}
