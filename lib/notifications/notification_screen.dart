import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:premium_force_main/bookings/booking_details_page.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/models/v2/notification_v2.dart';
import 'package:premium_force_main/providers/notification_provider.dart';

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
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          loc.notifications,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (provider.unreadCount > 0)
            IconButton(
              tooltip: loc.markAllAsRead,
              icon: const Icon(Icons.done_all, color: Color(0xFFE4A46B)),
              onPressed: () async {
                final marked = await provider.markAllAsRead();
                if (!context.mounted || !marked) return;
                _showMessage(loc.allNotificationsMarkedRead);
              },
            ),
          if (provider.notifications.isNotEmpty)
            TextButton(
              onPressed: () => _showClearConfirmation(context, loc, provider),
              child: Text(
                loc.clearAll,
                style: const TextStyle(color: Color(0xFFE4A46B)),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.refresh(silent: true),
        color: const Color(0xFFE4A46B),
        backgroundColor: Colors.black,
        child: _buildBody(loc, provider),
      ),
    );
  }

  Widget _buildBody(AppLocalizations loc, NotificationProvider provider) {
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
          Divider(color: Colors.grey.withValues(alpha: 0.1), height: 24),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF292929).withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 64,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              loc.noNotificationsYet,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.updatesAboutBookings,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(AppLocalizations loc, NotificationProvider provider) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.white24, size: 56),
              const SizedBox(height: 16),
              Text(
                provider.errorMessage ?? loc.somethingWentWrong,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: provider.refresh,
                child: Text(
                  loc.retry,
                  style: const TextStyle(color: Color(0xFFE4A46B)),
                ),
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(loc.clearAll, style: const TextStyle(color: Colors.white)),
        content: Text(
          loc.clearAllConfirmDesc,
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              loc.cancel,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final cleared = await provider.clearAll();
              if (!mounted || !cleared) return;
              _showMessage(loc.notificationsCleared);
            },
            child: Text(
              loc.clear,
              style: const TextStyle(color: Colors.redAccent),
            ),
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
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isRead
                ? Colors.transparent
                : const Color(0xFFE4A46B).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead
                  ? Colors.grey.withValues(alpha: 0.1)
                  : const Color(0xFFE4A46B).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isRead
                      ? const Color(0xFF292929)
                      : const Color(0xFFE4A46B).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon,
                  size: 20,
                  color: isRead ? Colors.grey : const Color(0xFFE4A46B),
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
                              color: Colors.white,
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
                            style: TextStyle(
                              color: Colors.grey.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.displayBody(isArabic),
                      style: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.8),
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
