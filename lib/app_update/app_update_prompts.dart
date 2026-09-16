import 'package:flutter/material.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/services/app_update_service.dart';
import 'package:premium_force_main/theme/app_palette.dart';

/// Shown in place of the app when this build is below the minimum supported
/// one.
///
/// It is a dead end on purpose: back is swallowed and there is nothing to
/// navigate to. The only way forward is the store.
class UpdateRequiredPage extends StatelessWidget {
  const UpdateRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = context.colors;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.sheet,
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: c.sheetGradient,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.system_update, color: c.accent, size: 80),
                const SizedBox(height: 24),
                Text(
                  l10n.updateRequiredTitle,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.updateRequiredMessage,
                  style: TextStyle(color: c.textSecondary, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                PremiumButton(
                  text: l10n.updateNow,
                  fontsize: 16,
                  showLoader: false,
                  onTap: AppUpdateService.openStore,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Offer a newer build without forcing it. Resolves once the dialog closes,
/// whichever button was used.
Future<void> showUpdateAvailableDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final c = context.colors;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: c.surfaceElevated,
      title: Text(
        l10n.updateAvailableTitle,
        style: TextStyle(color: c.textPrimary),
      ),
      content: Text(
        l10n.updateAvailableMessage,
        style: TextStyle(color: c.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(
            l10n.updateLater,
            style: TextStyle(color: c.textPrimary),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            AppUpdateService.openStore();
          },
          child: Text(l10n.updateNow, style: TextStyle(color: c.accent)),
        ),
      ],
    ),
  );
}
