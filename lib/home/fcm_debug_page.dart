import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:premium_force_main/services/notification_service.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/theme/app_palette.dart';

/// Temporary debug screen to display and copy the FCM token.
/// Replace [Homepage()] with this widget in home.dart for testing,
/// then swap it back once push notifications are confirmed working.
class FcmDebugPage extends StatefulWidget {
  const FcmDebugPage({super.key});

  @override
  State<FcmDebugPage> createState() => _FcmDebugPageState();
}

class _FcmDebugPageState extends State<FcmDebugPage>
    with SingleTickerProviderStateMixin {
  String? _token;
  bool _copied = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadToken();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    // Try in-memory first (fastest), fall back to Hive
    final token =
        NotificationService.instance.fcmToken ?? UserLocalStorage.getFcmToken();
    setState(() => _token = token);
  }

  Future<void> _copyToken() async {
    if (_token == null) return;
    await Clipboard.setData(ClipboardData(text: _token!));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.scaffold,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.infoSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.info.withValues(alpha: 0.4)),
                    ),
                    child: Icon(
                      Icons.notifications_active_rounded,
                      color: c.info,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FCM Debug',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Push notification token',
                        style: TextStyle(color: c.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // â”€â”€ Token card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (_token == null) _buildNoTokenCard() else _buildTokenCard(),

              const Spacer(),

              // â”€â”€ Refresh button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _loadToken,
                  icon: Icon(Icons.refresh_rounded, color: c.info, size: 18),
                  label: Text(
                    'Refresh Token',
                    style: TextStyle(
                      color: c.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: c.info.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: c.info.withValues(alpha: 0.25)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenCard() {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status chip
        Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.success,
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Token ready',
              style: TextStyle(
                color: c.success.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Token box
        GestureDetector(
          onTap: _copyToken,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: c.infoSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _copied
                    ? c.success.withValues(alpha: 0.6)
                    : c.info.withValues(alpha: 0.2),
                width: _copied ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _copied
                      ? c.success.withValues(alpha: 0.08)
                      : c.info.withValues(alpha: 0.06),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Token text
                SelectableText(
                  _token!,
                  // Follows the app's family rather than naming one — see
                  // ThemeData in main.dart.
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    height: 1.6,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 14),
                // Copy button row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _copied
                          ? Row(
                              key: ValueKey('copied'),
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: c.success,
                                  size: 15,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Copied!',
                                  style: TextStyle(
                                    color: c.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              key: const ValueKey('copy'),
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  color: c.info.withValues(alpha: 0.7),
                                  size: 15,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tap to copy',
                                  style: TextStyle(
                                    color: c.info.withValues(alpha: 0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Copy full button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _copyToken,
            icon: Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 18,
            ),
            label: Text(_copied ? 'Copied to clipboard!' : 'Copy Token'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _copied ? c.success : c.info,
              foregroundColor: Colors.white,
              // White on both the violet and the green fill, neither of which
              // lightens in the light theme.
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoTokenCard() {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.warningSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.warningBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded, color: c.warning, size: 36),
          const SizedBox(height: 12),
          Text(
            'No FCM token yet',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This is expected on iOS Simulator.\nTest on a real device to get a token.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textTertiary, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}
