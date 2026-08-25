import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:premium_force_main/theme/app_palette.dart';

/// Builds the two [ThemeData]s the app runs on, from the two [AppPalette]s.
///
/// Everything here is derived: give [_build] a palette and it produces the
/// matching theme, so the light and dark apps can never drift apart in the
/// components Material draws for us — pickers, dialogs, sliders, the country
/// picker's search field. Widgets we draw ourselves read [AppPalette] directly.
abstract final class AppTheme {
  /// The typeface for the whole app, Arabic and Latin alike.
  ///
  /// Noto Naskh Arabic ships `latin` and `latin-ext` alongside `arabic`, so it
  /// draws the English text and the digits too. Using it for everything rather
  /// than only as an Arabic fallback keeps a mixed line — an Arabic address
  /// next to a Latin flight number — in one typeface with one set of metrics,
  /// instead of two fonts meeting mid-sentence.
  ///
  /// It also settles what Arabic looked like before any of this: the OS
  /// decided, so it was Noto Naskh on stock Android, SF Arabic or Geeza Pro on
  /// iOS, and an OEM face on Samsung and Xiaomi.
  ///
  /// The family's weight axis is 400–700, which is the full range it offers.
  /// The four bundled faces cover it exactly; the handful of `w300` and
  /// `w800`/`w900` styles in the app resolve to the nearest of them, since
  /// lighter and heavier cuts do not exist.
  static const String fontFamily = 'NotoNaskhArabic';

  static final ThemeData dark = _build(AppPalette.dark);
  static final ThemeData light = _build(AppPalette.light);

  /// The status-bar / navigation-bar style that goes with [brightness].
  ///
  /// Named for the app's brightness, not the icons': a dark app needs *light*
  /// icons over it. Screens that float a bar over a photo or a map override
  /// this locally.
  static SystemUiOverlayStyle overlayStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isDark
          ? AppPalette.dark.scaffold
          : AppPalette.light.scaffold,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
  }

  static ThemeData _build(AppPalette p) {
    final isDark = p.isDark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: p.accent,
          brightness: p.brightness,
        ).copyWith(
          primary: p.accent,
          onPrimary: p.onAccent,
          secondary: p.accentSoft,
          onSecondary: p.onAccent,
          surface: p.surface,
          onSurface: p.textPrimary,
          surfaceContainerHighest: p.surfaceAlt,
          onSurfaceVariant: p.textSecondary,
          error: p.error,
          onError: isDark ? Colors.black : Colors.white,
          outline: p.border,
          outlineVariant: p.divider,
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: p.inverseSurface,
          onInverseSurface: p.textInverse,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: p.scaffold,
      canvasColor: p.surface,
      dividerColor: p.divider,
      splashColor: p.accent.withValues(alpha: 0.10),
      highlightColor: p.accent.withValues(alpha: 0.06),
      // Registered here so `context.colors` resolves anywhere below
      // [MaterialApp], and so Flutter cross-fades the palette on a mode change
      // instead of snapping the whole app in one frame.
      extensions: <ThemeExtension<dynamic>>[p],

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: p.textPrimary),
        actionsIconTheme: IconThemeData(color: p.textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        systemOverlayStyle: overlayStyle(p.brightness),
      ),

      iconTheme: IconThemeData(color: p.icon),
      primaryIconTheme: IconThemeData(color: p.icon),

      // The country picker, the date picker and every `showModalBottomSheet`
      // that does not paint its own container land on these.
      dialogTheme: DialogThemeData(
        backgroundColor: p.sheet,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.textSecondary,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.sheet,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.sheet,
        modalBarrierColor: p.scrim,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.icon,
        textColor: p.textPrimary,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(fontFamily: fontFamily, color: p.textPrimary),
      ),
      dividerTheme: DividerThemeData(color: p.divider, space: 1, thickness: 1),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        circularTrackColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.border,
        thumbColor: p.accent,
        overlayColor: p.accent.withValues(alpha: 0.12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accent
              : p.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accent.withValues(alpha: 0.35)
              : p.surfaceAlt,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accent
              : p.borderStrong,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accent
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(p.onAccent),
        side: BorderSide(color: p.borderStrong, width: 1.5),
      ),

      // Text and cursor colours only — deliberately no `filled` and no borders.
      //
      // [InputDecoration.applyDefaults] fills a decoration's *null* slots from
      // here, and the app's own fields draw their own container and pass
      // `border: InputBorder.none` while leaving `enabledBorder` unset. A
      // border defined here would therefore be adopted by every one of them and
      // ring each field with an outline it was designed without.
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(fontFamily: fontFamily, color: p.textTertiary),
        labelStyle: TextStyle(fontFamily: fontFamily, color: p.textSecondary),
        floatingLabelStyle: TextStyle(fontFamily: fontFamily, color: p.accent),
        errorStyle: TextStyle(fontFamily: fontFamily, color: p.error),
      ),

      textSelectionTheme: TextSelectionThemeData(
        // The country picker's search field takes its cursor from the ambient
        // theme too. A field that wants a different one, like the review
        // sheet's gold, still overrides this locally.
        cursorColor: p.textPrimary,
        // The handle and the highlight are set together: a gold handle
        // dragging a Material-purple selection reads as two different
        // controls.
        selectionHandleColor: p.accent,
        selectionColor: p.accent.withValues(alpha: 0.32),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accent),
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.sheet,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.accentSurface,
        headerForegroundColor: p.textPrimary,
        todayForegroundColor: WidgetStateProperty.all(p.accent),
        todayBorder: BorderSide(color: p.accent),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.onAccent
              : states.contains(WidgetState.disabled)
              ? p.textDisabled
              : p.textPrimary,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accent
              : Colors.transparent,
        ),
        yearForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.onAccent
              : p.textPrimary,
        ),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accent
              : Colors.transparent,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.sheet,
        dialBackgroundColor: p.surfaceAlt,
        dialHandColor: p.accent,
        hourMinuteColor: p.surfaceAlt,
        hourMinuteTextColor: p.textPrimary,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceElevated,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.textPrimary,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.textInverse,
          fontSize: 12,
        ),
      ),
    );
  }
}
