import 'package:cloud_firestore/cloud_firestore.dart';

final _db = FirebaseFirestore.instance;

/// Submit a leave request
Future<String> submitLeave({
  required String employeeId,
  required String employeeName,
  required String type,
  required int days,
  required DateTime start,
  required DateTime end,
  String? reason,
}) async {
  final doc = await _db.collection('leave_requests').add({
    'employeeId': employeeId,
    'employeeName': employeeName,
    'type': type,
    'days': days,
    'startDate': start.toIso8601String(),
    'endDate': end.toIso8601String(),
    'reason': reason ?? '',
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
    'approvedBy': null,
    'approvedAt': null,
  });
  return doc.id;
}

/// My leaves stream
Stream<QuerySnapshot<Map<String, dynamic>>> myLeaves(String employeeId) {
  return _db.collection('leave_requests')
    .where('employeeId', isEqualTo: employeeId)
    .orderBy('createdAt', descending: true)
    .snapshots();
}

/// Read my balances once
Future<Map<String, dynamic>?> getBalances(String employeeId) async {
  final snap = await _db.collection('leave_balances').doc(employeeId).get();
  return snap.data();
}

/// Notifications stream
Stream<QuerySnapshot<Map<String, dynamic>>> myNotifications(String employeeId) {
  return _db.collection('notifications')
    .where('employeeId', isEqualTo: employeeId)
    .orderBy('createdAt', descending: true)
    .snapshots();
}

/// Mark notification as read
Future<void> markNotificationRead(String id) {
  return _db.collection('notifications').doc(id).update({'read': true});
}
