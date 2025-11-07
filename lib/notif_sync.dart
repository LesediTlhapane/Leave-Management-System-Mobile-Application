// lib/notif_sync.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_data.dart'; // NotificationModel, myNotifications

StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;

// Keep track so we don't emit duplicate notifications for the same doc+status
final Set<String> _emittedKeys = <String>{};

/// Start listening to Firestore leave_requests for this employeeId and
/// push human-readable notifications into `myNotifications`.
///
/// [onAnyChange] (optional) is called every time we insert a new notification,
/// so your UI (badge, lists) can refresh.
void startNotificationsSyncForUser({
  required String employeeId,
  required String employeeName, // not strictly needed but kept for future
  void Function()? onAnyChange,
}) {
  // If already listening, stop the previous one
  _notifSub?.cancel();

  final db = FirebaseFirestore.instance;

  // You can add .orderBy('createdAt', descending: true) if you have the composite index.
  final q = db
      .collection('leave_requests')
      .where('employeeId', isEqualTo: employeeId);

  _notifSub = q.snapshots().listen((snap) {
    bool changed = false;

    for (final doc in snap.docs) {
      final m = doc.data();
      final id = doc.id;

      final status    = (m['status'] ?? 'pending').toString().toLowerCase();
      final name      = (m['employeeName'] ?? '').toString();
      final type      = (m['leaveType'] ?? '').toString();
      final days      = (m['totalDays'] is num) ? (m['totalDays'] as num).toInt() : 0;
      final reason    = (m['reason'] ?? '').toString();
      final createdAt = m['createdAt'];

      // Unique key per doc + status so we don't duplicate when snapshot fires again
      final key = '$id::$status';
      if (_emittedKeys.contains(key)) continue;

      String title;
      String message;

      // Build a friendly line for each status
      switch (status) {
        case 'approved':
          title = "Leave Approved";
          message = "$type (${days} day${days == 1 ? '' : 's'}) approved.";
          break;
        case 'rejected':
          title = "Leave Rejected";
          message = "$type (${days} day${days == 1 ? '' : 's'}) rejected.";
          break;
        case 'cancelled':
          title = "Leave Cancelled";
          message = "$type (${days} day${days == 1 ? '' : 's'}) was cancelled.";
          break;
        default:
          // pending (or any unknown) — show the application notification
          title = "Leave Application Submitted";
          final who = name.isNotEmpty ? name : "You";
          final why = reason.trim().isEmpty ? "" : " Reason: $reason";
          message = "$who applied for $type (${days} day${days == 1 ? '' : 's'}).$why";
          break;
      }

      // Convert server timestamp safely
      DateTime ts;
      try {
        if (createdAt is Timestamp) {
          ts = createdAt.toDate();
        } else if (createdAt is DateTime) {
          ts = createdAt;
        } else {
          ts = DateTime.now();
        }
      } catch (_) {
        ts = DateTime.now();
      }

      myNotifications.add(NotificationModel(
        title: title,
        message: message,
        timestamp: ts,
        employeeId: employeeId,
      ));

      _emittedKeys.add(key);
      changed = true;
    }

    if (changed && onAnyChange != null) {
      onAnyChange();
    }
  });
}

/// Stop listening (call this in dispose).
void stopNotificationsSync() {
  _notifSub?.cancel();
  _notifSub = null;
}
