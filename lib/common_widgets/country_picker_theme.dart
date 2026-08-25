import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/theme/app_palette.dart';

/// The country picker's look, in the app's colours.
///
/// The picker is a package sheet with no styling of its own worth keeping, so
/// every screen that opened one — sign-in, sign-up, the booking form — carried
/// its own sixty-line `CountryListThemeData`. Three copies of the same block is
/// three places to forget when a colour changes, which is exactly what a second
/// theme is. This is that block, once.
CountryListThemeData buildCountryListTheme(BuildContext context) {
  final c = context.colors;
  final loc = AppLocalizations.of(context)!;

  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );

  return CountryListThemeData(
    backgroundColor: c.surface,
    textStyle: TextStyle(color: c.textPrimary, fontSize: 14),
    searchTextStyle: TextStyle(color: c.textPrimary, fontSize: 14),
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(30),
      topRight: Radius.circular(30),
    ),
    inputDecoration: InputDecoration(
      hintText: loc.search,
      hintStyle: TextStyle(color: c.textTertiary),
      prefixIcon: Icon(Icons.search, color: c.icon),
      filled: true,
      fillColor: c.field,
      border: border(c.border),
      enabledBorder: border(c.border),
      focusedBorder: border(c.accent),
    ),
    bottomSheetHeight: MediaQuery.of(context).size.height * 0.75,
  );
}
