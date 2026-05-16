// lib/wellbeing_screen.dart
// LeaveFlow — Wellbeing & Burnout Indicator
// Unique per employee: computed from leave patterns, pending days, and check-in responses

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'employee_data.dart';
import 'leave_balance_data.dart';
import 'leave_model.dart'; // LeaveApplication, myLeaves

// ─── PUBLIC ENTRY POINT ──────────────────────────────────────────
class WellbeingScreen extends StatefulWidget {
  final Employee user;
  const WellbeingScreen({super.key, required this.user});

  @override
  State<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends State<WellbeingScreen>
    with TickerProviderStateMixin {

  // ── colours ──────────────────────────────────────────────────
  static const _navy   = Color(0xFF1E2D5A);
  static const _blue   = Color(0xFF3B4D79);
  static const _accent = Color(0xFF6C8EF5);
  static const _bg     = Color(0xFFF5F7FB);
  static const _border = Color(0xFFE5E7EB);
  static const _muted  = Color(0xFF6B7280);

  // ── check-in questions ───────────────────────────────────────
  static const _questions = [
    'How energised do you feel at work lately?',
    'How well are you managing your workload?',
    'How often do you feel stressed or overwhelmed?',
    'How satisfied are you with your work–life balance?',
    'How rested do you feel after weekends or time off?',
  ];

  final List<int?> _answers = List.filled(5, null);  // 1=low  5=high
  bool _submitted = false;
  late AnimationController _gaugeController;
  late Animation<double>    _gaugeAnim;

  // ── computed scores ──────────────────────────────────────────
  late _WellbeingResult _result;

  @override
  void initState() {
    super.initState();
    _gaugeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _gaugeAnim = CurvedAnimation(
        parent: _gaugeController, curve: Curves.easeOutCubic);
    _result = _computeFromBehavioural();
    _gaugeController.forward();
  }

  @override
  void dispose() {
    _gaugeController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // SCORE COMPUTATION
  // ─────────────────────────────────────────────────────────────

  /// Behavioural score (from leave data): shown before check-in
  _WellbeingResult _computeFromBehavioural() {
    final empId   = widget.user.id;
    final leaves  = leavesFor(empId);
    final balances= getBalances(empId);
    final now     = DateTime.now();

    // --- Factor 1: unused leave ratio -------------------------
    final annual = balances.firstWhere(
      (b) => b.type.toLowerCase().contains('annual'),
      orElse: () =>
          LeaveBalance(type: 'Annual', policyText: '', allocated: 15, remaining: 15),
    );
    final unusedRatio =
        (annual.allocated != null && annual.allocated! > 0)
            ? (annual.remaining ?? 0) / annual.allocated!
            : 0.5;
    // High unused ratio → possible overwork
    final f1 = unusedRatio > 0.8 ? 30.0 : unusedRatio > 0.5 ? 55.0 : 75.0;

    // --- Factor 2: sick leave usage in last 6 months ----------
    final sixMonthsAgo = now.subtract(const Duration(days: 180));
    final recentSick = leaves.where((l) {
      if (!l.leaveType.toLowerCase().contains('sick')) return false;
      try {
        final d = DateTime.parse(l.startDate);
        return d.isAfter(sixMonthsAgo);
      } catch (_) { return false; }
    }).length;
    final f2 = recentSick == 0 ? 80.0 : recentSick <= 2 ? 60.0 : 35.0;

    // --- Factor 3: pending / rejected applications ------------
    final rejected = leaves.where((l) => l.status == 'rejected').length;
    final pending  = leaves.where((l) => l.status == 'pending').length;
    final f3 = rejected >= 2 ? 40.0 : pending >= 3 ? 55.0 : 75.0;

    // --- Factor 4: days since last approved leave -------------
    DateTime? lastLeaveEnd;
    for (final l in leaves) {
      if (l.status != 'approved') continue;
      try {
        final d = DateTime.parse(l.endDate);
        if (lastLeaveEnd == null || d.isAfter(lastLeaveEnd)) lastLeaveEnd = d;
      } catch (_) {}
    }
    final daysSinceLast = lastLeaveEnd != null
        ? now.difference(lastLeaveEnd).inDays
        : 999;
    final f4 = daysSinceLast < 30  ? 85.0
             : daysSinceLast < 90  ? 65.0
             : daysSinceLast < 180 ? 45.0
             : 25.0;

    final score = ((f1 + f2 + f3 + f4) / 4.0).clamp(0.0, 100.0);
    return _WellbeingResult(
      score:  score,
      source: 'Behavioural Analysis',
      tips:   _tipsFor(score, unusedRatio, recentSick, daysSinceLast),
    );
  }

  /// Combined score once check-in is submitted
  _WellbeingResult _computeCombined() {
    final base         = _computeFromBehavioural();
    final answered     = _answers.where((a) => a != null).length;
    if (answered == 0) return base;

    final selfScore = _answers
        .where((a) => a != null)
        .map((a) => a! * 20.0)   // 1–5 → 20–100
        .reduce((a, b) => a + b) / answered;

    // weighted: 40% behavioural + 60% self-reported
    final combined = (base.score * 0.4 + selfScore * 0.6).clamp(0.0, 100.0);
    return _WellbeingResult(
      score:  combined,
      source: 'Self-Reported + Behavioural',
      tips:   _tipsFor(combined, 0, 0, 0),
    );
  }

  List<String> _tipsFor(
      double score, double unusedRatio, int sickCount, int daysSinceLast) {
    final tips = <String>[];
    if (score < 40) {
      tips.addAll([
        'Consider booking leave soon — rest is essential for recovery.',
        'Talk to HR about your workload; support is available.',
        'Try to disconnect from work completely during evenings.',
      ]);
    } else if (score < 65) {
      tips.addAll([
        'You\'re managing well — keep an eye on your workload.',
        'Plan a short break soon to recharge.',
        'Stay connected with your team for peer support.',
      ]);
    } else {
      tips.addAll([
        'Great balance! Keep maintaining healthy boundaries.',
        'Encourage your teammates to also take regular breaks.',
        'Keep using your leave — it\'s there for your wellbeing.',
      ]);
    }
    if (unusedRatio > 0.8) {
      tips.add('You still have lots of annual leave — book some time off!');
    }
    if (sickCount >= 3) {
      tips.add('Multiple sick days recently — make sure you\'re fully rested.');
    }
    if (daysSinceLast > 180) {
      tips.add('It\'s been over 6 months since your last leave — you deserve a break!');
    }
    return tips;
  }

  void _submitCheckIn() {
    setState(() {
      _submitted = true;
      _result    = _computeCombined();
      _gaugeController.reset();
      _gaugeController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
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
          'Wellbeing & Burnout',
          style: TextStyle(
              color: Color(0xFF111827), fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildGaugeCard(),
          const SizedBox(height: 16),
          _buildTipsCard(),
          const SizedBox(height: 16),
          if (!_submitted) _buildCheckInCard(),
          if (_submitted)  _buildCompletedBadge(),
          const SizedBox(height: 16),
          _buildInsightsGrid(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // GAUGE CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildGaugeCard() {
    final level = _burnoutLevel(_result.score);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [level.gradStart, level.gradEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: level.gradStart.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(level.icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Wellbeing Score — ${widget.user.name.split(' ').first}',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Gauge arc
          AnimatedBuilder(
            animation: _gaugeAnim,
            builder: (_, __) {
              return CustomPaint(
                size: const Size(200, 110),
                painter: _GaugePainter(
                  progress: _result.score / 100.0 * _gaugeAnim.value,
                  color: Colors.white,
                ),
                child: SizedBox(
                  height: 110,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(_result.score * _gaugeAnim.value).round()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          level.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _result.source,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TIPS CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tips_and_updates_outlined, color: _accent, size: 18),
              SizedBox(width: 8),
              Text(
                'Personalised Recommendations',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF111827)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._result.tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Color(0xFF059669), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tip,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF374151), height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CHECK-IN CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildCheckInCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mood_outlined, color: _accent, size: 18),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Check-In',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF111827)),
                  ),
                  Text(
                    'Takes 30 seconds · improves accuracy',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(_questions.length, (i) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}. ${_questions[i]}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (j) {
                    final val  = j + 1;
                    final sel  = _answers[i] == val;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _answers[i] = val),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 6),
                          height: 36,
                          decoration: BoxDecoration(
                            color: sel ? _blue : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                            border: sel
                                ? null
                                : Border.all(color: _border),
                          ),
                          child: Center(
                            child: Text(
                              '$val',
                              style: TextStyle(
                                color: sel ? Colors.white : _muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),
              ],
            );
          }),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _answers.every((a) => a != null)
                  ? _submitCheckIn
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                disabledBackgroundColor: const Color(0xFFD1D5DB),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text(
                'Submit Check-In',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedBadge() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: const [
          Icon(Icons.check_circle_rounded,
              color: Color(0xFF059669), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Check-in complete! Your score has been updated.',
              style: TextStyle(
                  color: Color(0xFF065F46),
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // INSIGHTS GRID
  // ─────────────────────────────────────────────────────────────
  Widget _buildInsightsGrid() {
    final leaves    = leavesFor(widget.user.id);
    final now       = DateTime.now();
    
    // Only count future approved leaves
    final approved  = leaves.where((l) {
      if (l.status != 'approved') return false;
      try {
        final endDate = DateTime.parse(l.endDate);
        return endDate.isAfter(now);
      } catch (_) { return false; }
    }).length;
    
    // Only count future pending leaves
    final pending   = leaves.where((l) {
      if (l.status != 'pending') return false;
      try {
        final startDate = DateTime.parse(l.startDate);
        return startDate.isAfter(now);
      } catch (_) { return false; }
    }).length;
    
    final balances  = getBalances(widget.user.id);
    final annual    = balances.firstWhere(
      (b) => b.type.toLowerCase().contains('annual'),
      orElse: () =>
          LeaveBalance(type: 'Annual', policyText: '', remaining: 0),
    );

    DateTime? lastEnd;
    for (final l in leaves) {
      if (l.status != 'approved') continue;
      try {
        final d = DateTime.parse(l.endDate);
        if (lastEnd == null || d.isAfter(lastEnd)) lastEnd = d;
      } catch (_) {}
    }
    final daysSince = lastEnd != null && lastEnd.isBefore(now)
        ? now.difference(lastEnd).inDays
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Leave Insights',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Color(0xFF111827)),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            _InsightTile(
              label: 'Approved Leaves',
              value: '$approved',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF059669),
            ),
            _InsightTile(
              label: 'Pending Requests',
              value: '$pending',
              icon: Icons.hourglass_empty_rounded,
              color: const Color(0xFFD97706),
            ),
            _InsightTile(
              label: 'Annual Days Left',
              value: '${annual.remaining ?? "—"}',
              icon: Icons.event_available_outlined,
              color: _accent,
            ),
            _InsightTile(
              label: 'Days Since Last Leave',
              value: daysSince != null ? '$daysSince' : 'N/A',
              icon: Icons.access_time_rounded,
              color: daysSince != null && daysSince > 90
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF7C3AED),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────
  _BurnoutLevel _burnoutLevel(double score) {
    if (score >= 75) {
      return _BurnoutLevel(
        label: 'Thriving',
        icon: Icons.sentiment_very_satisfied_outlined,
        gradStart: const Color(0xFF059669),
        gradEnd: const Color(0xFF34D399),
      );
    } else if (score >= 55) {
      return _BurnoutLevel(
        label: 'Balanced',
        icon: Icons.sentiment_satisfied_outlined,
        gradStart: const Color(0xFF2563EB),
        gradEnd: const Color(0xFF60A5FA),
      );
    } else if (score >= 35) {
      return _BurnoutLevel(
        label: 'At Risk',
        icon: Icons.sentiment_neutral_outlined,
        gradStart: const Color(0xFFD97706),
        gradEnd: const Color(0xFFFBBF24),
      );
    } else {
      return _BurnoutLevel(
        label: 'Burnout Risk',
        icon: Icons.sentiment_very_dissatisfied_outlined,
        gradStart: const Color(0xFFDC2626),
        gradEnd: const Color(0xFFF87171),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// ARC GAUGE PAINTER
// ─────────────────────────────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  const _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;
    final r  = size.width / 2 - 12;

    final trackPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Track arc (180°)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      math.pi,
      math.pi,
      false,
      trackPaint,
    );

    // Fill arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      math.pi,
      math.pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────
// HELPER WIDGETS & DATA
// ─────────────────────────────────────────────────────────────────

class _InsightTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _InsightTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      height: 1.2)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WellbeingResult {
  final double score;
  final String source;
  final List<String> tips;
  const _WellbeingResult(
      {required this.score, required this.source, required this.tips});
}

class _BurnoutLevel {
  final String label;
  final IconData icon;
  final Color gradStart;
  final Color gradEnd;
  const _BurnoutLevel(
      {required this.label,
      required this.icon,
      required this.gradStart,
      required this.gradEnd});
}