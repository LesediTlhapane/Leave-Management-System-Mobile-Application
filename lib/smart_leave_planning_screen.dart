// lib/smart_leave_planning_screen.dart
// LeaveFlow — Smart Leave Planning Suggestions
// Analyses leave balances + South African public holidays to suggest optimal leave periods

import 'package:flutter/material.dart';
import 'employee_data.dart';
import 'leave_balance_data.dart';

class SmartLeavePlanningScreen extends StatefulWidget {
  final Employee user;
  const SmartLeavePlanningScreen({super.key, required this.user});

  @override
  State<SmartLeavePlanningScreen> createState() =>
      _SmartLeavePlanningScreenState();
}

class _SmartLeavePlanningScreenState extends State<SmartLeavePlanningScreen>
    with SingleTickerProviderStateMixin {

  // ── colours ─────────────────────────────────────────────────
  static const _navy   = Color(0xFF1E2D5A);
  static const _blue   = Color(0xFF3B4D79);
  static const _accent = Color(0xFF6C8EF5);
  static const _bg     = Color(0xFFF5F7FB);
  static const _border = Color(0xFFE5E7EB);
  static const _muted  = Color(0xFF6B7280);
  static const _green  = Color(0xFF059669);

  // 2025 South African Public Holidays
  static final List<_PublicHoliday> _holidays = [
    _PublicHoliday("New Year's Day",         DateTime(2025, 1,  1)),
    _PublicHoliday("Human Rights Day",        DateTime(2025, 3, 21)),
    _PublicHoliday("Good Friday",             DateTime(2025, 4, 18)),
    _PublicHoliday("Family Day",              DateTime(2025, 4, 21)),
    _PublicHoliday("Freedom Day",             DateTime(2025, 4, 27)),
    _PublicHoliday("Workers' Day",            DateTime(2025, 5,  1)),
    _PublicHoliday("Youth Day",               DateTime(2025, 6, 16)),
    _PublicHoliday("National Women's Day",    DateTime(2025, 8,  9)),
    _PublicHoliday("Heritage Day",            DateTime(2025, 9, 24)),
    _PublicHoliday("Day of Reconciliation",   DateTime(2025, 12, 16)),
    _PublicHoliday("Christmas Day",           DateTime(2025, 12, 25)),
    _PublicHoliday("Day of Goodwill",         DateTime(2025, 12, 26)),
    // 2026
    _PublicHoliday("New Year's Day 2026",     DateTime(2026, 1,  1)),
    _PublicHoliday("Human Rights Day 2026",   DateTime(2026, 3, 21)),
  ];

  List<_LeaveSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _buildSuggestions();
  }

  void _buildSuggestions() {
    final balances = getBalances(widget.user.id);
    final annualBalance = balances.firstWhere(
      (b) => b.type.toLowerCase().contains('annual'),
      orElse: () => LeaveBalance(
          type: 'Annual Leave', policyText: '', allocated: 15, remaining: 10),
    );
    final daysLeft = annualBalance.remaining ?? 10;
    final today    = DateTime.now();

    final List<_LeaveSuggestion> result = [];

    // ── Strategy 1: Bridge days around public holidays ──────
    for (final ph in _holidays) {
      if (ph.date.isBefore(today)) continue;

      // Tuesday PH → take Monday off (long weekend = 4 days with 1 leave)
      if (ph.date.weekday == DateTime.tuesday) {
        final bridgeDay = ph.date.subtract(const Duration(days: 1));
        result.add(_LeaveSuggestion(
          title: 'Long Weekend — ${ph.name}',
          subtitle:
              'Take 1 leave day (${_fmt(bridgeDay)}) to get a 4-day weekend',
          leaveDaysNeeded: 1,
          freeDays: 4,
          icon: Icons.weekend_outlined,
          color: const Color(0xFF7C3AED),
          startDate: bridgeDay,
          endDate: ph.date,
          tip: 'Bridge day strategy: ${_fmt(bridgeDay)} off + '
              '${ph.name} = 4-day break!',
        ));
      }

      // Thursday PH → take Friday off (4-day weekend with 1 leave)
      if (ph.date.weekday == DateTime.thursday) {
        final friday = ph.date.add(const Duration(days: 1));
        result.add(_LeaveSuggestion(
          title: 'Long Weekend — ${ph.name}',
          subtitle:
              'Take 1 leave day (${_fmt(friday)}) to get a 4-day weekend',
          leaveDaysNeeded: 1,
          freeDays: 4,
          icon: Icons.weekend_outlined,
          color: const Color(0xFF7C3AED),
          startDate: ph.date,
          endDate: friday,
          tip: 'Take Friday ${_fmt(friday)} off — 4-day weekend for just 1 leave day!',
        ));
      }

      // Wednesday PH → take Tue + Thu = 5-day break with 2 leave days
      if (ph.date.weekday == DateTime.wednesday) {
        final tue = ph.date.subtract(const Duration(days: 1));
        final thu = ph.date.add(const Duration(days: 1));
        result.add(_LeaveSuggestion(
          title: '5-Day Break — ${ph.name}',
          subtitle:
              'Take Tue & Thu off (2 days) around ${ph.name} for a full week off',
          leaveDaysNeeded: 2,
          freeDays: 5,
          icon: Icons.beach_access_outlined,
          color: _green,
          startDate: tue,
          endDate: thu,
          tip:
              '${_fmt(tue)} + ${_fmt(thu)} = 5-day week for only 2 leave days!',
        ));
      }
    }

    // ── Strategy 2: End-of-year rollover warning ─────────────
    if (daysLeft > 0) {
      final yearEnd = DateTime(today.year, 12, 31);
      final daysUntilYearEnd = yearEnd.difference(today).inDays;
      if (daysUntilYearEnd < 90 && daysLeft >= 3) {
        result.add(_LeaveSuggestion(
          title: 'Use It or Lose It ⚠️',
          subtitle:
              'You have $daysLeft annual days left — use them before year end',
          leaveDaysNeeded: daysLeft,
          freeDays: daysLeft,
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFD97706),
          startDate: today.add(const Duration(days: 7)),
          endDate: yearEnd,
          tip:
              'Year-end is in $daysUntilYearEnd days. Plan your time off now!',
        ));
      }
    }

    // ── Strategy 3: Festive season block ─────────────────────
    final dec22 = DateTime(today.year < 2025 ? 2025 : today.year, 12, 22);
    if (dec22.isAfter(today) && daysLeft >= 5) {
      result.add(_LeaveSuggestion(
        title: 'Festive Season Block 🎄',
        subtitle:
            'Dec 22 – Jan 2: Use 5 leave days to get 12 consecutive days off',
        leaveDaysNeeded: 5,
        freeDays: 12,
        icon: Icons.celebration_outlined,
        color: const Color(0xFFDC2626),
        startDate: dec22,
        endDate: DateTime(today.year < 2025 ? 2026 : today.year + 1, 1, 2),
        tip:
            'Combine 5 leave days with 2 public holidays & weekends = 12 days!',
      ));
    }

    // ── Strategy 4: Mid-year recharge ─────────────────────────
    if (daysLeft >= 3) {
      final june = DateTime(today.year, 6, 16); // Youth Day
      if (june.isAfter(today)) {
        result.add(_LeaveSuggestion(
          title: 'Mid-Year Recharge 🌿',
          subtitle:
              'Take 3 days around Youth Day (Jun 16) for a 6-day refresh',
          leaveDaysNeeded: 3,
          freeDays: 6,
          icon: Icons.spa_outlined,
          color: _green,
          startDate: DateTime(today.year, 6, 14),
          endDate: DateTime(today.year, 6, 22),
          tip: 'June 14–22: 3 leave days + Youth Day + weekends = 6-day break!',
        ));
      }
    }

    // Sort by date
    result.sort((a, b) => a.startDate.compareTo(b.startDate));

    setState(() => _suggestions = result.take(6).toList());
  }

  static String _fmt(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday]} ${d.day} ${months[d.month]}';
  }

  @override
  Widget build(BuildContext context) {
    final balances   = getBalances(widget.user.id);
    final annualBal  = balances.firstWhere(
      (b) => b.type.toLowerCase().contains('annual'),
      orElse: () =>
          LeaveBalance(type: 'Annual Leave', policyText: '', remaining: 10),
    );
    final daysLeft = annualBal.remaining ?? 0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Smart Leave Planner',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Summary banner ─────────────────────────────────
          _buildSummaryBanner(daysLeft),
          const SizedBox(height: 20),

          // ── Section header ─────────────────────────────────
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: _accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Recommended Opportunities',
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Based on your ${daysLeft} remaining days & SA public holidays',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 14),

          // ── Suggestion cards ────────────────────────────────
          if (_suggestions.isEmpty)
            _buildEmpty()
          else
            ..._suggestions.map((s) => _buildSuggestionCard(s)),

          const SizedBox(height: 20),

          // ── Public holidays section ─────────────────────────
          _buildHolidaysSection(),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(int daysLeft) {
    final pct = daysLeft / 15.0;
    final color = pct > 0.5
        ? _green
        : pct > 0.25
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2D5A), Color(0xFF3B4D79)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                'Hello, ${widget.user.name.split(' ').first}!',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$daysLeft days',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Annual leave remaining',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Center(
                  child: Text(
                    '${(pct * 100).round()}%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(_LeaveSuggestion s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(color: s.color.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: s.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(s.icon, color: s.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.subtitle,
                        style:
                            const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Stat(
                      label: 'Leave days',
                      value: '${s.leaveDaysNeeded}',
                      color: _blue,
                    ),
                    const SizedBox(width: 12),
                    _Stat(
                      label: 'Days off',
                      value: '${s.freeDays}',
                      color: _green,
                    ),
                    const SizedBox(width: 12),
                    _Stat(
                      label: 'Ratio',
                      value:
                          '1:${(s.freeDays / s.leaveDaysNeeded).toStringAsFixed(1)}',
                      color: s.color,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tips_and_updates_outlined,
                          color: _accent, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.tip,
                          style: const TextStyle(
                              color: _blue, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_available_outlined, color: _muted, size: 40),
          SizedBox(height: 12),
          Text(
            'No upcoming suggestions right now.\nCheck back later!',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidaysSection() {
    final today     = DateTime.now();
    final upcoming  = _holidays.where((h) => h.date.isAfter(today)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.flag_outlined, color: _accent, size: 18),
            SizedBox(width: 8),
            Text(
              'Upcoming Public Holidays',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Color(0xFF111827)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: upcoming.take(8).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final h = entry.value;
              final isLast = i == upcoming.take(8).length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : const Border(
                          bottom: BorderSide(color: _border)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${h.date.day}',
                          style: const TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF111827))),
                          Text(_fmt(h.date),
                              style: const TextStyle(
                                  color: _muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _dayName(h.date.weekday),
                        style: const TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static String _dayName(int wd) {
    const n = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return n[wd];
  }
}

// ── Helper widgets ────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────

class _PublicHoliday {
  final String name;
  final DateTime date;
  const _PublicHoliday(this.name, this.date);
}

class _LeaveSuggestion {
  final String title;
  final String subtitle;
  final int leaveDaysNeeded;
  final int freeDays;
  final IconData icon;
  final Color color;
  final DateTime startDate;
  final DateTime endDate;
  final String tip;

  const _LeaveSuggestion({
    required this.title,
    required this.subtitle,
    required this.leaveDaysNeeded,
    required this.freeDays,
    required this.icon,
    required this.color,
    required this.startDate,
    required this.endDate,
    required this.tip,
  });
}