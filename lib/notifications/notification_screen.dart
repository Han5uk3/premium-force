import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:premium_force_main/bookings/booking_details_page.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/models/v2/notification_v2.dart';
import 'package:premium_force_main/providers/notification_provider.dart';
import 'package:premium_force_main/theme/app_palette.dart';

/// The in-app notification centre, backed by `GET /notifications`.
///
/// Read state and deletion live on the server, so the same inbox — and the same
/// unread badge — follows the customer to every device they sign in on. Tapping
/// an entry marks it read and, when it names a booking, opens that booking.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // The feed may already be warm from the badge; refresh silently so the list
    // stays readable while the newest page arrives.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<NotificationProvider>();
      provider.refresh(
        silent: provider.status == NotificationFeedStatus.loaded,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      context.read<NotificationProvider>().loadMore();
    }
  }

  Future<void> _openNotification(NotificationV2 notification) async {
    final provider = context.read<NotificationProvider>();
    provider.markAsRead(notification.id);

    final bookingId = notification.bookingId;
    if (bookingId == null || bookingId.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingDetailsPage(bookingId: bookingId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.colors;
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.scaffold,
        elevation: 0,
        title: Text(
          loc.notifications,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: c.icon, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (provider.unreadCount > 0)
            IconButton(
              tooltip: loc.markAllAsRead,
              icon: Icon(Icons.done_all, color: c.accent),
              onPressed: () async {
                final marked = await provider.markAllAsRead();
                if (!context.mounted || !marked) return;
                _showMessage(loc.allNotificationsMarkedRead);
              },
            ),
          if (provider.notifications.isNotEmpty)
            TextButton(
              onPressed: () => _showClearConfirmation(context, loc, provider),
              child: Text(loc.clearAll, style: TextStyle(color: c.accent)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.refresh(silent: true),
        color: c.accent,
        backgroundColor: c.surface,
        child: _buildBody(loc, provider),
      ),
    );
  }

  Widget _buildBody(AppLocalizations loc, NotificationProvider provider) {
    final c = context.colors;
    if (provider.status == NotificationFeedStatus.loading ||
        provider.status == NotificationFeedStatus.initial) {
      return const Center(child: PremiumLoader(size: 40));
    }

    if (provider.status == NotificationFeedStatus.failure &&
        provider.notifications.isEmpty) {
      return _buildErrorState(loc, provider);
    }

    if (provider.notifications.isEmpty) {
      return _buildEmptyState(loc);
    }

    final notifications = provider.notifications;

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // One extra row carries the "loading more" spinner at the tail.
      itemCount: notifications.length + (provider.isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) =>
          Divider(color: c.divider, height: 24),
      itemBuilder: (context, index) {
        if (index >= notifications.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: PremiumLoader(size: 24)),
          );
        }

        final notification = notifications[index];
        return _NotificationItem(
          notification: notification,
          onTap: () => _openNotification(notification),
          onDelete: () => provider.deleteNotification(notification.id),
        );
      },
    );
  }

  Widget _buildEmptyState(AppLocalizations loc) {
    final c = context.colors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 64,
                color: c.iconMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              loc.noNotificationsYet,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.updatesAboutBookings,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(AppLocalizations loc, NotificationProvider provider) {
    final c = context.colors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: c.iconMuted, size: 56),
              const SizedBox(height: 16),
              Text(
                provider.errorMessage ?? loc.somethingWentWrong,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: provider.refresh,
                child: Text(loc.retry, style: TextStyle(color: c.accent)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showMessage(String message) {
    AnimatedSnackBar.show(context, message, 'S');
  }

  void _showClearConfirmation(
    BuildContext context,
    AppLocalizations loc,
    NotificationProvider provider,
  ) {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surfaceElevated,
        title: Text(loc.clearAll, style: TextStyle(color: c.textPrimary)),
        content: Text(
          loc.clearAllConfirmDesc,
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.cancel, style: TextStyle(color: c.textPrimary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final cleared = await provider.clearAll();
              if (!mounted || !cleared) return;
              _showMessage(loc.notificationsCleared);
            },
            child: Text(loc.clear, style: TextStyle(color: c.error)),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationV2 notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Icon per notification type, so a trip update reads differently from an
  /// offer at a glance.
  IconData get _icon => switch (notification.type) {
    NotificationTypeV2.bookingStatus => Icons.event_available_outlined,
    NotificationTypeV2.tripAssignment => Icons.local_taxi_outlined,
    NotificationTypeV2.payment => Icons.receipt_long_outlined,
    NotificationTypeV2.promotion => Icons.local_offer_outlined,
    NotificationTypeV2.general => Icons.notifications_active_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final createdAt = notification.createdAt;
    final timeStr = createdAt == null
        ? ''
        : DateFormat(
            'MMM dd, hh:mm a',
            Localizations.localeOf(context).languageCode,
          ).format(createdAt.toLocal());
    final isRead = notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: isArabic ? Alignment.centerLeft : Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: c.errorSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: c.error),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          // Unread rows carry a gold tint and a gold hairline; read ones sit
          // flat on the page. That difference is the only thing marking them,
          // so it has to survive the theme swap.
          decoration: BoxDecoration(
            color: isRead ? Colors.transparent : c.accentSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isRead ? c.divider : c.accentBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isRead ? c.surfaceAlt : c.accentSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon,
                  size: 20,
                  color: isRead ? c.iconMuted : c.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.displayTitle(isArabic),
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13,
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (timeStr.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            timeStr,
                            style: TextStyle(color: c.textTertiary, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.displayBody(isArabic),
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
