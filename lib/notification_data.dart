// lib/notification_data.dart

class NotificationModel {
  final String title;
  final String message;
  final DateTime timestamp;
  final String employeeId;

  NotificationModel({
    required this.title,
    required this.message,
    required this.timestamp,
    required this.employeeId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationModel &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          message == other.message &&
          employeeId == other.employeeId &&
          (timestamp.millisecondsSinceEpoch ~/ 1000) ==
              (other.timestamp.millisecondsSinceEpoch ~/ 1000);

  @override
  int get hashCode =>
      title.hashCode ^ message.hashCode ^ employeeId.hashCode;
}

// ✅ Global in-memory notification list
final List<NotificationModel> myNotifications = [];

// ✅ helper — prevents duplicates & adds newest first
void addNotificationOnce(NotificationModel n) {
  if (!myNotifications.contains(n)) {
    myNotifications.insert(0, n);
  }
}
