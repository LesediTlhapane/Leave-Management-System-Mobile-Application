// lib/fire_backend.dart

import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore _db = FirebaseFirestore.instance;

/* =========================
 *  CREATE LEAVE REQUEST
 * ========================= */

Future<String> createLeaveRequest({
  required String employeeId,
  required String employeeName,
  required String department,
  required String leaveType,
  required int totalDays,
  required String startDateIso,
  required String endDateIso,
  required String startDateText,
  required String endDateText,
  required String reason,
  String? attachmentUrl,
  String? attachmentName,
}) async {
  try {
    final payload = <String, dynamic>{
      'employeeId': employeeId.toString(),
      'employeeName': employeeName.toString(),
      'department': department.toString(),
      'leaveType': leaveType.toString(),
      'totalDays': totalDays,
      'startDateIso': startDateIso.toString(),
      'endDateIso': endDateIso.toString(),
      'startDateText': startDateText.toString(),
      'endDateText': endDateText.toString(),
      'reason': reason.toString(),

      'status': 'pending',

      // IMPORTANT FIX
      'createdAt': Timestamp.now(),

      'source': 'flutter',

      if (attachmentUrl != null)
        'attachmentUrl': attachmentUrl,

      if (attachmentName != null)
        'attachmentName': attachmentName,
    };

    print('WRITING TO FIRESTORE...');
    print(payload);

    final ref = await _db
        .collection('leave_requests')
        .add(payload);

    print('SUCCESSFULLY CREATED DOCUMENT');
    print(ref.id);

    return ref.id;

  } catch (e) {
    print('CREATE LEAVE REQUEST ERROR');
    print(e);

    rethrow;
  }
}

/* =========================
 *  STATUS UPDATE
 * ========================= */

Future<void> updateLeaveStatus({
  required String docId,
  required String status,
  String? feedback,
}) async {
  try {
    await _db
        .collection('leave_requests')
        .doc(docId)
        .update({
      'status': status,
      'feedback': feedback ?? '',
      'decidedAt': Timestamp.now(),
    });

    print('STATUS UPDATED');

  } catch (e) {
    print('UPDATE STATUS ERROR');
    print(e);
  }
}

/* =========================
 *  NOTIFICATIONS
 * ========================= */

Future<void> _addNotification({
  required String employeeId,
  required String title,
  required String message,
  String? status,
}) async {
  try {
    await _db
        .collection('notifications')
        .add({
      'employeeId': employeeId,
      'title': title,
      'message': message,
      'status': status ?? '',
      'createdAt': Timestamp.now(),
      'source': 'flutter',
    });

    print('NOTIFICATION ADDED');

  } catch (e) {
    print('NOTIFICATION ERROR');
    print(e);
  }
}

/* =========================
 *  BALANCE DEDUCTION
 * ========================= */

Future<void> deductFromBalance({
  required String employeeId,
  required String leaveType,
  required int days,
}) async {
  try {
    final empRef =
        _db.collection('leave_balances').doc(employeeId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(empRef);

      final data =
          (snap.exists ? snap.data() : {}) as Map<String, dynamic>;

      final key = leaveType;

      final rec =
          Map<String, dynamic>.from(data[key] ?? {});

      final remaining =
          (rec['remaining'] is num)
              ? (rec['remaining'] as num).toInt()
              : 0;

      rec['remaining'] =
          (remaining - days) < 0
              ? 0
              : (remaining - days);

      data[key] = rec;

      tx.set(
        empRef,
        data,
        SetOptions(merge: true),
      );
    });

    print('BALANCE DEDUCTED');

  } catch (e) {
    print('BALANCE DEDUCTION ERROR');
    print(e);
  }
}

/* =========================
 *  BALANCE REFUND
 * ========================= */

Future<void> refundToBalance({
  required String employeeId,
  required String leaveType,
  required int days,
}) async {
  try {
    final empRef =
        _db.collection('leave_balances').doc(employeeId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(empRef);

      final data =
          (snap.exists ? snap.data() : {}) as Map<String, dynamic>;

      final key = leaveType;

      final rec =
          Map<String, dynamic>.from(data[key] ?? {});

      final remaining =
          (rec['remaining'] is num)
              ? (rec['remaining'] as num).toInt()
              : 0;

      rec['remaining'] = remaining + days;

      data[key] = rec;

      tx.set(
        empRef,
        data,
        SetOptions(merge: true),
      );
    });

    print('BALANCE REFUNDED');

  } catch (e) {
    print('BALANCE REFUND ERROR');
    print(e);
  }
}
/* =========================
 *  DELETE REQUEST
 * ========================= */

Future<void> deleteLeaveRequest(String docId) async {
  try {
    await _db
        .collection('leave_requests')
        .doc(docId)
        .delete();

    print('REQUEST DELETED');

  } catch (e) {
    print('DELETE ERROR');
    print(e);
  }
}

/* =========================
 *  CANCEL REQUEST
 * ========================= */

Future<void> cancelRequestAndRefund({
  required String docId,
  required String employeeId,
  required String leaveType,
  required int totalDays,
  required String startDateText,
  required String endDateText,
  bool deleteDoc = true,
}) async {
  try {

    // REFUND BALANCE
    if (totalDays > 0) {
      await refundToBalance(
        employeeId: employeeId,
        leaveType: leaveType,
        days: totalDays,
      );
    }

    // DELETE OR MARK CANCELLED
    if (deleteDoc) {
      await deleteLeaveRequest(docId);
    } else {
      await updateLeaveStatus(
        docId: docId,
        status: 'cancelled',
      );
    }

    // SEND NOTIFICATION
    await _addNotification(
      employeeId: employeeId,
      title: 'Leave Cancelled',
      message:
          '$leaveType $startDateText - $endDateText '
          '($totalDays day${totalDays == 1 ? '' : 's'}) returned',
      status: 'cancelled',
    );

    print('REQUEST CANCELLED');

  } catch (e) {
    print('CANCEL REQUEST ERROR');
    print(e);
  }
}