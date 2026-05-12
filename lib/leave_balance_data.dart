// leave_balance_data.dart
// FIXED: 
//  1. getBalances() returns live references (no copies)
//  2. syncBalancesFromFirestore() rebuilds local balances from Firestore on login
//  3. leaveTypeAlias is optional in deductBalance

import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveBalance {
  final String type;
  final String policyText;
  final int? allocated;
  int? remaining;

  LeaveBalance({
    required this.type,
    required this.policyText,
    required this.allocated,
    required this.remaining,
  });

  int get used => (allocated ?? 0) - (remaining ?? 0);
}

class LeaveTxn {
  final DateTime timestamp;
  final String action; // "deduct" | "refund"
  final int days;
  final String? note;

  LeaveTxn({
    required this.timestamp,
    required this.action,
    required this.days,
    this.note,
  });
}

final Map<String, List<LeaveBalance>> _balancesByEmployee = {};
final Map<String, Map<String, List<LeaveTxn>>> _historyByEmployee = {};

List<LeaveBalance> _defaultPolicy() => [
  LeaveBalance(type: "Annual Leave",                 policyText: "22 working days per year",        allocated: 22,  remaining: 22),
  LeaveBalance(type: "Sick Leave",                   policyText: "12 working days per year",        allocated: 12,  remaining: 12),
  LeaveBalance(type: "Maternity Leave",              policyText: "4 months (approx. 120 days)",     allocated: 120, remaining: 120),
  LeaveBalance(type: "Parental Leave",               policyText: "10 consecutive days",             allocated: 10,  remaining: 10),
  LeaveBalance(type: "Adoption Leave",               policyText: "10 consecutive weeks",            allocated: 50,  remaining: 50),
  LeaveBalance(type: "Commissioning Parental Leave", policyText: "10 consecutive weeks",            allocated: 50,  remaining: 50),
  LeaveBalance(type: "Family Responsibility Leave",  policyText: "3 days per annual cycle",         allocated: 3,   remaining: 3),
  LeaveBalance(type: "Special Leave",                policyText: "As approved (case-by-case)",      allocated: null, remaining: null),
  LeaveBalance(type: "Unpaid Leave",                 policyText: "As approved (no fixed limit)",    allocated: null, remaining: null),
];

void ensureBalancesForUser(String employeeId) {
  _balancesByEmployee.putIfAbsent(employeeId, () => _defaultPolicy());
  _historyByEmployee.putIfAbsent(employeeId, () => <String, List<LeaveTxn>>{});
}

// CORE FIX: returns live list, not copies
List<LeaveBalance> getBalances(String employeeId) {
  ensureBalancesForUser(employeeId);
  return _balancesByEmployee[employeeId]!;
}

// ── SYNC FROM FIRESTORE ───────────────────────────────────────────────────────
// Call in HomeScreen.initState() after ensureBalancesForUser().
// Resets to defaults then deducts all APPROVED leave from Firestore
// so balances survive app restarts.
Future<void> syncBalancesFromFirestore(String employeeId) async {
  try {
    // Reset to fresh defaults
    _balancesByEmployee[employeeId] = _defaultPolicy();
    _historyByEmployee[employeeId]  = <String, List<LeaveTxn>>{};

    final snap = await FirebaseFirestore.instance
        .collection('leave_requests')
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: 'approved')
        .get();

    for (final doc in snap.docs) {
      final data      = doc.data();
      final leaveType = (data['leaveType'] ?? '').toString();
      final totalDays = (data['totalDays'] is num)
          ? (data['totalDays'] as num).toInt()
          : 0;
      if (leaveType.isEmpty || totalDays <= 0) continue;
      _deductDirect(employeeId: employeeId, leaveType: leaveType, days: totalDays);
    }
    print('syncBalancesFromFirestore: done for $employeeId');
  } catch (e) {
    print('syncBalancesFromFirestore error: $e');
  }
}

// Internal deduct — no balance guard (used only during sync)
void _deductDirect({
  required String employeeId,
  required String leaveType,
  required int days,
}) {
  final list = _balancesByEmployee[employeeId]!;
  final i    = _findIndex(list, leaveType);
  if (i == -1) return;
  final row  = list[i];
  if (row.remaining == null) return;
  row.remaining = ((row.remaining ?? 0) - days).clamp(0, row.allocated ?? 9999);
}

List<LeaveTxn> getBalanceHistory({
  required String employeeId,
  required String leaveType,
}) {
  ensureBalancesForUser(employeeId);
  final list = (_historyByEmployee[employeeId]?[leaveType]) ?? const <LeaveTxn>[];
  return List<LeaveTxn>.from(list.reversed);
}

void _recordTxn({
  required String employeeId,
  required String leaveType,
  required String action,
  required int days,
  String? note,
}) {
  final map    = _historyByEmployee[employeeId]!;
  final bucket = map.putIfAbsent(leaveType, () => <LeaveTxn>[]);
  bucket.add(LeaveTxn(timestamp: DateTime.now(), action: action, days: days, note: note));
}

int _findIndex(List<LeaveBalance> list, String leaveType) {
  int i = list.indexWhere((b) => b.type == leaveType);
  if (i != -1) return i;
  i = list.indexWhere((b) => b.type.toLowerCase() == leaveType.toLowerCase());
  if (i != -1) return i;
  i = list.indexWhere((b) =>
      b.type.toLowerCase().contains(leaveType.toLowerCase()) ||
      leaveType.toLowerCase().contains(b.type.toLowerCase()));
  return i;
}

bool deductBalance({
  required String employeeId,
  required String leaveType,
  String? leaveTypeAlias,
  required int days,
  String? note,
}) {
  ensureBalancesForUser(employeeId);
  final list = _balancesByEmployee[employeeId]!;

  int i = _findIndex(list, leaveType);
  if (i == -1 && leaveTypeAlias != null) i = _findIndex(list, leaveTypeAlias);

  if (i == -1) {
    _recordTxn(employeeId: employeeId, leaveType: leaveType, action: "deduct", days: days, note: note);
    return true;
  }

  final row = list[i];
  if (row.remaining == null) {
    _recordTxn(employeeId: employeeId, leaveType: row.type, action: "deduct", days: days, note: note);
    return true;
  }
  if (days > (row.remaining ?? 0)) return false;

  row.remaining = (row.remaining ?? 0) - days;
  _recordTxn(employeeId: employeeId, leaveType: row.type, action: "deduct", days: days, note: note);
  return true;
}

void refundBalance({
  required String employeeId,
  required String leaveType,
  required int days,
  String? note,
}) {
  ensureBalancesForUser(employeeId);
  final list = _balancesByEmployee[employeeId];
  if (list == null) return;

  final i = _findIndex(list, leaveType);
  if (i == -1) {
    _recordTxn(employeeId: employeeId, leaveType: leaveType, action: "refund", days: days, note: note);
    return;
  }

  final row = list[i];
  if (row.remaining != null) {
    final max = row.allocated ?? (row.remaining! + days);
    row.remaining = ((row.remaining ?? 0) + days).clamp(0, max);
  }
  _recordTxn(employeeId: employeeId, leaveType: row.type, action: "refund", days: days, note: note);
}