// lib/fire_backend.dart
import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore _db = FirebaseFirestore.instance;

/// (Optional, safe to call multiple times) — disable local persistence on web
void _configureDb() {
  try {
    _db.settings = const Settings(persistenceEnabled: false);
  } catch (_) {}
}

/// Creates a doc in `leave_requests` and returns its id.
Future<String> createLeaveRequest({
  required String employeeId,
  required String employeeName,
  required String department,
  required String leaveType,
  required int totalDays,
  required String startDateIso,  // machine-friendly
  required String endDateIso,    // machine-friendly
  required String startDateText, // your DD/MM/YYYY text
  required String endDateText,   // your DD/MM/YYYY text
  required String reason,

  // NEW: optional supporting document fields
  String? attachmentUrl,
  String? attachmentName,
}) async {
  _configureDb();

  final payload = <String, dynamic>{
    'employeeId': employeeId,
    'employeeName': employeeName,
    'department': department,
    'leaveType': leaveType,
    'totalDays': totalDays,
    'startDateIso': startDateIso,
    'endDateIso': endDateIso,
    'startDateText': startDateText,
    'endDateText': endDateText,
    'reason': reason,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
    'source': 'flutter',

    // NEW: write only when provided
    if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
    if (attachmentName != null) 'attachmentName': attachmentName,
  };

  final ref = await _db.collection('leave_requests').add(payload);
  return ref.id;
}

/* =========================
 *  STATUS & NOTIFICATIONS
 * ========================= */

/// Update status of an existing leave request: 'pending' | 'approved' | 'rejected' | 'cancelled'
Future<void> updateLeaveStatus({
  required String docId,
  required String status,
  String? feedback,
}) async {
  _configureDb();

  final patch = <String, dynamic>{
    'status': status,
    'feedback': feedback,
    'decidedAt': FieldValue.serverTimestamp(),
  };

  await _db.collection('leave_requests').doc(docId).update(patch);
}

/// Write a basic notification to `notifications`
Future<void> _addNotification({
  required String employeeId,
  required String title,
  required String message,
  String? status,
}) async {
  await _db.collection('notifications').add({
    'employeeId': employeeId,
    'title': title,
    'message': message,
    'status': status,
    'createdAt': FieldValue.serverTimestamp(),
    'source': 'flutter',
  });
}

/* =========================
 *  BALANCES (TRANSACTIONS)
 * ========================= */

/// Decrement remaining by [days] (non-negative) for a specific leave type.
Future<void> deductFromBalance({
  required String employeeId,
  required String leaveType,
  required int days,
}) async {
  assert(days >= 0);
  final empRef = _db.collection('leave_balances').doc(employeeId);

  await _db.runTransaction((tx) async {
    final snap = await tx.get(empRef);
    final data = (snap.exists ? snap.data() : {}) as Map<String, dynamic>;

    final key = leaveType;
    final rec = Map<String, dynamic>.from(data[key] ?? {});
    final remaining = (rec['remaining'] is num) ? (rec['remaining'] as num).toInt() : 0;

    rec['remaining'] = (remaining - days) < 0 ? 0 : (remaining - days);
    data[key] = rec;

    tx.set(empRef, data, SetOptions(merge: true));
  });
}

/// Increment remaining by [days] for a specific leave type.
Future<void> refundToBalance({
  required String employeeId,
  required String leaveType,
  required int days,
}) async {
  assert(days >= 0);
  final empRef = _db.collection('leave_balances').doc(employeeId);

  await _db.runTransaction((tx) async {
    final snap = await tx.get(empRef);
    final data = (snap.exists ? snap.data() : {}) as Map<String, dynamic>;

    final key = leaveType;
    final rec = Map<String, dynamic>.from(data[key] ?? {});
    final remaining = (rec['remaining'] is num) ? (rec['remaining'] as num).toInt() : 0;

    rec['remaining'] = remaining + days;
    data[key] = rec;

    tx.set(empRef, data, SetOptions(merge: true));
  });
}

/* =========================
 *  APPROVE / REJECT / PENDING
 * ========================= */

/// Approve + deduct balance + notify.
Future<void> approveRequest({
  required String docId,
  required String employeeId,
  required String employeeName,
  required String leaveType,
  required int totalDays,
  required String startDateText,
  required String endDateText,
  String? feedback,
}) async {
  // 1) status
  await updateLeaveStatus(docId: docId, status: 'approved', feedback: feedback);

  // 2) deduct balance
  if (totalDays > 0) {
    await deductFromBalance(
      employeeId: employeeId,
      leaveType: leaveType,
      days: totalDays,
    );
  }

  // 3) notify
  await _addNotification(
    employeeId: employeeId,
    title: 'Leave Approved',
    message:
        '$leaveType $startDateText–$endDateText ($totalDays day${totalDays == 1 ? '' : 's'})',
    status: 'approved',
  );
}

/// Reject + notify (no balance change).
Future<void> rejectRequest({
  required String docId,
  required String employeeId,
  required String leaveType,
  required int totalDays,
  required String startDateText,
  required String endDateText,
  String? feedback,
}) async {
  await updateLeaveStatus(docId: docId, status: 'rejected', feedback: feedback);

  await _addNotification(
    employeeId: employeeId,
    title: 'Leave Rejected',
    message:
        '$leaveType $startDateText–$endDateText ($totalDays day${totalDays == 1 ? '' : 's'})',
    status: 'rejected',
  );
}

/// Set back to pending (no balance change).
Future<void> markPending({
  required String docId,
  String? feedback,
}) async {
  await updateLeaveStatus(docId: docId, status: 'pending', feedback: feedback);
}

/* =========================
 *  CANCEL / DELETE
 * ========================= */

/// Delete from Firestore (used when the employee cancels). The website
/// `onSnapshot` will remove it automatically from the table.
Future<void> deleteLeaveRequest(String docId) async {
  await _db.collection('leave_requests').doc(docId).delete();
}

/// Cancel from the app:
///  - refunds balance
///  - (option A) delete document so website row disappears
///  - (option B) or mark as 'cancelled' if you prefer to keep history
Future<void> cancelRequestAndRefund({
  required String docId,
  required String employeeId,
  required String leaveType,
  required int totalDays,
  required String startDateText,
  required String endDateText,
  bool deleteDoc = true, // true = remove from website table immediately
}) async {
  // 1) refund
  if (totalDays > 0) {
    await refundToBalance(
      employeeId: employeeId,
      leaveType: leaveType,
      days: totalDays,
    );
  }

  // 2) either delete or mark as cancelled
  if (deleteDoc) {
    await deleteLeaveRequest(docId);
  } else {
    await updateLeaveStatus(docId: docId, status: 'cancelled');
  }

  // 3) notify
  await _addNotification(
    employeeId: employeeId,
    title: 'Leave Cancelled',
    message:
        '$leaveType $startDateText–$endDateText ($totalDays day${totalDays == 1 ? '' : 's'}) returned',
    status: 'cancelled',
  );
}
