import 'package:flutter/material.dart';
import 'employee_data.dart';
import 'leave_balance_data.dart';

class LeaveBalanceDetailScreen extends StatelessWidget {
  final Employee user;
  final String leaveType;

  const LeaveBalanceDetailScreen({
    super.key,
    required this.user,
    required this.leaveType,
  });

  static const _brandBlue = Color(0xFF3B4D79);
  static const _heading   = Color(0xFF111827);
  static const _muted     = Color(0xFF6B7280);
  static const _border    = Color(0xFFE5E7EB);
  static const _bg        = Color(0xFFF5F7FB);

  @override
  Widget build(BuildContext context) {
    final balances = getBalances(user.id);
    final row = balances.firstWhere(
      (b) => b.type == leaveType,
      orElse: () => LeaveBalance(type: leaveType, policyText: "", allocated: null, remaining: null),
    );
    final history = getBalanceHistory(employeeId: user.id, leaveType: leaveType);

    final isUnlimited = row.remaining == null || row.allocated == null;
    final total = row.allocated ?? 0;
    final left  = row.remaining ?? 0;
    final used  = isUnlimited ? 0 : row.used;
    final pct   = isUnlimited || total == 0 ? 0.0 : (used / total).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _brandBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          leaveType,
          style: const TextStyle(color: _heading, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Summary card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
              boxShadow: const [BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 4))],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _heading)),
                const SizedBox(height: 12),
                if (!isUnlimited) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFF3F4F6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("$used used of $total", style: const TextStyle(color: _muted)),
                      Text("$left remaining", style: const TextStyle(color: _muted)),
                    ],
                  ),
                ] else
                  const Text("Unlimited / not tracked", style: TextStyle(color: _muted)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // History
          Row(
            children: const [
              Icon(Icons.history, size: 18, color: _muted),
              SizedBox(width: 6),
              Text("History", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _heading)),
            ],
          ),
          const SizedBox(height: 10),

          if (history.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              padding: const EdgeInsets.all(14),
              child: const Text("No activity yet.", style: TextStyle(color: _muted)),
            )
          else
            ...history.map((txn) {
              final isRefund = txn.action == "refund";
              final sign = isRefund ? "+" : "−";
              final color = isRefund ? Colors.green[700] : Colors.red[700];
              final date = _fmt(txn.timestamp);
              final subtitle = (txn.note ?? "").isEmpty ? null : txn.note;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: (isRefund ? const Color(0xFFE6F4EA) : const Color(0xFFFEE2E2)),
                      child: Icon(isRefund ? Icons.undo : Icons.remove_circle_outline,
                          color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${isRefund ? "Returned" : "Deducted"} $sign${txn.days} day(s)",
                            style: TextStyle(fontWeight: FontWeight.w800, color: color),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(subtitle, style: const TextStyle(color: _muted)),
                          ],
                          const SizedBox(height: 6),
                          Text(date, style: const TextStyle(color: _muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}";
  }
}
