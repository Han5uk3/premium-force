import 'package:flutter/material.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class BlockedPage extends StatelessWidget {
  const BlockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1105),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3E230A), Color(0xFF141313)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.block_flipped,
                color: Color(0xFFE4A46B),
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.accountBlockedTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.accountBlockedMessage,
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              PremiumButton(
                text: l10n.email,
                fontsize: 16,
                showLoader: false,
                onTap: () async {
                  final Uri emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: 'premium.force.sa@gmail.com',
                    queryParameters: {'subject': 'Blocked Account Inquiry'},
                  );
                  if (await canLaunchUrl(emailLaunchUri)) {
                    await launchUrl(emailLaunchUri);
                  } else {
                    // Fallback to clipboard or just showing the email
                    if (context.mounted) {
                      AnimatedSnackBar.show(
                        context,
                        l10n.supportEmail('premium.force.sa@gmail.com'),
                        'I',
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              PremiumButton(
                text: l10n.phoneNumber,
                fontsize: 16,
                showLoader: false,
                onTap: () async {
                  final Uri phoneLaunchUri = Uri(
                    scheme: 'tel',
                    path: '+966591991749',
                  );
                  try {
                    await launchUrl(phoneLaunchUri);
                  } catch (e) {}
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
                child: Text(
                  l10n.backToLogin,
                  style: const TextStyle(
                    color: Color(0xFFE4A46B),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
