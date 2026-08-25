import 'package:flutter/material.dart';

/// Every colour the app paints with, named for the job it does rather than the
/// shade it happens to be.
///
/// The app used to hard-code its palette at each call site — `Colors.white` for
/// body copy, `0xFF141313` for a card, `0xFFE4A46B` for the gold. That works
/// exactly once: for a single brightness. Naming the roles instead lets the
/// same widget tree paint itself dark or light by reading the ambient theme.
///
/// Registered on [ThemeData.extensions], so it is reachable anywhere a
/// [BuildContext] is: `context.colors.textPrimary`. It is a [ThemeExtension],
/// so Flutter also lerps it — the whole app cross-fades when the mode changes
/// instead of snapping.
///
/// ### Adding a token
/// Add the field, then give it a value in **both** [dark] and [light] and a
/// line in [copyWith] and [lerp]. A token that exists in one brightness only is
/// the bug this class was written to prevent.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.scaffold,
    required this.pageGradient,
    required this.appBarScrim,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceElevated,
    required this.surfaceDeep,
    required this.stripSurface,
    required this.sheet,
    required this.sheetGradient,
    required this.field,
    required this.fieldStrong,
    required this.overlaySurface,
    required this.navBar,
    required this.inverseSurface,
    required this.brandCanvas,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textInverse,
    required this.onAccent,
    required this.onGold,
    required this.icon,
    required this.iconMuted,
    required this.accent,
    required this.accentSoft,
    required this.accentDeep,
    required this.accentMuted,
    required this.accentSurface,
    required this.accentBorder,
    required this.goldGradient,
    required this.goldIconGradient,
    required this.goldDisabledGradient,
    required this.divider,
    required this.dividerStrong,
    required this.border,
    required this.borderStrong,
    required this.success,
    required this.successSurface,
    required this.successBorder,
    required this.error,
    required this.errorSurface,
    required this.errorBorder,
    required this.warning,
    required this.warningSurface,
    required this.warningBorder,
    required this.info,
    required this.infoSurface,
    required this.infoBorder,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.skeleton,
    required this.scrim,
    required this.shadow,
    required this.mapPlaceholder,
    required this.mapPlaceholderHighlight,
  });

  /// Which brightness this palette *is*, so code holding the palette can branch
  /// without also reaching for [Theme.of].
  final Brightness brightness;

  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  /// Flat page background, for screens that do not draw the gradient.
  final Color scaffold;

  /// The four-stop background every main screen sits on: warm at the top,
  /// neutral at the bottom, in both brightnesses.
  final List<Color> pageGradient;

  /// Two-stop wash drawn behind a transparent app bar so its title stays
  /// legible over whatever scrolls under it. Runs bottom to top, opaque to
  /// clear.
  final List<Color> appBarScrim;

  /// Primary card / panel.
  final Color surface;

  /// Secondary block inside a card — a row, an inner well.
  final Color surfaceAlt;

  /// Raised above the page: menus, popups, floating cards.
  final Color surfaceElevated;

  /// The deepest well on the page, below [surface].
  final Color surfaceDeep;

  /// The warm band a booking card runs its date / passengers / vehicle row on,
  /// and the matching strip on the details page.
  ///
  /// Its own token rather than a reuse of [surfaceAlt]: this one is deliberately
  /// *warmer* than the neutral surfaces around it, which is what separates the
  /// row from the card it sits inside.
  final Color stripSurface;

  /// Bottom sheets and dialogs.
  final Color sheet;

  /// The two-stop wash the larger sheets are built on — a warm gold head
  /// falling to the neutral surface below it.
  ///
  /// Runs top to bottom. The head is what tells a half-height sheet apart from
  /// the page it has covered.
  final List<Color> sheetGradient;

  /// Text-field fill.
  final Color field;

  /// The higher-contrast field fill (what used to be the blackbg variant).
  final Color fieldStrong;

  /// A chip or pill floating over a map or a photo, where whatever sits
  /// underneath cannot be predicted.
  final Color overlaySurface;

  /// The frosted bottom navigation bar. Carries its own alpha.
  final Color navBar;

  /// A surface deliberately opposite to the current mode, for the rare element
  /// that has to invert.
  final Color inverseSurface;

  /// The ground the app logo is drawn on.
  ///
  /// Deep warm brown in *both* themes, and deliberately so: the logo is a fixed
  /// PNG whose second word and tagline are white, and those disappear on ivory.
  /// Rather than wash the mark out, the light theme keeps a dark plate behind it
  /// — a dark hero over a light sheet, which is the shape the home screen
  /// already uses.
  final Color brandCanvas;

  // ---------------------------------------------------------------------------
  // Content
  // ---------------------------------------------------------------------------

  /// Body copy and headings.
  final Color textPrimary;

  /// Supporting copy — labels, captions, secondary rows.
  final Color textSecondary;

  /// The quietest readable text: hints, timestamps, helper lines.
  final Color textTertiary;

  /// Text inside a disabled control.
  final Color textDisabled;

  /// Text drawn on [inverseSurface].
  final Color textInverse;

  /// Text and icons on a fill of the solid [accent].
  ///
  /// Flips with the mode, because [accent] does: black on dark mode's pale gold,
  /// white on light mode's bronze. Reusing one ink for both would leave every
  /// accent-filled control unreadable in one of them.
  final Color onAccent;

  /// Text and icons on a fill of [goldGradient] — a button, the selected nav
  /// pill, the gold checkbox.
  ///
  /// Black in *both* modes, unlike [onAccent]: that gradient does not change
  /// between them, so neither can the ink on it.
  final Color onGold;

  /// Default icon colour, matching [textPrimary] in weight.
  final Color icon;

  /// A de-emphasised icon.
  final Color iconMuted;

  // ---------------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------------

  /// The brand gold, at the weight that reads on *this* mode's background.
  ///
  /// Dark keeps the signature 0xFFE4A46B. Light cannot: that shade carries
  /// about 1.9:1 against ivory, so it deepens to a bronze that clears 4.5:1 on
  /// every light surface here — including [surfaceDeep], the darkest of them —
  /// while staying unmistakably the same colour family.
  final Color accent;

  /// A softer gold for decoration — loaders, rules, inactive marks.
  final Color accentSoft;

  /// The dark end of the gold ramp.
  final Color accentDeep;

  /// The mid-dark gold, between [accentDeep] and [accent].
  final Color accentMuted;

  /// A gold-tinted background for badges and highlighted rows.
  final Color accentSurface;

  /// A gold-tinted hairline, for borders around [accentSurface].
  final Color accentBorder;

  /// The three-stop gold used to *fill* something — buttons, hairline frames,
  /// the selected nav pill. Identical in both modes: a filled gold chip is the
  /// brand's signature and reads the same on black or on ivory.
  final List<Color> goldGradient;

  /// The gold used to paint an icon or text sitting **on the page background**,
  /// via a [ShaderMask].
  ///
  /// Distinct from [goldGradient] because the two are seen against opposite
  /// grounds: the light middle stop that makes the ramp glow on black
  /// disappears on ivory, so light mode shifts the whole ramp darker.
  final List<Color> goldIconGradient;

  /// The muted stand-in for [goldGradient] on a disabled button.
  final List<Color> goldDisabledGradient;

  // ---------------------------------------------------------------------------
  // Lines
  // ---------------------------------------------------------------------------

  /// Hairline between list rows.
  final Color divider;

  /// A divider meant to be noticed — a section break.
  final Color dividerStrong;

  /// Outline around a card or an input.
  final Color border;

  /// Outline on a focused or selected control.
  final Color borderStrong;

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  final Color success;
  final Color successSurface;
  final Color successBorder;

  final Color error;
  final Color errorSurface;
  final Color errorBorder;

  final Color warning;
  final Color warningSurface;
  final Color warningBorder;

  final Color info;
  final Color infoSurface;
  final Color infoBorder;

  // ---------------------------------------------------------------------------
  // Effects
  // ---------------------------------------------------------------------------

  /// Base and highlight for the shimmer package's loading sweep.
  final Color shimmerBase;
  final Color shimmerHighlight;

  /// A solid placeholder block inside a shimmering skeleton.
  final Color skeleton;

  /// Full-screen dim behind a modal or a blocking loader. Carries its own
  /// alpha — paint it as-is.
  final Color scrim;

  /// Drop-shadow colour, alpha included.
  final Color shadow;

  /// Fill and sweep for the map skeleton, which imitates map tiles rather than
  /// the app's own surfaces — so it tracks the *map's* brightness, not the
  /// app's.
  final Color mapPlaceholder;
  final Color mapPlaceholderHighlight;

  /// True when this palette paints the dark app.
  bool get isDark => brightness == Brightness.dark;

  /// The palette in force for [context].
  ///
  /// Falls back to [dark] rather than throwing: a widget built outside a themed
  /// subtree — an overlay entry raised from a bare [Overlay], say — should
  /// render in the app's original colours, not crash.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? dark;

  // ---------------------------------------------------------------------------
  // The dark palette — the app as it shipped.
  // ---------------------------------------------------------------------------

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    scaffold: Color(0xFF000000),
    pageGradient: [
      Color(0xFF1E1105),
      Color(0xFF1E1105),
      Color(0xFF1A1717),
      Color(0xFF1A1717),
    ],
    appBarScrim: [Color(0x64000000), Color(0x00000000)],
    surface: Color(0xFF141313),
    surfaceAlt: Color(0xFF1A1A1A),
    surfaceElevated: Color(0xFF1E1E1E),
    surfaceDeep: Color(0xFF0D0A08),
    stripSurface: Color(0xFF332627),
    sheet: Color(0xFF1E1105),
    sheetGradient: [Color(0xFF3E230A), Color(0xFF141313)],
    field: Color(0xFF1A1410),
    fieldStrong: Color(0xFF000000),
    overlaySurface: Color(0xFF1E1E1E),
    navBar: Color(0xB3292929),
    inverseSurface: Color(0xFFFFFFFF),
    brandCanvas: Color(0xFF1E1105),

    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFCFC9C2),
    textTertiary: Color(0xFF9E9791),
    textDisabled: Color(0xFF6B6560),
    textInverse: Color(0xFF141210),
    onAccent: Color(0xFF000000),
    onGold: Color(0xFF000000),
    icon: Color(0xFFFFFFFF),
    iconMuted: Color(0xFF9E9791),

    accent: Color(0xFFE4A46B),
    accentSoft: Color(0xFFD4A574),
    accentDeep: Color(0xFF49280B),
    accentMuted: Color(0xFF60350F),
    accentSurface: Color(0xFF3E230A),
    accentBorder: Color(0xFF60350F),
    goldGradient: [Color(0xFF49280B), Color(0xFFE4A46B), Color(0xFF60350F)],
    goldIconGradient: [Color(0xFF49280B), Color(0xFFE4A46B), Color(0xFF60350F)],
    goldDisabledGradient: [
      Color(0xFF332B22),
      Color(0xFF4E4335),
      Color(0xFF332B22),
    ],

    divider: Color(0xFF2E2A26),
    dividerStrong: Color(0xFF424242),
    border: Color(0xFF3A3733),
    borderStrong: Color(0xFF616161),

    success: Color(0xFF4CAF50),
    successSurface: Color(0xFF16240F),
    successBorder: Color(0xFF2E7D32),

    error: Color(0xFFCF6679),
    errorSurface: Color(0xFF332627),
    errorBorder: Color(0xFF8E3B45),

    warning: Color(0xFFFFA726),
    warningSurface: Color(0xFF2A2013),
    warningBorder: Color(0xFF7A5A20),

    info: Color(0xFF7B61FF),
    infoSurface: Color(0xFF1A1A2E),
    infoBorder: Color(0xFF3A3560),

    shimmerBase: Color(0xFF1A1A1A),
    shimmerHighlight: Color(0xFF292929),
    skeleton: Color(0xFF1E1E1E),
    scrim: Color(0x8C000000),
    shadow: Color(0x66000000),
    mapPlaceholder: Color(0xFF1B1B1B),
    mapPlaceholderHighlight: Color(0xFF2A2A2A),
  );

  // ---------------------------------------------------------------------------
  // The light palette.
  // ---------------------------------------------------------------------------
  //
  // Warm rather than clinical: the page runs from ivory at the top to a neutral
  // paper grey at the bottom, mirroring the dark theme's brown-to-charcoal
  // descent. Cards are white so they lift off it, and the gold deepens to a
  // bronze that holds its contrast on ivory.

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    scaffold: Color(0xFFFAF7F3),
    pageGradient: [
      Color(0xFFFCF6EE),
      Color(0xFFFCF6EE),
      Color(0xFFF6F4F2),
      Color(0xFFF6F4F2),
    ],
    appBarScrim: [Color(0x0F000000), Color(0x00000000)],
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF7F2EB),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceDeep: Color(0xFFF1EAE0),
    stripSurface: Color(0xFFF4EDE6),
    sheet: Color(0xFFFFFDFA),
    sheetGradient: [Color(0xFFF7EDE0), Color(0xFFFFFDFA)],
    field: Color(0xFFF5F0E8),
    fieldStrong: Color(0xFFFFFFFF),
    overlaySurface: Color(0xFFFFFFFF),
    navBar: Color(0xE6FFFFFF),
    inverseSurface: Color(0xFF17140F),
    brandCanvas: Color(0xFF1E1105),

    textPrimary: Color(0xFF17140F),
    textSecondary: Color(0xFF5E574E),
    textTertiary: Color(0xFF6F6961),
    textDisabled: Color(0xFFB3ABA1),
    textInverse: Color(0xFFFFFFFF),
    onAccent: Color(0xFFFFFFFF),
    onGold: Color(0xFF000000),
    icon: Color(0xFF2A251F),
    iconMuted: Color(0xFF6F6961),

    accent: Color(0xFF925C17),
    accentSoft: Color(0xFFA5732C),
    accentDeep: Color(0xFF7A4A12),
    accentMuted: Color(0xFF8C5A1E),
    accentSurface: Color(0xFFF7EDE0),
    accentBorder: Color(0xFFE5D3B8),
    goldGradient: [Color(0xFF49280B), Color(0xFFE4A46B), Color(0xFF60350F)],
    goldIconGradient: [Color(0xFF7A4A12), Color(0xFFA5732C), Color(0xFF7A4A12)],
    goldDisabledGradient: [
      Color(0xFFE0D7C9),
      Color(0xFFEDE5D9),
      Color(0xFFE0D7C9),
    ],

    divider: Color(0xFFEAE3D9),
    dividerStrong: Color(0xFFDDD5C9),
    border: Color(0xFFE2DACE),
    borderStrong: Color(0xFFC9C0B2),

    success: Color(0xFF2E7D32),
    successSurface: Color(0xFFE8F3E9),
    successBorder: Color(0xFFB7DCB9),

    error: Color(0xFFB3261E),
    errorSurface: Color(0xFFFCEBEA),
    errorBorder: Color(0xFFF0C2BE),

    warning: Color(0xFF9A5900),
    warningSurface: Color(0xFFFDF3E2),
    warningBorder: Color(0xFFEBD5A8),

    info: Color(0xFF5B45D6),
    infoSurface: Color(0xFFEEEBFB),
    infoBorder: Color(0xFFCFC7F5),

    shimmerBase: Color(0xFFE9E3DA),
    shimmerHighlight: Color(0xFFF8F5F1),
    skeleton: Color(0xFFEDE7DE),
    scrim: Color(0x59000000),
    shadow: Color(0x14000000),
    mapPlaceholder: Color(0xFFE8EAED),
    mapPlaceholderHighlight: Color(0xFFF6F7F9),
  );

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? scaffold,
    List<Color>? pageGradient,
    List<Color>? appBarScrim,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceElevated,
    Color? surfaceDeep,
    Color? stripSurface,
    Color? sheet,
    List<Color>? sheetGradient,
    Color? field,
    Color? fieldStrong,
    Color? overlaySurface,
    Color? navBar,
    Color? inverseSurface,
    Color? brandCanvas,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? textInverse,
    Color? onAccent,
    Color? onGold,
    Color? icon,
    Color? iconMuted,
    Color? accent,
    Color? accentSoft,
    Color? accentDeep,
    Color? accentMuted,
    Color? accentSurface,
    Color? accentBorder,
    List<Color>? goldGradient,
    List<Color>? goldIconGradient,
    List<Color>? goldDisabledGradient,
    Color? divider,
    Color? dividerStrong,
    Color? border,
    Color? borderStrong,
    Color? success,
    Color? successSurface,
    Color? successBorder,
    Color? error,
    Color? errorSurface,
    Color? errorBorder,
    Color? warning,
    Color? warningSurface,
    Color? warningBorder,
    Color? info,
    Color? infoSurface,
    Color? infoBorder,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? skeleton,
    Color? scrim,
    Color? shadow,
    Color? mapPlaceholder,
    Color? mapPlaceholderHighlight,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      scaffold: scaffold ?? this.scaffold,
      pageGradient: pageGradient ?? this.pageGradient,
      appBarScrim: appBarScrim ?? this.appBarScrim,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceDeep: surfaceDeep ?? this.surfaceDeep,
      stripSurface: stripSurface ?? this.stripSurface,
      sheet: sheet ?? this.sheet,
      sheetGradient: sheetGradient ?? this.sheetGradient,
      field: field ?? this.field,
      fieldStrong: fieldStrong ?? this.fieldStrong,
      overlaySurface: overlaySurface ?? this.overlaySurface,
      navBar: navBar ?? this.navBar,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      brandCanvas: brandCanvas ?? this.brandCanvas,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      textInverse: textInverse ?? this.textInverse,
      onAccent: onAccent ?? this.onAccent,
      onGold: onGold ?? this.onGold,
      icon: icon ?? this.icon,
      iconMuted: iconMuted ?? this.iconMuted,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentDeep: accentDeep ?? this.accentDeep,
      accentMuted: accentMuted ?? this.accentMuted,
      accentSurface: accentSurface ?? this.accentSurface,
      accentBorder: accentBorder ?? this.accentBorder,
      goldGradient: goldGradient ?? this.goldGradient,
      goldIconGradient: goldIconGradient ?? this.goldIconGradient,
      goldDisabledGradient: goldDisabledGradient ?? this.goldDisabledGradient,
      divider: divider ?? this.divider,
      dividerStrong: dividerStrong ?? this.dividerStrong,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      success: success ?? this.success,
      successSurface: successSurface ?? this.successSurface,
      successBorder: successBorder ?? this.successBorder,
      error: error ?? this.error,
      errorSurface: errorSurface ?? this.errorSurface,
      errorBorder: errorBorder ?? this.errorBorder,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      warningBorder: warningBorder ?? this.warningBorder,
      info: info ?? this.info,
      infoSurface: infoSurface ?? this.infoSurface,
      infoBorder: infoBorder ?? this.infoBorder,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      skeleton: skeleton ?? this.skeleton,
      scrim: scrim ?? this.scrim,
      shadow: shadow ?? this.shadow,
      mapPlaceholder: mapPlaceholder ?? this.mapPlaceholder,
      mapPlaceholderHighlight:
          mapPlaceholderHighlight ?? this.mapPlaceholderHighlight,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> g(List<Color> a, List<Color> b) => <Color>[
      for (int i = 0; i < a.length; i++)
        Color.lerp(a[i], i < b.length ? b[i] : b.last, t)!,
    ];

    return AppPalette(
      // Brightness has no midpoint; it flips at the halfway mark so anything
      // branching on it agrees with what is actually on screen.
      brightness: t < 0.5 ? brightness : other.brightness,
      scaffold: c(scaffold, other.scaffold),
      pageGradient: g(pageGradient, other.pageGradient),
      appBarScrim: g(appBarScrim, other.appBarScrim),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      surfaceElevated: c(surfaceElevated, other.surfaceElevated),
      surfaceDeep: c(surfaceDeep, other.surfaceDeep),
      stripSurface: c(stripSurface, other.stripSurface),
      sheet: c(sheet, other.sheet),
      sheetGradient: g(sheetGradient, other.sheetGradient),
      field: c(field, other.field),
      fieldStrong: c(fieldStrong, other.fieldStrong),
      overlaySurface: c(overlaySurface, other.overlaySurface),
      navBar: c(navBar, other.navBar),
      inverseSurface: c(inverseSurface, other.inverseSurface),
      brandCanvas: c(brandCanvas, other.brandCanvas),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textDisabled: c(textDisabled, other.textDisabled),
      textInverse: c(textInverse, other.textInverse),
      onAccent: c(onAccent, other.onAccent),
      onGold: c(onGold, other.onGold),
      icon: c(icon, other.icon),
      iconMuted: c(iconMuted, other.iconMuted),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      accentDeep: c(accentDeep, other.accentDeep),
      accentMuted: c(accentMuted, other.accentMuted),
      accentSurface: c(accentSurface, other.accentSurface),
      accentBorder: c(accentBorder, other.accentBorder),
      goldGradient: g(goldGradient, other.goldGradient),
      goldIconGradient: g(goldIconGradient, other.goldIconGradient),
      goldDisabledGradient: g(
        goldDisabledGradient,
        other.goldDisabledGradient,
      ),
      divider: c(divider, other.divider),
      dividerStrong: c(dividerStrong, other.dividerStrong),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      success: c(success, other.success),
      successSurface: c(successSurface, other.successSurface),
      successBorder: c(successBorder, other.successBorder),
      error: c(error, other.error),
      errorSurface: c(errorSurface, other.errorSurface),
      errorBorder: c(errorBorder, other.errorBorder),
      warning: c(warning, other.warning),
      warningSurface: c(warningSurface, other.warningSurface),
      warningBorder: c(warningBorder, other.warningBorder),
      info: c(info, other.info),
      infoSurface: c(infoSurface, other.infoSurface),
      infoBorder: c(infoBorder, other.infoBorder),
      shimmerBase: c(shimmerBase, other.shimmerBase),
      shimmerHighlight: c(shimmerHighlight, other.shimmerHighlight),
      skeleton: c(skeleton, other.skeleton),
      scrim: c(scrim, other.scrim),
      shadow: c(shadow, other.shadow),
      mapPlaceholder: c(mapPlaceholder, other.mapPlaceholder),
      mapPlaceholderHighlight: c(
        mapPlaceholderHighlight,
        other.mapPlaceholderHighlight,
      ),
    );
  }
}

/// `context.colors.textPrimary` — the palette, without the ceremony.
extension AppPaletteX on BuildContext {
  /// The palette for the theme in force here.
  AppPalette get colors => AppPalette.of(this);

  /// Whether the dark theme is the one being painted.
  bool get isDarkMode => AppPalette.of(this).brightness == Brightness.dark;
}
