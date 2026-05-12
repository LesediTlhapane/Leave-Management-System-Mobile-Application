// lib/leave_balances_screen.dart
// FIX: uses setState on every rebuild so live balance changes are always shown.

import 'package:flutter/material.dart';
import 'employee_data.dart';
import 'leave_balance_data.dart';
import 'leave_balance_detail_screen.dart';

class LeaveBalancesScreen extends StatefulWidget {
  final Employee user;
  const LeaveBalancesScreen({super.key, required this.user});

  @override
  State<LeaveBalancesScreen> createState() => _LeaveBalancesScreenState();
}

class _LeaveBalancesScreenState extends State<LeaveBalancesScreen> {
  // ── colours matching the new navy theme ──────────────────────
  static const _navy   = Color(0xFF1E2D5A);
  static const _blue   = Color(0xFF3B4D79);
  static const _accent = Color(0xFF6C8EF5);
  static const _bg     = Color(0xFFF5F7FB);
  static const _border = Color(0xFFE5E7EB);
  static const _heading= Color(0xFF111827);
  static const _muted  = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    ensureBalancesForUser(widget.user.id);
  }

  // Re-read live balances every time the widget rebuilds (covers returning
  // from detail screen, apply screen, etc.)
  void _refresh() => setState(() {});

  Color _barColor(double pct) {
    if (pct <= 0.25) return const Color(0xFFDC2626); // red  — critically low
    if (pct <= 0.50) return const Color(0xFFD97706); // amber — running low
    return const Color(0xFF059669);                   // green — healthy
  }

  @override
  Widget build(BuildContext context) {
    // getBalances() now returns the LIVE list — no copies
    final balances = getBalances(widget.user.id);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _navy,
        surfaceTintColor: _navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Leave Balances',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withOpacity(0.1)),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: balances.length,
        itemBuilder: (context, i) {
          final b           = balances[i];
          final isUnlimited = b.remaining == null || b.allocated == null;
          final total       = b.allocated ?? 0;
          final remaining   = b.remaining ?? 0;
          final used        = isUnlimited ? 0 : b.used;
          final pct         = (isUnlimited || total == 0)
              ? 0.0
              : (remaining / total).clamp(0.0, 1.0);
          final barColor    = _barColor(pct);

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LeaveBalanceDetailScreen(
                    user: widget.user,
                    leaveType: b.type,
                  ),
                ),
              ).then((_) => _refresh()); // ← refresh when returning
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 10,
                      offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  // ── Header row ─────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD7E3FF)),
                          ),
                          child: const Icon(Icons.event_available_outlined,
                              color: _blue, size: 20),
                        ),
                        const SizedBox(width: 12),

                        // Title + policy
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.type,
                                  style: const TextStyle(
                                    color: _heading,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                  )),
                              const SizedBox(height: 3),
                              Text(b.policyText,
                                  style: const TextStyle(
                                      color: _muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Remaining pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isUnlimited
                                ? const Color(0xFFEEF2FF)
                                : barColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isUnlimited
                                  ? const Color(0xFFD7E3FF)
                                  : barColor.withOpacity(0.35),
                            ),
                          ),
                          child: Text(
                            isUnlimited ? 'Unlimited' : '$remaining left',
                            style: TextStyle(
                              color: isUnlimited ? _blue : barColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Progress bar + stats ────────────────────────
                  if (!isUnlimited) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFF3F4F6),
                          valueColor: AlwaysStoppedAnimation(barColor),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Used chip
                          Row(children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                  color: barColor,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text('$used used of $total',
                                style: const TextStyle(
                                    color: _muted, fontSize: 12)),
                          ]),
                          // Remaining text
                          Text(
                            '$remaining remaining',
                            style: TextStyle(
                              color: barColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Row(children: [
                        Icon(Icons.all_inclusive_rounded, color: _muted, size: 14),
                        SizedBox(width: 5),
                        Text('No fixed limit — as approved',
                            style: TextStyle(color: _muted, fontSize: 12)),
                      ]),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}