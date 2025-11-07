// notifications_screen.dart
import 'package:flutter/material.dart';
import 'employee_data.dart';
import 'notification_data.dart';

class NotificationsScreen extends StatelessWidget {
  final Employee user; // ✅ active user
  const NotificationsScreen({super.key, required this.user});

  static const _brandBlue = Color(0xFF3B4D79);
  static const _heading   = Color(0xFF111827);
  static const _muted     = Color(0xFF6B7280);
  static const _border    = Color(0xFFE5E7EB);

  /// Show rules for MOBILE:
  /// 1) Keep the self-submission card: messages that start with "You ..."
  /// 2) Keep decision updates: Approved / Rejected / Cancelled
  /// 3) Hide the website copy like "Nomsa Dlamini applied ..."
  bool _showOnMobile(String title, String message) {
    final t = title.toLowerCase().trim();
    final m = message.toLowerCase().trim();

    // self-submission
    if (m.startsWith('you ')) return true;

    // decision updates
    if (t.contains('approved') || t.contains('rejected') || t.contains('cancel')) {
      return true;
    }

    // some teams phrase decision text inside the message only
    if (m.contains('approved') || m.contains('rejected') || m.contains('cancelled')) {
      return true;
    }

    // everything else (e.g., "<name> applied ...") is for the website
    return false;
  }

  (IconData, Color) _iconFor(String title, String message) {
    final text = "${title.toLowerCase()} ${message.toLowerCase()}";
    if (text.contains("approve")) {
      return (Icons.check_circle, const Color(0xFF16A34A));
    }
    if (text.contains("reject") || text.contains("cancel")) {
      return (Icons.cancel, const Color(0xFFE11D48));
    }
    if (text.contains("pending") || text.contains("waiting")) {
      return (Icons.error_outline, const Color(0xFFF59E0B));
    }
    return (Icons.info_outline, _brandBlue);
  }

  String _timeAgo(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);

    if (diff.inMinutes < 1) return "just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours   < 24) return "${diff.inHours}h ago";

    final days = diff.inDays;
    if (days == 1) return "Yesterday";
    if (days < 7)  return "$days days ago";
    final weeks = (days / 7).floor();
    if (weeks == 1) return "1 week ago";
    return "$weeks weeks ago";
  }

  Widget _notificationCard({
    required String title,
    required String message,
    required DateTime timestamp,
  }) {
    final (icon, color) = _iconFor(title, message);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                // Flutter 3.22+: use withValues instead of withOpacity
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: _heading,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: const TextStyle(
                      color: _heading,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _timeAgo(timestamp),
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep your existing field (employeeId == user.id) but also apply the mobile filter.
    // Sort newest first.
    final items = myNotifications
        .where((n) => n.employeeId == user.id && _showOnMobile(n.title, n.message))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home_outlined, color: _brandBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(color: _heading, fontWeight: FontWeight.w700),
        ),
      ),
      body: items.isEmpty
          ? const Center(
              child: Text(
                "No notifications yet.",
                style: TextStyle(color: _muted, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final n = items[i];
                return _notificationCard(
                  title: n.title,
                  message: n.message,
                  timestamp: n.timestamp,
                );
              },
            ),
    );
  }
}
