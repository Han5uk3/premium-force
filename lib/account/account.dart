import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/account/manage_profile.dart';
import 'package:premium_force_main/account/terms_and_conditions.dart';
import 'package:premium_force_main/providers/auth_provider.dart';
import 'package:premium_force_main/authentication/login.dart';
import 'package:premium_force_main/utils/smooth_navigation.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/notifications/notification_screen.dart';

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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E1105),
            Color(0xFF1E1105),
            Color.fromARGB(255, 26, 23, 23),
            Color.fromARGB(255, 26, 23, 23),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buidAppBar(context, loc),
        body: Padding(
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                },
                child: ProfileTile(
                  loc: loc,
                  isNotification: true,
                  title: loc.notifications,
                  icon: Icons.notifications,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TermsAndConditionsPage(),
                    ),
                  );
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
                onTap: () {
                  _showLogoutBottomSheet(context, loc);
                },
                child: ProfileTile(
                  loc: loc,
                  isLogout: true,
                  title: loc.logout,
                  icon: Icons.logout,
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
                  isLast: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget buidAppBar(BuildContext context, AppLocalizations loc) {
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(100), Colors.transparent],
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            loc.account,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
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
    bool isLast = false,
    String? svgPath,
  }) {
    return ListTile(
      shape: Border(
        bottom: BorderSide(
          color: isLast
              ? Colors.transparent
              : Colors.grey.shade800.withAlpha(160),
        ),
      ),
      minTileHeight: 80,
      leading: isSvg
          ? SvgPicture.asset(svgPath!, width: 24, height: 24)
          : ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF49280B),
                    Color(0xFFE4A46B),
                    Color(0xFF60350F),
                  ],
                ).createShader(bounds);
              },
              child: Icon(icon, color: Colors.white),
            ),
      trailing: !(isDelete || isLogout)
          ? isNotification
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
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.black),
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
                                    ? const Color(0xFFE4A46B)
                                    : Colors.grey,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(80),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                notificationActive ? loc.on : loc.off,
                                style: const TextStyle(
                                  color: Colors.white,
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
                      return const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFF49280B),
                          Color(0xFFE4A46B),
                          Color(0xFF60350F),
                        ],
                      ).createShader(bounds);
                    },
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
          : null,
      title: Text(title, style: TextStyle(color: Colors.white)),
    );
  }

  void _showLogoutBottomSheet(BuildContext context, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1105),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetContext),
                      child: Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white, thickness: 1),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  loc.logoutConfirm,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  loc.loginAgainMessage,
                  textAlign: TextAlign.start,
                  style: TextStyle(color: Colors.white, fontSize: 16),
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
                            border: Border.all(color: Colors.grey.shade600),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            loc.cancel,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: PremiumButton(
                        onTap: () async {
                          final authProvider = context.read<AuthProvider>();
                          Navigator.pop(sheetContext); // Close bottom sheet
                          await authProvider.logout();
                          if (context.mounted) {
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
                        fontsize: 16,
                        showLoader: false,
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
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1105),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetContext),
                      child: Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white, thickness: 1),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  loc.deleteAccountConfirm,
                  textAlign: TextAlign.start,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  loc.deleteAccountMessage,
                  textAlign: TextAlign.start,
                  style: TextStyle(color: Colors.white, fontSize: 16),
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
                            border: Border.all(color: Colors.grey.shade600),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            loc.cancel,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: PremiumButton(
                        text: loc.deleteAccount,
                        onTap: () async {
                          final authProvider = context.read<AuthProvider>();
                          Navigator.pop(sheetContext); // Close bottom sheet
                          await authProvider.deleteAccount();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              SmoothNavigation.route(
                                const PremiumForceLoginPage(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        fontsize: 16,
                        showLoader: false,
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
}
