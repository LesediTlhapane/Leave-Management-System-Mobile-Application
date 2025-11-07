// leave_balance_data.dart
//
// Tracks balances per user + detailed transaction history per leave type.

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
  LeaveBalance(
    type: "Annual Leave",
    policyText: "22 working days per year",
    allocated: 22,
    remaining: 22,
  ),
  LeaveBalance(
    type: "Sick Leave",
    policyText: "12 working days per year",
    allocated: 12,
    remaining: 12,
  ),
  LeaveBalance(
    type: "Maternity Leave",
    policyText: "4 months (approx. 120 days)",
    allocated: 120,
    remaining: 120,
  ),
  LeaveBalance(
    type: "Parental Leave",
    policyText: "10 consecutive days",
    allocated: 10,
    remaining: 10,
  ),
  LeaveBalance(
    type: "Adoption Leave",
    policyText: "10 consecutive weeks",
    allocated: 50,
    remaining: 50,
  ),
  LeaveBalance(
    type: "Commissioning Parental Leave",
    policyText: "10 consecutive weeks",
    allocated: 50,
    remaining: 50,
  ),
  LeaveBalance(
    type: "Family Responsibility Leave",
    policyText: "3 days per annual cycle",
    allocated: 3,
    remaining: 3,
  ),
  LeaveBalance(
    type: "Special Leave",
    policyText: "As approved (case-by-case)",
    allocated: null,
    remaining: null,
  ),
  LeaveBalance(
    type: "Unpaid Leave",
    policyText: "As approved (no fixed limit)",
    allocated: null,
    remaining: null,
  ),
];

void ensureBalancesForUser(String employeeId) {
  _balancesByEmployee.putIfAbsent(employeeId, () => _defaultPolicy());
  _historyByEmployee.putIfAbsent(employeeId, () => <String, List<LeaveTxn>>{});
}

List<LeaveBalance> getBalances(String employeeId) {
  ensureBalancesForUser(employeeId);
  final list = _balancesByEmployee[employeeId]!;
  return list
      .map((b) => LeaveBalance(
            type: b.type,
            policyText: b.policyText,
            allocated: b.allocated,
            remaining: b.remaining,
          ))
      .toList();
}

List<LeaveTxn> getBalanceHistory({
  required String employeeId,
  required String leaveType,
}) {
  ensureBalancesForUser(employeeId);
  final map = _historyByEmployee[employeeId]!;
  final list = map[leaveType] ?? const <LeaveTxn>[];
  return List<LeaveTxn>.from(list.reversed);
}

void _recordTxn({
  required String employeeId,
  required String leaveType,
  required String action,
  required int days,
  String? note,
}) {
  final map = _historyByEmployee[employeeId]!;
  final bucket = map.putIfAbsent(leaveType, () => <LeaveTxn>[]);
  bucket.add(LeaveTxn(
    timestamp: DateTime.now(),
    action: action,
    days: days,
    note: note,
  ));
}

bool deductBalance({
  required String employeeId,
  required String leaveType,
  required int days,
  String? note,
}) {
  ensureBalancesForUser(employeeId);
  final list = _balancesByEmployee[employeeId]!;
  final i = list.indexWhere((b) => b.type == leaveType);
  if (i == -1) {
    _recordTxn(
      employeeId: employeeId,
      leaveType: leaveType,
      action: "deduct",
      days: days,
      note: note,
    );
    return true;
  }

  final row = list[i];
  if (row.remaining == null) {
    _recordTxn(
      employeeId: employeeId,
      leaveType: leaveType,
      action: "deduct",
      days: days,
      note: note,
    );
    return true;
  }

  if (days > (row.remaining ?? 0)) return false;

  row.remaining = (row.remaining ?? 0) - days;
  _recordTxn(
    employeeId: employeeId,
    leaveType: leaveType,
    action: "deduct",
    days: days,
    note: note,
  );
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

  final i = list.indexWhere((b) => b.type == leaveType);
  if (i == -1) {
    _recordTxn(
      employeeId: employeeId,
      leaveType: leaveType,
      action: "refund",
      days: days,
      note: note,
    );
    return;
  }

  final row = list[i];
  if (row.remaining != null) {
    row.remaining = (row.remaining ?? 0) + days;
  }

  _recordTxn(
    employeeId: employeeId,
    leaveType: leaveType,
    action: "refund",
    days: days,
    note: note,
  );
}
