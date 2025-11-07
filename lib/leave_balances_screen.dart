import 'package:flutter/material.dart';
import 'employee_data.dart';
import 'leave_balance_data.dart';
import 'leave_balance_detail_screen.dart'; // keep if present

class LeaveBalancesScreen extends StatefulWidget {
  final Employee user;
  const LeaveBalancesScreen({super.key, required this.user});

  @override
  State<LeaveBalancesScreen> createState() => _LeaveBalancesScreenState();
}

class _LeaveBalancesScreenState extends State<LeaveBalancesScreen> {
  static const _brandBlue = Color(0xFF3B4D79);
  static const _heading = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    ensureBalancesForUser(widget.user.id);
  }

  @override
  Widget build(BuildContext context) {
    final balances = getBalances(widget.user.id);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _brandBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Leave Balances",
          style: TextStyle(color: _heading, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: balances.length,
        itemBuilder: (context, i) {
          final b = balances[i];
          final isUnlimited = b.remaining == null;
          final used = isUnlimited ? null : b.used;
          final left = isUnlimited ? null : b.remaining!;
          final total = isUnlimited ? null : b.allocated!;
          final progress =
              (isUnlimited || total == 0) ? null : (used! / total!.clamp(1, 1 << 30));

          final card = Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
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
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: const Icon(Icons.event_available_outlined,
                            color: _brandBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.type,
                                style: const TextStyle(
                                  color: _heading,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                )),
                            const SizedBox(height: 4),
                            Text(
                              b.policyText,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFD7E3FF)),
                        ),
                        child: Text(
                          isUnlimited ? "Unlimited" : "$left left",
                          style: const TextStyle(
                            color: _brandBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (!isUnlimited) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress!.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: const Color(0xFFF3F4F6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$used used of $total",
                          style: const TextStyle(color: _muted, fontSize: 12.5),
                        ),
                        Text(
                          "$left remaining",
                          style: const TextStyle(color: _muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );

          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LeaveBalanceDetailScreen(
                    user: widget.user,
                    leaveType: b.type,
                  ),
                ),
              );
            },
            child: card,
          );
        },
      ),
    );
  }
}
