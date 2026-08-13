import 'package:flutter_paytabs_bridge/IOSThemeConfiguration.dart';

/// The dark PayTabs SDK theme used by every payment screen in the app.
///
/// Extracted so the legacy [PaymentService] and the session-driven
/// [SessionPaymentService] present an identical checkout to the user.
IOSThemeConfigurations buildPremiumForceTheme() {
  final theme = IOSThemeConfigurations();
  theme.logoImage = 'assets/applogo/premiumforcelogo.png';

  // Screen background (black)
  theme.backgroundColor = '000000';
  theme.backgroundColorDark = '000000';

  // Primary accent color (grey)
  theme.primaryColor = '444444';
  theme.primaryColorDark = '444444';

  // Secondary / card container background
  theme.secondaryColor = '1E1E1E';
  theme.secondaryColorDark = '1E1E1E';

  // Text color in text fields (white)
  theme.primaryFontColor = 'FFFFFF';
  theme.primaryFontColorDark = 'FFFFFF';

  // Label / helper text color (light grey)
  theme.secondaryFontColor = 'E0E0E0';
  theme.secondaryFontColorDark = 'E0E0E0';

  // Button background and text color
  theme.buttonColor = '444444';
  theme.buttonColorDark = '444444';
  theme.buttonFontColor = 'FFFFFF';
  theme.buttonFontColorDark = 'FFFFFF';

  // Navigation title color
  theme.titleFontColor = 'FFFFFF';
  theme.titleFontColorDark = 'FFFFFF';

  // Borders / stroke
  theme.strokeColor = '444444';
  theme.strokeColorDark = '444444';
  theme.strokeThinckness = 1;

  // Text field placeholder and background colors
  theme.placeholderColor = '888888';
  theme.placeholderColorDark = '888888';
  theme.inputFieldBackgroundColor = '141313';
  theme.inputFieldBackgroundColorDark = '141313';

  return theme;
}
