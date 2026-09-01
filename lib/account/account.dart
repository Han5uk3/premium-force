import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/main.dart';
import 'package:premium_force_main/account/manage_profile.dart';
import 'package:premium_force_main/providers/auth_provider.dart';
import 'package:premium_force_main/authentication/login.dart';
import 'package:premium_force_main/utils/smooth_navigation.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/common_widgets/gold_icon.dart';
import 'package:premium_force_main/theme/app_palette.dart';
import 'package:premium_force_main/theme/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool notificationActive = UserLocalStorage.getNotificationStatus();
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: c.pageGradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buidAppBar(context, loc),
        // The list outgrew the screen once appearance joined it, so it scrolls
        // rather than overflowing on a short device.
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageProfilePage(),
                    ),
                  );
                },
                child: ProfileTile(
                  loc: loc,
                  title: loc.manageProfile,
                  icon: Icons.person,
                  isSvg: true,
                  svgPath: "assets/icons/person.svg",
                ),
              ),
              GestureDetector(
                onTap: () => _showAppearanceSheet(context, loc),
                child: ProfileTile(
                  loc: loc,
                  isAppearance: true,
                  title: loc.appearance,
                  icon: Icons.dark_mode_outlined,
                ),
              ),
              GestureDetector(
                onTap: () {
                  final isCurrentlyEnglish =
                      Localizations.localeOf(context).languageCode == 'en';
                  MainApp.setLocale(
                    context,
                    Locale(isCurrentlyEnglish ? 'ar' : 'en'),
                  );
                },
                child: ProfileTile(
                  loc: loc,
                  isLanguage: true,
                  title: loc.language,
                  icon: Icons.language,
                ),
              ),
              // GestureDetector(
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => const NotificationScreen(),
              //       ),
              //     );
              //   },
              //   child: ProfileTile(
              //     loc: loc,
              //     isNotification: true,
              //     title: loc.notifications,
              //     icon: Icons.notifications,
              //   ),
              // ),
              GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse(
                    'https://premiumforcegroup.com/terms-and-conditions',
                  );
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {}
                },
                child: ProfileTile(
                  loc: loc,
                  isSvg: true,
                  title: loc.termsAndConditions,
                  icon: Icons.file_copy_outlined,
                  svgPath: "assets/icons/terms_and_conditions.svg",
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse(
                    'https://premiumforcegroup.com/privacy-policy',
                  );
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {}
                },
                child: ProfileTile(
                  loc: loc,
                  isSvg: false,
                  title: loc.privacyPolicy,
                  icon: Icons.privacy_tip_outlined,
                ),
              ),

              GestureDetector(
                onTap: () {
                  _showContactUsBottomSheet(context, loc);
                },
                child: ProfileTile(
                  loc: loc,
                  isSvg: false,
                  title: loc.contactUs,
                  icon: Icons.support_agent_outlined,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _showDeleteAccountBottomSheet(context, loc);
                },
                child: ProfileTile(
                  loc: loc,
                  isDelete: true,
                  title: loc.deleteAccount,
                  icon: Icons.delete,
                  isLast: false,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _showLogoutBottomSheet(context, loc);
                },
                child: ProfileTile(
                  loc: loc,
                  isLogout: true,
                  title: loc.logout,
                  icon: Icons.logout,
                  isLast: true,
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget buidAppBar(BuildContext context, AppLocalizations loc) {
    final c = context.colors;
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: c.appBarScrim,
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            loc.account,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: c.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
        ),
      ),
    );
  }

  Widget ProfileTile({
    required AppLocalizations loc,
    required String title,
    required IconData icon,
    bool isSvg = false,
    bool isDelete = false,
    bool isLogout = false,
    bool isNotification = false,
    bool isLanguage = false,
    bool isAppearance = false,
    bool isLast = false,
    String? svgPath,
  }) {
    final c = context.colors;
    return ListTile(
      shape: Border(
        bottom: BorderSide(color: isLast ? Colors.transparent : c.divider),
      ),
      minTileHeight: 80,
      leading: isSvg
          // The SVG carries the gold gradient baked in, so [GoldIcon] repaints
          // it with the ramp that reads on the theme in force.
          ? GoldIcon(asset: svgPath!, size: 20)
          : ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: c.goldIconGradient,
                ).createShader(bounds);
              },
              child: Icon(icon, color: Colors.white),
            ),
      trailing: !(isDelete || isLogout)
          ? isAppearance
                // Says which mode is on without opening the sheet.
                ? Text(
                    _themeLabel(loc),
                    style: TextStyle(color: c.accent, fontSize: 13),
                  )
                : isLanguage
                // Flag of the language currently in use, matching the switch in
                // the home appbar. The tile itself handles the tap.
                //
                // The SizedBox pins the clip to a square: the flags are wider
                // than they are tall, so letting ClipOval take its size from
                // the artwork gives an ellipse. BoxFit.cover then fills that
                // square by cropping the flag's sides rather than squashing it.
                ? SizedBox(
                    width: 32,
                    height: 32,
                    child: ClipOval(
                      child: SvgPicture.asset(
                        Localizations.localeOf(context).languageCode == 'en'
                            ? 'assets/flags/en.svg'
                            : 'assets/flags/ar.svg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : isNotification
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        notificationActive = !notificationActive;
                      });
                      UserLocalStorage.saveNotificationStatus(
                        notificationActive,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 70,
                      height: 26,
                      decoration: BoxDecoration(
                        color: c.surfaceDeep,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: c.surfaceDeep),
                      ),
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            left: notificationActive ? 35.0 : 0.0,
                            right: notificationActive ? 0.0 : 35.0,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: notificationActive
                                    ? c.accent
                                    : c.textTertiary,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.shadow,
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                notificationActive ? loc.on : loc.off,
                                style: TextStyle(
                                  color: c.onAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: c.goldIconGradient,
                      ).createShader(bounds);
                    },
                    // White, and it has to be: [ShaderMask] defaults to
                    // `BlendMode.modulate`, which *multiplies* the child by the
                    // shader. White is the multiplicative identity, so the
                    // gradient comes through unchanged; any other ink would
                    // darken it.
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
          : null,
      title: Text(title, style: TextStyle(color: c.textPrimary, fontSize: 14)),
    );
  }

  // ---------------------------------------------------------------------------
  // Appearance
  // ---------------------------------------------------------------------------

  /// The current theme choice, for the appearance row's trailing label.
  String _themeLabel(AppLocalizations loc) {
    // Watched, not read: picking "System" while the device is already dark
    // changes the mode without changing a single colour, so nothing else on
    // this page would rebuild and the label would keep naming the old choice.
    return switch (context.watch<ThemeProvider>().themeMode) {
      ThemeMode.light => loc.lightMode,
      ThemeMode.dark => loc.darkMode,
      ThemeMode.system => loc.systemMode,
    };
  }

  /// Where the customer chooses how the app looks, and how its maps look.
  ///
  /// The two are separate choices on purpose. Someone reading a light app in
  /// daylight may still want the night map — dark tiles make a gold car and its
  /// route line pop — and the reverse holds too, so the map is not simply
  /// chained to the app.
  void _showAppearanceSheet(BuildContext context, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        // Reads the palette from the sheet's own context, so the sheet repaints
        // itself the moment a mode is picked rather than showing the old one
        // until it is dismissed.
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            final c = context.colors;
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.sheet,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 24,
                      bottom: 12,
                      left: 24,
                      right: 24,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            loc.appearance,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(sheetContext),
                          child: Icon(Icons.close, color: c.icon, size: 24),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: c.divider, thickness: 1),
                  const SizedBox(height: 20),

                  _sectionHeading(c, loc.appTheme),
                  const SizedBox(height: 4),
                  _sectionNote(c, loc.systemModeDescription),

                  const SizedBox(height: 10),
                  _segmentedRow(
                    c: c,
                    options: [
                      _Segment(
                        label: loc.systemMode,
                        icon: Icons.phone_iphone_rounded,
                        selected: themeProvider.themeMode == ThemeMode.system,
                        onTap: () =>
                            themeProvider.setThemeMode(ThemeMode.system),
                      ),
                      _Segment(
                        label: loc.lightMode,
                        icon: Icons.light_mode_outlined,
                        selected: themeProvider.themeMode == ThemeMode.light,
                        onTap: () =>
                            themeProvider.setThemeMode(ThemeMode.light),
                      ),
                      _Segment(
                        label: loc.darkMode,
                        icon: Icons.dark_mode_outlined,
                        selected: themeProvider.themeMode == ThemeMode.dark,
                        onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                      ),
                     
                    ],
                  ),

                  const SizedBox(height: 24),
                  _sectionHeading(c, loc.mapStyle),
                  const SizedBox(height: 4),

                  _sectionNote(c, loc.mapStyleDescription),

                  const SizedBox(height: 10),
                  _segmentedRow(
                    c: c,
                    options: [
                      _Segment(
                        label: loc.mapStyleMatchApp,
                        icon: Icons.auto_awesome_outlined,
                        selected:
                            themeProvider.mapPreference ==
                            MapThemePreference.matchApp,
                        onTap: () => themeProvider.setMapPreference(
                          MapThemePreference.matchApp,
                        ),
                      ),
                      _Segment(
                        label: loc.lightMode,
                        icon: Icons.wb_sunny_outlined,
                        selected:
                            themeProvider.mapPreference ==
                            MapThemePreference.light,
                        onTap: () => themeProvider.setMapPreference(
                          MapThemePreference.light,
                        ),
                      ),
                      _Segment(
                        label: loc.darkMode,
                        icon: Icons.nightlight_round,
                        selected:
                            themeProvider.mapPreference ==
                            MapThemePreference.dark,
                        onTap: () => themeProvider.setMapPreference(
                          MapThemePreference.dark,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(
                    height: MediaQuery.of(sheetContext).padding.bottom + 28,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionHeading(AppPalette c, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        text,
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _sectionNote(AppPalette c, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 24, right: 24),
      child: Text(text, style: TextStyle(color: c.textTertiary, fontSize: 12)),
    );
  }

  /// Three equal-width choices, one of them selected.
  ///
  /// A row of pills rather than a list of radio rows: there are only three of
  /// each, and seeing all three side by side is what makes the choice obvious
  /// at a glance.
  Widget _segmentedRow({
    required AppPalette c,
    required List<_Segment> options,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          for (final option in options) ...[
            Expanded(
              child: GestureDetector(
                onTap: option.onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: option.selected ? c.accentSurface : c.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: option.selected ? c.accent : c.border,
                      width: option.selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        option.icon,
                        size: 20,
                        color: option.selected ? c.accent : c.iconMuted,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: option.selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: option.selected ? c.accent : c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (option != options.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  void _showLogoutBottomSheet(BuildContext context, AppLocalizations loc) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: c.sheet,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ShaderMask(
              //   shaderCallback: (Rect bounds) {
              //     return const LinearGradient(
              //       begin: Alignment.centerLeft,
              //       end: Alignment.centerRight,
              //       colors: [
              //         Color(0xFF49280B),
              //         Color(0xFFE4A46B),
              //         Color(0xFF60350F),
              //       ],
              //     ).createShader(bounds);
              //   },
              //   child: const Icon(Icons.logout, color: Colors.white, size: 50),
              // ),
              Padding(
                padding: const EdgeInsets.only(
                  top: 24,
                  bottom: 12,
                  left: 24,
                  right: 24,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        loc.logout,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetContext),
                      child: Icon(Icons.close, color: c.icon, size: 24),
                    ),
                  ],
                ),
              ),
              Divider(color: c.divider, thickness: 1),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  loc.logoutConfirm,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary, fontSize: 14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  loc.loginAgainMessage,
                  textAlign: TextAlign.start,
                  style: TextStyle(color: c.textSecondary, fontSize: 14),
                ),
              ),
              const SizedBox(height: 80),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(sheetContext),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.borderStrong),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            loc.cancel,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatefulBuilder(
                        builder: (context, setLoaderState) {
                          bool isLoggingOut = false;
                          return PremiumButton(
                            onTap: () async {
                              setLoaderState(() => isLoggingOut = true);
                              final authProvider = context.read<AuthProvider>();
                              await authProvider.logout();
                              if (context.mounted) {
                                Navigator.pop(sheetContext);
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  SmoothNavigation.route(
                                    const PremiumForceLoginPage(),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                            text: loc.logout,
                            fontsize: 14,
                            showLoader: isLoggingOut,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteAccountBottomSheet(
    BuildContext context,
    AppLocalizations loc,
  ) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: c.sheet,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 24,
                  bottom: 12,
                  left: 24,
                  right: 24,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        loc.deleteAccount,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetContext),
                      child: Icon(Icons.close, color: c.icon, size: 24),
                    ),
                  ],
                ),
              ),
              Divider(color: c.divider, thickness: 1),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  loc.deleteAccountConfirm,
                  textAlign: TextAlign.start,
                  style: TextStyle(color: c.textSecondary, fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  loc.deleteAccountMessage,
                  textAlign: TextAlign.start,
                  style: TextStyle(color: c.textSecondary, fontSize: 14),
                ),
              ),
              const SizedBox(height: 80),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(sheetContext),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.borderStrong),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            loc.cancel,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatefulBuilder(
                        builder: (context, setLoaderState) {
                          bool isDeleting = false;
                          return PremiumButton(
                            text: loc.deleteAccount,
                            onTap: () async {
                              if (isDeleting) return;
                              setLoaderState(() => isDeleting = true);
                              final authProvider = context.read<AuthProvider>();
                              final success = await authProvider
                                  .deleteAccount();
                              if (context.mounted) {
                                if (success) {
                                  Navigator.pop(sheetContext);
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    SmoothNavigation.route(
                                      const PremiumForceLoginPage(),
                                    ),
                                    (route) => false,
                                  );
                                } else {
                                  setLoaderState(() => isDeleting = false);
                                  AnimatedSnackBar.show(
                                    context,
                                    authProvider.errorMessage ??
                                        loc.failedToDeleteAccount,
                                    'E',
                                  );
                                }
                              }
                            },
                            fontsize: 14,
                            showLoader: isDeleting,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showContactUsBottomSheet(BuildContext context, AppLocalizations loc) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: c.sheet,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 24,
                  bottom: 12,
                  left: 24,
                  right: 24,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        loc.contactUs,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetContext),
                      child: Icon(Icons.close, color: c.icon, size: 24),
                    ),
                  ],
                ),
              ),
              Divider(color: c.divider, thickness: 1),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  loc.selectContactMethod,
                  textAlign: TextAlign.start,
                  style: TextStyle(color: c.textSecondary, fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PremiumButton(
                  text: loc.email,
                  fontsize: 14,
                  showLoader: false,
                  onTap: () async {
                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: 'premium.force.sa@gmail.com',
                    );
                    try {
                      await launchUrl(emailLaunchUri);
                    } catch (e) {}
                    if (context.mounted) Navigator.pop(sheetContext);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PremiumButton(
                  text: loc.phoneNumber,
                  fontsize: 14,
                  showLoader: false,
                  onTap: () async {
                    final Uri phoneLaunchUri = Uri(
                      scheme: 'tel',
                      path: '+966591991749',
                    );
                    try {
                      await launchUrl(phoneLaunchUri);
                    } catch (e) {}
                    if (context.mounted) Navigator.pop(sheetContext);
                  },
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}

/// One choice in an appearance segmented row.
class _Segment {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
}
