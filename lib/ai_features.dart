// lib/ai_features.dart
// ─────────────────────────────────────────────────────────────────────────────
// LeaveFlow — ALL AI FEATURE SCREENS IN ONE FILE
// Import this ONE file in home_screen.dart:
//   import 'ai_features.dart';
//
// Exports:
//   • AiLeaveAssistantScreen(user: user)
//   • SmartLeavePlanningScreen(user: user)
//   • WellbeingScreen(user: user)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'employee_data.dart';
import 'leave_balance_data.dart';
import 'leave_data.dart'; // LeaveApplication, myLeaves, leavesFor

// ═════════════════════════════════════════════════════════════════════════════
// 1.  AI LEAVE ASSISTANT CHATBOT
// ═════════════════════════════════════════════════════════════════════════════

class AiLeaveAssistantScreen extends StatefulWidget {
  final Employee user;
  const AiLeaveAssistantScreen({super.key, required this.user});

  @override
  State<AiLeaveAssistantScreen> createState() =>
      _AiLeaveAssistantScreenState();
}

class _AiLeaveAssistantScreenState extends State<AiLeaveAssistantScreen> {
  final _controller       = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMsg> _msgs = [];
  bool _typing = false;

  static const _navy   = Color(0xFF1E2D5A);
  static const _blue   = Color(0xFF3B4D79);
  static const _accent = Color(0xFF6C8EF5);
  static const _bg     = Color(0xFFF5F7FB);
  static const _border = Color(0xFFE5E7EB);
  static const _muted  = Color(0xFF6B7280);

  static const _quickReplies = [
    'How many leave days do I have left?',
    'What types of leave can I apply for?',
    'Can I take leave during a public holiday?',
    'How do I apply for sick leave?',
    'What is the leave carry-over policy?',
  ];

  @override
  void initState() {
    super.initState();
    _msgs.add(_ChatMsg(
      text: "Hi ${widget.user.name.split(' ').first}! 👋 I'm your AI leave "
          "assistant. Ask me anything about leave policies, balances, or "
          "planning — I'm here to help!",
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _systemPrompt() {
    final balances = getBalances(widget.user.id);

    // Build balance summary from live app data
    final balanceSummary = balances.map((b) {
      if (b.allocated != null && b.remaining != null) {
        final used = b.used;
        return '${b.type}: ${b.remaining} remaining, $used used of ${b.allocated}';
      }
      return '${b.type}: unlimited/untracked';
    }).join('\n  ');

    // Build leave history from in-memory list
    final myLeaveHistory = leavesFor(widget.user.id);
    final historyLines = myLeaveHistory.isEmpty
        ? 'No leave history this session.'
        : myLeaveHistory.map((l) =>
            '- ${l.leaveType} from ${l.startDate} to ${l.endDate} (${l.totalDays} days) [${l.status}]'
          ).join('\n  ');

    return '''
You are LeaveFlow AI — a friendly, knowledgeable leave management assistant embedded in the LeaveFlow employee app.

EMPLOYEE PROFILE:
- Name: ${widget.user.name}
- Employee ID: ${widget.user.id}
- Department: ${widget.user.department}
- Position: ${widget.user.position}

CURRENT LEAVE BALANCES (live from app):
  $balanceSummary

LEAVE HISTORY (this session):
  $historyLines

YOUR ROLE:
- Answer questions about this employee's specific balances, history, and entitlements using the data above.
- Help plan leave, explain policies, and guide the application process.
- Be concise, warm, and personal — use the employee's first name.
- Use bullet points for lists; keep replies under 200 words unless detail is needed.
- When asked "how many days do I have left", refer to the CURRENT LEAVE BALANCES above.
- Reference South African Labour Law (BCEA) where relevant:
  * Annual Leave: minimum 15 working days/year (this company gives 22)
  * Sick Leave: 30 days per 3-year cycle (this company gives 12/year)
  * Family Responsibility: 3 days/year
  * Maternity: 4 months unpaid (UIF may apply)
  * Public holidays do NOT count as leave days
- If a balance is 0, warn the employee and suggest alternatives.
- Never make up policy details — state clearly if something needs HR confirmation.
''';
  }

  // ── Local rule-based AI — no API key, no quota, always works ──
  // Answers are generated from the employee's real live data.
  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _msgs.add(_ChatMsg(text: text.trim(), isUser: true));
      _typing = true;
    });
    _controller.clear();
    _scrollDown();

    // Small delay to feel natural
    await Future.delayed(const Duration(milliseconds: 600));

    final reply = _localAiReply(text.trim());
    setState(() {
      _msgs.add(_ChatMsg(text: reply, isUser: false));
      _typing = false;
    });
    _scrollDown();
  }

  // ── Rule-based engine ─────────────────────────────────────────
  String _localAiReply(String input) {
    final q          = input.toLowerCase();
    final first      = widget.user.name.split(' ').first;
    final balances   = getBalances(widget.user.id);
    final leaves     = leavesFor(widget.user.id);

    // Helper to find a balance by type
    LeaveBalance? bal(String type) {
      try {
        return balances.firstWhere(
          (b) => b.type.toLowerCase().contains(type.toLowerCase()),
        );
      } catch (_) { return null; }
    }

    // ── How many days / balance queries ────────────────────────
    if (q.contains('how many') || q.contains('days left') ||
        q.contains('balance') || q.contains('remaining') ||
        q.contains('days do i have') || q.contains('how much leave')) {

      final lines = balances.map((b) {
        if (b.remaining == null) return '• ${b.type}: Unlimited';
        final pct = b.allocated != null && b.allocated! > 0
            ? ' (${((b.remaining! / b.allocated!) * 100).round()}% remaining)'
            : '';
        return '• ${b.type}: ${b.remaining} days left of ${b.allocated}$pct';
      }).join('\n');

      return 'Hi $first! Here are your current leave balances:\n\n$lines\n\nWould you like advice on how to best use your remaining days?';
    }

    // ── Annual leave specific ───────────────────────────────────
    if (q.contains('annual')) {
      final b = bal('annual');
      if (b != null && b.remaining != null) {
        final used = b.used;
        String advice = '';
        if (b.remaining! == 0) {
          advice = '\n\n⚠️ You have no annual leave left. Consider applying for unpaid leave if needed.';
        } else if (b.remaining! <= 3) {
          advice = '\n\n⚠️ You only have ${b.remaining} days left — use them wisely!';
        } else {
          advice = '\n\n💡 Tip: Check the Smart Leave Planner to maximise your days around public holidays.';
        }
        return 'Hi $first! Your Annual Leave:\n\n• Allocated: ${b.allocated} days\n• Used: $used days\n• Remaining: ${b.remaining} days$advice';
      }
    }

    // ── Sick leave ──────────────────────────────────────────────
    if (q.contains('sick')) {
      final b = bal('sick');
      if (b != null && b.remaining != null) {
        return 'Your Sick Leave balance:\n\n• Allocated: ${b.allocated} days/year\n• Used: ${b.used} days\n• Remaining: ${b.remaining} days\n\n📋 Under BCEA, you\'re entitled to 30 days sick leave per 3-year cycle. A medical certificate is required for absences of 2+ consecutive days.';
      }
    }

    // ── Maternity / parental ────────────────────────────────────
    if (q.contains('maternity') || q.contains('parental') || q.contains('paternity')) {
      final b = bal(q.contains('maternity') ? 'maternity' : 'parental');
      final rem = b?.remaining;
      return 'Your ${b?.type ?? "Parental"} leave balance: ${rem != null ? "$rem days remaining" : "see HR"}.\n\n📋 BCEA entitles:\n• Maternity: 4 months (unpaid — UIF may apply)\n• Parental: 10 consecutive days\n\nApply through the app or contact HR for documentation requirements.';
    }

    // ── Family responsibility ───────────────────────────────────
    if (q.contains('family') || q.contains('responsibility')) {
      final b = bal('family');
      return 'Your Family Responsibility Leave:\n\n• Remaining: ${b?.remaining ?? 3} days\n\n📋 Under BCEA you get 3 days per year for:\n• Death of a family member\n• Child\'s illness\n• Birth of your child\n\nA supporting document may be required.';
    }

    // ── Unpaid leave ────────────────────────────────────────────
    if (q.contains('unpaid')) {
      return 'Unpaid Leave is available when your other balances are exhausted.\n\n• No fixed limit — subject to management approval\n• Your salary is not paid during this period\n• UIF benefits may apply for extended periods\n\nApply through the app and your manager will review the request.';
    }

    // ── My leave history / applications ────────────────────────
    if (q.contains('my leave') || q.contains('history') ||
        q.contains('applications') || q.contains('applied') ||
        q.contains('status')) {
      if (leaves.isEmpty) {
        return 'Hi $first! You have no leave applications on record in this session. Use "Apply for Leave" from the home screen to submit one.';
      }
      final lines = leaves.map((l) =>
        '• ${l.leaveType}: ${l.startDate}–${l.endDate} (${l.totalDays} days) — ${l.status.toUpperCase()}'
      ).join('\n');
      final pending  = leaves.where((l) => l.status == 'pending').length;
      final approved = leaves.where((l) => l.status == 'approved').length;
      return 'Hi $first! Your leave applications:\n\n$lines\n\nSummary: $approved approved, $pending pending.';
    }

    // ── How to apply ────────────────────────────────────────────
    if (q.contains('how to apply') || q.contains('apply for') ||
        q.contains('submit') || q.contains('request leave')) {
      return 'To apply for leave, $first:\n\n1. Tap "Apply" on the home screen\n2. Select your leave type\n3. Choose start & end dates (weekends & public holidays are excluded automatically)\n4. Enter your reason\n5. Attach a supporting document if required (e.g. sick note)\n6. Tap "Submit Application"\n\nYour manager will be notified and you\'ll receive a notification when it\'s decided.';
    }

    // ── Public holidays ─────────────────────────────────────────
    if (q.contains('public holiday') || q.contains('holiday')) {
      return '📅 Public holidays do NOT count as leave days in South Africa.\n\nUpcoming SA public holidays in 2025:\n• 21 Mar — Human Rights Day\n• 18 Apr — Good Friday\n• 21 Apr — Family Day\n• 27 Apr — Freedom Day\n• 1 May — Workers\' Day\n• 16 Jun — Youth Day\n• 9 Aug — National Women\'s Day\n• 24 Sep — Heritage Day\n• 16 Dec — Day of Reconciliation\n• 25 Dec — Christmas Day\n• 26 Dec — Day of Goodwill\n\n💡 Use the Smart Leave Planner to take advantage of bridge days!';
    }

    // ── Carry over / rollover ───────────────────────────────────
    if (q.contains('carry') || q.contains('rollover') || q.contains('expire') ||
        q.contains('lose') || q.contains('expir')) {
      final b = bal('annual');
      return 'Leave carry-over policy:\n\n• Annual leave must generally be used within the leave cycle\n• Unused leave ${b != null && b.remaining != null && b.remaining! > 5 ? "(you have ${b.remaining} days remaining)" : ""} may not automatically roll over\n• Under BCEA, employers can require you to take leave if it accumulates excessively\n\n💡 You currently have ${b?.remaining ?? "unknown"} annual leave days — I recommend planning to use them before year end. Try the Smart Leave Planner!';
    }

    // ── Sick note / medical certificate ────────────────────────
    if (q.contains('sick note') || q.contains('medical') || q.contains('certificate') || q.contains('doctor')) {
      return 'Medical certificate requirements:\n\n• Required for sick leave of 2+ consecutive days\n• Must be issued by a registered medical practitioner\n• Should be submitted when you return to work\n• Attach it when applying via the app under "Supporting Document"\n\n⚠️ Sick leave without a certificate (when required) may be converted to unpaid leave by HR.';
    }

    // ── Cancel leave ────────────────────────────────────────────
    if (q.contains('cancel') || q.contains('withdraw')) {
      return 'To cancel a leave application:\n\n1. Go to "My Leaves" from the home screen\n2. Tap on the leave you want to cancel\n3. Tap "Cancel"\n\n📋 Note:\n• Pending leaves can be cancelled anytime\n• Approved leaves can also be cancelled — your balance will be refunded\n• Cancellation notifications are sent to HR automatically';
    }

    // ── Wellbeing / burnout ─────────────────────────────────────
    if (q.contains('wellbeing') || q.contains('burnout') || q.contains('stress') || q.contains('tired')) {
      final daysSinceLeave = () {
        DateTime? lastEnd;
        for (final l in leaves) {
          if (l.status != 'approved') continue;
          try {
            final d = DateTime.parse(l.endDate);
            if (lastEnd == null || d.isAfter(lastEnd)) lastEnd = d;
          } catch (_) {}
        }
        return lastEnd != null
            ? DateTime.now().difference(lastEnd).inDays
            : null;
      }();

      String advice = '';
      if (daysSinceLeave != null && daysSinceLeave > 90) {
        advice = '\n\n⚠️ It\'s been $daysSinceLeave days since your last approved leave — that\'s quite a while! Consider booking some time off soon.';
      }

      return 'Your wellbeing matters, $first! 💚\n\nCheck the "Wellbeing & Burnout" feature on the home screen for your personal score based on your leave patterns.$advice\n\nGeneral tips:\n• Take regular short breaks during the day\n• Use your leave entitlement — it\'s there for a reason\n• Talk to HR if your workload feels unmanageable';
    }

    // ── Greetings ───────────────────────────────────────────────
    if (q.contains('hello') || q.contains('hi') || q.contains('hey') ||
        q == 'hi' || q == 'hello') {
      final b = bal('annual');
      return 'Hello $first! 👋 I\'m your LeaveFlow AI assistant.\n\nYou currently have ${b?.remaining ?? "unknown"} annual leave days remaining.\n\nI can help you with:\n• Checking any leave balance\n• Understanding leave policies\n• Guidance on applying or cancelling leave\n• SA Labour Law (BCEA) questions\n\nWhat would you like to know?';
    }

    // ── Thank you ───────────────────────────────────────────────
    if (q.contains('thank') || q.contains('thanks')) {
      return 'You\'re welcome, $first! 😊 Feel free to ask anything else about your leave. Have a great day!';
    }

    // ── Default fallback with suggestions ──────────────────────
    final annualBal = bal('annual');
    return 'Hi $first! I\'m not sure I understood that fully, but here\'s what I can help with:\n\n• 📊 "How many leave days do I have left?"\n• 📅 "How do I apply for leave?"\n• 🏥 "What is the sick leave policy?"\n• 🌍 "When are the public holidays?"\n• ❌ "How do I cancel my leave?"\n• 💚 "How is my wellbeing score calculated?"\n\nYour current annual leave balance: ${annualBal?.remaining ?? "unknown"} days remaining.\n\nTry asking one of the questions above!';
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        surfaceTintColor: _navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF5B7BF8), Color(0xFF3B4D79)]),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AI Leave Assistant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            Text('Powered by LeaveFlow AI', style: TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withOpacity(0.1)),
        ),
      ),
      body: Column(children: [
        Expanded(child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: _msgs.length,
          itemBuilder: (_, i) => _bubble(_msgs[i]),
        )),
        if (_typing) _typingRow(),
        _quickReplyBar(),
        _inputBar(),
      ]),
    );
  }

  Widget _bubble(_ChatMsg msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF5B7BF8), Color(0xFF3B4D79)]),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? _blue : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: _border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Text(msg.text, style: TextStyle(color: isUser ? Colors.white : const Color(0xFF111827), fontSize: 13.5, height: 1.5)),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _typingRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF5B7BF8), Color(0xFF3B4D79)]),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => _TypingDot(delay: Duration(milliseconds: i * 200)))),
        ),
      ]),
    );
  }

  Widget _quickReplyBar() {
    return Container(
      height: 44, color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _send(_quickReplies[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD7E3FF)),
            ),
            child: Text(_quickReplies[i], style: const TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(left: 12, right: 12, top: 10, bottom: MediaQuery.of(context).viewInsets.bottom + 12),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(24), border: Border.all(color: _border)),
            child: TextField(
              controller: _controller,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              style: const TextStyle(fontSize: 13.5),
              decoration: const InputDecoration(
                hintText: 'Ask me anything about leave…',
                hintStyle: TextStyle(color: _muted, fontSize: 13.5),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _send(_controller.text),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF5B7BF8), Color(0xFF3B4D79)]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

class _ChatMsg { final String text; final bool isUser; _ChatMsg({required this.text, required this.isUser}); }

class _TypingDot extends StatefulWidget {
  final Duration delay;
  const _TypingDot({required this.delay});
  @override State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    Future.delayed(widget.delay, () { if (mounted) _ctrl.repeat(reverse: true); });
    _anim = Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(color: Color(0xFF3B4D79), shape: BoxShape.circle)),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2.  SMART LEAVE PLANNING SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class SmartLeavePlanningScreen extends StatefulWidget {
  final Employee user;
  const SmartLeavePlanningScreen({super.key, required this.user});
  @override State<SmartLeavePlanningScreen> createState() => _SmartLeavePlanningScreenState();
}

class _SmartLeavePlanningScreenState extends State<SmartLeavePlanningScreen> {
  static const _navy   = Color(0xFF1E2D5A);
  static const _blue   = Color(0xFF3B4D79);
  static const _accent = Color(0xFF6C8EF5);
  static const _bg     = Color(0xFFF5F7FB);
  static const _border = Color(0xFFE5E7EB);
  static const _muted  = Color(0xFF6B7280);
  static const _green  = Color(0xFF059669);

  static final _holidays = <_Holiday>[
    _Holiday("New Year's Day",       DateTime(2025,  1,  1)),
    _Holiday("Human Rights Day",      DateTime(2025,  3, 21)),
    _Holiday("Good Friday",           DateTime(2025,  4, 18)),
    _Holiday("Family Day",            DateTime(2025,  4, 21)),
    _Holiday("Freedom Day",           DateTime(2025,  4, 27)),
    _Holiday("Workers' Day",          DateTime(2025,  5,  1)),
    _Holiday("Youth Day",             DateTime(2025,  6, 16)),
    _Holiday("National Women's Day",  DateTime(2025,  8,  9)),
    _Holiday("Heritage Day",          DateTime(2025,  9, 24)),
    _Holiday("Day of Reconciliation", DateTime(2025, 12, 16)),
    _Holiday("Christmas Day",         DateTime(2025, 12, 25)),
    _Holiday("Day of Goodwill",       DateTime(2025, 12, 26)),
    _Holiday("New Year's Day 2026",   DateTime(2026,  1,  1)),
    _Holiday("Human Rights Day 2026", DateTime(2026,  3, 21)),
  ];

  List<_Suggestion> _suggestions = [];

  @override
  void initState() { super.initState(); _build(); }

  void _build() {
    final balances = getBalances(widget.user.id);
    final annual = balances.firstWhere(
      (b) => b.type.toLowerCase().contains('annual'),
      orElse: () => LeaveBalance(type: 'Annual Leave', policyText: '', allocated: 15, remaining: 10),
    );
    final daysLeft = annual.remaining ?? 10;
    final today = DateTime.now();
    final result = <_Suggestion>[];

    for (final ph in _holidays) {
      if (ph.date.isBefore(today)) continue;

      if (ph.date.weekday == DateTime.tuesday) {
        final bridge = ph.date.subtract(const Duration(days: 1));
        result.add(_Suggestion(
          title: 'Long Weekend — ${ph.name}',
          subtitle: 'Take 1 leave day (${_fmt(bridge)}) → 4-day weekend',
          need: 1, free: 4,
          icon: Icons.weekend_outlined, color: const Color(0xFF7C3AED),
          start: bridge, end: ph.date,
          tip: '${_fmt(bridge)} off + ${ph.name} = 4-day break for just 1 leave day!',
        ));
      }
      if (ph.date.weekday == DateTime.thursday) {
        final fri = ph.date.add(const Duration(days: 1));
        result.add(_Suggestion(
          title: 'Long Weekend — ${ph.name}',
          subtitle: 'Take Friday (${_fmt(fri)}) off → 4-day weekend',
          need: 1, free: 4,
          icon: Icons.weekend_outlined, color: const Color(0xFF7C3AED),
          start: ph.date, end: fri,
          tip: 'Take ${_fmt(fri)} — 4-day weekend for only 1 leave day!',
        ));
      }
      if (ph.date.weekday == DateTime.wednesday) {
        final tue = ph.date.subtract(const Duration(days: 1));
        final thu = ph.date.add(const Duration(days: 1));
        result.add(_Suggestion(
          title: '5-Day Break — ${ph.name}',
          subtitle: 'Take Tue & Thu off → 5-day week for 2 leave days',
          need: 2, free: 5,
          icon: Icons.beach_access_outlined, color: _green,
          start: tue, end: thu,
          tip: '${_fmt(tue)} + ${_fmt(thu)} = full 5-day week for only 2 leave days!',
        ));
      }
    }

    final yearEnd = DateTime(today.year, 12, 31);
    if (yearEnd.difference(today).inDays < 90 && daysLeft >= 3) {
      result.add(_Suggestion(
        title: 'Use It or Lose It ⚠️',
        subtitle: 'You have $daysLeft annual days — use them before year end',
        need: daysLeft, free: daysLeft,
        icon: Icons.warning_amber_rounded, color: const Color(0xFFD97706),
        start: today.add(const Duration(days: 7)), end: yearEnd,
        tip: 'Year-end is in ${yearEnd.difference(today).inDays} days. Plan now!',
      ));
    }

    final dec22 = DateTime(today.year < 2025 ? 2025 : today.year, 12, 22);
    if (dec22.isAfter(today) && daysLeft >= 5) {
      result.add(_Suggestion(
        title: 'Festive Season Block 🎄',
        subtitle: 'Dec 22 – Jan 2: use 5 leave days → 12 days off',
        need: 5, free: 12,
        icon: Icons.celebration_outlined, color: const Color(0xFFDC2626),
        start: dec22, end: DateTime(today.year < 2025 ? 2026 : today.year + 1, 1, 2),
        tip: '5 leave days + 2 public holidays + weekends = 12-day break!',
      ));
    }

    result.sort((a, b) => a.start.compareTo(b.start));
    setState(() => _suggestions = result.take(6).toList());
  }

  static String _fmt(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const w = ['','Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${w[d.weekday]} ${d.day} ${m[d.month]}';
  }

  @override
  Widget build(BuildContext context) {
    final balances = getBalances(widget.user.id);
    final annual = balances.firstWhere(
      (b) => b.type.toLowerCase().contains('annual'),
      orElse: () => LeaveBalance(type: 'Annual Leave', policyText: '', allocated: 15, remaining: 0),
    );
    final daysLeft = annual.remaining ?? 0;
    final pct = (daysLeft / 15.0).clamp(0.0, 1.0);
    final barColor = pct > 0.5 ? _green : pct > 0.25 ? const Color(0xFFD97706) : const Color(0xFFDC2626);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy, elevation: 0, surfaceTintColor: _navy,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Smart Leave Planner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: Colors.white.withOpacity(0.1))),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Summary banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E2D5A), Color(0xFF3B4D79)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: _navy.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 14),
                const SizedBox(width: 8),
                Text('Hello, ${widget.user.name.split(' ').first}!', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$daysLeft days', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  const Text('Annual leave remaining', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: barColor.withOpacity(0.2), borderRadius: BorderRadius.circular(13), border: Border.all(color: barColor.withOpacity(0.5))),
                  child: Center(child: Text('${(pct * 100).round()}%', style: TextStyle(color: barColor, fontWeight: FontWeight.w800, fontSize: 14))),
                ),
              ]),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.white.withOpacity(0.15), valueColor: AlwaysStoppedAnimation(barColor))),
            ]),
          ),
          const SizedBox(height: 20),

          Row(children: [
            Container(width: 3, height: 16, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text('Recommended Opportunities', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
          const SizedBox(height: 4),
          Text('Based on your $daysLeft remaining days & SA public holidays', style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 14),

          if (_suggestions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
              child: const Column(children: [
                Icon(Icons.event_available_outlined, color: _muted, size: 40),
                SizedBox(height: 12),
                Text('No upcoming suggestions right now.', textAlign: TextAlign.center, style: TextStyle(color: _muted)),
              ]),
            )
          else
            ..._suggestions.map((s) => _suggestionCard(s)),

          const SizedBox(height: 20),
          Row(children: [
            Container(width: 3, height: 16, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text('Upcoming Public Holidays', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          _holidayList(),
        ],
      ),
    );
  }

  Widget _suggestionCard(_Suggestion s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))]),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: s.color.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: s.color.withOpacity(0.15))),
          ),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: s.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(s.icon, color: s.color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF111827))),
              const SizedBox(height: 2),
              Text(s.subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
            ])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _statChip('Leave days', '${s.need}', _blue),
              const SizedBox(width: 10),
              _statChip('Days off', '${s.free}', _green),
              const SizedBox(width: 10),
              _statChip('Ratio', '1:${(s.free / s.need).toStringAsFixed(1)}', s.color),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
              child: Row(children: [
                const Icon(Icons.tips_and_updates_outlined, color: _accent, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(s.tip, style: const TextStyle(color: _blue, fontSize: 12, height: 1.4))),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _holidayList() {
    final today = DateTime.now();
    final upcoming = _holidays.where((h) => h.date.isAfter(today)).take(8).toList();
    const days = ['','Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        children: upcoming.asMap().entries.map((e) {
          final h = e.value;
          final isLast = e.key == upcoming.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: _border))),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('${h.date.day}', style: const TextStyle(color: _accent, fontWeight: FontWeight.w800, fontSize: 16))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF111827))),
                Text('${days[h.date.weekday]}, ${h.date.day} ${months[h.date.month]} ${h.date.year}', style: const TextStyle(color: _muted, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                child: Text(days[h.date.weekday], style: const TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

class _Holiday   { final String name; final DateTime date; const _Holiday(this.name, this.date); }
class _Suggestion {
  final String title, subtitle, tip;
  final int need, free;
  final IconData icon;
  final Color color;
  final DateTime start, end;
  const _Suggestion({required this.title, required this.subtitle, required this.tip, required this.need, required this.free, required this.icon, required this.color, required this.start, required this.end});
}

// ═════════════════════════════════════════════════════════════════════════════
// 3.  WELLBEING & BURNOUT INDICATOR
// ═════════════════════════════════════════════════════════════════════════════

class WellbeingScreen extends StatefulWidget {
  final Employee user;
  const WellbeingScreen({super.key, required this.user});
  @override State<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends State<WellbeingScreen> with TickerProviderStateMixin {
  static const _navy   = Color(0xFF1E2D5A);
  static const _blue   = Color(0xFF3B4D79);
  static const _accent = Color(0xFF6C8EF5);
  static const _bg     = Color(0xFFF5F7FB);
  static const _border = Color(0xFFE5E7EB);
  static const _muted  = Color(0xFF6B7280);

  static const _questions = [
    'How energised do you feel at work lately?',
    'How well are you managing your workload?',
    'How stressed or overwhelmed do you feel?',
    'How satisfied are you with your work–life balance?',
    'How rested do you feel after time off?',
  ];

  final List<int?> _answers = List.filled(5, null);
  bool _submitted = false;
  late AnimationController _gaugeCtrl;
  late Animation<double> _gaugeAnim;
  late _WbResult _result;

  @override
  void initState() {
    super.initState();
    _gaugeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _gaugeAnim = CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic);
    _result = _behavioural();
    _gaugeCtrl.forward();
  }

  @override
  void dispose() { _gaugeCtrl.dispose(); super.dispose(); }

  _WbResult _behavioural() {
    final id = widget.user.id;
    final leaves = leavesFor(id);
    final balances = getBalances(id);
    final now = DateTime.now();

    final annual = balances.firstWhere(
      (b) => b.type.toLowerCase().contains('annual'),
      orElse: () => LeaveBalance(type: 'Annual', policyText: '', allocated: 15, remaining: 15),
    );
    final unusedRatio = (annual.allocated != null && annual.allocated! > 0)
        ? (annual.remaining ?? 0) / annual.allocated!
        : 0.5;
    final f1 = unusedRatio > 0.8 ? 30.0 : unusedRatio > 0.5 ? 55.0 : 75.0;

    final sixAgo = now.subtract(const Duration(days: 180));
    int recentSick = 0;
    for (final l in leaves) {
      if (!l.leaveType.toLowerCase().contains('sick')) continue;
      try {
        if (DateTime.parse(l.startDate).isAfter(sixAgo)) recentSick++;
      } catch (_) {}
    }
    final f2 = recentSick == 0 ? 80.0 : recentSick <= 2 ? 60.0 : 35.0;

    final rejected = leaves.where((l) => l.status == 'rejected').length;
    final pending  = leaves.where((l) => l.status == 'pending').length;
    final f3 = rejected >= 2 ? 40.0 : pending >= 3 ? 55.0 : 75.0;

    DateTime? lastEnd;
    for (final l in leaves) {
      if (l.status != 'approved') continue;
      try {
        final d = DateTime.parse(l.endDate);
        if (lastEnd == null || d.isAfter(lastEnd)) lastEnd = d;
      } catch (_) {}
    }
    final daysSince = lastEnd != null ? now.difference(lastEnd).inDays : 999;
    final f4 = daysSince < 30 ? 85.0 : daysSince < 90 ? 65.0 : daysSince < 180 ? 45.0 : 25.0;

    final score = ((f1 + f2 + f3 + f4) / 4.0).clamp(0.0, 100.0);
    return _WbResult(score: score, source: 'Behavioural Analysis', tips: _tips(score, unusedRatio, recentSick, daysSince));
  }

  _WbResult _combined() {
    final base = _behavioural();
    final answered = _answers.where((a) => a != null).length;
    if (answered == 0) return base;
    final validAnswers = _answers.where((a) => a != null).map((a) => (a as int) * 20.0).toList();
    double selfSum = 0.0;
    for (final v in validAnswers) { selfSum += v; }
    final self = selfSum / answered;
    final score = (base.score * 0.4 + self * 0.6).clamp(0.0, 100.0);
    return _WbResult(score: score, source: 'Self-Reported + Behavioural', tips: _tips(score, 0, 0, 0));
  }

  List<String> _tips(double score, double unusedRatio, int sick, int daysSince) {
    final t = <String>[];
    if (score < 40) {
      t.addAll(['Consider booking leave soon — rest is essential for recovery.', 'Talk to HR about your workload; support is available.', 'Try to disconnect fully during evenings.']);
    } else if (score < 65) {
      t.addAll(['You\'re managing well — keep an eye on your workload.', 'Plan a short break soon to recharge.', 'Stay connected with your team for peer support.']);
    } else {
      t.addAll(['Great balance! Keep maintaining healthy boundaries.', 'Encourage teammates to also take regular breaks.', 'Keep using your leave — it\'s there for your wellbeing.']);
    }
    if (unusedRatio > 0.8) t.add('You still have lots of annual leave — book some time off!');
    if (sick >= 3) t.add('Multiple sick days recently — make sure you\'re fully rested.');
    if (daysSince > 180) t.add('It\'s been over 6 months since your last leave — you deserve a break!');
    return t;
  }

  void _submit() {
    setState(() { _submitted = true; _result = _combined(); _gaugeCtrl.reset(); _gaugeCtrl.forward(); });
  }

  _BurnoutLevel _level(double score) {
    if (score >= 75) return _BurnoutLevel('Thriving',     Icons.sentiment_very_satisfied_outlined, const Color(0xFF059669), const Color(0xFF34D399));
    if (score >= 55) return _BurnoutLevel('Balanced',     Icons.sentiment_satisfied_outlined,      const Color(0xFF2563EB), const Color(0xFF60A5FA));
    if (score >= 35) return _BurnoutLevel('At Risk',      Icons.sentiment_neutral_outlined,         const Color(0xFFD97706), const Color(0xFFFBBF24));
    return             _BurnoutLevel('Burnout Risk',  Icons.sentiment_very_dissatisfied_outlined, const Color(0xFFDC2626), const Color(0xFFF87171));
  }

  @override
  Widget build(BuildContext context) {
    final lv = _level(_result.score);
    final leaves = leavesFor(widget.user.id);
    final approved = leaves.where((l) => l.status == 'approved').length;
    final pending  = leaves.where((l) => l.status == 'pending').length;
    final balances = getBalances(widget.user.id);
    final annual = balances.firstWhere((b) => b.type.toLowerCase().contains('annual'),
        orElse: () => LeaveBalance(type: 'Annual', policyText: '', allocated: 15, remaining: 0));
    final now = DateTime.now();
    DateTime? lastEnd;
    for (final l in leaves) {
      if (l.status != 'approved') continue;
      try {
        final d = DateTime.parse(l.endDate);
        if (lastEnd == null || d.isAfter(lastEnd)) lastEnd = d;
      } catch (_) {}
    }
    final daysSince = lastEnd != null ? now.difference(lastEnd).inDays : null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy, elevation: 0, surfaceTintColor: _navy,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Wellbeing & Burnout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: Colors.white.withOpacity(0.1))),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [

          // Gauge card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [lv.gradStart, lv.gradEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: lv.gradStart.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(children: [
              Row(children: [
                Icon(lv.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Wellbeing Score — ${widget.user.name.split(' ').first}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: _gaugeAnim,
                builder: (_, __) => CustomPaint(
                  size: const Size(200, 110),
                  painter: _GaugePainter(progress: _result.score / 100.0 * _gaugeAnim.value),
                  child: SizedBox(height: 110, child: Align(alignment: Alignment.bottomCenter, child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${(_result.score * _gaugeAnim.value).round()}', style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
                    Text(lv.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ]))),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(_result.source, style: const TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 0.5)),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.tips_and_updates_outlined, color: _accent, size: 18),
                SizedBox(width: 8),
                Text('Personalised Recommendations', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF111827))),
              ]),
              const SizedBox(height: 12),
              ..._result.tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4))),
                ]),
              )),
            ]),
          ),
          const SizedBox(height: 16),

          // Check-in or badge
          if (!_submitted) _checkInCard() else _doneBadge(),
          const SizedBox(height: 16),

          // Insights grid
          Row(children: [
            Container(width: 3, height: 16, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text('Your Leave Insights', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF111827))),
          ]),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.5,
            children: [
              _insightTile('Approved Leaves',    '$approved',  Icons.check_circle_outline,      const Color(0xFF059669)),
              _insightTile('Pending Requests',   '$pending',   Icons.hourglass_empty_rounded,   const Color(0xFFD97706)),
              _insightTile('Annual Days Left',   '${annual.remaining ?? "—"}', Icons.event_available_outlined, _accent),
              _insightTile('Days Since Last Leave', daysSince != null ? '$daysSince' : 'N/A', Icons.access_time_rounded,
                  daysSince != null && daysSince > 90 ? const Color(0xFFDC2626) : const Color(0xFF7C3AED)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _checkInCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.mood_outlined, color: _accent, size: 18)),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Weekly Check-In', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF111827))),
            Text('Takes 30 seconds · improves accuracy', style: TextStyle(color: _muted, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 16),
        ...List.generate(_questions.length, (i) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i + 1}. ${_questions[i]}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const SizedBox(height: 6),
          Row(children: List.generate(5, (j) {
            final val = j + 1;
            final sel = _answers[i] == val;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _answers[i] = val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 6), height: 36,
                decoration: BoxDecoration(
                  color: sel ? _blue : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                  border: sel ? null : Border.all(color: _border),
                ),
                child: Center(child: Text('$val', style: TextStyle(color: sel ? Colors.white : _muted, fontWeight: FontWeight.w700))),
              ),
            ));
          })),
          const SizedBox(height: 14),
        ])),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _answers.every((a) => a != null) ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue, disabledBackgroundColor: const Color(0xFFD1D5DB),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0,
            ),
            child: const Text('Submit Check-In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _doneBadge() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFA7F3D0))),
      child: const Row(children: [
        Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 22),
        SizedBox(width: 10),
        Expanded(child: Text('Check-in complete! Your score has been updated.', style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
    );
  }

  Widget _insightTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(icon, color: color, size: 22),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11, height: 1.3)),
        ]),
      ]),
    );
  }
}

class _WbResult { final double score; final String source; final List<String> tips; const _WbResult({required this.score, required this.source, required this.tips}); }
class _BurnoutLevel { final String label; final IconData icon; final Color gradStart, gradEnd; const _BurnoutLevel(this.label, this.icon, this.gradStart, this.gradEnd); }

class _GaugePainter extends CustomPainter {
  final double progress;
  const _GaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;
    final r  = size.width / 2 - 12;

    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), math.pi, math.pi, false,
        Paint()..color = Colors.white.withOpacity(0.2)..strokeWidth = 14..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), math.pi, math.pi * progress, false,
        Paint()..color = Colors.white.withOpacity(0.9)..strokeWidth = 14..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.progress != progress;
}