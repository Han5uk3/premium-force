import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool notificationActive = false;
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
              ProfileTile(
                loc: loc,
                title: loc.manageProfile,
                icon: Icons.person,
                isSvg: true,
                svgPath: "assets/icons/person.svg",
              ),
              ProfileTile(
                loc: loc,
                isNotification: true,

                title: loc.notifications,
                icon: Icons.notifications,
              ),
              ProfileTile(
                loc: loc,
                isSvg: true,
                title: loc.termsAndConditions,
                icon: Icons.file_copy_outlined,
                svgPath: "assets/icons/terms_and_conditions.svg",
              ),
              ProfileTile(
                loc: loc,
                isLogout: true,
                title: loc.logout,
                icon: Icons.logout,
              ),
              ProfileTile(
                loc: loc,
                isDelete: true,

                title: loc.deleteAccount,
                icon: Icons.delete,

                isLast: true,
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
}
